-- Offline test harness for CritRag: stubs the WoW API, loads the addon in TOC order
-- and fires events. Run from the repo root: lua tests/run.lua
-- Stubs mirror the behavior verified in Blizzard UI source (branch "forever", 1.60.1);
-- they are not a substitute for in-game testing.

local ADDON_NAME = "CritRag"
local ADDON_DIR = ADDON_NAME .. "/"

---------------------------------------------------------------------------
-- WoW API stubs
---------------------------------------------------------------------------

local state

-- Secret values error on comparison/concatenation/indexing, like in game.
-- Pure Lua cannot make `secret ~= "string"` raise, so tests also assert that
-- issecretvalue() saw the secret (state.secretChecks) before it was used.
local SECRET = setmetatable({}, {
	__lt = function() error("attempt to compare a secret value") end,
	__le = function() error("attempt to compare a secret value") end,
	__concat = function() error("attempt to concatenate a secret value") end,
	__index = function() error("attempt to index a secret value") end,
})

local frames = {}

local FrameMethods = {}
FrameMethods.__index = FrameMethods

function FrameMethods:RegisterEvent(event)
	self.events[event] = true
end

function FrameMethods:RegisterUnitEvent(event, unit)
	self.events[event] = unit
end

function FrameMethods:UnregisterEvent(event)
	self.events[event] = nil
end

function FrameMethods:SetScript(handler, fn)
	self.scripts[handler] = fn
end

local function FireEvent(event, ...)
	for _, frame in ipairs(frames) do
		local registered = frame.events[event]
		if registered and (registered == true or registered == (...)) then
			frame.scripts.OnEvent(frame, event, ...)
		end
	end
end

