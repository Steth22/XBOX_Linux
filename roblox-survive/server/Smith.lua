-- The blacksmith: a smith at the camp and in every village. At his anvil you put a tool, weapon or
-- armor and an enchanted book; he puts the enchantment on it for coins (Minecraft's anvil).
-- Two of the same book make the next level. Indices: 401 = item, 402 = book, 403 = result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.Items)
local Config = require(ReplicatedStorage.Shared.Config)

local S = {}
S.ITEM, S.BOOK, S.OUT = 401, 402, 403
local ctx, Inventory, Data, Furnace
local anvils = {} -- [id] = part
local boxes = {} -- [Player] = { item, book }
local open = {} -- [Player] = anvil id

local function box(player)
	boxes[player] = boxes[player] or { item = false, book = false }
	return boxes[player]
end

function S.view(player)
	local b = box(player)
	local res, err, clash = Items.anvil(b.item or nil, b.book or nil)
	return { item = b.item, book = b.book, out = res and res.out or false, price = res and res.price or 0, err = (b.item and b.book and not res) and err or nil, clash = clash }
end

local function push(player) if open[player] then ctx.notify(player, "smith", S.view(player)) end end

local function giveBack(player)
	local b = boxes[player]
	local room = Data.room(player)
	if not b or not room then return end
	for _, k in ipairs({ "item", "book" }) do
		local it = b[k]
		if it then
			local rest = Inventory.add(room.inv, it.id, it.n, it.d, it.e)
			if rest > 0 then
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then require(script.Parent.Loot).drop(hrp.Position, { { id = it.id, n = rest, d = it.d, e = it.e } }, player.UserId) end
			end
			b[k] = false
		end
	end
end

---------------------------------------------------------------- the station: anvil, forge, rack and the smith
local function rig(cf, parent)
	local ok, m = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not m then return nil end
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end end
	m.Name = "Smith"
	local hum = m:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	m.HumanoidRootPart.Anchored = true
	local skin, apron, shirt, pants = Color3.fromRGB(196, 140, 100), Color3.fromRGB(70, 48, 34), Color3.fromRGB(150, 60, 46), Color3.fromRGB(50, 46, 44)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local n = p.Name
			if n == "Head" or n:find("Hand") then p.Color = skin
			elseif n:find("Torso") then p.Color = apron
			elseif n:find("Arm") then p.Color = shirt
			elseif n:find("Leg") or n:find("Foot") then p.Color = pants end
		end
	end
	local h = hum.HipHeight + m.HumanoidRootPart.Size.Y / 2
	m:PivotTo(cf * CFrame.new(0, h, 0))
	m.Parent = parent
	return m
end

