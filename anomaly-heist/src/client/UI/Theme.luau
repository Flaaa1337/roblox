--!strict
-- Shared UI look: readable, high-contrast, touch-sized (48 px targets).

local Theme = {
	font = Enum.Font.GothamBold,
	bodyFont = Enum.Font.Gotham,
	panelColor = Color3.fromRGB(24, 28, 36),
	panelTransparency = 0.15,
	text = Color3.fromRGB(242, 244, 246),
	muted = Color3.fromRGB(178, 186, 198),
	safe = Color3.fromRGB(64, 200, 228),
	anomaly = Color3.fromRGB(170, 120, 240),
	hazard = Color3.fromRGB(240, 142, 52),
	touchTarget = 48,
	corner = UDim.new(0, 10),
}

function Theme.panel(props: { [string]: any }): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Theme.panelColor
	frame.BackgroundTransparency = Theme.panelTransparency
	frame.BorderSizePixel = 0
	for k, v in props do
		(frame :: any)[k] = v
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.corner
	corner.Parent = frame
	return frame
end

function Theme.label(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.font
	label.TextColor3 = Theme.text
	label.TextWrapped = true
	label.AutoLocalize = false -- text comes from the LocalizationController
	for k, v in props do
		(label :: any)[k] = v
	end
	return label
end

function Theme.padding(px: number): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	return p
end

return Theme
