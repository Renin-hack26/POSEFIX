# FixPose — Complete Application Plan (FINAL DRAFT)

> **App Name:** FixPose
> **Type:** On-Device AI Pose Detection Fitness Coach & Rep Counter (full product app)
> **Origin:** BBIT Hackathon 2026 — APP-10 spec used as the core workout engine
> **Status:** Final draft — all 30 gaps closed & confirmed by user. On approval: copy to `POSEFIX/docs/PLANNING.md` and start Phase P0.
> **Hard Constraint:** Zero spending — free tiers, open-source, on-device only
> **Platform:** Android only (minSdk 24 / Android 7+)

---

## 0. REQUIREMENT REGISTER (source of truth)

### 0.1 Original Hackathon Spec (FR-1..FR-6 + NFRs)
| Tag | Requirement (preserved) |
|---|---|
| FR-1 | Front/back mobile camera stream, 30 FPS, on-device MediaPipe/TFLite-class pose detection → **implemented with Google ML Kit (on-device)** |
| FR-2 | Squats, Pushups, Jumping Jacks; Hip-Knee-Ankle biomechanical angle tracking |
| FR-3 | State-machine rep counting, full range of motion only (e.g., squat knee flexion < 90°) |
| FR-4 | Real-time TTS posture cues: "Keep your chest up!", "Go deeper!" |
| FR-5 | Colored skeletal overlay: green joints = good, red joints = warning |
| FR-6 | Post-workout summary: total reps, average cadence, form accuracy % |
| NFR | 100% on-device processing, zero video frames to cloud, 25+ FPS on mid-range Android |
| Docs | README.md, docs/PLANNING.md, docs/PROGRESS.md, docs/DEPLOYMENT.md, docs/DEFENSE_QA.md |

### 0.2 User-Added Product Requirements (all confirmed)
Auth (signup/login/OTP/forgot/reset), 4-tab navigation (HOME/WORKOUT/PLAN/SETTINGS), Home dashboard (greeting+analytics+strike+start-session+suggestions+tips+graphs+VEDA/report slots), full workout flow (video→camera→reports), Plan tab (AI weekly schedule + meals + library + progress + history), Settings (complete + sign out), VEDA AI, plan-driven notifications, first-launch permissions, offline-first local+cloud storage, minimal nutrition, export/share, badges.

---

## 1. TECH STACK (FINAL — no open decisions)

| Layer | Choice | Notes |
|---|---|---|
| Framework | Flutter (Dart 3.x) | Android only target |
| State management | Riverpod | compile-safe, testable |
| Navigation | GoRouter | tab shell + auth redirects + deep links |
| Models | Plain Dart entities + hand-written JSON mappers | immutable classes + `copyWith`; **freezed/json_serializable dropped** (build-time codegen removed — documented deviation, see PROGRESS) |
| Local DB | Drift (SQLite) | relational queries for history/graphs, migrations |
| KV cache | Hive | UI prefs, seen-flags, drafts |
| Auth | **Supabase Auth** (`supabase_flutter`) | email/password + OTP verification; user provides project URL + anon key |
| Cloud DB | **Supabase Postgres + Storage** | sync layer only; local-first writes (Drift primary) |
| OTP email | Gmail SMTP (**App Password** provided by user) sent via **Supabase Edge Function** (secret stays server-side, never in app) | **Gmail only, simple**; daily limits (~100–500/day) documented in DEPLOYMENT.md |
| Pose detection | **Google ML Kit Pose Detection** (on-device) | free, well-tested, accurate; Accurate mode → Balanced fallback if FPS < 25 |
| TTS | flutter_tts (system on-device voices) | offline; **first-launch check prompts one-time voice-pack download if no offline voice**; status in Settings |
| AI (plan gen + VEDA) | Hybrid: local rules/retrieval offline + **GROQ** online (VEDA chat) | never blocks core features; key provided by user |
| Instruction videos | video_player (local assets) | bundled, zero network |
| Video compression | FFmpeg (PC, build-time) | see §8 |
| Animations | Lottie / Rive | auth background loop, **posture avatars (user-provided rive/lottie json)**, micro-interactions |
| Charts | fl_chart | dashboard graphs, Wellbeing-style drill-downs |
| Notifications | flutter_local_notifications + timezone | **FCM removed**; **workmanager removed** (not needed) |
| Permissions | permission_handler | camera, notifications, storage at first launch |
| Export | pdf + csv + share_plus | reports PDF/CSV + share |
| Secure storage | flutter_secure_storage | tokens/session secrets |
| DI | get_it + riverpod | clean wiring |
| Testing | flutter_test + mocktail + integration_test | see §11 |
| CI/CD | GitHub Actions (+ Fastlane/codemagic free when needed) | analyze+test on push; APK on tag |

