--!strict
-- Deterministic world construction (spec 15.1). Everything lives inside one
-- owned folder, workspace.AnomalyHeistWorld. Re-running build() replaces only
-- that folder, so it never duplicates the map or touches other Studio work.
--
-- Edit-time bake (optional): in Studio's command bar run
--   require(game.ServerScriptService.Server.World.WorldBuilder).build()
-- to inspect the geometry without pressing Play. The running game rebuilds
-- the folder on start, so a baked copy is never the source of truth.

local Lighting = game:GetService("Lighting")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local ZoneDefinitions = require(game:GetService("ReplicatedStorage").Shared.Config.ZoneDefinitions)
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)
local Kit = require(script.Parent.Kit)
local ZoneLayouts = require(script.Parent.ZoneLayouts)

local WorldBuilder = {}

WorldBuilder.RootName = "AnomalyHeistWorld"
WorldBuilder.BuildVersion = GameConfig.version

local P = Kit.Palette

export type Plot = Types.PlotInfo & {
	model: Model,
	signFolder: Model,
	marker: BasePart,
}

export type World = {
	root: Folder,
	spawn: SpawnLocation,
	plots: { Plot },
	hubPortals: { [string]: Model }, -- zoneId -> portal model in the hub
	zones: { [string]: ZoneLayouts.ZoneInfo },
}

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(70, 72, 80)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 152, 160)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Haze = 0.6
	atmosphere.Glare = 0
	atmosphere.Color = Color3.fromRGB(200, 214, 230)
	atmosphere.Decay = Color3.fromRGB(110, 130, 160)
	atmosphere.Parent = Lighting
end

-- Plot positions: 8 plots on a ring, offset by 22.5 degrees so the four main
-- axes stay free for the spawn and the portals.
function WorldBuilder.plotLayout(): { Types.PlotInfo }
	local plots = {}
	for i = 1, GameConfig.plotCount do
		local angle = math.rad(22.5 + (i - 1) * (360 / GameConfig.plotCount))
		local center = Vector3.new(math.sin(angle), 0, math.cos(angle)) * GameConfig.hub.plotRingRadius
		table.insert(plots, { index = i, center = center, facing = -center.Unit })
	end
	return plots
end

local function ringPath(parent: Instance, radius: number, width: number)
	local segments = 32
	local length = 2 * math.pi * radius / segments + 1.2
	for i = 0, segments - 1 do
		local a = (i + 0.5) / segments * math.pi * 2
		local pos = Vector3.new(math.sin(a) * radius, 0.05, math.cos(a) * radius)
		Kit.part({
			Name = "RingPath", Size = Vector3.new(width, 0.1, length),
			CFrame = CFrame.lookAt(pos, pos + Vector3.new(math.cos(a), 0, -math.sin(a))),
			Color = P.path, Material = Enum.Material.Pavement, CanCollide = false,
		}, parent)
	end
end

