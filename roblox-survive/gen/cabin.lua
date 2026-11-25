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
