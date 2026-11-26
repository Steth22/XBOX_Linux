-- Every player gets a plot near the spawn. They pick one of 15 designs, then build and upgrade their house
-- with wood and stone (6 levels, up to 3 storeys). The house stands while its owner is in the room.
-- It has beds (any bed sets your respawn), separate chests (only the owner opens them), furnaces,
-- a crafting table, chairs and decorations.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local House = require(ReplicatedStorage.Shared.House)
local Items = require(ReplicatedStorage.Shared.Items)

local Homes = {}

-- flat, free plots round the spawn (checked against the terrain, trees, rocks and buildings), nearest first
Homes.PLOTS = {
	{ 80, 0 }, { 24, 76 }, { -65, -48 }, { 24, -77 }, { -100, 0 }, { -13, -120 }, { 12, 139 }, { -85, 111 },
	{ -153, 49 }, { 94, -130 }, { -75, 163 }, { -75, -164 }, { 107, 168 }, { 12, 199 }, { -162, 117 }, { 12, -200 },
}

local ctx, Inventory, Data, Furnace, Crafting
local homes = {} -- [Player] = { plot, base (CFrame), model, sign, furnaces, tables, chests = { [n] = model }, beds }
local folder

-- the height of the ground at x, z, read from the terrain voxels (works before collisions are ready)
local function groundAt(x, z)
	local T = workspace.Terrain
	local region = Region3.new(Vector3.new(x - 2, -40, z - 2), Vector3.new(x + 2, 120, z + 2)):ExpandToGrid(4)
	local mats, occ = T:ReadVoxels(region, 4)
	local sy = mats.Size.Y
	local y0 = region.CFrame.Position.Y - region.Size.Y / 2
	for iy = sy, 1, -1 do
		local m = mats[1][iy][1]
		if m ~= Enum.Material.Air and m ~= Enum.Material.Water and occ[1][iy][1] > 0.3 then
			-- the top of that voxel: never below the real surface
			return y0 + iy * 4
		end
	end
	return nil
end

-- where the house stands: on the highest ground of the plot, facing the spawn
local function baseOf(plot)
	local px, pz = Homes.PLOTS[plot][1], Homes.PLOTS[plot][2]
	local lo, hi = math.huge, -math.huge
	for dx = -14, 14, 7 do
		for dz = -14, 14, 7 do
			local y = groundAt(px + dx, pz + dz)
			if y then lo, hi = math.min(lo, y), math.max(hi, y) end
		end
	end
	if hi == -math.huge then lo, hi = 12, 12 end
	local floorY = hi + 0.3
	local pos = Vector3.new(px, floorY, pz)
	local face = Vector3.new(0, floorY, 0)
	if (face - pos).Magnitude < 1 then face = pos + Vector3.new(0, 0, -1) end
	return CFrame.lookAt(pos, face), floorY - lo + 3
end

Homes._base = function(i) return baseOf(i) end

local function pickPlot(player, room)
	local used = {}
	for pl, h in pairs(homes) do if pl ~= player then used[h.plot] = true end end
	local want = room.house and room.house.plot
	if want and Homes.PLOTS[want] and not used[want] then return want end
	for i = 1, #Homes.PLOTS do if not used[i] then return i end end
	return nil
end

local function clear(h)
	for _, f in ipairs(h.furnaces or {}) do Furnace.remove(f) end
	for _, t in ipairs(h.tables or {}) do Crafting.remove(t) end
	h.furnaces, h.tables, h.chests, h.beds = {}, {}, {}, {}
	if h.model then h.model:Destroy() h.model = nil end
end

local function prompt(parent, key, obj, dist)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = key
	pr.ObjectText = obj
	pr.MaxActivationDistance = dist or 9
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", key)
	pr:SetAttribute("Obj", obj)
	pr.Parent = parent
	return pr
end

