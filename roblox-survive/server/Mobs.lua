-- Creatures: peaceful animals, predators, night zombies and the Forest Guardian boss. All faceless.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Debug = require(script.Parent.Debug)

local Mobs = {}
local ctx, folder, traps
local mobs = {} -- [model] = state
local rng = Random.new()
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local MAP_HALF = Biomes.HALF - 40

local DEFS = {
	rabbit = { hp = 20, speed = 13.5, flee = true, size = 0.55, hip = 0.45, xp = 4, coins = 1, color = Color3.fromRGB(200, 186, 170), drops = { { "meat_raw", 1, 1, 1 }, { "hide", 1, 1, 0.04 } } },
	deer = { hp = 55, speed = 14.5, flee = true, size = 1.05, hip = 2.2, xp = 10, coins = 3, color = Color3.fromRGB(168, 118, 74), drops = { { "meat_raw", 1, 2, 1 }, { "hide", 1, 1, 0.1 } } },
	wolf = { hp = 70, speed = 13.5, aggro = 45, dmg = 8, reach = 4.5, size = 0.9, hip = 1.3, xp = 18, coins = 6, color = Color3.fromRGB(110, 112, 118), drops = { { "meat_raw", 1, 1, 1 }, { "hide", 1, 1, 0.08 } } },
	zombie = { hp = 85, speed = 8, aggro = 70, dmg = 12, reach = 4.2, night = true, xp = 22, coins = 8, color = Color3.fromRGB(110, 140, 96), drops = { { "bandage", 1, 1, 0.25 }, { "ammo", 4, 8, 0.15 }, { "arrow", 4, 8, 0.25 } } },
	boar = { hp = 90, speed = 11, neutral = true, aggro = 0, dmg = 10, reach = 4.5, size = 1.0, hip = 1.0, xp = 14, coins = 5, color = Color3.fromRGB(96, 70, 52), drops = { { "meat_raw", 1, 3, 1 }, { "hide", 1, 1, 0.08 } } },
	bear = { hp = 220, speed = 11, aggro = 35, dmg = 20, reach = 6, size = 1.7, hip = 1.6, xp = 45, coins = 15, color = Color3.fromRGB(88, 62, 44), drops = { { "meat_raw", 2, 4, 1 }, { "hide", 1, 1, 0.18 } } },
	spider = { hp = 45, speed = 12, aggro = 55, dmg = 7, reach = 4, night = true, xp = 12, coins = 4, color = Color3.fromRGB(40, 36, 44), drops = { { "arrow", 2, 5, 0.3 } } },
	alpha = { hp = 700, speed = 15, aggro = 70, dmg = 22, reach = 6, boss = true, tier = 1, size = 1.7, hip = 2.2, xp = 220, coins = 80, color = Color3.fromRGB(196, 198, 204), drops = { { "hide", 1, 2, 0.6 }, { "bow", 1, 1, 0.4 }, { "arrow", 10, 20, 1 } } },
	hare = { hp = 22, speed = 13.5, flee = true, size = 0.55, hip = 0.45, xp = 5, coins = 1, color = Color3.fromRGB(240, 240, 245), drops = { { "meat_raw", 1, 1, 1 }, { "hide_snow", 1, 1, 0.03 } } },
	snowwolf = { hp = 95, speed = 14, aggro = 50, dmg = 10, reach = 4.8, size = 1.0, hip = 1.3, xp = 24, coins = 8, color = Color3.fromRGB(228, 230, 238), drops = { { "meat_raw", 1, 2, 1 }, { "hide_snow", 1, 1, 0.06 } } },
	polarbear = { hp = 300, speed = 11.5, aggro = 38, dmg = 26, reach = 6.5, size = 1.9, hip = 1.7, xp = 60, coins = 20, color = Color3.fromRGB(240, 240, 244), drops = { { "meat_raw", 3, 5, 1 }, { "hide_snow", 1, 1, 0.15 } } },
	camel = { hp = 90, speed = 13, flee = true, size = 1.4, hip = 2.6, xp = 12, coins = 4, color = Color3.fromRGB(196, 160, 110), drops = { { "meat_raw", 2, 3, 1 }, { "hide_desert", 1, 1, 0.08 } } },
	goat = { hp = 60, speed = 14, flee = true, size = 0.9, hip = 1.6, xp = 9, coins = 3, color = Color3.fromRGB(205, 200, 190), drops = { { "meat_raw", 1, 2, 1 }, { "hide", 1, 1, 0.06 } } },
	scorpion = { hp = 95, speed = 12, aggro = 45, dmg = 13, reach = 5, size = 1, xp = 20, coins = 7, color = Color3.fromRGB(150, 96, 52), drops = { { "rifle_ammo", 2, 4, 0.12 }, { "gold", 1, 1, 0.1 } } },
	scorpionking = { hp = 1900, speed = 11, aggro = 85, dmg = 36, reach = 10, boss = true, tier = 2, size = 2.6, xp = 450, coins = 200, color = Color3.fromRGB(120, 70, 36), drops = { { "scimitar", 1, 1, 0.5 }, { "hide_desert", 1, 3, 0.8 }, { "rifle", 1, 1, 0.25 }, { "gold", 3, 6, 1 } } },
	yeti = { hp = 2600, speed = 10, aggro = 90, dmg = 42, reach = 10, boss = true, tier = 3, xp = 600, coins = 260, color = Color3.fromRGB(236, 240, 248), drops = { { "ice_spear", 1, 1, 0.4 }, { "hide_snow", 1, 3, 0.8 }, { "warm_coat", 1, 1, 0.5 }, { "diamond", 2, 4, 1 } } },
	-- new region creatures
	fox = { hp = 50, speed = 14, aggro = 35, dmg = 7, reach = 4, size = 0.7, hip = 0.9, xp = 14, coins = 5, color = Color3.fromRGB(205, 110, 50), drops = { { "meat_raw", 1, 1, 1 }, { "hide", 1, 1, 0.05 } } },
	ram = { hp = 100, speed = 13, neutral = true, aggro = 0, dmg = 14, reach = 5, size = 1.0, hip = 1.5, xp = 20, coins = 7, color = Color3.fromRGB(150, 130, 110), drops = { { "meat_raw", 1, 2, 1 }, { "hide", 1, 1, 0.07 } } },
	mammoth = { hp = 520, speed = 10, neutral = true, aggro = 0, dmg = 30, reach = 8, size = 2.3, hip = 3.2, xp = 90, coins = 30, color = Color3.fromRGB(110, 78, 56), drops = { { "meat_raw", 4, 6, 1 }, { "hide_snow", 1, 2, 0.3 } } },
	hyena = { hp = 80, speed = 14.5, aggro = 50, dmg = 11, reach = 4.5, size = 0.95, hip = 1.4, xp = 22, coins = 8, color = Color3.fromRGB(176, 146, 96), drops = { { "meat_raw", 1, 1, 1 }, { "hide_desert", 1, 1, 0.07 } } },
	puma = { hp = 160, speed = 15, aggro = 45, dmg = 18, reach = 5.5, size = 1.15, hip = 1.5, xp = 40, coins = 14, color = Color3.fromRGB(196, 156, 104), drops = { { "meat_raw", 1, 2, 1 }, { "hide", 1, 1, 0.15 } } },
	turtle = { hp = 70, speed = 6, flee = true, size = 1.0, hip = 0.5, xp = 10, coins = 4, color = Color3.fromRGB(110, 140, 80), drops = { { "meat_raw", 1, 2, 1 } } },
	crab = { hp = 60, speed = 11, aggro = 30, dmg = 9, reach = 4, size = 0.7, xp = 14, coins = 5, noTail = true, color = Color3.fromRGB(214, 84, 52), drops = { { "meat_raw", 1, 1, 0.8 } } },
	crabking = { hp = 2000, speed = 9, aggro = 70, dmg = 34, reach = 10, boss = true, tier = 2, size = 3.0, noTail = true, xp = 450, coins = 200, color = Color3.fromRGB(200, 60, 40), drops = { { "harpoon", 1, 1, 0.4 }, { "gold", 3, 6, 1 }, { "diamond", 1, 2, 0.5 } } },
	monkey = { hp = 35, speed = 15, flee = true, size = 0.6, hip = 1.0, xp = 8, coins = 3, color = Color3.fromRGB(110, 80, 55), drops = { { "coconut", 1, 1, 0.5 }, { "meat_raw", 1, 1, 0.6 } } },
	tiger = { hp = 230, speed = 15.5, aggro = 50, dmg = 24, reach = 6, size = 1.5, hip = 1.7, xp = 60, coins = 20, color = Color3.fromRGB(230, 130, 40), drops = { { "meat_raw", 2, 3, 1 }, { "hide", 1, 1, 0.2 } } },
	snake = { hp = 70, speed = 10, aggro = 30, dmg = 15, reach = 4.5, xp = 18, coins = 6, color = Color3.fromRGB(70, 110, 50), drops = { { "meat_raw", 1, 1, 0.5 } } },
	gorilla = { hp = 2800, speed = 11, aggro = 80, dmg = 44, reach = 9, boss = true, tier = 3, xp = 620, coins = 260, color = Color3.fromRGB(52, 48, 46), drops = { { "machete", 1, 1, 0.5 }, { "jungle_vest", 1, 1, 0.4 }, { "gold", 3, 5, 1 }, { "diamond", 1, 2, 0.6 } } },
	lavalizard = { hp = 150, speed = 12.5, aggro = 45, dmg = 20, reach = 5, size = 1.2, hip = 0.7, xp = 38, coins = 14, color = Color3.fromRGB(80, 36, 28), glow = Color3.fromRGB(255, 120, 30), drops = { { "obsidian", 1, 1, 0.08 }, { "iron", 1, 2, 0.3 } } },
	ashwolf = { hp = 130, speed = 14.5, aggro = 55, dmg = 16, reach = 5, size = 1.0, hip = 1.3, xp = 34, coins = 12, color = Color3.fromRGB(72, 68, 68), glow = Color3.fromRGB(255, 130, 50), drops = { { "meat_raw", 1, 2, 1 }, { "hide", 1, 1, 0.1 } } },
	magma = { tier = 4, hp = 3600, speed = 8.5, aggro = 70, dmg = 50, reach = 11, boss = true, xp = 800, coins = 320, color = Color3.fromRGB(64, 34, 28), glow = Color3.fromRGB(255, 110, 30), drops = { { "magma_blade", 1, 1, 0.35 }, { "lava_cloak", 1, 1, 0.5 }, { "obsidian", 3, 6, 1 }, { "diamond", 2, 3, 1 } } },
	bandit = { hp = 120, speed = 13, aggro = 55, dmg = 14, reach = 5, xp = 30, coins = 25, color = Color3.fromRGB(196, 150, 110), cloth = Color3.fromRGB(70, 56, 48), drops = { { "bandage", 1, 1, 0.3 }, { "ammo", 4, 8, 0.2 }, { "gold", 1, 1, 0.2 }, { "iron_sword", 1, 1, 0.03 } } },
	banditlord = { hp = 1600, speed = 12, aggro = 70, dmg = 30, reach = 6, boss = true, tier = 2, xp = 380, coins = 220, color = Color3.fromRGB(176, 130, 96), cloth = Color3.fromRGB(110, 30, 30), drops = { { "pistol", 1, 1, 0.4 }, { "rifle", 1, 1, 0.15 }, { "gold", 3, 5, 1 }, { "potion_strength", 1, 1, 0.3 } } },
	-- cave dwellers (spawned only inside caves, `cave = true`)
	bat = { hp = 30, speed = 15, aggro = 40, dmg = 6, reach = 4.5, cave = true, hip = 4.5, xp = 10, coins = 4, color = Color3.fromRGB(46, 40, 48), drops = { { "crystal", 1, 1, 0.12 } } },
	crawler = { hp = 110, speed = 12, aggro = 45, dmg = 14, reach = 5, cave = true, size = 1.35, xp = 26, coins = 9, color = Color3.fromRGB(196, 190, 176), drops = { { "crystal", 1, 2, 0.3 }, { "mushroom", 1, 2, 0.3 } } },
	ghoul = { hp = 140, speed = 9.5, aggro = 50, dmg = 18, reach = 4.5, cave = true, xp = 32, coins = 12, color = Color3.fromRGB(120, 130, 150), drops = { { "bandage", 1, 1, 0.25 }, { "gold", 1, 2, 0.18 }, { "obsidian", 1, 1, 0.05 } } },
	golem = { tier = 3, hp = 3000, speed = 8, aggro = 60, dmg = 45, reach = 10, boss = true, cave = true, xp = 650, coins = 280, color = Color3.fromRGB(58, 54, 66), glow = Color3.fromRGB(160, 110, 255), drops = { { "obsidian", 3, 5, 1 }, { "crystal", 4, 8, 1 }, { "diamond", 1, 2, 0.6 } } },
	guardian = { tier = 2, hp = 1500, speed = 9, aggro = 90, dmg = 30, reach = 10, boss = true, xp = 400, coins = 150, color = Color3.fromRGB(108, 112, 104), drops = { { "iron_sword", 1, 1, 0.5 }, { "pistol", 1, 1, 0.3 }, { "ammo", 10, 20, 1 } } },
}

