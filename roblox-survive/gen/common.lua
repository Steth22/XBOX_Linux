-- shared by every world-generation task: heights + regions for the whole map
local Biomes = require(game:GetService("ReplicatedStorage").Shared.Biomes)
local Terrain = workspace.Terrain
local HALF = Biomes.HALF
local WATER = 7
local rng = Random.new(2024)

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function sq(x, z) return math.max(math.abs(x), math.abs(z)) end
local function rough(x, z)
	return smooth((sq(x, z) - 900) / 260)
end
local function hForest(x, z)
	local h = 13 + math.noise(x / 200, z / 200, 11.3) * 6 + math.noise(x / 70, z / 70, 3.7) * 2.2 + math.noise(x / 22, z / 22, 8.1) * 0.5
	local p = math.noise(x / 95 + 40, z / 95 - 17, 5.5)
	if p > 0.30 then h -= (p - 0.30) * 70 end
	return h
end
local function hSnow(x, z)
	return 14 + math.noise(x / 130, z / 130, 21) * 4 + rough(x, z) * (math.noise(x / 55, z / 55, 22) * 16 + 10)
end
local function hDesert(x, z)
	local h = 12 + math.sin(x / 38 + math.noise(x / 90, z / 90, 31) * 4) * 2.6 + math.noise(x / 70, z / 70, 32) * 3
	h += rough(x, z) * (math.noise(x / 60, z / 60, 33) * 14 + 9)
	local o = math.noise(x / 110 + 9, z / 110, 34)
	if o > 0.38 then h -= (o - 0.38) * 80 end -- oases
	return h
end
local function hMount(x, z)
	local ramp = smooth((sq(x, z) - 620) / 260)
	local n = 1 - math.abs(math.noise(x / 170, z / 170, 41))
	return 16 + ramp * ((n ^ 2.2) * 130 + math.noise(x / 45, z / 45, 42) * 10 + 20)
end
local function hHills(x, z)
	return 15 + math.noise(x / 95, z / 95, 51) * 22 + math.noise(x / 32, z / 32, 52) * 5 + rough(x, z) * 12
end
local function hJungle(x, z)
	local h = 12 + math.noise(x / 150, z / 150, 61) * 5 + math.noise(x / 40, z / 40, 62) * 1.6
	-- winding rivers
	local rv = math.abs(math.noise(x / 260, z / 260, 71))
	if rv < 0.07 then h -= (0.07 - rv) / 0.07 * 10 end
	return h
end
-- volcano cones: returns extra height and whether the point is inside a lava crater
local function cones(x, z)
	local add, lava = 0, false
	for _, c in ipairs(Biomes.volcanoes) do
		local d = math.sqrt((x - c[1]) ^ 2 + (z - c[2]) ^ 2)
		if d < c[3] then
			local t = 1 - d / c[3]
			local hgt = c[4] * t ^ 1.5
			local rimR = c[3] * 0.14
			if d < rimR then
				local rim = c[4] * (1 - 0.14) ^ 1.5
				hgt = rim - (rimR - d) * 0.9
				if d < rimR * 0.8 then lava = true end
			end
			if hgt > add then add = hgt end
		end
	end
	return add, lava
end
local function hVolcano(x, z)
	local base = 20 + math.noise(x / 120, z / 120, 81) * 8 + math.noise(x / 35, z / 35, 82) * 2
	local add = cones(x, z)
	return base + add
end
local FN = { snow = hSnow, desert = hDesert, mountains = hMount, hills = hHills, jungle = hJungle, volcano = hVolcano }

