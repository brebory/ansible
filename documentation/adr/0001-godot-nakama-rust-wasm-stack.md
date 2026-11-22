# ADR-0001: Godot 4 (Compatibility) + Nakama Go Runtime + Rust WASM Simulation Core

- **Status:** Accepted
- **Date:** 2026-11-21

## Context

Ansible must run smoothly in **web browsers** (desktop and mobile) as well as **native mobile devices** (iOS/Android), while supporting asynchronous multiplayer features (accounts, friends, shared Drifter Squads with server-enforced daily reward caps) and deterministic turn-based RPG combat/expedition logic authored in **Rust**.

Heroic Labs' Nakama natively supports **Go, TypeScript (Goja ES5), and Lua** server runtime modules — there is no maintained community plugin for native Rust Nakama server modules (`heroiclabs/nakama-rs` is a client SDK, and Goja cannot run WASM).

## Decision

1. **Client (`client/`):** Use **Godot 4** configured with the **Compatibility (WebGL 2.0 / OpenGL ES 3)** renderer and single-threaded HTML5 Web export (`Thread Support: off`) so builds run reliably across browsers and mobile GPUs without requiring `Cross-Origin-Isolated` headers. Client-server communication uses HTTPS + WebSockets (compatible with `heroiclabs/nakama-godot`).
2. **Simulation Core (`sim-core/`):** Author deterministic gameplay rules (turn-based battle state machine, enemy AI, expedition checks, shared-squad daily-cap reward math) in a pure Rust crate with zero OS dependencies, compiled to `wasm32-unknown-unknown`.
3. **Backend (`server/`):** Run **Nakama** with a thin **Go runtime plugin** that embeds **`wazero`** (a zero-CGo pure-Go WebAssembly runtime) to execute `sim_core.wasm`. Nakama handles authentication, WebSockets, Storage Engine, Friends/Groups, and atomic daily-cap persistence, while delegating pure game-rule evaluation to Rust.
4. **Local Playtesting & Verification:** Use **`godot-mcp-runtime`** (`Erodenn/godot-mcp-runtime`) for zero-footprint live runtime control and **Godot MovieWriter / Xvfb + `ffmpeg`** (`scripts/record_playtest.sh`) to generate reviewable playtest footage.

## Consequences

- **Pros:**
  - Single authoritative Rust simulation core with deterministic RNG and fast `cargo test` feedback.
  - Zero CGo headaches when building Nakama Go plugins inside Docker (`wazero` is pure Go).
  - Full Nakama social/auth/WebSocket ecosystem out of the box.
  - Clean offline/local fallback in the Godot client for rapid iteration and browser demos.
- **Tradeoffs:**
  - Data crosses the Go ↔ WASM boundary as UTF-8 JSON (negligible overhead for turn-based RPCs; can upgrade to binary/protobuf later if needed).
  - Client prototype mirrors the battle engine in GDScript for offline play; authoritative mode routes actions through Nakama RPCs backed by `sim_core.wasm`.
