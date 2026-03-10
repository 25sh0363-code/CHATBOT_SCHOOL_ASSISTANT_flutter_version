# APK Build Guide

This project ships as:
- Flutter APK client
- Python FastAPI backend

The APK talks to backend `/chat` and `/chat/image` endpoints.

## 1. Confirm vector DB is ready

Expected backend files:
- `vectorstore/faiss_index/index.faiss`
- `vectorstore/faiss_index/index.pkl`

Health check:
```bash
curl -s http://127.0.0.1:8001/health
```
`vector_ready` must be `true`.

## 2. Optional: create vectorstore.zip

```bash
cd /Users/omi/Downloads/CHATBOT_SCHOOL_ASSISTANT_flutter_version
./scripts/create_vector_zip.sh
```

The zip root should be `faiss_index/` (preferred).

## 3. Run backend for phone/emulator

```bash
cd /Users/omi/Downloads/CHATBOT_SCHOOL_ASSISTANT_flutter_version
HOST=0.0.0.0 PORT=8001 ./scripts/run_backend.sh
```

## 4. Build APK

```bash
cd /Users/omi/Downloads/CHATBOT_SCHOOL_ASSISTANT_flutter_version/mobile_app
flutter pub get
flutter build apk --release
```

APK output:
- `build/app/outputs/flutter-apk/app-release.apk`

## 5. Test with correct backend URL

- Android emulator: `http://10.0.2.2:8001`
- Real Android phone: `http://<your-mac-lan-ip>:8001`

Run debug build with URL:
```bash
flutter run \
  --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8001
```

Optional vector download URL:
```bash
flutter run \
  --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8001 \
  --dart-define=VECTOR_ZIP_URL=https://your-host/vectorstore.zip
```

## 6. Smooth install checklist

- `OPENAI_API_KEY` exists in backend `.env`
- `vector_ready` is `true`
- Backend reachable from target device network
- Use emulator/phone-specific backend URL
- Do not use `127.0.0.1` on Android devices
