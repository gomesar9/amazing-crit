local ADDON_NAME, ns = ...
local L = ns.L

-- COMBAT_LOG_EVENT_UNFILTERED is blocked for addons in Forever (confirmed in-game,
-- 1.60.1). Crits are detected with UNIT_COMBAT on "target", which does not report
-- the source: any crit on your target counts (party members, your pet).
-- The weapon is inferred from the auto-attack state: auto-repeat (Auto Shot) means
-- ranged, melee auto-attack means main-hand/off-hand. Druids in any shapeshift
-- form are ignored (cat/bear attacks do not use the weapon).

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

-- Weapons without their own sound file use the generic one.
function ns.PlayCrit(category, ignoreThrottle)
	local file = ns.db.sounds[category] or ns.db.sounds.generic
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

-- Picks the sound category for the attack the player is most likely making.
local function GetCurrentCategory()
	if isDruid and inShapeshiftForm then
		return nil
	elseif isAutoRepeating then
		return weaponCategory[SLOT_RANGED]
	elseif isMeleeAttacking then
		-- Off-hand swings are indistinguishable here; prefer the main-hand weapon.
		return weaponCategory[SLOT_MAINHAND] or weaponCategory[SLOT_OFFHAND]
	end
end

local function IsHostileTarget()
	local canAttack = UnitCanAttack("player", "target")
	return not issecretvalue(canAttack) and canAttack
end

function ns.UpdateEnabled()
	if ns.db.enabled then
		frame:RegisterUnitEvent("UNIT_COMBAT", "target")
	else
		frame:UnregisterEvent("UNIT_COMBAT")
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

function handlers.UNIT_COMBAT(_, action, flagText, amount)
	if issecretvalue(action) or issecretvalue(flagText) then
		return
	end
	if action ~= "WOUND" or flagText ~= "CRITICAL" or not IsHostileTarget() then
		return
	end
	-- A secret amount only matters when a minimum is set.
	if ns.db.minDamage > 0 and (issecretvalue(amount) or (amount or 0) < ns.db.minDamage) then
		return
	end
	local category = GetCurrentCategory()
	if category and ns.db.categories[category] then
		ns.PlayCrit(category)
	end
end

frame:SetScript("OnEvent", function(_, event, ...)
	handlers[event](...)
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

local CHANNELS = { master = "Master", sfx = "SFX" }

SLASH_CRITRAG1 = "/critrag"
SlashCmdList.CRITRAG = function(msg)
	local cmd, arg = strsplit(" ", strlower(strtrim(msg or "")), 2)
	if cmd == "" then
		ns.OpenOptions()
	elseif cmd == "status" then
		Print(L.STATUS:format(
			ns.db.enabled and L.ON or L.OFF,
			ns.db.channel,
			ns.db.minDamage,
			GetCurrentCategory() or "-"))
		Print(L.USAGE)
	elseif cmd == "on" or cmd == "off" then
		ns.db.enabled = cmd == "on"
		ns.UpdateEnabled()
		Print(ns.db.enabled and L.ENABLED_MSG or L.DISABLED_MSG)
	elseif cmd == "test" then
		if arg ~= "generic" and ns.db.categories[arg or ""] == nil then
			Print(L.UNKNOWN_CATEGORY:format(arg or "", table.concat(ns.WEAPON_CATEGORIES, ", ") .. ", generic"))
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
