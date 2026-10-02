-- Game passes and developer products. Nothing random is ever sold.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MonetizationService = {}
local S

local ownership = {} -- [Player] = { [passName] = bool }
local groupMember = {} -- [Player] = bool
local productNameById = {}
local grants = {}

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
	grants.Insurance = function(player: Player, data)
		data.tokens.Insurance += 1
		S.Notify(player, "🛡️ Insurance active: your weapons come back the next time you die.", "Gold", true)
	end
	for name, amount in Config.ProductCredits do
		grants[name] = function(player: Player)
			S.Data.AddCredits(player, amount)
			S.Notify(player, string.format("💰 +%d credits! Thanks for supporting the game!", amount), "Gold", true)
		end
	end
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
				S.Data.MarkChanged(player)
				S.Analytics.Purchase(player, "Pass_" .. name, 0)
			end
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
