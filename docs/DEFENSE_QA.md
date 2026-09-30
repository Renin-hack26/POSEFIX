# FixPose — Defense Q&A (anticipated)

> Filled progressively; finalized at P8. Structure from spec (PLANNING.md §10.1).

## Privacy
**Q: Does any video leave the device?**
A: No. 100% on-device processing — pose detection runs via Google ML Kit on-device; zero video frames are sent to the cloud. Only workout *statistics* (reps, durations, form %) sync to Firestore.

**Q: Why is this privacy-relevant?**
A: Users work out in private spaces (hostel rooms, homes). Camera frames never leave the phone.

## Performance
**Q: How do you achieve 25+ FPS on mid-range Android?**
A: ML Kit Accurate mode with a documented fallback ladder: Accurate → Balanced → resolution reduction → overlay simplification, plus EMA landmark smoothing and FPS profiling in CI-informed testing (P2/P8 gates).

## Technical
**Q: Why a two-engine design (Vision + Brain)?**
A: Separation of concerns: the Vision engine owns camera/person-lock/smoothing (sensing), the Brain engine owns decisions/feedback/state machines (reasoning). Either can be tested and evolved independently.

**Q: How do you count a rep correctly (FR-3)?**
A: Per-exercise state machines (UP → DOWN → UP) with full-ROM thresholds (e.g., squat knee flexion < 90°), N-consecutive-frame confirmation, and confidence gates — no counting on partial or jittery motion.

**Q: What if the camera can't see the whole body / multiple people appear?**
A: Person-lock selects the main subject at session start (tap to re-select); minimum-landmark gates pause analysis when too little of the body is visible; framing guide (shaded region) steers correct phone placement.

**Q: How does the rep counter work when the app is backgrounded?**
A: Session auto-pauses and state persists locally; the user resumes exactly where they stopped.

**Q: Isn't OTP via Gmail fragile?**
A: It's a deliberate free-tier decision (documented limits ~100–500/day); the email service is isolated behind an interface for later provider swaps.

## Product
**Q: How is content personalized?**
A: Strike Engine (streaks/badges), rule-based greeting/suggestions + VEDA (hybrid: local rules offline, GROQ online) with full user context (plan, reports, activity logs).
