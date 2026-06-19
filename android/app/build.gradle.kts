import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.projectDir.resolve("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val isRackConsoleBuildTask = gradle.startParameter.taskNames.any {
    it.contains("rackconsole", ignoreCase = true)
}

if (!isRackConsoleBuildTask) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "my.dcstack.smartrack"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "my.dcstack.smartrack"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appName"] = "DCS Smart Rack"
    }

    flavorDimensions += "app"

    productFlavors {
        create("standard") {
            dimension = "app"
            applicationId = "my.dcstack.smartrack"
            manifestPlaceholders["appName"] = "DCS Smart Rack"
        }

        create("rackconsole") {
            dimension = "app"
            applicationId = "my.dcstack.smartrack.console"
            versionNameSuffix = "-console"
            manifestPlaceholders["appName"] = "DCS Rack Console"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