local function buildLandmark(parent: Instance)
	local m = Kit.model("ResearchTower", parent)
	Kit.part({ Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 48, 48), CFrame = CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = P.stoneDark, Material = Enum.Material.Slate, CanCollide = false }, m)
	Kit.part({ Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 18, 18), CFrame = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = P.concrete, Material = Enum.Material.Concrete }, m)
	Kit.part({ Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, 7, 7), CFrame = CFrame.new(0, 14, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = P.white, Material = Enum.Material.SmoothPlastic }, m)
	Kit.part({ Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 7.6, 7.6), CFrame = CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = P.safe, Material = Enum.Material.Metal }, m)
	Kit.part({ Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 12, 12), CFrame = CFrame.new(0, 26, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = P.metal, Material = Enum.Material.Metal }, m)
	local core = Kit.part({ Name = "AnomalyCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 6, CFrame = CFrame.new(0, 31, 0), Color = P.anomaly, Material = Enum.Material.Neon }, m)
	core:SetAttribute("SpinSpeed", 0.6)
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1
	light.Color = P.anomaly
	light.Shadows = false
	light.Parent = core
	-- four support arms holding the core
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local foot = Vector3.new(math.cos(a) * 7, 26, math.sin(a) * 7)
		local top = Vector3.new(math.cos(a) * 3, 33, math.sin(a) * 3)
		Kit.part({ Name = "Arm", Size = Vector3.new(0.8, 0.8, (top - foot).Magnitude), CFrame = CFrame.lookAt((foot + top) / 2, top), Color = P.metalDark, Material = Enum.Material.Metal }, m)
	end
end

local function buildPlot(parent: Instance, info: Types.PlotInfo): Plot
	local size = GameConfig.hub.plotSize
	local m = Kit.model("Plot" .. info.index, parent)
	m:SetAttribute("PlotIndex", info.index)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- the plot's local -Z points toward the hub center (its entrance side)
	local cf = CFrame.lookAt(info.center, info.center + info.facing)
	Kit.part({ Name = "Slab", Size = Vector3.new(size, 1, size), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(214, 218, 212), Material = Enum.Material.Concrete }, m)
	Kit.part({ Name = "Lawn", Size = Vector3.new(size - 6, 0.2, size - 10), CFrame = cf * CFrame.new(0, 1.1, 3), Color = P.grass, Material = Enum.Material.Grass, CanCollide = false }, m)
	-- low back and side walls, open front
	Kit.wall(cf * CFrame.new(0, 1, size / 2 - 0.75), size, 3, P.stoneDark, m)
	Kit.wall(cf * CFrame.new(-size / 2 + 0.75, 1, 4) * CFrame.Angles(0, math.rad(90), 0), size - 8, 3, P.stoneDark, m)
	Kit.wall(cf * CFrame.new(size / 2 - 0.75, 1, 4) * CFrame.Angles(0, math.rad(90), 0), size - 8, 3, P.stoneDark, m)
	-- 3 active pedestal sockets (spec 10.2 starts with 3) and 5 dim locked sockets
	for i = 0, 7 do
		local row = if i < 4 then 0 else 1
		local col = i % 4
		local pos = cf * CFrame.new(-9 + col * 6, 1, 2 + row * 7)
		if i < 3 then
			Kit.pedestal(pos, m)
		else
			Kit.part({ Name = "LockedSocket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4, 4), CFrame = pos * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = P.stoneDark, Material = Enum.Material.Slate, CanCollide = false }, m)
		end
	end
	Kit.machine(cf * CFrame.new(10, 1, 11) * CFrame.Angles(0, math.rad(180), 0), P.safe, false, m)
	local marker: BasePart = Kit.pad(cf * CFrame.new(0, 1, -size / 2 + 4), 3, P.safe, m)
	marker.Name = "EntranceMarker"
	local signFolder = Kit.sign(cf * CFrame.new(0, 6.5, -size / 2 + 1.2), Vector2.new(14, 3), "base.vacant", P.safe, m)
	signFolder.Name = "BaseSign"
	for x = -1, 1, 2 do
		Kit.part({ Name = "SignPost", Size = Vector3.new(0.5, 5, 0.5), CFrame = cf * CFrame.new(x * 6.5, 3.5, -size / 2 + 1.2), Color = P.metalDark, Material = Enum.Material.Metal }, m)
	end
	return {
		index = info.index,
		center = info.center,
		facing = info.facing,
		model = m,
		signFolder = signFolder,
		marker = marker,
	}
end

local function buildHub(root: Folder): (SpawnLocation, { Plot }, { [string]: Model })
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = root
	local half = GameConfig.hub.size / 2
	local width = GameConfig.hub.pathWidth + 2

	-- ground: grass apron + pale stone hub floor
	Kit.floor(CFrame.new(0, -0.2, 0), Vector2.new(GameConfig.hub.size + 96, GameConfig.hub.size + 96), P.grass, Enum.Material.Grass, hub)
	Kit.floor(CFrame.new(0, 0, 0), Vector2.new(GameConfig.hub.size, GameConfig.hub.size), P.stone, Enum.Material.Slate, hub)
	-- outer boundary (invisible) so nobody wanders off the island
	local outer = (GameConfig.hub.size + 96) / 2
	for i = 0, 3 do
		local a = i * math.pi / 2
		Kit.part({
			Name = "Boundary", Size = Vector3.new(GameConfig.hub.size + 96, 60, 2), Transparency = 1,
			CFrame = CFrame.new(math.sin(a) * outer, 30, math.cos(a) * outer) * CFrame.Angles(0, a, 0),
		}, hub)
	end

	buildLandmark(hub)
	ringPath(hub, 70, width)
	-- four spokes from the plaza to the edges
	for i = 0, 3 do
		local a = i * math.pi / 2
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		local from, to = dir * 24, dir * (half - 4)
		Kit.part({
			Name = "Spoke", Size = Vector3.new(width, 0.1, (to - from).Magnitude), CFrame = CFrame.lookAt((from + to) / 2 + Vector3.new(0, 0.05, 0), to + Vector3.new(0, 0.05, 0)),
			Color = P.path, Material = Enum.Material.Pavement, CanCollide = false,
		}, hub)
	end

	-- spawn faces the beginner portal (+Z)
	local spawnPos = GameConfig.hub.spawnOffset
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.lookAt(spawnPos + Vector3.new(0, 0.5, 0), spawnPos + Vector3.new(0, 0.5, 1))
	spawn.Color = P.safe
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = hub
	Kit.sign(CFrame.new(0, 8, -26) * CFrame.Angles(0, math.pi, 0), Vector2.new(20, 4), "sign.welcome", P.safe, hub)
	for x = -1, 1, 2 do
		Kit.part({ Name = "SignPost", Size = Vector3.new(0.6, 6, 0.6), CFrame = CFrame.new(x * 9.5, 3, -26), Color = P.metalDark, Material = Enum.Material.Metal }, hub)
	end

	-- plots
	local plots = {}
	for _, info in WorldBuilder.plotLayout() do
		local plot = buildPlot(hub, info)
		table.insert(plots, plot)
		-- short connector from the ring path to the plot entrance
		local from = info.center.Unit * 77
		local to = info.center.Unit * (GameConfig.hub.plotRingRadius - GameConfig.hub.plotSize / 2)
		Kit.part({
			Name = "Connector", Size = Vector3.new(10, 0.1, (to - from).Magnitude + 1), CFrame = CFrame.lookAt((from + to) / 2 + Vector3.new(0, 0.06, 0), to + Vector3.new(0, 0.06, 0)),
			Color = P.path, Material = Enum.Material.Pavement, CanCollide = false,
		}, hub)
	end

	-- portals on the north, east and west axes
	local portals: { [string]: Model } = {}
	local sides = { north = 0, east = math.pi / 2, west = -math.pi / 2 }
	for id, zone in ZoneDefinitions do
		local a = sides[zone.portalSide]
		local pos = Vector3.new(math.sin(a), 0, math.cos(a)) * (half - 12)
		local cf = CFrame.lookAt(pos, Vector3.zero)
		local portal = Kit.portal(cf, zone.implemented, hub)
		portal.Name = "Portal_" .. id
		portal:SetAttribute("ZoneId", id)
		portals[id] = portal
		Kit.sign(cf * CFrame.new(0, 23, 0), Vector2.new(16, 3), zone.nameKey, if zone.implemented then P.anomaly else P.metal, portal)
		if not zone.implemented then
			Kit.sign(cf * CFrame.new(0, 4, -3), Vector2.new(10, 2), "portal.not_available", P.metal, portal)
		end
	end

	-- social seating (the future trading area is ordinary seating for now)
	for _, a in { 135, 225 } do
		local r = math.rad(a)
		local center = Vector3.new(math.sin(r), 0, math.cos(r)) * 46
		for k = -1, 1 do
			local pos = center + Vector3.new(math.cos(r) * k * 7, 0, -math.sin(r) * k * 7)
			Kit.bench(CFrame.lookAt(pos, Vector3.zero), hub)
		end
		Kit.planter(CFrame.lookAt(center * 1.3, Vector3.zero), Vector2.new(10, 4), hub)
	end
	-- lamps around the ring, trees and planters between plots
	for i = 0, 7 do
		-- lamps sit between the spokes, trees between the plots
		local lampAngle = math.rad(i * 45 + 22.5)
		Kit.lamp(CFrame.new(math.sin(lampAngle) * 58, 0, math.cos(lampAngle) * 58), Color3.fromRGB(255, 236, 200), hub)
		if i % 2 == 1 then
			local a = math.rad(i * 45)
			Kit.tree(CFrame.new(math.sin(a) * 112, 0, math.cos(a) * 112), 1.3, hub)
		end
	end
	for i = 0, 15 do
		local a = math.rad(i * 22.5 + 11.25)
		Kit.tree(CFrame.new(math.sin(a) * 150, 0, math.cos(a) * 150), 1.1 + (i % 3) * 0.2, hub)
	end
	-- small workshop corners inside the ring (away from paths and seating)
	local workshop = Vector3.new(math.sin(math.rad(45)), 0, math.cos(math.rad(45))) * 42
	Kit.machine(CFrame.lookAt(workshop, Vector3.zero), P.safe, false, hub)
	Kit.cable(workshop + Vector3.new(0, 0.2, 0), Vector3.new(4, 0.2, 18), hub)
	local storage = Vector3.new(math.sin(math.rad(315)), 0, math.cos(math.rad(315))) * 42
	Kit.crate(CFrame.new(storage), 3, hub)
	Kit.crate(CFrame.new(storage + Vector3.new(3.5, 0, 1)) * CFrame.Angles(0, 0.4, 0), 2.5, hub)
	Kit.crate(CFrame.new(storage + Vector3.new(1, 3, 0)) * CFrame.Angles(0, 0.2, 0), 2.5, hub)
	return spawn, plots, portals
end

function WorldBuilder.build(): World
	local existing = workspace:FindFirstChild(WorldBuilder.RootName)
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = WorldBuilder.RootName
	root:SetAttribute("BuildVersion", WorldBuilder.BuildVersion)

	setupLighting()
	local spawn, plots, portals = buildHub(root)
	local zones: { [string]: ZoneLayouts.ZoneInfo } = {}
	for id, zone in ZoneDefinitions do
		if zone.implemented then
			zones[id] = ZoneLayouts.build(zone, root)
		end
	end
	root.Parent = workspace
	return { root = root, spawn = spawn, plots = plots, hubPortals = portals, zones = zones }
end

return WorldBuilder
