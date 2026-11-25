-- camp + market, cabins, caves, region outposts, world walls, spawn
local Appearance = require(game:GetService("ReplicatedStorage").Shared.Appearance)
local Items = require(game:GetService("ReplicatedStorage").Shared.Items)
for _, n in ipairs({ "Resources", "Decor", "MapWalls", "ForestSpawn", "Camp", "Cabins", "Caves", "Outposts", "Villages", "BanditCamps", "BlackMarketSpots", "MobTemplates" }) do
	local o = workspace:FindFirstChild(n)
	if o then o:Destroy() end
end
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local zones = {}
local resources = Instance.new("Folder"); resources.Name = "Resources"; resources.Parent = workspace
local decor = Instance.new("Folder"); decor.Name = "Decor"; decor.Parent = workspace

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


-- ---------------------------------------------------------------- camp: trader + fire
local Appearance = require(game:GetService("ReplicatedStorage").Shared.Appearance)
local camp = Instance.new("Model"); camp.Name = "Camp"; camp.Parent = workspace
local CX, CZ = 0, -26
table.insert(zones, { CX, CZ, 26 })
local function cpart(name, size, cf, color, mat, shape)
	local p = part(camp, name, size, cf, color, mat, shape, true)
	return p
end
local g0 = ground(CX, CZ)
local woodC = Color3.fromRGB(122, 86, 56)
cpart("Floor", Vector3.new(16, 1, 9), CFrame.new(CX, g0 + 0.2, CZ), Color3.fromRGB(100, 72, 48), Enum.Material.WoodPlanks)
local counter = cpart("Counter", Vector3.new(12, 2.4, 2.4), CFrame.new(CX, g0 + 1.9, CZ + 2.6), woodC, Enum.Material.WoodPlanks)
for _, x in ipairs({ -7, 7 }) do
	for _, z in ipairs({ -3.8, 3.8 }) do
		cpart("Post", Vector3.new(0.7, 9, 0.7), CFrame.new(CX + x, g0 + 5, CZ + z), woodC, Enum.Material.Wood)
	end
end
for i = 0, 7 do
	local col = (i % 2 == 0) and Color3.fromRGB(196, 70, 60) or Color3.fromRGB(240, 230, 210)
	cpart("Canopy", Vector3.new(2, 0.3, 10), CFrame.new(CX - 7 + i * 2 + 1, g0 + 9.6, CZ) * CFrame.Angles(math.rad(-12), 0, 0), col, Enum.Material.Fabric)
