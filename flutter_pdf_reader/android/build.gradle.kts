buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.4.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val clean by tasks.registering(Delete::class) {
    delete(rootProject.layout.buildDirectory)
}

// 方式1: 在 subprojects 块中通过 configureEach 设置 JVM 目标
// 方式2: 在 gradle.properties 中设置了 kotlin.jvm.target.validation.mode=IGNORE
// 方式1生效时，Java+Kotlin 目标一致(17)，校验不会触发
// 方式1失效时，方式2确保校验不会报错
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "17"
        }
    }
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
