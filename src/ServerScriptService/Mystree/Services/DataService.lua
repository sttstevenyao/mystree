-- ServerScriptService/Mystree/Services/DataService (ModuleScript)
-- Player saves (DataStore Config.DataStoreName, key "p_<UserId>"), Playbook 13:
--  * Session-locked: Lock = { Job, Time } is stamped on load and checked on every write, so two
--    servers never overwrite each other. A stale lock, or one still held after LockWaits waits of 6s,
--    is taken over.
--  * Every request is retried with backoff. A failed load kicks the player in live servers (never
--    play on default data that would overwrite the real save); Studio gets a temporary profile.
--  * Versioned (DataVersion) and reconciled against the template on load.
--  * LastOnline is stamped on every write. Receipts (purchase ids) live in the save.
-- Numbers are mirrored to player attributes. Small tables reach the client as one JSON "State"
-- attribute; the inventory (big) goes through the Inventory event as deltas.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Mystree.Config)

local DataService = {}
local S

-- numbers mirrored 1:1 to player attributes
local NUMBERS = { "Level", "Exp", "Scraps", "Spirit", "MountShards" }

-- Save schema v1 (bump Config.DataVersion and migrate in reconcile() when it changes)
local function template()
	return {
		DataVersion = Config.DataVersion,
		LastOnline = 0,
		Level = 1,
		Exp = 0,
		Scraps = 0,
		Spirit = 0, -- Spirit Stones (companion summons)
		MountShards = 0,
		Materials = { QilinHorn = 0, FoxTail = 0, RocFeather = 0 }, -- relics only (one gold: Config.ScrapValue)
		Tree = { Level = 1, GrowEndsAt = 0, Growing = false },
		-- gear: [id] = { Id, Slot, Class?, R, L, Main = {stat = n}, Subs = {key = x}, Lock? }
		Inventory = {},
		NextId = 1,
		Equipped = {}, -- [slot] = item id
		AutoDismantle = Config.DefaultAutoDismantle,
		AutoEquip = true,
		Companions = {}, -- [id] = { Stars }
		CompanionEquipped = {}, -- list of ids (1 slot, 2 with Twin Spirits)
		SummonPity = 0,
		Mounts = {}, -- [id] = true
		MountEquipped = "",
		Daily = { Day = 0, Streak = 0 },
		Boosts = { Incense = 0 }, -- seconds of playtime left (only ticks online)
		Stats = { Chops = 0, Kills = 0, Elites = 0, Bosses = 0, Best = 1, Dismantled = 0, Summons = 0, Mobs = {} },
		-- Main = current main quest step (0 = not started), Side = { [id] = base }, SideDone = { [id] = UTC day }
		-- MainAccepted: the current step was accepted (user: main quests are accepted or declined)
		Quests = { Main = 0, MainBase = 0, MainAccepted = false, Side = {}, SideDone = {} },
		-- StarterAt = os.time() the Starter Pack offer began (0 = not yet), StarterBought
		Offers = { StarterAt = 0, StarterBought = false },
		-- Decor = { {Id, X, Z, R} } island-local, Stash = { [id] = n }, Liked = { [ownerUserId] = UTC day }
		Island = { Theme = "Meadow", Themes = { Meadow = true }, Decor = {}, Stash = {}, Likes = 0, Liked = {} },
		Tutorial = 1, -- current step in Config.Tutorial; past the end = done
		TutorialBase = 0, -- Chops/Kills when the current counted step started
		Settings = table.clone(Config.DefaultSettings),
		Codes = {},
		Receipts = {},
	}
end

local store
local profiles = {} -- player -> { Data, Temporary }
local jobId = (game.JobId ~= "") and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

local function retry(label, fn, tries)
	local delay = 1
	local lastErr
	for i = 1, tries do
		local results = table.pack(pcall(fn))
		if results[1] then
			return true, table.unpack(results, 2, results.n)
		end
		lastErr = results[2]
		warn(string.format("[DataService] %s failed (%d/%d): %s", label, i, tries, tostring(lastErr)))
		if i < tries then
			task.wait(delay + math.random() * 0.5) -- jitter, so servers don't retry in lockstep
			delay *= 2
		end
	end
	return false, lastErr
end

local function keyFor(player)
	return "p_" .. player.UserId
end

