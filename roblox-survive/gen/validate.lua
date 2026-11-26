-- The last generation stage: finds the mistakes the other stages can leave behind and fixes them.
--   PART = "water"   (with XFROM / XTO in voxels): water hanging in the air or standing as a wall
--                     next to air is removed, spreading until every body of water rests on something.
--   PART = "objects": trees, rocks and plants inside caves, in water or the sea, inside buildings, in
--                     cave mouths or floating are removed; buildings get rock cleared out of their rooms
--                     and solid ground under their floors; cave items stuck in rock or floating go.
local T = workspace.Terrain
local M = Enum.Material
local HALF = 1536
local R = 4
local out = {}

local function vox(lo, hi)
	local region = Region3.new(lo, hi):ExpandToGrid(R)
	local mats, occ = T:ReadVoxels(region, R)
	return region, mats, occ
end

if PART == "water" then
	local Y0, Y1 = -148, 140
	local removed = 0
	local TILE = 64
	for tx = XFROM * R, XTO * R - 1, TILE do
		for tz = -HALF, HALF - 1, TILE do
			-- one voxel of margin all round so the neighbours can be checked
			local lo = Vector3.new(tx - R, Y0, tz - R)
			local hi = Vector3.new(math.min(tx + TILE, XTO * R) + R, Y1, tz + TILE + R)
			local region, mats, occ = vox(lo, hi)
			local sx, sy, sz = mats.Size.X, mats.Size.Y, mats.Size.Z
			local origin = region.CFrame.Position - region.Size / 2
			local function inMap(ix, iz)
				local wx, wz = origin.X + (ix - 0.5) * R, origin.Z + (iz - 0.5) * R
				return wx > -HALF and wx < HALF and wz > -HALF and wz < HALF
			end
			local function isAir(ix, iy, iz)
				if ix < 1 or iz < 1 or ix > sx or iz > sz then return false end
				if not inMap(ix, iz) then return false end
				if iy < 1 or iy > sy then return false end
				-- only real air counts (water voxels can read back with a low occupancy)
				-- only real air counts (ground voxels under water can read back with zero occupancy)
				return mats[ix][iy][iz] == M.Air
			end
			local function bad(ix, iy, iz)
				if mats[ix][iy][iz] ~= M.Water then return false end
				if isAir(ix, iy - 1, iz) then return true end
				return isAir(ix + 1, iy, iz) or isAir(ix - 1, iy, iz) or isAir(ix, iy, iz + 1) or isAir(ix, iy, iz - 1)
			end
			local queue = {}
			for ix = 2, sx - 1 do
				for iz = 2, sz - 1 do
					for iy = 1, sy do
						if mats[ix][iy][iz] == M.Water and bad(ix, iy, iz) then table.insert(queue, { ix, iy, iz }) end
					end
				end
			end
			local changed = false
			local guard = 0
			while #queue > 0 and guard < 200000 do
				guard += 1
				local q = table.remove(queue)
				local ix, iy, iz = q[1], q[2], q[3]
				if ix >= 2 and iz >= 2 and ix <= sx - 1 and iz <= sz - 1 and bad(ix, iy, iz) then
					mats[ix][iy][iz] = M.Air
					occ[ix][iy][iz] = 0
					removed += 1
					changed = true
					-- the water around (and above) it may now be hanging too
					for _, d in ipairs({ { 1, 0, 0 }, { -1, 0, 0 }, { 0, 0, 1 }, { 0, 0, -1 }, { 0, 1, 0 } }) do
						local nx, ny, nz = ix + d[1], iy + d[2], iz + d[3]
						if ny <= sy and mats[nx] and mats[nx][ny] and mats[nx][ny][nz] == M.Water then table.insert(queue, { nx, ny, nz }) end
					end
				end
			end
			if changed then T:WriteVoxels(region, R, mats, occ) end
		end
	end
	out.waterRemoved = removed
end

