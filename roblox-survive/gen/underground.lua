-- Furnishes the underground layer carved by terrain.lua: creature spots, ores, crystals, mushrooms, crates,
-- mine rails + carts, ladders, camps, dwarf traders, the ruins and their vault, gas, rock falls, the cave map mask,
-- the cave entrances, and the secret trader's spots. Run after common.lua + part.lua + ore.lua, once the
-- surface structures, villages and camps exist. Replaces the old caves.lua.
local T = workspace.Terrain
local grng = Random.new(31337)
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local UPC = CFrame.Angles(0, 0, math.rad(90))
for _, n in ipairs({ "Caves", "Underground", "UnderCamps", "BlackMarketSpots" }) do
	local o = workspace:FindFirstChild(n)
	if o then o:Destroy() end
end
for _, c in ipairs(workspace.Resources:GetChildren()) do
	if c:GetAttribute("CaveGen") then c:Destroy() end
end
local cavesF = Instance.new("Folder"); cavesF.Name = "Caves"; cavesF.Parent = workspace
local under = Instance.new("Folder"); under.Name = "Underground"; under.Parent = workspace
local tracksF = Instance.new("Folder"); tracksF.Name = "Tracks"; tracksF.Parent = under
local cartsF = Instance.new("Folder"); cartsF.Name = "Minecarts"; cartsF.Parent = under
local decor = Instance.new("Folder"); decor.Name = "Decor"; decor.Parent = under
local gasF = Instance.new("Folder"); gasF.Name = "GasZones"; gasF.Parent = under
local camps = Instance.new("Folder"); camps.Name = "UnderCamps"; camps.Parent = workspace
local spotsBM = Instance.new("Folder"); spotsBM.Name = "BlackMarketSpots"; spotsBM.Parent = workspace

