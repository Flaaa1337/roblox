-- SCRAPFALL client: camera, shooting, HUD and all menus.
-- Works with mouse & keyboard, touch and gamepad.

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local Crafting = require(Shared:WaitForChild("Crafting"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UI = require(script.Parent:WaitForChild("UIKit"))
local C = UI.Colors

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local profile = nil -- outpost snapshot
local inventory = nil -- raid inventory snapshot
local container = nil -- open container { id, title, contents }

local function action(name: string, arg)
	Remotes.Action:FireServer(name, arg)
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function inRaid(): boolean
	return player:GetAttribute("InRaid") == true
end

local function rarityColor(id: string): Color3
	local def = Items.Get(id)
	return def and Items.Rarities[def.rarity].color or C.Text
end

local function itemName(id: string): string
	local def = Items.Get(id)
	return def and def.name or id
end

local function colorFor(name: string?): Color3
	return C[name or "Text"] or C.Text
end

---------------------------------------------------------------------------
-- Root GUI
---------------------------------------------------------------------------
local gui = UI.new("ScreenGui", {
	Name = "ScrapfallHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true, Parent = player:WaitForChild("PlayerGui"),
})
local uiScale = UI.new("UIScale", { Parent = gui })
local function rescale()
	local vp = workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.55, 1.1)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

---------------------------------------------------------------------------
-- Toasts & banners
---------------------------------------------------------------------------
local toastHolder = UI.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(600, 200),
	BackgroundTransparency = 1, Parent = gui,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

local function toast(text: string, color: string?)
	local labels = {}
	for _, c in toastHolder:GetChildren() do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	if #labels >= 5 then
		labels[1]:Destroy()
	end
	local label = UI.label({
		Size = UDim2.fromOffset(600, 28), BackgroundTransparency = 0.35, BackgroundColor3 = Color3.fromRGB(10, 10, 14),
		Text = text, TextColor3 = colorFor(color), Font = UI.BodyFont, Parent = toastHolder,
	})
	UI.corner(6).Parent = label
	UI.new("UITextSizeConstraint", { MaxTextSize = 18, Parent = label })
	task.delay(4.5, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.wait(0.45)
			label:Destroy()
		end
	end)
end

local banner = UI.label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(860, 60),
	Text = "", TextStrokeTransparency = 0.2, Visible = false, Parent = gui,
})
local bannerToken
local function showBanner(text: string, color: string?)
	banner.Text = text
	banner.TextColor3 = colorFor(color)
	banner.Visible = true
	local token = {}
	bannerToken = token
	task.delay(3, function()
		if bannerToken == token then
			banner.Visible = false
		end
	end)
end

Remotes.Notify.OnClientEvent:Connect(function(text, color, big)
	if big then
		showBanner(text, color)
	else
		toast(text, color)
	end
end)

---------------------------------------------------------------------------
-- HUD: top bar
---------------------------------------------------------------------------
local topBar = UI.panel({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(360, 54), Parent = gui,
})
local topTitle = UI.label({ Size = UDim2.new(1, 0, 0.6, 0), Text = "THE OUTPOST", Parent = topBar })
local topSub = UI.label({
	Position = UDim2.fromScale(0, 0.6), Size = UDim2.new(1, 0, 0.36, 0), Font = UI.BodyFont, TextColor3 = C.Muted, Text = "", Parent = topBar,
})

local creditsPanel = UI.panel({ Position = UDim2.fromOffset(12, 64), Size = UDim2.fromOffset(200, 54), Parent = gui })
local creditsText = UI.label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26), Text = "0 cr", TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = creditsPanel })
local rankText = UI.label({ Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 18), Font = UI.BodyFont, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Text = "Rank 1", Parent = creditsPanel })

---------------------------------------------------------------------------
-- HUD: health, shield, ammo
---------------------------------------------------------------------------
local vitals = UI.panel({
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(260, 70), Parent = gui,
})
local function bar(y: number, color: Color3)
	local back = UI.new("Frame", {
		Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, 18), BackgroundColor3 = Color3.fromRGB(10, 10, 14), BorderSizePixel = 0, Parent = vitals,
	}, { UI.corner(5) })
	local fill = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, Parent = back }, { UI.corner(5) })
	local text = UI.label({ Size = UDim2.fromScale(1, 1), Font = UI.BodyFont, Text = "", Parent = back })
	return fill, text
end
local healthFill, healthText = bar(10, C.Green)
local shieldFill, shieldText = bar(40, C.Blue)

