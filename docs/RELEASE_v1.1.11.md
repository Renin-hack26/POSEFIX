# FixPose v1.1.11 — Release Notes & Demo Guide

**Build:** `releases/v1.1.11/FixPose-v1.1.11-debug.apk` (238.5 MB)
**Commit:** `a1590b2` | **Version:** 1.1.11+12
**Min SDK:** 24 (Android 7.0) | **Target:** Android 14
**Date:** 2026-10-01

---

## ✅ What Ships in This Build

### P4 — Home (Strike, Greeting, Graph, Slots)
- **Streak counter** — consecutive workout days with animated fire icon
- **Personalized greeting** — time-of-day + name from profile
- **Weekly activity graph** — 7-day bar chart (workout minutes)
- **Plan slots preview** — next 3 scheduled sessions with "Start" buttons

### P5 — Plan (AI Schedule, Library, Meals, History)
- **AI-generated weekly plan** — one-tap from Plan tab
- **Smart exercise library** — searchable, filterable catalog (24 exercises)
- **Meals today** — kcal progress bar + per-meal-type tiles (breakfast/lunch/dinner/snack)
- **History** — expandable session list with form score, duration, reps

### P6 — VEDA + Nutrition + Export
- **Meal logging** — search foods, add custom, per-meal-type (B/L/D/S)
- **Calorie target editor** — persistent daily goal (Settings → Meal screen)
- **AskVEDA kcal** — "How many calories in 2 eggs + toast?" → structured answer
- **PDF progress report** — weekly summary with charts, exportable via share sheet

### P7 — Notifications + Settings
- **Daily workout reminder** — exact alarm (AlarmManager), timezone-aware, survives reboot/force-stop
- **Hourly self-heal** — workmanager task re-arms lost schedules
- **Settings toggles** — reminders on/off, time picker, coach voice mute, export, sign-out

---

## ✅ WS9 — Count Consistency & Anti-Fake Fixes

| Issue | Fix |
|-------|-----|
| **Squat lockout too strict** (160° → missed reps) | Soft lockout lowered to **156°**; hysteresis holds once committed |
| **Push-up lockout too strict** (155° → missed reps) | Lowered to **153°** with same hysteresis |
| **Depth wobble at 90° steals ROM credit** | State-order reorder: `bottom` before `ascending` — wobble keeps evidence |
| **Hammer curl double-counts** (left+right sum) | Changed to **`max(left, right)`** — 1 curl = 1 count |
| **Phantom "not counted" on session start** | First FSM commit never rejects (`committedBefore != 'unknown'` guard) |
| **Fake workout (video) counted** | Analyzer pauses counting on `videoPlayback` / `multiPerson` / `occluded` |
| **Silent rejections** | Every lock-reason transition **speaks** (3s cooldown): "Too fast — rep not counted" / "Not counted — go through your full range" |

---

## 🎯 Demo Script (5 min)

1. **Install APK** → Grant camera + notification permissions
2. **Home** — See streak, graph, next session slot
3. **Plan** — Tap "Generate AI Plan" → see week, meals card, library
4. **Meal screen** (FAB or Plan → Log meal) — Set kcal target (e.g., 2200), log breakfast
5. **Plan refresh** — Meals card now shows progress bar + breakfast tile
5. **VEDA** — Ask "Calories in chicken breast?" → structured reply
5. **Workout** — Start a squat session → count reps, see form score, hear cues
5. **Fake test** — Point camera at phone playing exercise video → "Video detected" banner + voice, counting pauses
5. **Settings** — Toggle reminders, set time, mute coach, export JSON

---

## ❌ Deferred to v1.1.12

| Item | Reason |
|------|--------|
| WS2 HUD overhaul (rounds/rest/popups/calibration) | Partial impl aborted mid-flight; needs clean redo |
| Speech arbiter (no overlap, slower rate, proper pacing) | Designed, not yet integrated |
| MediaPipe/BlazePose 3D migration | Plugin API is CameraX-native (event stream) — full screen rewrite needed |

---

## 🔧 Technical Stack

| Layer | Tech |
|-------|------|
| UI | Flutter 3.24, Material 3, Riverpod, GoRouter |
| Pose | Google ML Kit (BlazePose Lite, 33 landmarks) |
| DB | Drift (SQLite) + Hive (flags) |
| Notifications | flutter_local_notifications + workmanager + flutter_timezone |
| Audio | flutter_tts (rate 0.45) + custom SFX (SoundPool) |
| Export | pdf + share_plus |
| AI | GROQ (VEDA chat, calorie estimation) |

---

## 📋 Known Limitations

- **Meals on Plan tab** — Requires a calorie target set first (Meal screen → target editor). Without target, defaults to 2000 kcal.
- **Video fake detection** — Catches looped/metronome videos via rhythm CV + z-depth; continuous non-looped video of a human is motion-identical to live (fundamental ML limitation).
- **Skeleton overlay** — ML Kit landmarks; One-Euro smoothing applied per landmark.
- **iOS** — Not targeted (Android-only minSdk 24).

---

## 📦 Install & Test

```bash
adb install -r releases/v1.1.11/FixPose-v1.1.11-debug.apk
```

Or download from GitHub Actions (if CI configured) / direct transfer.

---

## 📝 Next Sprint (v1.1.12)

1. Complete WS2: rounds/rest editor, wrong-pose popup, calibration, congrats card
2. Integrate speech arbiter (SoundEngine: `speechRate=0.45`, utteranceGap=400ms, urgent interrupt)
3. MediaPipe Tasks Pose Landmarker migration (native CameraX + world landmarks + segmentation)
4. Per-rep voice counting toggle (milestone every 5 → optional every rep)