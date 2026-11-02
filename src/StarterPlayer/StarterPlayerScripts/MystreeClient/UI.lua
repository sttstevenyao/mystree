-- StarterPlayerScripts/MystreeClient/UI (ModuleScript)
-- Mystree's UI kit: sleek stylized murim (user, 2026-10-27: "a sleek stylized murim ui", not the
-- stud-simulator packs). Ink and gold over rice paper:
--  * Ink-black panels with thin muted-gold borders and gold corner ornaments (the HUD).
--  * Windows: an ink header with the serif title in pale gold over a crimson brush stroke (VFX
--    Library "Ink splash"), a crimson seal-stamp close button, a rice-paper body with a faint
--    cloud-scroll pattern; an ink splash blooms behind a window as it opens.
--  * Buttons: crimson lacquer (main action), jade (secondary/confirm), ink tabs (active tab = gold),
--    ink square tiles with light text (side menu). Red dots mark something to claim.
-- Style names stay Orange / Green / Teal / Cream / Red / Grey / Purple so callers don't change.
--  * Rarity tiles: rounded squares in the rarity colour with the item in 3D and "Lv.4" bottom-right.
--  * The CP banner: italic orange text on a red brush stroke.
-- Feel rules still apply (Playbook 07/17): everything pops in/out, buttons bounce with a soft click,
-- numbers are big, layouts are designed at 1100x620 and scaled to the screen, touch targets >= 44 px.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Mystree.Config)
local Icons = require(ReplicatedStorage.Mystree.Icons)

local UI = {}

local player = Players.LocalPlayer
UI.PlayerGui = player:WaitForChild("PlayerGui")

-- ===================================================================== theme
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
UI.T = {
	Panel = rgb(22, 22, 27), -- ink
	Panel2 = rgb(36, 35, 41),
	PanelLine = rgb(150, 128, 88), -- muted gold
	Ornament = rgb(214, 178, 104), -- gold
	Header = rgb(52, 48, 50),
	HeaderDark = rgb(20, 19, 22),
	Parchment = rgb(240, 233, 216), -- rice paper
	Parchment2 = rgb(226, 216, 194),
	Ink = rgb(40, 33, 28),
	InkSoft = rgb(122, 110, 94),
	White = rgb(255, 255, 255),
	TextLight = rgb(236, 230, 214),
	Outline = rgb(14, 12, 12),
	Crimson = rgb(176, 40, 40),
	CrimsonDark = rgb(112, 18, 22),
	Orange = rgb(250, 168, 62),
	OrangeDark = rgb(222, 112, 28),
	OrangeLine = rgb(138, 74, 20),
	Green = rgb(118, 192, 134),
	GreenDark = rgb(58, 138, 88),
	GreenLine = rgb(36, 88, 56),
	Teal = rgb(104, 186, 178),
	TealDark = rgb(58, 138, 132),
	TealLine = rgb(34, 84, 80),
	Cream = rgb(246, 230, 170),
	CreamDark = rgb(232, 204, 122),
	CreamLine = rgb(140, 110, 50),
	Red = rgb(226, 70, 60),
	RedDark = rgb(170, 40, 36),
	CP = rgb(255, 178, 94),
	CPBrush = rgb(184, 50, 42),
	Gold = rgb(255, 214, 106),
	GoldDark = rgb(226, 160, 44),
	Exp = rgb(246, 186, 72),
	ExpDark = rgb(232, 130, 40),
	Bar = rgb(52, 46, 38),
}
local T = UI.T

-- Sleek kit (user, 2026-10-26: "too bubbly"): Montserrat instead of the rounded Nunito, Heavy drawn as
-- Bold, a serif (Merriweather) for window titles, tight corners, thin outlines, no springy overshoot.
local FONT = "rbxasset://fonts/families/Montserrat.json"
function UI.font(weight, italic)
	if weight == Enum.FontWeight.Heavy or weight == Enum.FontWeight.ExtraBold then
		weight = Enum.FontWeight.Bold
	end
	return Font.new(FONT, weight or Enum.FontWeight.SemiBold, italic and Enum.FontStyle.Italic or Enum.FontStyle.Normal)
end
UI.Bold = UI.font(Enum.FontWeight.Bold)
UI.Heavy = UI.font(Enum.FontWeight.Heavy)
UI.Serif = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)

