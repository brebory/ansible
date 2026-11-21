# Ansible — Domain Context & Ubiquitous Language

> Canonical glossary for `snackpackgames/ansible`. Issues, plans, code symbols, and tests must use these terms consistently.

## Core Domain Terms

| Term | Definition | Avoid Synonyms |
| :--- | :--- | :--- |
| **Ansible** | The player's lonely frontier space outpost at the edge of uncharted space. Houses structures, research labs, defenses, and a roster of drifters. Advances as time passes during expeditions. | base, fortress, town (as primary noun) |
| **Drifter** | A recruitable human or alien vagrant who arrives at the Ansible. Has species, base stats (`grit`, `aim`, `tech`, `speed`), traits, a recolorable futuristic-western visual kit, and can be assigned to outpost roles or expedition battle classes. | hero, unit, colonist, pawn |
| **Role** | A Drifter's functional assignment — either an outpost duty (`Builder`, `Researcher`, `Defender`) or an expedition **Battle Class** (`Gunslinger`, `Vanguard`, `TechShaman`). | job, profession |
| **Squad** | A combat-ready formation of Drifters (3 drifters in the vertical slice; expandable to include a borrowed Shared Squad/Drifter) deployed on an Expedition. | party, team |
| **Expedition** | A roguelike run departing from the Ansible into uncharted space. Players plot routes across a fog-of-war Star Map, resolve Narrative Scenes and Turn-Based Battles, and extract resources back to the Ansible. | dungeon, mission, raid |
| **Star Map** | The fog-of-war node graph of Points of Interest (POIs) explored during an Expedition. | world map, overworld |
| **POI (Point of Interest)** | A selectable node on the Star Map (e.g., Derelict Saloon, Scrap Nebula, Bandit Relay, Ancient Beacon). Access and visibility are gated by Ship capabilities and Ansible upgrades. | tile, encounter node |
| **Ship** | A collectible/buildable vessel assigned to an Expedition that determines Star Map jump range, scanner radius, cargo hold, and which specialized POIs can be selected. | vehicle, craft |
| **Shared Squad** | A snapshot of a player's Drifter Squad published to Nakama so friends or fellow frontier players can borrow it on Expeditions, awarding cooperation resources to the lender up to a server-enforced daily cap. | mercs, support team, clan loan |
| **Turn Pipeline** | The deterministic combat resolution sequence inherited from `ansible-text-specifications`: `Upkeep → PreExecValidation → PreExecTriggers → ExecuteAction → PostExecValidation → PostExecTriggers → EndTurn`. | combat loop |
| **Sim Core** | The deterministic Rust crate (`sim-core/`) compiled to `wasm32-unknown-unknown` and executed by the Nakama Go runtime (`wazero`) as the single source of truth for authoritative gameplay rules. | engine logic, backend rules |
