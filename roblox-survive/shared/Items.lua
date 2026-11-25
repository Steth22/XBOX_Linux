-- Item catalogue + real 3D models (used in the hand and as UI icons).
local I = {}

local WOOD = Color3.fromRGB(120, 82, 50)
local STEEL = Color3.fromRGB(165, 170, 178)
local DARK = Color3.fromRGB(46, 46, 52)

-- kind: res | food | heal | tool (swing) | ranged | ammo | place
I.defs = {
	wood = { ar = "خشب", en = "Wood", kind = "res", stack = 50, sell = 2 },
	stone = { ar = "حجر", en = "Stone", kind = "res", stack = 50, sell = 3 },
	iron = { ar = "حديد", en = "Iron", kind = "res", stack = 40, sell = 10 },
	gold = { ar = "ذهب", en = "Gold", kind = "res", stack = 30, sell = 25 },
	diamond = { ar = "ألماس", en = "Diamond", kind = "res", stack = 20, sell = 60 },
	hide = { ar = "جلد", en = "Hide", kind = "res", stack = 20, sell = 45 },
	hide_desert = { ar = "جلد صحراوي", en = "Desert Hide", kind = "res", stack = 20, sell = 110 },
	hide_snow = { ar = "جلد ثلجي", en = "Snow Hide", kind = "res", stack = 20, sell = 220 },
	crystal = { ar = "بلّور", en = "Crystal", kind = "res", stack = 30, sell = 40 },
	obsidian = { ar = "سَبَج", en = "Obsidian", kind = "res", stack = 20, sell = 95 },
	mushroom = { ar = "فطر الكهف", en = "Cave Mushroom", kind = "food", stack = 20, hunger = 16, heal = 6 },
	berries = { ar = "توت", en = "Berries", kind = "food", stack = 20, hunger = 12, heal = 2, buy = 6, buyQty = 2, sell = 1 },
	meat_raw = { ar = "لحم نيئ", en = "Raw Meat", kind = "food", stack = 20, hunger = 12, heal = 0 },
	meat_cooked = { ar = "لحم مطبوخ", en = "Cooked Meat", kind = "food", stack = 20, hunger = 40, heal = 10 },
	bandage = { ar = "ضماد", en = "Bandage", kind = "heal", stack = 10, heal = 35, buy = 25 },
	wood_axe = { ar = "فأس خشبي", en = "Wood Axe", kind = "tool", class = "axe", stack = 1, tree = 3, rock = 1, dmg = 10, dur = 150, buy = 30 },
	wood_pickaxe = { ar = "معول خشبي", en = "Wood Pickaxe", kind = "tool", class = "pickaxe", stack = 1, tree = 1, rock = 3, dmg = 8, dur = 150, buy = 40 },
	wood_sword = { ar = "سيف خشبي", en = "Wood Sword", kind = "tool", class = "sword", stack = 1, dmg = 18, dur = 120, buy = 60 },
	iron_sword = { ar = "سيف حديدي", en = "Iron Sword", kind = "tool", class = "sword", stack = 1, dmg = 34, dur = 320, buy = 320 },
	bow = { ar = "قوس", en = "Bow", kind = "ranged", stack = 1, dmg = 26, range = 170, rate = 0.8, ammo = "arrow", dur = 220, buy = 130 },
	pistol = { ar = "مسدس", en = "Pistol", kind = "ranged", stack = 1, dmg = 40, range = 230, rate = 0.35, ammo = "ammo", dur = 400, buy = 650 },
	arrow = { ar = "سهام", en = "Arrows", kind = "ammo", stack = 60, buy = 20, buyQty = 10 },
	ammo = { ar = "رصاص", en = "Bullets", kind = "ammo", stack = 90, buy = 45, buyQty = 15 },
	trap = { ar = "فخ", en = "Trap", kind = "place", stack = 5, buy = 80 },
	campfire = { ar = "نار مخيم", en = "Campfire", kind = "place", stack = 5, buy = 30 },
}

-- tool tiers: stone / iron / diamond versions of the axe, pickaxe and sword
local TIERS = {
	{ key = "stone", ar = "حجري", en = "Stone", head = Color3.fromRGB(128, 128, 134), mat = Enum.Material.Slate, power = 1, mult = 1.35, dur = 1.6, price = 2.3 },
	{ key = "iron", ar = "حديدي", en = "Iron", head = Color3.fromRGB(196, 200, 208), mat = Enum.Material.Metal, power = 2, mult = 1.8, dur = 2.5, price = 5.5 },
	{ key = "diamond", ar = "ألماسي", en = "Diamond", head = Color3.fromRGB(110, 225, 250), mat = Enum.Material.Glass, power = 4, mult = 2.6, dur = 4.5, price = 15 },
}
for _, t in ipairs(TIERS) do
	I.defs[t.key .. "_axe"] = { ar = "فأس " .. t.ar, en = t.en .. " Axe", kind = "tool", class = "axe", stack = 1, tree = 3 + t.power, rock = 1 + math.floor(t.power / 2), dmg = math.floor(10 * t.mult), dur = math.floor(150 * t.dur), buy = math.floor(30 * t.price), tier = t }
	I.defs[t.key .. "_pickaxe"] = { ar = "معول " .. t.ar, en = t.en .. " Pickaxe", kind = "tool", class = "pickaxe", stack = 1, tree = 1, rock = 3 + t.power, dmg = math.floor(8 * t.mult), dur = math.floor(150 * t.dur), buy = math.floor(40 * t.price), tier = t }
	if t.key ~= "iron" then
		I.defs[t.key .. "_sword"] = { ar = "سيف " .. t.ar, en = t.en .. " Sword", kind = "tool", class = "sword", stack = 1, dmg = math.floor(18 * t.mult * 1.05), dur = math.floor(120 * t.dur), buy = math.floor(60 * t.price), tier = t }
	end
end

-- armor: worn on the body, reduces damage taken
I.defs.leather_armor = { ar = "درع جلدي", en = "Leather Armor", kind = "armor", stack = 1, reduce = 0.15, buy = 140, color = Color3.fromRGB(140, 96, 60), mat = Enum.Material.Fabric }
I.defs.iron_armor = { ar = "درع حديدي", en = "Iron Armor", kind = "armor", stack = 1, reduce = 0.30, buy = 480, color = Color3.fromRGB(150, 155, 166), mat = Enum.Material.Metal }
I.defs.diamond_armor = { ar = "درع ألماسي", en = "Diamond Armor", kind = "armor", stack = 1, reduce = 0.45, buy = 1400, color = Color3.fromRGB(80, 176, 214), mat = Enum.Material.Metal }

-- weapons and gear sold at the outposts
I.defs.spear = { ar = "رمح حديدي", en = "Iron Spear", kind = "tool", class = "spear", stack = 1, dmg = 30, reach = 9, dur = 300, buy = 260 }
I.defs.ice_spear = { ar = "رمح جليدي", en = "Ice Spear", kind = "tool", class = "spear", stack = 1, dmg = 48, reach = 9.5, dur = 520, buy = 750 }
I.defs.scimitar = { ar = "سيف معقوف", en = "Scimitar", kind = "tool", class = "sword", stack = 1, dmg = 40, dur = 360, buy = 620 }
I.defs.war_hammer = { ar = "مطرقة حرب", en = "War Hammer", kind = "tool", class = "hammer", stack = 1, dmg = 62, tree = 2, rock = 6, dur = 420, buy = 1150 }
I.defs.crossbow = { ar = "قوس ونشاب", en = "Crossbow", kind = "ranged", stack = 1, dmg = 46, range = 210, rate = 1.1, ammo = "bolt", dur = 300, buy = 480 }
I.defs.bolt = { ar = "سهام نشاب", en = "Bolts", kind = "ammo", stack = 60, buy = 35, buyQty = 10 }
I.defs.rifle = { ar = "بندقية", en = "Rifle", kind = "ranged", stack = 1, dmg = 72, range = 320, rate = 1.4, ammo = "rifle_ammo", dur = 450, buy = 1500 }
I.defs.rifle_ammo = { ar = "طلقات بندقية", en = "Rifle Rounds", kind = "ammo", stack = 60, buy = 90, buyQty = 10 }
I.defs.dynamite = { ar = "ديناميت", en = "Dynamite", kind = "place", stack = 10, buy = 120 }
I.defs.warm_coat = { ar = "معطف دافئ", en = "Warm Coat", kind = "armor", stack = 1, reduce = 0.2, warm = 16, buy = 420, color = Color3.fromRGB(150, 110, 80), mat = Enum.Material.Fabric }
I.defs.desert_cloak = { ar = "عباءة الصحراء", en = "Desert Cloak", kind = "armor", stack = 1, reduce = 0.2, cool = 16, buy = 420, color = Color3.fromRGB(226, 206, 160), mat = Enum.Material.Fabric }

