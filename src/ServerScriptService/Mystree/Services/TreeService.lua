-- ServerScriptService/Mystree/Services/TreeService (ModuleScript)
-- The Divine Tree: plots, chopping, variable-ratio chop bonuses, growth, offline summary.
--  * Each player gets a random free plot (Playbook 01) and their tree is built at its stage.
--  * Chop: free (user, 2026-10-28: the old Peach energy is gone), always drops one gear piece
--    (GearService.give), +ChopExp, and may add a Lucky Chip / Sap Burst / Golden Bough bonus
--    (Config.Tree.Lucky). The main currency is shown as Peaches; its save key stays "Scraps".
--  * Auto-chop is driven by the client (it calls Chop on a timer while Auto is on); the remote's
--    cooldown caps the rate, so auto can't be faster than tapping.
--  * Growth runs on a timer (GrowEndsAt) and finishes by itself, online or offline.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)
local Assets = require(ReplicatedStorage.Mystree.Assets)

local TreeService = {}
local S

local rng = Random.new()
local plotOf = {} -- player -> plot model
local lastChop = {} -- player -> os.clock()

local function plotsFolder()
	return workspace:WaitForChild("Map"):WaitForChild("Plots")
end

function TreeService.plot(player)
	return plotOf[player]
end

local function stageFor(level)
	return math.clamp(1 + (level - 1) // Config.Tree.StageEvery, 1, 5)
end

local function treeCFrame(plot)
	return plot.PrimaryPart.CFrame * CFrame.new(0, 0.5, -4)
end

-- (Re)build the tree model on the player's plot when its stage changes
function TreeService.buildTree(player)
	local plot = plotOf[player]
	local data = S.DataService.data(player)
	if not (plot and data) then
		return
	end
	local level = data.Tree.Level
	local stage = stageFor(level)
	local tree = plot:FindFirstChild("Tree")
	if not tree or tree:GetAttribute("Stage") ~= stage then
		if tree then
			tree:Destroy()
		end
		tree = Assets.Tree(stage, treeCFrame(plot))
		tree.Name = "Tree"
		tree.Parent = plot
	end
	tree:SetAttribute("Owner", player.UserId)
	tree:SetAttribute("Level", level)
	S.IslandService.themeTree(player)
	local sign = plot:FindFirstChild("Board", true)
	for _, label in ipairs(sign and sign:GetDescendants() or {}) do
		if label.Name == "Owner" then
			label.Text = string.format("%s's Island · Tree Lv %d", player.DisplayName, level)
		end
	end
end

local function claimPlot(player)
	local free = {}
	for _, p in ipairs(plotsFolder():GetChildren()) do
		if not p:GetAttribute("Owner") then
			table.insert(free, p)
		end
	end
	if #free == 0 then
		return nil
	end
	local plot = free[rng:NextInteger(1, #free)]
	plot:SetAttribute("Owner", player.UserId)
	plotOf[player] = plot
	player:SetAttribute("Plot", plot.Name)
	return plot
end

local function releasePlot(player)
	local plot = plotOf[player]
	plotOf[player] = nil
	if not plot then
		return
	end
	plot:SetAttribute("Owner", nil)
	local tree = plot:FindFirstChild("Tree")
	if tree then
		tree:Destroy()
	end
	for _, label in ipairs(plot:GetDescendants()) do
		if label.Name == "Owner" and label:IsA("TextLabel") then
			label.Text = "Empty island"
		end
	end
end

-- Where a player stands at their plot (spawn, travel home)
function TreeService.standCFrame(player)
	local plot = plotOf[player]
	if not plot then
		return CFrame.new(0, 4, 20)
	end
	local stand = plot:FindFirstChild("Stand")
	local treePos = treeCFrame(plot).Position
	local p = stand.Position + Vector3.new(0, 3, 0)
	return CFrame.lookAt(p, Vector3.new(treePos.X, p.Y, treePos.Z))
end

-- ===================================================================== chopping
-- (no server-wide announcements for drops: user, 2026-10-27; once a tree only drops high rarities
-- they'd never stop. The player's own drop card and the nearby "Chopped" effect still show them.)

function TreeService.chop(player)
	local data = S.DataService.data(player)
	local plot = plotOf[player]
	if not (data and plot) then
		return false, "Your tree is still growing in. One moment!"
	end
	local now = os.clock()
	if lastChop[player] and now - lastChop[player] < Config.Tree.ChopCooldown * 0.8 then
		return false, nil
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local treePos = treeCFrame(plot).Position
	if not hrp or (hrp.Position - treePos).Magnitude > Config.Tree.ChopRange then
		return false, "Walk up to your tree to chop it."
	end
	lastChop[player] = now
	data.Stats.Chops += 1
	S.StatsService.addExp(player, Config.Level.ChopExp)

	-- the guaranteed drop, or a Golden Bough jackpot
	local L = Config.Tree.Lucky
	local golden = rng:NextNumber() < L.GoldenBough.Chance
	-- the Golden Bough always lands on the tree's best unlocked rarity
	local item = S.GearService.roll(player, golden and { Rarity = Rules.maxRarity(data.Tree.Level) } or nil)
	local result = S.GearService.give(player, item)
	local info = {
		Item = item,
		R = item.R,
		Equipped = result.Equipped,
		Dismantled = result.Dismantled,
		BagFull = result.BagFull,
		Scraps = result.Scraps,
		Golden = golden or nil,
	}
	-- variable-ratio bonuses on top (Playbook 01)
	-- chances start low and grow with the tree; so do the amounts (Config.Tree.Lucky)
	local treeLevel = data.Tree.Level
	local roll = rng:NextNumber()
	local sapChance = Rules.luckyChance(L.SapBurst, treeLevel)
	local chipChance = Rules.luckyChance(L.Chip, treeLevel)
	if roll < sapChance then
		-- the old Sap Burst, paid in Scraps since one gold (Config.ScrapValue)
		local n = math.floor(rng:NextInteger(L.SapBurst.Sap[1], L.SapBurst.Sap[2]) * (1 + treeLevel / 10) * Config.ScrapValue.Sap)
		S.DataService.add(player, "Scraps", n)
		info.Lucky = { Kind = "Chip", Amount = n }
	elseif roll < sapChance + chipChance then
		local per = Config.Rarities[2].Scraps * (1 + 0.15 * treeLevel * Config.ItemLevelPerTree)
		local n = math.floor(rng:NextInteger(L.Chip.ChopsWorth[1], L.Chip.ChopsWorth[2]) * per * S.GearService.scrapMult(player))
		S.DataService.add(player, "Scraps", n)
		info.Lucky = { Kind = "Chip", Amount = n }
	end
	S.Remotes.Drop:FireClient(player, info)
	-- everyone near sees the chop and the drop's rarity at this plot
	S.Remotes.fireNear("Chopped", treePos, 160, player, { R = item.R, Golden = golden or nil })
	return true
end

-- ===================================================================== growth
function TreeService.startGrowth(player)
	local data = S.DataService.data(player)
	local T = data.Tree
	if T.Growing then
		return false, "Your tree is already growing."
	end
	if T.Level >= Config.Tree.MaxLevel then
		return false, "Your tree is fully grown!"
	end
	local cost, seconds = Rules.growthCost(T.Level)
	for k, n in pairs(cost) do
		local have = Config.Materials[k] and S.DataService.mat(player, k) or (data[k] or 0)
		if have < n then
			local name = Config.Materials[k] and Config.Materials[k].Name or Config.Currencies[k].Name
			return false, string.format("You need %s more %s.", Format.Num(n - have), name)
		end
	end
	for k, n in pairs(cost) do
		if Config.Materials[k] then
			S.DataService.addMat(player, k, -n)
		else
			S.DataService.add(player, k, -n)
		end
	end
	T.Growing = true
	T.GrowEndsAt = os.time() + seconds
	S.DataService.push(player)
	if seconds <= 0 then
		TreeService.finishGrowth(player)
		return true, "Your tree grew!"
	end
	return true, string.format("Your tree is growing: ready in %s.", Format.Time(seconds))
end

function TreeService.finishGrowth(player, instant)
	local data = S.DataService.data(player)
	local T = data and data.Tree
	if not (T and T.Growing) then
		return false
	end
	if not instant and os.time() < T.GrowEndsAt then
		return false
	end
	T.Growing = false
	T.GrowEndsAt = 0
	T.Level += 1
	player:SetAttribute("TreeLevel", T.Level)
	S.DataService.push(player)
	TreeService.buildTree(player)
	S.StatsService.refresh(player)
	S.Remotes.effect(player, "Growth", T.Level)
	if T.Level % 5 == 0 then
		S.Remotes.notifyAll(string.format("🌳 %s's Divine Tree reached Lv %d!", player.DisplayName, T.Level), "Growth")
	end
	return true
end

-- ===================================================================== join / leave
local function onLoaded(player, data, isNew)
	player:SetAttribute("TreeLevel", data.Tree.Level)
	local away = (data.LastOnline > 0) and (os.time() - data.LastOnline) or 0
	local grew = data.Tree.Growing and os.time() >= data.Tree.GrowEndsAt
	if grew then
		-- finishGrowth needs the plot for the model; it is built below either way
		data.Tree.Growing = false
		data.Tree.GrowEndsAt = 0
		data.Tree.Level += 1
		player:SetAttribute("TreeLevel", data.Tree.Level)
		S.DataService.push(player)
		S.StatsService.refresh(player)
	end
	if not claimPlot(player) then
		warn("[TreeService] no free plot for " .. player.Name)
	end
	TreeService.buildTree(player)
	if not isNew and away > 60 and grew then
		S.Remotes.Welcome:FireClient(player, {
			Away = away,
			Grew = data.Tree.Level,
		})
	end
	-- first spawn goes to the plot. "HomeReady" tells the loading screen the player stands at their
	-- tree, so it ends there and never on the village spawn
	if player.Character then
		S.AntiCheatService.grace(player)
		player.Character:PivotTo(TreeService.standCFrame(player))
		player:SetAttribute("HomeReady", true)
		player:SetAttribute("Held", "Axe") -- you start at your tree with the axe out (user)
	end
end

function TreeService.Init(services)
	S = services
end

function TreeService.Start()
	local R = S.Remotes
	R.Handle("Chop", 0.3, {}, TreeService.chop)
	R.Handle("GrowTree", 0.5, {}, TreeService.startGrowth)
	S.DataService.Loaded:Connect(onLoaded)
	local function onPlayer(player)
		player.CharacterAdded:Connect(function(char)
			task.defer(function()
				if plotOf[player] and not player:GetAttribute("InGrounds") then
					S.AntiCheatService.grace(player)
					char:PivotTo(TreeService.standCFrame(player))
					player:SetAttribute("HomeReady", true)
					player:SetAttribute("Held", "Axe")
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, pl in ipairs(Players:GetPlayers()) do
		onPlayer(pl)
	end
	Players.PlayerRemoving:Connect(function(player)
		releasePlot(player)
		lastChop[player] = nil
	end)
	-- 1 s loop: growth timers, online-only boost timers
	local tick = 0
	while true do
		task.wait(1)
		tick += 1
		for _, player in ipairs(Players:GetPlayers()) do
			local data = S.DataService.data(player)
			-- fell off an island: back home (or to the grounds entry when hunting)
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp.Position.Y < Config.Map.FallY then
				S.WorldService.travel(player, player:GetAttribute("InGrounds") and "Grounds" or "Home")
			end
			if data then
				if data.Tree.Growing and os.time() >= data.Tree.GrowEndsAt then
					TreeService.finishGrowth(player)
				end
				if (data.Boosts.Incense or 0) > 0 then
					data.Boosts.Incense = math.max(0, data.Boosts.Incense - 1)
					if data.Boosts.Incense == 0 or tick % 15 == 0 then
						S.DataService.push(player)
					end
				end
			end
		end
	end
end

return TreeService
