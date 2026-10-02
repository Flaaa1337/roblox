--!strict
-- Client entry point: shows a localized loading state, waits for the server
-- ready signal (with a timeout and a clear error), then starts controllers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Contracts = require(Shared.Net.Contracts)

local Controllers = script.Parent:WaitForChild("Controllers")
local LocalizationController = require(Controllers.LocalizationController)
local InputController = require(Controllers.InputController)
local HUDController = require(Controllers.HUDController)
local EffectsController = require(Controllers.EffectsController)
local Theme = require(script.Parent:WaitForChild("UI"):WaitForChild("Theme"))

local player = Players.LocalPlayer
local READY_TIMEOUT = 60

LocalizationController.init()
InputController.init()

-- Loading screen
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name = "AnomalyHeistLoading"
loadingGui.ResetOnSpawn = false
loadingGui.DisplayOrder = 10
loadingGui.Parent = player:WaitForChild("PlayerGui")
local loadingText = Theme.label({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.new(0.8, 0, 0, 30),
	TextSize = 20, Text = LocalizationController.t("status.loading"), Parent = loadingGui,
})

local function serverState(): string
	if ReplicatedStorage:GetAttribute(Contracts.ErrorAttribute) then
		return "error"
	elseif ReplicatedStorage:GetAttribute(Contracts.ReadyAttribute) == true then
		return "ready"
	end
	return "waiting"
end

local started = os.clock()
while serverState() == "waiting" do
	if os.clock() - started > 5 then
		loadingText.Text = LocalizationController.t("error.server_starting")
	end
	if os.clock() - started > READY_TIMEOUT then
		break
	end
	task.wait(0.25)
end

local remotes = if serverState() == "ready" then Contracts.waitForRemotes(15) else nil
if not remotes then
	loadingText.Text = LocalizationController.t("error.server_failed")
	warn("[AnomalyHeist] client could not start: server state =", serverState())
	return
end

loadingGui:Destroy()
LocalizationController.start()
InputController.start()
HUDController.init(remotes)
HUDController.start()
EffectsController.init()
EffectsController.start()
