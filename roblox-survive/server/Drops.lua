-- A supply crate falls every 5 minutes somewhere on land (within reach of a player). Everyone sees a beam
-- of light and a marker. Whoever opens it first gets rare loot (enchanted books among it); everybody is told
-- who got it. Unopened, it goes after a minute and a half.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Items = require(ReplicatedStorage.Shared.Items)

local D = {}
D.EVERY = 300
D.LIFE = 90
local ctx, Inventory, Data
local rng = Random.new()
local current = nil

-- what can come out: { id, min, max, weight }. No secret-trader goods and no boss gear.
local LOOT = {
	{ "coins", 300, 1200, 14 },
	{ "diamond", 2, 5, 10 },
	{ "obsidian", 2, 4, 8 },
	{ "crystal", 3, 6, 9 },
	{ "gold", 4, 8, 10 },
	{ "iron", 6, 12, 8 },
	{ "lantern", 1, 1, 4 },
	{ "bandage", 3, 6, 6 },
	{ "potion_speed", 1, 2, 4 }, { "potion_strength", 1, 1, 4 }, { "potion_regen", 1, 2, 4 },
	{ "potion_stone", 1, 1, 3 }, { "potion_vision", 1, 2, 3 }, { "potion_warmth", 1, 2, 3 },
	{ "dynamite", 2, 4, 4 },
	{ "crossbow", 1, 1, 2 }, { "bolt", 10, 20, 3 },
	{ "book", 1, 1, 18 }, -- an enchanted book (rolled below)
}

local function pick()
	local total = 0
	for _, l in ipairs(LOOT) do total += l[4] end
	local r = rng:NextNumber() * total
	for _, l in ipairs(LOOT) do
		r -= l[4]
		if r <= 0 then return l end
	end
	return LOOT[1]
end

-- a random enchanted book; high levels are rare
local function randomBook()
	local k = Items.ENCH_ORDER[rng:NextInteger(1, #Items.ENCH_ORDER)]
	local max = Items.ENCH[k].max
	local roll = rng:NextNumber()
	local lvl = roll < 0.5 and 1 or roll < 0.8 and 2 or roll < 0.94 and 3 or roll < 0.99 and 4 or 5
	return "book_" .. k .. "_" .. math.min(lvl, max)
end

-- somewhere on dry land 80 to 260 studs from a random player
local function spot()
	local list = Players:GetPlayers()
	if #list == 0 then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = { workspace.Terrain }
	for _ = 1, 40 do
		local pl = list[rng:NextInteger(1, #list)]
		local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp.Position.Y > -26 then
			local a = rng:NextNumber() * math.pi * 2
			local r = rng:NextNumber(80, 260)
			local x, z = hrp.Position.X + math.cos(a) * r, hrp.Position.Z + math.sin(a) * r
			if math.abs(x) < 1480 and math.abs(z) < 1480 then
				local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -360, 0), params)
				if hit and hit.Material ~= Enum.Material.Water and hit.Material ~= Enum.Material.CrackedLava and hit.Normal.Y > 0.8 and hit.Position.Y > -20 then
					local busy = workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 3, 0)), Vector3.new(6, 5, 6), op)
					if #busy == 0 then return hit.Position end
				end
			end
		end
	end
	return nil
end

