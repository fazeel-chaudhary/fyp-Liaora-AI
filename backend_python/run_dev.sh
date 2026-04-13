#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# 0.0.0.0: web (127.0.0.1), Android emulator (10.0.2.2), and LAN phones can all reach this.
exec ./venv/bin/uvicorn main:app --reload --host 0.0.0.0 --port 8000
