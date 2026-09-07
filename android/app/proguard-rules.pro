# Add project specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /usr/local/Cellar/android-sdk/24.3.3/tools/proguard/proguard-android.txt
# You can edit the include path and order by changing the proguardFiles
# directive in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Add any project specific keep options here:

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Invoked via reflection, when setting js bundle.
-keepclassmembers class com.facebook.react.ReactInstanceManager {
    private final ** mBundleLoader;
}

# ReactHostImpl was rewritten from Java to Kotlin between RN 0.80.3 and
# 0.81.0, renaming its delegate field from "mReactHostDelegate" to
# "reactHostDelegate".
-keepclassmembers class com.facebook.react.runtime.ReactHostImpl {
    private final ** mReactHostDelegate;
    private final ** reactHostDelegate;
}

-keep interface com.facebook.react.runtime.ReactHostDelegate { *; }

-keep class * implements com.facebook.react.runtime.ReactHostDelegate { *; }

# The bundle loader field on ReactHostDelegate implementations (e.g. Expo's
# ExpoReactHostDelegate._jsBundleLoader) can still get stripped by R8 as
# dead code under the wildcard "implements" rule above, since it's only
# ever written via reflection. Keep it explicitly.
-keepclassmembers class * implements com.facebook.react.runtime.ReactHostDelegate {
    *** jsBundleLoader;
    *** _jsBundleLoader;
}

# Can't find referenced class org.bouncycastle.**
-dontwarn com.nimbusds.jose.**
