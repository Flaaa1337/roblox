--!strict
-- Gameplay HUD for M1 (spec 13.1): area + safety badge, current objective,
-- device-aware movement hint, portal transition overlay, notices and the
-- honest "some text is in English" note. Everything is localized, wraps for
-- long translations, mirrors for right-to-left locales and keeps 48 px touch
-- targets. No shop, collection or trade buttons exist until they work.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Contracts = require(Shared.Net.Contracts)
local ErrorCodes = require(Shared.Net.ErrorCodes)
local GameConfig = require(Shared.Config.GameConfig)
local ZoneDefinitions = require(Shared.Config.ZoneDefinitions)
local Theme = require(script.Parent.Parent.UI.Theme)
local Loc = require(script.Parent.LocalizationController)
local InputController = require(script.Parent.InputController)

local HUDController = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local textScale = 1
local hasTraveled = false
local hintDismissed = false
local transitionToken = 0

-- label -> function that produces its current text (re-run on language change)
type TextObject = TextLabel | TextButton
local bindings: { [Instance]: { label: TextObject, producer: () -> string } } = {}
local sized: { { label: TextObject, base: number } } = {}

local areaBadge: Frame
local areaIcon: TextLabel
local areaName: TextLabel
local areaStatus: TextLabel
local objective: Frame
local hintCard: Frame
local fallbackNote: TextLabel
local toast: TextLabel
local overlay: Frame
local overlayText: TextLabel

local function bind(label: TextObject, producer: () -> string)
	bindings[label] = { label = label, producer = producer }
	local obj: any = label
	obj.Text = producer()
end

local function sizedText(label: TextObject, base: number)
	table.insert(sized, { label = label, base = base })
	local obj: any = label
	obj.TextSize = math.floor(base * textScale)
end

local function refreshText()
	for _, binding in bindings do
		local obj: any = binding.label
		obj.Text = binding.producer()
	end
end

local function areaKey(areaId: string): string
	if areaId == "hub" then
		return "area.hub"
	end
	local zone = ZoneDefinitions[areaId]
	return if zone then zone.nameKey else "area.hub"
end

local function currentArea(): string
	local area = player:GetAttribute("AreaId")
	return if type(area) == "string" then area else "hub"
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local function applyDirection()
	local rtl = Loc.isRightToLeft()
	local align = if rtl then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
	areaBadge.AnchorPoint = if rtl then Vector2.new(1, 0) else Vector2.new(0, 0)
	areaBadge.Position = if rtl then UDim2.new(1, -12, 0, 12) else UDim2.new(0, 12, 0, 12)
	local layout = areaBadge:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.HorizontalAlignment = if rtl then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	end
	areaIcon.LayoutOrder = if rtl then 2 else 1
	local textColumn = areaName.Parent :: Frame
	textColumn.LayoutOrder = if rtl then 1 else 2
	areaName.TextXAlignment = align
	areaStatus.TextXAlignment = align
	fallbackNote.TextXAlignment = align
	fallbackNote.AnchorPoint = if rtl then Vector2.new(1, 1) else Vector2.new(0, 1)
	fallbackNote.Position = if rtl then UDim2.new(1, -12, 1, -12) else UDim2.new(0, 12, 1, -12)
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") and d.Parent == objective then
			d.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
end

