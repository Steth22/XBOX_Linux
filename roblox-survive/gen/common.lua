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
-- A grid of caverns under the whole map, joined by wide winding tunnels (every cavern can reach every other),
-- straight mine lines with rails, ramps down from the surface and ladder shafts. Shared by the terrain writer
-- (to carve it) and the content script (to furnish it). Deterministic.
local UG = { caverns = {}, tunnels = {}, lines = {}, entrances = {}, shafts = {} }
UG.TOP, UG.BOTTOM = -30, -140
local urng = Random.new(9090)
local SP, NG = 190, 15
local grid = {}
for i = 1, NG do
	grid[i] = {}
	for j = 1, NG do
		local grand = urng:NextNumber() < 0.12
		local c = {
			x = -SP * (NG - 1) / 2 + (i - 1) * SP + urng:NextNumber(-45, 45),
			z = -SP * (NG - 1) / 2 + (j - 1) * SP + urng:NextNumber(-45, 45),
			rx = grand and urng:NextNumber(55, 72) or urng:NextNumber(26, 42),
			rz = grand and urng:NextNumber(55, 72) or urng:NextNumber(26, 42),
			ry = grand and urng:NextNumber(24, 30) or urng:NextNumber(13, 19),
			grand = grand, i = i, j = j,
		}
		c.y = grand and urng:NextNumber(-98, -72) or urng:NextNumber(-94, -54)
		if c.y + c.ry > UG.TOP then c.y = UG.TOP - c.ry end
		c.floor = c.y - c.ry * 0.55
		c.region = Biomes.at(c.x, c.z)
		c.lake = not grand and urng:NextNumber() < 0.12
		c.lava = (c.region == "volcano" and urng:NextNumber() < 0.6) or (not c.lake and urng:NextNumber() < 0.04)
		if c.lake then c.water = c.y - c.ry * 0.25 end
		if c.lava then c.pool = { x = c.x + urng:NextNumber(-0.3, 0.3) * c.rx, z = c.z + urng:NextNumber(-0.3, 0.3) * c.rz, r = math.min(c.rx, c.rz) * 0.38 } end
		c.id = #UG.caverns + 1
		table.insert(UG.caverns, c)
		grid[i][j] = c
	end
end
UG.grid = grid

local function smooth01(t) return t * t * (3 - 2 * t) end
-- a tunnel from cavern a to cavern b, following the floors, optionally winding
local function tunnel(a, b, r, wiggle, kind)
	local pts = {}
	local dx, dz = b.x - a.x, b.z - a.z
	local len = math.sqrt(dx * dx + dz * dz)
	local px, pz = -dz / len, dx / len
	local n = math.max(2, math.floor(len / 6))
	local ph = urng:NextNumber(0, 100)
	for k = 0, n do
		local t = k / n
		local off = wiggle * math.sin(math.pi * t) + (wiggle ~= 0 and math.noise(t * 3, ph) * 10 or 0)
		local fl = a.floor + (b.floor - a.floor) * smooth01(t)
		table.insert(pts, Vector3.new(a.x + dx * t + px * off, fl + r * 0.6, a.z + dz * t + pz * off))
	end
	local tn = { pts = pts, r = r, kind = kind or "tunnel", a = a, b = b, id = #UG.tunnels + 1 }
	table.insert(UG.tunnels, tn)
	return tn
end
-- mine lines: two rows and two columns of the grid
local mineEdge = {}
for _, j in ipairs({ 4, 12 }) do for i = 1, NG - 1 do mineEdge[i .. "," .. j .. ">" .. (i + 1) .. "," .. j] = true end end
for _, i in ipairs({ 4, 12 }) do for j = 1, NG - 1 do mineEdge[i .. "," .. j .. ">" .. i .. "," .. (j + 1)] = true end end
local edgeTunnel = {}
for i = 1, NG do
	for j = 1, NG do
		local a = grid[i][j]
		for _, d in ipairs({ { 1, 0 }, { 0, 1 } }) do
			local b = grid[i + d[1]] and grid[i + d[1]][j + d[2]]
			if b then
				local key = i .. "," .. j .. ">" .. (i + d[1]) .. "," .. (j + d[2])
				local t
				if mineEdge[key] then
					t = tunnel(a, b, 6.5, 0, "mine")
				else
					local big = urng:NextNumber() < 0.12
					t = tunnel(a, b, big and urng:NextNumber(9, 11) or urng:NextNumber(6, 8), urng:NextNumber(-30, 30))
					if urng:NextNumber() < 0.06 then t.gas = true end
				end
				edgeTunnel[key] = t
			end
		end
	end
end
-- no lakes or lava pools on the rail lines
for _, t in ipairs(UG.tunnels) do
	if t.kind == "mine" then
		for _, c in ipairs({ t.a, t.b }) do c.lake, c.water, c.lava, c.pool = false, nil, false, nil end
	end
end
-- the rail lines: the mine tunnels joined end to end (they pass through each cavern's centre)
local function addLine(list)
	local pts = {}
	for k, t in ipairs(list) do
		for m, p in ipairs(t.pts) do
			if not (k > 1 and m == 1) then table.insert(pts, Vector3.new(p.X, p.Y - t.r * 0.6, p.Z)) end
		end
	end
	table.insert(UG.lines, pts)
end
for _, j in ipairs({ 4, 12 }) do
	local l = {}
	for i = 1, NG - 1 do table.insert(l, edgeTunnel[i .. "," .. j .. ">" .. (i + 1) .. "," .. j]) end
	addLine(l)
end
for _, i in ipairs({ 4, 12 }) do
	local l = {}
	for j = 1, NG - 1 do table.insert(l, edgeTunnel[i .. "," .. j .. ">" .. i .. "," .. (j + 1)]) end
	addLine(l)
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
	mineguardian = claim(grid[12][12], "mineguardian"),
	golem = claim(pick(function(c) return not used[c] and not c.lake and c.grand end), "golem"),
}
UG.ruins = claim(pick(function(c) return not used[c] and c.grand and not c.lake and not c.lava end), "ruins")
UG.dwarves = { claim(grid[4][4], "dwarf"), claim(grid[12][4], "dwarf") }
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
	hadd(c.x - c.rx - 4, c.z - c.rz - 4, c.x + c.rx + 4, c.z + c.rz + 4, { cav = c })
end
for _, t in ipairs(UG.tunnels) do
	for k = 1, #t.pts - 1 do
		local a, b = t.pts[k], t.pts[k + 1]
		local m = t.r + 4
		hadd(math.min(a.X, b.X) - m, math.min(a.Z, b.Z) - m, math.max(a.X, b.X) + m, math.max(a.Z, b.Z) + m,
			{ a = a, b = b, r = t.r, rough = (t.kind == "mine") and 0 or 1.4, floor = true })
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
			local c = sh.cav
			if math.abs(x - c.x) < c.rx + 4 and math.abs(z - c.z) < c.rz + 4 then table.insert(out, sh) end
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
			local c = sh.cav
			local e = math.sqrt(((x - c.x) / c.rx) ^ 2 + ((y - c.y) / c.ry) ^ 2 + ((z - c.z) / c.rz) ^ 2)
			f = (1 - e) * math.min(c.rx, c.ry, c.rz) * 0.9
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
