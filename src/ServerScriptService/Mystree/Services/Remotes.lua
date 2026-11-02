-- ServerScriptService/Mystree/Services/Remotes (ModuleScript)
-- Creates every remote listed in ReplicatedStorage.Mystree.Net and wraps each RemoteFunction handler with
-- a per-player cooldown, argument type checks and error isolation (Playbook 13). Handlers return
-- (ok, message[, extra]) so the client can show a toast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Mystree.Net)

local Remotes = {}

-- last call time per player per remote. A strong table, cleared when the player leaves
-- (weak Instance-keyed tables get emptied at random GC times: Playbook 09).
local lastCall = {}

function Remotes.Init(S)
	local folder = ReplicatedStorage:FindFirstChild(Net.FolderName) or Instance.new("Folder")
	folder.Name = Net.FolderName
	for _, name in ipairs(Net.Events) do
		local r = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
		Remotes[name] = r
	end
	for _, name in ipairs(Net.Functions) do
		local r = folder:FindFirstChild(name) or Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = folder
		Remotes[name] = r
	end
	folder.Parent = ReplicatedStorage
end

-- types: one entry per argument, a typeof() name ("string", "number", "table", "boolean"),
-- optionally ending in "?" when nil is allowed, or "any".
local function argsOk(types, args)
	for i, want in ipairs(types) do
		local v = args[i]
		local optional = string.sub(want, -1) == "?"
		local base = optional and string.sub(want, 1, -2) or want
		if not (base == "any" or (v == nil and optional) or typeof(v) == base) then
			return false
		end
		if base == "number" and (v ~= v or v == math.huge or v == -math.huge) then
			return false -- NaN / inf
		end
		if base == "string" and #v > 200 then
			return false
		end
	end
	return true
end

function Remotes.Handle(name, cooldown, types, fn)
	Remotes[name].OnServerInvoke = function(player, ...)
		local now = os.clock()
		lastCall[player] = lastCall[player] or {}
		local last = lastCall[player][name]
		if last and now - last < cooldown then
			return false, "Slow down a little!"
		end
		lastCall[player][name] = now
		local args = table.pack(...)
		if not argsOk(types, args) then
			warn(string.format("[Mystree] %s sent bad arguments to %s", player.Name, name))
			return false, "That didn't work."
		end
		local ok, a, b, c = pcall(fn, player, table.unpack(args, 1, args.n))
		if not ok then
			warn("[Mystree] " .. name .. " failed: " .. tostring(a))
			return false, "Something went wrong. Try again."
		end
		return a, b, c
	end
end

function Remotes.notify(player, text, kind)
	Remotes.Notify:FireClient(player, text, kind)
end

function Remotes.notifyAll(text, kind)
	Remotes.Notify:FireAllClients(text, kind)
end

function Remotes.effect(player, kind, ...)
	Remotes.Effect:FireClient(player, kind, ...)
end

function Remotes.alert(text, colorKey)
	Remotes.Alert:FireAllClients(text, colorKey)
end

-- Fire an event to every player whose character is within radius of pos (hit numbers, chops)
function Remotes.fireNear(name, pos, radius, ...)
	for _, pl in ipairs(Players:GetPlayers()) do
		local char = pl.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - pos).Magnitude <= radius then
			Remotes[name]:FireClient(pl, ...)
		end
	end
end

function Remotes.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

return Remotes
