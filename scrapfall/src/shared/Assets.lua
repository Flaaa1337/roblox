-- Asset slots. Drop real models / sounds into ReplicatedStorage.GameAssets
-- (Robots, Weapons, Props, Sounds) with the names listed below and the game
-- uses them automatically instead of the built-in shapes.
--
-- Robots:  Crawler, Buzzer, Watcher, Sentinel, Colossus
--          (optional part named "WeakPoint" = bonus damage, "Eye" = laser origin)
-- Weapons: ScrapPistol, Rattler, Hammer, Breacher, Longshot
--          (part named "Handle" is held in the hand, part named "Muzzle" = barrel tip)
-- Props:   Crate, Toolbox, MedCabinet, WeaponCase, RobotCache, DeathCache, Wreck
-- Sounds:  Shot_LightAmmo, Shot_HeavyAmmo, Shot_Shells, Laser, Bolt, Explosion,
--          Hit, Kill, Hurt, LiftAlarm, Extract, Spotted, Reload, Heal

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = {}

-- Built-in Roblox sounds used until you add your own.
Assets.FallbackSounds = {
	Shot_LightAmmo = { id = "rbxasset://sounds/paintball.wav", volume = 0.6, speed = 1.4 },
	Shot_HeavyAmmo = { id = "rbxasset://sounds/paintball.wav", volume = 0.8, speed = 0.9 },
	Shot_Shells = { id = "rbxasset://sounds/Rocket shot.wav", volume = 0.6, speed = 1.6 },
	Laser = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.5, speed = 0.7 },
	Bolt = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, speed = 0.4 },
	Explosion = { id = "rbxasset://sounds/collide.wav", volume = 1, speed = 0.5 },
	Hit = { id = "rbxasset://sounds/clickfast.wav", volume = 0.5, speed = 1.5 },
	Kill = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, speed = 1.3 },
	Hurt = { id = "rbxasset://sounds/hit.wav", volume = 0.6, speed = 1 },
	LiftAlarm = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 1, speed = 0.5 },
	Extract = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 1, speed = 1 },
	Spotted = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 1, speed = 0.3 },
	Reload = { id = "rbxasset://sounds/unsheath.wav", volume = 0.5, speed = 1.2 },
	Heal = { id = "rbxasset://sounds/unsheath.wav", volume = 0.4, speed = 0.8 },
}

local function folder(kind: string)
	local root = ReplicatedStorage:FindFirstChild("GameAssets")
	return root and root:FindFirstChild(kind)
end

-- Returns a fresh clone of the asset, or nil if none was added.
function Assets.Get(kind: string, name: string)
	local f = folder(kind)
	local template = f and f:FindFirstChild(name)
	if not template then
		return nil
	end
	local clone = template:Clone()
	-- never run scripts that came with a downloaded model
	for _, d in clone:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy()
		end
	end
	return clone
end

-- Makes a Sound for the given slot (custom asset first, then fallback).
function Assets.Sound(name: string): Sound?
	local custom = Assets.Get("Sounds", name)
	if custom and custom:IsA("Sound") then
		return custom
	end
	local fb = Assets.FallbackSounds[name]
	if not fb then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = fb.id
	sound.Volume = fb.volume
	sound.PlaybackSpeed = fb.speed
	return sound
end

-- Scales a model so its largest dimension matches `size`, then pivots it to cf.
function Assets.Fit(model: Model, size: number, cf: CFrame)
	local extents = model:GetExtentsSize()
	local largest = math.max(extents.X, extents.Y, extents.Z)
	if largest > 0 then
		model:ScaleTo(model:GetScale() * size / largest)
	end
	model:PivotTo(cf)
end

return Assets
