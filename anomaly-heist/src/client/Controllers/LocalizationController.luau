--!strict
-- Resolves player-facing text (spec 3.3). Order:
--   bundled translation for the player's locale -> configured fallback locales
--   -> Roblox Translator (cloud/automatic translations, if any) -> en-us source.
-- Also localizes world signs and proximity prompts that carry text keys, and
-- refreshes everything when the player changes language.
--
-- Studio-only stress test: set the Workspace attribute "AH_PseudoLocale" to
-- "long" (+50% length) or "rtl" (Arabic draft + mirrored HUD) before Play,
-- or FeatureFlags.studioPseudoLocale. Ignored in live servers.

local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local LocaleResolver = require(Shared.Util.LocaleResolver)
local Strings = require(Shared.Generated.Strings)
local FeatureFlags = require(Shared.Config.FeatureFlags)
local Signal = require(Shared.Util.Signal)
local Cleanup = require(Shared.Util.Cleanup)

local LocalizationController = {}

local player = Players.LocalPlayer
local translator: Translator? = nil
local currentLocale = "en-us"
local pseudo = "off"
local fallbackUsed = false
local warnedMissing: { [string]: boolean } = {}

LocalizationController.changed = Signal.new()
LocalizationController.fallbackNoticed = Signal.new()

local function pseudoMode(): string
	if not RunService:IsStudio() then
		return "off"
	end
	local attr = workspace:GetAttribute("AH_PseudoLocale")
	if attr == "long" or attr == "rtl" then
		return attr
	end
	return FeatureFlags.studioPseudoLocale
end

local function detectLocale(): string
	if translator then
		return LocaleResolver.normalize(translator.LocaleId)
	end
	local ok, id = pcall(function()
		return player.LocaleId
	end)
	return LocaleResolver.normalize(if ok then id else nil)
end

function LocalizationController.locale(): string
	return if pseudo == "rtl" then "ar-001" else currentLocale
end

function LocalizationController.isRightToLeft(): boolean
	return LocaleResolver.isRightToLeft(LocalizationController.locale())
end

-- Main lookup. Never returns a raw key; an unknown key yields "".
function LocalizationController.t(key: string, params: { [string]: any }?): string
	local locale = LocalizationController.locale()
	local result = LocaleResolver.resolve(locale, key, params)
	if result.missing then
		if not warnedMissing[key] then
			warnedMissing[key] = true
			warn("[Localization] unknown string key:", key)
		end
		return ""
	end
	local text = result.text
	if result.fellBack and translator and pseudo == "off" then
		-- the platform may hold cloud or automatic translations we don't bundle
		local ok, platformText = pcall(function()
			return (translator :: Translator):FormatByKey(key, params or {})
		end)
		local englishText = LocaleResolver.format(Strings.source[key] or "", params)
		if ok and type(platformText) == "string" and platformText ~= "" and platformText ~= englishText then
			text = platformText
		elseif not fallbackUsed then
			fallbackUsed = true
			LocalizationController.fallbackNoticed:fire()
		end
	end
	if pseudo == "long" then
		text = LocaleResolver.pseudoLong(text)
	end
	return text
end

function LocalizationController.usedFallback(): boolean
	return fallbackUsed
end

-- Resolves "@key" parameter references into localized text.
local function resolveParams(instance: Instance, prefix: string): { [string]: any }
	local params: { [string]: any } = {}
	for name, value in instance:GetAttributes() do
		local paramName = string.match(name, "^" .. prefix .. "(.+)$")
		if paramName then
			local text = if type(value) == "string" then value else nil
			if text and string.sub(text, 1, 1) == "@" then
				params[paramName] = LocalizationController.t(string.sub(text, 2))
			else
				params[paramName] = value
			end
		end
	end
	return params
end

---------------------------------------------------------------------------
-- World text (signs) and proximity prompts
---------------------------------------------------------------------------
local worldScopes: { [Instance]: Cleanup.Cleanup } = {}

local function applyWorldText(label: Instance)
	if not label:IsA("TextLabel") then
		return
	end
	local key = label:GetAttribute("TextKey")
	local selfKey = label:GetAttribute("SelfKey")
	if type(selfKey) == "string" and label:GetAttribute("OwnerUserId") == player.UserId then
		key = selfKey
	end
	if type(key) == "string" then
		label.Text = LocalizationController.t(key, resolveParams(label, "Param_"))
	end
end

local function applyPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local actionKey = prompt:GetAttribute("ActionKey")
	local objectKey = prompt:GetAttribute("ObjectKey")
	if type(actionKey) == "string" then
		prompt.ActionText = LocalizationController.t(actionKey, resolveParams(prompt, "ActionParam_"))
	end
	if type(objectKey) == "string" then
		prompt.ObjectText = LocalizationController.t(objectKey, resolveParams(prompt, "ObjectParam_"))
	end
end

local function track(instance: Instance, apply: (Instance) -> ())
	if worldScopes[instance] then
		return
	end
	local scope = Cleanup.new()
	worldScopes[instance] = scope
	scope:add(instance.AttributeChanged:Connect(function()
		apply(instance)
	end))
	apply(instance)
end

local function untrack(instance: Instance)
	local scope = worldScopes[instance]
	if scope then
		scope:destroy()
		worldScopes[instance] = nil
	end
end

local function watchTag(tag: string, apply: (Instance) -> ())
	-- instances stream in and out; handle both directions
	for _, instance in CollectionService:GetTagged(tag) do
		track(instance, apply)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		track(instance, apply)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
end

local function refreshAll()
	for _, label in CollectionService:GetTagged("AH_LocalizedText") do
		applyWorldText(label)
	end
	for _, prompt in CollectionService:GetTagged("AH_LocalizedPrompt") do
		applyPrompt(prompt)
	end
	LocalizationController.changed:fire()
end

function LocalizationController.init()
	pseudo = pseudoMode()
	local ok, result = pcall(function()
		return LocalizationService:GetTranslatorForPlayerAsync(player)
	end)
	if ok then
		translator = result
	else
		warn("[Localization] translator unavailable, using bundled strings:", result)
	end
	currentLocale = detectLocale()
	if pseudo ~= "off" then
		print("[Localization] Studio pseudo-locale active:", pseudo)
	end
end

function LocalizationController.start()
	watchTag("AH_LocalizedText", applyWorldText)
	watchTag("AH_LocalizedPrompt", applyPrompt)

	local function onLocaleChanged()
		local newLocale = detectLocale()
		if newLocale ~= currentLocale then
			currentLocale = newLocale
			fallbackUsed = false
			refreshAll()
		end
	end
	if translator then
		translator:GetPropertyChangedSignal("LocaleId"):Connect(onLocaleChanged)
	end
	player:GetPropertyChangedSignal("LocaleId"):Connect(onLocaleChanged)
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("AH_PseudoLocale"):Connect(function()
			pseudo = pseudoMode()
			refreshAll()
		end)
	end
end

return LocalizationController
