#!/usr/bin/env bash
# Record Ansible Godot 4 playtest footage via MovieWriter (deterministic) or Xvfb + x11grab,
# then transcode to reviewable H.264 MP4, lightweight GIF, and PNG keyframes via ffmpeg.
#
# Usage:
#   bash scripts/record_playtest.sh [--mode movie|x11grab] [--out-dir playtest-captures] [--fps 24] [--max-frames 480] [--duration 20]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="movie"
OUT_DIR="$ROOT_DIR/playtest-captures"
FPS=24
MAX_FRAMES=480
DURATION=20
GODOT_BIN="${GODOT_BIN:-$(command -v godot || command -v godot4 || echo "$HOME/.local/bin/godot")}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    --fps) FPS="$2"; shift 2 ;;
    --max-frames) MAX_FRAMES="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d_%H%M%S)"
MP4_OUT="$OUT_DIR/ansible_battle_playtest_${STAMP}.mp4"
GIF_OUT="$OUT_DIR/ansible_battle_playtest_${STAMP}.gif"

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "ERROR: Godot binary not found at $GODOT_BIN (set GODOT_BIN)"
  exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg is required"
  exit 1
fi

run_with_display() {
  if [[ -n "${DISPLAY:-}" ]]; then
    "$@"
  else
    xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 "$@"
  fi
}

if [[ "$MODE" == "movie" ]]; then
  RAW_AVI="$OUT_DIR/raw_${STAMP}.avi"
  echo "==> Recording deterministic playtest via Godot MovieWriter (${FPS}fps, max ${MAX_FRAMES} frames)..."
  # First import assets quietly if .godot cache doesn't exist yet
  if [[ ! -d "$ROOT_DIR/client/.godot" ]]; then
    "$GODOT_BIN" --headless --path "$ROOT_DIR/client" --import --quit >/dev/null 2>&1 || true
  fi

  run_with_display "$GODOT_BIN" \
    --path "$ROOT_DIR/client" \
    --rendering-driver opengl3 \
    --resolution 1280x720 \
    --write-movie "$RAW_AVI" \
    --fixed-fps "$FPS" \
    --quit-after "$MAX_FRAMES" \
    -- --auto-playtest --auto-quit || true

  if [[ ! -s "$RAW_AVI" ]]; then
    echo "ERROR: MovieWriter produced no output at $RAW_AVI"
    exit 1
  fi

  echo "==> Transcoding to H.264 MP4 + GIF + review keyframes via ffmpeg..."
  ffmpeg -y -hide_banner -loglevel error \
    -i "$RAW_AVI" \
    -c:v libx264 -pix_fmt yuv420p -preset fast -crf 21 \
    -movflags +faststart "$MP4_OUT"

  ffmpeg -y -hide_banner -loglevel error \
    -i "$MP4_OUT" \
    -vf "fps=10,scale=640:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" \
    "$GIF_OUT"

  rm -f "$RAW_AVI"

elif [[ "$MODE" == "x11grab" ]]; then
  echo "==> Recording live playtest session via Xvfb + ffmpeg x11grab (${DURATION}s @ ${FPS}fps)..."
  XVFB_DISPLAY=":99"
  Xvfb "$XVFB_DISPLAY" -screen 0 1280x720x24 >/dev/null 2>&1 &
  XVFB_PID=$!
  trap 'kill "$XVFB_PID" 2>/dev/null || true' EXIT
  sleep 1

  DISPLAY="$XVFB_DISPLAY" LIBGL_ALWAYS_SOFTWARE=1 "$GODOT_BIN" \
    --path "$ROOT_DIR/client" \
    --rendering-driver opengl3 \
    --resolution 1280x720 \
    -- --auto-playtest --auto-quit >/dev/null 2>&1 &
  GODOT_PID=$!
  sleep 1.5

  ffmpeg -y -hide_banner -loglevel error \
    -video_size 1280x720 -framerate "$FPS" -f x11grab -i "${XVFB_DISPLAY}.0" \
    -t "$DURATION" \
    -c:v libx264 -pix_fmt yuv420p -preset fast -crf 21 \
    -movflags +faststart "$MP4_OUT"

  kill "$GODOT_PID" 2>/dev/null || true

  ffmpeg -y -hide_banner -loglevel error \
    -i "$MP4_OUT" \
    -vf "fps=10,scale=640:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer" \
    "$GIF_OUT"
else
  echo "Unknown mode: $MODE (use 'movie' or 'x11grab')"
  exit 1
fi

# Extract 4 evenly-spaced PNG keyframes for instant visual inspection
FRAMES_DIR="$OUT_DIR/keyframes_${STAMP}"
mkdir -p "$FRAMES_DIR"
ffmpeg -y -hide_banner -loglevel error -i "$MP4_OUT" -vf "fps=0.35" -frames:v 6 "$FRAMES_DIR/frame_%02d.png"

echo ""
echo "Playtest capture complete:"
echo "  MP4:       $MP4_OUT"
echo "  GIF:       $GIF_OUT"
echo "  Keyframes: $FRAMES_DIR/"
ls -lh "$MP4_OUT" "$GIF_OUT" "$FRAMES_DIR"
