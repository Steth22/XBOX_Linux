
-- vegetation + ores for every region (structures must exist already: their areas are kept clear)
local resources = workspace:FindFirstChild("Resources") or Instance.new("Folder")
resources.Name = "Resources"; resources.Parent = workspace
local decor = workspace:FindFirstChild("Decor") or Instance.new("Folder")
decor.Name = "Decor"; decor.Parent = workspace
-- PART 1 clears and fills x < 0, PART 2 fills x >= 0
local XMIN, XMAX = (PART == 1) and -HALF or 0, (PART == 1) and 0 or HALF
if PART == 1 then
	for _, c in ipairs(resources:GetChildren()) do
		if not c:GetAttribute("CaveGen") then c:Destroy() end
	end
	decor:ClearAllChildren()
end
local zones = { { 0, 0, 34 } }
local function addZone(model, r)
	local ok, p = pcall(function() return model:GetPivot().Position end)
	if ok then table.insert(zones, { p.X, p.Z, r }) end
end
if workspace:FindFirstChild("Camp") then addZone(workspace.Camp, 34) end
for _, f in ipairs({ { "Cabins", 18 }, { "Outposts", 36 }, { "BanditCamps", 28 } }) do
	local folder = workspace:FindFirstChild(f[1])
	if folder then for _, m in ipairs(folder:GetChildren()) do addZone(m, f[2]) end end
end
for _, v in ipairs(workspace:FindFirstChild("Villages") and workspace.Villages:GetChildren() or {}) do
	local c = v:GetAttribute("Center")
	if c then table.insert(zones, { c.X, c.Z, 72 }) end
end
for _, s in ipairs(workspace:FindFirstChild("BlackMarketSpots") and workspace.BlackMarketSpots:GetChildren() or {}) do
	table.insert(zones, { s.Position.X, s.Position.Z, 9 })
end
if workspace:FindFirstChild("Caves") then
	for _, m in ipairs(workspace.Caves:GetChildren()) do
		local e = m:GetAttribute("Entry")
		if e then table.insert(zones, { e.X, e.Z, 18 }) end
	end
end
local function blocked(x, z)
	for _, zn in ipairs(zones) do
		if (x - zn[1]) ^ 2 + (z - zn[2]) ^ 2 < zn[3] ^ 2 then return true end
	end
	return false
end

