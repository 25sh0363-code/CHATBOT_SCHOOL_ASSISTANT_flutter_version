# School Assistant - Chemistry & Physics AI Tutor

School Assistant is a Flutter + FastAPI project that helps students study faster with AI, track tests, and manage daily school work.

## Features

- AI chat for Chemistry and Physics with retrieval-augmented context
- Image-based Q&A support in chat
- Notes generation from topic + optional PDF/image attachments
- Markdown notes viewer with support for rich formatting
- Tests module with marks tracking and performance trends
- Calendar module for viewing tests and timetable events by day
- Timetable planner with a single add form for both:
	- Task items
	- Homework items
- Separate lists for Tasks and Homework inside timetable view
- Native calendar handoff for reminder scheduling
- Local persistence for chat, tests, timetable, tasks, homework, and notes
- Light and dark theme support

## Platform Support

- Android (APK build)
- macOS (desktop build)

## Project Structure

- `mobile_app/`: Flutter client (Android + macOS)
- `backend_api.py`: FastAPI backend with chat and notes endpoints
- `vectorstore/`: FAISS index data for retrieval
- `scripts/`: helper scripts for local setup/run

## Backend Endpoints

- `POST /chat`: text chat with retrieval context
- `POST /chat/image`: image + question flow
- `POST /notes/generate`: AI-generated structured study notes

## Local Run

1. Start backend from repo root:

```bash
uvicorn backend_api:app --host 0.0.0.0 --port 8000 --reload
```

2. Run Flutter app:

```bash
cd mobile_app
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8000
```

## Build

Android APK:

```bash
cd mobile_app
flutter build apk --release
```

APK output:

- `mobile_app/build/app/outputs/flutter-apk/app-release.apk`

macOS desktop app:

```bash
cd mobile_app
flutter build macos --release
```

macOS prerequisite:

- Full Xcode installation is required (`xcodebuild` must be available).
- After installing Xcode, run:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

## Author

Om Suraj Kashikar