-- region gear
I.defs.coconut = { ar = "جوز هند", en = "Coconut", kind = "food", stack = 20, hunger = 22, heal = 5, buy = 12 }
I.defs.harpoon = { ar = "حربة", en = "Harpoon", kind = "tool", class = "spear", stack = 1, dmg = 52, reach = 10, dur = 480, buy = 900 }
I.defs.machete = { ar = "منجل الأدغال", en = "Machete", kind = "tool", class = "sword", stack = 1, dmg = 46, tree = 5, dur = 420, buy = 760 }
I.defs.magma_blade = { ar = "سيف الحمم", en = "Magma Blade", kind = "tool", class = "sword", stack = 1, dmg = 70, dur = 600, buy = 2200 }
I.defs.lava_cloak = { ar = "عباءة الحمم", en = "Lava Cloak", kind = "armor", stack = 1, reduce = 0.25, cool = 24, buy = 900, color = Color3.fromRGB(90, 40, 30), mat = Enum.Material.Fabric }
I.defs.jungle_vest = { ar = "سترة الأدغال", en = "Jungle Vest", kind = "armor", stack = 1, reduce = 0.22, cool = 12, buy = 520, color = Color3.fromRGB(70, 100, 60), mat = Enum.Material.Fabric }

-- light: burns only while held, `dur` = seconds of light left
I.defs.lantern = { ar = "مصباح", en = "Lantern", kind = "light", stack = 1, dur = 720, buy = 1000 }
-- secret market goods (never below 300)
I.defs.bed = { ar = "سرير", en = "Bed", kind = "place", stack = 1, buy = 900 }
I.defs.shadow_blade = { ar = "سيف الظل", en = "Shadow Blade", kind = "tool", class = "sword", stack = 1, dmg = 86, dur = 700, buy = 3200 }
I.potions = {
	{ id = "potion_speed", ar = "جرعة السرعة", en = "Speed Potion", buff = "speed", time = 120, buy = 350, color = Color3.fromRGB(90, 200, 255) },
	{ id = "potion_strength", ar = "جرعة القوة", en = "Strength Potion", buff = "strength", time = 120, buy = 450, color = Color3.fromRGB(230, 70, 60) },
	{ id = "potion_regen", ar = "جرعة التجدد", en = "Regen Potion", buff = "regen", time = 40, buy = 320, color = Color3.fromRGB(110, 230, 120) },
	{ id = "potion_stone", ar = "جرعة الحصانة", en = "Stoneskin Potion", buff = "stone", time = 90, buy = 500, color = Color3.fromRGB(160, 150, 140) },
	{ id = "potion_vision", ar = "جرعة الرؤية الليلية", en = "Night Vision Potion", buff = "vision", time = 240, buy = 380, color = Color3.fromRGB(190, 120, 255) },
	{ id = "potion_warmth", ar = "جرعة الدفء", en = "Warmth Potion", buff = "warmth", time = 300, buy = 300, color = Color3.fromRGB(255, 160, 60) },
}
for _, p in ipairs(I.potions) do
	I.defs[p.id] = { ar = p.ar, en = p.en, kind = "potion", stack = 5, buff = p.buff, time = p.time, buy = p.buy, color = p.color }
end

-- shop categories (the bag is shown under "supplies")
I.shopCats = {
	{ key = "tools", ids = { "wood_axe", "stone_axe", "iron_axe", "diamond_axe", "wood_pickaxe", "stone_pickaxe", "iron_pickaxe", "diamond_pickaxe" } },
	{ key = "weapons", ids = { "wood_sword", "stone_sword", "iron_sword", "diamond_sword", "bow", "arrow", "pistol", "ammo" } },
	{ key = "armor", ids = { "leather_armor", "iron_armor", "diamond_armor" } },
	{ key = "supplies", ids = { "bandage", "berries", "trap", "campfire", "lantern" } },
}

-- each trader has its own stock: forest = the main camp, the others are outposts in each region
I.shops = {
	forest = I.shopCats,
	snow = {
		{ key = "weapons", ids = { "spear", "ice_spear", "crossbow", "bolt" } },
		{ key = "armor", ids = { "warm_coat", "iron_armor" } },
		{ key = "supplies", ids = { "bandage", "campfire", "berries", "lantern" } },
	},
	desert = {
		{ key = "weapons", ids = { "scimitar", "rifle", "rifle_ammo", "pistol", "ammo" } },
		{ key = "armor", ids = { "desert_cloak", "iron_armor" } },
		{ key = "supplies", ids = { "bandage", "berries", "trap", "lantern" } },
	},
	mountains = {
		{ key = "tools", ids = { "iron_pickaxe", "diamond_pickaxe", "war_hammer" } },
		{ key = "weapons", ids = { "war_hammer", "crossbow", "bolt", "dynamite" } },
		{ key = "armor", ids = { "iron_armor", "diamond_armor" } },
		{ key = "supplies", ids = { "bandage", "lantern" } },
	},
	beach = {
		{ key = "weapons", ids = { "harpoon", "spear", "crossbow", "bolt" } },
		{ key = "supplies", ids = { "coconut", "bandage", "campfire", "lantern" } },
	},
	jungle = {
		{ key = "weapons", ids = { "machete", "bow", "arrow" } },
		{ key = "armor", ids = { "jungle_vest", "iron_armor" } },
		{ key = "supplies", ids = { "bandage", "berries", "trap", "lantern" } },
	},
	volcano = {
		{ key = "weapons", ids = { "magma_blade", "war_hammer", "dynamite" } },
		{ key = "armor", ids = { "lava_cloak", "diamond_armor" } },
		{ key = "tools", ids = { "diamond_pickaxe", "diamond_axe" } },
		{ key = "supplies", ids = { "bandage", "lantern" } },
	},
	-- village traders: everyday goods
	village = {
		{ key = "supplies", ids = { "berries", "coconut", "bandage", "campfire", "trap", "lantern" } },
		{ key = "tools", ids = { "wood_axe", "stone_axe", "wood_pickaxe", "stone_pickaxe" } },
		{ key = "weapons", ids = { "wood_sword", "stone_sword", "bow", "arrow" } },
	},
	-- the secret trader: open day and night, moves around the map
	black = {
		{ key = "special", ids = { "bed", "shadow_blade", "lantern" } },
		{ key = "potions", ids = { "potion_speed", "potion_strength", "potion_regen", "potion_stone", "potion_vision", "potion_warmth" } },
	},
}
function I.inShop(shop, id)
	for _, cat in ipairs(I.shops[shop] or {}) do
		for _, x in ipairs(cat.ids) do if x == id then return true end end
	end
	return false
end

I.shop = {
	"wood_axe", "stone_axe", "iron_axe", "diamond_axe",
	"wood_pickaxe", "stone_pickaxe", "iron_pickaxe", "diamond_pickaxe",
	"wood_sword", "stone_sword", "iron_sword", "diamond_sword",
	"leather_armor", "iron_armor", "diamond_armor",
	"bow", "arrow", "pistol", "ammo", "trap", "campfire", "bandage", "berries",
}

function I.get(id) return I.defs[id] end
function I.stack(id) local d = I.defs[id]; return d and d.stack or 1 end
function I.name(id, lang)
	local d = I.defs[id]
	if not d then return tostring(id) end
	return lang == "en" and d.en or d.ar
end
function I.held(id) -- items that go into the hand when selected
	return I.defs[id] ~= nil
end

