-- Builds the whole map from code (no assets needed):
--   Harbor  - lobby island with the leaderboard
--   Balloon - the giant shared basket the whole server rides in
--   Raft    - where you end up after going overboard

local Lighting = game:GetService("Lighting")

local WorldBuilder = {}
local S, Config

local WOOD = Color3.fromRGB(150, 105, 60)
local DARK_WOOD = Color3.fromRGB(105, 70, 40)
local SEA = Color3.fromRGB(40, 125, 200)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

-- Cylinder parts are round along X; rotate so the flat face points up.
local function disc(parent, name, center: Vector3, diameter: number, height: number, color, material)
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

local function label(parent: BasePart, text: string, face, textColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = textColor or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Parent = gui
	return t
end

local function ring(parent, center: Vector3, radius: number, segments: number, height: number, thickness: number, color, material)
	local circumference = 2 * math.pi * radius
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * radius, height / 2, math.sin(a) * radius)
		part({
			Name = "Rail",
			Size = Vector3.new(circumference / segments + 0.6, height, thickness),
			CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)),
			Color = color,
			Material = material,
			Parent = parent,
		})
	end
end

local function buildLighting()
	Lighting.ClockTime = 15
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 180)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Haze = 1.2
	atmosphere.Color = Color3.fromRGB(200, 225, 255)
	atmosphere.Decay = Color3.fromRGB(120, 170, 230)
	atmosphere.Parent = Lighting
end

local function buildHarbor(root)
	local folder = Instance.new("Folder")
	folder.Name = "Harbor"
	folder.Parent = root
	local c = Config.HarborPos

	part({
		Name = "Sea", Size = Vector3.new(2048, 1, 2048), CFrame = CFrame.new(c + Vector3.new(0, -3, 0)),
		Color = SEA, Material = Enum.Material.Glass, Transparency = 0.15, Parent = folder,
	})
	disc(folder, "Sand", c + Vector3.new(0, -1.5, 0), 150, 4, Color3.fromRGB(235, 215, 160), Enum.Material.Sand)
	disc(folder, "Grass", c + Vector3.new(0, -0.5, 0), 120, 1, Color3.fromRGB(90, 180, 80), Enum.Material.Grass)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HarborSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(c + Vector3.new(0, 0.5, 0))
	spawn.Color = Color3.fromRGB(255, 200, 60)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = folder

	local sign = part({
		Name = "TitleSign", Size = Vector3.new(36, 10, 1), CFrame = CFrame.new(c + Vector3.new(0, 12, -30)),
		Color = DARK_WOOD, Material = Enum.Material.WoodPlanks, Parent = folder,
	})
	label(sign, "OVERBOARD! 🎈\nThe next flight leaves soon...", Enum.NormalId.Back, Color3.fromRGB(255, 230, 120))
	for _, x in { -16, 16 } do
		part({
			Name = "Post", Size = Vector3.new(1.5, 12, 1.5), CFrame = CFrame.new(c + Vector3.new(x, 6, -30)),
			Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = folder,
		})
	end

	-- Global leaderboard board
	local board = part({
		Name = "Leaderboard", Size = Vector3.new(18, 22, 1),
		CFrame = CFrame.new(c + Vector3.new(34, 12, -10)) * CFrame.Angles(0, math.rad(-60), 0),
		Color = Color3.fromRGB(30, 40, 70), Material = Enum.Material.SmoothPlastic, Parent = folder,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.12)
	title.BackgroundTransparency = 1
	title.Text = "🏆 TOP SKY TREASURE HUNTERS"
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.fromRGB(255, 215, 80)
	title.Parent = gui
	local list = Instance.new("Frame")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.05, 0.14)
	list.Size = UDim2.fromScale(0.9, 0.84)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = list

	-- A small decorative balloon so new players instantly "get" the theme.
	local deco = c + Vector3.new(-30, 0, -10)
	disc(folder, "DecoBasket", deco + Vector3.new(0, 2, 0), 8, 4, WOOD, Enum.Material.WoodPlanks)
	part({
		Name = "DecoEnvelope", Shape = Enum.PartType.Ball, Size = Vector3.new(16, 16, 16),
		CFrame = CFrame.new(deco + Vector3.new(0, 16, 0)), Color = Color3.fromRGB(230, 60, 60),
		Material = Enum.Material.SmoothPlastic, Parent = folder,
	})

	return { spawn = spawn, leaderboardList = list }
