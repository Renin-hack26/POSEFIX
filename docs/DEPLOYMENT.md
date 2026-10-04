# FixPose — Deployment Guide

> Status: skeleton (filled during P1/P8). Structure from spec; swap to official template if provided (PLANNING.md §10.1).

## Requirements
- Flutter SDK (stable 3.47.5 used in development, at `C:\dev\flutter`)
- Android SDK: `C:\Android\Sdk` (cmdline-tools, platform-35, build-tools 35.0.0, platform-tools) — installed 2026-09-30, licenses accepted, `flutter config --android-sdk` set
- JDK 17: `C:\dev\jdk-17*` (Temurin) — `JAVA_HOME` set at user level
- A Supabase project (free tier)

## Supabase + services setup (P1)
1. Create project at supabase.com (free tier) → copy **Project URL + anon key** (git-ignored local config)
2. Enable **Authentication → Email/Password** (and disable open signups if desired)
3. Create Postgres tables + Storage bucket per §7 (sync mirror of local Drift data)
4. **OTP email (Gmail SMTP):**
   - Create Gmail **App Password** (Google Account → Security → 2-Step Verification → App passwords)
   - Deploy the **Supabase Edge Function** (`send-otp`) that sends the branded mail via SMTP with the App Password — secret lives in Supabase, **never in the app**
   - ⚠️ **Sending limits:** ~500 emails/day (normal accounts), ~100/day (newer accounts) — Gmail-only decision (PLANNING.md §5.1)
   - Spam-folder safety: multipart plain+HTML, No-Reply sender, SPF-aligned (implemented in email_service)
5. **GROQ API key** (VEDA chat + plan generation) → GitHub Secrets / secure config — **never commit**

## Backend apply (Supabase project — NOT from CI)
6. **Account schema** (idempotent — safe to re-run): `tools/sync_schema.ps1`
   applies `supabase/schema_account_sync.sql` via the Management API
   (needs `SUPABASE_ACCESS_TOKEN` + `SUPABASE_URL` in the environment).
   This creates the `public.profiles` account directory consumed by the
   `check-user` edge action.
7. **Edge function**: `supabase functions deploy send-otp` (Supabase CLI,
   linked project). Redeploy after any change under
   `supabase/functions/send-otp/` — the app cannot function without the
   matching server actions (`check-user` reads `profiles` with a GoTrue
   fallback, so either deploy order is safe).

## Asset pipeline (FFmpeg, before bundling)
```
ffmpeg -i input.mp4 -vf "scale=-2:720" -c:v libx264 -crf 28 -an -movflags +faststart assets/videos/<exercise>.mp4
```
Budget: **≤ 3 MB per video** (CI enforces).

## Offline TTS voices
First launch checks for an offline-capable system voice; prompts one-time (free) voice-pack download if missing. Status shown in Settings → Coach voice setup.

## Build APK
```
flutter build apk --release
```
Artifact: `build/app/outputs/flutter-apk/app-release.apk`
Deliverable: copy → `releases/v<version>/FixPose-v<version>-<buildtype>.apk` (naming + size budget in `releases/README.md`)
CI: tag push (`v*`) → GitHub Actions builds APK automatically.

### R8 / ProGuard (release crash fix, applied 2026-10-01)
The Flutter Gradle plugin force-enables `isMinifyEnabled` + `isShrinkResources` for release builds
(debug builds are unminified — debug ✅ / release ❌ crash). With AGP 9.x **R8 fullMode**, plugins
without consumer rules lose reflection/JNI wiring at runtime. Fix in place (auto-included by the
plugin — no `build.gradle` edit needed):
- `android/app/proguard-rules.pro` — keeps for `io.flutter.embedding.**`, `MainActivity`,
  `GeneratedPluginRegistrant`, `com.google.mlkit.**`, `com.google.android.gms.**`, `androidx.camera.**`,
  `io.flutter.plugins.camerax.**`, GSON TypeAdapter/TypeToken/`@SerializedName` (flutter_local_notifications
  vendor requirement), `com.github.dart_lang.jni.**` (drift/sqlite), `androidx.security.crypto` +
  `com.it_nomads.fluttersecurestorage`, `app.cash.sqldelight`; plus `-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod`
- `android/app/src/main/res/raw/keep.xml` — `tools:keep` for `@drawable/*`, `@mipmap/*`, `@raw/*`

If a future release still crashes on startup, bisect with `-Pshrink=false` (disables resource shrink)
or set `android.enableR8.fullMode=false` in `gradle.properties`, then narrow the missing keep from the
stack trace. Verify a release build with `apksigner verify` + a cold-start smoke test on-device.

## Secrets checklist (NEVER in repo)
- [ ] Gmail App Password
- [ ] GROQ API key
- [ ] Supabase Project URL + anon key (local config / GitHub Secrets)
- [ ] Upload keystore (`*.jks`)
