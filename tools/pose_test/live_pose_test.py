"""FixPose live pose-detection test — Windows camera + MediaPipe Tasks 1.0.

Runs the SAME Google pose model family (BlazePose / MediaPipe, 33 landmarks)
that ML Kit uses on Android, plus MediaPipe Hands (21 nodes per hand) for
full finger-tip tracking — so detection quality, joint mapping, bone
structure, angle measurement and rep counting can be verified independently
of the phone.

Structure drawn
  - body    : 33-landmark skeleton, lines/joints colored by confidence
  - face    : jaw line, eyes, nose, mouth (pose landmarks 0-10)
  - shoulders: neck/shoulder-bone lines ear -> shoulder + clavicle
  - hands   : 21-node finger skeletons per hand (MediaPipe HandLandmarker),
              finger tips highlighted
  - angles  : live degrees drawn at elbows and knees (arcs), shoulders/hips
              in the HUD

Rep counting
  0 - free pose (angles only)
  1 - squat    (knee-angle state machine: down <= 100 deg, rep at >= 155 deg)
  2 - push-up  (elbow-angle state machine: down <= 90 deg, rep at >= 150 deg)

Usage (from repo root):
  .venv-pose\\Scripts\\python.exe tools\\pose_test\\live_pose_test.py

Keys:
  0/1/2 - free / squat / push-up counting mode
  m     - toggle mirror (front-camera view)
  h     - toggle hand (finger) detection
  q     - quit
"""

import math
import sys
import time

import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

MODEL_DIR = "tools/pose_test/models"
POSE_MODEL = f"{MODEL_DIR}/pose_landmarker_full.task"
HAND_MODEL = f"{MODEL_DIR}/hand_landmarker.task"

# ---------------------------------------------------------------------------
# Connection topology — mirrors SkeletonOverlayPainter in the Flutter app.
# ---------------------------------------------------------------------------

# Body (33-landmark BlazePose): face, torso, arms, legs.
BODY_CONNECTIONS = [
    (0, 1), (1, 2), (2, 3), (3, 7),
    (0, 4), (4, 5), (5, 6), (6, 8),
    (9, 10),
    (11, 12), (11, 23), (12, 24), (23, 24),
    (11, 13), (13, 15), (15, 17), (15, 19), (15, 21), (17, 19),
    (12, 14), (14, 16), (16, 18), (16, 20), (16, 22), (18, 20),
    (23, 25), (25, 27), (27, 29), (27, 31), (29, 31),
    (24, 26), (26, 28), (28, 30), (28, 32), (30, 32),
]

# Face: jaw line (ear -> mouth -> mouth -> ear), eyes, nose bridge, mouth.
FACE_CONNECTIONS = [
    (7, 9), (9, 10), (10, 8),          # jaw line through the mouth corners
    (0, 9), (0, 10),                   # nose -> mouth corners
    (1, 2), (2, 3), (4, 5), (5, 6),    # eye outlines
    (0, 1), (0, 4),                    # nose -> inner eye corners
    (3, 7), (6, 8),                    # outer eye -> ears
]

# Shoulder / neck bone structure: ear -> shoulder (neck), plus a hint of
# clavicle via the nose-to-shoulder line.
SHOULDER_CONNECTIONS = [
    (7, 11), (8, 12),                  # neck: ears -> shoulders
    (11, 12),                          # clavicle / upper chest bar
]

# MediaPipe Hands topology (21 nodes per hand).
HAND_CONNECTIONS = [
    (0, 1), (1, 2), (2, 3), (3, 4),              # thumb
    (0, 5), (5, 6), (6, 7), (7, 8),              # index
    (5, 9), (9, 10), (10, 11), (11, 12),         # middle
    (9, 13), (13, 14), (14, 15), (15, 16),       # ring
    (13, 17), (17, 18), (18, 19), (19, 20),      # pinky
    (0, 17),                                     # wrist -> pinky knuckle
]
HAND_TIPS = {4, 8, 12, 16, 20}                   # thumb..pinky tips

