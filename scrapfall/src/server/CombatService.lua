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
	local length = if def.weapon.range > 300 then 4.5 elseif def.weapon.pellets > 1 then 3.6 elseif def.weapon.auto then 3 else 1.8
	local model = Instance.new("Model")
	model.Name = "HeldWeapon"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(0.4, 0.7, length)
	body.Color = def.color or Color3.fromRGB(80, 80, 80)
	body.Material = Enum.Material.Metal
	body.CanCollide = false
	body.CanQuery = false
	body.Massless = true
	body.CFrame = hand.CFrame * CFrame.new(0, -0.3, -length / 2 + 0.4)
	body.Parent = model
	local barrel = Instance.new("Part")
	barrel.Name = "Muzzle"
	barrel.Size = Vector3.new(0.25, 0.25, 0.8)
	barrel.Color = Color3.fromRGB(30, 30, 30)
	barrel.Material = Enum.Material.Metal
	barrel.CanCollide = false
	barrel.CanQuery = false
	barrel.Massless = true
	barrel.CFrame = body.CFrame * CFrame.new(0, 0.15, -length / 2 - 0.4)
	barrel.Parent = model
	local w1 = Instance.new("WeldConstraint")
	w1.Part0 = hand
	w1.Part1 = body
	w1.Parent = body
	local w2 = Instance.new("WeldConstraint")
	w2.Part0 = body
	w2.Part1 = barrel
	w2.Parent = barrel
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

local function broadcastTracer(shooter: Player, from: Vector3, to: Vector3)
	for _, other in Players:GetPlayers() do
		if other ~= shooter and other:GetAttribute("MapId") == shooter:GetAttribute("MapId") then
			S.Remotes.Effect:FireClient(other, "Tracer", from, to)
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

	for _ = 1, def.pellets do
		local dir = spreadDirection(baseDir, def.spread)
		local result = workspace:Raycast(from, dir * def.range, params)
		local to = if result then result.Position else from + dir * def.range
		broadcastTracer(player, from, to)
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
