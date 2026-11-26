-- Villages (houses, a trader, villagers, guards on towers and at the gates) and bandit camps.
-- Run after common.lua + part.lua, once structures.lua has placed the camp and the outposts.
local Appearance = require(game:GetService("ReplicatedStorage").Shared.Appearance)
local vr = Random.new(4242)
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local UPC = CFrame.Angles(0, 0, math.rad(90))
for _, n in ipairs({ "Villages", "BanditCamps" }) do
	local o = workspace:FindFirstChild(n)
	if o then o:Destroy() end
end
local villagesF = Instance.new("Folder"); villagesF.Name = "Villages"; villagesF.Parent = workspace
local campsF = Instance.new("Folder"); campsF.Name = "BanditCamps"; campsF.Parent = workspace

local taken = { { 0, 0, 160 } }
for _, f in ipairs({ "Outposts", "Cabins" }) do
	local folder = workspace:FindFirstChild(f)
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		local ok, p = pcall(function() return m:GetPivot().Position end)
		if ok then table.insert(taken, { p.X, p.Z, f == "Outposts" and 110 or 50 }) end
	end
end
local function free(x, z, r)
	for _, t in ipairs(taken) do
		if (x - t[1]) ^ 2 + (z - t[2]) ^ 2 < (t[3] + r) ^ 2 then return false end
	end
	return math.abs(x) < HALF - 150 and math.abs(z) < HALF - 150
end
-- a fairly flat, dry, free area of a region near (tx, tz)
local function findArea(tx, tz, region, r, tol)
	for rad = 0, 520, 16 do
		local n = math.max(1, math.floor(rad / 8))
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2
			local x, z = tx + math.cos(a) * rad, tz + math.sin(a) * rad
			if regionAt(x, z) == region and free(x, z, r) then
				local h = ground(x, z)
				local ok = h > WATER + 2.5
				for i = 0, 7 do
					local b = i / 8 * math.pi * 2
					local hh = ground(x + math.cos(b) * r * 0.8, z + math.sin(b) * r * 0.8)
					if math.abs(hh - h) > tol or hh < WATER + 1.5 then ok = false break end
				end
				if ok then return x, z end
			end
		end
	end
	return nil
end

local function newRig(look)
	local ok, rig = pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then return nil end
	for _, d in ipairs(rig:GetDescendants()) do if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rig.HumanoidRootPart.Anchored = true
	Appearance.apply(rig, look)
	return rig
end
local function standAt(rig, pos, lookAt)
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local hh = hum.HipHeight + rig.HumanoidRootPart.Size.Y / 2
	local p = pos + Vector3.new(0, hh, 0)
	rig:PivotTo(CFrame.lookAt(p, Vector3.new(lookAt.X, p.Y, lookAt.Z)))
end
local function randomLook()
	return { skin = vr:NextInteger(1, 6), shirt = vr:NextInteger(1, 8), pants = vr:NextInteger(1, 6), hat = ({ "none", "cap", "beanie", "explorer", "cowboy" })[vr:NextInteger(1, 5)], extra = ({ "none", "scarf", "belt", "backpack" })[vr:NextInteger(1, 4)] }
end

