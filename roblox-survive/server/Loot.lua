-- Dropped item bags (death drops, overflow) and searchable crates in cabins / caves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Loot = {}
local ctx, folder
local bags = {} -- [model] = { items, owner, t }
local rng = Random.new()

local TABLES = {
	cabin = { coins = { 5, 20 }, items = {
		{ "bandage", 1, 2, 0.5 }, { "arrow", 5, 10, 0.35 }, { "meat_cooked", 1, 2, 0.5 },
		{ "wood_sword", 1, 1, 0.12 }, { "bow", 1, 1, 0.07 }, { "trap", 1, 1, 0.2 }, { "campfire", 1, 1, 0.3 } } },
	cave = { coins = { 15, 40 }, items = {
		{ "ammo", 6, 12, 0.4 }, { "pistol", 1, 1, 0.06 }, { "iron_sword", 1, 1, 0.1 },
		{ "stone", 4, 8, 0.8 }, { "bandage", 1, 3, 0.5 }, { "arrow", 8, 16, 0.4 },
		{ "iron", 2, 4, 0.5 }, { "gold", 1, 2, 0.25 }, { "diamond", 1, 1, 0.08 } } },
}

local function groundBelow(pos)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { folder }
	for _, n in ipairs({ "Mobs", "Traps" }) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		if pl.Character then table.insert(ex, pl.Character) end
	end
	return require(script.Parent.Ground).below(pos, ex)
end

local function part(parent, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanTouch = false
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

-- items: list of { id, n, d }
function Loot.drop(pos, items, ownerId)
	if #items == 0 then return end
	local g = groundBelow(pos)
	local m = Instance.new("Model")
	m.Name = "ItemBag"
	local sack = part(m, Vector3.new(2.2, 2.2, 2.2), CFrame.new(g + Vector3.new(0, 1, 0)), Color3.fromRGB(150, 110, 70), Enum.Material.Fabric, Enum.PartType.Ball)
	sack.CanQuery = true
	part(m, Vector3.new(0.5, 0.9, 0.5), CFrame.new(g + Vector3.new(0, 2.2, 0)), Color3.fromRGB(110, 78, 50), Enum.Material.Fabric)
	local beam = part(m, Vector3.new(0.5, 40, 0.5), CFrame.new(g + Vector3.new(0, 21, 0)), Color3.fromRGB(255, 205, 90), Enum.Material.Neon)
	beam.Transparency = 0.55
	beam.CanQuery = false
	m.PrimaryPart = sack
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Take"
	pr.ObjectText = "Items"
	pr.HoldDuration = 0.5
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "take")
	pr:SetAttribute("Obj", "bag")
	pr.Parent = sack
	m.Parent = folder
	bags[m] = { items = items, owner = ownerId, t = os.clock() }
	pr.Triggered:Connect(function(player)
		local b = bags[m]
		if not b then return end
		if b.owner and player.UserId ~= b.owner and os.clock() - b.t < Config.BAG_OWNER_TIME then
			ctx.notify(player, "notYours")
			return
		end
		local left = {}
		for _, it in ipairs(b.items) do
			local rest = ctx.giveItem(player, it)
			if rest > 0 then
				table.insert(left, { id = it.id, n = rest, d = it.d })
			end
		end
		b.items = left
		if #left == 0 then
			bags[m] = nil
			m:Destroy()
		else
			ctx.notify(player, "bagFull")
		end
	end)
	task.delay(Config.BAG_LIFETIME, function()
		bags[m] = nil
		if m.Parent then m:Destroy() end
	end)
	return m
end

-- a single item lying on the ground (anyone can pick it up)
function Loot.dropItem(pos, it)
	local Items = require(ReplicatedStorage.Shared.Items)
	local m = Items.model(it.id)
	if not m then return end
	local g = groundBelow(pos)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end
	local cf, size = m:GetBoundingBox()
	local lying = size.Y > size.X and size.Y > size.Z
	m:PivotTo(CFrame.new(g + Vector3.new(0, 0.35, 0)) * CFrame.Angles(lying and math.rad(90) or 0, rng:NextNumber(0, 6.28), 0))
	m.Name = "Dropped"
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Take"
	pr.ObjectText = it.id
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 8
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "take")
	pr:SetAttribute("ItemId", it.id)
	pr:SetAttribute("Count", it.n)
	pr.Parent = m.PrimaryPart
	m.Parent = folder
	local data = { id = it.id, n = it.n, d = it.d }
	pr.Triggered:Connect(function(player)
		if not m.Parent then return end
		local rest = ctx.giveItem(player, data)
		if rest < data.n then ctx.notify(player, "picked", data.id, data.n - rest) end
		data.n = rest
		pr:SetAttribute("Count", rest)
		if rest <= 0 then m:Destroy() else ctx.notify(player, "bagFull") end
	end)
	task.delay(300, function() if m.Parent then m:Destroy() end end)
	return m
end

local function setupCrate(crate)
	local pr = crate:FindFirstChildWhichIsA("ProximityPrompt", true)
	local tbl = TABLES[crate:GetAttribute("Crate")]
	if not pr or not tbl then return end
	pr:SetAttribute("Key", "search")
	pr:SetAttribute("Obj", "crate")
	local lid = crate:FindFirstChild("Lid")
	local lidCf = lid and lid.CFrame
	pr.Triggered:Connect(function(player)
		if crate:GetAttribute("Empty") then
			ctx.notify(player, "crateEmpty")
			return
		end
		crate:SetAttribute("Empty", true)
		ctx.fx("crate", crate:GetPivot().Position)
		if lid then lid.CFrame = lidCf * CFrame.new(0, 0.6, 0.8) * CFrame.Angles(math.rad(-60), 0, 0) end
		local got = {}
		for _, e in ipairs(tbl.items) do
			if rng:NextNumber() < e[4] then
				table.insert(got, { id = e[1], n = rng:NextInteger(e[2], e[3]) })
			end
		end
		if #got == 0 then table.insert(got, { id = "berries", n = 3 }) end
		local over = {}
		for _, it in ipairs(got) do
			local rest = ctx.giveItem(player, it)
			ctx.notify(player, "picked", it.id, it.n - rest)
			if rest > 0 then table.insert(over, { id = it.id, n = rest }) end
		end
		if #over > 0 then Loot.drop(crate:GetPivot().Position + Vector3.new(0, 0, 3), over, player.UserId) end
		local cp = crate:GetPivot().Position
		local far = 1 + math.max(0, math.max(math.abs(cp.X), math.abs(cp.Z)) - 300) / 300
		local coins = math.floor(rng:NextInteger(tbl.coins[1], tbl.coins[2]) * far)
		ctx.reward(player, 8, coins)
		ctx.notify(player, "coinsGot", coins)
		task.delay(600, function()
			crate:SetAttribute("Empty", false)
			if lid then lid.CFrame = lidCf end
		end)
	end)
end

function Loot.init(c)
	ctx = c
	folder = Instance.new("Folder")
	folder.Name = "Loot"
	folder.Parent = workspace
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("Crate") then setupCrate(d) end
	end
end

return Loot
