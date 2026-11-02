-- StarterPlayerScripts/MystreeClient/Notify (ModuleScript)
-- Messages: toasts under the top bar (Notify event and Notify.toast), the big server-wide alert banner
-- across the top ("GODLY SKELETON HAS SPAWNED!"), level-up / growth moments, the welcome-back card
-- and the daily gift card. One placement function for toasts, so nothing else pushes them around.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)
local Fx = require(script.Parent.Fx)

local Notify = {}
local T = UI.T
-- seconds the welcome-back toast stays up (user: "make it last longer"). Here, not in Config, only
-- until Config's next push (it carries unapproved boss changes right now)
local WELCOME_TIME = 9
local player = Players.LocalPlayer

-- colour per message kind (rarity names use the rarity colours)
local KIND = {
	Error = T.Red,
	Info = T.Teal,
	Purchase = Color3.fromRGB(170, 110, 230),
	Growth = Color3.fromRGB(120, 210, 120),
	Bloodmoon = Color3.fromRGB(200, 40, 40),
	GoldenHour = Color3.fromRGB(255, 196, 70),
	Elite = Color3.fromRGB(240, 140, 60),
	Night = Color3.fromRGB(110, 130, 200),
	Day = Color3.fromRGB(250, 220, 130),
	Mount = Color3.fromRGB(150, 220, 180),
}
for _, r in ipairs(Config.Rarities) do
	KIND[r.Name] = r.Color
end
-- During the tutorial only tutorial messages show (user, 2026-10-26): everything else is dropped,
-- except errors about the player's own action ("Walk up to your tree"). Cards wait until it ends.
local function inTutorial()
	local i = player:GetAttribute("Tutorial")
	return i ~= nil and i <= #Config.Tutorial
end
Notify.inTutorial = inTutorial

function Notify.color(kind)
	return KIND[kind] or T.Teal
end

local gui, root = UI.screen("MystreeNotify", 30)
local stack = UI.new("Frame", { Name = "Toasts", BackgroundTransparency = 1, Size = UDim2.fromOffset(560, 400),
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 54), Parent = root })
-- toasts sit right under the clock; when the tutorial or visiting pill is up they go below it
local function placeStack()
	local visiting = (player:GetAttribute("Visiting") or 0) ~= 0
	local y = inTutorial() and 178 or (visiting and 132 or 54)
	TweenService:Create(stack, TweenInfo.new(0.2), { Position = UDim2.new(0.5, 0, 0, y) }):Play()
end
player:GetAttributeChangedSignal("Tutorial"):Connect(placeStack)
player:GetAttributeChangedSignal("Visiting"):Connect(placeStack)
UI.list(stack, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)

local order = 0
-- force = a tutorial message (always shown); hold = seconds on screen (default 4)
function Notify.toast(text, kind, force, hold)
	if not text or text == "" then
		return
	end
	if inTutorial() and not force and kind ~= "Error" then
		return
	end
	order += 1
	local c = Notify.color(kind)
	-- a CanvasGroup so the whole toast fades as one; it drops in from above
	local f = UI.new("CanvasGroup", { Size = UDim2.fromOffset(520, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Panel,
		BackgroundTransparency = 0.06, LayoutOrder = order, GroupTransparency = 1, Parent = stack })
	UI.corner(12, f)
	UI.stroke(f, c, 1.6)
	UI.pad(f, 18, 9)
	UI.gradient(f, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 210, 210), 90)
	UI.new("Frame", { Size = UDim2.new(0, 5, 1, 0), Position = UDim2.fromOffset(-12, 0), BackgroundColor3 = c, Parent = f }, { UI.corner(3) })
	UI.text({ Text = text, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 19, Weight = Enum.FontWeight.Bold, TextColor3 = T.White, Parent = f })
	local s = UI.new("UIScale", { Name = "PopScale", Scale = 0.92, Parent = f })
	TweenService:Create(f, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { GroupTransparency = 0 }):Play()
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- keep at most 4
	local toasts = {}
	for _, ch in ipairs(stack:GetChildren()) do
		if ch:IsA("GuiObject") then
			table.insert(toasts, ch)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - 4 do
		toasts[i]:Destroy()
	end
	task.delay(hold or 4, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
			TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Scale = 0.94 }):Play()
			task.delay(0.3, function()
				f:Destroy()
			end)
		end
	end)
end

function Notify.error(text)
	Sounds.play("Error")
	Notify.toast(text, "Error")
