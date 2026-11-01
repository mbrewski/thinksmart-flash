#!/bin/bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/tools/edl-venv/bin/python" "$ROOT/tools/edl/edl.py" "$@"
