-- ServerScriptService/Mystree/Services/IslandService (ModuleScript)
-- Island customization (user, 2026-10-26): decor, themes, visiting and likes.
--  * Decor is bought with Scraps into a stash, then placed at island-local (X, Z, R) positions that
--    pass Rules.canPlace (inside the edge, clear of the tree/stand/gate/board, spaced apart, capped
--    at Config.Island.MaxDecor). Models come from Assets.Decor and live in plot.Decor.
--  * Buff pieces (Config.Decor[*].Buff) feed IslandService.buffs(): strongest per kind counts.
--  * Themes repaint the island landmass, the tree's leaves and add drifting particles. Unlocks cost
--    tree level (kept) or Scraps / event materials (spent).
--  * Anyone can visit anyone's island (VisitIsland); visitors can like it once per UTC day. Likes
--    are saved on the owner and shown everywhere (attribute IslandLikes, global board).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Assets = require(ReplicatedStorage.Mystree.Assets)

local IslandService = {}
local S

local plotOf = {} -- player -> plot model (kept here so leaving can clean up after TreeService)

local function today()
	return os.time() // 86400
end

local function island(player)
	local data = S.DataService.data(player)
	return data and data.Island
end

-- the landmass model of a plot ("Island<n>" next to "Plot<n>")
local function landOf(plot)
	local map = workspace:FindFirstChild("Map")
	local n = plot and plot:GetAttribute("Index")
	return map and n and map:FindFirstChild("Island" .. n)
end

function IslandService.buffs(player)
	local I = island(player)
	return Rules.decorBuffs(I and I.Decor)
end

-- ===================================================================== building
local function placeModel(plot, folder, index, d)
	local ok, model = pcall(Assets.Decor, d.Id)
	if not ok or not model then
		warn("[IslandService] no model for decor " .. tostring(d.Id))
		return
	end
	model:PivotTo(plot.PrimaryPart.CFrame * CFrame.new(d.X, 0, d.Z) * CFrame.Angles(0, math.rad(d.R or 0), 0))
	model:SetAttribute("DecorIndex", index)
	model:SetAttribute("DecorId", d.Id)
	model.Parent = folder
end

function IslandService.buildDecor(player)
	local plot = plotOf[player] or S.TreeService.plot(player)
	local I = island(player)
	if not (plot and I) then
		return
	end
	plotOf[player] = plot
	local folder = plot:FindFirstChild("Decor")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Decor"
	for i, d in ipairs(I.Decor) do
		placeModel(plot, folder, i, d)
	end
	folder.Parent = plot
end

local function paint(plot, theme)
	local land = landOf(plot)
	if land then
		for _, p in ipairs(land:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name == "Ground" then
					p.Color = theme.Grass
				elseif p.Material == Enum.Material.Ground then
					p.Color = theme.Earth
				elseif p.Material == Enum.Material.Slate then
					p.Color = theme.Slate
				elseif p.Material == Enum.Material.Rock then
					p.Color = theme.Rock
				end
			end
		end
	end
	-- drifting particles over the island
	local old = plot:FindFirstChild("ThemeFx")
	if old then
		old:Destroy()
	end
	if theme.Fx then
		local R = Config.Map.IslandRadius
		local fx = Instance.new("Part")
		fx.Name = "ThemeFx"
		fx.Anchored = true
		fx.CanCollide = false
		fx.CanQuery = false
		fx.CanTouch = false
		fx.Transparency = 1
		fx.Size = Vector3.new(R * 1.6, 1, R * 1.6)
		fx.CFrame = plot.PrimaryPart.CFrame * CFrame.new(0, theme.Fx.Fall and 28 or 1, 0)
		local e = Instance.new("ParticleEmitter")
		e.Texture = theme.Fx.Glow and Config.Particles.Glow or Config.Particles.Square
		e.Color = ColorSequence.new(theme.Fx.Color)
		e.Rate = theme.Fx.Rate
		e.Lifetime = NumberRange.new(6, 9)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.25) })
		e.Speed = NumberRange.new(0.5, 1.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-60, 60)
		e.Acceleration = theme.Fx.Fall and Vector3.new(0.6, -2.2, 0.3) or Vector3.new(0, 0.8, 0)
		e.LightEmission = theme.Fx.Glow and 1 or 0
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Parent = fx
		fx.Parent = plot
	end
end

-- recolour the tree's leaves for the theme (called again whenever the tree is rebuilt)
function IslandService.themeTree(player)
	local plot = plotOf[player] or S.TreeService.plot(player)
	local I = island(player)
	local theme = I and Config.Themes[I.Theme]
	local tree = plot and plot:FindFirstChild("Tree")
	if not (tree and theme and theme.Leaf) then
		return
	end
	for i, p in ipairs(tree:GetDescendants()) do
		if p:IsA("BasePart") and p.Name == "Canopy" then
			p.Color = theme.Leaf:Lerp(Color3.new(0, 0, 0), (i % 3) * 0.06)
		end
	end
