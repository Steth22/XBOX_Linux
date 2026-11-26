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
local Furnace = require(script.Parent.Furnace)
local Weather = require(script.Parent.Weather)
local Powers = require(script.Parent.Powers)
local Biomes = require(ReplicatedStorage.Shared.Biomes)

local MessagingService = game:GetService("MessagingService")

local World = {}

local remotes
local serverCode = nil
local serverRec = nil -- the room record (owner, settings, bans)
local select -- forward
local applyStats -- forward
local selected = {} -- [Player] = hotbar index
local cooldown = {} -- [Player] = { [key] = clock }
local luckCd = {}
local rng = Random.new()
local buffs = {} -- [Player] = { [name] = expiry clock }
local sleeping = {} -- [Player] = bed model
local beds = {} -- [Player] = bed model they own
local lastHit = {} -- [Player] = what hurt them last (shown on the death screen)
local placedOnce = {} -- [Player] = already put at their saved spot this visit
local spawnBed = {} -- [Player] = the bed they respawn at (a placed bed only lives on this server)
local makeBed -- defined with the placing code
local lamp = {} -- [Player] = hotbar/bag slot of the lantern hanging in the left hand
local deathBag = {} -- [Player] = { model, x, z } items left where the player died
local mapDirty = {} -- [Player] = explored cells changed since the last send

-- world map: reveal the cells around a position (a string of "0"/"1", one per cell)
local MAPN = Config.MAP_CELLS
local CELL = (2 * Biomes.HALF) / MAPN
local function reveal(player, pos)
	local room = Data.room(player)
	if not room then return end
	local deep = pos.Y < -26
	local ex = deep and room.explored2 or room.explored
	if type(ex) ~= "string" or #ex ~= MAPN * MAPN then ex = string.rep("0", MAPN * MAPN) end
	local cx = math.floor((pos.X + Biomes.HALF) / CELL)
	local cz = math.floor((pos.Z + Biomes.HALF) / CELL)
	local changed = false
	for dz = -4, 4 do
		for dx = -4, 4 do
			local x, z = cx + dx, cz + dz
			if dx * dx + dz * dz <= 18 and x >= 0 and z >= 0 and x < MAPN and z < MAPN then
				local i = z * MAPN + x + 1
				if ex:sub(i, i) ~= "1" then
					ex = ex:sub(1, i - 1) .. "1" .. ex:sub(i + 1)
					changed = true
				end
			end
		end
	end
	if deep then room.explored2 = ex else room.explored = ex end
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
	-- underground places carry a 4th field: "under"
	for _, m in ipairs(workspace:FindFirstChild("UnderCamps") and workspace.UnderCamps:GetChildren() or {}) do
		local c = m:GetAttribute("Center")
		if c then table.insert(pois, { m.Name == "DwarfHold" and "dwarf" or "camp", math.floor(c.X), math.floor(c.Z), "under" }) end
	end
	local ruins = workspace:FindFirstChild("Underground") and workspace.Underground:FindFirstChild("Ruins")
	if ruins then local p = ruins:GetPivot().Position table.insert(pois, { "ruins", math.floor(p.X), math.floor(p.Z), "under" }) end
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

local admin = {} -- [Player] = { god, speed, hp, dmg, jump }
local adminPass = {} -- [Player] = owns the Admin game pass (checked when they join)
-- may this player switch admin on here? the developer anywhere, a pass owner in rooms they own
local function canAdmin(player)
	if Config.ADMINS[player.UserId] then return true end
	return adminPass[player] == true and serverRec ~= nil and serverRec.owner == player.UserId
end
-- admin is switched on per room, once, for good (everyone in the room sees it)
local function isAdmin(player)
	return canAdmin(player) and (serverRec == nil or serverRec.admin == true)
end
local function isMod(player)
	return serverRec ~= nil and type(serverRec.mods) == "table" and serverRec.mods[tostring(player.UserId)] == true
