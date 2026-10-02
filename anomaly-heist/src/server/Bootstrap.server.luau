--!strict
-- Server entry point. Initialization order (spec 14.2):
--   config validation -> remotes -> data layer (M3) -> world -> gameplay services -> ready signal
-- If anything fails, gameplay stays blocked and clients see a clear error.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contracts = require(Shared.Net.Contracts)
local ConfigValidator = require(Shared.Config.ConfigValidator)
local GameConfig = require(Shared.Config.GameConfig)

local WorldBuilder = require(script.Parent.World.WorldBuilder)
local BaseService = require(script.Parent.Services.BaseService)
local PortalService = require(script.Parent.Services.PortalService)

ReplicatedStorage:SetAttribute(Contracts.ReadyAttribute, false)
ReplicatedStorage:SetAttribute(Contracts.ErrorAttribute, nil)

local ok, err = xpcall(function()
	local problems = ConfigValidator.validate()
	if #problems > 0 then
		error("invalid configuration:\n  " .. table.concat(problems, "\n  "))
	end

	local remotes = Contracts.createServerRemotes()
	-- Data layer (profile repository) arrives with M3; M1 stores nothing.
	local world = WorldBuilder.build()

	BaseService.init(world)
	PortalService.init(world, remotes)
	BaseService.start()
	PortalService.start()
end, debug.traceback)

if ok then
	ReplicatedStorage:SetAttribute(Contracts.ReadyAttribute, true)
	print(string.format("[AnomalyHeist] server ready (build %s)", GameConfig.version))
else
	ReplicatedStorage:SetAttribute(Contracts.ErrorAttribute, "ServerFailed")
	warn("[AnomalyHeist] server initialization failed - gameplay is blocked:\n" .. tostring(err))
end
