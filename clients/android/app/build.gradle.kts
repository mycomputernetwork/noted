// Registered with auth as this client's redirect. AppAuth's manifest reads the placeholder.
val authRedirectScheme = "com.prabhanshugupta.noted"

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ksp)
}

android {
    namespace = "app.noted"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "app.noted"
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        buildConfigField("String", "AUTH_REDIRECT_URI", "\"$authRedirectScheme://oauth/callback\"")
        buildConfigField("String", "AUTH_LOGOUT_URI", "\"$authRedirectScheme://oauth/logout\"")
        manifestPlaceholders["appAuthRedirectScheme"] = authRedirectScheme
    }

    buildTypes {
        debug {
            buildConfigField("String", "BASE_URL", "\"http://localhost:3000/\"")
            buildConfigField("String", "AUTH_ISSUER", "\"http://localhost:3001\"")
            buildConfigField("String", "AUTH_CLIENT_ID", "\"noted-native-development\"")
        }
        release {
            buildConfigField("String", "BASE_URL", "\"https://noted.prabhanshugupta.com/\"")
            buildConfigField("String", "AUTH_ISSUER", "\"https://auth.prabhanshugupta.com\"")
            buildConfigField("String", "AUTH_CLIENT_ID", "\"noted-android\"")
            optimization {
                enable = false
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.retrofit)
    implementation(libs.retrofit.kotlinx.serialization)
    implementation(libs.okhttp.logging)
    implementation(libs.appauth)
    testImplementation(libs.junit)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
    debugImplementation(libs.androidx.compose.ui.tooling)
}