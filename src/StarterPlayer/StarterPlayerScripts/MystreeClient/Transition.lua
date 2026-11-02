-- StarterPlayerScripts/MystreeClient/Transition (ModuleScript)
-- Travel transition: a dark-jade ink wash sweeps across the screen, the place name settles in the
-- middle, and the wash sweeps off once the character has arrived.
--  * Transition.travel(remote, arg) covers the screen first, then invokes "Travel" / "VisitIsland",
--    then reveals. Every client travel button goes through it. Returns the remote's ok, msg.
--  * Gate portals fire Effect "TravelCover" (where) first: the wash sweeps in, the server moves the
--    character Config.GateCoverTime later and fires "Travel", and the wash sweeps off.
--  * Other server-side moves (Admin travel) fire only Effect "Travel" (where, ownerName?); when no
--    transition is running, the wash starts already covering and sweeps off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Mystree.Net)
local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)

local Transition = {}
local T = UI.T

local NAMES = { Hub = "Mystree Village", Grounds = "Hunting Grounds", Home = "Your Island", Plot = "Your Island" }
local SUBS = { Hub = "Elders, merchants and the Summoning Shrine", Grounds = "Beasts roam here. Stay sharp.", Home = "Your Divine Tree awaits", Plot = "Your Divine Tree awaits" }
local COVER, REVEAL, HOLD = 0.38, 0.5, 0.35

local gui = UI.screen("MystreeTransition", 60, true)
local root = gui:FindFirstChild("Root")
root.ZIndex = 2 -- the title sits above the wash
-- the wash is 1.6 screens wide with soft edges, so it can sit fully over the screen at x = -0.3
local ink = UI.new("Frame", { Name = "Ink", Size = UDim2.fromScale(1.6, 1), Position = UDim2.fromScale(-1.6, 0), BackgroundColor3 = T.Panel, Visible = false, Parent = gui })
UI.new("UIGradient", { Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.16, 0), NumberSequenceKeypoint.new(0.84, 0), NumberSequenceKeypoint.new(1, 1),
}), Parent = ink })
-- faint ink-wash hills along the bottom, like the window headers
for i = 0, 7 do
	local w = 0.09 + (i % 3) * 0.03
	UI.new("Frame", { Size = UDim2.fromScale(w, 1), Position = UDim2.fromScale(0.12 + i * 0.1, 0.8 + (i % 2) * 0.05), BackgroundColor3 = T.Header,
		BackgroundTransparency = 0.86, Parent = ink }, { UI.corner(999), UI.new("UIAspectRatioConstraint", { AspectRatio = 1.8 }) })
end

local title = UI.new("CanvasGroup", { Name = "Title", Size = UDim2.fromOffset(640, 120), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = root })
local nameLabel = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 58), Position = UDim2.fromOffset(0, 10), TextSize = 50, Weight = Enum.FontWeight.Heavy,
	TextColor3 = T.Cream, Stroke = T.Outline, StrokeThickness = 2.5, Parent = title })
local rule = UI.new("Frame", { Size = UDim2.fromOffset(260, 3), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), BackgroundColor3 = T.Ornament, BorderSizePixel = 0, Parent = title })
UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = rule })
local subLabel = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 84), TextSize = 19, TextColor3 = T.TextLight, Parent = title })

local covering = false -- a client transition owns the screen
local gateWaiting = false -- a gate's wash is in, waiting for the server's "Travel"
local token = 0

local function setName(where, ownerName)
	if where == "Visit" then
		nameLabel.Text = (ownerName or "A Friend") .. "'s Island"
		subLabel.Text = "Leave a like if you enjoy it"
	else
		nameLabel.Text = NAMES[where] or "Mystree"
		subLabel.Text = SUBS[where] or ""
	end
end

local function cover(instant)
	ink.Visible = true
	title.Visible = true
	if instant then
		ink.Position = UDim2.fromScale(-0.3, 0)
		title.GroupTransparency = 0
		title.Position = UDim2.fromScale(0.5, 0.5)
		return
	end
	ink.Position = UDim2.fromScale(-1.6, 0)
	title.GroupTransparency = 1
	title.Position = UDim2.new(0.5, -40, 0.5, 0)
	Sounds.play("Whoosh", 0.9, 0.5)
	TweenService:Create(ink, TweenInfo.new(COVER, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(-0.3, 0) }):Play()
	TweenService:Create(title, TweenInfo.new(COVER + 0.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, 0.12),
		{ GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }):Play()
	task.wait(COVER)
end

local function reveal(myToken)
	task.wait(HOLD)
	if myToken ~= token then
		return
	end
	TweenService:Create(title, TweenInfo.new(REVEAL * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1, Position = UDim2.new(0.5, 40, 0.5, 0) }):Play()
	local tw = TweenService:Create(ink, TweenInfo.new(REVEAL, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(1, 0) })
	tw:Play()
	tw.Completed:Wait()
	if myToken == token then
		ink.Visible = false
		title.Visible = false
	end
end

-- remote: "Travel" (arg "Hub" | "Grounds" | "Home") or "VisitIsland" (arg owner UserId)
function Transition.travel(remote, arg, ownerName)
	if covering then
		return false
	end
	covering = true
	token += 1
	local myToken = token
	setName(remote == "VisitIsland" and "Visit" or arg, ownerName)
	cover(false)
	local ok, msg = Net.invoke(remote, arg)
	covering = false
	if ok then
		task.spawn(reveal, myToken)
	else
		-- nothing moved: sweep straight back off
		task.spawn(function()
			task.wait()
			if myToken == token then
				TweenService:Create(title, TweenInfo.new(0.2), { GroupTransparency = 1 }):Play()
				local tw = TweenService:Create(ink, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(-1.6, 0) })
				tw:Play()
				tw.Completed:Wait()
				if myToken == token then
					ink.Visible = false
					title.Visible = false
				end
			end
		end)
	end
	return ok, msg
end

function Transition.Start()
	Net.get("Effect").OnClientEvent:Connect(function(kind, where, ownerName)
		if kind == "TravelCover" then
			if covering or gateWaiting then
				return
			end
			token += 1
			local myToken = token
			gateWaiting = true
			setName(where, ownerName)
			task.spawn(cover, false)
			-- if the move never comes, don't leave the screen covered
			task.delay(3, function()
				if gateWaiting and token == myToken then
					gateWaiting = false
					reveal(myToken)
				end
			end)
			return
		end
		if kind ~= "Travel" then
			return
		end
		setName(where, ownerName)
		if covering then
			return -- the client transition already covers the screen and will reveal
		end
		if gateWaiting then
			gateWaiting = false
			task.spawn(reveal, token)
			return
		end
		token += 1
		cover(true)
		task.spawn(reveal, token)
	end)
end

return Transition
