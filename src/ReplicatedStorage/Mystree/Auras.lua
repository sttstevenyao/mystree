-- ReplicatedStorage/Mystree/Auras (ModuleScript, used by the client)
-- Passive auras for Mythic beasts and Legendary+ spirits (Playbook 06: every Mythic gets one).
-- Textures are VFX Library ids (~/Roblox/VFX Library, from the VFX Studio plugin): white on
-- transparent, coloured here. The default sparkle is used only by the Divine Azure Dragon.
--
-- Auras.attach(model, presetName) -> handle (handle.Destroy(), handle.Stop()) or nil
--
-- Nodes: each layer sits on a named node. A sculpt places its own Attachments named "Aura<Node>"
-- (AuraHead, AuraTail, AuraBack, AuraCore, AuraFoot1..4, AuraWingL, AuraWingR) on the part that
-- carries that body area, so the aura follows its bones. A model without them (placeholders) gets
-- the nodes worked out from its bounding box, on its PrimaryPart. "Volume" layers emit from the
-- whole PrimaryPart box (motes and petals around the body).
-- Sizes are written for a creature 10 studs long and scale with the model.

local RunService = game:GetService("RunService")

local Auras = {}

local TEX = {
	Flame = "rbxassetid://9358765944", -- Fire #11 "a": a white stylised flame, Grid4x4
	Orb = "rbxasset://textures/particles/forcefield_glow_main.dds", -- a soft white glow (built in)
	Crackle = "rbxassetid://9178507829", -- Lightning #41: crackling arcs, Grid4x4
	Bolt = "rbxassetid://7151842823", -- Beam #117 "lightning beam 1 straightened": wingtip bolt
	Swirl = "rbxassetid://13580356309", -- Swirl #71 "swirl2": a soft ribbon spiral
	Cloud = "rbxassetid://258128463", -- Smoke #6 "cloud_main"
	Mist = "rbxassetid://13826565206", -- Smoke "Mist1", Grid4x4
	Snow = "rbxassetid://242837894", -- Form "PARTICE Snowflake"
	Petal = "rbxassetid://90111316485044", -- Other "glow petal", Grid4x4
	Spark = "rbxasset://textures/particles/sparkles_main.dds", -- real magic only (Divine)
}

local function seq(a, b)
	return ColorSequence.new(a, b or a)
end

