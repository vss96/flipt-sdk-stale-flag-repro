plugins {
    kotlin("jvm")
    kotlin("plugin.spring")
    id("org.springframework.boot")
    id("io.spring.dependency-management")
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_24)
    }
}

java {
    sourceCompatibility = JavaVersion.VERSION_24
    targetCompatibility = JavaVersion.VERSION_24
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    // Use local build of flipt-client-java with AuthenticationProvider support
    implementation(files("libs/flipt-client-java-1.2.1.jar"))
    // Transitive dependencies of flipt-client-java
    implementation("net.java.dev.jna:jna-platform:5.16.0")
    implementation("com.fasterxml.jackson.dataformat:jackson-dataformat-xml:2.18.3")
    implementation("com.fasterxml.jackson.datatype:jackson-datatype-jdk8:2.18.3")
}
