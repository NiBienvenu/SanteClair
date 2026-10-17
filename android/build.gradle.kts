import com.android.build.api.variant.LibraryAndroidComponentsExtension

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
// zego_express_engine 3.25 hardcodes API 31. Flutter's AndroidX dependencies
// require API 34+, so finalize its library DSL with the project's API 36.
// Keep this override in the project rather than modifying the pub cache.
subprojects {
    if (name == "zego_express_engine") {
        plugins.withId("com.android.library") {
            extensions.configure<LibraryAndroidComponentsExtension> {
                finalizeDsl { library ->
                    library.compileSdk = maxOf(library.compileSdk ?: 0, 36)
                }
            }
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
