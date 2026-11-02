-- Dev helper (Studio, Edit): pushes local src files into the place (Playbook 10).
-- Needs: python3 -m http.server 34893 --bind 127.0.0.1   (run in the CHO folder)
-- For each path, Studio's current source must still equal tools/dev/pulled/<path> (the last synced
-- copy), so a newer Studio-side edit is never overwritten. Compile-checks before writing. New files
-- are created (Folders on the way; .server.lua = Script, .client.lua = LocalScript, .lua = ModuleScript).
-- After a successful push:  python3 tools/dev/sync.py done <paths>
-- PATHS come from tools/dev/paths.txt (one per line), so a push from MCP is one short call:
--   return loadstring(game:GetService("HttpService"):GetAsync("http://localhost:34893/tools/dev/push.lua?" .. os.clock(), true))()
local HS = game:GetService("HttpService")
local PATHS = {}
-- an optional argument picks another list file (parallel sessions each keep their own):
--   loadstring(...)("paths_village.txt")
local listFile = ... or "paths.txt"
for line in string.gmatch(HS:GetAsync("http://localhost:34893/tools/dev/" .. listFile .. "?" .. os.clock(), true), "[^\r\n]+") do
	table.insert(PATHS, line)
end
local SES = game:GetService("ScriptEditorService")
local BASE = "http://localhost:34893/"
local out = {}
for _, path in ipairs(PATHS) do
	local new = HS:GetAsync(BASE .. "src/" .. path .. "?" .. os.clock(), true)
	local f, err = loadstring(new)
	if not f then
		table.insert(out, path .. ": COMPILE ERROR " .. tostring(err))
		continue
	end
	local segs = {}
	for seg in string.gmatch(path, "[^/]+") do
		table.insert(segs, seg)
	end
	local inst = game:GetService(segs[1])
	for i = 2, #segs - 1 do
		local child = inst:FindFirstChild(segs[i])
		if not child then
			child = Instance.new("Folder")
			child.Name = segs[i]
			child.Parent = inst
		end
		inst = child
	end
	local file = segs[#segs]
	local class, name = "ModuleScript", (file:gsub("%.lua$", ""))
	if file:match("%.server%.lua$") then
		class, name = "Script", (file:gsub("%.server%.lua$", ""))
	elseif file:match("%.client%.lua$") then
		class, name = "LocalScript", (file:gsub("%.client%.lua$", ""))
	end
	local target = inst:FindFirstChild(name)
	if target then
		local ok, synced = pcall(HS.GetAsync, HS, BASE .. "tools/dev/pulled/" .. path .. "?" .. os.clock(), true)
		if ok and SES:GetEditorSource(target) ~= synced then
			table.insert(out, path .. ": STUDIO CHANGED since last sync, skipped (pull and merge first)")
			continue
		end
	else
		target = Instance.new(class)
		target.Name = name
		target.Parent = inst
	end
	SES:UpdateSourceAsync(target, function()
		return new
	end)
	table.insert(out, path .. ": pushed " .. #new)
end
return table.concat(out, "\n")
