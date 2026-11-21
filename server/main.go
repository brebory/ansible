package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/heroiclabs/nakama-common/runtime"
)

const (
	collectionBattles      = "ansible_battles"
	collectionSharedSquads = "ansible_shared_squads"
	collectionDailyRewards = "ansible_coop_daily"
	defaultDailyScrapCap   = 100
)

var simBridge *SimCoreBridge

// InitModule is the Nakama Go runtime plugin entrypoint.
func InitModule(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, initializer runtime.Initializer) error {
	wasmPath := os.Getenv("ANSIBLE_SIM_WASM_PATH")
	if wasmPath == "" {
		wasmPath = "/nakama/data/modules/sim_core.wasm"
	}

	bridge, err := NewSimCoreBridge(ctx, wasmPath)
	if err != nil {
		return fmt.Errorf("failed to initialize Rust sim_core WASM bridge: %w", err)
	}
	simBridge = bridge

	if err := initializer.RegisterRpc("ansible_battle_start", rpcBattleStart); err != nil {
		return err
	}
	if err := initializer.RegisterRpc("ansible_battle_step", rpcBattleStep); err != nil {
		return err
	}
	if err := initializer.RegisterRpc("ansible_shared_squad_publish", rpcSharedSquadPublish); err != nil {
		return err
	}
	if err := initializer.RegisterRpc("ansible_shared_squad_borrow", rpcSharedSquadBorrow); err != nil {
		return err
	}

	logger.Info("Ansible Nakama Go + Rust WASM runtime module initialized (wasm=%s)", wasmPath)
	return nil
}

func rpcBattleStart(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, payload string) (string, error) {
	userID, ok := ctx.Value(runtime.RUNTIME_CTX_USER_ID).(string)
	if !ok || userID == "" {
		return "", runtime.NewError("authentication required", 16)
	}

	var req struct {
		BattleID string `json:"battle_id"`
		Seed     uint64 `json:"seed"`
	}
	if payload != "" {
		_ = json.Unmarshal([]byte(payload), &req)
	}
	if req.BattleID == "" {
		req.BattleID = fmt.Sprintf("battle_%d", time.Now().UnixNano())
	}
	if req.Seed == 0 {
		req.Seed = uint64(time.Now().UnixNano())
	}

	stateJSON, err := simBridge.BattleNew(ctx, req.BattleID, req.Seed)
	if err != nil {
		return "", runtime.NewError(err.Error(), 13)
	}

	_, err = nk.StorageWrite(ctx, []*runtime.StorageWrite{{
		Collection:      collectionBattles,
		Key:             req.BattleID,
		UserID:          userID,
		Value:           string(stateJSON),
		PermissionRead:  1,
		PermissionWrite: 0, // Server-authoritative
	}})
	if err != nil {
		return "", runtime.NewError("failed to persist battle state", 13)
	}
	return string(stateJSON), nil
}

func rpcBattleStep(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, payload string) (string, error) {
	userID, ok := ctx.Value(runtime.RUNTIME_CTX_USER_ID).(string)
	if !ok || userID == "" {
		return "", runtime.NewError("authentication required", 16)
	}

	var req struct {
		BattleID string          `json:"battle_id"`
		Action   json.RawMessage `json:"action"`
	}
	if err := json.Unmarshal([]byte(payload), &req); err != nil || req.BattleID == "" {
		return "", runtime.NewError("invalid battle_step payload", 3)
	}

	objs, err := nk.StorageRead(ctx, []*runtime.StorageRead{{
		Collection: collectionBattles,
		Key:        req.BattleID,
		UserID:     userID,
	}})
	if err != nil || len(objs) == 0 {
		return "", runtime.NewError("battle not found", 5)
	}

	stepPayload, err := json.Marshal(map[string]any{
		"state":  json.RawMessage(objs[0].Value),
		"action": req.Action,
	})
	if err != nil {
		return "", runtime.NewError(err.Error(), 13)
	}

	respJSON, err := simBridge.BattleStep(ctx, stepPayload)
	if err != nil {
		return "", runtime.NewError(err.Error(), 13)
	}

	var parsed struct {
		OK    bool            `json:"ok"`
		State json.RawMessage `json:"state"`
	}
	if err := json.Unmarshal(respJSON, &parsed); err == nil && parsed.OK {
		_, _ = nk.StorageWrite(ctx, []*runtime.StorageWrite{{
			Collection:      collectionBattles,
			Key:             req.BattleID,
			UserID:          userID,
			Value:           string(parsed.State),
			PermissionRead:  1,
			PermissionWrite: 0,
			Version:         objs[0].Version,
		}})
	}
	return string(respJSON), nil
}