local weaponPanel = UI.panel({
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), Size = UDim2.fromOffset(250, 80), Parent = gui,
})
local weaponName = UI.label({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Right, Parent = weaponPanel })
local ammoText = UI.label({ Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 34), Text = "", TextXAlignment = Enum.TextXAlignment.Right, Parent = weaponPanel })
local slotText = UI.label({ Position = UDim2.fromOffset(10, 60), Size = UDim2.new(1, -20, 0, 16), Font = UI.BodyFont, TextColor3 = C.Muted, Text = "", TextXAlignment = Enum.TextXAlignment.Right, Parent = weaponPanel })

local progress = UI.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.6, 0), Size = UDim2.fromOffset(220, 26),
	BackgroundColor3 = Color3.fromRGB(10, 10, 14), BackgroundTransparency = 0.3, BorderSizePixel = 0, Visible = false, Parent = gui,
}, { UI.corner(6) })
local progressFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Orange, BorderSizePixel = 0, Parent = progress }, { UI.corner(6) })
local progressText = UI.label({ Size = UDim2.fromScale(1, 1), Font = UI.BodyFont, Text = "", Parent = progress })

-- Crosshair & hit marker
local crosshair = UI.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30),
	BackgroundTransparency = 1, Visible = false, Parent = gui,
})
for _, spec in { { 0.5, 0, 2, 8 }, { 0.5, 1, 2, 8 }, { 0, 0.5, 8, 2 }, { 1, 0.5, 8, 2 } } do
	UI.new("Frame", {
		AnchorPoint = Vector2.new(spec[1], spec[2]), Position = UDim2.fromScale(spec[1], spec[2]), Size = UDim2.fromOffset(spec[3], spec[4]),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = crosshair,
	}, { UI.stroke(Color3.new(0, 0, 0), 1) })
end
local hitMarker = UI.label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40),
	Text = "✕", TextColor3 = Color3.new(1, 1, 1), Visible = false, Parent = gui,
})
local damageNumber = UI.label({
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 24, 0.5, -10), Size = UDim2.fromOffset(80, 26),
	Text = "", TextColor3 = C.Gold, TextStrokeTransparency = 0.3, Visible = false, Parent = gui,
})
local vignette = UI.new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 0, 0), BackgroundTransparency = 1,
	BorderSizePixel = 0, ZIndex = 0, Parent = gui,
})

---------------------------------------------------------------------------
-- Action buttons (touch + quick access)
---------------------------------------------------------------------------
local buttonBar = UI.new("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -100), Size = UDim2.fromOffset(250, 130),
	BackgroundTransparency = 1, Parent = gui,
})
local firing = false
local fireButton = UI.button({
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(110, 110),
	Text = "FIRE", BackgroundColor3 = C.Red, Visible = isTouch, Parent = buttonBar, MaxTextSize = 30,
})
fireButton.MouseButton1Down:Connect(function()
	firing = true
end)
fireButton.MouseButton1Up:Connect(function()
	firing = false
end)
fireButton.MouseLeave:Connect(function()
	firing = false
end)
local smallButtons = UI.new("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -118, 1, 0), Size = UDim2.fromOffset(130, 130),
	BackgroundTransparency = 1, Parent = buttonBar,
}, { UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(62, 62), CellPadding = UDim2.fromOffset(4, 4) }) })

local openInventory -- forward declarations
local useFirstMed

UI.button({ Text = "RELOAD\n[R]", BackgroundColor3 = C.Gray, Parent = smallButtons, MaxTextSize = 14 }, function()
	action("Reload")
end)
UI.button({ Text = "SWAP\n[1/2]", BackgroundColor3 = C.Gray, Parent = smallButtons, MaxTextSize = 14 }, function()
	if inventory then
		action("Equip", if inventory.equipped == 1 then 2 else 1)
	end
end)
UI.button({ Text = "HEAL\n[H]", BackgroundColor3 = C.Green, Parent = smallButtons, MaxTextSize = 14 }, function()
	useFirstMed()
end)
UI.button({ Text = "BAG\n[TAB]", BackgroundColor3 = C.Blue, Parent = smallButtons, MaxTextSize = 14 }, function()
	openInventory()
end)

