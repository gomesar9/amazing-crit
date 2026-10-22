local ADDON_NAME, ns = ...
local L = ns.L

-- COMBAT_LOG_EVENT_UNFILTERED is blocked for addons in Forever (confirmed in-game,
-- 1.60.1). Crits are detected with UNIT_COMBAT, which reports the unit that was
-- hit or healed, the result (WOUND/HEAL), the crit flag, the amount and the school
-- mask, but never the source. Two modes (see Config.lua):
--   "source": sound by what is known for certain: crit damage school on your
--             target, crit heals on you/your pet/your target, crits you take.
--   "weapon": crits on your target while you auto-attack, sound by the weapon
--             inferred from the auto-attack state (auto-repeat means ranged,
--             melee means main-hand/off-hand). Druids in any shapeshift form are
--             ignored (cat/bear attacks do not use the weapon).

local SOUND_PATH = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Sounds\\"

local SLOT_MAINHAND = INVSLOT_MAINHAND or 16
local SLOT_OFFHAND = INVSLOT_OFFHAND or 17
local SLOT_RANGED = INVSLOT_RANGED or 18
local WEAPON_SLOTS = { SLOT_MAINHAND, SLOT_OFFHAND, SLOT_RANGED }

local Subclass = Enum.ItemWeaponSubclass
local SUBCLASS_TO_CATEGORY = {
	[Subclass.Sword1H] = "sword",
	[Subclass.Sword2H] = "sword",
	[Subclass.Axe1H] = "axe",
	[Subclass.Axe2H] = "axe",
	[Subclass.Mace1H] = "mace",
	[Subclass.Mace2H] = "mace",
	[Subclass.Dagger] = "dagger",
	[Subclass.Unarmed] = "fist",
	[Subclass.Polearm] = "polearm",
	[Subclass.Staff] = "staff",
	[Subclass.Bows] = "bow",
	[Subclass.Guns] = "gun",
	[Subclass.Crossbow] = "crossbow",
	[Subclass.Wand] = "wand", -- TODO: verificar no Forever (Shoot da varinha dispara START_AUTOREPEAT_SPELL?)
	[Subclass.Thrown] = "thrown", -- TODO: verificar no Forever (Throw é auto-repeat? No vanilla não era)
}

-- Damage school mask bits, checked in this order; physical is only used when no
-- magic bit is set.
local Damageclass = Enum.Damageclass
local MAGIC_SCHOOLS = {
	{ bit = Damageclass.MaskHoly, key = "holy" },
	{ bit = Damageclass.MaskFire, key = "fire" },
	{ bit = Damageclass.MaskNature, key = "nature" },
	{ bit = Damageclass.MaskFrost, key = "frost" },
	{ bit = Damageclass.MaskShadow, key = "shadow" },
	{ bit = Damageclass.MaskArcane, key = "arcane" },
}
local SCHOOL_PHYSICAL = Damageclass.MaskPhysical

-- Older clients have no secret values; treat everything as readable there.
local issecretvalue = issecretvalue or function() return false end

local frame = CreateFrame("Frame")
local weaponCategory = {} -- [slot] = category key from ns.WEAPON_CATEGORIES | nil
local lastPlayTime = 0
local isAutoRepeating = false -- Auto Shot active
local isMeleeAttacking = false -- melee auto-attack active
local isDruid = false
local inShapeshiftForm = false

local function Print(msg)
	print(L.PREFIX .. msg)
end

local function UpdateWeaponCache()
	for _, slot in ipairs(WEAPON_SLOTS) do
		local category
		local itemID = GetInventoryItemID("player", slot)
		if itemID then
			local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
			if classID == Enum.ItemClass.Weapon then
				category = SUBCLASS_TO_CATEGORY[subClassID]
			end
		end
		weaponCategory[slot] = category
	end
end

local function UpdateShapeshiftForm()
	inShapeshiftForm = false
	for i = 1, GetNumShapeshiftForms() do
		local _, isActive = GetShapeshiftFormInfo(i)
		if isActive then
			inShapeshiftForm = true
			return
		end
	end
