-- Robot AI. Ground robots walk with a Humanoid (smooth, replicated physics),
-- drones fly with AlignPosition. Every robot: patrol -> hear/see a raider ->
-- chase & attack -> search the last known position -> patrol again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local RobotDefs = require(Shared:WaitForChild("Robots"))

local Robots = {}
local S

local rng = Random.new()
local robots = {} -- [id] = robot
local nextId = 0
local folder
local projectiles = {}
local mapState = {} -- [mapId] = { lastDeath = 0, bossReadyAt = 0, emptySince = 0 }

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function raidersIn(mapId: string)
	local list = {}
	for _, player in Players:GetPlayers() do
		if S.Raid.IsInRaid(player) and player:GetAttribute("MapId") == mapId then
			local root = S.GetRoot(player)
			if root then
				table.insert(list, { player = player, root = root })
			end
		end
	end
	return list
end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasLineOfSight(from: Vector3, targetChar: Model, toPos: Vector3): boolean
	losParams.FilterDescendantsInstances = { folder, S.World.dynamic, targetChar }
	local dir = toPos - from
	return workspace:Raycast(from, dir, losParams) == nil
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function visual(model: Model, root: BasePart, props)
	local p = Instance.new("Part")
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = model
	weld(root, p)
	return p
end

---------------------------------------------------------------------------
-- Building robot models. A custom model in GameAssets/Robots/<Type> replaces
-- the built-in look. Only visible parts can be hit (the root is invisible
-- and not hittable), so hitboxes match what you see.
---------------------------------------------------------------------------
local function glow(part: BasePart, color: Color3, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 2
	light.Parent = part
end

local function ellipsoid(model, root, name, size: Vector3, cf: CFrame, color: Color3, material)
	-- a block with a sphere mesh: looks round, hit box matches the shape's bounds
	local p = visual(model, root, {
		Name = name, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.Metal,
	})
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function cylinder(model, root, name, length: number, radius: number, from: Vector3, to: Vector3, color: Color3, material)
	local mid = (from + to) / 2
	return visual(model, root, {
		Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, radius * 2, radius * 2),
		CFrame = CFrame.lookAt(mid, to) * CFrame.Angles(0, math.rad(90), 0), Color = color, Material = material or Enum.Material.Metal,
	})
end

-- Two-segment leg from a hip point out to a foot on the ground.
local function leg(model, root, hip: Vector3, foot: Vector3, thickness: number, color: Color3)
	local knee = (hip + foot) / 2 + Vector3.new(0, (hip - foot).Magnitude * 0.45, 0) + (foot - hip) * Vector3.new(0.25, 0, 0.25)
	cylinder(model, root, "Leg", (knee - hip).Magnitude, thickness, hip, knee, color)
	cylinder(model, root, "Leg", (foot - knee).Magnitude, thickness * 0.8, knee, foot, color:Lerp(Color3.new(0, 0, 0), 0.25))
	visual(model, root, {
		Name = "Joint", Shape = Enum.PartType.Ball, Size = Vector3.one * thickness * 2.6, CFrame = CFrame.new(knee),
		Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal,
	})
end

local ARMOR = Color3.fromRGB(200, 195, 185)

