pluginManagement {
    val flutterSdkPath = System.getenv("FLUTTER_ROOT") ?:
        File(settingsDir.parentFile, "bin/cache/flutter-sdk").absolutePath

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.4.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

include(":app")
