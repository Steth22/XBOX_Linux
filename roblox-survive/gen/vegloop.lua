local counts = { tree = 0, rock = 0, bush = 0, flower = 0, iron = 0, gold = 0, diamond = 0 }
local STEP = 18
for gx = -HALF + 40, HALF - 40, STEP do
	for gz = -HALF + 40, HALF - 40, STEP do
		local x = gx + rng:NextNumber(-7, 7)
		local z = gz + rng:NextNumber(-7, 7)
		if not blocked(x, z) then
			local h, b, w = heightB(x, z)
			local region = (w > 0.5) and b or "forest"
			local roll = rng:NextNumber()
			local density = 0.55 + math.noise(x / 120, z / 120, 4.4) * 0.9
			if h > WATER + 1.5 then
				if region == "forest" then
					if roll < 0.5 * density then tree(x, z) counts.tree += 1
					elseif roll < 0.5 * density + 0.04 then rock(x, z) counts.rock += 1
					elseif roll < 0.5 * density + 0.075 then bush(x, z) counts.bush += 1 end
				elseif region == "hills" then
					if roll < 0.34 * density then tree(x, z) counts.tree += 1
					elseif roll < 0.34 * density + 0.06 then rock(x, z) counts.rock += 1
					elseif roll < 0.34 * density + 0.1 then bush(x, z) counts.bush += 1 end
				elseif region == "snow" then
					if roll < 0.16 * density then snowPine(x, z) counts.tree += 1
					elseif roll < 0.16 * density + 0.04 then tintRock(x, z, Color3.fromRGB(150, 160, 175)) counts.rock += 1 end
				elseif region == "desert" then
					if roll < 0.045 then cactus(x, z) counts.tree += 1
					elseif roll < 0.055 then deadTree(x, z) counts.tree += 1
					elseif roll < 0.085 then tintRock(x, z, Color3.fromRGB(196, 150, 104)) counts.rock += 1 end
				elseif region == "mountains" then
					if h < 42 and roll < 0.14 then tree(x, z) counts.tree += 1
					elseif roll < 0.2 then rock(x, z) counts.rock += 1 end
				end
			elseif region == "desert" and h > WATER + 0.3 and roll < 0.3 then
				palm(x, z) counts.tree += 1
			end
		end
	end
end
-- flowers (forest + hills)
for i = 1, 300 do
	local x, z = rng:NextNumber(-HALF + 60, HALF - 60), rng:NextNumber(-HALF + 60, HALF - 60)
	local r = regionAt(x, z)
	if (r == "forest" or r == "hills") and ground(x, z) > WATER + 1.5 and not blocked(x, z) then
		local cols = { Color3.fromRGB(240, 220, 90), Color3.fromRGB(235, 120, 150), Color3.fromRGB(220, 220, 240), Color3.fromRGB(160, 130, 230) }
		part(decor, "Flower", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, ground(x, z) + 0.3, z), cols[rng:NextInteger(1, #cols)], Enum.Material.SmoothPlastic, BALL, false)
		counts.flower += 1
	end
end
-- ores: the further from the centre, the richer (exploration pays off)
local ORE_PLAN = {
	{ "iron", { forest = 10, hills = 14, snow = 10, desert = 8, mountains = 40 } },
	{ "gold", { hills = 4, snow = 6, desert = 10, mountains = 18 } },
	{ "diamond", { snow = 3, desert = 2, mountains = 7 } },
}
for _, plan in ipairs(ORE_PLAN) do
	local kind = plan[1]
	for region, n in pairs(plan[2]) do
		local placed, tries = 0, 0
		while placed < n and tries < n * 60 do
			tries += 1
			local x, z = rng:NextNumber(-HALF + 60, HALF - 60), rng:NextNumber(-HALF + 60, HALF - 60)
			local h = ground(x, z)
			local d = math.max(math.abs(x), math.abs(z))
			local farEnough = kind == "iron" or d > 380 + (kind == "diamond" and 160 or 0)
			if regionAt(x, z) == region and h > WATER + 1.5 and farEnough and not blocked(x, z) then
				oreNode(kind, x, z, h)
				placed += 1
				counts[kind] += 1
			end
		end
	end
end
local ok = pcall(function() game:GetService("AssetService"):SavePlaceAsync() end)
local n = 0
for _ in ipairs(resources:GetChildren()) do n += 1 end
counts.saved = ok
counts.resources = n
return counts