function UI.rarityColor(r)
	return Config.Rarities[math.clamp(r or 1, 1, #Config.Rarities)].Color
end

local Sounds
function UI.setSounds(s)
	Sounds = s
end
local function click()
	if Sounds then
		Sounds.play("Click")
	end
end

-- ===================================================================== builders
function UI.new(class, props, children)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
	end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			o[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = o
	end
	if parent then
		o.Parent = parent
	end
	return o
end

-- Corners are tight (about half the asked radius, 6 at most), except real circles: a radius of at
-- least half the parent's short side stays as asked.
function UI.corner(r, parent)
	r = r or 10
	local circle = r >= 999
	if parent and not circle then
		local sz = parent.Size
		local short = math.min(sz.X.Offset, sz.Y.Offset)
		circle = sz.X.Scale == 0 and sz.Y.Scale == 0 and short > 0 and r * 2 >= short - 2
	end
	if not circle and parent then
		r = math.min(6, math.max(2, math.floor(r * 0.5 + 0.5)))
	end
	return UI.new("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
end

-- Outlines are thin (heavy outlines read as cartoon)
function UI.stroke(parent, color, thickness, transparency)
	thickness = thickness or 1.5
	if thickness > 1.5 then
		thickness = 1.2 + (thickness - 1.5) * 0.4
	end
	return UI.new("UIStroke", {
		Color = color or T.Outline, Thickness = thickness, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
	})
end

function UI.pad(parent, l, t, r, b)
	return UI.new("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or l or 0),
		PaddingRight = UDim.new(0, r or l or 0), PaddingBottom = UDim.new(0, b or t or l or 0), Parent = parent,
	})
end

function UI.list(parent, dir, padding, hAlign, vAlign)
	return UI.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function UI.gradient(parent, top, bottom, rotation)
	return UI.new("UIGradient", {
		Color = ColorSequence.new(top, bottom), Rotation = rotation or 90, Parent = parent,
	})
end

-- Text. props: any TextLabel props plus Stroke (Color3 outline, or false), StrokeThickness,
-- Weight, Italic, Scaled (TextScaled with a 14 px floor)
function UI.text(props)
	local base = {
		BackgroundTransparency = 1, FontFace = UI.font(props.Weight, props.Italic), TextColor3 = T.White,
		TextSize = 18, TextWrapped = true, Text = "",
	}
	for k, v in pairs(props) do
		if k ~= "Stroke" and k ~= "StrokeThickness" and k ~= "Weight" and k ~= "Italic" and k ~= "Scaled" and k ~= "MaxTextSize" then
			base[k] = v
		end
	end
	if props.Scaled then
		base.TextScaled = true
	end
	local l = UI.new(props.Class or "TextLabel", base)
	if props.Scaled then
		local c = UI.new("UITextSizeConstraint", { MinTextSize = 12, MaxTextSize = props.MaxTextSize or 60, Parent = l })
		if UI.trackMinText then -- (defined further down; labels made while UI loads keep 12)
			UI.trackMinText(c)
		end
	end
	if props.Stroke ~= false then
		UI.new("UIStroke", { Color = props.Stroke or T.Outline, Thickness = math.min(props.StrokeThickness or 1, 1.4), Transparency = 0.4, Parent = l })
	end
	return l
end

-- ===================================================================== motion
local POP_IN = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local POP_OUT = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function scaleOf(obj)
	local s = obj:FindFirstChild("PopScale")
	if not s then
		s = UI.new("UIScale", { Name = "PopScale", Parent = obj })
	end
	return s
end

function UI.popIn(obj, from)
	local s = scaleOf(obj)
	obj:SetAttribute("PopGen", (obj:GetAttribute("PopGen") or 0) + 1)
	obj.Visible = true
	s.Scale = math.max(from or 0.94, 0.9)
	TweenService:Create(s, POP_IN, { Scale = 1 }):Play()
end

function UI.popOut(obj, after)
	local s = scaleOf(obj)
	local gen = (obj:GetAttribute("PopGen") or 0) + 1
	obj:SetAttribute("PopGen", gen)
	TweenService:Create(s, POP_OUT, { Scale = 0.95 }):Play()
	task.delay(0.12, function()
		if obj:GetAttribute("PopGen") == gen then
			obj.Visible = false
			if after then
				after()
			end
		end
	end)
end

-- Press feedback on any GuiButton: a small dip and an ease back (no springy overshoot). Mouse and
-- touch come through MouseButton1; a gamepad's A on the selected button through InputBegan.
function UI.bounce(btn)
	local s = scaleOf(btn)
	local function down()
		TweenService:Create(s, TweenInfo.new(0.06), { Scale = 0.96 }):Play()
	end
	local function up()
		TweenService:Create(s, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	btn.MouseButton1Down:Connect(down)
	btn.MouseButton1Up:Connect(up)
	btn.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonA then
			down()
		end
	end)
	btn.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonA then
			up()
		end
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
end

-- A gentle shake for "can't afford" presses
function UI.shake(obj)
	local p = obj.Position
	for i = 1, 5 do
		obj.Position = p + UDim2.fromOffset((i % 2 == 0) and 4 or -4, 0)
		task.wait(0.03)
	end
	obj.Position = p
end

-- ===================================================================== buttons
-- A UIGradient tints its object's own text, so gradient buttons draw their text in a child "Label"
-- instead. The button's Text / TextSize / TextColor3 / FontFace stay the API (callers set b.Text as
-- usual) and are mirrored onto the label; the button's own text is kept invisible.
function UI.textLayer(b, strokeColor, strokeThickness)
	local label = UI.new("TextLabel", {
		Name = "Label", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(4, 0),
		Text = b.Text, TextSize = b.TextSize, TextColor3 = b.TextColor3, FontFace = b.FontFace, TextWrapped = true,
		ZIndex = b.ZIndex, Parent = b,
	})
	local st = UI.new("UIStroke", { Color = strokeColor or T.Outline, Thickness = math.min(strokeThickness or 1, 1.2), Transparency = 0.3, Parent = label })
	b.TextTransparency = 1
	for _, prop in ipairs({ "Text", "TextSize", "TextColor3", "FontFace", "TextScaled" }) do
		b:GetPropertyChangedSignal(prop):Connect(function()
			label[prop] = b[prop]
		end)
	end
	b:GetPropertyChangedSignal("ZIndex"):Connect(function()
		label.ZIndex = b.ZIndex
	end)
	return label, st
end

-- { top, bottom, text outline, shine, border }
local STYLES = {
	Orange = { rgb(206, 62, 50), rgb(140, 28, 30), rgb(70, 12, 14), rgb(255, 214, 190), rgb(226, 182, 104) }, -- crimson lacquer, gold edge
	Green = { rgb(100, 172, 140), rgb(46, 108, 84), rgb(18, 54, 40), rgb(214, 255, 232), rgb(30, 74, 56) }, -- jade
	Teal = { rgb(66, 64, 72), rgb(30, 29, 35), rgb(10, 10, 12), rgb(200, 196, 190), rgb(150, 128, 88) }, -- ink, muted gold edge
	Cream = { rgb(244, 216, 142), rgb(204, 160, 80), rgb(110, 76, 30), rgb(255, 248, 220), rgb(128, 92, 36) }, -- gold
	Red = { rgb(186, 42, 44), rgb(118, 18, 22), rgb(60, 8, 10), rgb(255, 200, 190), rgb(70, 10, 12) },
	Grey = { rgb(150, 146, 140), rgb(104, 100, 96), rgb(56, 54, 50), rgb(230, 226, 220), rgb(56, 54, 50) },
	-- Robux buttons
	Purple = { rgb(178, 128, 236), rgb(124, 72, 196), rgb(70, 34, 120), rgb(236, 220, 255), rgb(70, 34, 120) },
}
UI.Styles = STYLES

-- Action button: a soft top -> bottom gradient, a thin outline, white text with a faint outline,
-- press feedback + click. opts: Text, Style, Size, Position, AnchorPoint, TextSize, LayoutOrder,
-- Parent, OnClick, Name, Corner
function UI.button(opts)
	local st = STYLES[opts.Style or "Orange"]
	local b = UI.new("TextButton", {
		Name = opts.Name or "Button",
		Size = opts.Size or UDim2.fromOffset(150, 50),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		BackgroundColor3 = T.White,
		AutoButtonColor = false,
		Text = opts.Text or "",
		FontFace = UI.Heavy,
		TextSize = opts.TextSize or 22,
		TextColor3 = (opts.Style == "Cream") and rgb(110, 70, 30) or T.White,
		TextWrapped = true,
		LayoutOrder = opts.LayoutOrder or 0,
		Parent = opts.Parent,
	})
	UI.corner(opts.Corner or 6, b)
	local grad = UI.gradient(b, st[1]:Lerp(st[2], 0.25), st[2])
	local border = UI.stroke(b, st[5], 1.2, 0.1)
	border.Name = "Border"
	local _, textStroke = UI.textLayer(b, st[3], 1)
	textStroke.Name = "TextStroke"
	textStroke.Enabled = opts.Style ~= "Cream"
	-- a soft 1 px highlight along the top edge (depth without a thick rim)
	UI.new("Frame", { Name = "Shine", Size = UDim2.new(1, -10, 0, 1), Position = UDim2.fromOffset(5, 2), BackgroundColor3 = T.White,
		BackgroundTransparency = 0.55, BorderSizePixel = 0, Parent = b })
	b:SetAttribute("Style", opts.Style or "Orange")
	UI.bounce(b)
	b.MouseEnter:Connect(function()
		local cur = STYLES[b:GetAttribute("Style")]
		grad.Color = ColorSequence.new(cur[1]:Lerp(T.White, 0.1), cur[2]:Lerp(T.White, 0.06))
	end)
	b.MouseLeave:Connect(function()
		local cur = STYLES[b:GetAttribute("Style")]
		grad.Color = ColorSequence.new(cur[1]:Lerp(cur[2], 0.25), cur[2])
	end)
	if opts.OnClick then
		b.Activated:Connect(function()
			click()
			opts.OnClick(b)
		end)
	end
	return b
end

function UI.restyle(b, style)
	local st = STYLES[style]
	b:SetAttribute("Style", style)
	b:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(st[1]:Lerp(st[2], 0.25), st[2])
	for _, s in ipairs(b:GetChildren()) do
		if s:IsA("UIStroke") then
			s.Color = s.Name == "Border" and st[5] or st[3]
		end
	end
	local label = b:FindFirstChild("Label")
	local ts = label and label:FindFirstChild("TextStroke")
	if ts then
		ts.Color = st[3]
		ts.Enabled = style ~= "Cream"
	end
	b.TextColor3 = (style == "Cream") and rgb(110, 70, 30) or T.White
end

-- Dark square menu tile with light text (the reference's Beast / Genie / Mount buttons)
function UI.menuTile(opts)
	local b = UI.new("TextButton", {
		Name = opts.Name or "Tile",
		Size = opts.Size or UDim2.fromOffset(92, 92),
		Position = opts.Position or UDim2.new(),
		BackgroundColor3 = T.Panel2,
		AutoButtonColor = false,
		Text = opts.Text or "",
		FontFace = UI.Bold,
		TextSize = opts.TextSize or 20,
		TextColor3 = T.TextLight,
		TextWrapped = true,
		LayoutOrder = opts.LayoutOrder or 0,
		Parent = opts.Parent,
	})
	UI.corner(6, b)
	local st = UI.stroke(b, T.PanelLine, 1.2, 0.35)
	local g = UI.gradient(b, rgb(46, 44, 50), rgb(22, 21, 26))
	UI.textLayer(b, rgb(8, 8, 10), 1.2)
	UI.new("Frame", { Name = "Shine", Size = UDim2.new(1, -10, 0, 1), Position = UDim2.fromOffset(5, 2), BackgroundColor3 = T.White,
		BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = b })
	UI.bounce(b)
	b.MouseEnter:Connect(function()
		b.TextColor3 = T.Gold
		st.Color = T.Gold
		st.Transparency = 0
		g.Color = ColorSequence.new(rgb(62, 56, 52), rgb(30, 27, 28))
	end)
	b.MouseLeave:Connect(function()
		b.TextColor3 = T.TextLight
		st.Color = T.PanelLine
		st.Transparency = 0.35
		g.Color = ColorSequence.new(rgb(46, 44, 50), rgb(22, 21, 26))
	end)
	if opts.OnClick then
		b.Activated:Connect(function()
			click()
			opts.OnClick(b)
		end)
	end
	return b
end

-- A red notification dot in the top-right corner
function UI.dot(parent)
	local d = parent:FindFirstChild("Dot")
	if not d then
		-- centred on the parent's rounded corner (the 45-degree point of the corner arc), so it sits half on
		-- the button instead of floating beside a round one
		local c = parent:FindFirstChildOfClass("UICorner")
		local short = math.min(parent.Size.X.Offset, parent.Size.Y.Offset)
		local r = c and math.min(short / 2, c.CornerRadius.Offset + c.CornerRadius.Scale * short) or 0
		local inset = r * (1 - math.sqrt(0.5))
		d = UI.new("Frame", {
			Name = "Dot", Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -inset, 0, inset), AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = T.Red, ZIndex = (parent.ZIndex or 1) + 5, Parent = parent,
		}, { UI.corner(8), UI.new("UIStroke", { Color = T.White, Thickness = 1.5 }) })
	end
	return d
end

function UI.setDot(parent, on)
	if on then
		UI.dot(parent).Visible = true
	elseif parent:FindFirstChild("Dot") then
		parent.Dot.Visible = false
	end
end

-- One of the custom icons (ReplicatedStorage.Mystree.Icons) as an ImageLabel. key = icon key or a
-- Config currency / material id ("Sap", "Spirit", ...).
function UI.icon(parent, key, size, props)
	local img = UI.new("ImageLabel", {
		Name = "Icon", Image = Icons.get(key), Size = UDim2.fromOffset(size or 28, size or 28), BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit, Parent = parent,
	})
	for k, v in pairs(props or {}) do
		img[k] = v
	end
	return img
end

-- Hover (or tap on touch) tooltip: a small parchment card with a title and a line of help, placed
-- above the object (below it near the top of the screen).
local tip
local tipOwner
local function buildTip()
	local g = UI.new("ScreenGui", { Name = "MystreeTooltip", ResetOnSpawn = false, DisplayOrder = 80, IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None, Parent = UI.PlayerGui })
	local f = UI.new("Frame", { Name = "Tip", Size = UDim2.fromOffset(250, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Parchment,
		Visible = false, Parent = g })
	UI.corner(8, f)
	UI.stroke(f, T.Ornament, 2)
	UI.pad(f, 8, 6, 8, 8)
	UI.list(f, Enum.FillDirection.Vertical, 2)
	local title = UI.text({ Name = "Title", Text = "", Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 17,
		Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, LayoutOrder = 1, Parent = f })
	local body = UI.text({ Name = "Body", Text = "", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 14, TextColor3 = T.InkSoft, Stroke = false, LayoutOrder = 2, Parent = f })
	local s = UI.new("UIScale", { Parent = f })
	tip = { Frame = f, Title = title, Body = body, Scale = s }
end

local function showTip(target, title, body)
	if not tip then
		buildTip()
	end
	tipOwner = target
	tip.Scale.Scale = UI.fitScale()
	tip.Title.Text = title
	tip.Body.Text = body or ""
	tip.Body.Visible = body ~= nil and body ~= ""
	local f = tip.Frame
	f.Visible = true
	task.defer(function()
		if tipOwner ~= target then
			return
		end
		local inset = GuiService:GetGuiInset()
		local pos = target.AbsolutePosition + inset
		local size = target.AbsoluteSize
		local w, h = f.AbsoluteSize.X, f.AbsoluteSize.Y
		local vp = Workspace.CurrentCamera.ViewportSize
		local x = math.clamp(pos.X + size.X / 2 - w / 2, 6, vp.X - w - 6)
		local y = pos.Y - h - 8
		if y < inset.Y + 4 then
			y = pos.Y + size.Y + 8
		end
		f.Position = UDim2.fromOffset(x, y)
	end)
end

local function hideTip(target)
	if tip and tipOwner == target then
		tip.Frame.Visible = false
		tipOwner = nil
	end
end

-- (a tip also goes away when its button is hidden, e.g. its window closes under the mouse: no
-- MouseLeave comes then)
local function visibleOnScreen(obj)
	local o = obj
	while o and o:IsA("GuiObject") do
		if not o.Visible then
			return false
		end
		o = o.Parent
	end
	return obj:IsDescendantOf(game)
end

function UI.tooltip(target, title, body)
	target.MouseEnter:Connect(function()
		showTip(target, title, body)
		target:SetAttribute("_Tip", true)
		task.spawn(function()
			repeat
				task.wait(0.2)
			until not visibleOnScreen(target) or not target:GetAttribute("_Tip")
			hideTip(target)
		end)
	end)
	target.MouseLeave:Connect(function()
		target:SetAttribute("_Tip", nil)
		hideTip(target)
	end)
	target.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			showTip(target, title, body)
			task.delay(2.5, hideTip, target)
		end
	end)
	target.AncestryChanged:Connect(function()
		if not target:IsDescendantOf(game) then
			hideTip(target)
		end
	end)
end

-- Progress bar. Returns frame; set fill with UI.setBar(bar, frac, text)
function UI.bar(opts)
	local f = UI.new("Frame", {
		Name = opts.Name or "Bar", Size = opts.Size or UDim2.fromOffset(300, 18), Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero, BackgroundColor3 = opts.Back or T.Bar, Parent = opts.Parent,
		LayoutOrder = opts.LayoutOrder or 0,
	})
	UI.corner(opts.Corner or 4, f)
	UI.stroke(f, opts.Line or rgb(20, 18, 14), 1.5)
	local fill = UI.new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.White, Parent = f })
	UI.corner(opts.Corner or 4, fill)
	UI.gradient(fill, opts.Color or T.Exp, opts.Color2 or T.ExpDark, 0)
	UI.text({ Name = "Label", Size = UDim2.fromScale(1, 1), Text = "", TextSize = opts.TextSize or 15, Weight = Enum.FontWeight.Bold, Parent = f, ZIndex = 3 })
	return f