local function decorate(typeName: string, def, model: Model, root: BasePart)
	local cf = root.CFrame
	local size = def.size
	local dark = def.color:Lerp(Color3.new(0, 0, 0), 0.35)
	if typeName == "Crawler" then
		ellipsoid(model, root, "Shell", Vector3.new(size.X, size.Y, size.Z * 1.2), cf, def.color)
		ellipsoid(model, root, "ShellPlate", Vector3.new(size.X * 0.8, size.Y * 0.5, size.Z * 0.9), cf * CFrame.new(0, size.Y * 0.35, 0.1), ARMOR, Enum.Material.SmoothPlastic)
		for i = -1, 1 do
			local eye = visual(model, root, {
				Name = if i == 0 then "Eye" else "EyeSmall", Shape = Enum.PartType.Ball, Size = Vector3.one * (if i == 0 then 0.7 else 0.4),
				CFrame = cf * CFrame.new(i * 0.55, 0.1, -size.Z * 0.62), Color = def.eye, Material = Enum.Material.Neon,
			})
			if i == 0 then
				glow(eye, def.eye, 10)
			end
		end
		for side = -1, 1, 2 do
			for j = -1, 1 do
				local hip = (cf * CFrame.new(side * size.X * 0.4, 0, j * size.Z * 0.35)).Position
				local foot = (cf * CFrame.new(side * size.X * 1.1, -(def.hipHeight + size.Y / 2), j * size.Z * 0.55)).Position
				leg(model, root, hip, foot, 0.18, dark)
			end
		end
	elseif typeName == "Buzzer" then
		visual(model, root, {
			Name = "Hull", Shape = Enum.PartType.Cylinder, Size = Vector3.new(size.Y, size.X, size.Z),
			CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = def.color, Material = Enum.Material.Metal,
		})
		ellipsoid(model, root, "Dome", Vector3.new(size.X * 0.6, size.Y * 1.2, size.Z * 0.6), cf * CFrame.new(0, size.Y * 0.4, 0), ARMOR, Enum.Material.SmoothPlastic)
		for i = 1, 4 do
			local a = (i / 4) * math.pi * 2 + math.pi / 4
			local tip = cf * CFrame.new(math.cos(a) * size.X * 0.95, 0.2, math.sin(a) * size.Z * 0.95)
			cylinder(model, root, "Arm", size.X * 0.6, 0.18, (cf * CFrame.new(math.cos(a) * size.X * 0.35, 0.1, math.sin(a) * size.Z * 0.35)).Position, tip.Position, dark)
			visual(model, root, {
				Name = "Rotor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 2.6, 2.6),
				CFrame = tip * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(30, 30, 35),
				Material = Enum.Material.Glass, Transparency = 0.5,
			})
			local thruster = visual(model, root, {
				Name = "Thruster", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, CFrame = tip * CFrame.new(0, -0.3, 0),
				Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Neon,
			})
			if i == 1 then
				glow(thruster, Color3.fromRGB(120, 200, 255), 8)
			end
		end
		cylinder(model, root, "Gun", 1.6, 0.18, (cf * CFrame.new(0, -0.5, -0.4)).Position, (cf * CFrame.new(0, -0.6, -2)).Position, Color3.fromRGB(30, 30, 30))
		local eye = visual(model, root, {
			Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = cf * CFrame.new(0, -0.1, -size.Z * 0.5),
			Color = def.eye, Material = Enum.Material.Neon,
		})
		glow(eye, def.eye, 14)
	elseif typeName == "Watcher" then
		ellipsoid(model, root, "Body", size, cf, ARMOR, Enum.Material.SmoothPlastic)
		visual(model, root, {
			Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, size.X * 1.6, size.X * 1.6),
			CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal,
		})
		local eye = visual(model, root, {
			Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.3, CFrame = cf * CFrame.new(0, 0, -size.Z * 0.42),
			Color = def.eye, Material = Enum.Material.Neon,
		})
		glow(eye, def.eye, 18)
		visual(model, root, {
			Name = "Siren", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = cf * CFrame.new(0, size.Y * 0.55, 0),
			Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon,
		})
		for _, x in { -1, 1 } do
			cylinder(model, root, "Antenna", 1.6, 0.06, (cf * CFrame.new(x * 0.6, size.Y * 0.4, 0)).Position, (cf * CFrame.new(x * 0.9, size.Y * 0.4 + 1.5, 0.3)).Position, dark)
		end
	elseif typeName == "Sentinel" or typeName == "Colossus" then
		local boss = typeName == "Colossus"
		visual(model, root, {
			Name = "Torso", Size = size * Vector3.new(1, 0.7, 1.1), CFrame = cf, Color = def.color, Material = Enum.Material.Metal,
		})
		visual(model, root, {
			Name = "Armor", Size = size * Vector3.new(1.08, 0.25, 0.9), CFrame = cf * CFrame.new(0, size.Y * 0.42, -size.Z * 0.05),
			Color = ARMOR, Material = Enum.Material.SmoothPlastic,
		})
		local head = visual(model, root, {
			Name = "Head", Size = size * Vector3.new(0.5, 0.35, 0.45), CFrame = cf * CFrame.new(0, size.Y * 0.2, -size.Z * 0.62),
			Color = dark, Material = Enum.Material.Metal,
		})
		local eye = visual(model, root, {
			Name = "Eye", Size = Vector3.new(size.X * 0.4, size.Y * 0.08, 0.3), CFrame = head.CFrame * CFrame.new(0, 0, -size.Z * 0.23),
			Color = def.eye, Material = Enum.Material.Neon,
		})
		glow(eye, def.eye, if boss then 40 else 18)
		for _, x in { -1, 1 } do
			cylinder(model, root, "Barrel", size.Z * 0.5, size.X * 0.05, (head.CFrame * CFrame.new(x * size.X * 0.15, -size.Y * 0.12, 0)).Position,
				(head.CFrame * CFrame.new(x * size.X * 0.15, -size.Y * 0.12, -size.Z * 0.5)).Position, Color3.fromRGB(30, 30, 30))
		end
		for sx = -1, 1, 2 do
			for sz = -1, 1, 2 do
				local hip = (cf * CFrame.new(sx * size.X * 0.45, -size.Y * 0.2, sz * size.Z * 0.4)).Position
				local foot = (cf * CFrame.new(sx * size.X * 0.85, -(def.hipHeight + size.Y / 2), sz * size.Z * 0.75)).Position
				leg(model, root, hip, foot, if boss then 0.9 else 0.4, dark)
				visual(model, root, {
					Name = "Foot", Size = Vector3.new(1, 0.4, 1) * (if boss then 3 else 1.4), CFrame = CFrame.new(foot),
					Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal,
				})
			end
		end
		local core = visual(model, root, {
			Name = "WeakPoint", Shape = Enum.PartType.Ball, Size = Vector3.one * math.max(1.4, size.X * 0.22),
			CFrame = cf * CFrame.new(0, size.Y * 0.2, size.Z * 0.58), Color = Color3.fromRGB(255, 140, 30), Material = Enum.Material.Neon,
		})
		glow(core, Color3.fromRGB(255, 140, 30), if boss then 24 else 10)
		if boss then
			for _, x in { -1, 1 } do
				local pod = visual(model, root, {
					Name = "RocketPod", Size = Vector3.new(3, 3.4, 5), CFrame = cf * CFrame.new(x * (size.X / 2 + 1.8), size.Y * 0.35, 0),
					Color = Color3.fromRGB(90, 40, 30), Material = Enum.Material.CorrodedMetal,
				})
				for r = -1, 1, 2 do
					for c = -1, 1, 2 do
						visual(model, root, {
							Name = "Tube", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 1, 1),
							CFrame = pod.CFrame * CFrame.new(c * 0.7, r * 0.8, -2.55) * CFrame.Angles(0, math.rad(90), 0),
							Color = Color3.fromRGB(255, 90, 40), Material = Enum.Material.Neon,
						})
					end
				end
			end
		end
	end