---

## 2. ARCHITECTURE

**Clean Architecture + feature-first.** Business logic never in UI; all decisions via usecases/engines.

```
lib/
├── main.dart                     # Firebase/Drift/Hive init, DI, runApp
├── core/
│   ├── constants/                # form_rules.dart (thresholds, overridable), app config, badge tiers
│   ├── theme/                    # colors, typography, light/dark
│   ├── errors/                   # Failure, AppException, mappers
│   ├── utils/                    # extensions, formatters, validators (DOB future-block etc.)
│   ├── permissions/              # first-launch permission flow + rationale screens
│   ├── notification/             # scheduler service, channels, quiet hours
│   ├── storage/                  # Drift DB, Hive boxes, SYNC_ENGINE
│   └── di/                       # providers/injections
├── engines/
│   ├── vision_engine/            # FixPose_VISION_ENGINE (§4.1)
│   ├── brain_engine/             # FixPose_BRAIN_ENGINE (§4.2)
│   ├── pose_analyzer/            # angles, form rules, rep state machines
│   ├── strike_engine/            # STREAK/strike logic
│   ├── tts_engine/               # voice queue, cooldowns, rep-count voice, voice-setup check
│   └── notification_engine/      # plan-driven reminders
├── data/
│   ├── models/                   # DTOs + hand-written mappers (§7; no codegen)
│   ├── datasources/local/        # Drift DAOs, Hive
│   ├── datasources/remote/       # Supabase, GROQ, Gmail-email service
│   └── repositories/             # offline-first implementations
├── domain/
│   ├── entities/                 # pure entities
│   ├── repositories/             # abstract contracts
│   └── usecases/                 # SignUp, VerifyOtp, GeneratePlan, StartSession, AskVeda...
├── presentation/
│   ├── splash/
│   ├── auth/                     # signin, signup, otp, forgot, reset-password
│   ├── home/                     # greeting, analytics, strike badge, start/resume slot, suggestions, tips, graph, badges grid, VEDA/report slots
│   ├── workout/                  # picker, instruction video, transition, vision HUD, rest, summary
│   ├── plan/                     # weekly schedule, session editor, library slots, meals, progress, history
│   ├── settings/                 # profile, units, theme, notifications, privacy, export, account, sign out, voice status
│   ├── veda/                     # chat
│   ├── reports/                  # post-session + Wellbeing-style drill-downs
│   ├── shared/                   # curved cards, buttons, inputs, avatars, empty/error states
│   └── navigation/               # GoRouter, adaptive 4-tab shell
├── reserved/                     # ⚠ RESERVED PAGES (§10.2) — future in-tab pages, one route + one slot each
└── assets/
    ├── videos/                   # compressed per-exercise instruction videos
    ├── animations/               # lottie/rive: auth bg, UI motion
    ├── avatars/                  # gendered posture rive/lottie (user-provided)
    ├── images/                   # icons, thumbnails, app icon (watermark)
    └── tips/                     # bundled tips data (i18n-ready)
```

### 2.1 Code Hygiene Rules (agent MUST follow continuously)
1. Delete unused imports/files/comments — never leave dead code or commented-out blocks
2. `flutter analyze` = 0 issues at every phase gate; `dart fix --apply` before commits
3. Naming: `*_engine.dart`, `*_usecase.dart`, `*_screen.dart`, `*_widget.dart`, `*_repository.dart`
4. All strings centralized (i18n-ready); all thresholds only in `core/constants/form_rules.dart`
5. One file = one responsibility; split > ~300 lines
6. Shared widgets only in `presentation/shared/`; feature widgets stay in feature folders
7. Update `docs/PROGRESS.md` at every phase gate; re-sync §10 Open Items + Reserved Pages at every phase gate (stale items flagged)