end
local sign = cpart("Sign", Vector3.new(8, 2, 0.4), CFrame.lookAt(Vector3.new(CX, g0 + 11.3, CZ + 4.2), Vector3.new(CX, g0 + 11.3, CZ + 10)), Color3.fromRGB(80, 56, 38), Enum.Material.Wood)
local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.CanvasSize = Vector2.new(400, 100); sg.Parent = sign
local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.Text = "المتجر  |  SHOP"; tl.Font = Enum.Font.GothamBold; tl.TextScaled = true; tl.TextColor3 = Color3.fromRGB(255, 210, 110); tl.Parent = sg
for i = 1, 3 do
	cpart("Crate", Vector3.new(2.4, 2.4, 2.4), CFrame.new(CX + 9 + (i % 2) * 1.2, g0 + 1.2 + (i == 3 and 2.4 or 0), CZ - 2 + i * 1.4) * CFrame.Angles(0, i, 0), Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
end
local pr = Instance.new("ProximityPrompt")
pr.ActionText = "Shop"; pr.ObjectText = "Trader"; pr.HoldDuration = 0; pr.MaxActivationDistance = 12; pr.RequiresLineOfSight = false
pr:SetAttribute("Key", "trade")
pr.Parent = counter
-- the trader (faceless, our own body)
local okRig, rig = pcall(function()
	return game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
end)
if okRig and rig then
	rig.Name = "Trader"
	for _, d in ipairs(rig:GetDescendants()) do if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rig.HumanoidRootPart.Anchored = true
	local h = hum.HipHeight + rig.HumanoidRootPart.Size.Y / 2
	rig:PivotTo(CFrame.lookAt(Vector3.new(CX, g0 + 0.7 + h, CZ + 0.4), Vector3.new(CX, g0 + 0.7 + h, CZ + 10)))
	rig.Parent = camp
	Appearance.apply(rig, { skin = 3, shirt = 2, pants = 1, hat = "cowboy", extra = "belt" })
end
-- campfire
local FX, FZ = CX - 13, CZ + 12
local gf = ground(FX, FZ)
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	cpart("Stone", Vector3.new(1.3, 0.9, 1.3), CFrame.new(FX + math.cos(a) * 2.3, gf + 0.3, FZ + math.sin(a) * 2.3), Color3.fromRGB(120, 120, 126), Enum.Material.Slate, Enum.PartType.Ball)
end
local core = cpart("CampfireCore", Vector3.new(2.6, 0.6, 2.6), CFrame.new(FX, gf + 0.3, FZ), Color3.fromRGB(70, 46, 32), Enum.Material.Wood)
local fire = Instance.new("Fire"); fire.Size = 7; fire.Heat = 9; fire.Parent = core
local pl = Instance.new("PointLight"); pl.Range = 30; pl.Brightness = 2.2; pl.Color = Color3.fromRGB(255, 160, 80); pl.Parent = core
for i, a in ipairs({ 0.5, 2.4, 4.2 }) do
	cpart("Log", Vector3.new(5, 1.4, 1.4), CFrame.new(FX + math.cos(a) * 6, gf + 0.6, FZ + math.sin(a) * 6) * CFrame.Angles(0, -a + math.pi / 2, 0), Color3.fromRGB(110, 76, 50), Enum.Material.Wood, Enum.PartType.Cylinder)
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

local function buildStall()
	local Items = require(game:GetService("ReplicatedStorage").Shared.Items)
	local camp = workspace.Camp
	local trader = camp:FindFirstChild("Trader")
	local oldFloor = camp:FindFirstChild("Floor")
	local CX, CZ = 0, -26
	local g0 = oldFloor and (oldFloor.Position.Y - 0.2) or 11
	for _, c in ipairs(camp:GetChildren()) do
		if c:IsA("BasePart") and ({ Floor = 1, Counter = 1, Post = 1, Canopy = 1, Sign = 1, Crate = 1 })[c.Name] then c:Destroy() end
		if c.Name == "Stall" or c.Name == "Storage" then c:Destroy() end
	end
	local stall = Instance.new("Model")
	stall.Name = "Stall"
	stall.Parent = camp
	local function p(name, size, cf, color, mat, shape, collide)
		local x = Instance.new("Part")
		x.Name = name
		x.Anchored = true
		x.Size = size
		x.CFrame = cf
		x.Color = color
		x.Material = mat or Enum.Material.WoodPlanks
		if shape then x.Shape = shape end
		x.CanCollide = collide ~= false
		x.TopSurface = Enum.SurfaceType.Smooth
		x.BottomSurface = Enum.SurfaceType.Smooth
		x.Parent = stall
		return x
	end
	local base = CFrame.new(CX, g0, CZ)
	local wood, dark, roofC = Color3.fromRGB(128, 90, 58), Color3.fromRGB(86, 60, 40), Color3.fromRGB(150, 62, 48)
	p("Floor", Vector3.new(20, 0.8, 12), base * CFrame.new(0, 0.4, -1), dark)
	p("Step", Vector3.new(8, 0.5, 2), base * CFrame.new(0, 0.25, 5.8), dark)
	-- back wall + side walls (half height at the sides)
	p("Wall", Vector3.new(20, 10, 0.8), base * CFrame.new(0, 5.4, -6.6), wood)
	for _, x in ipairs({ -9.6, 9.6 }) do
		p("Wall", Vector3.new(0.8, 10, 12), base * CFrame.new(x, 5.4, -1), wood)
		p("Post", Vector3.new(1, 11, 1), base * CFrame.new(x, 5.9, 5), dark, Enum.Material.Wood)
	end
	-- roof
	p("Roof", Vector3.new(22, 0.7, 14.5), base * CFrame.new(0, 11.4, -0.6) * CFrame.Angles(math.rad(-10), 0, 0), roofC, Enum.Material.Wood)
	p("RoofTrim", Vector3.new(22.2, 0.5, 0.8), base * CFrame.new(0, 10.3, 6.4), dark, Enum.Material.Wood)
	-- striped awning over the counter
	for i = 0, 9 do
		local col = (i % 2 == 0) and Color3.fromRGB(196, 70, 60) or Color3.fromRGB(240, 230, 210)
		p("Awning", Vector3.new(2, 0.25, 3.2), base * CFrame.new(-9 + i * 2, 9.4, 7.4) * CFrame.Angles(math.rad(-28), 0, 0), col, Enum.Material.Fabric, nil, false)
	end
	-- counter (the trade prompt lives here)
	local counter = p("Counter", Vector3.new(14, 2.6, 2.2), base * CFrame.new(0, 2.1, 3.2), wood)
	p("CounterTop", Vector3.new(14.6, 0.35, 2.6), base * CFrame.new(0, 3.55, 3.2), dark)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Shop"; pr.ObjectText = "Trader"; pr.HoldDuration = 0; pr.MaxActivationDistance = 12; pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "trade")
	pr.Parent = counter
	-- shelves with real items on display
	local shelfItems = {
		{ "wood_axe", "stone_axe", "iron_axe", "diamond_axe" },
		{ "wood_pickaxe", "stone_pickaxe", "iron_pickaxe", "diamond_pickaxe" },
		{ "stone_sword", "iron_sword", "diamond_sword", "iron_armor" },
	}
	for row = 1, 3 do
		local y = 2.6 + row * 2.3
		p("Shelf", Vector3.new(16, 0.3, 1.6), base * CFrame.new(0, y, -5.6), dark)
		for i, id in ipairs(shelfItems[row]) do
			local m = Items.model(id)
			if m then
				for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end end
				local x = -6 + (i - 1) * 4
				local isArmor = string.find(id, "armor") ~= nil
				m:PivotTo(base * CFrame.new(x, y + (isArmor and 0.9 or 1.1), -5.6) * (isArmor and CFrame.new() or CFrame.Angles(0, math.rad(90), math.rad(-70))))
				m.Parent = stall
			end
		end
	end
	for i, id in ipairs({ "bow", "pistol", "leather_armor" }) do
		local m = Items.model(id)
		if m then
			for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end end
			m:PivotTo(base * CFrame.new(-4.5 + (i - 1) * 4.5, 4.2, 3.2) * CFrame.Angles(0, math.rad(20), math.rad(90)))
			m.Parent = stall
		end
	end
	-- lanterns
	for _, x in ipairs({ -7, 7 }) do
		p("Chain", Vector3.new(0.1, 1.4, 0.1), base * CFrame.new(x, 9.2, 5.2), Color3.fromRGB(60, 60, 64), Enum.Material.Metal, nil, false)
		local lamp = p("Lantern", Vector3.new(0.9, 1.2, 0.9), base * CFrame.new(x, 7.9, 5.2), Color3.fromRGB(255, 205, 120), Enum.Material.Neon, nil, false)
		local l = Instance.new("PointLight"); l.Range = 16; l.Brightness = 1.4; l.Color = Color3.fromRGB(255, 185, 110); l.Parent = lamp
	end
	-- barrels + sign
	for i, pos in ipairs({ Vector3.new(11.5, 0, 4), Vector3.new(12.6, 0, 1.6), Vector3.new(-11.6, 0, 3.4) }) do
		p("Barrel", Vector3.new(2.8, 2.2, 2.2), base * CFrame.new(pos + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 82, 50), Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	local sign = p("Sign", Vector3.new(9, 2.2, 0.4), CFrame.lookAt((base * CFrame.new(0, 12.9, 6.6)).Position, (base * CFrame.new(0, 12.9, 20)).Position), dark, Enum.Material.Wood)
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.CanvasSize = Vector2.new(420, 100); sg.Parent = sign
	local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.Text = "المتجر  |  SHOP"; tl.Font = Enum.Font.GothamBold; tl.TextScaled = true; tl.TextColor3 = Color3.fromRGB(255, 210, 110); tl.Parent = sg
	-- trader stands behind the counter
	if trader and trader:FindFirstChild("HumanoidRootPart") then
		local hum = trader:FindFirstChildOfClass("Humanoid")
		local h = (hum and hum.HipHeight or 2) + trader.HumanoidRootPart.Size.Y / 2
		local pos = (base * CFrame.new(0, 0.8 + h, 1.0)).Position
		trader:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 10)))
	end
	-- storage chests next to the fire
	local fire = camp:FindFirstChild("CampfireCore")
	local fpos = fire and fire.Position or (base * CFrame.new(-13, 0, 12)).Position
	for i, off in ipairs({ Vector3.new(-9, 0, -3), Vector3.new(-9, 0, 1.5) }) do
		local m = Instance.new("Model"); m.Name = "Storage"
		local at = fpos + off
		local function sp(name, size, cf, color, mat)
			local x = Instance.new("Part"); x.Name = name; x.Anchored = true; x.Size = size; x.CFrame = cf; x.Color = color; x.Material = mat; x.Parent = m
			return x
		end
		local box = sp("Box", Vector3.new(3.6, 2.4, 2.4), CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(110, 76, 48), Enum.Material.WoodPlanks)
		sp("Lid", Vector3.new(3.7, 0.6, 2.5), box.CFrame * CFrame.new(0, 1.5, 0), Color3.fromRGB(96, 66, 42), Enum.Material.WoodPlanks)
		for _, x in ipairs({ -1.2, 1.2 }) do sp("Band", Vector3.new(0.25, 3.2, 2.55), box.CFrame * CFrame.new(x, 0.3, 0), Color3.fromRGB(80, 82, 90), Enum.Material.Metal) end
		sp("Lock", Vector3.new(0.5, 0.6, 0.2), box.CFrame * CFrame.new(0, 0.9, 1.3), Color3.fromRGB(210, 170, 70), Enum.Material.Metal)
		m.PrimaryPart = box
		local spr = Instance.new("ProximityPrompt")
		spr.ActionText = "Open"; spr.ObjectText = "Storage"; spr.HoldDuration = 0; spr.MaxActivationDistance = 10; spr.RequiresLineOfSight = false
		spr:SetAttribute("Key", "stash"); spr:SetAttribute("Obj", "stash")
		spr.Parent = box
		m.Parent = camp
	end
