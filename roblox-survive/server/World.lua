-- World server (one reserved server = one room).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)
local Appearance = require(ReplicatedStorage.Shared.Appearance)
local Data = require(script.Parent.Data)
local Rooms = require(script.Parent.Rooms)
local Inventory = require(script.Parent.Inventory)
local Resources = require(script.Parent.Resources)
local Mobs = require(script.Parent.Mobs)
local Loot = require(script.Parent.Loot)
local Survival = require(script.Parent.Survival)
local Debug = require(script.Parent.Debug)
local Bestiary = require(ReplicatedStorage.Shared.Bestiary)
local Biomes = require(ReplicatedStorage.Shared.Biomes)

local MessagingService = game:GetService("MessagingService")

local World = {}

local remotes
local serverCode = nil
local selected = {} -- [Player] = hotbar index
local cooldown = {} -- [Player] = { [key] = clock }
local luckCd = {}
local rng = Random.new()
local buffs = {} -- [Player] = { [name] = expiry clock }
local sleeping = {} -- [Player] = bed model
local beds = {} -- [Player] = bed model they own
local lastHit = {} -- [Player] = what hurt them last (shown on the death screen)
local placedOnce = {} -- [Player] = already put at their saved spot this visit
local lamp = {} -- [Player] = hotbar/bag slot of the lantern hanging in the left hand
local deathBag = {} -- [Player] = { model, x, z } items left where the player died
local mapDirty = {} -- [Player] = explored cells changed since the last send

-- world map: reveal the cells around a position (a string of "0"/"1", one per cell)
local MAPN = Config.MAP_CELLS
local CELL = (2 * Biomes.HALF) / MAPN
local function reveal(player, pos)
	local room = Data.room(player)
	if not room then return end
	local ex = room.explored
	if type(ex) ~= "string" or #ex ~= MAPN * MAPN then ex = string.rep("0", MAPN * MAPN) end
	local cx = math.floor((pos.X + Biomes.HALF) / CELL)
	local cz = math.floor((pos.Z + Biomes.HALF) / CELL)
	local changed = false
	for dz = -2, 2 do
		for dx = -2, 2 do
			local x, z = cx + dx, cz + dz
			if dx * dx + dz * dz <= 5 and x >= 0 and z >= 0 and x < MAPN and z < MAPN then
				local i = z * MAPN + x + 1
				if ex:sub(i, i) ~= "1" then
					ex = ex:sub(1, i - 1) .. "1" .. ex:sub(i + 1)
					changed = true
				end
			end
		end
	end
	room.explored = ex
	if changed then mapDirty[player] = true end
end

-- places shown on the map (only where the player has explored)
local pois = nil
local function mapPois()
	if pois then return pois end
	pois = {}
	local function add(kind, p) table.insert(pois, { kind, math.floor(p.X), math.floor(p.Z) }) end
	local camp = workspace:FindFirstChild("Camp")
	if camp then add("trader", camp:GetPivot().Position) end
	for _, o in ipairs(workspace:FindFirstChild("Outposts") and workspace.Outposts:GetChildren() or {}) do add("trader", o:GetPivot().Position) end
	for _, v in ipairs(workspace:FindFirstChild("Villages") and workspace.Villages:GetChildren() or {}) do
		local c = v:GetAttribute("Center")
		if c then add("village", c) end
	end
	for _, cv in ipairs(workspace:FindFirstChild("Caves") and workspace.Caves:GetChildren() or {}) do
		local e = cv:GetAttribute("Entry")
		if e then add("cave", e) end
	end
	return pois
end

-- the lantern hangs from the left hand while the right hand keeps its tool
local function setLamp(player, on)
	local char = player.Character
	if not char then return end
	local old = char:FindFirstChild("OffhandLamp")
	if old then old:Destroy() end
	if not on then return end
	local hand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
	local m = Items.model("lantern")
	if not hand or not m then return end
	m.Name = "OffhandLamp"
	local drop = hand.Name == "LeftHand" and 1.15 or 1.9
	m:PivotTo(hand.CFrame * CFrame.new(0, -drop, -0.15))
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = false
			p.Massless = true
			if p.Material == Enum.Material.Neon then
				local l = Instance.new("PointLight")
				l.Range = 42
				l.Brightness = 2.6
				l.Shadows = true
				l.Color = Color3.fromRGB(255, 210, 150)
				l.Parent = p
			end
		end
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = m.PrimaryPart
	w.Parent = m.PrimaryPart
	m.Parent = char
end

local function hasBuff(player, name)
	local b = buffs[player]
	return b ~= nil and b[name] ~= nil and b[name] > os.clock()
end

local function cd(player, key, t)
	cooldown[player] = cooldown[player] or {}
	local now = os.clock()
	if cooldown[player][key] and now - cooldown[player][key] < t then return false end
	cooldown[player][key] = now
	return true
end

local function skill(player, name)
	local room = Data.room(player)
	return room and room.skills and room.skills[name] or 0
end

---------------------------------------------------------------- state
local function snapshot(player)
	local room, profile = Data.room(player), Data.profile(player)
	if not room or not profile then return nil end
	local level, into, need = Config.levelFromXp(room.xp)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return {
		coins = room.coins, sp = room.sp, xp = room.xp, level = level, into = into, need = need,
		slots = Inventory.view(room.inv), bag = room.inv.bag, sel = selected[player] or 0,
		code = serverCode, lang = profile.lang, players = #Players:GetPlayers(), bagPrice = Config.BAG_PRICE,
		hunger = room.hunger, thirst = room.thirst, temp = Survival.temp(player),
		hp = hum and hum.Health or 0, maxHp = hum and hum.MaxHealth or 100,
		skills = room.skills, night = ReplicatedStorage:GetAttribute("Night") == true, clock = Lighting.ClockTime,
		day = ReplicatedStorage:GetAttribute("Day") or 1,
		armor = room.inv.armor or false,
		buffs = (function()
			local out = {}
			for k, t in pairs(buffs[player] or {}) do
				local left = math.floor(t - os.clock())
				if left > 0 then out[k] = left end
			end
			return out
		end)(),
		sleeping = sleeping[player] ~= nil,
		lamp = lamp[player] or 0,
		death = (deathBag[player] and deathBag[player][1].Parent) and { deathBag[player][2], deathBag[player][3] } or nil,
		dex = room.dex,
		stash = Inventory.stashView(room.stash), stashLvl = room.stash.lvl,
		stashCost = room.stash.lvl < Config.STASH_MAX_LVL and Config.stashCost(room.stash.lvl) or nil,
	}
end

local function push(player)
	local s = snapshot(player)
	if s then remotes.State:FireClient(player, s) end
