-- ServerScriptService/Mystree/Services/GearService (ModuleScript)
-- Gear drops, equip, dismantle, lock, the auto-dismantle / auto-equip filter, and the forge.
-- Dismantling a weapon also gives forge materials (Config.Forge.Dismantle). The forge turns them into
-- a weapon of a chosen class and rarity (Forge) or a Mythforged weapon from a relic (Mythforge).
-- Every drop goes through GearService.give(): better than what you wear -> equipped (if AutoEquip),
-- at or below your auto-dismantle rarity -> Scraps on the spot, otherwise into the bag
-- (dismantled with a message when the bag is full, so a drop is never silently lost).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)

local GearService = {}
local S

local rng = Random.new()

function GearService.scrapMult(player)
	local st = S.StatsService.get(player)
	local mult = 1 + (st and st.ScrapBonus or 0) + S.IslandService.buffs(player).ScrapBonus
	if S.MonetizationService.hasPass(player, "VIP") then
		mult += Config.VipScrapBonus
	end
	return mult
end

-- Roll a drop at the player's tree level. opts: Min (rarity floor), Shift (tiers up), Rarity (forced)
-- the player's drop modifiers (gear luck, island luck, Lucky Incense, Fortune Charm): used by
-- every roll and sent to the tree's odds screen, so the shown odds are the real ones
function GearService.luck(player)
	local data = S.DataService.data(player)
	local st = S.StatsService.get(player)
	return {
		Luck = (st and st.DropLuck or 0) + S.IslandService.buffs(player).Luck,
		Incense = (data.Boosts.Incense or 0) > 0,
		Charm = S.MonetizationService.hasPass(player, "FortuneCharm"),
	}
end

function GearService.roll(player, opts)
	opts = opts or {}
	local data = S.DataService.data(player)
	local treeLevel = data.Tree.Level
	local luck = GearService.luck(player)
	luck.Shift, luck.Min = opts.Shift, opts.Min
	local rarity = opts.Rarity or Rules.rollRarity(treeLevel, luck, rng)
	-- a forced rarity (Golden Bough) still respects the tree's cap
	rarity = math.min(rarity, Rules.maxRarity(treeLevel))
	return Rules.rollItem(treeLevel, rarity, rng)
end

local function equippedItem(data, slot)
	local id = data.Equipped[slot]
	return id and data.Inventory[id]
end

-- The look of the equipped weapon, read by every client to put it in the player's hand
local function updateWeaponLook(player, data)
	local w = equippedItem(data, "Weapon")
	player:SetAttribute("WeaponLook", w and (w.Class .. ":" .. w.R) or "")
end

local function doEquip(player, data, item)
	data.Equipped[item.Slot] = item.Id
	if item.Slot == "Weapon" then
		updateWeaponLook(player, data)
	end
end

-- Dismantle value for a list of items, after bonuses
local function scrapsFor(player, items)
	local total = 0
	for _, it in ipairs(items) do
		total += Rules.dismantleValue(it)
	end
	return math.floor(total * GearService.scrapMult(player) + 0.5)
end

-- the extra Scraps dismantled weapons give (Config.Forge.Dismantle, in Scraps since one gold)
local function forgeScraps(items)
	local total = 0
	for k, n in pairs(Rules.forgeYield(items)) do
		total += (k == "Scraps") and n or math.floor(n * (Config.ScrapValue[k] or 0) + 0.5)
	end
	return total
end

-- Hand a rolled item to the player. Returns { Item, Equipped, Dismantled, Scraps, BagFull }.
function GearService.give(player, item)
	local data = S.DataService.data(player)
	local result = { Item = item, Equipped = false, Dismantled = false, Scraps = 0 }
	local current = equippedItem(data, item.Slot)
	local better = (current == nil) or Rules.itemCP(item) > Rules.itemCP(current)
	if data.AutoEquip and better then
		local stored = S.DataService.addItem(player, item)
		if stored then
			doEquip(player, data, stored)
			result.Equipped = true
			-- the replaced piece is dismantled if the filter would have dismantled it as a drop
			if current and not current.Lock and current.R <= data.AutoDismantle then
				local n = scrapsFor(player, { current }) + forgeScraps({ current })
				S.DataService.removeItems(player, { current.Id })
				S.DataService.add(player, "Scraps", n)
				result.Scraps += n
			end
			S.StatsService.refresh(player)
			S.DataService.push(player)
			return result
		end
	end
	if item.R <= data.AutoDismantle and not better then
		data.Stats.Dismantled = (data.Stats.Dismantled or 0) + 1
		local n = scrapsFor(player, { item }) + forgeScraps({ item })
		S.DataService.add(player, "Scraps", n)
		result.Dismantled = true
		result.Scraps += n
		return result
	end
	local stored = S.DataService.addItem(player, item)
	if not stored then
		local n = scrapsFor(player, { item }) + forgeScraps({ item })
		S.DataService.add(player, "Scraps", n)
		result.Dismantled = true
		result.BagFull = true
		result.Scraps += n
	end
	return result
end

function GearService.equip(player, id)
	local data = S.DataService.data(player)
	local item = data and data.Inventory[id]
	if not item then
		return false, "That item is gone."
	end
	doEquip(player, data, item)
	S.StatsService.refresh(player)
	S.DataService.push(player)
	return true
end