end

buildStall()

-- ---------------------------------------------------------------- cabins (forest + hills)
local cabins = Instance.new("Folder"); cabins.Name = "Cabins"; cabins.Parent = workspace
local function crate(parent, cf, kind)
	local m = Instance.new("Model"); m.Name = "LootCrate"
	local box = part(m, "Box", Vector3.new(3, 2.2, 2.2), cf * CFrame.new(0, 1.1, 0), Color3.fromRGB(150, 108, 66), Enum.Material.WoodPlanks, nil, true)
	part(m, "Band", Vector3.new(3.05, 0.3, 2.25), cf * CFrame.new(0, 1.4, 0), Color3.fromRGB(90, 90, 96), Enum.Material.Metal, nil, false)
	part(m, "Lid", Vector3.new(3.1, 0.4, 2.3), cf * CFrame.new(0, 2.4, 0), Color3.fromRGB(130, 92, 56), Enum.Material.WoodPlanks, nil, true)
	m.PrimaryPart = box
	local p = Instance.new("ProximityPrompt"); p.ActionText = "Search"; p.ObjectText = "Crate"; p.HoldDuration = 0.8; p.MaxActivationDistance = 9; p.RequiresLineOfSight = false
	p:SetAttribute("Key", "search"); p:SetAttribute("Obj", "crate"); p.Parent = box
	m:SetAttribute("Crate", kind)
	m.Parent = parent
	return m