end

-- Puts a custom model from GameAssets/Robots on the root. Returns true if used.
local function useCustomModel(typeName: string, def, model: Model, root: BasePart): boolean
	local custom = S.Assets.Get("Robots", typeName)
	if not custom then
		return false
	end
	if not custom:IsA("Model") then
		custom:Destroy()
		return false
	end
	S.Assets.Fit(custom, math.max(def.size.X, def.size.Z) * 1.4, root.CFrame)
	for _, d in custom:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
			weld(root, d)
		end
	end
	custom.Name = "Visual"
	custom.Parent = model
	if not custom:FindFirstChild("Eye", true) then
		visual(model, root, { Name = "Eye", Size = Vector3.one * 0.2, CFrame = root.CFrame * CFrame.new(0, 0, -def.size.Z / 2), Transparency = 1 })
	end
	return true
end

local function buildGround(typeName: string, def, position: Vector3)
	local model = Instance.new("Model")
	model.Name = def.name
	local size = def.size
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = size
	root.Transparency = 1
	root.CanQuery = false -- only visible parts count as hits
	root.CFrame = CFrame.new(position + Vector3.new(0, def.hipHeight + size.Y / 2 + 0.5, 0))
	root.Parent = model
	model.PrimaryPart = root
	if not useCustomModel(typeName, def, model, root) then
		decorate(typeName, def, model, root)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = def.hipHeight
	humanoid.WalkSpeed = def.speed
	humanoid.MaxHealth = 1e6
	humanoid.Health = 1e6
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid.Parent = model
	return model, root, humanoid
end

