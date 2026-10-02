-- Helpers for item lists: arrays of { id = string, count = number } where
-- each entry is one slot and respects the item's max stack size.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))

local Stacks = {}

local function maxStack(id: string): number
	local def = Items.Get(id)
	return def and def.stack or 1
end

-- Adds as much as fits; returns how many did NOT fit.
function Stacks.Add(list, capacity: number, id: string, count: number): number
	if not Items.Get(id) or count <= 0 then
		return count
	end
	local limit = maxStack(id)
	for _, slot in list do
		if count <= 0 then
			break
		end
		if slot.id == id and slot.count < limit then
			local add = math.min(limit - slot.count, count)
			slot.count += add
			count -= add
		end
	end
	while count > 0 and #list < capacity do
		local add = math.min(limit, count)
		table.insert(list, { id = id, count = add })
		count -= add
	end
	return count
end

-- How many would fit, without changing anything.
function Stacks.Fits(list, capacity: number, id: string, count: number): number
	local copy = {}
	for i, slot in list do
		copy[i] = { id = slot.id, count = slot.count }
	end
	return count - Stacks.Add(copy, capacity, id, count)
end

-- Removes up to count; returns how many were removed.
function Stacks.Remove(list, id: string, count: number): number
	local removed = 0
	for i = #list, 1, -1 do
		if removed >= count then
			break
		end
		local slot = list[i]
		if slot.id == id then
			local take = math.min(slot.count, count - removed)
			slot.count -= take
			removed += take
			if slot.count <= 0 then
				table.remove(list, i)
			end
		end
	end
	return removed
end

function Stacks.Count(list, id: string): number
	local total = 0
	for _, slot in list do
		if slot.id == id then
			total += slot.count
		end
	end
	return total
end

function Stacks.Copy(list)
	local copy = {}
	for i, slot in list do
		copy[i] = { id = slot.id, count = slot.count }
	end
	return copy
end

-- Total sell value of a list.
function Stacks.Value(list): number
	local total = 0
	for _, slot in list do
		local def = Items.Get(slot.id)
		if def then
			total += def.value * slot.count
		end
	end
	return total
end

return Stacks