-- (re)builds what stands on the player's plot
local function build(player)
	local h = homes[player]
	local room = Data.room(player)
	if not h or not room then return end
	local oldBeds = h.beds or {}
	clear(h)
	local hs = room.house
	local m
	local L = hs.lvl >= 1 and House.LEVELS[hs.lvl] or nil
	if L then
		m = House.build(hs.design, hs.lvl, { found = h.found })
	else
		m = House.plot(26, 22)
		local base = Instance.new("Part")
		base.Name = "Base"
		base.Anchored = true
		base.Transparency = 1
		base.CanCollide = false
		base.Size = Vector3.new(1, 1, 1)
		base.Parent = m
		m.PrimaryPart = base
	end
	m.Name = "House_" .. player.UserId
	m:SetAttribute("Owner", player.UserId)
	-- no ground or grass inside the house: once the terrain is rebuilt at startup (it would undo this),
	-- clear what pokes up and turn the tall grass round the house into short grass
	if L then
		local height = (m:GetAttribute("Height") or 12) + 6
		local base = h.base
		task.spawn(function()
			local t0 = os.clock()
			while not workspace:GetAttribute("TerrainReady") and os.clock() - t0 < 120 do task.wait(1) end
			pcall(function()
				local T = workspace.Terrain
				T:FillBlock(base * CFrame.new(0, height / 2 - 0.4, 0), Vector3.new(L.w + 2, height, L.d + 2), Enum.Material.Air)
				local c = base.Position
				local half = Vector3.new(L.w / 2 + 12, 0, L.w / 2 + 12)
				local region = Region3.new(c - half - Vector3.new(0, 24, 0), c + half + Vector3.new(0, 12, 0)):ExpandToGrid(4)
				T:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.LeafyGrass)
			end)
		end)
	end
	-- place it: the model was built round the origin
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.CFrame = h.base * p.CFrame end
	end
	m.Parent = folder
	h.model = m
	-- the sign by the path to the door
	local hd = L and L.d / 2 or 11
	local signCf = h.base * CFrame.new(5.5, 0, -hd - 4) * CFrame.Angles(0, math.pi, 0)
	local sign = House.sign(m, signCf)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.fromRGB(255, 240, 200)
	t.TextStrokeTransparency = 0.4
	t.Text = player.DisplayName
	t.Parent = gui
	local pr = prompt(sign, "house", "house", 10)
	pr.Triggered:Connect(function(pl)
		if pl == player then ctx.notify(pl, "openHouse", Homes.info(pl)) else ctx.notify(pl, "notYourHouse") end
	end)
	if not L then return end
	-- the door opens inwards and closes again
	local door
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") and d:GetAttribute("Door") then door = d break end end
	if door then
		local TweenService = game:GetService("TweenService")
		local closed = door.CFrame
		local hinge = closed * CFrame.new(-door.Size.X / 2, 0, 0)
		local opened = hinge * CFrame.Angles(0, math.rad(-100), 0) * CFrame.new(door.Size.X / 2, 0, 0)
		local kids = {}
		for _, k in ipairs(door:GetChildren()) do if k:IsA("BasePart") then kids[k] = closed:ToObjectSpace(k.CFrame) end end
		local isOpen = false
		local cfv = Instance.new("CFrameValue")
		cfv.Value = closed
		cfv.Parent = door
		cfv.Changed:Connect(function(v)
			door.CFrame = v
			for k, rel in pairs(kids) do k.CFrame = v * rel end
		end)
		local dp = prompt(door, "door", "door", 9)
		dp.Triggered:Connect(function()
			isOpen = not isOpen
			dp:SetAttribute("Key", isOpen and "doorClose" or "door")
			TweenService:Create(cfv, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Value = isOpen and opened or closed }):Play()
			if ctx.fx then ctx.fx("place", door.Position) end
		end)
	end
	-- the working parts
	local inside = m:FindFirstChild("Furniture")
	for _, d in ipairs(inside and inside:GetChildren() or {}) do
		if d.Name == "FurnaceSpot" then
			table.insert(h.furnaces, Furnace.add(d.CFrame, inside))
		elseif d.Name == "CraftSpot" then
			table.insert(h.tables, Crafting.add(d.CFrame, inside))
		elseif d:IsA("Model") and d:GetAttribute("Chest") then
			local n = d:GetAttribute("Chest")
			h.chests[n] = d
			local cp = prompt(d.PrimaryPart, "chest", "chest", 8)
			cp.Triggered:Connect(function(pl)
				if pl ~= player then ctx.notify(pl, "notYourChest") return end
				h.openChest = n
				ctx.notify(pl, "openChest", Homes.chestView(pl, n))
			end)
		elseif d:IsA("Model") and d:GetAttribute("Bed") then
			d:SetAttribute("HouseOf", player.UserId)
			table.insert(h.beds, d)
			local bp = prompt(d.PrimaryPart, "sleep", "bed", 9)
			bp.HoldDuration = 0.5
			bp.Triggered:Connect(function(pl) ctx.sleep(pl, d) end)
		end
	end
	-- a respawn on one of the old beds moves to the new house's first bed
	if ctx.rebed then
		for _, b in ipairs(oldBeds) do ctx.rebed(b, h.beds[1]) end
	end
