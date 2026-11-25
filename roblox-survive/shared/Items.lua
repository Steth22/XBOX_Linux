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
I.defs.iron_armor = { ar = "درع حديدي", en = "Iron Armor", kind = "armor", stack = 1, reduce = 0.30, buy = 480, color = Color3.fromRGB(176, 180, 190), mat = Enum.Material.Metal }
I.defs.diamond_armor = { ar = "درع ألماسي", en = "Diamond Armor", kind = "armor", stack = 1, reduce = 0.45, buy = 1400, color = Color3.fromRGB(110, 220, 245), mat = Enum.Material.Glass }

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
-- spec = { size, cf (relative to handle), color, material, shape }
local function P(size, cf, color, material, shape)
	return { size = size, cf = cf or CFrame.new(), color = color, material = material or Enum.Material.SmoothPlastic, shape = shape }
end
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local A = CFrame.Angles
local r = math.rad

local SPECS = {
	wood = { P(Vector3.new(2.3, 0.95, 0.95), A(0, r(90), 0), WOOD, Enum.Material.Wood, CYL),
		P(Vector3.new(0.06, 0.85, 0.85), CFrame.new(0, 0, 1.16) * A(0, r(90), 0), Color3.fromRGB(196, 160, 112), Enum.Material.Wood, CYL),
		P(Vector3.new(0.06, 0.85, 0.85), CFrame.new(0, 0, -1.16) * A(0, r(90), 0), Color3.fromRGB(196, 160, 112), Enum.Material.Wood, CYL) },
	stone = { P(Vector3.new(1.1, 0.9, 1.0), A(r(12), r(20), r(8)), Color3.fromRGB(128, 130, 136), Enum.Material.Slate),
		P(Vector3.new(0.7, 0.6, 0.7), CFrame.new(0.4, 0.25, 0.2) * A(r(30), r(40), 0), Color3.fromRGB(110, 112, 118), Enum.Material.Slate) },
	iron = { P(Vector3.new(1.1, 0.9, 1.0), A(r(12), r(20), r(8)), Color3.fromRGB(110, 106, 104), Enum.Material.Slate),
		P(Vector3.new(0.4, 0.35, 0.4), CFrame.new(0.35, 0.3, -0.2) * A(r(20), r(30), 0), Color3.fromRGB(196, 132, 92), Enum.Material.Metal),
		P(Vector3.new(0.35, 0.3, 0.35), CFrame.new(-0.3, 0.2, 0.3) * A(r(40), 0, r(20)), Color3.fromRGB(176, 118, 84), Enum.Material.Metal) },
	gold = { P(Vector3.new(1.0, 0.8, 0.9), A(r(12), r(20), r(8)), Color3.fromRGB(104, 100, 96), Enum.Material.Slate),
		P(Vector3.new(0.45, 0.4, 0.45), CFrame.new(0.3, 0.3, -0.15) * A(r(20), r(30), 0), Color3.fromRGB(255, 196, 60), Enum.Material.Metal),
		P(Vector3.new(0.38, 0.34, 0.38), CFrame.new(-0.28, 0.25, 0.25) * A(r(40), 0, r(20)), Color3.fromRGB(240, 180, 50), Enum.Material.Metal) },
	diamond = { P(Vector3.new(0.55, 1.1, 0.55), A(0, r(45), r(8)), Color3.fromRGB(130, 230, 255), Enum.Material.Glass),
		P(Vector3.new(0.4, 0.75, 0.4), CFrame.new(0.4, -0.15, 0.1) * A(0, r(45), r(-25)), Color3.fromRGB(160, 240, 255), Enum.Material.Glass),
		P(Vector3.new(0.35, 0.6, 0.35), CFrame.new(-0.35, -0.2, -0.1) * A(0, r(45), r(25)), Color3.fromRGB(110, 210, 250), Enum.Material.Glass) },
	hide = { P(Vector3.new(1.6, 0.12, 1.2), A(0, 0, r(8)), Color3.fromRGB(170, 120, 80), Enum.Material.Fabric),
		P(Vector3.new(0.9, 0.13, 0.5), CFrame.new(0, 0.02, 0.7), Color3.fromRGB(150, 104, 68), Enum.Material.Fabric) },
	berries = { P(Vector3.new(0.55, 0.55, 0.55), nil, Color3.fromRGB(150, 30, 80), nil, BALL),
		P(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0.38, 0.1, 0.1), Color3.fromRGB(176, 40, 96), nil, BALL),
		P(Vector3.new(0.48, 0.48, 0.48), CFrame.new(-0.3, 0.15, 0.25), Color3.fromRGB(165, 36, 90), nil, BALL),
		P(Vector3.new(0.45, 0.45, 0.45), CFrame.new(0.05, 0.4, -0.2), Color3.fromRGB(186, 50, 104), nil, BALL),
		P(Vector3.new(0.5, 0.08, 0.3), CFrame.new(0, 0.62, 0) * A(0, 0, r(20)), Color3.fromRGB(70, 130, 60)) },
	meat_raw = { P(Vector3.new(1.3, 0.55, 0.9), nil, Color3.fromRGB(196, 70, 70)),
		P(Vector3.new(1.2, 0.2, 0.2), CFrame.new(0.9, 0, 0) * A(0, 0, 0), Color3.fromRGB(240, 232, 214), nil, CYL),
		P(Vector3.new(0.35, 0.35, 0.35), CFrame.new(1.5, 0, 0), Color3.fromRGB(240, 232, 214), nil, BALL) },
	meat_cooked = { P(Vector3.new(1.3, 0.55, 0.9), nil, Color3.fromRGB(132, 74, 40)),
		P(Vector3.new(1.2, 0.2, 0.2), CFrame.new(0.9, 0, 0), Color3.fromRGB(240, 232, 214), nil, CYL),
		P(Vector3.new(0.35, 0.35, 0.35), CFrame.new(1.5, 0, 0), Color3.fromRGB(240, 232, 214), nil, BALL) },
	bandage = { P(Vector3.new(0.7, 0.8, 0.8), A(0, 0, r(90)), Color3.fromRGB(240, 240, 235), Enum.Material.Fabric, CYL),
		P(Vector3.new(0.72, 0.2, 0.82), CFrame.new(0, 0, 0), Color3.fromRGB(210, 60, 60), Enum.Material.Fabric) },
	wood_axe = { P(Vector3.new(0.34, 0.34, 3.6), nil, WOOD, Enum.Material.Wood, nil),
		P(Vector3.new(0.5, 0.42, 0.62), CFrame.new(0, 0, 1.55), Color3.fromRGB(90, 92, 98), Enum.Material.Metal),
		P(Vector3.new(0.9, 0.16, 0.95), CFrame.new(-0.65, 0, 1.55), STEEL, Enum.Material.Metal),
		P(Vector3.new(0.18, 0.17, 1.45), CFrame.new(-1.12, 0, 1.55), Color3.fromRGB(205, 210, 218), Enum.Material.Metal),
		P(Vector3.new(0.3, 0.3, 0.4), CFrame.new(0.38, 0, 1.55), Color3.fromRGB(90, 92, 98), Enum.Material.Metal),
		P(Vector3.new(0.38, 0.38, 0.5), CFrame.new(0, 0, -1.55), Color3.fromRGB(70, 50, 34), Enum.Material.Fabric) },
	wood_pickaxe = { P(Vector3.new(0.34, 0.34, 3.6), nil, WOOD, Enum.Material.Wood),
		P(Vector3.new(0.5, 0.42, 0.55), CFrame.new(0, 0, 1.55), Color3.fromRGB(90, 92, 98), Enum.Material.Metal),
		P(Vector3.new(1.3, 0.26, 0.32), CFrame.new(0.68, 0, 1.45) * A(0, r(-14), 0), STEEL, Enum.Material.Metal),
		P(Vector3.new(1.3, 0.26, 0.32), CFrame.new(-0.68, 0, 1.45) * A(0, r(14), 0), STEEL, Enum.Material.Metal),
		P(Vector3.new(0.5, 0.18, 0.2), CFrame.new(1.42, 0, 1.2) * A(0, r(-30), 0), Color3.fromRGB(205, 210, 218), Enum.Material.Metal),
		P(Vector3.new(0.5, 0.18, 0.2), CFrame.new(-1.42, 0, 1.2) * A(0, r(30), 0), Color3.fromRGB(205, 210, 218), Enum.Material.Metal),
		P(Vector3.new(0.38, 0.38, 0.5), CFrame.new(0, 0, -1.55), Color3.fromRGB(70, 50, 34), Enum.Material.Fabric) },
	wood_sword = { P(Vector3.new(0.38, 0.38, 1.0), nil, WOOD, Enum.Material.Wood),
		P(Vector3.new(1.3, 0.3, 0.28), CFrame.new(0, 0, 0.62), WOOD, Enum.Material.Wood),
		P(Vector3.new(0.62, 0.16, 2.6), CFrame.new(0, 0, 2.05), Color3.fromRGB(206, 184, 140), Enum.Material.Wood),
		P(Vector3.new(0.4, 0.16, 0.4), CFrame.new(0, 0, 3.4) * A(0, r(45), 0), Color3.fromRGB(206, 184, 140), Enum.Material.Wood) },
	iron_sword = { P(Vector3.new(0.34, 0.34, 1.1), nil, DARK, Enum.Material.Fabric),
		P(Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 0, -0.62), Color3.fromRGB(210, 170, 70), Enum.Material.Metal, BALL),
		P(Vector3.new(1.6, 0.3, 0.3), CFrame.new(0, 0, 0.68), Color3.fromRGB(210, 170, 70), Enum.Material.Metal),
		P(Vector3.new(0.6, 0.12, 3.4), CFrame.new(0, 0, 2.55), STEEL, Enum.Material.Metal),
		P(Vector3.new(0.12, 0.14, 3.2), CFrame.new(0, 0, 2.5), Color3.fromRGB(120, 124, 132), Enum.Material.Metal),
		P(Vector3.new(0.42, 0.12, 0.42), CFrame.new(0, 0, 4.25) * A(0, r(45), 0), STEEL, Enum.Material.Metal) },
	bow = { P(Vector3.new(0.32, 0.32, 0.7), nil, Color3.fromRGB(70, 50, 34), Enum.Material.Fabric),
		P(Vector3.new(0.24, 0.24, 2.0), CFrame.new(-0.2, 0, 1.25) * A(0, r(-18), 0), WOOD, Enum.Material.Wood),
		P(Vector3.new(0.24, 0.24, 2.0), CFrame.new(-0.2, 0, -1.25) * A(0, r(18), 0), WOOD, Enum.Material.Wood),
		P(Vector3.new(0.05, 0.05, 4.0), CFrame.new(0.3, 0, 0), Color3.fromRGB(235, 235, 225), Enum.Material.SmoothPlastic) },
	pistol = { P(Vector3.new(0.5, 0.34, 1.0), CFrame.new(0.1, 0, -0.15) * A(0, r(-12), 0), DARK, Enum.Material.Metal),
		P(Vector3.new(1.9, 0.36, 0.5), CFrame.new(-0.55, 0, 0.55), Color3.fromRGB(70, 72, 80), Enum.Material.Metal),
		P(Vector3.new(0.35, 0.18, 0.18), CFrame.new(-1.55, 0, 0.55), DARK, Enum.Material.Metal, CYL),
		P(Vector3.new(0.3, 0.08, 0.12), CFrame.new(-0.3, 0, 0.12), DARK, Enum.Material.Metal) },
	arrow = { P(Vector3.new(0.1, 0.1, 2.4), nil, WOOD, Enum.Material.Wood),
		P(Vector3.new(0.22, 0.22, 0.4), CFrame.new(0, 0, 1.3), STEEL, Enum.Material.Metal),
		P(Vector3.new(0.05, 0.35, 0.45), CFrame.new(0, 0, -1.05), Color3.fromRGB(220, 70, 60), Enum.Material.Fabric) },
	ammo = { P(Vector3.new(0.9, 0.55, 0.6), nil, Color3.fromRGB(70, 90, 60), Enum.Material.Metal),
		P(Vector3.new(0.18, 0.4, 0.18), CFrame.new(-0.25, 0.42, 0), Color3.fromRGB(210, 170, 70), Enum.Material.Metal, CYL),
		P(Vector3.new(0.18, 0.4, 0.18), CFrame.new(0.05, 0.42, 0), Color3.fromRGB(210, 170, 70), Enum.Material.Metal, CYL) },
	trap = { P(Vector3.new(0.2, 1.4, 1.4), A(0, 0, r(90)), Color3.fromRGB(90, 90, 96), Enum.Material.Metal, CYL),
		P(Vector3.new(1.3, 0.35, 0.1), CFrame.new(0, 0.2, 0.55), STEEL, Enum.Material.Metal),
		P(Vector3.new(1.3, 0.35, 0.1), CFrame.new(0, 0.2, -0.55), STEEL, Enum.Material.Metal) },
	campfire = { P(Vector3.new(1.8, 0.4, 0.4), A(0, r(30), 0), WOOD, Enum.Material.Wood, CYL),
		P(Vector3.new(1.8, 0.4, 0.4), A(0, r(-30), 0), WOOD, Enum.Material.Wood, CYL),
		P(Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 0.3, 0), Color3.fromRGB(255, 140, 40), Enum.Material.Neon, BALL) },
}

