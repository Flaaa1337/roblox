--!strict
-- Primitive fallback models for the first three species. Each has one
-- memorable silhouette feature (spec section 8). Models are cosmetic: they
-- never decide ownership. Final meshes can replace them later via the asset
-- manifest without changing gameplay code.

local CollectionService = game:GetService("CollectionService")

local Kit = require(script.Parent.Kit)

local Factory = {}

local function build(speciesId: string, cf: CFrame, parent: Instance?): (Model, (props: { [string]: any }) -> BasePart)
	local model = Instance.new("Model")
	model.Name = speciesId
	model:SetAttribute("SpeciesId", speciesId)
	local root = Kit.part({
		Name = "Root", Size = Vector3.new(1, 1, 1), CFrame = cf, Transparency = 1,
		CanCollide = false, CanQuery = false, CanTouch = false,
	}, model)
	model.PrimaryPart = root
	local function add(props: { [string]: any }): BasePart
		props.CanCollide = false
		props.CanTouch = false
		local offset = props.Offset :: CFrame
		props.Offset = nil
		props.CFrame = cf * offset
		local part = Kit.part(props, model)
		return part
	end
	model.Parent = parent
	return model, add
end

local function eye(add: (props: { [string]: any }) -> BasePart, offset: CFrame, size: number)
	add({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * size, Offset = offset, Color = Color3.fromRGB(245, 245, 245) })
	add({ Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.5, Offset = offset * CFrame.new(0, 0, -size * 0.35), Color = Color3.fromRGB(20, 20, 24) })
end

-- Gray pigeon with ONE segmented violet wing.
function Factory.glitchPigeon(cf: CFrame, parent: Instance?): Model
	local model, add = build("glitch_pigeon", cf, parent)
	local gray = Color3.fromRGB(150, 154, 162)
	add({ Name = "Body", Size = Vector3.new(1.8, 1.6, 2.6), Offset = CFrame.new(0, 1.6, 0), Color = gray })
	add({ Name = "Chest", Size = Vector3.new(1.6, 1.2, 0.6), Offset = CFrame.new(0, 1.7, -1.3), Color = Color3.fromRGB(120, 150, 150) })
	add({ Name = "Head", Size = Vector3.new(1.2, 1.2, 1.2), Offset = CFrame.new(0, 2.9, -1.1), Color = gray })
	add({ Name = "Beak", Size = Vector3.new(0.4, 0.3, 0.6), Offset = CFrame.new(0, 2.8, -1.9), Color = Color3.fromRGB(230, 180, 70) })
	eye(add, CFrame.new(-0.45, 3.05, -1.6), 0.35)
	eye(add, CFrame.new(0.45, 3.05, -1.6), 0.35)
	add({ Name = "Tail", Size = Vector3.new(1.2, 0.3, 1.2), Offset = CFrame.new(0, 1.9, 1.7) * CFrame.Angles(math.rad(20), 0, 0), Color = Color3.fromRGB(110, 114, 122) })
	add({ Name = "Wing", Size = Vector3.new(0.3, 1.2, 2), Offset = CFrame.new(-1, 1.7, 0.1), Color = Color3.fromRGB(130, 134, 142) })
	-- the glitch wing: three offset violet segments
	for i = 0, 2 do
		add({
			Name = "GlitchWing", Size = Vector3.new(0.3, 0.45, 0.8), Material = Enum.Material.Neon,
			Offset = CFrame.new(1.05 + i * 0.12, 1.3 + i * 0.45, 0.6 - i * 0.55), Color = Kit.Palette.anomaly,
		})
	end
	for x = -1, 1, 2 do
		add({ Name = "Leg", Size = Vector3.new(0.2, 0.8, 0.2), Offset = CFrame.new(x * 0.45, 0.4, -0.2), Color = Color3.fromRGB(220, 120, 110) })
	end
	return model
end

