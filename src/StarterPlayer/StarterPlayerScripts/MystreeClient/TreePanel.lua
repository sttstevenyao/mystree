-- StarterPlayerScripts/MystreeClient/TreePanel (ModuleScript)
-- The Divine Tree window: level and stage, drop odds now vs next level, growth cost with what you
-- have, the Grow button, and while growing a live countdown with Instant Growth (the paid shortcut
-- sits where the wait is, Playbook 03).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Mystree.Config)
local Rules = require(ReplicatedStorage.Mystree.Rules)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local Purchase = require(script.Parent.Purchase)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local TreePanel = {}
local T = UI.T
local player = Players.LocalPlayer

local C
local win
local refs = {}

local function toast(text, kind)
	if C and C.Notify and text then
		C.Notify.toast(text, kind)
	end
end

local function fail(btn, msg)
	Sounds.play("Error")
	toast(msg, "Error")
	if btn then
		task.spawn(UI.shake, btn)
	end
end

-- Studio test grant for Id 0 products, the real prompt otherwise
local function buy(key, btn)
	local ok, msg = Purchase.buy(key)
	if not ok then
		fail(btn, msg)
	elseif msg then
		toast(msg, "Purchase")
	end
end

local function stageOf(level)
	return math.clamp(1 + (level - 1) // Config.Tree.StageEvery, 1, 5)
end

local function have(key)
	if Config.Materials[key] then
		return State.attr("Mat_" .. key, 0)
	end
	return State.attr(key, 0)
end

local function nameOf(key)
	if Config.Materials[key] then
		return Config.Materials[key].Name
	end
	return Config.Currencies[key] and Config.Currencies[key].Name or key
end

-- ===================================================================== build
local function build(body)
	-- left column: level, stage, peaches, growth
	local left = UI.new("Frame", { BackgroundColor3 = T.Panel, Size = UDim2.new(0, 400, 1, 0), Parent = body })
	UI.corner(8, left)
	UI.stroke(left, T.PanelLine, 1.5, 0.3)
	UI.ornaments(left)
	UI.pad(left, 16, 14)
	refs.Level = UI.text({ Text = "Lv 1", Size = UDim2.new(1, 0, 0, 56), TextSize = 50, Weight = Enum.FontWeight.Heavy,
		TextColor3 = T.Gold, Stroke = T.OrangeLine, StrokeThickness = 2.5, Parent = left })
	refs.Stage = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 56), TextSize = 18,
		TextColor3 = T.TextLight, Parent = left })
	refs.Peaches = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 84), TextSize = 17,
		TextColor3 = T.TextLight, Parent = left })
	UI.new("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.fromOffset(0, 134), BackgroundColor3 = T.Ornament, BackgroundTransparency = 0.4, Parent = left })
	UI.text({ Text = "Grow to the next level", Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 142), TextSize = 20,
		Weight = Enum.FontWeight.Heavy, TextColor3 = T.White, Parent = left })
	refs.Cost = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 140), Position = UDim2.fromOffset(0, 172), Parent = left })
	UI.list(refs.Cost, Enum.FillDirection.Vertical, 4)
	refs.Timer = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 1, -112), TextSize = 26,
		Weight = Enum.FontWeight.Heavy, TextColor3 = T.Gold, Parent = left })
	local row = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), Position = UDim2.new(0, 0, 1, -66), Parent = left })
	UI.list(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	refs.Grow = UI.button({ Text = "Grow", Style = "Orange", Size = UDim2.fromOffset(170, 62), TextSize = 26, LayoutOrder = 1, Parent = row,
		OnClick = function(b)
			local ok, msg = Net.invoke("GrowTree")
			if ok then
				Sounds.play("Bell")
				toast(msg, "Growth")
			else
				fail(b, msg)
			end
		end })
	refs.Instant = UI.button({ Text = "Instant Growth  " .. Purchase.price("InstantGrowth"), Style = "Red", Size = UDim2.fromOffset(230, 62),
		TextSize = 20, LayoutOrder = 2, Parent = row, OnClick = function(b)
			buy("InstantGrowth", b)
		end })
	Purchase.label(refs.Instant, "InstantGrowth", "Instant Growth  R$%s")
	-- the shortcut is the purple Robux colour (Playbook 07: purple = Robux)
	local purple = { Color3.fromRGB(176, 120, 230), Color3.fromRGB(120, 70, 190), Color3.fromRGB(70, 34, 120), Color3.fromRGB(235, 215, 255) }
	UI.Styles.Purple = purple
	UI.restyle(refs.Instant, "Purple")

	-- right column: odds table now vs next
	local right = UI.new("Frame", { BackgroundColor3 = T.Parchment2, Size = UDim2.new(1, -414, 1, 0), Position = UDim2.fromOffset(414, 0), Parent = body })
	UI.corner(8, right)
	UI.stroke(right, T.InkSoft, 1.5, 0.4)
	UI.pad(right, 14, 10)
	UI.text({ Text = "Drop odds", Size = UDim2.new(1, 0, 0, 30), TextSize = 24, Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Parent = right })
	local head = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 34), Parent = right })
	UI.text({ Text = "Rarity", Size = UDim2.new(0.44, 0, 1, 0), TextSize = 17, TextColor3 = T.InkSoft, Stroke = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = head })
	refs.NowHead = UI.text({ Text = "Now", Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.fromScale(0.44, 0), TextSize = 17, TextColor3 = T.InkSoft, Stroke = false, Parent = head })
	refs.NextHead = UI.text({ Text = "Next", Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.fromScale(0.72, 0), TextSize = 17, TextColor3 = T.InkSoft, Stroke = false, Parent = head })
	refs.Rows = {}
	for i, r in ipairs(Config.Rarities) do
		local row2 = UI.new("Frame", { BackgroundColor3 = r.Color, BackgroundTransparency = 0.72, Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.fromOffset(0, 62 + (i - 1) * 46), Parent = right })
		UI.corner(6, row2)
		UI.text({ Text = r.Name, Size = UDim2.new(0.44, -10, 1, 0), Position = UDim2.fromOffset(10, 0), TextSize = 20, Weight = Enum.FontWeight.Heavy,
			TextColor3 = r.Color, Stroke = T.Outline, TextXAlignment = Enum.TextXAlignment.Left, Parent = row2 })
		local now = UI.text({ Text = "", Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.fromScale(0.44, 0), TextSize = 20, Weight = Enum.FontWeight.Heavy,
			TextColor3 = T.Ink, Stroke = false, Parent = row2 })
		local nxt = UI.text({ Text = "", Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.fromScale(0.72, 0), TextSize = 20, Weight = Enum.FontWeight.Heavy,
			TextColor3 = T.GreenDark, Stroke = false, Parent = row2 })
		refs.Rows[i] = { Now = now, Next = nxt }
	end
