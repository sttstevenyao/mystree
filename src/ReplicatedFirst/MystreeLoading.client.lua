-- ReplicatedFirst/MystreeLoading (LocalScript)
-- The loading screen. It runs before anything else replicates and covers the screen at once, then:
--  1. waits for the game to load and streams in the Wildlands (streaming is on, so the far side of
--     the open world isn't on the client until it is asked for),
--  2. fades the cover away to a slow camera flight over the Wildlands (user: "a view over the open
--     world"), with the logo, a progress bar and a rotating tip on top,
--  3. preloads every asset the game uses with a real progress bar: icons, sounds and music, fonts,
--     particle textures, and every mesh, image, sound and texture in ReplicatedStorage, Lighting,
--     SoundService and the streamed-in world,
--  4. covers the screen again, hands the camera back to the character and fades into the game.
-- Skip shows after 2 s (Playbook 17); skipping ends the screen early but the preload keeps going.
-- When it hands over it sets the player attribute "Loaded" (the music waits for it, so it starts on
-- the fade). Tips and timings live here, not in Config: this runs before ReplicatedStorage arrives.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local L = {
	SkipAfter = 2, -- s before the Skip button shows
	MinFlight = 1.5, -- s the flight shows at least, so the world view never just flashes by
	TipEvery = 4.5, -- s per tip
	StreamTimeout = 8, -- s to wait for each streamed area
	Workers = 4, -- preload batches running at once
	Batch = 8, -- assets per PreloadAsync call
	Reveal = 1.2, -- s the cover takes to fade away to the flight
	Fade = 0.45, -- s to cover before the handover when there was no flight; that fade-out is this + 0.2
	HomeTimeout = 20, -- s to wait for the server to put the player at their tree
	-- the landing: the camera arcs from the flight down to Back studs behind and Up above the player,
	-- looking at a point FocusUp above their root, turning to face them by TurnBy of the way
	Glide = { Time = 1.3, Arc = 35, Back = 12, Up = 4.5, FocusUp = 1.5, TurnBy = 0.5, FadeUi = 0.35 },
	-- the flight: an orbit round the Wildlands' centre (Config.Wild.Center), looking across it
	Orbit = { R = 340, H = 80, From = 205, Speed = 2.2, LookH = 10, Fov = 60 }, -- From in degrees, Speed in degrees/s
	Tips = {
		"Chop your Divine Tree for new gear. Keep a piece when its Power beats what you wear.",
		"Elder Mo in the Village hands out the main quests, and quests pay the most Peaches.",
		"Each zone's boss waits in an arena at the far edge, and comes back 8 minutes after it falls.",
		"Some camps only fill at night. Check the clock before you head out.",
		"Grow your tree to raise the best rarity it can drop.",
		"Bag full? Dismantle worse clears out gear you'll never wear.",
		"Visit other players' islands and leave a like.",
	},
}

-- the murim kit's colours and fonts (MystreeClient.UI), copied: that module isn't here yet
local C = {
	Panel = Color3.fromRGB(22, 22, 27),
	PanelDeep = Color3.fromRGB(8, 8, 10),
	PanelLine = Color3.fromRGB(150, 128, 88),
	Crimson = Color3.fromRGB(176, 40, 40),
	Parchment = Color3.fromRGB(243, 238, 226),
	TextLight = Color3.fromRGB(223, 233, 228),
	Outline = Color3.fromRGB(38, 44, 40),
	Bar = Color3.fromRGB(52, 46, 38),
	Orange = Color3.fromRGB(250, 168, 62),
	Gold = Color3.fromRGB(255, 214, 106),
	Cream = Color3.fromRGB(246, 230, 170),
	CreamLine = Color3.fromRGB(140, 110, 50),
	-- the Skip button: ink with a muted gold edge
	Teal = Color3.fromRGB(56, 54, 62),
	TealDark = Color3.fromRGB(30, 29, 35),
	TealLine = Color3.fromRGB(150, 128, 88),
}
local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"
local SERIF = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)
local function font(weight, italic)
	return Font.new(MONTSERRAT, weight, italic and Enum.FontStyle.Italic or Enum.FontStyle.Normal)
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- ===================================================================== screen
local function new(class, props)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			o[k] = v
		end
	end
	o.Parent = props.Parent
	return o
end
local function corner(parent, r)
	new("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
end
local function stroke(parent, col, thick)
	return new("UIStroke", { Color = col, Thickness = thick or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

local gui = new("ScreenGui", {
	Name = "MystreeLoading", IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, ResetOnSpawn = false, DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui,
})
-- the cover: solid jade until the world is streamed in, then it fades away to the flight
local cover = new("Frame", { Name = "Cover", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Panel, BorderSizePixel = 0, ZIndex = 1, Parent = gui })
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.Panel, C.PanelDeep), Parent = cover })
-- dark shades top and bottom, so the logo and the bar read over the bright world
local function shade(name, anchorY, rotation)
	local f = new("Frame", {
		Name = name, AnchorPoint = Vector2.new(0, anchorY), Position = UDim2.fromScale(0, anchorY), Size = UDim2.fromScale(1, 0.42),
		BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 2, Parent = gui,
	})
	new("UIGradient", { Rotation = rotation, Transparency = NumberSequence.new(0.2, 1), Parent = f })
	return f
end
shade("ShadeTop", 0, 90)
shade("ShadeBottom", 1, -90)

-- everything else is laid out on a 1100x620 stage scaled to the screen (as the UI kit does)
local stage = new("Frame", {
	Name = "Stage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1100, 620),
	BackgroundTransparency = 1, ZIndex = 3, Parent = gui,
})
local scale = new("UIScale", { Parent = stage })
local function fit()
	local s = gui.AbsoluteSize
	if s.X > 0 and s.Y > 0 then
		scale.Scale = math.min(s.X / 1100, s.Y / 620)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

-- a crimson brush stroke behind the logo (VFX Library "Ink splash", as on the windows)
new("ImageLabel", {
	Name = "Brush", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(550, 176), Size = UDim2.fromOffset(640, 190),
	BackgroundTransparency = 1, Image = "rbxassetid://16132530029", ImageColor3 = C.Crimson, ImageTransparency = 0.15, ZIndex = 3, Parent = stage,
})
local logo = new("TextLabel", {
	Name = "Logo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(550, 170), Size = UDim2.fromOffset(700, 110),
	BackgroundTransparency = 1, Text = "Mystree", FontFace = SERIF, TextSize = 92, TextColor3 = C.Parchment, ZIndex = 4, Parent = stage,
})
new("UIStroke", { Color = C.Outline, Thickness = 3, Parent = logo })
local tagline = new("TextLabel", {
	Name = "Tagline", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(550, 228), Size = UDim2.fromOffset(700, 30),
	BackgroundTransparency = 1, Text = "Grow your Divine Tree. Hunt the Wildlands.", FontFace = font(Enum.FontWeight.SemiBold),
	TextSize = 22, TextColor3 = C.TextLight, ZIndex = 4, Parent = stage,
})
new("UIStroke", { Color = C.Outline, Thickness = 1.5, Transparency = 0.3, Parent = tagline })
-- a caption that names the view once the flight starts
local caption = new("TextLabel", {
	Name = "Caption", Position = UDim2.fromOffset(40, 36), Size = UDim2.fromOffset(400, 30), BackgroundTransparency = 1,
	Text = "The Wildlands", FontFace = font(Enum.FontWeight.SemiBold, true), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = C.Cream, TextTransparency = 1, ZIndex = 4, Parent = stage,
})
local captionStroke = new("UIStroke", { Color = C.Outline, Thickness = 1.5, Transparency = 1, Parent = caption })

-- progress: a status line and percentage over a chunky bar
local BAR_W = 600
local status = new("TextLabel", {
	Name = "Status", Position = UDim2.fromOffset(550 - BAR_W / 2, 474), Size = UDim2.fromOffset(BAR_W - 80, 26), BackgroundTransparency = 1,
	Text = "Loading", FontFace = font(Enum.FontWeight.SemiBold), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = C.TextLight, ZIndex = 4, Parent = stage,
})
local percent = new("TextLabel", {
	Name = "Percent", Position = UDim2.fromOffset(550 + BAR_W / 2 - 80, 474), Size = UDim2.fromOffset(80, 26), BackgroundTransparency = 1,
	Text = "0%", FontFace = font(Enum.FontWeight.Bold), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = C.Gold, ZIndex = 4, Parent = stage,
})
local track = new("Frame", {
	Name = "Track", Position = UDim2.fromOffset(550 - BAR_W / 2, 504), Size = UDim2.fromOffset(BAR_W, 18),
	BackgroundColor3 = C.Bar, BorderSizePixel = 0, ZIndex = 4, Parent = stage,
})
corner(track, 9)
stroke(track, C.PanelLine, 1.5)
local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Orange, BorderSizePixel = 0, ZIndex = 5, Parent = track })
corner(fill, 9)
new("UIGradient", { Color = ColorSequence.new(C.Orange, C.Gold), Parent = fill })