---------------------------------------------------------------- models
-- spec = { size, cf (relative to handle), color, material, shape }. Parts made with H() are the metal head
-- of a tool: tier versions (stone / iron / diamond...) recolour only those. `edge` parts get a lighter tone.
-- Tool axes: the handle runs along +Z (head at +Z), blades point to -X.
local function P(size, cf, color, material, shape)
	return { size = size, cf = cf or CFrame.new(), color = color, material = material or Enum.Material.SmoothPlastic, shape = shape }
end
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local A = CFrame.Angles
local r = math.rad
local function H(size, cf, color, material, shape)
	local p = P(size, cf, color, material or Enum.Material.Metal, shape)
	p.head = true
	return p
end
local function E(size, cf, color, material, shape)
	local p = H(size, cf, color, material, shape)
	p.edge = true
	return p
end
local function shade(p) p.shade = true return p end
local Z = A(0, r(90), 0) -- cylinder axis X -> Z
local Y = A(0, 0, r(90)) -- cylinder axis X -> Y
local function rodZ(len, d, z, color, mat, x, y) return P(Vector3.new(len, d, d), CFrame.new(x or 0, y or 0, z) * Z, color, mat, CYL) end

local LEATHER = Color3.fromRGB(78, 54, 36)
local DARKWOOD = Color3.fromRGB(86, 60, 40)
local GOLD = Color3.fromRGB(214, 172, 74)
local BRASS = Color3.fromRGB(200, 160, 80)
local GUNMETAL = Color3.fromRGB(58, 60, 66)
local IRONC = Color3.fromRGB(120, 122, 128)

local SPECS = {}

---------------------------------------------------------------- tools
-- axe: a real wedge blade that widens towards the cutting edge
local function axeSpec(head)
	return {
		rodZ(3.7, 0.34, 0.05, WOOD, Enum.Material.Wood),
		rodZ(1.0, 0.4, -1.2, LEATHER, Enum.Material.Fabric),
		P(Vector3.new(0.48, 0.48, 0.48), CFrame.new(0, 0, -1.88), DARKWOOD, Enum.Material.Wood, BALL),
		H(Vector3.new(0.62, 0.52, 0.78), CFrame.new(0.05, 0, 1.45), head),
		H(Vector3.new(1.0, 0.2, 0.86), CFrame.new(-0.78, 0, 1.45), head),
		H(Vector3.new(1.02, 0.18, 0.42), CFrame.new(-0.86, 0, 1.78) * A(0, r(-24), 0), head),
		H(Vector3.new(1.02, 0.18, 0.42), CFrame.new(-0.86, 0, 1.12) * A(0, r(24), 0), head),
		E(Vector3.new(0.14, 0.16, 1.78), CFrame.new(-1.36, 0, 1.45), head),
		shade(H(Vector3.new(0.38, 0.44, 0.52), CFrame.new(0.52, 0, 1.45), head)),
		P(Vector3.new(0.3, 0.3, 0.2), CFrame.new(0, 0, 1.94), DARKWOOD, Enum.Material.Wood),
	}
end
-- pickaxe: a curved two-pointed head
local function pickSpec(head)
	local s = {
		rodZ(3.7, 0.34, 0.05, WOOD, Enum.Material.Wood),
		rodZ(1.0, 0.4, -1.2, LEATHER, Enum.Material.Fabric),
		P(Vector3.new(0.48, 0.48, 0.48), CFrame.new(0, 0, -1.88), DARKWOOD, Enum.Material.Wood, BALL),
		shade(H(Vector3.new(0.6, 0.5, 0.62), CFrame.new(0, 0, 1.5), head)),
	}
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(s, H(Vector3.new(0.82, 0.36, 0.42), CFrame.new(sx * 0.66, 0, 1.46) * A(0, r(sx * 8), 0), head))
		table.insert(s, H(Vector3.new(0.72, 0.28, 0.34), CFrame.new(sx * 1.24, 0, 1.33) * A(0, r(sx * 20), 0), head))
		table.insert(s, E(Vector3.new(0.52, 0.2, 0.22), CFrame.new(sx * 1.66, 0, 1.12) * A(0, r(sx * 36), 0), head))
	end
	return s
end
-- sword: wrapped grip, guard, blade with a darker fuller and a real point
local function swordSpec(blade, guard, mat)
	return {
		rodZ(1.1, 0.36, 0, LEATHER, Enum.Material.Fabric),
		rodZ(0.12, 0.42, -0.3, guard or GOLD, Enum.Material.Metal),
		rodZ(0.12, 0.42, 0.3, guard or GOLD, Enum.Material.Metal),
		P(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0, -0.68), guard or GOLD, Enum.Material.Metal, BALL),
		P(Vector3.new(1.7, 0.3, 0.3), CFrame.new(0, 0, 0.68), guard or GOLD, Enum.Material.Metal),
		P(Vector3.new(0.36, 0.36, 0.36), CFrame.new(-0.86, 0, 0.68), guard or GOLD, Enum.Material.Metal, BALL),
		P(Vector3.new(0.36, 0.36, 0.36), CFrame.new(0.86, 0, 0.68), guard or GOLD, Enum.Material.Metal, BALL),
		H(Vector3.new(0.64, 0.14, 3.0), CFrame.new(0, 0, 2.3), blade, mat),
		shade(H(Vector3.new(0.14, 0.17, 2.5), CFrame.new(0, 0, 2.1), blade, mat)),
		E(Vector3.new(0.08, 0.15, 3.0), CFrame.new(-0.31, 0, 2.3), blade, mat),
		E(Vector3.new(0.08, 0.15, 3.0), CFrame.new(0.31, 0, 2.3), blade, mat),
		H(Vector3.new(0.46, 0.13, 0.46), CFrame.new(0, 0, 3.82) * A(0, r(45), 0), blade, mat),
	}
end

SPECS.wood_axe = axeSpec(Color3.fromRGB(150, 152, 158))
SPECS.wood_pickaxe = pickSpec(Color3.fromRGB(150, 152, 158))
SPECS.wood_sword = {
	rodZ(1.1, 0.36, 0, LEATHER, Enum.Material.Fabric),
	P(Vector3.new(0.46, 0.46, 0.46), CFrame.new(0, 0, -0.66), DARKWOOD, Enum.Material.Wood, BALL),
	P(Vector3.new(1.4, 0.32, 0.3), CFrame.new(0, 0, 0.66), DARKWOOD, Enum.Material.Wood),
	P(Vector3.new(0.62, 0.2, 2.9), CFrame.new(0, 0, 2.25), Color3.fromRGB(196, 164, 116), Enum.Material.Wood),
	P(Vector3.new(0.44, 0.19, 0.44), CFrame.new(0, 0, 3.7) * A(0, r(45), 0), Color3.fromRGB(196, 164, 116), Enum.Material.Wood),
}
SPECS.iron_sword = swordSpec(STEEL, GOLD, Enum.Material.Metal)

-- bow: recurve limbs, wrapped grip, a taut string
SPECS.bow = { P(Vector3.new(0.42, 0.42, 0.9), nil, LEATHER, Enum.Material.Fabric) }
for _, sz in ipairs({ 1, -1 }) do
	table.insert(SPECS.bow, P(Vector3.new(0.28, 0.32, 1.0), CFrame.new(-0.12, 0, sz * 0.88) * A(0, r(-sz * 12), 0), WOOD, Enum.Material.Wood))
	table.insert(SPECS.bow, P(Vector3.new(0.23, 0.27, 0.92), CFrame.new(-0.42, 0, sz * 1.72) * A(0, r(-sz * 26), 0), WOOD, Enum.Material.Wood))
	table.insert(SPECS.bow, P(Vector3.new(0.18, 0.22, 0.5), CFrame.new(-0.5, 0, sz * 2.22) * A(0, r(sz * 22), 0), DARKWOOD, Enum.Material.Wood))
end
table.insert(SPECS.bow, P(Vector3.new(0.05, 0.05, 4.7), CFrame.new(-0.42, 0, 0), Color3.fromRGB(235, 232, 220)))