func rpcSharedSquadPublish(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, payload string) (string, error) {
	userID, ok := ctx.Value(runtime.RUNTIME_CTX_USER_ID).(string)
	if !ok || userID == "" {
		return "", runtime.NewError("authentication required", 16)
	}
	if payload == "" {
		return "", runtime.NewError("empty squad snapshot", 3)
	}
	_, err := nk.StorageWrite(ctx, []*runtime.StorageWrite{{
		Collection:      collectionSharedSquads,
		Key:             "active_squad",
		UserID:          userID,
		Value:           payload,
		PermissionRead:  2, // Public readable by friends & frontier outposts
		PermissionWrite: 0,
	}})
	if err != nil {
		return "", runtime.NewError("failed to publish shared squad", 13)
	}
	return `{"ok":true}`, nil
}

func rpcSharedSquadBorrow(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, payload string) (string, error) {
	borrowerID, ok := ctx.Value(runtime.RUNTIME_CTX_USER_ID).(string)
	if !ok || borrowerID == "" {
		return "", runtime.NewError("authentication required", 16)
	}
	var req struct {
		LenderUserID   string `json:"lender_user_id"`
		SquadPowerTier int    `json:"squad_power_tier"`
	}
	if err := json.Unmarshal([]byte(payload), &req); err != nil || req.LenderUserID == "" {
		return "", runtime.NewError("invalid shared_squad_borrow payload", 3)
	}

	dayKey := time.Now().UTC().Format("2006-01-02")
	objs, err := nk.StorageRead(ctx, []*runtime.StorageRead{{
		Collection: collectionDailyRewards,
		Key:        dayKey,
		UserID:     req.LenderUserID,
	}})
	if err != nil {
		return "", runtime.NewError("failed to read daily reward ledger", 13)
	}

	earnedToday := 0
	version := ""
	if len(objs) > 0 {
		version = objs[0].Version
		var ledger struct {
			EarnedToday int `json:"earned_today"`
		}
		_ = json.Unmarshal([]byte(objs[0].Value), &ledger)
		earnedToday = ledger.EarnedToday
	}

	evalReq, _ := json.Marshal(map[string]any{
		"lender_user_id":   req.LenderUserID,
		"borrower_user_id": borrowerID,
		"squad_power_tier": req.SquadPowerTier,
		"earned_today":     earnedToday,
		"daily_cap":        defaultDailyScrapCap,
	})
	respJSON, err := simBridge.EvaluateSharedSquadReward(ctx, evalReq)
	if err != nil {
		return "", runtime.NewError(err.Error(), 13)
	}

	var evalResp struct {
		Allowed        bool `json:"allowed"`
		NewEarnedToday int  `json:"new_earned_today"`
	}
	if err := json.Unmarshal(respJSON, &evalResp); err == nil && evalResp.Allowed {
		newLedger, _ := json.Marshal(map[string]int{"earned_today": evalResp.NewEarnedToday})
		_, _ = nk.StorageWrite(ctx, []*runtime.StorageWrite{{
			Collection:      collectionDailyRewards,
			Key:             dayKey,
			UserID:          req.LenderUserID,
			Value:           string(newLedger),
			PermissionRead:  1,
			PermissionWrite: 0,
			Version:         version,
		}})
	}
	return string(respJSON), nil
}
