-- StarterPlayerScripts/MystreeClient (LocalScript)
-- Boots the client controllers in a fixed order. Each controller is a ModuleScript child with an
-- optional Start(C); C is the shared table of controllers (C.Notify.toast(...), C.Bag.open(), ...).
-- All UI is built in code at runtime (Playbook 07). StarterGui only holds view-only editor previews
-- (attribute EditorPreview), which are removed from PlayerGui here.

local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local function dropPreview(g)
	if g:GetAttribute("EditorPreview") then
		g:Destroy()
	end
end
for _, g in ipairs(playerGui:GetChildren()) do
	dropPreview(g)
end
playerGui.ChildAdded:Connect(dropPreview)

local UI = require(script:WaitForChild("UI"))
local Sounds = require(script:WaitForChild("Sounds"))
UI.setSounds(Sounds)

local ORDER = {
	"Sounds", "Ambience", "Notify", "Transition", "WorldFx", "Hud", "Tutorial", "Chop", "Loot", "Equipment", "Combat", "MobFx", "Gaits",
	"Bag", "TreePanel", "Spirits", "Mounts", "Shop", "Forge", "Inspect", "Quests", "Offers", "Island", "Leaderboard", "Interact", "SummonFx", "Settings", "Movement", "AdminPanel",
}

local C = { UI = UI }
for _, name in ipairs(ORDER) do
	local mod = script:FindFirstChild(name)
	if mod then
		local ok, result = pcall(require, mod)
		if ok then
			C[name] = result
		else
			warn("[MystreeClient] " .. name .. " failed to load: " .. tostring(result))
		end
	end
end
for _, name in ipairs(ORDER) do
	if C[name] and C[name].Start then
		task.spawn(C[name].Start, C)
	end
end
