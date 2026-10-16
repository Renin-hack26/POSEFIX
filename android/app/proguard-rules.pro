# FixPose release ProGuard rules (Batch 8 prep).
#
# The Flutter engine references Play Core split-install (deferred
# components) which is not a dependency — we ship no deferred components,
# so silence R8 about those classes instead of bundling Play Core.
-dontwarn com.google.android.play.core.**

# ML Kit pose detection is the single vision backend. Its AAR ships
# consumer rules, but pin them anyway so an R8/AGP upgrade can never
# silently strip the detector that the whole session pipeline depends on.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_pose.** { *; }