-- Layer fields: Nodes = { names } or "Volume"; Texture; Flipbook = "Grid4x4" (loops over the
-- lifetime); Color; Size = { start, end } (studs at length 10); Life = { min, max }; Rate; Speed =
-- { min, max }; Spread (degrees); Dir = "Top" | ...; Accel (Vector3); Light (LightEmission);
-- Alpha = { start, end } transparency; Spin = { min, max } deg/s; Locked (LockedToPart).
local PRESETS = {
	-- Heavenly Qilin (Mythic) and the Qilin spirit: holy jade fire. Flames lick up from each hoof
	-- (the qilin walks on fire), a flame crest rides the mane, and jade motes drift off the body.
	Qilin = {
		Light = { Color = Color3.fromRGB(120, 255, 200), Range = 10, Brightness = 0.5 },
		Layers = {
			{ Nodes = { "Foot1", "Foot2", "Foot3", "Foot4" }, Texture = TEX.Flame, Flipbook = "Grid4x4",
				Color = seq(Color3.fromRGB(110, 240, 180), Color3.fromRGB(30, 160, 110)), Size = { 1.5, 0.2 }, Life = { 0.45, 0.65 },
				Rate = 9, Speed = { 1.4, 2.4 }, Spread = 12, Dir = "Top", Light = 0.8, Alpha = { 0.2, 1 } },
			{ Nodes = { "Back", "Head" }, Texture = TEX.Flame, Flipbook = "Grid4x4", Color = seq(Color3.fromRGB(90, 230, 170), Color3.fromRGB(20, 140, 100)),
				Size = { 2, 0.3 }, Life = { 0.6, 0.9 }, Rate = 8, Speed = { 2, 3.2 }, Spread = 20, Dir = "Top", Light = 0.8, Alpha = { 0.25, 1 },
				Spin = { -20, 20 } },
			{ Nodes = "Volume", Texture = TEX.Orb, Color = seq(Color3.fromRGB(170, 255, 220), Color3.fromRGB(60, 200, 150)),
				Size = { 0.3, 0 }, Life = { 2, 3 }, Rate = 4, Speed = { 0.3, 1 }, Spread = 180, Accel = Vector3.new(0, 1.2, 0), Light = 0.6, Alpha = { 0.3, 1 } },
		},
	},
	-- Nine-Tailed Fox (Mythic) and its spirit: foxfire. Pink flame pours off the tails, foxfire orbs
	-- float up behind it, and a few glowing petals drift around the body.
	NineTails = {
		Light = { Color = Color3.fromRGB(255, 150, 210), Range = 10, Brightness = 0.5 },
		Layers = {
			{ Nodes = { "Tail" }, Texture = TEX.Flame, Flipbook = "Grid4x4", Color = seq(Color3.fromRGB(255, 110, 190), Color3.fromRGB(170, 30, 120)),
				Size = { 2.4, 0.4 }, Life = { 0.55, 0.8 }, Rate = 16, Speed = { 1.8, 3 }, Spread = 35, Dir = "Top", Light = 0.85, Alpha = { 0.15, 1 } },
			{ Nodes = { "Tail" }, Texture = TEX.Orb, Color = seq(Color3.fromRGB(255, 130, 205), Color3.fromRGB(210, 60, 160)),
				Size = { 0.9, 0.3 }, Life = { 1.6, 2.4 }, Rate = 6, Speed = { 1.5, 3 }, Spread = 70, Dir = "Top", Accel = Vector3.new(0, 0.8, 0),
				Light = 1, Alpha = { 0, 1 } },
			{ Nodes = "Volume", Texture = TEX.Petal, Flipbook = "Grid4x4", Color = seq(Color3.fromRGB(255, 200, 230)), Size = { 0.35, 0.3 },
				Life = { 2.2, 3 }, Rate = 3, Speed = { 0.4, 1 }, Spread = 180, Accel = Vector3.new(0, -0.4, 0), Light = 0.6, Alpha = { 0.1, 1 },
				Spin = { -90, 90 } },
		},
	},
	-- Thunder Roc (Mythic): a storm on wings. Arcs crackle off both wings and the body, a bolt
	-- flickers between the wingtips, and the light stutters like lightning.
	ThunderRoc = {
		Light = { Color = Color3.fromRGB(150, 190, 255), Range = 12, Brightness = 0.6, Flicker = true },
		Beam = { From = "WingL", To = "WingR", Texture = TEX.Bolt, Width = 0.8, Color = seq(Color3.fromRGB(220, 235, 255), Color3.fromRGB(110, 160, 255)),
			Flicker = true },
		Layers = {
			{ Nodes = { "WingL", "WingR", "Core" }, Texture = TEX.Crackle, Flipbook = "Grid4x4", Color = seq(Color3.fromRGB(235, 245, 255), Color3.fromRGB(100, 150, 255)),
				Size = { 2.6, 3 }, Life = { 0.2, 0.3 }, Rate = 3, Speed = { 0, 0 }, Spread = 0, Light = 1, Alpha = { 0.1, 0.7 }, Spin = { 0, 0 }, Locked = true },
			{ Nodes = "Volume", Texture = TEX.Orb, Color = seq(Color3.fromRGB(210, 230, 255), Color3.fromRGB(90, 140, 255)), Size = { 0.3, 0 },
				Life = { 0.8, 1.4 }, Rate = 6, Speed = { 2, 4 }, Spread = 180, Light = 0.8, Alpha = { 0.2, 1 } },
		},
	},
	-- Azure Dragon (Divine spirit, the showpiece): azure ribbons spiral round it, cloud trails off
	-- the tail, and real-magic glints sparkle (the one place the sparkle texture is allowed).
	AzureDragon = {
		Light = { Color = Color3.fromRGB(110, 170, 255), Range = 10, Brightness = 0.6 },
		Layers = {
			{ Nodes = { "Core" }, Texture = TEX.Swirl, Color = seq(Color3.fromRGB(200, 230, 255), Color3.fromRGB(70, 140, 255)), Size = { 3, 4.4 },
				Life = { 1, 1.4 }, Rate = 2, Speed = { 0, 0 }, Spread = 0, Light = 0.7, Alpha = { 0.6, 1 }, Spin = { 140, 220 }, Locked = true },
			{ Nodes = { "Tail" }, Texture = TEX.Cloud, Color = seq(Color3.fromRGB(240, 248, 255), Color3.fromRGB(170, 205, 255)), Size = { 1.4, 3 },
				Life = { 1.2, 1.8 }, Rate = 5, Speed = { 0.3, 0.8 }, Spread = 40, Light = 0.3, Alpha = { 0.55, 1 }, Spin = { -30, 30 } },
			{ Nodes = "Volume", Texture = TEX.Spark, Color = seq(Color3.fromRGB(255, 255, 255), Color3.fromRGB(130, 190, 255)), Size = { 0.35, 0 },
				Life = { 0.8, 1.3 }, Rate = 3, Speed = { 0.5, 1.5 }, Spread = 180, Light = 0.8, Alpha = { 0.1, 1 } },
		},
	},
	-- Wisps: the body is mostly particles, a soft glow round the core and mist off the tendrils.
	MarshWisp = {
		Light = { Color = Color3.fromRGB(140, 240, 215), Range = 8, Brightness = 0.5 },
		Layers = {
			{ Nodes = { "Core" }, Texture = TEX.Orb, Color = seq(Color3.fromRGB(170, 250, 225), Color3.fromRGB(70, 180, 150)), Size = { 2.2, 3 },
				Life = { 0.8, 1.2 }, Rate = 3, Speed = { 0, 0.3 }, Spread = 180, Light = 0.5, Alpha = { 0.65, 1 } },
			{ Nodes = { "Core" }, Texture = TEX.Mist, Flipbook = "Grid4x4", Color = seq(Color3.fromRGB(120, 200, 180)), Size = { 1.4, 2.4 },
				Life = { 1.2, 1.8 }, Rate = 2, Speed = { 0.3, 0.7 }, Spread = 60, Light = 0.2, Alpha = { 0.7, 1 }, Accel = Vector3.new(0, -1, 0) },
		},
	},
	IceWisp = {
		Light = { Color = Color3.fromRGB(170, 225, 255), Range = 8, Brightness = 0.5 },
		Layers = {
			{ Nodes = { "Core" }, Texture = TEX.Orb, Color = seq(Color3.fromRGB(205, 240, 255), Color3.fromRGB(90, 160, 230)), Size = { 2.2, 3 },
				Life = { 0.8, 1.2 }, Rate = 3, Speed = { 0, 0.3 }, Spread = 180, Light = 0.5, Alpha = { 0.65, 1 } },
			{ Nodes = "Volume", Texture = TEX.Snow, Color = seq(Color3.fromRGB(240, 250, 255)), Size = { 0.25, 0.15 }, Life = { 1.2, 1.8 },
				Rate = 4, Speed = { 0.2, 0.6 }, Spread = 180, Accel = Vector3.new(0, -1, 0), Light = 0.5, Alpha = { 0.1, 1 } },
		},
	},
	-- Ember and Cinder Wraiths: embers rising off the robe, flame licking from the hands.
	EmberWraith = {
		Light = { Color = Color3.fromRGB(255, 150, 60), Range = 10, Brightness = 0.5 },
		Layers = {
			{ Nodes = "Volume", Texture = TEX.Orb, Color = seq(Color3.fromRGB(255, 190, 90), Color3.fromRGB(220, 70, 20)), Size = { 0.3, 0.1 },
				Life = { 0.9, 1.5 }, Rate = 7, Speed = { 1, 2.4 }, Spread = 40, Light = 0.8, Alpha = { 0.1, 1 }, Accel = Vector3.new(0, 2, 0) },
			{ Nodes = { "WingL", "WingR" }, Texture = TEX.Flame, Flipbook = "Grid4x4", Color = seq(Color3.fromRGB(255, 170, 70), Color3.fromRGB(200, 50, 20)), Size = { 1, 1.5 },
				Life = { 0.5, 0.8 }, Rate = 3, Speed = { 0.4, 1 }, Spread = 25, Light = 0.8, Alpha = { 0.35, 1 } },
		},
	},
	CinderWraith = {
		Layers = {
			{ Nodes = "Volume", Texture = TEX.Orb, Color = seq(Color3.fromRGB(255, 150, 70), Color3.fromRGB(180, 50, 20)), Size = { 0.25, 0.08 },
				Life = { 0.8, 1.3 }, Rate = 3, Speed = { 0.8, 1.8 }, Spread = 40, Light = 0.8, Alpha = { 0.1, 1 }, Accel = Vector3.new(0, 2, 0) },
		},
	},
	-- Frost Wolf (Legendary spirit): cold mist rolls off its paws and snow drifts down around it.
	FrostWolf = {
		Light = { Color = Color3.fromRGB(180, 225, 255), Range = 8, Brightness = 0.5 },
		Layers = {
			{ Nodes = { "Foot1", "Foot2", "Foot3", "Foot4" }, Texture = TEX.Mist, Flipbook = "Grid4x4", Color = seq(Color3.fromRGB(235, 248, 255), Color3.fromRGB(170, 215, 255)),
				Size = { 1.1, 2 }, Life = { 1, 1.4 }, Rate = 2, Speed = { 0.2, 0.5 }, Spread = 60, Light = 0.4, Alpha = { 0.6, 1 } },
			{ Nodes = "Volume", Texture = TEX.Snow, Color = seq(Color3.fromRGB(240, 250, 255)), Size = { 0.3, 0.2 }, Life = { 1.8, 2.6 },
				Rate = 5, Speed = { 0.2, 0.6 }, Spread = 180, Accel = Vector3.new(0, -1, 0), Light = 0.5, Alpha = { 0.1, 1 }, Spin = { -60, 60 } },
		},
	},
}
Auras.Presets = PRESETS