local function rescale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	textScale = math.clamp(camera.ViewportSize.Y / 720, 0.8, 1.2)
	for _, entry in sized do
		local obj: any = entry.label
		obj.TextSize = math.floor(entry.base * textScale)
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "AnomalyHeistHUD"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Area + safety badge -------------------------------------------------
	areaBadge = Theme.panel({ Name = "AreaBadge", AutomaticSize = Enum.AutomaticSize.XY, Position = UDim2.new(0, 12, 0, 12), Parent = gui })
	Theme.padding(8).Parent = areaBadge
	local badgeLayout = Instance.new("UIListLayout")
	badgeLayout.FillDirection = Enum.FillDirection.Horizontal
	badgeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	badgeLayout.SortOrder = Enum.SortOrder.LayoutOrder
	badgeLayout.Padding = UDim.new(0, 8)
	badgeLayout.Parent = areaBadge
	-- icon + text: color is never the only signal (spec 3.4)
	areaIcon = Theme.label({ Name = "Icon", Size = UDim2.fromOffset(32, 32), Text = "", TextScaled = true, LayoutOrder = 1, Parent = areaBadge })
	local column = Instance.new("Frame")
	column.Name = "Text"
	column.BackgroundTransparency = 1
	column.AutomaticSize = Enum.AutomaticSize.XY
	column.LayoutOrder = 2
	column.Parent = areaBadge
	local columnLayout = Instance.new("UIListLayout")
	columnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	columnLayout.Parent = column
	areaName = Theme.label({ Name = "AreaName", AutomaticSize = Enum.AutomaticSize.XY, TextWrapped = false, LayoutOrder = 1, Parent = column })
	sizedText(areaName, 18)
	areaStatus = Theme.label({ Name = "AreaStatus", AutomaticSize = Enum.AutomaticSize.XY, TextWrapped = false, Font = Theme.bodyFont, LayoutOrder = 2, Parent = column })
	sizedText(areaStatus, 14)
	local maxWidth = Instance.new("UISizeConstraint")
	maxWidth.MaxSize = Vector2.new(320, math.huge)
	maxWidth.Parent = areaBadge

	-- Objective -----------------------------------------------------------
	objective = Theme.panel({
		Name = "Objective", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.5, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = gui,
	})
	Theme.padding(10).Parent = objective
	local objectiveWidth = Instance.new("UISizeConstraint")
	objectiveWidth.MinSize = Vector2.new(220, 0)
	objectiveWidth.MaxSize = Vector2.new(520, math.huge)
	objectiveWidth.Parent = objective
	local objectiveText = Theme.label({
		Name = "ObjectiveText", Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = objective,
	})
	sizedText(objectiveText, 18)
	bind(objectiveText, function()
		local area = currentArea()
		local key = if area ~= "hub" then "objective.explore_zone"
			elseif hasTraveled then "objective.first_capture"
			else "objective.go_to_portal"
		return "◎  " .. Loc.t(key)
	end)

	-- Movement hint (dismissible) ------------------------------------------
	hintCard = Theme.panel({
		Name = "Hint", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.new(0.6, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = gui,
	})
	Theme.padding(10).Parent = hintCard
	local hintWidth = Instance.new("UISizeConstraint")
	hintWidth.MinSize = Vector2.new(240, 0)
	hintWidth.MaxSize = Vector2.new(560, math.huge)
	hintWidth.Parent = hintCard
	local hintLayout = Instance.new("UIListLayout")
	hintLayout.Padding = UDim.new(0, 8)
	hintLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hintLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hintLayout.Parent = hintCard
	local hintText = Theme.label({ Name = "HintText", Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Font = Theme.bodyFont, LayoutOrder = 1, Parent = hintCard })
	sizedText(hintText, 16)
	bind(hintText, function()
		local device = InputController.device()
		if device == "touch" then
			return Loc.t("hint.move_touch")
		elseif device == "gamepad" then
			return Loc.t("hint.move_gamepad")
		end
		return Loc.t("hint.move_keyboard", {
			up = InputController.keyName(Enum.KeyCode.W),
			left = InputController.keyName(Enum.KeyCode.A),
			down = InputController.keyName(Enum.KeyCode.S),
			right = InputController.keyName(Enum.KeyCode.D),
			jump = InputController.keyName(Enum.KeyCode.Space),
		}) .. "\n" .. Loc.t("base.direction")
	end)
	local dismiss = Instance.new("TextButton")
	dismiss.Name = "Dismiss"
	dismiss.AutoLocalize = false
	dismiss.Size = UDim2.new(0, 0, 0, Theme.touchTarget)
	dismiss.AutomaticSize = Enum.AutomaticSize.X
	dismiss.BackgroundColor3 = Theme.safe
	dismiss.TextColor3 = Color3.fromRGB(10, 30, 40)
	dismiss.Font = Theme.font
	dismiss.LayoutOrder = 2
	dismiss.Parent = hintCard
	local dismissCorner = Instance.new("UICorner")
	dismissCorner.CornerRadius = Theme.corner
	dismissCorner.Parent = dismiss
	local dismissPad = Theme.padding(12)
	dismissPad.Parent = dismiss
	sizedText(dismiss, 16)
	bind(dismiss, function()
		return Loc.t("hint.dismiss")
	end)
	dismiss.Activated:Connect(function()
		hintDismissed = true
		hintCard.Visible = false
	end)

	-- Fallback note, toast, travel overlay ---------------------------------
	fallbackNote = Theme.label({
		Name = "FallbackNote", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12),
		AutomaticSize = Enum.AutomaticSize.XY, TextWrapped = false, Font = Theme.bodyFont, TextColor3 = Theme.muted,
		Visible = false, Parent = gui,
	})
	sizedText(fallbackNote, 12)
	bind(fallbackNote, function()
		return "ⓘ " .. Loc.t("error.translation_fallback")
	end)

	toast = Theme.label({
		Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.new(0.5, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.2,
		BackgroundColor3 = Color3.fromRGB(60, 30, 20), Visible = false, Parent = gui,
	})
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = Theme.corner
	toastCorner.Parent = toast
	Theme.padding(8).Parent = toast
	sizedText(toast, 16)

	overlay = Instance.new("Frame")
	overlay.Name = "TravelOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(12, 10, 20)
	overlay.BackgroundTransparency = 1
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = gui
	overlayText = Theme.label({ Name = "Text", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.8, 0, 0, 40), ZIndex = 11, Parent = overlay })
	sizedText(overlayText, 24)
	bind(overlayText, function()
		return Loc.t("status.traveling")
	end)