SPECS.lantern = { P(Vector3.new(0.9, 0.12, 0.9), CFrame.new(0, -0.7, 0), DARK, Enum.Material.Metal),
	P(Vector3.new(0.7, 1.1, 0.7), CFrame.new(0, 0, 0), Color3.fromRGB(255, 214, 140), Enum.Material.Neon),
	P(Vector3.new(0.9, 0.12, 0.9), CFrame.new(0, 0.62, 0), DARK, Enum.Material.Metal),
	P(Vector3.new(0.12, 1.3, 0.12), CFrame.new(0.4, 0, 0.4), DARK, Enum.Material.Metal),
	P(Vector3.new(0.12, 1.3, 0.12), CFrame.new(-0.4, 0, -0.4), DARK, Enum.Material.Metal),
	P(Vector3.new(0.6, 0.6, 0.1), CFrame.new(0, 0.95, 0), DARK, Enum.Material.Metal, CYL) }
SPECS.bed = { P(Vector3.new(3.2, 0.6, 6.2), CFrame.new(0, 0.3, 0), WOOD, Enum.Material.WoodPlanks),
	P(Vector3.new(3.0, 0.5, 5.9), CFrame.new(0, 0.85, 0.1), Color3.fromRGB(150, 50, 60), Enum.Material.Fabric),
	P(Vector3.new(2.4, 0.45, 1.1), CFrame.new(0, 1.2, -2.3), Color3.fromRGB(235, 230, 220), Enum.Material.Fabric),
	P(Vector3.new(3.2, 1.8, 0.4), CFrame.new(0, 1.2, -3.0), WOOD, Enum.Material.WoodPlanks) }