end
local function cabin(x, z, rot)
	local g = ground(x, z)
	local m = Instance.new("Model"); m.Name = "Cabin"
	local base = CFrame.new(x, g, z) * CFrame.Angles(0, rot, 0)
	local logC = { Color3.fromRGB(128, 90, 58), Color3.fromRGB(116, 82, 54), Color3.fromRGB(138, 98, 64) }
	local W, D, LOG, ROWS = 14, 12, 1.1, 7
	local function log(len, cf)
		return part(m, "Log", Vector3.new(len, LOG, LOG), base * cf, logC[rng:NextInteger(1, 3)], Enum.Material.Wood, CYL, true)
	end
	part(m, "Floor", Vector3.new(W, 0.5, D), base * CFrame.new(0, 0.3, 0), Color3.fromRGB(96, 70, 48), Enum.Material.WoodPlanks, nil, true)
	part(m, "Step", Vector3.new(4, 0.5, 2), base * CFrame.new(0, 0.1, D / 2 + 1.4), Color3.fromRGB(96, 70, 48), Enum.Material.WoodPlanks, nil, true)
	for i = 0, ROWS - 1 do
		local yb = 0.55 + i * LOG + 0.5
		-- back wall
		log(W + 1.2, CFrame.new(0, yb, -D / 2))
		-- front wall with a door gap (rows 0..5)
		if i <= 5 then
			log(W / 2 - 1.6, CFrame.new(-(W / 4 + 1.0), yb, D / 2))
			log(W / 2 - 1.6, CFrame.new(W / 4 + 1.0, yb, D / 2))
		else
			log(W + 1.2, CFrame.new(0, yb, D / 2))
		end
		-- side walls (along Z) with windows on rows 2..4
		for _, sx in ipairs({ -1, 1 }) do
			local ys = yb + LOG / 2
			if i >= 2 and i <= 4 then
				log(D / 2 - 1.4, CFrame.new(sx * W / 2, ys, -(D / 4 + 0.9)) * CFrame.Angles(0, math.rad(90), 0))
				log(D / 2 - 1.4, CFrame.new(sx * W / 2, ys, D / 4 + 0.9) * CFrame.Angles(0, math.rad(90), 0))
			else
				log(D + 1.2, CFrame.new(sx * W / 2, ys, 0) * CFrame.Angles(0, math.rad(90), 0))
			end
		end
	end
	local wallTop = 0.55 + ROWS * LOG + 0.5
	-- windows
	for _, sx in ipairs({ -1, 1 }) do
		local glass = part(m, "Glass", Vector3.new(0.2, 3.2, 2.6), base * CFrame.new(sx * W / 2, 0.55 + 3.5 * LOG + 0.5, 0), Color3.fromRGB(170, 210, 230), Enum.Material.Glass, nil, true)
		glass.Transparency = 0.55
		part(m, "Frame", Vector3.new(0.3, 0.3, 3), base * CFrame.new(sx * W / 2, 0.55 + 3.5 * LOG + 0.5, 0), Color3.fromRGB(70, 50, 36), Enum.Material.Wood, nil, false)
	end
	-- gables: shorter logs as they rise
	local pitch = math.rad(33)
	local k = 0
	while true do
		local len = D + 1.2 - 2 * (k + 0.5) * LOG / math.tan(pitch)
		if len < 1 then break end
		for _, sx in ipairs({ -1, 1 }) do
			log(len, CFrame.new(sx * W / 2, wallTop + k * LOG + LOG / 2, 0) * CFrame.Angles(0, math.rad(90), 0))
		end
		k += 1
	end
	-- roof: front slab tilts down to +Z, back slab down to -Z
	local half = D / 2 + 0.9
	local slabLen = half / math.cos(pitch) + 0.4
	local rise = (D / 4) * math.tan(pitch)
	local roofC = Color3.fromRGB(70, 52, 40)
	part(m, "Roof", Vector3.new(W + 2.2, 0.6, slabLen), base * CFrame.new(0, wallTop + rise + 0.5, half / 2) * CFrame.Angles(pitch, 0, 0), roofC, Enum.Material.WoodPlanks, nil, true)
	part(m, "Roof", Vector3.new(W + 2.2, 0.6, slabLen), base * CFrame.new(0, wallTop + rise + 0.5, -half / 2) * CFrame.Angles(-pitch, 0, 0), roofC, Enum.Material.WoodPlanks, nil, true)
	part(m, "Ridge", Vector3.new(W + 2.4, 0.7, 0.7), base * CFrame.new(0, wallTop + 2 * rise + 0.8, 0), Color3.fromRGB(58, 42, 32), Enum.Material.Wood, nil, false)
	-- chimney
	part(m, "Chimney", Vector3.new(2, wallTop + 6, 2), base * CFrame.new(W / 2 - 2.2, (wallTop + 6) / 2, -D / 2 + 2.2), Color3.fromRGB(120, 118, 114), Enum.Material.Cobblestone, nil, true)
	-- lantern by the door
	local lamp = part(m, "Lantern", Vector3.new(0.8, 1, 0.8), base * CFrame.new(2.6, 6, D / 2 + 0.9), Color3.fromRGB(255, 200, 120), Enum.Material.Neon, nil, false)
	local l = Instance.new("PointLight"); l.Range = 14; l.Brightness = 1.2; l.Color = Color3.fromRGB(255, 180, 100); l.Parent = lamp
	m.Parent = cabins
	crate(m, base * CFrame.new(-3.5, 0.55, -3) * CFrame.Angles(0, 0.3, 0), "cabin")
	table.insert(zones, { x, z, 17 })