---------------------------------------------------------------- models
local function vis(m, hrp, size, offset, color, shape, material)
	local p = Instance.new("Part")
	p.Name = "Vis"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.CFrame = hrp.CFrame * offset
	p.Parent = m
	local w = Instance.new("WeldConstraint")
	w.Part0 = hrp
	w.Part1 = p
	w.Parent = p
	return p
end

local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder

-- a limb hanging from a joint (Motor6D named "Limb"); `phase` decides which limbs swing together
local function limb(m, hrp, size, jointOffset, color, phase, material)
	local p = Instance.new("Part")
	p.Name = "Vis"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = hrp.CFrame * jointOffset * CFrame.new(0, -size.Y / 2, 0)
	p.Parent = m
	local j = Instance.new("Motor6D")
	j.Name = "Limb"
	j.Part0 = hrp
	j.Part1 = p
	j.C0 = jointOffset
	j.C1 = CFrame.new(0, size.Y / 2, 0)
	j:SetAttribute("Phase", phase)
	j.Parent = hrp
	return p
end

local function base(kind, hrpSize, hip, at)
	local m = Instance.new("Model")
	m.Name = kind
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = hrpSize
	hrp.Transparency = 1
	hrp.Anchored = false
	hrp.CanCollide = false
	hrp.CanQuery = true
	local lift = hip + hrpSize.Y / 2
	hrp:SetAttribute("Lift", lift)
	hrp.CFrame = CFrame.new(at + Vector3.new(0, lift, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	hrp.Parent = m
	m.PrimaryPart = hrp
	local att = Instance.new("Attachment")
	att.Name = "Drive"
	att.Parent = hrp
	local ap = Instance.new("AlignPosition")
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = att
	ap.MaxForce = 1e7
	ap.Responsiveness = 35
	ap.Position = hrp.Position
	ap.Parent = hrp
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e7
	ao.Responsiveness = 18
	ao.CFrame = hrp.CFrame.Rotation
	ao.Parent = hrp
	return m, hrp, nil
end

-- a part spanning two points given in `base`'s local space, welded to `base` (bones, legs, horns, tails)
local function seg(m, base, a, b, th, color, material, depth)
	local wa, wb = base.CFrame:PointToWorldSpace(a), base.CFrame:PointToWorldSpace(b)
	local d = wb - wa
	local len = d.Magnitude
	if len < 0.01 then return nil end
	local up = d.Unit
	local right = math.abs(up.Y) < 0.95 and Vector3.yAxis:Cross(up).Unit or Vector3.xAxis
	local back = right:Cross(up)
	local p = Instance.new("Part")
	p.Name = "Vis"
	p.Size = Vector3.new(th, len + th * 0.25, depth or th)
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = CFrame.fromMatrix((wa + wb) / 2, right, up, back)
	p.Parent = m
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = p
	w.Parent = p
	return p
end

---------------------------------------------------------------- four-legged animals
-- body proportions per animal (multiplied by def.size). Front is -Z.
local Q = {
	default = { L = 2.6, H = 1.3, W = 1.25, neck = 0.8, neckAng = 35, head = Vector3.new(0.85, 0.8, 0.95), snout = { 0.5, 0.42, 0.6 }, ears = "pointy", tail = "thin" },
	rabbit = { L = 2.1, H = 1.45, W = 1.3, neck = 0.25, neckAng = 60, head = Vector3.new(0.95, 0.9, 0.95), snout = { 0.6, 0.5, 0.32 }, ears = "long", tail = "puff", rump = 0.15 },
	deer = { L = 2.6, H = 1.15, W = 1.0, neck = 1.5, neckAng = 60, head = Vector3.new(0.6, 0.62, 0.85), snout = { 0.42, 0.4, 0.62 }, ears = "side", tail = "puff" },
	wolf = { L = 2.7, H = 1.15, W = 1.0, neck = 0.75, neckAng = 32, head = Vector3.new(0.82, 0.78, 0.82), snout = { 0.44, 0.36, 0.82 }, ears = "pointy", tail = "bushy", ruff = true },
	fox = { L = 2.6, H = 1.0, W = 0.9, neck = 0.6, neckAng = 30, head = Vector3.new(0.8, 0.72, 0.78), snout = { 0.4, 0.32, 0.8 }, ears = "big", tail = "fox" },
	boar = { L = 2.5, H = 1.35, W = 1.25, neck = 0.35, neckAng = 0, head = Vector3.new(0.95, 0.95, 1.0), snout = { 0.6, 0.55, 0.75 }, ears = "small", tail = "thin", withers = 0.18 },
	bear = { L = 2.6, H = 1.55, W = 1.45, neck = 0.5, neckAng = 18, head = Vector3.new(1.0, 0.95, 1.0), snout = { 0.55, 0.5, 0.55 }, ears = "round", tail = "stub", withers = 0.25 },
	camel = { L = 2.4, H = 1.2, W = 1.05, neck = 1.7, neckAng = 42, head = Vector3.new(0.55, 0.6, 0.95), snout = { 0.45, 0.45, 0.5 }, ears = "small", tail = "thin" },
	goat = { L = 2.4, H = 1.2, W = 1.05, neck = 0.65, neckAng = 48, head = Vector3.new(0.68, 0.72, 0.85), snout = { 0.44, 0.42, 0.5 }, ears = "side", tail = "stub" },
	mammoth = { L = 2.6, H = 1.65, W = 1.5, neck = 0.25, neckAng = 10, head = Vector3.new(1.25, 1.35, 1.05), snout = nil, ears = "flap", tail = "thin", withers = 0.35 },
	hyena = { L = 2.5, H = 1.2, W = 1.0, neck = 0.65, neckAng = 26, head = Vector3.new(0.85, 0.8, 0.8), snout = { 0.48, 0.42, 0.55 }, ears = "round", tail = "bushy", withers = 0.28, rump = -0.18, ruff = true },
	cat = { L = 3.0, H = 1.1, W = 1.05, neck = 0.5, neckAng = 15, head = Vector3.new(0.88, 0.8, 0.82), snout = { 0.5, 0.4, 0.38 }, ears = "round", tail = "long" },
	monkey = { L = 1.8, H = 1.2, W = 1.0, neck = 0.3, neckAng = 55, head = Vector3.new(0.9, 0.9, 0.85), snout = { 0.55, 0.45, 0.3 }, ears = "monkey", tail = "curl", withers = 0.2 },
	lizard = { L = 3.0, H = 0.75, W = 1.2, neck = 0.5, neckAng = 4, head = Vector3.new(0.8, 0.5, 1.0), snout = { 0.6, 0.34, 0.6 }, ears = "none", tail = "lizard" },
}
Q.hare, Q.snowwolf, Q.ashwolf, Q.alpha = Q.rabbit, Q.wolf, Q.wolf, Q.wolf
Q.polarbear, Q.ram, Q.puma, Q.tiger, Q.lavalizard = Q.bear, Q.goat, Q.cat, Q.cat, Q.lizard

local function quadruped(kind, def, at)
	local s = def.size
	local q = Q[kind] or Q.default
	local m, hrp, hum = base(kind, Vector3.new(1.6, 1.4, 2.8) * s, def.hip, at)
	local col = def.color
	local dark = col:Lerp(Color3.new(0, 0, 0), 0.32)
	local light = col:Lerp(Color3.new(1, 1, 1), 0.3)
	local fur = (kind == "mammoth" or kind == "ram" or kind == "polarbear" or kind == "yeti") and Enum.Material.Fabric or Enum.Material.SmoothPlastic
	local L, H, W = q.L * s, q.H * s, q.W * s
	local wi, ru = (q.withers or 0) * s, (q.rump or 0) * s
	local function V(size, off, color, shape, mat) return vis(m, hrp, size, off, color, shape, mat or fur) end
	local function S(a, b, th, color, mat, depth) return seg(m, hrp, a, b, th, color, mat or fur, depth) end
	-- body: chest, barrel, rump, a lighter belly and a darker back line
	local y0 = 0.05 * s
	V(Vector3.new(W, H, L * 0.6), CFrame.new(0, y0 + (wi + ru) / 2, 0), col)
	V(Vector3.new(W * 1.06, H * 1.08, L * 0.38), CFrame.new(0, y0 + wi + H * 0.03, -L * 0.32), col)
	V(Vector3.new(W, H * 0.98, L * 0.34), CFrame.new(0, y0 + ru, L * 0.33), col)
	V(Vector3.new(W * 0.8, H * 0.26, L * 0.72), CFrame.new(0, y0 - H * 0.4 + (wi + ru) / 2, -0.04 * L), light)
	V(Vector3.new(W * 0.42, 0.12 * s, L * 0.8), CFrame.new(0, y0 + H / 2 + 0.04 * s + (wi + ru) / 2, 0), dark)
	-- neck and head
	local nb = Vector3.new(0, y0 + wi + H * 0.28, -L * 0.42)
	local ang = math.rad(q.neckAng)
	local nt = nb + Vector3.new(0, math.sin(ang), -math.cos(ang)) * q.neck * s
	S(nb, nt, W * 0.55, col, nil, W * 0.62)
	local hd = q.head * s
	local hc = nt + Vector3.new(0, hd.Y * 0.15, -hd.Z * 0.25)
	V(hd, CFrame.new(hc), col)
	if q.snout then
		local sn = q.snout
		local sc = hc + Vector3.new(0, -hd.Y * 0.18, -(hd.Z / 2 + sn[3] * s / 2 - 0.06 * s))
		V(Vector3.new(sn[1], sn[2], sn[3]) * s, CFrame.new(sc), kind == "monkey" and Color3.fromRGB(214, 178, 140) or light)
		V(Vector3.new(sn[1] * 0.72, sn[2] * 0.42, 0.1) * s, CFrame.new(sc + Vector3.new(0, sn[2] * s * 0.22, -sn[3] * s / 2)), Color3.fromRGB(34, 28, 26))
	end
	-- ears
	for _, x in ipairs({ -1, 1 }) do
		local ep = hc + Vector3.new(x * hd.X * 0.32, hd.Y * 0.5, hd.Z * 0.15)
		if q.ears == "pointy" or q.ears == "big" then
			local e = q.ears == "big" and 1.4 or 1
			V(Vector3.new(0.26 * e, 0.42 * e, 0.12) * s, CFrame.new(ep + Vector3.new(0, 0.16 * e * s, 0)) * CFrame.Angles(0, 0, math.rad(-x * 12)), dark)
		elseif q.ears == "long" then
			V(Vector3.new(0.22, 1.05, 0.14) * s, CFrame.new(ep + Vector3.new(0, 0.48 * s, 0.1 * s)) * CFrame.Angles(math.rad(14), 0, math.rad(-x * 8)), col)
			V(Vector3.new(0.12, 0.85, 0.06) * s, CFrame.new(ep + Vector3.new(0, 0.48 * s, 0.03 * s)) * CFrame.Angles(math.rad(14), 0, math.rad(-x * 8)), Color3.fromRGB(230, 190, 190), nil, Enum.Material.SmoothPlastic)
		elseif q.ears == "round" or q.ears == "small" then
			local e = q.ears == "small" and 0.7 or 1
			V(Vector3.new(0.3, 0.3, 0.3) * s * e, CFrame.new(ep + Vector3.new(0, 0.05 * s, 0)), dark, BALL)
		elseif q.ears == "side" then
			V(Vector3.new(0.45, 0.16, 0.22) * s, CFrame.new(ep + Vector3.new(x * 0.18 * s, -0.05 * s, 0)) * CFrame.Angles(0, 0, math.rad(x * 25)), col)
		elseif q.ears == "flap" then
			V(Vector3.new(0.12, 0.8, 0.7) * s, CFrame.new(ep + Vector3.new(x * 0.25 * s, -0.4 * s, 0.1 * s)), dark)
		elseif q.ears == "monkey" then
			V(Vector3.new(0.14, 0.36, 0.36) * s, CFrame.new(hc + Vector3.new(x * hd.X * 0.55, 0.05 * s, 0)), Color3.fromRGB(214, 178, 140), BALL)
		end
	end
	if q.ruff then
		V(Vector3.new(W * 1.12, H * 0.7, L * 0.2), CFrame.new(nb + Vector3.new(0, -0.05 * s, 0.1 * s)), kind == "alpha" and Color3.fromRGB(240, 240, 244) or dark)
	end
	-- legs: a thigh that swings, a thinner shin and a hoof or paw
	local legTotal = def.hip + 0.6 * s
	local hoof = (kind == "deer" or kind == "goat" or kind == "ram" or kind == "camel" or kind == "boar" or kind == "mammoth") and Color3.fromRGB(46, 38, 32) or dark
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			local phase = ((x < 0) == (z < 0)) and 0 or math.pi
			local front = z < 0
			local total = legTotal + (front and wi or ru)
			local thigh = total * 0.52
			local shin = total - thigh + 0.08 * s
			local lx = x * W * (kind == "lizard" and 0.62 or 0.32)
			local tw = W * (kind == "mammoth" and 0.42 or 0.33)
			local part = limb(m, hrp, Vector3.new(tw, thigh, tw * 1.1), CFrame.new(lx, -0.1 * s + (front and wi or ru), z * L * 0.34), col, phase, fur)
			local sw = tw * (kind == "mammoth" and 0.95 or 0.66)
			vis(m, part, Vector3.new(sw, shin, sw), CFrame.new(0, -thigh / 2 - shin / 2 + 0.08 * s, front and 0 or 0.04 * s), kind == "tiger" and col or col:Lerp(Color3.new(0, 0, 0), 0.12), nil, fur)
			vis(m, part, Vector3.new(sw * 1.15, 0.16 * s, sw * 1.35), CFrame.new(0, -thigh / 2 - shin + 0.14 * s, -0.06 * s), hoof)
		end
	end
	-- tail
	local tb = Vector3.new(0, y0 + ru + H * 0.3, L * 0.5)
	if q.tail == "thin" then
		S(tb, tb + Vector3.new(0, -0.7, 0.35) * s, 0.14 * s, dark)
	elseif q.tail == "stub" then
		V(Vector3.new(0.3, 0.3, 0.3) * s, CFrame.new(tb + Vector3.new(0, 0, 0.08 * s)), col, BALL)
	elseif q.tail == "puff" then
		V(Vector3.new(0.5, 0.5, 0.5) * s, CFrame.new(tb + Vector3.new(0, 0, 0.12 * s)), Color3.fromRGB(245, 242, 236), BALL)
	elseif q.tail == "bushy" or q.tail == "fox" then
		local tip = tb + Vector3.new(0, -0.55, 1.25) * s
		S(tb, tip, 0.42 * s, col, nil, 0.42 * s)
		V(Vector3.new(0.5, 0.5, 0.5) * s, CFrame.new(tip), q.tail == "fox" and Color3.fromRGB(245, 242, 236) or dark, BALL)
	elseif q.tail == "long" then
		local mid = tb + Vector3.new(0, -0.6, 1.0) * s
		S(tb, mid, 0.2 * s, col)
		S(mid, mid + Vector3.new(0, 0.35, 0.9) * s, 0.18 * s, kind == "tiger" and Color3.fromRGB(30, 26, 24) or col)
	elseif q.tail == "curl" then
		local a1 = tb + Vector3.new(0, 0.7, 0.5) * s
		S(tb, a1, 0.16 * s, col)
		S(a1, a1 + Vector3.new(0, 0.6, -0.35) * s, 0.15 * s, col)
	elseif q.tail == "lizard" then
		local p = tb + Vector3.new(0, -0.15 * s, 0)
		for i = 1, 4 do
			local n = p + Vector3.new(math.sin(i) * 0.15, -0.05, 0.75) * s
			S(p, n, (0.55 - i * 0.1) * s, col, nil, (0.4 - i * 0.07) * s)
			p = n
		end
	end
	-- what makes each animal itself
	if kind == "deer" then
		for _, x in ipairs({ -1, 1 }) do
			local b0 = hc + Vector3.new(x * 0.2 * s, hd.Y * 0.5, 0.1 * s)
			local b1 = b0 + Vector3.new(x * 0.35, 0.9, 0.15) * s
			local antler = Color3.fromRGB(222, 204, 170)
			S(b0, b1, 0.1 * s, antler)
			S(b1, b1 + Vector3.new(x * 0.4, 0.5, -0.1) * s, 0.08 * s, antler)
			S(b1, b1 + Vector3.new(-x * 0.05, 0.55, 0.25) * s, 0.08 * s, antler)
			S(b0 + Vector3.new(x * 0.15, 0.4, 0.05) * s, b0 + Vector3.new(x * 0.1, 0.65, -0.35) * s, 0.07 * s, antler)
		end
	elseif kind == "goat" then
		for _, x in ipairs({ -1, 1 }) do
			local h0 = hc + Vector3.new(x * 0.18 * s, hd.Y * 0.5, 0.05 * s)
			local h1 = h0 + Vector3.new(x * 0.1, 0.45, 0.35) * s
			S(h0, h1, 0.13 * s, Color3.fromRGB(80, 70, 60))
			S(h1, h1 + Vector3.new(x * 0.05, 0.05, 0.4) * s, 0.1 * s, Color3.fromRGB(80, 70, 60))
		end
		V(Vector3.new(0.22, 0.45, 0.2) * s, CFrame.new(hc + Vector3.new(0, -hd.Y * 0.62, -hd.Z * 0.45)), Color3.fromRGB(240, 236, 228))
	elseif kind == "ram" then
		V(Vector3.new(W * 1.22, H * 1.06, L * 0.86), CFrame.new(0, y0 + 0.05 * s, 0.02 * s), Color3.fromRGB(232, 226, 212), nil, Enum.Material.Fabric)
		for _, x in ipairs({ -1, 1 }) do
			local c0 = hc + Vector3.new(x * 0.42 * s, hd.Y * 0.25, 0.1 * s)
			local pts = { c0, c0 + Vector3.new(x * 0.2, 0.35, 0.25) * s, c0 + Vector3.new(x * 0.35, 0.05, 0.5) * s, c0 + Vector3.new(x * 0.35, -0.4, 0.3) * s, c0 + Vector3.new(x * 0.3, -0.45, -0.1) * s }
			for i = 1, #pts - 1 do S(pts[i], pts[i + 1], (0.3 - i * 0.04) * s, Color3.fromRGB(150, 130, 100)) end
		end
	elseif kind == "boar" then
		V(Vector3.new(0.3, 0.45, L * 0.75), CFrame.new(0, y0 + wi + H * 0.58, -0.1 * L), Color3.fromRGB(50, 38, 30), nil, Enum.Material.Fabric)
		for _, x in ipairs({ -1, 1 }) do
			local t0 = hc + Vector3.new(x * 0.22 * s, -hd.Y * 0.3, -hd.Z * 0.6)
			S(t0, t0 + Vector3.new(x * 0.15, 0.4, -0.15) * s, 0.12 * s, Color3.fromRGB(240, 232, 210))
		end
	elseif kind == "bear" or kind == "polarbear" then
		V(Vector3.new(W * 0.9, H * 0.4, L * 0.3), CFrame.new(0, y0 + wi + H * 0.45, -L * 0.28), col, nil, fur) -- shoulder hump
	elseif kind == "camel" then
		V(Vector3.new(W * 0.9, H * 0.85, W * 0.9), CFrame.new(0, y0 + H * 0.55, -L * 0.12), col:Lerp(Color3.new(0, 0, 0), 0.06), BALL)
		V(Vector3.new(W * 0.8, H * 0.75, W * 0.8), CFrame.new(0, y0 + H * 0.5, L * 0.2), col:Lerp(Color3.new(0, 0, 0), 0.06), BALL)
	elseif kind == "mammoth" then
		-- trunk curling down, long tusks, a shaggy coat
		local tr0 = hc + Vector3.new(0, -hd.Y * 0.2, -hd.Z * 0.48)
		local tr1 = tr0 + Vector3.new(0, -0.9, -0.35) * s
		local tr2 = tr1 + Vector3.new(0, -0.8, 0.05) * s
		S(tr0, tr1, 0.5 * s, col)
		S(tr1, tr2, 0.38 * s, col)
		S(tr2, tr2 + Vector3.new(0, -0.3, -0.2) * s, 0.3 * s, col)
		for _, x in ipairs({ -1, 1 }) do
			local t0 = hc + Vector3.new(x * 0.4 * s, -hd.Y * 0.35, -hd.Z * 0.35)
			local t1 = t0 + Vector3.new(x * 0.15, -0.6, -0.8) * s
			S(t0, t1, 0.24 * s, Color3.fromRGB(240, 232, 210), Enum.Material.SmoothPlastic)
			S(t1, t1 + Vector3.new(-x * 0.1, 0.45, -0.45) * s, 0.2 * s, Color3.fromRGB(240, 232, 210), Enum.Material.SmoothPlastic)
		end
		V(Vector3.new(W * 1.1, H * 0.4, L * 0.9), CFrame.new(0, y0 - H * 0.45, 0), dark, nil, Enum.Material.Fabric)
	elseif kind == "hyena" then
		for i = 1, 10 do
			V(Vector3.new(0.3, 0.3, 0.3) * s, CFrame.new(((i % 2) * 2 - 1) * W * 0.51, y0 + (i % 3 - 1) * 0.3 * s, (-0.45 + i * 0.09) * L), Color3.fromRGB(70, 54, 38), BALL)
		end
	elseif kind == "tiger" then
		for i = -3, 3 do
			V(Vector3.new(W * 1.04, H * 0.86, 0.16 * s), CFrame.new(0, y0 + 0.12 * s, i * L * 0.12) * CFrame.Angles(math.rad(10), 0, 0), Color3.fromRGB(28, 24, 22))
		end
		V(Vector3.new(hd.X * 1.02, hd.Y * 0.35, 0.12 * s), CFrame.new(hc + Vector3.new(0, hd.Y * 0.2, 0)), Color3.fromRGB(28, 24, 22))
	elseif kind == "lizard" or kind == "lavalizard" then
		for i = 1, 8 do
			V(Vector3.new(0.3, 0.2, 0.3) * s, CFrame.new(((i % 2) * 2 - 1) * W * 0.3, y0 + H * 0.5, (-0.45 + i * 0.11) * L), def.glow or dark, nil, def.glow and Enum.Material.Neon or nil)
		end
	elseif kind == "ashwolf" then
		for i = 1, 6 do
			V(Vector3.new(0.22, 0.22, 0.22) * s, CFrame.new(((i % 2) * 2 - 1) * W * 0.4, y0 + H * 0.45, (-0.35 + i * 0.12) * L), def.glow, BALL, Enum.Material.Neon)
		end
	elseif kind == "alpha" then
		V(Vector3.new(W * 1.25, H * 1.0, L * 0.3), CFrame.new(0, y0 + wi + H * 0.15, -L * 0.36), Color3.fromRGB(236, 236, 240), nil, Enum.Material.Fabric)
	end
	return m, hrp, hum
end

local function turtle(def, at)
	local s = def.size
	local m, hrp, hum = base("turtle", Vector3.new(2.2, 1, 2.8) * s, def.hip, at)
	local col = def.color
	local shell, rim = Color3.fromRGB(104, 84, 52), Color3.fromRGB(70, 56, 36)
	-- stepped dome shell with plates
	vis(m, hrp, Vector3.new(0.5, 2.7, 3.2) * s, CFrame.new(0, 0.05 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), rim, CYL)
	vis(m, hrp, Vector3.new(0.5, 2.3, 2.75) * s, CFrame.new(0, 0.45 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), shell, CYL)
	vis(m, hrp, Vector3.new(0.4, 1.6, 1.9) * s, CFrame.new(0, 0.8 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), shell:Lerp(Color3.new(1, 1, 1), 0.08), CYL)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		vis(m, hrp, Vector3.new(0.5, 0.12, 0.5) * s, CFrame.new(math.cos(a) * 0.75 * s, 0.72 * s, math.sin(a) * 0.9 * s) * CFrame.Angles(0, a, 0), rim)
	end
	vis(m, hrp, Vector3.new(0.6, 0.14, 0.6) * s, CFrame.new(0, 1.02 * s, 0), rim)
	-- head on a neck, stubby legs, a little tail
	seg(m, hrp, Vector3.new(0, 0, -1.3) * s, Vector3.new(0, 0.25, -1.85) * s, 0.42 * s, col)
	vis(m, hrp, Vector3.new(0.6, 0.48, 0.7) * s, CFrame.new(0, 0.3 * s, -2.1 * s), col, BALL)
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			local p = limb(m, hrp, Vector3.new(0.5, def.hip + 0.45 * s, 0.6) * Vector3.new(s, 1, s), CFrame.new(x * 1.0 * s, -0.05 * s, z * 0.95 * s), col, ((x < 0) == (z < 0)) and 0 or math.pi)
		end
	end
	seg(m, hrp, Vector3.new(0, 0, 1.5) * s, Vector3.new(0, -0.15, 1.9) * s, 0.18 * s, col)
	return m, hrp, hum
end

local function gorilla(def, at)
	-- hunched, long arms down to the ground, short legs
	local m, hrp, hum = base("gorilla", Vector3.new(4.5, 5.5, 3), 2.6, at)
	local fur, chest, skin = def.color, Color3.fromRGB(96, 96, 104), Color3.fromRGB(40, 36, 36)
	vis(m, hrp, Vector3.new(4.6, 4.2, 3.4), CFrame.new(0, 0.6, -0.3) * CFrame.Angles(math.rad(-22), 0, 0), fur, nil, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(3.0, 2.6, 0.4), CFrame.new(0, 0.7, -2.0) * CFrame.Angles(math.rad(-22), 0, 0), chest)
	vis(m, hrp, Vector3.new(3.6, 2.2, 2.6), CFrame.new(0, -1.6, 0.6), fur, nil, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(2.4, 2.6, 2.6), CFrame.new(0, 2.7, -2.0), fur, BALL, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(2.2, 0.6, 0.9), CFrame.new(0, 3.3, -3.0), skin) -- brow
	vis(m, hrp, Vector3.new(1.6, 1.0, 0.8), CFrame.new(0, 2.3, -3.15), skin) -- muzzle
	vis(m, hrp, Vector3.new(1.6, 1.4, 1.4), CFrame.new(0, 3.9, -1.4), fur, BALL, Enum.Material.Fabric) -- crest
	for _, x in ipairs({ -1, 1 }) do
		local arm = limb(m, hrp, Vector3.new(1.7, 7.1, 1.7), CFrame.new(x * 3.0, 1.8, -1.9), fur, x < 0 and 0 or math.pi, Enum.Material.Fabric)
		vis(m, arm, Vector3.new(1.9, 0.9, 2.1), CFrame.new(0, -3.45, -0.2), skin) -- knuckles
		limb(m, hrp, Vector3.new(1.8, 3.0, 1.8), CFrame.new(x * 1.3, -2.4, 0.8), fur, x < 0 and math.pi or 0, Enum.Material.Fabric)
	end
	return m, hrp, hum
end

---------------------------------------------------------------- spiders, crabs, scorpions
-- eight jointed legs: the thigh rises from the body and swings, the shin reaches down to the ground
local function jointedLegs(m, hrp, n, spread, bodyY, ground, s, color, thick, zFrom, zTo)
	for _, x in ipairs({ -1, 1 }) do
		for i = 0, n - 1 do
			local z = zFrom + (zTo - zFrom) * (n == 1 and 0.5 or i / (n - 1))
			local th = math.rad(x * 125)
			local up = 1.25 * s * spread
			local part = limb(m, hrp, Vector3.new(thick, up, thick), CFrame.new(x * 0.55 * s, bodyY, z) * CFrame.Angles(0, math.rad(x * (i - (n - 1) / 2) * -14), th), color, (i % 2 == 0) == (x < 0) and 0 or math.pi)
			local knee = Vector3.new(0, -up / 2, 0)
			local kneeHrp = hrp.CFrame:PointToObjectSpace(part.CFrame:PointToWorldSpace(knee))
			local foot = Vector3.new(kneeHrp.X + x * 0.55 * s * spread, ground, kneeHrp.Z + (z > 0 and 0.2 or -0.2) * s)
			seg(m, part, knee, part.CFrame:PointToObjectSpace(hrp.CFrame:PointToWorldSpace(foot)), thick * 0.8, color:Lerp(Color3.new(0, 0, 0), 0.15))
		end
	end
end

local function spider(def, at, kind)
	local m, hrp, hum = base(kind or "spider", Vector3.new(2.2, 1, 2.6), 1.2, at)
	local col = def.color
	local ground = -(1.2 + 0.5)
	vis(m, hrp, Vector3.new(2.5, 2.5, 2.5), CFrame.new(0, 0.35, 1.25), col, BALL)
	vis(m, hrp, Vector3.new(1.4, 1.2, 1.5), CFrame.new(0, 0.1, -0.5), col:Lerp(Color3.new(1, 1, 1), 0.06), BALL)
	vis(m, hrp, Vector3.new(0.9, 0.85, 0.85), CFrame.new(0, 0.15, -1.35), col, BALL)
	if kind == "crawler" then
		for i = 0, 2 do vis(m, hrp, Vector3.new(1.6 - i * 0.3, 0.2, 0.3), CFrame.new(0, 1.55 - i * 0.05, 0.7 + i * 0.5), col:Lerp(Color3.new(0, 0, 0), 0.3)) end
	else
		vis(m, hrp, Vector3.new(0.5, 0.12, 0.9), CFrame.new(0, 1.58, 1.25), Color3.fromRGB(170, 30, 30))
		vis(m, hrp, Vector3.new(0.9, 0.12, 0.35), CFrame.new(0, 1.6, 1.25), Color3.fromRGB(170, 30, 30))
	end
	for _, x in ipairs({ -1, 1 }) do
		seg(m, hrp, Vector3.new(x * 0.2, -0.05, -1.7), Vector3.new(x * 0.15, -0.55, -1.85), 0.18, Color3.fromRGB(20, 18, 20))
	end
	jointedLegs(m, hrp, 4, 1.25, 0.2, ground, 1, col, 0.2, -0.9, 0.6)
	return m, hrp, hum
end

local function scorpion(kind, def, at)
	local s = def.size
	local crab = def.noTail
	local m, hrp, hum = base(kind, Vector3.new(2.2, 0.8, 3) * s, 0.9 * s, at)
	local col, dark = def.color, def.color:Lerp(Color3.new(0, 0, 0), 0.28)
	local light = col:Lerp(Color3.new(1, 1, 1), 0.2)
	local ground = -(0.9 * s + 0.4 * s)
	if crab then
		-- wide flat shell
		vis(m, hrp, Vector3.new(0.7, 2.6, 2.6) * s, CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), col, CYL)
		vis(m, hrp, Vector3.new(0.3, 2.1, 2.1) * s, CFrame.new(0, 0.42 * s, 0.05 * s) * CFrame.Angles(0, 0, math.rad(90)), light, CYL)
		vis(m, hrp, Vector3.new(2.3, 0.25, 0.3) * s, CFrame.new(0, -0.15 * s, -1.25 * s), dark)
	else
		for i = 0, 3 do
			vis(m, hrp, Vector3.new(2.0 - i * 0.25, 0.75, 0.85) * s, CFrame.new(0, 0.05 * s, (-0.9 + i * 0.7) * s), i % 2 == 0 and col or light)
		end
		vis(m, hrp, Vector3.new(1.3, 0.6, 0.9) * s, CFrame.new(0, 0, -1.65 * s), dark)
		-- tail arching over the back, ending in a stinger
		local pts = { Vector3.new(0, 0.2, 1.6), Vector3.new(0, 0.9, 2.3), Vector3.new(0, 1.9, 2.5), Vector3.new(0, 2.7, 2.0), Vector3.new(0, 3.0, 1.2) }
		for i = 1, #pts - 1 do
			seg(m, hrp, pts[i] * s, pts[i + 1] * s, (0.6 - i * 0.07) * s, i % 2 == 0 and col or light, nil, (0.55 - i * 0.06) * s)
		end
		local st = pts[#pts] * s
		vis(m, hrp, Vector3.new(0.45, 0.45, 0.45) * s, CFrame.new(st), dark, BALL)
		seg(m, hrp, st, st + Vector3.new(0, -0.55, -0.45) * s, 0.14 * s, Color3.fromRGB(30, 24, 20))
	end
	-- arms and claws (pincers)
	for _, x in ipairs({ -1, 1 }) do
		local sh = Vector3.new(x * 0.9, 0, -1.2) * s
		local el = sh + Vector3.new(x * 0.6, 0.15, -0.7) * s
		local wr = el + Vector3.new(-x * 0.15, 0.05, -0.8) * s
		seg(m, hrp, sh, el, 0.32 * s, col)
		seg(m, hrp, el, wr, 0.34 * s, col)
		vis(m, hrp, Vector3.new(0.75, 0.5, 0.9) * s, CFrame.new(wr + Vector3.new(0, 0, -0.3 * s)), dark)
		seg(m, hrp, wr + Vector3.new(x * 0.18, 0, -0.65) * s, wr + Vector3.new(x * 0.1, 0, -1.35) * s, 0.22 * s, dark)
		seg(m, hrp, wr + Vector3.new(-x * 0.18, 0, -0.65) * s, wr + Vector3.new(-x * 0.02, 0, -1.2) * s, 0.18 * s, dark)
	end
	jointedLegs(m, hrp, crab and 3 or 4, 0.9, 0, ground, s, dark, 0.2 * s, -0.6 * s, (crab and 0.8 or 1.0) * s)
	return m, hrp, hum
end

local function bat(def, at)
	local m, hrp, hum = base("bat", Vector3.new(1.4, 1.1, 1.6), def.hip, at)
	local col = def.color
	local skin = col:Lerp(Color3.new(0, 0, 0), 0.35)
	vis(m, hrp, Vector3.new(1.2, 1.3, 1.2), CFrame.new(0, -0.1, 0.1), col, BALL, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(0.85, 0.8, 0.85), CFrame.new(0, 0.55, -0.55), col, BALL, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(0.4, 0.3, 0.35), CFrame.new(0, 0.45, -0.98), skin)
	for _, x in ipairs({ -1, 1 }) do
		vis(m, hrp, Vector3.new(0.2, 0.6, 0.12), CFrame.new(x * 0.28, 1.05, -0.5) * CFrame.Angles(0, 0, math.rad(-x * 18)), skin)
		seg(m, hrp, Vector3.new(x * 0.25, -0.7, 0.3), Vector3.new(x * 0.25, -1.05, 0.35), 0.1, skin)
		-- wing: a membrane that flaps, with finger bones
		local joint = CFrame.fromMatrix(Vector3.new(x * 0.5, 0.25, 0), Vector3.new(0, 0, 1), Vector3.new(-x, 0, 0), Vector3.new(0, -x, 0))
		local wing = limb(m, hrp, Vector3.new(1.3, 2.6, 0.08), joint, skin, x < 0 and 0 or math.pi, Enum.Material.Fabric)
		vis(m, wing, Vector3.new(0.9, 1.4, 0.07), CFrame.new(0.35, -0.6, 0) * CFrame.Angles(0, 0, math.rad(25)), skin, nil, Enum.Material.Fabric)
		seg(m, wing, Vector3.new(-0.62, 1.3, 0), Vector3.new(-0.62, -1.3, 0), 0.1, col)
		seg(m, wing, Vector3.new(-0.6, 0.6, 0), Vector3.new(0.6, -1.2, 0), 0.08, col)
		seg(m, wing, Vector3.new(-0.6, 0.2, 0), Vector3.new(0.75, -0.2, 0), 0.08, col)
	end
	return m, hrp, hum
end

local function snake(def, at)
	local m, hrp, hum = base("snake", Vector3.new(1, 0.8, 2), 0.1, at)
	local col = def.color
	local belly = Color3.fromRGB(214, 196, 110)
	-- head (wide, flat) raised a little
	vis(m, hrp, Vector3.new(0.95, 0.5, 1.15), CFrame.new(0, 0.35, -1.4), col:Lerp(Color3.new(0, 0, 0), 0.15))
	vis(m, hrp, Vector3.new(0.7, 0.4, 0.4), CFrame.new(0, 0.32, -2.05), col:Lerp(Color3.new(0, 0, 0), 0.15))
	-- a winding body of thick segments with a pattern
	local prev = Vector3.new(0, 0.2, -0.9)
	for i = 1, 9 do
		local p = Vector3.new(math.sin(i * 0.8) * 0.75, -0.08, -0.9 + i * 0.8)
		local th = 0.72 - i * 0.05
		seg(m, hrp, prev, p, th, i % 2 == 0 and col or col:Lerp(belly, 0.35), nil, th * 0.8)
		vis(m, hrp, Vector3.new(th, th * 0.8, th), CFrame.new(p), col, BALL)
		if i % 2 == 1 then vis(m, hrp, Vector3.new(th * 0.55, 0.1, th * 0.5), CFrame.new(p + Vector3.new(0, th * 0.42, 0)) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(40, 50, 30)) end
		prev = p
	end
	return m, hrp, hum
end

-- shared humanoid frame: chest, waist, shoulders, neck, jointed arms with hands, legs with boots
local function humanoid(m, hrp, o)
	local skin, shirt, pants, boots = o.skin, o.shirt, o.pants, o.boots or Color3.fromRGB(46, 36, 28)
	local fab = Enum.Material.Fabric
	vis(m, hrp, Vector3.new(2, 1.2, 1), CFrame.new(0, 0.4, 0) * CFrame.Angles(math.rad(o.hunch or 0), 0, 0), shirt, nil, fab)
	vis(m, hrp, Vector3.new(1.8, 0.95, 0.92), CFrame.new(0, -0.55, 0), pants:Lerp(shirt, 0.5), nil, fab)
	vis(m, hrp, Vector3.new(1.9, 0.28, 1.0), CFrame.new(0, -0.95, 0), Color3.fromRGB(52, 38, 28), nil, fab) -- belt
	vis(m, hrp, Vector3.new(0.36, 0.3, 0.1), CFrame.new(0, -0.95, -0.52), Color3.fromRGB(200, 170, 90), nil, Enum.Material.Metal)
	for _, x in ipairs({ -1, 1 }) do vis(m, hrp, Vector3.new(0.8, 0.8, 0.8), CFrame.new(x * 1.0, 0.82, 0), shirt, BALL, fab) end
	local headY = 1.7
	local hz = -(o.hunch or 0) / 60
	vis(m, hrp, Vector3.new(0.5, 0.4, 0.5), CFrame.new(0, 1.12, hz * 0.5), skin, nil)
	vis(m, hrp, Vector3.new(1.05, 1.15, 1.05), CFrame.new(0, headY, hz), skin)
	vis(m, hrp, Vector3.new(1.12, 0.32, 1.12), CFrame.new(0, headY + 0.45, hz), o.hair or skin:Lerp(Color3.new(0, 0, 0), 0.5), nil, fab)
	local arms = {}
	for _, x in ipairs({ -1, 1 }) do
		local arm
		if o.reach then
			-- arms held out in front (zombies)
			arm = vis(m, hrp, Vector3.new(0.55, 0.55, 1.1), CFrame.new(x * 1.05, 0.75, -0.6), shirt, nil, fab)
			vis(m, hrp, Vector3.new(0.48, 0.48, 1.0), CFrame.new(x * 1.05, 0.7, -1.55) * CFrame.Angles(math.rad(-6), 0, 0), skin)
			vis(m, hrp, Vector3.new(0.5, 0.3, 0.55), CFrame.new(x * 1.05, 0.66, -2.2), skin)
		else
			arm = limb(m, hrp, Vector3.new(0.58, 1.1, 0.58), CFrame.new(x * 1.25, 0.85, 0), shirt, x < 0 and math.pi or 0, fab)
			vis(m, arm, Vector3.new(0.5, 1.0, 0.5), CFrame.new(0, -1.0, -0.05), o.sleeves and shirt or skin, nil, o.sleeves and fab or nil)
			vis(m, arm, Vector3.new(0.55, 0.5, 0.55), CFrame.new(0, -1.62, -0.05), o.gloves or skin, nil, o.gloves and fab or nil)
		end
		arms[x] = arm
		local leg = limb(m, hrp, Vector3.new(0.78, 1.1, 0.8), CFrame.new(x * 0.48, -1.0, 0), pants, x < 0 and 0 or math.pi, fab)
		vis(m, leg, Vector3.new(0.68, 0.95, 0.7), CFrame.new(0, -0.95, 0), pants, nil, fab)
		vis(m, leg, Vector3.new(0.78, 0.42, 1.1), CFrame.new(0, -1.42, -0.15), boots, nil, fab)
	end
	return arms
end

local function zombie(def, at, kind)
	local m, hrp, hum = base(kind or "zombie", Vector3.new(2, 2, 1), 2, at)
	local skin = def.color
	local ghoul = kind == "ghoul"
	local shirt = ghoul and Color3.fromRGB(60, 58, 70) or Color3.fromRGB(86, 96, 120)
	local pants = ghoul and Color3.fromRGB(40, 38, 46) or Color3.fromRGB(70, 60, 50)
	humanoid(m, hrp, { skin = skin, shirt = shirt, pants = pants, hunch = 14, reach = true, hair = Color3.fromRGB(40, 36, 30) })
	-- torn shirt and patches of skin
	vis(m, hrp, Vector3.new(0.7, 0.5, 0.1), CFrame.new(0.4, 0.15, -0.53), skin)
	vis(m, hrp, Vector3.new(0.5, 0.35, 0.1), CFrame.new(-0.55, 0.65, -0.55), skin:Lerp(Color3.new(0, 0, 0), 0.2))
	for i = -2, 2 do vis(m, hrp, Vector3.new(0.3, 0.45, 0.1), CFrame.new(i * 0.4, -0.3, -0.5) * CFrame.Angles(0, 0, math.rad(i * 9)), shirt:Lerp(Color3.new(0, 0, 0), 0.3), nil, Enum.Material.Fabric) end
	if ghoul then
		for _, x in ipairs({ -1, 1 }) do vis(m, hrp, Vector3.new(0.14, 0.6, 0.14), CFrame.new(x * 0.35, 2.4, 0.1) * CFrame.Angles(0, 0, math.rad(-x * 20)), Color3.fromRGB(200, 196, 180)) end
	end
	return m, hrp, hum
end

local function human(kind, def, at)
	local m, hrp, hum = base(kind, Vector3.new(2, 2, 1), 2, at)
	local big = kind == "banditlord"
	local arms = humanoid(m, hrp, { skin = def.color, shirt = big and Color3.fromRGB(120, 34, 34) or Color3.fromRGB(150, 130, 100), pants = Color3.fromRGB(64, 56, 48), gloves = Color3.fromRGB(50, 40, 32), hair = Color3.fromRGB(40, 32, 26) })
	-- leather vest, a face scarf and a hood
	vis(m, hrp, Vector3.new(2.06, 1.1, 1.06), CFrame.new(0, 0.4, 0), def.cloth, nil, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(0.6, 1.0, 0.12), CFrame.new(0, 0.4, -0.54), Color3.fromRGB(150, 130, 100), nil, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(1.12, 0.45, 1.12), CFrame.new(0, 1.5, 0), big and Color3.fromRGB(30, 24, 22) or Color3.fromRGB(120, 40, 36), nil, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(1.3, 1.0, 1.3), CFrame.new(0, 2.05, 0.12), big and Color3.fromRGB(110, 30, 30) or Color3.fromRGB(70, 60, 50), BALL, Enum.Material.Fabric)
	if big then
		vis(m, hrp, Vector3.new(2.3, 3.4, 0.15), CFrame.new(0, -0.5, 0.62), Color3.fromRGB(130, 30, 30), nil, Enum.Material.Fabric)
		for _, x in ipairs({ -1, 1 }) do vis(m, hrp, Vector3.new(0.9, 0.35, 1.0), CFrame.new(x * 1.05, 1.15, 0), Color3.fromRGB(150, 154, 164), nil, Enum.Material.Metal) end
	end
	-- a sword in the right hand (it swings with the arm)
	local hand = arms[1]
	vis(m, hand, Vector3.new(0.22, 0.22, 0.9), CFrame.new(0, -1.62, -0.35), Color3.fromRGB(60, 40, 28), nil, Enum.Material.Fabric)
	vis(m, hand, Vector3.new(0.9, 0.18, 0.18), CFrame.new(0, -1.62, -0.85), Color3.fromRGB(200, 170, 90), nil, Enum.Material.Metal)
	vis(m, hand, Vector3.new(0.12, 0.42, 2.6), CFrame.new(0, -1.62, -2.2), Color3.fromRGB(196, 200, 206), nil, Enum.Material.Metal)
	if big then m:ScaleTo(1.35) end
	return m, hrp, hum
end

local function yeti(def, at, kind)
	local m, hrp, hum = base(kind or "yeti", Vector3.new(4.5, 5.5, 3), 4.6, at)
	local fur, face, horn = def.color, Color3.fromRGB(120, 140, 170), Color3.fromRGB(210, 200, 180)
	local fab = Enum.Material.Fabric
	vis(m, hrp, Vector3.new(4.6, 3.6, 3.2), CFrame.new(0, 0.9, 0) * CFrame.Angles(math.rad(-8), 0, 0), fur, nil, fab)
	vis(m, hrp, Vector3.new(4.0, 2.4, 2.9), CFrame.new(0, -1.7, 0.1), fur, nil, fab)
	vis(m, hrp, Vector3.new(3.0, 2.4, 0.4), CFrame.new(0, 0.6, -1.6) * CFrame.Angles(math.rad(-8), 0, 0), fur:Lerp(Color3.new(1, 1, 1), 0.4), nil, fab)
	for _, x in ipairs({ -1, 1 }) do vis(m, hrp, Vector3.new(2.2, 2.2, 2.2), CFrame.new(x * 2.3, 2.3, 0), fur, BALL, fab) end
	vis(m, hrp, Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, 3.9, -0.6), fur, BALL, fab)
	vis(m, hrp, Vector3.new(1.7, 1.4, 0.5), CFrame.new(0, 3.75, -1.8), face)
	for _, x in ipairs({ -1, 1 }) do
		local h0 = Vector3.new(x * 0.9, 4.8, -0.6)
		local h1 = h0 + Vector3.new(x * 0.9, 0.5, 0.2)
		seg(m, hrp, h0, h1, 0.45, horn)
		seg(m, hrp, h1, h1 + Vector3.new(x * 0.2, 0.7, -0.4), 0.32, horn)
		local arm = limb(m, hrp, Vector3.new(1.7, 3.2, 1.7), CFrame.new(x * 3.0, 2.0, 0), fur, x < 0 and 0 or math.pi, fab)
		vis(m, arm, Vector3.new(1.5, 2.8, 1.5), CFrame.new(0, -2.9, -0.1), fur, nil, fab)
		vis(m, arm, Vector3.new(1.6, 0.9, 1.7), CFrame.new(0, -4.5, -0.2), face)
		for f = -1, 1 do vis(m, arm, Vector3.new(0.2, 0.6, 0.2), CFrame.new(f * 0.5, -5.1, -0.8) * CFrame.Angles(math.rad(-30), 0, 0), horn) end
		local leg = limb(m, hrp, Vector3.new(2.0, 2.6, 2.0), CFrame.new(x * 1.2, -2.6, 0), fur, x < 0 and math.pi or 0, fab)
		vis(m, leg, Vector3.new(1.8, 2.0, 1.8), CFrame.new(0, -2.0, 0), fur, nil, fab)
		vis(m, leg, Vector3.new(2.0, 0.7, 2.8), CFrame.new(0, -3.2, -0.5), face)
	end
	return m, hrp, hum
end

local function guardian(def, at, kind)
	local m, hrp, hum = base(kind or "guardian", Vector3.new(6, 7, 4), 5, at)
	local stone, moss = def.color, def.glow and def.color:Lerp(Color3.new(0, 0, 0), 0.3) or Color3.fromRGB(70, 120, 56)
	local glow = def.glow or Color3.fromRGB(110, 230, 210)
	vis(m, hrp, Vector3.new(6, 7, 4), CFrame.new(), stone, nil, Enum.Material.Slate)
	vis(m, hrp, Vector3.new(4, 3.2, 3.6), CFrame.new(0, 5, -0.2), stone, nil, Enum.Material.Slate)
	vis(m, hrp, Vector3.new(6.2, 1.2, 4.2), CFrame.new(0, 3, 0), moss, nil, Enum.Material.Grass)
	vis(m, hrp, Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 0.6, -2.05), glow, BALL, Enum.Material.Neon)
	for _, x in ipairs({ -4.1, 4.1 }) do
		vis(m, hrp, Vector3.new(2.2, 6.5, 2.2), CFrame.new(x, -0.8, -0.6), stone, nil, Enum.Material.Slate)
		vis(m, hrp, Vector3.new(2.8, 2.4, 2.8), CFrame.new(x, -4.2, -0.8), stone:Lerp(Color3.new(0, 0, 0), 0.2), nil, Enum.Material.Slate)
	end
	for _, x in ipairs({ -1.6, 1.6 }) do
		limb(m, hrp, Vector3.new(2.6, 5.2, 2.6), CFrame.new(x, -3.0, 0), stone, x < 0 and 0 or math.pi, Enum.Material.Slate)
	end
	for i = 1, 3 do
		vis(m, hrp, Vector3.new(0.8, 2.4, 0.8), CFrame.new(-1.5 + i * 0.8, 4.2, 2.1) * CFrame.Angles(math.rad(-20), 0, math.rad(-15 + i * 8)), glow, nil, Enum.Material.Neon)
	end
	return m, hrp, hum