end

local function notify(player, key, a, b)
	remotes.Notify:FireClient(player, key, a, b)
end

local function hrpOf(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

---------------------------------------------------------------- context shared with the other systems
local ctx = {}
ctx.room = Data.room
ctx.buff = hasBuff
ctx.push = push
ctx.notify = notify
function ctx.broadcast(key, a)
	for _, pl in ipairs(Players:GetPlayers()) do notify(pl, key, a) end
end
function ctx.space(player, id)
	local room = Data.room(player)
	return room and Inventory.space(room.inv, id) or 0
end
function ctx.giveItem(player, it)
	local room = Data.room(player)
	if not room then return it.n end
	local rest = Inventory.add(room.inv, it.id, it.n, it.d)
	push(player)
	return rest
end
function ctx.give(player, id, n)
	return ctx.giveItem(player, { id = id, n = n })
end
function ctx.lucky(player, perLevel)
	return rng:NextNumber() < math.min(0.5, perLevel * skill(player, "luck"))
end
function ctx.reward(player, xp, coins)
	if not Data.room(player) then return end
	Data.addCoins(player, coins or 0)
	local gained, level = Data.addXp(player, xp or 0)
	if gained > 0 then
		notify(player, "levelUp", level)
		if player.Character then ctx.fx("levelUp", player.Character) end
	end
	push(player)
end
function ctx.hurt(player, amount, cause)
	local _, hum = hrpOf(player)
	if not hum or hum.Health <= 0 then return end
	if type(cause) == "string" then lastHit[player] = cause end
	local room = Data.room(player)
	local armor = room and room.inv.armor and Items.get(room.inv.armor)
	if armor then amount *= (1 - armor.reduce) end
	if hasBuff(player, "stone") then amount *= 0.6 end
	if sleeping[player] and ctx.wake then ctx.wake(player) end
	if hum.Health - amount <= 0 and ctx.lucky(player, 0.03) and (not luckCd[player] or os.clock() - luckCd[player] > 90) then
		luckCd[player] = os.clock()
		hum.Health = 1
		notify(player, "lucky")
		return
	end
	hum:TakeDamage(amount)
	if player.Character then ctx.fx("hurt", player.Character) end
end
-- "power" of a player: level, skills, best weapon and max health (used to level creatures)
function ctx.power(player)
	local room = Data.room(player)
	if not room then return 1 end
	local level = Config.levelFromXp(room.xp)
	local skills = 0
	for _, v in pairs(room.skills or {}) do skills += v end
	local best = 0
	for _, sl in ipairs(room.inv.slots) do
		local d = sl and Items.get(sl.id)
		if d and d.dmg and d.dmg > best then best = d.dmg end
	end
	local _, hum = hrpOf(player)
	local hp = hum and hum.MaxHealth or 100
	-- mostly the player's level, gear and skills only nudge it
	return math.max(1, level * 0.75 + skills * 0.35 + best / 10 + (hp - 100) / 40)
end
-- creature index: discoveries, kills and region necklaces
local function wearNecklace(player)
	local room = Data.room(player)
	local char = player.Character
	if not room or not char then return end
	local neck = room.dex and room.dex.neck
	Appearance.necklace(char, neck and Biomes.medal[neck] or nil)
end
function ctx.seen(player, kind)
	local room = Data.room(player)
	if not room or not room.dex or not Bestiary.kinds[kind] or room.dex.seen[kind] then return end
	room.dex.seen[kind] = true
	notify(player, "discovered", kind)
	push(player)
end
function ctx.killed(player, kind)
	local room = Data.room(player)
	if not room or not room.dex or not Bestiary.kinds[kind] then return end
	room.dex.seen[kind] = true
	room.dex.kills[kind] = (room.dex.kills[kind] or 0) + 1
	for _, region in ipairs(Bestiary.completed(room.dex.kills)) do
		if not room.dex.medals[region] then
			room.dex.medals[region] = true
			notify(player, "medalGot", region)
			if player.Character then ctx.fx("levelUp", player.Character) end
			ctx.reward(player, 250, 400)
			if not room.dex.neck then
				room.dex.neck = region
				wearNecklace(player)
			end
		end
	end
end

function ctx.addSp(player, n)
	local room = Data.room(player)
	if not room then return end
	room.sp += n
	notify(player, "spGot", n)
	if player.Character then ctx.fx("skillUp", player.Character) end
	push(player)
end
function ctx.newDay(day)
	if serverCode and serverCode ~= "TEST00" then
		Rooms.update(serverCode, function(rec) rec.day = math.max(rec.day or 1, day) end)
	end
	for _, pl in ipairs(Players:GetPlayers()) do notify(pl, "newDay", day) end
end
function ctx.fx(kind, a, b, c)
	remotes.Fx:FireAllClients(kind, a, b, c)
end
function ctx.drop(pos, items, owner)
	return Loot.drop(pos, items, owner)
end

---------------------------------------------------------------- tools
local function clearTools(player)
	local char = player.Character
	if not char then return end
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") then c:Destroy() end
	end
end

local select -- forward
local applyStats -- forward

local function useDurability(player, index)
	local room = Data.room(player)
	local slot = room and room.inv.slots[index]
	if not slot or not slot.d then return end
	if ctx.lucky(player, 0.04) then return end
	slot.d -= 1
	if slot.d <= 0 then
		room.inv.slots[index] = false
		notify(player, "broke")
		select(player, 0)
	end
end


local function swing(player, index, def)
	if not cd(player, "swing", 0.55) then return end
	local hrp = hrpOf(player)
	if not hrp then return end
	local animKind = ((def.class == "axe" or def.class == "hammer") and "chop") or (def.class == "pickaxe" and "mine") or (def.class == "spear" and "thrust") or "slash"
	ctx.fx("anim", player.Character, animKind)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Mobs.folder(), Resources.folder() }
	local reach = def.reach or 6
	local parts = workspace:GetPartBoundsInBox(hrp.CFrame * CFrame.new(0, 0, -(reach / 2 + 1.5)), Vector3.new(7, 8, reach + 2), params)
	local str = skill(player, "strength")
	local best, bd
	for _, p in ipairs(parts) do
		local m = Mobs.modelOf(p)
		if m then
			local d = (p.Position - hrp.Position).Magnitude
			if not bd or d < bd then best, bd = m, d end
		end
	end
	if best then
		Mobs.damage(best, (def.dmg or 5) * (1 + 0.1 * str) * (hasBuff(player, "strength") and 1.5 or 1), player)
		useDurability(player, index)
		return
	end
	local node = Resources.pick(parts, hrp.Position)
	if node and Resources.hit(player, node, def, math.floor(str / 3)) then
		useDurability(player, index)
	end
