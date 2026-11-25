-- Underground caves (normal / long & narrow / wide), their spawn spots, resources,
-- and the places the secret trader can set up. Run after common.lua + part.lua + ore.lua.
local T = workspace.Terrain
local crng = Random.new(777)
local cavesF = workspace:FindFirstChild("Caves") or Instance.new("Folder")
cavesF.Name = "Caves"
cavesF.Parent = workspace
-- a rerun replaces what this script made before
for _, c in ipairs(cavesF:GetChildren()) do
	if c:GetAttribute("Gen") then c:Destroy() end
end
for _, c in ipairs(workspace.Resources:GetChildren()) do
	if c:GetAttribute("CaveGen") then c:Destroy() end
end
local old = workspace:FindFirstChild("BlackMarketSpots")
if old then old:Destroy() end
local spotsBM = Instance.new("Folder")
spotsBM.Name = "BlackMarketSpots"
spotsBM.Parent = workspace

local function addSpot(folder, name, cf)
	local p = part(folder, name, Vector3.new(1, 1, 1), cf, Color3.new(1, 0, 1), Enum.Material.SmoothPlastic, nil, false)
	p.Transparency = 1
	return p
end

-- floor under a point inside a cave (same rule as the server's Ground.floor)
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
			if airAbove and h <= refY + 3.5 then return h end
			airAbove = false
		else
			airAbove = true
		end
	end
	return nil
end

-- places that must stay clear
local zones = { { 0, 0, 90 } }
for _, f in ipairs({ { "Outposts", 80 }, { "Cabins", 40 } }) do
	local folder = workspace:FindFirstChild(f[1])
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			local ok, pv = pcall(function() return m:GetPivot().Position end)
			if ok then table.insert(zones, { pv.X, pv.Z, f[2] }) end
		end
	end
end
for _, m in ipairs(cavesF:GetChildren()) do
	local e = m:GetAttribute("Entry")
	if e then table.insert(zones, { e.X, e.Z, 110 }) end
end
local function clear(x, z, r)
	if math.abs(x) > HALF - 90 or math.abs(z) > HALF - 90 then return false end
	for _, zn in ipairs(zones) do
		if (x - zn[1]) ^ 2 + (z - zn[2]) ^ 2 < (zn[3] + r) ^ 2 then return false end
	end
	return true
end

-- a tube = list of { pos = ball centre, r = radius }. Checks that rock covers it (except near the mouth).
local function valid(tube, mouth)
	-- the sloped mouth may stay open to the sky; once the tunnel is under 8 studs of rock it must stay there
	local covered = false
	for i, b in ipairs(tube) do
		if not clear(b.pos.X, b.pos.Z, 0) then return false end
		if b.pos.Y - b.r < -50 then return false end
		local h = ground(b.pos.X, b.pos.Z)
		if h < WATER + 2 then return false end
		local rock = h - (b.pos.Y + b.r)
		if not covered and rock >= 8 then covered = true end
		if covered and rock < 8 then return false end
		if not covered and i > mouth then return false end
	end
	return covered
end

local function carve(tube)
	-- solid rock shell first (so caves below the old terrain bottom still have walls), then hollow it out
	for _, b in ipairs(tube) do
		if b.pos.Y + b.r + 4 < ground(b.pos.X, b.pos.Z) - 2 then
			T:FillBall(b.pos, b.r + 4, Enum.Material.Rock)
		end
	end
	for _, b in ipairs(tube) do
		T:FillBall(b.pos, b.r, Enum.Material.Air)
		-- the mouth breaks the surface: clear trees / rocks standing in it
		if b.pos.Y + b.r > ground(b.pos.X, b.pos.Z) - 3 then
			for _, f in ipairs({ workspace:FindFirstChild("Resources"), workspace:FindFirstChild("Decor") }) do
				for _, m in ipairs(f and f:GetChildren() or {}) do
					local ok, pv = pcall(function() return m:GetPivot().Position end)
					if ok and Vector3.new(pv.X - b.pos.X, 0, pv.Z - b.pos.Z).Magnitude < b.r + 5 then m:Destroy() end
				end
			end
		end
	end
end

-- walk a winding path from the mouth: descend to `depth` below the entrance, then level out
local function path(x, z, yaw, length, r, depth, wiggle, seed)
	local h0 = ground(x, z)
	local tube = {}
	local p = Vector3.new(x, h0 + r * 0.35, z)
	local target = h0 - depth
	for d = 0, length, 3 do
		table.insert(tube, { pos = p, r = r, d = d })
		yaw += math.noise(d / 40, seed, 3.3) * wiggle
		local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
		local y = math.max(target + r * 0.75, p.Y - 1.4)
		p = Vector3.new(p.X + dir.X * 3, y, p.Z + dir.Z * 3)
	end
	return tube, yaw
end

local function mushroom(m, pos)
	local node = Instance.new("Model")
	node.Name = "Mushrooms"
	for i = 1, 3 do
		local off = Vector3.new(crng:NextNumber(-0.9, 0.9), 0, crng:NextNumber(-0.9, 0.9))
		local hgt = crng:NextNumber(0.6, 1.1)
		local stem = part(node, i == 1 and "Stem" or "Stem2", Vector3.new(0.3, hgt, 0.3), CFrame.new(pos + off + Vector3.new(0, hgt / 2, 0)), Color3.fromRGB(230, 225, 210), Enum.Material.SmoothPlastic, nil, false)
		if i == 1 then node.PrimaryPart = stem end
		local cap = part(node, "Berry", Vector3.new(1.0, 0.45, 1.0), CFrame.new(pos + off + Vector3.new(0, hgt + 0.1, 0)), Color3.fromRGB(80, 210, 230), Enum.Material.Neon, Enum.PartType.Ball, false)
		if i == 1 then
			local l = Instance.new("PointLight")
			l.Range = 7
			l.Brightness = 0.6
			l.Color = Color3.fromRGB(90, 220, 240)
			l.Parent = cap
		end
	end
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Pick"
	pr.ObjectText = "Mushroom"
	pr.HoldDuration = 0.4
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.Parent = node.PrimaryPart
	node:SetAttribute("NodeType", "bush")
	node:SetAttribute("Gives", "mushroom")
	node:SetAttribute("CaveGen", true)
	node.Parent = workspace.Resources
end

local function crate(parent, cf)
	local m = Instance.new("Model"); m.Name = "LootCrate"
	local box = part(m, "Box", Vector3.new(3, 2.2, 2.2), cf * CFrame.new(0, 1.1, 0), Color3.fromRGB(150, 108, 66), Enum.Material.WoodPlanks, nil, true)
	part(m, "Band", Vector3.new(3.05, 0.3, 2.25), cf * CFrame.new(0, 1.4, 0), Color3.fromRGB(90, 90, 96), Enum.Material.Metal, nil, false)
	part(m, "Lid", Vector3.new(3.1, 0.4, 2.3), cf * CFrame.new(0, 2.4, 0), Color3.fromRGB(130, 92, 56), Enum.Material.WoodPlanks, nil, true)
	m.PrimaryPart = box
	local p = Instance.new("ProximityPrompt"); p.ActionText = "Search"; p.ObjectText = "Crate"; p.HoldDuration = 0.8; p.MaxActivationDistance = 9; p.RequiresLineOfSight = false
	p:SetAttribute("Key", "search"); p:SetAttribute("Obj", "crate"); p.Parent = box
	m:SetAttribute("Crate", "cave")
	m.Parent = parent
end

local function ore(kind, pos)
	local n = oreNode(kind, pos.X, pos.Z, pos.Y)
	n:SetAttribute("CaveGen", true)
end

-- a point on the floor next to the tube wall, with the floor height filled in
local function onFloor(b, side, out)
	local dir = Vector3.new(crng:NextNumber(-1, 1), 0, crng:NextNumber(-1, 1))
	if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
	local p = b.pos + dir.Unit * (b.r * (out or 0.5)) * side
	local f = floorAt(p.X, b.pos.Y, p.Z)
	return f and Vector3.new(p.X, f, p.Z)
end

local made = { normal = 0, long = 0, wide = 0 }
local function build(kind, region)
	for _ = 1, 2500 do
		local x, z = crng:NextNumber(-HALF + 100, HALF - 100), crng:NextNumber(-HALF + 100, HALF - 100)
		if regionAt(x, z) == region and clear(x, z, 30) and ground(x, z) > WATER + 4 then
			local yaw = crng:NextNumber(0, math.pi * 2)
			local tube, mouth, hall = nil, 16, {}
			if kind == "long" then
				tube = path(x, z, yaw, 190, 4.4, 24, 0.35, crng:NextNumber(0, 100))
				-- a small hall at the far end (the trader sets up here)
				local e = tube[#tube]
				for _, o in ipairs({ Vector3.new(0, 0, 0), Vector3.new(4, 0, 0), Vector3.new(-4, 0, 0), Vector3.new(0, 0, 4), Vector3.new(0, 0, -4) }) do
					table.insert(hall, { pos = e.pos + o + Vector3.new(0, 3, 0), r = 8.5 })
				end
			elseif kind == "wide" then
				local t2, yaw2 = path(x, z, yaw, 78, 6, 32, 0.1, crng:NextNumber(0, 100))
				tube = t2
				local e = tube[#tube]
				local dir = Vector3.new(math.cos(yaw2), 0, math.sin(yaw2))
				local side = Vector3.new(-dir.Z, 0, dir.X)
				local centre = e.pos + dir * 30 + Vector3.new(0, 7, 0)
				for a = -24, 24, 8 do
					for b = -16, 16, 8 do
						if (a / 24) ^ 2 + (b / 16) ^ 2 <= 1.05 then
							table.insert(hall, { pos = centre + dir * a + side * b, r = 12.5 })
						end
					end
				end
			else
				tube = path(x, z, yaw, 54, 5.5, 16, 0.12, crng:NextNumber(0, 100))
				local e = tube[#tube]
				table.insert(hall, { pos = e.pos + Vector3.new(0, 4, 0), r = 10.5 })
				table.insert(hall, { pos = e.pos + Vector3.new(math.cos(yaw) * 6, 4, math.sin(yaw) * 6), r = 9 })
			end
			local all = {}
			for _, b in ipairs(tube) do table.insert(all, b) end
			for _, b in ipairs(hall) do table.insert(all, b) end
			if valid(all, mouth) then
				carve(all)
				local m = Instance.new("Model")
				m.Name = "Cave_" .. kind
				m:SetAttribute("Gen", true)
				m:SetAttribute("Type", kind)
				m:SetAttribute("Entry", Vector3.new(x, ground(x, z), z))
				m.Parent = cavesF
				local spots = Instance.new("Folder")
				spots.Name = "Spots"
				spots.Parent = m
				-- hall centre on the floor
				local hc = hall[1].pos
				local sumN = 0
				local sum = Vector3.zero
				for _, b in ipairs(hall) do sum += b.pos sumN += 1 end
				hc = sum / sumN
				local hf = floorAt(hc.X, hc.Y, hc.Z) or (hc.Y - 8)
				local centre = Vector3.new(hc.X, hf, hc.Z)
				m:SetAttribute("Center", centre)
				-- along the tunnel: spawn spots, ores, mushrooms, glowing crystals
				for i, b in ipairs(tube) do
					if i > 6 and i % 7 == 0 then
						local f = floorAt(b.pos.X, b.pos.Y, b.pos.Z)
						if f then addSpot(spots, "Spot", CFrame.new(b.pos.X, f, b.pos.Z)) end
					end
					if i > 8 and i % 9 == 4 then
						local p = onFloor(b, crng:NextInteger(0, 1) * 2 - 1, 0.55)
						if p then
							local roll = crng:NextNumber()
							ore(roll < 0.55 and "crystal" or (roll < 0.75 and "iron" or (roll < 0.9 and "gold" or (kind ~= "normal" and "obsidian" or "gold"))), p)
						end
					end
					if i > 5 and i % 11 == 2 then
						local p = onFloor(b, 1, 0.6)
						if p then mushroom(m, p) end
					end
					if i > 4 and i % 6 == 3 then
						local p = onFloor(b, -1, 0.75)
						if p then
							local cr = part(m, "Crystal", Vector3.new(0.7, crng:NextNumber(1.6, 3), 0.7), CFrame.new(p + Vector3.new(0, 0.8, 0)) * CFrame.Angles(crng:NextNumber(-0.4, 0.4), crng:NextNumber(0, 6), crng:NextNumber(-0.4, 0.4)), Color3.fromRGB(150, 100, 255), Enum.Material.Neon, nil, false)
							cr.Transparency = 0.2
						end
					end
				end
				-- the hall
				for k = 1, (kind == "wide" and 8 or 3) do
					local b = hall[crng:NextInteger(1, #hall)]
					local p = onFloor(b, 1, 0.6)
					if p then addSpot(spots, "Spot", CFrame.new(p)) end
				end
				local oreList = kind == "wide" and { "obsidian", "obsidian", "crystal", "crystal", "crystal", "diamond", "gold", "iron" }
					or (kind == "long" and { "crystal", "crystal", "diamond", "obsidian" } or { "crystal", "gold", "iron", "diamond" })
				for _, k in ipairs(oreList) do
					local b = hall[crng:NextInteger(1, #hall)]
					local p = onFloor(b, 1, 0.7)
					if p then ore(k, p) end
				end
				for _ = 1, (kind == "wide" and 4 or 2) do
					local b = hall[crng:NextInteger(1, #hall)]
					local p = onFloor(b, 1, 0.55)
					if p then mushroom(m, p) end
				end
				local cp = onFloor(hall[1], 1, 0.45)
				if cp then crate(m, CFrame.new(cp) * CFrame.Angles(0, crng:NextNumber(0, 6), 0)) end
				if kind == "wide" then
					-- stalagmites
					for _ = 1, 6 do
						local b = hall[crng:NextInteger(1, #hall)]
						local p = onFloor(b, 1, 0.8)
						if p then
							local hgt = crng:NextNumber(4, 9)
							part(m, "Stalagmite", Vector3.new(2.2, hgt, 2.2), CFrame.new(p + Vector3.new(0, hgt / 2 - 0.5, 0)) * CFrame.Angles(0, crng:NextNumber(0, 6), crng:NextNumber(-0.1, 0.1)), Color3.fromRGB(96, 92, 100), Enum.Material.Slate, nil, true)
						end
					end
					local cp2 = onFloor(hall[#hall], 1, 0.4)
					if cp2 then crate(m, CFrame.new(cp2)) end
				end
				-- secret trader spot: end of the long caves and the side of the wide ones (faces the way in)
				if kind == "long" or kind == "wide" then
					local back = tube[#tube - 3].pos
					local at = kind == "long" and centre or (onFloor(hall[#hall], 1, 0.3) or centre)
					addSpot(spotsBM, "Cave_" .. kind, CFrame.lookAt(at, Vector3.new(back.X, at.Y, back.Z)))
				end
				table.insert(zones, { x, z, 140 })
				table.insert(zones, { centre.X, centre.Z, 120 })
				made[kind] += 1
				return true
			end
		end
	end
	return false
end

build("long", "mountains"); build("long", "snow"); build("long", "hills")
build("wide", "mountains"); build("wide", "snow")
build("normal", "forest"); build("normal", "desert"); build("normal", "hills")

-- the old caves: give them a type and spawn spots (their hall is ringed by crystals)
for _, m in ipairs(cavesF:GetChildren()) do
	if not m:GetAttribute("Gen") then
		local sum, n = Vector3.zero, 0
		for _, c in ipairs(m:GetChildren()) do
			if c:IsA("BasePart") and c.Name == "Crystal" then sum += c.Position n += 1 end
		end
		if n > 0 then
			local c = sum / n
			local f = floorAt(c.X, c.Y + 2, c.Z)
			if f then
				m:SetAttribute("Type", "normal")
				m:SetAttribute("Center", Vector3.new(c.X, f, c.Z))
				local spots = m:FindFirstChild("Spots") or Instance.new("Folder")
				spots.Name = "Spots"
				spots.Parent = m
				spots:ClearAllChildren()
				for k = 0, 2 do
					local a = k / 3 * math.pi * 2
					local px, pz = c.X + math.cos(a) * 4, c.Z + math.sin(a) * 4
					local ff = floorAt(px, c.Y + 2, pz)
					if ff then addSpot(spots, "Spot", CFrame.new(px, ff, pz)) end
				end
				-- dim the old bright crystals: caves are meant to be dark
				for _, c2 in ipairs(m:GetDescendants()) do
					if c2:IsA("PointLight") then c2.Range = 9 c2.Brightness = 0.6 end
				end
			end
		end
	end
end

-- hidden surface spots for the secret trader (far from the camp, out of the way)
local surface = 0
for _, region in ipairs({ "forest", "hills", "snow", "desert", "mountains", "forest", "hills", "desert" }) do
	for _ = 1, 800 do
		local x, z = crng:NextNumber(-HALF + 110, HALF - 110), crng:NextNumber(-HALF + 110, HALF - 110)
		local d = math.max(math.abs(x), math.abs(z))
		if regionAt(x, z) == region and d > 220 and clear(x, z, 20) then
			local h = ground(x, z)
			local flat = true
			for _, o in ipairs({ { 6, 0 }, { -6, 0 }, { 0, 6 }, { 0, -6 } }) do
				if math.abs(ground(x + o[1], z + o[2]) - h) > 1.6 then flat = false end
			end
			if flat and h > WATER + 2 then
				-- clear the little camp area
				for _, f in ipairs({ workspace.Resources, workspace:FindFirstChild("Decor") }) do
					for _, m in ipairs(f and f:GetChildren() or {}) do
						local ok, pv = pcall(function() return m:GetPivot().Position end)
						if ok and Vector3.new(pv.X - x, 0, pv.Z - z).Magnitude < 9 then m:Destroy() end
					end
				end
				addSpot(spotsBM, "Surface_" .. region, CFrame.new(x, h, z) * CFrame.Angles(0, crng:NextNumber(0, 6.28), 0))
				table.insert(zones, { x, z, 60 })
				surface += 1
				break
			end
		end
	end
end

local ok = pcall(function() game:GetService("AssetService"):SavePlaceAsync() end)
return { saved = ok, long = made.long, wide = made.wide, normal = made.normal, surfaceSpots = surface, blackSpots = #spotsBM:GetChildren() }