-- one rotating tip that teaches a real mechanic
local tipBox = new("Frame", {
	Name = "Tip", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(550, 540), Size = UDim2.fromOffset(760, 54),
	BackgroundTransparency = 1, ZIndex = 4, Parent = stage,
})
local tipTag = new("TextLabel", {
	Name = "Tag", Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(52, 24), BackgroundColor3 = C.Cream,
	Text = "TIP", FontFace = font(Enum.FontWeight.Bold), TextSize = 14, TextColor3 = C.CreamLine, ZIndex = 5, Parent = tipBox,
})
corner(tipTag, 6)
stroke(tipTag, C.CreamLine, 1)
local tipText = new("TextLabel", {
	Name = "Text", Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -66, 1, 0), BackgroundTransparency = 1,
	Text = "", FontFace = font(Enum.FontWeight.Medium), TextSize = 20, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.TextLight, ZIndex = 5, Parent = tipBox,
})
new("UIStroke", { Color = C.Outline, Thickness = 1.5, Transparency = 0.3, Parent = tipText })

local skip = new("TextButton", {
	Name = "Skip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(1070, 596), Size = UDim2.fromOffset(120, 44),
	BackgroundColor3 = C.Teal, Text = "Skip", FontFace = font(Enum.FontWeight.Bold), TextSize = 20, TextColor3 = Color3.new(1, 1, 1),
	AutoButtonColor = false, Visible = false, ZIndex = 6, Parent = stage,
})
corner(skip, 8)
local skipStroke = stroke(skip, C.TealLine, 2)
new("UIStroke", { Color = C.TealLine, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = skip })

