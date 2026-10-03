# FixPose — Consolidated TODO (v1.1.11 work batch)

> Source: user requests 2026-10-01 (post-v1.1.10). One row per item.
> Status: ⬜ not started · 🔄 in progress · ✅ done · ⏸ blocked/needs user input
> Process: background subagents per workstream; central gates (analyze + full test) + commit owned by coordinator.

## WS1 — Notifications & reminders (background-safe) ✅ (agent complete)
| # | Item | Status |
|---|---|---|
| 1.1 | AndroidManifest: `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `WAKE_LOCK` + flutter_local_notifications `ScheduledNotificationReceiver` + `ScheduledNotificationBootReceiver` (root cause: notifications never show when app closed / lost on reboot) | ✅ |
| 1.2 | Timezone bug: engine hardcodes UTC (`notification_engine.dart:29`) → use device tz via `flutter_timezone` | ✅ |
| 1.3 | Exact-alarm capability check with inexact fallback (Android 12+ doze/OEM) | ✅ |
| 1.4 | Notification tap deep link: `workout:<id>` payload → route to plan/workout (incl. cold start via `getNotificationAppLaunchDetails`) | ✅ |
| 1.5 | **Background worker** (`workmanager` periodic task): self-heal reminder scheduling from prefs while app closed; re-arm idempotently | ✅ |
| 1.6 | Unit tests for daily-occurrence/next-schedule logic + `flutter analyze` clean | ✅ (14 tests) |

## WS2 — Camera vision session: layout, rounds, pops, HUD ✅ (Batch 4: full HUD overhaul shipped)

> **Outcome 2026-10-01: PARTIAL / aborted mid-flight.** (original note kept for history; Batch 4 re-implemented the scope cleanly on the shipped screen — no rewrite, no dead files.)
| # | Item | Status |
|---|---|---|
| 2.1 | Layout per `sample/index.html` §10: HUD **top-left** (REPS/ROUND/TIME — orphaned `VisionHud` exists), posture avatar **top-right** (orphaned `PostureAvatar` exists), cue bar **fixed bottom** (no stacked scrollable column = the "scattering"), controls **bottom-center** (flip · pause · end); frame guide via orphaned `FramingGuide` | ✅ (adopted all three orphans: VisionHud cluster + avatar + guide-on-no-lock; cue bar extracted to a fixed bottom slot; controls bottom-center) |
| 2.2 | Feedback = single fixed cue slot with warn/ok color states (sample styles.css) — never stacked/scattered | ✅ (fixed slot, warn amber / ok accent, priority rest > calibration > live cue) |
| 2.3 | Rep counter: `12/13` target (from block reps), **Round 2/3**, elapsed TIME, rest-period countdown + "ready for next round"; consume `PlanSession.roundsOverride`; write `SessionExercise.roundsCompleted/repsPerRound/roundTimesSec` (model exists, always 0 today) | ✅ (`RoundTracker` pure tracker; route carries rounds/reps/rest from plan + details; round reps/target + round + 1 s TIME chips; rest countdown banner; rounds persist per save) |
| 2.4 | **Pre-session editor** (in-screen sheet): rounds & reps editable before start | ✅ (bottom sheet after resolve, before camera; duration edits hold secs; dismiss backs out) |
| 2.5 | Wrong pose: **0.8 s cross-symbol popup + buzz** (Flutter `HapticFeedback` + existing Sfx — no new dep), severity-colored cue card | ✅ (✕ flash amber/red + medium haptic on every gate-refused rep) |
| 2.6 | Round complete: **tick popup** (+ wired `SessionAudioCues.onSet/onRestStart/onRestEnd` — hooks exist, never called); all rounds: **congrats popup w/ log + Next** (`onMilestone` too) | ✅ (✓ flash + onSet; rest SFX + vocab lines at both ends; congrats Log→summary / Next→bonus + onMilestone) |
| 2.7 | Bottom bar: **Pause / Cancel / End** — Cancel = confirm + discard (`clearActive`, no credit), End = existing complete→summary, Pause = instant w/ banner | ✅ |
| 2.8 | **Loading popup before session** (await SoundEngine ready + FSM resolve + analyzer start + camera, with step labels) | ✅ (6-step checklist overlay incl. TTS warm-up) |
| 2.9 | Skip-count fix: emit `repRejectedReason` from BrainEngine when trigger commits but ROM/timing gate fails → coach bar "not counted" + haptic (never silent) | ✅ (reason already emitted; Batch 4 added the haptic + flash — voice existed via WS9.3) |
| 2.10 | Auto-calibration: run `CalibrationConfig` (enabled on 6 exercises, never read today) as pre-session ROM-learning phase; sync with workout | ✅ (5 s locked-frame ROM feed → verdict line spoken + engine reset; pure layer from Batch 2) |
| 2.11 | Voice enrichment: wire milestone cues (every 5 reps), round/rest announcements, PLANNING §5.3 | ✅ (milestone cycled every 5 via arbiter `announce`; round/last-round/rest vocab lines queued) |
| 2.12 | Auto-pause on app background (`didChangeAppLifecycleState`, PLANNING 223); elapsed timer | ✅ (observer auto-pauses; elapsed clock freezes across pauses; 1 s TIME tick) |

## WS3 — Nutrition: meal page + log page + AI calorie entry ✅ (coordinator; entry links pending WS4)
| # | Item | Status |
|---|---|---|
| 3.1 | **Meal page**: free-text description ("2 rotis and dal") → AI determines calories (`EstimateMealCalories` via VEDA transport, strict JSON contract, null → manual entry fallback) | ✅ |
| 3.2 | User picks date+time (default now); **meal tag auto-determined by time of day** (breakfast 5–10 / lunch 11–15 / dinner 17–21 / else snack), overridable via chips | ✅ |
| 3.3 | **Log page**: chronological history of workouts + meals, grouped by day with per-day kcal/session totals (trailing 30 d) | ✅ |
| 3.4 | Daily calorie totals surfaced on the meal page (eaten / target + progress bar) | ✅ |
| 3.5 | Tests: AI estimate contract (6), tag windows (5), meal screen flows (5), log screen (2), report nutrition (entity+prompt+fallback+PDF+screen) | ✅ |
| 3.6 | Data: `MealEntry.timeMillis` device-local column, schema v1→2 drift migration (`onUpgrade` `addColumn`), log-ordered by time; sync download preserves local time (payload untouched) | ✅ |
| 3.7 | Routes `/meal` + `/log` reserved (1 slot recipe) + DI provider; entry links: Plan "Log meal → /meal", History "View all → /log" (inline expander superseded by the log page) + header cross-links meal ↔ log | ✅ (+ Batch 1 meals-on-Plan fix: Plan reloads on `mealsRevision` — the one-shot `initState` snapshot showed stale "no meals" after the /meal round-trip) |
| 3.8 | Wiring beyond the pages (user request): VEDA AI context feed gets today's kcal/target/meals (chat + local fallback); report gains nutrition (entity fields, AI prompt, rule-based bullet, PDF section, on-screen section — shown only when meals exist) | ✅ |

## WS4 — Strike, library cards, plan slots ✅ (Batch 1: strike wired + cards clickable + slots stable)
| # | Item | Status |
|---|---|---|
| 4.1 | Strike starts from **1**: ROOT CAUSE FOUND — `EndSession` usecase is dead code; `_endSession()` bypasses strike credit → wire it (plus no fake "0 day streak" on Home loading/error) | ✅ (routed through `endSessionProvider`; `strike_wiring_test` pins it) |
| 4.2 | Exercise-library **slot cards clickable** → `_LibraryCard` is a bare Container (no gesture) → Material+InkWell → detail route | ✅ (confirmed in code) |
| 4.3 | Plan **slots stable**: `_DaySessionsSlot` height changes per day → rest-day floor height + AnimatedSize + uniform card dimensions | ✅ (confirmed in code) |

## WS5 — Content: workouts data + demo preview ✅ (agent complete)
| # | Item | Status |
|---|---|---|
| 5.1 | Content integrity test (blocks→exercises→FSM); repair ambiguous refs; report gaps (44 workouts, 40 exercises; 4 exercises lack GIF; assets/videos/ empty — 44 dead mp4 refs, never rendered) | ✅ (6 tests, no repairs needed; Batch 1: the 44 dead mp4 refs removed from `workouts.json`, test now pins "no mp4 path") |
| 5.2 | Demo preview fixes: `instruction_video_screen` height jumps (202↔220↔video) + build-time flag mutation + caption layer crossing; mapper null-tolerance; workout-details hero now shows first block's GIF | ✅ |

## WS6 — Engine coverage + vision/skeleton robustness 🔄 partially done
| # | Item | Status |
|---|---|---|
| 6.1 | FSM coverage: **`chair-dip` had no engine → camera dead-end in 3 workouts** → alias to `tricep_dip` + `test/unit/exercise_registry_test.dart` (all 40 exercises + 236 block refs resolve) | ✅ |
| 6.2 | Skeleton overlay refinement: form-based green/red coloring (FR-5), wire quality display (folded into WS2 scope) | ✅ (Batch 4: painter `formSignal` — warnings red, praise full chartreuse, neutral standard; confidence tiers kept for shaky segments; driven per frame from feedback severities) |
| 6.3 | Any-angle pose robustness: thresholds/normalization pass (folded into WS2 scope; full model training = P9 user-delivered model — ⏸) | ⬜ WS2 |

## WS7 — Smart library search (user request 2026-10-01) ✅ (agent complete: 24 tests, analyze clean; plan-screen search box deferred to integration)
| # | Item | Status |
|---|---|---|
| 7.1 | Unified `LibrarySearch` (domain, pure + unit-tested): score workouts **and exercises** by — workout/exercise **name** (word + prefix), **category / goal / focusMuscles / tags / level**, **exercise names inside `blocks`** ("push" finds every workout containing push-ups), description keywords | ⬜ |
| 7.2 | **Related-word expansion**: synonym map (legs→quads/hamstrings/glutes/squat, abs/core→plank/crunch, chest→push-up/bench, cardio→fat burn/HIIT/jump, back→row/deadlift, shoulders→press/lateral, arms→curl/tricep, stretch→mobility/flexibility…) expanded at query time; multi-token queries = AND across tokens | ⬜ |
| 7.3 | Typo tolerance: normalized (case/separator) equality + prefix match + edit-distance ≤1 for tokens ≥5 chars | ⬜ |
| 7.4 | Wire into `WorkoutScreen._filterWorkouts` (today: **name `contains` only**, workout_screen.dart:282-285), plan `_LibrarySection` (today: no search), empty-state copy suggests related terms | ✅ (workout half already wired; Batch 1 added the plan search box over `filterExercises` + related-terms empty state) |
| 7.5 | Tests: unit (synonyms, multi-token, name-prefix, block-exercise match, no-match) + widget (search field filters with related word) | ⬜ |

## WS8 — Engine rules + feedback vocabulary + angle readouts ✅ (Batch 3; re-activated by the approved MASTER PLAN — the 2026-10-01 cancellation is superseded)
| # | Item | Status |
|---|---|---|
| 8.1 | **Feed ALL exercise rules to the pose engine** (user: "POSE ENGINE"): audit every rule surface per exercise — FSM definition (stateOrder/CounterRule/FeedbackRule), catalog thresholds (ROM/angle gates, pixel→normalized notes), `CalibrationConfig` (enabled on 6, never read → wire), bilateral config, timing/hold rules — and wire whatever `BrainEngine`/`PoseAnalyzer` doesn't consume today. Report the gap list. | ✅ (audit: states/order/counter/feedback/primary/formScore/landmarks/angles already consumed. WIRED: smoothing window → EMA alpha; holdState → holdSeconds clock; sides → bilateral keys. REPORTED: visualization → Batch 5 overlay; calibration phase → Batch 4 screen wiring) |
| 8.2 | **Bilateral rep counting → one count per rep-cycle** (user: "USE THE BEST"): hammer curl is the only `bilateral: true` exercise and counts each arm separately (+2 per curl) → count 1 per completed cycle so block targets ("12 reps") mean what they say and inflated/false counts die. `brain_engine.dart` bilateral branch (~:656/:917). | ✅ (done via WS9.2: max-per-arm counting; sides wiring verified by WS8 contract test) |
| 8.3 | **Feedback vocabulary: 50+ lines** (user: "MORE ACTION 50+ LINE … SITUATION IN DETAIL INSTRUCTIONS HANDLE ALL CASES"): ONE central vocabulary module — every coaching line tagged by situation + action (display / speak / speak-urgent / haptic), covering: form warnings by severity, rep-rejection reasons (2.9), round complete/last-round, rest countdown + ready, milestones (every 5 reps), encouragement, safety, framing, session start/pause/cancel/end, calorie/round summaries. Consumed by the cue slot (on-screen) AND `SoundEngine.speakCue`/`speakUrgent` + `SessionAudioCues` so display and voice never diverge; replaces scattered strings (exercise `FeedbackRule.message`/`audio_cue` map into it). | ✅ (`cue_vocabulary.dart`: 51 lines, all situations covered; lock/framing/mood/rejection mappings; feedback rules funneled with severity tags; milestone cycled; round/rest/session/milestone events consumed in Batch 4 WS2 wiring) |
| 8.4 | **Angle readouts on cam screen, bottom-left + bottom-right, translucent** (user: proper place for angle calculation, translucent style): primary/joint angle one side, L/R (bilateral) or secondary angle the other — fed from `PoseAnalyzer`/`BrainEngine` live values, styled like the sample's translucent HUD (low-opacity glass, small type, non-competing with cue bar). | ✅ (`angleReadouts`: bilateral L/R, primary+secondary w/ description labels, honest nulls; bottom-corner translucent pills fed from engine angles; duration hold chip `HOLD xs / Ys`; replaced the generic top chips) |
| 8.5 | Tests: engine rule-feeding (each rule surface consumed), one-count-per-cycle (bilateral sequence), vocabulary integrity (≥50 lines, all situations covered, no empty/dupe lines, every engine event maps to a line). | ✅ (`ws8_engine_rules_test`: 17 tests — surfaces, hold clock, vocab, readouts; bilateral via WS9.2) |

## WS9 — Count consistency (push-up/squat) + anti-fake detection responses (user order 2026-10-01: "count the push in squad … not consistent … tune that properly" + "unable to detect screen/video → proper responses to avoid fake workout"; runs right after WS2 — same file space) ✅
| 9.1 | **Tune push-up + squat rep counting for consistency** (reported: results not consistent/not proper). Audit the FSMs in `exercise_catalog.dart` (`squat` :26, `push_up` :121) + `brain_engine` transition logic — state-order flips, ROM/angle gates, hold-frame counts, debounce — and harden: evidence-frame hysteresis (a transition needs N consecutive agreeing frames), no flip on single-frame jitter, partial reps never count, one count per full rep-cycle. **DONE**: state-order (bottom evaluated before ascending) + hysteresis conditions (squat standing enter >156 / hold >146 — old 160 bar dropped soft lockouts; bottom entry strict <=90, holds to <=97 across a depth wobble; push-up plank_up enter >153 / hold >143) + session-start guard (the first commit of a session never rejects). Soft-lockout + boundary-wobble + rest-jitter sequences pinned by tests. | ✅ |
| 9.2 | **Bilateral counting (hammer curl)** — carry-over from cancelled WS8: one count per completed rep-cycle so block targets mean what they say (kills inflated +2 counts). Counting-consistency family, re-ordered here. **DONE**: engine counts max(left, right) per-arm reps instead of left+right — a simultaneous curl fired both sides on one frame and +2'd every rep; 3 curls now count 3 (bilateral status still shows both sides; totalCount getter aligned). | ✅ |
| 9.3 | **Trust gate + proper responses → zero fake reps**: complete the `LockReason` pipeline (`pose_analyzer.dart:41`: noPerson/multiPerson/lostTracking/occluded/videoPlayback): (a) rep counting FREEZES unless lock == ok — no evidence, no count; (b) every non-ok reason gets an on-screen + SPOKEN response (banner copy exists in `vision_hud.dart`; voice via `speakCue`/`speakUrgent`); (c) `videoPlayback` (screen/video aimed at the camera) → explicit "point the camera at you, not at a screen" response, reps rejected with reason; (d) sustained loss → auto-pause, re-lock → resume + confirm. **DONE**: (a) verified live — pose_analyzer feeds the brain only when locked (all five non-ok reasons freeze counting); (b) every lock-reason TRANSITION now speaks (lockReasonLine banner copy + 3 s cooldown — previously only videoPlayback had a voice); (c) videoPlayback banner + spoken line live, reps cannot accumulate while it is up; gate-refused reps answered explicitly (coach bar + onWarning voice: tooFast / rangeOfMotion — previously a silent drop); (d) session auto-pause deferred to v1.1.12 (the count freeze covers the fake-rep vector; manual pause exists). | ✅ |
| 9.4 | Tests: synthetic lock/count sequences — fast rep, slow rep, jitter, half-rep, no-pose stretch, videoPlayback window → exact stable counts, counting frozen while unlocked, correct rejection reasons. **DONE**: test/unit/count_consistency_test.dart (4: soft-lockout squat, depth-wobble squat, push-up soft lockout + wobble, one-count-per-cycle, startup honesty) + rep_rejection_test rewritten against the real engine API (5: full-range counts once, 5-rep stability, tooFast, rangeOfMotion, rest noise never counts). no-pose/videoPlayback freeze is analyzer-level (needs ML Kit) — covered by code review, not unit-harness testable. | ✅ |

## Cross-cutting
- Gates per workstream: `flutter analyze` 0 issues · `flutter test` all green · no commits by subagents (coordinator gates + commits).
- Releases: staged APKs for on-device testing (v1.1.11+…).