-- crossbow (points to +Z, top is -X)
SPECS.crossbow = {
	P(Vector3.new(0.38, 0.4, 2.8), CFrame.new(0, 0, 0.6), WOOD, Enum.Material.Wood),
	P(Vector3.new(0.75, 0.42, 0.9), CFrame.new(0.12, 0, -1.05), DARKWOOD, Enum.Material.Wood),
	P(Vector3.new(0.1, 0.14, 2.3), CFrame.new(-0.22, 0, 0.75), GUNMETAL, Enum.Material.Metal),
	H(Vector3.new(0.42, 0.55, 0.45), CFrame.new(-0.12, 0, 1.85), IRONC),
	P(Vector3.new(0.5, 0.12, 0.14), CFrame.new(0.32, 0, 0.1), GUNMETAL, Enum.Material.Metal),
	P(Vector3.new(0.5, 0.3, 0.36), CFrame.new(0.4, 0, -0.2), DARKWOOD, Enum.Material.Wood),
	P(Vector3.new(0.08, 0.08, 1.5), CFrame.new(-0.32, 0, 1.15), WOOD, Enum.Material.Wood),
	P(Vector3.new(0.16, 0.16, 0.3), CFrame.new(-0.32, 0, 1.95), STEEL, Enum.Material.Metal),
	P(Vector3.new(0.04, 2.9, 0.04), CFrame.new(-0.18, 0, 1.52), Color3.fromRGB(235, 232, 220)),
}
for _, sy in ipairs({ -1, 1 }) do
	table.insert(SPECS.crossbow, P(Vector3.new(0.2, 1.45, 0.24), CFrame.new(-0.12, sy * 0.78, 1.76) * A(r(-sy * 14), 0, 0), DARKWOOD, Enum.Material.Wood))
end

-- pistol (points to -X, top is +Z)
SPECS.pistol = {
	P(Vector3.new(0.55, 0.36, 1.15), CFrame.new(0.42, 0, -0.18) * A(0, r(-14), 0), GUNMETAL, Enum.Material.Metal),
	P(Vector3.new(0.45, 0.4, 0.8), CFrame.new(0.44, 0, -0.22) * A(0, r(-14), 0), Color3.fromRGB(110, 72, 46), Enum.Material.Wood),
	P(Vector3.new(1.95, 0.38, 0.46), CFrame.new(-0.42, 0, 0.6), Color3.fromRGB(78, 80, 88), Enum.Material.Metal),
	P(Vector3.new(1.45, 0.32, 0.26), CFrame.new(-0.28, 0, 0.26), GUNMETAL, Enum.Material.Metal),
	P(Vector3.new(0.22, 0.22, 0.22), CFrame.new(-1.44, 0, 0.62) * Y, GUNMETAL, Enum.Material.Metal, CYL),
	P(Vector3.new(0.06, 0.12, 0.12), CFrame.new(-1.56, 0, 0.62), Color3.fromRGB(10, 10, 12), nil, CYL),
	P(Vector3.new(0.5, 0.1, 0.08), CFrame.new(0.02, 0, -0.08), GUNMETAL, Enum.Material.Metal),
	P(Vector3.new(0.08, 0.1, 0.3), CFrame.new(-0.22, 0, 0.0), GUNMETAL, Enum.Material.Metal),
	P(Vector3.new(0.06, 0.12, 0.26), CFrame.new(0.06, 0, 0.0), Color3.fromRGB(30, 30, 34), Enum.Material.Metal),
	P(Vector3.new(0.1, 0.1, 0.12), CFrame.new(-1.3, 0, 0.88), GUNMETAL, Enum.Material.Metal),
	P(Vector3.new(0.12, 0.28, 0.12), CFrame.new(0.45, 0, 0.88), GUNMETAL, Enum.Material.Metal),
}
for i = 0, 3 do table.insert(SPECS.pistol, P(Vector3.new(0.05, 0.4, 0.4), CFrame.new(0.2 + i * 0.1, 0, 0.62), Color3.fromRGB(40, 42, 46), Enum.Material.Metal)) end

-- rifle (points to +Z, top is -X): stock, scope, bolt, magazine
SPECS.rifle = {
	P(Vector3.new(0.62, 0.36, 1.4), CFrame.new(0.16, 0, -0.95), Color3.fromRGB(110, 74, 46), Enum.Material.Wood),
	P(Vector3.new(0.66, 0.4, 0.14), CFrame.new(0.16, 0, -1.68), Color3.fromRGB(40, 36, 32), Enum.Material.Fabric),
	P(Vector3.new(0.42, 0.32, 0.8), CFrame.new(0.05, 0, -0.1) * A(0, r(10), 0), Color3.fromRGB(110, 74, 46), Enum.Material.Wood),
	P(Vector3.new(0.42, 0.36, 1.1), CFrame.new(-0.2, 0, 0.6), GUNMETAL, Enum.Material.Metal),
	P(Vector3.new(0.36, 0.34, 1.7), CFrame.new(-0.1, 0, 1.8), Color3.fromRGB(110, 74, 46), Enum.Material.Wood),
	rodZ(3.0, 0.2, 2.3, GUNMETAL, Enum.Material.Metal, -0.32),
	rodZ(0.28, 0.27, 3.75, Color3.fromRGB(36, 36, 40), Enum.Material.Metal, -0.32),
	rodZ(1.3, 0.3, 0.7, Color3.fromRGB(30, 32, 36), Enum.Material.Metal, -0.66),
	rodZ(0.25, 0.4, 0.05, Color3.fromRGB(30, 32, 36), Enum.Material.Metal, -0.66),
	rodZ(0.25, 0.4, 1.35, Color3.fromRGB(30, 32, 36), Enum.Material.Metal, -0.66),
	P(Vector3.new(0.05, 0.3, 0.3), CFrame.new(-0.66, 0, 1.49) * Z, Color3.fromRGB(120, 180, 220), Enum.Material.Glass, CYL),
	P(Vector3.new(0.2, 0.12, 0.14), CFrame.new(-0.45, 0, 0.3), GUNMETAL, Enum.Material.Metal),
	P(Vector3.new(0.2, 0.12, 0.14), CFrame.new(-0.45, 0, 1.1), GUNMETAL, Enum.Material.Metal),
	P(Vector3.new(0.1, 0.5, 0.1), CFrame.new(-0.25, 0.32, 0.35), GUNMETAL, Enum.Material.Metal),
	P(Vector3.new(0.18, 0.18, 0.18), CFrame.new(-0.25, 0.58, 0.35), GUNMETAL, Enum.Material.Metal, BALL),
	P(Vector3.new(0.5, 0.26, 0.42), CFrame.new(0.26, 0, 0.6), GUNMETAL, Enum.Material.Metal),
	P(Vector3.new(0.28, 0.08, 0.46), CFrame.new(0.26, 0, 0.12), GUNMETAL, Enum.Material.Metal),
}

-- spears: long shaft, leaf-shaped head on a socket, a binding
local function spearSpec(head, mat, barbs)
	local s = {
		rodZ(6.2, 0.28, 1.4, WOOD, Enum.Material.Wood),
		rodZ(0.7, 0.34, -0.2, LEATHER, Enum.Material.Fabric),
		rodZ(0.5, 0.32, 4.55, head, mat),
		H(Vector3.new(0.56, 0.12, 0.9), CFrame.new(0, 0, 5.15), head, mat),
		H(Vector3.new(0.4, 0.11, 0.4), CFrame.new(0, 0, 5.62) * A(0, r(45), 0), head, mat),
		E(Vector3.new(0.06, 0.13, 0.85), CFrame.new(0, 0, 5.15), head, mat),
	}
	if barbs then
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(s, H(Vector3.new(0.5, 0.1, 0.12), CFrame.new(sx * 0.32, 0, 4.82) * A(0, r(sx * 40), 0), head, mat))
		end
		table.insert(s, P(Vector3.new(0.12, 0.6, 0.6), CFrame.new(0, 0, 3.9) * Z, Color3.fromRGB(210, 196, 160), Enum.Material.Fabric, CYL))
	end
	return s
end
SPECS.spear = spearSpec(STEEL, Enum.Material.Metal)
SPECS.ice_spear = spearSpec(Color3.fromRGB(150, 225, 255), Enum.Material.Glass)
SPECS.harpoon = spearSpec(Color3.fromRGB(120, 130, 140), Enum.Material.Metal, true)

