plugins {
    kotlin("jvm") version "1.9.0"
    id("maven-publish")
}

group = "io.panteao"
version = "1.1.17"

repositories {
    mavenCentral()
}

dependencies {
    implementation(kotlin("stdlib"))
    implementation("org.json:json:20231013")
}

publishing {
    publications {
        create<MavenPublication>("mavenJava") {
            from(components["java"])
        }
    }
}