---

## 3. NAVIGATION MAP

```
Splash (animated FixPose logo)
 └─► First-Launch Permissions (camera, notifications, storage — rationale screens)  [first install only]
      └─► [Not logged in] Auth flow:
      │     SignIn ──(no account error: "User doesn't exist")──► SignUp
      │     SignUp → OTP → Account created → Onboarding: AI plan generated (§5.4) → HOME (auto-login)
      │     SignIn → "Forgot Password?" → email check (nonexistent → "User doesn't exist") → OTP → Set New Password → auto-login → HOME
      └─► [Logged in] Shell (4 tabs):
            HOME │ WORKOUT │ PLAN │ SETTINGS
            + push routes: vision screen, rest timer, session summary, report detail,
              exercise detail, session editor, VEDA chat, profile, export, delete-account
```

---

## 4. ENGINE ARCHITECTURE (FixPose core)

```
Camera ──▶ FixPose_VISION_ENGINE ──▶ FixPose_BRAIN_ENGINE ──▶ TTS_ENGINE / UI / Drift / STRIKE / NOTIFICATION
              ▲ (lock/relock/FPS)     ▲ (rules, plan, profile) ◀─ commands ─┘
```

### 4.1 FixPose_VISION_ENGINE — "the eyes"
- Camera controller: front/back switchable, target 30 FPS, resolution tuned for ≥25 FPS mid-range
- ML Kit Pose Detection: **Accurate** mode default; auto-downgrade to **Balanced** + overlay simplification if FPS < 25 (performance fallback ladder documented)
- **Person lock (main-person classification):** at session start, lock onto primary subject (largest/most-centered skeleton; manual tap re-select available). Others in frame ignored. Re-lock automatic if lost > N seconds, else prompt
- **Robustness (real-world):**
  - Partial visibility (e.g., pushup — legs out of frame): track visible landmarks only; require minimum landmark set per exercise before state transitions
  - Bad camera placement → framing guide (§5.3)
  - Multiple persons → person-lock filter
  - Landmark jitter → EMA smoothing (α ≈ 0.3, configurable)
- **Never transmits frames** — hard NFR guarantee (zero cloud video)
- Output: smoothed landmarks + confidences + visibility flags + FPS → BRAIN_ENGINE

### 4.2 FixPose_BRAIN_ENGINE — "the brain"
- Consumes: pose frames + form rules + today's plan + user profile
- **pose_analyzer:** Hip-Knee-Ankle angles (FR-2); elbow/spine for pushups; per-exercise **rep state machines** (UP→DOWN→UP, full-ROM enforced: squat knee flexion < 90°, pushup elbow < 90°, jumping-jack arm/leg open-close — researched defaults in `form_rules.dart`, **user may override later**)
- Form classification per joint → drives green/red overlay (FR-5), avatar shading, form-accuracy %
- Decision loop: rep counted → UI counter + TTS count; form error → correction cue ("what's wrong → how to fix → what to do", incl. spec cues) → TTS queue; round complete → rest timer; all rounds done → session summary
- Controls: vision (pause/resume/relock), TTS, strike engine, storage (live session persistence), notification engine (post-session badge updates)
- Emits session metrics: reps, rounds, per-rep times, round times, rest durations, cadence, form accuracy %, duration

### 4.3 Supporting engines
| Engine | Responsibility |
|---|---|
| **TTS_ENGINE** | Ordered voice queue with **low latency — first cue spoken < 0.5 s after detection (rep counts, framing warnings, form errors speak immediately; only same-cue repeats rate-limited, default 2 s)**, live rep counting voice, audio-focus **ducking** of background music, offline voice-pack readiness check (prompt download if missing; status in Settings) |
| **STRIKE_ENGINE** | Continuous-day strike: day-rollover logic, timezone-aware gap detection, strike + badge tier computation (3/7/14/30/100 days) |
| **NOTIFICATION_ENGINE** | Reads plan session start times → schedules local reminders; re-schedules on any plan edit; quiet hours 22:00–07:00 default; respect settings toggles |
| **SYNC_ENGINE** | Local-first: all writes → Drift → Firestore sync when online; conflict policy last-writer-wins per record; sessions append-only |