-- node offsets as fractions of the bounding box (x across, y up, z nose(-) to tail(+))
local NODES = {
	Core = Vector3.new(0, 0.05, 0),
	Head = Vector3.new(0, 0.35, -0.45),
	Back = Vector3.new(0, 0.48, 0.05),
	Tail = Vector3.new(0, 0.2, 0.48),
	Foot1 = Vector3.new(0.3, -0.48, -0.32),
	Foot2 = Vector3.new(-0.3, -0.48, -0.32),
	Foot3 = Vector3.new(0.3, -0.48, 0.32),
	Foot4 = Vector3.new(-0.3, -0.48, 0.32),
	WingL = Vector3.new(-0.5, 0.2, 0),
	WingR = Vector3.new(0.5, 0.2, 0),
}

local function nodeAttachment(model, host, name, made)
	local own = model:FindFirstChild("Aura" .. name, true)
	if own and own:IsA("Attachment") then
		return own
	end
	if made[name] then
		return made[name]
	end
	local cf, size = model:GetBoundingBox()
	local rel = host.CFrame:ToObjectSpace(cf)
	local f = NODES[name] or Vector3.zero
	local att = Instance.new("Attachment")
	att.Name = "AuraNode_" .. name
	att.Position = rel.Position + Vector3.new(f.X * size.X, f.Y * size.Y, f.Z * size.Z)
	att.Parent = host
	made[name] = att
	return att
