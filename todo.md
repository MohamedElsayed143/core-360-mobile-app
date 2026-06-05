# 🌌 Core-360 Mobile - Implementation Checklist

## Phase 1: Foundational Setup
- [x] Create Flutter Project (`core_360_app`)
- [x] Configure `pubspec.yaml` with Firebase dependencies (`firebase_core`, `firebase_auth`, `cloud_firestore`, etc.)
- [x] Initialize `FirebaseClient` and configure root/sub-collection references
- [x] Implement Cloud Firestore Seeding Script for global workouts collection

## Phase 2: Feature Architecture
### 1. User Onboarding & Identity
- [x] Authentication Screens (Sign In / Sign Up UI using Firebase Auth)
- [x] Secure Session fallbacks & User profile creation in Firestore
- [x] 3-Step Biometric Onboarding Survey Page (Form Validation & Firestore Saving)

### 2. Workout Routine Builder
- [x] Manual Workout Builder UI & Firestore saving (Routines & Sub-collections)
- [x] AI Workout Planner Survey (4 Steps Layout)
- [x] Integration with Groq API for Dynamic Routine Generation
- [x] Share Code Generation & Importing Logic (8-character alphanumeric Firestore lookup)

### 3. Active Workout Tracking Session
- [x] Active Stopwatch HUD (MM:SS timer)
- [x] YouTube Tutorial Video Player Integration (`youtube_player_flutter`)
- [x] Interactive Sets Ledger UI (Add/Delete/Log Sets, Reps, and KG in Firestore)
- [x] Post-Workout Trophy Summary Card & Session Saving

### 4. Neural Pose Analysis Engine (Computer Vision)
- [x] Camera Interface for Live Frame Capture
- [x] Google ML Kit Pose Detection SDK integration & Landmarking Bridge
- [x] Geometric Biomechanics Score Logic (0-100%) & Live HUD Warning Strip
- [x] AI Biomechanics Report layout & Firestore saving of Analysis Results

### 5. Bilingual RAG AI Coach Chat
- [x] Chat UI Interface (User and Assistant Message Bubbles)
- [x] RAG Payload Compiler (Fetches Firestore User Profile + History to send to API)
- [x] Streaming response support with Groq Cloud Endpoint
- [x] `[PLAN_PROPOSAL]` JSON parser to render clickable cards inside chat

### 6. Interactive Analytics & Progress Dashboard
- [x] 7-Day / 30-Day Time Window Selector Toggle
- [x] 4 Analytical KPI Blocks UI (Sourced from Firestore)
- [x] Area & Bar Charts Integration using `fl_chart`
- [x] Anatomical Muscle Highlighter Matrix (Front/Back Interactive View & trained counts)