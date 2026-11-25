-- Rooms are reserved servers. Record: {code, access, serverId, owner, created, last, public}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local Config = require(ReplicatedStorage.Shared.Config)

local Rooms = {}

local roomStore = DataStoreService:GetDataStore("Rooms_v1")
local publicMap = MemoryStoreService:GetSortedMap("PublicRooms_v1")
local presence = MemoryStoreService:GetSortedMap("Presence_v1")

local rng = Random.new()

local function genCode()
	local chars = Config.CODE_CHARS
	local out = {}
	for i = 1, Config.CODE_LEN do
		local k = rng:NextInteger(1, #chars)
		out[i] = chars:sub(k, k)
	end
	return table.concat(out)
end

function Rooms.normalize(code)
	if type(code) ~= "string" then return nil end
	code = code:upper():gsub("[^A-Z0-9]", "")
	if #code ~= Config.CODE_LEN then return nil end
	return code
end

-- returns record, or nil + reason ("notfound" | "expired" | "error")
function Rooms.get(code)
	code = Rooms.normalize(code)
	if not code then return nil, "notfound" end
	local ok, rec = pcall(function()
		return roomStore:GetAsync("room_" .. code)
	end)
	if not ok then return nil, "error" end
	if type(rec) ~= "table" or rec.deleted then return nil, "notfound" end
	if os.time() - (rec.last or 0) > Config.ROOM_TTL then
		return nil, "expired"
	end
	return rec
end

function Rooms.create(ownerId, public)
	for _ = 1, 6 do
		local code = genCode()
		local ok, existing = pcall(function()
			return roomStore:GetAsync("room_" .. code)
		end)
		if ok and existing == nil then
			local okR, access, serverId = pcall(function()
				return TeleportService:ReserveServer(game.PlaceId)
			end)
			if not okR then return nil, "error" end
			local rec = {
				code = code, access = access, serverId = serverId, owner = ownerId, created = os.time(), last = os.time(),
				public = public == true, room = public and "public" or "friends", maxPlayers = public and Config.MAX_PLAYERS or 8,
			}
			local okS = pcall(function()
				roomStore:SetAsync("room_" .. code, rec)
				roomStore:SetAsync("srv_" .. serverId, code)
			end)
			if not okS then return nil, "error" end
			return rec
		end
	end
	return nil, "error"
end

function Rooms.codeByServer(serverId)
	local ok, code = pcall(function()
		return roomStore:GetAsync("srv_" .. serverId)
	end)
	if ok and type(code) == "string" then return code end
	return nil
end

-- keeps the room alive for another TTL
function Rooms.touch(code)
	pcall(function()
		roomStore:UpdateAsync("room_" .. code, function(rec)
			if type(rec) ~= "table" then return nil end
			rec.last = os.time()
			return rec
		end)
	end)
end

function Rooms.teleport(player, rec)
	local opts = Instance.new("TeleportOptions")
	opts.ReservedServerAccessCode = rec.access
	opts:SetTeleportData({ code = rec.code })
	local ok, err = pcall(function()
		return TeleportService:TeleportAsync(game.PlaceId, { player }, opts)
	end)
	return ok, err
end

function Rooms.toLobby(player, msg)
	return pcall(function()
		local opts = Instance.new("TeleportOptions")
		if msg then opts:SetTeleportData({ msg = msg }) end
		TeleportService:TeleportAsync(game.PlaceId, { player }, opts)
	end)
end

-- room settings ("room" = access mode, maxPlayers)
function Rooms.update(code, fn)
	local ok, res = pcall(function()
		return roomStore:UpdateAsync("room_" .. code, function(rec)
			if type(rec) ~= "table" or rec.deleted then return nil end
			fn(rec)
			return rec
		end)
	end)
	return ok and res ~= nil, res
end

function Rooms.access(rec)
	if rec.room then return rec.room end
	return rec.public and "public" or "friends"
end

function Rooms.delete(code)
	return Rooms.update(code, function(rec)
		rec.deleted = true
		rec.last = 0
	end)
end

-- temporary permission for a player whose join request was accepted
function Rooms.approve(code, userId)
	pcall(function() presence:SetAsync("ap_" .. code .. "_" .. userId, true, 180) end)
end

function Rooms.isApproved(code, userId)
	local ok, v = pcall(function() return presence:GetAsync("ap_" .. code .. "_" .. userId) end)
	return ok and v == true
end

-- world servers advertise themselves so quick play can find them
function Rooms.advertise(code, count)
	pcall(function()
		publicMap:SetAsync(code, { count = count }, 90, count)
	end)
end

function Rooms.findPublic()
	local ok, items = pcall(function()
		return publicMap:GetRangeAsync(Enum.SortDirection.Descending, 50)
	end)
	if ok and items then
		for _, it in ipairs(items) do
			local count = it.value and it.value.count or 0
			if count > 0 and count < Config.MAX_PLAYERS then
				local rec = Rooms.get(it.key)
				if rec and Rooms.access(rec) == "public" and count < (rec.maxPlayers or Config.MAX_PLAYERS) then return rec end
			end
		end
	end
	return nil
end

function Rooms.setPresence(userId, code)
	pcall(function()
		presence:SetAsync(tostring(userId), code, 150)
	end)
end

function Rooms.getPresence(userId)
	local ok, code = pcall(function()
		return presence:GetAsync(tostring(userId))
	end)
	if ok and type(code) == "string" then return code end
	return nil
end

function Rooms.clearPresence(userId)
	pcall(function()
		presence:RemoveAsync(tostring(userId))
	end)
end

return Rooms
