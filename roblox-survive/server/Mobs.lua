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
local MAP_HALF = 740

local DEFS = {
	rabbit = { hp = 20, speed = 13.5, flee = true, size = 0.55, hip = 0.45, xp = 4, coins = 1, color = Color3.fromRGB(200, 186, 170), drops = { { "meat_raw", 1, 1, 1 }, { "hide", 1, 1, 0.3 } } },
	deer = { hp = 55, speed = 14.5, flee = true, size = 1.05, hip = 2.2, xp = 10, coins = 3, color = Color3.fromRGB(168, 118, 74), drops = { { "meat_raw", 1, 2, 1 }, { "hide", 1, 1, 0.8 } } },
	wolf = { hp = 70, speed = 13.5, aggro = 45, dmg = 8, reach = 4.5, size = 0.9, hip = 1.3, xp = 18, coins = 6, color = Color3.fromRGB(110, 112, 118), drops = { { "meat_raw", 1, 1, 1 }, { "hide", 1, 1, 0.7 } } },
	zombie = { hp = 85, speed = 8, aggro = 70, dmg = 12, reach = 4.2, night = true, xp = 22, coins = 8, color = Color3.fromRGB(110, 140, 96), drops = { { "bandage", 1, 1, 0.25 }, { "ammo", 4, 8, 0.15 }, { "arrow", 4, 8, 0.25 } } },
	boar = { hp = 90, speed = 11, neutral = true, aggro = 0, dmg = 10, reach = 4.5, size = 1.0, hip = 1.0, xp = 14, coins = 5, color = Color3.fromRGB(96, 70, 52), drops = { { "meat_raw", 1, 3, 1 }, { "hide", 1, 1, 0.6 } } },
	bear = { hp = 220, speed = 11, aggro = 35, dmg = 20, reach = 6, size = 1.7, hip = 1.6, xp = 45, coins = 15, color = Color3.fromRGB(88, 62, 44), drops = { { "meat_raw", 2, 4, 1 }, { "hide", 1, 3, 1 } } },
	spider = { hp = 45, speed = 12, aggro = 55, dmg = 7, reach = 4, night = true, xp = 12, coins = 4, color = Color3.fromRGB(40, 36, 44), drops = { { "arrow", 2, 5, 0.3 } } },
	alpha = { hp = 700, speed = 15, aggro = 70, dmg = 22, reach = 6, boss = true, tier = 1, size = 1.7, hip = 2.2, xp = 220, coins = 80, color = Color3.fromRGB(196, 198, 204), drops = { { "hide", 3, 5, 1 }, { "bow", 1, 1, 0.4 }, { "arrow", 10, 20, 1 } } },
	hare = { hp = 22, speed = 13.5, flee = true, size = 0.55, hip = 0.45, xp = 5, coins = 1, color = Color3.fromRGB(240, 240, 245), drops = { { "meat_raw", 1, 1, 1 }, { "hide", 1, 1, 0.4 } } },
	snowwolf = { hp = 95, speed = 14, aggro = 50, dmg = 10, reach = 4.8, size = 1.0, hip = 1.3, xp = 24, coins = 8, color = Color3.fromRGB(228, 230, 238), drops = { { "meat_raw", 1, 2, 1 }, { "hide", 1, 2, 0.8 } } },
	polarbear = { hp = 300, speed = 11.5, aggro = 38, dmg = 26, reach = 6.5, size = 1.9, hip = 1.7, xp = 60, coins = 20, color = Color3.fromRGB(240, 240, 244), drops = { { "meat_raw", 3, 5, 1 }, { "hide", 2, 3, 1 } } },
	camel = { hp = 90, speed = 13, flee = true, size = 1.4, hip = 2.6, xp = 12, coins = 4, color = Color3.fromRGB(196, 160, 110), drops = { { "meat_raw", 2, 3, 1 }, { "hide", 1, 2, 0.8 } } },
	goat = { hp = 60, speed = 14, flee = true, size = 0.9, hip = 1.6, xp = 9, coins = 3, color = Color3.fromRGB(205, 200, 190), drops = { { "meat_raw", 1, 2, 1 }, { "hide", 1, 1, 0.6 } } },
	scorpion = { hp = 95, speed = 12, aggro = 45, dmg = 13, reach = 5, size = 1, xp = 20, coins = 7, color = Color3.fromRGB(150, 96, 52), drops = { { "rifle_ammo", 2, 4, 0.12 }, { "gold", 1, 1, 0.1 } } },
	scorpionking = { hp = 1900, speed = 11, aggro = 85, dmg = 36, reach = 10, boss = true, tier = 2, size = 2.6, xp = 450, coins = 200, color = Color3.fromRGB(120, 70, 36), drops = { { "scimitar", 1, 1, 0.5 }, { "rifle", 1, 1, 0.25 }, { "gold", 3, 6, 1 } } },
	yeti = { hp = 2600, speed = 10, aggro = 90, dmg = 42, reach = 10, boss = true, tier = 3, xp = 600, coins = 260, color = Color3.fromRGB(236, 240, 248), drops = { { "ice_spear", 1, 1, 0.4 }, { "warm_coat", 1, 1, 0.5 }, { "diamond", 2, 4, 1 } } },
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
	elseif kind == "wolf" or kind == "snowwolf" then
		vis(m, hrp, Vector3.new(0.3, 0.5, 0.2) * s, CFrame.new(-0.35 * s, 1.35 * s, -1.65 * s), dark)
		vis(m, hrp, Vector3.new(0.3, 0.5, 0.2) * s, CFrame.new(0.35 * s, 1.35 * s, -1.65 * s), dark)
		vis(m, hrp, Vector3.new(0.3, 0.3, 1.4) * s, CFrame.new(0, 0.3 * s, 1.9 * s) * CFrame.Angles(math.rad(25), 0, 0), col)
	end
	return m, hrp, hum
end

local function zombie(def, at)
	local m, hrp, hum = base("zombie", Vector3.new(2, 2, 1), 2, at)
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

local function spider(def, at)
	local m, hrp, hum = base("spider", Vector3.new(2.2, 1, 2.6), 1.2, at)
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
	for i = 1, 4 do
		vis(m, hrp, Vector3.new(0.55, 0.55, 0.7) * s * (1 - i * 0.08), CFrame.new(0, (0.2 + i * 0.45) * s, (1.4 + i * 0.35 - (i > 2 and (i - 2) * 0.5 or 0)) * s), col)
	end
	vis(m, hrp, Vector3.new(0.2, 0.2, 0.7) * s, CFrame.new(0, 2.2 * s, 1.6 * s) * CFrame.Angles(math.rad(-50), 0, 0), Color3.fromRGB(40, 30, 26))
	return m, hrp, hum
end

local function yeti(def, at)
	local m, hrp, hum = base("yeti", Vector3.new(4.5, 5.5, 3), 4.6, at)
	local fur, dark = def.color, Color3.fromRGB(170, 180, 200)
	vis(m, hrp, Vector3.new(4.5, 5.5, 3), CFrame.new(), fur, nil, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(3.0, 3.0, 3.0), CFrame.new(0, 3.9, -0.3), fur, BALL, Enum.Material.Fabric)
	vis(m, hrp, Vector3.new(4.7, 1.2, 3.2), CFrame.new(0, 1.8, 0), dark, nil, Enum.Material.Fabric)
	for _, x in ipairs({ -1, 1 }) do
		limb(m, hrp, Vector3.new(1.6, 5.5, 1.6), CFrame.new(x * 3.1, 2.2, 0), fur, x < 0 and 0 or math.pi, Enum.Material.Fabric)
		limb(m, hrp, Vector3.new(1.9, 4.6, 1.9), CFrame.new(x * 1.2, -2.7, 0), fur, x < 0 and math.pi or 0, Enum.Material.Fabric)
	end
	return m, hrp, hum
end

local function guardian(def, at)
	local m, hrp, hum = base("guardian", Vector3.new(6, 7, 4), 5, at)
	local stone, moss = def.color, Color3.fromRGB(70, 120, 56)
	vis(m, hrp, Vector3.new(6, 7, 4), CFrame.new(), stone, nil, Enum.Material.Slate)
	vis(m, hrp, Vector3.new(4, 3.2, 3.6), CFrame.new(0, 5, -0.2), stone, nil, Enum.Material.Slate)
	vis(m, hrp, Vector3.new(6.2, 1.2, 4.2), CFrame.new(0, 3, 0), moss, nil, Enum.Material.Grass)
	vis(m, hrp, Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 0.6, -2.05), Color3.fromRGB(90, 230, 200), BALL, Enum.Material.Neon)
	for _, x in ipairs({ -4.1, 4.1 }) do
		vis(m, hrp, Vector3.new(2.2, 6.5, 2.2), CFrame.new(x, -0.8, -0.6), stone, nil, Enum.Material.Slate)
		vis(m, hrp, Vector3.new(2.8, 2.4, 2.8), CFrame.new(x, -4.2, -0.8), stone:Lerp(Color3.new(0, 0, 0), 0.2), nil, Enum.Material.Slate)
	end
	for _, x in ipairs({ -1.6, 1.6 }) do
		limb(m, hrp, Vector3.new(2.6, 5.2, 2.6), CFrame.new(x, -3.0, 0), stone, x < 0 and 0 or math.pi, Enum.Material.Slate)
	end
	for i = 1, 3 do
		vis(m, hrp, Vector3.new(0.8, 2.4, 0.8), CFrame.new(-1.5 + i * 0.8, 4.2, 2.1) * CFrame.Angles(math.rad(-20), 0, math.rad(-15 + i * 8)), Color3.fromRGB(110, 230, 210), nil, Enum.Material.Neon)
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
function Mobs.spawn(kind, at, level)
	local def = DEFS[kind]
	level = math.clamp(math.floor(level or 1), 1, 99)
	local m, hrp, hum
	if kind == "zombie" then m, hrp, hum = zombie(def, at)
	elseif kind == "guardian" then m, hrp, hum = guardian(def, at)
	elseif kind == "spider" then m, hrp, hum = spider(def, at)
	elseif kind == "scorpion" or kind == "scorpionking" then m, hrp, hum = scorpion(kind, def, at)
	elseif kind == "yeti" then m, hrp, hum = yeti(def, at)
	else m, hrp, hum = quadruped(kind, def, at) end
	local L = level - 1
	local maxHp = math.floor(def.hp * (1 + 0.10 * L))
	m:SetAttribute("Kind", kind)
	m:SetAttribute("Level", level)
	m:SetAttribute("HP", maxHp)
	m:SetAttribute("MaxHP", maxHp)
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = folder
	pcall(function() hrp:SetNetworkOwner(nil) end)
	mobs[m] = { kind = kind, def = def, hp = maxHp, level = level, lift = hrp:GetAttribute("Lift"), dest = nil, bob = rng:NextNumber(0, 6),
		ap = hrp:FindFirstChildOfClass("AlignPosition"), ao = hrp:FindFirstChildOfClass("AlignOrientation"), at = hrp.Position, pace = 1,
		dmg = (def.dmg or 0) * (1 + 0.05 * L), xp = math.floor(def.xp * (1 + 0.15 * L)), coins = math.floor(def.coins * (1 + 0.1 * L)), hrp = hrp, hum = hum, nextWander = 0, nextAttack = 0, scaredUntil = 0, rootedUntil = 0, target = nil, born = os.clock() }
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
	local gh, water = terrainHeight(np.X, np.Z)
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
	local tx = math.clamp(p.X + rng:NextNumber(-30, 30), -MAP_HALF, MAP_HALF)
	local tz = math.clamp(p.Z + rng:NextNumber(-30, 30), -MAP_HALF, MAP_HALF)
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
						ctx.hurt(s.target, s.dmg)
					end
				else
					wander(s, now)
				end
			end
			-- despawn
			local near = nearestPlayer(pos, 280)
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
	local regionBonus = math.max(0, d - 300) / 65 -- the outer regions are tougher (up to about +7)
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
	forest = { day = { rabbit = 3, deer = 2, boar = 2, wolf = 2, bear = 1 }, night = { zombie = 4, spider = 3, wolf = 2 } },
	hills = { day = { deer = 3, boar = 3, wolf = 2, bear = 1 }, night = { zombie = 3, spider = 3, wolf = 2 } },
	snow = { day = { hare = 4, snowwolf = 3, polarbear = 1 }, night = { snowwolf = 4, zombie = 2, polarbear = 1 } },
	desert = { day = { camel = 3, scorpion = 3 }, night = { scorpion = 4, spider = 3 } },
	mountains = { day = { goat = 4, wolf = 2, bear = 1 }, night = { wolf = 3, zombie = 2 } },
}
local BOSS = { forest = "alpha", hills = "alpha", snow = "yeti", desert = "scorpionking", mountains = "guardian" }
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
			if #options > 0 then
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

function Mobs.start(c)
	ctx = c
	folder = Instance.new("Folder")
	folder.Name = "Mobs"
	folder.Parent = workspace
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
