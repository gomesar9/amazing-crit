local _, ns = ...

local DB_VERSION = 4

-- Detection modes:
--   "source": uses only what UNIT_COMBAT reports for certain (which unit was hit
--             or healed, damage school). Ignores who caused the crit.
--   "weapon": guesses the player's weapon from the auto-attack state. Only
--             reliable when playing solo without a pet.
ns.MODES = { "source", "weapon" }

-- Sources for "source" mode, in display order. Each key is also a sound key and
-- maps to a SOURCE_<KEY> locale string.
ns.SOURCE_CATEGORIES = {
	"physical", "holy", "fire", "nature", "frost", "shadow", "arcane", -- crit damage on your target
	"heal_player", "heal_pet", "heal_target", -- crit heals received
	"taken_crit", "taken_crushing", -- damage you take
}

-- Weapon categories for "weapon" mode, in display order. Each key maps to item
-- subclasses in Core.lua and to a WEAPON_<KEY> locale string.
ns.WEAPON_CATEGORIES = {
	"sword", "axe", "mace", "dagger", "fist", "polearm", "staff",
	"bow", "gun", "crossbow", "wand", "thrown",
}

local function AllEnabled(keys)
	local tbl = {}
	for _, key in ipairs(keys) do
		tbl[key] = true
	end
	return tbl
end

ns.defaults = {
	version = DB_VERSION,
	enabled = true,
	mode = "source",
	channel = "Master",
	throttle = 0.15, -- seconds between two crit sounds
	minDamage = 0, -- crits (damage or heal) below this amount are ignored (0 = any crit)
	sources = AllEnabled(ns.SOURCE_CATEGORIES), -- per-source on/off ("source" mode)
	categories = AllEnabled(ns.WEAPON_CATEGORIES), -- per-weapon on/off ("weapon" mode)
	sounds = { -- keys without an entry use "generic"
		bow = "bow.ogg",
		sword = "sword.ogg",
		generic = "generic.ogg",
	},
}

-- Fills missing keys from defaults without overwriting user values.
local function ApplyDefaults(db, defaults)
	for k, v in pairs(defaults) do
		if db[k] == nil then
			db[k] = type(v) == "table" and CopyTable(v) or v
		elseif type(v) == "table" and type(db[k]) == "table" then
			ApplyDefaults(db[k], v)
		end
	end
end

local function Migrate(db)
	-- v1 -> v2: added "categories"; filled by ApplyDefaults, nothing to convert.
	-- v2 -> v3: new weapon categories and sounds.generic; also filled by ApplyDefaults.
	-- v3 -> v4: added "mode" and "sources"; existing users keep the weapon behavior
	-- they already had.
	if (db.version or 1) < 4 then
		db.mode = "weapon"
	end
	-- Future migrations go here, keyed by db.version.
	db.version = DB_VERSION
end

function ns.InitDB()
	if type(AmazingCritDB) ~= "table" then
		-- New installs start at the current version, so Migrate leaves them alone.
		AmazingCritDB = { version = DB_VERSION }
	end
	ApplyDefaults(AmazingCritDB, ns.defaults)
	Migrate(AmazingCritDB)
	ns.db = AmazingCritDB
end