local function buildAir(typeName: string, def, position: Vector3)
	local model = Instance.new("Model")
	model.Name = def.name
	local size = def.size
	local root = Instance.new("Part")
	root.Name = "Core"
	root.Size = size
	root.Transparency = 1
	root.CanQuery = false
	root.CFrame = CFrame.new(position + Vector3.new(0, def.hoverHeight, 0))
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root
	if not useCustomModel(typeName, def, model, root) then
		decorate(typeName, def, model, root)
	end

	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxForce = 1e6
	align.MaxVelocity = def.speed
	align.Responsiveness = 12
	align.Position = root.Position
	align.Parent = root
	local orient = Instance.new("AlignOrientation")
	orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	orient.Attachment0 = attachment
	orient.MaxTorque = 1e6
	orient.Responsiveness = 15
	orient.CFrame = root.CFrame
	orient.Parent = root
	return model, root, nil, align, orient
end

local function healthBar(robot)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.fromOffset(if robot.def.boss then 220 else 90, if robot.def.boss then 34 else 22)
	gui.StudsOffset = Vector3.new(0, robot.def.size.Y / 2 + 2, 0)
	gui.MaxDistance = if robot.def.boss then 300 else 90
	gui.AlwaysOnTop = robot.def.boss == true
	gui.Parent = robot.root
	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.5)
	name.BackgroundTransparency = 1
	name.Text = robot.def.name
	name.TextScaled = true
	name.Font = Enum.Font.GothamBlack
	name.TextColor3 = if robot.def.boss then Color3.fromRGB(255, 80, 60) else Color3.fromRGB(255, 220, 200)
	name.TextStrokeTransparency = 0.3
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0, 0.6)
	back.Size = UDim2.fromScale(1, 0.3)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 70, 50)
	fill.BorderSizePixel = 0
	fill.Parent = back
	robot.healthFill = fill
end

function Robots.Spawn(typeName: string, mapId: string, position: Vector3)
	local def = RobotDefs.Defs[typeName]
	if not def then
		return nil
	end
	local model, root, humanoid, align, orient
	if def.kind == "air" then
		model, root, humanoid, align, orient = buildAir(typeName, def, position)
	else
		model, root, humanoid = buildGround(typeName, def, position)
	end
	nextId += 1
	local robot = {
		id = nextId, typeName = typeName, def = def, mapId = mapId, model = model, root = root,
		humanoid = humanoid, align = align, orient = orient, health = def.health, home = position,
		state = "Patrol", target = nil, lastSeen = nil, lastSeenAt = 0, nextAttack = os.clock() + 1,
		nextWander = 0, investigate = nil, attacking = false, path = nil, nextPath = 0, orbit = rng:NextNumber(0, math.pi * 2),
	}
	model:SetAttribute("RobotId", robot.id)
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	healthBar(robot)
	robots[robot.id] = robot
	return robot
end

function Robots.FromPart(part: Instance)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local id = model:GetAttribute("RobotId")
		if id then
			return robots[id]
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

---------------------------------------------------------------------------
-- Damage & death
---------------------------------------------------------------------------
local function die(robot, killer)
	robots[robot.id] = nil
	robot.dead = true
	local pos = robot.root.Position
	S.Remotes.Effect:FireAllClients("Explosion", pos, if robot.def.boss then 3 else 1)
	robot.model:Destroy()

	local drops = {}
	for _, d in robot.def.drops do
		if rng:NextNumber() * 100 < d[2] then
			table.insert(drops, { id = d[1], count = rng:NextInteger(d[3], d[4]) })
		end
	end
	local groundPos = Vector3.new(pos.X, robot.home.Y, pos.Z)
	S.Loot.SpawnTemporary(CFrame.new(groundPos), "Wreck", drops, robot.mapId, robot.def.name .. " Wreck")

	local ms = mapState[robot.mapId]
	if ms then
		ms.lastDeath = os.clock()
		if robot.def.boss then
			ms.bossReadyAt = os.clock() + Config.BossRespawn
			S.Notify(nil, "💥 The COLOSSUS has fallen!" .. (if typeof(killer) == "Instance" then " (" .. killer.DisplayName .. ")" else ""), "Gold", true)
		end
	end
	if typeof(killer) == "Instance" then
		S.Raid.OnRobotKilled(killer, robot.typeName)
	end
end