# Angle specs: (a, b, c) — angle measured AT vertex b.
ANGLE_SPECS = {
    "elbow_l": (11, 13, 15),
    "elbow_r": (12, 14, 16),
    "knee_l": (23, 25, 27),
    "knee_r": (24, 26, 28),
    "shoulder_l": (13, 11, 23),
    "shoulder_r": (14, 12, 24),
    "hip_l": (11, 23, 25),
    "hip_r": (12, 24, 26),
    "body_l": (11, 23, 27),   # shoulder-hip-ankle body line (push-up form)
    "body_r": (12, 24, 28),
}

# Rep-count modes: name -> (angle key, down threshold, up threshold).
COUNT_MODES = {
    "0": None,                                     # free pose
    "1": ("squat", "knee", 100.0, 155.0),
    "2": ("push-up", "elbow", 90.0, 150.0),
}

GREEN = (118, 230, 0)      # BGR 0x00E676 — high confidence (>=0.5)
ORANGE = (0, 109, 255)     # BGR 0xFF6D00 — low confidence (<0.5)
WHITE = (255, 255, 255)
GRAY = (170, 170, 170)     # face / jaw lines
YELLOW = (0, 255, 255)     # shoulder-bone / neck lines
CYAN = (255, 255, 0)       # hand skeleton
MAGENTA = (255, 0, 255)    # finger tips
MAGENTA_HUD = (255, 0, 255)


def angle_at(pts, a, b, c):
    """Angle a-b-c in degrees at vertex b, or None if a point is missing."""
    if a not in pts or b not in pts or c not in pts:
        return None
    ux, uy = pts[a][0] - pts[b][0], pts[a][1] - pts[b][1]
    vx, vy = pts[c][0] - pts[b][0], pts[c][1] - pts[b][1]
    norm = math.hypot(ux, uy) * math.hypot(vx, vy)
    if norm == 0:
        return None
    dot = ux * vx + uy * vy
    return math.degrees(math.acos(max(-1.0, min(1.0, dot / norm))))


def draw_angle_arc(frame, pts, spec, color=WHITE, radius=26):
    """Draw an arc + degree label at the angle vertex."""
    a, b, c = spec
    ang = angle_at(pts, a, b, c)
    if ang is None:
        return ang
    p = pts[b]
    a1 = math.atan2(pts[a][1] - p[1], pts[a][0] - p[0])
    a2 = math.atan2(pts[c][1] - p[1], pts[c][0] - p[0])
    delta = a2 - a1
    while delta > math.pi:
        delta -= 2 * math.pi
    while delta < -math.pi:
        delta += 2 * math.pi
    steps = 18
    poly = np.array([
        (
            int(round(p[0] + radius * math.cos(a1 + delta * i / steps))),
            int(round(p[1] + radius * math.sin(a1 + delta * i / steps))),
        )
        for i in range(steps + 1)
    ], np.int32)
    cv2.polylines(frame, [poly], False, color, 1, cv2.LINE_AA)
    mid = a1 + delta / 2
    lx = int(round(p[0] + radius * 1.45 * math.cos(mid)))
    ly = int(round(p[1] + radius * 1.45 * math.sin(mid)))
    cv2.putText(frame, f"{round(ang)}", (lx - 8, ly + 4),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1, cv2.LINE_AA)
    return ang


def mean_or_none(values):
    values = [v for v in values if v is not None]
    return sum(values) / len(values) if values else None


