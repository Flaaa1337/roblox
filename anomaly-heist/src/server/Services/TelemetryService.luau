--!strict
-- Thin analytics wrapper (spec section 21). Missing or failing analytics
-- must never break gameplay, so every call is protected.

local AnalyticsService = game:GetService("AnalyticsService")

local TelemetryService = {}

local ALLOWED = {
	onboarding_started = true,
	zone_entered = true,
	localization_fallback = true,
}

function TelemetryService.custom(player: Player, eventName: string)
	if not ALLOWED[eventName] then
		warn("[Telemetry] unknown event name:", eventName)
		return
	end
	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, eventName)
	end)
	if not ok then
		warn("[Telemetry] event failed (gameplay continues):", eventName, err)
	end
end

return TelemetryService
