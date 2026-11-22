# Multi-stage Dockerfile: compiles Rust sim_core.wasm + Nakama Go runtime plugin
FROM rust:1.83-bookworm AS rust-builder
RUN rustup target add wasm32-unknown-unknown
WORKDIR /build/sim-core
COPY sim-core/Cargo.toml ./
COPY sim-core/src ./src
RUN cargo build --target wasm32-unknown-unknown --release

FROM heroiclabs/nakama-pluginbuilder:3.26.0 AS go-builder
ENV GO111MODULE=on
ENV CGO_ENABLED=1
WORKDIR /backend
COPY server/go.mod server/go.sum* ./
COPY server/*.go ./
RUN go mod tidy && go build --trimpath --buildmode=plugin -o ./ansible.so

FROM heroiclabs/nakama:3.26.0
COPY --from=go-builder /backend/ansible.so /nakama/data/modules/ansible.so
COPY --from=rust-builder /build/sim-core/target/wasm32-unknown-unknown/release/ansible_sim_core.wasm /nakama/data/modules/sim_core.wasm
ENV ANSIBLE_SIM_WASM_PATH=/nakama/data/modules/sim_core.wasm
