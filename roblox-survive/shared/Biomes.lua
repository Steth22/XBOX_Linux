-- World regions. The same rules are used by the map generator, temperature, creatures and the client fog.
-- Layout: a forest in the middle, six regions around it by direction, and a beach + sea along every edge.
local B = {}
B.HALF = 1536 -- the map spans -HALF..HALF on X and Z
B.CORE = 560 -- the central forest
B.SHORE = B.HALF - 270 -- the beach starts here
B.SEA = B.HALF - 120 -- open water beyond this

B.list = { "forest", "hills", "snow", "desert", "mountains", "beach", "jungle", "volcano" }

local function wobble(x, z)
	return math.noise(x / 300, z / 300, 7.7) * 90
end

-- angle in degrees: east = 0, north (-Z) = 90, south (+Z) = -90
local function angle(x, z)
	return math.deg(math.atan2(-z, x)) + math.noise(x / 420, z / 420, 3.3) * 18
end

function B.sector(x, z)
	local a = angle(x, z)
	if a > 180 then a -= 360 elseif a <= -180 then a += 360 end
	if a >= -25 and a < 45 then return "mountains" end
	if a >= 45 and a < 118 then return "snow" end
	if a >= 118 and a < 172 then return "hills" end
	if a >= -70 and a < -25 then return "volcano" end
	if a >= -125 and a < -70 then return "desert" end
	return "jungle"
end

function B.at(x, z)
	local d = math.max(math.abs(x), math.abs(z))
	if d + math.noise(x / 200, z / 200, 9.1) * 30 > B.SHORE then return "beach" end
	if d + wobble(x, z) < B.CORE then return "forest" end
	return B.sector(x, z)
end

-- blend weight: 0 = central forest, 1 = fully inside the outer region
function B.outer(x, z)
	local d = math.max(math.abs(x), math.abs(z)) + wobble(x, z)
	local t = math.clamp((d - (B.CORE - 60)) / 160, 0, 1)
	return t * t * (3 - 2 * t)
end

-- blend weight towards the beach (0 inland, 1 on the sand)
function B.shore(x, z)
	local d = math.max(math.abs(x), math.abs(z)) + math.noise(x / 200, z / 200, 9.1) * 30
	local t = math.clamp((d - (B.SHORE - 110)) / 110, 0, 1)
	return t * t * (3 - 2 * t)
end

-- volcano cones (centre x, z, radius, height)
B.volcanoes = {
	{ 804, 675, 230, 150 },
	{ 540, 1015, 200, 120 },
}

B.temp = { forest = 22, snow = -2, desert = 40, mountains = 9, hills = 20, beach = 28, jungle = 33, volcano = 44 }
B.nightDrop = { forest = 14, snow = 12, desert = 28, mountains = 14, hills = 14, beach = 10, jungle = 8, volcano = 12 }

-- client fog / mood per region. start / finish: distance fog, nothing is visible beyond `finish`
B.fog = {
	forest = { density = 0.46, color = Color3.fromRGB(196, 210, 222), haze = 2.2, start = 30, finish = 300 },
	hills = { density = 0.5, color = Color3.fromRGB(190, 208, 198), haze = 2.6, start = 40, finish = 338 },
	snow = { density = 0.64, color = Color3.fromRGB(232, 238, 248), haze = 4, start = 10, finish = 188 },
	desert = { density = 0.52, color = Color3.fromRGB(236, 206, 156), haze = 4.5, start = 40, finish = 288 },
	mountains = { density = 0.58, color = Color3.fromRGB(190, 200, 220), haze = 3.2, start = 25, finish = 250 },
	beach = { density = 0.4, color = Color3.fromRGB(205, 225, 238), haze = 2, start = 60, finish = 388 },
	jungle = { density = 0.6, color = Color3.fromRGB(150, 172, 150), haze = 4, start = 8, finish = 169 },
	volcano = { density = 0.6, color = Color3.fromRGB(120, 92, 80), haze = 4, start = 15, finish = 206 },
}

-- medal colours (a necklace for clearing every creature of a region)
B.medal = {
	forest = Color3.fromRGB(90, 170, 80), hills = Color3.fromRGB(150, 190, 110), snow = Color3.fromRGB(170, 220, 255),
	desert = Color3.fromRGB(235, 190, 100), mountains = Color3.fromRGB(170, 170, 185), beach = Color3.fromRGB(90, 200, 220),
	jungle = Color3.fromRGB(40, 150, 90), volcano = Color3.fromRGB(240, 100, 40), caves = Color3.fromRGB(160, 110, 255),
	bandits = Color3.fromRGB(200, 60, 60),
}

return B
