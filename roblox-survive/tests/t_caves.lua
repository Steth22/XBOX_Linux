-- caves, cave creatures, the secret trader, new items
local results = {}
local function check(name, fn)
	local ok, err = pcall(fn)
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
end
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
check("caves have spots on real floors", function()
	local Ground = require(SSS.Services.Ground)
	local n, bad = 0, {}
	for _, cave in ipairs(workspace.Caves:GetChildren()) do
		assert(cave:GetAttribute("Type"), "no type " .. cave.Name)
		for _, sp in ipairs(cave.Spots:GetChildren()) do
			n += 1
			local f = Ground.floor(sp.Position.X, sp.Position.Y + 1, sp.Position.Z)
			if not f or math.abs(f - sp.Position.Y) > 2.5 then table.insert(bad, cave.Name .. " " .. tostring(f) .. "/" .. math.floor(sp.Position.Y)) end
		end
	end
	assert(n >= 20, "spots " .. n)
	assert(#bad <= 2, table.concat(bad, ", "))
end)
check("cave creatures spawn and walk", function()
	local Mobs = require(SSS.Services.Mobs)
	local cave = nil
	for _, c in ipairs(workspace.Caves:GetChildren()) do if c:GetAttribute("Type") == "wide" then cave = c end end
	assert(cave, "no wide cave")
	local sp = cave.Spots:GetChildren()[1].Position
	for _, k in ipairs({ "bat", "crawler", "ghoul", "golem" }) do
		local m = Mobs.spawn(k, sp, 3, { id = cave })
		assert(m and m.PrimaryPart, k)
		m:Destroy()
	end
end)
check("secret trader builds and moves", function()
	local W = require(SSS.Services.World)
	assert(#workspace.BlackMarketSpots:GetChildren() >= 8)
	local m = W._test.buildBlack(workspace.BlackMarketSpots:GetChildren()[1].CFrame)
	assert(m:FindFirstChild("Trader") and m:FindFirstChild("Trader"):FindFirstChild("HumanoidRootPart"), "no trader")
	local pr = m:FindFirstChildWhichIsA("ProximityPrompt", true)
	assert(pr and pr:GetAttribute("Shop") == "black")
	m:Destroy()
end)
check("shops and new items", function()
	local I = require(RS.Shared.Items)
	for shop, cats in pairs(I.shops) do
		for _, c in ipairs(cats) do
			for _, id in ipairs(c.ids) do assert(I.get(id) and I.get(id).buy, shop .. ":" .. id) end
		end
	end
	for _, c in ipairs(I.shops.black) do for _, id in ipairs(c.ids) do assert(I.get(id).buy >= 300, id) end end
	assert(I.inShop("forest", "lantern") and I.inShop("snow", "lantern") and I.inShop("desert", "lantern") and I.inShop("mountains", "lantern"))
	assert(I.get("lantern").buy == 1000 and I.get("lantern").dur == 720)
	assert(I.get("hide_snow").sell > I.get("hide_desert").sell and I.get("hide_desert").sell > I.get("hide").sell)
	local L = require(RS.Shared.Locale)
	for _, k in ipairs({ "cat_special", "cat_potions", "o_black", "p_sleep", "mob_golem", "buff_vision", "sleeping" }) do
		assert(L.ar[k] and L.en[k], k)
	end
end)
check("cave ores and mushrooms exist", function()
	local n = { crystal = 0, obsidian = 0, mush = 0 }
	for _, m in ipairs(workspace.Resources:GetChildren()) do
		local t = m:GetAttribute("NodeType")
		if t == "crystal" or t == "obsidian" then n[t] += 1 end
		if m:GetAttribute("Gives") == "mushroom" then n.mush += 1 end
	end
	assert(n.crystal > 5 and n.obsidian > 2 and n.mush > 5, n.crystal .. "/" .. n.obsidian .. "/" .. n.mush)
end)
return results
