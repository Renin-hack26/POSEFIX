# FixPose — Progress Log

> Updated at **every phase gate** (PLANNING.md §10.3). One entry per phase/milestone.

## Phase Status

| Phase | Deliverable | Status | Date |
|---|---|---|---|
| P0 | Foundation (scaffold, structure, CI) | ✅ Complete | 2026-09-30 |
| P1 | Auth (signup/OTP/forgot/reset/sign-out) | 🟡 In progress | 2026-09-30 |
| DC | Data core (Drift DB, content, account sync, use cases) | ✅ Complete | 2026-09-30 |
| P2 | Pose Core (FR-1..FR-6 engines) | ⬜ Not started | |
| P3 | Workout Flow (video → camera → report) | ⬜ Not started | |
| P4 | Home (strike, greeting, graph, slots) | ⬜ Not started | |
| P5 | Plan (AI schedule, library, meals, history) | ⬜ Not started | |
| P6 | VEDA + Nutrition + Export | ⬜ Not started | |
| P7 | Notifications + Settings | ⬜ Not started | |
| P8 | Polish + Release (docs, APK, FPS validation) | ⬜ Not started | |

## Log

### 2026-09-30 — DC: Data core — offline DB + content + account sync + use cases 🗄️
- **Local store (Drift)**: 8 tables / 6 DAOs / schema v1; drift row classes renamed `@DataClassName('*Row')` to avoid clashing with domain entities · **freezed + json_serializable dropped → hand-written entities + JSON mappers** (documented deviation from PLANNING §1 "Models" — no build-time codegen; PLANNING updated)
- **Bundled content authored** (`assets/data/*.json`, validated): 40 exercises (core-3 with demo-clip paths), **52 unique workouts**, 100 foods, 14 tips, 7 plan templates covering all 9 level×goal combos — cross-ref, coverage, emoji and schema-key scans pass
- **Domain**: 11 entities, 8 repository interfaces, 6 use cases (Start/EndSession · GetStrikeState · GenerateWeeklyPlan · GetHomeDashboard · AskVeda), pure time-injected `StrikeEngine` (tiers 3/7/14/30/100 + form-mastery badge, ≥60 s credit rule)
- **Account sync (Supabase, zero spend)**: `SyncEngine` — 15-min sweep + sign-in trigger; uploads dirty rows (`syncedAt IS NULL`), download+merge with LWW approximation, **sign-out wipes local account tables** (privacy boundary); server schema applied live: 7 tables + triggers + RLS + grants (`supabase/schema_account_sync.sql`, idempotent)
- **VEDA**: GROQ when online + data-grounded offline fallback (never a dead-end chat)
- **Model samples received (user)** → `Model samples/fitness-trainer-pose-estimation`: 18-exercise YAML FSM reference (angles/states/counter/feedback/audio cues) = porting source for P2 rules; **camera/detection requirements folded into PLANNING**: person-lock multi-person handling (§4.1), per-exercise framing zones incl. wide push-up view + spoken camera-adjustment cues (§5.3), low-latency sound feedback < 0.5 s (§4.3)
- Encoding incident (internal): PowerShell ANSI writes had corrupted non-ASCII in ~20 files → repaired; repo-wide strict-UTF-8 + mojibake scans now **clean**; rule adopted: file writes via write/edit tools only
- Gate: `flutter analyze` = **0 issues** ✅ · `flutter test` = **all passed** ✅ · §10.1 re-synced (Model samples added, stale flagged) · §10.2 unchanged (no reserved pages) → `releases\v1.0.1\FixPose-v1.0.1-debug.apk` (278.5 MB, vCode 2)

