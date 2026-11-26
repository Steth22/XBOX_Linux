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
	return { coins = Config.START_COINS, xp = 0, sp = 0, inv = inv, hunger = 100, thirst = 100, skills = skills, stash = Inventory.newStash(), dex = { seen = {}, kills = {}, medals = {}, neck = false }, house = { lvl = 0, chests = {} }, t = os.time() }
end

local roomRecs = DataStoreService:GetDataStore("Rooms_v1")
-- the XP a player holds in every room that is still open and never had admin switched on
function Data.countXp(userId, p)
	local codes, seen = {}, {}
	for _, r in ipairs(p.rooms or {}) do if not seen[r.code] then seen[r.code] = true table.insert(codes, r.code) end end
	for _, c in ipairs(p.owned or {}) do if not seen[c] then seen[c] = true table.insert(codes, c) end end
	local total = 0
	for _, code in ipairs(codes) do
		local okR, rec = pcall(function() return roomRecs:GetAsync("room_" .. code) end)
		if okR and type(rec) == "table" and not rec.deleted and not rec.admin and os.time() - (rec.last or 0) <= Config.ROOM_TTL then
			local okP, rd = pcall(function() return roomStore:GetAsync("r_" .. code .. "_" .. userId) end)
			if okP and type(rd) == "table" then total += math.max(0, math.floor(tonumber(rd.xp) or 0)) end
		end
	end
	return total
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
		-- achievements: counters and the ones already earned
		if type(res.ach) == "table" then
			local a = { stats = {}, done = {} }
			for k, v in pairs(type(res.ach.stats) == "table" and res.ach.stats or {}) do if type(k) == "string" and tonumber(v) then a.stats[k] = tonumber(v) end end
			for k, v in pairs(type(res.ach.done) == "table" and res.ach.done or {}) do if type(k) == "string" and v == true then a.done[k] = true end end
			p.ach = a
		end
		p._recount = res.season ~= Config.XP_SEASON
		if type(res.owned) == "table" then
			for _, c in ipairs(res.owned) do
				if type(c) == "string" and #p.owned < 5 then table.insert(p.owned, c) end
			end
		end
		if type(res.rooms) == "table" then
			for _, r in ipairs(res.rooms) do
				if type(r) == "table" and type(r.code) == "string" then
					table.insert(p.rooms, { code = r.code, last = tonumber(r.last) or 0, coins = tonumber(r.coins) or 0, xp = tonumber(r.xp) or 0, pct = tonumber(r.pct) })
				end
			end
		end
	elseif not ok then
		p._noSave = true -- never overwrite real data after a failed load
		warn("Profile load failed for", player.UserId, res)
	end
	-- one-time recount: ranking XP = the XP you hold in every open room that never had admin on
	if p._recount then
		p._recount = nil
		p.lifeXp = Data.countXp(player.UserId, p)
		p._migrated = true
	end
	if player.Parent then
		profiles[player] = p
		player:SetAttribute("Lang", p.lang) -- the loading screen speaks the player's language
		if p.lifeXp > 0 or p._migrated then boardDirty[player] = true end
	end
	-- write the repaired value straight away so a second server can't add it again
	if p._migrated and player.Parent then
		p._migrated = nil
		Data.saveProfile(player)
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
	local copy = { lang = p.lang, look = p.look, lifeXp = p.lifeXp, season = Config.XP_SEASON, rooms = p.rooms, owned = p.owned, ach = p.ach }
	try(function()
		profileStore:SetAsync("p_" .. player.UserId, copy)
	end)
end

-- how far the player has got in a room, 0..100: creatures discovered, necklaces, map explored
function Data.progress(r)
	local Best = require(game:GetService("ReplicatedStorage").Shared.Bestiary)
	local seen, medals = 0, 0
	for _ in pairs(r.dex and r.dex.seen or {}) do seen += 1 end
	for _ in pairs(r.dex and r.dex.medals or {}) do medals += 1 end
	local function share(ex)
		if type(ex) ~= "string" or #ex == 0 then return 0 end
		local _, n = ex:gsub("1", "")
		return n / #ex
	end
	-- the surface counts for most of the map part; the caves for the rest
	local mapPart = math.min(1, share(r.explored) * 0.75 + share(r.explored2) * 0.25)
	local v = 0.4 * seen / math.max(1, Best.total()) + 0.3 * medals / #Best.regions + 0.3 * mapPart
	return math.clamp(math.floor(v * 100 + 0.5), 0, 100)
end