-- height, region, how far into the region (0..1)
local function heightB(x, z)
	local sector = Biomes.sector(x, z)
	local hf = hForest(x, z)
	local w = Biomes.outer(x, z)
	local h = hf
	if w > 0 and FN[sector] then h = hf + (FN[sector](x, z) - hf) * w end
	-- the shore: sand sloping down into the sea
	local sw = Biomes.shore(x, z)
	if sw > 0 then
		local d = sq(x, z)
		local beach = WATER + 3.5 + math.noise(x / 40, z / 40, 91) * 1.2 - math.max(0, d - Biomes.SHORE) / 18
		beach = math.max(beach, -10)
		h = h + (beach - h) * sw
	end
	local b = Biomes.at(x, z)
	if b ~= "beach" and w <= 0.5 then b = "forest" end
	return h, b, w
end
local function height(x, z)
	return (heightB(x, z))
end
local function ground(x, z) return height(x, z) end
local function regionAt(x, z)
	local _, b = heightB(x, z)
	return b
end
local function inCrater(x, z)
	local _, lava = cones(x, z)
	return lava
end

---------------------------------------------------------------- the underground layer
-- Caves like a real underground (Minecraft style): caverns of very different sizes scattered at random,
-- each made of a few overlapping blobs so no two look alike, joined by winding worm tunnels whose width
-- changes as they go. A spanning tree guarantees every cavern can reach every other; extra links make
-- loops. The mines are dug by people, so they run almost straight along four lines with rails.
-- Shared by the terrain writer (to carve it) and the content script (to furnish it). Deterministic.
local UG = { caverns = {}, tunnels = {}, lines = {}, entrances = {}, shafts = {} }
UG.TOP, UG.BOTTOM = -30, -140
local urng = Random.new(9090)
local LIM = HALF - 170
local function newCavern(x, z, size)
	-- size: "small" | "mid" | "grand"
	local rx, rz, ry
	if size == "grand" then rx, rz, ry = urng:NextNumber(58, 86), urng:NextNumber(50, 80), urng:NextNumber(24, 32)
	elseif size == "mid" then rx, rz, ry = urng:NextNumber(32, 50), urng:NextNumber(28, 46), urng:NextNumber(15, 21)
	else rx, rz, ry = urng:NextNumber(16, 28), urng:NextNumber(15, 26), urng:NextNumber(11, 15) end
	local c = { x = x, z = z, rx = rx, rz = rz, ry = ry, grand = size == "grand", size = size }
	c.y = size == "grand" and urng:NextNumber(-100, -74) or urng:NextNumber(-96, -50)
	if c.y + c.ry > UG.TOP then c.y = UG.TOP - c.ry end
	c.floor = c.y - c.ry * 0.55
	-- the main blob plus a few side blobs: irregular outlines
	c.blobs = { { x = x, z = z, rx = rx, rz = rz, ry = ry } }
	local extra = size == "grand" and urng:NextInteger(3, 5) or size == "mid" and urng:NextInteger(2, 3) or urng:NextInteger(0, 2)
	for _ = 1, extra do
		local a = urng:NextNumber(0, math.pi * 2)
		local d = urng:NextNumber(0.45, 0.85)
		local s = urng:NextNumber(0.4, 0.75)
		table.insert(c.blobs, { x = x + math.cos(a) * rx * d, z = z + math.sin(a) * rz * d, rx = rx * s, rz = rz * s, ry = ry * urng:NextNumber(0.6, 0.95) })
	end
	-- bounds of all blobs (other code reads rx / rz as the cavern's reach)
	local mx, mz = 0, 0
	for _, bl in ipairs(c.blobs) do
		mx = math.max(mx, math.abs(bl.x - x) + bl.rx)
		mz = math.max(mz, math.abs(bl.z - z) + bl.rz)
	end
	c.reachX, c.reachZ = mx, mz
	c.region = Biomes.at(x, z)
	c.id = #UG.caverns + 1
	table.insert(UG.caverns, c)
	return c
end
-- the four mine lines first: caverns every ~300 studs along x = +-760 and z = +-760
local MINE = 760
local lineCaverns = {}
for li, def in ipairs({ { "z", -MINE }, { "z", MINE }, { "x", -MINE }, { "x", MINE } }) do
	local list = {}
	for t = -LIM + 40, LIM - 40, 300 do
		local x, z
		if def[1] == "z" then x, z = t, def[2] else x, z = def[2], t end
		-- reuse a cavern where two lines cross
		local found
		for _, c in ipairs(UG.caverns) do
			if (c.x - x) ^ 2 + (c.z - z) ^ 2 < 60 ^ 2 then found = c end
		end
		local c = found or newCavern(x + urng:NextNumber(-20, 20), z + urng:NextNumber(-20, 20), urng:NextNumber() < 0.3 and "grand" or "mid")
		c.mine = true
		table.insert(list, c)
	end
	lineCaverns[li] = list
end
-- the rest: scattered caverns of every size, never too close to each other
local tries = 0
while #UG.caverns < 190 and tries < 20000 do
	tries += 1
	local roll = urng:NextNumber()
	local size = roll < 0.12 and "grand" or roll < 0.5 and "mid" or "small"
	local x, z = urng:NextNumber(-LIM, LIM), urng:NextNumber(-LIM, LIM)
	local ok = true
	local need = size == "grand" and 190 or size == "mid" and 130 or 95
	for _, c in ipairs(UG.caverns) do
		local gap = need + (c.grand and 60 or 0)
		if (c.x - x) ^ 2 + (c.z - z) ^ 2 < gap * gap then ok = false break end
	end
	if ok then newCavern(x, z, size) end
end
for _, c in ipairs(UG.caverns) do
	c.lake = not c.mine and not c.grand and urng:NextNumber() < 0.12
	c.lava = not c.mine and ((c.region == "volcano" and urng:NextNumber() < 0.6) or (not c.lake and urng:NextNumber() < 0.04))
	if c.lake then c.water = c.y - c.ry * 0.25 end
	if c.lava then c.pool = { x = c.x + urng:NextNumber(-0.3, 0.3) * c.rx, z = c.z + urng:NextNumber(-0.3, 0.3) * c.rz, r = math.min(c.rx, c.rz) * 0.38 } end
end

local function smooth01(t) return t * t * (3 - 2 * t) end
-- a tunnel from a to b. Worm tunnels wander sideways (two noise waves) and change width; mines run straight.
local function tunnel(a, b, r, wiggle, kind)
	local pts, radii = {}, {}
	local dx, dz = b.x - a.x, b.z - a.z
	local len = math.max(1, math.sqrt(dx * dx + dz * dz))
	local px, pz = -dz / len, dx / len
	local n = math.max(2, math.floor(len / 6))
	local ph = urng:NextNumber(0, 100)
	for k = 0, n do
		local t = k / n
		local env = math.sin(math.pi * t) -- no wandering at the ends, so they meet the caverns
		local off = 0
		if wiggle ~= 0 then
			off = env * (wiggle * math.noise(t * 2.2, ph) * 2 + 14 * math.noise(t * 7, ph + 7))
		end
		local fl = a.floor + (b.floor - a.floor) * smooth01(t)
		if wiggle ~= 0 then fl += env * 3 * math.noise(t * 5, ph + 3) end
		local rr = r
		if wiggle ~= 0 then rr = math.max(6, r * (1 + 0.3 * math.noise(t * 6, ph + 11))) end
		table.insert(pts, Vector3.new(a.x + dx * t + px * off, fl + rr * 0.6, a.z + dz * t + pz * off))
		table.insert(radii, rr)
	end
	local tn = { pts = pts, radii = radii, r = r, kind = kind or "tunnel", a = a, b = b, id = #UG.tunnels + 1 }
	table.insert(UG.tunnels, tn)
	return tn
end
-- the mine tunnels along each line (straight, rails later)
local lineTunnels = {}
local linked = {}
local function key(a, b) return math.min(a.id, b.id) .. ":" .. math.max(a.id, b.id) end
for li, list in ipairs(lineCaverns) do
	lineTunnels[li] = {}
	for k = 1, #list - 1 do
		table.insert(lineTunnels[li], tunnel(list[k], list[k + 1], 6.5, 0, "mine"))
		linked[key(list[k], list[k + 1])] = true
	end
end
-- every cavern joined: a spanning tree over the nearest neighbours (Prim), then some extra loops
local inTree = { [UG.caverns[1]] = true }
local treeN = 1
local bestLink = {}
local function relax(c)
	for _, o in ipairs(UG.caverns) do
		if not inTree[o] then
			local d = (o.x - c.x) ^ 2 + (o.z - c.z) ^ 2
			if not bestLink[o] or d < bestLink[o][2] then bestLink[o] = { c, d } end
		end
	end
end
relax(UG.caverns[1])
-- the mine caverns are already joined to each other along their lines
for _, list in ipairs(lineCaverns) do for _, c in ipairs(list) do if not inTree[c] then inTree[c] = true treeN += 1 relax(c) end end end
local function worm(a, b)
	if linked[key(a, b)] then return end
	linked[key(a, b)] = true
	local big = urng:NextNumber() < 0.15
	local t = tunnel(a, b, big and urng:NextNumber(9, 12) or urng:NextNumber(6.5, 8.5), urng:NextNumber(18, 40))
	if urng:NextNumber() < 0.06 then t.gas = true end
end
while treeN < #UG.caverns do
	local pick, pd
	for o, bl in pairs(bestLink) do
		if not inTree[o] and (not pd or bl[2] < pd) then pick, pd = o, bl[2] end
	end
	if not pick then break end
	worm(bestLink[pick][1], pick)
	inTree[pick] = true
	treeN += 1
	bestLink[pick] = nil
	relax(pick)
end
for _, c in ipairs(UG.caverns) do
	if urng:NextNumber() < 0.35 then
		local best, bd
		for _, o in ipairs(UG.caverns) do
			if o ~= c and not linked[key(c, o)] then
				local d = (o.x - c.x) ^ 2 + (o.z - c.z) ^ 2
				if d < 330 ^ 2 and (not bd or d < bd) then best, bd = o, d end
			end
		end
		if best then worm(c, best) end
	end
end
-- a few dead-end side passages that wander off and stop
for _ = 1, 40 do
	local c = UG.caverns[urng:NextInteger(1, #UG.caverns)]
	local a = urng:NextNumber(0, math.pi * 2)
	local d = urng:NextNumber(70, 140)
	local ex, ez = c.x + math.cos(a) * d, c.z + math.sin(a) * d
	if math.abs(ex) < LIM and math.abs(ez) < LIM then
		local stub = { x = ex, z = ez, floor = c.floor + urng:NextNumber(-6, 6) }
		tunnel(c, stub, urng:NextNumber(6, 7.5), urng:NextNumber(10, 25), "stub")
	end
end
-- the rail lines: the mine tunnels joined end to end (they pass through each cavern's centre)
for li = 1, #lineTunnels do
	local pts = {}
	for k, t in ipairs(lineTunnels[li]) do
		for m, p in ipairs(t.pts) do
			if not (k > 1 and m == 1) then table.insert(pts, Vector3.new(p.X, p.Y - t.r * 0.6, p.Z)) end
		end
	end
	table.insert(UG.lines, pts)
end
local function nearestTo(x, z, filter)
	local best, bd
	for _, c in ipairs(UG.caverns) do
		local d = (c.x - x) ^ 2 + (c.z - z) ^ 2
		if (not filter or filter(c)) and (not bd or d < bd) then best, bd = c, d end
	end
	return best
end

-- surface places to keep entrances away from
local keepAway = { { 0, 0 }, { -240, -240 }, { -736, -425 }, { 156, -886 }, { -148, 837 }, { -779, 450 }, { -700, -1300 },
	{ -182, -1034 }, { 60, 1000 }, { 900, -120 }, { 300, -1330 }, { -1000, 260 }, { 400, 693 } }
local function nearestCavern(x, z)
	local best, bd
	for _, c in ipairs(UG.caverns) do
		local d = (c.x - x) ^ 2 + (c.z - z) ^ 2
		if not c.lake and (not bd or d < bd) then best, bd = c, d end
	end
	return best
end
-- ramps from the surface down into a cavern
local tries = 0
while #UG.entrances < 24 and tries < 2000 do
	tries += 1
	local x, z = urng:NextNumber(-HALF + 300, HALF - 300), urng:NextNumber(-HALF + 300, HALF - 300)
	local ok = true
	for _, k in ipairs(keepAway) do if (x - k[1]) ^ 2 + (z - k[2]) ^ 2 < 170 ^ 2 then ok = false end end
	for _, e in ipairs(UG.entrances) do if (x - e.x) ^ 2 + (z - e.z) ^ 2 < 260 ^ 2 then ok = false end end
	if ok then
		local c = nearestCavern(x, z)
		local dir = Vector3.new(x - c.x, 0, z - c.z)
		dir = dir.Magnitude > 1 and dir.Unit or Vector3.new(1, 0, 0)
		local sx, sz, h
		local dist = 120
		for _ = 1, 4 do
			sx, sz = c.x + dir.X * dist, c.z + dir.Z * dist
			h = height(sx, sz)
			dist = math.max(80, (h - c.floor) / 0.42)
		end
		sx, sz = c.x + dir.X * dist, c.z + dir.Z * dist
		h = height(sx, sz)
		if h > WATER + 4 and math.abs(sx) < HALF - 200 and math.abs(sz) < HALF - 200 then
			local top = { x = sx, z = sz, floor = h - 1.5, y = h }
			local t = tunnel(top, c, 6.5, urng:NextNumber(-20, 20), "entrance")
			table.insert(UG.entrances, { x = sx, z = sz, y = h, cavern = c, tunnel = t })
		end
	end
end
-- ladder shafts straight down into caverns
for _, c in ipairs(UG.caverns) do
	if #UG.shafts >= 6 then break end
	if not c.grand and not c.lake and not c.lava and urng:NextNumber() < 0.05 then
		local x, z = c.x + c.rx * 0.45, c.z
		local h = height(x, z)
		if h > WATER + 4 then
			table.insert(UG.shafts, { x = x, z = z, top = h + 2, bottom = c.floor, cavern = c, r = 4.5 })
		end
	end
end
-- special places
local function pick(filter)
	local list = {}
	for _, c in ipairs(UG.caverns) do if filter(c) then table.insert(list, c) end end
	return list[urng:NextInteger(1, math.max(1, #list))]
end
local used = {}
local function claim(c, tag) if c then used[c] = true c.tag = tag end return c end
UG.bossLairs = {
	spiderqueen = claim(pick(function(c) return not used[c] and not c.lake and (c.region == "jungle" or c.region == "forest") and c.grand end) or pick(function(c) return not used[c] and c.region == "jungle" end), "spiderqueen"),
	giantworm = claim(pick(function(c) return not used[c] and not c.lake and c.region == "desert" end), "giantworm"),
	mineguardian = claim(nearestTo(MINE, MINE, function(c) return c.mine end), "mineguardian"),
	golem = claim(pick(function(c) return not used[c] and not c.lake and c.grand end), "golem"),
}
UG.ruins = claim(pick(function(c) return not used[c] and c.grand and not c.lake and not c.lava end), "ruins")
UG.dwarves = { claim(nearestTo(-MINE, -MINE, function(c) return c.mine and not used[c] end), "dwarf"), claim(nearestTo(MINE, -MINE, function(c) return c.mine and not used[c] end), "dwarf") }
UG.camps = {}
for _ = 1, 6 do table.insert(UG.camps, claim(pick(function(c) return not used[c] and not c.lake and not c.lava end), "camp")) end
UG.rockfall = {}
for _ = 1, 10 do table.insert(UG.rockfall, claim(pick(function(c) return not used[c] and not c.lake end), "rockfall")) end

-- spatial hash: which shapes touch each 24-stud column cell
local HCELL = 24
local hash = {}
local function hadd(x0, z0, x1, z1, shape)
	for cx = math.floor(x0 / HCELL), math.floor(x1 / HCELL) do
		for cz = math.floor(z0 / HCELL), math.floor(z1 / HCELL) do
			local k = cx * 100000 + cz
			local l = hash[k]
			if not l then l = {} hash[k] = l end
			table.insert(l, shape)
		end
	end
end
for _, c in ipairs(UG.caverns) do
	for _, bl in ipairs(c.blobs) do
		hadd(bl.x - bl.rx - 4, bl.z - bl.rz - 4, bl.x + bl.rx + 4, bl.z + bl.rz + 4, { cav = c, blob = bl })
	end
end
for _, t in ipairs(UG.tunnels) do
	for k = 1, #t.pts - 1 do
		local a, b = t.pts[k], t.pts[k + 1]
		local r = math.max(t.radii and t.radii[k] or t.r, t.radii and t.radii[k + 1] or t.r)
		local m = r + 4
		hadd(math.min(a.X, b.X) - m, math.min(a.Z, b.Z) - m, math.max(a.X, b.X) + m, math.max(a.Z, b.Z) + m,
			{ a = a, b = b, r = r, rough = (t.kind == "mine") and 0 or 1.4, floor = true })
	end
end
for _, s in ipairs(UG.shafts) do
	local a, b = Vector3.new(s.x, s.bottom + s.r, s.z), Vector3.new(s.x, s.top, s.z)
	hadd(s.x - s.r - 2, s.z - s.r - 2, s.x + s.r + 2, s.z + s.r + 2, { a = a, b = b, r = s.r, rough = 0.6, floor = false })
end

-- the shapes that can touch column (x, z)
local function ugColumn(x, z)
	local l = hash[math.floor(x / HCELL) * 100000 + math.floor(z / HCELL)]
	if not l then return nil end
	local out = {}
	for _, sh in ipairs(l) do
		if sh.cav then
			local bl = sh.blob
			if math.abs(x - bl.x) < bl.rx + 4 and math.abs(z - bl.z) < bl.rz + 4 then table.insert(out, sh) end
		else
			local m = sh.r + 4
			if x > math.min(sh.a.X, sh.b.X) - m and x < math.max(sh.a.X, sh.b.X) + m and z > math.min(sh.a.Z, sh.b.Z) - m and z < math.max(sh.a.Z, sh.b.Z) + m then table.insert(out, sh) end
		end
	end
	return #out > 0 and out or nil
end
-- open space at a point: > 0 inside a cave (in studs), < 0 in rock; also the cavern there (for water / lava)
local function ugField(x, y, z, shapes)
	local best, cav = -99, nil
	for _, sh in ipairs(shapes) do
		local f
		if sh.cav then
			local c, bl = sh.cav, sh.blob
			local e = math.sqrt(((x - bl.x) / bl.rx) ^ 2 + ((y - c.y) / bl.ry) ^ 2 + ((z - bl.z) / bl.rz) ^ 2)
			f = (1 - e) * math.min(bl.rx, bl.ry, bl.rz) * 0.9
			if not c.lake then f = math.min(f, y - c.floor) end
			f += math.noise(x / 14, y / 14, z / 14) * 3
			if f > best then best, cav = f, c end
		else
			local ab = sh.b - sh.a
			local p = Vector3.new(x, y, z)
			local t = math.clamp((p - sh.a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
			local q = sh.a + ab * t
			f = sh.r - (p - q).Magnitude
			if sh.floor then f = math.min(f, y - (q.Y - sh.r * 0.6)) end
			if sh.rough > 0 then f += math.noise(x / 10, y / 10, z / 10) * sh.rough end
			if f > best then best, cav = f, nil end
		end
	end
	return best, cav
end
UG.column, UG.field = ugColumn, ugField