end
local function adminOf(player) return isAdmin(player) and admin[player] or nil end

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
		off = room.inv.off or false,
		powers = Powers.of(room),
		buffs = (function()
			local out = {}
			for k, t in pairs(buffs[player] or {}) do
				local left = math.floor(t - os.clock())
				if left > 0 then out[k] = left end
			end
			return out
		end)(),
		sleeping = sleeping[player] ~= nil,
		lamp = 0,
		death = (deathBag[player] and deathBag[player][1].Parent) and { deathBag[player][2], deathBag[player][3], deathBag[player][4] } or nil,
		dex = room.dex,
		isOwner = serverRec ~= nil and serverRec.owner == player.UserId,
		locked = serverRec ~= nil and serverRec.locked == true,
		pvp = serverRec ~= nil and serverRec.pvp == true,
		admin = isAdmin(player) and (admin[player] or {}) or nil,
		canAdmin = canAdmin(player),
		adminOn = serverRec == nil or serverRec.admin == true,
		adminBy = serverRec and serverRec.adminBy or nil,
		isMod = isMod(player),
		mods = serverRec and type(serverRec.mods) == "table" and serverRec.mods or {},
		ownerId = serverRec and serverRec.owner or 0,
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
-- the event feed (bottom left, for everyone): joins, deaths, bosses, levels...
local leaving = {} -- [userId] = "kick" / "ban" so the feed says why someone left
function ctx.feed(key, a, b, c)
	remotes.Notify:FireAllClients("feed", { k = key, a = a, b = b, c = c })
end
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
		ctx.feed("level", player.DisplayName, level)
		if player.Character then ctx.fx("levelUp", player.Character) end
	end
	push(player)
end
function ctx.hurt(player, amount, cause)
	local _, hum = hrpOf(player)
	if not hum or hum.Health <= 0 then return end
	if type(cause) == "string" then lastHit[player] = cause end
	local adm = adminOf(player)
	if adm and adm.god then return end
	local room = Data.room(player)
	local armor = room and room.inv.armor and Items.get(room.inv.armor)
	if armor then amount *= (1 - armor.reduce) end
	if hasBuff(player, "stone") then amount *= 0.6 end
	if sleeping[player] and ctx.wake then ctx.wake(player) end
	if hum.Health - amount <= 0 and (not luckCd[player] or os.clock() - luckCd[player] > 90) then
		-- luck (and the blast power) can save you from death; with the blast power you explode
		local saved = ctx.lucky(player, 0.03) or (room and rng:NextNumber() < Powers.saveChance(room))
		if saved then
			luckCd[player] = os.clock()
			if room and Powers.blast(player, room) then
				hum.Health = math.max(1, hum.MaxHealth * 0.25)
			else
				hum.Health = 1
				notify(player, "lucky")
			end
			return
		end
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
			ctx.feed("medal", player.DisplayName, region)
			if player.Character then ctx.fx("levelUp", player.Character) end
			ctx.reward(player, 250, 400)
			if not room.dex.neck then
				room.dex.neck = region
				wearNecklace(player)
			end
		end
	end
end

local slowed, poisoned = {}, {}
function ctx.slow(player, secs, factor)
	local _, hum = hrpOf(player)
	if not hum then return end
	slowed[player] = os.clock() + secs
	hum.WalkSpeed = hum.WalkSpeed * factor
	task.delay(secs, function()
		if slowed[player] and os.clock() >= slowed[player] - 0.05 then slowed[player] = nil applyStats(player) end
	end)
end
function ctx.poison(player, dps, secs)
	if hasBuff(player, "antidote") then return end
	poisoned[player] = { dps = dps, untilT = os.clock() + secs }
	notify(player, "poisoned")
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
		local slotNow = Data.room(player) and Data.room(player).inv.slots[index]
		Mobs.damage(best, (def.dmg or 5) * (1 + 0.1 * str) * (hasBuff(player, "strength") and 1.5 or 1) * ((adminOf(player) or {}).dmg or 1), player, { id = slotNow and slotNow.id, class = def.class, lamp = lamp[player] ~= nil })
		useDurability(player, index)
		return
	end
	if serverRec and serverRec.pvp then
		local victim, vd
		for _, other in ipairs(Players:GetPlayers()) do
			local oh = other ~= player and hrpOf(other)
			if oh then
				local rel = hrp.CFrame:PointToObjectSpace(oh.Position)
				local d = rel.Magnitude
				if rel.Z < 0 and -rel.Z <= reach + 2 and math.abs(rel.X) < 3.5 and math.abs(rel.Y) < 4 and (not vd or d < vd) then victim, vd = other, d end
			end
		end
		if victim then
			ctx.hurt(victim, (def.dmg or 5) * (1 + 0.1 * str) * 0.6, "@" .. player.DisplayName)
			useDurability(player, index)
			return
		end
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
		if m then Mobs.damage(m, def.dmg * (1 + 0.1 * skill(player, "strength")) * (hasBuff(player, "strength") and 1.5 or 1) * ((adminOf(player) or {}).dmg or 1), player, { id = slot.id, class = "ranged", lamp = lamp[player] ~= nil }) end
		local victim = Players:GetPlayerFromCharacter(res.Instance:FindFirstAncestorOfClass("Model"))
		if victim and victim ~= player and serverRec and serverRec.pvp then
			ctx.hurt(victim, def.dmg * 0.6, "@" .. player.DisplayName)
		end
	end
	useDurability(player, index)
	push(player)