local function build(cf, parent)
	local m = Instance.new("Model")
	m.Name = "Blacksmith"
	local function part(size, off, color, mat, shape)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf * off
		p.Color = color
		p.Material = mat or Enum.Material.Metal
		if shape then p.Shape = shape end
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local iron, darkIron, stone, wood = Color3.fromRGB(70, 72, 78), Color3.fromRGB(44, 44, 50), Color3.fromRGB(120, 116, 110), Color3.fromRGB(110, 76, 48)
	-- a stone floor
	part(Vector3.new(12, 0.4, 9), CFrame.new(0, 0.2, 1), stone, Enum.Material.Cobblestone)
	-- the anvil on a stump, in front of the smith
	part(Vector3.new(2.2, 1.6, 2.2), CFrame.new(0, 1.2, -1.2), wood, Enum.Material.Wood, Enum.PartType.Cylinder).CFrame = cf * CFrame.new(0, 1.2, -1.2) * CFrame.Angles(0, 0, math.rad(90))
	part(Vector3.new(1.4, 0.7, 0.9), CFrame.new(0, 2.35, -1.2), darkIron)
	local anvil = part(Vector3.new(2.8, 0.7, 1.2), CFrame.new(0, 3.0, -1.2), iron)
	anvil.Name = "Anvil"
	part(Vector3.new(1.0, 0.5, 0.8), CFrame.new(1.8, 3.1, -1.2), iron)
	part(Vector3.new(0.3, 0.3, 1.0), CFrame.new(-0.6, 3.5, -1.3) * CFrame.Angles(0, math.rad(25), 0), Color3.fromRGB(110, 76, 48), Enum.Material.Wood)
	part(Vector3.new(0.6, 0.35, 0.35), CFrame.new(-0.6, 3.5, -1.75) * CFrame.Angles(0, math.rad(25), 0), darkIron)
	-- the forge behind him with glowing coals and a chimney
	part(Vector3.new(4.4, 3.2, 3.2), CFrame.new(-3.6, 1.8, 3.4), stone, Enum.Material.Cobblestone)
	local coal = part(Vector3.new(3.4, 0.3, 2.2), CFrame.new(-3.6, 3.45, 3.4), Color3.fromRGB(255, 110, 30), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 14
	light.Brightness = 1.6
	light.Parent = coal
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 4
	fire.Parent = coal
	part(Vector3.new(1.8, 7, 1.8), CFrame.new(-3.6, 6.5, 4.4), stone, Enum.Material.Cobblestone)
	-- a rack of swords and a barrel of water
	part(Vector3.new(4, 0.3, 0.4), CFrame.new(3.6, 4.4, 4.3), wood, Enum.Material.Wood)
	part(Vector3.new(0.3, 4.4, 0.3), CFrame.new(2.0, 2.2, 4.3), wood, Enum.Material.Wood)
	part(Vector3.new(0.3, 4.4, 0.3), CFrame.new(5.2, 2.2, 4.3), wood, Enum.Material.Wood)
	for k = 0, 2 do
		local id = ({ "iron_sword", "diamond_sword", "obsidian_sword" })[k + 1]
		local it = Items.model(id)
		if it then
			for _, d in ipairs(it:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true d.CanCollide = false end end
			it:PivotTo(cf * CFrame.new(2.6 + k * 1.1, 3.0, 4.0) * CFrame.Angles(math.rad(-90), 0, 0))
			it.Parent = m
		end
	end
	local barrel = part(Vector3.new(2.6, 2.2, 2.2), CFrame.new(4.6, 1.5, 1.2), wood, Enum.Material.Wood, Enum.PartType.Cylinder)
	barrel.CFrame = cf * CFrame.new(4.6, 1.5, 1.2) * CFrame.Angles(0, 0, math.rad(90))
	-- a sign
	local post = part(Vector3.new(0.4, 5, 0.4), CFrame.new(-5.4, 2.5, -2.6), wood, Enum.Material.Wood)
	local board = part(Vector3.new(4.2, 1.6, 0.3), CFrame.new(-5.4, 4.6, -2.6), wood, Enum.Material.WoodPlanks)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 150)
	gui.Parent = board
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.fromRGB(255, 210, 120)
	t.Text = "الحداد | SMITH"
	t.Parent = gui
	m.PrimaryPart = anvil
	m.Parent = parent
	rig(cf * CFrame.new(0, 0.4, 1.4), m)
	return m, anvil
end

-- a flat, free place (12 x 10) somewhere round pos
local function findSpot(pos, avoid)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = avoid
	for r = 0, 40, 4 do
		local n = math.max(1, math.floor(r / 3))
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2
			local p = pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local hits = {}
			local ok = true
			for _, o in ipairs({ { 0, 0 }, { 6, 5 }, { -6, 5 }, { 6, -5 }, { -6, -5 } }) do
				local h = workspace:Raycast(Vector3.new(p.X + o[1], pos.Y + 40, p.Z + o[2]), Vector3.new(0, -90, 0), params)
				if not h or h.Material == Enum.Material.Water then ok = false break end
				table.insert(hits, h.Position.Y)
			end
			if ok then
				local lo, hi = math.huge, -math.huge
				for _, y in ipairs(hits) do lo, hi = math.min(lo, y), math.max(hi, y) end
				if hi - lo < 2.5 then
					local blocking = workspace:GetPartBoundsInBox(CFrame.new(p.X, hi + 4, p.Z), Vector3.new(13, 7.5, 11), op)
					local solid = false
					for _, b in ipairs(blocking) do if b.CanCollide or b.Transparency < 1 then solid = true break end end
					if not solid then return Vector3.new(p.X, hits[1], p.Z) end
				end
			end
		end
	end
	return nil
end

local count = 0
local function place(at, faceTo, folder)
	local look = Vector3.new(faceTo.X, at.Y, faceTo.Z)
	if (look - at).Magnitude < 1 then look = at + Vector3.new(0, 0, -1) end
	local cf = CFrame.lookAt(at, look)
	local _, anvil = build(cf, folder)
	count += 1
	local id = "s" .. count
	anvils[id] = anvil
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Enchant"
	pr.ObjectText = "Blacksmith"
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "smith")
	pr:SetAttribute("Obj", "smith")
	pr.Parent = anvil
	pr.Triggered:Connect(function(player)
		open[player] = id
		ctx.notify(player, "openSmith", S.view(player))
	end)
