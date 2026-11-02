#!/usr/bin/env bash
# Run bkerler/edl. Clones tools/edl and builds tools/edl-venv on first use.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EDL_DIR="$ROOT/tools/edl"
EDL_PY="$EDL_DIR/edl.py"
VENV="$ROOT/tools/edl-venv"
REQ="$EDL_DIR/requirements.txt"
LOADER_SRC="$ROOT/tools/loaders/000660e160008000_b9eca30dfea46934_fhprg_peek.bin"
LOADER_DST="$EDL_DIR/Loaders/lenovo_motorola/000660e160008000_b9eca30dfea46934_fhprg_peek.bin"

if [[ ! -f "$EDL_PY" ]]; then
  echo "edl: cloning https://github.com/bkerler/edl.git into tools/edl" >&2
  git clone --depth 1 https://github.com/bkerler/edl.git "$EDL_DIR"
fi

if [[ ! -x "$VENV/bin/python" ]]; then
  echo "edl: creating venv at tools/edl-venv" >&2
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -U pip
  "$VENV/bin/pip" install -r "$REQ"
fi

if [[ -f "$LOADER_SRC" && ! -f "$LOADER_DST" ]]; then
  mkdir -p "$(dirname "$LOADER_DST")"
  cp "$LOADER_SRC" "$LOADER_DST"
fi

exec "$VENV/bin/python" "$EDL_PY" "$@"
