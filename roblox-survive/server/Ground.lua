-- Ground height straight from the terrain voxels (terrain raycasts proved unreliable on this map).
local Ground = {}

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
local rayWorks = nil

local function voxelHeight(x, z)
	local vx, vz = math.floor(x / 4) * 4, math.floor(z / 4) * 4
	local ok, mats, occ = pcall(function()
		return workspace.Terrain:ReadVoxels(Region3.new(Vector3.new(vx, -16, vz), Vector3.new(vx + 4, 228, vz + 4)), 4)
	end)
	if not ok or not mats or not mats[1] then return nil end
	local col, ocol = mats[1], occ[1]
	for iy = #col, 1, -1 do
		local m = col[iy][1]
		if m ~= Enum.Material.Air and ocol[iy][1] > 0 then
			return -16 + (iy - 1) * 4 + ocol[iy][1] * 4, m == Enum.Material.Water
		end
	end
	return nil
end

-- returns height (or nil), isWater
function Ground.height(x, z)
	if rayWorks ~= false then
		local res = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -200, 0), terrainOnly)
		if res then
			if rayWorks == nil then
				rayWorks = true
				pcall(function() require(script.Parent.Debug).log("ground", "terrain raycasts work") end)
			end
			return res.Position.Y, res.Material == Enum.Material.Water
		elseif rayWorks == nil then
			rayWorks = false
			pcall(function() require(script.Parent.Debug).log("ground", "terrain raycasts FAIL, using voxels") end)
		end
	end
	local h, water = voxelHeight(x, z)
	return h, water
end

-- floor under a point that may be inside a cave: the highest solid voxel with air above it
-- whose top is not above refY + 3.5 (so cave ceilings and the mountain above are ignored)
function Ground.floor(x, refY, z)
	local vx, vz = math.floor(x / 4) * 4, math.floor(z / 4) * 4
	local top = math.floor((refY + 8) / 4) * 4
	local bottom = top - 56
	local ok, mats, occ = pcall(function()
		return workspace.Terrain:ReadVoxels(Region3.new(Vector3.new(vx, bottom, vz), Vector3.new(vx + 4, top, vz + 4)), 4)
	end)
	if not ok or not mats or not mats[1] then return nil end
	local col, ocol = mats[1], occ[1]
	local airAbove = false
	for iy = #col, 1, -1 do
		local m, o = col[iy][1], ocol[iy][1]
		local solid = m ~= Enum.Material.Air and m ~= Enum.Material.Water and o > 0
		if solid then
			local h = bottom + (iy - 1) * 4 + o * 4
			if airAbove and h <= refY + 3.5 then return h end
			airAbove = false
		else
			airAbove = true
		end
	end
	return nil
end

-- true when solid terrain hangs over this point (a cave or an overhang)
function Ground.covered(pos)
	local h = Ground.height(pos.X, pos.Z)
	return h ~= nil and h > pos.Y + 6
end

-- best ground point under pos: parts (cabins, camp) via raycast, else terrain voxels
function Ground.below(pos, exclude)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = exclude or {}
	local res = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rp)
	local h = Ground.height(pos.X, pos.Z)
	if h and h > pos.Y + 6 then h = Ground.floor(pos.X, pos.Y, pos.Z) end -- inside a cave
	if res and (not h or res.Position.Y >= h - 0.5) then return res.Position end
	if h then return Vector3.new(pos.X, h, pos.Z) end
	return pos
end

return Ground
