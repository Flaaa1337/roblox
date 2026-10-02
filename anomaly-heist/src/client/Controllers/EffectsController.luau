--!strict
-- Client-only cosmetic motion: creature idle bobbing, the hub's spinning
-- anomaly core, floating glitch cubes, and a local beam marking the
-- player's own base. Purely visual, distance-limited, and tolerant of
-- instances streaming in and out. Gameplay never depends on it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cleanup = require(Shared.Util.Cleanup)

local EffectsController = {}

local player = Players.LocalPlayer
local MAX_DISTANCE = 180

local creatures: { [Model]: CFrame } = {} -- model -> base pivot
local spinners: { [BasePart]: CFrame } = {}
local bobbers: { [BasePart]: CFrame } = {}
local beamScope = Cleanup.new()

local function near(position: Vector3): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < MAX_DISTANCE
end

local function trackCreature(instance: Instance)
	if instance:IsA("Model") and not creatures[instance] then
		creatures[instance] = instance:GetPivot()
	end
end

local function scanDecor(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("SpinSpeed") and not spinners[d] then
				spinners[d] = d.CFrame
			elseif d:GetAttribute("Bob") and not bobbers[d] then
				bobbers[d] = d.CFrame
			end
		end
	end
end

local function updateBaseBeam()
	beamScope:destroy()
	beamScope = Cleanup.new()
	local index = player:GetAttribute("PlotIndex")
	if type(index) ~= "number" or index < 1 then
		return
	end
	local scope = beamScope
	task.spawn(function()
		-- the plot may not be streamed in yet; wait for it without blocking
		while scope == beamScope do
			local world = workspace:FindFirstChild("AnomalyHeistWorld")
			local hub = world and world:FindFirstChild("Hub")
			local plot = hub and hub:FindFirstChild("Plot" .. index)
			local marker = plot and plot:FindFirstChild("EntranceMarker")
			if marker and marker:IsA("BasePart") then
				local beam = Instance.new("Part")
				beam.Name = "AH_OwnBaseBeam"
				beam.Anchored = true
				beam.CanCollide = false
				beam.CanQuery = false
				beam.CanTouch = false
				beam.CastShadow = false
				beam.Material = Enum.Material.Neon
				beam.Color = Color3.fromRGB(64, 200, 228)
				beam.Transparency = 0.55
				beam.Size = Vector3.new(1.5, 70, 1.5)
				beam.CFrame = CFrame.new(marker.Position + Vector3.new(0, 35, 0))
				beam.Parent = workspace
				scope:add(beam)
				scope:add(marker.AncestryChanged:Connect(function(_, parent)
					if parent == nil then
						updateBaseBeam() -- streamed out: rebuild when it returns
					end
				end))
				return
			end
			task.wait(1)
		end
	end)
end

function EffectsController.init() end

function EffectsController.start()
	for _, m in CollectionService:GetTagged("AH_CreatureIdle") do
		trackCreature(m)
	end
	CollectionService:GetInstanceAddedSignal("AH_CreatureIdle"):Connect(trackCreature)
	CollectionService:GetInstanceRemovedSignal("AH_CreatureIdle"):Connect(function(instance)
		creatures[instance :: Model] = nil
	end)
	local world = workspace:WaitForChild("AnomalyHeistWorld", 30)
	if world then
		scanDecor(world)
		world.DescendantAdded:Connect(function(d: Instance)
			if d:IsA("BasePart") then
				local parent: Instance = d.Parent or d
				scanDecor(parent)
			end
		end)
		world.DescendantRemoving:Connect(function(d)
			if d:IsA("BasePart") then
				spinners[d] = nil
				bobbers[d] = nil
			end
		end)
	end

	player:GetAttributeChangedSignal("PlotIndex"):Connect(updateBaseBeam)
	updateBaseBeam()

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for model, base in creatures do
			if model.Parent and near(base.Position) then
				model:PivotTo(base * CFrame.new(0, math.abs(math.sin(t * 2.2)) * 0.3, 0) * CFrame.Angles(0, math.sin(t * 0.6) * 0.25, 0))
			end
		end
		for part, base in spinners do
			if near(base.Position) then
				local speed = part:GetAttribute("SpinSpeed")
				part.CFrame = base * CFrame.Angles(0, t * (if type(speed) == "number" then speed else 0.5), 0)
			end
		end
		for part, base in bobbers do
			if near(base.Position) then
				part.CFrame = base * CFrame.new(0, math.sin(t * 1.5 + base.Position.X) * 0.4, 0) * CFrame.Angles(0, t * 0.8, 0)
			end
		end
	end)
end

return EffectsController
