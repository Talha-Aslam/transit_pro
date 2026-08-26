allprojects {
    repositories {
        google()
        mavenCentral()
        // Mapbox Maps SDK is not on mavenCentral — it's a private repo gated by
        // the sk.* download token (Downloads:Read scope), read from
        // ~/.gradle/gradle.properties as MAPBOX_DOWNLOADS_TOKEN. Mapbox's server
        // returns 404 (not 401) to an unauthenticated request, so Gradle never
        // gets a challenge to trigger lazy auth — credentials must be declared
        // up front, which is why this can't just be a bare maven { url = ... }.
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            credentials {
                username = "mapbox"
                password =
                    providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").getOrElse("")
            }
            authentication {
                create<org.gradle.authentication.http.BasicAuthentication>("basic")
            }
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
