#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PORT="${PORT:-8000}"
HOST="${HOST:-127.0.0.1}"

exec .venv/bin/python -m uvicorn backend_api:app --host "$HOST" --port "$PORT"
