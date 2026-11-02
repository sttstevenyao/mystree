-- Edit-time tool (Studio, Edit): rebuilds Workspace.Map and the terrain from Builders.World().
-- Run from MCP:
--   return loadstring(game:GetService("HttpService"):GetAsync("http://localhost:34893/tools/BuildWorld.lua?" .. os.clock(), true))()
-- Uses a fresh copy of Builders (require caches modules for the whole Studio session).
local folder = game:GetService("ReplicatedStorage").Mystree
-- Builders reads Config by path, which is cached too: refresh the cached table in place
local cfgCopy = folder.Config:Clone()
cfgCopy.Name = "Config_run"
cfgCopy.Parent = folder
local okCfg, fresh = pcall(require, cfgCopy)
cfgCopy:Destroy()
if okCfg then
	local cached = require(folder.Config)
	for k, v in pairs(fresh) do
		cached[k] = v
	end
end
local copy = folder.Builders:Clone()
copy.Name = "Builders_run"
copy.Parent = folder
local ok, Builders = pcall(require, copy)
if not ok then
	copy:Destroy()
	return "require failed: " .. tostring(Builders)
end
for _, n in ipairs({ "Baseplate", "SpawnLocation" }) do
	local x = workspace:FindFirstChild(n)
	if x then
		x:Destroy()
	end
end
workspace.Terrain:Clear()
local ok2, err = pcall(Builders.World)
copy:Destroy()
if not ok2 then
	return "World failed: " .. tostring(err)
end
local n = 0
for _, d in ipairs(workspace.Map:GetDescendants()) do
	if d:IsA("BasePart") then
		n += 1
	end
end
return "Map built: " .. n .. " parts"
