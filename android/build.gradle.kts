allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Set Gradle extra properties consumed by plugins that read
// rootProject.ext.compileSdkVersion / minSdkVersion (e.g. agora_rtc_engine).
extra["compileSdkVersion"] = 36
extra["minSdkVersion"] = 24

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
