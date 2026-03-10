# School Assistant (Flutter + FastAPI)

Chemistry and Physics assistant with:
- Flutter app (`mobile_app/`)
- FastAPI backend (`backend_api.py`)
- FAISS vector database (`vectorstore/faiss_index`)

## What gets installed where

- APK includes all Flutter/Dart dependencies at build time.
- Android device does NOT install Python packages.
- Python dependencies are only on your backend machine/server.
- Vector DB is used by backend now, and optional vector ZIP download exists in app.

## Required setup (local)

1. Python backend deps:
```bash
cd /Users/omi/Downloads/CHATBOT_SCHOOL_ASSISTANT_flutter_version
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2. Set `.env`:
```env
OPENAI_API_KEY=your_key_here
# Optional fallback bootstrap for backend start if local index missing:
VECTORSTORE_ZIP_URL=https://your-host/vectorstore.zip
```

3. Flutter deps:
```bash
cd mobile_app
flutter pub get
```

## Run (macOS test)

Terminal 1:
```bash
cd /Users/omi/Downloads/CHATBOT_SCHOOL_ASSISTANT_flutter_version
PORT=8001 ./scripts/run_backend.sh
```

Terminal 2:
```bash
cd /Users/omi/Downloads/CHATBOT_SCHOOL_ASSISTANT_flutter_version
BACKEND_BASE_URL=http://127.0.0.1:8001 ./scripts/run_flutter_macos.sh
```

## Build APK

1. Start backend reachable by phone/emulator:
```bash
cd /Users/omi/Downloads/CHATBOT_SCHOOL_ASSISTANT_flutter_version
HOST=0.0.0.0 PORT=8001 ./scripts/run_backend.sh
```

2. Build APK:
```bash
cd /Users/omi/Downloads/CHATBOT_SCHOOL_ASSISTANT_flutter_version/mobile_app
flutter build apk --release
```

Output:
- `mobile_app/build/app/outputs/flutter-apk/app-release.apk`

3. Test backend URL in app:
- Android emulator: `http://10.0.2.2:8001`
- Real phone: `http://<your-mac-lan-ip>:8001`

Build/run with URL:
```bash
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8001
```

## Vector ZIP format (important)

Create ZIP for app/backend bootstrap:
```bash
cd /Users/omi/Downloads/CHATBOT_SCHOOL_ASSISTANT_flutter_version
./scripts/create_vector_zip.sh
```

ZIP must contain one of:
- `faiss_index/index.faiss` (preferred)
- `vectorstore/faiss_index/index.faiss` (also supported)

Optional app-side download on first launch:
```bash
flutter run \
  --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8001 \
  --dart-define=VECTOR_ZIP_URL=https://your-host/vectorstore.zip
```