function GearService.dismantle(player, ids)
	local data = S.DataService.data(player)
	local equipped = {}
	for _, id in pairs(data.Equipped) do
		equipped[id] = true
	end
	local items, removed, seen = {}, {}, {}
	for _, id in ipairs(ids) do
		local it = data.Inventory[id]
		if it and not seen[id] and not equipped[id] and not it.Lock then
			seen[id] = true -- the same id listed twice must not pay twice
			table.insert(items, it)
			table.insert(removed, id)
		end
	end
	if #items == 0 then
		return false, "Nothing to dismantle (equipped and locked gear is kept)."
	end
	local n = scrapsFor(player, items) + forgeScraps(items)
	data.Stats.Dismantled = (data.Stats.Dismantled or 0) + #items
	S.DataService.removeItems(player, removed)
	S.DataService.add(player, "Scraps", n)
	return true, string.format("Dismantled %d for %s Peaches", #items, Format.Num(n)), n
end

-- ===================================================================== forge
local function have(player, key)
	if Config.Materials[key] then
		return S.DataService.mat(player, key)
	end
	return S.DataService.get(player, key) or 0
end

local function pay(player, cost)
	for k, n in pairs(cost) do
		if Config.Materials[k] then
			S.DataService.addMat(player, k, -n)
		else
			S.DataService.add(player, k, -n)
		end
	end
end

local function costName(key)
	return (Config.Materials[key] and Config.Materials[key].Name) or (Config.Currencies[key] and Config.Currencies[key].Name) or key
end

-- store the new weapon (never dismantled by the filter) and tell everyone about the big ones
local function deliver(player, item)
	local stored = S.DataService.addItem(player, item)
	if not stored then
		return false
	end
	S.DataService.push(player)
	return stored
end

function GearService.forge(player, tierIndex, class)
	local data = S.DataService.data(player)
	local tier = Config.Forge.Tiers[tierIndex]
	if not (data and tier and Config.WeaponClasses[class]) then
		return false, "That recipe doesn't exist."
	end
	if Rules.maxRarity(data.Tree.Level) < tier.Rarity then
		return false, "Grow your Divine Tree to forge " .. Config.Rarities[tier.Rarity].Name .. " weapons."
	end
	if S.DataService.itemCount(player) >= S.DataService.bagSize(player) then
		return false, "Your bag is full."
	end
	local ok, missing = Rules.canPay(tier.Cost, function(k)
		return have(player, k)
	end)
	if not ok then
		return false, "Not enough " .. costName(missing) .. "."
	end
	pay(player, tier.Cost)
	local item = deliver(player, Rules.forgeItem(data.Tree.Level, tier.Rarity, class, rng))
	data.Stats.Forged = (data.Stats.Forged or 0) + 1
	return true, "Forged " .. Rules.itemName(item) .. "!", item
end

function GearService.mythforge(player, mythId)
	local data = S.DataService.data(player)
	local def = Config.Forge.Myth[mythId]
	if not (data and def) then
		return false, "That recipe doesn't exist."
	end
	if S.DataService.itemCount(player) >= S.DataService.bagSize(player) then
		return false, "Your bag is full."
	end
	local ok, missing = Rules.canPay(def.Cost, function(k)
		return have(player, k)
	end)
	if not ok then
		return false, "Not enough " .. costName(missing) .. "."
	end
	pay(player, def.Cost)
	local item = deliver(player, Rules.mythItem(data.Tree.Level, mythId, rng))
	data.Stats.Forged = (data.Stats.Forged or 0) + 1
	return true, "Forged " .. def.Name .. "!", item
end

function GearService.Init(services)
	S = services
end

function GearService.Start()
	local R = S.Remotes
	R.Handle("Equip", 0.15, { "string" }, GearService.equip)
	-- the modifiers for the odds screens (the client runs them through the shared Rules.weightsFor)
	R.Handle("GearLuck", 0.5, {}, function(player)
		return GearService.luck(player)
	end)
	R.Handle("Dismantle", 0.3, { "table" }, function(player, ids)
		local clean = {}
		for i, id in ipairs(ids) do
			if i > 400 then
				break
			end
			if type(id) == "string" then
				table.insert(clean, id)
			end
		end
		return GearService.dismantle(player, clean)
	end)
	R.Handle("DismantleWorse", 0.6, {}, function(player)
		local data = S.DataService.data(player)
		local ids = data and Rules.worseGear(data) or {}
		if #ids == 0 then
			return false, "Nothing worse than your equipped gear."
		end
		return GearService.dismantle(player, ids)
	end)
	R.Handle("Forge", 0.6, { "number", "string" }, function(player, tierIndex, class)
		return GearService.forge(player, math.floor(tierIndex), class)
	end)
	R.Handle("Mythforge", 1, { "string" }, GearService.mythforge)
	R.Handle("Lock", 0.15, { "string", "boolean" }, function(player, id, locked)
		local data = S.DataService.data(player)
		local it = data and data.Inventory[id]
		if not it then
			return false, "That item is gone."
		end
		it.Lock = locked or nil
		R.Inventory:FireClient(player, "Update", it)
		return true
	end)
	R.Handle("SetAutoDismantle", 0.2, { "number", "boolean?" }, function(player, rarity, autoEquip)
		local data = S.DataService.data(player)
		data.AutoDismantle = math.clamp(math.floor(rarity), 0, #Config.Rarities - 1)
		if autoEquip ~= nil then
			data.AutoEquip = autoEquip
		end
		S.DataService.push(player)
		return true
	end)
	S.DataService.Loaded:Connect(function(player, data, isNew)
		updateWeaponLook(player, data)
		if isNew then
			-- a starter sword so the Hunting Grounds work on minute one
			local starter = Rules.rollItem(1, 1, rng, "Weapon")
			starter.Class = "Sword"
			local stored = S.DataService.addItem(player, starter)
			if stored then
				doEquip(player, data, stored)
				S.StatsService.refresh(player)
				S.DataService.push(player)
			end
		end
	end)
end

return GearService