end

local function emitter(layer, s, parent)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Aura"
	e.Texture = layer.Texture
	e.Color = layer.Color
	e.LightEmission = layer.Light or 0.8
	e.Size = NumberSequence.new(layer.Size[1] * s, layer.Size[2] * s)
	e.Transparency = NumberSequence.new(layer.Alpha[1], layer.Alpha[2])
	e.Lifetime = NumberRange.new(layer.Life[1], layer.Life[2])
	e.Rate = layer.Rate
	e.Speed = NumberRange.new(layer.Speed[1] * s, layer.Speed[2] * s)
	e.SpreadAngle = Vector2.new(layer.Spread or 0, layer.Spread or 0)
	e.EmissionDirection = Enum.NormalId[layer.Dir or "Top"]
	e.Acceleration = (layer.Accel or Vector3.zero) * s
	e.Rotation = NumberRange.new(0, 360)
	local spin = layer.Spin or { -15, 15 }
	e.RotSpeed = NumberRange.new(spin[1], spin[2])
	e.LockedToPart = layer.Locked == true
	if layer.Flipbook then
		e.FlipbookLayout = Enum.ParticleFlipbookLayout[layer.Flipbook]
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	e.Parent = parent
	return e
end

local live = {} -- handles with a flickering light or beam
local flickerConn