if PART == "objects" then
	local WATER = 7
	local function solidAt(p)
		local _, mats, occ = vox(p - Vector3.new(1, 1, 1), p + Vector3.new(1, 1, 1))
		local m = mats[1][1][1]
		return m ~= M.Air and m ~= M.Water and occ[1][1][1] > 0.3, m
	end
	-- column above / below a point: is there rock overhead, ground underneath, water at it?
	local function column(p, down, up)
		local region, mats, occ = vox(Vector3.new(p.X - 1, p.Y - down, p.Z - 1), Vector3.new(p.X + 1, p.Y + up, p.Z + 1))
		local base = region.CFrame.Position.Y - region.Size.Y / 2
		local roof, ground, wet = false, false, false
		for iy = 1, mats.Size.Y do
			local y = base + (iy - 0.5) * R
			local m = mats[1][iy][1]
			local solid = m ~= M.Air and m ~= M.Water and occ[1][iy][1] > 0.4
			if y > p.Y + 6 and solid then roof = true end
			if y < p.Y + 1 and y > p.Y - 4 and solid then ground = true end
			if y > p.Y - 1 and y < p.Y + 3 and m == M.Water then wet = true end
		end
		return roof, ground, wet
	end
	-- footprints of buildings and camps (trees must not grow inside them)
	local boxes = {}
	local function addBox(cf, size) table.insert(boxes, { cf = cf, size = size }) end
	for _, name in ipairs({ "Cabins", "Outposts", "BanditCamps", "UnderCamps" }) do
		local f = workspace:FindFirstChild(name)
		for _, m in ipairs(f and f:GetChildren() or {}) do
			if m:IsA("Model") then
				local cf, size = m:GetBoundingBox()
				addBox(cf, size + Vector3.new(4, 0, 4))
			end
		end
	end
	local camp = workspace:FindFirstChild("Camp")
	if camp then local cf, size = camp:GetBoundingBox() addBox(cf, size + Vector3.new(6, 0, 6)) end
	local vf = workspace:FindFirstChild("Villages")
	for _, v in ipairs(vf and vf:GetChildren() or {}) do
		local c, r = v:GetAttribute("Center"), v:GetAttribute("Radius")
		if c and r then addBox(CFrame.new(c), Vector3.new(r * 2, 120, r * 2)) end
	end
	local function inBox(p)
		for _, b in ipairs(boxes) do
			local rel = b.cf:PointToObjectSpace(p)
			if math.abs(rel.X) < b.size.X / 2 and math.abs(rel.Z) < b.size.Z / 2 and math.abs(rel.Y) < b.size.Y / 2 + 6 then return true end
		end
		return false
	end
	-- cave mouths: keep the ramps clear
	local mouths = {}
	local caves = workspace:FindFirstChild("Caves")
	for _, m in ipairs(caves and caves:GetChildren() or {}) do
		local e = m:GetAttribute("Entry")
		if typeof(e) == "Vector3" then table.insert(mouths, e) end
	end
	local function nearMouth(p)
		for _, e in ipairs(mouths) do
			if Vector3.new(p.X - e.X, 0, p.Z - e.Z).Magnitude < 18 and math.abs(p.Y - e.Y) < 30 then return true end
		end
		return false
	end
	local counts = { cave = 0, water = 0, building = 0, mouth = 0, floating = 0, stuck = 0 }
	local function baseOf(m)
		local b = m:GetAttribute("Base")
		if typeof(b) == "Vector3" then return b end
		local cf, size = m:GetBoundingBox()
		return cf.Position - Vector3.new(0, size.Y / 2, 0)
	end
	local function check(item, underground)
		local p = item:IsA("Model") and baseOf(item) or (item.Position - Vector3.new(0, item.Size.Y / 2, 0))
		if underground then
			-- glowing crystals on the walls are meant to be in the rock; check the rest
			if item:IsA("BasePart") and item.Name == "Crystal" then return false end
			local cf, size = (item:IsA("Model") and item:GetBoundingBox()) or item.CFrame, (item:IsA("Model") and select(2, item:GetBoundingBox())) or item.Size
			local mid = (typeof(cf) == "CFrame" and cf.Position) or p
			-- buried: rock at its middle and at its top
			if solidAt(mid) and solidAt(mid + Vector3.new(0, size.Y / 2 - 0.5, 0)) then counts.stuck += 1 return true end
			local _, ground = column(p, 8, 2)
			if not ground then counts.floating += 1 return true end
			return false
		end
		local roof, ground, wet = column(p, 8, 90)
		if p.Y < WATER + 0.6 or wet then counts.water += 1 return true end
		if roof then counts.cave += 1 return true end
		if inBox(p) then counts.building += 1 return true end
		if nearMouth(p) then counts.mouth += 1 return true end
		if not ground then counts.floating += 1 return true end
		return false
	end
	for _, name in ipairs({ "Resources", "Decor" }) do
		local f = workspace:FindFirstChild(name)
		for _, item in ipairs(f and f:GetChildren() or {}) do
			if item:IsA("Model") or item:IsA("BasePart") then
				local pos = item:IsA("Model") and item:GetPivot().Position or item.Position
				if check(item, pos.Y < -26) then item:Destroy() end
			end
		end
	end
	-- things placed in the caverns (crystals, mushrooms, crates)
	for _, cav in ipairs(caves and caves:GetChildren() or {}) do
		for _, item in ipairs(cav:GetChildren()) do
			if (item:IsA("BasePart") or item:IsA("Model")) and item.Name ~= "Spots" then
				if check(item, true) then item:Destroy() end
			end
		end
	end
	out.removed = counts
	-- buildings: no rock inside the rooms, solid ground under the floor
	local cleared, filled = 0, 0
	local function fixFootprint(cf, size, floorY, height)
		local half = Vector3.new(size.X / 2 - 1, 0, size.Z / 2 - 1)
		-- rock poking into the rooms
		local lo = Vector3.new(cf.Position.X - half.X, floorY + 0.5, cf.Position.Z - half.Z)
		local hi = Vector3.new(cf.Position.X + half.X, floorY + height, cf.Position.Z + half.Z)
		local _, mats, occ = vox(lo, hi)
		local solid, total = 0, 0
		for ix = 1, mats.Size.X do for iy = 1, mats.Size.Y do for iz = 1, mats.Size.Z do
			total += 1
			if mats[ix][iy][iz] ~= M.Air and occ[ix][iy][iz] > 0.3 then solid += 1 end
		end end end
		if solid > 0 and solid / math.max(1, total) > 0.01 then
			T:FillBlock(CFrame.new((lo + hi) / 2) * cf.Rotation, Vector3.new(size.X - 1, height, size.Z - 1), M.Air)
			cleared += 1
		end
		-- holes under the floor (a cave or a cliff edge under the house)
		local _, bm, bo = vox(Vector3.new(lo.X, floorY - 8, lo.Z), Vector3.new(hi.X, floorY - 0.5, hi.Z))
		local empty, cells = 0, 0
		for ix = 1, bm.Size.X do for iz = 1, bm.Size.Z do
			cells += 1
			local any = false
			for iy = 1, bm.Size.Y do if bm[ix][iy][iz] ~= M.Air and bo[ix][iy][iz] > 0.3 then any = true end end
			if not any then empty += 1 end
		end end
		if empty / math.max(1, cells) > 0.15 then
			T:FillBlock(CFrame.new(cf.Position.X, floorY - 5, cf.Position.Z) * cf.Rotation, Vector3.new(size.X + 2, 9, size.Z + 2), M.Ground)
			filled += 1
		end
	end
	for _, v in ipairs(vf and vf:GetChildren() or {}) do
		for _, f in ipairs(v:GetChildren()) do
			if f:IsA("BasePart") and f.Name == "Foundation" then
				fixFootprint(f.CFrame, f.Size, f.Position.Y + f.Size.Y / 2, 13)
			end
		end
	end
	for _, name in ipairs({ "Cabins", "Outposts" }) do
		local f = workspace:FindFirstChild(name)
		for _, m in ipairs(f and f:GetChildren() or {}) do
			if m:IsA("Model") then
				local cf, size = m:GetBoundingBox()
				local floorY = cf.Position.Y - size.Y / 2
				local fl = m:FindFirstChild("Floor", true)
				if fl and fl:IsA("BasePart") then floorY = fl.Position.Y + fl.Size.Y / 2 end
				fixFootprint(cf, Vector3.new(size.X - 2, 0, size.Z - 2), floorY, math.min(size.Y - 2, 11))
			end
		end
	end
	out.roomsCleared, out.groundFilled = cleared, filled
end

out.saved = pcall(function() game:GetService("AssetService"):SavePlaceAsync() end)
return out