-- floor under a point in a cave (same rule as the server's Ground.floor)
local function floorAt(x, refY, z)
	local vx, vz = math.floor(x / 4) * 4, math.floor(z / 4) * 4
	local top = math.floor((refY + 8) / 4) * 4
	local bottom = top - 56
	local mats, occ = T:ReadVoxels(Region3.new(Vector3.new(vx, bottom, vz), Vector3.new(vx + 4, top, vz + 4)), 4)
	local col, ocol = mats[1], occ[1]
	local airAbove = false
	for iy = #col, 1, -1 do
		local m, o = col[iy][1], ocol[iy][1]
		if m ~= Enum.Material.Air and m ~= Enum.Material.Water and o > 0 then
			local h = bottom + (iy - 1) * 4 + o * 4
			if airAbove and h <= refY + 3.5 then return h, m end
			airAbove = false
		else
			airAbove = true
		end
	end
	return nil
end
local function addSpot(folder, name, cf)
	local p = part(folder, name, Vector3.new(1, 1, 1), cf, Color3.new(1, 0, 1), Enum.Material.SmoothPlastic, nil, false)
	p.Transparency = 1
	return p
end
-- a random floor point inside a cavern (nil if that spot is under water / lava / missing)
local function cavernFloor(c, spread)
	for _ = 1, 12 do
		local a = grng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(grng:NextNumber()) * (spread or 0.7)
		local x, z = c.x + math.cos(a) * c.rx * r, c.z + math.sin(a) * c.rz * r
		local f, m = floorAt(x, c.floor + 6, z)
		if f and m ~= Enum.Material.CrackedLava and (not c.water or f > c.water) then return Vector3.new(x, f, z) end
	end
	return nil
end
local function clearSurface(x, z, r)
	for _, f in ipairs({ workspace:FindFirstChild("Resources"), workspace:FindFirstChild("Decor") }) do
		for _, m in ipairs(f and f:GetChildren() or {}) do
			local ok, pv = pcall(function() return m:GetPivot().Position end)
			if ok and not m:GetAttribute("CaveGen") and Vector3.new(pv.X - x, 0, pv.Z - z).Magnitude < r then m:Destroy() end
		end
	end
end

local GLOW = { snow = Color3.fromRGB(150, 220, 255), volcano = Color3.fromRGB(255, 130, 50), beach = Color3.fromRGB(90, 230, 210),
	jungle = Color3.fromRGB(110, 255, 140), desert = Color3.fromRGB(255, 210, 120) }
local function crystal(parent, p, color, size)
	local cr = part(parent, "Crystal", Vector3.new(0.8, size, 0.8) * (grng:NextNumber(0.8, 1.3)), CFrame.new(p + Vector3.new(0, size * 0.4, 0)) * CFrame.Angles(grng:NextNumber(-0.4, 0.4), grng:NextNumber(0, 6), grng:NextNumber(-0.4, 0.4)), color, Enum.Material.Neon, nil, false)
	cr.Transparency = 0.15
	return cr
end
local function mushroomNode(p, big)
	local node = Instance.new("Model")
	node.Name = "Mushrooms"
	local s = big and 3 or 1
	local stem = part(node, "Stem", Vector3.new(0.35 * s, 1.0 * s, 0.35 * s), CFrame.new(p + Vector3.new(0, 0.5 * s, 0)), Color3.fromRGB(230, 225, 210), Enum.Material.SmoothPlastic, nil, big)
	node.PrimaryPart = stem
	local cap = part(node, "Berry", Vector3.new(1.2 * s, 1.2 * s, 1.2 * s), CFrame.new(p + Vector3.new(0, 1.05 * s, 0)), Color3.fromRGB(80, 210, 230), Enum.Material.Neon, BALL, false)
	local l = Instance.new("PointLight"); l.Range = big and 18 or 7; l.Brightness = big and 1 or 0.6; l.Color = Color3.fromRGB(90, 220, 240); l.Parent = cap
	if not big then
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Pick"; pr.ObjectText = "Mushroom"; pr.HoldDuration = 0.4; pr.MaxActivationDistance = 9; pr.RequiresLineOfSight = false
		pr.Parent = stem
		node:SetAttribute("NodeType", "bush")
		node:SetAttribute("Gives", "mushroom")
		node:SetAttribute("CaveGen", true)
		node.Parent = workspace.Resources
	else
		node.Parent = decor
	end
end
local function crateAt(parent, p, kind)
	local m = Instance.new("Model"); m.Name = "LootCrate"
	local cf = CFrame.new(p) * CFrame.Angles(0, grng:NextNumber(0, 6), 0)
	local box = part(m, "Box", Vector3.new(3, 2.2, 2.2), cf * CFrame.new(0, 1.1, 0), Color3.fromRGB(150, 108, 66), Enum.Material.WoodPlanks, nil, true)
	part(m, "Band", Vector3.new(3.05, 0.3, 2.25), cf * CFrame.new(0, 1.4, 0), Color3.fromRGB(90, 90, 96), Enum.Material.Metal, nil, false)
	part(m, "Lid", Vector3.new(3.1, 0.4, 2.3), cf * CFrame.new(0, 2.4, 0), Color3.fromRGB(130, 92, 56), Enum.Material.WoodPlanks, nil, true)
	m.PrimaryPart = box
	local pr = Instance.new("ProximityPrompt"); pr.ActionText = "Search"; pr.ObjectText = "Crate"; pr.HoldDuration = 0.3; pr.MaxActivationDistance = 9; pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "search"); pr:SetAttribute("Obj", "crate"); pr.Parent = box
	m:SetAttribute("Crate", kind or "cave")
	m.Parent = parent
	return m
end
local function newRig(look)
	local ok, rig = pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then return nil end
	for _, d in ipairs(rig:GetDescendants()) do if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end end
	rig:FindFirstChildOfClass("Humanoid").DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rig.HumanoidRootPart.Anchored = true
	require(game:GetService("ReplicatedStorage").Shared.Appearance).apply(rig, look)
	return rig
end