end

function UI.setBar(bar, frac, text, tween)
	frac = math.clamp(frac, 0, 1)
	if tween then
		TweenService:Create(bar.Fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(frac, 1) }):Play()
	else
		bar.Fill.Size = UDim2.fromScale(frac, 1)
	end
	if text then
		bar.Label.Text = text
	end
end

-- ===================================================================== screen guis and fit-to-screen
-- Every ScreenGui gets a UIScale from the screen size (design 1100x620). Small screens (phones,
-- under 540 tall) use a tighter 1000x540 design so text and buttons stay big enough to read and
-- tap; every window is at most 960x520, so they still fit.
-- No top-bar inset (user, 2026-10-26: "UIs are too low"): screens ignore Roblox's top bar, and
-- things near the top-left keep clear of Roblox's own buttons with UI.topbarLeft(). Interactive
-- screens do keep to the DEVICE safe area (DeviceSafeInsets: no notch or home bar under a button;
-- no change on PC), and draw past it (ClipToDeviceSafeArea off) so dims and washes still cover.
local scaled = {}
-- the screen size the UI lays out for. In Studio, workspace attribute FakeViewport (a Vector2, e.g.
-- 844, 390) lays everything out as on that screen, in the top-left corner (phone layout checks)
function UI.viewport()
	local fake = RunService:IsStudio() and Workspace:GetAttribute("FakeViewport")
	if typeof(fake) == "Vector2" then
		return fake, true
	end
	local cam = Workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1100, 620), false