end

-- Keys without their own sound file use the generic one.
function ns.PlayCrit(key, ignoreThrottle)
	local file = ns.db.sounds[key] or ns.db.sounds.generic
	if not file then
		return false
	end
	local now = GetTime()
	if not ignoreThrottle and now - lastPlayTime < ns.db.throttle then
		return true
	end
	lastPlayTime = now
	return PlaySoundFile(SOUND_PATH .. file, ns.db.channel) and true or false
end

local function HasBit(mask, bit)
	return math.floor(mask / bit) % 2 == 1
end

local function GetSchoolCategory(schoolMask)
	if type(schoolMask) ~= "number" or schoolMask < SCHOOL_PHYSICAL then
		return nil
	end
	for _, school in ipairs(MAGIC_SCHOOLS) do
		if HasBit(schoolMask, school.bit) then
			return school.key
		end
	end
	return "physical"
end

-- Picks the weapon category for the attack the player is most likely making.
local function GetCurrentWeaponCategory()
	if isDruid and inShapeshiftForm then
		return nil
	elseif isAutoRepeating then
		return weaponCategory[SLOT_RANGED]
	elseif isMeleeAttacking then
		-- Off-hand swings are indistinguishable here; prefer the main-hand weapon.
		return weaponCategory[SLOT_MAINHAND] or weaponCategory[SLOT_OFFHAND]
	end
end

-- Returns false when the answer is secret, so callers treat it as "unknown".
local function SafeCheck(fn, ...)
	local result = fn(...)
	return not issecretvalue(result) and result
end

local function IsHostileTarget()
	return SafeCheck(UnitCanAttack, "player", "target")
end

-- When you target yourself or your pet, UNIT_COMBAT may also fire for "target";
-- those crits are handled by the "player"/"pet" sources instead.
local function IsTargetSelfOrPet()
	return SafeCheck(UnitIsUnit, "target", "player") or SafeCheck(UnitIsUnit, "target", "pet")
end

-- "source" mode: unit + result + school, all reported by the event itself.
local function GetSourceCategory(unit, action, flagText, schoolMask)
	if unit == "target" then
		if flagText ~= "CRITICAL" or IsTargetSelfOrPet() then
			return nil
		elseif action == "WOUND" and IsHostileTarget() then
			if issecretvalue(schoolMask) then
				return nil
			end
			return GetSchoolCategory(schoolMask)
		elseif action == "HEAL" and not IsHostileTarget() then
			return "heal_target"
		end
	elseif unit == "player" then
		if action == "HEAL" and flagText == "CRITICAL" then
			return "heal_player"
		elseif action == "WOUND" and flagText == "CRITICAL" then
			return "taken_crit"
		elseif action == "WOUND" and flagText == "CRUSHING" then
			return "taken_crushing"
		end
	elseif unit == "pet" then
		if action == "HEAL" and flagText == "CRITICAL" then
			return "heal_pet"
		end
	end
end

-- "weapon" mode: crits on your target, weapon guessed from the auto-attack state.
local function GetWeaponModeCategory(unit, action, flagText)
	if unit == "target" and action == "WOUND" and flagText == "CRITICAL" and IsHostileTarget() then
		return GetCurrentWeaponCategory()
	end
end

local function IsBelowMinimum(amount)
	-- A secret amount only matters when a minimum is set.
	return ns.db.minDamage > 0 and (issecretvalue(amount) or (amount or 0) < ns.db.minDamage)
end

function ns.UpdateEnabled()
	frame:UnregisterEvent("UNIT_COMBAT")
	if not ns.db.enabled then
		return
	end
	if ns.db.mode == "source" then
		-- player, pet and target: more than RegisterUnitEvent's two units.
		frame:RegisterEvent("UNIT_COMBAT")
	else
		frame:RegisterUnitEvent("UNIT_COMBAT", "target")
	end
end

local handlers = {}

function handlers.ADDON_LOADED(addOnName)
	if addOnName ~= ADDON_NAME then
		return
	end
	ns.InitDB()
	frame:UnregisterEvent("ADDON_LOADED")
