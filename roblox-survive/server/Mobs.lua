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

local function quadruped(kind, def, at)
	local s = def.size
	local m, hrp, hum = base(kind, Vector3.new(1.6, 1.4, 2.8) * s, def.hip, at)
	local col = def.color
	local dark = col:Lerp(Color3.new(0, 0, 0), 0.25)
	vis(m, hrp, Vector3.new(1.6, 1.4, 2.8) * s, CFrame.new(), col)
	vis(m, hrp, Vector3.new(1.15, 1.1, 1.2) * s, CFrame.new(0, 0.6 * s, -1.75 * s), col)
	vis(m, hrp, Vector3.new(0.7, 0.6, 0.7) * s, CFrame.new(0, 0.42 * s, -2.55 * s), dark)
	for _, x in ipairs({ -0.55, 0.55 }) do
		for _, z in ipairs({ -0.95, 0.95 }) do
			local phase = ((x < 0) == (z < 0)) and 0 or math.pi
			limb(m, hrp, Vector3.new(0.42 * s, def.hip + 0.6 * s, 0.42 * s), CFrame.new(x * s, -0.1 * s, z * s), dark, phase)
		end
	end
	if kind == "camel" then
		vis(m, hrp, Vector3.new(1.0, 0.9, 1.1) * s, CFrame.new(0, 0.95 * s, 0.2 * s), col:Lerp(Color3.new(0, 0, 0), 0.08), BALL)
		vis(m, hrp, Vector3.new(0.5, 1.5, 0.5) * s, CFrame.new(0, 1.0 * s, -1.55 * s) * CFrame.Angles(math.rad(25), 0, 0), col)
	elseif kind == "goat" then
		for _, x in ipairs({ -1, 1 }) do
			vis(m, hrp, Vector3.new(0.14, 0.8, 0.14) * s, CFrame.new(x * 0.25 * s, 1.35 * s, -1.45 * s) * CFrame.Angles(math.rad(35), 0, math.rad(x * -12)), Color3.fromRGB(90, 80, 70))
		end
	elseif kind == "polarbear" then
		for _, x in ipairs({ -1, 1 }) do
			vis(m, hrp, Vector3.new(0.42, 0.42, 0.42) * s, CFrame.new(x * 0.42 * s, 1.22 * s, -1.65 * s), col, BALL)
		end
		vis(m, hrp, Vector3.new(1.75, 1.0, 1.6) * s, CFrame.new(0, 0.55 * s, -0.7 * s), col)
	elseif kind == "boar" then
		for _, x in ipairs({ -1, 1 }) do
			vis(m, hrp, Vector3.new(0.15, 0.6, 0.15) * s, CFrame.new(x * 0.3 * s, 0.25 * s, -2.75 * s) * CFrame.Angles(math.rad(-30), 0, math.rad(x * 15)), Color3.fromRGB(240, 232, 210))
		end
		vis(m, hrp, Vector3.new(0.5, 0.5, 2.6) * s, CFrame.new(0, 0.75 * s, 0), dark)
	elseif kind == "bear" then
		for _, x in ipairs({ -1, 1 }) do
			vis(m, hrp, Vector3.new(0.45, 0.45, 0.45) * s, CFrame.new(x * 0.42 * s, 1.25 * s, -1.65 * s), dark, BALL)
		end
		vis(m, hrp, Vector3.new(1.75, 1.0, 1.6) * s, CFrame.new(0, 0.55 * s, -0.7 * s), col)
	elseif kind == "alpha" then
		vis(m, hrp, Vector3.new(0.3, 0.55, 0.2) * s, CFrame.new(-0.35 * s, 1.35 * s, -1.65 * s), dark)
		vis(m, hrp, Vector3.new(0.3, 0.55, 0.2) * s, CFrame.new(0.35 * s, 1.35 * s, -1.65 * s), dark)
		vis(m, hrp, Vector3.new(1.9, 1.5, 1.2) * s, CFrame.new(0, 0.35 * s, -1.0 * s), Color3.fromRGB(235, 235, 240), nil, Enum.Material.Fabric)
		vis(m, hrp, Vector3.new(0.35, 0.35, 1.5) * s, CFrame.new(0, 0.3 * s, 1.95 * s) * CFrame.Angles(math.rad(25), 0, 0), col)
	elseif kind == "rabbit" or kind == "hare" then
		vis(m, hrp, Vector3.new(0.25, 1.1, 0.16) * s, CFrame.new(-0.25 * s, 1.55 * s, -1.6 * s), col)
		vis(m, hrp, Vector3.new(0.25, 1.1, 0.16) * s, CFrame.new(0.25 * s, 1.55 * s, -1.6 * s), col)
		vis(m, hrp, Vector3.new(0.6, 0.6, 0.6) * s, CFrame.new(0, 0.3 * s, 1.5 * s), Color3.fromRGB(245, 240, 235), BALL)
	elseif kind == "deer" then
		for _, x in ipairs({ -1, 1 }) do
			vis(m, hrp, Vector3.new(0.12, 1.2, 0.12) * s, CFrame.new(x * 0.3 * s, 1.6 * s, -1.6 * s) * CFrame.Angles(0, 0, math.rad(-x * 25)), Color3.fromRGB(220, 200, 170))
			vis(m, hrp, Vector3.new(0.1, 0.6, 0.1) * s, CFrame.new(x * 0.55 * s, 1.95 * s, -1.75 * s) * CFrame.Angles(math.rad(-30), 0, math.rad(-x * 50)), Color3.fromRGB(220, 200, 170))
		end
		vis(m, hrp, Vector3.new(0.4, 0.4, 0.3) * s, CFrame.new(0, 0.4 * s, 1.5 * s), Color3.fromRGB(245, 240, 235))
	elseif kind == "fox" then
		for _, x in ipairs({ -1, 1 }) do vis(m, hrp, Vector3.new(0.3, 0.55, 0.2) * s, CFrame.new(x * 0.32 * s, 1.35 * s, -1.65 * s), dark) end
		vis(m, hrp, Vector3.new(0.7, 0.7, 1.8) * s, CFrame.new(0, 0.2 * s, 2.1 * s) * CFrame.Angles(math.rad(20), 0, 0), col, BALL, Enum.Material.Fabric)
		vis(m, hrp, Vector3.new(0.5, 0.5, 0.6) * s, CFrame.new(0, -0.1 * s, 2.9 * s), Color3.fromRGB(240, 236, 228), BALL)
	elseif kind == "ram" then
		vis(m, hrp, Vector3.new(1.9, 1.6, 3.0) * s, CFrame.new(0, 0.1 * s, 0), Color3.fromRGB(230, 224, 210), nil, Enum.Material.Fabric)
		for _, x in ipairs({ -1, 1 }) do
			vis(m, hrp, Vector3.new(0.5, 0.9, 0.9) * s, CFrame.new(x * 0.62 * s, 0.95 * s, -1.75 * s), Color3.fromRGB(120, 100, 80), BALL)
			vis(m, hrp, Vector3.new(0.35, 0.35, 0.8) * s, CFrame.new(x * 0.7 * s, 0.6 * s, -2.2 * s) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(120, 100, 80))
		end
	elseif kind == "mammoth" then
		vis(m, hrp, Vector3.new(1.9, 1.7, 3.0) * s, CFrame.new(0, 0.2 * s, 0), col:Lerp(Color3.new(0, 0, 0), 0.1), nil, Enum.Material.Fabric)
		vis(m, hrp, Vector3.new(0.45, 1.8, 0.45) * s, CFrame.new(0, -0.2 * s, -2.75 * s) * CFrame.Angles(math.rad(-12), 0, 0), col, nil, Enum.Material.Fabric)
		for _, x in ipairs({ -1, 1 }) do
			vis(m, hrp, Vector3.new(0.22, 0.22, 1.6) * s, CFrame.new(x * 0.4 * s, -0.1 * s, -2.7 * s) * CFrame.Angles(math.rad(30), math.rad(x * 12), 0), Color3.fromRGB(240, 232, 210))
			vis(m, hrp, Vector3.new(0.5, 0.9, 0.12) * s, CFrame.new(x * 0.65 * s, 0.6 * s, -1.6 * s), col, nil, Enum.Material.Fabric)
		end
	elseif kind == "hyena" then
		vis(m, hrp, Vector3.new(1.5, 1.1, 1.3) * s, CFrame.new(0, 0.35 * s, -0.8 * s), col:Lerp(Color3.new(0, 0, 0), 0.1), nil, Enum.Material.Fabric)
		for i = 1, 6 do vis(m, hrp, Vector3.new(0.35, 0.35, 0.35) * s, CFrame.new((i % 2 == 0 and 0.75 or -0.75) * s, 0.2 * s, (-1 + i * 0.32) * s), Color3.fromRGB(70, 56, 40), BALL) end
		for _, x in ipairs({ -1, 1 }) do vis(m, hrp, Vector3.new(0.35, 0.4, 0.2) * s, CFrame.new(x * 0.35 * s, 1.3 * s, -1.65 * s), dark, BALL) end
	elseif kind == "puma" or kind == "tiger" then
		vis(m, hrp, Vector3.new(0.3, 0.3, 2.2) * s, CFrame.new(0, 0.2 * s, 2.3 * s) * CFrame.Angles(math.rad(15), 0, 0), col)
		for _, x in ipairs({ -1, 1 }) do vis(m, hrp, Vector3.new(0.3, 0.3, 0.2) * s, CFrame.new(x * 0.35 * s, 1.25 * s, -1.65 * s), dark, BALL) end
		if kind == "tiger" then
			for i = -2, 3 do vis(m, hrp, Vector3.new(1.65, 1.45, 0.18) * s, CFrame.new(0, 0, i * 0.45 * s), Color3.fromRGB(30, 26, 24)) end
			vis(m, hrp, Vector3.new(1.2, 0.5, 2.2) * s, CFrame.new(0, -0.5 * s, 0), Color3.fromRGB(240, 232, 220))
		end
	elseif kind == "turtle" then
		vis(m, hrp, Vector3.new(2.6, 1.5, 3.4) * s, CFrame.new(0, 0.35 * s, 0.1 * s), Color3.fromRGB(110, 86, 50), BALL)
		vis(m, hrp, Vector3.new(2.7, 0.3, 3.5) * s, CFrame.new(0, -0.1 * s, 0.1 * s), Color3.fromRGB(80, 64, 40))
	elseif kind == "monkey" then
		for _, x in ipairs({ -1, 1 }) do vis(m, hrp, Vector3.new(0.2, 0.45, 0.45) * s, CFrame.new(x * 0.62 * s, 0.6 * s, -1.75 * s), Color3.fromRGB(210, 170, 130), BALL) end
		vis(m, hrp, Vector3.new(0.25, 0.25, 2.6) * s, CFrame.new(0, 1.0 * s, 2.0 * s) * CFrame.Angles(math.rad(-50), 0, 0), col)
		vis(m, hrp, Vector3.new(0.7, 0.5, 0.2) * s, CFrame.new(0, 0.42 * s, -2.9 * s), Color3.fromRGB(210, 170, 130))
	elseif kind == "lavalizard" then
		for i = 1, 4 do vis(m, hrp, Vector3.new(1.2 - i * 0.22, 0.7 - i * 0.1, 1.0) * s, CFrame.new(0, -0.1 * s, (1.4 + i * 0.9) * s), col) end
		for i = 1, 7 do vis(m, hrp, Vector3.new(0.3, 0.3, 0.3) * s, CFrame.new((i % 2 == 0 and 0.55 or -0.55) * s, 0.65 * s, (-1.2 + i * 0.4) * s), def.glow, BALL, Enum.Material.Neon) end
	elseif kind == "wolf" or kind == "snowwolf" or kind == "ashwolf" then
		if kind == "ashwolf" then
			for i = 1, 5 do vis(m, hrp, Vector3.new(0.25, 0.25, 0.25) * s, CFrame.new((i % 2 == 0 and 0.5 or -0.5) * s, 0.6 * s, (-1 + i * 0.45) * s), def.glow, BALL, Enum.Material.Neon) end
		end
		vis(m, hrp, Vector3.new(0.3, 0.5, 0.2) * s, CFrame.new(-0.35 * s, 1.35 * s, -1.65 * s), dark)
		vis(m, hrp, Vector3.new(0.3, 0.5, 0.2) * s, CFrame.new(0.35 * s, 1.35 * s, -1.65 * s), dark)
		vis(m, hrp, Vector3.new(0.3, 0.3, 1.4) * s, CFrame.new(0, 0.3 * s, 1.9 * s) * CFrame.Angles(math.rad(25), 0, 0), col)
	end
	return m, hrp, hum