end
local refitted = Instance.new("BindableEvent")
UI.Refitted = refitted.Event -- the screen scale changed (also fired for FakeViewport)

local function fitScale()
	local vp = UI.viewport()
	if vp.Y < 540 then
		return math.clamp(math.min(vp.X / 1000, vp.Y / 540), 0.55, 1.5)
	end
	return math.clamp(math.min(vp.X / 1100, vp.Y / 620), 0.55, 1.5)
end

-- TextScaled labels keep 12 drawn pixels however small the screen scale gets
local minTexts = setmetatable({}, { __mode = "k" })
function UI.trackMinText(c)
	minTexts[c] = true
	c.MinTextSize = math.min(c.MaxTextSize, math.max(12, math.ceil(12 / math.min(fitScale(), UI.viewport().Y / 610))))
end

-- design-space x where the developer area of the top bar starts (right of Roblox's menu/chat buttons)
function UI.topbarLeft()
	local ok, rect = pcall(function()
		return GuiService.TopbarInset
	end)
	local px = (ok and rect and rect.Min.X > 0) and rect.Min.X or 120
	return px / fitScale()
end
UI.fitScale = fitScale

-- fullScreen: edge to edge, notch included (washes and covers with no buttons on them).
-- minHeight: design height the screen must always fit (windows + their tabs), so on a short phone
-- it scales down further than the HUD does.
local function scaleFor(e, k, vp)
	return e.MinHeight and math.min(k, vp.Y / e.MinHeight) or k
end

function UI.screen(name, order, fullScreen, minHeight)
	local g = UI.new("ScreenGui", {
		Name = name, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = order or 1, IgnoreGuiInset = true,
		ScreenInsets = fullScreen and Enum.ScreenInsets.None or Enum.ScreenInsets.DeviceSafeInsets, ClipToDeviceSafeArea = false,
		SafeAreaCompatibility = Enum.SafeAreaCompatibility.None, Parent = UI.PlayerGui,
	})
	-- a full-screen root frame that the scale applies to (size is screen / scale so anchors still work)
	local root = UI.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = g })
	local s = UI.new("UIScale", { Name = "Fit", Parent = root })
	local e = { Root = root, Scale = s, MinHeight = minHeight }
	table.insert(scaled, e)
	local vp, fake = UI.viewport()
	local k = scaleFor(e, fitScale(), vp)
	s.Scale = k
	root.Size = fake and UDim2.fromOffset(vp.X / k, vp.Y / k) or UDim2.fromScale(1 / k, 1 / k)
	return g, root
