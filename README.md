# FixPose 🏋️ — On-Device AI Pose Detection Fitness Coach & Rep Counter

> On-device mobile AI vision coach: skeletal joint tracking, automatic rep counting, real-time voice posture corrections. **100% on-device — zero video frames to cloud.**

## Features
- 🎯 **Real-time pose detection** (Google ML Kit, on-device, 25+ FPS target)
- 🔢 **Automatic rep counting** — state machines with full range of motion (squats, pushups, jumping jacks)
- 🔊 **Voice coach** — live rep counts + form corrections ("Keep your chest up!", "Go deeper!")
- 🟢🔴 **Live skeletal overlay** — green = good form, red = warning + gender-matched posture avatar
- 📅 **AI weekly training plan** (editable) with scheduled reminders
- 🔥 **Strike engine** — streaks, consistency badges
- 📊 **Workout analytics** — Wellbeing-style reports, cadence, form accuracy %
- 🤖 **VEDA** — AI assistant with your full training context
- 🍎 **Nutrition** — calorie target + manual logging
- 🔐 **Full auth** — signup, OTP, password reset, offline-first sync

## Tech
Flutter · Riverpod · GoRouter · Drift · Supabase (Auth/Postgres/Storage) · ML Kit Pose Detection · GROQ (VEDA chat)

## Docs
| Doc | Purpose |
|---|---|
| [docs/PLANNING.md](docs/PLANNING.md) | Full architecture & phase plan (source of truth) |
| [docs/PROGRESS.md](docs/PROGRESS.md) | Phase-by-phase progress log |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Setup, Supabase/services, build |
| [docs/DEFENSE_QA.md](docs/DEFENSE_QA.md) | Anticipated Q&A |

## Getting started
```bash
flutter pub get
flutter run
```

### Demo APK (Windows)
```powershell
# One-time env (JDK 17 + Android SDK installed — see docs/DEPLOYMENT.md)
$env:JAVA_HOME = (Get-ChildItem 'C:\dev' -Directory -Filter 'jdk-17*').FullName
$env:Path += ";C:\dev\flutter\bin;$env:JAVA_HOME\bin"
flutter build apk --release
# → build\app\outputs\flutter-apk\app-release.apk
```

---
BBIT Hackathon 2026 — APP-10 · Confidential
