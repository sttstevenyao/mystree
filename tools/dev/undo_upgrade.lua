-- Dev helper (Studio, Edit): one-step undo for a dated upgrade snapshot in CHO/backups/<stamp>.
-- Writes every script in <stamp>/paths.txt back to its snapshot text. Scripts added after the
-- snapshot are listed in the result but left alone. Afterwards, from CHO:
--   cp -R backups/<stamp>/src/. src/ && python3 tools/dev/sync.py done $(cat backups/<stamp>/paths.txt)
-- Run: return loadstring(game:GetService("HttpService"):GetAsync("http://localhost:34893/tools/dev/undo_upgrade.lua?"..os.clock(), true))("<stamp>", true)
-- The second argument false (or missing) is a dry run: it only reports what would change.
local stamp, apply = ...
local HS = game:GetService("HttpService")
local SES = game:GetService("ScriptEditorService")
local BASE = "http://localhost:34893/backups/" .. stamp .. "/"
local changed, missing = {}, {}
local known = {}
for path in string.gmatch(HS:GetAsync(BASE .. "paths.txt?" .. os.clock(), true), "[^\r\n]+") do
	known[path] = true
	local inst = game
	for seg in string.gmatch(path, "[^/]+") do
		local name = seg:gsub("%.server%.lua$", ""):gsub("%.client%.lua$", ""):gsub("%.lua$", "")
		inst = inst and inst:FindFirstChild(name)
	end
	if not inst then
		table.insert(missing, path)
		continue
	end
	local old = HS:GetAsync(BASE .. "src/" .. path .. "?" .. os.clock(), true)
	if inst.Source ~= old then
		table.insert(changed, path)
		if apply then
			assert(loadstring(old), path .. " snapshot does not compile")
			SES:UpdateSourceAsync(inst, function()
				return old
			end)
		end
	end
end
return (apply and "RESTORED " or "WOULD RESTORE ") .. #changed .. ":\n" .. table.concat(changed, "\n") .. "\nMISSING " .. #missing .. ":\n" .. table.concat(missing, "\n")