local function build(at)
	local m = Instance.new("Model")
	m.Name = "SupplyCrate"
	local function part(size, cf, color, mat)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.WoodPlanks
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local base = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	local gold, wood, dark = Color3.fromRGB(240, 190, 70), Color3.fromRGB(120, 70, 150), Color3.fromRGB(60, 30, 80)
	local body = part(Vector3.new(4.4, 2.8, 3.2), base * CFrame.new(0, 1.4, 0), wood)
	body.Name = "Body"
	part(Vector3.new(4.5, 1.0, 3.3), base * CFrame.new(0, 3.3, 0), dark)
	for _, x in ipairs({ -1.7, 1.7 }) do part(Vector3.new(0.4, 3.9, 3.4), base * CFrame.new(x, 1.95, 0), gold, Enum.Material.Metal) end
	part(Vector3.new(4.6, 0.35, 3.4), base * CFrame.new(0, 2.85, 0), gold, Enum.Material.Metal)
	local lock = part(Vector3.new(0.8, 0.9, 0.3), base * CFrame.new(0, 2.6, -1.7), gold, Enum.Material.Neon)
	lock.Name = "Lock"
	-- the beam of light that shows where it is from far away
	local beam = part(Vector3.new(1.6, 220, 1.6), CFrame.new(at + Vector3.new(0, 112, 0)), Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
	beam.Name = "Beam"
	beam.Transparency = 0.55
	beam.CanCollide, beam.CanQuery, beam.CanTouch = false, false, false
	beam.CastShadow = false
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(200, 120, 255))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Rate = 16
	sparkle.Parent = body
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 120)
	light.Range = 18
	light.Brightness = 2
	light.Parent = lock
	m.PrimaryPart = body
	m.Parent = workspace
	return m
end

local function clear()
	if current and current.model then current.model:Destroy() end
	current = nil
	ReplicatedStorage:SetAttribute("SupplyDrop", "")
end

local function open(player)
	if not current or current.taken then return end
	local room = Data.room(player)
	if not room then return end
	current.taken = true
	local m = current.model
	local at = m:GetPivot().Position
	-- 3 to 5 rolls
	local got, over = {}, {}
	for _ = 1, rng:NextInteger(3, 5) do
		local l = pick()
		if l[1] == "coins" then
			local n = rng:NextInteger(l[2], l[3])
			room.coins += n
			table.insert(got, { id = "coins", n = n })
		else
			local id = l[1] == "book" and randomBook() or l[1]
			local n = rng:NextInteger(l[2], l[3])
			local rest = Inventory.add(room.inv, id, n)
			if n - rest > 0 then table.insert(got, { id = id, n = n - rest }) end
			if rest > 0 then table.insert(over, { id = id, n = rest }) end
		end
	end
	if #over > 0 then require(script.Parent.Loot).drop(at, over, player.UserId) end
	ctx.fx("celebrate", at + Vector3.new(0, 3, 0))
	ctx.broadcast("dropOpened", player.DisplayName)
	if ctx.feed then pcall(ctx.feed, "drop", player.DisplayName) end
	ctx.notify(player, "dropLoot", got)
	if ctx.bump then ctx.bump(player, "drops", 1) end
	ctx.push(player)
	-- the lid flies off and the crate fades
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then TweenService:Create(p, TweenInfo.new(1.2), { Transparency = 1 }):Play() end
		if p:IsA("ParticleEmitter") then p.Enabled = false end
	end
	task.delay(1.3, clear)
end

local function spawnOne()
	if current then clear() end
	local at = spot()
	if not at then return end
	local m = build(at)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Open"
	pr.ObjectText = "Supply crate"
	pr.HoldDuration = 1
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "dropOpen")
	pr:SetAttribute("Obj", "drop")
	pr.Parent = m.PrimaryPart
	local expires = os.time() + D.LIFE
	current = { model = m, expires = expires }
	ReplicatedStorage:SetAttribute("SupplyDrop", string.format("%d,%d,%d,%d", math.floor(at.X), math.floor(at.Y), math.floor(at.Z), expires))
	pr.Triggered:Connect(function(player)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then open(player) end
	end)
	ctx.broadcast("dropSpawn")
	local mine = current
	task.delay(D.LIFE, function()
		if current == mine and not mine.taken then
			ctx.broadcast("dropGone")
			clear()
		end
	end)
end

function D.start(c, inv, data)
	ctx, Inventory, Data = c, inv, data
	ReplicatedStorage:SetAttribute("SupplyDrop", "")
	task.spawn(function()
		while true do
			task.wait(D.EVERY)
			if #Players:GetPlayers() > 0 then pcall(spawnOne) end
		end
	end)
end
D._spawn = spawnOne
D._open = open
D._book = randomBook
D._loot = LOOT

return D