---

## 5. SCREEN SPECIFICATIONS

### 5.1 AUTH (first open → logged in)
- **Background:** Lottie/Rive animated loop (not raw video), ≤2 MB, battery-friendly
- **Sign Up fields:** First name* · Middle name · Last name · **DOB*** (date picker; **future dates blocked**; age ≥13 rule) · **Gender*** (Male / Female / Prefer-not-to-say — unspecified → **male avatar** default) · Weight (kg) · Height (cm) · **Email*** (format + uniqueness) · **Password\* + Confirm Password\*** (strength rules + cross-validation)
- **Sign In:** email + password; explicit **"User doesn't exist"** for unregistered email; **Forgot Password** link
- **OTP page (signup + forgot):** 6 boxes, 60 s resend timer, **one-tap copy code**, prominent design
  - **Email design (required by user):** app branding + logo header (app icon = **watermark**, icon provided later), addressed to user's name, purpose line (why you received this), code large/monospace, **copy-code hint**, "Do not reply to this email" footer, No-Reply sender, multipart plain+HTML (spam-folder-safe), SPF-aligned sending
  - Delivery: Firebase identity + Trigger Email extension → Gmail SMTP App Password (limits documented in DEPLOYMENT.md)
- **Set New Password page** (after forgot OTP) → **auto-login → redirect HOME**
- Session persistence via flutter_secure_storage; **Sign out** available in Settings

### 5.2 HOME TAB (top → bottom)
| Slot | Specification |
|---|---|
| Header row | App logo (left) + **Consistency badge in curved-square frame** beside logo (top-left): strike count from STRIKE_ENGINE; tap → **badges grid** (3/7/14/30/100-day tiers + form-mastery), tap badge → detail sheet |
| Greeting banner | Time-based + emotion via **rules (time of day + strike + last-workout gap)**: e.g. "Good evening, {name}! 🔥 5-day streak" / "Welcome back — it's been 3 days" |
| Performance line | Gap since last workout + last session result + weekly total time + current strike |
| **Start Today's Session** | Prominent quick-action → jumps into today's plan session. **State machine: `None→Start`, `Active→(in progress)`, `Paused→Resume (3/4 rounds done)`**, `Completed→"Session Completed ✓"+ next-session info` (auto-updates after completion). Abandon available only inside session screen |
| Suggestions | Workout suggestions from last workouts — **Hybrid**: static rule defaults (recently neglected muscle/exercise → suggest) + VEDA personalization when online |
| Rotating tips | Carousel, **≥6 s dwell, pause on touch**, Hybrid source (bundled tips → AI when online) |
| Dashboard graph | **Time spent working out** fed by stored session times (fl_chart). **Tap any day/point → full Wellbeing-style report** (duration, reps, form %, rounds, per-exercise breakdown) |
| Extended analytics | Volume (total reps/week), best form %, exercise frequency chart, month-over-month comparison |
| Bottom slot | **Generate progress report** (PDF/CSV/share) · **Chat with VEDA** |

