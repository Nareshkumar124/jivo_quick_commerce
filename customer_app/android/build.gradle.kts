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
subprojects {
    project.evaluationDependsOn(":app")
}

// Mappls maps (D-03). The mappls_gl plugin's Gradle script fails the build
// when no `<appId>.a.olf` config is found next to the app module. The config
// files are secrets that only exist on machines where tool/setup_mappls.sh
// was run, never in git or CI. Without them, skip the plugin's
// generate<Variant>MapplsRes tasks: the app then builds, detects the missing
// config at run time (MainActivity) and shows its no-map fallback.
val mapplsConfigured: Boolean =
    file("app").walkTopDown().maxDepth(4).any { it.isFile && it.name.endsWith(".a.olf") }
if (!mapplsConfigured) {
    logger.lifecycle("Mappls config not found in android/app: building without maps.")
}
subprojects {
    tasks
        .matching { it.name.startsWith("generate") && it.name.endsWith("MapplsRes") }
        .configureEach { onlyIf { mapplsConfigured } }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