end

local function shoot(player, index, dir)
	local room = Data.room(player)
	local slot = room and room.inv.slots[index]
	local def = slot and Items.get(slot.id)
	if not def or def.kind ~= "ranged" or selected[player] ~= index then return end
	if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.5 then return end
	if not cd(player, "shoot", def.rate) then return end
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	if Inventory.count(room.inv, def.ammo) <= 0 then
		notify(player, "noAmmo")
		return
	end
	if not ctx.lucky(player, 0.04) then Inventory.remove(room.inv, def.ammo, 1) end
	local origin = head.Position + Vector3.new(0, 0.3, 0)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { char }
	for _, n in ipairs({ "Loot", "Decor", "Traps" }) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	rp.FilterDescendantsInstances = ex
	local res = workspace:Raycast(origin, dir.Unit * def.range, rp)
	local hitPos = res and res.Position or (origin + dir.Unit * def.range)
	ctx.fx("shoot", origin, hitPos, def.ammo)
	ctx.fx("anim", char, def.ammo == "arrow" and "bow" or "gun")
	if res then
		local m = Mobs.modelOf(res.Instance)
		if m then Mobs.damage(m, def.dmg * (1 + 0.1 * skill(player, "strength")) * (hasBuff(player, "strength") and 1.5 or 1), player) end
	end
	useDurability(player, index)
	push(player)
end

local cooking = {}
local function cookAll(player, firePart)
	local room = Data.room(player)
	if not room then return end
	if cooking[player] then cooking[player] = nil return end -- second press stops
	if Inventory.count(room.inv, "meat_raw") <= 0 then
		notify(player, "noMeat")
		return
	end
	cooking[player] = true
	notify(player, "cooking")
	task.spawn(function()
		while cooking[player] and player.Parent do
			task.wait(1.5)
			local r = Data.room(player)
			local hrp = hrpOf(player)
			if not cooking[player] or not r or not hrp or not firePart or not firePart.Parent then break end
			if (hrp.Position - firePart.Position).Magnitude > 14 then break end
			if not Inventory.remove(r.inv, "meat_raw", 1) then break end
			local rest = Inventory.add(r.inv, "meat_cooked", 1)
			if rest > 0 then Loot.drop(hrp.Position, { { id = "meat_cooked", n = rest } }, player.UserId) end
			ctx.fx("cook", firePart.Position)
			ctx.reward(player, 2, 0)
			notify(player, "cookedOne")
		end
		cooking[player] = nil
	end)
end

local function hookFire(part)
	CollectionService:AddTag(part, "Heat")
	local pr = part:FindFirstChildWhichIsA("ProximityPrompt")
	if not pr then
		pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Cook"
		pr.ObjectText = "Fire"
		pr.HoldDuration = 0.6
		pr.MaxActivationDistance = 10
		pr.RequiresLineOfSight = false
		pr.Parent = part
	end
	pr:SetAttribute("Key", "cook")
	pr:SetAttribute("Obj", "fire")
	pr.Triggered:Connect(function(player) cookAll(player, part) end)
end

local function place(player, index, def, id)
	if not cd(player, "place", 1) then return end
	local hrp = hrpOf(player)
	local room = Data.room(player)
	if not hrp or not room then return end
	local at = (hrp.CFrame * CFrame.new(0, 0, -4)).Position
	local res = { Position = require(script.Parent.Ground).below(at, { player.Character, Mobs.folder() }) }
	if not Inventory.removeSlot(room.inv, index, 1) then return end
	local m = Items.model(id)
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end
	m:PivotTo(CFrame.new(res.Position + Vector3.new(0, 0.25, 0)))
	if id == "dynamite" then
		m.Parent = workspace
		local at = m:GetPivot().Position
		task.delay(3, function()
			if m.Parent then m:Destroy() end
			ctx.fx("explode", at)
			for _, mob in ipairs(Mobs.folder():GetChildren()) do
				local root = mob.PrimaryPart
				if root and (root.Position - at).Magnitude < 16 then Mobs.damage(mob, 140, player.Parent and player or nil) end
			end
			if player.Parent then
				for _, node in ipairs(Resources.near(at, 13)) do
					Resources.hit(player, node, { tree = 5, rock = 9 }, 0)
				end
			end
		end)
	elseif id == "bed" then
		if beds[player] and beds[player].Parent then beds[player]:Destroy() end
		m.Name = "Bed"
		m:SetAttribute("Owner", player.UserId)
		local look = hrp.CFrame.LookVector
		m:PivotTo(CFrame.lookAt(res.Position + Vector3.new(0, 0.05, 0), res.Position + Vector3.new(look.X, 0.05, look.Z)))
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = true p.CanQuery = true end
		end
		local pr = Instance.new("ProximityPrompt")
		pr.ActionText = "Sleep"
		pr.ObjectText = "Bed"
		pr.HoldDuration = 0.5
		pr.MaxActivationDistance = 9
		pr.RequiresLineOfSight = false
		pr:SetAttribute("Key", "sleep")
		pr:SetAttribute("Obj", "bed")
		pr.Parent = m.PrimaryPart
		m.Parent = workspace
		beds[player] = m
		pr.Triggered:Connect(function(pl) ctx.sleep(pl, m) end)
		notify(player, "bedPlaced")
	elseif id == "trap" then
		m:SetAttribute("Owner", player.UserId)
		m.Parent = Mobs.traps()
		task.delay(600, function() if m.Parent then m:Destroy() end end)
	else
		m.Name = "Campfire"
		m.Parent = workspace
		local core
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Material == Enum.Material.Neon then core = p end
		end
		core = core or m.PrimaryPart
		local fire = Instance.new("Fire")
		fire.Size = 5
		fire.Parent = core
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 160, 80)
		light.Parent = core
		hookFire(core)
		task.delay(300, function() if m.Parent then m:Destroy() end end)
	end
	ctx.fx("anim", player.Character, "place")
	ctx.fx("place", res.Position)
	if id ~= "bed" then notify(player, "placed") end
	if not room.inv.slots[index] then select(player, 0) else push(player) end
end