end

-- ===================================================================== the big alert
local alert = UI.new("Frame", { Name = "Alert", Size = UDim2.new(1, 0, 0, 96), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, Parent = root })
local alertBand = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.White, Parent = alert })
local alertGrad = UI.new("UIGradient", { Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.15), NumberSequenceKeypoint.new(0.8, 0.15), NumberSequenceKeypoint.new(1, 1),
}), Parent = alertBand })
local alertText = UI.text({ Text = "", Size = UDim2.new(1, -40, 1, -10), Position = UDim2.fromOffset(20, 5), TextSize = 46,
	Weight = Enum.FontWeight.Heavy, Italic = true, StrokeThickness = 3, Parent = alert })
local shine = UI.new("Frame", { Size = UDim2.new(0, 120, 1, 0), BackgroundColor3 = T.White, BackgroundTransparency = 0.6, Rotation = 0, Parent = alert })
UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1) }), Parent = shine })

local alertQueue = {}
local alertBusy = false
local function runAlerts()
	if alertBusy then
		return
	end
	alertBusy = true
	while #alertQueue > 0 do
		local a = table.remove(alertQueue, 1)
		local c = Notify.color(a.Kind)
		alertBand.BackgroundColor3 = c:Lerp(Color3.new(0, 0, 0), 0.45)
		alertText.Text = a.Text
		alertText.TextColor3 = c:Lerp(Color3.new(1, 1, 1), 0.55)
		alert.Visible = true
		alert.Position = UDim2.new(0.5, 0, 0, -110)
		TweenService:Create(alert, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 70) }):Play()
		Sounds.play("Alert")
		Fx.flash(c, 0.8, 0.5)
		Fx.shake(1.2, 0.5)
		-- pulse the text and sweep the shine across
		for i = 1, 3 do
			shine.Position = UDim2.new(0, -140, 0, 0)
			TweenService:Create(shine, TweenInfo.new(0.7), { Position = UDim2.new(1, 20, 0, 0) }):Play()
			local s = alertText:FindFirstChild("PopScale") or UI.new("UIScale", { Name = "PopScale", Parent = alertText })
			s.Scale = 1.12
			TweenService:Create(s, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			task.wait(i == 1 and 1.2 or 1)
		end
		TweenService:Create(alert, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, -110) }):Play()
		task.wait(0.3)
		alert.Visible = false
	end
	alertBusy = false
end

function Notify.alert(text, kind)
	if inTutorial() then
		return
	end
	table.insert(alertQueue, { Text = text, Kind = kind })
	task.spawn(runAlerts)
end

-- ===================================================================== centre moments (level up, growth)
local moment = UI.new("Frame", { Name = "Moment", Size = UDim2.fromOffset(700, 150), AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36), BackgroundTransparency = 1, Visible = false, Parent = root })
local momentTitle = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 80), TextSize = 64, Weight = Enum.FontWeight.Heavy, Italic = true,
	TextColor3 = T.Gold, Stroke = Color3.fromRGB(90, 50, 10), StrokeThickness = 3.5, Parent = moment })
local momentSub = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 84), TextSize = 30,
	Weight = Enum.FontWeight.Heavy, Parent = moment })

function Notify.moment(title, sub, color, force)
	if inTutorial() and not force then
		return
	end
	momentTitle.Text = title
	momentTitle.TextColor3 = color or T.Gold
	momentSub.Text = sub or ""
	UI.popIn(moment, 0.4)
	task.delay(2.4, function()
		UI.popOut(moment)
	end)
end

-- ===================================================================== cards (welcome back, daily gift)
-- sized to its lines: no empty middle (user rule, 2026-10-26)
local function card(title, lines, buttonText, onButton)
	local w = UI.window({ Title = title, Size = Vector2.new(440, 300) })
	local body = w.Body
	local y = 4
	for _, line in ipairs(lines) do
		UI.text({ Text = line, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, y), TextSize = 26, TextColor3 = T.Ink, Stroke = false, Weight = Enum.FontWeight.Heavy, Parent = body })
		y += 40
	end
	UI.fitWindow(w, y + 12 + 62 + 4)
	UI.button({ Text = buttonText, Style = "Orange", Size = UDim2.fromOffset(240, 62), AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4), TextSize = 28, Parent = body, OnClick = function()
			w.close()
			if onButton then
				onButton()
			end
		end })
	w.open()
	return w
