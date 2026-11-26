-- Samples the finished terrain into a small picture for the in-game map: one character per map cell
-- (96 x 96), holding the ground material and a hill shade. Stored as workspace attributes
-- TerrainMap / TerrainMapN. Character = 48 + palette * 4 + shade.
local N = 96
local HALF = 1536
local CELL = 2 * HALF / N
local Y0, Y1 = -12, 288
local T = workspace.Terrain
local M = Enum.Material
local PAL = {
	[M.Grass] = 2, [M.LeafyGrass] = 3, [M.Ground] = 4, [M.Mud] = 5, [M.Sand] = 6, [M.Sandstone] = 7,
	[M.Snow] = 8, [M.Glacier] = 9, [M.Rock] = 10, [M.Slate] = 10, [M.Basalt] = 10, [M.CrackedLava] = 11,
	[M.Asphalt] = 12, [M.Limestone] = 13,
}
local pal, height = {}, {}
for cz = 0, N - 1 do
	local z = -HALF + (cz + 0.5) * CELL
	local z0 = math.floor(z / 4) * 4
	local region = Region3.new(Vector3.new(-HALF, Y0, z0), Vector3.new(HALF, Y1, z0 + 4)):ExpandToGrid(4)
	local mats, occ = T:ReadVoxels(region, 4)
	local sx, sy = mats.Size.X, mats.Size.Y
	for cx = 0, N - 1 do
		local x = -HALF + (cx + 0.5) * CELL
		local vx = math.clamp(math.floor((x - region.CFrame.Position.X + region.Size.X / 2) / 4) + 1, 1, sx)
		local p, h = 0, Y0
		for vy = sy, 1, -1 do
			local m = mats[vx][vy][1]
			if m ~= M.Air and occ[vx][vy][1] > 0.4 then
				h = Y0 + (vy - 1) * 4
				if m == M.Water then
					local depth = 0
					for k = vy, 1, -1 do
						if mats[vx][k][1] == M.Water then depth += 1 else break end
					end
					p = depth > 3 and 0 or 1
				else
					p = PAL[m] or 10
				end
				break
			end
		end
		local i = cz * N + cx + 1
		pal[i], height[i] = p, h
	end
end
-- smooth out single specks of ground: each land cell takes the most common land material around it
local smooth = table.clone(pal)
for cz = 0, N - 1 do
	for cx = 0, N - 1 do
		local i = cz * N + cx + 1
		if pal[i] > 1 and pal[i] ~= 11 then
			local cnt, best, bestN = {}, pal[i], 0
			for dz = -1, 1 do
				for dx = -1, 1 do
					local x, z = cx + dx, cz + dz
					if x >= 0 and z >= 0 and x < N and z < N then
						local q = pal[z * N + x + 1]
						if q > 1 then
							cnt[q] = (cnt[q] or 0) + 1
							if cnt[q] > bestN then best, bestN = q, cnt[q] end
						end
					end
				end
			end
			if bestN >= 4 then smooth[i] = best end
		end
	end
end
pal = smooth
-- bare ground and mud patches look like noise on a map: paint them with the land around them
local function isDirt(q) return q == 4 or q == 5 end
local clean = table.clone(pal)
for cz = 0, N - 1 do
	for cx = 0, N - 1 do
		local i = cz * N + cx + 1
		if isDirt(pal[i]) then
			local cnt, best, bestN = {}, 2, 0
			for r = 1, 4 do
				for dz = -r, r do
					for dx = -r, r do
						local x, z = cx + dx, cz + dz
						if x >= 0 and z >= 0 and x < N and z < N then
							local q = pal[z * N + x + 1]
							if q > 1 and not isDirt(q) then
								cnt[q] = (cnt[q] or 0) + 1
								if cnt[q] > bestN then best, bestN = q, cnt[q] end
							end
						end
					end
				end
				if bestN > 0 then break end
			end
			clean[i] = best
		end
	end
end
pal = clean
-- villages and camps: a packed-earth square with the houses' roofs on it
local function cellOf(x, z)
	local cx, cz = math.floor((x + HALF) / CELL), math.floor((z + HALF) / CELL)
	if cx < 0 or cz < 0 or cx >= N or cz >= N then return nil end
	return cz * N + cx + 1