end

function S.start(c, inv, data, furnace)
	ctx, Inventory, Data, Furnace = c, inv, data, furnace
	local folder = Instance.new("Folder")
	folder.Name = "Smiths"
	folder.Parent = workspace
	task.spawn(function()
		local t0 = os.clock()
		while not workspace:GetAttribute("TerrainReady") and os.clock() - t0 < 120 do task.wait(1) end
		local avoid = { folder, workspace:FindFirstChild("Resources") }
		local made = 0
		-- at the camp: to the side of the spawn
		local sp = workspace:FindFirstChild("ForestSpawn")
		local base = sp and sp.Position or Vector3.new()
		local at = findSpot(base + Vector3.new(-26, 0, -14), avoid)
		if at then place(at, base, folder) made += 1 end
		-- in every village, near its square
		local vf = workspace:FindFirstChild("Villages")
		for _, vil in ipairs(vf and vf:GetChildren() or {}) do
			local cpos = vil:GetAttribute("Center")
			if cpos then
				local a2 = findSpot(cpos + Vector3.new(-6, 0, -16), avoid)
				if a2 then place(a2, cpos, folder) made += 1 end
			end
		end
		require(script.Parent.Debug).log("smith", "built " .. made)
	end)
	Players.PlayerRemoving:Connect(function(player)
		giveBack(player)
		boxes[player] = nil
		open[player] = nil
	end)
end

-- bag <-> anvil, and taking the result (pays the smith)
function S.move(player, room, a, b)
	local aid = open[player]
	local anvil = aid and anvils[aid]
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not anvil or not hrp or (hrp.Position - anvil.Position).Magnitude > 16 then return false end
	local bx = box(player)
	local inv = room.inv
	local function slotOk(i) return i and i >= 1 and i <= Config.HOTBAR + Config.BIG_BAG and Inventory.usable(inv, i) end
	if a == S.OUT then
		local res, err = Items.anvil(bx.item or nil, bx.book or nil)
		if not res then ctx.notify(player, err or "needBook") return true end
		if (room.coins or 0) < res.price then ctx.notify(player, "needCoins") return true end
		if Inventory.space(inv, res.out.id) < 1 then ctx.notify(player, "bagFull") return true end
		room.coins -= res.price
		Inventory.add(inv, res.out.id, 1, res.out.d, res.out.e)
		bx.item, bx.book = false, false
		ctx.fx("levelUp", player.Character)
		ctx.fx("craft", anvil.Position + Vector3.new(0, 1, 0))
		ctx.notify(player, "enchanted", res.k, res.lvl)
		if ctx.bump then ctx.bump(player, "enchanted", 1) end
		push(player)
		return true
	end
	local key = ({ [S.ITEM] = "item", [S.BOOK] = "book" })
	if key[b] and slotOk(a) then
		-- bag -> anvil
		local sl = inv.slots[a]
		if not sl then return true end
		local d = Items.get(sl.id)
		if b == S.BOOK and d.kind ~= "book" then ctx.notify(player, "needBook") return true end
		if b == S.ITEM and not (d.kind == "book" or next(Items.enchSlots(sl.id))) then ctx.notify(player, "enchNotFit") return true end
		if bx[key[b]] then
			-- swap with what was there
			local old = bx[key[b]]
			bx[key[b]] = { id = sl.id, n = 1, d = sl.d, e = sl.e }
			inv.slots[a] = old
		else
			bx[key[b]] = { id = sl.id, n = 1, d = sl.d, e = sl.e }
			Inventory.removeSlot(inv, a, 1)
		end
		push(player)
		return true
	end
	if key[a] then
		-- anvil -> bag
		local it = bx[key[a]]
		if not it then return true end
		if slotOk(b) and not inv.slots[b] then
			inv.slots[b] = it
		elseif Inventory.add(inv, it.id, 1, it.d, it.e) > 0 then
			ctx.notify(player, "bagFull")
			return true
		end
		bx[key[a]] = false
		push(player)
		return true
	end
	return false
end

function S.close(player)
	giveBack(player)
	open[player] = nil
end

return S