local function startFlicker()
	if flickerConn then
		return
	end
	flickerConn = RunService.Heartbeat:Connect(function()
		for h in pairs(live) do
			if not h.Host.Parent then
				live[h] = nil
			else
				if h.Light and h.FlickerLight then
					h.Light.Brightness = h.BaseBright * (math.random() < 0.12 and 2.2 or 0.7 + math.random() * 0.4)
				end
				if h.Beam then
					h.Beam.Enabled = math.random() < 0.35
					h.Beam.CurveSize0 = (math.random() - 0.5) * 3
					h.Beam.CurveSize1 = (math.random() - 0.5) * 3
				end
			end
		end
		if next(live) == nil then
			flickerConn:Disconnect()
			flickerConn = nil
		end
	end)
end

function Auras.attach(model, name)
	local preset = PRESETS[name or ""]
	local host = model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
	if not (preset and host) then
		return nil
	end
	local _, size = model:GetBoundingBox()
	local s = math.clamp(math.max(size.X, size.Z) / 10, 0.25, 3)
	local made = {}
	local h = { Host = host, Emitters = {}, Made = made }
	for _, layer in ipairs(preset.Layers) do
		if layer.Nodes == "Volume" then
			local e = emitter(layer, s, host)
			e.Shape = Enum.ParticleEmitterShape.Box
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			table.insert(h.Emitters, e)
		else
			for _, n in ipairs(layer.Nodes) do
				table.insert(h.Emitters, emitter(layer, s, nodeAttachment(model, host, n, made)))
			end
		end
	end
	if preset.Light then
		local l = Instance.new("PointLight")
		l.Name = "AuraLight"
		l.Color = preset.Light.Color
		l.Range = preset.Light.Range * math.clamp(s, 0.5, 2)
		l.Brightness = preset.Light.Brightness
		l.Parent = host
		h.Light, h.BaseBright, h.FlickerLight = l, l.Brightness, preset.Light.Flicker
	end
	if preset.Beam then
		local b = preset.Beam
		local beam = Instance.new("Beam")
		beam.Name = "AuraBeam"
		beam.Attachment0 = nodeAttachment(model, host, b.From, made)
		beam.Attachment1 = nodeAttachment(model, host, b.To, made)
		beam.Texture = b.Texture
		beam.Color = b.Color
		beam.Width0, beam.Width1 = b.Width * s, b.Width * s
		beam.LightEmission = 1
		beam.TextureSpeed = 4
		beam.TextureLength = 3 * s
		beam.FaceCamera = true
		beam.Parent = host
		h.Beam = beam
	end
	if h.FlickerLight or h.Beam then
		live[h] = true
		startFlicker()
	end
	function h.Stop()
		for _, e in ipairs(h.Emitters) do
			e.Enabled = false
		end
		if h.Beam then
			h.Beam.Enabled = false
		end
		live[h] = nil
	end
	function h.Destroy()
		h.Stop()
		for _, e in ipairs(h.Emitters) do
			e:Destroy()
		end
		for _, a in pairs(made) do
			a:Destroy()
		end
		for _, x in ipairs({ h.Light, h.Beam }) do
			if x then
				x:Destroy()
			end
		end
	end
	return h
end

return Auras
