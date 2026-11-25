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
