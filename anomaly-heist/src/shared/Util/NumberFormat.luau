--!strict
-- Locale-aware integer/decimal formatting. Luau has no Intl, so separators
-- are configured per language here and covered by unit tests. Digits stay
-- Western Arabic (0-9) everywhere; see docs/DECISIONS.md D-008.

local NumberFormat = {}

type Style = { group: string, decimal: string, indian: boolean? }

local NBSP = "\u{00A0}"
local NNBSP = "\u{202F}"

local DOT_COMMA: Style = { group = ".", decimal = "," }
local SPACE_COMMA: Style = { group = NBSP, decimal = "," }
local COMMA_DOT: Style = { group = ",", decimal = "." }

-- Exact locale overrides first, then language-level defaults.
local BY_LOCALE: { [string]: Style } = {
	["es-mx"] = COMMA_DOT,
	["pt-pt"] = SPACE_COMMA,
	["fr-fr"] = { group = NNBSP, decimal = "," },
	["fr-ca"] = SPACE_COMMA,
	["hi-in"] = { group = ",", decimal = ".", indian = true },
	["bn-bd"] = { group = ",", decimal = ".", indian = true },
	["de-ch"] = { group = "'", decimal = "." },
}

local BY_LANGUAGE: { [string]: Style } = {
	de = DOT_COMMA, es = DOT_COMMA, pt = DOT_COMMA, it = DOT_COMMA, nl = DOT_COMMA, id = DOT_COMMA,
	tr = DOT_COMMA, da = DOT_COMMA, el = DOT_COMMA, ro = DOT_COMMA, hr = DOT_COMMA, sl = DOT_COMMA,
	sr = DOT_COMMA, bs = DOT_COMMA, vi = DOT_COMMA,
	fr = SPACE_COMMA, ru = SPACE_COMMA, uk = SPACE_COMMA, bg = SPACE_COMMA, cs = SPACE_COMMA,
	sk = SPACE_COMMA, pl = SPACE_COMMA, fi = SPACE_COMMA, sv = SPACE_COMMA, nb = SPACE_COMMA,
	et = SPACE_COMMA, lv = SPACE_COMMA, lt = SPACE_COMMA, hu = SPACE_COMMA, kk = SPACE_COMMA,
	ka = SPACE_COMMA, sq = SPACE_COMMA,
}

function NumberFormat.styleFor(localeId: string): Style
	local id = string.lower(localeId)
	return BY_LOCALE[id] or BY_LANGUAGE[string.match(id, "^(%a+)") or ""] or COMMA_DOT
end

local function groupDigits(digits: string, style: Style): string
	local n = #digits
	if n <= 3 then
		return digits
	end
	local parts = {}
	local last3 = string.sub(digits, n - 2, n)
	local rest = string.sub(digits, 1, n - 3)
	local size = if style.indian then 2 else 3
	while #rest > size do
		table.insert(parts, 1, string.sub(rest, #rest - size + 1))
		rest = string.sub(rest, 1, #rest - size)
	end
	if #rest > 0 then
		table.insert(parts, 1, rest)
	end
	table.insert(parts, last3)
	return table.concat(parts, style.group)
end

-- Formats an integer (rounded toward zero). Non-finite values become "0".
function NumberFormat.integer(value: number, localeId: string): string
	if value ~= value or value == math.huge or value == -math.huge then
		return "0"
	end
	local style = NumberFormat.styleFor(localeId)
	local negative = value < 0
	local digits = string.format("%d", math.abs(if value < 0 then math.ceil(value) else math.floor(value)))
	return (if negative then "-" else "") .. groupDigits(digits, style)
end

function NumberFormat.decimal(value: number, places: number, localeId: string): string
	if value ~= value or value == math.huge or value == -math.huge then
		return "0"
	end
	local style = NumberFormat.styleFor(localeId)
	local text = string.format("%." .. math.clamp(places, 0, 6) .. "f", math.abs(value))
	local whole, fraction = string.match(text, "^(%d+)%.?(%d*)$")
	local out = groupDigits(whole or text, style)
	if fraction and #fraction > 0 then
		out ..= style.decimal .. fraction
	end
	return (if value < 0 then "-" else "") .. out
end

return NumberFormat
