# School Assistant - SINOVATE

SINOVATE is a Flutter + FastAPI school assistant app that helps students study with AI, manage academic tasks, collaborate in groups, track exams, and stay focused during revision.

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
- Study planner with:
	- Important exam tracking
	- Daily exam countdown reminders up to the exam date
	- One-tap Google Calendar exam event creation
	- Revision plan generation
	- Focus timer with a floating in-app countdown overlay
	- Completion popup when a focus session ends
- Collaboration rooms with room creation, joining, notes/worksheet sharing, room deletion, and owner-managed member removal
- Local persistence for chat, tests, timetable, tasks, homework, notes, exams, and focus timer state
- Light and dark theme support

## Platform Support

- Android (APK build)
- iOS (project included, signing required for device/archive builds)

## Project Structure

- `mobile_app/`: Flutter client (Android + iOS)
- `backend_api.py`: FastAPI backend with chat and notes endpoints
- `vectorstore/`: FAISS index data for retrieval
- `scripts/`: helper scripts for local setup/run

## Backend Endpoints

- `POST /chat`: text chat with retrieval context
- `POST /chat/image`: image + question flow
- `POST /notes/generate`: AI-generated structured study notes
- Collaboration room APIs for create/join/delete, member removal, messages, note sharing, worksheet sharing, and meeting link updates

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

iOS archive / IPA:

```bash
cd mobile_app
flutter build ipa --release
```

iOS prerequisites:

- Full Xcode installation is required (`xcodebuild` must be available).
- A valid Apple Developer signing setup is required for signed device/IPA builds.
- CocoaPods must be installed and working.
- After installing Xcode, run:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

## Exam Countdown Behavior

- Adding an important exam stores it locally in the app.
- The app schedules one reminder per day at 7:00 AM until the exam date.
- Reminder text changes based on proximity to the exam, for example:
	- `20 days until your exam`
	- `Tomorrow is your exam`
	- `Today is the day!`
- The Google Calendar action creates a single one-time exam event, not a repeating event.

## Focus Timer Behavior

- Starting a focus session launches a floating timer overlay that remains visible while using the rest of the app.
- The timer state is persisted so active sessions can recover after app restart.
- When the timer completes, the app shows a congratulatory popup.

## Author

Om Suraj Kashikar
