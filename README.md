# SINOVATE School Assistant

SINOVATE is a Flutter + FastAPI study assistant built for students. It combines AI tutoring, note generation, collaboration, exam planning, and guided learning workflows in one app.

## Highlights

- AI Tutor chat with retrieval context
- Image-based question support
- Notes generation from topic/details and file attachments
- Markdown note reading/editing with local storage
- Learning Journey with:
  - Subject checklists
  - XP progress
  - Milestones
  - Optional custom subject mode
  - Completion award popup
- Mind Map Studio in More Tools:
  - Landscape-first interactive canvas
  - Tree-style branch layout
  - Heading/subheading focused mapping
  - Zoom + pan
- Tests tracking and performance trends
- Results Leaderboard in More Tools:
  - Students can share test percentages
  - Subject-wise ranking (Physics, Chemistry, Math)
  - Optional Google Sheets + Apps Script cloud sync
- Calendar view for tests, tasks, and homework
- Study Planner with exam countdown and focus mode
- Collaboration rooms with sharing and group utilities
- Light and dark themes

## Current Scope Changes

- To-Do module removed
- Timetable module removed
- Mind map moved out of Notes into dedicated More Tools feature

## Tech Stack

- Flutter (mobile client)
- FastAPI (backend API)
- LangChain + OpenAI stack for AI flows
- FAISS for retrieval index
- SharedPreferences for client persistence

## Repository Layout

- mobile_app/: Flutter application
- backend_api.py: FastAPI backend entrypoint
- vectorstore/: FAISS index files
- scripts/: helper scripts
- requirements.txt: backend dependencies

## Backend API (Main)

- POST /chat
- POST /chat/image
- POST /notes/generate
- Collaboration APIs for room and message workflows

## Local Setup

### 1) Backend

From repository root:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn backend_api:app --host 0.0.0.0 --port 8000 --reload
```

### 2) Flutter App

From repository root:

```bash
cd mobile_app
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8000
```

For Android emulator, use 10.0.2.2:

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000
```

Optional leaderboard cloud sync via Google Apps Script:

```bash
flutter run \
  --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=LEADERBOARD_APPS_SCRIPT_URL=https://your-script-url/exec
```

## Build

### Android APK

```bash
cd mobile_app
flutter build apk --release
```

With explicit leaderboard endpoint override:

```bash
cd mobile_app
flutter build apk --release \
  --dart-define=LEADERBOARD_APPS_SCRIPT_URL=https://your-script-url/exec
```

Output:

- mobile_app/build/app/outputs/flutter-apk/app-release.apk

### iOS (Signed Build)

```bash
cd mobile_app
flutter build ipa --release
```

Requirements:

- Xcode installed and selected
- Apple signing configured
- CocoaPods working

Useful first-run commands:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

## Notes

- Learning Journey progress is saved locally.
- Mind Map Studio is intended for landscape usage and large-canvas exploration.
- Focus timer state is persisted and resumes across app sessions.
- Results leaderboard supports local cache and can sync from a Google Sheets Apps Script backend.

## Author

Om Suraj Kashikar