function select(player, index)
	local room = Data.room(player)
	if not room then return end
	do
		local i = tonumber(index)
		local sl = i and room.inv.slots[i]
		local d = sl and Items.get(sl.id)
		if d and d.kind == "light" and i >= 1 and i <= Config.HOTBAR then
			if lamp[player] == i then lamp[player] = nil else lamp[player] = i end
			setLamp(player, lamp[player] ~= nil)
			push(player)
			return
		end
	end
	clearTools(player)
	index = tonumber(index)
	if not index or index < 1 or index > Config.HOTBAR or index ~= math.floor(index) then
		selected[player] = 0
		push(player)
		return
	end
	local slot = room.inv.slots[index]
	local def = slot and Items.get(slot.id)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not slot or not def or not hum or hum.Health <= 0 then
		selected[player] = 0
		push(player)
		return
	end
	selected[player] = index
	local id = slot.id
	local tool = Items.buildTool(id)
	if tool then
		if def.kind == "ranged" then tool:SetAttribute("Ranged", true) end
		if def.kind == "light" then
			for _, p in ipairs(tool:GetDescendants()) do
				if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
					local l = Instance.new("PointLight")
					l.Range = 42
					l.Brightness = 2.6
					l.Shadows = true
					l.Color = Color3.fromRGB(255, 210, 150)
					l.Parent = p
				end
			end
		end
		tool.Activated:Connect(function()
			local r = Data.room(player)
			local cur = r and r.inv.slots[index]
			if not cur or cur.id ~= id or selected[player] ~= index then return end
			if def.kind == "tool" then
				swing(player, index, def)
			elseif def.kind == "food" or def.kind == "heal" then
				if not cd(player, "eat", 0.8) then return end
				if Inventory.removeSlot(r.inv, index, 1) then
					ctx.fx("anim", char, def.kind == "heal" and "heal" or "eat")
					if def.hunger then r.hunger = math.min(100, r.hunger + def.hunger) end
					local heal = (def.heal or 0) * (def.kind == "heal" and (1 + 0.1 * skill(player, "aid")) or 1)
					hum.Health = math.min(hum.MaxHealth, hum.Health + heal)
					if not r.inv.slots[index] then select(player, 0) else push(player) end
				end
			elseif def.kind == "place" then
				place(player, index, def, id)
			elseif def.kind == "potion" then
				if not cd(player, "drink", 1) then return end
				if Inventory.removeSlot(r.inv, index, 1) then
					buffs[player] = buffs[player] or {}
					buffs[player][def.buff] = os.clock() + def.time
					ctx.fx("anim", char, "eat")
					ctx.fx("skillUp", char)
					notify(player, "drank", id)
					applyStats(player)
					if not r.inv.slots[index] then select(player, 0) else push(player) end
				end
			elseif def.kind == "armor" then
				if not cd(player, "wear", 0.8) then return end
				local old = r.inv.armor
				r.inv.slots[index] = false
				r.inv.armor = id
				if old then Inventory.add(r.inv, old, 1) end
				Appearance.armor(char, def.color, def.mat, id)
				ctx.fx("anim", char, "place")
				notify(player, "armorOn")
				select(player, 0)
			end
		end)
		tool.Parent = char
	end
	push(player)
end

local function revalidate(player)
	local room = Data.room(player)
	local idx = selected[player] or 0
	if idx == 0 or not room then push(player) return end
	local slot = room.inv.slots[idx]
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not slot then select(player, 0)
	elseif not tool or tool:GetAttribute("ItemId") ~= slot.id then select(player, idx)
	else push(player) end
end

---------------------------------------------------------------- characters
function applyStats(player)
	local _, hum = hrpOf(player)
	if not hum then return end
	local hp = 100 + 10 * skill(player, "health")
	local ratio = hum.Health / math.max(1, hum.MaxHealth)
	hum.MaxHealth = hp
	hum.Health = math.clamp(hp * ratio, 1, hp)
	hum.WalkSpeed = (16 + 0.6 * math.min(skill(player, "speed"), Config.SKILL_CAP.speed or 10)) * (hasBuff(player, "speed") and 1.3 or 1)
end

local function guardCharacter(char)
	char.ChildAdded:Connect(function(c)
		if (c:IsA("Accessory") and not c:GetAttribute("Custom")) or c:IsA("Shirt") or c:IsA("Pants")
			or c:IsA("ShirtGraphic") or c:IsA("BodyColors") or c:IsA("CharacterMesh") then
			task.defer(function() if c.Parent then c:Destroy() end end)
		end
	end)
end

local function spawnCharacter(player)
	if player.Parent then player:LoadCharacter() end
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	guardCharacter(char)
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local profile = Data.profile(player)
	Appearance.apply(char, profile and profile.look)
	local spawn = workspace:FindFirstChild("ForestSpawn")
	local saved = Data.room(player) and Data.room(player).pos
	if saved and not placedOnce[player] then
		-- back where the player left the room
		char:PivotTo(CFrame.new(saved[1], saved[2] + 3, saved[3]))
		-- far from the camp the ground may still be rebuilding: hold the player until it is solid
		local root = char:FindFirstChild("HumanoidRootPart")
		if root and not workspace:GetAttribute("TerrainReady") then
			root.Anchored = true
			task.spawn(function()
				local t0 = os.clock()
				while not workspace:GetAttribute("TerrainReady") and os.clock() - t0 < 90 do task.wait(0.5) end
				if root.Parent then root.Anchored = false end
			end)
		end
	elseif spawn then
		char:PivotTo(CFrame.new(spawn.Position + Vector3.new(rng:NextNumber(-8, 8), 4, rng:NextNumber(-8, 8))))
	end
	placedOnce[player] = true
	selected[player] = 0
	lamp[player] = nil
	Survival.reset(player)
	local room = Data.room(player)
	if room then
		room.hunger = math.max(room.hunger, 40)
		room.thirst = math.max(room.thirst, 40)
	end
	if room and room.inv.armor then
		local ad = Items.get(room.inv.armor)
		if ad then Appearance.armor(char, ad.color, ad.mat, room.inv.armor) end
	end
	task.defer(wearNecklace, player)
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = 100
	hum.Health = 100
	applyStats(player)
	hum.Health = hum.MaxHealth
	hum.Died:Connect(function()
		notify(player, "deathBy", lastHit[player] or "unknown")
		local rr = Data.room(player)
		if rr then rr.pos = nil end
		lastHit[player] = nil
		-- ragdoll: joints become ball sockets so the body collapses onto the ground
		pcall(function()
			for _, m in ipairs(char:GetDescendants()) do
				if m:IsA("Motor6D") and m.Part0 and m.Part1 then
					local a0 = Instance.new("Attachment")
					a0.CFrame = m.C0
					a0.Parent = m.Part0
					local a1 = Instance.new("Attachment")
					a1.CFrame = m.C1
					a1.Parent = m.Part1
					local bs = Instance.new("BallSocketConstraint")
					bs.Attachment0 = a0
					bs.Attachment1 = a1
					bs.LimitsEnabled = true
					bs.UpperAngle = 50
					bs.TwistLimitsEnabled = true
					bs.TwistLowerAngle = -35
					bs.TwistUpperAngle = 35
					bs.Parent = m.Part0
					m:Destroy()
				end
			end
			for _, p in ipairs(char:GetChildren()) do
				if p:IsA("BasePart") then
					if p.Name == "HumanoidRootPart" then
						p.CanCollide = false
						p.Massless = true
					else
						local col = Instance.new("Part")
						col.Name = "RagdollCollider"
						col.Size = p.Size * 0.9
						col.CFrame = p.CFrame
						col.Transparency = 1
						col.CanCollide = true
						col.CanQuery = false
						col.CanTouch = false
						col.Parent = char
						local wc = Instance.new("WeldConstraint")
						wc.Part0 = p
						wc.Part1 = col
						wc.Parent = col
					end
				end
			end
			local root = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
			if root then root:ApplyImpulse(-root.CFrame.LookVector * root.AssemblyMass * 12) end
		end)
		clearTools(player)
		selected[player] = 0
		local r = Data.room(player)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if r and hrp then
			local items = Inventory.takeAll(r.inv)
			if #items > 0 then
				local bag = Loot.drop(hrp.Position, items, player.UserId)
				if bag then deathBag[player] = { bag, math.floor(hrp.Position.X), math.floor(hrp.Position.Z) } end
				notify(player, "died")
			end
		end
		push(player)
		task.delay(Players.RespawnTime, function() spawnCharacter(player) end)
	end)
	push(player)