-- curved blades from segments that bend more towards the tip
local function curvedSpec(blade, wide)
	local s = {
		rodZ(1.1, 0.34, 0, Color3.fromRGB(120, 60, 40), Enum.Material.Fabric),
		P(Vector3.new(0.44, 0.44, 0.44), CFrame.new(0, 0, -0.66), GOLD, Enum.Material.Metal, BALL),
		P(Vector3.new(1.3, 0.28, 0.28), CFrame.new(0, 0, 0.68), GOLD, Enum.Material.Metal),
	}
	local w = wide and 0.95 or 0.7
	local x, z, a = 0, 0.8, 0
	for i = 1, 4 do
		local len = 0.85
		a += wide and 5 or 9
		local cx = x - math.sin(r(a)) * len / 2
		local cz = z + math.cos(r(a)) * len / 2
		table.insert(s, H(Vector3.new(w - i * 0.04, 0.13, len + 0.06), CFrame.new(cx - w * 0.12, 0, cz) * A(0, r(-a), 0), blade))
		x, z = cx - math.sin(r(a)) * len / 2, cz + math.cos(r(a)) * len / 2
	end
	table.insert(s, H(Vector3.new(0.4, 0.12, 0.4), CFrame.new(x - w * 0.2, 0, z) * A(0, r(45 - a), 0), blade))
	return s
end
SPECS.scimitar = curvedSpec(STEEL)
SPECS.machete = curvedSpec(Color3.fromRGB(150, 160, 150), true)

SPECS.war_hammer = {
	rodZ(3.8, 0.36, 0, WOOD, Enum.Material.Wood),
	rodZ(1.1, 0.42, -1.2, LEATHER, Enum.Material.Fabric),
	H(Vector3.new(1.5, 0.95, 0.95), CFrame.new(0, 0, 1.75), Color3.fromRGB(90, 92, 100)),
	E(Vector3.new(0.32, 1.15, 1.15), CFrame.new(-0.82, 0, 1.75) * Y, Color3.fromRGB(90, 92, 100), nil, CYL),
	E(Vector3.new(0.32, 1.15, 1.15), CFrame.new(0.82, 0, 1.75) * Y, Color3.fromRGB(90, 92, 100), nil, CYL),
	H(Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0, 2.38) * A(r(45), 0, r(45)), Color3.fromRGB(90, 92, 100)),
	P(Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, 0.49, 1.75), GOLD, Enum.Material.Metal, BALL),
}

---------------------------------------------------------------- ammo, throwables, placeables
local function arrowsSpec(len, head, fletch, n)
	local s = {}
	for i = 1, n do
		local ox, oy = (i - (n + 1) / 2) * 0.3, (i % 2) * 0.16
		table.insert(s, rodZ(len, 0.1, 0, WOOD, Enum.Material.Wood, ox, oy))
		table.insert(s, P(Vector3.new(0.22, 0.22, 0.22), CFrame.new(ox, oy, len / 2 + 0.05) * A(r(45), 0, r(45)), head, Enum.Material.Metal))
		table.insert(s, P(Vector3.new(0.04, 0.32, 0.5), CFrame.new(ox, oy, -len / 2 + 0.35), fletch, Enum.Material.Fabric))
		table.insert(s, P(Vector3.new(0.32, 0.04, 0.5), CFrame.new(ox, oy, -len / 2 + 0.35), fletch, Enum.Material.Fabric))
	end
	return s
end
SPECS.arrow = arrowsSpec(2.6, STEEL, Color3.fromRGB(220, 70, 60), 3)
SPECS.bolt = arrowsSpec(1.7, STEEL, Color3.fromRGB(60, 60, 64), 3)

local function bulletsSpec(box, h, n)
	local s = { P(Vector3.new(1.3, 0.45, 0.8), CFrame.new(0, -0.1, 0), box, Enum.Material.Metal),
		P(Vector3.new(1.32, 0.12, 0.82), CFrame.new(0, 0.12, 0), box:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Metal) }
	for i = 1, n do
		local x = -0.45 + (i - 1) * (0.9 / (n - 1))
		table.insert(s, P(Vector3.new(h, 0.2, 0.2), CFrame.new(x, 0.15 + h / 2, 0) * Y, BRASS, Enum.Material.Metal, CYL))
		table.insert(s, P(Vector3.new(0.2, 0.2, 0.2), CFrame.new(x, 0.15 + h, 0), Color3.fromRGB(184, 110, 70), Enum.Material.Metal, BALL))
	end
	return s
end
SPECS.ammo = bulletsSpec(Color3.fromRGB(70, 90, 60), 0.4, 4)
SPECS.rifle_ammo = bulletsSpec(Color3.fromRGB(90, 80, 50), 0.75, 4)

-- three red sticks tied together, a fuse with a spark
SPECS.dynamite = {
	P(Vector3.new(1.3, 0.4, 0.4), CFrame.new(-0.22, 0, 0) * Y, Color3.fromRGB(196, 46, 38), nil, CYL),
	P(Vector3.new(1.3, 0.4, 0.4), CFrame.new(0.22, 0, 0) * Y, Color3.fromRGB(196, 46, 38), nil, CYL),
	P(Vector3.new(1.3, 0.4, 0.4), CFrame.new(0, 0, 0.36) * Y, Color3.fromRGB(196, 46, 38), nil, CYL),
	P(Vector3.new(0.86, 0.16, 0.78), CFrame.new(0, 0.28, 0.12), Color3.fromRGB(150, 130, 90), Enum.Material.Fabric),
	P(Vector3.new(0.86, 0.16, 0.78), CFrame.new(0, -0.3, 0.12), Color3.fromRGB(150, 130, 90), Enum.Material.Fabric),
	P(Vector3.new(0.6, 0.06, 0.06), CFrame.new(0.05, 0.95, 0.12) * A(0, 0, r(70)), Color3.fromRGB(70, 60, 50), Enum.Material.Fabric, CYL),
	P(Vector3.new(0.2, 0.2, 0.2), CFrame.new(0.16, 1.24, 0.12), Color3.fromRGB(255, 190, 60), Enum.Material.Neon, BALL),
}

-- bear trap: steel ring of jaws with teeth around a pressure plate
SPECS.trap = { P(Vector3.new(0.12, 1.5, 1.5), Y, Color3.fromRGB(70, 70, 76), Enum.Material.Metal, CYL),
	P(Vector3.new(0.1, 0.6, 0.6), CFrame.new(0, 0.12, 0) * Y, Color3.fromRGB(150, 140, 120), Enum.Material.Metal, CYL) }
for k = 0, 13 do
	local a = k / 14 * math.pi * 2
	local cx, cz = math.cos(a) * 0.72, math.sin(a) * 0.72
	table.insert(SPECS.trap, P(Vector3.new(0.12, 0.16, 0.36), CFrame.new(cx, 0.14, cz) * A(0, -a, 0), STEEL, Enum.Material.Metal))
	table.insert(SPECS.trap, P(Vector3.new(0.08, 0.26, 0.08), CFrame.new(cx * 0.92, 0.32, cz * 0.92), Color3.fromRGB(210, 214, 220), Enum.Material.Metal))
end
for _, sx in ipairs({ -1, 1 }) do
	table.insert(SPECS.trap, P(Vector3.new(0.8, 0.14, 0.26), CFrame.new(sx * 1.15, 0.08, 0), Color3.fromRGB(70, 70, 76), Enum.Material.Metal))
end

-- campfire: stone ring, leaning logs, flames
SPECS.campfire = { P(Vector3.new(0.55, 0.42, 0.55), nil, Color3.fromRGB(70, 46, 32), Enum.Material.Wood, BALL) }
for k = 0, 7 do
	local a = k / 8 * math.pi * 2
	table.insert(SPECS.campfire, P(Vector3.new(0.5, 0.5, 0.5), CFrame.new(math.cos(a) * 1.0, -0.05, math.sin(a) * 1.0), Color3.fromRGB(120, 120, 126), Enum.Material.Slate, BALL))
end
for k = 0, 2 do
	local a = k / 3 * math.pi * 2
	table.insert(SPECS.campfire, P(Vector3.new(1.5, 0.28, 0.28), CFrame.new(math.cos(a) * 0.32, 0.3, math.sin(a) * 0.32) * A(0, -a, 0) * A(0, 0, r(40)), WOOD, Enum.Material.Wood, CYL))
