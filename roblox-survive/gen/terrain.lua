-- writes the terrain for voxel columns XFROM..XTO-1 (whole Z range)
local RES = 4
local VZ0, VZ1 = -HALF // RES, HALF // RES - 1
local CH = 32
for m, col in pairs({
	[Enum.Material.Grass] = Color3.fromRGB(86, 140, 62), [Enum.Material.LeafyGrass] = Color3.fromRGB(70, 120, 52),
	[Enum.Material.Ground] = Color3.fromRGB(110, 84, 58), [Enum.Material.Mud] = Color3.fromRGB(86, 66, 48),
	[Enum.Material.Sand] = Color3.fromRGB(222, 196, 140), [Enum.Material.Sandstone] = Color3.fromRGB(196, 150, 100),
	[Enum.Material.Snow] = Color3.fromRGB(238, 242, 248), [Enum.Material.Glacier] = Color3.fromRGB(170, 215, 235),
	[Enum.Material.Rock] = Color3.fromRGB(118, 116, 114), [Enum.Material.Slate] = Color3.fromRGB(96, 98, 104),
}) do Terrain:SetMaterialColor(m, col) end
Terrain.WaterTransparency = 0.7
Terrain.WaterColor = Color3.fromRGB(60, 120, 150)
Terrain.WaterWaveSize = 0.2

local function materials(biome, h, wx, wz)
	if biome == "snow" then
		return Enum.Material.Snow, Enum.Material.Ground, Enum.Material.Rock
	elseif biome == "desert" then
		if h < WATER + 1.5 then return Enum.Material.Grass, Enum.Material.Sand, Enum.Material.Sandstone end
		return Enum.Material.Sand, Enum.Material.Sandstone, Enum.Material.Sandstone
	elseif biome == "mountains" then
		if h > 82 then return Enum.Material.Snow, Enum.Material.Rock, Enum.Material.Rock end
		if h < 28 then return Enum.Material.Grass, Enum.Material.Ground, Enum.Material.Rock end
		local n = math.noise(wx / 30, wz / 30, 61)
		return (n > 0.2) and Enum.Material.Slate or Enum.Material.Rock, Enum.Material.Rock, Enum.Material.Rock
	else
		if h < WATER + 1.2 then return Enum.Material.Mud, Enum.Material.Ground, Enum.Material.Rock end
		if biome == "hills" and math.noise(wx / 40, wz / 40, 62) > 0.42 then return Enum.Material.Rock, Enum.Material.Ground, Enum.Material.Rock end
		local patch = math.noise(wx / 40 + 9, wz / 40 + 3, 1.7)
		return (patch > 0.18) and Enum.Material.LeafyGrass or Enum.Material.Grass, Enum.Material.Ground, Enum.Material.Rock
	end
end

if XFROM == -HALF // RES then Terrain:Clear() end
for cx = XFROM, XTO - 1, CH do
	for cz = VZ0, VZ1, CH do
		local x1 = math.min(cx + CH - 1, XTO - 1)
		local z1 = math.min(cz + CH - 1, VZ1)
		local cols, maxH = {}, WATER
		for ix = cx, x1 do
			cols[ix] = {}
			for iz = cz, z1 do
				local wx, wz = ix * RES + RES / 2, iz * RES + RES / 2
				local h, b, w = heightB(wx, wz)
				local biome = (w > 0.5) and b or "forest"
				cols[ix][iz] = { h = h, biome = biome, wx = wx, wz = wz }
				if h > maxH then maxH = h end
			end
		end
		local VY0, VY1 = -4, math.ceil(maxH / RES) + 1
		local mats, occ = {}, {}
		for ix = cx, x1 do
			local mx, ox = {}, {}
			mats[ix - cx + 1], occ[ix - cx + 1] = mx, ox
			for iy = VY0, VY1 do
				mx[iy - VY0 + 1], ox[iy - VY0 + 1] = {}, {}
			end
			for iz = cz, z1 do
				local c = cols[ix][iz]
				local top, sub, deep = materials(c.biome, c.h, c.wx, c.wz)
				for iy = VY0, VY1 do
					local y0 = iy * RES
					local solid = math.clamp((c.h - y0) / RES, 0, 1)
					local m, o = Enum.Material.Air, 0
					if solid > 0 then
						o = solid
						if c.h - y0 <= RES * 1.2 then m = top
						elseif c.h - y0 <= RES * 3.2 then m = sub
						else m = deep end
					elseif y0 < WATER then
						if c.biome == "snow" then
							m = Enum.Material.Glacier -- frozen ponds
						else
							m = Enum.Material.Water
						end
						o = math.clamp((WATER - y0) / RES, 0, 1)
					end
					mx[iy - VY0 + 1][iz - cz + 1] = m
					ox[iy - VY0 + 1][iz - cz + 1] = o
				end
			end
		end
		Terrain:WriteVoxels(Region3.new(Vector3.new(cx * RES, VY0 * RES, cz * RES), Vector3.new((x1 + 1) * RES, (VY1 + 1) * RES, (z1 + 1) * RES)), RES, mats, occ)
	end
end