---------------------------------------------------------------------------
-- Modal panel system (one menu at a time)
---------------------------------------------------------------------------
local modal = UI.panel({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(700, 470),
	Visible = false, Parent = gui,
})
local modalTitle = UI.label({
	Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -90, 0, 36), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = modal,
})
local modalInfo = UI.label({
	Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -32, 0, 20), Font = UI.BodyFont, TextColor3 = C.Muted,
	Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = modal,
})
local modalBody = UI.new("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -32, 1, -82), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = modal,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

local currentPanel = nil
local renderers = {}

local function closeModal()
	if currentPanel == "Container" then
		action("CloseContainer")
		container = nil
	end
	currentPanel = nil
	modal.Visible = false
end
UI.button({
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(44, 40),
	Text = "X", BackgroundColor3 = C.Red, Parent = modal,
}, closeModal)

local function clearBody()
	for _, child in modalBody:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function render()
	if not currentPanel then
		return
	end
	clearBody()
	modalInfo.Text = ""
	local fn = renderers[currentPanel]
	if fn then
		fn()
	end
end

local function openPanel(name: string)
	currentPanel = name
	modal.Visible = true
	render()
end

-- One row: title, subtitle, and up to 3 buttons { text, color, callback }
local rowOrder = 0
local function row(title: string, sub: string?, buttons, titleColor: Color3?)
	rowOrder += 1
	local frame = UI.new("Frame", {
		LayoutOrder = rowOrder, Size = UDim2.new(1, -8, 0, if sub then 54 else 40), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0,
		Parent = modalBody,
	}, { UI.corner(8) })
	local buttonWidth = 0
	for i, b in buttons or {} do
		local width = b.width or 100
		buttonWidth += width + 6
		UI.button({
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(buttonWidth - width - 6) - 8, 0.5, 0), Size = UDim2.fromOffset(width, 34),
			Text = b[1], BackgroundColor3 = b[2] or C.Blue, MaxTextSize = 16, Parent = frame, LayoutOrder = i,
		}, b[3])
	end
	UI.label({
		Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -(buttonWidth + 20), 0, if sub then 26 else 32), Text = title,
		TextColor3 = titleColor or C.Text, TextXAlignment = Enum.TextXAlignment.Left, Font = UI.Font, Parent = frame,
	}, nil)
	if sub then
		UI.label({
			Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -(buttonWidth + 20), 0, 18), Text = sub, Font = UI.BodyFont,
			TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame,
		})
	end
	return frame
end

local function header(text: string)
	rowOrder += 1
	UI.label({
		LayoutOrder = rowOrder, Size = UDim2.new(1, -8, 0, 28), Text = text, TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = modalBody,
	})
end

local function slotLabel(slot): string
	return string.format("%s  x%d", itemName(slot.id), slot.count)
end

