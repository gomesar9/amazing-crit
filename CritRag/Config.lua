local _, ns = ...

local DB_VERSION = 3

-- Weapon categories in display order. Each key maps to item subclasses in Core.lua
-- and to a WEAPON_<KEY> locale string.
ns.WEAPON_CATEGORIES = {
	"sword", "axe", "mace", "dagger", "fist", "polearm", "staff",
	"bow", "gun", "crossbow", "wand", "thrown",
}

local categoryDefaults = {}
for _, category in ipairs(ns.WEAPON_CATEGORIES) do
	categoryDefaults[category] = true
end

ns.defaults = {
	version = DB_VERSION,
	enabled = true,
	channel = "Master",
	throttle = 0.15, -- seconds between two crit sounds
	minDamage = 0, -- crits below this amount are ignored (0 = any crit)
	categories = categoryDefaults, -- per-weapon on/off
	sounds = { -- categories without an entry use "generic"
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
	-- Future migrations go here, keyed by db.version.
	db.version = DB_VERSION
end

function ns.InitDB()
	if type(CritRagDB) ~= "table" then
		CritRagDB = {}
	end
	ApplyDefaults(CritRagDB, ns.defaults)
	Migrate(CritRagDB)
	ns.db = CritRagDB
end