end

function Homes.start(c, inv, data, furnace, crafting)
	ctx, Inventory, Data, Furnace, Crafting = c, inv, data, furnace, crafting
	folder = Instance.new("Folder")
	folder.Name = "Houses"
	folder.Parent = workspace
	Players.PlayerRemoving:Connect(function(player)
		local h = homes[player]
		if h then
			if ctx.rebed then for _, b in ipairs(h.beds or {}) do ctx.rebed(b, nil) end end
			clear(h)
			if h.sign then h.sign:Destroy() end
		end
		homes[player] = nil
	end)
end

-- the player arrived: give them a plot and put their house on it
function Homes.enter(player)
	local room = Data.room(player)
	if not room then return end
	room.house = room.house or { lvl = 0, chests = {} }
	local plot = pickPlot(player, room)
	if not plot then return end
	room.house.plot = plot
	local base, found = baseOf(plot)
	homes[player] = { plot = plot, base = base, found = found, furnaces = {}, tables = {}, chests = {}, beds = {} }
	local ok, err = pcall(build, player)
	if not ok then warn("house build:", err) end
end

-- the first bed of the player's house (for the respawn), or nil
function Homes.bed(player)
	local h = homes[player]
	return h and h.beds and h.beds[1] or nil
end

-- where to appear when there is no bed: in front of the house door
function Homes.spawn(player)
	local h = homes[player]
	local room = Data.room(player)
	if not h or not room or (room.house.lvl or 0) < 1 then return nil end
	local L = House.LEVELS[room.house.lvl]
	return (h.base * CFrame.new(0, 3, -L.d / 2 - 4)).Position
end

local function costOf(lvl)
	local L = House.LEVELS[lvl]
	return L and { wood = L.wood, stone = L.stone } or nil
end

function Homes.info(player)
	local room = Data.room(player)
	local hs = room and room.house or { lvl = 0 }
	local paid = hs.paid or {}
	return { design = hs.design, lvl = hs.lvl or 0, max = House.MAX, cost = costOf((hs.lvl or 0) + 1), paid = { wood = paid.wood or 0, stone = paid.stone or 0 },
		have = room and { wood = Inventory.count(room.inv, "wood"), stone = Inventory.count(room.inv, "stone") } or nil }
end

local function near(player, maxDist)
	local h = homes[player]
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return h and hrp and (hrp.Position - h.base.Position).Magnitude < (maxDist or 60)
end