end

local function zombie(def, at, kind)
	local m, hrp, hum = base(kind or "zombie", Vector3.new(2, 2, 1), 2, at)
	local skin = def.color
	local cloth = Color3.fromRGB(70, 66, 80)
	vis(m, hrp, Vector3.new(2, 2, 1), CFrame.new(), cloth)
	vis(m, hrp, Vector3.new(1.4, 1.45, 1.4), CFrame.new(0, 1.7, 0), skin, BALL)
	for _, x in ipairs({ -1.25, 1.25 }) do
		vis(m, hrp, Vector3.new(0.6, 0.6, 2.1), CFrame.new(x, 0.55, -0.85), cloth)
		vis(m, hrp, Vector3.new(0.6, 0.6, 0.6), CFrame.new(x, 0.55, -2.0), skin, BALL)
	end
	for _, x in ipairs({ -0.5, 0.5 }) do
		limb(m, hrp, Vector3.new(0.85, 2, 0.85), CFrame.new(x, -1, 0), Color3.fromRGB(56, 50, 46), x < 0 and 0 or math.pi)
	end
	return m, hrp, hum
end

local function spider(def, at, kind)
	local m, hrp, hum = base(kind or "spider", Vector3.new(2.2, 1, 2.6), 1.2, at)
	local col = def.color
	vis(m, hrp, Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 0.1, 0.9), col, BALL)
	vis(m, hrp, Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 0.1, -0.7), col:Lerp(Color3.new(1, 1, 1), 0.08), BALL)
	vis(m, hrp, Vector3.new(0.9, 0.2, 0.9), CFrame.new(0, 1.2, 0.9), Color3.fromRGB(140, 40, 40))
	for _, x in ipairs({ -1, 1 }) do
		for i = 0, 3 do
			local z = -0.9 + i * 0.6
			vis(m, hrp, Vector3.new(2.0, 0.18, 0.18), CFrame.new(x * 1.3, 0.1, z) * CFrame.Angles(0, math.rad(x * (i - 1.5) * 12), math.rad(x * -25)), col)
			limb(m, hrp, Vector3.new(0.18, 1.6, 0.18), CFrame.new(x * 2.2, 0.2, z), col, (i % 2 == 0) == (x < 0) and 0 or math.pi)
		end
	end
	return m, hrp, hum
