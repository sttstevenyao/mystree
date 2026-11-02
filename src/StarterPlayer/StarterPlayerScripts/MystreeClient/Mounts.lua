-- StarterPlayerScripts/MystreeClient/Mounts (ModuleScript)
-- Mounts window: one card per mount (3D preview, name, speed, how to unlock), with Unlock (Mount
-- Scraps), Equip, and an EQUIPPED badge. Mounts can be ridden anywhere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Mystree.Config)
local Format = require(ReplicatedStorage.Mystree.Format)
local Net = require(ReplicatedStorage.Mystree.Net)
local Assets = require(ReplicatedStorage.Mystree.Assets)
local UI = require(script.Parent.UI)
local Purchase = require(script.Parent.Purchase)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local Mounts = {}
local T = UI.T
local player = Players.LocalPlayer

local C
local win
local refs = { Cards = {} }

local IDS = {}
for id in pairs(Config.Mounts) do
	table.insert(IDS, id)
end
table.sort(IDS, function(a, b)
	return Config.Mounts[a].Speed < Config.Mounts[b].Speed
end)

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

local function unlockText(def)
	if def.Unlock.Pass then
		return "Comes with the " .. Config.Gamepasses[def.Unlock.Pass].Name .. " pass"
	end
	if def.Unlock.Level then
		return "Unlocks at Lv " .. def.Unlock.Level
	end
	return Format.Num(def.Unlock.Scraps) .. " Peaches"
end

local function build(body)
	local head = UI.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), Parent = body })
	UI.list(head, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	UI.icon(head, "mount_shard", 30, { LayoutOrder = 1 })
	refs.Shards = UI.text({ Text = "", Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, TextSize = 24,
		Weight = Enum.FontWeight.Heavy, TextColor3 = T.TealDark, Stroke = false, LayoutOrder = 2, Parent = head })
	UI.text({ Text = "Ride anywhere to move faster (R, or the RIDE button). Unlock mounts with Peaches.", Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 34), TextSize = 16, TextColor3 = T.InkSoft, Stroke = false, Parent = body })
	-- every card in one row with no scrolling: the window is sized to the cards (see Mounts.Start)
	local row = UI.new("ScrollingFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -64), Position = UDim2.fromOffset(0, 62),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6, ScrollBarImageColor3 = T.TealDark, Parent = body })
	UI.list(row, Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	UI.autoScrollBar(row, 6)
	UI.pad(row, 4)
	for i, id in ipairs(IDS) do
		local def = Config.Mounts[id]
		local card = UI.new("Frame", { Name = id, BackgroundColor3 = T.Panel, Size = UDim2.fromOffset(158, 340), LayoutOrder = i, Parent = row })
		UI.corner(8, card)
		UI.stroke(card, T.PanelLine, 1.5, 0.3)
		UI.ornaments(card)
		local stage = UI.new("Frame", { BackgroundColor3 = T.White, Size = UDim2.new(1, -12, 0, 150), Position = UDim2.fromOffset(6, 10), Parent = card })
		UI.corner(6, stage)
		UI.gradient(stage, Color3.fromRGB(214, 232, 226), Color3.fromRGB(150, 188, 176))
		local vp = UI.new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(170, 170, 170),
			LightColor = Color3.fromRGB(255, 250, 240), LightDirection = Vector3.new(-1, -1.3, -1), Parent = stage })
		UI.setModel(vp, Assets.Mount(id), 40, -14)
		UI.text({ Text = def.Name, Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(4, 166), TextSize = 20, Weight = Enum.FontWeight.Heavy, Parent = card })
		UI.text({ Text = "Speed " .. def.Speed, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 196), TextSize = 19,
			Weight = Enum.FontWeight.Heavy, TextColor3 = T.Gold, Parent = card })
		local cond = UI.text({ Text = unlockText(def), Size = UDim2.new(1, -8, 0, 40), Position = UDim2.fromOffset(4, 224), TextSize = 15,
			TextColor3 = T.TextLight, Parent = card })
		local btn = UI.button({ Text = "", Style = "Orange", Size = UDim2.new(1, -16, 0, 60), Position = UDim2.new(0, 8, 1, -68), TextSize = 21, Parent = card,
			OnClick = function(b)
				local owned = State.Mounts[id]
				if not owned and def.Unlock.Pass then
					-- pass mounts: the pass purchase prompt
					if C and C.Offers then
						C.Offers.buy(def.Unlock.Pass)
					end
				elseif not owned then
					local ok, msg = Net.invoke("UnlockMount", id)
					if ok then
						Sounds.play("Legendary")
						toast(msg, "Mythic")
					else
						fail(b, msg)
					end
				elseif State.MountEquipped ~= id then
					local ok, msg = Net.invoke("EquipMount", id)
					if ok then
						Sounds.play("Pop")
					else
						fail(b, msg)
					end
				end
			end })
		local badge = UI.new("Frame", { BackgroundColor3 = T.GreenDark, Size = UDim2.fromOffset(100, 24), Position = UDim2.new(0.5, -50, 0, 2), Visible = false, ZIndex = 5, Parent = card })
		UI.corner(6, badge)
		UI.text({ Text = "EQUIPPED", Size = UDim2.fromScale(1, 1), TextSize = 15, Weight = Enum.FontWeight.Heavy, ZIndex = 6, Parent = badge })
		refs.Cards[id] = { Card = card, Button = btn, Badge = badge, Cond = cond }
	end
end

function Mounts.refresh()
	if not win then
		return
	end
	refs.Shards.Text = Format.Commas(State.attr("Scraps", 0)) .. " Peaches"
	for id, r in pairs(refs.Cards) do
		local def = Config.Mounts[id]
		local owned = State.Mounts[id] == true
		local equipped = State.MountEquipped == id
		r.Badge.Visible = equipped
		r.Cond.Text = owned and "Owned" or unlockText(def)
		if not owned and def.Unlock.Pass then
			local pass = Config.Gamepasses[def.Unlock.Pass]
			r.Button.Visible = true
			r.Button.Text = "Get  " .. Purchase.price(def.Unlock.Pass)
			UI.restyle(r.Button, "Purple")
		elseif not owned then
			r.Button.Visible = def.Unlock.Scraps ~= nil
			r.Button.Text = "Unlock"
			UI.restyle(r.Button, State.attr("Scraps", 0) >= (def.Unlock.Scraps or math.huge) and "Orange" or "Grey")
		else
			r.Button.Visible = not equipped
			r.Button.Text = "Equip"
			UI.restyle(r.Button, "Green")
		end
	end
end

function Mounts.open()
	if win then
		win.open()
	end
end

function Mounts.close()
	if win then
		win.close()
	end
end

function Mounts.Start(c)
	C = c
	-- 158-wide cards, 12 apart, 4 px padding; capped at the 1100 design width (then the row scrolls)
	local width = math.min(1060, #IDS * 170 - 12 + 8 + 24)
	win = UI.window({ Title = "Mounts", Size = Vector2.new(width, 74 + 62 + 340 + 12), OnOpen = function()
		Mounts.refresh()
	end })
	build(win.Body)
	local function changed()
		if UI.isOpen(win) then
			Mounts.refresh()
		end
	end
	State.Changed:Connect(changed)
	player:GetAttributeChangedSignal("Scraps"):Connect(changed)
end

return Mounts