end

local function rewardLines(gift)
	local lines = {}
	for k, n in pairs(gift) do
		local name = (Config.Currencies[k] and Config.Currencies[k].Name) or (Config.Materials[k] and Config.Materials[k].Name) or k
		table.insert(lines, "+" .. Format.Num(n) .. " " .. name)
	end
	table.sort(lines)
	return lines
end

local maybeDaily, maybeDailyNow
maybeDaily = function()
	-- never on top of a summon cinematic
	if UI.Busy then
		task.delay(1, maybeDaily)
		return
	end
	return maybeDailyNow()
end
maybeDailyNow = function()
	local today = workspace:GetAttribute("UtcDay")
	if not today or State.Daily.Day == today then
		return
	end
	local streak = (State.Daily.Day == today - 1) and State.Daily.Streak + 1 or 1
	local gift = Config.Daily.Gifts[((streak - 1) % #Config.Daily.Gifts) + 1]
	local lines = { "Day " .. streak .. " of your streak" }
	for _, l in ipairs(rewardLines(gift)) do
		table.insert(lines, l)
	end
	card("Daily Gift", lines, "Claim!", function()
		local ok, msg = Net.invoke("ClaimDaily")
		if ok then
			Sounds.play("Coin")
			Notify.toast("🎁 " .. msg, "Legendary")
		else
			Notify.error(msg)
		end
	end)
end

-- runs fn once the loading screen has handed over (ReplicatedFirst.MystreeLoading sets "Loaded"), so
-- nothing on join shows, or times out, behind it
local function afterLoaded(fn)
	task.spawn(function()
		local t0 = os.clock()
		while not player:GetAttribute("Loaded") and os.clock() - t0 < 60 do
			task.wait(0.2)
		end
		fn()
	end)
end

function Notify.Start(C)
	Net.get("Notify").OnClientEvent:Connect(function(text, kind)
		Notify.toast(text, kind)
	end)
	Net.get("Alert").OnClientEvent:Connect(Notify.alert)
	Net.get("Welcome").OnClientEvent:Connect(function(info)
		if inTutorial() then
			return
		end
		-- a short toast that leaves by itself, not a card to click away (user, 2026-10-27); only
		-- when something was gained
		local gains = {}
		if info.Grew then
			table.insert(gains, "your tree reached Lv " .. info.Grew)
		end
		if #gains == 0 then
			return
		end
		afterLoaded(function()
			Sounds.play("Coin")
			Notify.toast("Welcome back! While you were away (" .. Format.Time(info.Away) .. "): " .. table.concat(gains, ", ") .. ".", "Growth", false, WELCOME_TIME)
		end)
	end)
	Net.get("Effect").OnClientEvent:Connect(function(kind, a, b)
		if kind == "LevelUp" then
			Sounds.play("LevelUp")
			Notify.moment("LEVEL UP!", "Lv." .. a .. " · " .. b)
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				Fx.ring(hrp.Position - Vector3.new(0, 2.8, 0), T.Gold, 22, 0.7)
				Fx.burst(hrp.Position, { Texture = "Glow", Color = T.Gold, Count = 30, Speed = { 8, 18 }, Size = 0.8, Gravity = Vector3.new(0, 10, 0), Light = 1, Lifetime = { 0.8, 1.4 } })
			end
		elseif kind == "Growth" then
			Sounds.play("Legendary", 1.1)
			Notify.moment("YOUR TREE GREW!", "Divine Tree Lv " .. a .. " · rarer drops unlocked", Color3.fromRGB(150, 235, 140))
		elseif kind == "Purchase" then
			Sounds.play("Coin")
		elseif kind == "Mount" then
			Sounds.play("Epic")
			Notify.moment("NEW MOUNT!", Config.Mounts[a] and Config.Mounts[a].Name or a, Color3.fromRGB(150, 220, 180))
		end
	end)
	-- the daily gift on join, once the welcome-back toast has gone
	afterLoaded(function()
		task.wait(WELCOME_TIME + 1)
		if inTutorial() then
			-- the gift waits for the tutorial to finish
			local conn
			conn = player:GetAttributeChangedSignal("Tutorial"):Connect(function()
				if not inTutorial() then
					conn:Disconnect()
					task.delay(5, maybeDaily)
				end
			end)
		elseif not UI.isOpen(nil) then
			maybeDaily()
		end
	end)
	C.Notify = Notify
end

return Notify
