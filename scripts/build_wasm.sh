#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Building Rust simulation core (wasm32-unknown-unknown)..."
cargo build --manifest-path sim-core/Cargo.toml --target wasm32-unknown-unknown --release

mkdir -p server/assets
cp sim-core/target/wasm32-unknown-unknown/release/ansible_sim_core.wasm server/assets/sim_core.wasm
ls -lh server/assets/sim_core.wasm