end

local function scorpion(kind, def, at)
	local s = def.size
	local m, hrp, hum = base(kind, Vector3.new(2.2, 0.8, 3) * s, 0.9 * s, at)
	local col, dark = def.color, def.color:Lerp(Color3.new(0, 0, 0), 0.25)
	vis(m, hrp, Vector3.new(2.0, 0.8, 2.8) * s, CFrame.new(), col)
	vis(m, hrp, Vector3.new(1.4, 0.6, 1.0) * s, CFrame.new(0, 0.05 * s, -1.7 * s), dark)
	for _, x in ipairs({ -1, 1 }) do
		vis(m, hrp, Vector3.new(0.35, 0.35, 1.4) * s, CFrame.new(x * 1.1 * s, 0, -2.0 * s) * CFrame.Angles(0, math.rad(x * -20), 0), col)
		vis(m, hrp, Vector3.new(0.7, 0.4, 0.9) * s, CFrame.new(x * 1.4 * s, 0, -2.8 * s), dark)
		for i = 0, 2 do
			limb(m, hrp, Vector3.new(0.2, 1.1, 0.2) * s, CFrame.new(x * 1.1 * s, -0.1 * s, (-0.8 + i * 0.8) * s) * CFrame.Angles(0, 0, math.rad(x * 30)), dark, (i % 2 == 0) == (x < 0) and 0 or math.pi)
		end
	end
	-- curled tail with a stinger
	if def.noTail then
		vis(m, hrp, Vector3.new(2.4, 0.5, 2.0) * s, CFrame.new(0, 0.45 * s, 0.2 * s), col:Lerp(Color3.new(1, 1, 1), 0.1))
		return m, hrp, hum
	end
	for i = 1, 4 do
		vis(m, hrp, Vector3.new(0.55, 0.55, 0.7) * s * (1 - i * 0.08), CFrame.new(0, (0.2 + i * 0.45) * s, (1.4 + i * 0.35 - (i > 2 and (i - 2) * 0.5 or 0)) * s), col)
	end
	vis(m, hrp, Vector3.new(0.2, 0.2, 0.7) * s, CFrame.new(0, 2.2 * s, 1.6 * s) * CFrame.Angles(math.rad(-50), 0, 0), Color3.fromRGB(40, 30, 26))
	return m, hrp, hum
