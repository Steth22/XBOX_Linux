-- caves, cave creatures, the secret trader, new items
local results = {}
local function check(name, fn)
	local ok, err = pcall(fn)
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
end
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
check("underground caverns have spots on real floors", function()
	local Ground = require(SSS.Services.Ground)
	local n, bad, caverns = 0, {}, 0
	for _, cave in ipairs(workspace.Caves:GetChildren()) do
		local spots = cave:FindFirstChild("Spots")
		if spots then
			caverns += 1
			for _, sp in ipairs(spots:GetChildren()) do
				n += 1
				if n % 5 == 0 then
					local f = Ground.floor(sp.Position.X, sp.Position.Y + 1, sp.Position.Z)
					if not f or math.abs(f - sp.Position.Y) > 2.5 then table.insert(bad, cave.Name) end
				end
			end
		end
	end
	assert(caverns >= 200, "caverns " .. caverns)
	assert(n >= 600, "spots " .. n)
	assert(#bad <= 6, #bad .. " bad: " .. table.concat(bad, ", "))
end)
check("cave creatures and the new bosses spawn", function()
	local Mobs = require(SSS.Services.Mobs)
	local cave = nil
	for _, c in ipairs(workspace.Caves:GetChildren()) do if c:GetAttribute("Boss") == "spiderqueen" then cave = c end end
	assert(cave, "no spider queen lair")
	local sp = cave.Spots:GetChildren()[1].Position
	for _, k in ipairs({ "bat", "crawler", "ghoul", "golem", "spiderqueen", "giantworm", "mineguardian" }) do
		local m = Mobs.spawn(k, sp, 3, { id = cave })
		assert(m and m.PrimaryPart, k)
		m:Destroy()
	end
end)
check("mines, carts, entrances, camps, ruins, mask", function()
	local u = workspace.Underground
	assert(#u.Tracks:GetChildren() == 4, "tracks")
	assert(#u.Minecarts:GetChildren() >= 12, "carts")
	for _, t in ipairs(u.Tracks:GetChildren()) do assert(#(t:GetAttribute("Points") or "") > 1000, t.Name) end
	local e = 0
	for _, c in ipairs(workspace.Caves:GetChildren()) do if c:GetAttribute("Type") == "entrance" then e += 1 end end
	assert(e >= 20, "entrances " .. e)
	assert(#workspace.UnderCamps:GetChildren() >= 6, "camps")
	assert(u:FindFirstChild("Ruins") and u.Ruins:FindFirstChild("VaultDoor"), "vault")
	assert(#(workspace:GetAttribute("CaveMask") or "") == 96 * 96, "mask")
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
