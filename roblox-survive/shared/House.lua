-- The player's house: 15 designs, 6 levels. Builds a Model in local space: origin = the middle of the
-- ground floor at floor level, the front (with the door) faces -Z. Used by the server (the real house)
-- and by the client (previews in the house window).
-- Furniture that does something is marked: Model "Bed" (Attribute Bed), Model "Chest" (Attribute Chest = n),
-- Part "FurnaceSpot" / "CraftSpot" (the server puts a working furnace / crafting table there), Seat "Chair".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.Items)

local H = {}
H.FLOOR = 10 -- height of one storey

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local M = Enum.Material
H.DESIGNS = {
	{ key = "cabin", ar = "كوخ الحطّاب", en = "Woodcutter's Cabin", wall = rgb(132, 92, 58), wallM = M.Wood, trim = rgb(86, 58, 36), roof = rgb(150, 60, 46), roofM = M.WoodPlanks, floor = rgb(150, 110, 72), glass = rgb(170, 210, 230), roofType = "gable" },
	{ key = "cottage", ar = "بيت الحجر", en = "Stone Cottage", wall = rgb(150, 146, 138), wallM = M.Cobblestone, trim = rgb(96, 70, 48), roof = rgb(70, 82, 100), roofM = M.Slate, floor = rgb(140, 104, 70), glass = rgb(180, 215, 235), roofType = "gable" },
	{ key = "brick", ar = "البيت الأحمر", en = "Red Brick House", wall = rgb(160, 72, 56), wallM = M.Brick, trim = rgb(230, 222, 206), roof = rgb(60, 60, 66), roofM = M.Slate, floor = rgb(120, 86, 60), glass = rgb(170, 205, 225), roofType = "gable" },
	{ key = "adobe", ar = "بيت الطين", en = "Desert Adobe", wall = rgb(214, 170, 118), wallM = M.Sandstone, trim = rgb(150, 100, 60), roof = rgb(196, 150, 100), roofM = M.Sandstone, floor = rgb(190, 150, 104), glass = rgb(150, 200, 210), roofType = "flat" },
	{ key = "lodge", ar = "نُزُل الثلج", en = "Snow Lodge", wall = rgb(104, 76, 54), wallM = M.Wood, trim = rgb(236, 240, 245), roof = rgb(236, 240, 246), roofM = M.Snow, floor = rgb(130, 96, 66), glass = rgb(200, 230, 245), roofType = "gable" },
	{ key = "jungle", ar = "بيت الأدغال", en = "Jungle Hut", wall = rgb(160, 140, 90), wallM = M.WoodPlanks, trim = rgb(90, 110, 60), roof = rgb(120, 140, 70), roofM = M.Grass, floor = rgb(140, 116, 76), glass = rgb(170, 220, 190), roofType = "steps" },
	{ key = "manor", ar = "القصر الأبيض", en = "White Manor", wall = rgb(232, 228, 218), wallM = M.SmoothPlastic, trim = rgb(70, 90, 120), roof = rgb(70, 90, 120), roofM = M.Slate, floor = rgb(160, 120, 84), glass = rgb(170, 210, 235), roofType = "steps" },
	{ key = "tower", ar = "برج الحارس", en = "Watch Tower", wall = rgb(118, 118, 120), wallM = M.Slate, trim = rgb(70, 70, 74), roof = rgb(110, 44, 40), roofM = M.Slate, floor = rgb(110, 84, 60), glass = rgb(190, 200, 210), roofType = "flat" },
	{ key = "beach", ar = "بيت الشاطئ", en = "Beach House", wall = rgb(120, 180, 200), wallM = M.WoodPlanks, trim = rgb(246, 244, 236), roof = rgb(236, 230, 214), roofM = M.WoodPlanks, floor = rgb(210, 190, 150), glass = rgb(190, 235, 245), roofType = "gable" },
	{ key = "forge", ar = "دار الحدّاد", en = "Smith's Hall", wall = rgb(80, 76, 74), wallM = M.Basalt, trim = rgb(200, 110, 50), roof = rgb(46, 44, 46), roofM = M.Slate, floor = rgb(90, 80, 74), glass = rgb(240, 180, 110), roofType = "steps" },
	{ key = "farm", ar = "بيت المزرعة", en = "Farmhouse", wall = rgb(176, 64, 52), wallM = M.WoodPlanks, trim = rgb(240, 236, 226), roof = rgb(96, 88, 84), roofM = M.Slate, floor = rgb(160, 120, 80), glass = rgb(180, 210, 225), roofType = "gable" },
	{ key = "mossy", ar = "بيت الطحلب", en = "Mossy Ruin House", wall = rgb(120, 128, 110), wallM = M.Cobblestone, trim = rgb(80, 110, 60), roof = rgb(70, 110, 56), roofM = M.Grass, floor = rgb(110, 96, 74), glass = rgb(170, 210, 180), roofType = "gable" },
	{ key = "golden", ar = "الدار الذهبية", en = "Golden Hall", wall = rgb(236, 220, 180), wallM = M.Marble, trim = rgb(210, 170, 70), roof = rgb(196, 150, 60), roofM = M.Metal, floor = rgb(170, 130, 90), glass = rgb(250, 230, 170), roofType = "steps" },
	{ key = "night", ar = "بيت الليل", en = "Night House", wall = rgb(52, 56, 74), wallM = M.WoodPlanks, trim = rgb(150, 120, 220), roof = rgb(36, 36, 48), roofM = M.Slate, floor = rgb(80, 70, 90), glass = rgb(170, 140, 255), roofType = "gable" },
	{ key = "sakura", ar = "بيت الربيع", en = "Spring House", wall = rgb(246, 236, 226), wallM = M.WoodPlanks, trim = rgb(150, 90, 70), roof = rgb(220, 120, 150), roofM = M.WoodPlanks, floor = rgb(180, 140, 100), glass = rgb(200, 225, 240), roofType = "steps" },
}
-- what makes each design look its own: shutters, timber bands, a stone base, a round tower, flower boxes,
-- beams sticking out under a flat roof
local LOOKS = {
	cabin = { shutters = rgb(60, 100, 60) },
	cottage = { stoneBase = true, flowers = true },
	brick = { shutters = rgb(240, 236, 226) },
	adobe = { vigas = true },
	lodge = { timber = true, shutters = rgb(150, 40, 40) },
	jungle = { flowers = true, vigas = true },
	manor = { shutters = rgb(70, 90, 120), turret = true },
	tower = { turret = true, stoneBase = true },
	beach = { shutters = rgb(246, 244, 236), flowers = true },
	forge = { stoneBase = true, vigas = true },
	farm = { timber = true, flowers = true },
	mossy = { stoneBase = true, flowers = true, timber = true },
	golden = { turret = true, shutters = rgb(210, 170, 70) },
	night = { shutters = rgb(150, 120, 220), turret = true },
	sakura = { timber = true, flowers = true },
}
H.BY = {}
for i, d in ipairs(H.DESIGNS) do
	d.i = i
	H.BY[d.key] = d
	for k, v in pairs(LOOKS[d.key] or {}) do d[k] = v end
