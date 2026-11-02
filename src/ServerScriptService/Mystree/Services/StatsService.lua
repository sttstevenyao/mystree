-- ServerScriptService/Mystree/Services/StatsService (ModuleScript)
-- Player power: stat totals and Combat Power (Rules.totals), EXP and levels, the character's
-- health/speed, the overhead nameplate, and the public "Inspect" snapshot.
-- Call StatsService.refresh(player) after anything that changes gear, level or companions.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)
local Icons = require(ReplicatedStorage.Mystree.Icons)

local StatsService = {}
local S

local totals = {} -- player -> last Rules.totals result (strong table, cleared on leave)
local overrides = {} -- player -> { ATK = n, ... } typed in the admin panel (this session only)
local sprinting = {} -- player -> true while Shift sprint is on (client Movement)

function StatsService.get(player)
	return totals[player]
end

-- The overhead nameplate: name, "Lv.12 · Qi Refinement II", CP in the brush-red CP colour
local function nameplate(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = head:FindFirstChild("Nameplate")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Nameplate"
		gui.Size = UDim2.fromOffset(220, 66)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 90
		gui.LightInfluence = 0
		gui.Parent = head
		local function line(name, y, h, color, font)
			local t = Instance.new("TextLabel")
			t.Name = name
			t.BackgroundTransparency = 1
			t.Size = UDim2.new(1, 0, h, 0)
			t.Position = UDim2.fromScale(0, y)
			t.TextScaled = true
			t.TextColor3 = color
			t.TextStrokeTransparency = 0.25
			t.TextStrokeColor3 = Color3.fromRGB(30, 24, 20)
			t.FontFace = font
			t.Parent = gui
			return t
		end
		-- top line: the Power icon left of centre, the number right of it (user: an icon, not "CP")
		local cp = line("CP", 0, 0.36, Color3.fromRGB(255, 176, 92), Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold))
		cp.Size = UDim2.new(0.5, 0, 0.36, 0)
		cp.Position = UDim2.fromScale(0.47, 0)
		cp.TextXAlignment = Enum.TextXAlignment.Left
		local icon = Instance.new("ImageLabel")
		icon.Name = "PowerIcon"
		icon.BackgroundTransparency = 1
		icon.Image = Icons.get("cp")
		icon.ScaleType = Enum.ScaleType.Fit
		icon.AnchorPoint = Vector2.new(1, 0)
		icon.Size = UDim2.fromScale(0.13, 0.36)
		icon.Position = UDim2.fromScale(0.45, 0)
		icon.Parent = gui
		line("PlayerName", 0.36, 0.34, Color3.fromRGB(255, 255, 255), Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold))
		-- a crimson PVP tag left of the Power line while PvP is on
		local pvp = line("PvP", 0, 0.34, Color3.fromRGB(230, 70, 60), Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold))
		pvp.Text = "PVP"
		pvp.Size = UDim2.fromScale(0.2, 0.34)
		pvp.Position = UDim2.fromScale(0.02, 0.01)
		pvp.TextXAlignment = Enum.TextXAlignment.Left
		line("Realm", 0.7, 0.3, Color3.fromRGB(240, 222, 160), Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold))
	end
	local s = totals[player]
	local level = S.DataService.get(player, "Level") or 1
	gui.PlayerName.Text = player.DisplayName
	gui.Realm.Text = string.format("Lv.%d · %s", level, Rules.realm(level))
	gui.CP.Text = s and Format.Num(s.CP) or ""
	gui.PvP.Visible = player:GetAttribute("PvP") == true
end

-- The public snapshot other players read for Inspect (attribute "Public", JSON)
local function publish(player, data, s)
	local gear = {}
	for slot, id in pairs(data.Equipped) do
		local it = data.Inventory[id]
		if it then
			gear[slot] = { Name = Rules.itemName(it), R = it.R, L = it.L, Main = it.Main, Subs = it.Subs, Class = it.Class, Set = it.Set, Myth = it.Myth }
		end
	end
	local comps = {}
	for _, cid in ipairs(data.CompanionEquipped) do
		local owned = data.Companions[cid]
		table.insert(comps, { Id = cid, Stars = owned and owned.Stars or 1 })
	end
	player:SetAttribute("Public", HttpService:JSONEncode({
		CP = s.CP,
		Level = data.Level,
		Tree = data.Tree.Level,
		Stats = { ATK = s.ATK, HP = s.HP, DEF = s.DEF, AGL = s.AGL },
		Gear = gear,
		Companions = comps,
		Mount = data.MountEquipped,
		-- their record, for the profile others see
		Record = { Kills = data.Stats.Kills or 0, Bosses = data.Stats.Bosses or 0, Chops = data.Stats.Chops or 0, Likes = data.Island and data.Island.Likes or 0 },
	}))
end

