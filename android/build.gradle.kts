allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// 古い compileSdk のままのプラグイン(onnxruntime は 33)を 36 で組む。androidx の依存が 34 以上を求め、
// checkDebugAarMetadata で APK が組めない (D-416 で debug APK を組んだときに判明)。targetSdk / minSdk は変えない。
subprojects {
    val raiseCompileSdk: Project.() -> Unit = {
        val android = extensions.findByName("android")
        if (android != null && plugins.hasPlugin("com.android.library")) {
            val current = (android.withGroovyBuilder { getProperty("compileSdkVersion") } as String?)
                ?.removePrefix("android-")?.toIntOrNull() ?: 0
            if (current in 1..33) android.withGroovyBuilder { "compileSdkVersion"(36) }
        }
    }
    if (state.executed) raiseCompileSdk() else afterEvaluate { raiseCompileSdk() }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