### 5.3 WORKOUT TAB — full flow (FR-1..FR-6 wrapped)
```
Today's plan exercises (or free picker)
  → [First time ever per exercise] Instruction video (how to perform) → Next
  → Auto-advance sequence: rounds → rest → (transition card) → next exercise → … → FINAL SUMMARY
  → Vision (camera) screen active during each exercise
  → Post-session report (on complete OR user end)
```
- **No plan?** → App asks user to generate one first (prompt flow to Plan/onboarding)
- Videos shown **only the first time** an exercise is ever performed; skipped afterward (transition card only)
- **Vision screen (full-screen live camera):**
  - **Framing guide (shaded region)** showing where to position body — aids detection & posture judgment. **Zone is per-exercise** (push-up → wide low horizontal zone for the full body side-on; squat/jumping-jack → tall portrait zone), and misalignment is **spoken aloud** ("step back", "move left", "raise the phone") so the camera can be corrected hands-free, without delay
  - **Top-left HUD:** rep count (large) + round (e.g., 2/4) + elapsed time
  - **Real-time posture avatar:** full-body, gym attire, **gender-matched (unspecified→male)**, Rive/Lottie **synced to detected movement phase** (pose-phase → animation trigger mapping)
  - Green/red skeletal overlay (FR-5)
  - **Live correction module (voice):** what's wrong → how to fix → what to do (+ spec cues "Keep your chest up!", "Go deeper!")
  - **Live voice rep counting** ("1… 2… 3…")
  - Metrics live: reps/round, rounds, **rest time (auto rest-timer, full-screen countdown + Skip)**, per-rep time, total round time, session duration
  - **Pause / Resume / End always visible:** pause → full state persisted locally → **resumable later** (Home slot switches to Resume); end early or after final round → **report generated** (total reps, average cadence, form accuracy %, per-round breakdown, duration, performance graph) (FR-6)
  - **One-time coach marks** on first entry (place phone, step back, body in frame → "Got it"; persisted flag)
  - **Portrait locked**, **screen wakelock** during session, **auto-pause + state save on app backgrounding**, camera flip available (front default; side/low suggested for pushups)
- Performance: ≥25 FPS target with documented fallback ladder (mode downgrade → resolution → overlay complexity)

### 5.4 PLAN TAB
| Section | Specification |
|---|---|
| Weekly schedule | **AI-generated after signup (onboarding)**; **user-editable** (day, exercise, sets/reps, **session start time**); regenerate/adjust anytime (local rules offline; GROQ when online) |
| Today's session card | Curved slot → same flow as Workout tab |
| Exercise library | **Curved square slots: thumbnail image + icon + name** → detail (video + form rules + muscles + difficulty) |
| Meal tracking | Also here: **curved square slots (thumbnail + icon + name)** per meal of the day. **Minimal scope:** daily **calorie target** + **manual entry** (search/log, totals vs target) |
| Progress tracking | Weight/height entry (**Body metrics logging**, also editable in Settings→Profile), strike history, reps volume over time, form-% trends |
| Session history | **Full list of past sessions** (date, exercise, reps, duration, form%) → tap → report |
| Plan edits | Any change → NOTIFICATION_ENGINE re-schedules reminders |

### 5.5 SETTINGS TAB
Profile (view/edit incl. weight/height) · Units (kg/lb) · Theme (light/dark/system) · Notifications (edit per-day times, master toggle, quiet hours) · **Coach voice setup status** (offline voice ready / download prompt) · Privacy (cache clearing, data visibility) · Export (PDF/CSV + share) · Delete account (confirm + local & cloud cascade) · **Sign out** (clears session → Sign In)

### 5.6 VEDA (AI assistant)
- Name: **VEDA** — holds full context: **personal details, name, plan, all reports, activity logs**
- Hybrid: fast local rules/retrieval (offline) → **GROQ** for complex (graceful offline message)
- Capabilities: explain reports, form-fix advice, modify plan (with confirmation), weekly summaries, workout/nutrition Q&A
- Entry points: Home bottom slot + dedicated chat screen with history

### 5.7 NOTIFICATIONS
- First launch: **camera + notifications + storage permissions** requested with rationale screens
- Workout reminders scheduled at plan **session start times** (local, timezone-aware, re-scheduled on plan edit)
- Post-workout streak nudges (respect toggles); quiet hours 22:00–07:00; no-spam caps in settings

---

## 6. PERMISSIONS & PLATFORM
- **First install only:** Splash → permission rationale → camera, notifications, storage/media → auth
- minSdk **24** (Android 7+); target latest; portrait lock only inside workout flow
- Android-only builds; no Apple/CICD Apple costs

---

## 7. DATA MODELS (Drift primary + Firestore mirror)

