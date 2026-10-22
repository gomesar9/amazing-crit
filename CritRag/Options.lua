local ADDON_NAME, ns = ...
local L = ns.L

-- Settings API checked against Blizzard UI source, branch "forever" (1.60.1 build 70450):
-- Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua and
-- Blizzard_SettingControls.lua (SetParentInitializer).

local CHANNEL_OPTIONS = {
	{ value = "Master", label = "OPT_CHANNEL_MASTER" },
	{ value = "SFX", label = "OPT_CHANNEL_SFX" },
}

local function GetChannelOptions()
	local container = Settings.CreateControlTextContainer()
	for _, option in ipairs(CHANNEL_OPTIONS) do
		container:Add(option.value, L[option.label])
	end
	return container:GetData()
end

local function GetModeOptions()
	local container = Settings.CreateControlTextContainer()
	for _, mode in ipairs(ns.MODES) do
		local key = mode:upper()
		container:Add(mode, L["MODE_" .. key], L["MODE_" .. key .. "_TT"])
	end
	return container:GetData()
end

-- The native slider is linear, so the minimum damage slider moves over an index
-- into this list: 0, 5..50 by 5, 60..100 by 10, 150..1000 by 50, 1100..5000 by 100.
local MIN_DAMAGE_STEPS = { 0 }
for _, range in ipairs({ { 5, 50, 5 }, { 60, 100, 10 }, { 150, 1000, 50 }, { 1100, 5000, 100 } }) do
	for value = range[1], range[2], range[3] do
		MIN_DAMAGE_STEPS[#MIN_DAMAGE_STEPS + 1] = value
	end
end
ns.MIN_DAMAGE_STEPS = MIN_DAMAGE_STEPS

-- Index (0-based) of the step closest to value; /critrag min accepts any number.
local function MinDamageToIndex(value)
	local best, bestDiff = 0, math.huge
	for i, step in ipairs(MIN_DAMAGE_STEPS) do
		local diff = math.abs(step - value)
		if diff < bestDiff then
			best, bestDiff = i - 1, diff
		end
	end
	return best
end

local function IndexToMinDamage(index)
	return MIN_DAMAGE_STEPS[index + 1] or 0
end

local function FormatSeconds(value)
	return ("%.2f s"):format(value)
end

-- Registers a setting stored directly in a SavedVariables table.
local function AddSetting(category, key, tbl, varType, label)
	return Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_" .. key, key, tbl, varType, label, ns.defaults[key])
end

-- One checkbox per key of a toggles table; enabled only while its mode is active.
local function AddToggles(category, keys, toggles, defaults, prefix, labelPrefix, tooltip, modeInitializer, mode)
	local function IsModeActive()
		return ns.db.mode == mode
	end
	for _, key in ipairs(keys) do
		local setting = Settings.RegisterAddOnSetting(category, ADDON_NAME .. "_" .. prefix .. "_" .. key, key,
			toggles, Settings.VarType.Boolean, L[labelPrefix .. key:upper()], defaults[key])
		local initializer = Settings.CreateCheckbox(category, setting, tooltip)
		initializer:SetParentInitializer(modeInitializer, IsModeActive)
	end
end

-- One test button per sound file; "generic" covers keys without their own sound.
local function AddSoundTest(layout, soundKey, label)
	layout:AddInitializer(CreateSettingsButtonInitializer(label, L.OPT_TEST, function()
		if not ns.PlayCrit(soundKey, true) then
			print(L.PREFIX .. L.PLAY_FAILED)
		end
	end, L.OPT_TEST_TT, false))
end

function ns.InitOptions()
	local db = ns.db
	local category, layout = Settings.RegisterVerticalLayoutCategory(ADDON_NAME)

	local enabled = AddSetting(category, "enabled", db, Settings.VarType.Boolean, L.OPT_ENABLED)
	Settings.CreateCheckbox(category, enabled, L.OPT_ENABLED_TT)
	enabled:SetValueChangedCallback(function()
		ns.UpdateEnabled()
	end)

	local mode = AddSetting(category, "mode", db, Settings.VarType.String, L.OPT_MODE)
	local modeInitializer = Settings.CreateDropdown(category, mode, GetModeOptions, L.OPT_MODE_TT)
	mode:SetValueChangedCallback(function()
		ns.UpdateEnabled()
	end)

	local channel = AddSetting(category, "channel", db, Settings.VarType.String, L.OPT_CHANNEL)
	Settings.CreateDropdown(category, channel, GetChannelOptions, L.OPT_CHANNEL_TT)

	local minDamage = Settings.RegisterProxySetting(category, ADDON_NAME .. "_minDamage", Settings.VarType.Number,
		L.OPT_MIN_DAMAGE, MinDamageToIndex(ns.defaults.minDamage),
		function() return MinDamageToIndex(db.minDamage) end,
		function(index) db.minDamage = IndexToMinDamage(index) end)
	local minDamageOptions = Settings.CreateSliderOptions(0, #MIN_DAMAGE_STEPS - 1, 1)
	minDamageOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, IndexToMinDamage)
	Settings.CreateSlider(category, minDamage, minDamageOptions, L.OPT_MIN_DAMAGE_TT)

	local throttle = AddSetting(category, "throttle", db, Settings.VarType.Number, L.OPT_THROTTLE)
	local throttleOptions = Settings.CreateSliderOptions(0, 1, 0.05)
	throttleOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatSeconds)
	Settings.CreateSlider(category, throttle, throttleOptions, L.OPT_THROTTLE_TT)

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.OPT_SOURCES))
	AddToggles(category, ns.SOURCE_CATEGORIES, db.sources, ns.defaults.sources, "source", "SOURCE_",
		L.OPT_SOURCE_TT, modeInitializer, "source")

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.OPT_WEAPONS))
	AddToggles(category, ns.WEAPON_CATEGORIES, db.categories, ns.defaults.categories, "weapon", "WEAPON_",
		L.OPT_WEAPON_TT, modeInitializer, "weapon")

	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.OPT_SOUNDS))
	AddSoundTest(layout, "bow", L.WEAPON_BOW)
	AddSoundTest(layout, "sword", L.WEAPON_SWORD)
	AddSoundTest(layout, "generic", L.SOUND_GENERIC)

	Settings.RegisterAddOnCategory(category)
	ns.optionsCategory = category
end

function ns.OpenOptions()
	Settings.OpenToCategory(ns.optionsCategory:GetID())
end
