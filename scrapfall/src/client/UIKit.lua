-- Tiny helpers for building UI from code.

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne
UIKit.BodyFont = Enum.Font.GothamBold

UIKit.Colors = {
	Panel = Color3.fromRGB(22, 30, 52),
	PanelLight = Color3.fromRGB(38, 50, 82),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(170, 185, 215),
	Gold = Color3.fromRGB(255, 205, 60),
	Green = Color3.fromRGB(70, 200, 100),
	Red = Color3.fromRGB(235, 70, 70),
	Orange = Color3.fromRGB(255, 140, 50),
	Blue = Color3.fromRGB(70, 140, 255),
	Purple = Color3.fromRGB(160, 90, 255),
	Gray = Color3.fromRGB(110, 120, 140),
}

function UIKit.new(className: string, props, children)
	local inst = Instance.new(className)
	local parent
	for k, v in props or {} do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = parent
	return inst
end

function UIKit.corner(radius: number?)
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function UIKit.stroke(color: Color3?, thickness: number?)
	return UIKit.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.padding(px: number)
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px),
	})
end

function UIKit.panel(props)
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.Colors.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.1
	props.BorderSizePixel = 0
	local frame = UIKit.new("Frame", props, { UIKit.corner(14), UIKit.stroke(Color3.fromRGB(10, 14, 28), 2) })
	return frame
end

function UIKit.label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or UIKit.Colors.Text
	props.Font = props.Font or UIKit.Font
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	return UIKit.new("TextLabel", props)
end

function UIKit.button(props, onClick)
	props.BackgroundColor3 = props.BackgroundColor3 or UIKit.Colors.Blue
	props.TextColor3 = props.TextColor3 or UIKit.Colors.Text
	props.Font = props.Font or UIKit.Font
	props.AutoButtonColor = true
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local maxTextSize = props.MaxTextSize or 24
	props.MaxTextSize = nil
	local button = UIKit.new("TextButton", props, {
		UIKit.corner(10),
		UIKit.stroke(Color3.fromRGB(10, 14, 28), 2),
		UIKit.new("UITextSizeConstraint", { MaxTextSize = maxTextSize }),
	})
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function UIKit.formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

return UIKit