local function part(parent, name, size, cf, color, material, shape, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.Parent = parent
	return p
end


local UPC = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local function tree(x, z)
	local y = ground(x, z)
	local roll = rng:NextNumber()
	local m = Instance.new("Model")
	m.Name = "Tree"
	local trunk
	local function leaf(size, cf, color, shape)
		return part(m, "Leaves", size, cf, color, Enum.Material.Grass, shape, false)
	end
	if roll < 0.45 then
		-- pine: tapered tiers
		local h = rng:NextNumber(15, 23)
		trunk = part(m, "Trunk", Vector3.new(h, 1.7, 1.7), CFrame.new(x, y + h / 2 - 0.6, z) * UPC, Color3.fromRGB(92, 64, 44), Enum.Material.Wood, CYL, true)
		local g = rng:NextNumber(0, 1)
		for i = 0, 4 do
			local t = i / 4
			local dia = 12 - t * 8.5
			local ty = y + h * 0.3 + i * (h * 0.62 / 5)
			local col = Color3.fromRGB(34 + i * 4, 86 + i * 6 + g * 10, 52 + i * 2)
			leaf(Vector3.new(2.4, dia, dia), CFrame.new(x, ty, z) * UPC, col, CYL)
			leaf(Vector3.new(1.4, dia * 0.72, dia * 0.72), CFrame.new(x, ty + 1.5, z) * UPC, col:Lerp(Color3.new(1, 1, 1), 0.06), CYL)
		end
		leaf(Vector3.new(2.6, 2.6, 2.6), CFrame.new(x, y + h * 0.96, z), Color3.fromRGB(56, 120, 66), BALL)
	elseif roll < 0.8 then
		-- oak: thick trunk, branches, clustered crown
		local h = rng:NextNumber(9, 13)
		trunk = part(m, "Trunk", Vector3.new(h, 2.7, 2.7), CFrame.new(x, y + h / 2 - 0.6, z) * UPC, Color3.fromRGB(104, 72, 48), Enum.Material.Wood, CYL, true)
		for i = 1, 2 do
			local a = rng:NextNumber(0, 6.28)
			part(m, "Branch", Vector3.new(0.9, 5, 0.9), CFrame.new(x + math.cos(a) * 1.6, y + h * 0.8, z + math.sin(a) * 1.6) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(-40)), Color3.fromRGB(100, 70, 46), Enum.Material.Wood, nil, false)
		end
		local greens = { Color3.fromRGB(58, 118, 54), Color3.fromRGB(70, 132, 60), Color3.fromRGB(48, 104, 48) }
		for i = 1, 6 do
			local a = i / 6 * 6.28 + rng:NextNumber(-0.4, 0.4)
			local r = i == 6 and 0 or rng:NextNumber(2.5, 4)
			local sz = rng:NextNumber(6, 9)
			leaf(Vector3.new(sz, sz, sz), CFrame.new(x + math.cos(a) * r, y + h + rng:NextNumber(0.5, 3.5) + (i == 6 and 2 or 0), z + math.sin(a) * r), greens[rng:NextInteger(1, 3)], BALL)
		end
	else
		-- birch: white striped trunk, light airy crown
		local h = rng:NextNumber(13, 18)
		trunk = part(m, "Trunk", Vector3.new(h, 1.4, 1.4), CFrame.new(x, y + h / 2 - 0.6, z) * UPC, Color3.fromRGB(226, 222, 212), Enum.Material.SmoothPlastic, CYL, true)
		for i = 1, 5 do
			part(m, "Stripe", Vector3.new(0.25, 1.48, 1.48), CFrame.new(x, y + i * h / 6, z) * UPC * CFrame.Angles(rng:NextNumber(0, 6), 0, 0), Color3.fromRGB(60, 58, 56), Enum.Material.SmoothPlastic, CYL, false)
		end
		for i = 1, 3 do
			local sz = 7 - i
			leaf(Vector3.new(sz, sz, sz), CFrame.new(x + rng:NextNumber(-1.5, 1.5), y + h * 0.65 + i * 2.6, z + rng:NextNumber(-1.5, 1.5)), Color3.fromRGB(116 + i * 8, 168 + i * 6, 74), BALL)
		end
	end
	m.PrimaryPart = trunk
	m:SetAttribute("NodeType", "tree")
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:SetAttribute("HP", 9)
	m:SetAttribute("MaxHP", 9)
	m:SetAttribute("Base", Vector3.new(x, y - 0.5, z))
	m.Parent = resources
end

local function rock(x, z)
	local y = ground(x, z)
	local m = Instance.new("Model")
	m.Name = "Rock"
	local s = rng:NextNumber(3.5, 6)
	local col = Color3.fromRGB(118 + rng:NextInteger(-8, 8), 120, 126)
	local main = part(m, "Rock", Vector3.new(s, s * 0.8, s * 1.1), CFrame.new(x, y + s * 0.25, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6.28), rng:NextNumber(-0.2, 0.2)), col, Enum.Material.Slate, nil, true)
	m.PrimaryPart = main
	part(m, "Rock", Vector3.new(s * 0.55, s * 0.5, s * 0.6), CFrame.new(x + s * 0.6, y + s * 0.1, z + s * 0.3) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0.15), col:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.Slate, nil, true)
	part(m, "Rock", Vector3.new(s * 0.4, s * 0.35, s * 0.45), CFrame.new(x - s * 0.55, y, z - s * 0.4) * CFrame.Angles(0.2, rng:NextNumber(0, 6.28), 0), col:Lerp(Color3.new(0, 0, 0), 0.08), Enum.Material.Slate, nil, true)
	part(m, "Moss", Vector3.new(s * 0.7, 0.25, s * 0.8), main.CFrame * CFrame.new(0, s * 0.4, 0), Color3.fromRGB(78, 120, 60), Enum.Material.Grass, nil, false)
	m:SetAttribute("NodeType", "rock")
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:SetAttribute("HP", 12)
	m:SetAttribute("MaxHP", 12)
	m.Parent = resources