end

local function refit()
	local base = fitScale()
	local vp, fake = UI.viewport()
	for _, e in ipairs(scaled) do
		local k = scaleFor(e, base, vp)
		e.Scale.Scale = k
		e.Root.Size = fake and UDim2.fromOffset(vp.X / k, vp.Y / k) or UDim2.fromScale(1 / k, 1 / k)
	end
	local k = math.min(base, vp.Y / 610) -- (the smallest scale in use: the windows')
	for c in pairs(minTexts) do
		c.MinTextSize = math.min(c.MaxTextSize, math.max(12, math.ceil(12 / k)))
	end
end
task.spawn(function()
	local cam = Workspace.CurrentCamera
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("FakeViewport"):Connect(function()
			refit()
			refitted:Fire()
		end)
	end
end)

-- ===================================================================== decorative bits
-- Gold-grey corner ornaments for dark panels (two short lines meeting at each top corner)
function UI.ornaments(frame, color)
	color = color or T.Ornament
	for _, sx in ipairs({ 0, 1 }) do
		local a = UI.new("Frame", { Name = "Orn", BackgroundTransparency = 1, Size = UDim2.fromOffset(34, 34),
			Position = UDim2.new(sx, sx == 0 and 4 or -38, 0, 4), Parent = frame })
		UI.new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.fromOffset(0, 0), BackgroundColor3 = color, Parent = a })
		UI.new("Frame", { Size = UDim2.new(0, 2, 1, 0), Position = UDim2.new(sx, sx == 0 and 0 or -2, 0, 0), BackgroundColor3 = color, Parent = a })
		UI.new("Frame", { Size = UDim2.fromOffset(7, 7), Position = UDim2.new(sx, sx == 0 and 6 or -13, 0, 6), Rotation = 45, BackgroundColor3 = color, Parent = a })
	end
end

-- Faint diagonal pattern (a 20-key alternating gradient, Playbook 07) for panel bodies
function UI.pattern(parent, color, alpha, rotation)
	local f = UI.new("Frame", { Name = "Pattern", Size = UDim2.fromScale(1, 1), BackgroundColor3 = color or T.White,
		BackgroundTransparency = 0, ZIndex = parent.ZIndex, Parent = parent })
	local corner = parent:FindFirstChildOfClass("UICorner")
	if corner then
		UI.corner(corner.CornerRadius.Offset, f)
	end
	local keys = {}
	for i = 0, 19 do
		table.insert(keys, NumberSequenceKeypoint.new(i / 19, (i % 2 == 0) and (1 - (alpha or 0.04)) or 1))
	end
	UI.new("UIGradient", { Transparency = NumberSequence.new(keys), Rotation = rotation or 35, Parent = f })
	return f
