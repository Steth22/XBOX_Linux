local results2 = {}
local function check2(name, fn)
	local ok, err = pcall(fn)
	table.insert(results2, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
end
local SSS2 = game:GetService("ServerScriptService")
local notes = {}
local fake = {
	notify = function(_, k) table.insert(notes, k) end, broadcast = function(k) table.insert(notes, k) end,
	reward = function() end, giveItem = function(_, it) return 0 end, give = function() return 0 end,
	space = function() return 50 end, lucky = function() return false end, hurt = function() end, drop = function() end,
	room = function() return nil end, fx = function() end, power = function() return 3 end, addSp = function() end,
}
check2("Mobs spawn+kill", function()
	local Mobs = require(SSS2.Services.Mobs)
	Mobs.start(fake)
	for _, k in ipairs({ "rabbit", "deer", "wolf", "zombie", "guardian", "boar", "bear", "spider", "alpha", "hare", "snowwolf", "polarbear", "yeti", "camel", "goat", "scorpion", "scorpionking" }) do
		local m = Mobs.spawn(k, Vector3.new(0, 20, 0), 12)
		assert(m:GetAttribute("Level") == 12 and m:GetAttribute("MaxHP") > 20, "level " .. k)
		assert(m and m:FindFirstChild("HumanoidRootPart"), k)
		Mobs.damage(m, 5, nil)
		assert(m:GetAttribute("HP") < m:GetAttribute("MaxHP"), "hp " .. k)
		Mobs.damage(m, 99999, nil)
	end
	task.wait(1.5)
	assert(#workspace.Mobs:GetChildren() == 0, "mobs not cleaned: " .. #workspace.Mobs:GetChildren())
end)
check2("Loot drop", function()
	local Loot = require(SSS2.Services.Loot)
	Loot.init(fake)
	local b = Loot.drop(Vector3.new(5, 30, 5), { { id = "wood", n = 3 }, { id = "wood_axe", n = 1, d = 10 } }, 1)
	assert(b and b.Parent == workspace.Loot)
	for _, id in ipairs({ "wood", "wood_axe", "bow", "berries", "trap" }) do
		local d = Loot.dropItem(Vector3.new(8, 30, 8), { id = id, n = 3 })
		assert(d and d.Parent == workspace.Loot and d.PrimaryPart:FindFirstChildOfClass("ProximityPrompt"), "dropItem " .. id)
	end
end)
check2("Survival temp", function()
	local S = require(SSS2.Services.Survival)
	assert(type(S.envTemp(Vector3.new(), false, true)) == "number")
end)
check2("Items models + tools", function()
	local I = require(game.ReplicatedStorage.Shared.Items)
	for id in pairs(I.defs) do
		local m = I.model(id)
		assert(m and m.PrimaryPart, "model " .. id)
		local t = I.buildTool(id)
		assert(t and t:FindFirstChild("Handle"), "tool " .. id)
	end
end)
check2("Icons draw", function()
	local Icons = require(SSS2.Parent.StarterPlayer.StarterPlayerScripts.Client.Icons)
	local f = Instance.new("Frame")
	for _, n in ipairs({ "play", "ranking", "rooms", "look", "settings", "solo", "quick", "friend", "key", "coin", "skill", "heart", "drop", "food", "temp", "bag", "menu", "close", "plus", "lock", "trash", "sun", "moon", "home" }) do
		Icons.draw(n, f, 24, Color3.new(1, 1, 1))
	end
end)
check2("Effects handlers", function()
	local E = require(SSS2.Parent.StarterPlayer.StarterPlayerScripts.Client.Effects)
	local ev = { h = {} }
	function ev.Connect(self, f) table.insert(self.h, f) end
	E.start({ Fx = { OnClientEvent = ev } })
	local fire = ev.h[1]
	local rig = game.Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	rig.Parent = workspace
	local tree
	for _, mm in ipairs(workspace.Resources:GetChildren()) do if mm.Name == "Tree" then tree = mm break end end
	local p = Vector3.new(0, 20, 0)
	fire("anim", rig, "chop") fire("anim", rig, "thrust") fire("explode", Vector3.new(0, 20, 0)) fire("anim", rig, "mine") fire("anim", rig, "slash") fire("anim", rig, "gun") fire("anim", rig, "bow") fire("skillUp", rig) fire("anim", rig, "eat") fire("anim", rig, "aim") fire("anim", rig, "place") fire("anim", rig, "heal")
	fire("hitTree", tree:GetPivot().Position, tree) fire("treeFall", tree) fire("hitRock", p) fire("rockBreak", p) fire("pick", p)
	fire("hitMob", p, "wolf") fire("mobDie", p, "guardian") fire("mobAttack", p, "zombie") fire("hurt", rig)
	fire("shoot", p, p + Vector3.new(30, 0, 0), "arrow") fire("shoot", p, p + Vector3.new(30, 0, 0), "ammo")
	fire("levelUp", rig) fire("cook", p) fire("celebrate", p) fire("craft", p) fire("place", p) fire("crate", p)
	task.wait(2.5)
end)
check2("crafting recipes", function()
	local Items = require(game:GetService("ReplicatedStorage").Shared.Items)
	local function g(rows)
		local cells = {}
		for y = 1, 3 do for x = 1, 3 do
			local ch = (rows[y] or "..."):sub(x, x)
			cells[(y - 1) * 3 + x] = ({ W = "wood", S = "stick", T = "stone", I = "iron", H = "hide" })[ch] or false
		end end
		return cells
	end
	assert(Items.craft(g({ "W..", "W..", "..." })).out == "stick", "stick")
	assert(Items.craft(g({ "..W", "..W", "..." })).out == "stick", "stick moved")
	assert(Items.craft(g({ "TT.", "TS.", ".S." })).out == "stone_axe", "axe")
	assert(Items.craft(g({ ".TT", ".ST", ".S." })).out == "stone_axe", "axe mirrored")
	assert(Items.craft(g({ "III", ".S.", ".S." })).out == "iron_pickaxe", "pickaxe")
	assert(Items.craft(g({ "H.H", "HHH", "HHH" })).out == "leather_armor", "armor")
	assert(Items.craft(g({ "W..", "...", "..." })) == nil, "no recipe")
	for _, rc in ipairs(Items.recipes) do
		assert(Items.get(rc.out), "unknown output " .. rc.out)
		assert(Items.model(rc.out), "no model " .. rc.out)
		for _, row in ipairs(rc.grid) do for _, id in pairs(row) do if id then assert(Items.get(id), "unknown input " .. tostring(id)) end end end
	end
	require(SSS2.Services.Crafting)
end)
check2("houses build on every plot without hitting anything", function()
	local H = require(game:GetService("ReplicatedStorage").Shared.House)
	local Homes = require(SSS2.Services.Homes)
	for _, d in ipairs(H.DESIGNS) do
		for lvl = 1, H.MAX do
			local m = H.build(d.key, lvl, {})
			local beds, chests = 0, 0
			for _, x in ipairs(m:GetDescendants()) do
				if x:IsA("Model") and x:GetAttribute("Bed") then beds += 1 end
				if x:IsA("Model") and x:GetAttribute("Chest") then chests += 1 end
			end
			assert(chests == H.chests(lvl), d.key .. " chests " .. lvl)
			assert(beds >= 1, d.key .. " beds " .. lvl)
			m:Destroy()
		end
	end
	local res = workspace:FindFirstChild("Resources")
	for i = 1, #Homes.PLOTS do
		local base = Homes._base(i)
		assert(base.Position.Y > -10 and base.Position.Y < 80, "plot height " .. i)
		local L = H.LEVELS[H.MAX]
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.FilterDescendantsInstances = { workspace.Terrain, res }
		local hits = workspace:GetPartBoundsInBox(base * CFrame.new(0, 16, 0), Vector3.new(L.w + 8, 30, L.d + 10), op)
		for _, p in ipairs(hits) do
			assert(p.Transparency >= 1 or not p.CanCollide, "plot " .. i .. " hits " .. p:GetFullName())
		end
		for _, n in ipairs(res and res:GetChildren() or {}) do
			if n:IsA("Model") then
				local rel = base:PointToObjectSpace(n:GetPivot().Position)
				assert(not (math.abs(rel.X) < L.w / 2 + 4 and math.abs(rel.Z) < L.d / 2 + 6), "plot " .. i .. " has a " .. n.Name)
			end
		end
	end
end)
check2("a house is built, upgraded to the top and its chests work", function()
	local RS = game:GetService("ReplicatedStorage")
	local H = require(RS.Shared.House)
	local Data = require(SSS2.Services.Data)
	local Inventory = require(SSS2.Services.Inventory)
	local Furnace = require(SSS2.Services.Furnace)
	local Crafting = require(SSS2.Services.Crafting)
	local Homes = require(SSS2.Services.Homes)
	local room = { inv = Inventory.new(), house = { lvl = 0, chests = {} }, coins = 0 }
	room.inv.bag = "big"
	local oldRoom = Data.room
	Data.room = function() return room end
	local notes = {}
	local c = {}
	for k, v in pairs(fake) do c[k] = v end
	c.notify = function(_, k) table.insert(notes, k) end
	c.push = function() end
	c.sleep = function() end
	c.fx = function() end
	pcall(function() Furnace.start(c, Inventory, Data, {}) end)
	pcall(function() Crafting.start(c, Inventory, Data, Furnace, {}) end)
	Homes.start(c, Inventory, Data, Furnace, Crafting)
	local char = Instance.new("Model")
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Anchored = true
	hrp.Parent = char
	char.Parent = workspace
	local pl = { UserId = 77, DisplayName = "Tester", Character = char, Parent = game }
	local okE, errE = pcall(Homes.enter, pl)
	assert(okE, tostring(errE))
	local base = Homes._base(room.house.plot)
	hrp.CFrame = base * CFrame.new(0, 3, -20)
	assert(workspace.Houses:FindFirstChild("House_77"), "no plot")
	Homes.upgrade(pl, "manor")
	assert(room.house.lvl == 0 and table.find(notes, "needWoodStone"), "built without wood")
	-- part of the price now, the rest later
	Inventory.add(room.inv, "wood", 10)
	Homes.upgrade(pl, "manor")
	assert(room.house.lvl == 0 and room.house.paid.wood == 10 and Inventory.count(room.inv, "wood") == 0, "partial payment")
	for lvl = 1, H.MAX do
		-- a small bag: bring the materials in several trips
		for trip = 1, 12 do
			if room.house.lvl >= lvl then break end
			Inventory.add(room.inv, "wood", 200)
			Inventory.add(room.inv, "stone", 200)
			Homes.upgrade(pl, "manor")
		end
		assert(room.house.lvl == lvl, "level " .. lvl .. " notes " .. table.concat(notes, ","))
		local m = workspace.Houses:FindFirstChild("House_77")
		assert(m and m:FindFirstChild("Shell"), "house model " .. lvl)
		hrp.CFrame = base * CFrame.new(0, 3, -20)
	end
	assert(Homes.bed(pl), "no bed")
	assert(Homes.spawn(pl), "no spawn")
	local m = workspace.Houses:FindFirstChild("House_77")
	local furn, tables = 0, 0
	for _, d in ipairs(m:GetDescendants()) do
		if d.Name == "Furnace" then furn += 1 end
		if d.Name == "CraftingTable" then tables += 1 end
	end
	assert(furn == 2 and tables == 1, "furnaces " .. furn .. " tables " .. tables)
	-- chest 3: put wood in and take it back
	Inventory.add(room.inv, "wood", 5)
	local chest3
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("Model") and d:GetAttribute("Chest") == 3 then chest3 = d end end
	hrp.CFrame = chest3.PrimaryPart.CFrame * CFrame.new(0, 0, -3)
	local slot
	for i = 1, 35 do if room.inv.slots[i] and room.inv.slots[i].id == "wood" then slot = i break end end
	local before = Inventory.count(room.inv, "wood")
	Homes.chestPut(pl, 3, slot)
	assert(Inventory.count(room.inv, "wood") < before, "chest put")
	assert(room.house.chests[3][1] and room.house.chests[3][1].id == "wood", "chest has wood")
	assert(not room.house.chests[2][1], "other chests stay empty")
	Homes.chestTake(pl, 3, 1)
	assert(Inventory.count(room.inv, "wood") == before and not room.house.chests[3][1], "chest take")
	Data.room = oldRoom
	m:Destroy()
	char:Destroy()
end)
check2("enchantments, books, the anvil and the supply crate", function()
	local Items = require(game:GetService("ReplicatedStorage").Shared.Items)
	local Inventory = require(SSS2.Services.Inventory)
	-- books exist for every level, one per bag square, with a model
	for _, k in ipairs(Items.ENCH_ORDER) do
		for l = 1, Items.ENCH[k].max do
			local id = "book_" .. k .. "_" .. l
			assert(Items.get(id) and Items.stack(id) == 1 and Items.model(id), "book " .. id)
			assert(Items.enchPrice(k, l) >= 1000, "price " .. id)
		end
	end
	assert(Items.enchPrice("sharpness", 5) > Items.enchPrice("sharpness", 1), "price grows with level")
	-- what fits where
	assert(Items.canEnchant("iron_sword", "sharpness") and not Items.canEnchant("iron_sword", "protection"), "sword")
	assert(Items.canEnchant("iron_pickaxe", "fortune") and not Items.canEnchant("iron_pickaxe", "fire_aspect"), "pickaxe")
	assert(Items.canEnchant("iron_armor", "protection") and not Items.canEnchant("iron_armor", "sharpness"), "armor")
	-- the anvil
	local r = Items.anvil({ id = "iron_sword", n = 1, d = 100 }, { id = "book_sharpness_3", n = 1 })
	assert(r and r.out.e.sharpness == 3 and r.out.d == 100 and r.price >= 1000, "sword + book")
	r = Items.anvil({ id = "iron_sword", n = 1, e = { sharpness = 3 } }, { id = "book_sharpness_3", n = 1 })
	assert(r and r.out.e.sharpness == 4, "same level goes up one")
	local _, err = Items.anvil({ id = "iron_sword", n = 1, e = { sharpness = 5 } }, { id = "book_sharpness_5", n = 1 })
	assert(err == "enchMaxed", "max " .. tostring(err))
	_, err = Items.anvil({ id = "iron_armor", n = 1, e = { protection = 2 } }, { id = "book_fire_protection_1", n = 1 })
	assert(err == "enchConflict", "protections clash " .. tostring(err))
	_, err = Items.anvil({ id = "iron_pickaxe", n = 1 }, { id = "book_protection_1", n = 1 })
	assert(err == "enchNotFit", "doesn't fit " .. tostring(err))
	r = Items.anvil({ id = "book_looting_2", n = 1 }, { id = "book_looting_2", n = 1 })
	assert(r and r.out.id == "book_looting_3", "two books")
	assert(Items.cleanEnch("iron_sword", { sharpness = 9, protection = 2, nonsense = 1 }).sharpness == 5, "clean")
	-- enchanted items never stack and keep their enchantments in the bag
	local inv = Inventory.new()
	inv.bag = true
	Inventory.add(inv, "book_fortune_1", 1)
	Inventory.add(inv, "book_fortune_1", 1)
	local books = 0
	for i = 1, 20 do if inv.slots[i] and inv.slots[i].id == "book_fortune_1" then books += 1 end end
	assert(books == 2, "books in two squares")
	Inventory.add(inv, "iron_sword", 1, 50, { sharpness = 2 })
	local fixed = Inventory.fix(inv)
	local found = false
	for i = 1, 20 do if fixed.slots[i] and fixed.slots[i].id == "iron_sword" then found = fixed.slots[i].e and fixed.slots[i].e.sharpness == 2 end end
	assert(found, "enchantment saved")
	-- iron and diamond gear is no longer sold
	for shop in pairs(Items.shops) do
		for _, id in ipairs({ "iron_sword", "diamond_pickaxe", "iron_armor" }) do assert(not Items.inShop(shop, id), id .. " sold at " .. shop) end
	end
	for _, id in ipairs({ "obsidian_sword", "obsidian_armor", "crystal_sword", "crystal_armor", "obsidian_pickaxe" }) do assert(Items.get(id) and Items.model(id), "new " .. id) end
	-- supply crate loot
	local Drops = require(SSS2.Services.Drops)
	for _, l in ipairs(Drops._loot) do assert(l[1] == "coins" or l[1] == "book" or Items.get(l[1]), "loot " .. l[1]) end
	for _ = 1, 50 do assert(Items.get(Drops._book()), "random book") end
	require(SSS2.Services.Smith)
end)
return { results, results2 }
