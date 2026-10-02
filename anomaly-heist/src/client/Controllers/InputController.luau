--!strict
-- Tracks the player's current input device so hints match what they hold
-- (spec 13.2). Movement, camera and jump stay native Roblox controls.
-- Gameplay actions (Dash, Pulse, Drop, Collection) are added with M2/M4.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local GameConfig = require(Shared.Config.GameConfig)

export type Device = "keyboard" | "touch" | "gamepad"

local InputController = {}

InputController.deviceChanged = Signal.new()

local device: Device = "keyboard"

local function classify(inputType: Enum.UserInputType): Device?
	if inputType == Enum.UserInputType.Touch then
		return "touch"
	elseif string.find(inputType.Name, "Gamepad") then
		return "gamepad"
	elseif inputType == Enum.UserInputType.Keyboard
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.MouseWheel then
		return "keyboard"
	end
	return nil
end

function InputController.device(): Device
	return device
end

-- Layout-aware key label (e.g. Z instead of W on AZERTY keyboards).
function InputController.keyName(keyCode: Enum.KeyCode): string
	local ok, text = pcall(function()
		return UserInputService:GetStringForKeyCode(keyCode)
	end)
	if ok and type(text) == "string" and string.match(text, "%S") then
		return string.upper(text)
	end
	return keyCode.Name
end

function InputController.init()
	local initial: Device? = classify(UserInputService:GetLastInputType())
	if initial then
		device = initial
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		device = "touch"
	end
	local player = Players.LocalPlayer
	player.CameraMinZoomDistance = GameConfig.camera.minZoom
	player.CameraMaxZoomDistance = GameConfig.camera.maxZoom
end

function InputController.start()
	UserInputService.LastInputTypeChanged:Connect(function(inputType)
		local newDevice: Device? = classify(inputType)
		if newDevice and newDevice ~= device then
			device = newDevice
			InputController.deviceChanged:fire(device)
		end
	end)
end

return InputController