end

-- ===================================================================== depth and motion helpers
-- A soft drop shadow: two darker rounded frames behind obj (siblings, lower ZIndex), offset down.
function UI.shadow(obj, radius, strength)
	local parent = obj.Parent
	if not parent then
		return
	end
	local r = radius or 10
	for i, a in ipairs({ 0.72, 0.86 }) do
		local sh = UI.new("Frame", {
			Name = obj.Name .. "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = a + (1 - (strength or 1)) * 0.2,
			Size = obj.Size + UDim2.fromOffset(i * 4, i * 4), Position = obj.Position + UDim2.fromOffset(-i * 2, 3 + i * 2),
			AnchorPoint = obj.AnchorPoint, ZIndex = math.max(0, obj.ZIndex - 1), LayoutOrder = obj.LayoutOrder, Visible = obj.Visible, Parent = parent,
		})
		sh:SetAttribute("Shadow", true)
		UI.corner(r + i * 2, sh)
		-- follow the object when it moves, resizes or hides
		local function sync()
			sh.Position = obj.Position + UDim2.fromOffset(-i * 2, 3 + i * 2)
			sh.Size = obj.Size + UDim2.fromOffset(i * 4, i * 4)
			sh.Visible = obj.Visible
		end
		obj:GetPropertyChangedSignal("Position"):Connect(sync)
		obj:GetPropertyChangedSignal("Size"):Connect(sync)
		obj:GetPropertyChangedSignal("Visible"):Connect(sync)
	end
end

-- Smoothly show or hide a CanvasGroup (fade + a small slide). from = slide offset (UDim2) when hidden.
local fadeGen = {}
function UI.fade(group, show, from, time)
	local t = time or 0.22
	fadeGen[group] = (fadeGen[group] or 0) + 1
	local gen = fadeGen[group]
	local home = group:GetAttribute("HomePos")
	if not home then
		group:SetAttribute("HomePos", group.Position)
		home = group.Position
	end
	local away = home + (from or UDim2.fromOffset(0, 20))
	if show then
		if not group.Visible then
			group.Visible = true
			group.GroupTransparency = 1
			group.Position = away
		end
		TweenService:Create(group, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { GroupTransparency = 0, Position = home }):Play()
	elseif group.Visible then
		TweenService:Create(group, TweenInfo.new(t * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1, Position = away }):Play()
		task.delay(t * 0.8, function()
			if fadeGen[group] == gen then
				group.Visible = false
			end
		end)
	end
end

-- Background blur while a window is open (smooth in and out)
local blur = Instance.new("BlurEffect")
blur.Name = "MystreeWindowBlur"
blur.Size = 0
blur.Parent = game:GetService("Lighting")
local function setBlur(on)
	TweenService:Create(blur, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = on and 10 or 0 }):Play()
end

-- ===================================================================== windows
-- One window open at a time, a dim backdrop that closes it, pop in/out.
local winGui, winRoot = UI.screen("MystreeWindows", 20, false, 610) -- the tallest window plus the Shop's tabs
local backdrop = UI.new("TextButton", {
	Name = "Backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = rgb(8, 8, 10), BackgroundTransparency = 1,
	Size = UDim2.fromScale(4, 4), Position = UDim2.fromScale(-1.5, -1.5), Visible = false, Parent = winRoot,
})
local openWindow
UI.WindowRoot = winRoot

-- gamepad: a menu that opens puts the selection on its first button (and the close button when it
-- has none); closing clears it. Only for gamepad players, so mouse users never see the outline.
local function usingGamepad()
	local t = UserInputService:GetLastInputType()
	return t.Name:sub(1, 7) == "Gamepad"
end
local function selectIn(frame, fallback)
	if not usingGamepad() then
		return
	end
	local best
	for _, d in ipairs(frame:GetDescendants()) do
		if d:IsA("GuiButton") and d.Visible and d.Selectable and d.Name ~= "Close" then
			if not best or d.AbsolutePosition.Y < best.AbsolutePosition.Y - 2
				or (math.abs(d.AbsolutePosition.Y - best.AbsolutePosition.Y) <= 2 and d.AbsolutePosition.X < best.AbsolutePosition.X) then
				best = d
			end
		end
	end
	GuiService.SelectedObject = best or fallback
end
UI.selectIn = selectIn

function UI.closeWindow()
	local w = openWindow
	openWindow = nil
	if w and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(w.Frame) then
		GuiService.SelectedObject = nil
	end
	if w then
		UI.popOut(w.Frame, w.OnClose)
	end
	TweenService:Create(backdrop, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	setBlur(false)
	task.delay(0.15, function()
		if not openWindow then
			backdrop.Visible = false
		end
	end)
end
backdrop.Activated:Connect(UI.closeWindow)

function UI.isOpen(w)
	return openWindow == w
end

-- the window that is open now (nil when none)
function UI.current()
	return openWindow
end

-- murim art from the VFX Library (white on transparent, tinted in place)
local INK_SPLASH = "rbxassetid://16132530029" -- "Ink splash": title brush strokes, the bloom behind opening windows
local CLOUD_SCROLL = "rbxassetid://103967826475791" -- "Dragon_Pearl_Mask_01": a cloud-scroll pattern
UI.Art = { InkSplash = INK_SPLASH, CloudScroll = CLOUD_SCROLL, KeyRing = "rbxassetid://93858335764593" }

-- an ink splash that blooms and fades behind a window as it opens
local function inkBloom(frame)
	local w, h = frame.Size.X.Offset, frame.Size.Y.Offset
	local splash = UI.new("ImageLabel", { Name = "InkBloom", Image = INK_SPLASH, ImageColor3 = rgb(8, 8, 10), ImageTransparency = 0.3,
		BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Stretch, AnchorPoint = Vector2.new(0.5, 0.5), Position = frame.Position,
		Size = UDim2.fromOffset(w * 0.8, h * 0.8), ZIndex = 1, Parent = frame.Parent })
	TweenService:Create(splash, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(w * 1.35, h * 1.3), ImageTransparency = 1 }):Play()
	task.delay(0.55, function()
		splash:Destroy()
	end)