-- Fill missing fields from the template (one level of tables deep)
local function reconcile(saved)
	local data = template()
	if type(saved) ~= "table" then
		return data
	end
	for k, v in pairs(saved) do
		if k ~= "Lock" and data[k] ~= nil and typeof(v) == typeof(data[k]) then
			if type(v) == "table" and next(data[k]) ~= nil and #data[k] == 0 then
				for k2, v2 in pairs(v) do
					data[k][k2] = v2
				end
			else
				data[k] = v
			end
		end
	end
	-- one gold (v3): retired materials and Mount Shards become Scraps at Config.ScrapValue
	for k, v in pairs(data.Materials) do
		local value = Config.ScrapValue[k]
		if value then
			data.Scraps += math.floor((tonumber(v) or 0) * value + 0.5)
			data.Materials[k] = nil
		end
	end
	-- the old Peach chop energy (retired 2026-10-28) is paid out in the main currency
	if type(saved.Peaches) == "number" and saved.Peaches > 0 then
		data.Scraps += math.floor(saved.Peaches * Config.ScrapValue.Peaches)
	end
	if (data.MountShards or 0) > 0 then
		data.Scraps += data.MountShards * Config.ScrapValue.MountShards
		data.MountShards = 0
	end
	data.DataVersion = Config.DataVersion
	return data
end

-- ===================================================================== public API
function DataService.isLoaded(player)
	return profiles[player] ~= nil
end

function DataService.data(player)
	local p = profiles[player]
	return p and p.Data
end

function DataService.get(player, key)
	local p = profiles[player]
	return p and p.Data[key]
end

function DataService.set(player, key, value)
	local p = profiles[player]
	if not p or type(p.Data[key]) ~= "number" then
		return
	end
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
		warn("[DataService] refused a non-finite " .. tostring(key) .. " for " .. player.Name)
		return -- NaN / inf can't be saved (no JSON form) and would wreck the profile
	end
	value = math.clamp(value, -1e15, 1e15) -- far below 2^53, where whole numbers stop being exact
	p.Data[key] = value
	player:SetAttribute(key, value)
end

function DataService.add(player, key, delta)
	local v = (DataService.get(player, key) or 0) + delta
	DataService.set(player, key, v)
	return v
end

-- Materials (only the relics now) live in a sub-table; attribute "Mat_<name>". A retired material
-- (Config.ScrapValue) is paid or charged as Scraps instead, so nothing old can be lost or free.
function DataService.mat(player, name)
	local p = profiles[player]
	return p and p.Data.Materials[name] or 0
end

function DataService.addMat(player, name, delta)
	local p = profiles[player]
	if p and Config.ScrapValue[name] then
		return DataService.add(player, "Scraps", math.floor(delta * Config.ScrapValue[name] + 0.5))
	end
	if not p or Config.Materials[name] == nil then
		return 0
	end
	local v = math.max(0, (p.Data.Materials[name] or 0) + delta)
	p.Data.Materials[name] = v
	player:SetAttribute("Mat_" .. name, v)
	return v
end

-- Grant a reward table { Scraps = n, Spirit = n, QilinHorn = n, ... } (retired keys like the old
-- Peaches pay their Config.ScrapValue in the main currency)
function DataService.grant(player, reward)
	for k, n in pairs(reward) do
		if Config.Materials[k] or Config.ScrapValue[k] then
			DataService.addMat(player, k, n)
		elseif type(DataService.get(player, k)) == "number" then
			DataService.add(player, k, n)
		end
	end
end

-- Send the small table parts of the save to the client (call after changing them)
function DataService.push(player)
	local p = profiles[player]
	if not p then
		return
	end
	local d = p.Data
	player:SetAttribute("State", HttpService:JSONEncode({
		Equipped = d.Equipped,
		AutoDismantle = d.AutoDismantle,
		AutoEquip = d.AutoEquip,
		Companions = d.Companions,
		CompanionEquipped = d.CompanionEquipped,
		SummonPity = d.SummonPity,
		Mounts = d.Mounts,
		MountEquipped = d.MountEquipped,
		Daily = d.Daily,
		Boosts = d.Boosts,
		Stats = d.Stats,
		Tree = d.Tree,
		Quests = d.Quests,
		Offers = d.Offers,
		Island = d.Island,
		Settings = d.Settings,
	}))
end

-- ===================================================================== inventory
function DataService.bagSize(player)
	local extra = (S.MonetizationService and S.MonetizationService.hasPass(player, "BigBag")) and Config.BigBagExtra or 0
	return Config.BagSize + extra
