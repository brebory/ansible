# Playtesting & Video Capture Guide

Ansible ships with two complementary agent/human playtesting layers modeled after `snackpackgames/fiber`:

## 1. Live Interactive Runtime Control (`godot-mcp-runtime`)

[`.mcp.json`](../.mcp.json) configures [`Erodenn/godot-mcp-runtime`](https://github.com/Erodenn/godot-mcp-runtime) (`npx -y godot-mcp-runtime`) with zero-footprint transient bridge injection (nothing committed into `client/addons/`).

### Quick Verification
```bash
bash scripts/setup_mcp.sh
```

### Driving the Battle Prototype via MCP
1. Launch the project: `run_project` pointing at `client/`.
2. Inspect visible Neon Spaghetti Western HUD controls via UI discovery (`SaloonCommandDeck`, `SkillButton_0`..`SkillButton_3`, `TargetBtn_*`, `FireActionButton`, `RecolorSquadButton`).
3. Click skills/targets, toggle shader palettes (`RecolorSquadButton` / `R`), inspect live `BattleEngine` state via `run_script`, and take screenshots.
4. Call `stop_project` when done — `.mcp/` cleans itself up automatically.

## 2. Automated Playtest Video Capture (`ffmpeg` + Godot MovieWriter / Xvfb)

Use [`scripts/record_playtest.sh`](../scripts/record_playtest.sh) to capture reviewable H.264 `.mp4`, `.gif`, and PNG keyframes under `playtest-captures/` (gitignored).

### Deterministic Capture (Recommended for CI & Headless Review)
Uses Godot's `--write-movie` (`--fixed-fps`) driven by [`AutoPlaytestDriver`](../client/scripts/playtest/auto_playtest_driver.gd) (`--auto-playtest --auto-quit`), then transcodes via `ffmpeg`:

```bash
bash scripts/record_playtest.sh --mode movie --fps 20 --max-frames 520
```

### Live Display / Xvfb Capture (For Live `godot-mcp-runtime` Sessions)
Captures a real-time Xvfb display stream via `ffmpeg -f x11grab`:

```bash
bash scripts/record_playtest.sh --mode x11grab --duration 20 --fps 24
```
