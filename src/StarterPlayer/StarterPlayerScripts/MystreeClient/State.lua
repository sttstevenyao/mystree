-- StarterPlayerScripts/MystreeClient/State (ModuleScript)
-- The client's copy of the player's save. Small tables come from the JSON "State" attribute
-- (DataService.push); numbers are plain player attributes (Peaches, Scraps, Level, CP, Mat_Sap...);
-- the inventory arrives through the Inventory event as deltas. Nothing here is trusted by the server.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Net = require(ReplicatedStorage.Mystree.Net)
local Rules = require(ReplicatedStorage.Mystree.Rules)

local player = Players.LocalPlayer

local State = {
	Equipped = {},
	AutoDismantle = Config.DefaultAutoDismantle,
	AutoEquip = true,
	Companions = {},
	CompanionEquipped = {},
	SummonPity = 0,
	Mounts = {},
	MountEquipped = "",
	Daily = { Day = 0, Streak = 0 },
	Boosts = { Incense = 0 },
	Stats = { Chops = 0, Kills = 0, Elites = 0, Bosses = 0 },
	Tree = { Level = 1, GrowEndsAt = 0, Growing = false },
	Settings = table.clone(Config.DefaultSettings),
	Quests = { Main = 0, MainBase = 0, Side = {}, SideDone = {} },
	Offers = { StarterAt = 0, StarterBought = false },
	Island = { Theme = "Meadow", Themes = { Meadow = true }, Decor = {}, Stash = {}, Likes = 0, Liked = {} },
	Inventory = {}, -- [id] = item
	Auto = false, -- auto-chop toggle (client-side)
}

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event -- small tables changed
local invChanged = Instance.new("BindableEvent")
State.InventoryChanged = invChanged.Event -- (op, payload)

local function decode()
	local raw = player:GetAttribute("State")
	if type(raw) ~= "string" then
		return
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok then
		return
	end
	for k, v in pairs(data) do
		State[k] = v
	end
	for k, v in pairs(Config.DefaultSettings) do
		if State.Settings[k] == nil then
			State.Settings[k] = v
		end
	end
	changed:Fire()
end

player:GetAttributeChangedSignal("State"):Connect(decode)
decode()

Net.get("Inventory").OnClientEvent:Connect(function(op, payload)
	if op == "All" then
		State.Inventory = payload or {}
	elseif op == "Add" or op == "Update" then
		State.Inventory[payload.Id] = payload
	elseif op == "Remove" then
		for _, id in ipairs(payload) do
			State.Inventory[id] = nil
		end
	end
	invChanged:Fire(op, payload)
end)

function State.attr(name, default)
	local v = player:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

function State.setting(name)
	local v = State.Settings[name]
	if v == nil then
		return Config.DefaultSettings[name]
	end
	return v
end

-- optimistic local change (the server confirms through the State attribute)
function State.setSetting(name, on)
	State.Settings[name] = on
	changed:Fire()
end

function State.equipped(slot)
	local id = State.Equipped[slot]
	return id and State.Inventory[id]
end

-- The table Rules.totals needs, built from the client copy (for "CP if equipped" previews)
function State.asData()
	return {
		Level = State.attr("Level", 1),
		Equipped = State.Equipped,
		Inventory = State.Inventory,
		Companions = State.Companions,
		CompanionEquipped = State.CompanionEquipped,
	}
end

-- CP change if this item were equipped instead of what's in its slot
function State.cpDelta(item)
	local data = State.asData()
	local before = Rules.totals(data).CP
	local eq = table.clone(data.Equipped)
	eq[item.Slot] = item.Id
	data.Equipped = eq
	return Rules.totals(data).CP - before
end

function State.itemCount()
	local n = 0
	for _ in pairs(State.Inventory) do
		n += 1
	end
	return n
end

function State.bagSize()
	return Config.BagSize + (State.attr("Pass_BigBag") and Config.BigBagExtra or 0)
end

return State