-- Small dog whose body is a white refrigerator.
function Factory.fridgeDog(cf: CFrame, parent: Instance?): Model
	local model, add = build("fridge_dog", cf, parent)
	local white = Color3.fromRGB(236, 238, 240)
	local fur = Color3.fromRGB(170, 112, 70)
	add({ Name = "Fridge", Size = Vector3.new(2.6, 3.2, 3.4), Offset = CFrame.new(0, 2.6, 0.4), Color = white, Material = Enum.Material.Metal })
	add({ Name = "DoorLine", Size = Vector3.new(2.62, 0.1, 3.42), Offset = CFrame.new(0, 3.2, 0.4), Color = Color3.fromRGB(180, 184, 190) })
	add({ Name = "Handle", Size = Vector3.new(0.2, 1.2, 0.2), Offset = CFrame.new(1.35, 2.6, -0.6), Color = Color3.fromRGB(160, 164, 170), Material = Enum.Material.Metal })
	add({ Name = "Head", Size = Vector3.new(1.8, 1.6, 1.6), Offset = CFrame.new(0, 3.4, -1.9), Color = fur })
	add({ Name = "Snout", Size = Vector3.new(1, 0.8, 0.9), Offset = CFrame.new(0, 3.0, -2.9), Color = Color3.fromRGB(230, 210, 180) })
	add({ Name = "Nose", Size = Vector3.new(0.4, 0.3, 0.2), Offset = CFrame.new(0, 3.3, -3.4), Color = Color3.fromRGB(30, 26, 26) })
	add({ Name = "Tongue", Size = Vector3.new(0.4, 0.1, 0.5), Offset = CFrame.new(0.15, 2.55, -3.1) * CFrame.Angles(math.rad(-20), 0, 0), Color = Color3.fromRGB(230, 110, 130) })
	eye(add, CFrame.new(-0.45, 3.75, -2.7), 0.35)
	eye(add, CFrame.new(0.45, 3.75, -2.7), 0.35)
	for x = -1, 1, 2 do
		add({ Name = "Ear", Size = Vector3.new(0.4, 1.2, 0.8), Offset = CFrame.new(x * 1.0, 3.5, -1.8) * CFrame.Angles(0, 0, x * math.rad(15)), Color = Color3.fromRGB(120, 80, 50) })
		for z = -1, 1, 2 do
			add({ Name = "Leg", Size = Vector3.new(0.6, 1.0, 0.6), Offset = CFrame.new(x * 0.9, 0.5, 0.4 + z * 1.2), Color = fur })
		end
	end
	add({ Name = "Tail", Size = Vector3.new(0.3, 0.3, 1.0), Offset = CFrame.new(0, 3.4, 2.4) * CFrame.Angles(math.rad(35), 0, 0), Color = fur })
	-- frost vents (cold-air mechanic in M2)
	add({ Name = "Vent", Size = Vector3.new(1.6, 0.2, 0.6), Offset = CFrame.new(0, 1.15, 1.6), Color = Kit.Palette.safe, Material = Enum.Material.Neon })
	return model
end

-- Green toad with a speaker-like throat.
function Factory.sirenToad(cf: CFrame, parent: Instance?): Model
	local model, add = build("siren_toad", cf, parent)
	local green = Color3.fromRGB(96, 168, 82)
	add({ Name = "Body", Size = Vector3.new(2.8, 1.6, 2.6), Offset = CFrame.new(0, 1.0, 0), Color = green })
	add({ Name = "Back", Size = Vector3.new(2.2, 0.6, 2.0), Offset = CFrame.new(0, 2.0, 0.2), Color = Color3.fromRGB(78, 140, 66) })
	eye(add, CFrame.new(-0.8, 2.3, -0.8), 0.7)
	eye(add, CFrame.new(0.8, 2.3, -0.8), 0.7)
	-- speaker throat: grille cone with rings
	add({
		Name = "Speaker", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 1.6, 1.6),
		Offset = CFrame.new(0, 0.9, -1.45) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(40, 42, 48), Material = Enum.Material.Metal,
	})
	add({
		Name = "SpeakerCone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.1, 1.1),
		Offset = CFrame.new(0, 0.9, -1.8) * CFrame.Angles(0, math.rad(90), 0), Color = Kit.Palette.hazard, Material = Enum.Material.Neon,
	})
	for x = -1, 1, 2 do
		add({ Name = "Leg", Size = Vector3.new(0.9, 0.5, 1.4), Offset = CFrame.new(x * 1.4, 0.25, 0.6), Color = green })
		add({ Name = "Foot", Size = Vector3.new(0.9, 0.2, 0.7), Offset = CFrame.new(x * 1.1, 0.1, -1.0), Color = green })
	end
	return model
end

local BUILDERS: { [string]: (CFrame, Instance?) -> Model } = {
	glitch_pigeon = Factory.glitchPigeon,
	fridge_dog = Factory.fridgeDog,
	siren_toad = Factory.sirenToad,
}

-- Builds a creature by species id; returns nil for species without a model.
function Factory.create(speciesId: string, cf: CFrame, parent: Instance?): Model?
	local builder = BUILDERS[speciesId]
	if not builder then
		return nil
	end
	local model = builder(cf, parent)
	CollectionService:AddTag(model, "AH_CreatureIdle")
	return model
end

function Factory.has(speciesId: string): boolean
	return BUILDERS[speciesId] ~= nil
end

return Factory