end

local function placeCabins(region, n)
	local placed, tries = 0, 0
	while placed < n and tries < 600 do
		tries += 1
		local x, z = rng:NextNumber(-HALF + 90, HALF - 90), rng:NextNumber(-HALF + 90, HALF - 90)
		if regionAt(x, z) == region then
			local h = ground(x, z)
			local flat = math.abs(ground(x + 7, z) - h) < 1.6 and math.abs(ground(x - 7, z) - h) < 1.6 and math.abs(ground(x, z + 7) - h) < 1.6 and math.abs(ground(x, z - 7) - h) < 1.6
			local apart = (x * x + z * z) > 90 * 90
			for _, zn in ipairs(zones) do if (x - zn[1]) ^ 2 + (z - zn[2]) ^ 2 < 80 ^ 2 then apart = false end end
			if flat and apart and h > WATER + 2 then
				cabin(x, z, rng:NextInteger(0, 3) * math.pi / 2)
				placed += 1
			end
		end
	end
	return placed
end
local nCabins = placeCabins("forest", 10) + placeCabins("hills", 8) + placeCabins("snow", 4) + placeCabins("jungle", 5)

-- ---------------------------------------------------------------- caves carved into steep ground
local caves = Instance.new("Folder"); caves.Name = "Caves"; caves.Parent = workspace
local caveCount = 0
local function carveCave(x, z, dir)
	local floorY = ground(x, z) + 0.5
	for d = -6, 54, 3 do
		local p = Vector3.new(x, 0, z) + dir * d
		workspace.Terrain:FillBall(Vector3.new(p.X, floorY + 4.5 - math.max(0, d) * 0.06, p.Z), 6.5, Enum.Material.Air)
	end
	local c = Vector3.new(x, 0, z) + dir * 62
	local cy = floorY - 1
	workspace.Terrain:FillBall(Vector3.new(c.X, cy + 5, c.Z), 11, Enum.Material.Air)
	workspace.Terrain:FillBlock(CFrame.new(c.X, cy - 3, c.Z), Vector3.new(24, 4, 24), Enum.Material.Rock)
	local m = Instance.new("Model"); m.Name = "Cave"; m.Parent = caves
	local fy = cy - 1
	crate(m, CFrame.new(c + Vector3.new(0, fy, 0) + dir * 6) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0), "cave")
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local pos = c + Vector3.new(math.cos(a) * 8, fy + 1.5, math.sin(a) * 8)
		local cr = part(m, "Crystal", Vector3.new(1.2, 3 + i % 2, 1.2), CFrame.new(pos) * CFrame.Angles(0.3, i, 0.2), Color3.fromRGB(110, 220, 230), Enum.Material.Neon, nil, true)
		local l = Instance.new("PointLight"); l.Range = 14; l.Brightness = 1.3; l.Color = Color3.fromRGB(120, 220, 240); l.Parent = cr
	end
	for i, kind in ipairs({ "gold", "gold", "iron", "diamond" }) do
		local a = i / 4 * math.pi * 2 + 0.4
		oreNode(kind, c.X + math.cos(a) * 5, c.Z + math.sin(a) * 5, fy)
	end
	m:SetAttribute("Entry", Vector3.new(x, floorY, z))
	table.insert(zones, { x, z, 16 })
	caveCount += 1