---------------------------------------------------------------- caverns: creatures, ores, glow, mushrooms, crates
local counts = { caverns = 0, spots = 0, ores = 0, crates = 0, mushrooms = 0 }
for _, c in ipairs(UG.caverns) do
	local center = cavernFloor(c, 0.15) or Vector3.new(c.x, c.floor, c.z)
	local m = Instance.new("Model")
	m.Name = "Cavern_" .. c.id
	m:SetAttribute("Type", "under_" .. c.region)
	m:SetAttribute("Center", center)
	m:SetAttribute("Region", c.region)
	m:SetAttribute("Radius", math.max(c.rx, c.rz))
	if c.tag == "spiderqueen" or c.tag == "giantworm" or c.tag == "mineguardian" or c.tag == "golem" then m:SetAttribute("Boss", c.tag) end
	if c.tag == "rockfall" then m:SetAttribute("Rockfall", true) end
	m.Parent = cavesF
	local spots = Instance.new("Folder"); spots.Name = "Spots"; spots.Parent = m
	for _ = 1, c.grand and 7 or 4 do
		local p = cavernFloor(c, 0.75)
		if p then addSpot(spots, "Spot", CFrame.new(p)) counts.spots += 1 end
	end
	-- ores: deeper caves hold rarer ones
	local depth = -c.floor
	for _ = 1, c.grand and 6 or grng:NextInteger(2, 4) do
		local p = cavernFloor(c, 0.85)
		if p then
			local roll = grng:NextNumber()
			local kind = "iron"
			if depth > 95 and roll < 0.12 then kind = "diamond"
			elseif (c.region == "volcano" or depth > 100) and roll < 0.3 then kind = "obsidian"
			elseif depth > 70 and roll < 0.45 then kind = "gold"
			elseif roll < 0.7 then kind = "crystal" end
			local n = oreNode(kind, p.X, p.Z, p.Y)
			n:SetAttribute("CaveGen", true)
			counts.ores += 1
		end
	end
	-- glowing crystals in the cave's colour
	local glow = GLOW[c.region] or Color3.fromRGB(160, 110, 255)
	for k = 1, c.grand and 10 or 5 do
		local p = cavernFloor(c, 0.95)
		if p then
			local cr = crystal(m, p, glow, grng:NextNumber(1.6, 3.4))
			if k <= 2 then local l = Instance.new("PointLight"); l.Range = 14; l.Brightness = 0.7; l.Color = glow; l.Parent = cr end
		end
	end
	-- mushrooms (a forest of giant glowing ones under the jungle)
	local nm = c.region == "jungle" and 6 or 2
	for k = 1, nm do
		local p = cavernFloor(c, 0.8)
		if p then mushroomNode(p, c.region == "jungle" and k <= 3) counts.mushrooms += 1 end
	end
	if grng:NextNumber() < (c.grand and 0.9 or 0.35) then
		local p = cavernFloor(c, 0.6)
		if p then crateAt(m, p, "cave") counts.crates += 1 end
	end
	-- a wooden scaffold with a ladder and a crate on top, in some big caves
	if c.grand and grng:NextNumber() < 0.5 then
		local p = cavernFloor(c, 0.55)
		if p then
			local hgt = 12
			for _, o in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
				part(m, "Post", Vector3.new(0.8, hgt, 0.8), CFrame.new(p + Vector3.new(o[1], hgt / 2, o[2])), Color3.fromRGB(110, 78, 50), Enum.Material.Wood, nil, true)
			end
			part(m, "Deck", Vector3.new(7.6, 0.6, 7.6), CFrame.new(p + Vector3.new(0, hgt, 0)), Color3.fromRGB(96, 70, 46), Enum.Material.WoodPlanks, nil, true)
			local lad = Instance.new("TrussPart")
			lad.Anchored = true
			lad.Size = Vector3.new(2, hgt, 2)
			lad.CFrame = CFrame.new(p + Vector3.new(0, hgt / 2, 4.8))
			lad.Color = Color3.fromRGB(120, 86, 56)
			lad.Material = Enum.Material.Wood
			lad.Parent = m
			crateAt(m, p + Vector3.new(0, hgt + 0.3, 0), "cave")
		end
	end
	counts.caverns += 1
end

