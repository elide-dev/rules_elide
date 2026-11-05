package dev.elide.bazel;

import com.google.devtools.build.lib.worker.WorkerProtocol.Input;
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkRequest;
import com.google.devtools.build.lib.worker.WorkerProtocol.WorkResponse;
import com.google.protobuf.ByteString;
import com.google.protobuf.UnknownFieldSet;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import java.util.Random;

/** Interoperability checks against Bazel's generated protobuf implementation. */
public final class WorkerProtocolTest {
  private static void require(boolean condition) {
    if (!condition) throw new AssertionError("Worker protocol interoperability failed");
  }

  private static ByteArrayInputStream frame(com.google.protobuf.MessageLite message) throws IOException {
    ByteArrayOutputStream output = new ByteArrayOutputStream();
    message.writeDelimitedTo(output);
    return new ByteArrayInputStream(output.toByteArray());
  }

  public static void main(String[] args) throws Exception {
    UnknownFieldSet unknown = UnknownFieldSet.newBuilder().addField(100,
        UnknownFieldSet.Field.newBuilder().addVarint(-1).addFixed32(42).addFixed64(123456)
            .addLengthDelimited(ByteString.copyFromUtf8("opaque"))
            .addGroup(UnknownFieldSet.newBuilder().addField(5,
                UnknownFieldSet.Field.newBuilder().addVarint(7).build()).build()).build()).build();
    Random random = new Random(4187);
    for (int iteration = 0; iteration < 100; iteration++) {
      byte[] digest = new byte[iteration];
      random.nextBytes(digest);
      WorkRequest original = WorkRequest.newBuilder().addArguments("--")
          .addArguments("source/\u03bb.java").addArguments("x".repeat(iteration * 17))
          .addInputs(Input.newBuilder().setPath("lib/dependency.jar").setDigest(ByteString.copyFrom(digest)))
          .setRequestId(random.nextInt()).setVerbosity(iteration).setCancel(iteration % 2 == 0)
          .setSandboxDir("sandbox").setUnknownFields(unknown).build();
      var decoded = WorkerProtocol.WorkRequest.parseDelimitedFrom(frame(original));
      require(decoded.getArgumentsList().equals(original.getArgumentsList()));
      require(decoded.getRequestId() == original.getRequestId());
      require(decoded.getInputsCount() == 1);
      require(decoded.getInputsList().get(0).getPath().equals("lib/dependency.jar"));
      require(Arrays.equals(decoded.getInputsList().get(0).getDigest(), digest));
      ByteArrayOutputStream output = new ByteArrayOutputStream();
      decoded.withArguments(List.of("--incremental", "--", "new.kt")).writeDelimitedTo(output);
      WorkRequest rewritten = WorkRequest.parseDelimitedFrom(new ByteArrayInputStream(output.toByteArray()));
      require(rewritten.equals(original.toBuilder().clearArguments()
          .addAllArguments(List.of("--incremental", "--", "new.kt")).build()));

      WorkResponse response = WorkResponse.newBuilder().setRequestId(original.getRequestId())
          .setExitCode(iteration % 3 - 1).setOutput("diagnostic \u03bb")
          .setWasCancelled(iteration % 2 == 0).setUnknownFields(unknown).build();
      var decodedResponse = WorkerProtocol.WorkResponse.parseDelimitedFrom(frame(response));
      require(decodedResponse.getRequestId() == response.getRequestId());
      require(decodedResponse.getExitCode() == response.getExitCode());
      require(decodedResponse.getOutput().equals(response.getOutput()));
      output.reset();
      decodedResponse.writeDelimitedTo(output);
      require(WorkResponse.parseDelimitedFrom(new ByteArrayInputStream(output.toByteArray())).equals(response));
      output.reset();
      WorkerProtocol.WorkResponse.error(original.getRequestId(), "error").writeDelimitedTo(output);
      WorkResponse error = WorkResponse.parseDelimitedFrom(new ByteArrayInputStream(output.toByteArray()));
      require(error.getExitCode() == 1 && error.getRequestId() == original.getRequestId());
      require(error.getOutput().equals("error"));
    }
    require(WorkerProtocol.WorkRequest.parseDelimitedFrom(new ByteArrayInputStream(new byte[0])) == null);
    require(WorkerProtocol.WorkRequest.parseDelimitedFrom(new ByteArrayInputStream(new byte[] {0})).getInputsCount() == 0);
    ByteArrayOutputStream stream = new ByteArrayOutputStream();
    WorkRequest.getDefaultInstance().writeDelimitedTo(stream);
    WorkRequest.newBuilder().setRequestId(123).build().writeDelimitedTo(stream);
    ByteArrayInputStream messages = new ByteArrayInputStream(stream.toByteArray());
    require(WorkerProtocol.WorkRequest.parseDelimitedFrom(messages).getRequestId() == 0);
    require(WorkerProtocol.WorkRequest.parseDelimitedFrom(messages).getRequestId() == 123);
    require(WorkerProtocol.WorkRequest.parseDelimitedFrom(messages) == null);
    // Truncated length/body/field, invalid tags/wire types/groups/UTF-8, oversized frame.
    for (byte[] invalid : new byte[][] {
        {(byte) 128}, {2, 8}, {1, 0}, {1, 15}, {1, 12}, {2, 11, 20},
        {2, 10, 2}, {3, 10, 1, (byte) 255},
        {(byte) 255, (byte) 255, (byte) 255, (byte) 255, 127}}) {
      try {
        WorkerProtocol.WorkRequest.parseDelimitedFrom(new ByteArrayInputStream(invalid));
        throw new AssertionError("Malformed request accepted: " + Arrays.toString(invalid));
      } catch (IOException expected) {
        // Invalid data must not be treated as EOF or a successful empty request.
      }
    }
    System.out.println("Worker protocol interoperability and malformed-stream checks passed");
  }
}