end
local function findCaves(region, n)
	local made, tries = 0, 0
	while made < n and tries < 900 do
		tries += 1
		local x, z = rng:NextNumber(-HALF + 120, HALF - 120), rng:NextNumber(-HALF + 120, HALF - 120)
		if regionAt(x, z) == region then
			local h0 = ground(x, z)
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local ahead = ground(x + dir.X * 62, z + dir.Z * 62)
				local mid = ground(x + dir.X * 30, z + dir.Z * 30)
				if h0 > WATER + 2 and ahead - h0 > 30 and mid - h0 > 14 then
					local far = true
					for _, zn in ipairs(zones) do if (x - zn[1]) ^ 2 + (z - zn[2]) ^ 2 < 120 ^ 2 then far = false end end
					if far then
						carveCave(x, z, dir)
						made += 1
						break
					end
				end
			end
		end
	end
	return made
end

-- ---------------------------------------------------------------- outposts: trader + fire + storage in each region
local outposts = Instance.new("Folder"); outposts.Name = "Outposts"; outposts.Parent = workspace
local function newRig(look)
	local ok, rig = pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then return nil end
	for _, d in ipairs(rig:GetDescendants()) do if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end end
	rig:FindFirstChildOfClass("Humanoid").DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rig.HumanoidRootPart.Anchored = true
	return rig, look
