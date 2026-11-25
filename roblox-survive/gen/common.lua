-- shared by every world-generation task: heights + materials for all regions
local Biomes = require(game:GetService("ReplicatedStorage").Shared.Biomes)
local Terrain = workspace.Terrain
local HALF = Biomes.HALF
local WATER = 7
local rng = Random.new(2024)

local function smooth(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function rough(x, z)
	return smooth((math.max(math.abs(x), math.abs(z)) - 520) / 160)
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
	local d = math.max(math.abs(x), math.abs(z))
	local ramp = smooth((d - 300) / 180)
	local n = 1 - math.abs(math.noise(x / 170, z / 170, 41))
	return 16 + ramp * ((n ^ 2.2) * 120 + math.noise(x / 45, z / 45, 42) * 10 + 20)
end
local function hHills(x, z)
	return 15 + math.noise(x / 95, z / 95, 51) * 22 + math.noise(x / 32, z / 32, 52) * 5 + rough(x, z) * 12
end
local FN = { snow = hSnow, desert = hDesert, mountains = hMount, hills = hHills }

-- height, region, how far into the region (0..1)
local function heightB(x, z)
	local b = Biomes.at(x, z)
	local hf = hForest(x, z)
	local w = Biomes.outer(x, z)
	local h = hf
	if w > 0 and FN[b] then h = hf + (FN[b](x, z) - hf) * w end
	local d = math.max(math.abs(x), math.abs(z))
	if d > HALF - 50 then
		local t = (d - (HALF - 50)) / 50
		h += t * t * 80 -- cliffs at the world edge
	end
	return h, b, w
end
local function height(x, z)
	return (heightB(x, z))
end
local function ground(x, z) return height(x, z) end
local function regionAt(x, z)
	local _, b, w = heightB(x, z)
	return (w > 0.5) and b or "forest"
end