-- Returns killed, damageDealt
function Robots.Damage(robot, amount: number, attacker, weak: boolean)
	if robot.dead then
		return false, 0
	end
	if weak and robot.def.weakPoint then
		amount *= robot.def.weakPoint
	end
	robot.health -= amount
	if robot.healthFill then
		robot.healthFill.Size = UDim2.fromScale(math.clamp(robot.health / robot.def.health, 0, 1), 1)
	end
	if typeof(attacker) == "Instance" and robot.target == nil then
		robot.target = attacker
		robot.state = "Chase"
		robot.lastSeenAt = os.clock()
		local root = S.GetRoot(attacker)
		robot.lastSeen = root and root.Position
	end
	if robot.health <= 0 then
		die(robot, attacker)
		return true, amount
	end
	return false, amount
end

-- Gunshots and extraction lifts attract robots.
function Robots.Noise(mapId: string, position: Vector3, radius: number, source: Player?)
	for _, robot in robots do
		if robot.mapId == mapId and not robot.target and (robot.root.Position - position).Magnitude <= radius then
			robot.investigate = position
			robot.state = "Investigate"
			robot.lastSeenAt = os.clock()
			robot.path = nil
		end
	end
end

---------------------------------------------------------------------------
-- Projectiles (Sentinel bolts, Colossus rockets)
---------------------------------------------------------------------------
local projParams = RaycastParams.new()
projParams.FilterType = Enum.RaycastFilterType.Exclude

local function explode(position: Vector3, radius: number, damage: number, mapId: string, owner)
	S.Remotes.Effect:FireAllClients("Explosion", position, 1.5)
	for _, r in raidersIn(mapId) do
		local dist = (r.root.Position - position).Magnitude
		if dist <= radius then
			S.Combat.DamagePlayer(r.player, damage * (1 - dist / (radius * 1.5)), owner)
		end
	end
end

local function fireProjectile(robot, from: Vector3, to: Vector3, speed: number, damage: number, blast: number?)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * (if blast then 1.6 else 1)
	p.Color = if blast then Color3.fromRGB(255, 120, 40) else robot.def.eye
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CFrame = CFrame.new(from)
	p.Parent = S.World.dynamic
	local dir = (to - from)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
	table.insert(projectiles, {
		part = p, pos = from, velocity = dir * speed, damage = damage, blast = blast,
		mapId = robot.mapId, owner = robot, expires = os.clock() + 4,
	})
end

local function stepProjectiles(dt: number)
	projParams.FilterDescendantsInstances = { folder, S.World.dynamic }
	for i = #projectiles, 1, -1 do
		local proj = projectiles[i]
		local nextPos = proj.pos + proj.velocity * dt
		local result = workspace:Raycast(proj.pos, nextPos - proj.pos, projParams)
		local done = os.clock() > proj.expires
		if result then
			done = true
			if proj.blast then
				explode(result.Position, proj.blast, proj.damage, proj.mapId, proj.owner)
			else
				local model = result.Instance:FindFirstAncestorOfClass("Model")
				local victim = model and Players:GetPlayerFromCharacter(model)
				if victim then
					S.Combat.DamagePlayer(victim, proj.damage, proj.owner)
				end
			end
		end
		if done then
			proj.part:Destroy()
			table.remove(projectiles, i)
		else
			proj.pos = nextPos
			proj.part.CFrame = CFrame.new(nextPos)
		end
	end
end

---------------------------------------------------------------------------
-- Attacks
---------------------------------------------------------------------------
local function eyePosition(robot): Vector3
	local eye = robot.model:FindFirstChild("Eye")
	return if eye then eye.Position else robot.root.Position
end

local function telegraphBeam(robot, targetRoot: BasePart, seconds: number)
	local eye = robot.model:FindFirstChild("Eye")
	if not eye then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = eye
	local a1 = Instance.new("Attachment")
	a1.Parent = targetRoot
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.15
	beam.Width1 = 0.15
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Color = ColorSequence.new(robot.def.eye)
	beam.Parent = eye
	Debris:AddItem(beam, seconds)
	Debris:AddItem(a0, seconds)
	Debris:AddItem(a1, seconds)
end

