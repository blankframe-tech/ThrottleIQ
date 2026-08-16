allprojects {
    repositories {
        google()
        mavenCentral()
        // flutter_background_geolocation ships its Android AARs inside the
        // plugin directory rather than publishing them to a public Maven
        // repo, so Gradle has to be pointed at them explicitly. Without these
        // two lines the build fails to resolve
        // com.transistorsoft:tslocationmanager and nothing about the error
        // mentions the plugin by name.
        maven(url = "${project(":flutter_background_geolocation").projectDir}/libs")
        // The plugin's background-service dependency chain resolves a Huawei
        // artifact on some configurations; harmless on devices without HMS.
        maven(url = "https://developer.huawei.com/repo/")
    }

    // flutter_background_geolocation's background-service chain pulls
    // androidx.work:work-runtime-ktx:2.7.1, while another plugin resolves
    // plain work-runtime:2.8.1 — same classes, two jars, so the merge fails
    // with "Duplicate class". Forcing both to the newer version keeps a
    // single copy on the classpath.
    configurations.all {
        resolutionStrategy {
            force("androidx.work:work-runtime:2.8.1")
            force("androidx.work:work-runtime-ktx:2.8.1")
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}



plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}