end
table.insert(SPECS.campfire, P(Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, 0.45, 0), Color3.fromRGB(255, 120, 30), Enum.Material.Neon, BALL))
table.insert(SPECS.campfire, P(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.7, 0), Color3.fromRGB(255, 200, 70), Enum.Material.Neon, BALL))
table.insert(SPECS.campfire, P(Vector3.new(0.28, 0.28, 0.28), CFrame.new(0.05, 1.0, 0), Color3.fromRGB(255, 150, 40), Enum.Material.Neon, BALL))

SPECS.lantern = { P(Vector3.new(0.9, 0.12, 0.9), CFrame.new(0, -0.7, 0), DARK, Enum.Material.Metal),
	P(Vector3.new(0.66, 1.1, 0.66), CFrame.new(0, 0, 0), Color3.fromRGB(255, 214, 140), Enum.Material.Neon),
	P(Vector3.new(0.9, 0.12, 0.9), CFrame.new(0, 0.62, 0), DARK, Enum.Material.Metal),
	P(Vector3.new(0.6, 0.2, 0.6), CFrame.new(0, 0.78, 0), DARK, Enum.Material.Metal),
	P(Vector3.new(0.6, 0.6, 0.08), CFrame.new(0, 1.12, 0), DARK, Enum.Material.Metal, CYL),
}
for _, o in ipairs({ { 0.4, 0.4 }, { -0.4, 0.4 }, { 0.4, -0.4 }, { -0.4, -0.4 } }) do
	table.insert(SPECS.lantern, P(Vector3.new(0.1, 1.3, 0.1), CFrame.new(o[1], 0, o[2]), DARK, Enum.Material.Metal))
end

SPECS.bed = { P(Vector3.new(3.2, 0.6, 6.2), CFrame.new(0, 0.3, 0), WOOD, Enum.Material.WoodPlanks),
	P(Vector3.new(3.0, 0.5, 5.9), CFrame.new(0, 0.85, 0.1), Color3.fromRGB(150, 50, 60), Enum.Material.Fabric),
	P(Vector3.new(3.04, 0.18, 2.4), CFrame.new(0, 1.12, 1.6), Color3.fromRGB(120, 40, 50), Enum.Material.Fabric),
	P(Vector3.new(2.4, 0.45, 1.1), CFrame.new(0, 1.2, -2.3), Color3.fromRGB(235, 230, 220), Enum.Material.Fabric),
	P(Vector3.new(3.2, 1.8, 0.4), CFrame.new(0, 1.2, -3.0), WOOD, Enum.Material.WoodPlanks),
	P(Vector3.new(3.2, 1.0, 0.3), CFrame.new(0, 0.8, 3.0), WOOD, Enum.Material.WoodPlanks) }

---------------------------------------------------------------- materials and food
SPECS.wood = { P(Vector3.new(2.4, 0.95, 0.95), CFrame.new(0, 0, 0.3) * A(0, r(90), 0), WOOD, Enum.Material.Wood, CYL),
	P(Vector3.new(2.2, 0.85, 0.85), CFrame.new(0.15, 0.75, -0.25) * A(0, r(80), 0), Color3.fromRGB(110, 76, 48), Enum.Material.Wood, CYL),
	P(Vector3.new(0.06, 0.82, 0.82), CFrame.new(0, 0, 1.52) * A(0, r(90), 0), Color3.fromRGB(206, 170, 120), Enum.Material.Wood, CYL),
	P(Vector3.new(0.06, 0.32, 0.32), CFrame.new(0, 0, 1.55) * A(0, r(90), 0), Color3.fromRGB(170, 130, 90), Enum.Material.Wood, CYL),
	P(Vector3.new(0.06, 0.74, 0.74), CFrame.new(0.15 + math.sin(r(80)) * 1.12, 0.75, -0.25 + math.cos(r(80)) * 1.12) * A(0, r(80), 0), Color3.fromRGB(206, 170, 120), Enum.Material.Wood, CYL) }
SPECS.stone = { P(Vector3.new(1.1, 0.85, 1.0), A(r(12), r(20), r(8)), Color3.fromRGB(128, 130, 136), Enum.Material.Slate),
	P(Vector3.new(0.75, 0.6, 0.7), CFrame.new(0.65, -0.12, 0.3) * A(r(30), r(40), 0), Color3.fromRGB(110, 112, 118), Enum.Material.Slate),
	P(Vector3.new(0.55, 0.45, 0.5), CFrame.new(-0.55, -0.2, 0.45) * A(r(10), r(60), r(20)), Color3.fromRGB(140, 142, 146), Enum.Material.Slate) }
-- bars: two ingots crossed
local function ingots(color)
	local s = {}
	for i, rot in ipairs({ 0, 90 }) do
		local y = (i - 1) * 0.5
		table.insert(s, P(Vector3.new(1.4, 0.34, 0.66), CFrame.new(0, y, 0) * A(0, r(rot), 0), color, Enum.Material.Metal))
		table.insert(s, P(Vector3.new(1.16, 0.18, 0.46), CFrame.new(0, y + 0.25, 0) * A(0, r(rot), 0), color:Lerp(Color3.new(1, 1, 1), 0.18), Enum.Material.Metal))
	end
	return s
end
SPECS.iron = ingots(Color3.fromRGB(150, 154, 162))
SPECS.gold = ingots(Color3.fromRGB(240, 192, 70))
-- cut gems: a flat table, a crown and a pointed pavilion
local function gem(color, mat, x, z, s)
	return {
		P(Vector3.new(0.3 * s, 1.0 * s, 1.0 * s), CFrame.new(x, 0.3 * s, z) * Y, color, mat, CYL),
		P(Vector3.new(0.18 * s, 0.6 * s, 0.6 * s), CFrame.new(x, 0.52 * s, z) * Y, color:Lerp(Color3.new(1, 1, 1), 0.3), mat, CYL),
		P(Vector3.new(0.68 * s, 0.68 * s, 0.68 * s), CFrame.new(x, -0.05 * s, z) * A(r(45), 0, r(35)), color, mat),
	}
end
SPECS.diamond = {}
for _, g in ipairs({ { 0, 0, 1 }, { 0.75, 0.4, 0.7 } }) do
	for _, p in ipairs(gem(Color3.fromRGB(150, 235, 255), Enum.Material.Glass, g[1], g[2], g[3])) do table.insert(SPECS.diamond, p) end
end
local function gemSpec(c1, c2, mat)
	return { P(Vector3.new(0.5, 1.3, 0.5), A(0, r(45), r(8)), c1, mat),
		P(Vector3.new(0.38, 0.9, 0.38), CFrame.new(0.4, -0.15, 0.1) * A(0, r(45), r(-25)), c2, mat),
		P(Vector3.new(0.34, 0.75, 0.34), CFrame.new(-0.36, -0.2, -0.1) * A(0, r(45), r(25)), c1, mat),
		P(Vector3.new(0.3, 0.6, 0.3), CFrame.new(0.05, -0.25, 0.42) * A(r(25), r(45), 0), c2, mat),
		P(Vector3.new(1.3, 0.3, 1.0), CFrame.new(0, -0.55, 0), Color3.fromRGB(90, 88, 96), Enum.Material.Slate) }
end
SPECS.crystal = gemSpec(Color3.fromRGB(150, 110, 255), Color3.fromRGB(190, 150, 255), Enum.Material.Glass)
SPECS.obsidian = gemSpec(Color3.fromRGB(40, 30, 55), Color3.fromRGB(70, 50, 90), Enum.Material.Glass)

-- pelts: body, four legs, neck and tail
local function pelt(c)
	local d = c:Lerp(Color3.new(0, 0, 0), 0.18)
	local s = { P(Vector3.new(1.5, 0.1, 1.9), nil, c, Enum.Material.Fabric),
		P(Vector3.new(1.1, 0.11, 1.4), CFrame.new(0, 0.01, 0), d, Enum.Material.Fabric),
		P(Vector3.new(0.6, 0.1, 0.6), CFrame.new(0, 0, -1.15), c, Enum.Material.Fabric),
		P(Vector3.new(0.18, 0.1, 0.8), CFrame.new(0, 0, 1.3) * A(0, r(12), 0), d, Enum.Material.Fabric) }
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			table.insert(s, P(Vector3.new(0.75, 0.09, 0.36), CFrame.new(sx * 0.95, 0, sz * 0.72) * A(0, r(sx * sz * -25), 0), c, Enum.Material.Fabric))
		end
	end
	return s