for _, p in ipairs(I.potions) do
	SPECS[p.id] = { P(Vector3.new(0.95, 0.95, 0.95), nil, p.color, Enum.Material.Glass, BALL),
		P(Vector3.new(0.6, 0.6, 0.6), nil, p.color, Enum.Material.Neon, BALL),
		P(Vector3.new(0.6, 0.32, 0.32), CFrame.new(0, 0.62, 0) * A(0, 0, r(90)), Color3.fromRGB(200, 225, 235), Enum.Material.Glass, CYL),
		P(Vector3.new(0.22, 0.26, 0.26), CFrame.new(0, 0.98, 0) * A(0, 0, r(90)), Color3.fromRGB(140, 100, 60), Enum.Material.Wood, CYL) }
end
SPECS.mushroom = { P(Vector3.new(0.3, 0.7, 0.3), CFrame.new(0, -0.1, 0), Color3.fromRGB(230, 225, 210)),
	P(Vector3.new(0.9, 0.45, 0.9), CFrame.new(0, 0.3, 0), Color3.fromRGB(80, 200, 220), Enum.Material.Neon, BALL) }
local function gemSpec(c1, c2, mat)
	return { P(Vector3.new(0.5, 1.2, 0.5), A(0, r(45), r(8)), c1, mat),
		P(Vector3.new(0.38, 0.8, 0.38), CFrame.new(0.38, -0.15, 0.1) * A(0, r(45), r(-25)), c2, mat),
		P(Vector3.new(0.34, 0.7, 0.34), CFrame.new(-0.34, -0.2, -0.1) * A(0, r(45), r(25)), c1, mat) }
