-- ServerScriptService/Mystree/Services/MountService (ModuleScript)
-- Mounts: unlocked by level, Mount Shards or boss drops; one equipped; ride in the Hunting Grounds
-- for the mount's speed (the Village stays at walking speed). Riding is two player attributes,
-- "Mount" (equipped id) and "Riding" (bool); every client draws the mount under the rider.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)

local MountService = {}
local S

function MountService.speedFor(player)
	if player:GetAttribute("Riding") then
		local def = Config.Mounts[player:GetAttribute("Mount") or ""]
		return def and def.Speed
	end
	return nil
end

function MountService.grant(player, id)
	local data = S.DataService.data(player)
	if not (data and Config.Mounts[id]) or data.Mounts[id] then
		return false
	end
	data.Mounts[id] = true
	if data.MountEquipped == "" or Config.Mounts[id].Speed > (Config.Mounts[data.MountEquipped] and Config.Mounts[data.MountEquipped].Speed or 0) then
		data.MountEquipped = id
		player:SetAttribute("Mount", id)
	end
	S.DataService.push(player)
	S.Remotes.effect(player, "Mount", id)
	return true
end

-- Level unlocks (Old Horse at Lv 8)
function MountService.checkUnlocks(player)
	local data = S.DataService.data(player)
	for id, def in pairs(Config.Mounts) do
		local earned = (def.Unlock.Level and data.Level >= def.Unlock.Level)
			or (def.Unlock.Pass and S.MonetizationService.hasPass(player, def.Unlock.Pass))
		if earned and not data.Mounts[id] then
			MountService.grant(player, id)
			S.Remotes.notify(player, string.format("You unlocked the %s! Ride it in the Hunting Grounds.", def.Name), "Mount")
		end
	end
end

local function setRiding(player, on)
	player:SetAttribute("Riding", on)
	S.StatsService.applyCharacter(player)
end

function MountService.Init(services)
	S = services
end

function MountService.Start()
	local R = S.Remotes
	R.Handle("UnlockMount", 0.5, { "string" }, function(player, id)
		local def = Config.Mounts[id]
		local data = S.DataService.data(player)
		if not def then
			return false
		end
		if data.Mounts[id] then
			return false, "You already have it."
		end
		local need = def.Unlock.Scraps
		if def.Unlock.Pass then
			return false, "This mount comes with the " .. Config.Gamepasses[def.Unlock.Pass].Name .. " pass."
		end
		if not need then
			return false, string.format("Reach Lv %d to unlock it.", def.Unlock.Level or 0)
		end
		if data.Scraps < need then
			return false, string.format("You need %s more Peaches.", Format.Num(need - data.Scraps))
		end
		S.DataService.add(player, "Scraps", -need)
		MountService.grant(player, id)
		return true, string.format("You unlocked the %s!", def.Name)
	end)
	R.Handle("EquipMount", 0.3, { "string" }, function(player, id)
		local data = S.DataService.data(player)
		if id ~= "" and not data.Mounts[id] then
			return false, "You don't have that mount."
		end
		data.MountEquipped = id
		player:SetAttribute("Mount", id)
		if id == "" then
			setRiding(player, false)
		else
			S.StatsService.applyCharacter(player)
		end
		S.DataService.push(player)
		return true
	end)
	R.Handle("Ride", 0.5, { "boolean" }, function(player, on)
		local data = S.DataService.data(player)
		if on then
			if data.MountEquipped == "" then
				return false, "Unlock a mount first (Old Horse at Lv 8)."
			end
		end
		setRiding(player, on)
		return true
	end)
	S.DataService.Loaded:Connect(function(player, data)
		player:SetAttribute("Mount", data.MountEquipped)
		player:SetAttribute("Riding", false)
		MountService.checkUnlocks(player)
	end)
	local function onPlayer(player)
		player.CharacterAdded:Connect(function()
			player:SetAttribute("Riding", false)
		end)
		-- mounts ride anywhere (user, 2026-10-27)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, pl in ipairs(Players:GetPlayers()) do
		onPlayer(pl)
	end
end

return MountService
