-- OVERBOARD! client: HUD, backpack, voting, shop, notifications and input.
-- Works with mouse, touch and gamepad.

local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local LootDefs = require(Shared:WaitForChild("Loot"))
local Shop = require(Shared:WaitForChild("Shop"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local FlightState = ReplicatedStorage:WaitForChild("FlightState")
local UI = require(script.Parent:WaitForChild("UIKit"))
local C = UI.Colors

local function colorFor(name: string?): Color3
	if name and LootDefs.Rarities[name] then
		return LootDefs.Rarities[name].color
	end
	return C[name or "Text"] or C.Text
end

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function action(name: string, arg)
	Remotes.Action:FireServer(name, arg)
end

local profile = nil
local carried = {}

---------------------------------------------------------------------------
-- Root GUI + scaling for phones
---------------------------------------------------------------------------
local gui = UI.new("ScreenGui", {
	Name = "OverboardHUD",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local scale = UI.new("UIScale", { Parent = gui })
local function rescale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local vp = camera.ViewportSize
	scale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 720), 0.55, 1.1)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

---------------------------------------------------------------------------
-- Status bar (top)
---------------------------------------------------------------------------
local status = UI.panel({
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(460, 60),
	Parent = gui,
})
local statusTitle = UI.label({ Size = UDim2.new(1, 0, 0.6, 0), Text = "OVERBOARD!", Parent = status })
local statusSub = UI.label({
	Position = UDim2.fromScale(0, 0.58), Size = UDim2.new(1, 0, 0.38, 0),
	Font = UI.BodyFont, TextColor3 = C.Muted, Text = "", Parent = status,
})

local coinsLabel = UI.panel({
	Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(170, 44), Parent = gui,
})
local coinsText = UI.label({
	Size = UDim2.fromScale(1, 1), Text = "💰 0", TextColor3 = C.Gold, Parent = coinsLabel,
	Font = UI.Font,
})
UI.padding(6).Parent = coinsLabel

---------------------------------------------------------------------------
-- Altitude / fuel / load gauge (left)
---------------------------------------------------------------------------
local gauge = UI.panel({
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(110, 330),
	Visible = false, Parent = gui,
})
UI.label({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 22), Text = "ALTITUDE", Parent = gauge })
local altBack = UI.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 32), Size = UDim2.fromOffset(34, 190),
	BackgroundColor3 = Color3.fromRGB(10, 14, 28), BorderSizePixel = 0, Parent = gauge,
}, { UI.corner(8) })
local altFill = UI.new("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = C.Green, BorderSizePixel = 0, Parent = altBack,
}, { UI.corner(8) })
local altText = UI.label({ Position = UDim2.fromOffset(0, 226), Size = UDim2.new(1, 0, 0, 24), Text = "100", Parent = gauge })
local rateText = UI.label({
	Position = UDim2.fromOffset(0, 250), Size = UDim2.new(1, 0, 0, 18), Font = UI.BodyFont, Text = "", Parent = gauge,
})
local fuelText = UI.label({
	Position = UDim2.fromOffset(0, 274), Size = UDim2.new(1, 0, 0, 20), Font = UI.BodyFont,
	TextColor3 = C.Orange, Text = "⛽ 0", Parent = gauge,
})
local loadText = UI.label({
	Position = UDim2.fromOffset(0, 298), Size = UDim2.new(1, 0, 0, 20), Font = UI.BodyFont, Text = "", Parent = gauge,
})

