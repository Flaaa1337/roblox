-- Builds the hub and the raid zone entirely from code.
-- The raid zone is generated from a fixed seed, so every server has the same
-- layout and players can learn the map.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}
local S

local CONCRETE = Color3.fromRGB(150, 145, 135)
local DARK_CONCRETE = Color3.fromRGB(105, 100, 95)
local RUST = Color3.fromRGB(140, 80, 50)

local CONTAINER_STYLE = {
	Crate = { color = Color3.fromRGB(150, 120, 70), size = Vector3.new(4, 3, 3), hold = 1.5, label = "Supply Crate" },
	Toolbox = { color = Color3.fromRGB(200, 60, 50), size = Vector3.new(3, 2, 2), hold = 2, label = "Toolbox" },
	MedCabinet = { color = Color3.fromRGB(230, 230, 230), size = Vector3.new(3, 4, 1.5), hold = 1.5, label = "Med Cabinet" },
	WeaponCase = { color = Color3.fromRGB(50, 70, 50), size = Vector3.new(5, 1.6, 2.4), hold = 3, label = "Weapon Case" },
	RobotCache = { color = Color3.fromRGB(60, 60, 70), size = Vector3.new(4, 4, 4), hold = 4, label = "Robot Cache" },
	DeathCache = { color = Color3.fromRGB(80, 120, 200), size = Vector3.new(3, 2, 3), hold = 2, label = "Raider Backpack" },
	Wreck = { color = Color3.fromRGB(70, 65, 60), size = Vector3.new(3, 1.5, 3), hold = 1.5, label = "Robot Wreck" },
}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	props.Parent = nil
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function surfaceText(parent: BasePart, text: string, face, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Parent = gui
	return gui
end

local function billboard(parent: Instance, text: string, color: Color3, offsetY: number, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 30)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance or 40
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return gui
end

-- Public so LootService can drop death caches and robot wrecks.
function MapBuilder.MakeContainer(cf: CFrame, kind: string, parent: Instance)
	local style = CONTAINER_STYLE[kind]
	local box = part({
		Name = kind, Size = style.size, CFrame = cf * CFrame.new(0, style.size.Y / 2, 0),
		Color = style.color, Material = Enum.Material.Metal, Parent = parent,
	})
	part({
		Name = "Lid", Size = Vector3.new(style.size.X + 0.2, 0.3, style.size.Z + 0.2),
		CFrame = box.CFrame * CFrame.new(0, style.size.Y / 2, 0), Color = style.color:Lerp(Color3.new(0, 0, 0), 0.3),
		Material = Enum.Material.Metal, CanCollide = false, Parent = box,
	})
	local custom = S.Assets.Get("Props", kind)
	if custom and custom:IsA("Model") then
		S.Assets.Fit(custom, math.max(style.size.X, style.size.Y, style.size.Z) * 1.2, cf * CFrame.new(0, style.size.Y / 2, 0))
		for _, d in custom:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		custom.Parent = box
		box.Transparency = 1
		box:FindFirstChild("Lid"):Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Search"
	prompt.ObjectText = style.label
	prompt.HoldDuration = style.hold
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	billboard(box, style.label, Color3.fromRGB(255, 230, 160), style.size.Y / 2 + 1.5, 30)
	return box, prompt
end

local function effect(className: string, props)
	local inst = Lighting:FindFirstChildOfClass(className) or Instance.new(className)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = Lighting
	return inst
end

local function buildLighting()
	-- Golden-hour wasteland look. (Lighting.Technology = Future is set in the
	-- place file because scripts are not allowed to change it.)
	Lighting.ClockTime = 17.3
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(40, 32, 30)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 100, 90)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = 0.1
	effect("Atmosphere", {
		Density = 0.38, Offset = 0.25, Haze = 2.2, Glare = 0.6,
		Color = Color3.fromRGB(235, 185, 140), Decay = Color3.fromRGB(110, 80, 70),
	})
	effect("ColorCorrectionEffect", {
		Brightness = 0.02, Contrast = 0.14, Saturation = -0.12, TintColor = Color3.fromRGB(255, 238, 220),
	})
	effect("BloomEffect", { Intensity = 0.7, Size = 28, Threshold = 1.4 })
	effect("SunRaysEffect", { Intensity = 0.07, Spread = 0.6 })
	effect("DepthOfFieldEffect", { FarIntensity = 0.12, FocusDistance = 40, InFocusRadius = 90, NearIntensity = 0 })
end

---------------------------------------------------------------------------
-- Terrain helpers (terrain looks far better than flat parts)
---------------------------------------------------------------------------
local Terrain = workspace.Terrain

local function paint(center: Vector3, radius: number, material)
	-- repaints the top layer of the ground in a disc
	Terrain:FillCylinder(CFrame.new(center.X, -1, center.Z), 2, radius, material)
end

local function mound(center: Vector3, radius: number, material)
	Terrain:FillBall(Vector3.new(center.X, -radius * 0.65, center.Z), radius, material)
end

local function boulder(center: Vector3, radius: number, material)
	Terrain:FillBall(center + Vector3.new(0, radius * 0.3, 0), radius, material)
end

---------------------------------------------------------------------------
-- Outpost: an underground survivor town you can walk around in
---------------------------------------------------------------------------
local function station(folder, cf: CFrame, name: string, panel: string, color: Color3, text: string, size: Vector3?)
	size = size or Vector3.new(10, 7, 3)
	local base = part({
		Name = name, Size = size, CFrame = cf * CFrame.new(0, size.Y / 2, 0),
		Color = color, Material = Enum.Material.DiamondPlate, Parent = folder,
	})
	local screen = part({
		Name = "Screen", Size = Vector3.new(size.X - 1, 3, 0.2), CFrame = base.CFrame * CFrame.new(0, size.Y / 2 + 2.2, 0),
		Color = Color3.fromRGB(20, 25, 30), Material = Enum.Material.SmoothPlastic, Parent = folder,
	})
	surfaceText(screen, text, Enum.NormalId.Back, Color3.fromRGB(255, 200, 90))
	surfaceText(screen, text, Enum.NormalId.Front, Color3.fromRGB(255, 200, 90))
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Color = color:Lerp(Color3.new(1, 1, 1), 0.5)
	light.Parent = screen
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Panel", panel)
	prompt.Parent = base
	return prompt
