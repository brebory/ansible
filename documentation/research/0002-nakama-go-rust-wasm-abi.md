# Research: Nakama Go + Rust WASM (`wazero` vs. `extism`) Runtime ABI & Dev Workflow

- **Parent Map:** [Map: Core Architecture, Nakama + Rust WASM Backend & Web/Mobile Pipeline](https://github.com/snackpackgames/ansible/issues/1)
- **Ticket:** [[Research] Nakama Go + Rust WASM (wazero/extism) runtime ABI and dev workflow](https://github.com/snackpackgames/ansible/issues/2)
- **Date:** 2026-11-21
- **Status:** Complete (ready for ticket resolution)

---

## Executive Recommendation

| Decision Area | Recommended Choice | Key Rationale |
|---|---|---|
| **WASM Runtime** | **Raw `wazero` (`github.com/tetratelabs/wazero`)** over `extism/go-sdk` | Pure Go (zero CGO), single external dep (`golang.org/x/sys`) minimizing Nakama `-buildmode=plugin` dependency-pinning conflicts, actively maintained (`v1.12.0`), zero guest host-kernel lock-in. |
| **Rust Target** | **`wasm32-unknown-unknown`** (no WASI) | Structurally enforces determinism at link time: zero WASI host imports (no clocks, filesystem, env, or OS RNG possible). |
| **Guest/Host ABI** | **3-export linear-memory ABI** (`alloc`, `dealloc`, `sim_dispatch`) with packed `u64` `(ptr << 32) \| len` | ~40 LOC Rust + ~80 LOC Go; no host callbacks needed (Nakama Go performs all DB/Storage/Wallet I/O around pure simulation calls). |
| **Wire Serialization** | **UTF-8 JSON** (`serde_json` ↔ `encoding/json` / `json.RawMessage`) | Matches Nakama Storage (`jsonb`) and Nakama RPC JSON payloads natively; enables zero-translation pass-through in Go and human-readable golden replay fixtures; swappable to MessagePack (`rmp-serde`) later without touching `sim-core`. |
| **Deterministic RNG** | **`rand_chacha::ChaCha8Rng`** (pinned in `Cargo.lock`) with explicit `(seed_hex, stream, word_pos)` cursor | Documented portable & deterministic across platforms/targets; avoids non-portable `StdRng`/`SmallRng`; supports independent sub-streams (`set_stream`) and clean JSON persistence. |
| **Concurrency & Isolation** | **Single `wazero.CompiledModule` + bounded instance pool (`sync.Pool` / channel pool)** + `WithMemoryLimitPages` + `WithCloseOnContextDone(true)` | `CompiledModule` is goroutine-safe and AOT-compiled once in `InitModule`; each `api.Module` instance is single-threaded and memory/timeout-capped so guest bugs cannot stall or crash Nakama. |
| **Local Dev Workflow** | **Docker Compose (`postgres` + `nakama`) + disk-loaded `.wasm` hot-reload in dev; `//go:embed` in release** | Go plugins (`.so`) cannot be unloaded without restarting Nakama, but `wazero` can recompile and atomically swap a rebuilt `.wasm` file in ~50–150 ms with zero Nakama restart. |
| **Testing Strategy** | **3 independent layers**: native `cargo test -p sim-core`, Go `go test ./server/simbridge/...` (cross-target determinism), and Nakama RPC integration tests | Tests Rust logic in milliseconds and verifies byte-for-byte parity between 64-bit native Rust and 32-bit `wasm32` execution without Docker. |

---

## 1. Runtime Comparison: `wazero` vs. `extism/go-sdk`

### Why Nakama Go Plugin Constraints Decide This Choice

Nakama loads Go runtime modules via Go's `-buildmode=plugin` shared objects (`.so`) ([Heroic Labs: Go Runtime](https://heroiclabs.com/docs/nakama/server-framework/go-runtime/)). Heroic Labs' [Go Module Dependency Pinning](https://heroiclabs.com/docs/nakama/server-framework/go-runtime/go-dependencies/) documentation highlights three strict failure modes at `plugin.Open`:

1. **Platform mismatch:** The `.so` must be built for the exact target OS/arch (Windows cannot natively build Linux Go plugins; Docker is required).
2. **Go toolchain version mismatch:** The plugin must be compiled with the **exact same Go version** as the Nakama binary (guaranteed by matching `heroiclabs/nakama-pluginbuilder:<VER>` and `heroiclabs/nakama:<VER>` tags). As of Nakama `3.37.0` / `nakama-common v1.49.0`, Nakama builds with Go `1.27.1` ([Nakama Release Notes](https://heroiclabs.com/docs/nakama/getting-started/release-notes/), [`heroiclabs/nakama-common`](https://github.com/heroiclabs/nakama-common)).
3. **Direct & transitive dependency version mismatch:** *Every* Go package imported directly or indirectly by the plugin that is also imported by Nakama itself must match Nakama's exact version in `vendor/modules.txt`, or Nakama fails fast on startup (`plugin was built with a different version of package ...`).

### Head-to-Head Matrix

| Criterion | Raw `wazero` (`github.com/tetratelabs/wazero`) | `extism/go-sdk` (`github.com/extism/go-sdk`) + `extism-pdk` |
|---|---|---|
| **Underlying Engine** | Pure Go WebAssembly Core 1.0/2.0 runtime (AOT `Compiler` on `amd64`/`arm64`, `Interpreter` fallback), zero CGO ([pkg.go.dev/wazero](https://pkg.go.dev/github.com/tetratelabs/wazero)). | Wraps `wazero` (also zero CGO), plus embeds an extra `extism-runtime.wasm` kernel module ([`extism/go-sdk`](https://github.com/extism/go-sdk)). |
| **Maintenance & Go Support** | Actively maintained (`v1.12.0`, May 2026); tracks Go's 2-release support policy ([wazero Releases](https://github.com/tetratelabs/wazero/releases)). | Last commit on `main` was May 2025 (`de6f8ac`), pinning `wazero v1.9.0` ([`extism/go-sdk`](https://github.com/extism/go-sdk)). |
| **Go Dependency Surface (Nakama Pinning Risk)** | **1 external dependency**: `golang.org/x/sys` (added in `v1.11.0`; previously zero) ([wazero Releases](https://github.com/tetratelabs/wazero/releases), [pkg.go.dev/wazero](https://pkg.go.dev/github.com/tetratelabs/wazero)). Pinning one package against Nakama's `vendor/modules.txt` is trivial. | Larger transitive surface (`wazero` pinned older, Dylibso Observe SDK hooks, manifest/HTTP helpers) — higher risk of `plugin.Open` transitive conflicts and stale `wazero` compatibility with newer Go toolchains. |
| **Guest Coupling & Portability** | Guest compiles to bare `wasm32-unknown-unknown` with **zero host imports**. The exact same `.wasm` binary can run in Go, browser JS/WebGL2, or any Wasm runtime. | Guest depends on `extism-pdk` (`#[plugin_fn]`) and imports `extism:host/env` functions ([`docs.rs/extism-pdk`](https://docs.rs/extism-pdk/latest/extism_pdk/)). Cannot run outside an Extism host without rewriting exports. |
| **ABI Boilerplate** | ~40 LOC Rust (`sim-wasm`) + ~80 LOC Go (`simbridge`) written once. | Zero manual pointer/length glue (`#[plugin_fn]` + `Json<T>` / `Msgpack<T>` / `Prost<T>` + `plugin.Call(name, bytes)`). |
| **Concurrency Model** | `CompiledModule` shared across goroutines; instantiate anonymous `api.Module` instances into a pool ([pkg.go.dev/wazero](https://pkg.go.dev/github.com/tetratelabs/wazero)). | `NewCompiledPlugin` (added `v1.7.0`) -> `compiled.Instance(...)` per goroutine/pool ([pkg.go.dev/extism/go-sdk](https://pkg.go.dev/github.com/extism/go-sdk)); note cache lifetime caveat ([issue #97](https://github.com/extism/go-sdk/issues/97)). |
| **Best Fit** | First-party deterministic simulation core with pure `bytes -> bytes` dispatch and no guest-to-host callbacks. | Hosting untrusted, polyglot third-party user plugins needing host HTTP/KV callbacks ([Extism FAQs](https://extism.org/docs/questions/)). |

**Verdict:** Use **raw `wazero`** directly. Extism's primary value proposition (polyglot third-party plugin SDKs + host HTTP/KV/var abstractions) solves a problem Ansible does not have, while introducing an older pinned `wazero`, extra transitive Go dependencies inside Nakama's sensitive `-buildmode=plugin` loader, and guest lock-in to `extism-runtime.wasm`.

---

## 2. Architecture & Minimal Linear-Memory ABI

### Crate & Package Boundary (Zero Coupling Between Domain Logic and Hosts)

```text
ansible/
├── sim/
│   ├── Cargo.toml               # Rust workspace
│   ├── Cargo.lock               # Committed! Pins rand_chacha & serde versions
│   ├── sim-core/                # Pure deterministic Rust library (#![forbid(unsafe_code)])
│   │   └── src/                 #   Domain state, combat/expedition/outpost reducers, RNG cursor
│   └── sim-wasm/                # Thin cdylib wrapper (~50 LOC), target: wasm32-unknown-unknown
│       └── src/lib.rs           #   ONLY exports: alloc, dealloc, sim_dispatch
└── server/
    ├── go.mod / vendor/         # Pinned to Nakama's exact nakama-common & golang.org/x/sys
    ├── simbridge/               # Pure Go package (NO nakama-common imports!)
    │   ├── bridge.go            #   wazero Runtime, CompiledModule, instance pool, hot-reload
    │   └── bridge_test.go       #   Runs golden JSON vectors against compiled .wasm via `go test`
    ├── main.go                  # Nakama InitModule: wires simbridge + registers RPCs/hooks
    └── rpc_*.go                 # Thin Nakama handlers: auth, StorageRead/Write, call simbridge
```

### Why `wasm32-unknown-unknown` (No WASI)

Per the official [rustc `wasm32-unknown-unknown` target docs](https://doc.rust-lang.org/rustc/platform-support/wasm32-unknown-unknown.html), this minimal target provides full `core` and `alloc` support while making zero assumptions about OS syscalls (`std::fs` always errors, `println!` is a no-op, `std::thread::spawn` panics). Because `sim-wasm` emits **zero imports** and `simbridge` does **not** instantiate `wasi_snapshot_preview1`, any accidental dependency that tries to read wall-clock time, OS entropy (`getrandom`), or files either fails to compile or fails validation immediately at `CompileModule` time.

### The 3-Export ABI Specification

All simulation calls follow a single pure functional contract:

$$\text{sim\_dispatch}(\text{RequestEnvelope JSON bytes}) \longrightarrow \text{ResponseEnvelope JSON bytes}$$

#### Rust Guest (`sim-wasm/src/lib.rs`)

- **`alloc(len: u32) -> u32`**: Allocates a `Vec<u8>` with capacity `len`, returns its pointer (`u32`), and transfers ownership to the host via `std::mem::forget`.
- **`dealloc(ptr: u32, len: u32)`**: Reconstructs `Vec::from_raw_parts(ptr as *mut u8, 0, len as usize)` and drops it (matching the exact capacity allocated).
- **`sim_dispatch(in_ptr: u32, in_len: u32) -> u64`**:
  1. Reads input slice `&[u8]` from `(in_ptr, in_len)` (does *not* free the input buffer; host calls `dealloc` in a `defer`, avoiding double-free ambiguity).
  2. Deserializes `RequestEnvelope` via `serde_json::from_slice`, dispatches into `sim_core::handle(req)`, and serializes `ResponseEnvelope` (including structured domain errors as JSON `{"ok": false, "error": {...}}` rather than panicking/trapping).
  3. Converts the output `Vec<u8>` with `into_boxed_slice()` (so `len == cap`, guaranteeing safe reconstruction in `dealloc`!), leaks pointer via `Box::into_raw`, and returns packed `((out_ptr as u64) << 32) | (out_len as u64)`.
  4. Configure `panic = "abort"` in `[profile.release]` for `sim-wasm` to shrink binary size; if a bug ever triggers a WASM trap, the Go host discards the trapped instance from the pool and instantiates a fresh one.

> **Allocation Safety Note:** Always use `into_boxed_slice()` for returned buffers (or store exact `(ptr, cap)`) so `len == capacity` when the host later calls `dealloc(out_ptr, out_len)`. Passing `len != capacity` to `Vec::from_raw_parts` is undefined behavior in Rust (note wazero's own Rust allocation example had to fix this exact bug in [#2327](https://github.com/tetratelabs/wazero/releases)).

#### Go Host (`server/simbridge/bridge.go`)

1. **Startup (`NewBridge`)**:
   - Create one `wazero.Runtime` using `wazero.NewRuntimeConfigCompiler()` (AOT native machine code on `amd64`/`arm64`, 10x+ faster than interpreter; [pkg.go.dev/wazero](https://pkg.go.dev/github.com/tetratelabs/wazero)):
     - `.WithCompilationCache(cache)` (optional `NewCompilationCacheWithDir` in dev for fast restarts)
     - `.WithMemoryLimitPages(256)` (16 MiB cap per instance at 64 KiB/page)
     - `.WithCloseOnContextDone(true)` (terminates runaway loops when RPC context times out; [`context_done_example_test.go`](https://github.com/tetratelabs/wazero/blob/main/context_done_example_test.go))
   - Call `r.CompileModule(ctx, wasmBytes)` **once** centrally (wazero docs explicitly warn against compiling the same module concurrently from multiple goroutines).
2. **Concurrency & Pooling**:
   - WebAssembly Core 1.0/2.0 modules are strictly single-threaded ([wazero Languages](https://wazero.io/languages/)). Never share an `api.Module` across concurrent Nakama RPC goroutines.
   - Maintain a bounded worker pool (e.g., buffered channel `chan *simInstance` of size `runtime.GOMAXPROCS(0) * 2`, lazily instantiated with `wazero.NewModuleConfig().WithName("")` and `WithStartFunctions()`).
   - For each call:
     1. Acquire an instance from the pool under `ctx` (with e.g. `context.WithTimeout(ctx, 2*time.Second)`).
     2. `alloc(inLen)` → `mod.Memory().Write(inPtr, reqBytes)` → `defer dealloc(inPtr, inLen)`.
     3. `packed := sim_dispatch(inPtr, inLen)` → unpack `outPtr = uint32(packed >> 32)`, `outLen = uint32(packed)` → copy bytes via `mod.Memory().Read(outPtr, outLen)` (copy out of linear memory before freeing!) → `dealloc(outPtr, outLen)`.
     4. **Health check before returning to pool:** If the call returned a WASM trap/context-cancel error, OR `mod.Memory().Size() > maxRetainedBytes` (e.g., 8 MiB), close and discard the instance instead of returning it to the pool so memory never balloons over weeks of uptime.

---

## 3. Serialization: JSON vs. Binary

### Why JSON Is the Right Default for Ansible

1. **Native Nakama Storage alignment:** Nakama's Storage Engine stores every object value as JSON (`jsonb` in PostgreSQL) ([Heroic Labs: Storage Engine](https://heroiclabs.com/docs/nakama/concepts/storage/)).
2. **Native Nakama RPC alignment:** Nakama RPCs transmit JSON string payloads by default over HTTP/gRPC/WebSocket ([Heroic Labs: Server To Server](https://heroiclabs.com/docs/nakama/server-framework/runtime-examples/server-to-server/)).
3. **Zero-translation pass-through in Go:** Because both Nakama Storage and Nakama RPCs already speak JSON, Nakama Go does **not** need to mirror or re-marshal every Rust game entity struct. Go can pass `json.RawMessage` (the stored state blob + client action JSON) directly inside the `RequestEnvelope` to `sim-wasm`, inspect only the small envelope header/delta returned by Rust (e.g., `next_state`, `wallet_delta`, `public_events`), and write `next_state` straight back to Nakama Storage with conditional version checks ([Collections: Conditional Writes](https://heroiclabs.com/docs/nakama/concepts/storage/collections/)). Rust remains the **single source of truth** for game schemas.
4. **Turn-based workload fit:** Map #1 explicitly rules out real-time twitch/physics synchronization (where Heroic Labs recommends Protobuf/FlatBuffers under the 1500-byte MTU; [Authoritative Multiplayer](https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/)). Ansible RPC payloads (a combat turn, expedition node resolution, or outpost tick) are small (~1–50 KB) and low-frequency; `serde_json` parses/serializes 50 KB in sub-millisecond time inside AOT-compiled `wazero`.
5. **Golden replayability & debugging:** Any production bug or desync can be captured as a plain-text JSON request envelope and committed directly as a regression fixture in `sim-core/tests/fixtures/`.

### Envelope & Schema Hygiene Rules

- **Versioned envelope:** Every request/response carries `"schema_version": 1` and `"op": "<command_name>"`.
- **64-bit integer safety for HTML5/Godot web clients:** Encode 64-bit IDs, timestamps, or seeds as strings (or keep gameplay numbers within `i32`/`u32`) so JavaScript/JSON parsers never lose precision beyond IEEE-754 $2^{53}-1$.
- **Deterministic JSON output:** Use `BTreeMap` (never `HashMap`) in Rust structs so serialized JSON keys always emit in identical lexicographical order across runs and platforms.
- **Upgrade path to binary:** Because `sim-wasm` is a ~50-line adapter over `sim-core`'s `serde` types, switching the Go↔WASM boundary to MessagePack (`rmp-serde` ↔ `vmihailenco/msgpack/v5`) or Protobuf (`prost`) later requires changing only `sim-wasm` and `simbridge`, with zero changes to `sim-core`.

---

## 4. Deterministic RNG Seeding & Cross-Platform Determinism

### PRNG Selection & Pinning

Per [The Rust Rand Book — Reproducibility](https://rust-random.github.io/book/crate-reprod.html):
- **`rand::rngs::StdRng` and `SmallRng` are explicitly declared non-portable** (permitted to change output values across platforms and releases). **Do not use them in `sim-core`.**
- **`rand_chacha::ChaCha8Rng` (or `ChaCha12Rng`)** is explicitly documented as **deterministic and portable**, verified against reference test vectors ([`docs.rs/rand_chacha`](https://docs.rs/rand_chacha)).
- **Version pinning requirement:** The Rand Book notes that *minor* releases of `rand` crates may introduce value-breaking changes to distributions. Therefore:
  1. Commit `Cargo.lock` and treat upgrades to `rand_chacha`, `rand_core`, and `rand` as schema-versioned changes.
  2. Guard determinism with permanent golden test vectors in `sim-core` (e.g., asserting fixed outputs for a fixed seed + action sequence).

### Explicit RNG Cursor Pattern

`ChaCha8Rng` exposes direct state inspection and seeking ([`ChaCha8Rng` docs](https://docs.rs/rand_chacha/latest/rand_chacha/struct.ChaCha8Rng.html)):
- `get_seed() -> [u8; 32]` / `ChaCha8Rng::from_seed([u8; 32])`
- `get_stream() -> u64` / `set_stream(u64)` ($2^{64}$ independent streams per seed)
- `get_word_pos() -> u128` / `set_word_pos(u128)` (68-bit word offset into the 1 ZiB stream)

**Recommended flow:**
1. When an expedition or battle begins, **Nakama Go** generates a cryptographically random 32-byte seed (`crypto/rand`) and persists an explicit `RngCursor { seed_hex: String, stream: u64, word_pos: String }` inside the authoritative state in Nakama Storage.
2. Each `sim_dispatch` call reconstructs `ChaCha8Rng` from `RngCursor`, executes the turn/node, and returns the updated `RngCursor` (`get_word_pos()`) inside `next_state`.
3. Use `set_stream(...)` to partition independent subsystems (e.g., stream `0` = star map generation, stream `1` = combat resolution, stream `2` = loot/vagrant rolls) so balance tweaks in one subsystem do not shift RNG rolls in another.

### Five Strict Determinism Invariants for `sim-core`

1. **Integer / fixed-point math only (no `f32`/`f64` in simulation state or formulas):** WebAssembly Core 3.0 specifies IEEE-754 round-to-nearest-even for basic float ops, but NaN sign/payload bits remain non-deterministic outside the deterministic profile ([Wasm Spec: Numerics](https://webassembly.github.io/spec/core/exec/numerics.html), [Profiles](https://webassembly.github.io/spec/core/appendix/profiles.html)), and Rust `std` transcendental math (`sin`, `powf`, etc.) varies by platform ([Rust Rand Book](https://rust-random.github.io/book/crate-reprod.html)). Use `i32`/`i64`/`u32`/`u64` and integer basis points (`10_000 = 100.00%`).
2. **Never sample `usize`/`isize`:** Native test hosts are 64-bit while `wasm32-unknown-unknown` is 32-bit. Always sample explicit `u32`/`u64` bounds ([Rust Rand Book: Portability of `usize`](https://rust-random.github.io/book/crate-reprod.html)).
3. **Never iterate `HashMap`/`HashSet`:** Use `BTreeMap`/`BTreeSet` or explicitly sorted `Vec`s.
4. **Zero ambient I/O or clocks:** Pass `server_unix_ms: i64` and all player/world context explicitly in `RequestEnvelope`.
5. **Enforce `#![forbid(unsafe_code)]` in `sim-core`:** Confine the tiny `unsafe` FFI slice conversion exclusively to `sim-wasm/src/lib.rs`.

---

## 5. Local Dev Workflow, Hot-Reload & Docker Compose

### Why `.wasm` Hot-Reload Eliminates Go Plugin Rebuild Friction

Go's `plugin.Open` cannot unload a `.so` file without restarting Nakama. However, because game logic lives in Rust (`sim-wasm`) and Go (`server/*.go`) is a thin transport/storage shell, **most day-to-day iterations never touch Go at all**:

- **Dev mode (`ANSIBLE_WASM_PATH=/nakama/data/wasm/sim_wasm.wasm`, `ANSIBLE_DEV_HOT_RELOAD=true`):**
  1. `docker-compose.yml` runs `postgres:16.8-alpine` and `registry.heroiclabs.com/heroiclabs/nakama:<VER>` (matching [Heroic Labs Docker Compose docs](https://heroiclabs.com/docs/nakama/getting-started/install/docker/)).
  2. Host directories `./build/modules` (containing `backend.so`) and `./build/wasm` (containing `sim_wasm.wasm`) are bind-mounted into `/nakama/data/modules` and `/nakama/data/wasm`.
  3. Developer edits Rust in `sim-core` and runs `cargo build --target wasm32-unknown-unknown -p sim-wasm` (or `cargo watch`) and copies/outputs to `./build/wasm/sim_wasm.wasm` (atomic rename via temp file).
  4. `simbridge` detects the file mtime/SHA-256 change (or receives a dev-only `dev_reload_sim` RPC), compiles the new `CompiledModule` in the background (~50–150 ms), and swaps an `atomic.Pointer[activeModule]` holding the compiled module + fresh pool. In-flight RPCs finish on the old module; new RPCs immediately execute the new Rust code — **no Go rebuild, no Docker rebuild, no Nakama restart, no Godot client reconnect.**
  5. Mount a named Docker volume at `/tmp/wazero-cache` and pass `wazero.NewCompilationCacheWithDir("/tmp/wazero-cache")` so Nakama restarts skip AOT recompilation when the `.wasm` hasn't changed.
- **When Go glue changes:** Run a one-shot `docker compose run --rm pluginbuilder` container (`registry.heroiclabs.com/heroiclabs/nakama-pluginbuilder:<VER>`) to rebuild `./build/modules/backend.so` with `CGO_ENABLED=1 go build --trimpath --mod=vendor --buildmode=plugin -o /out/backend.so`, then `docker compose restart nakama`.
- **Production / Heroic Cloud builds:** Use a multi-stage `Dockerfile` (Stage 1: Rust compiles `sim_wasm.wasm`; Stage 2: `nakama-pluginbuilder:<VER>` embeds `sim_wasm.wasm` via `//go:embed` into `backend.so` when `-tags=embedwasm` is set; Stage 3: `nakama:<VER>`). Embedding `.wasm` in release builds makes the plugin a single self-contained `.so`, which is also compatible with [Heroic Cloud Builders](https://heroiclabs.com/docs/heroic-cloud/concepts/titles/builders/) if Heroic Cloud is chosen later.

---

## 6. Independent Unit Testing Strategy

| Test Layer | Command | Requires Docker / Nakama? | What It Proves |
|---|---|---|---|
| **1. Pure Rust Unit & Golden Replay Tests** | `cargo test -p sim-core` | No | Combat/expedition/outpost mechanics, edge cases, `ChaCha8Rng` golden vectors, `BTreeMap` serialization invariants. Runs in milliseconds. |
| **2. Go↔WASM Bridge & Cross-Target Determinism Tests** | `cargo build --release --target wasm32-unknown-unknown -p sim-wasm && go test -race ./server/simbridge/...` | No | ABI memory safety (`alloc`/`dealloc`), concurrent goroutine pool safety (`-race`), timeout/trap recovery (`WithCloseOnContextDone`), memory cap (`WithMemoryLimitPages`), and **byte-for-byte output parity** between native 64-bit `cargo test` golden outputs and 32-bit `wasm32` execution in `wazero`. |
| **3. Nakama RPC & Storage Integration Tests** | `go test ./server/...` (mocked `runtime.NakamaModule`) + `docker compose` smoke suite | Mocked unit tests: No; E2E smoke: Yes | Verifies `backend.so` loads cleanly via `plugin.Open` (catching Go/dep version mismatches in CI!), auth guards, Nakama Storage conditional writes, and live WebSocket/HTTP RPC round-trips. |

---

## 7. Primary Sources Cited

- Heroic Labs, *Go Runtime*: https://heroiclabs.com/docs/nakama/server-framework/go-runtime/
- Heroic Labs, *Go Module Dependency Pinning*: https://heroiclabs.com/docs/nakama/server-framework/go-runtime/go-dependencies/
- Heroic Labs, *Install Nakama with Docker Compose*: https://heroiclabs.com/docs/nakama/getting-started/install/docker/
- Heroic Labs, *Nakama Release Notes*: https://heroiclabs.com/docs/nakama/getting-started/release-notes/
- Heroic Labs, *Storage Engine & Collections*: https://heroiclabs.com/docs/nakama/concepts/storage/ and https://heroiclabs.com/docs/nakama/concepts/storage/collections/
- Heroic Labs, *Server-to-Server RPCs* & *Authoritative Multiplayer*: https://heroiclabs.com/docs/nakama/server-framework/runtime-examples/server-to-server/ and https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/
- Heroic Labs, *Heroic Cloud Builders*: https://heroiclabs.com/docs/heroic-cloud/concepts/titles/builders/
- `heroiclabs/nakama-common` repository: https://github.com/heroiclabs/nakama-common
- `wazero` Go package docs (`v1.12.0`): https://pkg.go.dev/github.com/tetratelabs/wazero
- `wazero` Releases (incl. `v1.11.0` `golang.org/x/sys` note & Rust dealloc fix `#2327`): https://github.com/tetratelabs/wazero/releases
- `wazero` Concurrency & Compiler architecture: https://wazero.io/languages/ and https://wazero.io/docs/how_do_compiler_functions_work/
- `wazero` Context termination example (`WithCloseOnContextDone`): https://github.com/tetratelabs/wazero/blob/main/context_done_example_test.go
- `extism/go-sdk` repository & Go package docs: https://github.com/extism/go-sdk and https://pkg.go.dev/github.com/extism/go-sdk
- Extism FAQs & `extism-pdk` Rust docs: https://extism.org/docs/questions/ and https://docs.rs/extism-pdk/latest/extism_pdk/
- The rustc Book, `wasm32-unknown-unknown`: https://doc.rust-lang.org/rustc/platform-support/wasm32-unknown-unknown.html
- The Rust Rand Book, *Reproducibility*: https://rust-random.github.io/book/crate-reprod.html
- `rand_chacha` & `ChaCha8Rng` API docs: https://docs.rs/rand_chacha and https://docs.rs/rand_chacha/latest/rand_chacha/struct.ChaCha8Rng.html
- WebAssembly Core 3.0 Specification (*Numerics* & *Deterministic Profile*): https://webassembly.github.io/spec/core/exec/numerics.html and https://webassembly.github.io/spec/core/appendix/profiles.html