-- ---------------------------------------------------------------- houses (a style per region, every house different)
local STYLE = {
	forest = { walls = { Color3.fromRGB(150, 108, 70), Color3.fromRGB(128, 92, 60), Color3.fromRGB(170, 130, 88) }, roofs = { Color3.fromRGB(120, 52, 40), Color3.fromRGB(70, 60, 56), Color3.fromRGB(96, 70, 44) }, mat = Enum.Material.WoodPlanks, roofMat = Enum.Material.WoodPlanks, kind = "gable", ground = Enum.Material.Ground },
	hills = { walls = { Color3.fromRGB(206, 196, 170), Color3.fromRGB(226, 214, 190), Color3.fromRGB(190, 178, 150) }, roofs = { Color3.fromRGB(70, 90, 120), Color3.fromRGB(150, 70, 56), Color3.fromRGB(90, 96, 100) }, mat = Enum.Material.Plaster, roofMat = Enum.Material.Slate, kind = "gable", ground = Enum.Material.Ground },
	snow = { walls = { Color3.fromRGB(110, 80, 56), Color3.fromRGB(96, 70, 50), Color3.fromRGB(130, 96, 66) }, roofs = { Color3.fromRGB(236, 240, 248) }, mat = Enum.Material.WoodPlanks, roofMat = Enum.Material.Snow, kind = "gable", ground = Enum.Material.Snow },
	desert = { walls = { Color3.fromRGB(214, 180, 128), Color3.fromRGB(226, 196, 150), Color3.fromRGB(196, 160, 112) }, roofs = { Color3.fromRGB(196, 160, 110), Color3.fromRGB(230, 220, 200) }, mat = Enum.Material.Sandstone, roofMat = Enum.Material.Sandstone, kind = "flat", ground = Enum.Material.Sand },
	jungle = { walls = { Color3.fromRGB(130, 96, 60), Color3.fromRGB(112, 84, 54) }, roofs = { Color3.fromRGB(150, 130, 70), Color3.fromRGB(120, 110, 60) }, mat = Enum.Material.Wood, roofMat = Enum.Material.Grass, kind = "stilt", ground = Enum.Material.Mud },
	beach = { walls = { Color3.fromRGB(176, 140, 96), Color3.fromRGB(200, 170, 130) }, roofs = { Color3.fromRGB(196, 170, 100), Color3.fromRGB(176, 150, 90) }, mat = Enum.Material.WoodPlanks, roofMat = Enum.Material.Grass, kind = "stilt", ground = Enum.Material.Sand },
}
local function pick(list) return list[vr:NextInteger(1, #list)] end

-- variant: 1 cottage, 2 two storeys, 3 long house, 4 cottage with a porch, 5 small hut, 6 big hall
-- every house gets its own size inside the range of its kind
local SIZES = {
	{ W = { 14, 18 }, D = { 12, 15 }, H = { 9, 11 } },
	{ W = { 16, 20 }, D = { 13, 16 }, H = { 18, 19 } },
	{ W = { 22, 28 }, D = { 11, 13 }, H = { 9, 10.5 } },
	{ W = { 14, 17 }, D = { 12, 14 }, H = { 9.5, 11 } },
	{ W = { 10, 12 }, D = { 9, 11 }, H = { 8.5, 9.5 } },
	{ W = { 20, 24 }, D = { 17, 20 }, H = { 12, 14 } },
}
local function houseSize(variant)
	local z = SIZES[variant]
	return vr:NextNumber(z.W[1], z.W[2]), vr:NextNumber(z.D[1], z.D[2]), vr:NextNumber(z.H[1], z.H[2])
end
local function house(m, x, z, rot, st, variant, W, D, H)
	if not W then W, D, H = houseSize(variant) end
	local porch = variant == 4 and 5 or 0
	local wall, roof = pick(st.walls), pick(st.roofs)
	local rotCF = CFrame.Angles(0, rot, 0)
	-- ground under the whole footprint
	local gMin, gMax = math.huge, -math.huge
	for _, cx in ipairs({ -W / 2 - 1, 0, W / 2 + 1 }) do
		for _, cz in ipairs({ -D / 2 - 1, 0, D / 2 + 1 + porch }) do
			local wp = (CFrame.new(x, 0, z) * rotCF * CFrame.new(cx, 0, cz)).Position
			local gg = ground(wp.X, wp.Z)
			gMin, gMax = math.min(gMin, gg), math.max(gMax, gg)
		end
	end
	local stilt = st.kind == "stilt"
	local floorY = stilt and (gMax + 4) or (gMax + 0.6)
	local T = workspace.Terrain
	-- terrain: a solid pad up to the floor (not for stilt huts) and nothing inside the house
	if not stilt then
		local bottom = gMin - 6
		local top = floorY - 0.5
		T:FillBlock(CFrame.new(x, (bottom + top) / 2, z) * rotCF * CFrame.new(0, 0, porch / 2), Vector3.new(W + 6, top - bottom, D + 6 + porch), st.ground)
	end
	T:FillBlock(CFrame.new(x, floorY + (H + 24) / 2, z) * rotCF * CFrame.new(0, 0, porch / 2), Vector3.new(W + 3, H + 24, D + 3 + porch), Enum.Material.Air)
	local base = CFrame.new(x, floorY, z) * rotCF
	local function p(name, size, cf, color, mat, shape, collide)
		return part(m, name, size, base * cf, color, mat, shape, collide ~= false)
	end
	local stone, beam = Color3.fromRGB(120, 118, 114), Color3.fromRGB(86, 62, 42)
	local upstairsBed = false
	if stilt then
		for _, sx in ipairs({ -1, 0, 1 }) do for _, sz in ipairs({ -1, 1 }) do
			local hgt = floorY - gMin + 2
			p("Post", Vector3.new(1, hgt, 1), CFrame.new(sx * (W / 2 - 0.5), -hgt / 2, sz * (D / 2 - 0.5)), beam, Enum.Material.Wood)
		end end
		for i = 0, 5 do
			p("Step", Vector3.new(4, 0.4, 1.2), CFrame.new(0, -0.6 - i * 0.7, D / 2 + 1 + i * 1.1), Color3.fromRGB(110, 80, 50), Enum.Material.WoodPlanks)
		end
	else
		p("Foundation", Vector3.new(W + 0.8, 1.4, D + 0.8), CFrame.new(0, -0.5, 0), stone, Enum.Material.Cobblestone)
		p("Doorstep", Vector3.new(5.8, 0.8, 1.6), CFrame.new(0, -0.6, D / 2 + 1.1), stone, Enum.Material.Cobblestone)
	end
	p("Floor", Vector3.new(W, 0.4, D), CFrame.new(0, 0.2, 0), Color3.fromRGB(110, 80, 54), Enum.Material.WoodPlanks)
	-- walls: back, sides, front with a door; window glass with frames
	local T2 = 0.8
	local function windowAt(cf, w, h)
		local gl = p("Glass", Vector3.new(w, h, 0.25), cf, Color3.fromRGB(255, 214, 150), Enum.Material.Glass, nil, false)
		gl.Transparency = 0.35
		p("Frame", Vector3.new(w + 0.4, 0.3, 0.4), cf * CFrame.new(0, h / 2, 0), beam, Enum.Material.Wood, nil, false)
		p("Frame", Vector3.new(w + 0.4, 0.3, 0.4), cf * CFrame.new(0, -h / 2, 0), beam, Enum.Material.Wood, nil, false)
		p("Sill", Vector3.new(w + 0.8, 0.25, 0.7), cf * CFrame.new(0, -h / 2 - 0.2, 0.2), beam, Enum.Material.Wood, nil, false)
	end
	p("Wall", Vector3.new(W, H, T2), CFrame.new(0, H / 2, -D / 2), wall, st.mat)
	for _, sx in ipairs({ -1, 1 }) do
		p("Wall", Vector3.new(T2, H, D), CFrame.new(sx * W / 2, H / 2, 0), wall, st.mat)
		windowAt(CFrame.new(sx * (W / 2 + 0.05), math.min(H, 10) * 0.55, 0) * CFrame.Angles(0, math.rad(90), 0), 3, 2.6)
		p("Wall", Vector3.new(W / 2 - 2.8, H, T2), CFrame.new(sx * (W / 4 + 1.4), H / 2, D / 2), wall, st.mat)
		if W / 2 - 2.8 >= 3 then windowAt(CFrame.new(sx * (W / 4 + 1.4), math.min(H, 10) * 0.55, D / 2 + 0.05), math.min(2.6, W / 2 - 3.6), 2.4) end
	end
	windowAt(CFrame.new(0, math.min(H, 10) * 0.55, -D / 2 - 0.05), 3.4, 2.4)
	p("Wall", Vector3.new(5.6, H - 7.4, T2), CFrame.new(0, H - (H - 7.4) / 2, D / 2), wall, st.mat)
	-- a wide door, standing open
	local hinge = base * CFrame.new(-2.75, 3.7, D / 2)
	part(m, "Door", Vector3.new(5.2, 7.4, 0.3), hinge * CFrame.Angles(0, math.rad(-80), 0) * CFrame.new(2.6, 0, 0), Color3.fromRGB(96, 62, 40), Enum.Material.WoodPlanks, nil, true)
	-- corner beams
	for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
		p("Beam", Vector3.new(1, H, 1), CFrame.new(sx * W / 2, H / 2, sz * D / 2), beam, Enum.Material.Wood)
	end end
	if variant == 2 then
		-- second storey: a beam band, an inner floor and more windows
		p("Band", Vector3.new(W + 0.4, 0.8, D + 0.4), CFrame.new(0, 9, 0), beam, Enum.Material.Wood, nil, false)
		-- upper floor over the back half, reached by a staircase along the right wall; the bedroom is upstairs
		local upD = D / 2 - 0.4
		p("UpperFloor", Vector3.new(W - 1, 0.4, upD), CFrame.new(0, 9, -D / 2 + upD / 2 + 0.4), Color3.fromRGB(110, 80, 54), Enum.Material.WoodPlanks)
		p("Rail", Vector3.new(W - 4.2, 1.6, 0.25), CFrame.new(-1.6, 10, -D / 2 + upD + 0.4), beam, Enum.Material.Wood)
		local steps = 10
		local zTop, zBottom = -D / 2 + upD + 0.2, D / 2 - 1.2
		for i = 1, steps do
			local f = i / steps
			p("Stair", Vector3.new(2.4, 0.5, (zBottom - zTop) / steps + 0.15), CFrame.new(W / 2 - 1.7, 0.4 + f * 8.8, zBottom - f * (zBottom - zTop)), Color3.fromRGB(120, 86, 56), Enum.Material.WoodPlanks)
		end
		upstairsBed = true
		for _, sx in ipairs({ -1, 1 }) do
			windowAt(CFrame.new(sx * (W / 4 + 1.1), 13.5, D / 2 + 0.05), 2.8, 2.4)
			windowAt(CFrame.new(sx * (W / 2 + 0.05), 13.5, 0) * CFrame.Angles(0, math.rad(90), 0), 3, 2.4)
		end
		windowAt(CFrame.new(0, 13.5, D / 2 + 0.05), 2.4, 2.2)
	end
	-- roof
	if st.kind == "flat" then
		p("Roof", Vector3.new(W + 0.6, 0.6, D + 0.6), CFrame.new(0, H + 0.3, 0), roof, st.roofMat)
		for _, o in ipairs({ { 0, -D / 2, W + 0.6, 0.5 }, { 0, D / 2, W + 0.6, 0.5 }, { -W / 2, 0, 0.5, D + 0.6 }, { W / 2, 0, 0.5, D + 0.6 } }) do
			p("Parapet", Vector3.new(o[3], 1.2, o[4]), CFrame.new(o[1], H + 1.1, o[2]), roof, st.roofMat)
		end
		if variant ~= 3 then p("Dome", Vector3.new(6, 6, 6), CFrame.new(W / 4, H + 0.6, -D / 6), Color3.fromRGB(240, 236, 226), Enum.Material.Plaster, BALL) end
		for i = 1, 3 do p("Beam", Vector3.new(0.4, 0.4, 1.4), CFrame.new(-W / 2 + i * W / 4, H - 1, D / 2 + 0.6), beam, Enum.Material.Wood, nil, false) end
	else
		local pitch = math.rad(stilt and 42 or vr:NextNumber(28, 38))
		local over = 1.4
		local half = D / 2 + over
		local len = half / math.cos(pitch) + 0.6
		local rise = (D / 2 + over) * math.tan(pitch) / 2
		p("Roof", Vector3.new(W + 2.4, 0.7, len), CFrame.new(0, H + rise + 0.2, half / 2) * CFrame.Angles(pitch, 0, 0), roof, st.roofMat)
		p("Roof", Vector3.new(W + 2.4, 0.7, len), CFrame.new(0, H + rise + 0.2, -half / 2) * CFrame.Angles(-pitch, 0, 0), roof, st.roofMat)
		p("Ridge", Vector3.new(W + 2.6, 0.8, 0.8), CFrame.new(0, H + rise * 2 + 0.2, 0), beam, Enum.Material.Wood, nil, false)
		-- gables closed with stacked boards
		local gr = (D / 2) * math.tan(pitch)
		for i = 0, 5 do
			local f = i / 6
			local w2 = D * (1 - f)
			if w2 > 0.6 then
				for _, sx in ipairs({ -1, 1 }) do
					p("Gable", Vector3.new(T2, gr / 6 + 0.05, w2), CFrame.new(sx * W / 2, H + gr * (f + 1 / 12), 0), wall, st.mat)
				end
			end
		end
		if not stilt and vr:NextNumber() < 0.6 then
			p("Chimney", Vector3.new(2.2, H + rise * 2 + 3, 2.2), CFrame.new(W / 2 - 2.5, (H + rise * 2 + 3) / 2, -D / 4), stone, Enum.Material.Cobblestone)
		end
	end
	if porch > 0 then
		p("Porch", Vector3.new(W - 2, 0.4, porch), CFrame.new(0, 0.2, D / 2 + porch / 2), Color3.fromRGB(110, 80, 54), Enum.Material.WoodPlanks)
		for _, sx in ipairs({ -1, 1 }) do
			p("Post", Vector3.new(0.7, 7.6, 0.7), CFrame.new(sx * (W / 2 - 1.5), 3.8, D / 2 + porch - 0.4), beam, Enum.Material.Wood)
			p("Bench", Vector3.new(3, 0.4, 1.2), CFrame.new(sx * (W / 4 + 1), 1.4, D / 2 + porch - 1.2), beam, Enum.Material.Wood)
		end
		p("PorchRoof", Vector3.new(W - 1, 0.5, porch + 1), CFrame.new(0, 7.9, D / 2 + porch / 2) * CFrame.Angles(math.rad(12), 0, 0), roof, st.roofMat)
	end
	-- inside: beds (upstairs in the two-storey house, two in the long house), a table, a chest, a warm light
	local by = upstairsBed and 9.2 or 0
	local bedXs = (variant == 3 and { -W / 2 + 2.6, -W / 2 + 6.6 }) or (variant == 6 and { -W / 2 + 2.6, -W / 2 + 6.6, -W / 2 + 10.6 }) or { -W / 2 + 2.6 }
	if variant == 6 then
		-- the hall: two wooden pillars and a long table
		for _, px in ipairs({ -W / 6, W / 6 }) do p("Pillar", Vector3.new(1, H, 1), CFrame.new(px, H / 2, D / 8), beam, Enum.Material.Wood) end
		p("LongTable", Vector3.new(W * 0.45, 0.3, 2.4), CFrame.new(W * 0.12, 2.6, D / 4), beam, Enum.Material.WoodPlanks)
	end
	for _, bx in ipairs(bedXs) do
		p("Bed", Vector3.new(3.4, 1.2, 6), CFrame.new(bx, by + 0.9, -D / 2 + 3.6), Color3.fromRGB(150, 50, 60), Enum.Material.Fabric)
		p("Pillow", Vector3.new(2.4, 0.5, 1.2), CFrame.new(bx, by + 1.7, -D / 2 + 1.4), Color3.fromRGB(235, 230, 220), Enum.Material.Fabric, nil, false)
	end
	p("Table", Vector3.new(3.6, 0.3, 2.6), CFrame.new(W / 2 - 3.2, 2.6, -D / 2 + 3), beam, Enum.Material.WoodPlanks)
	for _, o in ipairs({ { -1.4, -1 }, { 1.4, -1 }, { -1.4, 1 }, { 1.4, 1 } }) do
		p("Leg", Vector3.new(0.3, 2.4, 0.3), CFrame.new(W / 2 - 3.2 + o[1], 1.4, -D / 2 + 3 + o[2]), beam, Enum.Material.Wood, nil, false)
	end
	p("Chest", Vector3.new(2.6, 1.6, 1.6), CFrame.new(W / 2 - 2, 1.2, D / 2 - 2.2), Color3.fromRGB(120, 84, 50), Enum.Material.WoodPlanks)
	local lampIn = p("LampIn", Vector3.new(0.5, 0.7, 0.5), CFrame.new(0, H - 1.2, 0), Color3.fromRGB(255, 200, 120), Enum.Material.Neon, nil, false)
	local li = Instance.new("PointLight"); li.Range = 18; li.Brightness = 1.2; li.Color = Color3.fromRGB(255, 190, 120); li.Parent = lampIn
	local lamp = p("Lamp", Vector3.new(0.6, 0.9, 0.6), CFrame.new(2.8, 6.6, D / 2 + 0.7), Color3.fromRGB(255, 200, 120), Enum.Material.Neon, nil, false)
	local l = Instance.new("PointLight"); l.Range = 16; l.Brightness = 1.3; l.Color = Color3.fromRGB(255, 180, 100); l.Parent = lamp
	return math.max(W, D + porch)
end

local function tower(m, x, z)
	local g = ground(x, z)
	local wood = Color3.fromRGB(110, 78, 50)
	for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
		part(m, "Post", Vector3.new(0.9, 14, 0.9), CFrame.new(x + sx * 2.4, g + 7, z + sz * 2.4), wood, Enum.Material.Wood, nil, true)
	end end
	part(m, "Deck", Vector3.new(6.4, 0.6, 6.4), CFrame.new(x, g + 12, z), Color3.fromRGB(96, 70, 46), Enum.Material.WoodPlanks, nil, true)
	for _, o in ipairs({ { 0, 3.1, 6.4, 0.3 }, { 0, -3.1, 6.4, 0.3 }, { 3.1, 0, 0.3, 6.4 }, { -3.1, 0, 0.3, 6.4 } }) do
		part(m, "Rail", Vector3.new(o[3], 1.4, o[4]), CFrame.new(x + o[1], g + 13, z + o[2]), wood, Enum.Material.Wood, nil, true)
	end
	part(m, "TowerRoof", Vector3.new(7.4, 0.5, 7.4), CFrame.new(x, g + 17.5, z), Color3.fromRGB(120, 52, 40), Enum.Material.WoodPlanks, nil, true)
	for _, sx in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
		part(m, "Post", Vector3.new(0.5, 4.8, 0.5), CFrame.new(x + sx * 2.9, g + 15, z + sz * 2.9), wood, Enum.Material.Wood, nil, false)
	end end
	local torch = part(m, "Torch", Vector3.new(0.5, 0.8, 0.5), CFrame.new(x, g + 16.6, z), Color3.fromRGB(255, 170, 80), Enum.Material.Neon, nil, false)
	local l = Instance.new("PointLight"); l.Range = 26; l.Brightness = 1.6; l.Color = Color3.fromRGB(255, 170, 90); l.Parent = torch
	return Vector3.new(x, g + 12.3, z)
end

local function village(region, tx, tz)
	local x, z = findArea(tx, tz, region, region == "beach" and 46 or 60, region == "beach" and 8 or 7)
	if not x then return false end
	local st = STYLE[region] or STYLE.forest
	local g = ground(x, z)
	local center = Vector3.new(x, g, z)
	local m = Instance.new("Model"); m.Name = "Village_" .. region
	m:SetAttribute("Center", center)
	m:SetAttribute("Radius", 72)
	m:SetAttribute("Region", region)
	m.Parent = villagesF
	local npcs = Instance.new("Folder"); npcs.Name = "NPCs"; npcs.Parent = m
	-- clear vegetation / decor in the area
	for _, f in ipairs({ workspace:FindFirstChild("Resources"), workspace:FindFirstChild("Decor") }) do
		for _, c in ipairs(f and f:GetChildren() or {}) do
			local ok, pv = pcall(function() return c:GetPivot().Position end)
			if ok and Vector3.new(pv.X - x, 0, pv.Z - z).Magnitude < 82 then c:Destroy() end
		end
	end
	-- the square is levelled first
	workspace.Terrain:FillCylinder(CFrame.new(x, g - 4, z), 8, 22, st.ground)
	workspace.Terrain:FillCylinder(CFrame.new(x, g + 14, z), 28, 22, Enum.Material.Air)
	-- houses in a ring, doors facing the square, every one a little different
	local nh = 7
	local pool = { 1, 2, 3, 4, 5, 6, 1, 2, 5 }
	for i = #pool, 2, -1 do local j = vr:NextInteger(1, i) pool[i], pool[j] = pool[j], pool[i] end
	for i = 1, nh do
		local variant = pool[i]
		local W, D, H = houseSize(variant)
		local a = i / nh * math.pi * 2 + vr:NextNumber(-0.12, 0.12)
		local r = 28 + math.max(W, D) / 2 + vr:NextNumber(0, 6)
		local hx, hz = x + math.cos(a) * r, z + math.sin(a) * r
		local rot = math.atan2(x - hx, z - hz) -- +Z (the door side) towards the centre
		house(m, hx, hz, rot, st, variant, W, D, H)
	end
	-- the square: a well and a trader's stall
	part(m, "Well", Vector3.new(2.2, 6, 6), CFrame.new(x, g + 1.1, z) * UPC, Color3.fromRGB(130, 128, 124), Enum.Material.Cobblestone, CYL, true)
	local water = part(m, "WellWater", Vector3.new(0.3, 4.6, 4.6), CFrame.new(x, g + 2, z) * UPC, Color3.fromRGB(60, 120, 150), Enum.Material.Glass, CYL, false)
	water.Transparency = 0.3
	for _, sx in ipairs({ -1, 1 }) do part(m, "Post", Vector3.new(0.5, 6, 0.5), CFrame.new(x + sx * 2.6, g + 4, z), Color3.fromRGB(100, 72, 46), Enum.Material.Wood, nil, true) end
	part(m, "WellRoof", Vector3.new(7, 0.5, 4), CFrame.new(x, g + 7.2, z), Color3.fromRGB(120, 52, 40), Enum.Material.WoodPlanks, nil, true)
	local sx, sz = x + 14, z
	local counter = part(m, "Counter", Vector3.new(2.2, 2.6, 8), CFrame.new(sx, g + 1.3, sz), Color3.fromRGB(128, 90, 58), Enum.Material.WoodPlanks, nil, true)
	part(m, "Awning", Vector3.new(6, 0.3, 9), CFrame.new(sx + 1.4, g + 6.6, sz) * CFrame.Angles(0, 0, math.rad(-12)), st.roofs[1], Enum.Material.Fabric, nil, true)
	for _, oz in ipairs({ -4, 4 }) do part(m, "Post", Vector3.new(0.5, 6.6, 0.5), CFrame.new(sx + 3.6, g + 3.3, sz + oz), Color3.fromRGB(100, 72, 46), Enum.Material.Wood, nil, true) end
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Shop"; pr.ObjectText = "Trader"; pr.HoldDuration = 0; pr.MaxActivationDistance = 12; pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "trade"); pr:SetAttribute("Shop", "village")
	pr.Parent = counter
	local trader = newRig(randomLook())
	if trader then
		trader.Name = "Trader"
		standAt(trader, Vector3.new(sx + 2.4, g, sz), Vector3.new(x, g, z))
		trader.Parent = m
	end
	-- village fire
	local fpos = Vector3.new(x - 12, g, z + 8)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part(m, "Stone", Vector3.new(1.2, 0.8, 1.2), CFrame.new(fpos + Vector3.new(math.cos(a) * 2.2, 0.3, math.sin(a) * 2.2)), Color3.fromRGB(120, 120, 126), Enum.Material.Slate, BALL, true)
	end
	local core = part(m, "CampfireCore", Vector3.new(2.4, 0.6, 2.4), CFrame.new(fpos + Vector3.new(0, 0.3, 0)), Color3.fromRGB(70, 46, 32), Enum.Material.Wood, nil, true)
	local fire = Instance.new("Fire"); fire.Size = 6; fire.Heat = 8; fire.Parent = core
	local pl = Instance.new("PointLight"); pl.Range = 28; pl.Brightness = 2; pl.Color = Color3.fromRGB(255, 160, 80); pl.Parent = core
	-- two watchtowers with archers, two gate guards
	for k, a in ipairs({ 0.6, 0.6 + math.pi }) do
		local deck = tower(m, x + math.cos(a) * 60, z + math.sin(a) * 60)
		local archer = newRig({ skin = vr:NextInteger(1, 6), shirt = 6, pants = 3, hat = "helmet", extra = "none" })
		if archer then
			archer.Name = "Archer"
			archer:SetAttribute("Role", "archer")
			Appearance.armor(archer, Color3.fromRGB(150, 154, 164), Enum.Material.Metal)
			standAt(archer, deck, center)
			archer.Parent = npcs
		end
	end
	for _, a in ipairs({ math.pi / 2, -math.pi / 2 }) do
		local gx, gz = x + math.cos(a) * 58, z + math.sin(a) * 58
		local guard = newRig({ skin = vr:NextInteger(1, 6), shirt = 2, pants = 3, hat = "helmet", extra = "none" })
		if guard then
			guard.Name = "Guard"
			guard:SetAttribute("Role", "guard")
			Appearance.armor(guard, Color3.fromRGB(170, 174, 184), Enum.Material.Metal)
			standAt(guard, Vector3.new(gx, ground(gx, gz), gz), Vector3.new(gx + math.cos(a) * 10, 0, gz + math.sin(a) * 10))
			guard.Parent = npcs
		end
	end
	for _ = 1, 5 do
		local a, r = vr:NextNumber(0, 6.28), vr:NextNumber(6, 22)
		local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		local v = newRig(randomLook())
		if v then
			v.Name = "Villager"
			v:SetAttribute("Role", "villager")
			standAt(v, Vector3.new(px, ground(px, pz), pz), center)
			v.Parent = npcs
		end
	end
	-- a low fence ring with four openings
	for i = 0, 47 do
		local a = i / 48 * math.pi * 2
		local gap = (i % 12) == 0 or (i % 12) == 1
		if not gap then
			local fx, fz = x + math.cos(a) * 68, z + math.sin(a) * 68
			local fg = ground(fx, fz)
			part(m, "Fence", Vector3.new(0.6, 3, 0.6), CFrame.new(fx, fg + 1.2, fz), Color3.fromRGB(110, 80, 52), Enum.Material.Wood, nil, true)
			local a2 = (i + 1) / 48 * math.pi * 2
			local nx, nz = x + math.cos(a2) * 68, z + math.sin(a2) * 68
			local mid = Vector3.new((fx + nx) / 2, (fg + ground(nx, nz)) / 2 + 2, (fz + nz) / 2)
			part(m, "Rail", Vector3.new(0.3, 0.3, 8.8), CFrame.lookAt(mid, Vector3.new(nx, mid.Y, nz)), Color3.fromRGB(120, 88, 58), Enum.Material.Wood, nil, false)
		end
	end
	table.insert(taken, { x, z, 240 })
	return true
end

local made = 0
for _, v in ipairs({
	{ "forest", -240, -240 }, { "hills", -736, -425 }, { "snow", 156, -886 }, { "desert", -148, 837 },
	{ "jungle", -779, 450 }, { "beach", -700, -1300 },
}) do
	if village(v[1], v[2], v[3]) then made += 1 end
end

-- ---------------------------------------------------------------- bandit camps
local function camp(region)
	for _ = 1, 400 do
		local x, z = vr:NextNumber(-HALF + 200, HALF - 200), vr:NextNumber(-HALF + 200, HALF - 200)
		if regionAt(x, z) == region and free(x, z, 200) then
			local x2, z2 = findArea(x, z, region, 22, 4)
			if x2 and free(x2, z2, 200) then
				x, z = x2, z2
				local g = ground(x, z)
				local m = Instance.new("Model"); m.Name = "BanditCamp"
				m:SetAttribute("Type", "bandit")
				m:SetAttribute("Center", Vector3.new(x, g, z))
				m.Parent = campsF
				for _, f in ipairs({ workspace:FindFirstChild("Resources"), workspace:FindFirstChild("Decor") }) do
					for _, c in ipairs(f and f:GetChildren() or {}) do
						local ok, pv = pcall(function() return c:GetPivot().Position end)
						if ok and Vector3.new(pv.X - x, 0, pv.Z - z).Magnitude < 26 then c:Destroy() end
					end
				end
				local spots = Instance.new("Folder"); spots.Name = "Spots"; spots.Parent = m
				-- tents
				for k = 0, 2 do
					local a = k / 3 * math.pi * 2 + 0.4
					local tx, tz = x + math.cos(a) * 11, z + math.sin(a) * 11
					local tg = ground(tx, tz)
					local rot = CFrame.new(tx, tg, tz) * CFrame.Angles(0, -a, 0)
					local cloth = ({ Color3.fromRGB(110, 40, 36), Color3.fromRGB(70, 60, 50), Color3.fromRGB(90, 76, 52) })[k + 1]
					part(m, "Tent", Vector3.new(7, 0.3, 4.6), rot * CFrame.new(0, 2, 1.5) * CFrame.Angles(math.rad(50), 0, 0), cloth, Enum.Material.Fabric, nil, true)
					part(m, "Tent", Vector3.new(7, 0.3, 4.6), rot * CFrame.new(0, 2, -1.5) * CFrame.Angles(math.rad(-50), 0, 0), cloth, Enum.Material.Fabric, nil, true)
					local sp = part(spots, "Spot", Vector3.new(1, 1, 1), CFrame.new(x + math.cos(a + 0.9) * 8, ground(x + math.cos(a + 0.9) * 8, z + math.sin(a + 0.9) * 8), z + math.sin(a + 0.9) * 8), Color3.new(1, 0, 0), nil, nil, false)
					sp.Transparency = 1
				end
				-- fire, crates, a flag
				local core = part(m, "CampfireCore", Vector3.new(2.4, 0.6, 2.4), CFrame.new(x, g + 0.3, z), Color3.fromRGB(60, 40, 30), Enum.Material.Wood, nil, true)
				local fire = Instance.new("Fire"); fire.Size = 6; fire.Parent = core
				local pl = Instance.new("PointLight"); pl.Range = 24; pl.Brightness = 1.8; pl.Color = Color3.fromRGB(255, 150, 70); pl.Parent = core
				local box = Instance.new("Model"); box.Name = "LootCrate"
				local b = part(box, "Box", Vector3.new(3, 2.2, 2.2), CFrame.new(x + 5, g + 1.1, z - 4), Color3.fromRGB(120, 86, 50), Enum.Material.WoodPlanks, nil, true)
				part(box, "Lid", Vector3.new(3.1, 0.4, 2.3), CFrame.new(x + 5, g + 2.4, z - 4), Color3.fromRGB(100, 70, 44), Enum.Material.WoodPlanks, nil, true)
				box.PrimaryPart = b
				local p = Instance.new("ProximityPrompt"); p.ActionText = "Search"; p.ObjectText = "Crate"; p.HoldDuration = 0.8; p.MaxActivationDistance = 9; p.RequiresLineOfSight = false
				p:SetAttribute("Key", "search"); p:SetAttribute("Obj", "crate"); p.Parent = b
				box:SetAttribute("Crate", "cave")
				box.Parent = m
				part(m, "FlagPole", Vector3.new(0.4, 12, 0.4), CFrame.new(x - 6, g + 6, z - 6), Color3.fromRGB(80, 60, 40), Enum.Material.Wood, nil, true)
				part(m, "Flag", Vector3.new(0.1, 2.4, 3.6), CFrame.new(x - 6, g + 10.6, z - 4.2), Color3.fromRGB(150, 20, 20), Enum.Material.Fabric, nil, false)
				table.insert(taken, { x, z, 260 })
				return true
			end
		end
	end
	return false
end
local camps = 0
for _, r in ipairs({ "hills", "desert", "jungle", "mountains", "volcano", "snow" }) do
	if camp(r) then camps += 1 end
end

local ok = pcall(function() game:GetService("AssetService"):SavePlaceAsync() end)
return { saved = ok, villages = made, banditCamps = camps }
