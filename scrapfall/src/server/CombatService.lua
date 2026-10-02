-- Shooting, reloading, healing and damage. The server is the authority:
-- the client only sends where it is aiming, the server checks fire rate,
-- ammo and line of sight and decides what was hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))

local Combat = {}
local S, Stacks

local rng = Random.new()
local state = {} -- [Player] = { lastShot, reloadingUntil, usingUntil, useToken, lastAttacker, lastAttackerTime }

local function getState(player: Player)
	local st = state[player]
	if not st then
		st = { lastShot = 0, reloadingUntil = 0, usingUntil = 0, useToken = nil, lastAttacker = nil, lastAttackerTime = 0 }
		state[player] = st
	end
	return st
end

local function now()
	return os.clock()
end

---------------------------------------------------------------------------
-- Weapon models (simple part guns welded to the right hand)
---------------------------------------------------------------------------
local function gunPart(model, hand, name, size: Vector3, offset: CFrame, color: Color3, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Metal
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	-- with the arm held out, the hand's -Y axis points forward
	p.CFrame = hand.CFrame * CFrame.Angles(math.rad(-90), 0, 0) * offset
	p.Parent = model
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = p
	w.Parent = p
	return p
end

-- Built-in gun shapes; replaced by GameAssets/Weapons/<ItemId> if present.
local function buildGun(model: Model, hand: BasePart, id: string, def)
	local w = def.weapon
	local length = if w.range > 400 then 4.6 elseif w.pellets > 1 then 3.6 elseif w.auto then 3 else 1.6
	local body = def.color or Color3.fromRGB(80, 80, 80)
	local dark = Color3.fromRGB(28, 28, 32)
	local base = CFrame.new(0, 0.3, -length / 2 + 0.35)
	gunPart(model, hand, "Body", Vector3.new(0.35, 0.55, length), base, body)
	gunPart(model, hand, "Grip", Vector3.new(0.3, 0.7, 0.4), base * CFrame.new(0, -0.5, length / 2 - 0.5) * CFrame.Angles(math.rad(-15), 0, 0), dark)
	if w.mag > 6 then
		gunPart(model, hand, "Mag", Vector3.new(0.25, 0.8, 0.4), base * CFrame.new(0, -0.6, -0.2) * CFrame.Angles(math.rad(10), 0, 0), dark)
	end
	gunPart(model, hand, "Barrel", Vector3.new(length * 0.55, 0.22, 0.22), base * CFrame.new(0, 0.1, -length / 2 - length * 0.2) * CFrame.Angles(0, math.rad(90), 0), dark, nil, Enum.PartType.Cylinder)
	if w.range > 250 then
		gunPart(model, hand, "Scope", Vector3.new(1.2, 0.3, 0.3), base * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, math.rad(90), 0), dark, nil, Enum.PartType.Cylinder)
		gunPart(model, hand, "Lens", Vector3.new(0.05, 0.26, 0.26), base * CFrame.new(0, 0.45, -0.62) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(80, 180, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	if w.auto or w.range > 250 then
		gunPart(model, hand, "Stock", Vector3.new(0.3, 0.45, 0.9), base * CFrame.new(0, -0.05, length / 2 + 0.4), body:Lerp(dark, 0.4))
	end
	gunPart(model, hand, "Stripe", Vector3.new(0.37, 0.08, length * 0.6), base * CFrame.new(0, 0.1, 0), Color3.fromRGB(255, 150, 40), Enum.Material.Neon)
	gunPart(model, hand, "Muzzle", Vector3.new(0.2, 0.2, 0.2), base * CFrame.new(0, 0.1, -length / 2 - length * 0.5), dark)
end

function Combat.RefreshWeaponModel(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local old = char:FindFirstChild("HeldWeapon")
	if old then
		old:Destroy()
	end
	local inv = S.Inventory.Get(player)
	local weapon = inv and inv.weapons[inv.equipped]
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	if not weapon or not hand then
		return
	end
	local def = Items.Get(weapon.id)
	local custom = S.Assets.Get("Weapons", weapon.id)
	local model
	if custom and custom:IsA("Model") then
		model = custom
		local handle = model:FindFirstChild("Handle", true) or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if handle then
			model.PrimaryPart = handle
			model:PivotTo(hand.CFrame * CFrame.Angles(math.rad(-90), 0, 0))
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = hand
				w.Part1 = d
				w.Parent = d
			end
		end
	else
		model = Instance.new("Model")
		buildGun(model, hand, weapon.id, def)
	end
	model.Name = "HeldWeapon"
	model.Parent = char
end

---------------------------------------------------------------------------
-- Damage
---------------------------------------------------------------------------
-- attacker: Player, robot table or nil. Returns true if it killed.
function Combat.DamagePlayer(target: Player, amount: number, attacker, headshot: boolean?)
	local char = target.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not S.Raid.IsInRaid(target) then
		return false
	end
	if char:FindFirstChildOfClass("ForceField") then
		return false
	end
	if typeof(attacker) == "Instance" then
		if not Config.PvPEnabled or attacker == target then
			return false
		end
		amount *= Config.PvPDamageMultiplier
		if headshot then
			amount *= Config.PlayerHeadshotMultiplier
		end
	end
	local st = getState(target)
	st.lastAttacker = attacker
	st.lastAttackerTime = now()
	-- interrupt healing
	if st.usingUntil > now() then
		st.usingUntil = 0
		st.useToken = nil
		target:SetAttribute("UsingUntil", 0)
	end

	local shield = target:GetAttribute("Shield") or 0
	if shield > 0 then
		local absorbed = math.min(shield, amount)
		shield -= absorbed
		amount -= absorbed
		target:SetAttribute("Shield", shield)
	end
	if amount > 0 then
		humanoid:TakeDamage(amount)
	end
	S.Remotes.Effect:FireClient(target, "Hurt", amount)
	return humanoid.Health <= 0
end

function Combat.GetKiller(player: Player)
	local st = state[player]
	if st and now() - st.lastAttackerTime < 15 then
		return st.lastAttacker
	end
	return nil
end

---------------------------------------------------------------------------
-- Shooting
---------------------------------------------------------------------------
local function rayParams(exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

local function spreadDirection(dir: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return dir
	end
	local cf = CFrame.lookAt(Vector3.zero, dir)
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber())
	local roll = rng:NextNumber() * math.pi * 2
	return (cf * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

local function broadcastTracer(shooter: Player, from: Vector3, to: Vector3, ammo: string?)
	for _, other in Players:GetPlayers() do
		if other ~= shooter and other:GetAttribute("MapId") == shooter:GetAttribute("MapId") then
			S.Remotes.Effect:FireClient(other, "Tracer", from, to, ammo)
		end
	end
end

local function hitSomething(shooter: Player, result: RaycastResult, damage: number)
	local hit = result.Instance
	local model = hit:FindFirstAncestorOfClass("Model")
	-- Robot?
	local robot = S.Robots.FromPart(hit)
	if robot then
		local weak = hit.Name == "WeakPoint"
		local killed, dealt = S.Robots.Damage(robot, damage, shooter, weak)
		S.Remotes.Effect:FireClient(shooter, "Hit", math.floor(dealt), weak, killed)
		return
	end
	-- Player?
	local victim = model and Players:GetPlayerFromCharacter(model)
	if not victim and model then
		local outer = model:FindFirstAncestorOfClass("Model")
		victim = outer and Players:GetPlayerFromCharacter(outer)
	end
	if victim and victim ~= shooter and victim:GetAttribute("MapId") == shooter:GetAttribute("MapId") then
		local headshot = hit.Name == "Head"
		local killed = Combat.DamagePlayer(victim, damage, shooter, headshot)
		S.Remotes.Effect:FireClient(shooter, "Hit", math.floor(damage), headshot, killed)
	end
end

function Combat.Fire(player: Player, origin, direction)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or direction.Magnitude < 0.5 then
		return
	end
	direction = direction.Unit
	local inv = S.Inventory.Get(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not inv or not head or not humanoid or humanoid.Health <= 0 then
		return
	end
	local weapon = inv.weapons[inv.equipped]
	if not weapon then
		return
	end
	local def = Items.Get(weapon.id).weapon
	local st = getState(player)
	local t = now()
	if t - st.lastShot < (60 / def.rpm) * 0.85 or t < st.reloadingUntil or t < st.usingUntil then
		return
	end
	if weapon.mag <= 0 then
		return
	end
	if (origin - head.Position).Magnitude > Config.MaxAimOriginOffset then
		return
	end
	st.lastShot = t
	weapon.mag -= 1
	player:SetAttribute("Mag", weapon.mag)

	-- Shooting removes spawn protection
	local ff = char:FindFirstChildOfClass("ForceField")
	if ff then
		ff:Destroy()
	end

	local exclude = { char, S.World.dynamic }
	local params = rayParams(exclude)
	-- 1) what is the camera looking at?
	local aimResult = workspace:Raycast(origin, direction * def.range, params)
	local aimPoint = if aimResult then aimResult.Position else origin + direction * def.range
	-- 2) shoot from the gun toward that point (so you can't shoot through cover in front of you)
	local muzzleModel = char:FindFirstChild("HeldWeapon")
	local muzzle = muzzleModel and muzzleModel:FindFirstChild("Muzzle")
	local from = if muzzle then muzzle.Position else head.Position
	local baseDir = (aimPoint - from)
	if baseDir.Magnitude < 0.1 then
		baseDir = direction
	end
	baseDir = baseDir.Unit

	for pellet = 1, def.pellets do
		local dir = spreadDirection(baseDir, def.spread)
		local result = workspace:Raycast(from, dir * def.range, params)
		local to = if result then result.Position else from + dir * def.range
		broadcastTracer(player, from, to, if pellet == 1 then def.ammo else nil)
		if result then
			hitSomething(player, result, def.damage)
		end
	end
	S.Robots.Noise(player:GetAttribute("MapId"), from, Config.GunNoiseRadius, player)
end

function Combat.Reload(player: Player)
	local inv = S.Inventory.Get(player)
	local weapon = inv and inv.weapons[inv.equipped]
	if not weapon then
		return
	end
	local def = Items.Get(weapon.id).weapon
	local st = getState(player)
	if now() < st.reloadingUntil or weapon.mag >= def.mag then
		return
	end
	if Stacks.Count(inv.backpack, def.ammo) <= 0 then
		S.Notify(player, "No " .. Items.Get(def.ammo).name .. "!", "Red")
		return
	end
	st.reloadingUntil = now() + def.reload
	player:SetAttribute("ReloadingUntil", workspace:GetServerTimeNow() + def.reload)
	local equippedSlot = inv.equipped
	task.delay(def.reload, function()
		if S.Inventory.Get(player) ~= inv or inv.equipped ~= equippedSlot or inv.weapons[equippedSlot] ~= weapon then
			return
		end
		local need = def.mag - weapon.mag
		local got = Stacks.Remove(inv.backpack, def.ammo, need)
		weapon.mag += got
		S.Inventory.Sync(player)
	end)
end

function Combat.Equip(player: Player, slot)
	local inv = S.Inventory.Get(player)
	if not inv or type(slot) ~= "number" or not inv.weapons[slot] or inv.equipped == slot then
		return
	end
	inv.equipped = slot
	local st = getState(player)
	st.reloadingUntil = 0
	player:SetAttribute("ReloadingUntil", 0)
	S.Inventory.Sync(player)
end

-- Use a med from the backpack (takes time, interrupted by damage).
function Combat.UseItem(player: Player, index)
	local inv = S.Inventory.Get(player)
	if not inv or type(index) ~= "number" then
		return
	end
	local slot = inv.backpack[index]
	local def = slot and Items.Get(slot.id)
	if not def or def.category ~= "med" then
		if def and def.weapon then
			S.Inventory.EquipFromBackpack(player, index)
		end
		return
	end
	local st = getState(player)
	if now() < st.usingUntil then
		return
	end
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if def.heal and humanoid.Health >= humanoid.MaxHealth and not def.shield then
		S.Notify(player, "Already at full health.", "Gray")
		return
	end
	if def.shield and (player:GetAttribute("Shield") or 0) >= Config.MaxShield then
		S.Notify(player, "Shield already full.", "Gray")
		return
	end
	local token = {}
	st.useToken = token
	st.usingUntil = now() + def.useTime
	player:SetAttribute("UsingUntil", workspace:GetServerTimeNow() + def.useTime)
	player:SetAttribute("UsingItem", def.name)
	task.delay(def.useTime, function()
		if st.useToken ~= token or S.Inventory.Get(player) ~= inv or humanoid.Health <= 0 then
			return
		end
		st.useToken = nil
		if Stacks.Remove(inv.backpack, slot.id, 1) < 1 then
			return
		end
		if def.heal then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + def.heal)
		end
		if def.shield then
			player:SetAttribute("Shield", math.min(Config.MaxShield, (player:GetAttribute("Shield") or 0) + def.shield))
		end
		player:SetAttribute("UsingUntil", 0)
		S.Inventory.Sync(player)
	end)
end

function Combat.ResetPlayer(player: Player)
	state[player] = nil
	player:SetAttribute("Shield", 0)
	player:SetAttribute("UsingUntil", 0)
	player:SetAttribute("ReloadingUntil", 0)
end

function Combat.Init(services)
	S = services
	Stacks = S.Stacks
end

function Combat.Start()
	S.Remotes.Fire.OnServerEvent:Connect(Combat.Fire)
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)
end

return Combat
