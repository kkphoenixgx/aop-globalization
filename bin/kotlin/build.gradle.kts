plugins {
    kotlin("jvm") version "1.9.0"
    application
}
repositories {
    mavenCentral()
}
dependencies {
    implementation("org.json:json:20230227")
}
application {
    mainClass.set("ClientKt")
}
