-- ServerScriptService/Mystree/Services/LeaderboardService (ModuleScript)
-- Global top lists for the custom leaderboard (Config.Leaderboards): best Combat Power, tree level
-- and island likes, in OrderedDataStores. Every RefreshEvery s it posts each player's values (only
-- when they changed) and reads the top lists into the workspace attribute "Boards" (JSON):
-- { CP = { {Rank, UserId, Name, Value} }, Tree = {...}, Likes = {...}, Updated, Offline? }.
-- Without DataStores (Studio with no API access) the lists come from the players in this server
-- and Offline = true, so the screen still shows something real.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Mystree.Config)

local LeaderboardService = {}
local S

local L = Config.Leaderboards
local stores = {} -- board id -> OrderedDataStore
local posted = {} -- player -> { [board id] = value }
local names = {} -- userId -> name cache

local function value(player, id)
	local data = S.DataService.data(player)
	if not data then
		return nil
	end
	if id == "CP" then
		return math.floor(data.Stats.Best or 0)
	elseif id == "Tree" then
		return data.Tree.Level
	elseif id == "Likes" then
		return data.Island.Likes
	end
end

local function nameOf(userId)
	if names[userId] then
		return names[userId]
	end
	local pl = Players:GetPlayerByUserId(userId)
	if pl then
		names[userId] = pl.DisplayName
		return pl.DisplayName
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and n or ("Player " .. userId)
	return names[userId]
end

local function localBoards()
	local out = { Updated = os.time(), Offline = true }
	for _, b in ipairs(L.Boards) do
		local list = {}
		for _, pl in ipairs(Players:GetPlayers()) do
			local v = value(pl, b.Id)
			if v then
				table.insert(list, { UserId = pl.UserId, Name = pl.DisplayName, Value = v })
			end
		end
		table.sort(list, function(a, c)
			return a.Value > c.Value
		end)
		for i, e in ipairs(list) do
			e.Rank = i
		end
		out[b.Id] = list
	end
	return out
end

local function refresh()
	if next(stores) == nil then
		workspace:SetAttribute("Boards", HttpService:JSONEncode(localBoards()))
		return
	end
	-- post what changed
	for _, pl in ipairs(Players:GetPlayers()) do
		posted[pl] = posted[pl] or {}
		for _, b in ipairs(L.Boards) do
			local v = value(pl, b.Id)
			if v and v > 0 and posted[pl][b.Id] ~= v then
				local ok = pcall(function()
					stores[b.Id]:SetAsync(tostring(pl.UserId), v)
				end)
				if ok then
					posted[pl][b.Id] = v
				end
			end
		end
	end
	-- read the tops
	local out = { Updated = os.time() }
	for _, b in ipairs(L.Boards) do
		local ok, page = pcall(function()
			return stores[b.Id]:GetSortedAsync(false, L.Top):GetCurrentPage()
		end)
		local list = {}
		if ok then
			for i, e in ipairs(page) do
				local uid = tonumber(e.key)
				table.insert(list, { Rank = i, UserId = uid, Name = uid and nameOf(uid) or e.key, Value = e.value })
			end
		end
		out[b.Id] = list
	end
	workspace:SetAttribute("Boards", HttpService:JSONEncode(out))
end

function LeaderboardService.Init(services)
	S = services
	local ok = pcall(function()
		for _, b in ipairs(L.Boards) do
			stores[b.Id] = DataStoreService:GetOrderedDataStore(b.Store)
		end
		if RunService:IsStudio() then
			-- fail fast without Studio API access (same probe as DataService)
			stores[L.Boards[1].Id]:GetSortedAsync(false, 1)
		end
	end)
	if not ok then
		table.clear(stores)
	end
end

function LeaderboardService.Start()
	Players.PlayerRemoving:Connect(function(player)
		posted[player] = nil
	end)
	task.wait(5)
	while true do
		local ok, err = pcall(refresh)
		if not ok then
			warn("[LeaderboardService] " .. tostring(err))
		end
		-- the in-server fallback is cheap, so refresh it faster
		task.wait(next(stores) and L.RefreshEvery or 10)
	end
end

return LeaderboardService
