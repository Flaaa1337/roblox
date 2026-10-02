--!strict
-- Pure text resolver used by the client LocalizationController and by tests.
-- Fallback policy (spec 3.3):
--   selected locale -> configured fallback locales -> en-us source -> diagnostic
-- Never returns a raw key to the player.

local Strings = require(script.Parent.Parent.Generated.Strings)

local LocaleResolver = {}

export type Result = {
	text: string,
	locale: string, -- locale the text actually came from
	fellBack: boolean, -- true when a non-source player locale used a fallback
	missing: boolean, -- key unknown: text is empty and a diagnostic is needed
}

function LocaleResolver.normalize(localeId: string?): string
	local id = string.lower(localeId or "")
	id = string.gsub(id, "_", "-")
	if Strings.locales[id] then
		return id
	end
	-- Roblox may report a bare language ("es") or an unlisted region; map to
	-- the first manifest locale with that language.
	local language = string.match(id, "^(%a+)")
	if language then
		local candidates = {}
		for candidate in Strings.locales do
			if string.match(candidate, "^(%a+)") == language then
				table.insert(candidates, candidate)
			end
		end
		table.sort(candidates)
		if #candidates > 0 then
			return candidates[1]
		end
	end
	return Strings.sourceLocale
end

function LocaleResolver.isRightToLeft(localeId: string): boolean
	local entry = Strings.locales[LocaleResolver.normalize(localeId)]
	return entry ~= nil and entry.direction == "rtl"
end

-- Ordered list of locales to try for a player locale.
function LocaleResolver.chain(localeId: string): { string }
	local id = LocaleResolver.normalize(localeId)
	local chain = { id }
	local entry = Strings.locales[id]
	if entry then
		for _, fallback in entry.fallback do
			if not table.find(chain, fallback) then
				table.insert(chain, fallback)
			end
		end
	end
	if not table.find(chain, Strings.sourceLocale) then
		table.insert(chain, Strings.sourceLocale)
	end
	return chain
end

function LocaleResolver.format(template: string, params: { [string]: any }?): string
	return (string.gsub(template, "{([%w_]+)}", function(name: string)
		local value = params and params[name]
		if value == nil then
			return ""
		end
		return tostring(value)
	end))
end

-- Makes text ~50% longer with accented letters, for layout stress tests.
function LocaleResolver.pseudoLong(text: string): string
	local accents = { a = "á", e = "é", i = "í", o = "ö", u = "ü", A = "Å", E = "É", O = "Ø" }
	local stretched = string.gsub(text, "[aeiouAEO]", function(c: string)
		return accents[c] .. c
	end)
	return "[" .. stretched .. " ~~]"
end

function LocaleResolver.resolve(localeId: string, key: string, params: { [string]: any }?): Result
	local requested = LocaleResolver.normalize(localeId)
	for _, locale in LocaleResolver.chain(requested) do
		local text: string?
		if locale == Strings.sourceLocale then
			text = Strings.source[key]
		else
			local t = Strings.translations[locale]
			text = t and t[key]
		end
		if text then
			return {
				text = LocaleResolver.format(text, params),
				locale = locale,
				fellBack = locale ~= requested and requested ~= Strings.sourceLocale,
				missing = false,
			}
		end
	end
	return { text = "", locale = Strings.sourceLocale, fellBack = true, missing = true }
end

return LocaleResolver