end

local function buildBalloon(root)
	local folder = Instance.new("Folder")
	folder.Name = "Balloon"
	folder.Parent = root
	local top = Config.BalloonPos
	local R = Config.BasketRadius

	local floor = disc(folder, "BasketFloor", top - Vector3.new(0, 1, 0), R * 2 + 2, 2, WOOD, Enum.Material.WoodPlanks)
	ring(folder, top, R + 0.5, 32, 3.5, 1, DARK_WOOD, Enum.Material.WoodPlanks)

	-- Burner in the middle
	local burner = part({
		Name = "Burner", Size = Vector3.new(4, 5, 4), CFrame = CFrame.new(top + Vector3.new(0, 2.5, 0)),
		Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.DiamondPlate, Parent = folder,
	})
	local flame = part({
		Name = "Flame", Size = Vector3.new(3, 1, 3), CFrame = CFrame.new(top + Vector3.new(0, 5.5, 0)),
		Color = Color3.fromRGB(60, 60, 60), Material = Enum.Material.Metal, CanCollide = false, Parent = folder,
	})
	local fire = Instance.new("Fire")
	fire.Size = 12
	fire.Heat = 20
	fire.Enabled = false
	fire.Parent = flame
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pump Burner"
	prompt.ObjectText = "Burner (uses fuel)"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = burner

	-- Envelope + ropes (no collision, purely visual)
	local envelopeBottom = top + Vector3.new(0, 32, 0)
	local envelopeSize = R * 2.4
	part({
		Name = "Envelope", Shape = Enum.PartType.Ball, Size = Vector3.new(envelopeSize, envelopeSize, envelopeSize),
		CFrame = CFrame.new(envelopeBottom + Vector3.new(0, envelopeSize / 2 - 4, 0)),
		Color = Color3.fromRGB(230, 60, 60), Material = Enum.Material.SmoothPlastic,
		CanCollide = false, CanQuery = false, Parent = folder,
	})
	part({
		Name = "Stripe", Shape = Enum.PartType.Ball, Size = Vector3.new(envelopeSize + 0.4, envelopeSize * 0.3, envelopeSize + 0.4),
		CFrame = CFrame.new(envelopeBottom + Vector3.new(0, envelopeSize / 2 - 4, 0)),
		Color = Color3.fromRGB(255, 220, 70), Material = Enum.Material.SmoothPlastic,
		CanCollide = false, CanQuery = false, Parent = folder,
	})
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local from = top + Vector3.new(math.cos(a) * R, 3.5, math.sin(a) * R)
		local to = envelopeBottom + Vector3.new(math.cos(a) * R * 0.8, 0, math.sin(a) * R * 0.8)
		local length = (to - from).Magnitude
		part({
			Name = "Rope", Size = Vector3.new(0.4, 0.4, length), CFrame = CFrame.lookAt((from + to) / 2, to),
			Color = Color3.fromRGB(90, 70, 50), Material = Enum.Material.Fabric,
			CanCollide = false, CanQuery = false, Parent = folder,
		})
	end

	local sea = part({
		Name = "FlightSea", Size = Vector3.new(2048, 1, 2048), CFrame = CFrame.new(top - Vector3.new(0, 250, 0)),
		Color = SEA, Material = Enum.Material.Glass, Transparency = 0.1,
		CanCollide = false, CanQuery = false, CanTouch = false, Parent = folder,
	})

	return {
		top = top,
		floor = floor,
		burnerPrompt = prompt,
		fire = fire,
		sea = sea,
		folder = folder,
	}
end

local function buildDock(parent)
	local top = Config.BalloonPos
	local R = Config.BasketRadius
	local model = Instance.new("Model")
	model.Name = "SkyPort"
	local base = top + Vector3.new(0, -1, R + 16)
	part({
		Name = "Deck", Size = Vector3.new(50, 2, 22), CFrame = CFrame.new(base),
		Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = model,
	})
	local sign = part({
		Name = "Sign", Size = Vector3.new(30, 7, 1), CFrame = CFrame.new(base + Vector3.new(0, 9, 10)),
		Color = Color3.fromRGB(40, 60, 110), Material = Enum.Material.SmoothPlastic, Parent = model,
	})
	label(sign, "⚓ SKY PORT - loot cashed out!", Enum.NormalId.Front, Color3.fromRGB(255, 230, 120))
	for _, x in { -22, 22 } do
		part({
			Name = "Lamp", Size = Vector3.new(1, 8, 1), CFrame = CFrame.new(base + Vector3.new(x, 5, -9)),
			Color = Color3.fromRGB(255, 220, 120), Material = Enum.Material.Neon, Parent = model,
		})
	end
	model.Parent = parent
	return model