end

---------------------------------------------------------------- vendor
local vendors = {} -- { part, shop }
local function isNight()
	return ReplicatedStorage:GetAttribute("Night") == true
end
-- shop id of the trader the player stands at (nil if none)
local function nearVendor(player, shop)
	local hrp = hrpOf(player)
	if not hrp then return nil end
	for _, v in ipairs(vendors) do
		if v.part.Parent and (not shop or v.shop == shop) and (hrp.Position - v.part.Position).Magnitude <= Config.VENDOR_RANGE then
			return v.shop
		end
	end
	return nil
end


---------------------------------------------------------------- sleeping: the night ends when everyone sleeps
local function sleepCount()
	local n, total = 0, 0
	for _, pl in ipairs(Players:GetPlayers()) do
		local _, hum = hrpOf(pl)
		if hum and hum.Health > 0 then
			total += 1
			if sleeping[pl] then n += 1 end
		end
	end
	return n, total
end
local function announceSleep()
	local n, total = sleepCount()
	for _, pl in ipairs(Players:GetPlayers()) do notify(pl, "sleepCount", n, total) end
end
function ctx.wake(player)
	local bed = sleeping[player]
	if not bed then return end
	sleeping[player] = nil
	bed:SetAttribute("Sleeper", nil)
	local hrp, hum = hrpOf(player)
	if hrp then
		hrp.Anchored = false
		if hum then hum.PlatformStand = false end
		if bed.Parent then
			hrp.CFrame = CFrame.new((bed:GetPivot() * CFrame.new(3.4, 3, 0)).Position)
		end
	end
	notify(player, "woke")
	announceSleep()
	push(player)
end
function ctx.sleep(player, bed)
	if sleeping[player] then ctx.wake(player) return end
	if not isNight() then notify(player, "notTired") return end
	local occupant = bed:GetAttribute("Sleeper")
	if occupant and occupant ~= player.UserId then notify(player, "bedTaken") return end
	local hrp, hum = hrpOf(player)
	if not hrp or not hum or hum.Health <= 0 then return end
	select(player, 0)
	sleeping[player] = bed
	bed:SetAttribute("Sleeper", player.UserId)
	hum.PlatformStand = true
	hrp.Anchored = true
	-- lie on the mattress, head on the pillow
	hrp.CFrame = bed:GetPivot() * CFrame.new(0, 1.9, 0.4) * CFrame.Angles(math.rad(90), 0, 0)
	notify(player, "sleepStart")
	announceSleep()
	push(player)
end
local function checkSleep()
	if not isNight() then
		for pl in pairs(sleeping) do ctx.wake(pl) end
		return
	end
	local n, total = sleepCount()
	if n > 0 and n >= total then
		Survival.skipNight()
		for pl in pairs(sleeping) do
			local _, hum = hrpOf(pl)
			if hum then hum.Health = hum.MaxHealth end
			ctx.wake(pl)
		end
		for _, pl in ipairs(Players:GetPlayers()) do notify(pl, "slept") end
	end
end

---------------------------------------------------------------- lantern burn + potion timers (every second)
local function lightAndBuffs(player)
	local room = Data.room(player)
	if not room then return end
	local li = lamp[player]
	if li then
		local slot = room.inv.slots[li]
		if not slot or slot.id ~= "lantern" then
			-- the lantern was moved: follow it, or put the light out if it left the inventory
			li = nil
			for i, sl in ipairs(room.inv.slots) do
				if sl and sl.id == "lantern" then li = i break end
			end
			lamp[player] = li
			if not li then setLamp(player, false) end
		end
		if li then
			slot = room.inv.slots[li]
			local def = Items.get("lantern")
			slot.d = (slot.d or def.dur) - 1
			if slot.d <= 0 then
				room.inv.slots[li] = false
				lamp[player] = nil
				setLamp(player, false)
				notify(player, "lanternDead")
			end
		end
	end
	local b = buffs[player]
	if b then
		local _, hum = hrpOf(player)
		if hasBuff(player, "regen") and hum and hum.Health > 0 then
			hum.Health = math.min(hum.MaxHealth, hum.Health + 3)
		end
		for k, t in pairs(b) do
			if t <= os.clock() then
				b[k] = nil
				notify(player, "buffEnd", k)
				if k == "speed" then applyStats(player) end
			end
		end
	end
end

---------------------------------------------------------------- the secret trader: open day and night, never stays long
local black = { model = nil, spot = nil, vendor = nil }
local BLACK_STAY = 420
local function newRig()
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then return nil end
	for _, d in ipairs(rig:GetDescendants()) do if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end end
	rig:FindFirstChildOfClass("Humanoid").DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rig.HumanoidRootPart.Anchored = true
	return rig
end
local function bpart(parent, size, cf, color, mat, shape, collide)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.Parent = parent
	return p
