-- What a raider carries DURING a raid: two weapon slots, a backpack and a
-- small safe pocket (kept even if you die). Everything here is at risk.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))

local Inventory = {}
local S, Stacks

local inventories = {} -- [Player] = inv

function Inventory.Capacity(player: Player): number
	local data = S.Data.Get(player)
	local level = data and data.upgrades.Backpack or 0
	return Config.BackpackBase + level * Config.BackpackPerUpgrade
end

function Inventory.SafeCapacity(player: Player): number
	return if S.Monetization.OwnsPass(player, "BigPockets") then Config.BigPocketsSlots else Config.SafePocketSlots
end

function Inventory.Get(player: Player)
	return inventories[player]
end

local function snapshot(inv, player)
	local weapons = {}
	for i = 1, Config.WeaponSlots do
		local w = inv.weapons[i]
		weapons[i] = if w then { id = w.id, mag = w.mag } else false
	end
	return {
		weapons = weapons,
		equipped = inv.equipped,
		backpack = inv.backpack,
		safe = inv.safe,
		capacity = Inventory.Capacity(player),
		safeCapacity = Inventory.SafeCapacity(player),
	}
end

function Inventory.UpdateWeaponAttributes(player: Player)
	local inv = inventories[player]
	local weapon = inv and inv.weapons[inv.equipped]
	if not weapon then
		player:SetAttribute("WeaponId", "")
		player:SetAttribute("Mag", 0)
		player:SetAttribute("Reserve", 0)
		return
	end
	local def = Items.Get(weapon.id).weapon
	player:SetAttribute("WeaponId", weapon.id)
	player:SetAttribute("Mag", weapon.mag)
	player:SetAttribute("MagMax", def.mag)
	player:SetAttribute("Reserve", Stacks.Count(inv.backpack, def.ammo))
end

function Inventory.Sync(player: Player)
	local inv = inventories[player]
	if inv then
		S.Remotes.Inventory:FireClient(player, snapshot(inv, player))
	else
		S.Remotes.Inventory:FireClient(player, nil)
	end
	Inventory.UpdateWeaponAttributes(player)
	if S.Combat then
		S.Combat.RefreshWeaponModel(player)
	end
end

-- Builds the raid inventory from the saved loadout.
function Inventory.Create(player: Player, loadout)
	local inv = { weapons = {}, equipped = 1, backpack = {}, safe = {} }
	for i = 1, Config.WeaponSlots do
		local id = loadout.weapons[i]
		local def = id and id ~= "" and Items.Get(id)
		inv.weapons[i] = if def and def.weapon then { id = id, mag = def.weapon.mag } else false
	end
	local capacity = Inventory.Capacity(player)
	for _, slot in loadout.items do
		Stacks.Add(inv.backpack, capacity, slot.id, slot.count)
	end
	if not inv.weapons[1] and inv.weapons[2] then
		inv.equipped = 2
	end
	inventories[player] = inv
	Inventory.Sync(player)
	return inv
end

function Inventory.Clear(player: Player)
	inventories[player] = nil
	Inventory.Sync(player)
end

-- Gives an item to a raider; returns how many did NOT fit.
function Inventory.Give(player: Player, id: string, count: number): number
	local inv = inventories[player]
	local def = Items.Get(id)
	if not inv or not def then
		return count
	end
	if def.weapon then
		for i = 1, Config.WeaponSlots do
			if count > 0 and not inv.weapons[i] then
				inv.weapons[i] = { id = id, mag = 0 }
				count -= 1
			end
		end
	end
	local left = Stacks.Add(inv.backpack, Inventory.Capacity(player), id, count)
	Inventory.Sync(player)
	return left
end

-- Everything the raider has, as a flat item list (weapons included).
function Inventory.AllItems(inv, includeSafe: boolean)
	local list = {}
	for i = 1, Config.WeaponSlots do
		local w = inv.weapons[i]
		if w then
			table.insert(list, { id = w.id, count = 1 })
		end
	end
	for _, slot in inv.backpack do
		table.insert(list, { id = slot.id, count = slot.count })
	end
	if includeSafe then
		for _, slot in inv.safe do
			table.insert(list, { id = slot.id, count = slot.count })
		end
	end
	return list
end

function Inventory.ToSafe(player: Player, index)
	local inv = inventories[player]
	if not inv or type(index) ~= "number" then
		return
	end
	local slot = inv.backpack[index]
	if not slot then
		return
	end
	if #inv.safe >= Inventory.SafeCapacity(player) then
		S.Notify(player, "Safe pocket is full.", "Red")
		return
	end
	table.remove(inv.backpack, index)
	table.insert(inv.safe, slot)
	Inventory.Sync(player)
end

function Inventory.FromSafe(player: Player, index)
	local inv = inventories[player]
	if not inv or type(index) ~= "number" then
		return
	end
	local slot = inv.safe[index]
	if not slot then
		return
	end
	if #inv.backpack >= Inventory.Capacity(player) then
		S.Notify(player, "Backpack is full.", "Red")
		return
	end
	table.remove(inv.safe, index)
	table.insert(inv.backpack, slot)
	Inventory.Sync(player)
end

-- Drop a backpack slot on the ground as a bag others can loot.
function Inventory.Drop(player: Player, index)
	local inv = inventories[player]
	local root = S.GetRoot(player)
	if not inv or not root or type(index) ~= "number" or not inv.backpack[index] then
		return
	end
	local slot = table.remove(inv.backpack, index)
	S.Loot.SpawnTemporary(root.CFrame * CFrame.new(0, -2.5, -3), "DeathCache", { slot }, player:GetAttribute("MapId"), "Dropped Bag")
	Inventory.Sync(player)
end

-- Move a weapon from a weapon slot into the backpack (to swap for a new one).
function Inventory.Holster(player: Player, slotIndex)
	local inv = inventories[player]
	if not inv or type(slotIndex) ~= "number" then
		return
	end
	local w = inv.weapons[slotIndex]
	if not w then
		return
	end
	if #inv.backpack >= Inventory.Capacity(player) then
		S.Notify(player, "Backpack is full.", "Red")
		return
	end
	local def = Items.Get(w.id).weapon
	if w.mag > 0 then
		Stacks.Add(inv.backpack, Inventory.Capacity(player), def.ammo, w.mag)
	end
	table.insert(inv.backpack, { id = w.id, count = 1 })
	inv.weapons[slotIndex] = false
	Inventory.Sync(player)
end

-- Equip a weapon from the backpack into an empty weapon slot.
function Inventory.EquipFromBackpack(player: Player, index)
	local inv = inventories[player]
	if not inv or type(index) ~= "number" then
		return
	end
	local slot = inv.backpack[index]
	local def = slot and Items.Get(slot.id)
	if not def or not def.weapon then
		return
	end
	for i = 1, Config.WeaponSlots do
		if not inv.weapons[i] then
			table.remove(inv.backpack, index)
			inv.weapons[i] = { id = slot.id, mag = 0 }
			inv.equipped = i
			Inventory.Sync(player)
			return
		end
	end
	S.Notify(player, "Both weapon slots are full - holster one first.", "Red")
end

function Inventory.Init(services)
	S = services
	Stacks = S.Stacks
end

-- Called by RaidService after it has handled a leaving player's items.
function Inventory.Forget(player: Player)
	inventories[player] = nil
end

return Inventory