| Entity | Key fields |
|---|---|
| **UserProfile** | id, first/middle/last, dob, gender, weight, height, email, units, avatarType, createdAt |
| **WorkoutSession** | id, userId, date, exercises[], rounds[], reps, duration, avgCadence, formAccuracy%, perRepTimes[], restDurations[], status (active/paused/completed/abandoned), pausedState |
| **Exercise** | id, name, category, thumbnail, videoAsset, angleRules, thresholds, cues[], muscles, difficulty, videoSeen |
| **TrainingPlan** | id, weekStart, days[7] → sessions[]{exerciseId, sets, reps, startTime, status}, source (AI/manual), lastUpdated |
| **MealEntry** | id, date, name, calories, source (manual) |
| **MealTarget** | userId, dailyCalories |
| **StrikeState** | currentStrike, longestStrike, lastActiveDate, badges[] |
| **BodyMetric** | date, weight, height?, notes |
| **Report** | sessionId, stats, generatedAt, pdfPath? |
| **ChatMessage** | id, role, text, createdAt, contextRef |

---

## 8. VIDEO & ASSET STRATEGY
- User team provides: raw **instruction videos** per exercise, **Rive/Lottie posture avatars** (male/female), auth background animation, **app icon** (OTP watermark)
- **FFmpeg pipeline (PC, pre-bundle):** H.264, ≤720p, CRF 28, strip audio → **≤3 MB per video** → `assets/videos/`
- Play from local assets (zero network); CI size budget check
- Avatars: Rive/Lottie ≤2 MB each; pose-phase mapping API built in P3 (renderer swappable)

---

## 9. UI DESIGN WORKFLOW (team collaboration)
1. Agent produces **mandatory slot spec** per screen (widgets, states empty/loading/error, interactions) → delivered as a **design prompt checklist** for the user's designers
2. Designers return multiple **HTML/CSS candidates** per screen
3. User selects best → final HTML/CSS set delivered
4. Agent converts HTML/CSS → Flutter widgets (pixel-matched, themed) — slot spec guarantees no feature loss
5. Until then: `shared/` placeholders with agreed slot structure

**Confirmed design decisions (2026-09-30, user):**
- Navigation stays the planned **4 tabs: HOME / WORKOUT / PLAN / SETTINGS** (a 5-item reference design was rejected for nav — style reference only)
- Visual direction: **liquid glass** — cream-tinted translucent cards + subtle grid-line background in **light**; near-black green-tinted glass in **dark**
- **Accent: chartreuse green with gradient shading** (bright highlight → deep shade) for a dynamic look; text on chartreuse = near-black green, accent text on surfaces = deep chartreuse (light) / bright chartreuse (dark)
- **Themes:** follows the device by default (`prefers-color-scheme`) **and** manually switchable (Auto / Light / Dark) — maps to Flutter `ThemeMode.system` + a Settings theme picker
- **No emoji anywhere in the UI** — Material Symbols icons only
- **OTP:** the code is never displayed in-app — it goes to the email only (copy button lives in the email). In-app copy exactly: *"The code was sent to your email. Check spam if it's missing."*
- Candidate set authored by agent at **`sample/index.html` + `sample/styles.css`** — **14 screens** (splash, sign-in, sign-up, OTP, reset, home, workout library, workout details, instruction, vision, summary, plan, VEDA, settings), each rendered in **both themes** → user picks/edits → chosen direction becomes the final HTML/CSS for step 4
- Every suggestion/workout card opens its own **Workout Details** page (hero, stats, Start, exercise plan, goal) — full flow: suggestion → detail page → session → report + Home feed + Plan history (user confirmed)

---

## 10. PLAN PROCESS SECTIONS

