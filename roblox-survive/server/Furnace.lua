-- Furnaces next to every trader (and two in each village). Minecraft style: an input slot, a fuel
-- slot (wood) and an output slot. Each item takes 3 seconds and 5 wood. Every player has their own
-- contents in each furnace (they stay while the server runs and go back to the bag on leaving).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.Items)
local Config = require(ReplicatedStorage.Shared.Config)

local F = {}
F.TIME = 3
F.FUEL = 5
local IN, FUEL, OUT = 201, 202, 203
F.IN, F.FUEL_SLOT, F.OUT = IN, FUEL, OUT

local ctx, Inventory, Data
local furnaces = {} -- [id] = part
local state = {} -- [Player] = { [furnaceId] = { input, fuel, out, t } }
local open = {} -- [Player] = furnaceId being looked at

local function box(player, fid)
	state[player] = state[player] or {}
	state[player][fid] = state[player][fid] or { input = false, fuel = false, out = false, t = 0 }
	return state[player][fid]
end

local function view(player, fid)
	local b = box(player, fid)
	return { id = fid, input = b.input, fuel = b.fuel, out = b.out, t = b.t, time = F.TIME, need = F.FUEL }
end

function F.push(player)
	local fid = open[player]
	if fid then ctx.notify(player, "furnace", view(player, fid)) end
end

-- builds a stone furnace at cf
local function build(cf, parent, name)
	local m = Instance.new("Model")
	m.Name = name or "Furnace"
	local function part(size, offset, color, mat)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf * offset
		p.Color = color
		p.Material = mat or Enum.Material.Slate
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local stone = Color3.fromRGB(128, 124, 118)
	local dark = Color3.fromRGB(86, 82, 78)
	local body = part(Vector3.new(4.4, 4.2, 4.4), CFrame.new(0, 2.3, 0), stone, Enum.Material.Cobblestone)
	body.Name = "Body"
	-- base and top slabs, darker corner posts
	part(Vector3.new(4.9, 0.4, 4.9), CFrame.new(0, 0.2, 0), dark, Enum.Material.Slate)
	part(Vector3.new(4.9, 0.45, 4.9), CFrame.new(0, 4.6, 0), dark, Enum.Material.Slate)
	for _, x in ipairs({ -2.15, 2.15 }) do
		for _, z in ipairs({ -2.15, 2.15 }) do
			part(Vector3.new(0.6, 4.0, 0.6), CFrame.new(x, 2.4, z), dark, Enum.Material.Slate)
		end
	end
	-- the front: a stone frame round a dark mouth, embers inside
	part(Vector3.new(3.0, 0.45, 0.35), CFrame.new(0, 3.05, -2.25), dark, Enum.Material.Slate)
	part(Vector3.new(0.45, 2.1, 0.35), CFrame.new(-1.3, 1.85, -2.25), dark, Enum.Material.Slate)
	part(Vector3.new(0.45, 2.1, 0.35), CFrame.new(1.3, 1.85, -2.25), dark, Enum.Material.Slate)
	part(Vector3.new(2.15, 2.0, 0.3), CFrame.new(0, 1.85, -2.12), Color3.fromRGB(26, 22, 20), Enum.Material.SmoothPlastic)
	local fire = part(Vector3.new(1.8, 0.5, 0.2), CFrame.new(0, 1.1, -2.2), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
	fire.Name = "Glow"
	fire.Transparency = 0.6
	-- a small grate above the mouth
	for k = -1, 1 do part(Vector3.new(0.18, 0.5, 0.2), CFrame.new(k * 0.45, 3.65, -2.25), Color3.fromRGB(50, 48, 46), Enum.Material.Metal) end
	-- chimney with a cap
	part(Vector3.new(1.1, 1.8, 1.1), CFrame.new(1.2, 5.7, 1.2), stone, Enum.Material.Cobblestone)
	part(Vector3.new(1.4, 0.3, 1.4), CFrame.new(1.2, 6.7, 1.2), dark, Enum.Material.Slate)
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 0
	light.Color = Color3.fromRGB(255, 150, 60)
	light.Parent = fire
	m.PrimaryPart = body
	m.Parent = parent
	return m, body
end

-- finds a free, flat spot near pos (looks around in a ring)
local function spotNear(pos, avoid, up)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = avoid
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Exclude
	op.FilterDescendantsInstances = avoid
	for _, r in ipairs({ 7, 9, 11, 13 }) do
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			local p = pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local hit = workspace:Raycast(p + Vector3.new(0, up, 0), Vector3.new(0, -up - 30, 0), params)
			if hit and hit.Normal.Y > 0.8 and math.abs(hit.Position.Y - pos.Y) < 6 then
				local center = hit.Position + Vector3.new(0, 2.4, 0)
				local blocking = workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(5, 4.2, 5), op)
				local solid = false
				for _, b in ipairs(blocking) do
					if b.CanCollide and not b:IsA("Terrain") then solid = true break end
				end
				if not solid then return hit.Position end
			end
		end
	end
	return nil
end

local count = 0
local function hook(m, body)
	count += 1
	local id = "f" .. count
	furnaces[id] = body
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Use"
	pr.ObjectText = "Furnace"
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "furnace")
	pr:SetAttribute("Obj", "furnace")
	pr.Parent = body
	pr.Triggered:Connect(function(player)
		open[player] = id
		ctx.notify(player, "openFurnace", view(player, id))
	end)
end

