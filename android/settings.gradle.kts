// Fix AGP AndroidLocationsException when both ANDROID_USER_HOME and ANDROID_PREFS_ROOT exist in environment
run {
    try {
        val peClass = Class.forName("java.lang.ProcessEnvironment")
        for (fieldName in listOf("theEnvironment", "theCaseInsensitiveEnvironment")) {
            try {
                val field = peClass.getDeclaredField(fieldName)
                field.isAccessible = true
                @Suppress("UNCHECKED_CAST")
                val map = field.get(null) as? MutableMap<Any, Any>
                if (map != null) {
                    val keysToRemove = map.keys.filter { it.toString().equals("ANDROID_PREFS_ROOT", ignoreCase = true) }
                    for (k in keysToRemove) {
                        map.remove(k)
                    }
                }
            } catch (e: Exception) {}
        }
    } catch (e: Exception) {}
    try {
        System.clearProperty("ANDROID_PREFS_ROOT")
    } catch (e: Exception) {}
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
