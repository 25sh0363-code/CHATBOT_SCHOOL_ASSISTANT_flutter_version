# SINOVATE Mobile App

This folder contains the Flutter mobile client for SINOVATE.

## Main features

- AI chat with retrieval-backed study context
- Notes generation and markdown viewing
- Tests tracking and performance trend charts
- Timetable, tasks, homework, and calendar views
- Study planner with important exams, revision planning, and daily exam countdown reminders
- Google Calendar handoff for single exam events
- Focus timer with a floating in-app countdown overlay and completion popup
- Collaboration rooms with note/worksheet sharing and owner member controls
- Local persistence via `shared_preferences`

## Setup

1. Install Flutter SDK.
2. Start backend API from the project root:

```bash
uvicorn backend_api:app --host 0.0.0.0 --port 8000 --reload
```

3. From this folder:

```bash
flutter pub get
flutter run \
	--dart-define=BACKEND_BASE_URL=http://10.0.2.2:8000 \
	--dart-define=VECTOR_ZIP_URL=https://your-host/path/vectorstore.zip
```

## Build APK

```bash
flutter build apk --release
```

Release APK output:

- `build/app/outputs/flutter-apk/app-release.apk`

## Build iOS

```bash
flutter build ipa --release
```

Notes:

- Xcode and CocoaPods must be installed and working.
- A valid Apple signing team/certificate is required for signed IPA builds.

## Exam reminders

- Each important exam gets a daily reminder at 7:00 AM until the exam date.
- Reminder messages change based on how close the exam is.
- The in-app Google Calendar action creates a one-time exam event for the exam date.

## Focus timer

- Starting a focus session shows a floating timer card while the rest of the app stays usable.
- The timer continues counting down while navigating across the app.
- When the session ends, a congratulations popup appears.

## Google sign-in notes

You need to configure Google Sign-In for Android:

- Add your package name and SHA-1 in Google Cloud Console.
- Download `google-services.json` and place it in `android/app/`.
- Add corresponding Gradle setup for Firebase/Google services if needed.

## Vector DB bootstrap

Set `VECTOR_ZIP_URL` using `--dart-define` (or leave empty to skip download).

The app will:

- check local app docs folder for `vectorstore/faiss_index/index.faiss`
- download zip only when missing
- unzip and keep cached on device