### 2026-09-30 — P1: OTP backend LIVE + full auth wiring + animation kit 🎯
- **Supabase Edge Function `send-otp` deployed** (Deno + nodemailer → Gmail SMTP App Password — the user's Gmail flow, NOT Supabase email; secrets server-side only): actions `send`/`verify`/`check-user`/`create-user`/`reset-password`; SHA-256 `email:code` rows in `otp_codes` (RLS on, no policies), 60s resend cooldown · 10-min expiry · max 5 attempts — matches `AppConstants`
- **Required OTP test done**: `send` → `{"ok":true}` (test email accepted for **shubham93328@gmail.com**); `verify` with wrong code → `400 {"error":"invalid"}` (server-side rejection verified)
- Infra: `otp_codes` table via Management API · `GMAIL_ADDRESS`/`GMAIL_APP_PASSWORD` via `supabase secrets set` · function deploy exit 0
- Client stack (P1 placeholders → real): `SupabaseConfig` (URL + publishable key only) · `EmailService` (send action + `FunctionException`→`AppException` mapping incl. new `OtpCooldownException`) · `AuthRemoteDataSource` · `UserRepositoryImpl` (pending signup held in memory → verify → create-user → auto sign-in; forgot = check-user → exact "User doesn't exist"; reset = apply + auto-login) · 7 use cases · Riverpod DI (`app_dependencies.dart`) · `Supabase.initialize` in `main.dart` (local-only at boot → app still starts offline)
- All 5 auth screens wired to use cases: sign-up dispatches the real OTP · OTP verifies server-side (clears boxes on failure, working resend via `ResendOtp`) · forgot/reset use the reset purpose · **Settings → Sign out now ends the session** (`signOutProvider`)
- **Under-construction banners** added everywhere functionality is pending (new shared `UnderConstructionBanner`, amber pill tokens): plan · vision · instruction video · session summary · VEDA
- **Animation kit (parallel agent)**: `FadeSlideIn` entrance + `Shimmer` skeletons + `AppTransitions.fadeRise`; 5 reserved routes converted to `pageBuilder`, splash entrance motion, shimmer loading states on home/plan/workout
- Traced with pixel-measured golden renders (temp tests, deleted after use): **password-field hint Row overflowed at font-scale ≥1.3 → fixed with `Expanded` + ellipsis**; **date-picker "left white space" not reproducible in portrait/landscape/1.3× (always exactly 16px/16px centered)** — original report traces to the GridBackground fill bug fixed earlier in this pass
- Version → **1.0.1+2** (versionName 1.0.1 / versionCode 2 = upgrade-safe)
- Gate: `flutter analyze` = **0 issues** ✅ · `flutter test` = **all passed** ✅ → `FixPose-v1.0.1-debug.apk` building. Tracked non-blocking: a 40px Row overflow exists only at Android font scale 1.3 (dialog region; not seen at default scale)
- Next: on-device E2E of the auth loop + named APK delivery → then release build (R8 crash bisect: debug ✅ / release ❌)

### 2026-09-30 — UI Build: screens 06–14 + routes + app icon (UI-first order) 🧱
- Screens 06–14 converted from `sample/` (3 parallel work streams): **06 Home** (greeting, today's-session gradient banner, suggestions/tips carousels, weekly time-spent graph, analytics tiles), **07 Workout** (resume card, category chips, library), **08 Workout details**, **09 Instruction video**, **10 Vision/live-reps** (framing-guide painter, HUD chips, posture avatar, controls), **11 Session summary**, **12 Plan** (week strip, next-session card, exercise library, meals, history), **13 VEDA chat** (canned exchange, suggestion chips, composer), **14 Settings** (appearance Auto/Light/Dark wired to `themeModeProvider`, notifications, data, sign-out)
- Router: 5 reserved full-screen routes added (PLANNING §10.2): `/workout-details` · `/instruction-video` · `/vision` · `/summary` · `/veda` — every in-app navigation path is now live
- **App icon**: launcher icon built from the sample splash/sign-in logo — chartreuse `160deg` gradient tile + Material Symbols Rounded `accessibility_new` (FILL 1, wght 450) in accent ink; sources `tools/icon/*.html` (headless-Chrome render → PNG). Adaptive icon for API 26+ (background + foreground + `monochrome` themed-icon layer) + rounded-tile legacy PNGs 48–192px for API 24–25
- Gradle 9.3.1 wrapper downloaded (`-Djava.net.preferIPv4Stack=true` fixed the IPv6-first download timeout)
- Gate: `flutter analyze` = **0 issues** · `flutter test` = **all passed**
- **Demo APK BUILT ✅** — `flutter build apk --release` → `build\app\outputs\flutter-apk\app-release.apk` (118.2 MB, debug-signed, `apksigner verify` OK; package `com.fixpose.fixpose` v0.1.0, label FixPose, minSdk 24 / target 36). Three integration blockers traced to exact source lines and fixed: (1) `flutter_local_notifications 8.2.0→22.3.1` — the old release called `jcenter()` (removed in Gradle 9) at its `android/build.gradle:7`; pulled `timezone ^0.11.0` + `wakelock_plus ^1.8.0` (dbus `^0.7.8` vs `^0.8.0` conflict), (2) `permission_handler 13.0.2→12.0.3` — its android impl 14.1.0 pins `compileSdk = 37` but Android 17's platform declares `ApiLevel=37.0` (hash `android-37.0`, integer 37 unresolvable); 12.0.3 pairs with android 13.0.1 (`compileSdk 35`, installed), (3) core-library desugaring enabled in `:app` (`isCoreLibraryDesugaringEnabled` + `desugar_jdk_libs 2.1.4`, required by notifications' AAR metadata)
- Warnings tracked (not blocking): KGP notice — `flutter_tts` + `rive_native` still apply the Kotlin Gradle Plugin (future Flutter will fail → upgrade those plugins); cupertino_icons font notice (no Cupertino icons used, harmless)
- Next: animation kit (page transitions, entrance motion, shimmer skeletons) → P1 Supabase auth

### 2026-09-30 — UI Build: design system + auth cluster (UI-first order) 🧱
- **Stack swap (user decision):** Firebase dropped → **Supabase only** (auth/Postgres/storage); **GROQ** replaces Gemini for VEDA chat. Deps swapped (`supabase_flutter` in, firebase_* out), datasources renamed (`supabase_data_source`, `groq_data_source`), docs synced (PLANNING §1, DEPLOYMENT, README, DEFENSE_QA)
- Design system written: `app_theme.dart` (light + dark liquid-glass via `AppPalette` theme extension, chartreuse gradient accent), `GridBackground` (26px grid + chartreuse/blue blooms), shared widgets: GlassCard · Primary/Secondary/Link buttons · AppTextField/FieldLabel · PasswordField (strength meter) · StatusPill · SectionHeader · AppLogo · AppBackButton; real `validators`/`formatters`
- Auth screens converted from sample 01–05: splash (auto-route), sign-in, sign-up (full field set, DOB date picker, gender segments, live password strength), forgot, OTP (6-box input, 60s resend countdown, exact spec copy), reset (live rules checklist); `themeModeProvider` (default = follow device) wired into `main.dart`
- Android toolchain installed: JDK 17 (C:\dev) + Android SDK (C:\Android\Sdk — platform-35, build-tools 35.0.0, platform-tools), licenses accepted, `flutter config --android-sdk` set → **APK builds unblocked**
- Secrets stored in `secrets/local.env` (git-ignored): Gmail address + App Password, Supabase personal access token, GitHub token — pending: Supabase project URL + anon key, GROQ key
- Gate: `flutter analyze` = **0 issues**
- Next: screens 06–14 → router routes → `flutter build apk` (demo)

### 2026-09-30 — UI Design: Sample Direction A (intermission inside P1) 🎨
- User shared a dark/neon reference → confirmed: **4 tabs stay**, direction changes to **light + liquid glass**, **no emoji, Material icons only**
- Created `sample/index.html` + `sample/styles.css` — self-contained HTML/CSS gallery, **14 phone-frame screens**: splash, sign-in, sign-up, OTP, reset password, home, workout library, workout details, instruction video, vision/live-rep screen, session summary, plan, VEDA chat, settings
- Iterations applied: cream surfaces + grid-line background · OTP code removed from screen (email-only, exact copy agreed) · **chartreuse-green accent with gradient shading** · **light + dark themes** (device-auto via `prefers-color-scheme` + manual Auto/Light/Dark toggle) · workout tab + workout-details pages added
- PLANNING §9 updated with the confirmed design decisions; §10.1 open item now "awaiting user's pick + change list"
- Next: user reviews `sample/`, picks/edits → chosen HTML/CSS becomes the Flutter conversion source (§9 step 4); P1 auth logic resumes meanwhile

### 2026-09-30 — P0 COMPLETE ✅
- Flutter SDK 3.47.5 (Dart 3.13.4) installed at C:\dev\flutter, added to user PATH
- Filebase structure created: 130+ files (core/data/domain/engines/presentation/reserved)
- `flutter create` generated android/ scaffolding (minSdk to set 24 in P1); template counter test deleted
- Dependencies installed via `flutter pub add` (31 runtime + 7 dev) — see pubspec.yaml
- Real content written: form_rules.dart (thresholds), app_constants.dart, app_router/app_shell (4-tab), main.dart, CI workflow, 4 docs
- Gates: `flutter analyze` = **0 issues** · `flutter test` = **all passed** (smoke boot test)
- Docs: PLANNING.md finalized (all 30 gaps closed), PROGRESS/DEPLOYMENT/DEFENSE_QA skeletons created

### Environment notes
- Android SDK: ✅ installed 2026-09-30 — C:\Android\Sdk (platform-35, build-tools 35.0.0), JDK 17 at C:\dev, licenses accepted; `flutter config --android-sdk` set
- Supabase project: not yet created (user provides URL + anon key for P1; personal access token already in `secrets/local.env`)
- Secrets: `secrets/local.env` (git-ignored) — Gmail App Password ✓, Supabase PAT ✓, GitHub token ✓; GROQ key ⏳