---------------------------------------------------------------- mine lines: rails, supports, lanterns, carts
local lineCount, cartCount, railParts = 0, 0, 0
for li, pts in ipairs(UG.lines) do
	-- rail points on the real floor
	local rail = {}
	for _, p in ipairs(pts) do
		local f = floorAt(p.X, p.Y + 3, p.Z)
		table.insert(rail, Vector3.new(p.X, (f or p.Y) + 0.35, p.Z))
	end
	-- smooth out steps so the cart glides
	for _ = 1, 2 do
		for k = 2, #rail - 1 do
			rail[k] = Vector3.new(rail[k].X, (rail[k - 1].Y + rail[k].Y * 2 + rail[k + 1].Y) / 4, rail[k].Z)
		end
	end
	local model = Instance.new("Model")
	model.Name = "Track_" .. li
	local enc = {}
	for _, p in ipairs(rail) do table.insert(enc, string.format("%.1f,%.1f,%.1f", p.X, p.Y, p.Z)) end
	model:SetAttribute("Points", table.concat(enc, ";"))
	model.Parent = tracksF
	local dist = 0
	for k = 1, #rail - 1 do
		local a, b = rail[k], rail[k + 1]
		local d = b - a
		local len = d.Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		for _, side in ipairs({ -1.3, 1.3 }) do
			part(model, "Rail", Vector3.new(0.22, 0.22, len + 0.1), cf * CFrame.new(side, 0, 0), Color3.fromRGB(110, 112, 118), Enum.Material.Metal, nil, false)
		end
		for t = 0, len, 2.5 do
			part(model, "Tie", Vector3.new(3.6, 0.22, 0.7), CFrame.lookAt(a + d.Unit * t - Vector3.new(0, 0.2, 0), a + d.Unit * (t + 1) - Vector3.new(0, 0.2, 0)), Color3.fromRGB(92, 66, 44), Enum.Material.Wood, nil, false)
		end
		railParts += 1
		-- wooden supports and lanterns along the tunnels (not inside the caverns)
		dist += len
		local inCavern = false
		for _, c in ipairs(UG.caverns) do
			if ((a.X - c.x) / c.rx) ^ 2 + ((a.Z - c.z) / c.rz) ^ 2 < 0.7 then inCavern = true break end
		end
		if not inCavern and k % 2 == 0 then
			local right = cf.RightVector
			for _, side in ipairs({ -4.8, 4.8 }) do
				part(model, "Post", Vector3.new(0.7, 7.5, 0.7), CFrame.new(a + right * side + Vector3.new(0, 3.5, 0)), Color3.fromRGB(110, 78, 50), Enum.Material.Wood, nil, true)
			end
			part(model, "Beam", Vector3.new(10.4, 0.7, 0.7), CFrame.lookAt(a + Vector3.new(0, 7.3, 0), a + Vector3.new(0, 7.3, 0) + cf.LookVector) , Color3.fromRGB(100, 72, 46), Enum.Material.Wood, nil, false).CFrame = cf - cf.Position + a + Vector3.new(0, 7.3, 0)
			if k % 6 == 0 then
				local lamp = part(model, "Lantern", Vector3.new(0.6, 0.9, 0.6), CFrame.new(a + Vector3.new(0, 6.4, 0)), Color3.fromRGB(255, 200, 120), Enum.Material.Neon, nil, false)
				local l = Instance.new("PointLight"); l.Range = 20; l.Brightness = 1.2; l.Color = Color3.fromRGB(255, 180, 100); l.Parent = lamp
			end
		end
	end
	-- buffers at both ends, and carts at the ends and in the middle
	for _, e in ipairs({ { rail[1], rail[2] }, { rail[#rail], rail[#rail - 1] } }) do
		local cf = CFrame.lookAt(e[1], e[2])
		part(model, "Buffer", Vector3.new(4, 1.6, 0.8), cf * CFrame.new(0, 0.8, 0.6), Color3.fromRGB(150, 40, 36), Enum.Material.Metal, nil, true)
	end
	for _, frac in ipairs({ 0.02, 0.5, 0.98 }) do
		local cart = Instance.new("Model")
		cart.Name = "Minecart"
		cart:SetAttribute("Track", model.Name)
		cart:SetAttribute("Start", frac)
		local body = part(cart, "Body", Vector3.new(3.6, 1.8, 4.6), CFrame.new(0, 1.4, 0), Color3.fromRGB(96, 100, 108), Enum.Material.Metal, nil, true)
		cart.PrimaryPart = body
		part(cart, "Rim", Vector3.new(3.8, 0.3, 4.8), CFrame.new(0, 2.4, 0), Color3.fromRGB(70, 74, 80), Enum.Material.Metal, nil, false)
		for _, x in ipairs({ -1.6, 1.6 }) do
			for _, z in ipairs({ -1.5, 1.5 }) do
				part(cart, "Wheel", Vector3.new(0.4, 1.1, 1.1), CFrame.new(x, 0.55, z), Color3.fromRGB(40, 40, 44), Enum.Material.Metal, CYL, false)
			end
		end
		local seat = Instance.new("Seat")
		seat.Name = "Seat"
		seat.Size = Vector3.new(2.4, 0.4, 2.4)
		seat.Anchored = true
		seat.CanCollide = false
		seat.Transparency = 1
		seat.CFrame = CFrame.new(0, 1.6, 0.3)
		seat:SetAttribute("Cart", true)
		seat.Parent = cart
		cart.Parent = cartsF
		cartCount += 1
	end
	lineCount += 1
end

---------------------------------------------------------------- entrances (with a sign and lanterns) and ladder shafts
for k, e in ipairs(UG.entrances) do
	clearSurface(e.x, e.z, 16)
	local m = Instance.new("Model")
	m.Name = "CaveEntrance_" .. k
	m:SetAttribute("Entry", Vector3.new(e.x, e.y, e.z))
	m:SetAttribute("Type", "entrance")
	m.Parent = cavesF
	local d = Vector3.new(e.cavern.x - e.x, 0, e.cavern.z - e.z).Unit
	for _, side in ipairs({ -1, 1 }) do
		local p = Vector3.new(e.x, e.y, e.z) - d * 4 + Vector3.new(-d.Z, 0, d.X) * side * 8
		part(m, "Post", Vector3.new(0.8, 6, 0.8), CFrame.new(p + Vector3.new(0, 3, 0)), Color3.fromRGB(110, 78, 50), Enum.Material.Wood, nil, true)
		local lamp = part(m, "Lantern", Vector3.new(0.7, 1, 0.7), CFrame.new(p + Vector3.new(0, 6.5, 0)), Color3.fromRGB(255, 200, 120), Enum.Material.Neon, nil, false)
		local l = Instance.new("PointLight"); l.Range = 18; l.Brightness = 1.2; l.Color = Color3.fromRGB(255, 180, 100); l.Parent = lamp
	end
end
for k, s in ipairs(UG.shafts) do
	clearSurface(s.x, s.z, 8)
	local lad = Instance.new("TrussPart")
	lad.Name = "ShaftLadder"
	lad.Anchored = true
	lad.Size = Vector3.new(2, s.top - s.bottom, 2)
	lad.CFrame = CFrame.new(s.x + s.r - 1.2, (s.top + s.bottom) / 2, s.z)
	lad.Color = Color3.fromRGB(120, 86, 56)
	lad.Material = Enum.Material.Wood
	lad.Parent = decor
	local ring = part(decor, "ShaftRim", Vector3.new(1, s.r * 2 + 2, s.r * 2 + 2), CFrame.new(s.x, s.top - 1.8, s.z) * UPC, Color3.fromRGB(110, 108, 104), Enum.Material.Cobblestone, CYL, false)
	ring.Transparency = 0
	local m = Instance.new("Model")
	m.Name = "Shaft_" .. k
	m:SetAttribute("Entry", Vector3.new(s.x, s.top, s.z))
	m:SetAttribute("Type", "entrance")
	m.Parent = cavesF
end

---------------------------------------------------------------- camps (bed + fire = a respawn point), dwarf traders
local function campAt(c, withDwarf)
	local p = cavernFloor(c, 0.3)
	if not p then return nil end
	local m = Instance.new("Model")
	m.Name = withDwarf and "DwarfHold" or "UnderCamp"
	m:SetAttribute("Center", p)
	m.Parent = camps
	-- fire
	local core = part(m, "CampfireCore", Vector3.new(2.4, 0.6, 2.4), CFrame.new(p + Vector3.new(0, 0.3, 0)), Color3.fromRGB(70, 46, 32), Enum.Material.Wood, nil, true)
	local fire = Instance.new("Fire"); fire.Size = 6; fire.Parent = core
	local pl = Instance.new("PointLight"); pl.Range = 30; pl.Brightness = 2; pl.Color = Color3.fromRGB(255, 160, 80); pl.Parent = core
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part(m, "Stone", Vector3.new(1.2, 0.8, 1.2), CFrame.new(p + Vector3.new(math.cos(a) * 2.2, 0.3, math.sin(a) * 2.2)), Color3.fromRGB(110, 110, 116), Enum.Material.Slate, BALL, true)
	end
	-- a bedroll under a small tent
	local bp = p + Vector3.new(6, 0, 0)
	part(m, "Bed", Vector3.new(3.2, 0.6, 6), CFrame.new(bp + Vector3.new(0, 0.3, 0)), Color3.fromRGB(120, 60, 50), Enum.Material.Fabric, nil, true)
	part(m, "Tent", Vector3.new(6, 0.3, 5), CFrame.new(bp + Vector3.new(-1.6, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(55)), Color3.fromRGB(90, 76, 52), Enum.Material.Fabric, nil, true)
	part(m, "Tent", Vector3.new(6, 0.3, 5), CFrame.new(bp + Vector3.new(1.6, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(-55)), Color3.fromRGB(90, 76, 52), Enum.Material.Fabric, nil, true)
	crateAt(m, p + Vector3.new(-5, 0, 3), "cave")
	if withDwarf then
		local counter = part(m, "Counter", Vector3.new(8, 2.6, 2.2), CFrame.new(p + Vector3.new(0, 1.3, -7)), Color3.fromRGB(110, 80, 52), Enum.Material.WoodPlanks, nil, true)
		part(m, "Anvil", Vector3.new(2.2, 1.2, 1.2), CFrame.new(p + Vector3.new(5.5, 0.6, -7)), Color3.fromRGB(60, 62, 68), Enum.Material.Metal, nil, true)
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Shop"; pr.ObjectText = "Dwarf"; pr.HoldDuration = 0; pr.MaxActivationDistance = 12; pr.RequiresLineOfSight = false
		pr:SetAttribute("Key", "trade"); pr:SetAttribute("Shop", "dwarf")
		pr.Parent = counter
		local rig = newRig({ skin = 2, shirt = 2, pants = 6, hat = "helmet", extra = "belt" })
		if rig then
			rig.Name = "Trader"
			rig:ScaleTo(0.75)
			local hum = rig:FindFirstChildOfClass("Humanoid")
			local hh = hum.HipHeight + rig.HumanoidRootPart.Size.Y / 2
			local pos = p + Vector3.new(0, hh, -9.4)
			rig:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 10)))
			local head = rig:FindFirstChild("Head")
			if head then
				local beard = part(rig, "Beard", Vector3.new(0.9, 1.1, 0.5), head.CFrame * CFrame.new(0, -0.55, -0.4), Color3.fromRGB(200, 120, 60), Enum.Material.Fabric, nil, false)
				local w = Instance.new("WeldConstraint"); w.Part0 = head; w.Part1 = beard; w.Parent = beard
				beard.Anchored = false
			end
			rig.Parent = m
		end
	end
	return m
end
local campsMade = 0
for _, c in ipairs(UG.camps) do if campAt(c, false) then campsMade += 1 end end
for _, c in ipairs(UG.dwarves) do campAt(c, true) end

---------------------------------------------------------------- the ancient ruins and their vault
local ruinsMade = false
if UG.ruins then
	local c = UG.ruins
	local m = Instance.new("Model"); m.Name = "Ruins"; m.Parent = under
	local stone, dark = Color3.fromRGB(150, 140, 120), Color3.fromRGB(110, 102, 88)
	for k = 1, 14 do
		local p = cavernFloor(c, 0.85)
		if p then
			local hgt = grng:NextNumber(4, 16)
			part(m, "Pillar", Vector3.new(2.6, hgt, 2.6), CFrame.new(p + Vector3.new(0, hgt / 2 - 0.5, 0)) * CFrame.Angles(0, grng:NextNumber(0, 6), grng:NextNumber(-0.08, 0.08)), k % 2 == 0 and stone or dark, Enum.Material.Cobblestone, nil, true)
			part(m, "Capital", Vector3.new(3.4, 0.8, 3.4), CFrame.new(p + Vector3.new(0, hgt - 0.2, 0)), stone, Enum.Material.Cobblestone, nil, true)
		end
	end
	for _ = 1, 8 do
		local p = cavernFloor(c, 0.8)
		if p then part(m, "Wall", Vector3.new(grng:NextNumber(6, 12), grng:NextNumber(3, 7), 1.6), CFrame.new(p + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, grng:NextNumber(0, 6), 0), dark, Enum.Material.Cobblestone, nil, true) end
	end
	-- the vault: a stone room with a heavy door (needs an ancient key)
	local p = cavernFloor(c, 0.2)
	if p then
		local base = CFrame.new(p) * CFrame.Angles(0, grng:NextNumber(0, 6), 0)
		local function v(name, size, off, col)
			return part(m, name, size, base * off, col or stone, Enum.Material.Cobblestone, nil, true)
		end
		v("VaultWall", Vector3.new(14, 10, 1.6), CFrame.new(0, 5, -6))
		v("VaultWall", Vector3.new(1.6, 10, 12), CFrame.new(-7, 5, 0))
		v("VaultWall", Vector3.new(1.6, 10, 12), CFrame.new(7, 5, 0))
		v("VaultWall", Vector3.new(5, 10, 1.6), CFrame.new(-4.5, 5, 6))
		v("VaultWall", Vector3.new(5, 10, 1.6), CFrame.new(4.5, 5, 6))
		v("VaultRoof", Vector3.new(15, 1.2, 13.6), CFrame.new(0, 10.4, 0), dark)
		local door = v("VaultDoor", Vector3.new(4, 7.6, 1.2), CFrame.new(0, 3.8, 6), Color3.fromRGB(90, 84, 72))
		part(m, "DoorMark", Vector3.new(1.2, 1.2, 0.2), base * CFrame.new(0, 4.4, 6.65), Color3.fromRGB(230, 190, 90), Enum.Material.Neon, nil, false)
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Unlock"; pr.ObjectText = "Vault"; pr.HoldDuration = 0.8; pr.MaxActivationDistance = 10; pr.RequiresLineOfSight = false
		pr:SetAttribute("Key", "unlock"); pr:SetAttribute("Obj", "vault")
		pr.Parent = door
		crateAt(m, (base * CFrame.new(0, 0, -2.5)).Position, "vault")
		local glow = part(m, "VaultGlow", Vector3.new(0.6, 0.6, 0.6), base * CFrame.new(0, 8, 0), Color3.fromRGB(255, 210, 110), Enum.Material.Neon, BALL, false)
		local l = Instance.new("PointLight"); l.Range = 16; l.Brightness = 1.4; l.Color = Color3.fromRGB(255, 200, 110); l.Parent = glow
		ruinsMade = true
	end
end

---------------------------------------------------------------- poison gas in some tunnels
local gasZones = 0
for _, t in ipairs(UG.tunnels) do
	if t.gas then
		local n = #t.pts
		for k = math.floor(n * 0.35), math.floor(n * 0.65), 3 do
			local p = t.pts[k]
			local z = part(gasF, "Gas", Vector3.new(t.r * 2.2, t.r * 1.6, 8), CFrame.lookAt(p, t.pts[k + 1] or p + Vector3.new(0, 0, 1)), Color3.fromRGB(120, 200, 80), Enum.Material.SmoothPlastic, nil, false)
			z.Transparency = 1
			local pe = Instance.new("ParticleEmitter")
			pe.Color = ColorSequence.new(Color3.fromRGB(140, 210, 90), Color3.fromRGB(90, 150, 60))
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
			pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
			pe.Lifetime = NumberRange.new(3, 5)
			pe.Rate = 6
			pe.Speed = NumberRange.new(0.3, 1)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Parent = z
			gasZones += 1
		end
	end
end

---------------------------------------------------------------- cave map mask (which 32-stud cells are open underground)
local MASKN = 96
local cell = (2 * HALF) / MASKN
local bits = table.create(MASKN * MASKN, "0")
for iz = 0, MASKN - 1 do
	for ix = 0, MASKN - 1 do
		local x, z = -HALF + (ix + 0.5) * cell, -HALF + (iz + 0.5) * cell
		local shapes = UG.column(x, z)
		local open = false
		for _, sh in ipairs(shapes or {}) do
			if sh.cav then
				local c = sh.cav
				if ((x - c.x) / c.rx) ^ 2 + ((z - c.z) / c.rz) ^ 2 < 1 then open = true break end
			else
				local a, b = Vector3.new(sh.a.X, 0, sh.a.Z), Vector3.new(sh.b.X, 0, sh.b.Z)
				local ab = b - a
				local p = Vector3.new(x, 0, z)
				local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
				if (p - (a + ab * t)).Magnitude < sh.r + cell * 0.4 then open = true break end
			end
		end
		if open then bits[iz * MASKN + ix + 1] = "1" end
	end
end
workspace:SetAttribute("CaveMask", table.concat(bits))
workspace:SetAttribute("CaveMaskN", MASKN)

---------------------------------------------------------------- secret trader spots: some deep caves and hidden places on the surface
for _, c in ipairs(UG.caverns) do
	if not c.tag and not c.lake and grng:NextNumber() < 0.05 then
		local p = cavernFloor(c, 0.4)
		if p then addSpot(spotsBM, "Cave_" .. c.id, CFrame.new(p) * CFrame.Angles(0, grng:NextNumber(0, 6.28), 0)) end
	end
end
local taken = { { 0, 0, 160 } }
for _, f in ipairs({ "Outposts", "Villages", "BanditCamps" }) do
	for _, m in ipairs(workspace:FindFirstChild(f) and workspace[f]:GetChildren() or {}) do
		local ok, pv = pcall(function() return m:GetAttribute("Center") or m:GetPivot().Position end)
		if ok and pv then table.insert(taken, { pv.X, pv.Z, 110 }) end
	end
end
for _, e in ipairs(UG.entrances) do table.insert(taken, { e.x, e.z, 40 }) end
local surface = 0
for _, region in ipairs({ "forest", "hills", "snow", "desert", "mountains", "jungle", "volcano", "beach", "forest", "jungle", "desert", "hills" }) do
	for _ = 1, 800 do
		local x, z = grng:NextNumber(-HALF + 110, HALF - 110), grng:NextNumber(-HALF + 110, HALF - 110)
		local d = math.max(math.abs(x), math.abs(z))
		local free = true
		for _, t in ipairs(taken) do if (x - t[1]) ^ 2 + (z - t[2]) ^ 2 < t[3] ^ 2 then free = false break end end
		if free and regionAt(x, z) == region and d > 350 then
			local h = ground(x, z)
			local flat = h > WATER + 2
			for _, o in ipairs({ { 6, 0 }, { -6, 0 }, { 0, 6 }, { 0, -6 } }) do
				if math.abs(ground(x + o[1], z + o[2]) - h) > 1.6 then flat = false end
			end
			if flat then
				clearSurface(x, z, 9)
				addSpot(spotsBM, "Surface_" .. region, CFrame.new(x, h, z) * CFrame.Angles(0, grng:NextNumber(0, 6.28), 0))
				table.insert(taken, { x, z, 60 })
				surface += 1
				break
			end
		end
	end
end

local ok = pcall(function() game:GetService("AssetService"):SavePlaceAsync() end)
counts.saved = ok
counts.lines, counts.carts, counts.camps, counts.ruins, counts.gas = lineCount, cartCount, campsMade, ruinsMade, gasZones
counts.entrances, counts.shafts, counts.blackSpots = #UG.entrances, #UG.shafts, #spotsBM:GetChildren()
return counts