end

---------------------------------------------------------------------------
-- State updates
---------------------------------------------------------------------------
local function updateArea()
	local area = currentArea()
	local safe = area == "hub"
	areaIcon.Text = if safe then "🛡" else "🧭"
	areaBadge.BackgroundColor3 = if safe then Color3.fromRGB(18, 48, 58) else Color3.fromRGB(40, 26, 60)
	bind(areaName, function()
		return Loc.t(areaKey(currentArea()))
	end)
	bind(areaStatus, function()
		return Loc.t(if currentArea() == "hub" then "status.safe_area" else "status.expedition_area")
	end)
	refreshText()
end

function HUDController.showNotice(code: string)
	local key = ErrorCodes.keyFor(code)
	if not key then
		return
	end
	bind(toast, function()
		return "⚠ " .. Loc.t(key)
	end)
	toast.Visible = true
	local token = {}
	toast:SetAttribute("Token", tostring(token))
	task.delay(4, function()
		if toast:GetAttribute("Token") == tostring(token) then
			toast.Visible = false
		end
	end)
end

local function setOverlay(visible: boolean)
	local reduced = false -- reduced-motion setting arrives with the settings screen (M5)
	if visible then
		overlay.Visible = true
		if reduced then
			overlay.BackgroundTransparency = 0
		else
			TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
		end
	else
		if reduced then
			overlay.Visible = false
			overlay.BackgroundTransparency = 1
		else
			local tween = TweenService:Create(overlay, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
			tween.Completed:Connect(function()
				if overlay.BackgroundTransparency >= 0.99 then
					overlay.Visible = false
				end
			end)
			tween:Play()
		end
	end
end

local function onTransition(phase: string, areaId: string, errorCode: string?)
	if phase == "start" then
		transitionToken += 1
		local token = transitionToken
		setOverlay(true)
		-- client-side safety timeout: never leave the screen covered
		task.delay(GameConfig.portal.clientTimeoutSeconds, function()
			if transitionToken == token and overlay.Visible then
				setOverlay(false)
				HUDController.showNotice("TravelFailed")
			end
		end)
	elseif phase == "arrived" then
		transitionToken += 1
		if areaId ~= "hub" then
			hasTraveled = true
		end
		setOverlay(false)
		updateArea()
	elseif phase == "failed" then
		transitionToken += 1
		setOverlay(false)
		if errorCode then
			HUDController.showNotice(errorCode)
		end
	end
end

function HUDController.init(remotes: { [string]: RemoteEvent })
	build()
	rescale()
	updateArea()
	applyDirection()
	remotes[Contracts.Events.AreaTransition].OnClientEvent:Connect(onTransition)
	remotes[Contracts.Events.Notice].OnClientEvent:Connect(function(code)
		if type(code) == "string" then
			HUDController.showNotice(code)
		end
	end)
end

function HUDController.start()
	player:GetAttributeChangedSignal("AreaId"):Connect(updateArea)
	Loc.changed:connect(function()
		refreshText()
		applyDirection()
	end)
	Loc.fallbackNoticed:connect(function()
		fallbackNote.Visible = true
	end)
	fallbackNote.Visible = Loc.usedFallback()
	InputController.deviceChanged:connect(function()
		refreshText()
	end)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	hintCard.Visible = not hintDismissed
end

return HUDController