end

local function bat(def, at)
	local m, hrp, hum = base("bat", Vector3.new(1.4, 1.1, 1.6), def.hip, at)
	local col = def.color
	vis(m, hrp, Vector3.new(1.3, 1.2, 1.6), CFrame.new(), col, BALL, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 0.35, -0.8), col, BALL, Enum.Material.Fabric)
	for _, x in ipairs({ -1, 1 }) do
		vis(m, hrp, Vector3.new(0.18, 0.5, 0.18), CFrame.new(x * 0.28, 0.9, -0.85) * CFrame.Angles(0, 0, math.rad(-x * 15)), col)
		-- wings hang sideways from the shoulders and flap around the body axis
		local joint = CFrame.fromMatrix(Vector3.new(x * 0.55, 0.2, 0), Vector3.new(0, 0, 1), Vector3.new(-x, 0, 0), Vector3.new(0, -x, 0))
		limb(m, hrp, Vector3.new(1.1, 2.4, 0.1), joint, col:Lerp(Color3.new(0, 0, 0), 0.3), x < 0 and 0 or math.pi, Enum.Material.Fabric)
	end
	return m, hrp, hum
end

local function snake(def, at)
	local m, hrp, hum = base("snake", Vector3.new(1, 0.8, 2), 0.1, at)
	local col = def.color
	vis(m, hrp, Vector3.new(1.1, 0.8, 1.3), CFrame.new(0, 0.1, -0.9), col:Lerp(Color3.new(0, 0, 0), 0.15), BALL)
	for i = 0, 8 do
		local x = math.sin(i * 0.9) * 0.7
		vis(m, hrp, Vector3.new(0.85 - i * 0.06, 0.6 - i * 0.03, 1.1), CFrame.new(x, -0.05, i * 0.85), i % 2 == 0 and col or Color3.fromRGB(200, 180, 70), BALL)
	end
	return m, hrp, hum
