--!strict
-- Per-key cooldown/rate limiting for server-side request handling.

export type RateLimiter = {
	tryUse: (self: RateLimiter, key: any) -> boolean,
	remaining: (self: RateLimiter, key: any) -> number,
	forget: (self: RateLimiter, key: any) -> (),
	_cooldown: number,
	_last: { [any]: number },
	_clock: () -> number,
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(cooldownSeconds: number, clock: (() -> number)?): RateLimiter
	return setmetatable({ _cooldown = cooldownSeconds, _last = {}, _clock = clock or os.clock }, RateLimiter) :: any
end

function RateLimiter.tryUse(self: RateLimiter, key: any): boolean
	local now = self._clock()
	local last = self._last[key]
	if last and now - last < self._cooldown then
		return false
	end
	self._last[key] = now
	return true
end

function RateLimiter.remaining(self: RateLimiter, key: any): number
	local last = self._last[key]
	if not last then
		return 0
	end
	return math.max(0, self._cooldown - (self._clock() - last))
end

function RateLimiter.forget(self: RateLimiter, key: any)
	self._last[key] = nil
end

return RateLimiter
