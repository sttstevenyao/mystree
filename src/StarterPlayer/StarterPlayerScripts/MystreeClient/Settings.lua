-- StarterPlayerScripts/MystreeClient/Settings (ModuleScript)
-- Settings window (Hud's gear button, bottom-right): one row per Config.DefaultSettings toggle.
-- A click flips the setting locally at once (State.setSetting) and saves it with Net "SaveSettings";
-- if the server refuses, the row flips back. Sized to its rows so there is no empty space.
-- The PvP row is different (Live): it isn't saved (off on every join); it shows the "PvP" player
-- attribute and asks the server ("SetPvP"), which turns it off only after a delay and never mid-fight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local State = require(script.Parent.State)
local Sounds = require(script.Parent.Sounds)

local Settings = {}
local T = UI.T

local ROWS = {
	{ Key = "Music", Name = "Music", Desc = "Background music" },
	{ Key = "Sfx", Name = "Sound Effects", Desc = "Chops, hits, pops and alerts" },
	{ Key = "ScreenShake", Name = "Screen Shake", Desc = "Camera shake on big hits and pulls" },
	{ Key = "Particles", Name = "Particles", Desc = "Sparks, motes and dust" },
	{ Key = "Flashing", Name = "Flashing Lights", Desc = "Screen flashes on rare pulls" },
	{ Key = "PvP", Name = "PvP", Desc = "Fight others who have it on (Hunting Grounds)", Live = true },
}
local player = Players.LocalPlayer
local C
local ROW_H, GAP, W = 58, 6, 440

local win
local toggles = {} -- key -> refresh(on, animate)

local function makeToggle(parent, key)
	local track = UI.new("TextButton", { Name = "Toggle", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(74, 34), AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0), BackgroundColor3 = T.Bar, Parent = parent })
	UI.corner(17, track)
	UI.stroke(track, T.Outline, 2)
	local knob = UI.new("Frame", { Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), BackgroundColor3 = T.Parchment, Parent = track })
	UI.corner(13, knob)
	UI.stroke(knob, T.Outline, 1.5)
	local word = UI.text({ Text = "OFF", Size = UDim2.fromOffset(40, 34), Position = UDim2.fromOffset(32, 0), TextSize = 14, Weight = Enum.FontWeight.Heavy,
		TextColor3 = T.TextLight, Parent = track })
	local function refresh(on, animate)
		local info = TweenInfo.new(animate and 0.18 or 0, Enum.EasingStyle.Quad)
		TweenService:Create(knob, info, { Position = on and UDim2.new(1, -30, 0.5, 0) or UDim2.new(0, 4, 0.5, 0) }):Play()
		TweenService:Create(track, info, { BackgroundColor3 = on and T.GreenDark or T.Bar }):Play()
		word.Text = on and "ON" or "OFF"
		word.Position = UDim2.fromOffset(on and 4 or 32, 0)
	end
	if key == "PvP" then
		track.Activated:Connect(function()
			Sounds.play("Click")
			local on = not player:GetAttribute("PvP")
			task.spawn(function()
				local ok, msg = Net.invoke("SetPvP", on)
				if msg and C and C.Notify then
					C.Notify.toast(msg, ok and "Info" or "Error")
				end
			end)
		end)
		toggles[key] = refresh
		return
	end
	track.Activated:Connect(function()
		local on = not State.setting(key)
		Sounds.play("Click")
		State.setSetting(key, on)
		refresh(on, true)
		task.spawn(function()
			local ok = Net.invoke("SaveSettings", key, on)
			if not ok then
				State.setSetting(key, not on)
				refresh(not on, true)
			end
		end)
	end)
	toggles[key] = refresh
end

local function build()
	win = UI.window({ Title = "Settings", Size = Vector2.new(W, 74 + #ROWS * (ROW_H + GAP) + 26) })
	UI.list(win.Body, Enum.FillDirection.Vertical, GAP)
	for i, r in ipairs(ROWS) do
		local row = UI.new("Frame", { Name = r.Key, Size = UDim2.new(1, 0, 0, ROW_H), BackgroundColor3 = T.Parchment2, LayoutOrder = i, Parent = win.Body })
		UI.corner(8, row)
		UI.stroke(row, T.Ornament, 1.5)
		UI.text({ Text = r.Name, Size = UDim2.new(1, -110, 0, 26), Position = UDim2.fromOffset(14, 6), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 20,
			Weight = Enum.FontWeight.Heavy, TextColor3 = T.Ink, Stroke = false, Parent = row })
		UI.text({ Text = r.Desc, Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(14, 32), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14,
			TextColor3 = T.InkSoft, Stroke = false, Parent = row })
		makeToggle(row, r.Key)
	end
	UI.text({ Text = "Saved to your profile", Size = UDim2.new(1, 0, 0, 18), TextSize = 13, TextColor3 = T.InkSoft, Stroke = false, LayoutOrder = 99, Parent = win.Body })
end

local function refreshAll()
	for key, refresh in pairs(toggles) do
		if key == "PvP" then
			refresh(player:GetAttribute("PvP") == true and not player:GetAttribute("PvPOffAt"), false)
		else
			refresh(State.setting(key), false)
		end
	end
end

function Settings.open()
	refreshAll()
	win.open()
end

function Settings.Start(c)
	C = c
	build()
	State.Changed:Connect(refreshAll)
	player:GetAttributeChangedSignal("PvP"):Connect(refreshAll)
	player:GetAttributeChangedSignal("PvPOffAt"):Connect(refreshAll)
end

return Settings