end

local function human(kind, def, at)
	local m, hrp, hum = base(kind, Vector3.new(2, 2, 1), 2, at)
	local skin, cloth = def.color, def.cloth
	local big = kind == "banditlord"
	vis(m, hrp, Vector3.new(2, 2, 1), CFrame.new(), cloth, nil, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 1.65, 0), skin, BALL)
	vis(m, hrp, Vector3.new(1.42, 0.5, 1.42), CFrame.new(0, 1.55, 0), Color3.fromRGB(40, 32, 30), BALL, Enum.Material.Fabric) -- mask
	vis(m, hrp, Vector3.new(1.5, 1.0, 1.5), CFrame.new(0, 2.05, 0.1), big and Color3.fromRGB(110, 30, 30) or Color3.fromRGB(60, 50, 44), BALL, Enum.Material.Fabric) -- hood
	vis(m, hrp, Vector3.new(2.1, 0.3, 1.1), CFrame.new(0, -0.75, 0), Color3.fromRGB(50, 36, 26), nil, Enum.Material.Fabric)
	if big then vis(m, hrp, Vector3.new(2.3, 3.2, 0.15), CFrame.new(0, -0.4, 0.62), Color3.fromRGB(130, 30, 30), nil, Enum.Material.Fabric) end
	for _, x in ipairs({ -1.25, 1.25 }) do
		limb(m, hrp, Vector3.new(0.75, 2, 0.75), CFrame.new(x, 0.9, 0), cloth, x < 0 and math.pi or 0, Enum.Material.Fabric)
	end
	for _, x in ipairs({ -0.5, 0.5 }) do
		limb(m, hrp, Vector3.new(0.85, 2, 0.85), CFrame.new(x, -1, 0), Color3.fromRGB(56, 48, 40), x < 0 and 0 or math.pi, Enum.Material.Fabric)
	end
	-- a blade in the right hand
	vis(m, hrp, Vector3.new(0.2, 0.3, 3.2), CFrame.new(1.4, -0.6, -1.4) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(190, 194, 200), nil, Enum.Material.Metal)
	if big then m:ScaleTo(1.4) end
	return m, hrp, hum
end

local function yeti(def, at, kind)
	local m, hrp, hum = base(kind or "yeti", Vector3.new(4.5, 5.5, 3), 4.6, at)
	local fur, dark = def.color, kind == "gorilla" and Color3.fromRGB(90, 90, 96) or Color3.fromRGB(170, 180, 200)
	vis(m, hrp, Vector3.new(4.5, 5.5, 3), CFrame.new(), fur, nil, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(3.0, 3.0, 3.0), CFrame.new(0, 3.9, -0.3), fur, BALL, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(4.7, 1.2, 3.2), CFrame.new(0, 1.8, 0), dark, nil, Enum.Material.Fabric)
	for _, x in ipairs({ -1, 1 }) do
		limb(m, hrp, Vector3.new(1.6, 5.5, 1.6), CFrame.new(x * 3.1, 2.2, 0), fur, x < 0 and 0 or math.pi, Enum.Material.Fabric)
		limb(m, hrp, Vector3.new(1.9, 4.6, 1.9), CFrame.new(x * 1.2, -2.7, 0), fur, x < 0 and math.pi or 0, Enum.Material.Fabric)
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
	elseif kind == "yeti" or kind == "gorilla" then m, hrp, hum = yeti(def, at, kind)
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
		if def.boss then ctx.broadcast("bossDown", s.kind) end
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
