allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Apply Flutter compatibility script to all subprojects
// This provides Flutter SDK properties to legacy plugins
subprojects {
    if (project.buildFile.exists()) {
        project.apply(from: "${rootProject.projectDir}/flutter_compat.gradle")
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