end

local function shack(folder, cf: CFrame, w: number, d: number, h: number, color: Color3)
	part({ Name = "ShackWall", Size = Vector3.new(w, h, 1), CFrame = cf * CFrame.new(0, h / 2, -d / 2), Color = color, Material = Enum.Material.CorrodedMetal, Parent = folder })
	part({ Name = "ShackWall", Size = Vector3.new(1, h, d), CFrame = cf * CFrame.new(-w / 2, h / 2, 0), Color = color, Material = Enum.Material.CorrodedMetal, Parent = folder })
	part({ Name = "ShackWall", Size = Vector3.new(1, h, d), CFrame = cf * CFrame.new(w / 2, h / 2, 0), Color = color, Material = Enum.Material.CorrodedMetal, Parent = folder })
	part({
		Name = "ShackRoof", Size = Vector3.new(w + 3, 0.6, d + 3), CFrame = cf * CFrame.new(0, h + 0.5, 1) * CFrame.Angles(math.rad(-8), 0, 0),
		Color = RUST, Material = Enum.Material.CorrodedMetal, Parent = folder,
	})
	local lamp = part({
		Name = "Lantern", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(w / 2 - 1, h - 1, d / 2 + 1),
		Color = Color3.fromRGB(255, 190, 110), Material = Enum.Material.Neon, CanCollide = false, Parent = folder,
	})
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Parent = lamp
end