def main() -> int:
    cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
    if not cap.isOpened():
        print("ERROR: cannot open camera 0")
        return 1
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    pose_options = vision.PoseLandmarkerOptions(
        base_options=mp_python.BaseOptions(model_asset_path=POSE_MODEL),
        running_mode=vision.RunningMode.VIDEO,
        num_poses=1,
        min_pose_detection_confidence=0.5,
        min_tracking_confidence=0.5,
    )
    landmarker = vision.PoseLandmarker.create_from_options(pose_options)

    hand_options = vision.HandLandmarkerOptions(
        base_options=mp_python.BaseOptions(model_asset_path=HAND_MODEL),
        running_mode=vision.RunningMode.VIDEO,
        num_hands=2,
        min_hand_detection_confidence=0.5,
        min_hand_presence_confidence=0.5,
        min_tracking_confidence=0.5,
    )
    handmarker = vision.HandLandmarker.create_from_options(hand_options)

    mirror = True
    hands_on = True
    mode_key = "0"
    fps = 0.0
    t_prev = time.perf_counter()
    window = "FixPose live detection  [q quit | m mirror | h hands | 0 free 1 squat 2 pushup]"

    reps = 0
    phase = "READY"

    while True:
        ok, frame = cap.read()
        if not ok:
            break
        if mirror:
            frame = cv2.flip(frame, 1)
        h, w = frame.shape[:2]

        now_ms = int(time.perf_counter() * 1000)
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = landmarker.detect_for_video(mp_image, now_ms)
        hand_result = handmarker.detect_for_video(mp_image, now_ms) if hands_on else None

        now = time.perf_counter()
        dt = now - t_prev
        t_prev = now
        fps = fps * 0.9 + (1.0 / dt if dt > 0 else 0) * 0.1

        # ---- pose landmarks (pixel space) --------------------------------
        pts = {}
        if result.pose_landmarks:
            for i, lm in enumerate(result.pose_landmarks[0]):
                vis = lm.visibility if lm.visibility is not None else 1.0
                if vis < 0.3:
                    continue
                pts[i] = (int(lm.x * w), int(lm.y * h))

        torso_ok = all(k in pts for k in (11, 12, 23, 24))
        if len(pts) == 0:
            state = "no person detected - step into frame"
        elif not torso_ok:
            state = f"person partial - {len(pts)}/33 landmarks"
        else:
            state = f"person locked - {len(pts)}/33 landmarks"

        # ---- body skeleton (colored by confidence) ------------------------
        for a, b in BODY_CONNECTIONS:
            if a in pts and b in pts:
                cv2.line(frame, pts[a], pts[b], GREEN, 2, cv2.LINE_AA)

        # ---- face / jaw line ---------------------------------------------
        for a, b in FACE_CONNECTIONS:
            if a in pts and b in pts:
                cv2.line(frame, pts[a], pts[b], GRAY, 1, cv2.LINE_AA)

        # ---- shoulder-bone / neck structure -------------------------------
        for a, b in SHOULDER_CONNECTIONS:
            if a in pts and b in pts:
                cv2.line(frame, pts[a], pts[b], YELLOW, 2, cv2.LINE_AA)

        # ---- hands: full 21-node finger skeletons -------------------------
        hand_count = 0
        if hand_result and hand_result.hand_landmarks:
            hand_count = len(hand_result.hand_landmarks)
            for hand in hand_result.hand_landmarks:
                hpts = {i: (int(lm.x * w), int(lm.y * h))
                        for i, lm in enumerate(hand)}
                for a, b in HAND_CONNECTIONS:
                    if a in hpts and b in hpts:
                        cv2.line(frame, hpts[a], hpts[b], CYAN, 2, cv2.LINE_AA)
                for i, p in hpts.items():
                    if i in HAND_TIPS:
                        cv2.circle(frame, p, 7, MAGENTA, -1, cv2.LINE_AA)
                        cv2.putText(frame, str(i), (p[0] + 6, p[1] - 6),
                                    cv2.FONT_HERSHEY_SIMPLEX, 0.4,
                                    MAGENTA, 1, cv2.LINE_AA)
                    else:
                        cv2.circle(frame, p, 4, CYAN, -1, cv2.LINE_AA)

        # ---- body joints + index labels -----------------------------------
        for i, (x, y) in pts.items():
            if i in (11, 12, 23, 24):          # shoulder / hip "bones"
                cv2.circle(frame, (x, y), 8, GREEN, 2, cv2.LINE_AA)
            cv2.circle(frame, (x, y), 5, GREEN, -1, cv2.LINE_AA)
            cv2.putText(frame, str(i), (x - 4, y - 9),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.3, WHITE, 1, cv2.LINE_AA)

        # ---- angles: arcs at elbows + knees --------------------------------
        ang = {k: angle_at(pts, *spec) for k, spec in ANGLE_SPECS.items()}
        for key in ("elbow_l", "elbow_r", "knee_l", "knee_r"):
            draw_angle_arc(frame, pts, ANGLE_SPECS[key])

        # ---- rep counter state machine -------------------------------------
        mode = COUNT_MODES[mode_key]
        reps_line = ""
        if mode is not None:
            name, joint, down_t, up_t = mode
            avg = mean_or_none([ang.get(f"{joint}_l"), ang.get(f"{joint}_r")])
            if avg is None:
                phase = "NO JOINT"
            elif not torso_ok:
                phase = "NO LOCK"
            else:
                if avg <= down_t and phase in ("READY", "UP"):
                    phase = "DOWN"
                elif avg >= up_t and phase == "DOWN":
                    reps += 1
                    phase = "UP"
                elif avg >= up_t:
                    phase = "UP"
            extra = ""
            if name == "squat" and ang.get("hip_l") is not None:
                extra = f"  HIP {round(ang['hip_l'])}"
            if name == "push-up":
                body = mean_or_none([ang.get("body_l"), ang.get("body_r")])
                if body is not None:
                    warn = "" if body >= 140 else "  !SAG"
                    extra = f"  BODY {round(body)}{warn}"
            reps_line = (f"{name.upper()}  {phase}  "
                         f"{'KNEE' if joint == 'knee' else 'ELB'} "
                         f"{round(avg) if avg is not None else '--'}{extra}")
            cv2.putText(frame, f"REPS {reps}", (w - 210, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.9, MAGENTA_HUD, 2,
                        cv2.LINE_AA)
        else:
            def fmt(key, label):
                v = ang.get(key)
                return f"{label} {round(v)}" if v is not None else f"{label} --"
            reps_line = ("  ".join([
                fmt("elbow_l", "ELB-L"), fmt("elbow_r", "ELB-R"),
                fmt("knee_l", "KNEE-L"), fmt("knee_r", "KNEE-R"),
            ]))
            if ang.get("shoulder_l") is not None:
                reps_line += (f"  SHLD {round(ang['shoulder_l'])}"
                              f"  HIP {round(ang['hip_l']) if ang.get('hip_l') is not None else '--'}")

        # ---- HUD ------------------------------------------------------------
        cv2.rectangle(frame, (0, 0), (w, 104), (30, 30, 30), -1)
        cv2.putText(frame, state.upper(), (14, 28),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                    GREEN if torso_ok else ORANGE, 2, cv2.LINE_AA)
        cv2.putText(
            frame,
            f"fps {fps:4.1f} | mirror {int(mirror)} | pose {len(pts)}/33"
            f" | hands {hand_count} | mode {mode[0] if mode else 'free'}",
            (14, 56),
            cv2.FONT_HERSHEY_SIMPLEX, 0.5, WHITE, 1, cv2.LINE_AA,
        )
        if reps_line:
            cv2.putText(frame, reps_line, (14, 84),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.55,
                        YELLOW if mode else WHITE, 1, cv2.LINE_AA)
        cv2.putText(frame, "q quit  m mirror  h hands  0 free  1 squat  2 pushup",
                    (14, h - 12),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, (120, 120, 120), 1,
                    cv2.LINE_AA)

        cv2.imshow(window, frame)
        key = cv2.waitKey(1) & 0xFF
        if key == ord("q"):
            break
        elif key == ord("m"):
            mirror = not mirror
        elif key == ord("h"):
            hands_on = not hands_on
        elif key in (ord("0"), ord("1"), ord("2")):
            if key != ord("0"):
                reps = 0
            phase = "READY"
            mode_key = chr(key)

    landmarker.close()
    handmarker.close()
    cap.release()
    cv2.destroyAllWindows()
    return 0


if __name__ == "__main__":
    sys.exit(main())
