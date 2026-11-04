package proc

import com.google.devtools.ksp.processing.*
import com.google.devtools.ksp.symbol.KSAnnotated

class GenerateProvider : SymbolProcessorProvider {
    override fun create(environment: SymbolProcessorEnvironment): SymbolProcessor = Generate(environment)
}

class Generate(private val env: SymbolProcessorEnvironment) : SymbolProcessor {
    private var done = false
    override fun process(resolver: Resolver): List<KSAnnotated> {
        if (done) return emptyList()
        done = true
        val value = env.options["message"] ?: error("processor option missing")
        env.codeGenerator.createNewFile(Dependencies(true), "sample", "Generated", "kt").bufferedWriter().use {
            it.write("package sample\nobject Generated { const val message = \"$value\" }\n")
        }
        env.codeGenerator.createNewFile(Dependencies(true), "", "processor-result", "txt").bufferedWriter().use {
            it.write(value)
        }
        return emptyList()
    }
}
