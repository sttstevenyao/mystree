-- Dev helper (Studio, Client during Play): serializes the live Mystree ScreenGuis to JSON so
-- ui_preview.lua can rebuild them in StarterGui as view-only editor copies (user: "put the ui in
-- StarterGui so I can see it in the editor"). Only properties that differ from a fresh instance
-- are kept. 3D content (Models, parts inside ViewportFrames) is skipped.
-- Clients can't make HTTP requests, so it relays through a temporary RemoteEvent
-- ReplicatedStorage._UISnap that a Server execute_luau creates (POSTs each part to recv.py at
-- 34894 -> tools/dev/pulled/_ui/part_N.json). Paste this file's source into execute_luau (Client).
local HS = game:GetService("HttpService")
local pg = game:GetService("Players").LocalPlayer.PlayerGui

local PROPS = {
	"Visible", "Size", "Position", "AnchorPoint", "Rotation", "ZIndex", "LayoutOrder", "BackgroundColor3", "BackgroundTransparency",
	"BorderSizePixel", "ClipsDescendants", "AutomaticSize", "GroupTransparency", "GroupColor3",
	"Text", "TextColor3", "TextSize", "TextTransparency", "TextWrapped", "TextScaled", "TextXAlignment", "TextYAlignment", "RichText", "FontFace",
	"TextStrokeTransparency", "TextStrokeColor3", "Image", "ImageColor3", "ImageTransparency", "ScaleType", "SliceCenter", "ImageRectOffset", "ImageRectSize",
	"CanvasSize", "ScrollBarThickness", "ScrollingDirection", "AutomaticCanvasSize", "ScrollBarImageColor3",
	"CornerRadius", "Color", "Thickness", "Transparency", "ApplyStrokeMode", "LineJoinMode", "Offset", "Enabled",
	"Padding", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "Wraps", "CellSize", "CellPadding", "FillDirectionMaxCells",
	"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight", "Scale", "AspectRatio", "AspectType", "DominantAxis", "MaxSize", "MinSize",
	"MaxTextSize", "MinTextSize", "DisplayOrder", "IgnoreGuiInset", "ScreenInsets", "ZIndexBehavior", "ResetOnSpawn", "AutoButtonColor",
	"Ambient", "LightColor", "LightDirection",
}

local function enc(v)
	local t = typeof(v)
	if t == "UDim2" then
		return { "U2", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
	elseif t == "UDim" then
		return { "U", v.Scale, v.Offset }
	elseif t == "Vector2" then
		return { "V2", v.X, v.Y }
	elseif t == "Color3" then
		return { "C", math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) }
	elseif t == "EnumItem" then
		return { "E", tostring(v.EnumType), v.Name }
	elseif t == "Font" then
		return { "F", v.Family, v.Weight.Name, v.Style.Name }
	elseif t == "Rect" then
		return { "R", v.Min.X, v.Min.Y, v.Max.X, v.Max.Y }
	elseif t == "ColorSequence" then
		local k = { "CS" }
		for _, p in ipairs(v.Keypoints) do
			table.insert(k, { p.Time, math.floor(p.Value.R * 255 + 0.5), math.floor(p.Value.G * 255 + 0.5), math.floor(p.Value.B * 255 + 0.5) })
		end
		return k
	elseif t == "NumberSequence" then
		local k = { "NS" }
		for _, p in ipairs(v.Keypoints) do
			table.insert(k, { p.Time, p.Value })
		end
		return k
	elseif t == "number" or t == "string" or t == "boolean" then
		return v
	end
	return nil
end

local defaults = {}
local function defaultOf(class)
	if defaults[class] == nil then
		local ok, inst = pcall(Instance.new, class)
		defaults[class] = ok and inst or false
	end
	return defaults[class]
end

local SKIP = { Model = true, WorldModel = true, Camera = true, Sound = true, LocalScript = true, ModuleScript = true, Script = true }

local function ser(inst)
	if SKIP[inst.ClassName] or inst:IsA("BasePart") then
		return nil
	end
	local def = defaultOf(inst.ClassName)
	if not def then
		return nil
	end
	local node = { c = inst.ClassName, n = inst.Name, p = {} }
	for _, prop in ipairs(PROPS) do
		if prop == "Transparency" and inst:IsA("GuiObject") then
			continue -- deprecated alias of BackgroundTransparency that also hides text
		end
		local ok, v = pcall(function()
			return inst[prop]
		end)
		if ok and v ~= nil then
			local okd, dv = pcall(function()
				return def[prop]
			end)
			if not okd or dv ~= v then
				local e = enc(v)
				if e ~= nil then
					node.p[prop] = e
				end
			end
		end
	end
	local kids = {}
	for _, ch in ipairs(inst:GetChildren()) do
		local s = ser(ch)
		if s then
			table.insert(kids, s)
		end
	end
	if #kids > 0 then
		node.k = kids
	end
	return node
end

local list = {}
for _, g in ipairs(pg:GetChildren()) do
	if g:IsA("ScreenGui") and string.sub(g.Name, 1, 7) == "Mystree" then
		table.insert(list, ser(g))
	end
end
local json = HS:JSONEncode(list)
local SIZE = 50000
local parts = math.ceil(#json / SIZE)
local relay = game.ReplicatedStorage:WaitForChild("_UISnap", 5)
for i = 1, parts do
	relay:FireServer(i, string.sub(json, (i - 1) * SIZE + 1, i * SIZE))
	task.wait(0.15)
end
return #json .. " bytes in " .. parts .. " parts"
