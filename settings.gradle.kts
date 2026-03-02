plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

rootProject.name = "flipt-client-sdk-issue"

include("identity-server")
include("app")