local function buildHub(root)
	local folder = Instance.new("Folder")
	folder.Name = "Outpost"
	folder.Parent = root
	local c = Config.HubPos
	local R = 120 -- half size of the cavern

	-- Cavern carved out of solid rock
	Terrain:FillBlock(CFrame.new(c + Vector3.new(0, 30, 0)), Vector3.new(R * 2 + 80, 100, R * 2 + 80), Enum.Material.Rock)
	Terrain:FillBlock(CFrame.new(c + Vector3.new(0, 28, 0)), Vector3.new(R * 2, 60, R * 2), Enum.Material.Air)
	local caveRng = Random.new(7)
	for _ = 1, 40 do
		local p = c + Vector3.new(caveRng:NextNumber(-R, R), 58, caveRng:NextNumber(-R, R))
		if math.abs(p.X - c.X) > 20 or math.abs(p.Z - c.Z) > 20 then
			Terrain:FillBall(p, caveRng:NextNumber(4, 10), Enum.Material.Slate) -- stalactites
		end
	end
	for _ = 1, 30 do
		local a = caveRng:NextNumber(0, math.pi * 2)
		local p = c + Vector3.new(math.cos(a) * R, caveRng:NextNumber(0, 40), math.sin(a) * R)
		Terrain:FillBall(p, caveRng:NextNumber(6, 14), Enum.Material.Rock) -- uneven walls
	end
	part({
		Name = "Floor", Size = Vector3.new(R * 2, 4, R * 2), CFrame = CFrame.new(c - Vector3.new(0, 2, 0)),
		Color = Color3.fromRGB(85, 75, 65), Material = Enum.Material.Cobblestone, Parent = folder,
	})
	-- Central plaza with the big lift shaft up to the surface
	part({
		Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 70, 70),
		CFrame = CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 100, 90), Material = Enum.Material.Concrete, Parent = folder,
	})
	local shaft = part({
		Name = "LiftShaft", Shape = Enum.PartType.Cylinder, Size = Vector3.new(56, 14, 14),
		CFrame = CFrame.new(c + Vector3.new(0, 28, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 70, 75), Material = Enum.Material.DiamondPlate, Parent = folder,
	})
	for i = 1, 4 do
		local ring = part({
			Name = "ShaftLight", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 15, 15),
			CFrame = CFrame.new(c + Vector3.new(0, i * 11, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 150, 40), Material = Enum.Material.Neon, CanCollide = false, Parent = folder,
		})
		if i == 2 then
			local light = Instance.new("PointLight")
			light.Range = 60
			light.Brightness = 1.4
			light.Color = Color3.fromRGB(255, 180, 110)
			light.Parent = ring
		end
	end
	billboard(shaft, "THE OUTPOST", Color3.fromRGB(255, 190, 90), 32, 300)

	-- Ceiling lights
	for x = -80, 80, 80 do
		for z = -80, 80, 80 do
			if not (x == 0 and z == 0) then
				local bulb = part({
					Name = "CeilingLight", Size = Vector3.new(6, 0.6, 6), CFrame = CFrame.new(c + Vector3.new(x, 54.5, z)),
					Color = Color3.fromRGB(255, 210, 150), Material = Enum.Material.Neon, Parent = folder,
				})
				local light = Instance.new("PointLight")
				light.Range = 60
				light.Brightness = 1.2
				light.Color = Color3.fromRGB(255, 205, 150)
				light.Parent = bulb
			end
		end
	end

	-- Shacks along the cave walls make it feel like a town
	local shackColors = { Color3.fromRGB(120, 80, 60), Color3.fromRGB(80, 100, 110), Color3.fromRGB(110, 110, 80) }
	local i = 0
	for _, side in { -1, 1 } do
		for z = -90, 90, 30 do
			i += 1
			if math.abs(z) > 20 then
				local cf = CFrame.new(c + Vector3.new(side * 100, 0, z)) * CFrame.Angles(0, math.rad(side * 90), 0)
				shack(folder, cf, 16, 12, 10, shackColors[i % #shackColors + 1])
			end
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "OutpostSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(c + Vector3.new(0, 0.5, 45))
	spawn.Color = Color3.fromRGB(255, 170, 40)
	spawn.Material = Enum.Material.Metal
	spawn.Parent = folder

	-- Stations (all face the plaza)
	local function facing(pos: Vector3)
		return CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z))
	end
	local prompts = {
		station(folder, facing(c + Vector3.new(-50, 0, -60)), "Trader", "Trader", Color3.fromRGB(150, 110, 40), "TRADER"),
		station(folder, facing(c + Vector3.new(-15, 0, -70)), "Stash", "Stash", Color3.fromRGB(60, 90, 140), "STASH & LOADOUT"),
		station(folder, facing(c + Vector3.new(20, 0, -70)), "Workbench", "Workbench", Color3.fromRGB(120, 90, 60), "WORKBENCH LV1"),
		station(folder, facing(c + Vector3.new(55, 0, -60)), "Upgrades", "Upgrades", Color3.fromRGB(80, 120, 80), "UPGRADES"),
		station(folder, facing(c + Vector3.new(-60, 0, 55)), "Private Quarters", "Quarters", Color3.fromRGB(110, 70, 140), "PRIVATE QUARTERS"),
		station(folder, facing(c + Vector3.new(0, 0, -28)), "Map Terminal", "MapSelect", Color3.fromRGB(200, 110, 30), "⬆ DEPLOY - CHOOSE MAP",
			Vector3.new(16, 5, 3)),
	}

	-- Leaderboard
	local board = part({
		Name = "Leaderboard", Size = Vector3.new(24, 18, 1),
		CFrame = facing(c + Vector3.new(60, 12, 60)) * CFrame.Angles(0, math.pi, 0),
		Color = Color3.fromRGB(25, 28, 36), Material = Enum.Material.SmoothPlastic, Parent = folder,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.14)
	title.BackgroundTransparency = 1
	title.Text = "🏆 TOP RAIDERS (total extracted)"
	title.TextScaled = true
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = Color3.fromRGB(255, 180, 60)
	title.Parent = gui
	local list = Instance.new("Frame")
	list.Name = "List"
	list.Position = UDim2.fromScale(0.05, 0.16)
	list.Size = UDim2.fromScale(0.9, 0.82)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = list

	return { spawn = spawn, prompts = prompts, leaderboardList = list }
end

---------------------------------------------------------------------------
-- Private Quarters: one room per player, built when they first visit
---------------------------------------------------------------------------
function MapBuilder.BuildQuarters(index: number, ownerName: string)
	local origin = Config.QuartersOrigin + Vector3.new(0, 0, index * Config.QuartersSpacing)
	local model = Instance.new("Model")
	model.Name = "Quarters_" .. index
	local W, D, H = 60, 44, 16
	local wallColor = Color3.fromRGB(95, 85, 80)

	part({ Name = "Floor", Size = Vector3.new(W, 2, D), CFrame = CFrame.new(origin - Vector3.new(0, 1, 0)), Color = Color3.fromRGB(110, 85, 60), Material = Enum.Material.WoodPlanks, Parent = model })
	part({ Name = "Ceiling", Size = Vector3.new(W, 2, D), CFrame = CFrame.new(origin + Vector3.new(0, H + 1, 0)), Color = wallColor, Material = Enum.Material.Concrete, Parent = model })
	part({ Name = "Wall", Size = Vector3.new(W, H, 1), CFrame = CFrame.new(origin + Vector3.new(0, H / 2, -D / 2)), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
	part({ Name = "Wall", Size = Vector3.new(W, H, 1), CFrame = CFrame.new(origin + Vector3.new(0, H / 2, D / 2)), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
	part({ Name = "Wall", Size = Vector3.new(1, H, D), CFrame = CFrame.new(origin + Vector3.new(-W / 2, H / 2, 0)), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
	part({ Name = "Wall", Size = Vector3.new(1, H, D), CFrame = CFrame.new(origin + Vector3.new(W / 2, H / 2, 0)), Color = wallColor, Material = Enum.Material.Brick, Parent = model })
	for _, x in { -15, 15 } do
		local bulb = part({
			Name = "Light", Size = Vector3.new(4, 0.4, 4), CFrame = CFrame.new(origin + Vector3.new(x, H - 0.2, 0)),
			Color = Color3.fromRGB(255, 220, 170), Material = Enum.Material.Neon, Parent = model,
		})
		local light = Instance.new("PointLight")
		light.Range = 35
		light.Color = Color3.fromRGB(255, 215, 165)
		light.Parent = bulb
	end
	local sign = part({
		Name = "NamePlate", Size = Vector3.new(16, 3, 0.4), CFrame = CFrame.new(origin + Vector3.new(0, H - 3, -D / 2 + 0.8)),
		Color = Color3.fromRGB(30, 30, 35), Material = Enum.Material.SmoothPlastic, Parent = model,
	})
	surfaceText(sign, ownerName .. "'s Quarters", Enum.NormalId.Back, Color3.fromRGB(255, 200, 90))

	local function prompt(cf: CFrame, name: string, panel: string, color: Color3, text: string)
		return station(model, cf, name, panel, color, text, Vector3.new(8, 5, 3))
	end
	local bench = prompt(CFrame.new(origin + Vector3.new(-20, 0, -18)), "Personal Workbench", "Workbench", Color3.fromRGB(120, 90, 60), "WORKBENCH")
	local stash = prompt(CFrame.new(origin + Vector3.new(-6, 0, -18)), "Stash", "Stash", Color3.fromRGB(60, 90, 140), "STASH")
	local decor = prompt(CFrame.new(origin + Vector3.new(8, 0, -18)), "Decorate", "Decorate", Color3.fromRGB(150, 80, 120), "DECORATE")
	local exit = prompt(CFrame.lookAt(origin + Vector3.new(0, 0, 18), origin), "Back to Outpost", "Exit", Color3.fromRGB(200, 110, 30), "EXIT")

	-- Decoration slots along the walls and corners
	local slots = {}
	local positions = {
		Vector3.new(-25, 0, 15), Vector3.new(-25, 0, 0), Vector3.new(25, 0, 15), Vector3.new(25, 0, 0),
		Vector3.new(25, 0, -15), Vector3.new(-12, 0, 10), Vector3.new(12, 0, 10), Vector3.new(20, 0, -18),
	}
	for i, offset in positions do
		local pos = origin + offset
		slots[i] = CFrame.lookAt(pos, Vector3.new(origin.X, pos.Y, origin.Z))
		local marker = part({
			Name = "SlotMarker", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 5, 5),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.Neon, Transparency = 0.7, CanCollide = false, Parent = model,
		})
		billboard(marker, "Slot " .. i, Color3.fromRGB(255, 220, 140), 1.5, 25)
	end

	local decorFolder = Instance.new("Folder")
	decorFolder.Name = "Decor"
	decorFolder.Parent = model
	model.Parent = S.World.root

	return {
		model = model,
		spawn = CFrame.new(origin + Vector3.new(0, 3, 10)),
		prompts = { bench, stash, decor, exit },
		slots = slots,
		decorFolder = decorFolder,
	}
end

---------------------------------------------------------------------------
-- Set dressing: wrecked cars, street lamps, dead trees, barrels, fences
---------------------------------------------------------------------------
local function car(folder, rng: Random, pos: Vector3)
	local model = Instance.new("Model")
	model.Name = "WreckedCar"
	local colors = { Color3.fromRGB(140, 60, 45), Color3.fromRGB(70, 90, 110), Color3.fromRGB(180, 170, 150), Color3.fromRGB(60, 80, 60) }
	local color = colors[rng:NextInteger(1, #colors)]
	local base = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-6, 6)))
	part({ Name = "Body", Size = Vector3.new(6, 2.2, 13), CFrame = base * CFrame.new(0, 1.8, 0), Color = color, Material = Enum.Material.CorrodedMetal, Parent = model })
	part({ Name = "Cabin", Size = Vector3.new(5.4, 2, 6), CFrame = base * CFrame.new(0, 3.9, 0.8), Color = color:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.CorrodedMetal, Parent = model })
	part({ Name = "Windshield", Size = Vector3.new(5, 1.7, 0.2), CFrame = base * CFrame.new(0, 3.9, -2.25) * CFrame.Angles(math.rad(-25), 0, 0), Color = Color3.fromRGB(30, 40, 45), Material = Enum.Material.Glass, Transparency = 0.4, Parent = model })
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			if rng:NextNumber() < 0.85 then
				part({
					Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 2.4, 2.4),
					CFrame = base * CFrame.new(x * 3, 0.9, z * 4.2), Color = Color3.fromRGB(25, 25, 28), Material = Enum.Material.Rubber, Parent = model,
				})
			end
		end
	end
	model.Parent = folder
end

local function streetLamp(folder, pos: Vector3, working: boolean)
	part({ Name = "LampPole", Size = Vector3.new(0.6, 16, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)), Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal, Parent = folder })
	part({ Name = "LampArm", Size = Vector3.new(4, 0.4, 0.4), CFrame = CFrame.new(pos + Vector3.new(1.8, 15.8, 0)), Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal, Parent = folder })
	local bulb = part({
		Name = "LampHead", Size = Vector3.new(1.6, 0.5, 1), CFrame = CFrame.new(pos + Vector3.new(3.6, 15.5, 0)),
		Color = if working then Color3.fromRGB(255, 200, 130) else Color3.fromRGB(60, 60, 60),
		Material = if working then Enum.Material.Neon else Enum.Material.Glass, Parent = folder,
	})
	if working then
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Range = 40
		light.Angle = 80
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Parent = bulb
	end
end

local function deadTree(folder, rng: Random, pos: Vector3)
	local height = rng:NextNumber(12, 22)
	local wood = Color3.fromRGB(70, 55, 45)
	local trunk = part({
		Name = "Trunk", Size = Vector3.new(1.4, height, 1.4), CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))),
		Color = wood, Material = Enum.Material.Wood, Parent = folder,
	})
	for _ = 1, rng:NextInteger(3, 5) do
		local y = rng:NextNumber(height * 0.4, height * 0.95) - height / 2
		local len = rng:NextNumber(4, 8)
		local yaw = rng:NextNumber(0, math.pi * 2)
		part({
			Name = "Branch", Size = Vector3.new(0.5, len, 0.5), CanCollide = false,
			CFrame = trunk.CFrame * CFrame.new(0, y, 0) * CFrame.Angles(0, yaw, math.rad(rng:NextNumber(30, 60))) * CFrame.new(0, len / 2, 0),
			Color = wood, Material = Enum.Material.Wood, Parent = folder,
		})
	end
end

local function barrels(folder, rng: Random, pos: Vector3)
	local colors = { Color3.fromRGB(150, 50, 40), Color3.fromRGB(60, 90, 140), Color3.fromRGB(200, 160, 40), Color3.fromRGB(90, 90, 90) }
	for i = 1, rng:NextInteger(1, 4) do
		local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		local fallen = rng:NextNumber() < 0.25
		part({
			Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.2, 2.4, 2.4),
			CFrame = CFrame.new(pos + offset + Vector3.new(0, if fallen then 1.2 else 1.6, 0)) * (if fallen then CFrame.Angles(0, rng:NextNumber(0, 6), 0) else CFrame.Angles(0, 0, math.rad(90))),
			Color = colors[rng:NextInteger(1, #colors)], Material = Enum.Material.CorrodedMetal, Parent = folder,
		})
	end
end

local function fence(folder, rng: Random, pos: Vector3)
	local yaw = rng:NextNumber(0, math.pi)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local segments = rng:NextInteger(2, 5)
	for i = 0, segments do
		part({ Name = "FencePost", Size = Vector3.new(0.4, 7, 0.4), CFrame = base * CFrame.new(i * 8, 3.5, 0), Color = Color3.fromRGB(80, 80, 85), Material = Enum.Material.Metal, Parent = folder })
		if i < segments and rng:NextNumber() < 0.8 then
			part({
				Name = "FenceMesh", Size = Vector3.new(8, 6, 0.1), CFrame = base * CFrame.new(i * 8 + 4, 3.5, 0) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, 0),
				Color = Color3.fromRGB(110, 110, 115), Material = Enum.Material.DiamondPlate, Transparency = 0.55, Parent = folder,
			})
		end
	end
end

local function powerPole(folder, pos: Vector3)
	part({ Name = "PowerPole", Size = Vector3.new(1, 28, 1), CFrame = CFrame.new(pos + Vector3.new(0, 14, 0)), Color = Color3.fromRGB(80, 60, 45), Material = Enum.Material.Wood, Parent = folder })
	part({ Name = "CrossBar", Size = Vector3.new(8, 0.6, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 25, 0)), Color = Color3.fromRGB(80, 60, 45), Material = Enum.Material.Wood, Parent = folder })