---------------------------------------------------------------------------
-- Backpack (right)
---------------------------------------------------------------------------
local backpack = UI.panel({
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(230, 330),
	Visible = false, Parent = gui,
})
local backpackTitle = UI.label({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 26), Text = "🎒 0 / 10 kg", Parent = backpack })
UI.label({
	Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 16), Font = UI.BodyFont, TextColor3 = C.Muted,
	Text = "Cash out at the next Sky Port!", Parent = backpack,
})
local backpackList = UI.new("ScrollingFrame", {
	Position = UDim2.fromOffset(8, 54), Size = UDim2.new(1, -16, 1, -62), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = backpack,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function renderBackpack()
	for _, child in backpackList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local value = 0
	for index, item in carried do
		value += item.value
		local row = UI.new("Frame", {
			LayoutOrder = index, Size = UDim2.new(1, -6, 0, 40), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0,
			Parent = backpackList,
		}, { UI.corner(8) })
		UI.new("Frame", {
			Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = colorFor(item.rarity), BorderSizePixel = 0, Parent = row,
		}, { UI.corner(3) })
		UI.label({
			Position = UDim2.fromOffset(12, 2), Size = UDim2.new(1, -74, 0.55, 0), Text = item.name,
			TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = colorFor(item.rarity), Font = UI.BodyFont, Parent = row,
		})
		UI.label({
			Position = UDim2.new(0, 12, 0.55, 0), Size = UDim2.new(1, -74, 0.4, 0),
			Text = string.format("%d kg • %d 💰", item.weight, item.value), TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.Muted, Font = UI.BodyFont, Parent = row,
		})
		UI.button({
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(56, 30),
			Text = "TOSS", BackgroundColor3 = C.Red, MaxTextSize = 16, Parent = row,
		}, function()
			action("Drop", index)
		end)
	end
	local weight = player:GetAttribute("CarryWeight") or 0
	local cap = player:GetAttribute("CarryCap") or 10
	backpackTitle.Text = string.format("🎒 %d / %d kg  (%s 💰)", weight, cap, UI.formatNumber(value))
	backpackTitle.TextColor3 = if weight >= cap then C.Red else C.Text
end

Remotes.Carry.OnClientEvent:Connect(function(list)
	carried = list or {}
	renderBackpack()
end)
player:GetAttributeChangedSignal("CarryCap"):Connect(renderBackpack)

---------------------------------------------------------------------------
-- Toasts & banners
---------------------------------------------------------------------------
local toastHolder = UI.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76), Size = UDim2.fromOffset(560, 220),
	BackgroundTransparency = 1, Parent = gui,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

local function toast(text: string, color: string?)
	local children = toastHolder:GetChildren()
	local labels = {}
	for _, c in children do
		if c:IsA("TextLabel") then
			table.insert(labels, c)
		end
	end
	if #labels >= 5 then
		labels[1]:Destroy()
	end
	local label = UI.label({
		Size = UDim2.fromOffset(560, 30), BackgroundTransparency = 0.35, BackgroundColor3 = Color3.fromRGB(10, 14, 28),
		Text = text, TextColor3 = colorFor(color), Font = UI.BodyFont, Parent = toastHolder,
	})
	UI.corner(8).Parent = label
	UI.new("UITextSizeConstraint", { MaxTextSize = 20, Parent = label })
	task.delay(4.5, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.wait(0.45)
			label:Destroy()
		end
	end)
end

local banner = UI.label({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(820, 70),
	Text = "", TextStrokeTransparency = 0.2, Visible = false, Parent = gui,
})
local bannerToken
local function showBanner(text: string, color: string?)
	banner.Text = text
	banner.TextColor3 = colorFor(color)
	banner.Visible = true
	banner.Size = UDim2.fromOffset(600, 50)
	TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(820, 70) }):Play()
	local token = {}
	bannerToken = token
	task.delay(2.8, function()
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
-- Action bar (bottom)
---------------------------------------------------------------------------
local bar = UI.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(620, 60),
	BackgroundTransparency = 1, Parent = gui,
}, {
	UI.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local shoveButton = UI.button({
	LayoutOrder = 1, Size = UDim2.fromOffset(140, 56), Text = "🤚 SHOVE [Q]", BackgroundColor3 = C.Orange,
	Visible = false, Parent = bar,
}, function()
	action("Shove")
end)
local voteButton = UI.button({
	LayoutOrder = 2, Size = UDim2.fromOffset(140, 56), Text = "📯 VOTE HORN", BackgroundColor3 = C.Purple,
	Visible = false, Parent = bar,
}, function()
	action("CallVote")
end)
local shopButton = UI.button({
	LayoutOrder = 3, Size = UDim2.fromOffset(140, 56), Text = "🛒 SHOP", BackgroundColor3 = C.Green, Parent = bar,
})
local dailyButton = UI.button({
	LayoutOrder = 4, Size = UDim2.fromOffset(160, 56), Text = "🎁 DAILY", BackgroundColor3 = C.Gold,
	TextColor3 = Color3.fromRGB(40, 30, 0), Visible = false, Parent = bar,
}, function()
	action("ClaimDaily")
end)

ContextActionService:BindAction("OverboardShove", function(_, state)
	if state == Enum.UserInputState.Begin then
		action("Shove")
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)

---------------------------------------------------------------------------
-- Raft panel
---------------------------------------------------------------------------
local raftPanel = UI.panel({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -84), Size = UDim2.fromOffset(520, 74),
	Visible = false, Parent = gui,
})
local raftText = UI.label({
	Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -170, 1, -12), Font = UI.BodyFont,
	TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = raftPanel,
})
local rescueButton = UI.button({
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 50),
	Text = "🪢 RESCUE ROPE", BackgroundColor3 = C.Gold, TextColor3 = Color3.fromRGB(40, 30, 0),
	Visible = Config.Products.Rescue ~= 0, Parent = raftPanel,
}, function()
	if Config.Products.Rescue ~= 0 then
		MarketplaceService:PromptProductPurchase(player, Config.Products.Rescue)
	end
