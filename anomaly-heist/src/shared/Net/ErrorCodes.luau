--!strict
-- Error codes sent from server to client. The client turns them into
-- localized messages; the server never sends display text.

local ErrorCodes = {
	PortalCooldown = "error.portal_cooldown",
	PortalTooFar = "error.portal_too_far",
	PortalLocked = "error.portal_locked",
	TravelFailed = "error.travel_failed",
	ServerFailed = "error.server_failed",
}

export type Code = "PortalCooldown" | "PortalTooFar" | "PortalLocked" | "TravelFailed" | "ServerFailed"

-- Returns the localization key for a code, or nil for unknown codes.
function ErrorCodes.keyFor(code: string): string?
	local value = (ErrorCodes :: any)[code]
	if type(value) == "string" then
		return value
	end
	return nil
end

return ErrorCodes