end

local function hookFire(part)
	CollectionService:AddTag(part, "Heat")
	local pr = part:FindFirstChildWhichIsA("ProximityPrompt") or Instance.new("ProximityPrompt")
	-- fires only warm you now; cooking happens in the furnaces
	pr:Destroy()
end

-- a bed the player owns (placed now, or put back where it stood when they rejoin)
function makeBed(player, cf)
	if beds[player] and beds[player].Parent then beds[player]:Destroy() end
	local m = Items.model("bed")
	if not m then return nil end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true p.CanCollide = true p.CanQuery = true end
	end
	m.Name = "Bed"
	m:SetAttribute("Owner", player.UserId)
	m:PivotTo(cf)
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
	return m
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
				if root and (root.Position - at).Magnitude < 16 then Mobs.damage(mob, 140, player.Parent and player or nil, { id = "dynamite" }) end
			end
			if player.Parent then
				for _, node in ipairs(Resources.near(at, 13)) do
					Resources.hit(player, node, { tree = 5, rock = 9 }, 0)
				end
			end
		end)
	elseif id == "bed" then
		m:Destroy()
		local look = hrp.CFrame.LookVector
		makeBed(player, CFrame.lookAt(res.Position + Vector3.new(0, 0.05, 0), res.Position + Vector3.new(look.X, 0.05, look.Z)))
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
			-- a light goes into the off hand (swapping with whatever was there)
			local prev = room.inv.off
			room.inv.off = { id = sl.id, n = 1, d = sl.d }
			if sl.n > 1 then
				sl.n -= 1
				if prev then
					local rest = Inventory.add(room.inv, prev.id, 1, prev.d)
					if rest > 0 then room.inv.off = prev sl.n += 1 notify(player, "bagFull") push(player) return end
				end
			else
				room.inv.slots[i] = prev and { id = prev.id, n = 1, d = prev.d } or false
			end
			lamp[player] = true
			setLamp(player, true)
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
	local ad = adminOf(player)
	if ad then
		if ad.hp then hum.MaxHealth = ad.hp hum.Health = math.min(hum.Health, ad.hp) end
		if ad.speed then hum.WalkSpeed = ad.speed end
		if ad.jump then hum.UseJumpPower = true hum.JumpPower = ad.jump end
	end
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
	local room0 = Data.room(player)
	local bedSpot = room0 and room0.spawn
	if bedSpot and not bedSpot.village and not (spawnBed[player] and spawnBed[player].Parent) then
		room0.spawn = nil -- that bed is gone
		bedSpot = nil
	end
	local target = nil
	if saved and not placedOnce[player] then target = Vector3.new(saved[1], saved[2], saved[3])
	elseif bedSpot then target = Vector3.new(bedSpot[1], bedSpot[2], bedSpot[3]) end
	if target then
		-- back where the player left the room, or at their bed
		char:PivotTo(CFrame.new(target + Vector3.new(0, 3, 0)))
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
	if room and room.inv.off then
		lamp[player] = true
		task.defer(setLamp, player, true)
	end
	task.defer(wearNecklace, player)
	task.defer(Powers.apply, player)
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = 100
	hum.Health = 100
	applyStats(player)
	hum.Health = hum.MaxHealth
	hum.Died:Connect(function()
		notify(player, "deathBy", lastHit[player] or "unknown")
		ctx.feed("death", player.DisplayName, lastHit[player] or "unknown")
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
			r.pos = nil -- after dying you come back at your bed (or the camp), not where you fell
			local items = Inventory.takeAll(r.inv)
			if #items > 0 then
				local bag = Loot.drop(hrp.Position, items, player.UserId)
				if bag then deathBag[player] = { bag, math.floor(hrp.Position.X), math.floor(hrp.Position.Z), math.floor(hrp.Position.Y) } end
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
local function setSpawn(player, bed)
	local room = Data.room(player)
	if not room then return end
	local p = (bed:GetPivot() * CFrame.new(3.4, 1, 0)).Position
	local village = bed:IsA("BasePart")
	local same = spawnBed[player] == bed
	spawnBed[player] = bed
	room.spawn = { math.floor(p.X * 10) / 10, math.floor(p.Y * 10) / 10, math.floor(p.Z * 10) / 10, village = village }
	if not village then
		local b = bed:GetPivot()
		local _, ry = b:ToEulerAnglesYXZ()
		room.spawn.bed = { math.floor(b.X * 10) / 10, math.floor(b.Y * 10) / 10, math.floor(b.Z * 10) / 10, math.floor(ry * 100) / 100 }
	end
	if not same then notify(player, "spawnSet") end
end
function ctx.sleep(player, bed)
	if sleeping[player] then ctx.wake(player) return end
	setSpawn(player, bed) -- any bed you use becomes your respawn point
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
	local top = bed:IsA("BasePart") and (bed.CFrame * CFrame.new(0, bed.Size.Y / 2 + 0.55, 0.4)) or (bed:GetPivot() * CFrame.new(0, 1.9, 0.4))
	hrp.CFrame = top * CFrame.Angles(math.rad(90), 0, 0)
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
	-- the light in the off hand burns down
	local off = room.inv.off
	if off and not lamp[player] and player.Character then
		lamp[player] = true
		setLamp(player, true)
	end
	if off then
		local def = Items.get(off.id)
		if def and def.dur then
			off.d = (off.d or def.dur) - 1
			if off.d <= 0 then
				room.inv.off = false
				lamp[player] = nil
				setLamp(player, false)
				notify(player, "lanternDead")
				push(player)
			end
		end
	elseif lamp[player] then
		lamp[player] = nil
		setLamp(player, false)
	end
	local pz = poisoned[player]
	if pz then
		if os.clock() > pz.untilT or hasBuff(player, "antidote") then poisoned[player] = nil else ctx.hurt(player, pz.dps, "poison") end
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

-- equipment "slots" in the bag window: 100 = armor, 101 = off hand
local EQ_ARMOR, EQ_OFF = 100, 101
local function wearArmor(player, id)
	local char = player.Character
	if not char then return end
	local def = id and Items.get(id)
	if def then Appearance.armor(char, def.color, def.mat, id) else Appearance.armor(char, nil) end
	applyStats(player)
end
function actions.move(player, room, a, b)
	a, b = tonumber(a), tonumber(b)
	if not a or not b then return end
	if a >= 200 or b >= 200 then
		if Furnace.move(player, room, a, b) then revalidate(player) end
		return
	end
	local inv = room.inv
	local function slotOk(i) return i >= 1 and i <= Config.HOTBAR + Config.BIG_BAG and Inventory.usable(inv, i) end
	if b == EQ_ARMOR or b == EQ_OFF then
		-- bag slot -> equipment
		if not slotOk(a) then return end
		local sl = inv.slots[a]
		local d = sl and Items.get(sl.id)
		if not d then return end
		if b == EQ_ARMOR then
			if d.kind ~= "armor" then notify(player, "wrongSlot") return end
			local old = inv.armor
			inv.armor = sl.id
			inv.slots[a] = old and { id = old, n = 1 } or false
			wearArmor(player, inv.armor)
			notify(player, "armorOn")
		else
			if d.kind ~= "light" then notify(player, "wrongSlot") return end
			local old = inv.off
			inv.off = { id = sl.id, n = 1, d = sl.d }
			if sl.n > 1 then
				sl.n -= 1
				if old and Inventory.add(inv, old.id, 1, old.d) > 0 then inv.off = old sl.n += 1 notify(player, "bagFull") push(player) return end
			else
				inv.slots[a] = old and { id = old.id, n = 1, d = old.d } or false
			end
			lamp[player] = true
			setLamp(player, true)
		end
		if selected[player] == a then select(player, 0) else revalidate(player) end
		return
	end
	if a == EQ_ARMOR or a == EQ_OFF then
		-- equipment -> a bag slot (empty, or holding something that fits the same place)
		if not slotOk(b) then return end
		local there = inv.slots[b]
		local td = there and Items.get(there.id)
		if a == EQ_ARMOR then
			if not inv.armor then return end
			if there and not (td and td.kind == "armor") then return end
			local old = inv.armor
			inv.armor = there and there.id or false
			inv.slots[b] = { id = old, n = 1 }
			wearArmor(player, inv.armor or nil)
		else
			if not inv.off then return end
			if there and not (td and td.kind == "light" and there.n == 1) then return end
			local old = inv.off
			inv.off = there and { id = there.id, n = 1, d = there.d } or false
			inv.slots[b] = { id = old.id, n = 1, d = old.d }
			lamp[player] = inv.off and true or nil
			setLamp(player, inv.off ~= false)
		end
		revalidate(player)
		return
	end
	if Inventory.move(inv, a, b) then revalidate(player) end
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
	for j = 1, Config.HOTBAR + Config.BIG_BAG do
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

-- the dwarves' big bag: 30 slots
function actions.buyBigBag(player, room)
	if room.inv.bag == "big" then return end
	if not nearVendor(player) then notify(player, "tooFar") return end
	if room.coins < Config.BIG_BAG_PRICE then notify(player, "needCoins") return end
	room.coins -= Config.BIG_BAG_PRICE
	room.inv.bag = "big"
	notify(player, "bought")
	ctx.reward(player, 30, 0)
	push(player)
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
	local ORES = { stone = true, iron = true, gold = true, diamond = true, crystal = true, obsidian = true }
	if ORES[id] and nearVendor(player, "dwarf") then total = math.floor(total * 1.5) end
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
function actions.crateTake(player, room, id, what) Loot.take(player, id, what) end
function actions.cart(player, room, v) require(script.Parent.Underground).throttle(player, v) end

-- admin tools (only for Config.ADMINS; checked here on the server)
local ADMIN = {}
local function groundNear(pos)
	local h = require(script.Parent.Ground).height(pos.X, pos.Z)
	return Vector3.new(pos.X, (h or pos.Y) + 3, pos.Z)
end
function ADMIN.god(player, room, ad, on) ad.god = on == true end
function ADMIN.speed(player, room, ad, v) ad.speed = math.clamp(tonumber(v) or 16, 8, 300) applyStats(player) end
function ADMIN.jump(player, room, ad, v) ad.jump = math.clamp(tonumber(v) or 50, 20, 400) applyStats(player) end
function ADMIN.hp(player, room, ad, v) ad.hp = math.clamp(tonumber(v) or 100, 50, 100000) applyStats(player) local _, h = hrpOf(player) if h then h.Health = h.MaxHealth end end
function ADMIN.dmg(player, room, ad, v) ad.dmg = math.clamp(tonumber(v) or 1, 1, 1000) end
function ADMIN.heal(player, room)
	local _, h = hrpOf(player)
	if h then h.Health = h.MaxHealth end
	room.hunger = 100
	Survival.reset(player)
end
function ADMIN.spawn(player, room, ad, v)
	local hrp = hrpOf(player)
	if not hrp or type(v) ~= "table" or not table.find(Mobs.kinds(), v.kind) then return end
	for i = 1, math.clamp(tonumber(v.count) or 1, 1, 10) do
		local at = (hrp.CFrame * CFrame.new((i - 1) * 4 - 6, 0, -14)).Position
		local g = require(script.Parent.Ground).height(at.X, at.Z) or at.Y
		Mobs.spawn(v.kind, Vector3.new(at.X, g, at.Z), math.clamp(tonumber(v.level) or 1, 1, 99))
	end
end
function ADMIN.clearMobs(player)
	local hrp = hrpOf(player)
	if hrp then notify(player, "adminDone", Mobs.clear(hrp.Position, 200)) end
end
function ADMIN.give(player, room, ad, v)
	if type(v) ~= "table" or not Items.get(v.id) then return end
	local rest = Inventory.add(room.inv, v.id, math.clamp(tonumber(v.n) or 1, 1, 999))
	if rest > 0 then notify(player, "bagFull") end
end
function ADMIN.coins(player, room, ad, v) room.coins = math.max(0, room.coins + (tonumber(v) or 0)) end
function ADMIN.xp(player, room, ad, v) ctx.reward(player, math.clamp(tonumber(v) or 0, 0, 1e7), 0) end
function ADMIN.sp(player, room, ad, v) room.sp = math.max(0, room.sp + (tonumber(v) or 0)) end
function ADMIN.weather(player, room, ad, v) Weather.force(tostring(v)) end
function ADMIN.time(player, room, ad, v)
	if v == "skip" then Survival.skipNight() return end
	Lighting.ClockTime = v == "night" and 21 or 8
	ReplicatedStorage:SetAttribute("Night", v == "night")
end
function ADMIN.tp(player, room, ad, v)
	local hrp = hrpOf(player)
	if hrp and type(v) == "table" and tonumber(v[1]) and tonumber(v[2]) then
		hrp.CFrame = CFrame.new(groundNear(Vector3.new(tonumber(v[1]), hrp.Position.Y, tonumber(v[2]))))
	end
end
function ADMIN.tpTo(player, room, ad, uid)
	local t = Players:GetPlayerByUserId(tonumber(uid) or 0)
	local hrp, th = hrpOf(player), t and hrpOf(t)
	if hrp and th then hrp.CFrame = th.CFrame * CFrame.new(0, 0, 4) end
end
function ADMIN.bring(player, room, ad, uid)
	local t = Players:GetPlayerByUserId(tonumber(uid) or 0)
	local hrp, th = hrpOf(player), t and hrpOf(t)
	if hrp and th then th.CFrame = hrp.CFrame * CFrame.new(0, 0, -4) end
end
function ADMIN.reveal(player, room)
	room.explored = string.rep("1", Config.MAP_CELLS * Config.MAP_CELLS)
	room.explored2 = room.explored
	notify(player, "explored", room.explored, room.explored2)
end
function ADMIN.medals(player, room)
	for _, reg in ipairs(Bestiary.regions) do
		for _, k in ipairs(reg.kinds) do room.dex.seen[k] = true room.dex.kills[k] = math.max(room.dex.kills[k] or 0, 1) end
		room.dex.medals[reg.key] = true
	end
end
function ADMIN.clearBag(player, room)
	Inventory.takeAll(room.inv)
	select(player, 0)
end
function actions.admin(player, room, cmd, arg)
	if not isAdmin(player) or type(cmd) ~= "string" or not ADMIN[cmd] then return end
	admin[player] = admin[player] or {}
	ADMIN[cmd](player, room, admin[player], arg)
	push(player)
end

-- room owner tools: kick, ban, lock, moderators (moderators may kick and ban too)
local function ownerOnly(player)
	return serverRec ~= nil and serverCode ~= nil and serverRec.owner == player.UserId
end
-- may player throw target (a user id) out of the room?
local function mayRemove(player, uid)
	if not serverRec or not serverCode or not uid or uid == player.UserId or uid == serverRec.owner then return false end
	if ownerOnly(player) then return true end
	return isMod(player) and not (type(serverRec.mods) == "table" and serverRec.mods[tostring(uid)])
end
function actions.kick(player, room, uid)
	uid = tonumber(uid)
	local target = uid and Players:GetPlayerByUserId(uid)
	if not target or not mayRemove(player, uid) then return end
	Data.saveRoom(target)
	leaving[target.UserId] = "kick"
	Rooms.toLobby(target, "kicked")
end
function actions.ban(player, room, uid)
	uid = tonumber(uid)
	if not mayRemove(player, uid) then return end
	serverRec.banned = serverRec.banned or {}
	serverRec.banned[tostring(uid)] = true
	Rooms.update(serverCode, function(rec)
		rec.banned = type(rec.banned) == "table" and rec.banned or {}
		rec.banned[tostring(uid)] = true
	end)
	local target = Players:GetPlayerByUserId(uid)
	if target then
		Data.saveRoom(target)
		leaving[target.UserId] = "ban"
		Rooms.toLobby(target, "banned")
	end
end
function actions.mod(player, room, uid, on)
	uid = tonumber(uid)
	local target = uid and Players:GetPlayerByUserId(uid)
	if not ownerOnly(player) or not target or target == player then return end
	on = on == true
	serverRec.mods = type(serverRec.mods) == "table" and serverRec.mods or {}
	serverRec.mods[tostring(uid)] = on or nil
	Rooms.update(serverCode, function(rec)
		rec.mods = type(rec.mods) == "table" and rec.mods or {}
		rec.mods[tostring(uid)] = on or nil
	end)
	ctx.feed(on and "modOn" or "modOff", target.DisplayName)
	for _, pl in ipairs(Players:GetPlayers()) do push(pl) end
end
-- switching admin on in this room: can't be undone, and everyone is told
function actions.adminActivate(player, room)
	if not canAdmin(player) or not serverRec or serverRec.admin then return end
	serverRec.admin = true
	serverRec.adminBy = player.DisplayName
	Data.unranked = true
	if serverCode and serverCode ~= "TEST00" then
		Rooms.update(serverCode, function(rec) rec.admin = true rec.adminBy = player.DisplayName end)
	end
	ctx.feed("adminOn", player.DisplayName)
	for _, pl in ipairs(Players:GetPlayers()) do push(pl) end
end
function actions.lock(player, room, on)
	if not ownerOnly(player) then return end
	serverRec.locked = on == true
	Rooms.update(serverCode, function(rec) rec.locked = on == true end)
	notify(player, on and "lockedNow" or "unlockedNow")
	for _, pl in ipairs(Players:GetPlayers()) do push(pl) end
end
function actions.map(player, room)
	notify(player, "mapData", mapPois(), { room.explored or string.rep("0", MAPN * MAPN), room.explored2 or string.rep("0", MAPN * MAPN), workspace:GetAttribute("CaveMask") or "", workspace:GetAttribute("CaveMaskN") or 96 })
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

function actions.closeFurnace(player) Furnace.close(player) end
function actions.powerUp(player, room, kind) Powers.upgrade(player, room, tostring(kind)) end
function actions.powerToggle(player, room, kind) Powers.toggle(player, room, tostring(kind)) end
-- the secret trader's token: paid with some of every resource
function actions.buyToken(player, room)
	if not nearVendor(player, "black") then notify(player, "tooFar") return end
	for _, c in ipairs(Items.TOKEN_COST) do
		if Inventory.count(room.inv, c[1]) < c[2] then notify(player, "needRes") return end
	end
	if Inventory.space(room.inv, "token") < 1 then notify(player, "bagFull") return end
	for _, c in ipairs(Items.TOKEN_COST) do Inventory.remove(room.inv, c[1], c[2]) end
	Inventory.add(room.inv, "token", 1)
	notify(player, "boughtToken")
	if player.Character then ctx.fx("skillUp", player.Character) end
	push(player)
end

function actions.unequipOff(player, room)
	local off = room.inv.off
	if not off then return end
	if Inventory.space(room.inv, off.id) < 1 then notify(player, "bagFull") return end
	room.inv.off = false
	Inventory.add(room.inv, off.id, 1, off.d)
	lamp[player] = nil
	setLamp(player, false)
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
		Data.unranked = rec.admin == true
		if (rec.day or 1) > (ReplicatedStorage:GetAttribute("Day") or 1) then ReplicatedStorage:SetAttribute("Day", rec.day) end
		-- the room keeps its time of day between visits (a fresh server would start in the morning)
		if not serverCode and type(rec.clock) == "number" then
			Lighting.ClockTime = rec.clock % 24
			ReplicatedStorage:SetAttribute("Night", Lighting.ClockTime < 6 or Lighting.ClockTime > 18.5)
		end
		local isOwner = rec.owner == player.UserId
		if not isOwner and type(rec.banned) == "table" and rec.banned[tostring(player.UserId)] then Rooms.toLobby(player, "banned") return end
		if not isOwner and rec.locked then Rooms.toLobby(player, "roomLocked") return end
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
	if Config.ADMIN_PASS ~= 0 and serverRec and serverRec.owner == player.UserId then
		local okP, owns = pcall(function() return game:GetService("MarketplaceService"):UserOwnsGamePassAsync(player.UserId, Config.ADMIN_PASS) end)
		adminPass[player] = okP and owns == true
	end
	local loaded = Data.loadRoom(player, serverCode)
	ctx.feed(loaded and loaded._new and "newPlayer" or "join", player.DisplayName)
	-- put back what only lived on the old server: the player's own bed and the bag left where they died
	local room = Data.room(player)
	if room then
		local sp = room.spawn
		if sp and not sp.village and type(sp.bed) == "table" and not (beds[player] and beds[player].Parent) then
			local b = sp.bed
			local ok, bed = pcall(makeBed, player, CFrame.new(b[1], b[2], b[3]) * CFrame.Angles(0, b[4] or 0, 0))
			if ok and bed then spawnBed[player] = bed end
		end
		local live = Loot.ownedBag(player.UserId)
		if live then
			local p = live:GetPivot().Position
			deathBag[player] = { live, math.floor(p.X), math.floor(p.Z), math.floor(p.Y) }
		elseif room.lostBag and os.time() < (room.lostBag.expires or 0) then
			-- the 15 minutes keep running while you are away
			local lb = room.lostBag
			local bag = Loot.drop(Vector3.new(lb.pos[1], lb.pos[2] + 3, lb.pos[3]), lb.items, player.UserId, lb.expires - os.time())
			if bag then deathBag[player] = { bag, math.floor(lb.pos[1]), math.floor(lb.pos[3]), math.floor(lb.pos[2]) } end
		end
	end
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
	local bedFolders = {}
	for _, n in ipairs({ "Villages", "UnderCamps" }) do
		local f = workspace:FindFirstChild(n)
		for _, d in ipairs(f and f:GetDescendants() or {}) do table.insert(bedFolders, d) end
	end
	for _, d in ipairs(bedFolders) do
		if d:IsA("BasePart") and d.Name == "Bed" then
			local pr = Instance.new("ProximityPrompt")
			pr.ActionText = "Sleep"
			pr.ObjectText = "Bed"
			pr.HoldDuration = 0.5
			pr.MaxActivationDistance = 9
			pr.RequiresLineOfSight = false
			pr:SetAttribute("Key", "sleep")
			pr:SetAttribute("Obj", "bed")
			pr.Parent = d
			pr.Triggered:Connect(function(pl) ctx.sleep(pl, d) end)
		end
	end
	local okU, errU = pcall(function() require(script.Parent.Underground).start(ctx, Inventory, Data) end)
	if not okU then Debug.log("start.underground", errU) end
	local okV, errV = pcall(function() require(script.Parent.Villages).start(ctx, Mobs) end)
	if not okV then Debug.log("start.villages", errV) end

	-- camp: trader + fire
	for _, campName in ipairs({ "Camp", "Outposts", "Villages", "BanditCamps", "UnderCamps" }) do
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

	-- far-away places the clients may not have streamed in: the dwarf traders and the rail lines
	pcall(function()
		local spots = {}
		local uc = workspace:FindFirstChild("UnderCamps")
		for _, m in ipairs(uc and uc:GetChildren() or {}) do
			if m.Name == "DwarfHold" then
				local p = m:GetPivot().Position
				table.insert(spots, string.format("%d,%d,%d", p.X, p.Y, p.Z))
			end
		end
		ReplicatedStorage:SetAttribute("DwarfSpots", table.concat(spots, ";"))
		local lines = {}
		local tf = workspace:FindFirstChild("Underground") and workspace.Underground:FindFirstChild("Tracks")
		for _, t in ipairs(tf and tf:GetChildren() or {}) do table.insert(lines, t:GetAttribute("Points") or "") end
		ReplicatedStorage:SetAttribute("RailLines", table.concat(lines, "|"))
	end)
	-- the death bag is saved with the room, so a disconnect or a closed server doesn't lose it
	Data.beforeSave = function(player, r)
		local m, items, expires = Loot.ownedBag(player.UserId)
		if m then
			local p = m:GetPivot().Position
			local copy = {}
			for _, it in ipairs(items) do table.insert(copy, { id = it.id, n = it.n, d = it.d }) end
			r.lostBag = { pos = { math.floor(p.X * 10) / 10, math.floor(p.Y * 10) / 10, math.floor(p.Z * 10) / 10 }, items = copy, expires = expires }
		else
			r.lostBag = nil
		end
	end
	local okP, errP = pcall(function() Powers.start(ctx, Mobs, Data, Inventory) end)
	if not okP then Debug.log("start.powers", errP) end
	local okW, errW = pcall(function() Weather.start(ctx) end)
	if not okW then Debug.log("start.weather", errW) end
	local okF, errF = pcall(function() Furnace.start(ctx, Inventory, Data, vendors) end)
	if not okF then Debug.log("start.furnace", errF) end

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
		adminPass[player] = nil
		admin[player] = nil
		lastHit[player] = nil
		local why = leaving[player.UserId]
		leaving[player.UserId] = nil
		ctx.feed(why == "ban" and "banned" or (why == "kick" and "kicked" or "leave"), player.DisplayName)
		placedOnce[player] = nil
		spawnBed[player] = nil
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
					notify(pl, "explored", rr.explored, rr.explored2)
				end
				local ok, err = pcall(lightAndBuffs, pl)
				if not ok then Debug.log("tick.buffs", err) end
				push(pl)
			end
			if next(sleeping) then pcall(checkSleep) end
			if tick == 3 or (tick % BLACK_STAY == 0) then
				local ok, moved = pcall(moveBlack)
				if ok and moved and tick > 3 then ctx.broadcast("blackMoved") ctx.feed("blackMoved") end
				if ok and not moved and tick > 3 then tick -= 45 end
			end
			if serverCode and tick % 30 == 0 then
				if serverRec and Rooms.access(serverRec) == "public" then Rooms.advertise(serverCode, #Players:GetPlayers()) end
				for _, pl in ipairs(Players:GetPlayers()) do Rooms.setPresence(pl.UserId, serverCode) end
			end
			if serverCode and tick % 1200 == 0 then Rooms.touch(serverCode) end
			-- pick up setting changes made in the lobby (fighting, access...)
			if serverCode and serverCode ~= "TEST00" and tick % 20 == 0 then
				task.spawn(function()
					local r = Rooms.get(serverCode)
					if r then serverRec = r end
				end)
			end
			if serverCode and serverCode ~= "TEST00" and tick % 45 == 0 then
				local clock, day = Lighting.ClockTime, ReplicatedStorage:GetAttribute("Day") or 1
				task.spawn(Rooms.update, serverCode, function(rec) rec.clock = clock rec.day = math.max(rec.day or 1, day) end)
			end
		end
	end)
end

World._test = { buildBlack = buildBlack, moveBlack = moveBlack, ctx = ctx }

return World