end)

---------------------------------------------------------------------------
-- Vote panel
---------------------------------------------------------------------------
local votePanel = UI.panel({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(440, 380),
	Visible = false, Parent = gui,
})
local voteTitle = UI.label({ Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 34), Text = "", Parent = votePanel })
local voteTimer = UI.label({
	Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 0, 22), Font = UI.BodyFont,
	TextColor3 = C.Muted, Text = "", Parent = votePanel,
})
local voteList = UI.new("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 74), Size = UDim2.new(1, -20, 1, -84), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = votePanel,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

local voteState = nil -- { endsAt, buttons = {[id]=button}, candidates, myVote, counts }

local function renderVoteButtons()
	if not voteState then
		return
	end
	for _, c in voteState.candidates do
		local button = voteState.buttons[c.id]
		local count = voteState.counts[tostring(c.id)] or 0
		local mine = voteState.myVote == c.id
		button.Text = string.format("%s%s  •  %d kg   [%d votes]%s", if c.bot then "🤖 " else "", c.name, c.weight, count, if mine then "  ✔" else "")
		button.BackgroundColor3 = if mine then C.Red else C.PanelLight
	end
end

Remotes.Vote.OnClientEvent:Connect(function(kind, payload)
	if kind == "Start" then
		for _, child in voteList:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		voteState = { endsAt = payload.endsAt, buttons = {}, candidates = payload.candidates, counts = {}, myVote = nil }
		voteTitle.Text = payload.reason
		local canVote = player:GetAttribute("Zone") == "Balloon"
		for i, c in payload.candidates do
			voteState.buttons[c.id] = UI.button({
				LayoutOrder = i, Size = UDim2.new(1, -8, 0, 44), BackgroundColor3 = C.PanelLight,
				Font = UI.BodyFont, MaxTextSize = 20, Text = c.name, Parent = voteList,
			}, function()
				if canVote and voteState then
					voteState.myVote = c.id
					action("Vote", c.id)
					renderVoteButtons()
				end
			end)
		end
		votePanel.Visible = true
		renderVoteButtons()
	elseif kind == "Tally" and voteState then
		voteState.counts = payload
		renderVoteButtons()
	elseif kind == "End" then
		if payload and payload.name then
			voteTitle.Text = "🌊 " .. payload.name .. " goes OVERBOARD!"
		elseif payload and payload.cancelled then
			voteTitle.Text = "Vote cancelled"
		else
			voteTitle.Text = "🤝 Nobody goes overboard!"
		end
		voteState = nil
		task.delay(1.8, function()
			if not voteState then
				votePanel.Visible = false
			end
		end)
	end
end)

---------------------------------------------------------------------------
-- Shop
---------------------------------------------------------------------------
local shopPanel = UI.panel({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(600, 440),
	Visible = false, Parent = gui,
})
UI.label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 38), Text = "🛒 SHOP", TextXAlignment = Enum.TextXAlignment.Left, Parent = shopPanel })
UI.button({
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(40, 40),
	Text = "X", BackgroundColor3 = C.Red, Parent = shopPanel,
}, function()
	shopPanel.Visible = false
end)
local tabs = UI.new("Frame", {
	Position = UDim2.fromOffset(16, 54), Size = UDim2.new(1, -32, 0, 40), BackgroundTransparency = 1, Parent = shopPanel,
}, { UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) })
local shopList = UI.new("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 102), Size = UDim2.new(1, -32, 1, -114), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Parent = shopPanel,
}, { UI.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

local currentTab = "Upgrades"

local function shopRow(order: number, title: string, desc: string, buttonText: string, buttonColor: Color3, onClick)
	local row = UI.new("Frame", {
		LayoutOrder = order, Size = UDim2.new(1, -8, 0, 64), BackgroundColor3 = C.PanelLight, BorderSizePixel = 0,
		Parent = shopList,
	}, { UI.corner(10) })
	UI.label({
		Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -190, 0, 26), Text = title,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	UI.label({
		Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -190, 0, 22), Text = desc, Font = UI.BodyFont,
		TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
	})
	local button = UI.button({
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(165, 46),
		Text = buttonText, BackgroundColor3 = buttonColor, MaxTextSize = 20, Parent = row,
	}, onClick)
	return row, button
end

local STORE_ITEMS = {
	{ kind = "Pass", key = "VIP", title = "⭐ VIP", desc = "2x coins on every cash-out, gold name, Storm trail" },
	{ kind = "Pass", key = "Lifejacket", title = "🦺 Lifejacket", desc = "Keep your loot when you go overboard or crash" },
	{ kind = "Pass", key = "MegaHook", title = "🪝 Mega Hook", desc = "+12 hook range and +10 kg backpack, forever" },
	{ kind = "Product", key = "EmergencyBurner", title = "🔥 Emergency Burner", desc = "+30 altitude for the WHOLE balloon. Be the hero!" },
	{ kind = "Product", key = "TreasureRain", title = "💎 Treasure Rain", desc = "3 chests, 2 seagulls, 2 eggs, 1 crown - for everyone" },
	{ kind = "Product", key = "Rescue", title = "🪢 Rescue Rope", desc = "Climb straight back from the raft to the balloon" },
	{ kind = "Product", key = "CoinsSmall", title = "💰 500 Coins", desc = "A handful of coins" },
	{ kind = "Product", key = "CoinsMedium", title = "💰 1,500 Coins", desc = "A bag of coins" },
	{ kind = "Product", key = "CoinsLarge", title = "💰 5,000 Coins", desc = "A treasure chest of coins" },
}
local priceCache = {}

local function renderShop()
	for _, child in shopList:GetChildren() do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if not profile then
		return
	end

	if currentTab == "Upgrades" then
		for i, id in Shop.UpgradeOrder do
			local def = Shop.Upgrades[id]
			local level = profile.upgrades[id] or 0
			local current = Shop.UpgradeValue(id, level)
			local maxed = level >= def.max
			local desc = if maxed
				then string.format("%s  •  %d%s (MAX)", def.desc, current, def.unit)
				else string.format("%d%s → %d%s", current, def.unit, Shop.UpgradeValue(id, level + 1), def.unit)
			local cost = Shop.UpgradeCost(id, level)
			shopRow(i, string.format("%s  (Lv %d/%d)", def.name, level, def.max), desc,
				if maxed then "MAX" else "💰 " .. UI.formatNumber(cost),
				if maxed then C.Gray elseif profile.coins >= cost then C.Green else C.Gray,
				function()
					action("BuyUpgrade", id)
				end)
		end
	elseif currentTab == "Trails" then
		shopRow(0, "No Trail", "Plain and simple", if profile.equippedTrail == "" then "EQUIPPED" else "EQUIP", C.Blue, function()
			action("EquipTrail", "")
		end)
		for i, trail in Shop.Trails do
			local owned = profile.trails[trail.id] or (trail.vip and profile.passes.VIP)
			local equipped = profile.equippedTrail == trail.id
			local text, color
			if equipped then
				text, color = "EQUIPPED", C.Gray
			elseif owned then
				text, color = "EQUIP", C.Blue
			elseif trail.vip then
				text, color = "VIP ONLY", C.Gold
			else
				text, color = "💰 " .. UI.formatNumber(trail.price), if profile.coins >= trail.price then C.Green else C.Gray
			end
			shopRow(i, trail.name, if trail.vip then "Exclusive to VIP" else "A shiny trail behind you", text, color, function()
				if owned then
					action("EquipTrail", trail.id)
				elseif trail.vip then
					if Config.GamePasses.VIP ~= 0 then
						MarketplaceService:PromptGamePassPurchase(player, Config.GamePasses.VIP)
					end
				else
					action("BuyTrail", trail.id)
				end
			end)
		end
	else
		local any = false
		for i, item in STORE_ITEMS do
			local id = if item.kind == "Pass" then Config.GamePasses[item.key] else Config.Products[item.key]
			if id and id ~= 0 then
				any = true
				local owned = item.kind == "Pass" and profile.passes[item.key]
				local tokens = item.kind == "Product" and profile.tokens[item.key] or 0
				local desc = item.desc .. (if tokens and tokens > 0 then string.format("  (saved: %d)", tokens) else "")
				local _, button = shopRow(i, item.title, desc, if owned then "OWNED ✔" else (priceCache[id] or "BUY"),
					if owned then C.Gray else C.Gold, function()
						if owned then
							return
						end
						if item.kind == "Pass" then
							MarketplaceService:PromptGamePassPurchase(player, id)
						else
							MarketplaceService:PromptProductPurchase(player, id)
						end
					end)
				button.TextColor3 = if owned then C.Text else Color3.fromRGB(40, 30, 0)
				if not priceCache[id] and not owned then
					task.spawn(function()
						local infoType = if item.kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
						local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
						if ok and info and info.PriceInRobux then
							priceCache[id] = "R$ " .. info.PriceInRobux
							if button.Parent then
								button.Text = priceCache[id]
							end
						end
					end)
				end
			end
		end
		if not any then
			UI.label({ Size = UDim2.new(1, 0, 0, 40), Text = "Store coming soon!", TextColor3 = C.Muted, Parent = shopList })
		end
	end
end

for i, name in { "Upgrades", "Trails", "Robux" } do
	UI.button({
		LayoutOrder = i, Size = UDim2.fromOffset(140, 40), Text = name, BackgroundColor3 = C.Blue, Parent = tabs,
	}, function()
		currentTab = name
		renderShop()
	end)
end

shopButton.Activated:Connect(function()
	shopPanel.Visible = not shopPanel.Visible
	if shopPanel.Visible then
		renderShop()
	end
end)

Remotes.Profile.OnClientEvent:Connect(function(snapshot)
	profile = snapshot
	coinsText.Text = "💰 " .. UI.formatNumber(snapshot.coins)
	dailyButton.Visible = snapshot.daily.available
	dailyButton.Text = string.format("🎁 DAILY +%d", snapshot.daily.reward)
	if shopPanel.Visible then
		renderShop()
	end
end)

---------------------------------------------------------------------------
-- How-to-play card (first thing a new player sees)
---------------------------------------------------------------------------
local howTo = UI.panel({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 330),
	Parent = gui,
})
UI.label({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 44), Text = "🎈 OVERBOARD!", TextColor3 = C.Gold, Parent = howTo })
UI.label({
	Position = UDim2.fromOffset(24, 62), Size = UDim2.new(1, -48, 0, 190), Font = UI.BodyFont, TextScaled = false,
	TextSize = 19, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Text = "🪝  Click floating loot to hook it\n"
		.. "⚖️  Heavy loot makes the balloon SINK\n"
		.. "🔥  Press E at the burner to climb (uses fuel)\n"
		.. "⚓  Loot only becomes coins at a SKY PORT\n"
		.. "🗳️  Too heavy? Vote someone OVERBOARD!\n"
		.. "🌊  Overboard? Fire fuel barrels back up to return",
	Parent = howTo,
})
UI.button({
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(220, 50),
	Text = "LET'S FLY!", BackgroundColor3 = C.Green, Parent = howTo,
}, function()
	howTo.Visible = false
end)