### 10.1 Open Items — Awaiting User Input (updated at every phase gate)
| Item | Status |
|---|---|
| Pose-fixing / workout details user reserved ("later I will tell you") | ⏳ awaiting (Phase J — FSM rules already ported from Model samples; final vision rules/model still to come) |
| Exact form-rule overrides (defaults active meanwhile) | ⏳ awaiting |
| App icon asset (OTP watermark + branding) | ✅ built 2026-09-30 from the sample logo (adaptive + legacy layers) |
| Instruction videos (per exercise) | ✅ resolved 2026-10-01 — **real-person demo GIFs** sourced from the open Kaggle "Fitness Exercises with Animations" dataset (MIT-licensed host `omercotkd/exercises-gifs`, 1,324 exercises); 36 GIFs downloaded for the bundled bodyweight catalog → user review before integration; no ffmpeg needed (GIFs play natively via `Image.asset`) |
| Equipment-based gym exercises (barbell/dumbbell/cable/machine) | ⏳ planned later ("for now keep what we had; later we will plan for all in wider aspect") — dataset has 1,300+ equipment exercises with GIFs ready when scope expands |
| Rive/Lottie posture avatar files | ⏳ stale — rive/lottie removed from the stack (documented deviation); avatar slots render without them |
| Final HTML/CSS designs (via §9 workflow) | ✅ converted — screens 01–14 built from `sample/` Direction A |
| Supabase project (URL + anon key) | ✅ provided 2026-09-30 — URL + publishable key (app) + secret key (**server-only, never in app**) in `secrets/local.env` |
| GROQ API key (VEDA chat) | ✅ provided 2026-09-30 (`secrets/local.env`) — wired via `--dart-define` |
| Gmail App Password (OTP email) | ✅ provided 2026-09-30 (`secrets/local.env`: address + App Password) |
| Pose rules + camera/detection reference (18-exercise FSM: YAML angles, state machines, feedback + audio cues) | ✅ received 2026-09-30 — `Model samples/fitness-trainer-pose-estimation`; **ported 2026-10-01 into `exercise_catalog.dart` (all 18 FSMs)**; camera/detection requirements (person-lock multi-person handling, per-exercise framing incl. wide push-up view, spoken camera-adjustment cues, low-latency sound feedback) folded into §4.1/§4.3/§5.3 |
| Official doc templates (if provided later) | ⏳ optional |

### 10.2 Reserved Pages — slots inside the 4 tabs (user fills later)
| Tab | Reserved slot | Status |
|---|---|---|
| HOME | (none reserved yet) | — |
| WORKOUT | (none reserved yet) | — |
| PLAN | (none reserved yet) | — |
| SETTINGS | (none reserved yet) | — |
*Pattern: adding a reserved page = 1 route + 1 slot — router designed for this.*

### 10.3 Phase-gate checklist (every P0..P8 completion)
- [ ] `flutter analyze` 0 issues, dead code deleted
- [ ] `docs/PROGRESS.md` updated
- [ ] §10.1 Open Items re-synced & stale flagged
- [ ] §10.2 Reserved Pages re-synced

---

## 11. PHASED DELIVERY ROADMAP

| Phase | Deliverable | Contents |
|---|---|---|
| **P0 Foundation** | Scaffold | Project init, folder structure, themes, GoRouter shell, Drift schema (all §7), Firebase wiring, DI, permission flow, CI (analyze+test), **delete all template cruft** |
| **P1 Auth** | Working auth | All auth screens, branded OTP (Gmail), forgot/reset, "User doesn't exist", auto-redirect, sign out, session persistence |
| **P2 Pose Core** | FR-1..FR-6 engine | VISION_ENGINE + BRAIN_ENGINE + pose_analyzer (state machines, thresholds), green/red overlay, rep counter, TTS cues + rep voice, FPS fallback ladder, person-lock |
| **P3 Workout Flow** | Full workout tab | Instruction video → auto-advance chain → vision HUD (framing, avatar phase-sync, top-left counters) → rest timer → pause/resume/end → post-session report; coach marks; portrait/wakelock/auto-pause |
| **P4 Home** | Dashboard | STRIKE_ENGINE + badge grid, greeting rules, start/resume slot state machine, suggestions+tips (hybrid), graph + drill-down reports, analytics, report/VEDA slots |
| **P5 Plan** | Planning tab | AI generation (onboarding) + editing, session start times, notification re-scheduling, exercise library slots, meal slots, progress + body metrics, session history list |
| **P6 VEDA + Nutrition + Export** | Assistant & outputs | Hybrid chat with full user context, calorie target + manual logging, PDF/CSV/share |
| **P7 Notifications + Settings** | System integration | Scheduler, full settings incl. voice status, delete account cascade, privacy screen |
| **P8 Polish** | v1.0 pre-release | HTML/CSS → Flutter translation (§9), i18n/a11y pass, 25+ FPS validation on mid-range, full test suite, all 5 hackathon docs finalized |
| **P9 (Phase J) Vision model** | Final vision rules/model | User-delivered final FSM rules/model integrated + tuned for minimum latency & accuracy (all engines fine-tuned, bad-camera quality covered) — **before any release build** |
| **P10 (Phase I) Release build** | Final APK — LAST | Named APKs (`FixPose-v1.0.1-release.apk` etc.) built only AFTER Phase J; then user Q&A |

