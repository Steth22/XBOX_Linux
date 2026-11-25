-- Custom player look. Account avatars are never shown: everything is rebuilt from these presets.
local A = {}

A.skins = {
	Color3.fromRGB(255, 224, 189), Color3.fromRGB(241, 194, 155), Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(94, 58, 30),
}
A.shirts = {
	Color3.fromRGB(70, 130, 90), Color3.fromRGB(196, 90, 60), Color3.fromRGB(70, 100, 170), Color3.fromRGB(210, 170, 60),
	Color3.fromRGB(120, 80, 150), Color3.fromRGB(60, 60, 66), Color3.fromRGB(200, 200, 205), Color3.fromRGB(150, 60, 70),
}
A.pants = {
	Color3.fromRGB(80, 66, 50), Color3.fromRGB(50, 60, 90), Color3.fromRGB(60, 60, 66), Color3.fromRGB(95, 110, 70),
	Color3.fromRGB(130, 100, 70), Color3.fromRGB(40, 40, 44),
}
A.hats = { "none", "explorer", "cap", "beanie", "cowboy", "helmet" }
A.extras = { "none", "backpack", "scarf", "belt" }

function A.default()
	return { skin = 2, shirt = 1, pants = 1, hat = "explorer", extra = "backpack" }
end

local function indexOf(list, v)
	for i, x in ipairs(list) do
		if x == v then return i end
	end
	return nil
end