local function attack(robot, target: Player, targetRoot: BasePart)
	local def = robot.def
	robot.nextAttack = os.clock() + def.attackCooldown
	if def.attack == "melee" then
		S.Combat.DamagePlayer(target, def.damage, robot)
		if robot.humanoid then
			robot.humanoid.Jump = true
		end
		return
	end
	robot.attacking = true
	task.spawn(function()
		if def.attack == "laser" then
			telegraphBeam(robot, targetRoot, def.telegraph)
			task.wait(def.telegraph)
			for _ = 1, def.burst do
				if robot.dead or not targetRoot.Parent then
					break
				end
				local from = eyePosition(robot)
				local aim = targetRoot.Position + Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1, 1.5), rng:NextNumber(-1.5, 1.5))
				losParams.FilterDescendantsInstances = { folder, S.World.dynamic }
				local result = workspace:Raycast(from, (aim - from).Unit * def.attackRange * 1.2, losParams)
				local to = if result then result.Position else aim
				S.Remotes.Effect:FireAllClients("Laser", from, to)
				if result then
					local model = result.Instance:FindFirstAncestorOfClass("Model")
					local victim = model and Players:GetPlayerFromCharacter(model)
					if victim then
						S.Combat.DamagePlayer(victim, def.damage, robot)
					end
				end
				task.wait(0.12)
			end
		elseif def.attack == "bolt" then
			telegraphBeam(robot, targetRoot, def.telegraph)
			task.wait(def.telegraph)
			if not robot.dead and targetRoot.Parent then
				S.Remotes.Effect:FireAllClients("Sound", "Bolt", eyePosition(robot))
				local lead = targetRoot.AssemblyLinearVelocity * 0.3
				fireProjectile(robot, eyePosition(robot), targetRoot.Position + lead, def.boltSpeed, def.damage)
			end
		elseif def.attack == "rockets" then
			S.Notify(target, "⚠️ COLOSSUS ROCKETS INCOMING!", "Red")
			task.wait(def.telegraph)
			for _ = 1, def.rockets do
				if robot.dead or not targetRoot.Parent then
					break
				end
				local spot = targetRoot.Position + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
				fireProjectile(robot, robot.root.Position + Vector3.new(0, robot.def.size.Y, 0), spot, def.boltSpeed, def.damage, def.blastRadius)
				task.wait(0.25)
			end
		elseif def.attack == "scout" then
			S.Notify(target, "🚨 A Watcher spotted you - reinforcements incoming!", "Red", true)
			S.Remotes.Effect:FireAllClients("Sound", "Spotted", robot.root.Position)
			local siren = robot.model:FindFirstChild("Siren")
			if siren then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 40, 40)
				light.Range = 40
				light.Brightness = 4
				light.Parent = siren
				Debris:AddItem(light, def.telegraph + 2)
			end
			task.wait(def.telegraph)
			if not robot.dead then
				-- alert everything nearby and call a few crawlers
				for _, other in robots do
					if other.mapId == robot.mapId and other ~= robot and (other.root.Position - robot.root.Position).Magnitude < def.callRadius then
						other.target = target
						other.state = "Chase"
						other.lastSeen = targetRoot.Position
						other.lastSeenAt = os.clock()
					end
				end
				for _ = 1, def.callSpawn do
					local offset = Vector3.new(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25))
					local ground = Vector3.new(robot.root.Position.X, robot.home.Y, robot.root.Position.Z) + offset
					local crawler = Robots.Spawn("Crawler", robot.mapId, ground)
					if crawler then
						crawler.target = target
						crawler.state = "Chase"
						crawler.lastSeenAt = os.clock()
						crawler.lastSeen = targetRoot.Position
					end
				end
			end
		end
		robot.attacking = false
	end)
end

---------------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------------
local function moveTo(robot, position: Vector3)
	if robot.align then
		local hover = position + Vector3.new(0, robot.def.hoverHeight, 0)
		robot.align.Position = hover
		local flat = Vector3.new(position.X, robot.root.Position.Y, position.Z)
		if (flat - robot.root.Position).Magnitude > 1 then
			robot.orient.CFrame = CFrame.lookAt(robot.root.Position, flat)
		end
	elseif robot.humanoid then
		robot.humanoid:MoveTo(position)
	end
end

local function face(robot, position: Vector3)
	if robot.align then
		robot.orient.CFrame = CFrame.lookAt(robot.root.Position, position)
	end
end

