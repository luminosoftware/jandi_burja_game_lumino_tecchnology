import java.io.FileInputStream
import java.util.Properties


plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 1. Read the key.properties file from the root android folder
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
require(keystorePropertiesFile.exists()) {
    "Missing android/key.properties. Configure the upload keystore before a release build."
}
keystoreProperties.load(FileInputStream(keystorePropertiesFile))

fun requiredSigningProperty(name: String): String =
    requireNotNull(keystoreProperties.getProperty(name)) {
        "Missing '$name' in android/key.properties."
    }

android {
    namespace = "com.jandaburja.game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent identifier: Google Play forbids changing applicationId after
        // the first upload. Chosen once, deliberately.
        applicationId = "com.jandaburja.game"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 2. Set up the secure release signing configuration
    signingConfigs {
        create("release") {
            val keystoreFile = rootProject.file(requiredSigningProperty("storeFile"))
            require(keystoreFile.exists()) {
                "Upload keystore not found at ${keystoreFile.path}. Check storeFile in android/key.properties."
            }
            storeFile = keystoreFile
            storePassword = requiredSigningProperty("storePassword")
            keyAlias = requiredSigningProperty("keyAlias")
            keyPassword = requiredSigningProperty("keyPassword")
        }
    }






    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
