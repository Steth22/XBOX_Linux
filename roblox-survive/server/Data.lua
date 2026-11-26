-- Player profile (global) + per-room data + global XP leaderboard.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Appearance = require(ReplicatedStorage.Shared.Appearance)
local Inventory = require(script.Parent.Inventory)

local Data = {}

local profileStore = DataStoreService:GetDataStore("Profiles_v1")
local roomStore = DataStoreService:GetDataStore("RoomPlayers_v1")
local board = DataStoreService:GetOrderedDataStore("GlobalXP_v1")

local profiles = {} -- [Player] = profile
local rooms = {} -- [Player] = room data
local roomCodes = {} -- [Player] = code
local boardDirty = {}

local function try(fn, tries)
	tries = tries or 3
	local lastErr
	for i = 1, tries do
		local ok, res = pcall(fn)
		if ok then return true, res end
		lastErr = res
		task.wait(1.2 * i)
	end
	return false, lastErr
end

local function defaultProfile()
	return { lang = "ar", look = Appearance.default(), lifeXp = 0, rooms = {}, owned = {} }
end

local function defaultRoom()
	local inv = Inventory.new()
	for _, it in ipairs(Config.START_ITEMS) do
		Inventory.add(inv, it[1], it[2])
	end
	local skills = {}
	for _, k in ipairs(Config.SKILLS) do skills[k] = 0 end
	return { coins = Config.START_COINS, xp = 0, sp = 0, inv = inv, hunger = 100, thirst = 100, skills = skills, stash = Inventory.newStash(), dex = { seen = {}, kills = {}, medals = {}, neck = false }, t = os.time() }
end

---------------------------------------------------------------- profile
function Data.loadProfile(player)
	local ok, res = try(function()
		return profileStore:GetAsync("p_" .. player.UserId)
	end)
	local p = defaultProfile()
	if ok and type(res) == "table" then
		p.lang = (res.lang == "en") and "en" or "ar"
		p.look = Appearance.sanitize(res.look)
		p.lifeXp = math.max(0, tonumber(res.lifeXp) or 0)
		if type(res.owned) == "table" then
			for _, c in ipairs(res.owned) do
				if type(c) == "string" and #p.owned < 5 then table.insert(p.owned, c) end
			end
		end
		if type(res.rooms) == "table" then
			for _, r in ipairs(res.rooms) do
				if type(r) == "table" and type(r.code) == "string" then
					table.insert(p.rooms, { code = r.code, last = tonumber(r.last) or 0, coins = tonumber(r.coins) or 0, xp = tonumber(r.xp) or 0 })
				end
			end
		end
	elseif not ok then
		p._noSave = true -- never overwrite real data after a failed load
		warn("Profile load failed for", player.UserId, res)
	end
	if player.Parent then
		profiles[player] = p
		if p.lifeXp > 0 then boardDirty[player] = true end
	end
	return p
end

function Data.profile(player)
	return profiles[player]
end

function Data.waitProfile(player, timeout)
	local t0 = os.clock()
	while not profiles[player] and player.Parent and os.clock() - t0 < (timeout or 20) do
		task.wait(0.2)
	end
	return profiles[player]
end

function Data.saveProfile(player)
	local p = profiles[player]
	if not p or p._noSave then return end
	local copy = { lang = p.lang, look = p.look, lifeXp = p.lifeXp, rooms = p.rooms, owned = p.owned }
	try(function()
		profileStore:SetAsync("p_" .. player.UserId, copy)
	end)
end

function Data.touchRoomList(player, code, coins, xp)
	local p = profiles[player]
	if not p then return end
	local found
	for _, r in ipairs(p.rooms) do
		if r.code == code then found = r break end
	end
	if not found then
		found = { code = code }
		table.insert(p.rooms, found)
	end
	found.last = os.time()
	found.coins = coins or found.coins or 0
	found.xp = xp or found.xp or 0
	table.sort(p.rooms, function(a, b) return (a.last or 0) > (b.last or 0) end)
	while #p.rooms > 10 do table.remove(p.rooms) end
end