end

function IslandService.applyTheme(player)
	local plot = plotOf[player] or S.TreeService.plot(player)
	local I = island(player)
	if not (plot and I) then
		return
	end
	local theme = Config.Themes[I.Theme] or Config.Themes.Meadow
	paint(plot, theme)
	IslandService.themeTree(player)
	player:SetAttribute("IslandTheme", I.Theme)
end

-- ===================================================================== actions
local function num(v)
	return type(v) == "number" and v == v and math.abs(v) < 1000
end

local function snap(v)
	local g = Config.Island.Grid
	return math.floor(v / g + 0.5) * g
end

function IslandService.buy(player, id)
	local data = S.DataService.data(player)
	local def = Config.Decor[id]
	if not def then
		return false, "Unknown decor."
	end
	if def.MinTree and data.Tree.Level < def.MinTree then
		return false, string.format("Grow your tree to Lv %d first.", def.MinTree)
	end
	if data.Scraps < def.Price then
		return false, string.format("You need %d more Peaches.", def.Price - data.Scraps)
	end
	S.DataService.add(player, "Scraps", -def.Price)
	data.Island.Stash[id] = (data.Island.Stash[id] or 0) + 1
	S.DataService.push(player)
	return true, def.Name .. " bought. Place it on your island!"
end

function IslandService.place(player, id, x, z, r)
	local I = island(player)
	if not (num(x) and num(z) and num(r)) then
		return false
	end
	if (I.Stash[id] or 0) < 1 then
		return false, "Buy one first."
	end
	x, z = snap(x), snap(z)
	local ok, why = Rules.canPlace(I.Decor, id, x, z)
	if not ok then
		return false, why
	end
	I.Stash[id] -= 1
	if I.Stash[id] <= 0 then
		I.Stash[id] = nil
	end
	table.insert(I.Decor, { Id = id, X = x, Z = z, R = math.floor(r) % 360 })
	IslandService.buildDecor(player)
	S.DataService.push(player)
	return true
end

function IslandService.move(player, index, x, z, r)
	local I = island(player)
	local d = I.Decor[index]
	if not (d and num(x) and num(z) and num(r)) then
		return false, "That piece is gone."
	end
	x, z = snap(x), snap(z)
	local ok, why = Rules.canPlace(I.Decor, d.Id, x, z, index)
	if not ok then
		return false, why
	end
	d.X, d.Z, d.R = x, z, math.floor(r) % 360
	IslandService.buildDecor(player)
	S.DataService.push(player)
	return true
end

function IslandService.store(player, index)
	local I = island(player)
	local d = I.Decor[index]
	if not d then
		return false, "That piece is gone."
	end
	table.remove(I.Decor, index)
	I.Stash[d.Id] = (I.Stash[d.Id] or 0) + 1
	IslandService.buildDecor(player)
	S.DataService.push(player)
	return true, Config.Decor[d.Id].Name .. " went back to your stash."
end

function IslandService.setTheme(player, id)
	local data = S.DataService.data(player)
	local def = Config.Themes[id]
	if not def then
		return false, "Unknown theme."
	end
	local I = data.Island
	if not I.Themes[id] then
		local U = def.Unlock
		if U.TreeLevel and data.Tree.Level < U.TreeLevel then
			return false, string.format("Grow your tree to Lv %d to unlock %s.", U.TreeLevel, def.Name)
		end
		for k, n in pairs(U) do
			if k ~= "TreeLevel" then
				local have = Config.Materials[k] and S.DataService.mat(player, k) or (data[k] or 0)
				if have < n then
					local name = (Config.Materials[k] and Config.Materials[k].Name) or (Config.Currencies[k] and Config.Currencies[k].Name) or k
					return false, string.format("You need %d more %s.", n - have, name)
				end
			end
		end
		for k, n in pairs(U) do
			if k ~= "TreeLevel" then
				if Config.Materials[k] then
					S.DataService.addMat(player, k, -n)
				else
					S.DataService.add(player, k, -n)
				end
			end
		end
		I.Themes[id] = true
	end
	I.Theme = id
	IslandService.applyTheme(player)
	S.DataService.push(player)
	return true, def.Name .. " is on!"
end

