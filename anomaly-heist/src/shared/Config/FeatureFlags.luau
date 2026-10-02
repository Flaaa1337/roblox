--!strict
-- Server-authoritative feature flags. Conservative defaults: anything that
-- changes ownership or involves money starts off. The client may read these
-- to hide UI; it can never enable a server capability.

local FeatureFlags = {
	pvp = false, -- M4
	commerce = false, -- M6, requires owner approval
	trading = false, -- post-launch, separate spec
	liveEvents = false,
	capture = false, -- M2: capture/cargo/extraction loop
	mutationGeneration = false, -- M2
	-- Studio-only localization stress test: "off" | "long" | "rtl".
	-- Ignored outside Studio. See docs/LOCALIZATION.md.
	studioPseudoLocale = "off",
}

return FeatureFlags