end
local function outpost(shop, x, z, label, shelf, look, groundMat)
	local h = ground(x, z)
	workspace.Terrain:FillBlock(CFrame.new(x, h - 5, z), Vector3.new(56, 10, 48), groundMat)
	workspace.Terrain:FillBlock(CFrame.new(x, h + 25, z), Vector3.new(56, 40, 48), Enum.Material.Air)
	local g0 = h
	local m = Instance.new("Model"); m.Name = "Outpost_" .. shop; m.Parent = outposts
	local base = CFrame.new(x, g0, z)
	local wood, dark, roofC = Color3.fromRGB(128, 90, 58), Color3.fromRGB(86, 60, 40), Color3.fromRGB(150, 62, 48)
	if shop == "snow" then roofC = Color3.fromRGB(230, 236, 245) elseif shop == "desert" then roofC = Color3.fromRGB(210, 150, 80) end
	local function p(name, size, cf, color, mat, shape, collide) return part(m, name, size, cf, color, mat or Enum.Material.WoodPlanks, shape, collide ~= false) end
	p("Floor", Vector3.new(20, 0.8, 12), base * CFrame.new(0, 0.4, -1), dark)
	p("Wall", Vector3.new(20, 10, 0.8), base * CFrame.new(0, 5.4, -6.6), wood)
	for _, sx in ipairs({ -9.6, 9.6 }) do
		p("Wall", Vector3.new(0.8, 10, 12), base * CFrame.new(sx, 5.4, -1), wood)
		p("Post", Vector3.new(1, 11, 1), base * CFrame.new(sx, 5.9, 5), dark, Enum.Material.Wood)
	end
	p("Roof", Vector3.new(22, 0.7, 14.5), base * CFrame.new(0, 11.4, -0.6) * CFrame.Angles(math.rad(-10), 0, 0), roofC, shop == "snow" and Enum.Material.Snow or Enum.Material.Wood)
	local counter = p("Counter", Vector3.new(14, 2.6, 2.2), base * CFrame.new(0, 2.1, 3.2), wood)
	p("CounterTop", Vector3.new(14.6, 0.35, 2.6), base * CFrame.new(0, 3.55, 3.2), dark)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Shop"; pr.ObjectText = "Trader"; pr.HoldDuration = 0; pr.MaxActivationDistance = 12; pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "trade"); pr:SetAttribute("Shop", shop)
	pr.Parent = counter
	for row = 1, 2 do
		local y = 2.6 + row * 2.6
		p("Shelf", Vector3.new(16, 0.3, 1.6), base * CFrame.new(0, y, -5.6), dark)
		for i, id in ipairs(shelf[row] or {}) do
			local it = Items.model(id)
			if it then
				for _, d in ipairs(it:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end end
				local isArmor = Items.get(id).kind == "armor"
				it:PivotTo(base * CFrame.new(-6 + (i - 1) * 4, y + (isArmor and 0.9 or 1.1), -5.6) * (isArmor and CFrame.new() or CFrame.Angles(0, math.rad(90), math.rad(-70))))
				it.Parent = m
			end
		end
	end
	for _, sx in ipairs({ -7, 7 }) do
		local lamp = p("Lantern", Vector3.new(0.9, 1.2, 0.9), base * CFrame.new(sx, 8.4, 5.2), Color3.fromRGB(255, 205, 120), Enum.Material.Neon, nil, false)
		local l = Instance.new("PointLight"); l.Range = 16; l.Brightness = 1.4; l.Color = Color3.fromRGB(255, 185, 110); l.Parent = lamp
	end
	local sign = p("Sign", Vector3.new(10, 2.2, 0.4), CFrame.lookAt((base * CFrame.new(0, 12.9, 6.6)).Position, (base * CFrame.new(0, 12.9, 20)).Position), dark, Enum.Material.Wood)
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.CanvasSize = Vector2.new(460, 100); sg.Parent = sign
	local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.Text = label; tl.Font = Enum.Font.GothamBold; tl.TextScaled = true; tl.TextColor3 = Color3.fromRGB(255, 210, 110); tl.Parent = sg
	local rig = newRig()
	if rig then
		rig.Name = "Trader"
		local hum = rig:FindFirstChildOfClass("Humanoid")
		local hh = hum.HipHeight + rig.HumanoidRootPart.Size.Y / 2
		local pos = (base * CFrame.new(0, 0.8 + hh, 1.0)).Position
		rig:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 10)))
		rig.Parent = m
		Appearance.apply(rig, look)
	end
	-- fire + storage
	local fpos = (base * CFrame.new(-14, 0, 12)).Position
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		p("Stone", Vector3.new(1.3, 0.9, 1.3), CFrame.new(fpos + Vector3.new(math.cos(a) * 2.3, 0.3, math.sin(a) * 2.3)), Color3.fromRGB(120, 120, 126), Enum.Material.Slate, BALL)
	end
	local core = p("CampfireCore", Vector3.new(2.6, 0.6, 2.6), CFrame.new(fpos + Vector3.new(0, 0.3, 0)), Color3.fromRGB(70, 46, 32), Enum.Material.Wood)
	local fire = Instance.new("Fire"); fire.Size = 7; fire.Heat = 9; fire.Parent = core
	local pl = Instance.new("PointLight"); pl.Range = 30; pl.Brightness = 2.2; pl.Color = Color3.fromRGB(255, 160, 80); pl.Parent = core
	local box = p("Box", Vector3.new(3.6, 2.4, 2.4), CFrame.new(fpos + Vector3.new(9, 1.2, -3)), Color3.fromRGB(110, 76, 48))
	p("Lid", Vector3.new(3.7, 0.6, 2.5), box.CFrame * CFrame.new(0, 1.5, 0), Color3.fromRGB(96, 66, 42))
	local spr = Instance.new("ProximityPrompt")
	spr.ActionText = "Open"; spr.ObjectText = "Storage"; spr.HoldDuration = 0; spr.MaxActivationDistance = 10; spr.RequiresLineOfSight = false
	spr:SetAttribute("Key", "stash"); spr:SetAttribute("Obj", "stash")
	spr.Parent = box
	table.insert(zones, { x, z, 34 })