local function buildAll(folder, vendorParts)
	local avoid = { folder }
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(avoid, pl.Character) end end
	local made = 0
	local function put(pos, up, faceTo)
		local at = spotNear(pos, avoid, up)
		if not at then return false end
		local look = faceTo and Vector3.new(faceTo.X, at.Y, faceTo.Z) or (at + Vector3.new(0, 0, -1))
		local cf = CFrame.lookAt(at, look)
		if (look - at).Magnitude < 0.1 then cf = CFrame.new(at) end
		local m, body = build(cf, folder)
		hook(m, body)
		made += 1
		return true
	end
	-- terrain collision is rebuilt at startup; wait for it before looking for the ground
	local t0 = os.clock()
	while not workspace:GetAttribute("TerrainReady") and os.clock() - t0 < 90 do task.wait(0.5) end
	-- one beside every trader (the roaming black market has none)
	for _, v in ipairs(vendorParts) do
		if v.part and v.part.Parent and v.shop ~= "black" then
			local p = v.part.Position
			local under = p.Y < -26
			put(p - Vector3.new(0, 2.5, 0), under and 6 or 12, p)
		end
	end
	-- a second one in every village, near its middle
	local vf = workspace:FindFirstChild("Villages")
	for _, vil in ipairs(vf and vf:GetChildren() or {}) do
		local cpos = vil:GetAttribute("Center")
		if cpos then
			local hit = workspace:Raycast(cpos + Vector3.new(0, 120, 0), Vector3.new(0, -260, 0))
			local base = hit and hit.Position or cpos
			put(base + Vector3.new(6, 0, 6), 12, base)
		end
	end
	return made
end

function F.start(c, inv, data, vendorParts)
	ctx, Inventory, Data = c, inv, data
	local folder = Instance.new("Folder")
	folder.Name = "Furnaces"
	folder.Parent = workspace
	task.spawn(function()
		local n = buildAll(folder, vendorParts)
		require(script.Parent.Debug).log("furnace", "built " .. n)
	end)
	-- smelting: every 0.25 s
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, boxes in pairs(state) do
				if not player.Parent then state[player] = nil continue end
				local changed = false
				for fid, b in pairs(boxes) do
					local result = b.input and Items.smelt[b.input.id]
					local room = result and not (b.out and (b.out.id ~= result or b.out.n >= Items.stack(result)))
					if result and room and b.fuel and b.fuel.n >= F.FUEL then
						b.t += 0.25
						if b.t >= F.TIME then
							b.t = 0
							b.fuel.n -= F.FUEL
							if b.fuel.n <= 0 then b.fuel = false end
							b.input.n -= 1
							if b.input.n <= 0 then b.input = false end
							if b.out then b.out.n += 1 else b.out = { id = result, n = 1 } end
							ctx.reward(player, 2, 0)
							local part = furnaces[fid]
							if part then ctx.fx("cook", part.Position + Vector3.new(0, 2, 0)) end
						end
						changed = true
					elseif b.t ~= 0 then
						b.t = 0
						changed = true
					end
				end
				if changed and open[player] then F.push(player) end
			end
			-- the glow shows a furnace at work
			local busy = {}
			for _, boxes in pairs(state) do
				for fid, b in pairs(boxes) do if b.t > 0 then busy[fid] = true end end
			end
			for fid, part in pairs(furnaces) do
				local glow = part.Parent and part.Parent:FindFirstChild("Glow")
				local on = busy[fid] == true
				if glow and (glow.Transparency == 0) ~= on then
					glow.Transparency = on and 0 or 0.6
					local l = glow:FindFirstChildWhichIsA("PointLight")
					if l then l.Brightness = on and 1.6 or 0 end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- give everything back so nothing is lost
		local room = Data.room(player)
		for _, b in pairs(state[player] or {}) do
			for _, k in ipairs({ "input", "fuel", "out" }) do
				local it = b[k]
				if it and room then Inventory.add(room.inv, it.id, it.n) end
			end
		end
		state[player] = nil
		open[player] = nil
	end)
end

-- moving items between the bag and the furnace (indices 201 input, 202 fuel, 203 output)
function F.move(player, room, a, b)
	local fid = open[player]
	local part = fid and furnaces[fid]
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not part or not hrp or (hrp.Position - part.Position).Magnitude > 16 then return false end
	local bx = box(player, fid)
	local inv = room.inv
	local function slotOk(i) return i and i >= 1 and i <= Config.HOTBAR + Config.BIG_BAG and Inventory.usable(inv, i) end
	local key = { [IN] = "input", [FUEL] = "fuel", [OUT] = "out" }
	if key[b] and slotOk(a) then
		-- bag -> furnace (the whole stack, or as much as fits)
		local sl = inv.slots[a]
		if not sl then return true end
		if b == OUT then return true end
		if b == FUEL and sl.id ~= "wood" then ctx.notify(player, "needWoodFuel") return true end
		if b == IN and not Items.smelt[sl.id] then ctx.notify(player, "cantSmelt") return true end
		local cur = bx[key[b]]
		if cur and cur.id ~= sl.id then return true end
		local room2 = Items.stack(sl.id) - (cur and cur.n or 0)
		local n = math.min(room2, sl.n)
		if n <= 0 then return true end
		bx[key[b]] = { id = sl.id, n = (cur and cur.n or 0) + n }
		Inventory.removeSlot(inv, a, n)
		F.push(player)
		return true
	end
	if key[a] then
		-- furnace -> bag (into slot b if given, otherwise anywhere)
		local it = bx[key[a]]
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
			bx[key[a]] = false
		end
		if a == IN then bx.t = 0 end
		F.push(player)
		return true
	end
	return false
end

function F.close(player) open[player] = nil end
F.build = build

return F