end

local function buildRaft(root)
	local folder = Instance.new("Folder")
	folder.Name = "Raft"
	folder.Parent = root
	local top = Config.RaftPos

	part({
		Name = "RaftSea", Size = Vector3.new(700, 1, 700), CFrame = CFrame.new(top - Vector3.new(0, 6, 0)),
		Color = SEA, Material = Enum.Material.Glass, Transparency = 0.1, CanCollide = false, Parent = folder,
	})
	part({
		Name = "Raft", Size = Vector3.new(40, 2, 40), CFrame = CFrame.new(top - Vector3.new(0, 1, 0)),
		Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = folder,
	})
	local sign = part({
		Name = "Sign", Size = Vector3.new(26, 7, 1), CFrame = CFrame.new(top + Vector3.new(0, 6, -19)),
		Color = DARK_WOOD, Material = Enum.Material.WoodPlanks, Parent = folder,
	})
	label(sign, "OVERBOARD! Hop the crates, grab FUEL BARRELS,\nfire them from the SKY CANNON to get back up!", Enum.NormalId.Back)

	-- Sky cannon
	local cannon = part({
		Name = "SkyCannon", Size = Vector3.new(8, 1, 8), CFrame = CFrame.new(top + Vector3.new(14, 0.5, 14)),
		Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, Parent = folder,
	})
	part({
		Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 4, 4),
		CFrame = CFrame.new(top + Vector3.new(14, 5, 14)) * CFrame.Angles(0, 0, math.rad(70)),
		Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal, CanCollide = false, Parent = folder,
	})
	local cannonLabel = Instance.new("BillboardGui")
	cannonLabel.Size = UDim2.fromOffset(200, 50)
	cannonLabel.StudsOffset = Vector3.new(0, 10, 0)
	cannonLabel.AlwaysOnTop = true
	cannonLabel.Parent = cannon
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "🚀 SKY CANNON"
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.fromRGB(255, 160, 60)
	t.TextStrokeTransparency = 0.3
	t.Parent = cannonLabel

	-- Floating crates: a little jump course; barrels spawn on the outer ones.
	local barrelSpots = {}
	local angle, radius = 0, 30
	for i = 1, 12 do
		angle += math.rad(38)
		radius += 3.2
		local pos = top + Vector3.new(math.cos(angle) * radius, (i % 3) * 1.5, math.sin(angle) * radius)
		part({
			Name = "Crate", Size = Vector3.new(8, 2, 8), CFrame = CFrame.new(pos - Vector3.new(0, 1, 0)),
			Color = Color3.fromRGB(180, 140, 80), Material = Enum.Material.Wood, Parent = folder,
		})
		if i >= 4 then
			table.insert(barrelSpots, CFrame.new(pos + Vector3.new(0, 1.6, 0)))
		end
	end

	return { top = top, cannon = cannon, barrelSpots = barrelSpots, folder = folder }
end

function WorldBuilder.Init(services)
	S = services
	Config = S.Config
end

function WorldBuilder.Build()
	local root = Instance.new("Folder")
	root.Name = "OverboardWorld"
	root.Parent = workspace

	buildLighting()
	local world = {
		root = root,
		harbor = buildHarbor(root),
		balloon = buildBalloon(root),
		raft = buildRaft(root),
	}

	local dockTemplate = buildDock(nil)
	function world.ShowDock(visible: boolean)
		local existing = world.balloon.folder:FindFirstChild("SkyPort")
		if visible and not existing then
			dockTemplate:Clone().Parent = world.balloon.folder
		elseif not visible and existing then
			existing:Destroy()
		end
	end

	-- Moving scenery and loot live here.
	local flying = Instance.new("Folder")
	flying.Name = "FlyingStuff"
	flying.Parent = root
	world.flying = flying

	S.World = world
	return world
end

return WorldBuilder