end

function handlers.PLAYER_LOGIN()
	local _, classFilename = UnitClassBase("player")
	isDruid = classFilename == "DRUID"
	UpdateWeaponCache()
	ns.UpdateEnabled()
	ns.InitOptions()
	frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	frame:RegisterEvent("START_AUTOREPEAT_SPELL")
	frame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
	frame:RegisterEvent("PLAYER_ENTER_COMBAT")
	frame:RegisterEvent("PLAYER_LEAVE_COMBAT")
	if isDruid then
		UpdateShapeshiftForm()
		frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
	end
end

function handlers.PLAYER_EQUIPMENT_CHANGED(slot)
	if slot == SLOT_MAINHAND or slot == SLOT_OFFHAND or slot == SLOT_RANGED then
		UpdateWeaponCache()
	end
end

handlers.UPDATE_SHAPESHIFT_FORM = UpdateShapeshiftForm

function handlers.START_AUTOREPEAT_SPELL()
	isAutoRepeating = true
end

function handlers.STOP_AUTOREPEAT_SPELL()
	isAutoRepeating = false
end

function handlers.PLAYER_ENTER_COMBAT()
	isMeleeAttacking = true
end

function handlers.PLAYER_LEAVE_COMBAT()
	isMeleeAttacking = false
end

function handlers.UNIT_COMBAT(unit, action, flagText, amount, schoolMask)
	if issecretvalue(unit) or issecretvalue(action) or issecretvalue(flagText) then
		return
	end
	local key, toggles
	if ns.db.mode == "source" then
		key, toggles = GetSourceCategory(unit, action, flagText, schoolMask), ns.db.sources
	else
		key, toggles = GetWeaponModeCategory(unit, action, flagText), ns.db.categories
	end
	if key and toggles[key] and not IsBelowMinimum(amount) then
		ns.PlayCrit(key)
	end
end

frame:SetScript("OnEvent", function(_, event, ...)
	handlers[event](...)
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

local CHANNELS = { master = "Master", sfx = "SFX" }

local function IsSoundKey(key)
	return key == "generic" or ns.db.categories[key] ~= nil or ns.db.sources[key] ~= nil
end

SLASH_CRITRAG1 = "/critrag"
SlashCmdList.CRITRAG = function(msg)
	local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")), 2)
	if cmd == "" then
		ns.OpenOptions()
	elseif cmd == "status" then
		Print(L.STATUS:format(
			ns.db.enabled and L.ON or L.OFF,
			L["MODE_" .. ns.db.mode:upper()],
			ns.db.channel,
			ns.db.minDamage,
			ns.db.mode == "weapon" and GetCurrentWeaponCategory() or "-"))
		Print(L.USAGE)
	elseif cmd == "on" or cmd == "off" then
		ns.db.enabled = cmd == "on"
		ns.UpdateEnabled()
		Print(ns.db.enabled and L.ENABLED_MSG or L.DISABLED_MSG)
	elseif cmd == "mode" and (arg == "source" or arg == "weapon") then
		ns.db.mode = arg
		ns.UpdateEnabled()
		Print(L.MODE_SET:format(L["MODE_" .. arg:upper()]))
	elseif cmd == "test" then
		if not IsSoundKey(arg or "") then
			Print(L.UNKNOWN_CATEGORY:format(arg or "", table.concat(ns.SOURCE_CATEGORIES, ", ") .. ", "
				.. table.concat(ns.WEAPON_CATEGORIES, ", ") .. ", generic"))
		elseif not ns.PlayCrit(arg, true) then
			Print(L.PLAY_FAILED)
		end
	elseif cmd == "min" and tonumber(arg) then
		ns.db.minDamage = math.max(0, math.floor(tonumber(arg)))
		Print(L.MIN_DAMAGE_SET:format(ns.db.minDamage))
	elseif cmd == "channel" and CHANNELS[arg or ""] then
		ns.db.channel = CHANNELS[arg]
		Print(L.CHANNEL_SET:format(ns.db.channel))
	else
		Print(L.USAGE)
	end
end
