-- Harvestable nodes (trees, rocks, berry bushes) under workspace.Resources.
local R = {}

local folder
local nodes = {} -- [model] = { parts = { [part] = {T, CC, CQ} } }
local rng = Random.new()
local ctx

local function capture(model)
	local info = { parts = {} }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			info.parts[d] = { T = d.Transparency, CC = d.CanCollide, CQ = d.CanQuery }
		end
	end
	nodes[model] = info
end

local function setHidden(model, hidden, filter)
	local info = nodes[model]
	if not info then return end
	for part, o in pairs(info.parts) do
		if not filter or filter(part) then
			part.Transparency = hidden and 1 or o.T
			part.CanCollide = (not hidden) and o.CC
			part.CanQuery = (not hidden) and o.CQ
		end
	end
end

local function nodeOf(part)
	local cur = part
	while cur and cur.Parent ~= folder do cur = cur.Parent end
	if cur and nodes[cur] then return cur end
	return nil
end

local REWARD = {
	tree = { id = "wood", min = 3, max = 5, xp = 6, coins = 2, respawn = 120 },
	rock = { id = "stone", min = 2, max = 4, xp = 5, coins = 3, respawn = 150 },
	iron = { id = "iron", min = 1, max = 2, xp = 9, coins = 4, respawn = 210 },
	gold = { id = "gold", min = 1, max = 2, xp = 14, coins = 8, respawn = 300, needRock = 3 },
	diamond = { id = "diamond", min = 1, max = 1, xp = 25, coins = 15, respawn = 480, needRock = 5 },
	crystal = { id = "crystal", min = 1, max = 3, xp = 16, coins = 6, respawn = 360, needRock = 4 },
	obsidian = { id = "obsidian", min = 1, max = 2, xp = 30, coins = 14, respawn = 600, needRock = 6 },
}

function R.init(c)
	ctx = c
	folder = workspace:FindFirstChild("Resources")
	if not folder then warn("workspace.Resources not found") return end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") then
			capture(model)
			if model:GetAttribute("NodeType") == "bush" then
				local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt then
					local gives = model:GetAttribute("Gives") or "berries"
					prompt:SetAttribute("Key", "pick")
					if gives ~= "berries" then prompt:SetAttribute("Obj", gives) end
					prompt.Triggered:Connect(function(player)
						if model:GetAttribute("Ready") == false then return end
						if ctx.space(player, gives) <= 0 then ctx.notify(player, "bagFull") return end
						local n = gives == "berries" and rng:NextInteger(2, 3) or rng:NextInteger(1, 2)
						if ctx.lucky(player, 0.03) then n *= 2 end
						ctx.give(player, gives, n)
						ctx.reward(player, gives == "berries" and 2 or 4, 0)
						ctx.notify(player, "picked", gives, n)
						ctx.fx("pick", model:GetPivot().Position)
						model:SetAttribute("Ready", false)
						prompt.Enabled = false
						setHidden(model, true, function(p) return p.Name == "Berry" end)
						task.delay(90, function()
							model:SetAttribute("Ready", true)
							prompt.Enabled = true
							setHidden(model, false, function(p) return p.Name == "Berry" end)
						end)
					end)
				end
			end
		end
	end
end

-- nearest living node inside the given parts list
function R.pick(parts, from)
	local best, bestDist
	for _, part in ipairs(parts) do
		local m = nodeOf(part)
		if m and (m:GetAttribute("HP") or 0) > 0 and REWARD[m:GetAttribute("NodeType")] then
			local d = (part.Position - from).Magnitude
			if not bestDist or d < bestDist then best, bestDist = m, d end
		end
	end
	return best
end

function R.folder() return folder end

-- living nodes within a radius (used by explosions)
function R.near(pos, radius)
	local out = {}
	for model in pairs(nodes) do
		if model.Parent and (model:GetAttribute("HP") or 0) > 0 and REWARD[model:GetAttribute("NodeType")] then
			if (model:GetPivot().Position - pos).Magnitude <= radius then table.insert(out, model) end
		end
	end
	return out
end

-- returns true if the hit landed
function R.hit(player, node, def, bonus)
	local kind = node:GetAttribute("NodeType")
	local rw = REWARD[kind]
	if not rw then return false end
	if ctx.space(player, rw.id) <= 0 then
		ctx.notify(player, "bagFull")
		return false
	end
	if rw.needRock and (def.rock or 1) < rw.needRock then
		ctx.notify(player, rw.needRock > 3 and "needBetterPickaxe" or "needPickaxe")
		return false
	end
	local power = ((kind == "tree") and (def.tree or 1) or (def.rock or 1)) + (bonus or 0)
	local hp = node:GetAttribute("HP") - power
	node:SetAttribute("HP", hp)
	ctx.fx(kind == "tree" and "hitTree" or "hitRock", node:GetPivot().Position, node)
	if hp <= 0 then
		local n = rng:NextInteger(rw.min, rw.max)
		-- Fortune: up to one more per level
		if def.fortune then n += rng:NextInteger(0, def.fortune) end
		if power >= 3 then n += 1 end
		if ctx.lucky(player, 0.03) then n *= 2 end
		n = math.min(n, ctx.space(player, rw.id))
		ctx.give(player, rw.id, n)
		ctx.reward(player, rw.xp, rw.coins)
		ctx.notify(player, "picked", rw.id, n)
		if ctx.bump then ctx.bump(player, kind == "tree" and "trees" or "rocks", 1) end
		if kind == "tree" then
			ctx.fx("treeFall", node)
			task.delay(1.7, function() setHidden(node, true) end)
		else
			ctx.fx("rockBreak", node:GetPivot().Position, node)
			setHidden(node, true)
		end
		task.delay(rw.respawn, function()
			node:SetAttribute("HP", node:GetAttribute("MaxHP"))
			setHidden(node, false)
		end)
	end
	return true
end

return R
