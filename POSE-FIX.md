0---
title: "On-Device AI Pose Detection Fitness Coach & Rep Counter"
application_id: "APP-10"
level: "LEVEL 3 — ADVANCED (3RD YEAR RECOMMENDED)"
source: "BBIT HACKATHON 2026 — CODERS' CLUB OFFICIAL HANDBOOK"
page: 50
data_sensitivity: "HIGHLY SENSITIVE — preserve supplied information and do not compromise it"
---

# APP-10 — On-Device AI Pose Detection Fitness Coach & Rep Counter

> **Level:** LEVEL 3 — ADVANCED (3RD YEAR RECOMMENDED)
>
> **Source:** BBIT HACKATHON 2026 — CODERS' CLUB OFFICIAL HANDBOOK
>
> **Page:** 50
>
> **Confidentiality:** Budge Budge Institute of Technology | Confidential — Hackathon 2026

## 1. REAL-WORLD CONTEXT & RESUME VALUE

### [CONTEXT]
Students working out in hostel rooms or gym beginners frequently suffer lumbar spine and knee injuries due to improper exercise form (squats with knees caving in, incomplete pushup range of motion).

### [COST CONTEXT]
Hiring a private personal trainer costs ₹5,000+/month.

### [SOLUTION CONTEXT]
An on-device mobile AI vision coach that uses the phone camera to track skeletal joint angles, count reps automatically, and provide real-time voice corrections elevates digital fitness.

### [RESUME VALUE / PRODUCT CHARACTERISTICS]
The described solution is an **on-device mobile AI vision coach** centered on phone-camera-based skeletal joint tracking, automatic repetition counting, and real-time voice corrections.

---

## 2. TARGET PERSONAS & CORE PROBLEM

### [PRIMARY USERS]
- Home gym workout enthusiasts
- Student athletes
- Physical rehabilitation patients

### [CORE PROBLEM]
The handbook identifies improper exercise form as a source of lumbar spine and knee injuries, including:
- Squats with knees caving in
- Incomplete pushup range of motion

---

## 3. CORE FUNCTIONAL REQUIREMENTS (WHAT TO BUILD IN 32 HOURS)

> **Implementation Time Constraint:** WHAT TO BUILD IN 32 HOURS

### FR-1 — Real-Time Skeleton Tracking

**Tag:** `[FR-1]`

**Requirement:** Ingests front/back mobile camera stream at 30 FPS running on-device MediaPipe / TensorFlow Lite pose detection.

**Description:**
The system must ingest a **front/back mobile camera stream at 30 FPS** and perform **on-device pose detection** using **MediaPipe / TensorFlow Lite**.

**Preserved parameters:**
- Camera stream: front/back mobile camera stream
- Target frame rate: 30 FPS
- Processing mode: on-device
- Pose detection technologies: MediaPipe / TensorFlow Lite

---

### FR-2 — Exercise Form Classification

**Tag:** `[FR-2]`

**Requirement:** Supports Squats, Pushups, and Jumping Jacks with biomechanical angle tracking (Hip-Knee-Ankle angles).

**Description:**
The system must support exercise form classification for the specified exercises while tracking the stated biomechanical angles.

**Supported exercises:**
- Squats
- Pushups
- Jumping Jacks

**Biomechanical tracking parameter:**
- Hip-Knee-Ankle angles

---

### FR-3 — Automatic Repetition Counter

**Tag:** `[FR-3]`

**Requirement:** State-machine counting completed reps only when full range of motion is achieved (e.g. knee flexion < 90° for squats).

**Description:**
The repetition counter must use **state-machine counting** and count a repetition only when the exercise reaches the required **full range of motion**.

**Explicit example / threshold:**
- Squats: knee flexion < 90°

---

### FR-4 — Audio Posture Cues

**Tag:** `[FR-4]`

**Requirement:** Real-time voice feedback via text-to-speech: 'Keep your chest up!' or 'Go deeper!' during the exercise.

**Description:**
The system must provide **real-time voice feedback** through **text-to-speech** during the exercise, using posture-correction cues.

**Specified example cues:**
- `'Keep your chest up!'`
- `'Go deeper!'`