end
SPECS.crystal = gemSpec(Color3.fromRGB(150, 110, 255), Color3.fromRGB(190, 150, 255), Enum.Material.Glass)
SPECS.obsidian = gemSpec(Color3.fromRGB(40, 30, 55), Color3.fromRGB(70, 50, 90), Enum.Material.Glass)

local function recolor(spec, color, mat, from)
	local out = {}
	for i, p in ipairs(spec) do
		local c = { size = p.size, cf = p.cf, color = p.color, material = p.material, shape = p.shape }
		if p.material == Enum.Material.Metal and p.color ~= DARK and (not from or i >= from) then
			c.color = color
			c.material = mat
		end
		out[i] = c
	end
	return out
end
for _, t in ipairs(TIERS) do
	SPECS[t.key .. "_axe"] = recolor(SPECS.wood_axe, t.head, t.mat, 3)
	SPECS[t.key .. "_pickaxe"] = recolor(SPECS.wood_pickaxe, t.head, t.mat, 3)
	if t.key ~= "iron" then SPECS[t.key .. "_sword"] = recolor(SPECS.iron_sword, t.head, t.mat, 4) end
end
for _, h in ipairs({ { "hide_desert", Color3.fromRGB(214, 176, 112) }, { "hide_snow", Color3.fromRGB(236, 240, 248) } }) do
	SPECS[h[1]] = { P(Vector3.new(1.6, 0.12, 1.2), A(0, 0, r(8)), h[2], Enum.Material.Fabric),
		P(Vector3.new(0.9, 0.13, 0.5), CFrame.new(0, 0.02, 0.7), h[2]:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Fabric) }
