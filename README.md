# Mystree (Roblox place "CHO")

Roblox place **CHO** (placeId 98987233689526, group 35685335). An idle-cultivation RPG: chop your Divine Tree on your own floating island for gear, hunt with friends, grow the tree for rarer drops. Design: [[Mystree Kickoff]]. Quality bar: the Playbook ([[00 Start Here]]), with Mystree's art and UI exceptions listed in the kickoff.

These files mirror the scripts in Studio (Rojo-style layout under `src/`). **Studio is the source of truth.**

## Where everything lives in Studio

| Studio location | Source file |
|---|---|
| `ReplicatedStorage.Mystree`: `Config`, `Net`, `Format`, `Rules` (pure game math), `Builders` (placeholder models + world), `Assets` (asset registry) | `src/ReplicatedStorage/Mystree/*.lua` |
| `ServerScriptService.Mystree.Main` (Script) | `src/ServerScriptService/Mystree/Main.server.lua` |
| `ServerScriptService.Mystree.Services`: Remotes, Data, Stats, Gear, Tree, World, Combat, Mob, Companion, Mount, Daily, Tutorial, Monetization, AntiCheat, Admin | `src/ServerScriptService/Mystree/Services/*.lua` |
| `StarterPlayerScripts.MystreeClient` (LocalScript) with State, Sounds, UI, Fx, Rig, Notify, WorldFx, Hud, Tutorial, Chop, Loot, Equipment, Combat, MobFx, Bag, TreePanel, Spirits, Mounts, Shop, Inspect, AdminPanel | `src/StarterPlayer/StarterPlayerScripts/MystreeClient*` |
| `Workspace.Map` (Village, 8 islands = `Plots`, Grounds, gates, scenery) | built by `Builders.World` via `tools/BuildWorld.lua` (parts only, **no terrain**) |
| `Workspace.Mobs`, plot `Tree` models | spawned at runtime |
| `ReplicatedStorage.MystreeRemotes` | created at runtime from `Net` |
| `ReplicatedStorage.MystreeAssets.<Kind>.<Id>` | **art slots** (empty for now): drop real models here and they replace the placeholders (see `Assets.lua` for the naming rules) |

## Sync (Playbook 10)

1. Start the servers from this folder: `python3 -m http.server 34893 --bind 127.0.0.1` (serves files) and `python3 tools/dev/recv.py` (port 34894, receives pulls). Raise a Zoo uses 34873/34874 and DIS 34883/34884.
2. List the files to push in `tools/dev/paths.txt`, then in Studio (Edit) run:
   `return loadstring(game:GetService("HttpService"):GetAsync("http://localhost:34893/tools/dev/push.lua?" .. os.clock(), true))()`
   It refuses a file whose Studio copy changed since the last sync, and compile-checks first.
3. **Right after every good push:** `python3 tools/dev/sync.py done $(cat tools/dev/paths.txt)`. Forgetting this makes the next push of that file refuse (pull it with a POST to 34894, check it's your own change, then push).
4. Rebuild the map: same loader with `tools/BuildWorld.lua` (it refreshes the cached Config first).
- HttpService.HttpEnabled was turned on in this place for the sync tools (the game itself never uses HTTP).

## Testing

- Admin panel: the red **Admin** button (top-right, next to the clock) or F2. Studio is always admin.
- From MCP: `game.ReplicatedStorage.MystreeRemotes.Admin:InvokeServer("Roll", 5)` on the Client; live services through `ServerStorage.MystreeDebug:Invoke(service, fn, ...)` on the Server.
- **Saves:** Studio API access is off in this place, so playtests use a temporary profile that isn't saved. Turn on Game Settings > Security > Enable Studio Access to API Services to test real saves (then Studio writes the REAL store: use Admin > ResetSave afterwards).
- `screen_capture` during Play lags behind short effects (beams, cards). Measure them by sampling instances over time instead.

## Before publishing

- Replace every `Id = 0` in `Config.Products` / `Config.Gamepasses` with real ids (0 = free test grant in Studio, "not on sale" live).
- Art pass: tree stages, weapons, gear icons, mobs, companions, mounts, islands (`MystreeAssets.Island.Island`), real swing/chop animations.
- Better sound ids (the current ones are reused from other projects).

## Undoing an upgrade

Dated snapshots live in `backups/<stamp>/` (`src` + `paths.txt`). `tools/dev/undo_upgrade.lua` writes every listed script back to its snapshot, with a dry run first. Its header has the exact commands. `backups/2026-11-02_pre-upgrade` is the state before the audio and Qilin upgrades.
