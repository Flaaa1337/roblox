-- Game passes and developer products.
-- Every product always delivers something: if it can't be used right now
-- (e.g. Rescue Rope while you're not overboard) it is saved as a token and
-- used automatically at the right moment.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local MonetizationService = {}
local S, Config

local ownership = {} -- [Player] = { [passName] = bool }
local groupMember = {} -- [Player] = bool
local productNameById = {}

function MonetizationService.OwnsPass(player: Player, name: string): boolean
	local cache = ownership[player]
	return cache ~= nil and cache[name] == true
end

function MonetizationService.IsGroupMember(player: Player): boolean
	return groupMember[player] == true
end

local function refresh(player: Player)
	local cache = {}
	for name, id in Config.GamePasses do
		cache[name] = false
		if id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			cache[name] = ok and owns == true
		end
	end
	ownership[player] = cache
	if Config.GroupId ~= 0 then
		local ok, member = pcall(player.IsInGroup, player, Config.GroupId)
		groupMember[player] = ok and member == true
	end
	S.Data.MarkChanged(player)
end

-- Product grant functions. They must not yield for long and must not fail.
local grants = {}

grants.EmergencyBurner = function(player: Player, data)
	if S.Flight.IsActive() then
		S.Flight.EmergencyBurner(player)
	else
		data.tokens.EmergencyBurner += 1
		S.Notify(player, "🔥 Emergency Burner saved - it fires automatically when the next balloon gets low!", "Gold")
	end
end

grants.Rescue = function(player: Player, data)
	if not S.Flight.ReturnToBalloon(player, "🪢 Rescue Rope! Back on the balloon!") then
		data.tokens.Rescue += 1
		S.Notify(player, "🪢 Rescue Rope saved - it pulls you back up the next time you go overboard!", "Gold")
	end
end

grants.TreasureRain = function(player: Player, data)
	if S.Flight.GetState().state == "Flying" then
		S.Flight.TreasureRain(player)
	else
		data.tokens.TreasureRain += 1
		S.Notify(player, "💎 Treasure Rain saved - it starts right after the next lift-off!", "Gold")
	end
end

for name, amount in Config.ProductCoins do
	grants[name] = function(player: Player)
		S.Data.AddCoins(player, amount, false)
		S.Notify(player, string.format("💰 +%d coins! Thank you for supporting the game!", amount), "Gold", true)
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = S.Data.WaitForProfile(player, 10)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if table.find(data.receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local name = productNameById[receipt.ProductId]
	local grant = name and grants[name]
	if not grant then
		warn("[Monetization] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(grant, player, data)
	if not ok then
		warn("[Monetization] grant failed", name, err)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(data.receipts, receipt.PurchaseId)
	while #data.receipts > 50 do
		table.remove(data.receipts, 1)
	end
	S.Data.MarkChanged(player)
	S.Data.Save(player)
	S.Analytics.Purchase(player, name, receipt.CurrencySpent)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init(services)
	S = services
	Config = S.Config
	for name, id in Config.Products do
		if id ~= 0 then
			productNameById[id] = name
		end
	end
end

function MonetizationService.Start()
	Players.PlayerAdded:Connect(refresh)
	for _, player in Players:GetPlayers() do
		task.spawn(refresh, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ownership[player] = nil
		groupMember[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for name, id in Config.GamePasses do
			if id == passId then
				ownership[player] = ownership[player] or {}
				ownership[player][name] = true
				S.Notify(player, "🎉 " .. name .. " unlocked! Thank you!", "Gold", true)
				S.Flight.SyncCarry(player)
				S.ShopSvc.ApplyTrail(player)
				S.Data.MarkChanged(player)
				S.Analytics.Purchase(player, "Pass_" .. name, 0)
			end
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