-- Returns a clean, validated look table (used for anything coming from DataStore or the client).
function A.sanitize(a)
	local d = A.default()
	if type(a) ~= "table" then return d end
	local function pick(v, n, fallback)
		v = tonumber(v)
		if v and v >= 1 and v <= n and v == math.floor(v) then return v end
		return fallback
	end
	return {
		skin = pick(a.skin, #A.skins, d.skin),
		shirt = pick(a.shirt, #A.shirts, d.shirt),
		pants = pick(a.pants, #A.pants, d.pants),
		hat = indexOf(A.hats, a.hat) and a.hat or d.hat,
		extra = indexOf(A.extras, a.extra) and a.extra or d.extra,
	}
end

-- Our own faceless body: the Roblox body parts are hidden and replaced by styled shapes
-- welded on top, so animations still work but nothing of the default avatar is visible.
local SHAPES = {
	-- name = { kind, colorKey, sizeFn(partSize) -> size, cfFn(size) -> offset, shape }
}

local function cyl(len, d)
	return Vector3.new(len, d, d)
end

local function addVis(folder, base, size, offset, color, shape, material)
	local p = Instance.new("Part")
	p.Name = "Vis"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.CFrame = base.CFrame * offset
	p.Parent = folder
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = p
	w.Parent = p
	return p
end

local UP = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y

local function buildBody(char, skin, shirt, pants)
	local old = char:FindFirstChild("Body")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Body"
	folder.Parent = char
	local boots = Color3.fromRGB(62, 46, 36)
	local belt = Color3.fromRGB(92, 64, 40)
	local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder

	local function get(n) local p = char:FindFirstChild(n); return (p and p:IsA("BasePart")) and p or nil end
	local function hide(p)
		p.Transparency = 1
		for _, d in ipairs(p:GetChildren()) do
			if d:IsA("Decal") then d:Destroy() end -- no face
		end
	end
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then hide(p) end
	end

	local head = get("Head")
	if head then
		local d = math.max(head.Size.X, head.Size.Y) * 1.22
		addVis(folder, head, Vector3.new(d, d * 1.04, d), CFrame.new(0, 0.05, 0), skin, BALL)
	end
	local ut, lt = get("UpperTorso"), get("LowerTorso")
	if ut then
		local s = ut.Size
		addVis(folder, ut, Vector3.new(s.X * 0.92, s.Y, s.Z * 1.05), CFrame.new(), shirt)
		addVis(folder, ut, Vector3.new(s.Z * 1.0, s.Z * 1.0, s.Z * 1.0), CFrame.new(-s.X * 0.42, s.Y * 0.28, 0), shirt, BALL)
		addVis(folder, ut, Vector3.new(s.Z * 1.0, s.Z * 1.0, s.Z * 1.0), CFrame.new(s.X * 0.42, s.Y * 0.28, 0), shirt, BALL)
		addVis(folder, ut, cyl(0.28, s.Z * 0.95), CFrame.new(0, s.Y * 0.5, 0) * UP, shirt:Lerp(Color3.new(0, 0, 0), 0.25), CYL)
		addVis(folder, ut, cyl(0.5, s.Z * 0.55), CFrame.new(0, s.Y * 0.62, 0) * UP, skin, CYL)
		addVis(folder, ut, Vector3.new(0.1, s.Y * 0.95, 0.06), CFrame.new(0, 0, -s.Z * 0.53), shirt:Lerp(Color3.new(0, 0, 0), 0.4))
		for _, x in ipairs({ -1, 1 }) do
			addVis(folder, ut, Vector3.new(s.X * 0.22, s.Y * 0.22, 0.1), CFrame.new(x * s.X * 0.22, s.Y * 0.12, -s.Z * 0.54), shirt:Lerp(Color3.new(0, 0, 0), 0.18))
		end
	end
	if lt then
		local s = lt.Size
		addVis(folder, lt, Vector3.new(s.X * 0.9, s.Y, s.Z * 1.0), CFrame.new(), pants)
		addVis(folder, lt, Vector3.new(s.X * 0.94, 0.22, s.Z * 1.08), CFrame.new(0, s.Y * 0.4, 0), belt)
		addVis(folder, lt, Vector3.new(0.3, 0.26, 0.1), CFrame.new(0, s.Y * 0.4, -s.Z * 0.56), Color3.fromRGB(200, 170, 80), nil, Enum.Material.Metal)
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local ua, la, hand = get(side .. "UpperArm"), get(side .. "LowerArm"), get(side .. "Hand")
		if ua then addVis(folder, ua, cyl(ua.Size.Y, math.min(ua.Size.X, ua.Size.Z) * 0.95), UP, shirt, CYL) end
		if la then
			addVis(folder, la, cyl(la.Size.Y, math.min(la.Size.X, la.Size.Z) * 0.9), UP, shirt, CYL)
			addVis(folder, la, cyl(0.18, math.min(la.Size.X, la.Size.Z) * 1.0), CFrame.new(0, -la.Size.Y * 0.45, 0) * UP, shirt:Lerp(Color3.new(0, 0, 0), 0.25), CYL)
		end
		if hand then
			local d = math.max(hand.Size.X, hand.Size.Z) * 1.05
			addVis(folder, hand, Vector3.new(d, d, d), CFrame.new(), skin, BALL)
		end
		local ul, ll, foot = get(side .. "UpperLeg"), get(side .. "LowerLeg"), get(side .. "Foot")
		if ul then addVis(folder, ul, cyl(ul.Size.Y, math.min(ul.Size.X, ul.Size.Z) * 0.98), UP, pants, CYL) end
		if ll then addVis(folder, ll, cyl(ll.Size.Y, math.min(ll.Size.X, ll.Size.Z) * 0.92), UP, pants, CYL) end
		if foot then
			local s = foot.Size
			addVis(folder, foot, Vector3.new(s.X * 1.05, s.Y * 1.25, s.Z * 1.1), CFrame.new(0, s.Y * 0.1, 0), boots)
			addVis(folder, foot, Vector3.new(s.X * 1.05, s.X * 1.05, s.X * 1.05), CFrame.new(0, 0, -s.Z * 0.45), boots, BALL)
		end
		-- R6 fallback
		local arm, leg = get(side .. " Arm"), get(side .. " Leg")
		if arm then
			addVis(folder, arm, cyl(arm.Size.Y * 0.8, arm.Size.X * 0.95), CFrame.new(0, arm.Size.Y * 0.1, 0) * UP, shirt, CYL)
			addVis(folder, arm, Vector3.new(arm.Size.X, arm.Size.X, arm.Size.X), CFrame.new(0, -arm.Size.Y * 0.4, 0), skin, BALL)
		end
		if leg then
			addVis(folder, leg, cyl(leg.Size.Y * 0.8, leg.Size.X * 0.95), CFrame.new(0, leg.Size.Y * 0.1, 0) * UP, pants, CYL)
			addVis(folder, leg, Vector3.new(leg.Size.X * 1.05, leg.Size.Y * 0.25, leg.Size.Z * 1.15), CFrame.new(0, -leg.Size.Y * 0.38, -0.1), boots)
		end
	end
	local torso = get("Torso")
	if torso then
		local s = torso.Size
		addVis(folder, torso, Vector3.new(s.X * 0.95, s.Y * 0.7, s.Z * 1.05), CFrame.new(0, s.Y * 0.15, 0), shirt)
		addVis(folder, torso, Vector3.new(s.X * 0.95, s.Y * 0.3, s.Z * 1.0), CFrame.new(0, -s.Y * 0.35, 0), pants)
	end
end

-- Gear (hats / packs) is welded straight onto the body parts, like the body itself:
-- no Accessory objects, so nothing can drift, float or be replaced by account items.
local tan, brown = Color3.fromRGB(196, 160, 104), Color3.fromRGB(120, 84, 52)
local CYLS, BALLS = Enum.PartType.Cylinder, Enum.PartType.Ball
local GEAR = {}
function GEAR.explorer(f, head, d)
	addVis(f, head, Vector3.new(0.14, d * 1.8, d * 1.8), CFrame.new(0, d * 0.3, 0) * UP, tan, CYLS)
	addVis(f, head, Vector3.new(d * 0.5, d * 1.02, d * 1.02), CFrame.new(0, d * 0.52, 0) * UP, tan, CYLS)
	addVis(f, head, Vector3.new(0.14, d * 1.05, d * 1.05), CFrame.new(0, d * 0.36, 0) * UP, brown, CYLS)
end
function GEAR.cap(f, head, d)
	addVis(f, head, Vector3.new(d * 0.42, d * 1.05, d * 1.05), CFrame.new(0, d * 0.36, 0) * UP, Color3.fromRGB(190, 60, 60), CYLS)
	addVis(f, head, Vector3.new(d * 0.72, 0.12, d * 0.5), CFrame.new(0, d * 0.2, -d * 0.6), Color3.fromRGB(150, 45, 45))
end
function GEAR.beanie(f, head, d)
	addVis(f, head, Vector3.new(d * 0.55, d * 1.07, d * 1.07), CFrame.new(0, d * 0.32, 0) * UP, Color3.fromRGB(70, 110, 160), CYLS, Enum.Material.Fabric)
	addVis(f, head, Vector3.new(0.18, d * 1.1, d * 1.1), CFrame.new(0, d * 0.1, 0) * UP, Color3.fromRGB(55, 90, 135), CYLS, Enum.Material.Fabric)
	addVis(f, head, Vector3.new(d * 0.32, d * 0.32, d * 0.32), CFrame.new(0, d * 0.66, 0), Color3.fromRGB(235, 235, 235), BALLS, Enum.Material.Fabric)
end
function GEAR.cowboy(f, head, d)
	addVis(f, head, Vector3.new(0.14, d * 2.15, d * 2.15), CFrame.new(0, d * 0.32, 0) * UP, Color3.fromRGB(140, 95, 55), CYLS)
	addVis(f, head, Vector3.new(d * 0.62, d * 0.98, d * 0.98), CFrame.new(0, d * 0.62, 0) * UP, Color3.fromRGB(125, 82, 48), CYLS)
	addVis(f, head, Vector3.new(0.14, d * 1.0, d * 1.0), CFrame.new(0, d * 0.42, 0) * UP, Color3.fromRGB(60, 40, 28), CYLS)
end
function GEAR.helmet(f, head, d)
	addVis(f, head, Vector3.new(d * 1.1, d * 1.1, d * 1.1), CFrame.new(0, d * 0.16, 0), Color3.fromRGB(120, 126, 136), BALLS, Enum.Material.Metal)
	addVis(f, head, Vector3.new(0.14, d * 1.24, d * 1.24), CFrame.new(0, d * 0.12, 0) * UP, Color3.fromRGB(80, 84, 92), CYLS, Enum.Material.Metal)
end
function GEAR.backpack(f, torso)
	local s = torso.Size
	addVis(f, torso, Vector3.new(s.X * 0.72, s.Y * 0.95, s.Z * 0.75), CFrame.new(0, -s.Y * 0.02, s.Z * 0.85), Color3.fromRGB(112, 82, 56), nil, Enum.Material.Fabric)
	addVis(f, torso, Vector3.new(s.X * 0.74, s.Y * 0.3, s.Z * 0.8), CFrame.new(0, s.Y * 0.3, s.Z * 0.88), Color3.fromRGB(88, 62, 42), nil, Enum.Material.Fabric)
	addVis(f, torso, Vector3.new(s.X * 0.5, s.Y * 0.3, 0.2), CFrame.new(0, -s.Y * 0.2, s.Z * 1.27), Color3.fromRGB(95, 70, 48), nil, Enum.Material.Fabric)
	addVis(f, torso, Vector3.new(s.X * 0.95, s.Z * 0.55, s.Z * 0.55), CFrame.new(0, s.Y * 0.62, s.Z * 0.8), Color3.fromRGB(150, 60, 50), CYLS, Enum.Material.Fabric)
	for _, x in ipairs({ -1, 1 }) do
		addVis(f, torso, Vector3.new(0.22, s.Y * 0.95, 0.12), CFrame.new(x * s.X * 0.24, 0, -s.Z * 0.53), Color3.fromRGB(70, 52, 36), nil, Enum.Material.Fabric)
	end
end
function GEAR.scarf(f, torso)
	local s = torso.Size
	addVis(f, torso, Vector3.new(0.4, s.Z * 1.35, s.Z * 1.35), CFrame.new(0, s.Y * 0.48, 0) * UP, Color3.fromRGB(190, 70, 60), CYLS, Enum.Material.Fabric)
	addVis(f, torso, Vector3.new(0.45, s.Y * 0.55, 0.16), CFrame.new(s.X * 0.18, s.Y * 0.2, -s.Z * 0.62), Color3.fromRGB(170, 60, 52), nil, Enum.Material.Fabric)
end
function GEAR.belt(f, waist)
	local s = waist.Size
	for _, x in ipairs({ -1, 1 }) do
		addVis(f, waist, Vector3.new(s.X * 0.26, s.Y * 0.7, s.Z * 0.45), CFrame.new(x * s.X * 0.42, -s.Y * 0.05, -s.Z * 0.35), Color3.fromRGB(120, 86, 56), nil, Enum.Material.Fabric)
	end
end

-- Worn armor: plates welded over the body (nil / false removes it)
function A.armor(char, color, material)
	local old = char:FindFirstChild("Armor")
	if old then old:Destroy() end
	if not color then return end
	local f = Instance.new("Folder")
	f.Name = "Armor"
	f.Parent = char
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.18)
	local function get(n) local p = char:FindFirstChild(n); return (p and p:IsA("BasePart")) and p or nil end
	local ut = get("UpperTorso") or get("Torso")
	if ut then
		local s = ut.Size
		addVis(f, ut, Vector3.new(s.X * 1.0, s.Y * 0.92, s.Z * 1.22), CFrame.new(0, s.Y * 0.02, -s.Z * 0.02), color, nil, material)
		addVis(f, ut, Vector3.new(s.X * 0.6, s.Y * 0.4, 0.12), CFrame.new(0, s.Y * 0.12, -s.Z * 0.64), dark, nil, material)
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local ua = get(side .. "UpperArm") or get(side .. " Arm")
		if ua then
			local s = ua.Size
			addVis(f, ua, Vector3.new(s.X * 1.45, s.Y * 0.42, s.Z * 1.45), CFrame.new(0, s.Y * 0.3, 0), dark, nil, material)
		end
		local ll = get(side .. "LowerLeg") or get(side .. " Leg")
		if ll then
			local s = ll.Size
			addVis(f, ll, Vector3.new(s.X * 1.2, s.Y * 0.7, s.Z * 1.25), CFrame.new(0, s.Y * 0.05, -s.Z * 0.05), color, nil, material)
		end
	end
end

-- Applies the look to a character (R15 preferred, R6 fallback). Faceless, fully clothed.
function A.apply(char, look)
	look = A.sanitize(look)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Accessory") or c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic")
			or c:IsA("BodyColors") or c:IsA("CharacterMesh") then
			c:Destroy()
		end
	end
	buildBody(char, A.skins[look.skin], A.shirts[look.shirt], A.pants[look.pants])
	local f = char:FindFirstChild("Body")
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local waist = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
	if head and GEAR[look.hat] then
		GEAR[look.hat](f, head, math.max(head.Size.X, head.Size.Y) * 1.22)
	end
	if look.extra == "backpack" and torso then GEAR.backpack(f, torso)
	elseif look.extra == "scarf" and torso then GEAR.scarf(f, torso)
	elseif look.extra == "belt" and waist then GEAR.belt(f, waist) end
end

return A
