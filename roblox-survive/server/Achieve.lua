-- Tracks the achievement counters in the profile and hands out the rewards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local A = require(ReplicatedStorage.Shared.Achievements)

local M = {}
local ctx, Data, Inventory

local function store(p)
	p.ach = type(p.ach) == "table" and p.ach or {}
	p.ach.stats = type(p.ach.stats) == "table" and p.ach.stats or {}
	p.ach.done = type(p.ach.done) == "table" and p.ach.done or {}
	return p.ach
end

function M.view(player)
	local p = Data.profile(player)
	if not p then return nil end
	local a = store(p)
	return { stats = a.stats, done = a.done }
end

local function give(player, reward)
	local room = Data.room(player)
	if not room then return end
	if reward.coins then Data.addCoins(player, reward.coins) end
	if reward.token then
		local rest = Inventory.add(room.inv, "token", reward.token)
		if rest > 0 then Inventory.stashPut(room.stash, { id = "token", n = rest }) end
	end
end

local function check(player)
	local p = Data.profile(player)
	if not p then return end
	local a = store(p)
	for _, def in ipairs(A.list) do
		if not a.done[def.key] and (a.stats[def.stat] or 0) >= def.goal then
			a.done[def.key] = true
			give(player, def.reward)
			ctx.notify(player, "achieved", def.key)
			ctx.feed("achieved", player.DisplayName, def.key)
			if player.Character then ctx.fx("levelUp", player.Character) end
		end
	end
	ctx.push(player)
end

-- add n to a counter (or, for "highest" counters, keep the larger value)
function M.bump(player, stat, n)
	local p = Data.profile(player)
	if not p or not player.Parent then return end
	local a = store(p)
	n = n or 1
	if A.highest[stat] then
		if n <= (a.stats[stat] or 0) then return end
		a.stats[stat] = n
	else
		a.stats[stat] = (a.stats[stat] or 0) + n
	end
	check(player)
end

function M.start(c, data, inv)
	ctx, Data, Inventory = c, data, inv
	-- things that are easier to read than to hook: level, coins, index, medals, players in the room
	task.spawn(function()
		while true do
			task.wait(5)
			local n = #Players:GetPlayers()
			for _, pl in ipairs(Players:GetPlayers()) do
				local room = Data.room(pl)
				if room then
					pcall(function()
						local cfg = require(ReplicatedStorage.Shared.Config)
						M.bump(pl, "level", (cfg.levelFromXp(room.xp)))
						M.bump(pl, "coins", room.coins)
						M.bump(pl, "party", n)
						local seen, medals = 0, 0
						for _ in pairs(room.dex and room.dex.seen or {}) do seen += 1 end
						for _ in pairs(room.dex and room.dex.medals or {}) do medals += 1 end
						M.bump(pl, "discovered", seen)
						M.bump(pl, "medals", medals)
						local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
						if hrp and hrp.Position.Y < -26 then M.bump(pl, "caves", 1) end
					end)
				end
			end
		end
	end)
end

return M
