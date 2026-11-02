-- Dev tool (Studio, Edit): builds a list of Looks in a grid at the preview pad, reports part counts
-- and z-fight pairs. return loadstring(GetAsync(".../roster.lua"))()({ "Bandit", ... }, cols, gap)
local HS = game:GetService("HttpService")
return function(list, cols, gap)
	local prev = loadstring(HS:GetAsync("http://localhost:34893/tools/dev/creature_preview.lua?" .. os.clock(), true))()
	local entries = {}
	for _, id in ipairs(list) do
		table.insert(entries, { Look = id, Gap = gap or 12 })
	end
	local r = prev(entries)
	local f = workspace._CreaturePreview
	local ms = {}
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("Model") then
			table.insert(ms, c)
		end
	end
	local z = loadstring(HS:GetAsync("http://localhost:34893/tools/dev/plate_zcheck.lua?" .. os.clock(), true))()
	return r .. "\n" .. z
end
