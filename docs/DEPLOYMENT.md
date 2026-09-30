# FixPose — Deployment Guide

> Status: skeleton (filled during P1/P8). Structure from spec; swap to official template if provided (PLANNING.md §10.1).

## Requirements
- Flutter SDK (stable 3.47.5 used in development)
- Android SDK (minSdk 24 / Android 7+), JDK 17
- A Firebase project (free Spark tier)

## Firebase setup (P1)
1. Create project at console.firebase.google.com (Spark/free plan)
2. Enable **Authentication → Email/Password**
3. Create **Cloud Firestore** (offline persistence enabled in app)
4. Download `google-services.json` → `android/app/` (git-ignored)
5. **OTP email (Gmail SMTP):**
   - Create Gmail **App Password** (Google Account → Security → 2-Step Verification → App passwords)
   - Install Firebase extension **"Trigger Email"** → configure SMTP with the App Password
   - ⚠️ **Sending limits:** ~500 emails/day (normal accounts), ~100/day (newer accounts) — Gmail-only decision (PLANNING.md §5.1)
   - Spam-folder safety: multipart plain+HTML, No-Reply sender, SPF-aligned (implemented in email_service)
6. **Gemini API key** (VEDA + plan generation) → GitHub Secrets / Firebase params — **never commit**

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
- [ ] Gemini API key
- [ ] `google-services.json`
- [ ] Upload keystore (`*.jks`)
