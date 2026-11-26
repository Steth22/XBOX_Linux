-- Crafting tables, one just outside every trader's stall on its left (as you face the trader).
-- Minecraft style: a 3x3 grid and an output slot. Items placed in the grid stay the player's own
-- (each player has their own grid); taking the output uses one item from every filled cell.
-- Indices used by the move action: 301..309 = the grid (row by row), 310 = the output.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.Items)
local Config = require(ReplicatedStorage.Shared.Config)

local C = {}
C.GRID, C.OUT = 301, 310

local ctx, Inventory, Data, Furnace
local tables = {} -- [id] = part
local grids = {} -- [Player] = { [1..9] = {id, n} or false }
local open = {} -- [Player] = table id

local function grid(player)
	if not grids[player] then
		grids[player] = {}
		for i = 1, 9 do grids[player][i] = false end
	end
	return grids[player]
end

local function result(g)
	local cells = {}
	for i = 1, 9 do cells[i] = g[i] and g[i].id or false end
	return Items.craft(cells)
end

local function view(player)
	local g = grid(player)
	local rc = result(g)
	local cells = {}
	for i = 1, 9 do cells[i] = g[i] or false end
	return { cells = cells, out = rc and { id = rc.out, n = rc.n } or false }
end

function C.push(player)
	if open[player] then ctx.notify(player, "craft", view(player)) end
end

-- a big wooden crafting block like Minecraft's: plank sides with tools hung on them, a 3x3 grid on top
local function build(cf, parent)
	local m = Instance.new("Model")
	m.Name = "CraftingTable"
	local function part(size, offset, color, mat)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf * offset
		p.Color = color
		p.Material = mat or Enum.Material.Wood
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local plank = Color3.fromRGB(168, 120, 72)
	local dark = Color3.fromRGB(100, 66, 38)
	local top = Color3.fromRGB(186, 136, 84)
	local metal = Color3.fromRGB(176, 180, 188)
	local S = 4.6
	local body = part(Vector3.new(S, S - 0.5, S), CFrame.new(0, (S - 0.5) / 2, 0), plank, Enum.Material.WoodPlanks)
	body.Name = "Body"
	-- dark corner posts and a thick top
	for _, x in ipairs({ -S / 2, S / 2 }) do for _, z in ipairs({ -S / 2, S / 2 }) do
		part(Vector3.new(0.5, S - 0.5, 0.5), CFrame.new(x * 0.98, (S - 0.5) / 2, z * 0.98), dark)
	end end
	part(Vector3.new(S + 0.3, 0.55, S + 0.3), CFrame.new(0, S - 0.25, 0), top, Enum.Material.WoodPlanks)
	-- the 3x3 grid on top
	for k = -1, 1, 2 do
		part(Vector3.new(0.14, 0.08, S - 0.4), CFrame.new(k * (S / 6), S + 0.06, 0), dark)
		part(Vector3.new(S - 0.4, 0.08, 0.14), CFrame.new(0, S + 0.06, k * (S / 6)), dark)
	end
	-- tools hung on the front (-Z) and the sides: a saw, a hammer, pincers
	local f = -S / 2 - 0.06
	part(Vector3.new(1.8, 0.7, 0.08), CFrame.new(-0.6, 2.6, f) * CFrame.Angles(0, 0, math.rad(-12)), metal, Enum.Material.Metal)
	part(Vector3.new(0.6, 0.45, 0.12), CFrame.new(0.55, 2.85, f), dark)
	part(Vector3.new(0.22, 1.6, 0.1), CFrame.new(1.1, 1.6, f), dark)
	part(Vector3.new(0.8, 0.4, 0.14), CFrame.new(1.1, 2.45, f), Color3.fromRGB(90, 92, 98), Enum.Material.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * (S / 2 + 0.06)
		part(Vector3.new(0.08, 1.4, 0.22), CFrame.new(x, 2.2, -0.5) * CFrame.Angles(math.rad(20), 0, 0), Color3.fromRGB(90, 92, 98), Enum.Material.Metal)
		part(Vector3.new(0.08, 1.4, 0.22), CFrame.new(x, 2.2, -0.1) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(90, 92, 98), Enum.Material.Metal)
		part(Vector3.new(0.1, 0.9, 1.6), CFrame.new(x, 1.0, 0.8), dark)
	end
	m.PrimaryPart = body
	m.Parent = parent
	return m, body
end

local count = 0
local function hook(body)
	count += 1
	local id = "c" .. count
	tables[id] = body
	body:SetAttribute("TableId", id)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Craft"
	pr.ObjectText = "Crafting Table"
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "craft")
	pr:SetAttribute("Obj", "craft")
	pr.Parent = body
	pr.Triggered:Connect(function(player)
		open[player] = id
		ctx.notify(player, "openCraft", view(player))
	end)
end

