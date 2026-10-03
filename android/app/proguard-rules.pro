# FixPose release ProGuard rules (Batch 8 prep).
#
# The Flutter engine references Play Core split-install (deferred
# components) which is not a dependency — we ship no deferred components,
# so silence R8 about those classes instead of bundling Play Core.
-dontwarn com.google.android.play.core.**
