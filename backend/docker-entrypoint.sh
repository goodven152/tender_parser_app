#!/usr/bin/env bash
set -e

echo "▶️  Checking parser repo…"
if [ ! -d "${APP_DIR}/.git" ]; then
  git clone --depth 1 --branch "${REPO_BRANCH}" "${REPO_URL}" "${APP_DIR}"
else
  git -C "${APP_DIR}" pull --ff-only
fi

if [ -f "${APP_DIR}/requirements.txt" ]; then
  pip install --no-cache-dir -r "${APP_DIR}/requirements.txt"
fi

export PYTHONPATH="${APP_DIR}:${PYTHONPATH}"
echo "🚀  Starting Uvicorn on :8000"
exec uvicorn main:app --host 0.0.0.0 --port 8000