import org.gradle.api.file.Directory

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Apply Flutter compatibility script for legacy plugins
subprojects {
    if (buildFile.exists()) {
        apply(from = rootProject.file("flutter_compat.gradle"))
    }
}

// Flutter build directory outside android/
val newBuildDir: Directory =
    rootProject.layout.buildDirectory.dir("../../build").get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    layout.buildDirectory.value(newBuildDir.dir(name))
}

// Ensure app module evaluated first
subprojects {
    evaluationDependsOn(":app")
}

// 🔒 Force AndroidX versions (prevents AGP 8.9+ deps)
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.12.0")
            force("androidx.core:core-ktx:1.12.0")
            force("androidx.browser:browser:1.8.0")
        }
    }
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
