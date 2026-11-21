#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-$(command -v godot || command -v godot4 || echo "$HOME/.local/bin/godot")}"

echo "==> Checking Ansible playtesting & capture toolchain..."
if [[ -x "$GODOT_BIN" ]]; then
  echo "  [OK] Godot: $("$GODOT_BIN" --version) ($GODOT_BIN)"
else
  echo "  [MISSING] Godot 4.5+ not found on PATH or GODOT_BIN"
  exit 1
fi

if command -v ffmpeg >/dev/null 2>&1; then
  echo "  [OK] ffmpeg: $(ffmpeg -version | head -n 1)"
else
  echo "  [MISSING] ffmpeg not installed"
  exit 1
fi

if command -v npx >/dev/null 2>&1; then
  echo "  [OK] npx available (configured in .mcp.json for Erodenn/godot-mcp-runtime)"
else
  echo "  [MISSING] Node.js / npx not installed (required for godot-mcp-runtime)"
  exit 1
fi

echo ""
echo "MCP server config (.mcp.json) uses: npx -y godot-mcp-runtime"
echo "Point your MCP client at this repo root to launch & drive client/ live."
