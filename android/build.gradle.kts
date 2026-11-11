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
// Plugins such as file_picker still compile against an old SDK, but their
// dependencies (flutter_plugin_android_lifecycle) require compileSdk 36+.
// finalizeDsl runs after the plugin's own build script but before AGP reads
// compileSdk, so it is neither overwritten nor "too late" (AGP 9).
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension>("androidComponents") {
            finalizeDsl { library ->
                val current: Int = library.compileSdk ?: 0
                if (current < 36) {
                    library.compileSdk = 36
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
