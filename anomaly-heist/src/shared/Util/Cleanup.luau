--!strict
-- Collects connections, instances, threads and callbacks so a controller or
-- per-player scope can be torn down in one call (respawn, leave, zone change).

export type Cleanup = {
	add: (self: Cleanup, item: any) -> any,
	destroy: (self: Cleanup) -> (),
	_items: { any },
	_destroyed: boolean,
}

local Cleanup = {}
Cleanup.__index = Cleanup

function Cleanup.new(): Cleanup
	return setmetatable({ _items = {}, _destroyed = false }, Cleanup) :: any
end

local function release(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "thread" then
		pcall(function()
			task.cancel(item)
		end)
	elseif kind == "function" then
		item()
	elseif kind == "table" and type(item.destroy) == "function" then
		item:destroy()
	end
end

function Cleanup.add(self: Cleanup, item: any): any
	if self._destroyed then
		release(item)
		return item
	end
	table.insert(self._items, item)
	return item
end

function Cleanup.destroy(self: Cleanup)
	if self._destroyed then
		return
	end
	self._destroyed = true
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		xpcall(release, function(err)
			warn("[Cleanup] release failed:", err)
		end, items[i])
	end
end

return Cleanup