local function NewSettingsStub()
	local s = { categories = {}, settings = {}, opened = nil }

	local function NewCategory(name)
		local category = { name = name, ID = #s.categories + 1, initializers = {} }
		function category:GetID() return self.ID end
		local layout = {}
		function layout:AddInitializer(initializer)
			table.insert(category.initializers, initializer)
		end
		return category, layout
	end

	s.VarType = { Boolean = "boolean", String = "string", Number = "number" }

	function s.RegisterVerticalLayoutCategory(name)
		return NewCategory(name)
	end

	function s.RegisterAddOnCategory(category)
		table.insert(s.categories, category)
	end

	function s.RegisterAddOnSetting(category, variable, variableKey, variableTbl, variableType, name, defaultValue)
		assert(type(variableTbl) == "table", "variableTbl must be a table")
		assert(type(defaultValue) == variableType, ("default type mismatch for %s"):format(variable))
		assert(not s.settings[variable], "duplicate setting variable " .. variable)
		if variableTbl[variableKey] == nil then
			variableTbl[variableKey] = defaultValue
		end
		local setting = { variable = variable, name = name, category = category, defaultValue = defaultValue, callbacks = {} }
		function setting:GetValue() return variableTbl[variableKey] end
		function setting:GetVariableType() return variableType end
		function setting:SetValue(value)
			variableTbl[variableKey] = value
			for _, cb in ipairs(self.callbacks) do
				cb(self, value)
			end
		end
		function setting:SetValueChangedCallback(cb)
			table.insert(self.callbacks, cb)
		end
		s.settings[variable] = setting
		return setting
	end

	function s.RegisterProxySetting(category, variable, variableType, name, defaultValue, getValue, setValue)
		assert(type(defaultValue) == variableType, ("default type mismatch for %s"):format(variable))
		assert(not s.settings[variable], "duplicate setting variable " .. variable)
		local setting = { variable = variable, name = name, category = category, defaultValue = defaultValue, callbacks = {} }
		function setting:GetValue() return getValue() end
		function setting:GetVariableType() return variableType end
		function setting:SetValue(value)
			setValue(value)
			for _, cb in ipairs(self.callbacks) do
				cb(self, value)
			end
		end
		function setting:SetValueChangedCallback(cb)
			table.insert(self.callbacks, cb)
		end
		s.settings[variable] = setting
		return setting
	end

	local function AddControl(kind)
		return function(category, setting, options, tooltip)
			local initializer = { kind = kind, setting = setting, options = options, tooltip = tooltip }
			table.insert(category.initializers, initializer)
			return initializer
		end
	end

	function s.CreateCheckbox(category, setting, tooltip)
		return AddControl("checkbox")(category, setting, nil, tooltip)
	end

	s.CreateDropdown = AddControl("dropdown")

	function s.CreateSlider(category, setting, options, tooltip)
		assert(setting:GetVariableType() == "number" and options ~= nil)
		return AddControl("slider")(category, setting, options, tooltip)
	end

	function s.CreateSliderOptions(minValue, maxValue, rate)
		local options = { minValue = minValue, maxValue = maxValue, steps = (maxValue - minValue) / rate }
		function options:SetLabelFormatter(labelType, value)
			self.formatters = self.formatters or {}
			self.formatters[labelType] = value or tostring
		end
		return options
	end

	function s.CreateControlTextContainer()
		local container = { data = {} }
		function container:Add(value, label, tooltip)
			table.insert(self.data, { value = value, label = label, text = label, tooltip = tooltip })
		end
		function container:GetData() return self.data end
		return container
	end

	function s.OpenToCategory(categoryID)
		s.opened = categoryID
	end

	return s
end

local function ResetEnvironment(opts)
	opts = opts or {}
	frames = {}
	state = {
		time = 100,
		played = {},
		printed = {},
		canAttack = true,
		secretChecks = 0,
		equipped = opts.equipped or {},
		locale = opts.locale or "enUS",
		class = opts.class or "WARRIOR",
		forms = opts.forms or {}, -- list of booleans: isActive per shapeshift form
	}

	_G.CritRagDB = opts.savedVariables
	_G.SlashCmdList = {}
	_G.SLASH_CRITRAG1 = nil

	_G.Enum = {
		ItemClass = { Weapon = 2, Armor = 4 },
		-- Values from Blizzard_APIDocumentationGenerated/ItemConstantsDocumentation.lua (forever).
		ItemWeaponSubclass = {
			Axe1H = 0, Axe2H = 1, Bows = 2, Guns = 3, Mace1H = 4, Mace2H = 5, Polearm = 6,
			Sword1H = 7, Sword2H = 8, Warglaive = 9, Staff = 10, Bearclaw = 11, Catclaw = 12,
			Unarmed = 13, Generic = 14, Dagger = 15, Thrown = 16, Obsolete3 = 17, Crossbow = 18,
			Wand = 19, Fishingpole = 20,
		},
	}
	_G.INVSLOT_MAINHAND, _G.INVSLOT_OFFHAND, _G.INVSLOT_RANGED = 16, 17, 18

	_G.CreateFrame = function()
		local frame = setmetatable({ events = {}, scripts = {} }, FrameMethods)
		table.insert(frames, frame)
		return frame
	end
	_G.GetLocale = function() return state.locale end
	_G.GetTime = function() return state.time end
	_G.GetInventoryItemID = function(_, slot)
		local item = state.equipped[slot]
		return item and item.id
	end
	_G.C_Item = {
		GetItemInfoInstant = function(itemID)
			for _, item in pairs(state.equipped) do
				if item.id == itemID then
					return itemID, nil, nil, nil, nil, item.classID, item.subClassID
				end
			end
		end,
	}
	_G.PlaySoundFile = function(path, channel)
		table.insert(state.played, { path = path, channel = channel })
		return true, #state.played
	end
	_G.UnitCanAttack = function() return state.canAttack end
	_G.UnitClassBase = function() return state.class:lower(), state.class, 1 end
	_G.GetNumShapeshiftForms = function() return #state.forms end
	_G.GetShapeshiftFormInfo = function(i) return 136116, state.forms[i], true, 768 end
	_G.issecretvalue = function(v)
		if rawequal(v, SECRET) then
			state.secretChecks = state.secretChecks + 1
			return true
		end
		return false
	end
	_G.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[#parts + 1] = tostring((select(i, ...)))
		end
		table.insert(state.printed, table.concat(parts, " "))
	end
	_G.strlower = string.lower
	_G.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
	_G.strsplit = function(delim, s, limit)
		local result, start = {}, 1
		while true do
			if limit and #result == limit - 1 then
				table.insert(result, s:sub(start))
				break
			end
			local i = s:find(delim, start, true)
			if not i then
				table.insert(result, s:sub(start))
				break
			end
			table.insert(result, s:sub(start, i - 1))
			start = i + #delim
		end
		return table.unpack(result)
	end
	_G.CopyTable = function(t)
		local copy = {}
		for k, v in pairs(t) do
			copy[k] = type(v) == "table" and _G.CopyTable(v) or v
		end
		return copy
	end
	_G.Settings = NewSettingsStub()
	_G.CreateSettingsListSectionHeaderInitializer = function(name)
		return { kind = "header", name = name }
	end
	_G.CreateSettingsButtonInitializer = function(name, buttonText, buttonClick, tooltip)
		return { kind = "button", name = name, buttonText = buttonText, click = buttonClick, tooltip = tooltip }
	end
	_G.MinimalSliderWithSteppersMixin = { Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 } }
end

local function ReadTocFiles()
	local files = {}
	for line in io.lines(ADDON_DIR .. ADDON_NAME .. ".toc") do
		if line ~= "" and not line:match("^##") then
			files[#files + 1] = (line:gsub("\\", "/"))
		end
	end
	return files
end

local function LoadAddon(opts)
	ResetEnvironment(opts)
	local ns = {}
	for _, file in ipairs(ReadTocFiles()) do
		local chunk = assert(loadfile(ADDON_DIR .. file))
		chunk(ADDON_NAME, ns)
	end
	FireEvent("ADDON_LOADED", ADDON_NAME)
	FireEvent("PLAYER_LOGIN")
	return ns
end

local function Slash(msg)
	_G.SlashCmdList.CRITRAG(msg)
end

---------------------------------------------------------------------------
-- Test runner
---------------------------------------------------------------------------

local SWORD = { id = 1001, classID = 2, subClassID = 7 }
local SWORD2H = { id = 1002, classID = 2, subClassID = 8 }
local BOW = { id = 1003, classID = 2, subClassID = 2 }
local AXE = { id = 1004, classID = 2, subClassID = 0 }
local GUN = { id = 1005, classID = 2, subClassID = 3 }
local STAFF = { id = 1006, classID = 2, subClassID = 10 }
local FISHING_POLE = { id = 1007, classID = 2, subClassID = 20 }

local tests, failures = {}, 0

local function test(name, fn)
	tests[#tests + 1] = { name = name, fn = fn }
end

local function eq(actual, expected, what)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(what or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function lastSound()
	local entry = state.played[#state.played]
	return entry and entry.path:match("([^\\]+)$")
end

local function Crit(amount)
	state.time = state.time + 1 -- stay clear of the throttle
	FireEvent("UNIT_COMBAT", "target", "WOUND", "CRITICAL", amount or 500, 1)
end

local function FindInitializer(ns, predicate)
	for _, initializer in ipairs(ns.optionsCategory.initializers) do
		if predicate(initializer) then
			return initializer
		end
	end
end

test("melee crit with sword plays sword sound", function()
	LoadAddon({ equipped = { [16] = SWORD } })
	FireEvent("PLAYER_ENTER_COMBAT")
	Crit()
	eq(#state.played, 1, "sounds played")
	eq(lastSound(), "sword.ogg", "sound")
	eq(state.played[1].channel, "Master", "channel")
end)

test("two-handed sword counts as sword", function()
	LoadAddon({ equipped = { [16] = SWORD2H } })
	FireEvent("PLAYER_ENTER_COMBAT")
	Crit()
	eq(lastSound(), "sword.ogg", "sound")
end)

test("off-hand weapon used when main-hand is not classified", function()
	LoadAddon({ equipped = { [16] = FISHING_POLE, [17] = SWORD } })
	FireEvent("PLAYER_ENTER_COMBAT")
	Crit()
	eq(lastSound(), "sword.ogg", "sound")
end)

test("auto shot crit with bow plays bow sound", function()
	LoadAddon({ equipped = { [16] = SWORD, [18] = BOW } })
	FireEvent("START_AUTOREPEAT_SPELL")
	FireEvent("PLAYER_ENTER_COMBAT")
	Crit()
	eq(lastSound(), "bow.ogg", "auto-repeat takes priority")
	FireEvent("STOP_AUTOREPEAT_SPELL")
	Crit()
	eq(lastSound(), "sword.ogg", "back to melee")
end)

test("unsupported weapons and idle state play nothing", function()
	LoadAddon({ equipped = { [16] = FISHING_POLE } })
	FireEvent("PLAYER_ENTER_COMBAT")
	Crit()
	FireEvent("START_AUTOREPEAT_SPELL")
	Crit()
	LoadAddon({ equipped = { [16] = SWORD } })
	Crit() -- no auto-attack active
	eq(#state.played, 0, "sounds played")
end)

test("non-crit, non-wound and friendly targets are ignored", function()
	LoadAddon({ equipped = { [16] = SWORD } })
	FireEvent("PLAYER_ENTER_COMBAT")
	FireEvent("UNIT_COMBAT", "target", "WOUND", "", 500, 1)
	FireEvent("UNIT_COMBAT", "target", "HEAL", "CRITICAL", 500, 2)
	FireEvent("UNIT_COMBAT", "focus", "WOUND", "CRITICAL", 500, 1)
	state.canAttack = false
	Crit()
	eq(#state.played, 0, "sounds played")
end)

test("secret values never raise errors", function()
	LoadAddon({ equipped = { [16] = SWORD } })
	FireEvent("PLAYER_ENTER_COMBAT")
	FireEvent("UNIT_COMBAT", "target", SECRET, "CRITICAL", 500, 1)
	eq(state.secretChecks, 1, "secret action checked")
	FireEvent("UNIT_COMBAT", "target", "WOUND", SECRET, 500, 1)
	eq(state.secretChecks, 2, "secret flagText checked")
	state.canAttack = SECRET
	Crit()
	eq(state.secretChecks, 3, "secret UnitCanAttack checked")
	eq(#state.played, 0, "sounds played")
	state.canAttack = true
	Crit(SECRET)
	eq(#state.played, 1, "secret amount is fine without a minimum")
	Slash("min 100")
	Crit(SECRET)
	eq(#state.played, 1, "secret amount skipped with a minimum")
end)

test("minimum damage filters small crits", function()
	LoadAddon({ equipped = { [16] = SWORD } })
	FireEvent("PLAYER_ENTER_COMBAT")
	Slash("min 300")
	eq(_G.CritRagDB.minDamage, 300, "minDamage")
	Crit(299)
	eq(#state.played, 0, "below minimum")
	Crit(300)
	eq(#state.played, 1, "at minimum")
end)

test("minimum damage slider uses non-linear steps", function()
	local ns = LoadAddon()
	local steps = ns.MIN_DAMAGE_STEPS
	eq(#steps, 74, "step count")
	local expectedDiff = function(v)
		if v <= 50 then return 5 elseif v <= 100 then return 10 elseif v <= 1000 then return 50 else return 100 end
	end
	eq(steps[1], 0, "first")
	eq(steps[#steps], 5000, "last")
	for i = 2, #steps do
		eq(steps[i] - steps[i - 1], expectedDiff(steps[i]), "step before " .. steps[i])
	end

	local slider = FindInitializer(ns, function(i) return i.kind == "slider" and i.setting.variable == "CritRag_minDamage" end)
	eq(slider.options.minValue, 0, "slider min")
	eq(slider.options.maxValue, #steps - 1, "slider max")
	eq(slider.options.steps, #steps - 1, "slider steps")
	local format = slider.options.formatters[2]
	local setting = slider.setting
	eq(setting.defaultValue, 0, "default index")

	setting:SetValue(10)
	eq(_G.CritRagDB.minDamage, 50, "index 10 -> 50")
	eq(format(10), 50, "label for index 10")
	setting:SetValue(15)
	eq(_G.CritRagDB.minDamage, 100, "index 15 -> 100")
	setting:SetValue(16)
	eq(_G.CritRagDB.minDamage, 150, "index 16 -> 150")
	setting:SetValue(#steps - 1)
	eq(_G.CritRagDB.minDamage, 5000, "last index -> 5000")
	eq(setting:GetValue(), #steps - 1, "round trip")

	Slash("min 333")
	eq(_G.CritRagDB.minDamage, 333, "slash keeps exact value")
	eq(format(setting:GetValue()), 350, "slider shows nearest step")
	Slash("min 0")
	eq(setting:GetValue(), 0, "zero")
end)

test("throttle drops crits that are too close", function()
	LoadAddon({ equipped = { [16] = SWORD } })
	FireEvent("PLAYER_ENTER_COMBAT")
	FireEvent("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 500, 1)
	state.time = state.time + 0.1
	FireEvent("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 500, 1)
	eq(#state.played, 1, "second crit throttled")
	state.time = state.time + 0.2
	FireEvent("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 500, 1)
	eq(#state.played, 2, "after throttle window")
end)

test("equipment change updates the weapon cache", function()
	LoadAddon({ equipped = { [16] = FISHING_POLE } })
	FireEvent("PLAYER_ENTER_COMBAT")
	Crit()
	eq(#state.played, 0, "fishing pole")
	state.equipped[16] = SWORD
	FireEvent("PLAYER_EQUIPMENT_CHANGED", 16, false)
	Crit()
	eq(lastSound(), "sword.ogg", "sword after swap")
end)

test("options panel registers every control", function()
	local ns = LoadAddon()
	eq(#_G.Settings.categories, 1, "categories registered")
	eq(ns.optionsCategory.name, ADDON_NAME, "category name")
	local counts = {}
	for _, initializer in ipairs(ns.optionsCategory.initializers) do
		counts[initializer.kind] = (counts[initializer.kind] or 0) + 1
	end
	eq(counts.checkbox, 1 + #ns.WEAPON_CATEGORIES, "checkboxes (enabled + weapons)")
	eq(counts.dropdown, 1, "dropdowns")
	eq(counts.slider, 2, "sliders")
	eq(counts.header, 2, "headers")
	eq(counts.button, 3, "test buttons (bow, sword, generic)")
	for _, initializer in ipairs(ns.optionsCategory.initializers) do
		local label = initializer.setting and initializer.setting.name or initializer.name
		assert(label, "control without label: " .. tostring(initializer.kind))
	end
	local dropdown = FindInitializer(ns, function(i) return i.kind == "dropdown" end)
	local channels = dropdown.options()
	eq(#channels, 2, "channel options")
	eq(channels[1].value, "Master", "first channel")
end)

test("unchecking a weapon silences it, test button still plays", function()
	local ns = LoadAddon({ equipped = { [16] = SWORD } })
	FireEvent("PLAYER_ENTER_COMBAT")
	_G.Settings.settings.CritRag_weapon_sword:SetValue(false)
	Crit()
	eq(#state.played, 0, "unchecked weapon")
	local button = FindInitializer(ns, function(i) return i.kind == "button" end)
	button.click()
	eq(lastSound(), "bow.ogg", "first test button is bow")
end)

test("enabled checkbox toggles UNIT_COMBAT registration", function()
	LoadAddon({ equipped = { [16] = SWORD } })
	FireEvent("PLAYER_ENTER_COMBAT")
	_G.Settings.settings.CritRag_enabled:SetValue(false)
	Crit()
	eq(#state.played, 0, "disabled")
	_G.Settings.settings.CritRag_enabled:SetValue(true)
	Crit()
	eq(#state.played, 1, "re-enabled")
end)

test("slash commands", function()
	local ns = LoadAddon()
	Slash("")
	eq(_G.Settings.opened, ns.optionsCategory:GetID(), "no argument opens options")
	Slash("channel sfx")
	eq(_G.CritRagDB.channel, "SFX", "channel")
	Slash("off")
	eq(_G.CritRagDB.enabled, false, "off")
	Slash("test sword")
	eq(lastSound(), "sword.ogg", "test plays even when disabled")
	Slash("test generic")
	eq(lastSound(), "generic.ogg", "test generic")
	Slash("test dagger")
	eq(lastSound(), "generic.ogg", "test dagger falls back to generic")
	local before = #state.played
	Slash("test banana")
	eq(#state.played, before, "unknown sound plays nothing")
	assert(state.printed[#state.printed]:find("dagger", 1, true), "unknown lists options")
	Slash("status")
	assert(state.printed[#state.printed - 1]:find("SFX", 1, true), "status shows channel")
end)

test("v1 SavedVariables migrate to v2 keeping user values", function()
	LoadAddon({ savedVariables = { version = 1, enabled = false, channel = "SFX", minDamage = 250 } })
	local db = _G.CritRagDB
	eq(db.version, 3, "version")
	eq(db.enabled, false, "enabled kept")
	eq(db.channel, "SFX", "channel kept")
	eq(db.minDamage, 250, "minDamage kept")
	eq(db.categories.bow, true, "categories.bow added")
	eq(db.categories.sword, true, "categories.sword added")
	eq(db.categories.axe, true, "categories.axe added")
	eq(db.sounds.generic, "generic.ogg", "generic sound added")
end)

test("v2 SavedVariables keep per-weapon choices", function()
	LoadAddon({ savedVariables = { version = 2, categories = { bow = false, sword = true } } })
	local db = _G.CritRagDB
	eq(db.version, 3, "version")
	eq(db.categories.bow, false, "bow choice kept")
	eq(db.categories.thrown, true, "thrown added")
end)

test("weapons without their own sound use the generic sound", function()
	local cases = {
		{ AXE, 16, "PLAYER_ENTER_COMBAT" },
		{ STAFF, 16, "PLAYER_ENTER_COMBAT" },
		{ GUN, 18, "START_AUTOREPEAT_SPELL" },
	}
	for _, case in ipairs(cases) do
		LoadAddon({ equipped = { [case[2]] = case[1] } })
		FireEvent(case[3])
		Crit()
		eq(lastSound(), "generic.ogg", "subclass " .. case[1].subClassID)
	end
end)

test("every weapon subclass we classify has a category and locale label", function()
	local ns = LoadAddon()
	local known = {}
	for _, category in ipairs(ns.WEAPON_CATEGORIES) do
		known[category] = true
		assert(ns.L["WEAPON_" .. category:upper()], "missing label for " .. category)
		eq(_G.CritRagDB.categories[category], true, "default for " .. category)
	end
	local W = _G.Enum.ItemWeaponSubclass
	local expected = {
		[W.Sword1H] = "sword", [W.Sword2H] = "sword", [W.Axe1H] = "axe", [W.Axe2H] = "axe",
		[W.Mace1H] = "mace", [W.Mace2H] = "mace", [W.Dagger] = "dagger", [W.Unarmed] = "fist",
		[W.Polearm] = "polearm", [W.Staff] = "staff", [W.Bows] = "bow", [W.Guns] = "gun",
		[W.Crossbow] = "crossbow", [W.Wand] = "wand", [W.Thrown] = "thrown",
	}
	for subClassID, category in pairs(expected) do
		assert(known[category], "unknown category " .. category)
		local slot = (category == "bow" or category == "gun" or category == "crossbow"
			or category == "wand" or category == "thrown") and 18 or 16
		LoadAddon({ equipped = { [slot] = { id = 2000 + subClassID, classID = 2, subClassID = subClassID } } })
		FireEvent(slot == 18 and "START_AUTOREPEAT_SPELL" or "PLAYER_ENTER_COMBAT")
		_G.Settings.settings["CritRag_weapon_" .. category]:SetValue(false)
		Crit()
		eq(#state.played, 0, category .. " checkbox controls subclass " .. subClassID)
		_G.Settings.settings["CritRag_weapon_" .. category]:SetValue(true)
		Crit()
		eq(#state.played, 1, category .. " plays for subclass " .. subClassID)
	end
end)

test("druid in a shapeshift form is ignored", function()
	LoadAddon({ class = "DRUID", equipped = { [16] = STAFF }, forms = { false, false } })
	FireEvent("PLAYER_ENTER_COMBAT")
	Crit()
	eq(#state.played, 1, "caster form plays")
	state.forms[1] = true
	FireEvent("UPDATE_SHAPESHIFT_FORM")
	Crit()
	eq(#state.played, 1, "bear/cat form silent")
	state.forms[1] = false
	FireEvent("UPDATE_SHAPESHIFT_FORM")
	Crit()
	eq(#state.played, 2, "back to caster form")
end)

test("druid already shapeshifted at login is ignored", function()
	LoadAddon({ class = "DRUID", equipped = { [16] = STAFF }, forms = { false, true } })
	FireEvent("PLAYER_ENTER_COMBAT")
	Crit()
	eq(#state.played, 0, "form active at login")
end)

test("non-druid with an active stance still plays", function()
	LoadAddon({ class = "WARRIOR", equipped = { [16] = SWORD }, forms = { true } })
	FireEvent("PLAYER_ENTER_COMBAT")
	FireEvent("UPDATE_SHAPESHIFT_FORM")
	Crit()
	eq(lastSound(), "sword.ogg", "warrior stance")
end)

test("ptBR locale has every enUS key", function()
	local enNs = LoadAddon({ locale = "enUS" })
	local enKeys = {}
	for k in pairs(enNs.L) do enKeys[k] = true end
	ResetEnvironment({ locale = "ptBR" })
	local ns = {}
	assert(loadfile(ADDON_DIR .. "Locales/enUS.lua"))(ADDON_NAME, ns)
	local before = {}
	for k, v in pairs(ns.L) do before[k] = v end
	assert(loadfile(ADDON_DIR .. "Locales/ptBR.lua"))(ADDON_NAME, ns)
	for k in pairs(enKeys) do
		if k ~= "PREFIX" and ns.L[k] == before[k] then
			error("ptBR missing translation for " .. k)
		end
	end
end)

for _, t in ipairs(tests) do
	local ok, err = pcall(t.fn)
	if ok then
		io.write("ok   ", t.name, "\n")
	else
		failures = failures + 1
		io.write("FAIL ", t.name, "\n     ", tostring(err), "\n")
	end
end

io.write(("\n%d tests, %d failures\n"):format(#tests, failures))
os.exit(failures == 0 and 0 or 1)