-- gives everything in the player's grid back to their bag
local function giveBack(player)
	local g = grids[player]
	local room = Data.room(player)
	if not g or not room then return end
	for i = 1, 9 do
		local it = g[i]
		if it then
			local rest = Inventory.add(room.inv, it.id, it.n)
			if rest > 0 then
				-- the bag is full: leave the rest on the ground, still the player's own
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if hrp then require(script.Parent.Loot).drop(hrp.Position, { { id = it.id, n = rest } }, player.UserId) end
			end
			g[i] = false
		end
	end
end

function C.start(c, inv, data, furnace, vendorParts)
	ctx, Inventory, Data, Furnace = c, inv, data, furnace
	local folder = Instance.new("Folder")
	folder.Name = "CraftingTables"
	folder.Parent = workspace
	task.spawn(function()
		local t0 = os.clock()
		while not workspace:GetAttribute("TerrainReady") and os.clock() - t0 < 90 do task.wait(0.5) end
		local made = 0
		for _, v in ipairs(vendorParts) do
			if v.part and v.part.Parent and v.shop ~= "black" then
				local avoid = { folder }
				for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(avoid, pl.Character) end end
				local at, front = Furnace.spotBeside(v.part, -1, avoid)
				if at then
					local _, body = build(CFrame.lookAt(at, at + front), folder)
					hook(body)
					made += 1
				end
			end
		end
		require(script.Parent.Debug).log("craft", "built " .. made)
	end)
	Players.PlayerRemoving:Connect(function(player)
		giveBack(player)
		grids[player] = nil
		open[player] = nil
	end)
end

-- moving items between the bag and the table
function C.move(player, room, a, b, one)
	local tid = open[player]
	local part = tid and tables[tid]
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not part or not hrp or (hrp.Position - part.Position).Magnitude > 16 then return false end
	local g = grid(player)
	local inv = room.inv
	local function slotOk(i) return i and i >= 1 and i <= Config.HOTBAR + Config.BIG_BAG and Inventory.usable(inv, i) end
	local function cellOf(i) return i and i >= C.GRID and i < C.GRID + 9 and (i - C.GRID + 1) or nil end

	-- take the result: one item from every filled cell
	if a == C.OUT then
		local rc = result(g)
		if not rc then return true end
		if Inventory.space(inv, rc.out) < rc.n then
			ctx.notify(player, "bagFull")
			return true
		end
		Inventory.add(inv, rc.out, rc.n)
		for i = 1, 9 do
			if g[i] then
				g[i].n -= 1
				if g[i].n <= 0 then g[i] = false end
			end
		end
		ctx.reward(player, 3, 0)
		if ctx.bump then ctx.bump(player, "crafted", 1) end
		ctx.fx("craft", part.Position + Vector3.new(0, 4, 0))
		ctx.notify(player, "crafted", rc.out, rc.n)
		C.push(player)
		return true
	end

	local ca, cb = cellOf(a), cellOf(b)
	if cb and slotOk(a) then
		-- bag -> cell: one item (tap) or the whole stack (drag)
		local sl = inv.slots[a]
		if not sl then return true end
		-- tools, armor and books keep their wear and enchantments: they don't go on the table
		if sl.d or sl.e or Items.stack(sl.id) == 1 then ctx.notify(player, "cantCraftWith") return true end
		local cur = g[cb]
		if cur and cur.id ~= sl.id then return true end
		local want = one and 1 or sl.n
		local n = math.min(want, Items.stack(sl.id) - (cur and cur.n or 0), sl.n)
		if n <= 0 then return true end
		g[cb] = { id = sl.id, n = (cur and cur.n or 0) + n }
		Inventory.removeSlot(inv, a, n)
		C.push(player)
		return true
	end
	if ca and cb then
		-- cell -> cell
		if ca == cb then return true end
		local x, y = g[ca], g[cb]
		if x and y and x.id == y.id then
			local n = math.min(x.n, Items.stack(x.id) - y.n)
			y.n += n
			x.n -= n
			if x.n <= 0 then g[ca] = false end
		else
			g[ca], g[cb] = y, x
		end
		C.push(player)
		return true
	end
	if ca then
		-- cell -> bag (into slot b if it is free, otherwise anywhere)
		local it = g[ca]
		if not it then return true end
		local rest
		if slotOk(b) and not inv.slots[b] then
			inv.slots[b] = { id = it.id, n = math.min(it.n, Items.stack(it.id)) }
			rest = it.n - inv.slots[b].n
			if rest > 0 then rest = Inventory.add(inv, it.id, rest) end
		else
			rest = Inventory.add(inv, it.id, it.n)
		end
		if rest > 0 then
			it.n = rest
			ctx.notify(player, "bagFull")
		else
			g[ca] = false
		end
		C.push(player)
		return true
	end
	return false
end

-- a working crafting table anywhere (in a player's house)
function C.add(cf, parent)
	local m, body = build(cf, parent)
	hook(body)
	return m
end
function C.remove(m)
	local body = m and m:FindFirstChild("Body")
	local id = body and body:GetAttribute("TableId")
	if id then
		tables[id] = nil
		for player, tid in pairs(open) do
			if tid == id then giveBack(player) open[player] = nil end
		end
	end
	if m then m:Destroy() end
end

function C.close(player)
	giveBack(player)
	open[player] = nil
end

return C