---------------------------------------------------------------------------
-- Raid inventory
---------------------------------------------------------------------------
renderers.Inventory = function()
	modalTitle.Text = "🎒 BACKPACK"
	if not inventory then
		header("You are not in a raid.")
		return
	end
	modalInfo.Text = string.format("Backpack %d/%d  •  Safe pocket %d/%d (kept if you die)",
		#inventory.backpack, inventory.capacity, #inventory.safe, inventory.safeCapacity)
	header("Weapons")
	for i, w in inventory.weapons do
		if w then
			row(string.format("[%d] %s%s", i, itemName(w.id), if inventory.equipped == i then "  (equipped)" else ""),
				string.format("Magazine %d", w.mag),
				{ { "EQUIP", C.Blue, function() action("Equip", i) end }, { "TO BAG", C.Gray, function() action("Holster", i) end } },
				rarityColor(w.id))
		else
			row(string.format("[%d] empty", i), nil, {})
		end
	end
	header("Backpack")
	for i, slot in inventory.backpack do
		local def = Items.Get(slot.id)
		local buttons = {}
		if def.category == "med" then
			table.insert(buttons, { "USE", C.Green, function() action("UseItem", i) end, width = 70 })
		elseif def.weapon then
			table.insert(buttons, { "EQUIP", C.Blue, function() action("UseItem", i) end, width = 70 })
		end
		table.insert(buttons, { "SAFE", C.Gold, function() action("ToSafe", i) end, width = 70 })
		table.insert(buttons, { "DROP", C.Red, function() action("DropItem", i) end, width = 70 })
		row(slotLabel(slot), string.format("%s • worth %d cr", def.rarity, def.value * slot.count), buttons, rarityColor(slot.id))
	end
	header("Safe pocket")
	for i, slot in inventory.safe do
		row(slotLabel(slot), nil, { { "TO BAG", C.Gray, function() action("FromSafe", i) end } }, rarityColor(slot.id))
	end
end

openInventory = function()
	if currentPanel == "Inventory" then
		closeModal()
	else
		openPanel("Inventory")
	end
end

useFirstMed = function()
	if not inventory then
		return
	end
	for i, slot in inventory.backpack do
		local def = Items.Get(slot.id)
		if def and def.category == "med" then
			action("UseItem", i)
			return
		end
	end
	toast("No meds in your backpack!", "Red")
end

---------------------------------------------------------------------------
-- Containers
---------------------------------------------------------------------------
renderers.Container = function()
	if not container then
		return
	end
	modalTitle.Text = "📦 " .. container.title
	if #container.contents == 0 then
		header("Empty.")
		return
	end
	row("Take everything", nil, { { "TAKE ALL", C.Green, function() action("Take", { id = container.id, index = 0 }) end, width = 130 } })
	for i, slot in container.contents do
		local def = Items.Get(slot.id)
		row(slotLabel(slot), def and string.format("%s • worth %d cr", def.rarity, def.value * slot.count),
			{ { "TAKE", C.Blue, function() action("Take", { id = container.id, index = i }) end } }, rarityColor(slot.id))
	end
end

Remotes.Container.OnClientEvent:Connect(function(kind, payload)
	if kind == "Open" then
		container = payload
		openPanel("Container")
	elseif kind == "Close" and currentPanel == "Container" then
		closeModal()
	end
end)

---------------------------------------------------------------------------
-- Outpost panels
---------------------------------------------------------------------------
renderers.Trader = function()
	modalTitle.Text = "🛒 TRADER"
	if not profile then
		return
	end
	modalInfo.Text = string.format("Credits: %s  •  Bought items go to your stash", UI.formatNumber(profile.credits))
	for i, offer in Items.TraderStock do
		local def = Items.Get(offer.id)
		local cost = def.price * offer.count
		local sub = if def.weapon
			then string.format("Damage %d • %d rpm • mag %d • %s", def.weapon.damage * def.weapon.pellets, def.weapon.rpm, def.weapon.mag, itemName(def.weapon.ammo))
			else def.category
		row(string.format("%dx %s", offer.count, def.name), sub, {
			{ UI.formatNumber(cost) .. " cr", if profile.credits >= cost then C.Green else C.Gray, function() action("Buy", i) end, width = 120 },
		}, rarityColor(offer.id))
	end
end

renderers.Stash = function()
	modalTitle.Text = "🗄️ STASH & LOADOUT"
	if not profile then
		return
	end
	local function loadoutCount()
		return #profile.loadout.items
	end
	modalInfo.Text = string.format("Stash %d/%d  •  Loadout backpack %d/%d  •  %s cr  •  sell bonus x%.2f",
		#profile.stash, profile.stashCapacity, loadoutCount(), profile.backpackCapacity, UI.formatNumber(profile.credits), profile.sellMultiplier)
	header("Loadout (taken into the next raid - lost if you die!)")
	for i, id in profile.loadout.weapons do
		if id ~= "" then
			row(string.format("Weapon %d: %s", i, itemName(id)), nil, { { "← STASH", C.Gray, function() action("ToStash", { kind = "weapon", index = i }) end } }, rarityColor(id))
		else
			row(string.format("Weapon %d: empty", i), "Move a weapon here from your stash", {})
		end
	end
	for i, slot in profile.loadout.items do
		row(slotLabel(slot), nil, { { "← STASH", C.Gray, function() action("ToStash", { kind = "item", index = i }) end } }, rarityColor(slot.id))
	end
	header("Stash")
	row("Sell all salvage", "Scrap, wires, cores... everything in the salvage category", {
		{ "SELL ALL", C.Gold, function() action("SellSalvage") end, width = 120 },
	})
	for i, slot in profile.stash do
		local def = Items.Get(slot.id)
		local value = math.floor(def.value * slot.count * profile.sellMultiplier)
		row(slotLabel(slot), string.format("%s • %s • sells for %d cr", def.rarity, def.category, value), {
			{ "LOADOUT →", C.Blue, function() action("ToLoadout", i) end, width = 110 },
			{ "SELL", C.Gold, function() action("Sell", i) end, width = 70 },
		}, rarityColor(slot.id))
	end
end

renderers.Workbench = function()
	if not profile then
		return
	end
	local tier = profile.bench
	local personal = player:GetAttribute("InQuarters") == true
	modalTitle.Text = string.format("🔧 WORKBENCH  (Level %d)", tier)
	modalInfo.Text = "Crafting uses materials from your stash."
	if personal then
		local nextCost = Config.BenchUpgrades[profile.quarters.benchTier + 1]
		if nextCost then
			local parts = {}
			for _, input in nextCost.items do
				table.insert(parts, input.count .. "x " .. itemName(input.id))
			end
			row(string.format("Upgrade to Level %d", profile.quarters.benchTier + 1), UI.formatNumber(nextCost.credits) .. " cr + " .. table.concat(parts, ", "), {
				{ "UPGRADE", C.Gold, function() action("UpgradeBench") end, width = 110 },
			}, C.Gold)
		end
	elseif tier < 2 then
		row("Want better recipes?", "Level 2 & 3 benches are built in your Private Quarters", {})
	end
	for i, recipe in Crafting.Recipes do
		local parts, canCraft = {}, recipe.tier <= tier
		for _, input in recipe.inputs do
			local have = 0
			for _, slot in profile.stash do
				if slot.id == input.id then
					have += slot.count
				end
			end
			if have < input.count then
				canCraft = false
			end
			table.insert(parts, string.format("%dx %s (%d)", input.count, itemName(input.id), have))
		end
		if recipe.credits > 0 then
			table.insert(parts, recipe.credits .. " cr")
		end
		local label = if recipe.tier > tier then "NEEDS LV" .. recipe.tier else "CRAFT"
		row(string.format("%dx %s", recipe.count, itemName(recipe.id)), table.concat(parts, " + "), {
			{ label, if canCraft then C.Green else C.Gray, function() action("Craft", i) end, width = 110 },
		}, rarityColor(recipe.id))
	end
end

local STORE = {
	{ kind = "Pass", key = "VIP", title = "⭐ VIP", desc = "+25% credits when selling, gold name" },
	{ kind = "Pass", key = "Quarters", title = "🏠 Private Quarters", desc = "Your own room, personal workbench, decorations" },
	{ kind = "Pass", key = "BigPockets", title = "🔒 Big Pockets", desc = "Safe pocket keeps 3 stacks when you die" },
	{ kind = "Pass", key = "ExtraStash", title = "🗄️ Extra Stash", desc = "+40 stash slots" },
	{ kind = "Product", key = "Insurance", title = "🛡️ Insurance", desc = "Next death: your weapons return to your stash" },
	{ kind = "Product", key = "CreditsSmall", title = "💰 1,000 Credits", desc = "" },
	{ kind = "Product", key = "CreditsMedium", title = "💰 3,000 Credits", desc = "" },
	{ kind = "Product", key = "CreditsLarge", title = "💰 10,000 Credits", desc = "" },
}

local function storeRows()
	local any = false
	for _, item in STORE do
		local id = if item.kind == "Pass" then Config.GamePasses[item.key] else Config.Products[item.key]
		if id and id ~= 0 then
			any = true
			local owned = item.kind == "Pass" and profile.passes[item.key]
			row(item.title, item.desc, {
				{ if owned then "OWNED" else "BUY (R$)", if owned then C.Gray else C.Gold, function()
					if owned then
						return
					end
					if item.kind == "Pass" then
						MarketplaceService:PromptGamePassPurchase(player, id)
					else
						MarketplaceService:PromptProductPurchase(player, id)
					end
				end, width = 120 },
			}, C.Gold)
		end
	end
	if not any then
		row("Store coming soon!", nil, {})
	end
end

renderers.Upgrades = function()
	modalTitle.Text = "⬆️ UPGRADES & STORE"
	if not profile then
		return
	end
	modalInfo.Text = "Credits: " .. UI.formatNumber(profile.credits)
	local function upgradeRow(which: string, label: string, costs, max: number, current: number, per: number, unit: string)
		local level = profile.upgrades[which]
		local cost = costs[level + 1]
		row(string.format("%s (Lv %d/%d)", label, level, max), string.format("Now %d %s", current, unit), {
			{ if cost then UI.formatNumber(cost) .. " cr" else "MAX", if cost and profile.credits >= cost then C.Green else C.Gray, function()
				action("Upgrade", which)
			end, width = 120 },
		})
	end
	header("Upgrades")
	upgradeRow("Backpack", "Backpack", Config.BackpackUpgradeCost, Config.BackpackMaxUpgrades, profile.backpackCapacity, Config.BackpackPerUpgrade, "slots")
	upgradeRow("Stash", "Stash", Config.StashUpgradeCost, Config.StashMaxUpgrades, profile.stashCapacity, Config.StashPerUpgrade, "slots")
	header("Store")
	storeRows()
	header("Your stats")
	local st = profile.stats
	row(string.format("Raids %d • Extracts %d • Kills %d • Deaths %d", st.raids, st.extracts, st.kills, st.deaths),
		"Best extraction: " .. UI.formatNumber(st.bestExtract) .. " cr", {})
end

renderers.MapSelect = function()
	modalTitle.Text = "🗺️ CHOOSE YOUR MAP"
	if not profile then
		return
	end
	local weapons = {}
	for _, id in profile.loadout.weapons do
		if id ~= "" then
			table.insert(weapons, itemName(id))
		end
	end
	modalInfo.Text = if #weapons > 0
		then "Loadout: " .. table.concat(weapons, ", ") .. string.format(" + %d item stacks", #profile.loadout.items)
		else "No weapon in your loadout - you'll get a free Scrap Pistol kit."
	for _, map in profile.maps do
		row(map.name .. "  •  Danger: " .. map.danger, map.desc .. string.format("  (%d raiders inside)", map.raiders), {
			{ "DEPLOY", C.Orange, function()
				closeModal()
				action("Deploy", map.id)
			end, width = 120 },
		}, C.Gold)
	end
end

renderers.QuartersBuy = function()
	modalTitle.Text = "🏠 PRIVATE QUARTERS"
	if not profile then
		return
	end
	modalInfo.Text = "Your own room: personal workbench (Lv2 & Lv3 recipes), stash access, furniture and trophies."
	row("Unlock with credits", UI.formatNumber(Config.QuartersCreditPrice) .. " credits", {
		{ "UNLOCK", if profile.credits >= Config.QuartersCreditPrice then C.Green else C.Gray, function() action("BuyQuarters") end, width = 120 },
	})
	if Config.GamePasses.Quarters ~= 0 then
		row("Unlock instantly", "Quarters game pass", {
			{ "BUY (R$)", C.Gold, function() MarketplaceService:PromptGamePassPurchase(player, Config.GamePasses.Quarters) end, width = 120 },
		})
	end
end

renderers.Decorate = function()
	modalTitle.Text = "🛋️ DECORATE"
	if not profile then
		return
	end
	local q = profile.quarters
	modalInfo.Text = "Buy furniture and trophies, then cycle each slot with ◀ ▶."
	header("Slots")
	local options = { "" }
	for _, id in Crafting.DecorOrder do
		if (q.ownedDecor[id] or 0) > 0 then
			table.insert(options, id)
		end
	end
	for slot = 1, Crafting.DecorSlots do
		local current = q.decor[slot] or ""
		local index = table.find(options, current) or 1
		local function cycle(step)
			local nextIndex = ((index - 1 + step) % #options) + 1
			action("PlaceDecor", { slot = slot, id = options[nextIndex] })
		end
		row(string.format("Slot %d: %s", slot, if current == "" then "empty" else Crafting.Decor[current].name), nil, {
			{ "◀", C.Gray, function() cycle(-1) end, width = 50 },
			{ "▶", C.Gray, function() cycle(1) end, width = 50 },
			{ "✕", C.Red, function() action("PlaceDecor", { slot = slot, id = "" }) end, width = 50 },
		})
	end
	header("Shop")
	for _, id in Crafting.DecorOrder do
		local def = Crafting.Decor[id]
		local parts = { UI.formatNumber(def.price) .. " cr" }
		for _, input in def.inputs or {} do
			table.insert(parts, input.count .. "x " .. itemName(input.id))
		end
		row(def.name .. string.format("  (owned %d)", q.ownedDecor[id] or 0), table.concat(parts, " + "), {
			{ "BUY", C.Green, function() action("BuyDecor", id) end, width = 90 },
		}, if def.inputs then C.Gold else C.Text)
	end
end

Remotes.OpenPanel.OnClientEvent:Connect(function(panel)
	if panel == "Exit" then
		return
	end
	openPanel(panel)
end)

Remotes.Profile.OnClientEvent:Connect(function(snapshot)
	profile = snapshot
	creditsText.Text = UI.formatNumber(snapshot.credits) .. " cr"
	rankText.Text = string.format("Raider Rank %d  (%d/%d XP)", snapshot.level, snapshot.xpInto, snapshot.xpNeed)
	if currentPanel and currentPanel ~= "Container" and currentPanel ~= "Inventory" then
		render()
	end
end)

Remotes.Inventory.OnClientEvent:Connect(function(snapshot)
	inventory = snapshot
	if currentPanel == "Inventory" then
		render()
	end
end)

---------------------------------------------------------------------------
-- Store button (always available outside raids)
---------------------------------------------------------------------------
local storeButton = UI.button({
	Position = UDim2.fromOffset(12, 124), Size = UDim2.fromOffset(200, 44), Text = "⭐ STORE & UPGRADES", BackgroundColor3 = C.Gold,
	TextColor3 = Color3.fromRGB(40, 30, 0), Parent = gui,
}, function()
	openPanel("Upgrades")
end)

---------------------------------------------------------------------------
-- Effects: tracers, lasers, hit markers, damage
---------------------------------------------------------------------------
local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "ClientEffects"
effectsFolder.Parent = workspace

local function tracer(from: Vector3, to: Vector3, color: Color3, width: number, life: number)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(width, width, length)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = effectsFolder
	TweenService:Create(p, TweenInfo.new(life), { Transparency = 1 }):Play()
	Debris:AddItem(p, life + 0.05)
end

Remotes.Effect.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Tracer" then
		tracer(a, b, Color3.fromRGB(255, 220, 140), 0.12, 0.08)
	elseif kind == "Laser" then
		tracer(a, b, Color3.fromRGB(255, 80, 40), 0.25, 0.15)
	elseif kind == "Hit" then
		hitMarker.Visible = true
		hitMarker.TextColor3 = if c then C.Red elseif b then C.Gold else Color3.new(1, 1, 1)
		damageNumber.Text = tostring(a) .. (if b then "!" else "")
		damageNumber.TextColor3 = if b then C.Gold else Color3.new(1, 1, 1)
		damageNumber.Visible = true
		task.delay(0.15, function()
			hitMarker.Visible = false
		end)
		task.delay(0.5, function()
			damageNumber.Visible = false
		end)
	elseif kind == "Hurt" then
		vignette.BackgroundTransparency = 0.7
		TweenService:Create(vignette, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	end
end)

---------------------------------------------------------------------------
-- Camera & character facing (over-the-shoulder in raids)
---------------------------------------------------------------------------
local freeMouse = false
local holdTrack = nil

local function applyCameraMode()
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if inRaid() then
		humanoid.CameraOffset = Vector3.new(2, 0.6, 0)
		humanoid.AutoRotate = false
		player.CameraMinZoomDistance = 7
		player.CameraMaxZoomDistance = 12
	else
		humanoid.CameraOffset = Vector3.zero
		humanoid.AutoRotate = true
		player.CameraMaxZoomDistance = 40
		player.CameraMinZoomDistance = 0.5
	end
end
player:GetAttributeChangedSignal("InRaid"):Connect(applyCameraMode)

local function playHoldAnimation(char: Model)
	local humanoid = char:WaitForChild("Humanoid", 10)
	local animator = humanoid and humanoid:WaitForChild("Animator", 10)
	if not animator then
		return
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://507768375" -- default R15 "holding a tool" pose
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if ok then
		holdTrack = track
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
	end
end

player.CharacterAdded:Connect(function(char)
	firing = false
	task.defer(applyCameraMode)
	playHoldAnimation(char)
end)
if player.Character then
	task.defer(applyCameraMode)
	task.spawn(playHoldAnimation, player.Character)
end

---------------------------------------------------------------------------
-- Shooting
---------------------------------------------------------------------------
local lastShot = 0
local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

local function weaponDef()
	local id = player:GetAttribute("WeaponId")
	local def = id and id ~= "" and Items.Get(id)
	return def and def.weapon
end

local function tryFire()
	local def = weaponDef()
	local char = player.Character
	if not def or not char or not inRaid() then
		return
	end
	if serverNow() < (player:GetAttribute("ReloadingUntil") or 0) or serverNow() < (player:GetAttribute("UsingUntil") or 0) then
		return
	end
	local mag = player:GetAttribute("Mag") or 0
	if mag <= 0 then
		firing = false
		action("Reload")
		return
	end
	local now = os.clock()
	if now - lastShot < 60 / def.rpm then
		return
	end
	lastShot = now
	if not def.auto then
		firing = false
	end
	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	Remotes.Fire:FireServer(origin, direction)

	-- local tracer right away so shooting feels instant
	aimParams.FilterDescendantsInstances = { char, effectsFolder }
	local result = workspace:Raycast(origin, direction * def.range, aimParams)
	local to = if result then result.Position else origin + direction * def.range
	local held = char:FindFirstChild("HeldWeapon")
	local muzzle = held and held:FindFirstChild("Muzzle")
	tracer(if muzzle then muzzle.Position else origin, to, Color3.fromRGB(255, 230, 150), 0.1, 0.06)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		if not processed and not modal.Visible then
			firing = true
		end
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		firing = false
	end
end)

local function bind(name: string, fn, ...)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			fn()
		end
		return Enum.ContextActionResult.Pass
	end, false, ...)
end
bind("SF_Reload", function() action("Reload") end, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
bind("SF_Slot1", function() action("Equip", 1) end, Enum.KeyCode.One)
bind("SF_Slot2", function() action("Equip", 2) end, Enum.KeyCode.Two)
bind("SF_Swap", function()
	if inventory then
		action("Equip", if inventory.equipped == 1 then 2 else 1)
	end
end, Enum.KeyCode.ButtonY)
bind("SF_Heal", function() useFirstMed() end, Enum.KeyCode.H, Enum.KeyCode.DPadUp)
bind("SF_Bag", function()
	if inRaid() then
		openInventory()
	end
end, Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect)
bind("SF_FreeMouse", function() freeMouse = not freeMouse end, Enum.KeyCode.LeftAlt)

---------------------------------------------------------------------------
-- Per-frame update
---------------------------------------------------------------------------
local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

RunService.RenderStepped:Connect(function()
	local raid = inRaid()
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")

	-- Mouse & facing
	local lockMouse = raid and not modal.Visible and not freeMouse and not isTouch
	UserInputService.MouseBehavior = if lockMouse then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not lockMouse
	if raid and root and humanoid and humanoid.Health > 0 then
		local look = workspace.CurrentCamera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end
	if holdTrack then
		local wantHold = raid and (player:GetAttribute("WeaponId") or "") ~= ""
		if wantHold and not holdTrack.IsPlaying then
			holdTrack:Play()
		elseif not wantHold and holdTrack.IsPlaying then
			holdTrack:Stop()
		end
	end

	if firing then
		tryFire()
	end

	-- HUD visibility
	crosshair.Visible = raid and not modal.Visible
	vitals.Visible = raid
	weaponPanel.Visible = raid
	buttonBar.Visible = raid
	storeButton.Visible = not raid
	creditsPanel.Visible = not raid

	if raid then
		local mapName = player:GetAttribute("MapId") or ""
		for _, map in Config.Maps do
			if map.id == mapName then
				mapName = map.name
			end
		end
		local left = (player:GetAttribute("RaidEndsAt") or 0) - serverNow()
		topTitle.Text = if left > 0 then "⏱ " .. formatTime(left) else "⚡ STORM!"
		topTitle.TextColor3 = if left < 60 then C.Red else C.Text
		topSub.Text = mapName .. "  •  find an EXTRACTION lift"
	elseif player:GetAttribute("InQuarters") then
		topTitle.Text = "PRIVATE QUARTERS"
		topTitle.TextColor3 = C.Text
		topSub.Text = "Workbench • Stash • Decorate"
	else
		topTitle.Text = "THE OUTPOST"
		topTitle.TextColor3 = C.Text
		topSub.Text = "Map Terminal → Deploy"
	end

	if humanoid then
		local hp = math.max(0, humanoid.Health)
		healthFill.Size = UDim2.fromScale(hp / humanoid.MaxHealth, 1)
		healthFill.BackgroundColor3 = if hp < 30 then C.Red else C.Green
		healthText.Text = string.format("HP %d", math.ceil(hp))
	end
	local shield = player:GetAttribute("Shield") or 0
	shieldFill.Size = UDim2.fromScale(shield / Config.MaxShield, 1)
	shieldText.Text = string.format("SHIELD %d", shield)

	local def = weaponDef()
	if def then
		weaponName.Text = itemName(player:GetAttribute("WeaponId"))
		local mag = player:GetAttribute("Mag") or 0
		ammoText.Text = string.format("%d / %d", mag, player:GetAttribute("Reserve") or 0)
		ammoText.TextColor3 = if mag == 0 then C.Red else C.Text
	else
		weaponName.Text = "No weapon"
		ammoText.Text = "-"
	end
	if inventory then
		local parts = {}
		for i, w in inventory.weapons do
			table.insert(parts, string.format("%s[%d] %s", if inventory.equipped == i then "▶" else "", i, if w then itemName(w.id) else "-"))
		end
		slotText.Text = table.concat(parts, "   ")
	end

	-- Reload / heal progress
	local now = serverNow()
	local reloadUntil = player:GetAttribute("ReloadingUntil") or 0
	local useUntil = player:GetAttribute("UsingUntil") or 0
	if raid and useUntil > now then
		progress.Visible = true
		progressText.Text = "Using " .. (player:GetAttribute("UsingItem") or "")
		progressFill.Size = UDim2.fromScale(1 - math.clamp((useUntil - now) / 5, 0, 1), 1)
	elseif raid and reloadUntil > now then
		progress.Visible = true
		progressText.Text = "Reloading..."
		progressFill.Size = UDim2.fromScale(1 - math.clamp((reloadUntil - now) / 3, 0, 1), 1)
	else
		progress.Visible = false
	end
end)

---------------------------------------------------------------------------
-- Welcome card
---------------------------------------------------------------------------
local welcome = UI.panel({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 360), Parent = gui,
})
UI.label({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 44), Text = "SCRAPFALL", TextColor3 = C.Orange, Parent = welcome })
UI.label({
	Position = UDim2.fromOffset(24, 62), Size = UDim2.new(1, -48, 0, 220), Font = UI.BodyFont, TextScaled = false, TextSize = 18,
	TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Text = "🏚️  You live in the OUTPOST, deep underground.\n"
		.. "🗺️  Use the MAP TERMINAL to deploy to the surface.\n"
		.. "📦  Search crates, fight the machines, take their parts.\n"
		.. "🛗  Call an EXTRACTION lift and survive until it arrives.\n"
		.. "☠️  Die and everything you carried is left behind.\n"
		.. "🔧  Craft at the workbench, build your own QUARTERS.\n\n"
		.. (if isTouch then "Tap FIRE to shoot. Drag to aim." else "Mouse to aim • Click to shoot • R reload • H heal • TAB bag • ALT free mouse"),
	Parent = welcome,
})
UI.button({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(220, 48),
	Text = "LET'S GO", BackgroundColor3 = C.Orange, Parent = welcome,
}, function()
	welcome.Visible = false
end)

action("RequestProfile")
