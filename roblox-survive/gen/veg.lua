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