end

local function bush(x, z)
	local y = ground(x, z)
	local m = Instance.new("Model")
	m.Name = "BerryBush"
	local base = part(m, "Base", Vector3.new(4.6, 3.4, 4.6), CFrame.new(x, y + 1.2, z), Color3.fromRGB(58, 116, 56), Enum.Material.Grass, Enum.PartType.Ball, true)
	m.PrimaryPart = base
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		part(m, "Berry", Vector3.new(0.7, 0.7, 0.7), CFrame.new(x + math.cos(a) * 1.9, y + 1.2 + rng:NextNumber(-0.4, 0.9), z + math.sin(a) * 1.9), Color3.fromRGB(176, 40, 90), Enum.Material.SmoothPlastic, Enum.PartType.Ball, false)
	end
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Pick"
	pr:SetAttribute("Key", "pick")
	pr.ObjectText = "Berries"
	pr.HoldDuration = 0.4
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.Parent = base
	m:SetAttribute("NodeType", "bush")
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:SetAttribute("Ready", true)
	m.Parent = resources
end



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

local function node(m, trunk, hp, base)
	m.PrimaryPart = trunk
	m:SetAttribute("NodeType", "tree")
	m:SetAttribute("HP", hp)
	m:SetAttribute("MaxHP", hp)
	m:SetAttribute("Base", base)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = resources
end
local function snowPine(x, z)
	local y = ground(x, z)
	local m = Instance.new("Model"); m.Name = "Tree"
	local h = rng:NextNumber(14, 22)
	local trunk = part(m, "Trunk", Vector3.new(h, 1.6, 1.6), CFrame.new(x, y + h / 2 - 0.6, z) * UPC, Color3.fromRGB(84, 60, 44), Enum.Material.Wood, CYL, true)
	for i = 0, 3 do
		local dia = 11 - i * 2.6
		local ty = y + h * 0.32 + i * (h * 0.62 / 4)
		part(m, "Leaves", Vector3.new(2.4, dia, dia), CFrame.new(x, ty, z) * UPC, Color3.fromRGB(34, 74, 52), Enum.Material.Grass, CYL, false)
		part(m, "Snow", Vector3.new(0.6, dia * 0.86, dia * 0.86), CFrame.new(x, ty + 1.4, z) * UPC, Color3.fromRGB(240, 244, 250), Enum.Material.Snow, CYL, false)
	end
	node(m, trunk, 9, Vector3.new(x, y - 0.5, z))
end
local function cactus(x, z)
	local y = ground(x, z)
	local m = Instance.new("Model"); m.Name = "Tree"
	local h = rng:NextNumber(6, 10)
	local green = Color3.fromRGB(78, 128, 62)
	local trunk = part(m, "Trunk", Vector3.new(h, 1.6, 1.6), CFrame.new(x, y + h / 2 - 0.4, z) * UPC, green, Enum.Material.Grass, CYL, true)
	part(m, "Leaves", Vector3.new(1.6, 1.6, 1.6), CFrame.new(x, y + h - 0.4, z), green, Enum.Material.Grass, BALL, false)
	for _, sx in ipairs({ -1, 1 }) do
		local ay = y + h * rng:NextNumber(0.35, 0.6)
		part(m, "Leaves", Vector3.new(1.6, 1.1, 1.1), CFrame.new(x + sx * 1.3, ay, z) * CFrame.Angles(0, 0, 0), green, Enum.Material.Grass, CYL, false)
		part(m, "Leaves", Vector3.new(2.4, 1.1, 1.1), CFrame.new(x + sx * 2, ay + 1.2, z) * UPC, green, Enum.Material.Grass, CYL, false)
	end
	node(m, trunk, 6, Vector3.new(x, y - 0.4, z))