end
SPECS.hide = pelt(Color3.fromRGB(160, 112, 74))
SPECS.hide_desert = pelt(Color3.fromRGB(214, 176, 112))
SPECS.hide_snow = pelt(Color3.fromRGB(236, 240, 248))

SPECS.berries = { P(Vector3.new(0.55, 0.55, 0.55), nil, Color3.fromRGB(150, 30, 80), nil, BALL),
	P(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.38, 0.1, 0.1), Color3.fromRGB(176, 40, 96), nil, BALL),
	P(Vector3.new(0.48, 0.48, 0.48), CFrame.new(-0.3, 0.15, 0.25), Color3.fromRGB(165, 36, 90), nil, BALL),
	P(Vector3.new(0.45, 0.45, 0.45), CFrame.new(0.05, 0.4, -0.2), Color3.fromRGB(186, 50, 104), nil, BALL),
	P(Vector3.new(0.06, 0.4, 0.06), CFrame.new(0.05, 0.75, -0.2), Color3.fromRGB(70, 110, 50)),
	P(Vector3.new(0.5, 0.06, 0.3), CFrame.new(0.2, 0.88, -0.2) * A(0, 0, r(20)), Color3.fromRGB(70, 130, 60), Enum.Material.Grass) }
SPECS.coconut = { P(Vector3.new(1.1, 1.1, 1.1), nil, Color3.fromRGB(110, 74, 44), Enum.Material.Fabric, BALL) }
for k = 0, 2 do
	local a = k / 3 * math.pi * 2
	table.insert(SPECS.coconut, P(Vector3.new(0.16, 0.16, 0.16), CFrame.new(math.cos(a) * 0.16, 0.5, math.sin(a) * 0.16), Color3.fromRGB(46, 30, 18), nil, BALL))
end
table.insert(SPECS.coconut, P(Vector3.new(0.12, 0.8, 0.8), CFrame.new(1.0, -0.15, 0.3) * Y, Color3.fromRGB(110, 74, 44), Enum.Material.Fabric, CYL))
table.insert(SPECS.coconut, P(Vector3.new(0.14, 0.66, 0.66), CFrame.new(1.0, -0.08, 0.3) * Y, Color3.fromRGB(246, 242, 232), nil, CYL))

-- steak with a fat rim and a bone; the cooked one has grill marks
local function steak(meat, fat, cooked)
	local s = { P(Vector3.new(0.42, 1.5, 1.5), Y, meat, nil, CYL),
		P(Vector3.new(0.3, 1.66, 1.66), CFrame.new(0, -0.03, 0) * Y, fat, nil, CYL),
		P(Vector3.new(1.1, 0.24, 0.24), CFrame.new(1.05, 0, 0.1), Color3.fromRGB(240, 232, 214), nil, CYL),
		P(Vector3.new(0.3, 0.3, 0.3), CFrame.new(1.62, 0, 0.0), Color3.fromRGB(240, 232, 214), nil, BALL),
		P(Vector3.new(0.3, 0.3, 0.3), CFrame.new(1.62, 0, 0.22), Color3.fromRGB(240, 232, 214), nil, BALL) }
	if cooked then
		for i = -1, 1 do
			table.insert(s, P(Vector3.new(1.3, 0.04, 0.12), CFrame.new(0, 0.22, i * 0.38) * A(0, r(35), 0), Color3.fromRGB(50, 26, 14)))
		end
	end
	return s
end
SPECS.meat_raw = steak(Color3.fromRGB(200, 66, 70), Color3.fromRGB(236, 196, 190))
SPECS.meat_cooked = steak(Color3.fromRGB(130, 70, 38), Color3.fromRGB(176, 120, 70), true)
SPECS.mushroom = { P(Vector3.new(0.8, 0.36, 0.36), CFrame.new(0, -0.1, 0) * Y, Color3.fromRGB(236, 230, 214), nil, CYL),
	P(Vector3.new(1.05, 1.05, 1.05), CFrame.new(0, 0.42, 0), Color3.fromRGB(70, 196, 220), Enum.Material.Neon, BALL),
	P(Vector3.new(0.12, 1.02, 1.02), CFrame.new(0, 0.3, 0) * Y, Color3.fromRGB(200, 236, 240), nil, CYL),
	P(Vector3.new(0.18, 0.18, 0.18), CFrame.new(0.25, 0.86, 0.1), Color3.fromRGB(240, 250, 255), nil, BALL),
	P(Vector3.new(0.14, 0.14, 0.14), CFrame.new(-0.2, 0.84, -0.18), Color3.fromRGB(240, 250, 255), nil, BALL),
	P(Vector3.new(0.5, 0.24, 0.24), CFrame.new(0.55, -0.25, 0.2) * Y, Color3.fromRGB(236, 230, 214), nil, CYL),
	P(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.55, 0.05, 0.2), Color3.fromRGB(70, 196, 220), Enum.Material.Neon, BALL) }
-- bandage roll with a red cross and a loose end
SPECS.bandage = { P(Vector3.new(0.8, 0.95, 0.95), nil, Color3.fromRGB(242, 240, 232), Enum.Material.Fabric, CYL),
	P(Vector3.new(0.82, 0.3, 0.3), nil, Color3.fromRGB(210, 205, 190), nil, CYL),
	P(Vector3.new(0.04, 0.55, 0.16), CFrame.new(0.42, 0, 0), Color3.fromRGB(210, 50, 50)),
	P(Vector3.new(0.04, 0.16, 0.55), CFrame.new(0.42, 0, 0), Color3.fromRGB(210, 50, 50)),
	P(Vector3.new(0.7, 0.04, 1.1), CFrame.new(0, -0.47, 0.6), Color3.fromRGB(242, 240, 232), Enum.Material.Fabric) }

for _, p in ipairs(I.potions) do
	SPECS[p.id] = { P(Vector3.new(0.95, 0.95, 0.95), nil, p.color, Enum.Material.Glass, BALL),
		P(Vector3.new(0.6, 0.6, 0.6), nil, p.color, Enum.Material.Neon, BALL),
		P(Vector3.new(0.6, 0.32, 0.32), CFrame.new(0, 0.62, 0) * Y, Color3.fromRGB(200, 225, 235), Enum.Material.Glass, CYL),
		P(Vector3.new(0.22, 0.26, 0.26), CFrame.new(0, 0.98, 0) * Y, Color3.fromRGB(140, 100, 60), Enum.Material.Wood, CYL) }
end

---------------------------------------------------------------- tier versions (only the head changes)
local function recolor(spec, color, mat)
	local out = {}
	for i, p in ipairs(spec) do
		local c = { size = p.size, cf = p.cf, color = p.color, material = p.material, shape = p.shape }
		if p.head then
			c.color = p.edge and color:Lerp(Color3.new(1, 1, 1), 0.3) or (p.shade and color:Lerp(Color3.new(0, 0, 0), 0.25) or color)
			c.material = mat
		end
		out[i] = c
	end
	return out
end
for _, t in ipairs(TIERS) do
	SPECS[t.key .. "_axe"] = recolor(SPECS.wood_axe, t.head, t.mat)
	SPECS[t.key .. "_pickaxe"] = recolor(SPECS.wood_pickaxe, t.head, t.mat)
	if t.key ~= "iron" then SPECS[t.key .. "_sword"] = recolor(SPECS.iron_sword, t.head, t.mat) end
end
-- the wooden tools keep a plain grey head
SPECS.wood_axe = recolor(SPECS.wood_axe, Color3.fromRGB(110, 112, 118), Enum.Material.Metal)
SPECS.wood_pickaxe = recolor(SPECS.wood_pickaxe, Color3.fromRGB(110, 112, 118), Enum.Material.Metal)
SPECS.shadow_blade = recolor(swordSpec(STEEL, Color3.fromRGB(40, 30, 50), Enum.Material.Metal), Color3.fromRGB(110, 60, 170), Enum.Material.Neon)
SPECS.magma_blade = recolor(swordSpec(STEEL, Color3.fromRGB(60, 40, 36), Enum.Material.Metal), Color3.fromRGB(255, 110, 30), Enum.Material.Neon)

