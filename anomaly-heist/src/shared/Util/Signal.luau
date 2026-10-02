--!strict
-- Minimal script signal for in-process events between controllers/services.

export type Connection = { disconnect: (self: Connection) -> (), _connected: boolean }
export type Signal<T...> = {
	connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	fire: (self: Signal<T...>, T...) -> (),
	destroy: (self: Signal<T...>) -> (),
	_handlers: { [Connection]: (T...) -> () },
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _handlers = {} }, Signal) :: any
end

function Signal.connect<T...>(self: Signal<T...>, fn: (T...) -> ()): Connection
	local handlers = self._handlers
	local connection
	connection = {
		_connected = true,
		disconnect = function(c: Connection)
			c._connected = false
			handlers[c] = nil
		end,
	} :: Connection
	handlers[connection] = fn
	return connection
end

function Signal.fire<T...>(self: Signal<T...>, ...: T...)
	for connection, fn in table.clone(self._handlers) do
		if connection._connected then
			task.spawn(fn, ...)
		end
	end
end

function Signal.destroy<T...>(self: Signal<T...>)
	table.clear(self._handlers)
end

return Signal
