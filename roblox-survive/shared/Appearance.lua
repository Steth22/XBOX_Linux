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

-- Worn armor (nil / false removes it). `style` comes from the item id:
-- leather (straps and pads), plate (iron: shaped plates, pauldrons, greaves), crystal (diamond: plates with glowing edges),
-- cloak (warm coat / desert cloak / lava cloak: long coat, cape, folded hood), vest (jungle vest with pockets).
local STYLE_OF = {
	leather_armor = "leather", iron_armor = "plate", diamond_armor = "crystal",
	warm_coat = "cloak", desert_cloak = "cloak", lava_cloak = "cloak", jungle_vest = "vest",
}
function A.armor(char, color, material, id)
	local old = char:FindFirstChild("Armor")
	if old then old:Destroy() end
	if not color then return end
	local style = STYLE_OF[id or ""] or (material == Enum.Material.Glass and "crystal") or (material == Enum.Material.Metal and "plate") or "leather"
	local f = Instance.new("Folder")
	f.Name = "Armor"
	f.Parent = char
	local function get(n) local p = char:FindFirstChild(n); return (p and p:IsA("BasePart")) and p or nil end
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.25)
	local light = color:Lerp(Color3.new(1, 1, 1), 0.25)
	local strap = Color3.fromRGB(70, 48, 32)
	local gold = Color3.fromRGB(214, 176, 90)
	local glow = color:Lerp(Color3.new(1, 1, 1), 0.5)
	local mat = material
	local trim = (id == "lava_cloak" and Color3.fromRGB(255, 120, 40)) or (id == "warm_coat" and Color3.fromRGB(240, 236, 228)) or (id == "desert_cloak" and Color3.fromRGB(180, 70, 50)) or gold
	local ut, lt = get("UpperTorso") or get("Torso"), get("LowerTorso")
	local function each(fn)
		for _, side in ipairs({ "Left", "Right" }) do fn(side, side == "Left" and -1 or 1) end
	end

	if style == "plate" or style == "crystal" then
		-- metal plates over the clothes: chest, layered shoulders, bracers, greaves. The trousers stay visible.
		local edge = style == "crystal" and Enum.Material.Neon or Enum.Material.Metal
		local edgeC = style == "crystal" and color:Lerp(Color3.new(1, 1, 1), 0.55) or Color3.fromRGB(70, 72, 78)
		local plateMat = Enum.Material.Metal
		local shade = color:Lerp(Color3.new(0, 0, 0), 0.35)
		if ut then
			local s = ut.Size
			addVis(f, ut, Vector3.new(s.X * 1.02, s.Y * 0.82, s.Z * 1.22), CFrame.new(0, s.Y * 0.08, 0), shade, nil, plateMat) -- under plate
			addVis(f, ut, Vector3.new(s.X * 0.9, s.Y * 0.62, 0.3), CFrame.new(0, s.Y * 0.14, -s.Z * 0.6), color, nil, plateMat) -- breastplate
			addVis(f, ut, Vector3.new(s.X * 0.62, s.Y * 0.34, 0.12), CFrame.new(0, s.Y * 0.22, -s.Z * 0.78), light, nil, plateMat)
			addVis(f, ut, Vector3.new(0.12, s.Y * 0.62, 0.36), CFrame.new(0, s.Y * 0.14, -s.Z * 0.64), edgeC, nil, edge)
			addVis(f, ut, Vector3.new(s.X * 0.9, s.Y * 0.62, 0.3), CFrame.new(0, s.Y * 0.14, s.Z * 0.6), color, nil, plateMat) -- backplate
			addVis(f, ut, Vector3.new(0.26, s.X * 0.62, s.Z * 1.1), CFrame.new(0, s.Y * 0.47, 0) * CFrame.Angles(0, 0, math.rad(90)), shade, CYLS, plateMat) -- gorget
			for _, x in ipairs({ -1, 1 }) do
				addVis(f, ut, Vector3.new(0.18, 0.18, 0.18), CFrame.new(x * s.X * 0.38, s.Y * 0.38, -s.Z * 0.76), gold, BALLS, Enum.Material.Metal)
				addVis(f, ut, Vector3.new(0.18, 0.18, 0.18), CFrame.new(x * s.X * 0.38, -s.Y * 0.08, -s.Z * 0.76), gold, BALLS, Enum.Material.Metal)
			end
		end
		each(function(side, x)
			local ua, la = get(side .. "UpperArm") or get(side .. " Arm"), get(side .. "LowerArm")
			if ua then
				local s = ua.Size
				-- two stacked shoulder plates, close to the arm
				addVis(f, ua, Vector3.new(s.X * 1.42, s.Y * 0.3, s.Z * 1.42), CFrame.new(x * s.X * 0.1, s.Y * 0.36, 0) * CFrame.Angles(0, 0, math.rad(-x * 14)), color, nil, plateMat)
				addVis(f, ua, Vector3.new(s.X * 1.3, s.Y * 0.24, s.Z * 1.3), CFrame.new(x * s.X * 0.12, s.Y * 0.14, 0) * CFrame.Angles(0, 0, math.rad(-x * 10)), shade, nil, plateMat)
				addVis(f, ua, Vector3.new(s.X * 1.46, 0.1, s.Z * 1.46), CFrame.new(x * s.X * 0.1, s.Y * 0.52, 0) * CFrame.Angles(0, 0, math.rad(-x * 14)), edgeC, nil, edge)
			end
			if la then
				local s = la.Size
				addVis(f, la, Vector3.new(s.X * 1.18, s.Y * 0.55, s.Z * 1.18), CFrame.new(0, s.Y * 0.05, 0), color, nil, plateMat) -- bracer
				addVis(f, la, Vector3.new(s.X * 1.22, 0.1, s.Z * 1.22), CFrame.new(0, s.Y * 0.33, 0), edgeC, nil, edge)
			end
			local ll = get(side .. "LowerLeg") or get(side .. " Leg")
			if ll then
				local s = ll.Size
				addVis(f, ll, Vector3.new(s.X * 1.12, s.Y * 0.55, s.Z * 0.5), CFrame.new(0, -s.Y * 0.1, -s.Z * 0.32), color, nil, plateMat) -- shin plate (front only)
				addVis(f, ll, Vector3.new(s.X * 0.8, s.X * 0.75, s.X * 0.5), CFrame.new(0, s.Y * 0.36, -s.Z * 0.48), light, BALLS, plateMat) -- knee
				addVis(f, ll, Vector3.new(0.1, s.Y * 0.5, 0.14), CFrame.new(0, -s.Y * 0.1, -s.Z * 0.58), edgeC, nil, edge)
			end
		end)
		if lt then
			local s = lt.Size
			addVis(f, lt, Vector3.new(s.X * 1.1, s.Y * 0.32, s.Z * 1.28), CFrame.new(0, s.Y * 0.22, 0), strap, nil, Enum.Material.Fabric) -- belt
			addVis(f, lt, Vector3.new(0.46, 0.38, 0.14), CFrame.new(0, s.Y * 0.22, -s.Z * 0.66), gold, nil, Enum.Material.Metal)
			for _, x in ipairs({ -1, 1 }) do
				addVis(f, lt, Vector3.new(s.X * 0.38, s.Y * 0.7, 0.14), CFrame.new(x * s.X * 0.27, -s.Y * 0.28, -s.Z * 0.62) * CFrame.Angles(math.rad(-8), 0, 0), color, nil, plateMat) -- tassets
			end
		end
	elseif style == "leather" then
		if ut then
			local s = ut.Size
			addVis(f, ut, Vector3.new(s.X * 1.04, s.Y * 0.92, s.Z * 1.22), CFrame.new(0, -s.Y * 0.02, 0), color, nil, Enum.Material.Fabric)
			for _, a in ipairs({ 35, -35 }) do
				addVis(f, ut, Vector3.new(0.32, s.Y * 1.15, 0.12), CFrame.new(0, 0, -s.Z * 0.64) * CFrame.Angles(0, 0, math.rad(a)), strap, nil, Enum.Material.Fabric)
			end
			addVis(f, ut, Vector3.new(0.4, 0.4, 0.14), CFrame.new(0, 0, -s.Z * 0.7), gold, BALLS, Enum.Material.Metal)
			addVis(f, ut, Vector3.new(s.X * 0.7, s.Y * 0.5, s.Z * 0.6), CFrame.new(0, -s.Y * 0.02, s.Z * 0.82), dark, nil, Enum.Material.Fabric) -- pack
		end
		each(function(side, x)
			local ua, la, ll = get(side .. "UpperArm") or get(side .. " Arm"), get(side .. "LowerArm"), get(side .. "LowerLeg") or get(side .. " Leg")
			if ua then local s = ua.Size addVis(f, ua, Vector3.new(s.X * 1.5, s.Y * 0.38, s.Z * 1.5), CFrame.new(x * s.X * 0.08, s.Y * 0.32, 0), dark, nil, Enum.Material.Fabric) end
			if la then
				local s = la.Size
				addVis(f, la, Vector3.new(s.X * 1.22, s.Y * 0.6, s.Z * 1.22), CFrame.new(0, -s.Y * 0.08, 0), color, nil, Enum.Material.Fabric)
				for i = 0, 1 do addVis(f, la, Vector3.new(s.X * 1.26, 0.12, s.Z * 1.26), CFrame.new(0, -s.Y * (0.2 - i * 0.3), 0), strap, nil, Enum.Material.Fabric) end
			end
			if ll then
				local s = ll.Size
				addVis(f, ll, Vector3.new(s.X * 1.2, s.Y * 0.62, s.Z * 1.24), CFrame.new(0, -s.Y * 0.16, 0), dark, nil, Enum.Material.Fabric) -- boots
				addVis(f, ll, Vector3.new(s.X * 0.95, s.Y * 0.3, 0.2), CFrame.new(0, s.Y * 0.36, -s.Z * 0.58), color, nil, Enum.Material.Fabric) -- knee pad
			end
		end)
		if lt then
			local s = lt.Size
			addVis(f, lt, Vector3.new(s.X * 1.12, s.Y * 0.34, s.Z * 1.3), CFrame.new(0, s.Y * 0.18, 0), strap, nil, Enum.Material.Fabric)
			addVis(f, lt, Vector3.new(0.7, 0.6, 0.4), CFrame.new(s.X * 0.38, -s.Y * 0.05, -s.Z * 0.5), dark, nil, Enum.Material.Fabric) -- pouch
		end
	elseif style == "cloak" then
		if ut then
			local s = ut.Size
			addVis(f, ut, Vector3.new(s.X * 1.08, s.Y * 1.0, s.Z * 1.28), CFrame.new(0, 0, 0), color, nil, Enum.Material.Fabric)
			addVis(f, ut, Vector3.new(s.X * 1.25, s.Y * 0.28, s.Z * 1.45), CFrame.new(0, s.Y * 0.46, 0), trim, nil, Enum.Material.Fabric) -- collar
			addVis(f, ut, Vector3.new(s.X * 0.95, s.Y * 0.6, s.Z * 0.7), CFrame.new(0, s.Y * 0.38, s.Z * 0.72), dark, BALLS, Enum.Material.Fabric) -- folded hood
			addVis(f, ut, Vector3.new(s.X * 1.18, s.Y * 2.6, 0.14), CFrame.new(0, -s.Y * 0.85, s.Z * 0.74) * CFrame.Angles(math.rad(6), 0, 0), color:Lerp(Color3.new(0, 0, 0), 0.12), nil, Enum.Material.Fabric) -- cape
			addVis(f, ut, Vector3.new(s.X * 1.2, 0.16, 0.18), CFrame.new(0, -s.Y * 2.1, s.Z * 0.86) * CFrame.Angles(math.rad(6), 0, 0), trim, nil, id == "lava_cloak" and Enum.Material.Neon or Enum.Material.Fabric)
			addVis(f, ut, Vector3.new(0.16, s.Y * 0.95, 0.16), CFrame.new(0, 0, -s.Z * 0.66), trim, nil, id == "lava_cloak" and Enum.Material.Neon or Enum.Material.Fabric) -- front seam
		end
		each(function(side, x)
			local ua, la = get(side .. "UpperArm") or get(side .. " Arm"), get(side .. "LowerArm")
			if ua then local s = ua.Size addVis(f, ua, Vector3.new(s.X * 1.25, s.Y * 1.0, s.Z * 1.25), CFrame.new(0, 0, 0), color, nil, Enum.Material.Fabric) end
			if la then
				local s = la.Size
				addVis(f, la, Vector3.new(s.X * 1.25, s.Y * 0.9, s.Z * 1.25), CFrame.new(0, 0, 0), color, nil, Enum.Material.Fabric)
				addVis(f, la, Vector3.new(s.X * 1.4, s.Y * 0.2, s.Z * 1.4), CFrame.new(0, -s.Y * 0.38, 0), trim, nil, Enum.Material.Fabric) -- cuff
			end
		end)
		if lt then
			local s = lt.Size
			addVis(f, lt, Vector3.new(s.X * 1.16, s.Y * 1.0, s.Z * 1.34), CFrame.new(0, -s.Y * 0.1, 0), color, nil, Enum.Material.Fabric) -- coat skirt
			addVis(f, lt, Vector3.new(s.X * 1.2, s.Y * 0.3, s.Z * 1.38), CFrame.new(0, s.Y * 0.2, 0), strap, nil, Enum.Material.Fabric)
		end
	else -- vest
		if ut then
			local s = ut.Size
			addVis(f, ut, Vector3.new(s.X * 1.05, s.Y * 0.92, s.Z * 1.24), CFrame.new(0, -s.Y * 0.02, 0), color, nil, Enum.Material.Fabric)
			for i, o in ipairs({ { -0.25, 0.1 }, { 0.25, 0.1 }, { -0.25, -0.22 }, { 0.25, -0.22 } }) do
				addVis(f, ut, Vector3.new(s.X * 0.3, s.Y * 0.22, 0.24), CFrame.new(o[1] * s.X, o[2] * s.Y, -s.Z * 0.68), dark, nil, Enum.Material.Fabric) -- pockets
			end
			for i = 1, 5 do
				addVis(f, ut, Vector3.new(s.X * 0.36, s.Y * 0.2, 0.1), CFrame.new(((i % 3) - 1) * s.X * 0.3, (i * 0.17 - 0.5) * s.Y, s.Z * 0.66), color:Lerp(Color3.fromRGB(40, 60, 30), 0.5), BALLS, Enum.Material.Fabric) -- camo
			end
		end
		each(function(side, x)
			local la, ll = get(side .. "LowerArm"), get(side .. "LowerLeg") or get(side .. " Leg")
			if la then local s = la.Size addVis(f, la, Vector3.new(s.X * 1.22, s.Y * 0.5, s.Z * 1.22), CFrame.new(0, -s.Y * 0.15, 0), dark, nil, Enum.Material.Fabric) end
			if ll then local s = ll.Size addVis(f, ll, Vector3.new(s.X * 1.2, s.Y * 0.6, s.Z * 1.24), CFrame.new(0, -s.Y * 0.18, 0), strap, nil, Enum.Material.Fabric) end
		end)
		if lt then
			local s = lt.Size
			addVis(f, lt, Vector3.new(s.X * 1.12, s.Y * 0.34, s.Z * 1.3), CFrame.new(0, s.Y * 0.18, 0), strap, nil, Enum.Material.Fabric)
		end
	end