end

-- each level: footprint, storeys and the price (wood, stone)
H.LEVELS = {
	{ w = 14, d = 12, floors = 1, wood = 30, stone = 15 },
	{ w = 18, d = 14, floors = 1, wood = 90, stone = 50 },
	{ w = 18, d = 16, floors = 2, wood = 170, stone = 110 },
	{ w = 20, d = 16, floors = 2, wood = 260, stone = 190 },
	{ w = 22, d = 18, floors = 3, wood = 400, stone = 300 },
	{ w = 24, d = 18, floors = 3, wood = 600, stone = 460 },
}
H.MAX = #H.LEVELS
-- how many chests a house of that level has
function H.chests(lvl) return math.clamp(lvl or 0, 0, 6) end
H.CHEST_SLOTS = 15

---------------------------------------------------------------- building blocks
local function newPart(parent, size, cf, color, mat, name, class)
	local p = Instance.new(class or "Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if name then p.Name = name end
	p.Parent = parent
	return p
end

-- a wall along X at z, from x0 to x1 and y0 to y1, with rectangular holes { x0, x1, y0, y1 }
local function wallX(parent, z, x0, x1, y0, y1, th, holes, color, mat)
	table.sort(holes, function(a, b) return a[1] < b[1] end)
	local x = x0
	local function seg(a, b, c, d)
		if b - a > 0.05 and d - c > 0.05 then newPart(parent, Vector3.new(b - a, d - c, th), CFrame.new((a + b) / 2, (c + d) / 2, z), color, mat) end
	end
	for _, h in ipairs(holes) do
		seg(x, h[1], y0, y1)
		seg(h[1], h[2], y0, h[3])
		seg(h[1], h[2], h[4], y1)
		x = h[2]
	end
	seg(x, x1, y0, y1)
end
-- the same along Z at x
local function wallZ(parent, x, z0, z1, y0, y1, th, holes, color, mat)
	table.sort(holes, function(a, b) return a[1] < b[1] end)
	local z = z0
	local function seg(a, b, c, d)
		if b - a > 0.05 and d - c > 0.05 then newPart(parent, Vector3.new(th, d - c, b - a), CFrame.new(x, (c + d) / 2, (a + b) / 2), color, mat) end
	end
	for _, h in ipairs(holes) do
		seg(z, h[1], y0, y1)
		seg(h[1], h[2], y0, h[3])
		seg(h[1], h[2], h[4], y1)
		z = h[2]
	end
	seg(z, z1, y0, y1)
end

-- glass and a sill in a window hole; `along` = "x" for walls along X
local function windowFill(parent, along, at, a0, a1, b0, b1, d)
	local w, h = a1 - a0, b1 - b0
	local mid = (a0 + a1) / 2
	local cy = (b0 + b1) / 2
	if along == "x" then
		local g = newPart(parent, Vector3.new(w, h, 0.2), CFrame.new(mid, cy, at), d.glass, M.Glass)
		g.Transparency = 0.45
		newPart(parent, Vector3.new(w + 0.6, 0.3, 1.4), CFrame.new(mid, b0 - 0.15, at), d.trim, M.Wood)
		newPart(parent, Vector3.new(0.2, h, 0.3), CFrame.new(mid, cy, at), d.trim, M.Wood)
	else
		local g = newPart(parent, Vector3.new(0.2, h, w), CFrame.new(at, cy, mid), d.glass, M.Glass)
		g.Transparency = 0.45
		newPart(parent, Vector3.new(1.4, 0.3, w + 0.6), CFrame.new(at, b0 - 0.15, mid), d.trim, M.Wood)
		newPart(parent, Vector3.new(0.3, h, 0.2), CFrame.new(at, cy, mid), d.trim, M.Wood)
	end
	local out = at > 0 and 1 or -1
	local face = at + out * 0.62
	if d.shutters then
		for _, sg in ipairs({ -1, 1 }) do
			local off = sg * (w * 0.75 + 0.15)
			if along == "x" then
				newPart(parent, Vector3.new(w / 2 + 0.2, h + 0.4, 0.25), CFrame.new(mid + off, cy, face), d.shutters, M.WoodPlanks)
			else
				newPart(parent, Vector3.new(0.25, h + 0.4, w / 2 + 0.2), CFrame.new(face, cy, mid + off), d.shutters, M.WoodPlanks)
			end
		end
	end
	if d.flowers then
		local box, bloom
		if along == "x" then
			box = newPart(parent, Vector3.new(w + 0.4, 0.7, 0.9), CFrame.new(mid, b0 - 0.6, at + out * 0.95), rgb(110, 76, 50), M.WoodPlanks)
			bloom = newPart(parent, Vector3.new(w, 0.55, 0.7), CFrame.new(mid, b0 - 0.05, at + out * 0.95), (math.floor(mid + cy) % 2 == 0) and rgb(232, 90, 120) or rgb(250, 206, 70), M.Grass)
		else
			box = newPart(parent, Vector3.new(0.9, 0.7, w + 0.4), CFrame.new(at + out * 0.95, b0 - 0.6, mid), rgb(110, 76, 50), M.WoodPlanks)
			bloom = newPart(parent, Vector3.new(0.7, 0.55, w), CFrame.new(at + out * 0.95, b0 - 0.05, mid), (math.floor(mid + cy) % 2 == 0) and rgb(232, 90, 120) or rgb(250, 206, 70), M.Grass)
		end
		bloom.CanCollide = false
	end
end

---------------------------------------------------------------- furniture
local WOOD = rgb(124, 86, 54)
local DARK = rgb(84, 58, 38)

local function bed(parent, cf)
	local m = Items.model("bed")
	if not m then return end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true p.CanCollide = true end
	end
	m.Name = "Bed"
	m:SetAttribute("Bed", true)
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

local function chest(parent, cf, n)
	local m = Instance.new("Model")
	m.Name = "Chest"
	m:SetAttribute("Chest", n)
	local body = newPart(m, Vector3.new(3, 1.6, 1.9), cf * CFrame.new(0, 0.8, 0), WOOD, M.WoodPlanks, "Body")
	newPart(m, Vector3.new(3.1, 0.5, 2.0), cf * CFrame.new(0, 1.85, 0), DARK, M.WoodPlanks)
	for _, x in ipairs({ -1.1, 1.1 }) do newPart(m, Vector3.new(0.25, 2.15, 2.05), cf * CFrame.new(x, 1.07, 0), rgb(70, 70, 76), M.Metal) end
	newPart(m, Vector3.new(0.45, 0.55, 0.2), cf * CFrame.new(0, 1.55, -1.02), rgb(210, 170, 70), M.Metal)
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

local function chair(parent, cf, color)
	local seat = newPart(parent, Vector3.new(1.8, 0.35, 1.8), cf * CFrame.new(0, 1.6, 0), color or WOOD, M.WoodPlanks, "Chair", "Seat")
	for _, x in ipairs({ -0.75, 0.75 }) do for _, z in ipairs({ -0.75, 0.75 }) do
		newPart(parent, Vector3.new(0.25, 1.45, 0.25), cf * CFrame.new(x, 0.72, z), DARK, M.Wood)
	end end
	newPart(parent, Vector3.new(1.8, 1.8, 0.25), cf * CFrame.new(0, 2.6, 0.8), color or WOOD, M.WoodPlanks)
	return seat
end

local function tableAt(parent, cf, w, d)
	newPart(parent, Vector3.new(w, 0.3, d), cf * CFrame.new(0, 2.6, 0), WOOD, M.WoodPlanks)
	for _, x in ipairs({ -w / 2 + 0.3, w / 2 - 0.3 }) do for _, z in ipairs({ -d / 2 + 0.3, d / 2 - 0.3 }) do
		newPart(parent, Vector3.new(0.3, 2.45, 0.3), cf * CFrame.new(x, 1.22, z), DARK, M.Wood)
	end end
end

local function rug(parent, cf, w, d, color)
	local r = newPart(parent, Vector3.new(w, 0.08, d), cf * CFrame.new(0, 0.04, 0), color, M.Fabric)
	r.CanCollide = false
	local b = newPart(parent, Vector3.new(w - 1, 0.1, d - 1), cf * CFrame.new(0, 0.05, 0), color:Lerp(Color3.new(1, 1, 1), 0.3), M.Fabric)
	b.CanCollide = false
end

local function lamp(parent, cf)
	newPart(parent, Vector3.new(0.3, 0.3, 0.9), cf * CFrame.new(0, 0, -0.45), DARK, M.Metal)
	local l = newPart(parent, Vector3.new(0.8, 1.0, 0.8), cf * CFrame.new(0, -0.3, -1.0), rgb(255, 210, 130), M.Neon)
	l.CanCollide = false
	local pl = Instance.new("PointLight")
	pl.Range = 16
	pl.Brightness = 1.3
	pl.Color = rgb(255, 196, 120)
	pl.Shadows = true
	pl.Parent = l
end

local function shelf(parent, cf)
	newPart(parent, Vector3.new(4, 6, 1.2), cf * CFrame.new(0, 3, 0), DARK, M.WoodPlanks)
	local colors = { rgb(150, 50, 50), rgb(50, 90, 150), rgb(60, 120, 70), rgb(200, 160, 60), rgb(120, 70, 140) }
	for row = 0, 2 do
		for k = 0, 6 do
			local h = 1.1 + ((k * 7 + row * 3) % 4) * 0.12
			newPart(parent, Vector3.new(0.38, h, 0.9), cf * CFrame.new(-1.5 + k * 0.5, 1.0 + row * 1.8 + h / 2, -0.2), colors[(k + row) % 5 + 1], M.SmoothPlastic)
		end
	end
end

local function plant(parent, cf)
	newPart(parent, Vector3.new(1.4, 1.2, 1.4), cf * CFrame.new(0, 0.6, 0), rgb(170, 96, 66), M.Slate)
	local b = newPart(parent, Vector3.new(2, 2, 2), cf * CFrame.new(0, 2.0, 0), rgb(70, 130, 60), M.Grass, nil)
	b.Shape = Enum.PartType.Ball
	b.CanCollide = false
end

local function painting(parent, cf, color)
	newPart(parent, Vector3.new(3.4, 2.4, 0.2), cf, DARK, M.Wood)
	newPart(parent, Vector3.new(2.9, 1.9, 0.22), cf, color, M.SmoothPlastic)
end

-- a stand-in for the working furnace / crafting table (the server swaps in the real ones)
local function spot(parent, name, cf, preview)
	local p = newPart(parent, Vector3.new(1, 1, 1), cf, Color3.new(), M.SmoothPlastic, name)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	if preview then
		if name == "FurnaceSpot" then
			newPart(parent, Vector3.new(4.4, 4.6, 4.4), cf * CFrame.new(0, 2.3, 0), rgb(128, 124, 118), M.Cobblestone)
			local g = newPart(parent, Vector3.new(1.8, 1.2, 0.2), cf * CFrame.new(0, 1.6, -2.25), rgb(255, 120, 30), M.Neon)
			g.CanCollide = false
		else
			newPart(parent, Vector3.new(4.2, 0.5, 4.2), cf * CFrame.new(0, 3.35, 0), rgb(160, 112, 66), M.WoodPlanks)
			newPart(parent, Vector3.new(3.6, 3.1, 3.6), cf * CFrame.new(0, 1.55, 0), DARK, M.Wood).Transparency = 0.5
		end
	end
	return p
end

---------------------------------------------------------------- the house
-- opts: { found = foundation depth below the floor, preview = true for the client's small model }
function H.build(designKey, lvl, opts)
	opts = opts or {}
	local d = H.BY[designKey] or H.DESIGNS[1]
	lvl = math.clamp(lvl or 1, 1, H.MAX)
	local L = H.LEVELS[lvl]
	local W, D, F = L.w, L.d, L.floors
	local FH = H.FLOOR
	local top = F * FH
	local m = Instance.new("Model")
	m.Name = "House"
	local shell = Instance.new("Model")
	shell.Name = "Shell"
	shell.Parent = m
	local inside = Instance.new("Model")
	inside.Name = "Furniture"
	inside.Parent = m
	local hw, hd = W / 2, D / 2

	-- foundation and the ground floor
	local found = opts.found or 1.5
	local base = newPart(shell, Vector3.new(W + 2, found, D + 2), CFrame.new(0, -found / 2 - 0.3, 0), rgb(120, 118, 112), M.Cobblestone, "Foundation")
	newPart(shell, Vector3.new(W - 1, 0.3, D - 1), CFrame.new(0, -0.15, 0), d.floor, M.WoodPlanks, "Floor")
	-- front steps up to the door
	newPart(shell, Vector3.new(6, 0.6, 2), CFrame.new(0, -0.6, -hd - 2), rgb(120, 118, 112), M.Cobblestone)

	-- the ladder hole in the upper floors (back right corner) and the ladder
	local hx0, hx1, hz0, hz1 = hw - 5, hw - 1, hd - 4.5, hd - 1
	for f = 2, F do
		local y = (f - 1) * FH
		-- slab with a hole
		newPart(shell, Vector3.new(hx0 - (-hw + 1), 0.8, D - 2), CFrame.new((-hw + 1 + hx0) / 2, y - 0.4, 0), d.floor, M.WoodPlanks)
		newPart(shell, Vector3.new(hx1 - hx0, 0.8, hz0 - (-hd + 1)), CFrame.new((hx0 + hx1) / 2, y - 0.4, (-hd + 1 + hz0) / 2), d.floor, M.WoodPlanks)
		-- a railing round the hole on the side facing the room
		newPart(shell, Vector3.new(0.3, 2.6, hz1 - hz0), CFrame.new(hx0 + 0.15, y + 1.3, (hz0 + hz1) / 2), d.trim, M.Wood)
	end
	if F > 1 then
		local lh = (F - 1) * FH + 3
		local t = newPart(shell, Vector3.new(2, lh, 2), CFrame.new(hw - 2, lh / 2, hd - 2), d.trim, M.Wood, "Ladder", "TrussPart")
	end

	-- walls with the door and windows, storey by storey
	local th = 1
	for f = 1, F do
		local y0, y1 = (f - 1) * FH - (f > 1 and 0.8 or 0), f * FH - 0.8
		local wy0, wy1 = (f - 1) * FH + 3.2, (f - 1) * FH + 6.8
		-- front
		local holes = {}
		if f == 1 then table.insert(holes, { -2.5, 2.5, y0, (f - 1) * FH + 7.5 }) end
		for _, x in ipairs({ -hw / 2 - 0.5, hw / 2 + 0.5 }) do
			if f > 1 or math.abs(x) > 5 then table.insert(holes, { x - 1.5, x + 1.5, wy0, wy1 }) end
		end
		if f > 1 then table.insert(holes, { -1.5, 1.5, wy0, wy1 }) end
		wallX(shell, -hd + th / 2, -hw, hw, y0, y1, th, holes, d.wall, d.wallM)
		for _, h in ipairs(holes) do if h[3] > y0 + 0.5 then windowFill(shell, "x", -hd + th / 2, h[1], h[2], h[3], h[4], d) end end
		-- back
		local bh = { { -hw / 2 - 1.5, -hw / 2 + 1.5, wy0, wy1 } }
		wallX(shell, hd - th / 2, -hw, hw, y0, y1, th, bh, d.wall, d.wallM)
		windowFill(shell, "x", hd - th / 2, bh[1][1], bh[1][2], wy0, wy1, d)
		-- sides
		for _, sx in ipairs({ -1, 1 }) do
			local sh = { { -1.5, 1.5, wy0, wy1 } }
			if D >= 16 then sh = { { -hd / 2 - 1.5, -hd / 2 + 1.5, wy0, wy1 }, { hd / 2 - 1.5 - 1, hd / 2 + 1.5 - 1, wy0, wy1 } } end
			if sx == 1 then
				-- no window behind the ladder
				for i = #sh, 1, -1 do if sh[i][2] > hz0 - 0.5 then table.remove(sh, i) end end
			end
			wallZ(shell, sx * (hw - th / 2), -hd + th, hd - th, y0, y1, th, sh, d.wall, d.wallM)
			for _, h in ipairs(sh) do windowFill(shell, "z", sx * (hw - th / 2), h[1], h[2], wy0, wy1, d) end
		end
		-- a band of trim between storeys, outside
		if f > 1 then
			newPart(shell, Vector3.new(W + 0.6, 0.6, 0.5), CFrame.new(0, y0 + 0.4, -hd - 0.1), d.trim, M.Wood)
			newPart(shell, Vector3.new(W + 0.6, 0.6, 0.5), CFrame.new(0, y0 + 0.4, hd + 0.1), d.trim, M.Wood)
			newPart(shell, Vector3.new(0.5, 0.6, D + 0.6), CFrame.new(-hw - 0.1, y0 + 0.4, 0), d.trim, M.Wood)
			newPart(shell, Vector3.new(0.5, 0.6, D + 0.6), CFrame.new(hw + 0.1, y0 + 0.4, 0), d.trim, M.Wood)
		end
	end
	-- corner posts and the door frame
	for _, x in ipairs({ -hw, hw }) do for _, z in ipairs({ -hd, hd }) do
		newPart(shell, Vector3.new(1.3, top, 1.3), CFrame.new(x, top / 2 - 0.4, z), d.trim, M.Wood)
	end end
	newPart(shell, Vector3.new(0.6, 7.8, 1.3), CFrame.new(-2.8, 3.9, -hd + 0.5), d.trim, M.Wood)
	newPart(shell, Vector3.new(0.6, 7.8, 1.3), CFrame.new(2.8, 3.9, -hd + 0.5), d.trim, M.Wood)
	newPart(shell, Vector3.new(6.2, 0.6, 1.3), CFrame.new(0, 7.8, -hd + 0.5), d.trim, M.Wood)

	-- the design's own touches on the outside
	if d.timber then
		for f = 1, F do
			for _, yy in ipairs({ (f - 1) * FH + 2.4, (f - 1) * FH + 7.6 }) do
				newPart(shell, Vector3.new(W, 0.45, 0.4), CFrame.new(0, yy, -hd - 0.15), d.trim, M.Wood)
				newPart(shell, Vector3.new(W, 0.45, 0.4), CFrame.new(0, yy, hd + 0.15), d.trim, M.Wood)
				newPart(shell, Vector3.new(0.4, 0.45, D), CFrame.new(-hw - 0.15, yy, 0), d.trim, M.Wood)
				newPart(shell, Vector3.new(0.4, 0.45, D), CFrame.new(hw + 0.15, yy, 0), d.trim, M.Wood)
			end
		end
	end
	if d.stoneBase then
		local sc = rgb(128, 126, 120)
		newPart(shell, Vector3.new(hw - 2.9, 2.8, 0.6), CFrame.new(-(hw + 2.9) / 2, 1.1, -hd - 0.3), sc, M.Cobblestone)
		newPart(shell, Vector3.new(hw - 2.9, 2.8, 0.6), CFrame.new((hw + 2.9) / 2, 1.1, -hd - 0.3), sc, M.Cobblestone)
		newPart(shell, Vector3.new(W + 1.2, 2.8, 0.6), CFrame.new(0, 1.1, hd + 0.3), sc, M.Cobblestone)
		newPart(shell, Vector3.new(0.6, 2.8, D), CFrame.new(-hw - 0.3, 1.1, 0), sc, M.Cobblestone)
		newPart(shell, Vector3.new(0.6, 2.8, D), CFrame.new(hw + 0.3, 1.1, 0), sc, M.Cobblestone)
	end
	if d.vigas then
		for x = -hw + 2, hw - 2, 3 do
			for _, sz in ipairs({ -1, 1 }) do
				newPart(shell, Vector3.new(1.8, 0.6, 0.6), CFrame.new(x, top - 1.4, sz * (hd + 0.6)) * CFrame.Angles(0, math.pi / 2, 0), d.trim, M.Wood, nil).Shape = Enum.PartType.Cylinder
			end
		end
	end
	if d.turret then
		-- a round tower on the front left corner with a pointed roof
		local th2 = top + 3
		local tx, tz = -hw - 0.4, -hd - 0.4
		local cyl = newPart(shell, Vector3.new(th2 + 1, 6, 6), CFrame.new(tx, th2 / 2 - 0.5, tz) * CFrame.Angles(0, 0, math.pi / 2), d.wall, d.wallM)
		cyl.Shape = Enum.PartType.Cylinder
		for f = 1, F do
			local band = newPart(shell, Vector3.new(0.5, 6.4, 6.4), CFrame.new(tx, (f - 1) * FH + 0.2, tz) * CFrame.Angles(0, 0, math.pi / 2), d.trim, M.Wood)
			band.Shape = Enum.PartType.Cylinder
			local slit = newPart(shell, Vector3.new(1.0, 2.4, 0.3), CFrame.new(tx - 2.2, (f - 1) * FH + 5, tz - 2.2) * CFrame.Angles(0, math.rad(45), 0), d.glass, M.Glass)
			slit.Transparency = 0.3
		end
		for k = 0, 4 do
			local dia = 7.2 - k * 1.45
			local ring = newPart(shell, Vector3.new(1.0, dia, dia), CFrame.new(tx, th2 + 0.5 + k * 1.0, tz) * CFrame.Angles(0, 0, math.pi / 2), d.roof, d.roofM)
			ring.Shape = Enum.PartType.Cylinder
		end
		local tip = newPart(shell, Vector3.new(0.9, 0.9, 0.9), CFrame.new(tx, th2 + 5.6, tz), d.trim, M.Metal)
		tip.Shape = Enum.PartType.Ball
	end

	-- ceiling of the top storey and the roof
	newPart(shell, Vector3.new(W, 0.8, D), CFrame.new(0, top - 0.4, 0), d.trim, M.WoodPlanks, "Ceiling")
	local roofTop = top
	if d.roofType == "gable" then
		local ang = math.rad(30)
		local s = hd + 1.4
		local r0 = hd * math.tan(ang)
		for _, sz in ipairs({ -1, 1 }) do
			local len = s / math.cos(ang)
			local cz = sz * s / 2
			local cy = top + r0 - (s / 2) * math.tan(ang) + 0.4
			newPart(shell, Vector3.new(W + 2.4, 0.7, len), CFrame.new(0, cy, cz) * CFrame.Angles(sz * ang, 0, 0), d.roof, d.roofM)
		end
		newPart(shell, Vector3.new(W + 2.6, 0.7, 0.9), CFrame.new(0, top + r0 + 0.5, 0), d.trim, M.Wood)
		-- the triangles at each end
		for _, sx in ipairs({ -1, 1 }) do
			local w1 = newPart(shell, Vector3.new(1, r0, hd), CFrame.new(sx * (hw - 0.5), top + r0 / 2, hd / 2) * CFrame.Angles(0, math.pi, 0), d.wall, d.wallM, nil, "WedgePart")
			local w2 = newPart(shell, Vector3.new(1, r0, hd), CFrame.new(sx * (hw - 0.5), top + r0 / 2, -hd / 2), d.wall, d.wallM, nil, "WedgePart")
		end
		roofTop = top + r0
	elseif d.roofType == "steps" then
		-- a stepped roof that narrows towards the top
		local n = 4
		for k = 0, n - 1 do
			local sc = 1 - k / n
			newPart(shell, Vector3.new((W + 2.4) * sc + 1, 1.1, (D + 2.4) * sc + 1), CFrame.new(0, top + 0.55 + k * 1.1, 0), d.roof, d.roofM)
		end
		newPart(shell, Vector3.new(2, 1.4, 2), CFrame.new(0, top + n * 1.1 + 0.7, 0), d.trim, M.Wood)
		roofTop = top + n * 1.1 + 1.4
	else
		-- flat roof with a low wall round it
		newPart(shell, Vector3.new(W + 1.6, 0.6, D + 1.6), CFrame.new(0, top + 0.3, 0), d.roof, d.roofM)
		for _, sz in ipairs({ -1, 1 }) do
			newPart(shell, Vector3.new(W + 1.6, 1.6, 0.8), CFrame.new(0, top + 1.4, sz * (hd + 0.4)), d.wall, d.wallM)
			newPart(shell, Vector3.new(0.8, 1.6, D + 1.6), CFrame.new(sz * (hw + 0.4), top + 1.4, 0), d.wall, d.wallM)
		end
		roofTop = top + 2.2
	end
	-- chimney from level 2
	if lvl >= 2 then
		local ch = roofTop - top + 4
		newPart(shell, Vector3.new(2.4, ch + 2, 2.4), CFrame.new(-hw + 2.5, top + (ch + 2) / 2 - 1, hd - 3), rgb(130, 120, 112), M.Brick)
		newPart(shell, Vector3.new(2.9, 0.5, 2.9), CFrame.new(-hw + 2.5, top + ch + 1, hd - 3), rgb(80, 76, 72), M.Slate)
	end
	-- a porch roof over the door from level 4, lanterns from level 3, a fence and flowers at level 6
	if lvl >= 4 then
		local p = newPart(shell, Vector3.new(8, 0.5, 3.6), CFrame.new(0, 8.6, -hd - 1.6) * CFrame.Angles(math.rad(-14), 0, 0), d.roof, d.roofM)
		for _, x in ipairs({ -3.6, 3.6 }) do newPart(shell, Vector3.new(0.5, 8.3, 0.5), CFrame.new(x, 4.05, -hd - 3.2), d.trim, M.Wood) end
	end
	if lvl >= 3 then
		for _, x in ipairs({ -3.6, 3.6 }) do lamp(shell, CFrame.new(x, 6.6, -hd - 0.1)) end
	end
	if lvl >= 6 then
		local fx, fz = hw + 4, hd + 4
		for _, sx in ipairs({ -1, 1 }) do
			newPart(shell, Vector3.new(0.4, 1.4, 2 * fz), CFrame.new(sx * fx, 0.7, 0), d.trim, M.Wood)
			newPart(shell, Vector3.new(fx - 3.5, 1.4, 0.4), CFrame.new(sx * (fx + 3.5) / 2, 0.7, -fz), d.trim, M.Wood)
		end
		newPart(shell, Vector3.new(2 * fx, 1.4, 0.4), CFrame.new(0, 0.7, fz), d.trim, M.Wood)
		for k = -2, 2 do
			if k ~= 0 then
				newPart(shell, Vector3.new(2.6, 0.8, 1.4), CFrame.new(k * 4.4, 0.4, -hd - 1), rgb(110, 80, 56), M.Wood)
				local f = newPart(shell, Vector3.new(2.2, 0.7, 1.0), CFrame.new(k * 4.4, 1.0, -hd - 1), (k % 2 == 0) and rgb(230, 80, 110) or rgb(250, 210, 70), M.Grass)
				f.CanCollide = false
			end
		end
	end

	---------------------------------------------------------------- furniture
	local function at(f, x, z, ry) return CFrame.new(x, (f - 1) * FH, z) * CFrame.Angles(0, ry or 0, 0) end
	local pv = opts.preview
	local chestN = 0
	local function addChest(f, x, z)
		chestN += 1
		chest(inside, at(f, x, z), chestN)
	end
	local rugColor = d.trim:Lerp(rgb(170, 60, 60), 0.5)
	-- ground floor
	if lvl <= 2 then bed(inside, at(1, -hw + 2.8, hd - 4.2, math.pi)) end
	addChest(1, -hw + 6.2, hd - 1.9)
	lamp(inside, at(1, 0, hd - 1, 0) * CFrame.new(0, 7.2, 0))
	if lvl >= 2 then
		addChest(1, -hw + 9.6, hd - 1.9)
		spot(inside, "FurnaceSpot", CFrame.lookAt(Vector3.new(-hw + 3.4, 0, -hd + 3.4), Vector3.new(-hw + 4.4, 0, -hd + 3.4)), pv)
		spot(inside, "CraftSpot", CFrame.lookAt(Vector3.new(hw - 3.4, 0, -hd + 3.4), Vector3.new(hw - 4.4, 0, -hd + 3.4)), pv)
		rug(inside, at(1, -0.5, 0.6), 8, 6, rugColor)
		tableAt(inside, at(1, -0.5, 0.6), 3.2, 2.2)
		chair(inside, at(1, -0.5, -1.9, math.pi), d.wall:Lerp(WOOD, 0.6))
		chair(inside, at(1, -0.5, 3.1, 0), d.wall:Lerp(WOOD, 0.6))
	end
	if lvl >= 3 then
		shelf(inside, at(1, -hw + 1.8, hd - 4, -math.pi / 2))
		painting(inside, at(1, -hw + 1.1, 0, -math.pi / 2) * CFrame.new(0, 5, 0), d.glass:Lerp(rgb(60, 120, 80), 0.5))
	end
	if lvl >= 4 then
		plant(inside, at(1, -4.2, -hd + 2))
		plant(inside, at(1, 4.2, -hd + 2))
	end
	-- first floor
	if F >= 2 then
		bed(inside, at(2, -hw + 2.8, hd - 4.2, math.pi))
		addChest(2, -hw + 6.2, hd - 1.9)
		rug(inside, at(2, 0, 0), 7, 5, rugColor)
		lamp(inside, at(2, 0, hd - 1, 0) * CFrame.new(0, 7.2, 0))
		chair(inside, at(2, hw - 3, -hd + 3, math.pi / 4), d.trim)
		plant(inside, at(2, hw - 3, -hd + 6))
		if lvl >= 4 then
			bed(inside, at(2, -hw + 2.8, hd - 10.6, math.pi))
			addChest(2, -hw + 9.6, hd - 1.9)
			painting(inside, at(2, 0, -hd + 1.1, math.pi) * CFrame.new(0, 5, 0), d.glass:Lerp(rgb(200, 140, 70), 0.5))
		end
	end
	-- top floor
	if F >= 3 then
		bed(inside, at(3, -hw + 2.8, hd - 4.2, math.pi))
		addChest(3, -hw + 6.2, hd - 1.9)
		rug(inside, at(3, 0, 0), 8, 6, rugColor)
		lamp(inside, at(3, 0, hd - 1, 0) * CFrame.new(0, 7.2, 0))
		shelf(inside, at(3, hw - 1.8, -hd + 4, math.pi / 2))
		if lvl >= 6 then
			bed(inside, at(3, -hw + 2.8, hd - 10.6, math.pi))
			addChest(3, -hw + 9.6, hd - 1.9)
			spot(inside, "FurnaceSpot", CFrame.lookAt(Vector3.new(-hw + 3.4, 2 * FH, -hd + 3.4), Vector3.new(-hw + 4.4, 2 * FH, -hd + 3.4)), pv)
			tableAt(inside, at(3, 0, 0), 3, 2)
			chair(inside, at(3, 0, -2.4, math.pi), d.trim)
		end
	end
	m.PrimaryPart = base
	m:SetAttribute("Height", roofTop)
	return m
end

-- an empty plot: a frame of stakes and rope, and a sign
function H.plot(w, d)
	local m = Instance.new("Model")
	m.Name = "Plot"
	local hw, hd = w / 2, d / 2
	for _, x in ipairs({ -hw, hw }) do for _, z in ipairs({ -hd, hd }) do
		newPart(m, Vector3.new(0.5, 2.4, 0.5), CFrame.new(x, 1.2, z), WOOD, M.Wood)
	end end
	for _, z in ipairs({ -hd, hd }) do newPart(m, Vector3.new(w, 0.15, 0.15), CFrame.new(0, 2.0, z), rgb(220, 200, 150), M.Fabric).CanCollide = false end
	for _, x in ipairs({ -hw, hw }) do newPart(m, Vector3.new(0.15, 0.15, d), CFrame.new(x, 2.0, 0), rgb(220, 200, 150), M.Fabric).CanCollide = false end
	return m
end

-- the sign in front of the house (the house window opens from it)
function H.sign(parent, cf)
	newPart(parent, Vector3.new(0.5, 4, 0.5), cf * CFrame.new(0, 2, 0), DARK, M.Wood)
	local board = newPart(parent, Vector3.new(3.6, 2.2, 0.3), cf * CFrame.new(0, 3.8, 0), WOOD, M.WoodPlanks, "Sign")
	return board
end

return H
