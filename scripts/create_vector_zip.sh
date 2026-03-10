#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f "vectorstore/faiss_index/index.faiss" ]]; then
  echo "Missing vectorstore/faiss_index/index.faiss"
  exit 1
fi

rm -f vectorstore.zip

# Keep zip root as faiss_index/ for simplest extraction on app/backend.
(
  cd vectorstore
  zip -r ../vectorstore.zip faiss_index >/dev/null
)

echo "Created: $(pwd)/vectorstore.zip"