---------------------------------------------------------------------------
-- Fling (server asks us to launch our own character)
---------------------------------------------------------------------------
Remotes.Fling.OnClientEvent:Connect(function(velocity: Vector3)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	task.delay(0.9, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end)

---------------------------------------------------------------------------
-- HUD update loop
---------------------------------------------------------------------------
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.1 then
		return
	end
	accumulator = 0

	local state = FlightState:GetAttribute("State") or "Waiting"
	local zone = player:GetAttribute("Zone") or "Harbor"
	local distance = FlightState:GetAttribute("Distance") or 0
	local active = state == "Flying" or state == "Docked"

	if state == "Waiting" then
		statusTitle.Text = "Waiting for players..."
		statusSub.Text = ""
	elseif state == "Intermission" then
		statusTitle.Text = string.format("Next flight in %ds", FlightState:GetAttribute("Countdown") or 0)
		statusSub.Text = "Upgrade your gear in the SHOP!"
	elseif state == "Flying" then
		statusTitle.Text = "✈ " .. UI.formatNumber(distance) .. " m"
		local toPort = math.max(0, (FlightState:GetAttribute("NextPort") or 0) - distance)
		statusSub.Text = string.format("⚓ Next Sky Port in %s m", UI.formatNumber(toPort))
	elseif state == "Docked" then
		statusTitle.Text = "⚓ SKY PORT"
		local left = math.max(0, (FlightState:GetAttribute("DockEndsAt") or 0) - serverNow())
		statusSub.Text = string.format("Departing in %ds", math.ceil(left))
	elseif state == "Crashed" then
		statusTitle.Text = "💥 SPLASH!"
		statusSub.Text = "Back to the harbor..."
	end

	-- Gauge
	gauge.Visible = active
	if active then
		local alt = FlightState:GetAttribute("Altitude") or 0
		local frac = math.clamp(alt / Config.MaxAltitude, 0, 1)
		altFill.Size = UDim2.fromScale(1, frac)
		local color = if alt > 60 then C.Green elseif alt > Config.AutoVoteAltitude then C.Gold else C.Red
		if alt <= Config.AutoVoteAltitude and math.floor(os.clock() * 4) % 2 == 0 then
			color = Color3.fromRGB(255, 255, 255)
		end
		altFill.BackgroundColor3 = color
		altText.Text = string.format("%d", math.floor(alt))
		local rate = FlightState:GetAttribute("Rate") or 0
		rateText.Text = if rate >= 0 then string.format("▲ +%.1f/s", rate) else string.format("▼ %.1f/s", rate)
		rateText.TextColor3 = if rate >= 0 then C.Green else C.Red
		fuelText.Text = string.format("⛽ %d%s", FlightState:GetAttribute("Fuel") or 0, if FlightState:GetAttribute("Burning") then " 🔥" else "")
		local load = FlightState:GetAttribute("Load") or 0
		loadText.Text = string.format("Load %d%%", math.floor(load * 100))
		loadText.TextColor3 = if load > 1 then C.Red elseif load > 0.75 then C.Gold else C.Text
	end

	-- Backpack & actions
	local aboard = active and zone == "Balloon"
	backpack.Visible = aboard or #carried > 0
	voteButton.Visible = aboard
	shoveButton.Visible = aboard and Config.ShoveEnabled
	if shoveButton.Visible then
		local left = (player:GetAttribute("ShoveReadyAt") or 0) - serverNow()
		shoveButton.Text = if left > 0 then string.format("🤚 %ds", math.ceil(left)) else "🤚 SHOVE [Q]"
		shoveButton.BackgroundColor3 = if left > 0 then C.Gray else C.Orange
	end

	-- Raft
	raftPanel.Visible = active and zone == "Raft"
	if raftPanel.Visible then
		raftText.Text = string.format(
			"🌊 OVERBOARD! Fire fuel barrels from the 🚀 Sky Cannon: %d/%d\n(or wait for the next Sky Port)",
			player:GetAttribute("Deliveries") or 0, Config.DeliveriesToReturn
		)
	end
	rescueButton.Visible = Config.Products.Rescue ~= 0

	-- Vote timer
	if voteState then
		voteTimer.Text = string.format("%ds left - click a name to vote%s", math.max(0, math.ceil(voteState.endsAt - serverNow())),
			if zone == "Balloon" then "" else " (spectating)")
	end
end)

action("RequestProfile")