end
-- nearest flat dry spot of a region around (tx, tz)
local function spotNear(tx, tz, region, size)
	for r = 0, 400, 12 do
		for k = 0, math.max(0, math.floor(r / 6)) do
			local a = k / math.max(1, math.floor(r / 6) + 1) * math.pi * 2
			local x, z = tx + math.cos(a) * r, tz + math.sin(a) * r
			if regionAt(x, z) == region then
				local h = ground(x, z)
				local ok = h > WATER + 2.5
				for _, o in ipairs({ { size, 0 }, { -size, 0 }, { 0, size }, { 0, -size } }) do
					if math.abs(ground(x + o[1], z + o[2]) - h) > 5 or ground(x + o[1], z + o[2]) < WATER + 1.5 then ok = false end
				end
				if ok then return x, z end
			end
		end
	end
	return tx, tz
end
local function place(shop, tx, tz, region, ...)
	local x, z = spotNear(tx, tz, region, 26)
	outpost(shop, x, z, ...)
end
place("snow", -182, -1034, "snow", "متجر الثلوج | SNOW", { { "spear", "ice_spear", "crossbow" }, { "warm_coat", "iron_armor" } }, { skin = 1, shirt = 3, pants = 2, hat = "beanie", extra = "scarf" }, Enum.Material.Snow)
place("desert", 60, 1000, "desert", "متجر الصحراء | DESERT", { { "scimitar", "rifle", "pistol" }, { "desert_cloak", "iron_armor" } }, { skin = 4, shirt = 4, pants = 5, hat = "cowboy", extra = "belt" }, Enum.Material.Sand)
place("mountains", 900, -120, "mountains", "متجر الجبال | MOUNTAIN", { { "iron_pickaxe", "diamond_pickaxe", "war_hammer" }, { "crossbow", "diamond_armor" } }, { skin = 2, shirt = 6, pants = 3, hat = "helmet", extra = "backpack" }, Enum.Material.Rock)
place("beach", 300, -1330, "beach", "متجر الشاطئ | BEACH", { { "harpoon", "spear", "crossbow" }, { "coconut", "bandage" } }, { skin = 3, shirt = 3, pants = 4, hat = "cap", extra = "none" }, Enum.Material.Sand)
place("jungle", -1000, 260, "jungle", "متجر الأدغال | JUNGLE", { { "machete", "bow" }, { "jungle_vest", "iron_armor" } }, { skin = 5, shirt = 1, pants = 4, hat = "explorer", extra = "backpack" }, Enum.Material.Mud)
place("volcano", 400, 693, "volcano", "متجر البراكين | VOLCANO", { { "magma_blade", "war_hammer", "dynamite" }, { "lava_cloak", "diamond_armor" } }, { skin = 2, shirt = 6, pants = 6, hat = "helmet", extra = "belt" }, Enum.Material.Basalt)
local nCaves = 0 -- caves are made by caves.lua

-- ---------------------------------------------------------------- walls + spawn
local walls = Instance.new("Folder"); walls.Name = "MapWalls"; walls.Parent = workspace
for _, d in ipairs({ { 0, HALF, HALF * 2, 4 }, { 0, -HALF, HALF * 2, 4 }, { HALF, 0, 4, HALF * 2 }, { -HALF, 0, 4, HALF * 2 } }) do
	local w = part(walls, "Wall", Vector3.new(d[3], 500, d[4]), CFrame.new(d[1], 200, d[2]), Color3.new(), Enum.Material.SmoothPlastic, nil, true)
	w.Transparency = 1
end
local sp = Instance.new("SpawnLocation")
sp.Name = "ForestSpawn"; sp.Anchored = true; sp.Size = Vector3.new(8, 1, 8)
sp.Position = Vector3.new(0, ground(0, 0) + 0.5, 0)
sp.Transparency = 1; sp.CanCollide = false; sp.Neutral = true; sp.Duration = 0
sp.Parent = workspace

local ok = pcall(function() game:GetService("AssetService"):SavePlaceAsync() end)
return { saved = ok, cabins = nCabins, caves = nCaves, outposts = #outposts:GetChildren() }
