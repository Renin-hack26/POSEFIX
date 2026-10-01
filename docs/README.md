# FixPose — Documentation Index

> On-device AI pose detection fitness coach & rep counter (Flutter, Android-only,
> minSdk 24). 100% on-device — zero video frames to the cloud.
> Project overview lives in the [root README](../README.md).

This folder is the single source of truth for *design, planning and release
state*. Use this page to find the right document fast.

## Documents

| Document | What it is | Use it when… |
|---|---|---|
| [PLANNING.md](PLANNING.md) | **Master product & technical plan** (FINAL DRAFT) — architecture, storage scope (Drift/Hive), UI system incl. the motion-language sample (§5.3), notification design (§11), roadmap. | You need to know *how the app is designed* or why a subsystem exists. Section numbers (§x.y) referenced elsewhere in code/docs resolve here. |
| [TODO_v1.1.11.md](TODO_v1.1.11.md) | **Current release work batch** — workstreams WS1–WS8 with full specs and ✅/🔄/⬜ status checklists. | You need the scope, spec and live status of the v1.1.11 release. |
| [PROGRESS.md](PROGRESS.md) | **Chronological progress log** — what shipped, when, per release. | You need to catch up on history ("what changed and when"). |
| [DEPLOYMENT.md](DEPLOYMENT.md) | **Deployment guide** — building, secrets/dart-defines, signing, release flow. | You are building, packaging or shipping an APK. |
| [DEFENSE_QA.md](DEFENSE_QA.md) | **Anticipated defense Q&A** — questions & answers about design decisions and trade-offs. | You are presenting/demoting the project and need prepared answers. |

Related documents outside this folder:

- [`../README.md`](../README.md) — project overview, feature list, getting started.
- [`../releases/README.md`](../releases/README.md) — how built APKs are archived under `releases/`.
- [`../assets/demo/ATTRIBUTION.md`](../assets/demo/ATTRIBUTION.md) — exercise demo GIF credits.

## Quick facts (day-to-day)

- **Platform**: Android only, minSdk 24. No iOS work in scope.
- **Debug build**:
  ```powershell
  flutter build apk --debug --dart-define-from-file=secrets/dart_defines.json
  ```
- **Quality gates** (every change must pass both before building/committing):
  ```powershell
  flutter analyze   # must be "No issues found"
  flutter test      # must be "All tests passed"
  ```
- **Testing split**: assistant runs builds/tests/releases; on-device testing is
  done by the project owner.
- **Content gaps** (known, tracked in `TODO_v1.1.11.md`): 4 exercises have no
  demo GIF (`v-up`, `warrior-flow`, `downward-dog`, `cobra-stretch`);
  `assets/videos/` is empty (44 declared mp4 refs are intentionally not bundled —
  the instruction screen falls back to GIF/form guide).