end
local function palm(x, z)
	local y = ground(x, z)
	local m = Instance.new("Model"); m.Name = "Tree"
	local lean = rng:NextNumber(-0.25, 0.25)
	local trunk
	for i = 0, 3 do
		local p = part(m, "Trunk", Vector3.new(3.2, 1.2 - i * 0.1, 1.2 - i * 0.1), CFrame.new(x + lean * i * 3, y + 1.4 + i * 3, z) * UPC * CFrame.Angles(lean, 0, 0), Color3.fromRGB(150, 116, 76), Enum.Material.Wood, CYL, i == 0)
		if i == 0 then trunk = p end
	end
	local top = Vector3.new(x + lean * 12, y + 13, z)
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		part(m, "Leaves", Vector3.new(6, 0.3, 1.6), CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.new(2.6, -0.4, 0) * CFrame.Angles(0, 0, math.rad(-18)), Color3.fromRGB(70, 140, 60), Enum.Material.Grass, nil, false)
	end
	node(m, trunk, 8, Vector3.new(x, y - 0.4, z))
end
local function deadTree(x, z)
	local y = ground(x, z)
	local m = Instance.new("Model"); m.Name = "Tree"
	local h = rng:NextNumber(7, 11)
	local c = Color3.fromRGB(110, 92, 76)
	local trunk = part(m, "Trunk", Vector3.new(h, 1.2, 1.2), CFrame.new(x, y + h / 2 - 0.4, z) * UPC, c, Enum.Material.Wood, CYL, true)
	for i = 1, 3 do
		local a = rng:NextNumber(0, 6.28)
		part(m, "Branch", Vector3.new(0.4, 3.4, 0.4), CFrame.new(x + math.cos(a), y + h * (0.5 + i * 0.12), z + math.sin(a)) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(-45)), c, Enum.Material.Wood, nil, false)
	end
	node(m, trunk, 5, Vector3.new(x, y - 0.4, z))
