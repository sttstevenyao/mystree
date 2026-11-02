-- Dev helper (Studio, Edit): rebuilds the live UI snapshot (ui_snapshot.lua ->
-- tools/dev/pulled/_ui/all.json) as ScreenGuis in StarterGui, so the HUD and windows can be seen and
-- inspected in the editor. They are VIEW-ONLY copies: every one carries the attribute EditorPreview,
-- and the client boot script destroys them from PlayerGui. The real UI is still built in code.
-- Re-run after a UI change to refresh them. Needs the CHO http.server on 34893.
--   return loadstring(game:GetService("HttpService"):GetAsync("http://localhost:34893/tools/dev/ui_preview.lua?" .. os.clock(), true))()
local HS = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local list = HS:JSONDecode(HS:GetAsync("http://localhost:34893/tools/dev/pulled/_ui/all.json?" .. os.clock(), true))

local function dec(e)
	if type(e) ~= "table" then
		return e
	end
	local t = e[1]
	if t == "U2" then
		return UDim2.new(e[2], e[3], e[4], e[5])
	elseif t == "U" then
		return UDim.new(e[2], e[3])
	elseif t == "V2" then
		return Vector2.new(e[2], e[3])
	elseif t == "C" then
		return Color3.fromRGB(e[2], e[3], e[4])
	elseif t == "E" then
		return Enum[e[2]][e[3]]
	elseif t == "F" then
		return Font.new(e[2], Enum.FontWeight[e[3]], Enum.FontStyle[e[4]])
	elseif t == "R" then
		return Rect.new(e[2], e[3], e[4], e[5])
	elseif t == "CS" then
		local k = {}
		for i = 2, #e do
			table.insert(k, ColorSequenceKeypoint.new(e[i][1], Color3.fromRGB(e[i][2], e[i][3], e[i][4])))
		end
		return ColorSequence.new(k)
	elseif t == "NS" then
		local k = {}
		for i = 2, #e do
			table.insert(k, NumberSequenceKeypoint.new(e[i][1], e[i][2]))
		end
		return NumberSequence.new(k)
	end
end

local made, failed = 0, 0
-- world-space guis (prompt pills, name plates) would float in the editor viewport: skip them
local SKIP = { BillboardGui = true, SurfaceGui = true }
local function build(node, parent)
	if SKIP[node.c] then
		return
	end
	local ok, inst = pcall(Instance.new, node.c)
	if not ok then
		failed += 1
		return
	end
	inst.Name = node.n
	for prop, v in pairs(node.p) do
		-- GuiObject.Transparency is a deprecated alias that also hides text; BackgroundTransparency covers it
		if prop == "Transparency" and inst:IsA("GuiObject") then
			continue
		end
		if not pcall(function()
			inst[prop] = dec(v)
		end) then
			failed += 1
		end
	end
	for _, k in ipairs(node.k or {}) do
		build(k, inst)
	end
	inst.Parent = parent
	made += 1
	return inst
end

-- replace earlier previews only
for _, g in ipairs(StarterGui:GetChildren()) do
	if g:GetAttribute("EditorPreview") then
		g:Destroy()
	end
end
local names = {}
for _, node in ipairs(list) do
	local g = build(node, nil)
	if g then
		g:SetAttribute("EditorPreview", true)
		g.Parent = StarterGui
		table.insert(names, g.Name)
	end
	task.wait()
end
return string.format("%d instances (%d property/class misses): %s", made, failed, table.concat(names, ", "))
