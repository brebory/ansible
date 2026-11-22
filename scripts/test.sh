#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

GODOT_BIN="${GODOT_BIN:-$(command -v godot || command -v godot4 || echo "$HOME/.local/bin/godot")}"

echo "=========================================="
echo " 1/4 Rust sim-core unit tests"
echo "=========================================="
cargo test --manifest-path sim-core/Cargo.toml

echo "=========================================="
echo " 2/4 Build Rust WASM module"
echo "=========================================="
bash scripts/build_wasm.sh

echo "=========================================="
echo " 3/4 Nakama Go + wazero WASM bridge tests"
echo "=========================================="
(cd server && go test -v ./...)

echo "=========================================="
echo " 4/4 Godot headless battle engine tests"
echo "=========================================="
if [[ -x "$GODOT_BIN" ]]; then
  if [[ ! -f "client/.godot/global_script_class_cache.cfg" ]]; then
    "$GODOT_BIN" --headless --path client --import --quit >/dev/null 2>&1 || true
  fi
  "$GODOT_BIN" --headless --path client --script res://tests/test_battle_engine.gd
else
  echo "WARNING: Godot binary not found (set GODOT_BIN); skipping Godot headless tests."
fi

echo "All checks passed!"
