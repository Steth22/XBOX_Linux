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
