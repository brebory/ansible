package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"sync"

	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/api"
)

// SimCoreBridge hosts the compiled Rust sim_core.wasm inside Nakama's Go runtime
// using wazero (pure Go, zero CGo). Each call is serialized per module instance.
type SimCoreBridge struct {
	mu      sync.Mutex
	runtime wazero.Runtime
	mod     api.Module
}

func NewSimCoreBridge(ctx context.Context, wasmPath string) (*SimCoreBridge, error) {
	wasmBytes, err := os.ReadFile(wasmPath)
	if err != nil {
		return nil, fmt.Errorf("read wasm %q: %w", wasmPath, err)
	}
	return NewSimCoreBridgeFromBytes(ctx, wasmBytes)
}

func NewSimCoreBridgeFromBytes(ctx context.Context, wasmBytes []byte) (*SimCoreBridge, error) {
	rt := wazero.NewRuntime(ctx)
	mod, err := rt.Instantiate(ctx, wasmBytes)
	if err != nil {
		_ = rt.Close(ctx)
		return nil, fmt.Errorf("instantiate sim_core.wasm: %w", err)
	}
	return &SimCoreBridge{
		runtime: rt,
		mod:     mod,
	}, nil
}

func (b *SimCoreBridge) Close(ctx context.Context) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.runtime.Close(ctx)
}

func (b *SimCoreBridge) callJSON(ctx context.Context, fnName string, payload []byte) ([]byte, error) {
	b.mu.Lock()
	defer b.mu.Unlock()

	allocFn := b.mod.ExportedFunction("alloc")
	deallocFn := b.mod.ExportedFunction("dealloc")
	targetFn := b.mod.ExportedFunction(fnName)
	if allocFn == nil || deallocFn == nil || targetFn == nil {
		return nil, fmt.Errorf("missing required WASM export (%s/alloc/dealloc)", fnName)
	}

	inLen := uint64(len(payload))
	allocRes, err := allocFn.Call(ctx, inLen)
	if err != nil {
		return nil, fmt.Errorf("wasm alloc(%d): %w", inLen, err)
	}
	inPtr := uint32(allocRes[0])
	defer func() {
		_, _ = deallocFn.Call(ctx, uint64(inPtr), inLen)
	}()

	if !b.mod.Memory().Write(inPtr, payload) {
		return nil, fmt.Errorf("wasm memory write out of bounds at %d (len %d)", inPtr, inLen)
	}

	res, err := targetFn.Call(ctx, uint64(inPtr), inLen)
	if err != nil {
		return nil, fmt.Errorf("wasm call %s: %w", fnName, err)
	}

	packed := res[0]
	outPtr := uint32(packed >> 32)
	outLen := uint32(packed & 0xFFFFFFFF)

	raw, ok := b.mod.Memory().Read(outPtr, outLen)
	if !ok {
		return nil, fmt.Errorf("wasm memory read out of bounds at %d (len %d)", outPtr, outLen)
	}
	outCopy := make([]byte, len(raw))
	copy(outCopy, raw)

	_, _ = deallocFn.Call(ctx, uint64(outPtr), uint64(outLen))
	return outCopy, nil
}

func (b *SimCoreBridge) BattleNew(ctx context.Context, battleID string, seed uint64) (json.RawMessage, error) {
	req, err := json.Marshal(map[string]any{
		"battle_id": battleID,
		"seed":      seed,
	})
	if err != nil {
		return nil, err
	}
	out, err := b.callJSON(ctx, "wasm_battle_new", req)
	if err != nil {
		return nil, err
	}
	return json.RawMessage(out), nil
}

func (b *SimCoreBridge) BattleStep(ctx context.Context, stepReqJSON []byte) (json.RawMessage, error) {
	out, err := b.callJSON(ctx, "wasm_battle_step", stepReqJSON)
	if err != nil {
		return nil, err
	}
	return json.RawMessage(out), nil
}

func (b *SimCoreBridge) EvaluateSharedSquadReward(ctx context.Context, reqJSON []byte) (json.RawMessage, error) {
	out, err := b.callJSON(ctx, "wasm_shared_squad_reward", reqJSON)
	if err != nil {
		return nil, err
	}
	return json.RawMessage(out), nil
}
