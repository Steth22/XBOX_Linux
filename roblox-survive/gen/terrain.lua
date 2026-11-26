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
	[Enum.Material.Basalt] = Color3.fromRGB(52, 48, 50), [Enum.Material.CrackedLava] = Color3.fromRGB(255, 96, 30),
	[Enum.Material.Asphalt] = Color3.fromRGB(70, 62, 60),
}) do Terrain:SetMaterialColor(m, col) end
Terrain.WaterTransparency = 0.7
Terrain.WaterColor = Color3.fromRGB(60, 120, 150)
Terrain.WaterWaveSize = 0.2

local function materials(biome, h, wx, wz)
	if biome == "beach" then
		if h < WATER + 0.5 then return Enum.Material.Sand, Enum.Material.Sand, Enum.Material.Sandstone end
		return Enum.Material.Sand, Enum.Material.Sandstone, Enum.Material.Rock
	elseif biome == "jungle" then
		if h < WATER + 1.2 then return Enum.Material.Mud, Enum.Material.Mud, Enum.Material.Rock end
		local patch = math.noise(wx / 30, wz / 30, 64)
		return (patch > -0.1) and Enum.Material.LeafyGrass or Enum.Material.Grass, Enum.Material.Mud, Enum.Material.Rock
	elseif biome == "volcano" then
		if inCrater(wx, wz) then return Enum.Material.CrackedLava, Enum.Material.Basalt, Enum.Material.Basalt end
		local n = math.noise(wx / 26, wz / 26, 83)
		if n > 0.45 then return Enum.Material.CrackedLava, Enum.Material.Basalt, Enum.Material.Basalt end -- small lava cracks
		return (n > 0.05) and Enum.Material.Asphalt or Enum.Material.Basalt, Enum.Material.Basalt, Enum.Material.Rock
	elseif biome == "snow" then
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

-- rock and cave floors under each region (the underground layer)
local UGWALL = { forest = Enum.Material.Rock, hills = Enum.Material.Rock, mountains = Enum.Material.Slate, snow = Enum.Material.Glacier,
	desert = Enum.Material.Sandstone, jungle = Enum.Material.Rock, volcano = Enum.Material.Basalt, beach = Enum.Material.Limestone }
local UGFLOOR = { forest = Enum.Material.Ground, hills = Enum.Material.Ground, mountains = Enum.Material.Slate, snow = Enum.Material.Snow,
	desert = Enum.Material.Sand, jungle = Enum.Material.Mud, volcano = Enum.Material.Basalt, beach = Enum.Material.Sand }
Terrain:SetMaterialColor(Enum.Material.Limestone, Color3.fromRGB(206, 200, 178))

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
				local h, biome = heightB(wx, wz)
				local shapes = UG.column(wx, wz)
				local ylo, yhi = 1e9, -1e9
				if shapes then
					for _, sh in ipairs(shapes) do
						if sh.cav then
							ylo, yhi = math.min(ylo, sh.cav.y - sh.cav.ry - 6), math.max(yhi, sh.cav.y + sh.cav.ry + 6)
						else
							ylo = math.min(ylo, math.min(sh.a.Y, sh.b.Y) - sh.r - 6)
							yhi = math.max(yhi, math.max(sh.a.Y, sh.b.Y) + sh.r + 6)
						end
					end
				end
				cols[ix][iz] = { h = h, biome = biome, wx = wx, wz = wz, shapes = shapes, ylo = ylo, yhi = yhi, under = Biomes.at(wx, wz) }
				if h > maxH then maxH = h end
			end
		end
		local VY0, VY1 = -36, math.ceil(maxH / RES) + 1
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
				local wallM, floorM = UGWALL[c.under] or Enum.Material.Rock, UGFLOOR[c.under] or Enum.Material.Ground
				for iy = VY0, VY1 do
					local y0 = iy * RES
					local yc = y0 + RES / 2
					local solid = math.clamp((c.h - y0) / RES, 0, 1)
					if iy == VY0 then solid = 1 end
					local m, o = Enum.Material.Air, 0
					-- caves cut into the rock (and through the surface at the entrances)
					local f, cav = -99, nil
					if c.shapes and yc > c.ylo and yc < c.yhi then f, cav = UG.field(c.wx, yc, c.wz, c.shapes) end
					local rockOcc = f > -2 and math.clamp(0.5 - f / 3, 0, 1) or 1
					if iy == VY0 then rockOcc = 1 end
					if solid > 0 and rockOcc > 0.04 then
						o = math.min(solid, rockOcc)
						if yc < -16 then
							m = wallM
							if f > -5 and c.shapes then
								local fa, cavA = UG.field(c.wx, yc + RES, c.wz, c.shapes)
								if fa > 0 then
									m = floorM
									local cc = cavA or cav
									if cc and cc.pool and (Vector3.new(c.wx - cc.pool.x, 0, c.wz - cc.pool.z)).Magnitude < cc.pool.r then m = Enum.Material.CrackedLava end
								end
							elseif c.under ~= "snow" and math.noise(c.wx / 40, yc / 40, c.wz / 40) > 0.35 then
								m = Enum.Material.Slate
							end
						elseif c.h - y0 <= RES * 1.2 then m = top
						elseif c.h - y0 <= RES * 3.2 then m = sub
						else m = deep end
					elseif solid > 0 then
						-- carved: air, or an underground lake
						if cav and cav.water and yc < cav.water then m, o = Enum.Material.Water, 1 end
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