end

function MapBuilder.Props(folder, rng: Random, c: Vector3, half: number, clear, quarry: boolean)
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = folder
	-- along the roads
	for i = -2, 2 do
		local offset = i * 128 + 64
		if math.abs(offset) < half then
			for t = -half + 20, half - 20, 32 do
				local alongX = c + Vector3.new(offset + 10, 0, t)
				local alongZ = c + Vector3.new(t, 0, offset - 10)
				if not quarry and clear(alongX, 10) and rng:NextNumber() < 0.5 then
					streetLamp(props, alongX, rng:NextNumber() < 0.35)
				elseif quarry and clear(alongX, 10) and rng:NextNumber() < 0.3 then
					powerPole(props, alongX)
				end
				if clear(alongZ, 12) and rng:NextNumber() < 0.22 then
					car(props, rng, alongZ + Vector3.new(0, 0, rng:NextNumber(-4, 4)))
				end
			end
		end
	end
	-- scattered dressing
	for _ = 1, 70 do
		local pos = c + Vector3.new(rng:NextNumber(-half + 15, half - 15), 0, rng:NextNumber(-half + 15, half - 15))
		if clear(pos, 12) and (pos - c).Magnitude > 45 then
			local roll = rng:NextNumber()
			if roll < 0.35 then
				barrels(props, rng, pos)
			elseif roll < 0.6 then
				deadTree(props, rng, pos)
			elseif roll < 0.8 then
				fence(props, rng, pos)
			else
				car(props, rng, pos)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Raid zone