---------------------------------------------------------------- armor (as a chest piece on a stand)
for _, id in ipairs({ "leather_armor", "iron_armor", "diamond_armor" }) do
	local d = I.defs[id]
	local c, dk, lt = d.color, d.color:Lerp(Color3.new(0, 0, 0), 0.25), d.color:Lerp(Color3.new(1, 1, 1), 0.25)
	local strap = Color3.fromRGB(70, 48, 32)
	local edgeMat = id == "diamond_armor" and Enum.Material.Neon or d.mat
	local edgeC = id == "diamond_armor" and d.color:Lerp(Color3.new(1, 1, 1), 0.5) or dk
	if id == "leather_armor" then
		SPECS[id] = { P(Vector3.new(1.6, 1.5, 0.85), nil, c, d.mat),
			P(Vector3.new(0.18, 1.8, 0.1), CFrame.new(0, 0, -0.46) * A(0, 0, r(35)), strap, Enum.Material.Fabric),
			P(Vector3.new(0.18, 1.8, 0.1), CFrame.new(0, 0, -0.46) * A(0, 0, r(-35)), strap, Enum.Material.Fabric),
			P(Vector3.new(0.26, 0.26, 0.12), CFrame.new(0, 0, -0.5), GOLD, Enum.Material.Metal, BALL),
			P(Vector3.new(0.8, 0.35, 0.95), CFrame.new(-1.0, 0.55, 0), dk, d.mat),
			P(Vector3.new(0.8, 0.35, 0.95), CFrame.new(1.0, 0.55, 0), dk, d.mat),
			P(Vector3.new(1.7, 0.22, 0.9), CFrame.new(0, -0.6, 0), strap, Enum.Material.Fabric) }
	else
		SPECS[id] = { P(Vector3.new(1.6, 1.5, 0.9), nil, dk, d.mat),
			P(Vector3.new(1.4, 0.95, 0.2), CFrame.new(0, 0.15, -0.5), c, d.mat),
			P(Vector3.new(1.0, 0.5, 0.1), CFrame.new(0, 0.25, -0.62), lt, d.mat),
			P(Vector3.new(0.1, 0.95, 0.24), CFrame.new(0, 0.15, -0.56), edgeC, edgeMat),
			P(Vector3.new(0.9, 0.3, 1.1), CFrame.new(-1.0, 0.62, 0) * A(0, 0, r(14)), c, d.mat),
			P(Vector3.new(0.8, 0.24, 1.0), CFrame.new(-1.05, 0.38, 0) * A(0, 0, r(10)), dk, d.mat),
			P(Vector3.new(0.9, 0.3, 1.1), CFrame.new(1.0, 0.62, 0) * A(0, 0, r(-14)), c, d.mat),
			P(Vector3.new(0.8, 0.24, 1.0), CFrame.new(1.05, 0.38, 0) * A(0, 0, r(-10)), dk, d.mat),
			P(Vector3.new(1.7, 0.22, 0.95), CFrame.new(0, -0.68, 0), strap, Enum.Material.Fabric),
			P(Vector3.new(0.3, 0.26, 0.1), CFrame.new(0, -0.68, -0.5), GOLD, Enum.Material.Metal),
			P(Vector3.new(0.55, 0.6, 0.12), CFrame.new(-0.4, -1.05, -0.42), c, d.mat),
			P(Vector3.new(0.55, 0.6, 0.12), CFrame.new(0.4, -1.05, -0.42), c, d.mat) }
	end
end
-- coats and cloaks: body, collar, sleeves, belt, a hood on the back
for _, id in ipairs({ "warm_coat", "desert_cloak", "lava_cloak", "jungle_vest" }) do
	local d = I.defs[id]
	local c = d.color
	local trim = (id == "warm_coat" and Color3.fromRGB(240, 236, 228)) or (id == "lava_cloak" and Color3.fromRGB(255, 120, 40)) or (id == "desert_cloak" and Color3.fromRGB(180, 70, 50)) or Color3.fromRGB(60, 80, 46)
	local trimMat = id == "lava_cloak" and Enum.Material.Neon or Enum.Material.Fabric
	local s = { P(Vector3.new(1.6, 1.7, 0.85), nil, c, d.mat),
		P(Vector3.new(1.75, 0.34, 0.95), CFrame.new(0, 0.82, 0), trim, trimMat),
		P(Vector3.new(0.12, 1.6, 0.9), CFrame.new(0, -0.05, -0.02), trim, trimMat),
		P(Vector3.new(1.65, 0.22, 0.92), CFrame.new(0, -0.35, 0), Color3.fromRGB(70, 48, 32), Enum.Material.Fabric),
		P(Vector3.new(1.65, 0.6, 0.85), CFrame.new(0, -1.1, 0), c:Lerp(Color3.new(0, 0, 0), 0.1), d.mat) }
	if id ~= "jungle_vest" then
		table.insert(s, P(Vector3.new(1.4, 1.0, 0.6), CFrame.new(0, 0.7, 0.55), c:Lerp(Color3.new(0, 0, 0), 0.2), d.mat, BALL))
		for _, sx in ipairs({ -1, 1 }) do
			table.insert(s, P(Vector3.new(1.5, 0.48, 0.48), CFrame.new(sx * 1.05, 0.0, 0) * Y, c, d.mat, CYL))
			table.insert(s, P(Vector3.new(0.2, 0.56, 0.56), CFrame.new(sx * 1.05, -0.72, 0) * Y, trim, trimMat, CYL))
		end
	else
		for _, o in ipairs({ { -0.42, 0.25 }, { 0.42, 0.25 }, { -0.42, -0.25 }, { 0.42, -0.25 } }) do
			table.insert(s, P(Vector3.new(0.5, 0.4, 0.12), CFrame.new(o[1], o[2], -0.47), c:Lerp(Color3.new(0, 0, 0), 0.25), d.mat))
		end
	end
	SPECS[id] = s
end

-- Returns a Model whose PrimaryPart is "Handle" (unanchored, welded) - used for tools and icons.
function I.model(id)
	local spec = SPECS[id]
	if not spec then return nil end
	local m = Instance.new("Model")
	m.Name = id
	local handle
	for i, s in ipairs(spec) do
		local p = Instance.new("Part")
		p.Name = i == 1 and "Handle" or "Part"
		p.Size = s.size
		p.Color = s.color
		p.Material = s.material
		if s.shape then p.Shape = s.shape end
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if i == 1 then
			-- the first spec may be rotated; keep the handle axis-aligned with an invisible core
			handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(0.3, 0.3, 0.3)
			handle.Transparency = 1
			handle.CanCollide = false
			handle.CanTouch = false
			handle.CanQuery = false
			handle.Massless = true
			handle.CFrame = CFrame.new()
			handle.Parent = m
			p.Name = "Part"
		end
		p.CFrame = s.cf
		p.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
	end
	m.PrimaryPart = handle
	return m
end

-- where the hand holds each item (handle-space Z)
local GRIP = { wood_axe = -1.25, wood_pickaxe = -1.25, wood_sword = 0, iron_sword = 0, bow = 0, pistol = -0.2 }

function I.buildTool(id)
	local d = I.defs[id]
	local m = I.model(id)
	if not d or not m then return nil end
	local tool = Instance.new("Tool")
	tool.Name = d.en
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = ""
	tool:SetAttribute("ItemId", id)
	tool:SetAttribute("Kind", d.kind)
	local gripZ = GRIP[id] or ((d.class == "axe" or d.class == "pickaxe" or d.class == "hammer") and -1.25 or (d.class == "spear" and 0.4 or 0))
	tool.Grip = CFrame.fromMatrix(Vector3.new(0, 0, gripZ), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0))
	for _, c in ipairs(m:GetChildren()) do
		c.Parent = tool
	end
	m:Destroy()
	return tool
end

return I
