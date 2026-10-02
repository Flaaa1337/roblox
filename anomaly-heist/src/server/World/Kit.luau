--!strict
-- Modular primitive art kit (spec 4.3). Every piece is built from anchored
-- Parts so the first build needs no uploaded assets. Pieces return their
-- root Model or Part; callers parent them.

local CollectionService = game:GetService("CollectionService")

local Kit = {}

Kit.Palette = {
	stone = Color3.fromRGB(226, 221, 210),
	stoneDark = Color3.fromRGB(196, 190, 178),
	concrete = Color3.fromRGB(176, 174, 168),
	metal = Color3.fromRGB(118, 124, 132),
	metalDark = Color3.fromRGB(70, 74, 82),
	wood = Color3.fromRGB(150, 108, 70),
	grass = Color3.fromRGB(104, 170, 84),
	grassDark = Color3.fromRGB(82, 140, 68),
	leaf = Color3.fromRGB(86, 158, 72),
	leafDark = Color3.fromRGB(64, 128, 58),
	trunk = Color3.fromRGB(112, 82, 58),
	rock = Color3.fromRGB(140, 138, 132),
	safe = Color3.fromRGB(64, 200, 228), -- cyan: safe equipment
	anomaly = Color3.fromRGB(150, 92, 232), -- violet: anomalies
	hazard = Color3.fromRGB(240, 142, 52), -- orange: hazards
	path = Color3.fromRGB(206, 200, 186),
	white = Color3.fromRGB(240, 240, 238),
}

local P = Kit.Palette

export type PartProps = { [string]: any }