---

## 12. MANDATORY DOCUMENTATION (structured from spec; swap to official templates if provided)
- `README.md` — overview, features, screenshots, setup, build
- `docs/PLANNING.md` — this document (finalized copy)
- `docs/PROGRESS.md` — phase log, updated at every phase gate
- `docs/DEPLOYMENT.md` — Firebase setup, Gmail App Password + SMTP limits, FFmpeg asset pipeline, APK build/signing, minSdk
- `docs/DEFENSE_QA.md` — anticipated Q&A (privacy, FPS, on-device guarantee, engines, ML choices)

---

## 13. TESTING & CI
- **Unit:** pose_analyzer angles + state machines (all 3 exercises, ROM edges), STRIKE_ENGINE (timezone/rollover/gap), validators (DOB future-block, password match), usecases
- **Widget:** auth forms + OTP, workout HUD, plan slots, home slots
- **Integration:** signup→OTP→plan-gen→home; workout flow with mocked camera; pause→restart→resume→report
- **Performance:** FPS harness (DevTools overlay) against mid-range profile at P2 & P8
- **CI (GitHub Actions):** push → analyze + test → (tag) → APK artifact; asset size budget check

---

## 14. SECURITY & PRIVACY
- Firestore rules: user-scoped read/write, Auth required everywhere
- **Zero video frames leave device** (hard guarantee, checked in DEFENSE_QA)
- Secrets (Gmail App Password, GROQ key, Supabase credentials) in GitHub Secrets / secure config — never in repo
- flutter_secure_storage for tokens; privacy screen (hidden in app switcher)
- Delete account → local cascade + Firestore delete
- OTP email: rate-limited, expiring codes, no-reply

---

## 15. RISKS & MITIGATIONS
| Risk | Mitigation |
|---|---|
| FPS < 25 mid-range | Fallback ladder (Accurate→Balanced→resolution→overlay), profiling at P2 |
| Person-lock failure | Tap to re-select, confidence auto re-lock |
| Gmail deliverability/limits | Spam-safe multipart template; documented limits; provider kept simple per user decision |
| VEDA/GROQ offline or quota | Hybrid local-first; cache; graceful degradation |
| Avatar phase-sync complexity | Renderer interface built P3 with no-op fallback; swap in Rive when assets arrive |
| Scope creep | Phases P0–P8 enforced; new ideas → §10 Open Items, never interleaved |
| Asset bloat | FFmpeg ≤3 MB/exercise budget + CI check |
| Missing user assets (videos/avatars/icon) | P3 ships with placeholder assets; drop-in replacement when provided |

---

## 16. ACCEPTANCE CRITERIA (v1.0 done when)
1. FR-1..FR-6 all working on-device with ≥25 FPS on mid-range Android
2. Full auth cycle incl. branded OTP, forgot/reset, auto-redirect, sign out
3. Onboarding generates first AI plan; plan editable; reminders fire at session start times
4. Complete workout flow: video → camera (framing, avatar, HUD, voice corrections, counting) → pause/resume → report
5. Home: strike badge, greeting, start/resume slot auto-updating, graph drill-downs, VEDA/report slots
6. Plan: library + meals + progress + history all functional
7. VEDA answers with real user context; nutrition logging works; exports produce files
8. All settings functional incl. delete account; permissions requested at first launch
9. Offline: pose detection + local data fully functional without internet
10. `flutter analyze` clean, tests green in CI, APK builds, 5 docs complete