end

-- your drop modifiers from the server (gear and island luck, Lucky Incense, Fortune Charm), so the
-- odds shown are the ones you actually roll; fetched when the window opens and every few seconds
local luck, luckAt = {}, -99
local function fetchLuck()
	luckAt = os.clock()
	task.spawn(function()
		local l = Net.invoke("GearLuck")
		if type(l) == "table" then
			luck = l
			if UI.isOpen(win) then
				TreePanel.refresh()
			end
		end
	end)
end

local function pcts(level)
	if os.clock() - luckAt > 5 then
		fetchLuck()
	end
	return Rules.normalize(Rules.weightsFor(level, luck))
end

local function costRow(key, need)
	local got = have(key)
	local ok = got >= need
	local f = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26) })
	UI.text({ Text = nameOf(key), Size = UDim2.new(0.5, 0, 1, 0), TextSize = 19, TextColor3 = T.TextLight,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = f })
	UI.text({ Text = string.format("%s / %s", Format.Num(got), Format.Num(need)), Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.fromScale(0.5, 0), TextSize = 19, Weight = Enum.FontWeight.Heavy, TextColor3 = ok and T.Green or T.Red,
		TextXAlignment = Enum.TextXAlignment.Right, Parent = f })
	return f
end

local ORDER = { "Scraps", "Sap", "Heartwood", "BloodAmber", "Sunstone" }