end

function DataService.itemCount(player)
	local p = profiles[player]
	local n = 0
	if p then
		for _ in pairs(p.Data.Inventory) do
			n += 1
		end
	end
	return n
end

-- Store a rolled item; returns it with its new Id (or nil when the bag is full)
function DataService.addItem(player, item)
	local p = profiles[player]
	if not p then
		return nil
	end
	if DataService.itemCount(player) >= DataService.bagSize(player) then
		return nil
	end
	item.Id = "i" .. p.Data.NextId
	p.Data.NextId += 1
	p.Data.Inventory[item.Id] = item
	S.Remotes.Inventory:FireClient(player, "Add", item)
	return item
end

function DataService.removeItems(player, ids)
	local p = profiles[player]
	if not p then
		return
	end
	for _, id in ipairs(ids) do
		p.Data.Inventory[id] = nil
	end
	S.Remotes.Inventory:FireClient(player, "Remove", ids)
end

function DataService.sendInventory(player)
	local p = profiles[player]
	if p then
		S.Remotes.Inventory:FireClient(player, "All", p.Data.Inventory)
	end
end

function DataService.hasReceipt(player, purchaseId)
	local p = profiles[player]
	return p ~= nil and table.find(p.Data.Receipts, purchaseId) ~= nil
end

function DataService.addReceipt(player, purchaseId)
	local p = profiles[player]
	if not p then
		return
	end
	table.insert(p.Data.Receipts, purchaseId)
	while #p.Data.Receipts > Config.MaxReceipts do
		table.remove(p.Data.Receipts, 1)
	end
end

local function mirror(player, data)
	for _, k in ipairs(NUMBERS) do
		player:SetAttribute(k, data[k])
	end
	for name in pairs(Config.Materials) do
		player:SetAttribute("Mat_" .. name, data.Materials[name] or 0)
	end
end

-- Admin "Reset my save": a fresh template (keeps receipts so old purchases stay processed)
function DataService.reset(player)
	local p = profiles[player]
	if not p then
		return
	end
	local receipts = p.Data.Receipts
	p.Data = template()
	p.Data.Receipts = receipts
	mirror(player, p.Data)
	DataService.push(player)
	DataService.sendInventory(player)
end

-- ===================================================================== load / save
-- a full copy, so tables the game changes while UpdateAsync waits can't half-land in the save
local function deepCopy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = type(v) == "table" and deepCopy(v) or v
	end
	return c
end

local leaving = {} -- [UserId] = true while a leave-save is in flight (a quick rejoin waits for it)

local function save(player, releaseLock)
	local p = profiles[player]
	if not (p and store) or p.Temporary or p.Released then
		return false
	end
	local snapshot = deepCopy(p.Data)
	snapshot.LastOnline = os.time()
	local lostLock = false
	local ok = retry("save " .. player.UserId, function()
		store:UpdateAsync(keyFor(player), function(old, keyInfo)
			-- fenced by this session's token: a save whose lock was released or taken never writes
			local lock = type(old) == "table" and old.Lock
			if not lock or lock.Job ~= jobId or (lock.Token and lock.Token ~= p.Token) then
				lostLock = true
				return nil
			end
			snapshot.Lock = (not releaseLock) and { Job = jobId, Time = os.time(), Token = p.Token } or nil
			return snapshot, keyInfo and keyInfo:GetUserIds() or { player.UserId }
		end)
	end, 3)
	if releaseLock and ok then
		p.Released = true
	end
	if lostLock then
		warn("[DataService] another server holds " .. player.Name .. "'s save; skipped writing")
		return false
	end
	if ok then
		p.Data.LastOnline = snapshot.LastOnline
	end
	return ok
end

-- Save right away (after a Robux purchase). Returns true once it is safely stored.
function DataService.saveNow(player)
	return save(player, false)
end

local function releaseOnly(player)
	retry("release " .. player.UserId, function()
		store:UpdateAsync(keyFor(player), function(old)
			if type(old) == "table" and old.Lock and old.Lock.Job == jobId then
				old.Lock = nil
				return old
			end
			return nil
		end)
	end, 2)
end

