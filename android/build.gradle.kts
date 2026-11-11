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
// mapbox_maps_flutter supone que con AGP 9 Kotlin viene integrado y no aplica 'kotlin-android', pero este
// proyecto tiene android.builtInKotlin=false (plantilla de Flutter). Se le aplica aquí para que su bloque
// `kotlin {}` exista. Quitarlo cuando el plugin lo resuelva o se active builtInKotlin.
subprojects {
    if (name == "mapbox_maps_flutter_mobile") {
        pluginManager.withPlugin("com.android.library") { pluginManager.apply("org.jetbrains.kotlin.android") }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
