local function oreHeight(x, z)
	local vx, vz = math.floor(x / 4) * 4, math.floor(z / 4) * 4
	local mats, occ = workspace.Terrain:ReadVoxels(Region3.new(Vector3.new(vx, -16, vz), Vector3.new(vx + 4, 72, vz + 4)), 4)
	for iy = #mats[1], 1, -1 do
		local m = mats[1][iy][1]
		if m ~= Enum.Material.Air and occ[1][iy][1] > 0 then
			return -16 + (iy - 1) * 4 + occ[1][iy][1] * 4, m == Enum.Material.Water
		end
	end
	return nil
end
local oreRng = Random.new(99)
local ORE = {
	iron = { hp = 14, fleck = Color3.fromRGB(196, 132, 92), mat = Enum.Material.Metal },
	gold = { hp = 18, fleck = Color3.fromRGB(255, 196, 60), mat = Enum.Material.Metal },
	diamond = { hp = 24, fleck = Color3.fromRGB(130, 230, 255), mat = Enum.Material.Glass },
}
local function orePart(m, size, cf, color, mat, collide)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end
local function oreNode(kind, x, z, y)
	local def = ORE[kind]
	local m = Instance.new("Model")
	m.Name = "Ore_" .. kind
	local s = oreRng:NextNumber(3.6, 5)
	local base = orePart(m, Vector3.new(s, s * 0.8, s * 1.05), CFrame.new(x, y + s * 0.25, z) * CFrame.Angles(oreRng:NextNumber(-0.2, 0.2), oreRng:NextNumber(0, 6.28), 0), Color3.fromRGB(92, 90, 96), Enum.Material.Slate, true)
	m.PrimaryPart = base
	for i = 1, (kind == "diamond" and 5 or 7) do
		local off = Vector3.new(oreRng:NextNumber(-0.45, 0.45) * s, oreRng:NextNumber(0.05, 0.45) * s, oreRng:NextNumber(-0.5, 0.5) * s)
		local sz = kind == "diamond" and Vector3.new(0.5, oreRng:NextNumber(1.2, 2), 0.5) or Vector3.new(0.7, 0.55, 0.7) * oreRng:NextNumber(0.8, 1.3)
		local p = orePart(m, sz, base.CFrame * CFrame.new(off) * CFrame.Angles(oreRng:NextNumber(-0.6, 0.6), oreRng:NextNumber(0, 6), oreRng:NextNumber(-0.6, 0.6)), def.fleck, def.mat, false)
		if kind == "diamond" then p.Transparency = 0.15 end
	end
	if kind ~= "iron" then
		local l = Instance.new("PointLight")
		l.Range = 9
		l.Brightness = 0.8
		l.Color = def.fleck
		l.Parent = base
	end
	m:SetAttribute("NodeType", kind)
	m:SetAttribute("HP", def.hp)
	m:SetAttribute("MaxHP", def.hp)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = workspace.Resources
	return m
end
