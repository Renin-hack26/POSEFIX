# FixPose APK Deliverables

Named release artifacts, organized per version. Built from the repo root and
copied here after every phase gate.

## Naming convention

```
releases/v<version>/FixPose-v<version>-<buildtype>.apk
```

- `<version>` — matches `pubspec.yaml` (`1.0.1`), build number in parentheses
  (`+2`) is Android's `versionCode`.
- `<buildtype>` — `debug` | `release`.
- Example: `releases/v1.0.1/FixPose-v1.0.1-debug.apk`

## Size budget

- **release < 350 MB** (hard requirement; arm64 + R8 shrink keeps it well under)
- debug may exceed 350 MB (accepted — full runtime libs, no shrinking)

## Contents

| File | versionName+Code | Type | Size | Date |
|---|---|---|---|---|
| `FixPose-v1.0.1-debug.apk` | 1.0.1+2 | debug | 278.5 MB | 2026-09-30 |
| `FixPose-v1.1.0-debug.apk` | 1.1.0+3 | debug | 233.8 MB | 2026-10-01 |
| `FixPose-v1.1.1-debug.apk` | 1.1.1+4 | debug | 233.8 MB | 2026-10-01 |

## Build commands (repo root)

```powershell
# Debug
flutter build apk --debug
# Release (R8 + arm64 split as configured)
flutter build apk --release
```

Raw output: `build\app\outputs\flutter-apk\app-<buildtype>.apk` → copy to this
folder with the named convention above.

> APK files are git-ignored (too large for git); this README and the folder
> structure are tracked.