---------------------------------------------------------------- room data
function Data.loadRoom(player, code)
	local ok, res = try(function()
		return roomStore:GetAsync("r_" .. code .. "_" .. player.UserId)
	end)
	local r = defaultRoom()
	if ok and type(res) == "table" then
		r.coins = math.max(0, math.floor(tonumber(res.coins) or r.coins))
		r.xp = math.max(0, math.floor(tonumber(res.xp) or 0))
		r.sp = math.max(0, math.floor(tonumber(res.sp) or 0))
		r.inv = Inventory.fix(res.inv)
		r.stash = Inventory.fixStash(res.stash)
		r.hunger = math.clamp(tonumber(res.hunger) or 100, 10, 100)
		r.thirst = math.clamp(tonumber(res.thirst) or 100, 10, 100)
		if type(res.pos) == "table" and tonumber(res.pos[1]) and tonumber(res.pos[2]) and tonumber(res.pos[3]) then
			r.pos = { tonumber(res.pos[1]), tonumber(res.pos[2]), tonumber(res.pos[3]) }
		end
		if type(res.explored) == "string" and #res.explored == Config.MAP_CELLS * Config.MAP_CELLS and not res.explored:find("[^01]") then
			r.explored = res.explored
		end
		if type(res.spawn) == "table" and tonumber(res.spawn[1]) and tonumber(res.spawn[2]) and tonumber(res.spawn[3]) then
			r.spawn = { tonumber(res.spawn[1]), tonumber(res.spawn[2]), tonumber(res.spawn[3]), village = res.spawn.village == true }
		end
		if type(res.dex) == "table" then
			local Best = require(game:GetService("ReplicatedStorage").Shared.Bestiary)
			local d = res.dex
			for k in pairs(Best.kinds) do
				if type(d.seen) == "table" and d.seen[k] then r.dex.seen[k] = true end
				if type(d.kills) == "table" and tonumber(d.kills[k]) then r.dex.kills[k] = math.max(0, math.floor(tonumber(d.kills[k]))) end
			end
			for _, reg in ipairs(Best.regions) do
				if type(d.medals) == "table" and d.medals[reg.key] then r.dex.medals[reg.key] = true end
			end
			if type(d.neck) == "string" and r.dex.medals[d.neck] then r.dex.neck = d.neck end
		end
		if type(res.skills) == "table" then
			for _, k in ipairs(Config.SKILLS) do
				r.skills[k] = math.clamp(math.floor(tonumber(res.skills[k]) or 0), 0, Config.SKILL_CAP[k] or 999)
			end
		end
	elseif not ok then
		r._noSave = true
		warn("Room load failed", code, player.UserId, res)
	else
		r._new = true -- first time in this room
	end
	if player.Parent then
		rooms[player] = r
		roomCodes[player] = code
		Data.touchRoomList(player, code, r.coins, r.xp)
	end
	return r
end

function Data.room(player)
	return rooms[player]
end

function Data.roomCode(player)
	return roomCodes[player]
end

function Data.saveRoom(player)
	local r, code = rooms[player], roomCodes[player]
	if not r or not code then return end
	Data.touchRoomList(player, code, r.coins, r.xp)
	if r._noSave then return end
	local copy = { coins = r.coins, xp = r.xp, sp = r.sp, inv = r.inv, hunger = r.hunger, thirst = r.thirst, skills = r.skills, stash = r.stash, dex = r.dex, pos = r.pos, explored = r.explored, spawn = r.spawn, t = os.time() }
	try(function()
		roomStore:SetAsync("r_" .. code .. "_" .. player.UserId, copy)
	end)
end

-- returns levels gained, new level
function Data.addXp(player, n)
	local r, p = rooms[player], profiles[player]
	if not r or not p then return 0, 1 end
	local before = Config.levelFromXp(r.xp)
	r.xp += n
	p.lifeXp += n
	boardDirty[player] = true
	local after = Config.levelFromXp(r.xp)
	local gained = after - before
	if gained > 0 then r.sp += gained end
	return gained, after
end

function Data.addCoins(player, n)
	local r = rooms[player]
	if r then r.coins = math.max(0, r.coins + n) end
end

---------------------------------------------------------------- leaderboard
local names = {}
local function nameOf(userId)
	if names[userId] then return names[userId] end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = ok and n or "?"
	return names[userId]
end

local cache = { t = -1e9, list = {}, rank = {} }

local function refresh()
	if os.clock() - cache.t < 60 then return end
	local list, rank = {}, {}
	local ok = pcall(function()
		local pages = board:GetSortedAsync(false, 100)
		local pos = 0
		for _ = 1, math.max(1, Config.RANK_SCAN // 100) do
			for _, e in ipairs(pages:GetCurrentPage()) do
				pos += 1
				rank[tostring(e.key)] = { rank = pos, xp = e.value }
				if pos <= Config.LB_SIZE then
					table.insert(list, { rank = pos, userId = tonumber(e.key), xp = e.value })
				end
			end
			if pages.IsFinished then break end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if ok then
		cache = { t = os.clock(), list = list, rank = rank }
	else
		cache.t = os.clock() - 40 -- retry soon
	end
end

function Data.getBoard(player)
	refresh()
	local top = {}
	for _, e in ipairs(cache.list) do
		table.insert(top, { rank = e.rank, name = nameOf(e.userId), xp = e.xp })
	end
	local me = cache.rank[tostring(player.UserId)]
	local p = profiles[player]
	return {
		top = top,
		meRank = me and me.rank or nil,
		meXp = p and p.lifeXp or 0,
		scanned = Config.RANK_SCAN,
	}
end

function Data.flushBoard()
	for player in pairs(boardDirty) do
		boardDirty[player] = nil
		local p = profiles[player]
		if p and not p._noSave then
			pcall(function()
				board:SetAsync(tostring(player.UserId), math.floor(p.lifeXp))
			end)
		end
	end
end

---------------------------------------------------------------- lifecycle
function Data.release(player)
	Data.saveRoom(player)
	Data.saveProfile(player)
	if boardDirty[player] then
		local p = profiles[player]
		if p and not p._noSave then
			pcall(function() board:SetAsync(tostring(player.UserId), math.floor(p.lifeXp)) end)
		end
	end
	boardDirty[player] = nil
	profiles[player] = nil
	rooms[player] = nil
	roomCodes[player] = nil
end

function Data.start()
	Players.PlayerRemoving:Connect(function(player)
		Data.release(player)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			Data.flushBoard()
			for _, pl in ipairs(Players:GetPlayers()) do
				task.spawn(function()
					Data.saveRoom(pl)
					Data.saveProfile(pl)
				end)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for _, pl in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				Data.release(pl)
				pending -= 1
			end)
		end
		local t0 = os.clock()
		while pending > 0 and os.clock() - t0 < 25 do task.wait(0.2) end
	end)
end

return Data