-- Fires (player, data, isNew) once a save is loaded; services hook join logic here. A plain Lua
-- signal, not a BindableEvent: those copy tables, and handlers must get the live save table.
local loadedHandlers = {}
DataService.Loaded = {
	Connect = function(_, fn)
		table.insert(loadedHandlers, fn)
	end,
}
local function fireLoaded(player, data, isNew)
	for _, fn in ipairs(loadedHandlers) do
		local ok, err = pcall(fn, player, data, isNew)
		if not ok then
			warn("[DataService] a Loaded handler failed: " .. tostring(err))
		end
	end
end

local function load(player)
	local saved = {}
	local temporary = false
	local token = HttpService:GenerateGUID(false)
	-- left and rejoined this same server: let the leave-save land before reading
	local t0 = os.clock()
	while leaving[player.UserId] and os.clock() - t0 < 20 do
		task.wait(0.2)
	end
	if store then
		local waits = 0
		while true do
			local heldElsewhere = false
			local ok, result = retry("load " .. player.UserId, function()
				return store:UpdateAsync(keyFor(player), function(old)
					old = (type(old) == "table") and old or {}
					local lock = old.Lock
					if lock and lock.Job ~= jobId and os.time() - (lock.Time or 0) < Config.LockStale and waits < Config.LockWaits then
						heldElsewhere = true
						return nil -- the server they just left is probably still saving
					end
					old.Lock = { Job = jobId, Time = os.time(), Token = token }
					return old, { player.UserId }
				end)
			end, 4)
			if not ok then
				if RunService:IsStudio() then
					warn("[DataService] load failed in Studio; using a temporary profile that will not be saved")
					temporary = true
					break
				end
				player:Kick("We couldn't load your save. Please rejoin in a minute.")
				return
			end
			if not heldElsewhere then
				saved = result or {}
				break
			end
			waits += 1
			task.wait(6)
			if not player.Parent then
				return
			end
		end
	else
		temporary = true
	end
	if not player.Parent then
		if store and not temporary then
			releaseOnly(player)
		end
		return
	end

	local isNew = saved.DataVersion == nil
	local data = reconcile(saved)
	profiles[player] = { Data = data, Temporary = temporary, Token = token }
	mirror(player, data)
	DataService.push(player)
	DataService.sendInventory(player)
	fireLoaded(player, data, isNew)
	player:SetAttribute("DataLoaded", true)
end

function DataService.Init(services)
	S = services
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore(Config.DataStoreName)
		if RunService:IsStudio() then
			-- fail fast when Studio has no API access instead of retrying every load
			store:GetAsync("probe")
		end
	end)
	if not ok then
		store = nil
		warn("[DataService] DataStores unavailable (" .. tostring(err) .. "); progress will not save. "
			.. "In Studio, turn on Game Settings > Security > Enable Studio Access to API Services.")
	end
end

function DataService.Start()
	-- one settings toggle at a time; only known keys, only booleans
	S.Remotes.Handle("SaveSettings", 0.15, { "string", "boolean" }, function(player, key, on)
		local data = DataService.data(player)
		if not data or Config.DefaultSettings[key] == nil then
			return false
		end
		data.Settings[key] = on
		if key == "ShowArmor" then
			player:SetAttribute("ShowArmor", on) -- everyone's client draws (or hides) the armour
		elseif string.sub(key, 1, 4) == "Hide" then
			S.StatsService.refresh(player) -- republishes ArmorLook without the hidden piece
		end
		DataService.push(player)
		return true
	end)
	-- deferred, so every other service's Start has hooked Loaded before the first save arrives
	Players.PlayerAdded:Connect(function(pl)
		task.defer(load, pl)
	end)
	for _, pl in ipairs(Players:GetPlayers()) do
		task.defer(load, pl)
	end
	Players.PlayerRemoving:Connect(function(player)
		leaving[player.UserId] = true
		save(player, true)
		profiles[player] = nil
		leaving[player.UserId] = nil
	end)
	game:BindToClose(function()
		-- PlayerRemoving may not get to run before shutdown: save everyone and wait for it
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		-- (in Studio don't hold Stop open: Studio Stop isn't a real shutdown test)
		while pending > 0 and os.clock() - t0 < (RunService:IsStudio() and 3 or 25) do
			task.wait(0.1)
		end
	end)
	while true do
		task.wait(Config.AutosaveInterval)
		-- spread across the first half of the interval so all players don't hit the store at once
		for player in pairs(profiles) do
			task.delay(math.random() * Config.AutosaveInterval * 0.5, save, player, false)
		end
	end
end

return DataService
