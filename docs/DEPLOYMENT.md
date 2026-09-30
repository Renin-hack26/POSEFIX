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
CI: tag push (`v*`) → GitHub Actions builds APK automatically.

## Secrets checklist (NEVER in repo)
- [ ] Gmail App Password
- [ ] GROQ API key
- [ ] Supabase Project URL + anon key (local config / GitHub Secrets)
- [ ] Upload keystore (`*.jks`)