end
local function tintRock(x, z, color)
	rock(x, z)
	local r = resources:GetChildren()
	local m = r[#r]
	if m and m.Name == "Rock" and color then
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Rock" then p.Color = color end
			if p:IsA("BasePart") and p.Name == "Moss" then p.Color = color:Lerp(Color3.new(1, 1, 1), 0.6); p.Material = Enum.Material.Snow end
		end
	end
end

local function jungleTree(x, z)
	local y = ground(x, z)
	local m = Instance.new("Model"); m.Name = "Tree"
	local h = rng:NextNumber(22, 32)
	local bark = Color3.fromRGB(96, 80, 60)
	local trunk = part(m, "Trunk", Vector3.new(h, 2.6, 2.6), CFrame.new(x, y + h / 2 - 0.6, z) * UPC, bark, Enum.Material.Wood, CYL, true)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		part(m, "Root", Vector3.new(0.7, 3.2, 3.6), CFrame.new(x + math.cos(a) * 1.6, y + 1.2, z + math.sin(a) * 1.6) * CFrame.Angles(0, -a, 0), bark, Enum.Material.Wood, nil, false)
	end
	local greens = { Color3.fromRGB(40, 110, 50), Color3.fromRGB(30, 96, 44), Color3.fromRGB(56, 126, 58) }
	for i = 1, 5 do
		local a = i / 5 * 6.28
		local r = i == 5 and 0 or rng:NextNumber(4, 6)
		local sz = rng:NextNumber(10, 14)
		part(m, "Leaves", Vector3.new(sz, sz * 0.45, sz), CFrame.new(x + math.cos(a) * r, y + h + rng:NextNumber(-1.5, 1.5), z + math.sin(a) * r), greens[rng:NextInteger(1, 3)], Enum.Material.Grass, BALL, false)
	end
	for _ = 1, 4 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(3, 6)
		local len = rng:NextNumber(6, 12)
		part(m, "Vine", Vector3.new(len, 0.25, 0.25), CFrame.new(x + math.cos(a) * r, y + h - len / 2 - 1, z + math.sin(a) * r) * UPC, Color3.fromRGB(60, 120, 50), Enum.Material.Grass, CYL, false)
	end
	node(m, trunk, 14, Vector3.new(x, y - 0.5, z))
end
local function fern(x, z)
	local y = ground(x, z)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		part(decor, "Fern", Vector3.new(3.2, 0.2, 1), CFrame.new(x, y + 0.6, z) * CFrame.Angles(0, a, 0) * CFrame.new(1.4, 0, 0) * CFrame.Angles(0, 0, math.rad(28)), Color3.fromRGB(60, 130, 56), Enum.Material.Grass, nil, false)
	end
end
local counts = { tree = 0, rock = 0, bush = 0, flower = 0, iron = 0, gold = 0, diamond = 0 }
local STEP = 22
for gx = XMIN + 40, XMAX - 1, STEP do
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
				elseif region == "jungle" then
					if roll < 0.42 * density + 0.12 then jungleTree(x, z) counts.tree += 1
					elseif roll < 0.42 * density + 0.2 then fern(x, z)
					elseif roll < 0.42 * density + 0.24 then bush(x, z) counts.bush += 1
					elseif roll < 0.42 * density + 0.27 then rock(x, z) counts.rock += 1 end
				elseif region == "beach" then
					if roll < 0.08 then palm(x, z) counts.tree += 1
					elseif roll < 0.1 then tintRock(x, z, Color3.fromRGB(200, 190, 170)) counts.rock += 1 end
				elseif region == "volcano" then
					if h < 60 and roll < 0.05 then deadTree(x, z) counts.tree += 1
					elseif roll < 0.13 then tintRock(x, z, Color3.fromRGB(60, 54, 56)) counts.rock += 1 end
				end
			elseif region == "desert" and h > WATER + 0.3 and roll < 0.3 then
				palm(x, z) counts.tree += 1
			elseif region == "beach" and h > WATER + 0.3 and roll < 0.06 then
				palm(x, z) counts.tree += 1
			end
		end
	end
end
-- flowers (forest + hills)
for i = 1, 400 do
	local x, z = rng:NextNumber(XMIN + 60, XMAX - 60), rng:NextNumber(-HALF + 60, HALF - 60)
	local r = regionAt(x, z)
	if (r == "forest" or r == "hills") and ground(x, z) > WATER + 1.5 and not blocked(x, z) then
		local cols = { Color3.fromRGB(240, 220, 90), Color3.fromRGB(235, 120, 150), Color3.fromRGB(220, 220, 240), Color3.fromRGB(160, 130, 230) }
		part(decor, "Flower", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, ground(x, z) + 0.3, z), cols[rng:NextInteger(1, #cols)], Enum.Material.SmoothPlastic, BALL, false)
		counts.flower += 1
	end
end
-- ores: the further from the centre, the richer (exploration pays off)
local ORE_PLAN = {
	{ "iron", { forest = 14, hills = 18, snow = 14, desert = 10, mountains = 40, jungle = 10, volcano = 16, beach = 4 } },
	{ "gold", { hills = 6, snow = 8, desert = 12, mountains = 18, jungle = 8, volcano = 10, beach = 3 } },
	{ "diamond", { snow = 3, desert = 3, mountains = 6, jungle = 2, volcano = 7 } },
}
for _, plan in ipairs(ORE_PLAN) do
	local kind = plan[1]
	for region, n in pairs(plan[2]) do
		local placed, tries = 0, 0
		while placed < n and tries < n * 80 do
			tries += 1
			local x, z = rng:NextNumber(XMIN + 60, XMAX - 60), rng:NextNumber(-HALF + 60, HALF - 60)
			local h = ground(x, z)
			local d = math.max(math.abs(x), math.abs(z))
			local farEnough = kind == "iron" or d > 620 + (kind == "diamond" and 250 or 0)
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
