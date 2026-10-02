-- Thin wrapper around Roblox AnalyticsService. The data shows up in the
-- Creator Dashboard (Analytics -> Economy / Funnels / Custom) and tells us
-- whether the game is actually fun: where new players drop off, what they
-- spend coins on and how often they come back.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local Analytics = {}
local S

local funnelDone = {} -- [Player] = { [step] = true }

local FUNNEL = {
	[1] = "Joined",
	[2] = "BoardedFirstFlight",
	[3] = "HookedFirstLoot",
	[4] = "FirstCashOut",
	[5] = "BoughtFirstUpgrade",
}

local function safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[Analytics]", err)
	end
end

function Analytics.Funnel(player: Player, step: number, name: string?)
	local done = funnelDone[player]
	if not done or done[step] then
		return
	end
	done[step] = true
	safe(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name or FUNNEL[step])
	end)
end

local function balance(player: Player): number
	local data = S.Data.Get(player)
	return data and data.coins or 0
end

function Analytics.Earn(player: Player, amount: number, source: string)
	if source == "CashOut" then
		Analytics.Funnel(player, 4)
	end
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player, Enum.AnalyticsEconomyFlowType.Source, "Coins", amount, balance(player),
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name, source
		)
	end)
end

function Analytics.Spend(player: Player, amount: number, sku: string)
	Analytics.Funnel(player, 5)
	safe(function()
		AnalyticsService:LogEconomyEvent(
			player, Enum.AnalyticsEconomyFlowType.Sink, "Coins", amount, balance(player),
			Enum.AnalyticsEconomyTransactionType.Shop.Name, sku
		)
	end)
end

function Analytics.Purchase(player: Player, sku: string, robux: number?)
	safe(function()
		AnalyticsService:LogCustomEvent(player, "RobuxPurchase_" .. sku, robux or 0)
	end)
end

function Analytics.Progress(player: Player, name: string, value: number)
	safe(function()
		AnalyticsService:LogCustomEvent(player, name, value)
	end)
end

function Analytics.Custom(player: Player, name: string, value: number?)
	if string.sub(name, 1, 11) == "LootHooked_" then
		Analytics.Funnel(player, 3)
	end
	safe(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

function Analytics.Init(services)
	S = services
end

function Analytics.Start()
	local function onAdded(player)
		funnelDone[player] = {}
		Analytics.Funnel(player, 1)
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, player in Players:GetPlayers() do
		onAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		funnelDone[player] = nil
	end)
end

return Analytics
