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

