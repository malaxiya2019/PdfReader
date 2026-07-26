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

// JVM 目标一致性由 gradle.properties 中的 kotlin.jvm.target.validation.mode=IGNORE 处理
// 不要在这里强制覆盖子项目的 JVM 配置，避免干扰插件自身的构建配置
