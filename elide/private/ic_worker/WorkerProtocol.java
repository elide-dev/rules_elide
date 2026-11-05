package dev.elide.bazel;

import java.io.ByteArrayOutputStream;
import java.io.EOFException;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/** Minimal Bazel worker wire codec; preserves unknown fields when forwarding messages. */
final class WorkerProtocol {
  private static final int MAX_MESSAGE = 64 * 1024 * 1024;

  private static final class Cursor {
    final byte[] data;
    int position;
    Cursor(byte[] data) { this.data = data; }
    long varint() throws IOException {
      long result = 0;
      for (int shift = 0; shift < 64; shift += 7) {
        if (position == data.length) throw new EOFException("Truncated protobuf varint");
        int value = data[position++] & 255;
        if (shift == 63 && value > 1) throw new IOException("Invalid protobuf varint");
        result |= (long) (value & 127) << shift;
        if (value < 128) return result;
      }
      throw new IOException("Invalid protobuf varint");
    }
    void skip(long length) throws IOException {
      if (length < 0 || length > data.length - position) throw new EOFException("Truncated protobuf field");
      position += (int) length;
    }
  }

  private static final class Field {
    int number;
    int wire;
    long scalar;
    byte[] bytes;
    byte[] raw;
  }

  private static Field field(Cursor cursor, int depth) throws IOException {
    if (depth > 100) throw new IOException("Protobuf nesting limit exceeded");
    int start = cursor.position;
    long tag = cursor.varint();
    if (tag <= 0 || tag > 0xffffffffL || (tag >>> 3) == 0) throw new IOException("Invalid protobuf tag");
    Field field = new Field();
    field.number = (int) (tag >>> 3);
    field.wire = (int) (tag & 7);
    switch (field.wire) {
      case 0: field.scalar = cursor.varint(); break;
      case 1: cursor.skip(8); break;
      case 2:
        long length = cursor.varint();
        int from = cursor.position;
        cursor.skip(length);
        field.bytes = Arrays.copyOfRange(cursor.data, from, cursor.position);
        break;
      case 3:
        while (true) {
          Field nested = field(cursor, depth + 1);
          if (nested.wire == 4) {
            if (nested.number != field.number) throw new IOException("Mismatched protobuf group");
            break;
          }
        }
        break;
      case 4: break;
      case 5: cursor.skip(4); break;
      default: throw new IOException("Invalid protobuf wire type");
    }
    field.raw = Arrays.copyOfRange(cursor.data, start, cursor.position);
    return field;
  }

  private static List<Field> fields(byte[] data) throws IOException {
    Cursor cursor = new Cursor(data);
    List<Field> fields = new ArrayList<>();
    while (cursor.position < data.length) {
      Field field = field(cursor, 0);
      if (field.wire == 4) throw new IOException("Unexpected protobuf end group");
      fields.add(field);
    }
    return fields;
  }

  private static void varint(OutputStream output, long value) throws IOException {
    while ((value & ~127L) != 0) {
      output.write((int) value & 127 | 128);
      value >>>= 7;
    }
    output.write((int) value);
  }

  private static String text(byte[] bytes) throws IOException {
    return StandardCharsets.UTF_8.newDecoder().decode(java.nio.ByteBuffer.wrap(bytes)).toString();
  }

  private static void string(OutputStream output, int number, String value) throws IOException {
    byte[] bytes = value.getBytes(StandardCharsets.UTF_8);
    varint(output, number * 8 + 2);
    varint(output, bytes.length);
    output.write(bytes);
  }

  private static byte[] read(InputStream input) throws IOException {
    int first = input.read();
    if (first < 0) return null;
    long length = first & 127;
    int value = first;
    for (int shift = 7; value >= 128; shift += 7) {
      if (shift > 28) throw new IOException("Invalid worker message length");
      value = input.read();
      if (value < 0) throw new EOFException("Truncated worker message length");
      length |= (long) (value & 127) << shift;
    }
    if (length > MAX_MESSAGE) throw new IOException("Worker message exceeds 64 MiB");
    byte[] bytes = input.readNBytes((int) length);
    if (bytes.length != length) throw new EOFException("Truncated worker message");
    return bytes;
  }

  static final class Input {
    private String path = "";
    private byte[] digest = new byte[0];
    String getPath() { return path; }
    byte[] getDigest() { return digest; }
  }

  static final class WorkRequest {
    private final List<Field> fields;
    private final List<String> arguments = new ArrayList<>();
    private final List<Input> inputs = new ArrayList<>();
    private int requestId;
    private WorkRequest(byte[] bytes) throws IOException {
      fields = fields(bytes);
      for (Field field : fields) {
        if (field.number == 1 && field.wire == 2) arguments.add(text(field.bytes));
        if (field.number == 3 && field.wire == 0) requestId = (int) field.scalar;
        if (field.number == 2 && field.wire == 2) {
          Input input = new Input();
          for (Field entry : fields(field.bytes)) {
            if (entry.number == 1 && entry.wire == 2) input.path = text(entry.bytes);
            if (entry.number == 2 && entry.wire == 2) input.digest = entry.bytes;
          }
          inputs.add(input);
        }
      }
    }
    static WorkRequest parseDelimitedFrom(InputStream input) throws IOException {
      byte[] bytes = read(input);
      return bytes == null ? null : new WorkRequest(bytes);
    }
    static WorkRequest create(List<String> args) throws IOException {
      return new WorkRequest(new byte[0]).withArguments(args);
    }
    WorkRequest withArguments(List<String> args) throws IOException {
      ByteArrayOutputStream output = new ByteArrayOutputStream();
      for (String arg : args) string(output, 1, arg);
      for (Field field : fields) {
        if (field.number != 1 || field.wire != 2) output.write(field.raw);
      }
      return new WorkRequest(output.toByteArray());
    }
    void writeDelimitedTo(OutputStream output) throws IOException {
      int length = 0;
      for (Field field : fields) length += field.raw.length;
      varint(output, length);
      for (Field field : fields) output.write(field.raw);
    }
    List<String> getArgumentsList() { return arguments; }
    List<Input> getInputsList() { return inputs; }
    int getInputsCount() { return inputs.size(); }
    int getRequestId() { return requestId; }
  }

  static final class WorkResponse {
    private final byte[] bytes;
    private int exitCode;
    private int requestId;
    private String output = "";
    private WorkResponse(byte[] bytes) throws IOException {
      this.bytes = bytes;
      for (Field field : fields(bytes)) {
        if (field.number == 1 && field.wire == 0) exitCode = (int) field.scalar;
        if (field.number == 2 && field.wire == 2) output = text(field.bytes);
        if (field.number == 3 && field.wire == 0) requestId = (int) field.scalar;
      }
    }
    static WorkResponse parseDelimitedFrom(InputStream input) throws IOException {
      byte[] bytes = read(input);
      return bytes == null ? null : new WorkResponse(bytes);
    }
    static WorkResponse error(int requestId, String message) throws IOException {
      ByteArrayOutputStream output = new ByteArrayOutputStream();
      varint(output, 8); varint(output, 1);
      string(output, 2, message);
      varint(output, 24); varint(output, requestId);
      return new WorkResponse(output.toByteArray());
    }
    void writeDelimitedTo(OutputStream output) throws IOException {
      varint(output, bytes.length);
      output.write(bytes);
    }
    int getExitCode() { return exitCode; }
    int getRequestId() { return requestId; }
    String getOutput() { return output; }
  }
}