-- pick a design (only before the first house is built) and/or build the next level
function Homes.upgrade(player, design)
	local room = Data.room(player)
	local h = homes[player]
	if not room or not h or not near(player) then return end
	local hs = room.house
	if hs.lvl == 0 and type(design) == "string" and House.BY[design] then hs.design = design end
	if not hs.design then ctx.notify(player, "pickDesign") return end
	if hs.lvl >= House.MAX then ctx.notify(player, "maxed") return end
	-- the wood and stone you carry go into the house; it grows when all of it is in
	local cost = costOf(hs.lvl + 1)
	hs.paid = hs.paid or { wood = 0, stone = 0 }
	local gave = 0
	for _, k in ipairs({ "wood", "stone" }) do
		local need = cost[k] - (hs.paid[k] or 0)
		local n = math.min(need, Inventory.count(room.inv, k))
		if n > 0 then
			Inventory.remove(room.inv, k, n)
			hs.paid[k] = (hs.paid[k] or 0) + n
			gave += n
		end
	end
	if hs.paid.wood < cost.wood or hs.paid.stone < cost.stone then
		if gave > 0 then ctx.notify(player, "houseGave", gave) ctx.push(player)
		else ctx.notify(player, "needWoodStone", cost.wood - hs.paid.wood, cost.stone - hs.paid.stone) end
		ctx.notify(player, "openHouse", Homes.info(player))
		return
	end
	hs.paid = { wood = 0, stone = 0 }
	hs.lvl += 1
	for n = 1, House.chests(hs.lvl) do
		if not hs.chests[n] then
			local slots = {}
			for i = 1, House.CHEST_SLOTS do slots[i] = false end
			hs.chests[n] = slots
		end
	end
	-- anyone standing where the walls go is lifted out first
	local L = House.LEVELS[hs.lvl]
	local ok, err = pcall(build, player)
	if not ok then warn("house build:", err) end
	for _, pl in ipairs(Players:GetPlayers()) do
		local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local rel = h.base:PointToObjectSpace(hrp.Position)
			if math.abs(rel.X) < L.w / 2 + 1 and math.abs(rel.Z) < L.d / 2 + 1 and rel.Y > -3 and rel.Y < L.floors * House.FLOOR + 2 then
				pl.Character:PivotTo(CFrame.new((h.base * CFrame.new(0, 3, -L.d / 2 - 5)).Position))
			end
		end
	end
	ctx.fx("levelUp", player.Character)
	ctx.fx("place", h.base.Position)
	ctx.reward(player, 25 * hs.lvl, 0)
	if ctx.bump then ctx.bump(player, "house", hs.lvl) end
	ctx.notify(player, "houseUp", hs.lvl)
	ctx.notify(player, "openHouse", Homes.info(player))
	ctx.push(player)
end

---------------------------------------------------------------- chests (each one separate, owner only)
function Homes.chestView(player, n)
	local room = Data.room(player)
	local slots = room and room.house.chests[n] or {}
	local out = {}
	for i = 1, House.CHEST_SLOTS do out[i] = slots[i] or false end
	return { n = n, slots = out }
end

local function nearChest(player, n)
	local h = homes[player]
	local c = h and h.chests[n]
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return c and c.PrimaryPart and hrp and (hrp.Position - c.PrimaryPart.Position).Magnitude < 14
end

function Homes.chestPut(player, n, i)
	local room = Data.room(player)
	n, i = tonumber(n), tonumber(i)
	if not room or not n or not i or not nearChest(player, n) or not Inventory.usable(room.inv, i) then return end
	local s = room.inv.slots[i]
	local box = room.house.chests[n]
	if not s or not box then return end
	local max = Items.stack(s.id)
	local left = s.n
	if not s.d then
		for k = 1, House.CHEST_SLOTS do
			local b = box[k]
			if left > 0 and b and b.id == s.id and b.n < max then
				local put = math.min(left, max - b.n)
				b.n += put
				left -= put
			end
		end
	end
	for k = 1, House.CHEST_SLOTS do
		if left > 0 and not box[k] then
			local put = math.min(left, max)
			box[k] = { id = s.id, n = put, d = s.d }
			left -= put
		end
	end
	local stored = s.n - left
	if stored <= 0 then ctx.notify(player, "chestFull") return end
	Inventory.removeSlot(room.inv, i, stored)
	ctx.notify(player, "chest", Homes.chestView(player, n))
	ctx.push(player)
end

function Homes.chestTake(player, n, k)
	local room = Data.room(player)
	n, k = tonumber(n), tonumber(k)
	if not room or not n or not k or not nearChest(player, n) then return end
	local box = room.house.chests[n]
	local s = box and box[k]
	if not s then return end
	local rest = Inventory.add(room.inv, s.id, s.n, s.d)
	if rest >= s.n then ctx.notify(player, "bagFull") return end
	if rest > 0 then s.n = rest else box[k] = false end
	ctx.notify(player, "chest", Homes.chestView(player, n))
	ctx.push(player)
end

return Homes
