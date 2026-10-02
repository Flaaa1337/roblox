--!nocheck
-- Localization pipeline for ANOMALY HEIST (runs with Lune, not inside Roblox).
--
--   lune run tools/localization.luau            -- validate + generate
--   lune run tools/localization.luau --check    -- validate only, fail if generated files are stale
--
-- Inputs:
--   localization/registry-snapshot.language-codes.md  official Roblox registry (Roblox/creator-docs)
--   localization/locale-config.json                    project fallback chains, scripts, directions
--   localization/source.en-us.json                     US English source strings
--   localization/translations/<locale>.json            translations (draft/reviewed)
-- Outputs:
--   localization/locale-manifest.json
--   localization/coverage.json
--   localization/generated/Localization.csv            -> LocalizationTable (via Rojo)
--   src/shared/Generated/Strings.luau                  -> runtime source + translations + fallback chains

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local ROOT = process.args[1] == "--root" and process.args[2] or "."
local CHECK_ONLY = table.find(process.args, "--check") ~= nil
local errors, warnings = {}, {}

local function err(msg)
	table.insert(errors, msg)
end
local function warn_(msg)
	table.insert(warnings, msg)
end
local function path(p)
	return ROOT .. "/" .. p
end
local function readJson(p)
	return serde.decode("json", fs.readFile(path(p)))
end
local function sortedKeys(t)
	local keys = {}
	for k in t do
		if k ~= "_meta" then
			table.insert(keys, k)
		end
	end
	table.sort(keys)
	return keys
end