end
SPECS.shadow_blade = recolor(SPECS.iron_sword, Color3.fromRGB(60, 30, 90), Enum.Material.Neon, 4)
for _, id in ipairs({ "leather_armor", "iron_armor", "diamond_armor" }) do
	local d = I.defs[id]
	SPECS[id] = {
		P(Vector3.new(1.6, 1.4, 0.8), nil, d.color, d.mat),
		P(Vector3.new(0.7, 0.45, 0.95), CFrame.new(-0.95, 0.5, 0), d.color:Lerp(Color3.new(0, 0, 0), 0.15), d.mat),
		P(Vector3.new(0.7, 0.45, 0.95), CFrame.new(0.95, 0.5, 0), d.color:Lerp(Color3.new(0, 0, 0), 0.15), d.mat),
		P(Vector3.new(1.65, 0.18, 0.85), CFrame.new(0, -0.45, 0), Color3.fromRGB(90, 64, 40), Enum.Material.Fabric),
	}
end

local function spearSpec(head, mat)
	return { P(Vector3.new(0.28, 0.28, 6.2), CFrame.new(0, 0, 1.4), WOOD, Enum.Material.Wood),
		P(Vector3.new(0.32, 0.32, 0.6), CFrame.new(0, 0, -0.2), Color3.fromRGB(70, 50, 34), Enum.Material.Fabric),
		P(Vector3.new(0.55, 0.14, 1.3), CFrame.new(0, 0, 4.9), head, mat),
		P(Vector3.new(0.3, 0.14, 0.5), CFrame.new(0, 0, 5.75) * A(0, r(45), 0), head, mat) }
end
SPECS.spear = spearSpec(STEEL, Enum.Material.Metal)
SPECS.ice_spear = spearSpec(Color3.fromRGB(150, 225, 255), Enum.Material.Glass)
SPECS.scimitar = { P(Vector3.new(0.34, 0.34, 1.1), nil, Color3.fromRGB(120, 60, 40), Enum.Material.Fabric),
	P(Vector3.new(1.3, 0.28, 0.28), CFrame.new(0, 0, 0.68), Color3.fromRGB(210, 170, 70), Enum.Material.Metal),
	P(Vector3.new(0.75, 0.12, 2.0), CFrame.new(-0.05, 0, 1.75), STEEL, Enum.Material.Metal),
	P(Vector3.new(0.85, 0.12, 1.4), CFrame.new(-0.3, 0, 3.3) * A(0, r(-18), 0), STEEL, Enum.Material.Metal) }
