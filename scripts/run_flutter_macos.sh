#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../mobile_app"

export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"

BACKEND_BASE_URL="${BACKEND_BASE_URL:-http://127.0.0.1:8000}"

exec flutter run -d macos --dart-define=BACKEND_BASE_URL="$BACKEND_BASE_URL"