---

### FR-5 — Visual Skeletal Overlay

**Tag:** `[FR-5]`

**Requirement:** Real-time colored overlay on camera feed (Green joints = Good form; Red joints = Posture warning).

**Description:**
The system must render a **real-time colored skeletal overlay** on the camera feed to indicate form status.

**Visual status mapping:**
- **Green joints** = Good form
- **Red joints** = Posture warning

---

### FR-6 — Workout Summary Dossier

**Tag:** `[FR-6]`

**Requirement:** Post-workout stats detailing total reps, average cadence, and form accuracy percentage.

**Description:**
After the workout, the system must provide a summary containing the specified post-workout statistics.

**Required statistics:**
- Total reps
- Average cadence
- Form accuracy percentage

---

## 4. NON-FUNCTIONAL & RELIABILITY REQUIREMENTS

### [NFR / RELIABILITY]

The solution must satisfy the following non-functional and reliability requirements:

- **Processing:** 100% on-device processing
- **Cloud transmission:** Zero video frames sent to cloud
- **Privacy:** Complete privacy
- **Performance target:** Smooth 25+ FPS
- **Target hardware class:** Mid-range Android phones

### [PRIVACY REQUIREMENT]

> **100% on-device processing (zero video frames sent to cloud; complete privacy)**

### [PERFORMANCE REQUIREMENT]

> **smooth 25+ FPS on mid-range Android phones**

---

## 5. MANDATORY TEAM DOCUMENTATION ARTIFACTS

### [MANDATORY DOCUMENTATION]

The team must submit the following files based on the official templates:

- `README.md`
- `docs/PLANNING.md`
- `docs/PROGRESS.md`
- `docs/DEPLOYMENT.md`
- `docs/DEFENSE_QA.md`

### [DOCUMENTATION CONDITION]

> Must submit: README.md, docs/PLANNING.md, docs/PROGRESS.md, docs/DEPLOYMENT.md, and docs/DEFENSE_QA.md based on official templates.

---

## 6. RUBRIC ALIGNMENT

### [RUBRIC]

Maximum marks in:

- **Innovation & Creativity**
- **Technical Implementation**
- **Live Demo spectacle**

---

## HINT & RECOMMENDED STACK

> **Recommendation Only**

The handbook provides the following recommended stack options. The recommendation is preserved without treating it as mandatory.

### [FRONTEND — OPTION 1]

- **React Native**
- **Expo Camera**
- **@tensorflow/tf-js**

### [POSE DETECTION — OPTION 1]

- **@tensorflow/tf-js**

### [FRONTEND — OPTION 2]

- **Flutter**
- **Google ML Kit Pose Detection**

### [POSE DETECTION — OPTION 2]

- **Google ML Kit Pose Detection**

### [AUDIO]

- **Expo Speech**

### [DEPLOYMENT]

- **Expo Go**
- **APK**

---

## DISCLAIMER — TECHNICAL STACK FREEDOM

> **Disclaimer:** This stack is a helpful recommendation; teams have full technical freedom to choose any modern stack.

The listed technologies are therefore recommendations only, while the handbook explicitly states that teams retain full technical freedom to choose any modern stack.

---

## STRUCTURED REQUIREMENT INDEX