local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- ===================================================================== progress
local target, shown = 0, 0
local function setProgress(p, text)
	target = math.max(target, math.clamp(p, 0, 1))
	if text then
		status.Text = text
	end
end
local barConn = RunService.Heartbeat:Connect(function(dt)
	shown += (target - shown) * math.min(1, dt * 6)
	if target - shown < 0.002 then
		shown = target
	end
	fill.Size = UDim2.fromScale(shown, 1)
	percent.Text = math.floor(shown * 100 + 0.5) .. "%"
end)

local finished = false
local tipIndex = math.random(1, #L.Tips)
tipText.Text = L.Tips[tipIndex]
task.spawn(function()
	while not finished do
		task.wait(L.TipEvery)
		if finished then
			break
		end
		tween(tipText, 0.25, { TextTransparency = 1 }).Completed:Wait()
		tipIndex = tipIndex % #L.Tips + 1
		tipText.Text = L.Tips[tipIndex]
		tween(tipText, 0.25, { TextTransparency = 0 })
	end
end)

-- ===================================================================== camera flight
local camera = workspace.CurrentCamera
local center = Vector3.new(1250, 0, 0) -- replaced by Config.Wild.Center once ReplicatedStorage is in
local flightStart
local oldFov = camera.FieldOfView
local function flightCFrame(t)
	local o = L.Orbit
	local th = math.rad(o.From + o.Speed * t)
	local pos = center + Vector3.new(math.cos(th) * o.R, o.H, math.sin(th) * o.R)
	return CFrame.lookAt(pos, center + Vector3.new(0, o.LookH, 0))
end
local function startFlight()
	if finished or flightStart then
		return
	end
	flightStart = os.clock()
	camera = workspace.CurrentCamera
	oldFov = camera.FieldOfView
	-- after the default camera scripts, so they can't pull the view back to the character
	RunService:BindToRenderStep("MystreeLoadingFlight", Enum.RenderPriority.Camera.Value + 1, function()
		camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = L.Orbit.Fov
		camera.CFrame = flightCFrame(os.clock() - flightStart)
	end)
	tween(cover, L.Reveal, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	tween(caption, L.Reveal, { TextTransparency = 0 })
	tween(captionStroke, L.Reveal, { Transparency = 0.3 })
end
-- the end of the flight: an arc from the Wildlands down to just behind the player at their tree,
-- turning to face them on the way (yaw and pitch are blended, so it never flips through
-- straight down), then the normal camera takes over from that exact spot
local function glide(hrp)
	RunService:UnbindFromRenderStep("MystreeLoadingFlight")
	camera = workspace.CurrentCamera
	local g = L.Glide
	local from = camera.CFrame.Position
	local startDir = camera.CFrame.LookVector
	local function yawPitch(v)
		return math.atan2(-v.X, -v.Z), math.asin(math.clamp(v.Y, -1, 1))
	end
	local function fromYawPitch(yaw, pitch)
		return Vector3.new(-math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
	end
	local yaw0, pitch0 = yawPitch(startDir)
	local flat = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
	local focus = hrp.Position + Vector3.new(0, g.FocusUp, 0)
	local to = focus - flat * g.Back + Vector3.new(0, g.Up, 0)
	local t0 = os.clock()
	local function frame()
		local a = math.clamp((os.clock() - t0) / g.Time, 0, 1)
		local e = (1 - math.cos(math.pi * a)) / 2
		local pos = from:Lerp(to, e) + Vector3.new(0, math.sin(math.pi * e) * g.Arc, 0)
		-- turn toward the player over the first part of the glide, then keep looking at them
		local u = math.clamp(a / g.TurnBy, 0, 1)
		u = u * u * (3 - 2 * u)
		local yaw1, pitch1 = yawPitch((focus - pos).Unit)
		local dy = (yaw1 - yaw0 + math.pi) % (2 * math.pi) - math.pi
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(pos, pos + fromYawPitch(yaw0 + dy * u, pitch0 + (pitch1 - pitch0) * u))
		camera.FieldOfView = L.Orbit.Fov + (oldFov - L.Orbit.Fov) * e
	end
	RunService:BindToRenderStep("MystreeLoadingGlide", Enum.RenderPriority.Camera.Value + 1, frame)
	while os.clock() - t0 < g.Time do
		task.wait()
	end
	RunService:UnbindFromRenderStep("MystreeLoadingGlide")
	camera.CFrame = CFrame.lookAt(to, focus)
	camera.FieldOfView = oldFov
end
local function endFlight(humanoid)
	RunService:UnbindFromRenderStep("MystreeLoadingFlight")
	camera = workspace.CurrentCamera
	camera.FieldOfView = oldFov
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- ===================================================================== hold the game's UI
-- The game builds its HUD and windows while this screen is up, and the cover goes see-through for
-- the flight, so they would show over it (user: "make all the actual in game ui pop up after the
-- loading screen"). Every other ScreenGui in PlayerGui, and the mob health bars over the Wildlands,
-- are held hidden until the handover. A gui's own code may still switch it while held (Combat,
-- SummonFx do): the last value it asked for is kept and applied on release.
local held, holding = {}, true
local function hold(g)
	if not holding or held[g] or g == gui or not g.Parent then
		return
	end
	local h = { want = g.Enabled }
	held[g] = h
	g.Enabled = false
	h.conn = g:GetPropertyChangedSignal("Enabled"):Connect(function()
		if holding and g.Enabled then
			h.want = true
			g.Enabled = false
		end
	end)
end
local function holdable(d)
	return d:IsA("ScreenGui") or (d:IsA("BillboardGui") and d.Name == "MobBar")
end
for _, g in ipairs(playerGui:GetChildren()) do
	if g:IsA("ScreenGui") then
		hold(g)
	end
end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BillboardGui") and d.Name == "MobBar" then
		hold(d)
	end
end
-- deferred, so code that creates a gui and switches it off on the next line is seen as "off"
local holdConns = {
	playerGui.ChildAdded:Connect(function(g)
		if g:IsA("ScreenGui") then
			task.defer(hold, g)
		end
	end),
	workspace.DescendantAdded:Connect(function(d)
		if holdable(d) and d:IsA("BillboardGui") then
			task.defer(hold, d)
		end
	end),
}
local function release()
	holding = false
	for _, c in ipairs(holdConns) do
		c:Disconnect()
	end
	for g, h in pairs(held) do
		h.conn:Disconnect()
		if g.Parent then
			g.Enabled = h.want
		end
	end
	table.clear(held)
end

-- ===================================================================== handover
local function fadeAll(t)
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			tween(d, t, { TextTransparency = 1, BackgroundTransparency = 1 })
		elseif d:IsA("Frame") then
			tween(d, t, { BackgroundTransparency = 1 })
		elseif d:IsA("ImageLabel") then
			tween(d, t, { ImageTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, t, { Transparency = 1 })
		end
	end
end
-- the server sets "HomeReady" once the player stands at their tree (TreeService), so the screen
-- always ends there, never on the village spawn
local function waitForHome()
	local t0 = os.clock()
	while not player:GetAttribute("HomeReady") and os.clock() - t0 < L.HomeTimeout do
		task.wait(0.1)
	end
	local character = player.Character or player.CharacterAdded:Wait()
	return character:WaitForChild("HumanoidRootPart", 10), character:WaitForChild("Humanoid", 10)
end
local function finish()
	if finished then
		return
	end
	finished = true
	skip.Active = false
	if not player:GetAttribute("HomeReady") then
		status.Text = "Heading to your tree"
	end
	local hrp, humanoid = waitForHome()
	if flightStart and hrp then
		-- the screen's text and shades fade while the camera glides down to the player; the game's
		-- UI comes up as it lands
		fadeAll(L.Glide.FadeUi)
		glide(hrp)
		endFlight(humanoid)
		release()
		player:SetAttribute("Loaded", true)
	else
		-- never got to the flight (skipped early): swap the camera behind the solid cover, then fade
		tween(cover, L.Fade, { BackgroundTransparency = 0 }).Completed:Wait()
		endFlight(humanoid)
		release()
		player:SetAttribute("Loaded", true)
		task.wait(0.15)
		fadeAll(L.Fade + 0.2)
		task.wait(L.Fade + 0.3)
	end
	barConn:Disconnect()
	gui:Destroy()
end

task.delay(L.SkipAfter, function()
	if finished then
		return
	end
	skip.BackgroundTransparency, skip.TextTransparency, skipStroke.Transparency = 1, 1, 1
	skip.Visible = true
	tween(skip, 0.3, { BackgroundTransparency = 0, TextTransparency = 0 })
	tween(skipStroke, 0.3, { Transparency = 0 })
end)
skip.MouseEnter:Connect(function()
	tween(skip, 0.12, { BackgroundColor3 = C.TealDark })
end)
skip.MouseLeave:Connect(function()
	tween(skip, 0.12, { BackgroundColor3 = C.Teal })
end)
skip.Activated:Connect(function()
	task.spawn(finish)
end)

-- ===================================================================== what to preload
-- content ids that need fetching (rbxasset:// files ship with the client), each once. Loose ids from
-- modules (the icon set, image slots in Config) go in as ImageLabels, sounds as Sound instances, and
-- an id found on an instance goes in as that instance, which fetches it as the right type (mesh,
-- animation, texture)
local items, seen = {}, {}
local function fetchable(id)
	return type(id) == "string" and id ~= "" and not seen[id]
		and (id:find("^rbxassetid://") or id:find("^rbxthumb://") or id:find("^https?://")) ~= nil
end
local function addId(id, isSound)
	if not fetchable(id) then
		return
	end
	seen[id] = true
	-- wrapped in an instance either way: a bare id string reports a failure even for a good image
	if isSound then
		local s = Instance.new("Sound")
		s.SoundId = id
		table.insert(items, s)
	else
		local img = Instance.new("ImageLabel")
		img.Image = id
		table.insert(items, img)
	end
end
local function addInstance(inst)
	if not seen[inst] then
		seen[inst] = true
		table.insert(items, inst)
	end
end

-- the content properties of every class that carries assets
local PROPS = {
	MeshPart = { "MeshId", "TextureID" },
	SpecialMesh = { "MeshId", "TextureId" },
	Decal = { "Texture" },
	Texture = { "Texture" },
	ImageLabel = { "Image" },
	ImageButton = { "Image" },
	ParticleEmitter = { "Texture" },
	Beam = { "Texture" },
	Trail = { "Texture" },
	Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp", "SunTextureId", "MoonTextureId" },
	Animation = { "AnimationId" },
	Shirt = { "ShirtTemplate" },
	Pants = { "PantsTemplate" },
	ShirtGraphic = { "Graphic" },
	Tool = { "TextureId" },
}
local function addTree(root)
	for i, d in ipairs(root:GetDescendants()) do
		local props = PROPS[d.ClassName]
		if props then
			-- one instance per new id: the instance preloads all of its own ids
			local fresh = false
			for _, p in ipairs(props) do
				local ok, v = pcall(function()
					return d[p]
				end)
				if ok and fetchable(v) then
					seen[v] = true
					fresh = true
				end
			end
			if fresh then
				addInstance(d)
			end
		elseif d:IsA("Sound") then
			if fetchable(d.SoundId) then
				seen[d.SoundId] = true
				addInstance(d)
			end
		elseif d:IsA("SurfaceAppearance") or d:IsA("MaterialVariant") then
			addInstance(d) -- their maps aren't readable as ids; the instance preloads them
		end
		if i % 3000 == 0 then
			task.wait()
		end
	end
end
-- every asset id string anywhere in a module's tables (icons, particle textures, image slots)
local function addStrings(t, depth, visited)
	if depth > 6 or visited[t] then
		return
	end
	visited[t] = true
	for _, v in pairs(t) do
		if type(v) == "string" then
			addId(v)
		elseif type(v) == "table" then
			addStrings(v, depth + 1, visited)
		end
	end
end
local function collect(Config)
	-- sounds and music (Config keeps bare numbers)
	for _, def in pairs(Config.Sounds or {}) do
		addId("rbxassetid://" .. tostring(def.Id), true)
	end
	for _, track in ipairs(Config.Music or {}) do
		addId("rbxassetid://" .. tostring(track.Id), true)
	end
	addStrings(Config, 0, {})
	local okIcons, Icons = pcall(require, ReplicatedStorage.Mystree:WaitForChild("Icons", 5))
	if okIcons and type(Icons) == "table" then
		addStrings(Icons, 0, {})
	end
	-- the UI kit's fonts, every weight it uses
	for _, f in ipairs({
		font(Enum.FontWeight.Regular), font(Enum.FontWeight.Medium), font(Enum.FontWeight.SemiBold), font(Enum.FontWeight.Bold),
		font(Enum.FontWeight.SemiBold, true), font(Enum.FontWeight.Bold, true), SERIF,
	}) do
		addInstance(new("TextLabel", { FontFace = f, Text = "Mystree" }))
	end
	for _, root in ipairs({ ReplicatedStorage, game:GetService("Lighting"), game:GetService("SoundService"), workspace }) do
		addTree(root)
	end
end

local function preload()
	local total, done, failed, nextIndex, running = #items, 0, 0, 1, 0
	local bad = {}
	local function onAsset(id, fetch)
		-- a TextLabel also reports its blank content slot as a failed "" (the font itself loads)
		if fetch == Enum.AssetFetchStatus.Failure and id ~= "" then
			failed += 1
			if #bad < 8 then
				table.insert(bad, id)
			end
		end
	end
	local function worker()
		while nextIndex <= total do
			local i = nextIndex
			local j = math.min(total, i + L.Batch - 1)
			nextIndex = j + 1
			pcall(ContentProvider.PreloadAsync, ContentProvider, table.move(items, i, j, 1, {}), onAsset)
			done += j - i + 1
			setProgress(0.35 + 0.65 * done / total, string.format("Loading art and sounds  %d / %d", done, total))
		end
		running -= 1
	end
	for _ = 1, L.Workers do
		running += 1
		task.spawn(worker)
	end
	while running > 0 do
		task.wait(0.1)
	end
	if failed > 0 then
		warn(string.format("[MystreeLoading] %d of %d assets failed to load: %s", failed, total, table.concat(bad, " ")))
	end
	return total, failed
end

-- ===================================================================== run
setProgress(0.02, "Loading the world")
if not game:IsLoaded() then
	game.Loaded:Wait()
end
setProgress(0.1, "Streaming the Wildlands")
local okConfig, Config = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Mystree"):WaitForChild("Config"))
end)
if not okConfig then
	Config = {}
end
center = (Config.Wild and Config.Wild.Center) or center

-- the middle first (the flight looks at it), then every zone around it in parallel
local points = { center }
for _, z in ipairs(Config.Zones or {}) do
	if z.Center then
		table.insert(points, z.Center)
	end
end
local streamed = 0
local function stream(p)
	pcall(player.RequestStreamAroundAsync, player, p, L.StreamTimeout)
	streamed += 1
	setProgress(0.1 + 0.25 * streamed / #points)
end
stream(points[1])
startFlight()
for i = 2, #points do
	task.spawn(stream, points[i])
end
local t0 = os.clock()
while streamed < #points and os.clock() - t0 < L.StreamTimeout + 1 do
	task.wait(0.1)
end

setProgress(0.35, "Gathering assets")
collect(Config)
preload()
setProgress(1, "Ready")
while flightStart and os.clock() - flightStart < L.MinFlight and not finished do
	task.wait(0.1)
end
task.wait(0.3) -- let the bar reach 100%
finish()
