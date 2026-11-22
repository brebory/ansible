# Ansible

> A **neon spaghetti western** base-building space exploration RPG — staff and grow a lonely frontier outpost (an **Ansible**), send human and alien **Drifters** on roguelike **Expeditions** across a fog-of-war **Star Map**, fight PlayStation-era Final Fantasy cinematic turn-based line-up battles, and share **Drifter Squads** asynchronously with other players for daily-capped cooperative rewards.

## What's In This Repo

- **`client/`** — **Godot 4** (Compatibility / WebGL2 renderer for Browser & Mobile) playable **Turn-Based Battle Vertical Slice**:
  - 3v3 PS1-era Final Fantasy line-up combat with cinematic camera choreography (`Establishing Sweep`, `Over-Shoulder Command`, `Deadeye Target Lock`, `Dutch-Angle Action Cut-In`, `Impact Shake`, `Victory Orbit`)
  - Procedural low-poly 3D Human (`Vega Vance`), Chitinoid (`Krix-9`), and Vexari (`Syl Ora`) Drifters + frontier outlaws with a **4-channel recolorable shader** (`[R]` live palette switcher)
  - **Neon Spaghetti Western** holographic HUD (notched western frames, scanline shader, Wanted Turn Order timeline, Saloon Command Deck, floating 3D-projected damage/crit/status popups)
  - WebSocket-capable Nakama adapter with instant local deterministic fallback
- **`sim-core/`** — Deterministic **Rust** simulation core compiled to `wasm32-unknown-unknown` implementing the canonical `Upkeep → Pre-Exec Validation → Pre-Exec Triggers → Execute → Post-Exec Validation → Post-Exec Triggers → EndTurn` battle pipeline and server-authoritative shared-squad daily-cap reward math.
- **`server/`** — **Nakama Go runtime plugin** embedding **`wazero`** (pure-Go WebAssembly runtime) to execute `sim_core.wasm` for authoritative battle RPCs and async shared Drifter Squad rewards.
- **Playtesting & Video Capture** — Configured with **`godot-mcp-runtime`** (`.mcp.json`) and **`scripts/record_playtest.sh`** (Godot MovieWriter / Xvfb + `ffmpeg`) to record reviewable MP4, GIF, and PNG keyframe footage.
- **Wayfinder Maps** — All 7 major feature pillars are charted as `afk-implementation` Wayfinder Maps in GitHub Issues; see [documentation/wayfinder/maps-index.md](documentation/wayfinder/maps-index.md).

## Quickstart

```bash
# 1. Run all automated tests (Rust + WASM + Go wazero bridge + Godot headless)
bash scripts/test.sh

# 2. Record automated playtest footage (MP4 + GIF + PNG keyframes)
bash scripts/record_playtest.sh

# 3. Boot local Nakama + PostgreSQL + Go/WASM server
docker compose up --build

# 4. Wire Wayfinder labels, native sub-issues, and blocked_by edges on GitHub (run once locally)
bash scripts/wire_wayfinder_github.sh
```

## Controls (Battle Prototype)

- **`1`–`4` or Click**: Select skill on the Saloon Command Deck
- **`A`/`D` or `←`/`→` or Click target chip**: Cycle enemy/ally target
- **`Enter` / `Space` / `★ DRAW`**: Execute action
- **`R` or `[R] SHADER` button**: Cycle the 4-channel recolorable Drifter shader presets live
- **`F9`**: Toggle `AutoPlaytestDriver` hands-free demo mode
