-- Villages: villagers walk around, archers on the towers and spear guards keep predators and bandits away.
-- Built by the map generator under workspace.Villages: each village model has Center / Radius attributes
-- and an "NPCs" folder of rigs with a Role attribute (villager | guard | archer | trader).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage.Shared.Items)
local Ground = require(script.Parent.Ground)
local Debug = require(script.Parent.Debug)

local V = {}
local rng = Random.new()

local function equip(rig, id)
	local hum = rig:FindFirstChildOfClass("Humanoid")
	local tool = Items.buildTool(id)
	if hum and tool then
		tool.Parent = rig
		pcall(function() hum:EquipTool(tool) end)
	end
end

local function rootOf(rig)
	return rig:FindFirstChild("HumanoidRootPart")
end

function V.start(ctx, Mobs)
	local folder = workspace:FindFirstChild("Villages")
	if not folder then return end
	local villages = {}
	for _, v in ipairs(folder:GetChildren()) do
		local center, radius = v:GetAttribute("Center"), v:GetAttribute("Radius")
		local npcs = v:FindFirstChild("NPCs")
		if center and radius and npcs then
			local rec = { model = v, center = center, radius = radius, villagers = {}, guards = {}, archers = {}, inside = {} }
			for _, rig in ipairs(npcs:GetChildren()) do
				local role = rig:GetAttribute("Role")
				local root = rootOf(rig)
				if root then
					rig:SetAttribute("Post", root.Position)
					if role == "villager" then table.insert(rec.villagers, { rig = rig, next = 0 })
					elseif role == "guard" then table.insert(rec.guards, { rig = rig, cd = 0 }) equip(rig, "spear")
					elseif role == "archer" then table.insert(rec.archers, { rig = rig, cd = 0 }) equip(rig, "crossbow") end
				end
			end
			table.insert(villages, rec)
		end
	end
	Debug.log("villages", "loaded " .. #villages)

	-- walkers stay anchored until the terrain under them has collision again
	local ready = false
	task.spawn(function()
		local t0 = os.clock()
		while not workspace:GetAttribute("TerrainReady") and os.clock() - t0 < 180 do task.wait(1) end
		for _, rec in ipairs(villages) do
			for _, list in ipairs({ rec.villagers, rec.guards }) do
				for _, n in ipairs(list) do
					local root = rootOf(n.rig)
					if root then
						root.Anchored = false
						pcall(function() root:SetNetworkOwner(nil) end)
					end
				end
			end
		end
		ready = true
	end)

	local function face(rig, pos)
		local root = rootOf(rig)
		if not root then return end
		local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			if root.Anchored then
				root.CFrame = CFrame.lookAt(root.Position, flat)
			end
		end
	end

	local function stepVillage(rec, now)
		local threats = Mobs.hostileNear(rec.center, rec.radius + 40)
		-- archers shoot from the towers
		for _, a in ipairs(rec.archers) do
			local root = rootOf(a.rig)
			if root and now >= a.cd then
				local best, bd
				for _, t in ipairs(threats) do
					local d = (t.pos - root.Position).Magnitude
					if d < 120 and (not bd or d < bd) then best, bd = t, d end
				end
				if best then
					a.cd = now + 1.6
					face(a.rig, best.pos)
					local head = a.rig:FindFirstChild("Head")
					local from = (head and head.Position or root.Position) + Vector3.new(0, 0.3, 0)
					ctx.fx("shoot", from, best.pos, "bolt")
					Mobs.damage(best.model, 38, nil)
				end
			end
		end
		-- spear guards run at anything that comes in, then go back to their post
		for _, g in ipairs(rec.guards) do
			local root = rootOf(g.rig)
			local hum = g.rig:FindFirstChildOfClass("Humanoid")
			if root and hum and ready then
				local best, bd
				for _, t in ipairs(threats) do
					local d = (t.pos - root.Position).Magnitude
					if d < rec.radius + 30 and (not bd or d < bd) then best, bd = t, d end
				end
				if best then
					hum.WalkSpeed = 17
					hum:MoveTo(best.pos)
					if bd < 7.5 and now >= g.cd then
						g.cd = now + 1.1
						ctx.fx("anim", g.rig, "thrust")
						Mobs.damage(best.model, 34, nil)
					end
				else
					local post = g.rig:GetAttribute("Post")
					if post and (root.Position - post).Magnitude > 4 then
						hum.WalkSpeed = 10
						hum:MoveTo(post)
					end
				end
			end
		end
		-- villagers stroll between the houses
		for _, n in ipairs(rec.villagers) do
			local hum = n.rig:FindFirstChildOfClass("Humanoid")
			if hum and ready and now >= n.next then
				n.next = now + rng:NextNumber(5, 12)
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(4, rec.radius * 0.55)
				local x, z = rec.center.X + math.cos(a) * r, rec.center.Z + math.sin(a) * r
				local h = Ground.height(x, z)
				if h then
					hum.WalkSpeed = rng:NextNumber(6, 9)
					hum:MoveTo(Vector3.new(x, h + 2, z))
				end
			end
		end
		-- tell players when they are under the village's protection
		for _, pl in ipairs(Players:GetPlayers()) do
			local c = pl.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local inside = r and (Vector3.new(r.Position.X - rec.center.X, 0, r.Position.Z - rec.center.Z)).Magnitude < rec.radius
			if inside and not rec.inside[pl] then ctx.notify(pl, "villageSafe") end
			rec.inside[pl] = inside or nil
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.4)
			local now = os.clock()
			for _, rec in ipairs(villages) do
				local ok, err = pcall(stepVillage, rec, now)
				if not ok then Debug.log("villages.step", err) end
			end
		end
	end)
end

return V
