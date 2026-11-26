-- 1) The striped awning on the trader stalls sloped the wrong way (front edge up): tilt it down.
-- 2) Levels the ground of every house plot (a flat pad of short grass) and returns each pad's height.
-- PLOTS = { {x, z}, ... } is filled in by the caller.
local T = workspace.Terrain
local flipped = 0
for _, folderName in ipairs({ "Camp", "Outposts", "Villages" }) do
	local f = workspace:FindFirstChild(folderName)
	for _, d in ipairs(f and f:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name == "Awning" and d.Material == Enum.Material.Fabric and math.abs(d.Size.Z - 3.2) < 0.01 and not d:GetAttribute("Flipped") then
			d.CFrame = d.CFrame * CFrame.Angles(math.rad(56), 0, 0)
			d:SetAttribute("Flipped", true)
			flipped += 1
		end
	end
end

-- the surface height of the terrain column at x, z
local function surface(x, z)
	local region = Region3.new(Vector3.new(x - 2, -40, z - 2), Vector3.new(x + 2, 140, z + 2)):ExpandToGrid(4)
	local mats, occ = T:ReadVoxels(region, 4)
	local y0 = region.CFrame.Position.Y - region.Size.Y / 2
	for iy = mats.Size.Y, 1, -1 do
		local m = mats[1][iy][1]
		if m ~= Enum.Material.Air and m ~= Enum.Material.Water and occ[1][iy][1] > 0.05 then
			return y0 + (iy - 1) * 4 + 4 * occ[1][iy][1]
		end
	end
	return nil
end

local out = {}
local HALF = 21
for i, p in ipairs(PLOTS) do
	local x, z = p[1], p[2]
	local hi, lo = -math.huge, math.huge
	for dx = -HALF, HALF, 3 do
		for dz = -HALF, HALF, 3 do
			local y = surface(x + dx, z + dz)
			if y then hi = math.max(hi, y) lo = math.min(lo, y) end
		end
	end
	local level = math.floor(hi * 2 + 0.5) / 2
	-- a pad that steps down at the edges so it blends into lower ground
	for k = 4, 0, -1 do
		local size = 2 * HALF + 2 + k * 6
		local top = level - k * 1.5
		T:FillBlock(CFrame.new(x, top - 12, z), Vector3.new(size, 24, size), Enum.Material.LeafyGrass)
	end
	-- nothing above the pad
	T:FillBlock(CFrame.new(x, level + 25, z), Vector3.new(2 * HALF + 2, 50, 2 * HALF + 2), Enum.Material.Air)
	-- no tall grass in the yard
	local region = Region3.new(Vector3.new(x - HALF - 16, level - 30, z - HALF - 16), Vector3.new(x + HALF + 16, level + 8, z + HALF + 16)):ExpandToGrid(4)
	T:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.LeafyGrass)
	-- trees, rocks and bushes that stood on it
	for _, fname in ipairs({ "Resources", "Decor" }) do
		local fo = workspace:FindFirstChild(fname)
		for _, n in ipairs(fo and fo:GetChildren() or {}) do
			local ok, piv = pcall(function() return n:IsA("Model") and n:GetPivot().Position or (n:IsA("BasePart") and n.Position) end)
			if ok and piv and math.abs(piv.X - x) < HALF + 3 and math.abs(piv.Z - z) < HALF + 3 then n:Destroy() end
		end
	end
	out[i] = { x, z, level, math.floor(hi - lo) }
end
local ok = pcall(function() game:GetService("AssetService"):SavePlaceAsync() end)
return game:GetService("HttpService"):JSONEncode({ saved = ok, flipped = flipped, plots = out })
