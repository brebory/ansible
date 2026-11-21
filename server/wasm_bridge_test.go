package main

import (
	"context"
	"encoding/json"
	"path/filepath"
	"testing"
)

func TestSimCoreWasmBattleAndSharedSquadBridge(t *testing.T) {
	ctx := context.Background()
	wasmPath := filepath.Join("assets", "sim_core.wasm")

	bridge, err := NewSimCoreBridge(ctx, wasmPath)
	if err != nil {
		t.Fatalf("failed to load sim_core.wasm (run scripts/build_wasm.sh first): %v", err)
	}
	defer bridge.Close(ctx)

	// 1. Initialize deterministic 3v3 battle inside Rust WASM
	stateRaw, err := bridge.BattleNew(ctx, "go-wasm-test-1", 1337)
	if err != nil {
		t.Fatalf("BattleNew failed: %v", err)
	}

	var state map[string]any
	if err := json.Unmarshal(stateRaw, &state); err != nil {
		t.Fatalf("unmarshal initial state: %v", err)
	}
	if state["outcome"] != "ongoing" {
		t.Fatalf("expected ongoing outcome, got %v", state["outcome"])
	}

	// 2. Step Vega's Quickdraw against Redline Kid through WASM
	stepReq, _ := json.Marshal(map[string]any{
		"state": stateRaw,
		"action": map[string]any{
			"actor_id":  "drifter_vega",
			"skill_id":  "quickdraw",
			"target_id": "enemy_deadeye",
		},
	})
	respRaw, err := bridge.BattleStep(ctx, stepReq)
	if err != nil {
		t.Fatalf("BattleStep failed: %v", err)
	}

	var stepResp struct {
		OK     bool             `json:"ok"`
		Error  *string          `json:"error"`
		Events []map[string]any `json:"events"`
	}
	if err := json.Unmarshal(respRaw, &stepResp); err != nil {
		t.Fatalf("unmarshal BattleStep response: %v", err)
	}
	if !stepResp.OK {
		t.Fatalf("expected step OK, got error: %v", stepResp.Error)
	}
	if len(stepResp.Events) < 3 {
		t.Fatalf("expected rich turn events from Rust WASM, got %d", len(stepResp.Events))
	}

	// 3. Verify daily-capped shared squad reward via Rust WASM
	rewardReq, _ := json.Marshal(map[string]any{
		"lender_user_id":   "player_alpha",
		"borrower_user_id": "player_beta",
		"squad_power_tier": 4,
		"earned_today":     90,
		"daily_cap":        100,
	})
	rewardRaw, err := bridge.EvaluateSharedSquadReward(ctx, rewardReq)
	if err != nil {
		t.Fatalf("EvaluateSharedSquadReward failed: %v", err)
	}
	var rewardResp struct {
		Allowed            bool `json:"allowed"`
		LenderScrapGranted int  `json:"lender_scrap_granted"`
		CapReached         bool `json:"cap_reached"`
	}
	if err := json.Unmarshal(rewardRaw, &rewardResp); err != nil {
		t.Fatalf("unmarshal reward resp: %v", err)
	}
	if !rewardResp.Allowed || rewardResp.LenderScrapGranted != 10 || !rewardResp.CapReached {
		t.Fatalf("unexpected reward calculation: %+v", rewardResp)
	}
}
