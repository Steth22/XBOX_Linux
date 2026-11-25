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
	forest = { density = 0.38, color = Color3.fromRGB(200, 215, 230), haze = 1.2 },
	hills = { density = 0.42, color = Color3.fromRGB(190, 210, 200), haze = 1.6 },
	snow = { density = 0.5, color = Color3.fromRGB(235, 240, 250), haze = 2.4 },
	desert = { density = 0.44, color = Color3.fromRGB(240, 210, 160), haze = 2.6 },
	mountains = { density = 0.46, color = Color3.fromRGB(195, 205, 225), haze = 1.8 },
}

return B