end
local function buildBlack(cf)
	local folder = workspace:FindFirstChild("BlackMarkets") or Instance.new("Folder")
	folder.Name = "BlackMarkets"
	folder.Parent = workspace
	local m = Instance.new("Model")
	m.Name = "BlackMarket"
	local cloth, dark, wood = Color3.fromRGB(46, 30, 58), Color3.fromRGB(24, 18, 30), Color3.fromRGB(70, 50, 36)
	bpart(m, Vector3.new(11, 0.2, 9), cf * CFrame.new(0, 0.1, 0), cloth, Enum.Material.Fabric)
	-- low lean-to tent behind the trader
	for _, x in ipairs({ -1, 1 }) do
		bpart(m, Vector3.new(0.4, 6, 0.4), cf * CFrame.new(x * 5, 3, 3.6), wood, Enum.Material.Wood, nil, true)
	end
	bpart(m, Vector3.new(11, 0.25, 6.4), cf * CFrame.new(0, 5.2, 1.2) * CFrame.Angles(math.rad(-28), 0, 0), dark, Enum.Material.Fabric, nil, true)
	local counter = bpart(m, Vector3.new(6, 2.4, 1.8), cf * CFrame.new(0, 1.2, -2.2), wood, Enum.Material.WoodPlanks, nil, true)
	bpart(m, Vector3.new(6.4, 0.25, 2.1), cf * CFrame.new(0, 2.5, -2.2), cloth, Enum.Material.Fabric)
	for i, id in ipairs({ "potion_vision", "potion_strength", "potion_speed" }) do
		local it = Items.model(id)
		if it then
			for _, d in ipairs(it:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
			it:PivotTo(cf * CFrame.new(-1.8 + (i - 1) * 1.8, 3.2, -2.2))
			it.Parent = m
		end
	end
	for i = 1, 3 do
		bpart(m, Vector3.new(2, 2, 2), cf * CFrame.new(-4.2 + (i % 2) * 0.6, 1 + (i == 3 and 2 or 0), 2.4 - (i == 3 and 0 or i * 0.1)), Color3.fromRGB(90, 64, 44), Enum.Material.WoodPlanks, nil, true)
	end
	local lamp = bpart(m, Vector3.new(0.8, 1.1, 0.8), cf * CFrame.new(2.6, 3.1, -2.2), Color3.fromRGB(190, 120, 255), Enum.Material.Neon)
	local l = Instance.new("PointLight")
	l.Range = 16
	l.Brightness = 1.3
	l.Color = Color3.fromRGB(180, 110, 255)
	l.Parent = lamp
	local rig = newRig()
	if rig then
		rig.Name = "Trader"
		local hum = rig:FindFirstChildOfClass("Humanoid")
		local hh = hum.HipHeight + rig.HumanoidRootPart.Size.Y / 2
		local pos = (cf * CFrame.new(0, hh, 0.2)).Position
		rig:PivotTo(CFrame.lookAt(pos, pos + cf.LookVector))
		rig.Parent = m
		Appearance.apply(rig, { skin = 3, shirt = 6, pants = 6, hat = "none", extra = "none" })
		Appearance.hood(rig)
	end
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = "Shop"
	pr.ObjectText = "Secret Trader"
	pr.HoldDuration = 0
	pr.MaxActivationDistance = 12
	pr.RequiresLineOfSight = false
	pr:SetAttribute("Key", "trade")
	pr:SetAttribute("Shop", "black")
	pr.Parent = counter
	pr.Triggered:Connect(function(player) notify(player, "openShop", "black") end)
	m.Parent = folder
	return m, counter
end
local function moveBlack()
	local spotsF = workspace:FindFirstChild("BlackMarketSpots")
	local spots = spotsF and spotsF:GetChildren() or {}
	if #spots == 0 then return false end
	-- don't vanish in front of a customer
	if black.model then
		for _, pl in ipairs(Players:GetPlayers()) do
			local hrp = hrpOf(pl)
			if hrp and (hrp.Position - black.model:GetPivot().Position).Magnitude < 35 then return false end
		end
	end
	local pick
	for _ = 1, 10 do
		pick = spots[rng:NextInteger(1, #spots)]
		if pick ~= black.spot then break end
	end
	if black.model then black.model:Destroy() end
	for i, v in ipairs(vendors) do
		if v == black.vendor then table.remove(vendors, i) break end
	end
	local m, counter = buildBlack(pick.CFrame)
	black.model, black.spot = m, pick
	black.vendor = { part = counter, shop = "black" }
	table.insert(vendors, black.vendor)
	Debug.log("black", "moved to " .. tostring(pick.Name))
	return true
end

---------------------------------------------------------------- remote actions
local actions = {}

function actions.select(player, room, i) select(player, i) end
function actions.shoot(player, room, i, dir) shoot(player, tonumber(i), dir) end

function actions.move(player, room, a, b)
	if Inventory.move(room.inv, tonumber(a), tonumber(b)) then revalidate(player) end
end

function actions.discard(player, room, i, count)
	i = tonumber(i)
	if not i or not Inventory.usable(room.inv, i) then return end
	local s = room.inv.slots[i]
	if not s then return end
	local n = math.clamp(math.floor(tonumber(count) or s.n), 1, s.n)
	local id, d = s.id, s.d
	Inventory.removeSlot(room.inv, i, n)
	local hrp = hrpOf(player)
	if hrp then
		local at = (hrp.CFrame * CFrame.new(0, 0, -3)).Position
		Loot.dropItem(at, { id = id, n = n, d = d })
		ctx.fx("place", at)
	end
	revalidate(player)
end

function actions.split(player, room, i)
	i = tonumber(i)
	if not i or not Inventory.usable(room.inv, i) then return end
	local s = room.inv.slots[i]
	if not s or s.n < 2 then return end
	for j = 1, Config.HOTBAR + Config.BAG do
		if j ~= i and Inventory.usable(room.inv, j) and not room.inv.slots[j] then
			local half = math.floor(s.n / 2)
			s.n -= half
			room.inv.slots[j] = { id = s.id, n = half }
			push(player)
			return
		end
	end
	notify(player, "bagFull")
end

function actions.buy(player, room, id, shop)
	local def = Items.get(id)
	shop = type(shop) == "string" and shop or "forest"
	if isNight() and shop ~= "black" then notify(player, "shopClosed") return end
	if not def or not def.buy or not Items.inShop(shop, id) then return end
	if not nearVendor(player, shop) then notify(player, "tooFar") return end
	if room.coins < def.buy then notify(player, "needCoins") return end
	local qty = def.buyQty or 1
	if Inventory.space(room.inv, id) < qty then notify(player, "bagFull") return end
	room.coins -= def.buy
	Inventory.add(room.inv, id, qty)
	notify(player, "bought", id)
	ctx.reward(player, math.max(1, math.floor(def.buy / 10)), 0)
end

function actions.buyBag(player, room)
	if isNight() then notify(player, "shopClosed") return end
	if room.inv.bag then return end
	if not nearVendor(player) then notify(player, "tooFar") return end
	if room.coins < Config.BAG_PRICE then notify(player, "needCoins") return end
	room.coins -= Config.BAG_PRICE
	room.inv.bag = true
	notify(player, "bought")
	ctx.reward(player, 15, 0)
end

function actions.sell(player, room, id)
	local def = Items.get(id)
	if not def or not def.sell then return end
	if not nearVendor(player) then notify(player, "tooFar") return end
	if isNight() and not nearVendor(player, "black") then notify(player, "shopClosed") return end
	local n = Inventory.count(room.inv, id)
	if n <= 0 then return end
	Inventory.remove(room.inv, id, n)
	local total = n * def.sell
	room.coins += total
	notify(player, "sold", total)
	ctx.reward(player, math.max(1, math.floor(total / 8)), 0)
	revalidate(player)
end

function actions.skill(player, room, name)
	local valid = false
	for _, k in ipairs(Config.SKILLS) do if k == name then valid = true end end
	if not valid then return end
	if room.sp <= 0 then notify(player, "noPoints") return end
	local cap = Config.SKILL_CAP[name]
	if cap and (room.skills[name] or 0) >= cap then notify(player, "maxed") return end
	room.sp -= 1
	room.skills[name] = (room.skills[name] or 0) + 1
	applyStats(player)
	notify(player, "skillUp", name)
	if player.Character then ctx.fx("skillUp", player.Character) end
	push(player)
end

function actions.leave(player)
	Data.saveRoom(player)
	Data.saveProfile(player)
	Rooms.toLobby(player)
end

function actions.state(player) push(player) end
function actions.map(player, room)
	notify(player, "mapData", mapPois(), room.explored or string.rep("0", MAPN * MAPN))
	mapDirty[player] = nil
end
function actions.wearMedal(player, room, region)
	if type(region) ~= "string" or not room.dex.medals[region] then return end
	room.dex.neck = region
	wearNecklace(player)
	push(player)
end
function actions.wake(player) if ctx.wake then ctx.wake(player) end end

local reports = 0
function actions.report(player, room, msg)
	if reports < 20 and type(msg) == "string" then
		reports += 1
		Debug.log("client", string.sub(msg, 1, 120))
	end
end

local stashParts = {}
local function nearStash(player)
	local hrp = hrpOf(player)
	if not hrp then return false end
	for _, p in ipairs(stashParts) do
		if p.Parent and (p.Position - hrp.Position).Magnitude < 16 then return true end
	end
	return false
end

function actions.stashPut(player, room, i)
	i = tonumber(i)
	if not nearStash(player) or not i or not Inventory.usable(room.inv, i) then return end
	local s = room.inv.slots[i]
	if not s then return end
	local stored = Inventory.stashPut(room.stash, { id = s.id, n = s.n, d = s.d })
	if stored <= 0 then notify(player, "stashFull") return end
	Inventory.removeSlot(room.inv, i, stored)
	revalidate(player)
end

function actions.stashTake(player, room, j)
	j = tonumber(j)
	if not nearStash(player) or not j then return end
	local s = room.stash.slots[j]
	if not s then return end
	local rest = Inventory.add(room.inv, s.id, s.n, s.d)
	if rest >= s.n then notify(player, "bagFull") return end
	if rest > 0 then s.n = rest else room.stash.slots[j] = false end
	push(player)
end

function actions.stashUpgrade(player, room)
	if not nearStash(player) then return end
	if room.stash.lvl >= Config.STASH_MAX_LVL then notify(player, "maxed") return end
	local cost = Config.stashCost(room.stash.lvl)
	if room.coins < cost then notify(player, "needCoins") return end
	room.coins -= cost
	room.stash.lvl += 1
	notify(player, "stashUp", Inventory.stashCap(room.stash))
	if player.Character then ctx.fx("skillUp", player.Character) end
	push(player)
end

function actions.unequipArmor(player, room)
	local id = room.inv.armor
	if not id then return end
	if Inventory.space(room.inv, id) < 1 then notify(player, "bagFull") return end
	room.inv.armor = false
	Inventory.add(room.inv, id, 1)
	if player.Character then Appearance.armor(player.Character, nil) end
	push(player)
end

local serverRec = nil
function actions.answerReq(player, room, uid, accept)
	uid = tonumber(uid)
	if not uid or not serverRec or serverRec.owner ~= player.UserId then return end
	if accept then Rooms.approve(serverCode, uid) end
	pcall(function()
		MessagingService:PublishAsync("RoomResp", { uid = uid, code = serverCode, ok = accept == true })
	end)
end

---------------------------------------------------------------- join
local function resolveCode(player)
	if serverCode then return serverCode end
	local code
	local ok, join = pcall(function() return player:GetJoinData() end)
	if ok and join and join.TeleportData and type(join.TeleportData.code) == "string" then code = join.TeleportData.code end
	if not code and game.PrivateServerId ~= "" then code = Rooms.codeByServer(game.PrivateServerId) end
	if not code and RunService:IsStudio() then code = "TEST00" end
	return code
end

local function onJoin(player)
	Data.loadProfile(player)
	local code = resolveCode(player)
	if not code then Rooms.toLobby(player) return end
	if code ~= "TEST00" then
		local rec = Rooms.get(code)
		if not rec then Rooms.toLobby(player, "expired") return end
		if not serverCode then Rooms.touch(code) end
		serverRec = rec
		if (rec.day or 1) > (ReplicatedStorage:GetAttribute("Day") or 1) then ReplicatedStorage:SetAttribute("Day", rec.day) end
		-- the room keeps its time of day between visits (a fresh server would start in the morning)
		if not serverCode and type(rec.clock) == "number" then
			Lighting.ClockTime = rec.clock % 24
			ReplicatedStorage:SetAttribute("Night", Lighting.ClockTime < 6 or Lighting.ClockTime > 18.5)
		end
		local isOwner = rec.owner == player.UserId
		if not isOwner then
			if #Players:GetPlayers() > (rec.maxPlayers or Config.MAX_PLAYERS) then Rooms.toLobby(player, "full") return end
			local mode = Rooms.access(rec)
			if mode ~= "public" and rec.owner ~= 0 then
				local okF, friend = pcall(function() return player:IsFriendsWith(rec.owner) end)
				friend = okF and friend
				if mode == "friends" and not friend then Rooms.toLobby(player, "friendsOnly") return end
				if mode == "request" and not friend and not Rooms.isApproved(code, player.UserId) then Rooms.toLobby(player, "requestDeclined") return end
			end
		end
	end
	if not serverCode then
		serverCode = code
		ReplicatedStorage:SetAttribute("RoomCode", code)
		pcall(function()
			MessagingService:SubscribeAsync("RoomReq", function(msg)
				local d = msg.Data
				if type(d) ~= "table" or d.code ~= serverCode or not serverRec then return end
				local owner = Players:GetPlayerByUserId(serverRec.owner)
				if owner then
					notify(owner, "joinRequest", d.name, d.uid)
				else
					pcall(function() MessagingService:PublishAsync("RoomResp", { uid = d.uid, code = serverCode, ok = false, reason = "ownerOffline" }) end)
				end
			end)
		end)
	end
	Data.loadRoom(player, serverCode)
	Rooms.setPresence(player.UserId, serverCode)
	push(player)
	spawnCharacter(player)
end

function World.start(r)
	remotes = r
	Players.CharacterAutoLoads = false
	pcall(function() StarterPlayer.LoadCharacterAppearance = false end)
	Players.RespawnTime = 5
	require(script.Parent.TerrainFix).run(require(ReplicatedStorage.Shared.Biomes).HALF)

	Lighting.Brightness = 2.4
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(100, 108, 118)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 136, 148)
	-- distance fog is driven by each client per region; an Atmosphere would disable it
	for _, a in ipairs(Lighting:GetChildren()) do
		if a:IsA("Atmosphere") then a:Destroy() end
	end
	Lighting.FogStart = 30
	Lighting.FogEnd = 240

	for name, fn in pairs({ resources = function() Resources.init(ctx) end, loot = function() Loot.init(ctx) end, mobs = function() Mobs.start(ctx) end, survival = function() Survival.start(ctx) end }) do
		local ok, err = pcall(fn)
		if not ok then warn("start", name, err) Debug.log("start." .. name, err) end
	end
	Debug.log("world", "started")
	local okV, errV = pcall(function() require(script.Parent.Villages).start(ctx, Mobs) end)
	if not okV then Debug.log("start.villages", errV) end

	-- camp: trader + fire
	for _, campName in ipairs({ "Camp", "Outposts", "Villages", "BanditCamps" }) do
		local camp = workspace:FindFirstChild(campName)
		if not camp then continue end
		for _, d in ipairs(camp:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d:GetAttribute("Key") == "trade" then
				local shop = d:GetAttribute("Shop") or "forest"
				table.insert(vendors, { part = d.Parent, shop = shop })
				d.Triggered:Connect(function(player)
					if isNight() then notify(player, "shopClosed") else notify(player, "openShop", shop) end
				end)
			elseif d:IsA("BasePart") and d.Name == "CampfireCore" then
				hookFire(d)
			elseif d:IsA("ProximityPrompt") and d:GetAttribute("Key") == "stash" then
				table.insert(stashParts, d.Parent)
				d.Triggered:Connect(function(player) notify(player, "openStash") end)
			end
		end
	end

	remotes.World.OnServerInvoke = function(player, action, a, b)
		local room = Data.room(player)
		if not room or type(action) ~= "string" or not actions[action] then return false end
		local ok, err = pcall(actions[action], player, room, a, b)
		if not ok then warn("World action failed:", action, err) Debug.log("action." .. action, err) end
		return ok
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
		task.spawn(onJoin, player)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		p.CharacterAdded:Connect(function(char) onCharacter(p, char) end)
		task.spawn(onJoin, p)
	end
	local function saveClock()
		if serverCode and serverCode ~= "TEST00" then
			local clock, day = Lighting.ClockTime, ReplicatedStorage:GetAttribute("Day") or 1
			Rooms.update(serverCode, function(rec) rec.clock = clock rec.day = math.max(rec.day or 1, day) end)
		end
	end
	game:BindToClose(saveClock)
	Players.PlayerRemoving:Connect(function(player)
		if #Players:GetPlayers() <= 1 then task.spawn(saveClock) end
		if sleeping[player] then
			local bed = sleeping[player]
			sleeping[player] = nil
			if bed.Parent then bed:SetAttribute("Sleeper", nil) end
			task.defer(announceSleep)
		end
		if beds[player] and beds[player].Parent then beds[player]:Destroy() end
		beds[player] = nil
		buffs[player] = nil
		lastHit[player] = nil
		placedOnce[player] = nil
		lamp[player] = nil
		deathBag[player] = nil
		mapDirty[player] = nil
		selected[player] = nil
		cooldown[player] = nil
		luckCd[player] = nil
		Rooms.clearPresence(player.UserId)
	end)

	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			for _, pl in ipairs(Players:GetPlayers()) do
				-- remember where the player stands (saved with the room)
				local hrp, hum = hrpOf(pl)
				local rr = Data.room(pl)
				if rr and hrp and hum and hum.Health > 0 and placedOnce[pl] and tick % 3 == 0 and not sleeping[pl]
					and hum.FloorMaterial ~= Enum.Material.Air and hum.FloorMaterial ~= Enum.Material.Water then
					local p = hrp.Position
					rr.pos = { math.floor(p.X * 10) / 10, math.floor(p.Y * 10) / 10, math.floor(p.Z * 10) / 10 }
				end
				if hrp and hum and hum.Health > 0 then reveal(pl, hrp.Position) end
				if mapDirty[pl] and tick % 3 == 0 and rr then
					mapDirty[pl] = nil
					notify(pl, "explored", rr.explored)
				end
				local ok, err = pcall(lightAndBuffs, pl)
				if not ok then Debug.log("tick.buffs", err) end
				push(pl)
			end
			if next(sleeping) then pcall(checkSleep) end
			if tick == 3 or (tick % BLACK_STAY == 0) then
				local ok, moved = pcall(moveBlack)
				if ok and moved and tick > 3 then ctx.broadcast("blackMoved") end
				if ok and not moved and tick > 3 then tick -= 45 end
			end
			if serverCode and tick % 30 == 0 then
				if serverRec and Rooms.access(serverRec) == "public" then Rooms.advertise(serverCode, #Players:GetPlayers()) end
				for _, pl in ipairs(Players:GetPlayers()) do Rooms.setPresence(pl.UserId, serverCode) end
			end
			if serverCode and tick % 1200 == 0 then Rooms.touch(serverCode) end
			if serverCode and serverCode ~= "TEST00" and tick % 45 == 0 then
				local clock, day = Lighting.ClockTime, ReplicatedStorage:GetAttribute("Day") or 1
				task.spawn(Rooms.update, serverCode, function(rec) rec.clock = clock rec.day = math.max(rec.day or 1, day) end)
			end
		end
	end)
end

World._test = { buildBlack = buildBlack, moveBlack = moveBlack, ctx = ctx }

return World