end

-- opts: Title, Size (Vector2 design px), OnOpen, OnClose. Returns window { Frame, Body, Header, Title, open(), close() }
function UI.window(opts)
	local size = opts.Size or Vector2.new(760, 520)
	local frame = UI.new("Frame", {
		Name = opts.Title, Size = UDim2.fromOffset(size.X, size.Y), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52), BackgroundColor3 = T.Parchment, Visible = false, ZIndex = 2, Parent = winRoot,
	})
	UI.corner(8, frame)
	UI.stroke(frame, T.Ornament, 1.5, 0.1)
	-- a faint cloud-scroll watermark in the paper's lower corner
	UI.new("ImageLabel", { Name = "Watermark", Image = CLOUD_SCROLL, ImageColor3 = rgb(150, 116, 70), ImageTransparency = 0.82,
		BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(280, 280), AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -6, 1, -6), ZIndex = 2, Parent = frame })
	UI.shadow(frame, 8, 0.9)
	local header = UI.new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = T.White, ZIndex = 3, ClipsDescendants = true, Parent = frame })
	UI.corner(8, header)
	UI.gradient(header, T.Header, T.HeaderDark)
	-- square off the header's bottom corners
	UI.new("Frame", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12), BackgroundColor3 = T.HeaderDark, BorderSizePixel = 0, ZIndex = 3, Parent = header })
	-- a crimson brush stroke behind the title
	UI.new("ImageLabel", { Name = "Brush", Image = INK_SPLASH, ImageColor3 = rgb(214, 58, 50), ImageTransparency = 0, BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Stretch, Size = UDim2.fromOffset(360, 104), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		ZIndex = 4, Parent = header })
	-- a thin gold rule under the header, fading out at both ends
	local rule = UI.new("Frame", { Name = "Line", Size = UDim2.new(1, 0, 0, 2), Position = UDim2.fromOffset(0, 58), BackgroundColor3 = T.Ornament, BorderSizePixel = 0, ZIndex = 4, Parent = frame })
	UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.7) }), Parent = rule })
	local title = UI.text({ Name = "Title", Text = opts.Title, Size = UDim2.new(1, -140, 1, 0), Position = UDim2.fromOffset(70, 0),
		TextSize = 27, TextColor3 = T.Cream, Stroke = T.Outline, StrokeThickness = 1.5, ZIndex = 5, Parent = header })
	title.FontFace = UI.Serif
	-- close: a crimson seal stamp
	local close = UI.new("TextButton", {
		Name = "Close", Text = "X", FontFace = UI.font(Enum.FontWeight.Bold), TextSize = 22, TextColor3 = T.White, AutoButtonColor = false,
		BackgroundColor3 = T.Crimson, Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -48, 0, 10), ZIndex = 6, Parent = frame,
	})
	UI.corner(4, close)
	UI.stroke(close, T.Ornament, 1.2, 0.2)
	close.MouseEnter:Connect(function()
		TweenService:Create(close, TweenInfo.new(0.12), { BackgroundColor3 = T.Crimson:Lerp(T.White, 0.15) }):Play()
	end)
	close.MouseLeave:Connect(function()
		TweenService:Create(close, TweenInfo.new(0.12), { BackgroundColor3 = T.Crimson }):Play()
	end)
	UI.bounce(close)
	local body = UI.new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, -74), Position = UDim2.fromOffset(12, 66), ZIndex = 3, Parent = frame })
	local w = { Frame = frame, Body = body, Header = header, Title = title, OnClose = opts.OnClose }
	function w.open()
		if openWindow == w then
			return
		end
		if openWindow then
			local prev = openWindow
			openWindow = nil
			prev.Frame.Visible = false
			if prev.OnClose then
				prev.OnClose()
			end
		end
		openWindow = w
		backdrop.Visible = true
		TweenService:Create(backdrop, TweenInfo.new(0.2), { BackgroundTransparency = 0.55 }):Play()
		setBlur(true)
		if opts.OnOpen then
			opts.OnOpen()
		end
		inkBloom(frame)
		UI.popIn(frame)
		task.defer(selectIn, frame, close)
		if Sounds then
			Sounds.play("Pop", 1.1, 0.6)
		end
	end
	function w.close()
		if openWindow == w then
			UI.closeWindow()
		end
	end
	function w.toggle()
		if openWindow == w then
			w.close()
		else
			w.open()
		end
	end
	close.Activated:Connect(function()
		click()
		w.close()
	end)
	return w
end

-- ===================================================================== fitting to content
-- User rule: no big empty space inside any window, card or prompt. Size containers from what is in
-- them instead of a fixed box.
-- A window whose Body is exactly bodyHeight tall (the Body is the frame minus the 74 px header);
-- width is optional. Safe to call while open: the frame is centred on its anchor.
function UI.fitWindow(w, bodyHeight, width)
	w.Frame.Size = UDim2.fromOffset(width or w.Frame.Size.X.Offset, math.floor(bodyHeight + 74 + 0.5))
end

-- Width in design px of one line of UI.text (for pills and cards that hug their label). May yield.
function UI.textWidth(text, size, weight)
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Size = size
	params.Font = UI.font(weight)
	params.Width = 4000
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	return ok and bounds.X or #text * size * 0.56
end

-- Show a ScrollingFrame's bar only while its content overflows (no empty scroll track)
function UI.autoScrollBar(sf, thickness)
	local function update()
		local canvas, view = sf.AbsoluteCanvasSize, sf.AbsoluteWindowSize
		sf.ScrollBarThickness = (canvas.Y > view.Y + 1 or canvas.X > view.X + 1) and (thickness or 8) or 0
	end
	sf:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(update)
	sf:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(update)
	update()