---------------------------------------------------------------------------
-- 1. Registry -> manifest
---------------------------------------------------------------------------
local registry = {}
do
	local md = fs.readFile(path("localization/registry-snapshot.language-codes.md"))
	local cells = {}
	for cell in md:gmatch("<td>(.-)</td>") do
		table.insert(cells, cell)
	end
	if #cells % 3 ~= 0 then
		err("registry snapshot: unexpected table shape (" .. #cells .. " cells)")
	end
	for i = 1, #cells, 3 do
		local name, code, locale = cells[i], cells[i + 1], cells[i + 2]
		local english, native = name:match("^(.-) %((.*)%)$")
		table.insert(registry, { languageCode = code, localeId = locale, englishName = english or name, nativeName = native or name })
	end
end
if #registry ~= 50 then
	warn_("registry snapshot lists " .. #registry .. " locales (spec expected 50) - review the manifest")
end

local config = readJson("localization/locale-config.json")
local source = readJson("localization/source.en-us.json")
local sourceKeys = sortedKeys(source)

local translations = {}
for _, file in fs.readDir(path("localization/translations")) do
	local locale = file:match("^(.+)%.json$")
	if locale then
		translations[locale] = readJson("localization/translations/" .. file)
	end
end

local registryById = {}
for _, entry in registry do
	if registryById[entry.localeId] then
		err("duplicate locale id in registry: " .. entry.localeId)
	end
	registryById[entry.localeId] = entry
end

---------------------------------------------------------------------------
-- 2. Validate source strings
---------------------------------------------------------------------------
local function placeholders(text)
	local set, list = {}, {}
	for name in text:gmatch("{([%w_]+)}") do
		if not set[name] then
			set[name] = true
			table.insert(list, name)
		end
	end
	table.sort(list)
	return table.concat(list, ",")
end

for _, key in sourceKeys do
	local entry = source[key]
	if not key:match("^[a-z0-9_]+%.[a-z0-9_.]+$") then
		err("source key has invalid format: " .. key)
	end
	if type(entry) ~= "table" or type(entry.text) ~= "string" or entry.text == "" then
		err("source entry missing text: " .. key)
	elseif type(entry.context) ~= "string" or entry.context == "" then
		err("source entry missing context: " .. key)
	end
end

---------------------------------------------------------------------------
-- 3. Validate translations
---------------------------------------------------------------------------
for locale, data in translations do
	if not registryById[locale] then
		err("translation file for locale not in registry: " .. locale)
	end
	for _, key in sortedKeys(data) do
		local entry = data[key]
		if not source[key] then
			err(locale .. ": key not in source: " .. key)
		elseif type(entry.text) ~= "string" or entry.text == "" then
			err(locale .. ": empty translation for " .. key)
		elseif placeholders(entry.text) ~= placeholders(source[key].text) then
			err(locale .. ": placeholder mismatch for " .. key .. " (" .. placeholders(entry.text) .. " vs " .. placeholders(source[key].text) .. ")")
		elseif entry.status ~= "draft" and entry.status ~= "reviewed" then
			err(locale .. ": status must be draft or reviewed for " .. key)
		end
	end
end

---------------------------------------------------------------------------
-- 4. Keys referenced in code must exist
---------------------------------------------------------------------------
local namespaces = {}
for _, key in sourceKeys do
	namespaces[key:match("^([a-z0-9_]+)%.")] = true
end
local used = {}
local function scan(dir)
	for _, name in fs.readDir(path(dir)) do
		local p = dir .. "/" .. name
		if fs.isDir(path(p)) then
			if name ~= "Generated" then
				scan(p)
			end
		elseif name:match("%.luau$") then
			local text = fs.readFile(path(p))
			for key in text:gmatch("\"([a-z0-9_]+%.[a-z0-9_.]+)\"") do
				local ns = key:match("^([a-z0-9_]+)%.")
				if namespaces[ns] and not key:match("%.luau$") then
					used[key] = true
					if not source[key] then
						err(p .. ": uses unknown string key " .. key)
					end
				end
			end
		end
	end
end
scan("src")
local unused = {}
for _, key in sourceKeys do
	if not used[key] then
		table.insert(unused, key)
	end
end

---------------------------------------------------------------------------
-- 5. Manifest + coverage
---------------------------------------------------------------------------
local today = os.date("!%Y-%m-%d")
local criticalTotal = 0
for _, key in sourceKeys do
	if source[key].critical then
		criticalTotal += 1
	end
end

local manifest = { _meta = {
	registrySource = "https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/localization/language-codes.md",
	registrySnapshot = "localization/registry-snapshot.language-codes.md",
	generatedBy = "tools/localization.luau",
	note = "A manifest entry is a coverage target, not a finished translation. See coverage.json.",
}, locales = {} }
local coverage = { _meta = { sourceKeys = #sourceKeys, criticalKeys = criticalTotal, note = "pending = no translations yet; English fallback is used." }, locales = {} }

for _, entry in registry do
	local id = entry.localeId
	local cfg = config.locales[id] or {}
	if not config.locales[id] then
		err("locale-config.json has no entry for " .. id)
	end
	local data = translations[id] or {}
	local translated, critical, reviewed = 0, 0, 0
	for _, key in sourceKeys do
		local t = data[key]
		if t then
			translated += 1
			if source[key].critical then
				critical += 1
			end
			if t.status == "reviewed" then
				reviewed += 1
			end
		end
	end
	local status
	if id == config.sourceLocale then
		status = "source"
	elseif cfg.blocked then
		status = "blocked"
	elseif translated == 0 then
		status = "pending"
	elseif reviewed == translated and translated == #sourceKeys then
		status = "reviewed"
	else
		status = "draft"
	end
	local isSource = id == config.sourceLocale
	table.insert(manifest.locales, {
		localeId = id,
		languageCode = entry.languageCode,
		englishName = entry.englishName,
		nativeName = entry.nativeName,
		script = cfg.script or "Latn",
		direction = cfg.direction or "ltr",
		fallback = cfg.fallback or {},
		coverageStatus = status,
		lastReviewed = (data._meta and data._meta.lastReviewed) or nil,
		manifestUpdated = today,
	})
	coverage.locales[id] = {
		status = status,
		allStrings = if isSource then 100 else math.floor(translated / #sourceKeys * 1000) / 10,
		criticalStrings = if isSource then 100 else (if criticalTotal > 0 then math.floor(critical / criticalTotal * 1000) / 10 else 100),
		reviewedStrings = if isSource then #sourceKeys else reviewed,
	}
end
for id in config.locales do
	if not registryById[id] then
		err("locale-config.json lists locale not in registry: " .. id)
	end
end

---------------------------------------------------------------------------
-- 6. Generated artifacts
---------------------------------------------------------------------------
local localeOrder = {}
for _, entry in registry do
	if entry.localeId ~= config.sourceLocale then
		table.insert(localeOrder, entry.localeId)
	end
end

local function csvField(s)
	return "\"" .. tostring(s or ""):gsub("\"", "\"\"") .. "\""
end
local csv = { table.concat({ "Key", "Source", "Context", "Example", table.unpack(localeOrder) }, ",") }
for _, key in sourceKeys do
	local row = { csvField(key), csvField(source[key].text), csvField(source[key].context), csvField("") }
	for _, locale in localeOrder do
		local t = translations[locale] and translations[locale][key]
		table.insert(row, csvField(t and t.text or ""))
	end
	table.insert(csv, table.concat(row, ","))
end
local csvText = table.concat(csv, "\n") .. "\n"

local function q(s)
	return string.format("%q", s)
end
local lua = {
	"--!strict",
	"-- GENERATED by tools/localization.luau - do not edit by hand.",
	"-- Source strings, translations and fallback chains for the runtime resolver.",
	"",
	"local Strings = {}",
	"",
	"Strings.sourceLocale = " .. q(config.sourceLocale),
	"",
	"Strings.source = {",
}
for _, key in sourceKeys do
	table.insert(lua, "\t[" .. q(key) .. "] = " .. q(source[key].text) .. ",")
end
table.insert(lua, "} :: { [string]: string }")
table.insert(lua, "")
table.insert(lua, "Strings.translations = {")
local translatedLocales = {}
for locale in translations do
	table.insert(translatedLocales, locale)
end
table.sort(translatedLocales)
for _, locale in translatedLocales do
	table.insert(lua, "\t[" .. q(locale) .. "] = {")
	for _, key in sortedKeys(translations[locale]) do
		table.insert(lua, "\t\t[" .. q(key) .. "] = " .. q(translations[locale][key].text) .. ",")
	end
	table.insert(lua, "\t},")
end
table.insert(lua, "} :: { [string]: { [string]: string } }")
table.insert(lua, "")
table.insert(lua, "-- localeId -> { fallback locale ids (before the source locale), direction }")
table.insert(lua, "Strings.locales = {")
for _, m in manifest.locales do
	local fb = {}
	for _, f in m.fallback do
		table.insert(fb, q(f))
	end
	table.insert(lua, string.format("\t[%s] = { fallback = { %s }, direction = %s },", q(m.localeId), table.concat(fb, ", "), q(m.direction)))
end
table.insert(lua, "} :: { [string]: { fallback: { string }, direction: string } }")
table.insert(lua, "")
table.insert(lua, "return Strings")
local luaText = table.concat(lua, "\n") .. "\n"

local manifestText = serde.encode("json", manifest, true) .. "\n"
local coverageText = serde.encode("json", coverage, true) .. "\n"

local outputs = {
	["localization/generated/Localization.csv"] = csvText,
	["src/shared/Generated/Strings.luau"] = luaText,
	["localization/locale-manifest.json"] = manifestText,
	["localization/coverage.json"] = coverageText,
}

---------------------------------------------------------------------------
-- 7. Report
---------------------------------------------------------------------------
for _, w in warnings do
	print("WARN  " .. w)
end
if #unused > 0 then
	print("INFO  " .. #unused .. " source keys not referenced in code yet (planned for later milestones): " .. table.concat(unused, ", "))
end
for _, e in errors do
	print("ERROR " .. e)
end

if #errors > 0 then
	print(string.format("FAIL  %d error(s)", #errors))
	process.exit(1)
end

local stale = {}
for p, text in outputs do
	local current = fs.isFile(path(p)) and fs.readFile(path(p)) or nil
	-- the manifest carries today's date; compare it without that field
	local function strip(s)
		return s and s:gsub("\"manifestUpdated\": \"[%d-]+\"", "") or s
	end
	if strip(current) ~= strip(text) then
		table.insert(stale, p)
		if not CHECK_ONLY then
			fs.writeFile(path(p), text)
		end
	end
end

local drafts = 0
for _, c in coverage.locales do
	if c.status == "draft" then
		drafts += 1
	end
end
print(string.format("OK    %d locales in manifest, %d source keys (%d critical), %d locales with draft translations, %d keys used in code",
	#registry, #sourceKeys, criticalTotal, drafts, #sourceKeys - #unused))
if CHECK_ONLY and #stale > 0 then
	print("FAIL  generated files are stale: " .. table.concat(stale, ", ") .. " - run tools/localization.luau")
	process.exit(1)
elseif #stale > 0 then
	print("WROTE " .. table.concat(stale, ", "))
end