---------------------------------------------------------------------------
local function building(folder, rng: Random, center: Vector3, containers)
	local w, d, h = rng:NextInteger(24, 40), rng:NextInteger(20, 34), rng:NextInteger(13, 18)
	local yaw = math.rad(rng:NextInteger(0, 3) * 90)
	local base = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	local color = if rng:NextNumber() < 0.5 then CONCRETE else Color3.fromRGB(160, 135, 115)
	local model = Instance.new("Model")
	model.Name = "Building"

	part({ Name = "Floor", Size = Vector3.new(w, 1, d), CFrame = base * CFrame.new(0, 0.5, 0), Color = DARK_CONCRETE, Material = Enum.Material.Concrete, Parent = model })

	-- Four walls; each gets a doorway (front/back) or window gap (sides).
	local walls = {
		{ length = w, cf = base * CFrame.new(0, h / 2, -d / 2), door = true },
		{ length = w, cf = base * CFrame.new(0, h / 2, d / 2), door = rng:NextNumber() < 0.6 },
		{ length = d, cf = base * CFrame.new(-w / 2, h / 2, 0) * CFrame.Angles(0, math.rad(90), 0), door = false },
		{ length = d, cf = base * CFrame.new(w / 2, h / 2, 0) * CFrame.Angles(0, math.rad(90), 0), door = rng:NextNumber() < 0.3 },
	}
	for _, wall in walls do
		local gap = if wall.door then 7 else 0
		local gapCenter = rng:NextNumber(-wall.length / 4, wall.length / 4)
		if gap == 0 then
			part({ Name = "Wall", Size = Vector3.new(wall.length, h, 1.2), CFrame = wall.cf, Color = color, Material = Enum.Material.Concrete, Parent = model })
			-- window slit
			part({
				Name = "Window", Size = Vector3.new(wall.length * 0.4, 2.5, 1.4), CFrame = wall.cf * CFrame.new(gapCenter, 1, 0),
				Color = Color3.fromRGB(20, 20, 25), Material = Enum.Material.Glass, Transparency = 0.6, CanCollide = false, Parent = model,
			})
		else
			local leftLen = wall.length / 2 + gapCenter - gap / 2
			local rightLen = wall.length / 2 - gapCenter - gap / 2
			part({ Name = "Wall", Size = Vector3.new(leftLen, h, 1.2), CFrame = wall.cf * CFrame.new(-wall.length / 2 + leftLen / 2, 0, 0), Color = color, Material = Enum.Material.Concrete, Parent = model })
			part({ Name = "Wall", Size = Vector3.new(rightLen, h, 1.2), CFrame = wall.cf * CFrame.new(wall.length / 2 - rightLen / 2, 0, 0), Color = color, Material = Enum.Material.Concrete, Parent = model })
			part({ Name = "Lintel", Size = Vector3.new(gap, h - 9, 1.2), CFrame = wall.cf * CFrame.new(gapCenter, 4.5, 0), Color = color, Material = Enum.Material.Concrete, Parent = model })
		end
	end

	-- Broken wall tops and exposed rebar make the ruins read as ruins.
	for _, wall in walls do
		for _ = 1, rng:NextInteger(1, 3) do
			local x = rng:NextNumber(-wall.length / 2 + 2, wall.length / 2 - 2)
			local w2 = rng:NextNumber(2, 6)
			part({
				Name = "Rubble", Size = Vector3.new(w2, rng:NextNumber(1, 4), 1.3),
				CFrame = wall.cf * CFrame.new(x, h / 2 + 1, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-12, 12))),
				Color = color, Material = Enum.Material.Concrete, Parent = model,
			})
			if rng:NextNumber() < 0.6 then
				part({
					Name = "Rebar", Size = Vector3.new(0.2, rng:NextNumber(2, 4), 0.2), CanCollide = false,
					CFrame = wall.cf * CFrame.new(x + w2 / 2 + 0.5, h / 2 + 1.5, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25))),
					Color = Color3.fromRGB(110, 60, 40), Material = Enum.Material.CorrodedMetal, Parent = model,
				})
			end
		end
	end
	-- Rubble piles at the base (terrain)
	for _ = 1, rng:NextInteger(1, 3) do
		-- the left wall never has a door, so rubble there never blocks a way in
		local corner = base * CFrame.new(-w / 2 - 2.5, 0, rng:NextNumber(-d / 2, d / 2))
		Terrain:FillBall(corner.Position, rng:NextNumber(2.5, 4), Enum.Material.Concrete)
	end

	-- Partly collapsed roof: drones can see in through the holes.
	if rng:NextNumber() < 0.75 then
		local roofW = w * rng:NextNumber(0.5, 1)
		part({
			Name = "Roof", Size = Vector3.new(roofW, 1, d), CFrame = base * CFrame.new(-(w - roofW) / 2, h + 0.5, 0),
			Color = DARK_CONCRETE, Material = Enum.Material.Concrete, Parent = model,
		})
	end

	-- Inside: cover + loot
	for _ = 1, rng:NextInteger(1, 2) do
		part({
			Name = "Cover", Size = Vector3.new(rng:NextInteger(4, 8), rng:NextInteger(3, 5), 2),
			CFrame = base * CFrame.new(rng:NextNumber(-w / 3, w / 3), 2, rng:NextNumber(-d / 3, d / 3)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = RUST, Material = Enum.Material.CorrodedMetal, Parent = model,
		})
	end
	local kinds = { "Crate", "Crate", "Toolbox", "MedCabinet", "WeaponCase" }
	for i = 1, rng:NextInteger(1, 3) do
		local kind = kinds[rng:NextInteger(1, #kinds)]
		local spot = base * CFrame.new(rng:NextNumber(-w / 2 + 3, w / 2 - 3), 1, (if i % 2 == 0 then 1 else -1) * (d / 2 - 2.5))
		table.insert(containers, { cf = spot, kind = kind })
	end

	model.Parent = folder
end

local function shippingContainer(folder, rng: Random, position: Vector3, containers)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local colors = { Color3.fromRGB(160, 60, 40), Color3.fromRGB(40, 90, 140), Color3.fromRGB(60, 120, 70), Color3.fromRGB(200, 150, 40) }
	local color = colors[rng:NextInteger(1, #colors)]
	local model = Instance.new("Model")
	model.Name = "ShippingContainer"
	local L, W, H = 24, 10, 10
	part({ Name = "Floor", Size = Vector3.new(W, 0.6, L), CFrame = base * CFrame.new(0, 0.3, 0), Color = color, Material = Enum.Material.CorrodedMetal, Parent = model })
	part({ Name = "Roof", Size = Vector3.new(W, 0.6, L), CFrame = base * CFrame.new(0, H, 0), Color = color, Material = Enum.Material.CorrodedMetal, Parent = model })
	part({ Name = "Side", Size = Vector3.new(0.6, H, L), CFrame = base * CFrame.new(-W / 2, H / 2, 0), Color = color, Material = Enum.Material.CorrodedMetal, Parent = model })
	part({ Name = "Side", Size = Vector3.new(0.6, H, L), CFrame = base * CFrame.new(W / 2, H / 2, 0), Color = color, Material = Enum.Material.CorrodedMetal, Parent = model })
	part({ Name = "Back", Size = Vector3.new(W, H, 0.6), CFrame = base * CFrame.new(0, H / 2, -L / 2), Color = color, Material = Enum.Material.CorrodedMetal, Parent = model })
	model.Parent = folder
	if rng:NextNumber() < 0.7 then
		table.insert(containers, { cf = base * CFrame.new(0, 0.6, -L / 2 + 3), kind = if rng:NextNumber() < 0.3 then "WeaponCase" else "Crate" })
	end
end

local function crashSite(folder, rng: Random, center: Vector3, containers)
	local model = Instance.new("Model")
	model.Name = "CrashSite"
	-- A huge downed machine hull, half buried
	part({
		Name = "Hull", Shape = Enum.PartType.Ball, Size = Vector3.new(60, 60, 60), CFrame = CFrame.new(center + Vector3.new(0, -12, 0)),
		Color = Color3.fromRGB(70, 65, 60), Material = Enum.Material.CorrodedMetal, Parent = model,
	})
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		part({
			Name = "Leg", Size = Vector3.new(5, 5, 50),
			CFrame = CFrame.new(center + Vector3.new(math.cos(a) * 38, 6, math.sin(a) * 38)) * CFrame.Angles(math.rad(rng:NextNumber(-30, 30)), a, math.rad(rng:NextNumber(-20, 20))),
			Color = RUST, Material = Enum.Material.CorrodedMetal, Parent = model,
		})
	end
	local eye = part({
		Name = "DeadEye", Shape = Enum.PartType.Ball, Size = Vector3.new(12, 12, 12), CFrame = CFrame.new(center + Vector3.new(0, 14, -24)),
		Color = Color3.fromRGB(120, 20, 20), Material = Enum.Material.Neon, Parent = model,
	})
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 50, 30)
	light.Range = 40
	light.Parent = eye
	model.Parent = folder
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + 0.4
		table.insert(containers, { cf = CFrame.new(center + Vector3.new(math.cos(a) * 46, 0, math.sin(a) * 46)), kind = "RobotCache" })
	end
end

local function buildRaid(root, map)
	local folder = Instance.new("Folder")
	folder.Name = "Map_" .. map.id
	folder.Parent = root
	local rng = Random.new(map.seed)
	local c = map.pos
	local size = map.size
	local half = size / 2

	local quarry = not map.crashSite
	local groundMat = if quarry then Enum.Material.Sand else Enum.Material.Ground
	local rockMat = if quarry then Enum.Material.Sandstone else Enum.Material.Rock
	-- Ground (terrain)
	Terrain:FillBlock(CFrame.new(c - Vector3.new(0, 8, 0)), Vector3.new(size + 200, 16, size + 200), groundMat)
	-- Cliffs all around the zone
	for i = 0, 3 do
		local angle = math.rad(i * 90)
		local center = c + Vector3.new(math.sin(angle) * (half + 30), 20, math.cos(angle) * (half + 30))
		Terrain:FillBlock(CFrame.new(center) * CFrame.Angles(0, angle, 0), Vector3.new(size + 160, 60, 50), rockMat)
	end
	for _ = 1, 60 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = half + rng:NextNumber(5, 25)
		Terrain:FillBall(c + Vector3.new(math.cos(a) * r, rng:NextNumber(20, 50), math.sin(a) * r), rng:NextNumber(12, 24), rockMat)
	end
	-- Invisible wall so nobody climbs out
	for i = 0, 3 do
		local angle = math.rad(i * 90)
		part({
			Name = "Boundary", Size = Vector3.new(size + 40, 300, 4), Transparency = 1,
			CFrame = CFrame.new(c + Vector3.new(math.sin(angle) * (half + 8), 150, math.cos(angle) * (half + 8))) * CFrame.Angles(0, angle, 0),
			Parent = folder,
		})
	end
	-- Roads (painted into the terrain)
	for i = -2, 2 do
		local offset = i * 128 + 64
		if math.abs(offset) < half then
			Terrain:FillBlock(CFrame.new(c + Vector3.new(offset, -1, 0)), Vector3.new(16, 2, size), if quarry then Enum.Material.Ground else Enum.Material.Asphalt)
			Terrain:FillBlock(CFrame.new(c + Vector3.new(0, -1, offset)), Vector3.new(size, 2, 16), if quarry then Enum.Material.Ground else Enum.Material.Asphalt)
		end
	end
	-- Ground variety
	local patchMats = if quarry
		then { Enum.Material.Sandstone, Enum.Material.Ground, Enum.Material.Salt }
		else { Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Mud, Enum.Material.Pavement }
	for _ = 1, 90 do
		local pos = c + Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(-half, half))
		paint(pos, rng:NextNumber(8, 26), patchMats[rng:NextInteger(1, #patchMats)])
	end
	local containers = {}
	local blocked = {} -- positions to keep clear (spawns, lifts)

	-- Insertion points (where raiders arrive)
	local insertions = {}
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * (half - 25), 0, math.sin(a) * (half - 25))
		table.insert(insertions, CFrame.lookAt(pos + Vector3.new(0, 3, 0), c + Vector3.new(0, 3, 0)))
		table.insert(blocked, pos)
		part({ Name = "Insertion", Size = Vector3.new(8, 0.3, 8), CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)), Color = Color3.fromRGB(80, 160, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
	end

	-- Extraction lifts
	local extracts = {}
	for i, deg in { 0, 120, 240 } do
		local a = math.rad(deg + 30)
		local pos = c + Vector3.new(math.cos(a) * (half - 45), 0, math.sin(a) * (half - 45))
		table.insert(blocked, pos)
		local pad = part({
			Name = "ExtractPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, Config.ExtractRadius * 2, Config.ExtractRadius * 2),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(60, 200, 90), Material = Enum.Material.Neon, Transparency = 0.3, Parent = folder,
		})
		local beacon = part({
			Name = "Beacon", Size = Vector3.new(2, 60, 2), CFrame = CFrame.new(pos + Vector3.new(Config.ExtractRadius + 2, 30, 0)),
			Color = Color3.fromRGB(60, 200, 90), Material = Enum.Material.Neon, CanCollide = false, Parent = folder,
		})
		for k = 0, 3 do
			local a2 = k / 4 * math.pi * 2 + math.pi / 4
			part({
				Name = "LiftPillar", Size = Vector3.new(1.5, 18, 1.5),
				CFrame = CFrame.new(pos + Vector3.new(math.cos(a2) * Config.ExtractRadius, 9, math.sin(a2) * Config.ExtractRadius)),
				Color = Color3.fromRGB(60, 62, 66), Material = Enum.Material.DiamondPlate, Parent = folder,
			})
		end
		part({
			Name = "LiftFrame", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, Config.ExtractRadius * 2 + 2, Config.ExtractRadius * 2 + 2),
			CFrame = CFrame.new(pos + Vector3.new(0, 18.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(255, 160, 40), Material = Enum.Material.Metal, Transparency = 0.6, CanCollide = false, Parent = folder,
		})
		local beaconLight = Instance.new("PointLight")
		beaconLight.Color = Color3.fromRGB(80, 255, 120)
		beaconLight.Range = 35
		beaconLight.Brightness = 2
		beaconLight.Parent = beacon
		local console = part({
			Name = "Console", Size = Vector3.new(3, 4, 2), CFrame = CFrame.new(pos + Vector3.new(Config.ExtractRadius - 2, 2, 0)),
			Color = Color3.fromRGB(50, 55, 60), Material = Enum.Material.Metal, Parent = folder,
		})
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Call Lift"
		prompt.ObjectText = "Extraction " .. i
		prompt.HoldDuration = Config.ExtractHoldTime
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = console
		local label = billboard(beacon, "EXTRACTION", Color3.fromRGB(90, 255, 120), 32, 2000)
		label.AlwaysOnTop = true
		table.insert(extracts, { position = pos, pad = pad, beacon = beacon, prompt = prompt, label = label.Label, index = i })
	end

	local function clear(pos: Vector3, radius: number): boolean
		for _, b in blocked do
			if (b - pos).Magnitude < radius then
				return false
			end
		end
		return true
	end

	-- City blocks
	for gx = -2, 2 do
		for gz = -2, 2 do
			local cell = c + Vector3.new(gx * 128, 0, gz * 128)
			if not (gx == 0 and gz == 0) then
				for _ = 1, rng:NextInteger(map.buildings[1], map.buildings[2]) do
					local pos = cell + Vector3.new(rng:NextNumber(-35, 35), 0, rng:NextNumber(-35, 35))
					if clear(pos, 45) and math.abs(pos.X - c.X) < half - 25 and math.abs(pos.Z - c.Z) < half - 25 then
						building(folder, rng, pos, containers)
						table.insert(blocked, pos)
					end
				end
			end
		end
	end
	if map.crashSite then
		crashSite(folder, rng, c, containers)
	else
		-- open maps get a robot cache camp in the middle instead
		for i = 1, 3 do
			local a = i / 3 * math.pi * 2
			table.insert(containers, { cf = CFrame.new(c + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14)), kind = "RobotCache" })
		end
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			part({
				Name = "Barricade", Size = Vector3.new(10, 4, 2), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 26, 2, math.sin(a) * 26)) * CFrame.Angles(0, -a, 0),
				Color = RUST, Material = Enum.Material.CorrodedMetal, Parent = folder,
			})
		end
	end

	for _ = 1, map.containers do
		local pos = c + Vector3.new(rng:NextNumber(-half + 30, half - 30), 0, rng:NextNumber(-half + 30, half - 30))
		if clear(pos, 28) and (pos - c).Magnitude > 60 then
			shippingContainer(folder, rng, pos, containers)
			table.insert(blocked, pos)
		end
	end

	-- Boulders, hills and cover (terrain), plus a few loose crates
	for _ = 1, map.rocks do
		local pos = c + Vector3.new(rng:NextNumber(-half + 10, half - 10), 0, rng:NextNumber(-half + 10, half - 10))
		if clear(pos, 14) and (pos - c).Magnitude > 50 then
			local r = rng:NextNumber(3, 8)
			boulder(pos, r, rockMat)
			if rng:NextNumber() < 0.4 then
				boulder(pos + Vector3.new(r, 0, rng:NextNumber(-r, r)), r * 0.6, rockMat)
			end
			if rng:NextNumber() < 0.15 then
				table.insert(containers, { cf = CFrame.new(pos + Vector3.new(r + 3, 0, 0)), kind = "Crate" })
			end
		end
	end
	for _ = 1, 14 do
		local pos = c + Vector3.new(rng:NextNumber(-half + 40, half - 40), 0, rng:NextNumber(-half + 40, half - 40))
		if clear(pos, 40) and (pos - c).Magnitude > 70 then
			mound(pos, rng:NextNumber(18, 32), groundMat)
		end
	end
	MapBuilder.Props(folder, rng, c, half, clear, quarry)

	-- Robot spawn points: anywhere not right next to a spawn or lift
	local robotSpawns = {}
	local tries = 0
	while #robotSpawns < 50 and tries < 1000 do
		tries += 1
		local pos = c + Vector3.new(rng:NextNumber(-half + 20, half - 20), 0, rng:NextNumber(-half + 20, half - 20))
		local ok = true
		for _, ins in insertions do
			if (ins.Position - pos).Magnitude < 70 then
				ok = false
			end
		end
		if ok then
			table.insert(robotSpawns, pos)
		end
	end

	return {
		def = map,
		id = map.id,
		folder = folder,
		center = c,
		half = half,
		insertions = insertions,
		extracts = extracts,
		containerSpots = containers,
		robotSpawns = robotSpawns,
		bossSpawn = if map.crashSite then c + Vector3.new(0, 0, 70) else nil,
	}
end

function MapBuilder.Init(services)
	S = services
end

function MapBuilder.Build()
	local root = Instance.new("Folder")
	root.Name = "ScrapfallWorld"
	root.Parent = workspace
	buildLighting()
	local maps = {}
	for _, map in Config.Maps do
		maps[map.id] = buildRaid(root, map)
	end
	local world = { root = root, hub = buildHub(root), maps = maps }
	local dynamic = Instance.new("Folder")
	dynamic.Name = "Dynamic"
	dynamic.Parent = root
	world.dynamic = dynamic
	S.World = world
	return world
end

return MapBuilder