function IslandService.visit(player, ownerId)
	if S.CombatService.inCombat(player) then
		return false, "You can't leave in the middle of a fight."
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	if not owner then
		return false, "They left the server."
	end
	if owner == player then
		return S.WorldService.travel(player, "Home")
	end
	local plot = plotOf[owner] or S.TreeService.plot(owner)
	local char = player.Character
	if not (plot and char) then
		return false, "Their island isn't ready yet."
	end
	S.AntiCheatService.grace(player)
	player:SetAttribute("InGrounds", false)
	char:PivotTo(S.TreeService.standCFrame(owner) * CFrame.new(3, 0, 2))
	player:SetAttribute("Visiting", ownerId)
	S.StatsService.applyCharacter(player)
	S.Remotes.effect(player, "Travel", "Visit", owner.DisplayName)
	return true, "Welcome to " .. owner.DisplayName .. "'s island!"
end

function IslandService.like(player, ownerId)
	local owner = Players:GetPlayerByUserId(ownerId)
	if not owner or owner == player then
		return false, "You can't like that island."
	end
	local mine = island(player)
	local theirs = island(owner)
	if not (mine and theirs) then
		return false
	end
	local plot = plotOf[owner] or S.TreeService.plot(owner)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (plot and hrp) or (hrp.Position - plot.PrimaryPart.Position).Magnitude > Config.Map.IslandRadius + 25 then
		return false, "Visit the island to like it."
	end
	local key = tostring(ownerId)
	if mine.Liked[key] == today() then
		return false, "You already liked this island today."
	end
	mine.Liked[key] = today()
	theirs.Likes += 1
	owner:SetAttribute("IslandLikes", theirs.Likes)
	S.DataService.push(player)
	S.DataService.push(owner)
	S.Remotes.notify(owner, player.DisplayName .. " liked your island! (" .. theirs.Likes .. " likes)", "Legendary")
	return true, "You liked " .. owner.DisplayName .. "'s island."
end

-- leaving: put the island back to its plain look for the next owner
local function release(player)
	local plot = plotOf[player]
	plotOf[player] = nil
	if not plot then
		return
	end
	local decor = plot:FindFirstChild("Decor")
	if decor then
		decor:Destroy()
	end
	paint(plot, Config.Themes.Meadow)
end

function IslandService.Init(services)
	S = services
end

function IslandService.Start()
	local R = S.Remotes
	R.Handle("BuyDecor", 0.3, { "string" }, IslandService.buy)
	R.Handle("PlaceDecor", 0.2, { "string", "number", "number", "number" }, IslandService.place)
	R.Handle("MoveDecor", 0.2, { "number", "number", "number", "number" }, IslandService.move)
	R.Handle("StoreDecor", 0.2, { "number" }, IslandService.store)
	R.Handle("SetTheme", 0.5, { "string" }, IslandService.setTheme)
	R.Handle("VisitIsland", 1, { "number" }, IslandService.visit)
	R.Handle("LikeIsland", 1, { "number" }, IslandService.like)
	S.DataService.Loaded:Connect(function(player, data)
		player:SetAttribute("IslandLikes", data.Island.Likes)
		player:SetAttribute("Visiting", 0)
		-- the plot is claimed by TreeService's Loaded handler (connected earlier)
		-- pieces placed before a layout change (the chest and workbench moved) that now sit in a
		-- kept-clear spot go back to the stash instead of overlapping it
		local moved = 0
		for i = #data.Island.Decor, 1, -1 do
			local d = data.Island.Decor[i]
			local def = Config.Decor[d.Id]
			for _, c in ipairs(Config.Island.Clear) do
				if def and math.sqrt((d.X - c[1]) ^ 2 + (d.Z - c[2]) ^ 2) < c[3] + def.Radius then
					table.remove(data.Island.Decor, i)
					data.Island.Stash[d.Id] = (data.Island.Stash[d.Id] or 0) + 1
					moved += 1
					break
				end
			end
		end
		if moved > 0 then
			S.DataService.push(player)
			task.delay(6, function()
				S.Remotes.notify(player, string.format("%d decor piece%s moved to your stash: your island's layout changed.", moved, moved == 1 and "" or "s"), "Info")
			end)
		end
		task.defer(function()
			IslandService.buildDecor(player)
			IslandService.applyTheme(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		release(player)
		-- anyone visiting them is now just standing on an empty island
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl:GetAttribute("Visiting") == player.UserId then
				pl:SetAttribute("Visiting", 0)
			end
		end
	end)
	-- leaving someone's island clears "Visiting"
	while true do
		task.wait(1)
		for _, pl in ipairs(Players:GetPlayers()) do
			local v = pl:GetAttribute("Visiting")
			if v and v ~= 0 then
				local owner = Players:GetPlayerByUserId(v)
				local plot = owner and (plotOf[owner] or S.TreeService.plot(owner))
				local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
				if not (plot and hrp) or (hrp.Position - plot.PrimaryPart.Position).Magnitude > Config.Map.IslandRadius + 30 then
					pl:SetAttribute("Visiting", 0)
				end
			end
		end
	end
end

return IslandService