function StatsService.applyCharacter(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local s = totals[player]
	if not (hum and s) then
		return
	end
	local frac = (hum.MaxHealth > 0) and hum.Health / hum.MaxHealth or 1
	hum.MaxHealth = s.HP
	hum.Health = math.clamp(frac, 0.05, 1) * s.HP
	local speed = Config.WalkSpeed * (1 + s.MoveSpeed) * (sprinting[player] and Config.Move.SprintMult or 1)
	local mountSpeed = S.MountService and S.MountService.speedFor(player)
	hum.WalkSpeed = mountSpeed or speed
	player:SetAttribute("SpeedCap", hum.WalkSpeed)
end

-- admin: pin a main stat to `value` (nil = back to what level and gear give), then refresh
function StatsService.setOverride(player, key, value)
	overrides[player] = overrides[player] or {}
	overrides[player][key] = value
	if next(overrides[player]) == nil then
		overrides[player] = nil
	end
	StatsService.refresh(player)
end

-- the value a stat would have without an admin override
function StatsService.natural(player, key)
	local data = S.DataService.data(player)
	return data and Rules.totals(data)[key]
end

function StatsService.refresh(player)
	local data = S.DataService.data(player)
	if not data then
		return
	end
	local s = Rules.totals(data)
	if overrides[player] then
		for k, v in pairs(overrides[player]) do
			s[k] = v
		end
		s.CP = Rules.cp(s)
	end
	totals[player] = s
	for _, k in ipairs({ "ATK", "HP", "DEF", "AGL", "CP" }) do
		player:SetAttribute(k, s[k])
	end
	player:SetAttribute("SubStats", HttpService:JSONEncode({
		CritChance = s.CritChance, CritDamage = s.CritDamage, Lifesteal = s.Lifesteal,
		AttackSpeed = s.AttackSpeed, MoveSpeed = s.MoveSpeed, DropLuck = s.DropLuck, ScrapBonus = s.ScrapBonus,
	}))
	if s.CP > (data.Stats.Best or 0) then
		data.Stats.Best = s.CP
	end
	publish(player, data, s)
	-- what the armour on the character looks like ("Helm:5:SetId,Armor:6:,..."), drawn by every client
	-- (Equipment), and whether the player shows it (the ShowArmor setting = hide all; Hide<Slot>
	-- settings hide one piece)
	local look = {}
	for _, slot in ipairs({ "Helm", "Armor", "Gloves", "Boots", "Belt" }) do
		local it = data.Equipped[slot] and data.Inventory[data.Equipped[slot]]
		if it and not data.Settings["Hide" .. slot] then
			table.insert(look, string.format("%s:%d:%s", slot, it.R, it.Set or ""))
		end
	end
	player:SetAttribute("ArmorLook", table.concat(look, ","))
	player:SetAttribute("ShowArmor", data.Settings.ShowArmor ~= false)
	StatsService.applyCharacter(player)
	nameplate(player)
end

-- EXP and level-ups (heal to full and a level-up effect for everyone nearby)
function StatsService.addExp(player, amount)
	local data = S.DataService.data(player)
	if not data or amount <= 0 then
		return
	end
	local exp = data.Exp + math.floor(amount)
	local level = data.Level
	local gained = 0
	while level < Config.Level.Max and exp >= Rules.expToNext(level) do
		exp -= Rules.expToNext(level)
		level += 1
		gained += 1
	end
	S.DataService.set(player, "Exp", exp)
	if gained > 0 then
		S.DataService.set(player, "Level", level)
		StatsService.refresh(player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
		end
		S.Remotes.effect(player, "LevelUp", level, Rules.realm(level))
		if S.MountService then
			S.MountService.checkUnlocks(player)
		end
	end
end

function StatsService.Init(services)
	S = services
end

function StatsService.Start()
	S.DataService.Loaded:Connect(function(player)
		StatsService.refresh(player)
	end)
	-- Shift sprint: the client speeds up at once; this sets the real speed and the anti-cheat cap
	S.Remotes.Handle("Sprint", 0.1, { "boolean" }, function(player, on)
		sprinting[player] = on or nil
		StatsService.applyCharacter(player)
		return true
	end)
	local function onChar(player, char)
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum then
			return
		end
		char:WaitForChild("Head", 10)
		while player.Parent and not totals[player] do
			task.wait(0.2)
		end
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		StatsService.applyCharacter(player)
		local h = char:FindFirstChildOfClass("Humanoid")
		if h then
			h.Health = h.MaxHealth
		end
		nameplate(player)
	end
	local function onPlayer(player)
		player.CharacterAdded:Connect(function(char)
			onChar(player, char)
		end)
		player:GetAttributeChangedSignal("PvP"):Connect(function()
			nameplate(player)
		end)
		if player.Character then
			task.spawn(onChar, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, pl in ipairs(Players:GetPlayers()) do
		onPlayer(pl)
	end
	Players.PlayerRemoving:Connect(function(player)
		totals[player] = nil
		overrides[player] = nil
		sprinting[player] = nil
	end)
end

return StatsService
