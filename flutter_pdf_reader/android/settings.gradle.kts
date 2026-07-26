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
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

include(":app")
