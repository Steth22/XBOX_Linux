-- the big map: regions, villages, bandit camps, outposts, every creature, the index data
local results = {}
local function check(name, fn)
	local ok, err = pcall(fn)
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
end
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
check("every creature spawns", function()
	local Best = require(RS.Shared.Bestiary)
	local Mobs = require(SSS.Services.Mobs)
	local bad = {}
	for kind in pairs(Best.kinds) do
		local ok, m = pcall(Mobs.spawn, kind, Vector3.new(0, 300, 0), 2)
		if not ok or not m or not m.PrimaryPart then table.insert(bad, kind .. ":" .. tostring(m)) end
		if ok and m then m:Destroy() end
	end
	assert(#bad == 0, table.concat(bad, ", "))
end)
check("index lists and names", function()
	local Best = require(RS.Shared.Bestiary)
	local L = require(RS.Shared.Locale)
	for _, r in ipairs(Best.regions) do
		assert(L.ar["biome_" .. r.key] and L.en["biome_" .. r.key], r.key)
		for _, k in ipairs(r.kinds) do
			assert(Best.kinds[k], "type " .. k)
			assert(L.ar["mob_" .. k] and L.en["mob_" .. k], "name " .. k)
		end
	end
	for _, t in ipairs(Best.types) do assert(L.ar["ty_" .. t], t) end
	local kills = {}
	for _, k in ipairs(Best.region("beach").kinds) do kills[k] = 1 end
	local done = Best.completed(kills)
	assert(#done == 1 and done[1] == "beach")
end)
check("regions all exist on the map", function()
	local B = require(RS.Shared.Biomes)
	local seen = {}
	for x = -B.HALF + 40, B.HALF - 40, 48 do
		for z = -B.HALF + 40, B.HALF - 40, 48 do seen[B.at(x, z)] = (seen[B.at(x, z)] or 0) + 1 end
	end
	local parts = {}
	for _, r in ipairs(B.list) do
		assert((seen[r] or 0) > 20, "missing " .. r)
		table.insert(parts, r .. "=" .. seen[r])
	end
	print(table.concat(parts, " "))
end)
check("villages are complete", function()
	local v = workspace.Villages:GetChildren()
	assert(#v >= 5, "villages " .. #v)
	for _, m in ipairs(v) do
		assert(m:GetAttribute("Center") and m:GetAttribute("Radius"), m.Name)
		local roles = {}
		for _, r in ipairs(m.NPCs:GetChildren()) do roles[r:GetAttribute("Role")] = (roles[r:GetAttribute("Role")] or 0) + 1 end
		assert((roles.archer or 0) >= 2 and (roles.guard or 0) >= 2 and (roles.villager or 0) >= 3, m.Name)
		local pr
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("ProximityPrompt") and d:GetAttribute("Shop") == "village" then pr = d end end
		assert(pr, "no trader " .. m.Name)
		assert(m:FindFirstChild("Trader"), "no trader rig " .. m.Name)
	end
end)
check("outposts, camps, spots", function()
	assert(#workspace.Outposts:GetChildren() >= 6, "outposts " .. #workspace.Outposts:GetChildren())
	assert(#workspace.BanditCamps:GetChildren() >= 4, "camps " .. #workspace.BanditCamps:GetChildren())
	for _, c in ipairs(workspace.BanditCamps:GetChildren()) do assert(#c.Spots:GetChildren() >= 2) end
	assert(#workspace.BlackMarketSpots:GetChildren() >= 10)
	local I = require(RS.Shared.Items)
	for _, o in ipairs(workspace.Outposts:GetChildren()) do
		for _, d in ipairs(o:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d:GetAttribute("Shop") then assert(I.shops[d:GetAttribute("Shop")], d:GetAttribute("Shop")) end
		end
	end
end)
check("index data saves", function()
	local Data = require(SSS.Services.Data)
	assert(Data.loadRoom ~= nil)
	local W = require(SSS.Services.World)
	assert(W._test.ctx.killed and W._test.ctx.seen)
end)
check("villages module starts", function()
	local V = require(SSS.Services.Villages)
	local W = require(SSS.Services.World)
	V.start(W._test.ctx, require(SSS.Services.Mobs))
end)
check("armor looks", function()
	local A = require(RS.Shared.Appearance)
	local I = require(RS.Shared.Items)
	local rig = game.Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	rig.Parent = workspace
	A.apply(rig, A.default())
	for _, id in ipairs({ "leather_armor", "iron_armor", "diamond_armor", "warm_coat", "desert_cloak", "lava_cloak", "jungle_vest" }) do
		local d = I.get(id)
		A.armor(rig, d.color, d.mat, id)
		local n = #rig.Armor:GetChildren()
		assert(n >= 8, id .. " parts " .. n)
		assert(I.model(id), "model " .. id)
	end
	A.armor(rig, nil)
	assert(not rig:FindFirstChild("Armor"))
	rig:Destroy()
end)
check("world map data", function()
	local W = require(SSS.Services.World)
	local Config = require(RS.Shared.Config)
	assert(Config.MAP_CELLS == 48)
	-- map places exist for the explored check
	local n = 0
	for _, f in ipairs({ "Villages", "Outposts", "Caves" }) do n += #workspace[f]:GetChildren() end
	assert(n > 15, "places " .. n)
end)
return results
