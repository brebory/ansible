use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Faction {
    Player,
    Enemy,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Species {
    Human,
    Vexari,
    Chitinoid,
    OutlawBot,
    VoidRaider,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DrifterRole {
    Gunslinger,
    Vanguard,
    TechShaman,
    Builder,
    Researcher,
    Defender,
    Raider,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StatusKind {
    Burn,
    Guard,
    Marked,
    Overclock,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct StatusInstance {
    pub kind: StatusKind,
    pub turns_remaining: u8,
    pub potency: i32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TargetMode {
    SingleEnemy,
    AllEnemies,
    SingleAlly,
    SelfOnly,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillDef {
    pub id: String,
    pub name: String,
    pub description: String,
    pub ap_cost: i32,
    pub base_power: i32,
    pub target_mode: TargetMode,
    pub is_heal: bool,
    pub apply_status: Option<StatusKind>,
    pub status_turns: u8,
    pub status_potency: i32,
    pub crit_bonus_pct: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Combatant {
    pub id: String,
    pub name: String,
    pub faction: Faction,
    pub species: Species,
    pub role: DrifterRole,
    pub slot_index: u8,
    pub max_hp: i32,
    pub hp: i32,
    pub max_ap: i32,
    pub ap: i32,
    pub grit: i32,
    pub aim: i32,
    pub tech: i32,
    pub speed: i32,
    pub alive: bool,
    pub statuses: Vec<StatusInstance>,
    pub skills: Vec<SkillDef>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum BattleOutcome {
    Ongoing,
    Victory,
    Defeat,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CameraCueKind {
    EstablishingSweep,
    CommandOverShoulder,
    ActionCutIn,
    ImpactShake,
    VictoryOrbit,
    DefeatPan,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum BattleEvent {
    TurnStarted {
        round: u32,
        actor_id: String,
        ap_restored: i32,
    },
    UpkeepStatusTick {
        actor_id: String,
        status: StatusKind,
        delta_hp: i32,
        remaining_hp: i32,
    },
    CameraCue {
        cue: CameraCueKind,
        actor_id: Option<String>,
        target_id: Option<String>,
    },
    SkillExecuted {
        actor_id: String,
        skill_id: String,
        skill_name: String,
        ap_spent: i32,
    },
    DamageDealt {
        actor_id: String,
        target_id: String,
        amount: i32,
        is_crit: bool,
        guarded: bool,
        marked_bonus: bool,
        remaining_hp: i32,
    },
    HealingApplied {
        actor_id: String,
        target_id: String,
        amount: i32,
        remaining_hp: i32,
    },
    StatusApplied {
        actor_id: String,
        target_id: String,
        status: StatusKind,
        turns: u8,
    },
    TriggerFired {
        source_id: String,
        trigger_name: String,
        detail: String,
    },
    CombatantDefeated {
        combatant_id: String,
        name: String,
    },
    BattleEnded {
        outcome: BattleOutcome,
        scrap_reward: i32,
        holo_data_reward: i32,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BattleState {
    pub battle_id: String,
    pub seed: u64,
    pub rng_state: u64,
    pub round: u32,
    pub turn_order: Vec<String>,
    pub current_turn_idx: usize,
    pub outcome: BattleOutcome,
    pub combatants: Vec<Combatant>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BattleActionInput {
    pub actor_id: String,
    pub skill_id: String,
    pub target_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BattleStepRequest {
    pub state: BattleState,
    pub action: Option<BattleActionInput>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BattleStepResponse {
    pub ok: bool,
    pub error: Option<String>,
    pub state: BattleState,
    pub events: Vec<BattleEvent>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedSquadRewardRequest {
    pub lender_user_id: String,
    pub borrower_user_id: String,
    pub squad_power_tier: i32,
    pub earned_today: i32,
    pub daily_cap: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedSquadRewardResponse {
    pub allowed: bool,
    pub reason: String,
    pub lender_scrap_granted: i32,
    pub borrower_bonus_scrap: i32,
    pub new_earned_today: i32,
    pub cap_reached: bool,
}