end
for _, folderName in ipairs({ "Villages", "BanditCamps", "Camp", "Outposts" }) do
	local f = workspace:FindFirstChild(folderName)
	for _, place in ipairs(f and (f:IsA("Model") and { f } or f:GetChildren()) or {}) do
		local c = place:GetAttribute("Center")
		local r = place:GetAttribute("Radius")
		if not c and place:IsA("Model") then c = place:GetPivot().Position r = 30 end
		if c and r then
			for z = c.Z - r, c.Z + r, CELL / 2 do
				for x = c.X - r, c.X + r, CELL / 2 do
					if (x - c.X) ^ 2 + (z - c.Z) ^ 2 <= r * r then
						local i = cellOf(x, z)
						if i and pal[i] > 1 then pal[i] = 14 end
					end
				end
			end
			-- roofs: the big parts high up in each house
			for _, d in ipairs(place:GetDescendants()) do
				if d:IsA("BasePart") and d.Size.X * d.Size.Z > 60 and d.Position.Y > c.Y + 6 then
					local i = cellOf(d.Position.X, d.Position.Z)
					if i and pal[i] == 14 then pal[i] = 15 end
				end
			end
		end
	end
end
local out = table.create(N * N)
for cz = 0, N - 1 do
	for cx = 0, N - 1 do
		local i = cz * N + cx + 1
		-- light from the north-west: slopes facing it are brighter
		local j = (math.max(cz - 1, 0)) * N + math.max(cx - 1, 0) + 1
		local d = height[i] - height[j]
		local shade = d < -8 and 0 or d < 0 and 1 or d < 8 and 2 or 3
		if pal[i] <= 1 then shade = 2 end
		out[i] = string.char(48 + pal[i] * 4 + shade)
	end
end
workspace:SetAttribute("TerrainMap", table.concat(out))

-- the caves: for each cell, the floor of the open space below ground (or solid rock)
-- palette: 0 rock, 1 water, 2 lava, 3 earth, 4 slate, 5 snow/ice, 6 sand, 7 mud, 8 basalt, 9 limestone
local CPAL = { [M.Ground] = 3, [M.Rock] = 3, [M.Slate] = 4, [M.Snow] = 5, [M.Glacier] = 5, [M.Sand] = 6, [M.Sandstone] = 6,
	[M.Mud] = 7, [M.LeafyGrass] = 7, [M.Grass] = 7, [M.Basalt] = 8, [M.Asphalt] = 8, [M.Limestone] = 9 }
local CY0, CY1 = -148, -28
local cave = table.create(N * N)
for cz = 0, N - 1 do
	local z = -HALF + (cz + 0.5) * CELL
	local z0 = math.floor(z / 4) * 4
	local region = Region3.new(Vector3.new(-HALF, CY0, z0), Vector3.new(HALF, CY1, z0 + 4)):ExpandToGrid(4)
	local mats, occ = T:ReadVoxels(region, 4)
	local sx, sy = mats.Size.X, mats.Size.Y
	for cx = 0, N - 1 do
		local x = -HALF + (cx + 0.5) * CELL
		local best, bestH = 0, nil
		-- look at three points across the cell so narrow tunnels still show
		for _, off in ipairs({ -CELL / 3, 0, CELL / 3 }) do
			local vx = math.clamp(math.floor((x + off - region.CFrame.Position.X + region.Size.X / 2) / 4) + 1, 1, sx)
			local open = false
			for vy = sy, 1, -1 do
				local m = mats[vx][vy][1]
				local solid = m ~= M.Air and occ[vx][vy][1] > 0.5
				if m == M.Water and open then best, bestH = 1, vy break end
				if m == M.CrackedLava and open then best, bestH = 2, vy break end
				if not solid and m ~= M.Water then
					open = true
				elseif open then
					local q = CPAL[m] or 3
					if best == 0 or (bestH and vy < bestH) then best, bestH = q, vy end
					break
				end
			end
			if best == 1 or best == 2 then break end
		end
		local shade = 0
		if bestH then shade = math.clamp(math.floor((bestH - 1) / sy * 4), 0, 3) end
		cave[cz * N + cx + 1] = string.char(48 + best * 4 + shade)
	end
end
workspace:SetAttribute("CaveMap", table.concat(cave))
workspace:SetAttribute("TerrainMapN", N)
local okSave = pcall(function() game:GetService("AssetService"):SavePlaceAsync() end)
return { saved = okSave, n = N }