end

-- a deep dark hood and a long cloak (the secret trader)
function A.hood(char)
	local f = char:FindFirstChild("Body")
	local head = char:FindFirstChild("Head")
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local waist = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
	if not f or not head or not torso then return end
	local cloak = Color3.fromRGB(28, 22, 34)
	local d = math.max(head.Size.X, head.Size.Y) * 1.22
	addVis(f, head, Vector3.new(d * 1.25, d * 1.3, d * 1.3), CFrame.new(0, d * 0.12, d * 0.08), cloak, BALLS, Enum.Material.Fabric)
	addVis(f, head, Vector3.new(d * 1.0, d * 0.9, 0.12), CFrame.new(0, d * 0.05, -d * 0.52), Color3.fromRGB(8, 6, 10), nil, Enum.Material.Fabric)
	local s = torso.Size
	addVis(f, torso, Vector3.new(s.X * 1.25, s.Y * 1.05, s.Z * 1.3), CFrame.new(0, 0, 0.05), cloak, nil, Enum.Material.Fabric)
	if waist then
		local w = waist.Size
		addVis(f, waist, Vector3.new(w.X * 1.35, w.Y * 3.2, w.Z * 1.45), CFrame.new(0, -w.Y * 1.3, 0.05), cloak, nil, Enum.Material.Fabric)
	end
end

-- a region necklace (nil removes it)
function A.necklace(char, color)
	local old = char:FindFirstChild("Necklace")
	if old then old:Destroy() end
	if not color then return end
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not torso then return end
	local f = Instance.new("Folder")
	f.Name = "Necklace"
	f.Parent = char
	local s = torso.Size
	addVis(f, torso, Vector3.new(0.14, s.Z * 1.12, s.Z * 1.12), CFrame.new(0, s.Y * 0.46, 0) * UP, Color3.fromRGB(220, 190, 110), CYLS, Enum.Material.Metal)
	addVis(f, torso, Vector3.new(0.5, 0.62, 0.18), CFrame.new(0, s.Y * 0.2, -s.Z * 0.56) * CFrame.Angles(0, 0, math.rad(45)), color, nil, Enum.Material.Neon)
	addVis(f, torso, Vector3.new(0.66, 0.78, 0.12), CFrame.new(0, s.Y * 0.2, -s.Z * 0.53) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(220, 190, 110), nil, Enum.Material.Metal)
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