| ID / Tag | Type / Aspect | Required Parameter / Requirement |
|---|---|---|
| `APP-10` | Application | On-Device AI Pose Detection Fitness Coach & Rep Counter |
| `LEVEL 3` | Difficulty / Level | Advanced; 3rd Year Recommended |
| `[CONTEXT]` | Real-world context | Improper exercise form can contribute to lumbar spine and knee injuries |
| `[COST CONTEXT]` | Cost | Private personal trainer: ₹5,000+/month |
| `[PRIMARY USERS]` | Target personas | Home gym workout enthusiasts; student athletes; physical rehabilitation patients |
| `[FR-1]` | Functional requirement | Front/back mobile camera stream; 30 FPS; on-device MediaPipe / TensorFlow Lite pose detection |
| `[FR-2]` | Functional requirement | Squats, Pushups, Jumping Jacks; Hip-Knee-Ankle angle tracking |
| `[FR-3]` | Functional requirement | State-machine rep counting; full range of motion; squat example: knee flexion < 90° |
| `[FR-4]` | Functional requirement | Real-time text-to-speech posture feedback; specified example cues preserved |
| `[FR-5]` | Functional requirement | Real-time colored skeletal overlay; Green = Good form; Red = Posture warning |
| `[FR-6]` | Functional requirement | Total reps; average cadence; form accuracy percentage |
| `[NFR / RELIABILITY]` | Non-functional | 100% on-device; zero cloud video frames; complete privacy; smooth 25+ FPS; mid-range Android phones |
| `[DOCUMENTATION]` | Mandatory artifacts | README.md; docs/PLANNING.md; docs/PROGRESS.md; docs/DEPLOYMENT.md; docs/DEFENSE_QA.md |
| `[RUBRIC]` | Rubric alignment | Innovation & Creativity; Technical Implementation; Live Demo spectacle |
| `[TECHNOLOGY]` | Recommended stack | React Native, Expo Camera, @tensorflow/tf-js, Flutter, Google ML Kit Pose Detection, Expo Speech, Expo Go, APK |
| `[DISCLAIMER]` | Stack constraint | Recommendation only; teams have full technical freedom to choose any modern stack |

---

## EXACT SOURCE TEXT — PRESERVED CONTENT

### 1. REAL-WORLD CONTEXT & RESUME VALUE

Students working out in hostel rooms or gym beginners frequently suffer lumbar spine and knee injuries due to improper exercise form (squats with knees caving in, incomplete pushup range of motion). Hiring a private personal trainer costs ₹5,000+/month. An on-device mobile AI vision coach that uses the phone camera to track skeletal joint angles, count reps automatically, and provide real-time voice corrections elevates digital fitness.

### 2. TARGET PERSONAS & CORE PROBLEM

Primary Users: Home gym workout enthusiasts, student athletes, and physical rehabilitation patients.

### 3. CORE FUNCTIONAL REQUIREMENTS (WHAT TO BUILD IN 32 HOURS)

- FR-1 (Real-Time Skeleton Tracking): Ingests front/back mobile camera stream at 30 FPS running on-device MediaPipe / TensorFlow Lite pose detection.
- FR-2 (Exercise Form Classification): Supports Squats, Pushups, and Jumping Jacks with biomechanical angle tracking (Hip-Knee-Ankle angles).
- FR-3 (Automatic Repetition Counter): State-machine counting completed reps only when full range of motion is achieved (e.g. knee flexion < 90° for squats).
- FR-4 (Audio Posture Cues): Real-time voice feedback via text-to-speech: 'Keep your chest up!' or 'Go deeper!' during the exercise.
- FR-5 (Visual Skeletal Overlay): Real-time colored overlay on camera feed (Green joints = Good form; Red joints = Posture warning).
- FR-6 (Workout Summary Dossier): Post-workout stats detailing total reps, average cadence, and form accuracy percentage.

### 4. NON-FUNCTIONAL & RELIABILITY REQUIREMENTS

100% on-device processing (zero video frames sent to cloud; complete privacy); smooth 25+ FPS on mid-range Android phones.

### 5. MANDATORY TEAM DOCUMENTATION ARTIFACTS

Must submit: README.md, docs/PLANNING.md, docs/PROGRESS.md, docs/DEPLOYMENT.md, and docs/DEFENSE_QA.md based on official templates.

### 6. RUBRIC ALIGNMENT

Maximum marks in Innovation & Creativity, Technical Implementation, and Live Demo spectacle.

### HINT & RECOMMENDED STACK (RECOMMENDATION ONLY)

Frontend: React Native with Expo Camera + @tensorflow/tf-js or Flutter + Google ML Kit Pose Detection; Audio: Expo Speech; Deployment: Expo Go / APK.

**Disclaimer:** This stack is a helpful recommendation; teams have full technical freedom to choose any modern stack.

---

**Source footer:** Budge Budge Institute of Technology | Confidential — Hackathon 2026  
**Page:** 50
