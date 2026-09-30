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
Flutter · Riverpod · GoRouter · Drift · Firebase (Auth/Firestore) · ML Kit Pose Detection · Gemini (free tier)

## Docs
| Doc | Purpose |
|---|---|
| [docs/PLANNING.md](docs/PLANNING.md) | Full architecture & phase plan (source of truth) |
| [docs/PROGRESS.md](docs/PROGRESS.md) | Phase-by-phase progress log |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Setup, Firebase, build |
| [docs/DEFENSE_QA.md](docs/DEFENSE_QA.md) | Anticipated Q&A |

## Getting started
```bash
flutter pub get
flutter run
```

---
BBIT Hackathon 2026 — APP-10 · Confidential
