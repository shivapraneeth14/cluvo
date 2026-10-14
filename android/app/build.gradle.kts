import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val keystoreFile = if (keystorePropertiesFile.exists()) {
    val path = keystoreProperties.getProperty("storeFile") ?: ""
    file(path).takeIf { it.exists() }
} else null

android {
    namespace = "com.cluvo.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.cluvo.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreFile != null) {
                storeFile = keystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Refuse to build a release artifact when no release keystore is configured.
// Previously this silently fell back to the debug signing key, which produces
// a store-rejected / impersonatable build. Debug builds are unaffected because
// they do not use the release signing config.
tasks.matching {
    it.name == "assembleRelease" || it.name == "bundleRelease" || it.name == "packageRelease"
}.configureEach {
    doFirst {
        if (keystoreFile == null) {
            throw GradleException(
                "Release signing is not configured. Create apps/mobile/android/key.properties " +
                    "with storeFile/storePassword/keyAlias/keyPassword and place the keystore. " +
                    "Refusing to produce a release build signed with the debug key."
            )
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
