# R8 keep rules for release builds. The Flutter Gradle plugin adds this file
# to every release build type automatically (next to its own rules).

# Razorpay Standard Checkout (razorpay_flutter -> com.razorpay:checkout).
# From Razorpay's Android integration docs: checkout runs in a WebView with a
# JavaScript bridge and calls back through onPayment* methods, all looked up
# by name, so R8 must not rename or remove them. Razorpay's
# "-optimizations !method/inlining/*" line is left out: R8 ignores
# -optimizations.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-keepclasseswithmembers class * {
    public void onPayment*(...);
}
