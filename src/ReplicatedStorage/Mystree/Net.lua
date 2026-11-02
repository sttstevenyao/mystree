-- ReplicatedStorage/Mystree/Net (ModuleScript)
-- The one list of every remote (Playbook 09). The server's Remotes service creates them in
-- ReplicatedStorage.MystreeRemotes; clients call Net.get(name) / Net.invoke(name, ...).
-- Functions answer (ok, message[, extra]) so the client can show a toast. Events are one-way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.FolderName = "MystreeRemotes"

-- server -> client
Net.Events = {
	"Notify", -- (text, kind) toast
	"Alert", -- (text, colorKey) the big top-of-screen server alert
	"Inventory", -- (op, payload) "All" {items} | "Add" item | "Remove" {ids} | "Update" item
	"Drop", -- (info) a chop/kill drop: { Item?, Rarity, Pos, Lucky?, Dismantled?, Scraps?, Mats? }
	"Hit", -- (info) damage done: { Target, Amount, Crit, Pos, By } (sent to everyone near)
	"Effect", -- (kind, ...) LevelUp, Growth, Summon, Hurt, Death, Purchase
	"Chopped", -- (player, info) another player's chop, so everyone sees chips and drops at plots
	"Welcome", -- (summary) offline Peaches and growth while away
}

-- client -> server, all rate-limited and type-checked
Net.Functions = {
	"Chop", -- () one strike at your tree
	"Equip", -- (itemId)
	"Dismantle", -- ({itemIds})
	"Lock", -- (itemId, locked)
	"SetAutoDismantle", -- (rarityIndex)
	"GrowTree", -- () start growth to the next level
	"Swing", -- (comboIndex, lookVector) PvE attack intent
	"Summon", -- (count) companions
	"EquipCompanion", -- (id, slot)
	"UnlockMount", -- (id)
	"EquipMount", -- (id or "")
	"Ride", -- (on)
	"Travel", -- (where) "Hub" | "Grounds" | "Plot"
	"ClaimDaily", -- ()
	"SkipTutorial", -- ()
	"QuestTalk", -- (npcId) -> ok, msg, dialog (see QuestService.dialog)
	"QuestAccept", -- (sideQuestId) -> ok, msg, dialog
	"QuestTurnIn", -- (questId: main step Id or side quest Id) -> ok, msg, dialog
	"QuestAbandon", -- (sideQuestId) -> ok, msg
	"BuyDecor", -- (decorId) -> ok, msg  (goes to your stash)
	"PlaceDecor", -- (decorId, x, z, r) island-local -> ok, msg
	"MoveDecor", -- (index, x, z, r) -> ok, msg
	"StoreDecor", -- (index) -> ok, msg  (back to the stash)
	"SetTheme", -- (themeId) -> ok, msg  (unlocks it if you can pay)
	"VisitIsland", -- (ownerUserId) -> ok, msg
	"LikeIsland", -- (ownerUserId) -> ok, msg
	"SaveSettings", -- (key, on)
	"Sprint", -- (on) Shift sprint toggle -> ok
	"Dash", -- () Q dash: starts the server's i-frame window -> ok
	"Hold", -- ("" | "Weapon" | "Axe") what the character holds -> ok (player attribute "Held")
	"SetPvP", -- (on) -> ok, msg  (player attribute "PvP"; turning off waits Config.PvP.OffDelay)
	"DismantleWorse", -- () -> ok, msg  (Rules.worseGear: worse now and no more potential than equipped)
	"Forge", -- (tierIndex, weaponClass) -> ok, msg, item  (Config.Forge.Tiers)
	"Mythforge", -- (mythId) -> ok, msg, item  (Config.Forge.Myth)
	"StudioPurchase", -- (productKey) Studio only, Id 0 products
	"GearLuck", -- () -> { Luck, Incense, Charm }: drop modifiers for the odds screens
	"Buy", -- (productOrPassKey) -> ok, msg: the server checks the offer, then opens the Roblox prompt
	"Admin", -- (command, ...)
}

local folder
local function getFolder()
	folder = folder or ReplicatedStorage:WaitForChild(Net.FolderName)
	return folder
end

function Net.get(name)
	return getFolder():WaitForChild(name)
end

-- Client: call a function remote; always returns ok, message[, extra] (never errors)
function Net.invoke(name, ...)
	local args = table.pack(...)
	local results = table.pack(pcall(function()
		return Net.get(name):InvokeServer(table.unpack(args, 1, args.n))
	end))
	if not results[1] then
		return false, "Couldn't reach the server. Try again."
	end
	return table.unpack(results, 2, results.n)
end

return Net
