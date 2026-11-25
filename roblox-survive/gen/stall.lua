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