function Data.touchRoomList(player, code, coins, xp, pct)
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
	if pct then found.pct = pct end
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
		-- the map grid got finer (48 -> 96): each old cell becomes 2 x 2 new ones
		local function upscale(ex)
			if type(ex) ~= "string" or ex:find("[^01]") then return nil end
			local N = Config.MAP_CELLS
			if #ex == N * N then return ex end
			if #ex ~= (N // 2) * (N // 2) then return nil end
			local rows = table.create(N)
			for z = 0, N - 1 do
				local row = table.create(N)
				for x = 0, N - 1 do
					local k = (z // 2) * (N // 2) + (x // 2) + 1
					row[x + 1] = ex:sub(k, k)
				end
				rows[z + 1] = table.concat(row)
			end
			return table.concat(rows)
		end
		res.explored, res.explored2 = upscale(res.explored), upscale(res.explored2)
		if type(res.explored) == "string" and #res.explored == Config.MAP_CELLS * Config.MAP_CELLS and not res.explored:find("[^01]") then
			r.explored = res.explored
		end
		if type(res.explored2) == "string" and #res.explored2 == Config.MAP_CELLS * Config.MAP_CELLS and not res.explored2:find("[^01]") then
			r.explored2 = res.explored2
		end
		if type(res.spawn) == "table" and tonumber(res.spawn[1]) and tonumber(res.spawn[2]) and tonumber(res.spawn[3]) then
			r.spawn = { tonumber(res.spawn[1]), tonumber(res.spawn[2]), tonumber(res.spawn[3]), village = res.spawn.village == true, house = res.spawn.house == true or nil }
			-- a bed the player placed: where it stood, so it can be put back
			local b = res.spawn.bed
			if type(b) == "table" and tonumber(b[1]) and tonumber(b[2]) and tonumber(b[3]) then r.spawn.bed = { tonumber(b[1]), tonumber(b[2]), tonumber(b[3]), tonumber(b[4]) or 0 } end
		end
		-- items left where the player died (kept if the server closed before they were picked up)
		if type(res.lostBag) == "table" and type(res.lostBag.items) == "table" and type(res.lostBag.pos) == "table" then
			local items = {}
			for _, it in ipairs(res.lostBag.items) do
				if type(it) == "table" and type(it.id) == "string" and tonumber(it.n) then table.insert(items, { id = it.id, n = math.floor(tonumber(it.n)), d = tonumber(it.d) }) end
			end
			local expires = tonumber(res.lostBag.expires) or 0
			if #items > 0 and os.time() < expires then r.lostBag = { pos = { tonumber(res.lostBag.pos[1]) or 0, tonumber(res.lostBag.pos[2]) or 0, tonumber(res.lostBag.pos[3]) or 0 }, items = items, expires = expires } end
		end
		-- the player's house: design, level, plot and what is in each chest
		if type(res.house) == "table" then
			local House = require(game:GetService("ReplicatedStorage").Shared.House)
			local Items = require(game:GetService("ReplicatedStorage").Shared.Items)
			local hs = { lvl = math.clamp(math.floor(tonumber(res.house.lvl) or 0), 0, House.MAX), chests = {} }
			if type(res.house.design) == "string" and House.BY[res.house.design] then hs.design = res.house.design end
			if not hs.design then hs.lvl = 0 end
			hs.plot = tonumber(res.house.plot)
			if type(res.house.paid) == "table" then hs.paid = { wood = math.max(0, math.floor(tonumber(res.house.paid.wood) or 0)), stone = math.max(0, math.floor(tonumber(res.house.paid.stone) or 0)) } end
			if type(res.house.chests) == "table" then
				for n = 1, 6 do
					local src = res.house.chests[n] or res.house.chests[tostring(n)]
					local slots = {}
					for i = 1, House.CHEST_SLOTS do
						local v = type(src) == "table" and (src[i] or src[tostring(i)])
						if type(v) == "table" and Items.get(v.id) and tonumber(v.n) and v.n >= 1 then
							slots[i] = { id = v.id, n = math.min(math.floor(v.n), Items.stack(v.id)), d = tonumber(v.d) }
						else
							slots[i] = false
						end
					end
					hs.chests[n] = slots
				end
			end
			r.house = hs
		end
		if type(res.powers) == "table" then
			local pw = { off = {} }
			for _, k in ipairs({ "fire", "ice", "blast" }) do pw[k] = math.clamp(math.floor(tonumber(res.powers[k]) or 0), 0, 5) end
			if type(res.powers.off) == "table" then pw.off.fire = res.powers.off.fire == true or nil pw.off.ice = res.powers.off.ice == true or nil end
			r.powers = pw
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
		Data.touchRoomList(player, code, r.coins, r.xp, Data.progress(r))
	end
	return r
end

function Data.room(player)
	return rooms[player]
end

function Data.roomCode(player)
	return roomCodes[player]
end

Data.beforeSave = nil -- set by World: copies live things (the death bag) into the room before saving
function Data.saveRoom(player)
	if Data.beforeSave and rooms[player] then pcall(Data.beforeSave, player, rooms[player]) end
	local r, code = rooms[player], roomCodes[player]
	if not r or not code then return end
	Data.touchRoomList(player, code, r.coins, r.xp, Data.progress(r))
	if r._noSave then return end
	local copy = { coins = r.coins, xp = r.xp, sp = r.sp, inv = r.inv, hunger = r.hunger, thirst = r.thirst, skills = r.skills, stash = r.stash, dex = r.dex, pos = r.pos, explored = r.explored, explored2 = r.explored2, spawn = r.spawn, powers = r.powers, lostBag = r.lostBag, house = r.house, t = os.time() }
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
	-- XP earned in a room with admin switched on doesn't count for the ranking
	if not Data.unranked then
		p.lifeXp += n
		boardDirty[player] = true
	end
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