end

---------------------------------------------------------------- helpers
local function rayParams()
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { folder }
	for _, n in ipairs({ "Resources", "Decor", "Loot", "Traps", "MapWalls" }) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then table.insert(ex, pl.Character) end
	end
	rp.FilterDescendantsInstances = ex
	return rp
end

-- Ground height read straight from the terrain voxels (works even where terrain raycasts don't).
-- returns height, isWater
local Ground = require(script.Parent.Ground)
local function terrainHeight(x, z)
	return Ground.height(x, z)
end
local function _unusedTerrainHeight(x, z)
	local vx, vz = math.floor(x / 4) * 4, math.floor(z / 4) * 4
	local ok, mats, occ = pcall(function()
		return workspace.Terrain:ReadVoxels(Region3.new(Vector3.new(vx, -16, vz), Vector3.new(vx + 4, 72, vz + 4)), 4)
	end)
	if not ok or not mats or not mats[1] then return nil end
	local col, ocol = mats[1], occ[1]
	for iy = #col, 1, -1 do
		local m = col[iy][1]
		if m ~= Enum.Material.Air and ocol[iy][1] > 0 then
			local y0 = -16 + (iy - 1) * 4
			return y0 + ocol[iy][1] * 4, m == Enum.Material.Water
		end
	end
	return nil
end

local fails = 0
local function groundAt(x, z)
	local h, water = terrainHeight(x, z)
	if not h then fails += 1 return nil end
	if water then return nil end
	return Vector3.new(x, h, z)
end

local function alive(player)
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if h and r and h.Health > 0 then return r end
	return nil
end

local function nearestPlayer(pos, range)
	local best, bestD
	for _, pl in ipairs(Players:GetPlayers()) do
		local r = alive(pl)
		if r then
			local d = (r.Position - pos).Magnitude
			if d <= range and (not bestD or d < bestD) then best, bestD = pl, d end
		end
	end
	return best, bestD
end

local function count(kind)
	local n = 0
	for _, s in pairs(mobs) do
		if s.kind == kind and not s.dead then n += 1 end
	end
	return n
end

---------------------------------------------------------------- spawn / damage / death
function Mobs.spawn(kind, at, level, cave)
	local def = DEFS[kind]
	level = math.clamp(math.floor(level or 1), 1, 99)
	local m, hrp, hum
	if kind == "zombie" or kind == "ghoul" then m, hrp, hum = zombie(def, at, kind)
	elseif kind == "guardian" or kind == "golem" or kind == "magma" then m, hrp, hum = guardian(def, at, kind)
	elseif kind == "spider" or kind == "crawler" then m, hrp, hum = spider(def, at, kind)
	elseif kind == "bat" then m, hrp, hum = bat(def, at)
	elseif kind == "scorpion" or kind == "scorpionking" or kind == "crab" or kind == "crabking" then m, hrp, hum = scorpion(kind, def, at)
	elseif kind == "yeti" then m, hrp, hum = yeti(def, at, kind)
	elseif kind == "gorilla" then m, hrp, hum = gorilla(def, at)
	elseif kind == "turtle" then m, hrp, hum = turtle(def, at)
	elseif kind == "snake" then m, hrp, hum = snake(def, at)
	elseif kind == "bandit" or kind == "banditlord" then m, hrp, hum = human(kind, def, at)
	else m, hrp, hum = quadruped(kind, def, at) end
	local L = level - 1
	local maxHp = math.floor(def.hp * (1 + 0.10 * L))
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Level", level)
	m:SetAttribute("HP", maxHp)
	m:SetAttribute("MaxHP", maxHp)
	if def.boss then m:SetAttribute("Boss", true) end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = folder
	pcall(function() hrp:SetNetworkOwner(nil) end)
	mobs[m] = { kind = kind, def = def, hp = maxHp, level = level, lift = hrp:GetAttribute("Lift"), dest = nil, bob = rng:NextNumber(0, 6),
		ap = hrp:FindFirstChildOfClass("AlignPosition"), ao = hrp:FindFirstChildOfClass("AlignOrientation"), at = hrp.Position, pace = 1,
		dmg = (def.dmg or 0) * (1 + 0.05 * L), xp = math.floor(def.xp * (1 + 0.15 * L)), coins = math.floor(def.coins * (1 + 0.1 * L)), hrp = hrp, hum = hum, nextWander = 0, nextAttack = 0, scaredUntil = 0, rootedUntil = 0, target = nil, born = os.clock() }
	if cave then
		local st = mobs[m]
		st.cave, st.caveId, st.home = not cave.surface, cave.id, at
		st.lift = st.hrp.Position.Y - at.Y
	end
	return m
end

local function kill(m, s, player)
	s.dead = true
	s.dest = nil
	if s.ap then s.ap.Enabled = false end
	if s.ao then s.ao.Enabled = false end
	s.hrp.Anchored = true
	m:SetAttribute("HP", 0)
	if player and player.Parent then
		local def = s.def
		if ctx.killed then pcall(ctx.killed, player, s.kind) end
		ctx.reward(player, s.xp, s.coins)
		local sp = 0
		if def.boss then
			sp = (def.tier or 1) + 1 + math.floor(s.level / 10)
		elseif rng:NextNumber() < 0.01 then
			sp = 1
		end
		if sp > 0 then ctx.addSp(player, sp) end
		local over = {}
		local double = ctx.lucky(player, 0.03)
		for _, d in ipairs(def.drops) do
			if rng:NextNumber() < d[4] then
				local n = rng:NextInteger(d[2], d[3]) * (double and 2 or 1)
				local rest = ctx.giveItem(player, { id = d[1], n = n })
				if n - rest > 0 then ctx.notify(player, "picked", d[1], n - rest) end
				if rest > 0 then table.insert(over, { id = d[1], n = rest }) end
			end
		end
		if #over > 0 then ctx.drop(s.hrp.Position, over, player.UserId) end
		if def.boss then
			ctx.broadcast("bossDown", s.kind)
			if ctx.feed then ctx.feed("bossDown", s.kind, player.DisplayName) end
		end
	end
	ctx.fx("mobDie", s.hrp.Position, s.kind)
	m:PivotTo(m:GetPivot() * CFrame.Angles(0, 0, math.rad(80)))
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p ~= s.hrp then
			TweenService:Create(p, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		end
	end
	task.delay(1.3, function()
		mobs[m] = nil
		m:Destroy()
	end)
end

function Mobs.damage(m, amount, player)
	local s = mobs[m]
	if not s or s.dead then return false end
	s.hp -= amount
	m:SetAttribute("HP", math.max(0, s.hp))
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(255, 80, 70)
	hl.FillTransparency = 0.45
	hl.OutlineTransparency = 1
	hl.Parent = m
	task.delay(0.15, function() hl:Destroy() end)
	ctx.fx("hitMob", s.hrp.Position, s.kind)
	if s.def.flee then
		s.scaredUntil = os.clock() + 7
		s.target = player
	else
		s.target = player
	end
	if s.hp <= 0 then kill(m, s, player) end
	return true
end

function Mobs.modelOf(part)
	local cur = part
	while cur and cur.Parent ~= folder do cur = cur.Parent end
	if cur and mobs[cur] then return cur end
	return nil
end

function Mobs.folder() return folder end

---------------------------------------------------------------- movement (kinematic, follows the ground)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

local function moveStep(s, dt)
	if not s.dest then return end
	local p = s.at
	local flat = Vector3.new(s.dest.X - p.X, 0, s.dest.Z - p.Z)
	local d = flat.Magnitude
	if d < 1.5 then s.dest = nil return end
	local speed = (s.speed or s.def.speed) * (s.pace or 1)
	local np = p + flat.Unit * math.min(d, speed * dt)
	local gh, water
	if s.cave then
		local cur = p.Y - s.lift
		gh = Ground.floor(np.X, cur + 2.5, np.Z)
		if gh and math.abs(gh - cur) > 4.5 then gh = nil end
	else
		gh, water = terrainHeight(np.X, np.Z)
	end
	if not gh or water then
		s.dest = nil
		return
	end
	s.bob += dt * speed * 0.9
	local y = gh + s.lift + math.abs(math.sin(s.bob)) * 0.18
	local pos = Vector3.new(np.X, y, np.Z)
	s.at = pos
	if s.ap then s.ap.Position = pos end
	if s.ao then s.ao.CFrame = CFrame.lookAt(Vector3.new(), flat.Unit) end
end

---------------------------------------------------------------- AI
local function wander(s, now)
	if now < s.nextWander then return end
	s.nextWander = now + rng:NextNumber(3, 7)
	local p = s.hrp.Position
	if s.home then p = s.home end
	local spread = s.home and 14 or 30
	local tx = math.clamp(p.X + rng:NextNumber(-spread, spread), -MAP_HALF, MAP_HALF)
	local tz = math.clamp(p.Z + rng:NextNumber(-spread, spread), -MAP_HALF, MAP_HALF)
	s.dest = Vector3.new(tx, p.Y, tz)
	s.pace = 0.35
end

local stepOne
local function step()
	for m, s in pairs(mobs) do
		if not s.dead and m.Parent then
			local ok, err = pcall(stepOne, m, s)
			if not ok then Debug.log("mobs.one", s.kind .. ": " .. tostring(err)) end
		end
	end
end

function stepOne(m, s)
	local now = os.clock()
	local night = ReplicatedStorage:GetAttribute("Night") == true
	do
		do
			local pos = s.hrp.Position
			local def = s.def
			s.speed = (now < s.rootedUntil) and 0 or def.speed
			-- traps
			for _, trap in ipairs(traps:GetChildren()) do
				local tp = trap:GetPivot().Position
				if (Vector3.new(tp.X, pos.Y, tp.Z) - pos).Magnitude < 3.5 + (def.boss and 4 or 0) then
					local owner = trap:GetAttribute("Owner") and Players:GetPlayerByUserId(trap:GetAttribute("Owner"))
					trap:Destroy()
					s.rootedUntil = now + 4
					Mobs.damage(m, def.boss and 120 or 60, owner)
					break
				end
			end
			if s.dead then return end
			if def.flee then
				local pl, d = nearestPlayer(pos, 22)
				local threat = (now < s.scaredUntil and s.target and alive(s.target)) or (pl and alive(pl))
				if threat and (d or 0) < 30 then
					local away = pos - threat.Position
					away = Vector3.new(away.X, 0, away.Z)
					if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
					s.dest = pos + away.Unit * 30
					s.pace = 1
				else
					wander(s, now)
				end
			else
				local tr = s.target and alive(s.target)
				if not tr or (tr.Position - pos).Magnitude > math.max(def.aggro, 30) * 1.6 then
					s.target = nil
					tr = nil
					if not def.neutral then
						local pl = nearestPlayer(pos, def.aggro)
						s.target = pl
						tr = pl and alive(pl)
					end
				end
				if tr and s.target then
					local d = (tr.Position - pos).Magnitude
					if d > def.reach * 0.7 then s.dest = tr.Position s.pace = 1 else s.dest = nil end
					if d <= def.reach + (def.boss and 2 or 0) and now >= s.nextAttack then
						s.nextAttack = now + (def.boss and 1.8 or 1.2)
						ctx.fx("mobAttack", pos, s.kind)
						ctx.hurt(s.target, s.dmg, s.kind)
					end
				else
					wander(s, now)
				end
			end
			-- creatures with a home (caves, bandit camps) stay near it
			if s.home and (pos - s.home).Magnitude > 75 then
				s.target = nil
				s.dest = s.home
				s.pace = 1
			end
			-- despawn
			local near = nearestPlayer(pos, s.caveId and 160 or 280)
			if s.caveId and not near then
				mobs[m] = nil
				m:Destroy()
				return
			end
			if (not near and not def.boss) or (def.night and not night and now - s.born > 5) then
				mobs[m] = nil
				m:Destroy()
			end
		end
	end
end

local lastBoss = { alpha = os.clock(), guardian = os.clock() }

-- level for a spot: average power of the players around it
local function levelAt(pos)
	local sum, n = 0, 0
	for _, pl in ipairs(Players:GetPlayers()) do
		local r = alive(pl)
		if r and (r.Position - pos).Magnitude < 240 then
			sum += ctx.power(pl)
			n += 1
		end
	end
	local d = math.max(math.abs(pos.X), math.abs(pos.Z))
	local regionBonus = math.max(0, d - 560) / 110 -- the outer regions are tougher (up to about +9)
	if n == 0 then return math.max(1, math.floor(1 + regionBonus)) end
	return math.max(1, math.floor(sum / n * rng:NextNumber(0.8, 1.05) + regionBonus + 0.5))
end

local function spawnNear(kind, r, minD, maxD, bonus)
	local a = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(minD, maxD)
	local x = math.clamp(r.Position.X + math.cos(a) * dist, -MAP_HALF, MAP_HALF)
	local z = math.clamp(r.Position.Z + math.sin(a) * dist, -MAP_HALF, MAP_HALF)
	local g = groundAt(x, z)
	if not g then return nil end
	return Mobs.spawn(kind, g, levelAt(g) + (bonus or 0)), g
end

-- what lives where (caps are per nearby player)
local BIOME_MOBS = {
	forest = { day = { rabbit = 3, deer = 2, boar = 2, wolf = 2, bear = 1, fox = 2 }, night = { zombie = 4, spider = 3, wolf = 2 } },
	hills = { day = { deer = 3, boar = 3, ram = 2, wolf = 2, bear = 1, bandit = 1 }, night = { zombie = 3, spider = 3, wolf = 2 } },
	snow = { day = { hare = 4, snowwolf = 3, polarbear = 1, mammoth = 1 }, night = { snowwolf = 4, zombie = 2, polarbear = 1 } },
	desert = { day = { camel = 3, scorpion = 3, hyena = 2, bandit = 1 }, night = { scorpion = 4, spider = 3, hyena = 3 } },
	mountains = { day = { goat = 4, wolf = 2, bear = 1, puma = 1 }, night = { wolf = 3, zombie = 2, puma = 1 } },
	beach = { day = { turtle = 3, crab = 3 }, night = { crab = 4, zombie = 3 } },
	jungle = { day = { monkey = 3, snake = 3, tiger = 1, bandit = 1 }, night = { spider = 4, snake = 3, tiger = 2 } },
	volcano = { day = { lavalizard = 3, ashwolf = 2 }, night = { ashwolf = 3, lavalizard = 3, zombie = 2 } },
}
local BOSS = { forest = "alpha", hills = "alpha", snow = "yeti", desert = "scorpionking", mountains = "guardian", beach = "crabking", jungle = "gorilla", volcano = "magma" }
local bossTimer = {}

local function countNear(kind, pos, radius)
	local n = 0
	for _, s in pairs(mobs) do
		if s.kind == kind and not s.dead and (s.hrp.Position - pos).Magnitude < radius then n += 1 end
	end
	return n
end

local function populate()
	local night = ReplicatedStorage:GetAttribute("Night") == true
	for _, pl in ipairs(Players:GetPlayers()) do
		local r = alive(pl)
		if r then
			if ctx.seen then
				for _, st in pairs(mobs) do
					if not st.dead and (st.hrp.Position - r.Position).Magnitude < 45 then pcall(ctx.seen, pl, st.kind) end
				end
			end
			-- one spawn attempt per player per tick, in the biome of the chosen spot
			local a = rng:NextNumber(0, math.pi * 2)
			local dist = rng:NextNumber(70, 140)
			local x = math.clamp(r.Position.X + math.cos(a) * dist, -MAP_HALF, MAP_HALF)
			local z = math.clamp(r.Position.Z + math.sin(a) * dist, -MAP_HALF, MAP_HALF)
			local biome = Biomes.at(x, z)
			local list = BIOME_MOBS[biome][night and "night" or "day"]
			local options = {}
			for kind, cap in pairs(list) do
				if countNear(kind, r.Position, 220) < cap then table.insert(options, kind) end
			end
			if #options > 0 and not Mobs.safe(Vector3.new(x, 0, z), 40) then
				local g = groundAt(x, z)
				if g then
					local kind = options[rng:NextInteger(1, #options)]
					Mobs.spawn(kind, g, levelAt(g))
				end
			end
			-- region boss
			local here = Biomes.at(r.Position.X, r.Position.Z)
			local boss = BOSS[here]
			local key = pl.UserId .. boss
			bossTimer[key] = bossTimer[key] or os.clock()
			if count(boss) == 0 and os.clock() - bossTimer[key] > 420 and rng:NextNumber() < 0.04 then
				local m, g = spawnNear(boss, r, 80, 110, 3)
				if m then
					bossTimer[key] = os.clock()
					ctx.broadcast("bossSpawn", boss)
					if ctx.feed then ctx.feed("bossSpawn", boss) end
					if boss == "alpha" then
						for _ = 1, 2 do Mobs.spawn("wolf", g + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)), levelAt(g)) end
					end
				end
			end
		end
	end
end

-- caves: each has spawn spots (generated with the map) and its own creature list
local CAVE_MOBS = {
	normal = { bat = 3, crawler = 2 },
	long = { bat = 3, crawler = 2, ghoul = 2 },
	wide = { bat = 4, crawler = 3, ghoul = 3 },
}
local caveBoss = {}
CAVE_MOBS.bandit = { bandit = 4 }
local function cavePopulate()
	local list = {}
	for _, n in ipairs({ "Caves", "BanditCamps" }) do
		local f = workspace:FindFirstChild(n)
		if f then for _, c in ipairs(f:GetChildren()) do table.insert(list, c) end end
	end
	for _, cave in ipairs(list) do
		local surface = cave:GetAttribute("Type") == "bandit"
		local spotsF = cave:FindFirstChild("Spots")
		local list = CAVE_MOBS[cave:GetAttribute("Type") or ""]
		if spotsF and list then
			local spots = spotsF:GetChildren()
			-- is anyone close to this cave?
			local nearPl
			for _, sp in ipairs(spots) do
				nearPl = nearestPlayer(sp.Position, 90)
				if nearPl then break end
			end
			if nearPl then
				local r = alive(nearPl)
				local counts, total = {}, 0
				for _, st in pairs(mobs) do
					if st.caveId == cave and not st.dead then
						counts[st.kind] = (counts[st.kind] or 0) + 1
						total += 1
					end
				end
				local options = {}
				for kind, cap in pairs(list) do
					if (counts[kind] or 0) < cap then table.insert(options, kind) end
				end
				if #options > 0 and r then
					local cand = {}
					for _, sp in ipairs(spots) do
						local d = (sp.Position - r.Position).Magnitude
						if d > 22 and d < 110 then table.insert(cand, sp) end
					end
					if #cand > 0 then
						local sp = cand[rng:NextInteger(1, #cand)]
						local kind = options[rng:NextInteger(1, #options)]
						Mobs.spawn(kind, sp.Position, levelAt(sp.Position) + 2, { id = cave, surface = surface })
					end
				end
				-- the rock giant sleeps in the wide caves
				local bossKind = (cave:GetAttribute("Type") == "wide" and "golem") or (surface and "banditlord") or nil
				if bossKind and r then
					caveBoss[cave] = caveBoss[cave] or (os.clock() - 9999)
					local bossAlive = false
					for _, st in pairs(mobs) do if st.caveId == cave and st.kind == bossKind and not st.dead then bossAlive = true end end
					local lair = cave:GetAttribute("Center")
					if not bossAlive and lair and os.clock() - caveBoss[cave] > 600 and (r.Position - lair).Magnitude < 70 then
						caveBoss[cave] = os.clock()
						Mobs.spawn(bossKind, lair, levelAt(lair) + 4, { id = cave, surface = surface })
						ctx.broadcast("bossSpawn", bossKind)
						if ctx.feed then ctx.feed("bossSpawn", bossKind) end
					end
				end
			end
		end
	end
end

-- villages and the camp keep predators out
local safeZones = nil
function Mobs.safe(pos, pad)
	if not safeZones then
		safeZones = { { Vector3.new(0, 0, 0), 70 } }
		local v = workspace:FindFirstChild("Villages")
		for _, m in ipairs(v and v:GetChildren() or {}) do
			local c, r = m:GetAttribute("Center"), m:GetAttribute("Radius")
			if c and r then table.insert(safeZones, { c, r }) end
		end
	end
	for _, z in ipairs(safeZones) do
		if (Vector3.new(pos.X - z[1].X, 0, pos.Z - z[1].Z)).Magnitude < z[2] + (pad or 0) then return true end
	end
	return false
end

-- living creatures that attack people (guards go after these)
function Mobs.hostileNear(pos, radius)
	local out = {}
	for m, st in pairs(mobs) do
		if not st.dead and not st.def.flee and not st.def.neutral and (st.hrp.Position - pos).Magnitude < radius then
			table.insert(out, { model = m, pos = st.hrp.Position, kind = st.kind })
		end
	end
	return out
end

-- a still copy of every creature for the index (clients show them in 3D)
local function buildTemplates()
	local f = ReplicatedStorage:FindFirstChild("MobTemplates") or Instance.new("Folder")
	f.Name = "MobTemplates"
	f:ClearAllChildren()
	for kind in pairs(DEFS) do
		local ok, m = pcall(Mobs.spawn, kind, Vector3.new(0, -800, 0), 1)
		if ok and m then
			mobs[m] = nil
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("AlignPosition") or d:IsA("AlignOrientation") or d:IsA("BillboardGui") then d:Destroy()
				elseif d:IsA("BasePart") then d.Anchored = true end
			end
			m:PivotTo(CFrame.new())
			m.Parent = f
		end
	end
	f.Parent = ReplicatedStorage
end

function Mobs.start(c)
	ctx = c
	folder = Instance.new("Folder")
	folder.Name = "Mobs"
	folder.Parent = workspace
	pcall(buildTemplates)
	traps = workspace:FindFirstChild("Traps") or Instance.new("Folder")
	traps.Name = "Traps"
	traps.Parent = workspace
	task.spawn(function()
		while true do
			task.wait(0.3)
			local ok, err = pcall(step)
			if not ok then warn("Mobs step:", err) Debug.log("mobs.step", err) end
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.05)
			local now = os.clock()
			local dt = math.min(now - last, 0.2)
			last = now
			for _, s in pairs(mobs) do
				if not s.dead then
					local ok, err = pcall(moveStep, s, dt)
					if not ok then Debug.log("mobs.move", err) break end
				end
			end
		end
	end)
	task.spawn(function()
		local reports = 0
		while true do
			task.wait(4)
			local ok, err = pcall(populate)
			if not ok then warn("Mobs populate:", err) Debug.log("mobs.populate", err) end
			if reports < 6 and #Players:GetPlayers() > 0 then
				reports += 1
				local counts = {}
				for _, st in pairs(mobs) do counts[st.kind] = (counts[st.kind] or 0) + 1 end
				local parts = {}
				for k, v in pairs(counts) do table.insert(parts, k .. "=" .. v) end
				Debug.log("mobs.count", table.concat(parts, " ") .. " players=" .. #Players:GetPlayers() .. " groundFails=" .. fails)
			end
		end
	end)
end

function Mobs.traps() return traps end

return Mobs
