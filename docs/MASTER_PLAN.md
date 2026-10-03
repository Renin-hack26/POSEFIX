# MASTER PLAN — FixPose v1.1.11+12 (8 batches)

Approved by user. Execution order B1 → B8, with Batch 0 (demo) in progress.
Commit style `vX.Y.Z: …`; gates before every build/commit: `flutter analyze`
0 issues, `flutter test` green, secret-scan of staged diff.

## Batch 0 — BlazePose desktop evaluation demo (IN PROGRESS)

Interactive dictation demo at `tools/blazepose_demo/`
(served via `python -m http.server 8765 --directory tools\blazepose_demo`).

- MediaPipe Tasks Vision `pose_landmarker_full` + FaceLandmarker (478 pt) +
  skin-lock velocity predictor (lag slider 0–150 ms), mirror-corrected.
- Clean 3D humanoid (`bp_body3d.js`) built from 33 world landmarks per frame —
  no points/lines until the user dictates them.
- **Gates Batch 5.** User verdict pending.

## Open Vission evaluation (DONE — 2026-10-03)

`C:\Users\imu\Desktop\New folder` = "Open Vission" Python pose engine.

- Tests: **430/430 pass**. Benchmark: **PASS — 38.5 fps, p95 e2e 29.9 ms**
  (budget 80 ms); MediaPipe p50 11.2 ms, MoveNet Thunder-class p50 6.2 ms.
- Architecture verdict: **MERGE along a seam** — FixPose's data-driven
  Brain Engine + 46-exercise catalog stays the spine (scales to 200+);
  Open Vission's quality layers port to Dart.

### Decisions (user-confirmed)

| Decision | Choice |
|---|---|
| MoveNet second opinion | **Include MoveNet Thunder** (12.6 MB, second inference per frame → full 4-signal trust incl. cross-model agreement) |
| BlazePose model | **`pose_landmarker_heavy.task` (30.7 MB)** bundled in APK |
| Plan slotting | **Batch 5 expanded** (below) |

## Batch 1 — Gap fixes (DONE — 2026-10-03)

- Strike: `_endSession()` routed through `endSessionProvider` (strike + plan
  credit + report); pinned by `test/unit/strike_wiring_test.dart` (3 tests).
- Meals-on-Plan root cause: Plan resolved meals once in `initState`, so the
  Plan → /meal → back round-trip always showed the stale snapshot. Fixed
  with `mealsRevisionProvider` (bumped on log/remove/target-edit);
  Plan reloads on change.
- WS7.4: WorkoutScreen half was already wired; Plan `_LibrarySection` gained
  a search field over `LibrarySearch.filterExercises` + related-terms
  empty state.
- WS4 verify: 4.2 (cards clickable) + 4.3 (slot floor) confirmed in code;
  4.1 fixed above.
- Dead assets: 44 dead `demoVideoAsset` mp4 refs removed from
  `assets/data/workouts.json` (files never bundled, never rendered);
  integrity test now pins "no workout declares an mp4 path".
- Banner audit: no stale/under-construction banner on any live surface
  (`UnderConstructionBanner` unused — kept as a shared component).

## Batch 2 — Speech arbiter + notification organization (DONE — 2026-10-03)

Implemented against the spec tests committed in `39a9f82`:

- Speech arbiter (`sound_engine.dart`): one line at a time, newest waiter
  wins, 250 ms breath gap, urgent cuts the line + drops the waiter, 2 s
  identical-cue cooldown, mute cuts + refuses, watchdog frees a wedged
  floor (~1.5 s + 30 ms/char), `speechRate` 0.52 → 0.45. 6 arbiter tests.
- Notification org (`notification_engine.dart`): `daily_reminders` +
  `session_alerts` channels for new schedules, `workout_reminders` kept as
  the legacy channel for old alarms; reminder-time key/default
  single-sourced on the engine, Settings rewired to it. 3 channel tests.
- WS2.10 primer (unblocks gates): pure calibration layer
  (`session_flow.dart`: `RomCapture`, `judgeCalibrationDepth`,
  `calibrationGoodSpanDeg` 60°, `calibrationCompleteLine`) + 10 tests;
  screen-phase wiring stays in Batch 4.

## Batch 3 — WS8

## Batch 4 — WS2 HUD + WS6.2 + auto-pause

## Batch 5 — Pose stack (EXPANDED)

One coherent pose-stack batch:

1. **Model migration**: `google_mlkit_pose_detection` →
   `com.google.mediapipe:tasks-vision` PoseLandmarker, bundled
   `pose_landmarker_heavy.task` (matches Open Vission primary stack).
2. **MoveNet Thunder second opinion** via TFLite — `movenet_thunder_fp16.tflite`
   (12.6 MB) bundled; per-frame dual inference.
3. **Trust gate port** (`trust.py` → Dart): visibility 0.35 / agreement 0.30 /
   temporal 0.20 / geometry 0.15, threshold 0.85, hard gates + hold reasons;
   frames below trust never advance the Brain Engine FSM; rep commits require
   rep-level trust ≥ 0.85 (30th-percentile accumulator). Runs on
   `BrainEngine.processFrame` — benefits all 46+ exercises at once.
4. **Visibility-aware side selection** (`side_value`/`min_side`) so occluded
   limbs never feed counters.
5. **Overlay upgrade**: merge Open Vission's 3-tier 39-bone rendering,
   hollow rings for occluded joints, defensive drawing into
   `SkeletonOverlayPainter`.

Gated on the Batch 0 demo verdict.

Reference (read-only): `C:\Users\imu\Desktop\New folder\openvission\`
(`trust.py`, `skeleton.py`, `exercises/base.py`, `constants.py`, `geometry.py`).

## Batch 6 — WS6.3

## Batch 7 — P1 auth E2E + P3 + P8

## Batch 8 — KGP + R8 + P10 release APK

Blocked on user: **P9 custom model**, **release signing key**.

## Notes

- Gates 2026-10-03 (B1+B2): `flutter analyze` 0 issues; `flutter test`
  203/204 — the single failure is `plan_generation_trace_test`, which fails
  identically on clean HEAD: Windows Smart App Control
  (`VerifiedAndReputablePolicyState=1`) blocks the freshly built
  `build\native_assets\windows\sqlite3.dll` (error 4551). Host-environment
  issue, needs a user allow-list action; does NOT affect the Android APK.

- Trust layer can be prototyped on today's ML Kit feed (it already exposes
  per-landmark `likelihood`, `z`, EMA smoothing) — but per user decision the
  port ships inside expanded Batch 5, not before.
- Single-source fallback stays in code: if MoveNet is ever dropped, agreement
  weight redistributes over the remaining three signals (Open Vission already
  implements this).