end

-- Bottom tab strip for a window (the reference's Beast / Bond / Summon). tabs = { {Name, Build(page)} }
-- Returns { select(name), Pages = {name = frame}, Buttons = {name = button} }
function UI.tabs(win, tabs, onSelect)
	local strip = UI.new("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 54),
		Position = UDim2.new(0, 20, 1, 6), ZIndex = 4, Parent = win.Frame })
	UI.list(strip, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center)
	-- the tab strip hangs below the window: lift the window so both fit on short screens
	win.Frame.Position = UDim2.new(0.5, 0, 0.5, -32)
	local pagesFrame = UI.new("Frame", { Name = "Pages", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 3, Parent = win.Body })
	local res = { Pages = {}, Buttons = {}, Current = nil }
	local order = {}
	for i, t in ipairs(tabs) do
		order[t.Name] = i
		local page = UI.new("Frame", { Name = t.Name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 3, Parent = pagesFrame })
		res.Pages[t.Name] = page
		local b = UI.button({ Text = t.Name, Style = "Teal", Size = UDim2.fromOffset(190, 44), TextSize = 19, LayoutOrder = i, Parent = strip })
		b.ZIndex = 4
		res.Buttons[t.Name] = b
		b.Activated:Connect(function()
			click()
			res.select(t.Name)
		end)
		if t.Build then
			t.Build(page)
		end
	end
	function res.select(name)
		if res.Current == name then
			return
		end
		local prev = res.Current
		res.Current = name
		for n, page in pairs(res.Pages) do
			UI.restyle(res.Buttons[n], n == name and "Cream" or "Teal")
			if n == name then
				page.Visible = true
				if prev then
					local dir = (order[name] > order[prev]) and 1 or -1
					page.Position = UDim2.fromScale(0.25 * dir, 0)
					TweenService:Create(page, TweenInfo.new(0.24, Enum.EasingStyle.Quint), { Position = UDim2.fromScale(0, 0) }):Play()
				end
				local s = scaleOf(res.Buttons[n])
				s.Scale = 1.04
				TweenService:Create(s, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
			else
				page.Visible = false
			end
		end
		if onSelect then
			onSelect(name)
		end
	end
	return res
end

-- ===================================================================== rarity tiles and 3D previews
-- Rarity tile: rounded square in the rarity colour with a soft vignette, an optional 3D model,
-- "Lv.4" bottom-right. Returns tile (TextButton), tile.Viewport for setModel.
function UI.tile(opts)
	local c = UI.rarityColor(opts.Rarity)
	local b = UI.new("TextButton", {
		Name = opts.Name or "Tile", Text = "", AutoButtonColor = false, Size = opts.Size or UDim2.fromOffset(86, 86),
		Position = opts.Position or UDim2.new(), BackgroundColor3 = T.White, LayoutOrder = opts.LayoutOrder or 0,
		Parent = opts.Parent,
	})
	UI.corner(6, b)
	local g = UI.gradient(b, c:Lerp(T.White, 0.28), c:Lerp(rgb(30, 30, 30), 0.12), 90)
	g.Name = "RarityGradient"
	local st = UI.stroke(b, c:Lerp(rgb(20, 20, 20), 0.45), 2)
	st.Name = "RarityStroke"
	local vp = UI.new("ViewportFrame", { Name = "Viewport", BackgroundTransparency = 1, Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3), Ambient = rgb(170, 170, 170), LightColor = rgb(255, 250, 240),
		LightDirection = Vector3.new(-1, -1.4, -1), Parent = b })
	UI.text({ Name = "Level", Text = opts.Level or "", Size = UDim2.new(1, -6, 0, 20), Position = UDim2.new(0, 0, 1, -22),
		TextXAlignment = Enum.TextXAlignment.Right, TextSize = 16, Weight = Enum.FontWeight.Heavy, Parent = b, ZIndex = 4 })
	UI.text({ Name = "Caption", Text = opts.Caption or "", Size = UDim2.new(1, 0, 1, 0), TextSize = opts.CaptionSize or 18,
		Weight = Enum.FontWeight.Heavy, Parent = b, ZIndex = 4 })
	UI.bounce(b)
	local baseThickness = st.Thickness
	b.MouseEnter:Connect(function()
		st.Thickness = baseThickness + 1
	end)
	b.MouseLeave:Connect(function()
		st.Thickness = baseThickness
	end)
	if opts.OnClick then
		b.Activated:Connect(function()
			click()
			opts.OnClick(b)
		end)
	end
	return b
end

function UI.setTileRarity(tile, r)
	local c = UI.rarityColor(r)
	tile.RarityGradient.Color = ColorSequence.new(c:Lerp(T.White, 0.28), c:Lerp(rgb(30, 30, 30), 0.12))
	tile.RarityStroke.Color = c:Lerp(rgb(20, 20, 20), 0.45)
end

-- Put a model in a ViewportFrame, framed to fit. spin = degrees of yaw for a 3/4 look.
function UI.setModel(vp, model, yaw, pitch, zoom)
	for _, c in ipairs(vp:GetChildren()) do
		if c:IsA("Model") or c:IsA("BasePart") or c:IsA("Camera") or c:IsA("WorldModel") then
			c:Destroy()
		end
	end
	if not model then
		return
	end
	local cam = UI.new("Camera", { FieldOfView = 30, Parent = vp })
	vp.CurrentCamera = cam
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local r = size.Magnitude / 2
	local dist = r / math.tan(math.rad(cam.FieldOfView / 2)) * (zoom or 1.05)
	local dir = CFrame.Angles(0, math.rad(yaw or 35), 0) * CFrame.Angles(math.rad(pitch or -18), 0, 0)
	cam.CFrame = CFrame.new(cf.Position) * dir * CFrame.new(0, 0, dist)
	return cam
end

return UI
