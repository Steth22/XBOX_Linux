-- World regions. The same rules are used by the map generator, temperature, creatures and the client fog.
local B = {}
B.HALF = 768 -- the map spans -HALF..HALF on X and Z
B.CORE = 340 -- the central forest

local function wobble(x, z)
	return math.noise(x / 170, z / 170, 7.7) * 60
end

function B.at(x, z)
	local d = math.max(math.abs(x), math.abs(z))
	if d + wobble(x, z) < B.CORE then return "forest" end
	local ax, az = math.abs(x), math.abs(z)
	local k = 0.9 + math.noise(x / 220, z / 220, 3.3) * 0.35
	if z < 0 and az >= ax * k then return "snow" end
	if z > 0 and az >= ax * k then return "desert" end
	if x > 0 then return "mountains" end
	return "hills"
end

-- blend weight: 0 = central forest, 1 = fully inside the outer biome
function B.outer(x, z)
	local d = math.max(math.abs(x), math.abs(z)) + wobble(x, z)
	local t = math.clamp((d - (B.CORE - 40)) / 110, 0, 1)
	return t * t * (3 - 2 * t)
end

B.temp = { forest = 22, snow = -2, desert = 40, mountains = 9, hills = 20 }
B.nightDrop = { forest = 14, snow = 12, desert = 28, mountains = 14, hills = 14 }

-- client fog / mood per region
B.fog = {
	-- start / finish: distance fog, nothing is visible beyond `finish`
	forest = { density = 0.46, color = Color3.fromRGB(196, 210, 222), haze = 2.2, start = 30, finish = 240 },
	hills = { density = 0.5, color = Color3.fromRGB(190, 208, 198), haze = 2.6, start = 40, finish = 270 },
	snow = { density = 0.64, color = Color3.fromRGB(232, 238, 248), haze = 4, start = 10, finish = 150 },
	desert = { density = 0.52, color = Color3.fromRGB(236, 206, 156), haze = 4.5, start = 40, finish = 230 },
	mountains = { density = 0.58, color = Color3.fromRGB(190, 200, 220), haze = 3.2, start = 25, finish = 200 },
}

return B
