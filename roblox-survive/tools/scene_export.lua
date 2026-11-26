-- Exports a piece of the real map for the thumbnail renderer: terrain voxels, every part nearby,
-- creatures spawned where the shot needs them, and item models (for the player's hands).
-- Filled in by thumbs.py: CX, CZ, R, Y0, Y1, MOBS = { {kind, x, z, yaw, ySearchTop}, ... }, ITEMS = { ids }
local HttpService = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local T = workspace.Terrain
local RES = 4

-- terrain
local region = Region3.new(Vector3.new(CX - R, Y0, CZ - R), Vector3.new(CX + R, Y1, CZ + R)):ExpandToGrid(RES)
local mats, occ = T:ReadVoxels(region, RES)
local sx, sy, sz = mats.Size.X, mats.Size.Y, mats.Size.Z
local origin = region.CFrame.Position - region.Size / 2
local matIndex, palette = {}, {}
local mchars, ochars = table.create(sx * sy * sz), table.create(sx * sy * sz)
local n = 0
for iz = 1, sz do
	for iy = 1, sy do
		for ix = 1, sx do
			local m = mats[ix][iy][iz]
			local k = matIndex[m]
			if not k then
				table.insert(palette, m.Name)
				k = #palette
				matIndex[m] = k
			end
			n += 1
			mchars[n] = string.char(47 + k)
			ochars[n] = string.char(48 + math.floor(occ[ix][iy][iz] * 40 + 0.5))
		end
	end
end
local colors = {}
for _, name in ipairs(palette) do
	local ok, c = pcall(function() return T:GetMaterialColor(Enum.Material[name]) end)
	colors[name] = ok and { c.R, c.G, c.B } or { 0.5, 0.5, 0.5 }
end

-- ground height at a column (top solid voxel), searching down from a height
local function groundAt(x, z, top)
	local ix = math.clamp(math.floor((x - origin.X) / RES) + 1, 1, sx)
	local iz = math.clamp(math.floor((z - origin.Z) / RES) + 1, 1, sz)
	local start = top and math.clamp(math.floor((top - origin.Y) / RES) + 1, 1, sy) or sy
	local seenAir = top == nil
	for iy = start, 1, -1 do
		local m = mats[ix][iy][iz]
		local solid = m ~= Enum.Material.Air and m ~= Enum.Material.Water and occ[ix][iy][iz] > 0.45
		if not solid then seenAir = true end
		if solid and seenAir then return origin.Y + (iy - 1) * RES + RES * occ[ix][iy][iz] end
	end
	return Y0
end

-- creatures for the shot
local mobsOut = {}
pcall(function()
	local Mobs = require(SSS.Services.Mobs)
	local ctx = { notify = function() end, fx = function() end, push = function() end, broadcast = function() end, feed = function() end,
		reward = function() end, seen = function() end, killed = function() end, lucky = function() return false end, power = function() return 1 end }
	pcall(function() Mobs.start(ctx) end)
	for _, mb in ipairs(MOBS or {}) do
		local gy = groundAt(mb[2], mb[3], mb[5])
		local m = Mobs.spawn(mb[1], Vector3.new(mb[2], gy + 3, mb[3]), 20)
		if m then
			local pivot = m:GetPivot()
			local cf, size = m:GetBoundingBox()
			local dy = gy - (cf.Position.Y - size.Y / 2)
			m:PivotTo(CFrame.new(mb[2], pivot.Position.Y + dy, mb[3]) * CFrame.Angles(0, mb[4] or 0, 0))
			table.insert(mobsOut, m)
		end
	end
end)

-- every visible part in the box
local parts = {}
local function addPart(p)
	if not p:IsA("BasePart") or p.Transparency >= 0.98 then return end
	if p:IsA("Terrain") then return end
	local pos = p.Position
	if math.abs(pos.X - CX) > R + 20 or math.abs(pos.Z - CZ) > R + 20 or pos.Y < Y0 - 20 or pos.Y > Y1 + 60 then return end
	local shape = p:IsA("Part") and p.Shape.Name or (p:IsA("WedgePart") and "Wedge" or "Block")
	local light = p:FindFirstChildWhichIsA("Light")
	table.insert(parts, { s = { p.Size.X, p.Size.Y, p.Size.Z }, c = { p.CFrame:GetComponents() }, col = { p.Color.R, p.Color.G, p.Color.B },
		m = p.Material.Name, sh = shape, t = p.Transparency, l = light and light.Enabled and { light.Color.R, light.Color.G, light.Color.B, light.Brightness, light.Range } or nil })
end
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and not d:IsDescendantOf(workspace.CurrentCamera) then
		local skip = d:FindFirstAncestor("MapWalls") or d:FindFirstAncestor("LobbyScene") or d:FindFirstAncestor("BlackMarketSpots")
		if not skip then addPart(d) end
	end
end

-- item models (centred on their handle) for the player's hands
local items = {}
pcall(function()
	local I = require(RS.Shared.Items)
	for _, id in ipairs(ITEMS or {}) do
		local m = I.model(id)
		if m and m.PrimaryPart then
			local h = m.PrimaryPart.CFrame
			local list = {}
			for _, p in ipairs(m:GetDescendants()) do
				if p:IsA("BasePart") and p.Transparency < 1 then
					local rel = h:ToObjectSpace(p.CFrame)
					table.insert(list, { s = { p.Size.X, p.Size.Y, p.Size.Z }, c = { rel:GetComponents() }, col = { p.Color.R, p.Color.G, p.Color.B }, m = p.Material.Name, sh = p:IsA("Part") and p.Shape.Name or "Block", t = p.Transparency })
				end
			end
			items[id] = list
		end
	end
end)

for _, m in ipairs(mobsOut) do m:Destroy() end
return HttpService:JSONEncode({
	vox = { nx = sx, ny = sy, nz = sz, ox = origin.X, oy = origin.Y, oz = origin.Z, res = RES, mats = table.concat(mchars), occ = table.concat(ochars) },
	palette = palette, colors = colors, parts = parts, items = items,
	ground = (function()
		local g = {}
		for _, q in ipairs(GROUND or {}) do table.insert(g, groundAt(q[1], q[2], q[3])) end
		return g
	end)(),
})