function Kit.part(props: PartProps, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

function Kit.wedge(props: PartProps, parent: Instance?): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

function Kit.model(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Invisible marker used by gameplay (spawn points, waypoints...).
function Kit.marker(name: string, cf: CFrame, parent: Instance, attributes: { [string]: any }?): Part
	local p = Kit.part({
		Name = name, Size = Vector3.new(2, 2, 2), CFrame = cf, Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false,
	}, parent)
	for key, value in (attributes or {}) :: { [string]: any } do
		p:SetAttribute(key, value)
	end
	return p
end

---------------------------------------------------------------------------
-- Ground & architecture
---------------------------------------------------------------------------
function Kit.floor(cf: CFrame, size: Vector2, color: Color3, material: Enum.Material?, parent: Instance?): Part
	return Kit.part({
		Name = "Floor", Size = Vector3.new(size.X, 2, size.Y), CFrame = cf * CFrame.new(0, -1, 0),
		Color = color, Material = material or Enum.Material.Slate,
	}, parent)
end

function Kit.wall(cf: CFrame, length: number, height: number, color: Color3?, parent: Instance?): Part
	return Kit.part({
		Name = "Wall", Size = Vector3.new(length, height, 1.5), CFrame = cf * CFrame.new(0, height / 2, 0),
		Color = color or P.concrete, Material = Enum.Material.Concrete,
	}, parent)
end

-- Wall with a centered doorway gap.
function Kit.doorway(cf: CFrame, length: number, height: number, gap: number, parent: Instance?): Model
	local m = Kit.model("Doorway", parent)
	local side = (length - gap) / 2
	Kit.wall(cf * CFrame.new(-(gap + side) / 2, 0, 0), side, height, nil, m)
	Kit.wall(cf * CFrame.new((gap + side) / 2, 0, 0), side, height, nil, m)
	Kit.part({
		Name = "Lintel", Size = Vector3.new(gap, 2, 1.5), CFrame = cf * CFrame.new(0, height - 1, 0),
		Color = P.concrete, Material = Enum.Material.Concrete,
	}, m)
	return m
end

-- Ramp rising along the CFrame's -Z (LookVector) by `rise` over `run`.
function Kit.ramp(cf: CFrame, width: number, run: number, rise: number, parent: Instance?): WedgePart
	return Kit.wedge({
		Name = "Ramp", Size = Vector3.new(width, rise, run), CFrame = cf * CFrame.new(0, rise / 2, -run / 2) * CFrame.Angles(0, math.pi, 0),
		Color = P.stoneDark, Material = Enum.Material.Slate,
	}, parent)
end

function Kit.stairs(cf: CFrame, width: number, steps: number, stepRise: number, stepRun: number, parent: Instance?): Model
	local m = Kit.model("Stairs", parent)
	for i = 1, steps do
		Kit.part({
			Name = "Step", Size = Vector3.new(width, stepRise * i, stepRun),
			CFrame = cf * CFrame.new(0, stepRise * i / 2, -(i - 0.5) * stepRun),
			Color = P.stoneDark, Material = Enum.Material.Slate,
		}, m)
	end
	return m
end

function Kit.railing(cf: CFrame, length: number, parent: Instance?): Model
	local m = Kit.model("Railing", parent)
	local posts = math.max(2, math.floor(length / 6) + 1)
	for i = 0, posts - 1 do
		local x = -length / 2 + (length / (posts - 1)) * i
		Kit.part({ Name = "Post", Size = Vector3.new(0.4, 3, 0.4), CFrame = cf * CFrame.new(x, 1.5, 0), Color = P.metal, Material = Enum.Material.Metal }, m)
	end
	Kit.part({ Name = "Rail", Size = Vector3.new(length, 0.3, 0.3), CFrame = cf * CFrame.new(0, 3, 0), Color = P.metal, Material = Enum.Material.Metal }, m)
	Kit.part({ Name = "Rail", Size = Vector3.new(length, 0.2, 0.2), CFrame = cf * CFrame.new(0, 1.8, 0), Color = P.metal, Material = Enum.Material.Metal }, m)
	return m
end

---------------------------------------------------------------------------
-- Props
---------------------------------------------------------------------------
function Kit.tree(cf: CFrame, scale: number, parent: Instance?): Model
	local m = Kit.model("Tree", parent)
	local h = 7 * scale
	Kit.part({ Name = "Trunk", Size = Vector3.new(1.4 * scale, h, 1.4 * scale), CFrame = cf * CFrame.new(0, h / 2, 0), Color = P.trunk, Material = Enum.Material.Wood }, m)
	Kit.part({ Name = "Leaves", Size = Vector3.new(7, 5, 7) * scale, CFrame = cf * CFrame.new(0, h + 1.5 * scale, 0), Color = P.leaf, Material = Enum.Material.Grass }, m)
	Kit.part({ Name = "Leaves", Size = Vector3.new(4.5, 3.5, 4.5) * scale, CFrame = cf * CFrame.new(0.6 * scale, h + 4.8 * scale, -0.4 * scale), Color = P.leafDark, Material = Enum.Material.Grass }, m)
	return m
end

function Kit.rock(cf: CFrame, size: Vector3, parent: Instance?): Part
	return Kit.part({ Name = "Rock", Size = size, CFrame = cf * CFrame.new(0, size.Y / 2 - 0.4, 0), Color = P.rock, Material = Enum.Material.Slate }, parent)
end

function Kit.planter(cf: CFrame, size: Vector2, parent: Instance?): Model
	local m = Kit.model("Planter", parent)
	Kit.part({ Name = "Box", Size = Vector3.new(size.X, 2, size.Y), CFrame = cf * CFrame.new(0, 1, 0), Color = P.stoneDark, Material = Enum.Material.Concrete }, m)
	Kit.part({ Name = "Soil", Size = Vector3.new(size.X - 1, 0.2, size.Y - 1), CFrame = cf * CFrame.new(0, 2.05, 0), Color = P.grassDark, Material = Enum.Material.Grass }, m)
	for i = -1, 1, 2 do
		Kit.part({ Name = "Bush", Size = Vector3.new(2.5, 2, 2.5), CFrame = cf * CFrame.new(i * size.X / 4, 3, 0), Color = P.leaf, Material = Enum.Material.Grass }, m)
	end
	return m
end

function Kit.bench(cf: CFrame, parent: Instance?): Model
	local m = Kit.model("Bench", parent)
	Kit.part({ Name = "Seat", Size = Vector3.new(6, 0.5, 2), CFrame = cf * CFrame.new(0, 2, 0), Color = P.wood, Material = Enum.Material.WoodPlanks }, m)
	Kit.part({ Name = "Back", Size = Vector3.new(6, 2, 0.4), CFrame = cf * CFrame.new(0, 3.2, 0.8), Color = P.wood, Material = Enum.Material.WoodPlanks }, m)
	for i = -1, 1, 2 do
		Kit.part({ Name = "Leg", Size = Vector3.new(0.4, 2, 1.8), CFrame = cf * CFrame.new(i * 2.6, 1, 0), Color = P.metalDark, Material = Enum.Material.Metal }, m)
	end
	return m
end

function Kit.crate(cf: CFrame, size: number, parent: Instance?): Model
	local m = Kit.model("Crate", parent)
	Kit.part({ Name = "Box", Size = Vector3.one * size, CFrame = cf * CFrame.new(0, size / 2, 0), Color = Color3.fromRGB(176, 140, 92), Material = Enum.Material.WoodPlanks }, m)
	Kit.part({ Name = "Band", Size = Vector3.new(size + 0.1, 0.3, size + 0.1), CFrame = cf * CFrame.new(0, size * 0.75, 0), Color = P.metalDark, Material = Enum.Material.Metal }, m)
	return m
end

function Kit.lamp(cf: CFrame, color: Color3, parent: Instance?): Model
	local m = Kit.model("Lamp", parent)
	Kit.part({ Name = "Pole", Size = Vector3.new(0.6, 10, 0.6), CFrame = cf * CFrame.new(0, 5, 0), Color = P.metalDark, Material = Enum.Material.Metal }, m)
	local head = Kit.part({ Name = "Head", Size = Vector3.new(1.6, 1, 1.6), CFrame = cf * CFrame.new(0, 10.4, 0), Color = color, Material = Enum.Material.Neon }, m)
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = color
	light.Shadows = false
	light.Parent = head
	return m
end

-- Workshop machine / research device; `damaged` tilts it and adds scrap.
function Kit.machine(cf: CFrame, accent: Color3, damaged: boolean, parent: Instance?): Model
	local m = Kit.model("Machine", parent)
	local tilt = if damaged then CFrame.Angles(0, 0, math.rad(9)) else CFrame.identity
	local base = cf * tilt
	Kit.part({ Name = "Body", Size = Vector3.new(5, 4, 3), CFrame = base * CFrame.new(0, 2, 0), Color = P.metal, Material = Enum.Material.Metal }, m)
	Kit.part({ Name = "Panel", Size = Vector3.new(3.4, 1.6, 0.2), CFrame = base * CFrame.new(0, 2.6, -1.55), Color = Color3.fromRGB(30, 34, 40), Material = Enum.Material.SmoothPlastic }, m)
	Kit.part({ Name = "Light", Size = Vector3.new(0.6, 0.6, 0.2), CFrame = base * CFrame.new(1.2, 2.6, -1.62), Color = accent, Material = Enum.Material.Neon }, m)
	Kit.part({ Name = "Vent", Size = Vector3.new(1.6, 1.4, 1.6), CFrame = base * CFrame.new(-1.2, 4.7, 0.4), Color = P.metalDark, Material = Enum.Material.Metal }, m)
	if damaged then
		Kit.part({ Name = "Scrap", Size = Vector3.new(1.5, 0.3, 2), CFrame = cf * CFrame.new(3.6, 0.15, 0.8) * CFrame.Angles(0, 0.7, 0), Color = P.metalDark, Material = Enum.Material.CorrodedMetal }, m)
		Kit.part({ Name = "Cable", Size = Vector3.new(0.3, 0.3, 4), CFrame = cf * CFrame.new(-3, 0.15, 1) * CFrame.Angles(0, 0.4, 0), Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.Rubber }, m)
	end
	return m
end

-- Ground cables between two points (decoration).
function Kit.cable(from: Vector3, to: Vector3, parent: Instance?): Part
	local mid = (from + to) / 2
	return Kit.part({
		Name = "Cable", Size = Vector3.new(0.35, 0.35, (to - from).Magnitude), CFrame = CFrame.lookAt(mid, to),
		Color = Color3.fromRGB(34, 34, 38), Material = Enum.Material.Rubber, CanCollide = false,
	}, parent)
end

---------------------------------------------------------------------------
-- Signs and portals (localized text is applied by the client)
---------------------------------------------------------------------------
-- A world sign whose text is a localization key. Optional `params` are set
-- as attributes "Param_<name>"; a value starting with "@" is itself a key.
function Kit.sign(cf: CFrame, size: Vector2, key: string, accent: Color3, parent: Instance?, params: { [string]: string }?): Model
	local m = Kit.model("Sign", parent)
	local board = Kit.part({
		Name = "Board", Size = Vector3.new(size.X, size.Y, 0.4), CFrame = cf,
		Color = Color3.fromRGB(34, 38, 46), Material = Enum.Material.SmoothPlastic,
	}, m)
	Kit.part({ Name = "Trim", Size = Vector3.new(size.X + 0.4, 0.3, 0.5), CFrame = cf * CFrame.new(0, -size.Y / 2 - 0.15, 0), Color = accent, Material = Enum.Material.Neon }, m)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.TextWrapped = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(240, 240, 238)
		label.AutoLocalize = false -- the LocalizationController sets the text
		label.Text = ""
		label:SetAttribute("TextKey", key)
		for name, value in (params or {}) :: { [string]: string } do
			label:SetAttribute("Param_" .. name, value)
		end
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.05, 0)
		padding.PaddingRight = UDim.new(0.05, 0)
		padding.PaddingTop = UDim.new(0.1, 0)
		padding.PaddingBottom = UDim.new(0.1, 0)
		padding.Parent = label
		label.Parent = gui
		CollectionService:AddTag(label, "AH_LocalizedText")
	end
	return m
end

-- Large ring portal. `active` portals glow violet; dormant ones are gray.
function Kit.portal(cf: CFrame, active: boolean, parent: Instance?): Model
	local m = Kit.model("Portal", parent)
	local radius, segments = 9, 20
	local frameColor = if active then P.safe else P.metal
	for i = 0, segments - 1 do
		local a = (i / segments) * math.pi * 2
		local pos = cf * CFrame.new(math.cos(a) * radius, radius + 1 + math.sin(a) * radius, 0)
		-- rotate each segment so its long side follows the ring
		Kit.part({
			Name = "Ring", Size = Vector3.new(3.2, 1.6, 2), CFrame = pos * CFrame.Angles(0, 0, a + math.pi / 2),
			Color = frameColor, Material = Enum.Material.Metal,
		}, m)
	end
	Kit.part({ Name = "Base", Size = Vector3.new(radius * 2 + 6, 1, 8), CFrame = cf * CFrame.new(0, 0.5, 0), Color = P.stoneDark, Material = Enum.Material.Slate }, m)
	local surface = Kit.part({
		Name = "Surface", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, radius * 2 - 1, radius * 2 - 1),
		CFrame = cf * CFrame.new(0, radius + 1, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = if active then P.anomaly else Color3.fromRGB(60, 62, 68),
		Material = if active then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		Transparency = if active then 0.35 else 0.1, CanCollide = false,
	}, m)
	if active then
		local light = Instance.new("PointLight")
		light.Range = 24
		light.Brightness = 1.5
		light.Color = P.anomaly
		light.Shadows = false
		light.Parent = surface
	end
	m.PrimaryPart = surface
	return m
end

-- Circular pad (arrival / extraction / base marker).
function Kit.pad(cf: CFrame, radius: number, color: Color3, parent: Instance?): Part
	return Kit.part({
		Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, radius * 2, radius * 2),
		CFrame = cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Neon,
		Transparency = 0.35, CanCollide = false,
	}, parent)
end

-- Base pedestal (displays a creature from M2 on).
function Kit.pedestal(cf: CFrame, parent: Instance?): Model
	local m = Kit.model("Pedestal", parent)
	Kit.part({ Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 4, 4), CFrame = cf * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = P.stoneDark, Material = Enum.Material.Slate }, m)
	Kit.part({ Name = "Top", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4.4, 4.4), CFrame = cf * CFrame.new(0, 2.55, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = P.safe, Material = Enum.Material.Metal }, m)
	return m
end

return Kit