function TreePanel.refresh()
	if not win then
		return
	end
	local level = player:GetAttribute("TreeLevel") or (State.Tree and State.Tree.Level) or 1
	local maxed = level >= Config.Tree.MaxLevel
	refs.Level.Text = "Lv " .. level
	-- the best rarity this tree can drop, and when the next one unlocks
	local best = Config.Rarities[Rules.maxRarity(level)].Name
	local unlockAt = Rules.nextRarityLevel(level)
	refs.Stage.Text = unlockAt and string.format("Drops up to %s · Lv %d unlocks %s", best, unlockAt, Config.Rarities[Rules.maxRarity(unlockAt)].Name)
		or string.format("Drops up to %s", best)
	refs.Peaches.Text = "Chopping is free: every chop drops a piece of gear."
	-- odds
	local now, nxt = pcts(level), pcts(math.min(level + 1, Config.Tree.MaxLevel))
	refs.NowHead.Text = "Lv " .. level
	refs.NextHead.Text = maxed and "" or ("Lv " .. (level + 1))
	for i, row in ipairs(refs.Rows) do
		row.Now.Text = now[i] > 0 and Format.Pct(now[i]) or "-"
		row.Next.Text = (maxed or nxt[i] <= 0) and (maxed and "" or "-") or Format.Pct(nxt[i])
		row.Next.TextColor3 = (nxt[i] > now[i] + 1e-6) and T.GreenDark or ((nxt[i] < now[i] - 1e-6) and T.InkSoft or T.Ink)
	end
	-- cost
	for _, c in ipairs(refs.Cost:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local growing = State.Tree and State.Tree.Growing
	if maxed then
		local f = costRow("Scraps", 0)
		f:ClearAllChildren()
		UI.text({ Text = "Your tree is fully grown!", Size = UDim2.fromScale(1, 1), TextSize = 20, TextColor3 = T.Gold, Parent = f })
		f.Parent = refs.Cost
	elseif not growing then
		local cost, seconds = Rules.growthCost(level)
		local n = 0
		for i, key in ipairs(ORDER) do
			if cost[key] then
				local row = costRow(key, cost[key])
				row.LayoutOrder = i
				row.Parent = refs.Cost
				n += 1
			end
		end
		local timeRow = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 99, Parent = refs.Cost })
		UI.text({ Text = (n == 0 and seconds == 0) and "Free and instant!" or ("Growth time: " .. Format.Time(seconds)), Size = UDim2.fromScale(1, 1),
			TextSize = 18, TextColor3 = T.Ornament, TextXAlignment = Enum.TextXAlignment.Left, Parent = timeRow })
	end
	refs.Grow.Visible = not growing and not maxed
	refs.Instant.Visible = growing == true
	TreePanel.tick()
end

-- countdown, run every second while open
function TreePanel.tick()
	if not (win and refs.Timer) then
		return
	end
	if State.Tree and State.Tree.Growing then
		local left = (State.Tree.GrowEndsAt or 0) - os.time()
		refs.Timer.Text = left > 0 and ("Growing: " .. Format.Clock(left)) or "Almost ready..."
	else
		refs.Timer.Text = ""
	end
end

function TreePanel.open()
	if win then
		win.open()
	end
end

function TreePanel.close()
	if win then
		win.close()
	end
end

function TreePanel.Start(c)
	C = c
	win = UI.window({ Title = "Divine Tree", Size = Vector2.new(880, 500), OnOpen = function()
		TreePanel.refresh()
	end })
	build(win.Body)
	local function changed()
		if UI.isOpen(win) then
			TreePanel.refresh()
		end
	end
	State.Changed:Connect(changed)
	for _, a in ipairs({ "TreeLevel", "Scraps", "Mat_Sap", "Mat_Heartwood", "Mat_BloodAmber", "Mat_Sunstone" }) do
		player:GetAttributeChangedSignal(a):Connect(changed)
	end
	while true do
		task.wait(1)
		if UI.isOpen(win) then
			TreePanel.tick()
		end
	end
end

return TreePanel
