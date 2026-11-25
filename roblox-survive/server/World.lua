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

local MessagingService = game:GetService("MessagingService")

local World = {}

local remotes
local serverCode = nil
local selected = {} -- [Player] = hotbar index
local cooldown = {} -- [Player] = { [key] = clock }
local luckCd = {}
local rng = Random.new()

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
function ctx.hurt(player, amount)
	local _, hum = hrpOf(player)
	if not hum or hum.Health <= 0 then return end
	local room = Data.room(player)
	local armor = room and room.inv.armor and Items.get(room.inv.armor)
	if armor then amount *= (1 - armor.reduce) end
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
		Mobs.damage(best, (def.dmg or 5) * (1 + 0.1 * str), player)
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
		if m then Mobs.damage(m, def.dmg * (1 + 0.1 * skill(player, "strength")), player) end
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
	notify(player, "placed")
	if not room.inv.slots[index] then select(player, 0) else push(player) end
end

function select(player, index)
	local room = Data.room(player)
	if not room then return end
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
			elseif def.kind == "armor" then
				if not cd(player, "wear", 0.8) then return end
				local old = r.inv.armor
				r.inv.slots[index] = false
				r.inv.armor = id
				if old then Inventory.add(r.inv, old, 1) end
				Appearance.armor(char, def.color, def.mat)
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
local function applyStats(player)
	local _, hum = hrpOf(player)
	if not hum then return end
	local hp = 100 + 10 * skill(player, "health")
	local ratio = hum.Health / math.max(1, hum.MaxHealth)
	hum.MaxHealth = hp
	hum.Health = math.clamp(hp * ratio, 1, hp)
	hum.WalkSpeed = 16 + 0.6 * math.min(skill(player, "speed"), Config.SKILL_CAP.speed or 10)
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
	if spawn then
		char:PivotTo(CFrame.new(spawn.Position + Vector3.new(rng:NextNumber(-8, 8), 4, rng:NextNumber(-8, 8))))
	end
	selected[player] = 0
	Survival.reset(player)
	local room = Data.room(player)
	if room then
		room.hunger = math.max(room.hunger, 40)
		room.thirst = math.max(room.thirst, 40)
	end
	if room and room.inv.armor then
		local ad = Items.get(room.inv.armor)
		if ad then Appearance.armor(char, ad.color, ad.mat) end
	end
	hum.BreakJointsOnDeath = false
	hum.MaxHealth = 100
	hum.Health = 100
	applyStats(player)
	hum.Health = hum.MaxHealth
	hum.Died:Connect(function()
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
				Loot.drop(hrp.Position, items, player.UserId)
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
	if isNight() then notify(player, "shopClosed") return end
	local def = Items.get(id)
	shop = type(shop) == "string" and shop or "forest"
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
	if isNight() then notify(player, "shopClosed") return end
	local def = Items.get(id)
	if not def or not def.sell then return end
	if not nearVendor(player) then notify(player, "tooFar") return end
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
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local at = Instance.new("Atmosphere")
		at.Density = 0.4
		at.Offset = 0.2
		at.Color = Color3.fromRGB(200, 215, 230)
		at.Parent = Lighting
	end

	for name, fn in pairs({ resources = function() Resources.init(ctx) end, loot = function() Loot.init(ctx) end, mobs = function() Mobs.start(ctx) end, survival = function() Survival.start(ctx) end }) do
		local ok, err = pcall(fn)
		if not ok then warn("start", name, err) Debug.log("start." .. name, err) end
	end
	Debug.log("world", "started")

	-- camp: trader + fire
	for _, campName in ipairs({ "Camp", "Outposts" }) do
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
	Players.PlayerRemoving:Connect(function(player)
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
			for _, pl in ipairs(Players:GetPlayers()) do push(pl) end
			if serverCode and tick % 30 == 0 then
				if serverRec and Rooms.access(serverRec) == "public" then Rooms.advertise(serverCode, #Players:GetPlayers()) end
				for _, pl in ipairs(Players:GetPlayers()) do Rooms.setPresence(pl.UserId, serverCode) end
			end
			if serverCode and tick % 1200 == 0 then Rooms.touch(serverCode) end
		end
	end)
end

return World