-- Ground robots use pathfinding when they can't walk straight at the goal.
local function pathTo(robot, goal: Vector3)
	if robot.align or os.clock() < robot.nextPath then
		return
	end
	robot.nextPath = os.clock() + 2
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = math.max(2, robot.def.size.X / 2),
			AgentHeight = robot.def.hipHeight + robot.def.size.Y,
			AgentCanJump = true,
		})
		local ok = pcall(function()
			path:ComputeAsync(robot.root.Position, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success and not robot.dead then
			robot.path = path:GetWaypoints()
			robot.pathIndex = 2
		end
	end)
end

local function followPath(robot): boolean
	if not robot.path then
		return false
	end
	local wp = robot.path[robot.pathIndex]
	if not wp then
		robot.path = nil
		return false
	end
	if (Vector3.new(wp.Position.X, 0, wp.Position.Z) - Vector3.new(robot.root.Position.X, 0, robot.root.Position.Z)).Magnitude < 4 then
		robot.pathIndex += 1
		wp = robot.path[robot.pathIndex]
		if not wp then
			robot.path = nil
			return false
		end
	end
	if wp.Action == Enum.PathWaypointAction.Jump then
		robot.humanoid.Jump = true
	end
	robot.humanoid:MoveTo(wp.Position)
	return true
end

---------------------------------------------------------------------------
-- Brain
---------------------------------------------------------------------------
local function think(robot)
	local def = robot.def
	local pos = robot.root.Position
	local raiders = raidersIn(robot.mapId)

	-- Validate current target
	local target, targetRoot = robot.target, nil
	if target then
		targetRoot = S.GetRoot(target)
		if not targetRoot or not S.Raid.IsInRaid(target) or target:GetAttribute("MapId") ~= robot.mapId then
			robot.target, target = nil, nil
			robot.state = "Patrol"
		end
	end

	-- Look for raiders
	local visibleTarget, visibleRoot, bestDist = nil, nil, def.sight
	for _, r in raiders do
		local dist = (r.root.Position - pos).Magnitude
		if dist < bestDist and hasLineOfSight(eyePosition(robot), r.player.Character, r.root.Position) then
			visibleTarget, visibleRoot, bestDist = r.player, r.root, dist
		end
	end
	if visibleTarget and (not target or visibleTarget == target or bestDist < 20) then
		target, targetRoot = visibleTarget, visibleRoot
		robot.target = target
		robot.state = "Chase"
		robot.lastSeen = targetRoot.Position
		robot.lastSeenAt = os.clock()
		robot.path = nil
	end

	if robot.state == "Chase" and target and targetRoot then
		local dist = (targetRoot.Position - pos).Magnitude
		local canSee = visibleTarget == target
		if canSee then
			robot.lastSeen = targetRoot.Position
			robot.lastSeenAt = os.clock()
		end
		if canSee and dist <= def.attackRange and os.clock() >= robot.nextAttack and not robot.attacking then
			attack(robot, target, targetRoot)
		end
		if def.attack == "melee" then
			if canSee then
				moveTo(robot, targetRoot.Position)
			elseif not followPath(robot) then
				pathTo(robot, robot.lastSeen)
				moveTo(robot, robot.lastSeen)
			end
		elseif robot.align then
			-- drones circle the target at a distance
			robot.orbit += 0.25
			local radius = math.min(def.attackRange * 0.5, 30)
			local goal = targetRoot.Position + Vector3.new(math.cos(robot.orbit) * radius, 0, math.sin(robot.orbit) * radius)
			moveTo(robot, Vector3.new(goal.X, robot.home.Y, goal.Z))
			face(robot, targetRoot.Position)
		else
			-- ranged walkers keep their distance
			local wanted = def.attackRange * 0.55
			if not canSee or dist > wanted then
				if canSee then
					moveTo(robot, targetRoot.Position)
				elseif not followPath(robot) then
					pathTo(robot, robot.lastSeen)
					moveTo(robot, robot.lastSeen)
				end
			else
				robot.humanoid:MoveTo(pos)
			end
		end
		if not canSee and os.clock() - robot.lastSeenAt > 4 then
			robot.state = "Search"
		end
	elseif robot.state == "Search" or robot.state == "Investigate" then
		local goal = if robot.state == "Search" then robot.lastSeen else robot.investigate
		if not goal then
			robot.state = "Patrol"
		else
			local flatDist = (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
			if flatDist < 6 or os.clock() - robot.lastSeenAt > 14 then
				robot.state = "Patrol"
				robot.target = nil
				robot.investigate = nil
			elseif not followPath(robot) then
				pathTo(robot, goal)
				moveTo(robot, goal)
			end
		end
	else
		robot.state = "Patrol"
		if os.clock() >= robot.nextWander then
			robot.nextWander = os.clock() + rng:NextNumber(4, 8)
			local goal = robot.home + Vector3.new(rng:NextNumber(-35, 35), 0, rng:NextNumber(-35, 35))
			moveTo(robot, goal)
		end
	end
end

---------------------------------------------------------------------------
-- Population per map
---------------------------------------------------------------------------
local function countIn(mapId: string): number
	local n = 0
	for _, robot in robots do
		if robot.mapId == mapId and not robot.def.boss then
			n += 1
		end
	end
	return n
end

local function pickType(map): string
	local weights = map.def.robotWeights or RobotDefs.SpawnWeights
	local total = 0
	for _, w in weights do
		total += w
	end
	local pick = rng:NextNumber() * total
	for name, w in weights do
		pick -= w
		if pick <= 0 then
			return name
		end
	end
	return "Crawler"
end

local function spawnPointAwayFrom(map, raiders)
	for _ = 1, 15 do
		local spot = map.robotSpawns[rng:NextInteger(1, #map.robotSpawns)]
		local ok = true
		for _, r in raiders do
			if (r.root.Position - spot).Magnitude < 80 then
				ok = false
				break
			end
		end
		if ok then
			return spot
		end
	end
	return nil
end

local function populate()
	for mapId, map in S.World.maps do
		local ms = mapState[mapId]
		local raiders = raidersIn(mapId)
		local raiderCount = 0
		for _, player in Players:GetPlayers() do
			if S.Raid.IsInRaid(player) and player:GetAttribute("MapId") == mapId then
				raiderCount += 1
			end
		end
		if raiderCount == 0 then
			-- nobody here: clean up after a while to save server performance
			if ms.emptySince == 0 then
				ms.emptySince = os.clock()
			elseif os.clock() - ms.emptySince > 30 then
				for id, robot in robots do
					if robot.mapId == mapId then
						robots[id] = nil
						robot.dead = true
						robot.model:Destroy()
					end
				end
			end
		else
			ms.emptySince = 0
			local wanted = math.min(Config.RobotMax, Config.RobotBase + Config.RobotPerRaider * raiderCount)
			if countIn(mapId) < wanted and os.clock() - ms.lastDeath > Config.RobotRespawnDelay / 4 then
				local spot = spawnPointAwayFrom(map, raiders)
				if spot then
					local typeName = pickType(map)
					local pack = RobotDefs.Defs[typeName].packSize
					for _ = 1, rng:NextInteger(pack[1], pack[2]) do
						Robots.Spawn(typeName, mapId, spot + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)))
					end
				end
			end
			if map.bossSpawn and os.clock() >= ms.bossReadyAt then
				local hasBoss = false
				for _, robot in robots do
					if robot.mapId == mapId and robot.def.boss then
						hasBoss = true
					end
				end
				if not hasBoss then
					Robots.Spawn("Colossus", mapId, map.bossSpawn)
					ms.bossReadyAt = math.huge
					for _, r in raiders do
						S.Notify(r.player, "⚠️ A COLOSSUS is patrolling the crash site...", "Red", true)
					end
				end
			end
		end
	end
end

function Robots.Init(services)
	S = services
end

function Robots.Start()
	folder = Instance.new("Folder")
	folder.Name = "Robots"
	folder.Parent = workspace
	for mapId in S.World.maps do
		mapState[mapId] = { lastDeath = 0, bossReadyAt = 60, emptySince = 0 }
	end

	RunService.Heartbeat:Connect(stepProjectiles)

	-- Think loop: spread robots across frames
	task.spawn(function()
		while true do
			local list = {}
			for _, robot in robots do
				table.insert(list, robot)
			end
			local per = math.max(1, math.ceil(#list / 5))
			for i, robot in list do
				if not robot.dead then
					local ok, err = pcall(think, robot)
					if not ok then
						warn("[Robots] think error:", err)
					end
				end
				if i % per == 0 then
					task.wait(0.05)
				end
			end
			task.wait(0.05)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(2)
			local ok, err = pcall(populate)
			if not ok then
				warn("[Robots] populate error:", err)
			end
		end
	end)
end

return Robots