SPECS.war_hammer = { P(Vector3.new(0.36, 0.36, 3.8), nil, WOOD, Enum.Material.Wood),
	P(Vector3.new(1.4, 1.0, 1.0), CFrame.new(0, 0, 1.75), Color3.fromRGB(90, 92, 100), Enum.Material.Metal),
	P(Vector3.new(0.3, 1.1, 1.1), CFrame.new(-0.72, 0, 1.75), Color3.fromRGB(150, 155, 165), Enum.Material.Metal),
	P(Vector3.new(0.3, 1.1, 1.1), CFrame.new(0.72, 0, 1.75), Color3.fromRGB(150, 155, 165), Enum.Material.Metal) }
SPECS.crossbow = { P(Vector3.new(0.4, 0.35, 2.2), CFrame.new(-0.1, 0, 0.6), WOOD, Enum.Material.Wood),
	P(Vector3.new(0.25, 3.0, 0.25), CFrame.new(-0.1, 0, 1.6), Color3.fromRGB(80, 60, 40), Enum.Material.Wood),
	P(Vector3.new(0.05, 2.8, 0.05), CFrame.new(-0.1, 0, 1.25), Color3.fromRGB(235, 235, 225), Enum.Material.SmoothPlastic),
	P(Vector3.new(0.6, 0.3, 0.4), CFrame.new(0.3, 0, -0.2), DARK, Enum.Material.Metal) }
SPECS.bolt = { P(Vector3.new(0.12, 0.12, 1.6), nil, WOOD, Enum.Material.Wood), P(Vector3.new(0.24, 0.24, 0.35), CFrame.new(0, 0, 0.9), STEEL, Enum.Material.Metal) }
SPECS.rifle = { P(Vector3.new(0.5, 0.36, 1.2), CFrame.new(0.2, 0, -0.5), Color3.fromRGB(110, 74, 46), Enum.Material.Wood),
	P(Vector3.new(0.45, 0.36, 1.8), CFrame.new(-0.25, 0, 0.6), Color3.fromRGB(110, 74, 46), Enum.Material.Wood),
	P(Vector3.new(0.22, 0.22, 2.6), CFrame.new(-0.45, 0, 2.2), DARK, Enum.Material.Metal),
	P(Vector3.new(0.3, 0.3, 0.9), CFrame.new(-0.65, 0, 0.9), Color3.fromRGB(70, 72, 80), Enum.Material.Metal) }
SPECS.rifle_ammo = { P(Vector3.new(0.9, 0.55, 0.6), nil, Color3.fromRGB(90, 80, 50), Enum.Material.Metal), P(Vector3.new(0.16, 0.5, 0.16), CFrame.new(0, 0.5, 0), Color3.fromRGB(210, 170, 70), Enum.Material.Metal, CYL) }
SPECS.dynamite = { P(Vector3.new(0.4, 1.2, 0.4), nil, Color3.fromRGB(190, 50, 40), Enum.Material.SmoothPlastic, CYL),
	P(Vector3.new(0.4, 1.2, 0.4), CFrame.new(0.42, 0, 0), Color3.fromRGB(190, 50, 40), Enum.Material.SmoothPlastic, CYL),
	P(Vector3.new(0.9, 0.12, 0.5), CFrame.new(0.2, 0, 0), Color3.fromRGB(60, 50, 40), Enum.Material.Fabric),
	P(Vector3.new(0.06, 0.06, 0.7), CFrame.new(0.2, 0.75, 0) * A(r(90), 0, 0), Color3.fromRGB(230, 220, 200), Enum.Material.Fabric) }
for _, id in ipairs({ "warm_coat", "desert_cloak" }) do
	local d = I.defs[id]
	SPECS[id] = { P(Vector3.new(1.7, 1.6, 0.9), nil, d.color, d.mat),
		P(Vector3.new(1.8, 0.35, 1.0), CFrame.new(0, 0.7, 0), d.color:Lerp(Color3.new(1, 1, 1), 0.25), d.mat),
		P(Vector3.new(0.12, 1.4, 0.95), CFrame.new(0, -0.05, 0), d.color:Lerp(Color3.new(0, 0, 0), 0.3), d.mat) }
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
