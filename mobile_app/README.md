# Flutter Mobile Starter (APK Path)

This folder is a starter Flutter app for turning School Assistant into a downloadable Android app.

## Features included in starter

- Google sign-in screen + guest mode
- Home shell with 3 tabs: Chat, Tests, Calendar
- Test add/result add flow with local persistence (`shared_preferences`)
- Performance trend chart (`fl_chart`)
- Calendar events (`table_calendar`)
- One-time vector DB bootstrap service from zip URL

## Setup

1. Install Flutter SDK and Android Studio.
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
