-- Lobby server: menu actions + a small background scene (no characters are spawned here).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local Appearance = require(ReplicatedStorage.Shared.Appearance)
local Data = require(script.Parent.Data)
local Rooms = require(script.Parent.Rooms)

local Lobby = {}

local lastCall = {} -- [Player] = { [action] = clock }
local COOLDOWN = {
	create = 4, join = 3, quick = 4, renameRoom = 2, solo = 4, joinFriend = 3, friends = 5, board = 5, setLook = 1, setLang = 0.5,
	roomSettings = 1, deleteRoom = 2, buyRooms = 2,
}

local function throttled(player, action)
	local cd = COOLDOWN[action]
	if not cd then return false end
	lastCall[player] = lastCall[player] or {}
	local now = os.clock()
	if lastCall[player][action] and now - lastCall[player][action] < cd then
		return true
	end
	lastCall[player][action] = now
	return false
end

local function roomList(profile)
	local out = {}
	for _, r in ipairs(profile.rooms) do
		local left = math.max(0, Config.ROOM_TTL - (os.time() - (r.last or 0)))
		if left > 0 then
			table.insert(out, { code = r.code, coins = r.coins or 0, xp = r.xp or 0, hours = math.ceil(left / 3600) })
		end
	end
	return out
end

local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")

local function enterRoom(player, rec)
	local ok = Rooms.teleport(player, rec)
	if ok then return { ok = true } end
	return { ok = false, err = "busy" }
end

local passCache = {}
local function roomLimit(player)
	local extra = 0
	if Config.EXTRA_ROOMS_PASS ~= 0 then
		if passCache[player] == nil then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config.EXTRA_ROOMS_PASS)
			end)
			if ok then passCache[player] = owns end
		end
		if passCache[player] then extra = Config.EXTRA_ROOMS end
	end
	return Config.BASE_ROOMS + extra
end

-- drops expired / deleted rooms from the owned list, returns details
local function ownedRooms(player, profile)
	local out, keep = {}, {}
	for _, code in ipairs(profile.owned) do
		local rec, why = Rooms.get(code)
		if rec then
			table.insert(keep, code)
			local left = math.max(0, Config.ROOM_TTL - (os.time() - (rec.last or 0)))
			table.insert(out, { code = code, name = type(rec.name) == "string" and rec.name or nil, maxPlayers = rec.maxPlayers or 8, access = Rooms.access(rec), hours = math.ceil(left / 3600) })
		elseif why == "error" then
			table.insert(keep, code)
		end
	end
	profile.owned = keep
	return out
end

local pendingReq = {} -- [userId] = { code, t }

local actions = {}

function actions.info(player, profile)
	return {
		ok = true,
		lang = profile.lang,
		look = profile.look,
		lifeXp = profile.lifeXp,
		rooms = roomList(profile),
		owned = ownedRooms(player, profile),
		limit = roomLimit(player),
		hasPass = Config.EXTRA_ROOMS_PASS ~= 0,
		isStudio = game:GetService("RunService"):IsStudio(),
	}
end

function actions.board(player)
	return { ok = true, board = Data.getBoard(player) }
end

function actions.setLang(player, profile, lang)
	profile.lang = (lang == "en") and "en" or "ar"
	return { ok = true }
end

function actions.setLook(player, profile, look)
	profile.look = Appearance.sanitize(look)
	task.spawn(Data.saveProfile, player)
	return { ok = true, look = profile.look }
end

local function createOwned(player, profile, public)
	local owned = ownedRooms(player, profile)
	if #owned >= roomLimit(player) then return nil, "roomLimit" end
	local rec = Rooms.create(player.UserId, public == true)
	if not rec then return nil, "busy" end
	table.insert(profile.owned, rec.code)
	task.spawn(Data.saveProfile, player)
	return rec
end

function actions.create(player, profile)
	local rec, err = createOwned(player, profile)
	if not rec then return { ok = false, err = err } end
	return { ok = true, code = rec.code }
end

function actions.solo(player, profile)
	local owned = ownedRooms(player, profile)
	local rec
	if #owned > 0 then
		rec = Rooms.get(owned[1].code)
	else
		local err
		rec, err = createOwned(player, profile)
		if not rec then return { ok = false, err = err } end
	end
	if not rec then return { ok = false, err = "busy" } end
	return enterRoom(player, rec)
end

function actions.join(player, profile, code)
	local rec, why = Rooms.get(code)
	if not rec then
		return { ok = false, err = (why == "expired") and "expired" or (why == "error" and "busy" or "notFound") }
	end
	if rec.owner == player.UserId or rec.owner == 0 then return enterRoom(player, rec) end
	local mode = Rooms.access(rec)
	if mode == "public" then return enterRoom(player, rec) end
	local okF, isFriend = pcall(function() return player:IsFriendsWith(rec.owner) end)
	if okF and isFriend then return enterRoom(player, rec) end
	if mode == "friends" then return { ok = false, err = "friendsOnly" } end
	-- by request: ask the owner inside the room
	if Rooms.getPresence(rec.owner) ~= rec.code then return { ok = false, err = "ownerOffline" } end
	pendingReq[player.UserId] = { code = rec.code, t = os.clock() }
	pcall(function()
		MessagingService:PublishAsync("RoomReq", { code = rec.code, uid = player.UserId, name = player.DisplayName })
	end)
	task.delay(60, function()
		local p = pendingReq[player.UserId]
		if p and p.code == rec.code and player.Parent then
			pendingReq[player.UserId] = nil
			Lobby.remotes.Notify:FireClient(player, "requestTimeout")
		end
	end)
	return { ok = false, err = "requestSent" }
end

-- quick play: join someone's public room; if there is none, open one of your own (it counts towards your limit),
-- and if you already have all your rooms, go to your own room. Rooms without an owner are never made.
function actions.quick(player, profile)
	local rec = Rooms.findPublic()
	if rec then return enterRoom(player, rec) end
	local owned = ownedRooms(player, profile)
	if #owned < roomLimit(player) then
		local err
		rec, err = createOwned(player, profile, true)
		if not rec then return { ok = false, err = err } end
		return enterRoom(player, rec)
	end
	rec = Rooms.get(owned[1].code)
	if not rec then return { ok = false, err = "busy" } end
	return enterRoom(player, rec)
end

-- rename one of your rooms (filtered like any text other players can see)
local TextService = game:GetService("TextService")
function actions.renameRoom(player, profile, code, name)
	if type(code) ~= "string" or type(name) ~= "string" then return { ok = false, err = "notFound" } end
	local owns = false
	for _, c in ipairs(profile.owned) do if c == code then owns = true end end
	if not owns then return { ok = false, err = "notFound" } end
	name = name:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	name = utf8.len(name) and name or ""
	if (utf8.len(name) or 0) > 24 then name = name:sub(1, utf8.offset(name, 25) - 1) end
	local final = nil
	if #name > 0 then
		local ok, res = pcall(function()
			return TextService:FilterStringAsync(name, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		if not ok or not res or res:find("#") then return { ok = false, err = "nameBad" } end
		final = res
	end
	local ok = Rooms.update(code, function(rec)
		if rec.owner ~= player.UserId then return end
		rec.name = final
	end)
	return { ok = ok == true, owned = ownedRooms(player, profile) }
end

function actions.friends(player)
	local out = {}
	local ok, friends = pcall(function() return player:GetFriendsOnline(30) end)
	if ok and friends then
		for _, f in ipairs(friends) do
			local code = Rooms.getPresence(f.VisitorId)
			if code then
				table.insert(out, { userId = f.VisitorId, name = f.UserName or f.DisplayName or "?", code = code })
			end
		end
	end
	return { ok = true, friends = out }
end

function actions.joinFriend(player, profile, userId)
	userId = tonumber(userId)
	if not userId then return { ok = false, err = "notFound" } end
	local code = Rooms.getPresence(userId)
	if not code then return { ok = false, err = "notFound" } end
	return actions.join(player, profile, code)
end

local function ownsCode(profile, code)
	for _, c in ipairs(profile.owned) do if c == code then return true end end
	return false
end

function actions.roomSettings(player, profile, code, settings)
	if type(code) ~= "string" or not ownsCode(profile, code) or type(settings) ~= "table" then return { ok = false, err = "notFound" } end
	local mode = settings.access
	local valid = false
	for _, a in ipairs(Config.ROOM_ACCESS) do if a == mode then valid = true end end
	local maxP = math.clamp(math.floor(tonumber(settings.maxPlayers) or 8), 1, Config.MAX_PLAYERS)
	local ok = Rooms.update(code, function(rec)
		if rec.owner ~= player.UserId then return end
		rec.maxPlayers = maxP
		if valid then
			rec.room = mode
			rec.public = mode == "public"
		end
	end)
	return { ok = ok == true, owned = ownedRooms(player, profile) }
end

function actions.deleteRoom(player, profile, code)
	if type(code) ~= "string" or not ownsCode(profile, code) then return { ok = false, err = "notFound" } end
	Rooms.delete(code)
	for i, c in ipairs(profile.owned) do
		if c == code then table.remove(profile.owned, i) break end
	end
	for i, r in ipairs(profile.rooms) do
		if r.code == code then table.remove(profile.rooms, i) break end
	end
	task.spawn(Data.saveProfile, player)
	return { ok = true, owned = ownedRooms(player, profile), rooms = roomList(profile) }
end

function actions.buyRooms(player)
	if Config.EXTRA_ROOMS_PASS == 0 then return { ok = false, err = "passMissing" } end
	pcall(function() MarketplaceService:PromptGamePassPurchase(player, Config.EXTRA_ROOMS_PASS) end)
	return { ok = true }
end

local function scene()
	Lighting.ClockTime = 17.4
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(96, 84, 78)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 112, 104)
	Lighting.EnvironmentDiffuseScale = 0.6
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.35
	atm.Color = Color3.fromRGB(255, 196, 150)
	atm.Decay = Color3.fromRGB(120, 90, 110)
	atm.Glare = 0.4
	atm.Haze = 1.6
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.TintColor = Color3.fromRGB(255, 240, 225)
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local f = Instance.new("Folder")
	f.Name = "LobbyScene"
	f.Parent = workspace
	local o = CFrame.new(0, 500, 0) -- far above the world map
	local function part(name, size, cf, color, mat, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = o * cf
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then p.Shape = shape end
		p.Parent = f
		return p
	end
	local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
	local UPR = CFrame.Angles(0, 0, math.rad(90))
	-- ground disc (cylinder axis X turned upright)
	part("Ground", Vector3.new(4, 220, 220), CFrame.new(0, -2, 0) * UPR, Color3.fromRGB(78, 116, 62), Enum.Material.Grass, CYL)
	part("Path", Vector3.new(4.1, 22, 22), CFrame.new(0, -1.95, 0) * UPR, Color3.fromRGB(120, 96, 70), Enum.Material.Ground, CYL)
	-- pines in a ring, leaving the camera side (-Z) open
	local rng = Random.new(7)
	for i = 1, 26 do
		local a = i / 26 * math.pi * 2
		if math.cos(a - math.pi * 1.5) < 0.55 then
			local r = rng:NextNumber(34, 70)
			local x, z = math.cos(a) * r, math.sin(a) * r
			local h = rng:NextNumber(12, 20)
			part("Trunk", Vector3.new(h, 1.8, 1.8), CFrame.new(x, h / 2, z) * UPR, Color3.fromRGB(92, 62, 42), Enum.Material.Wood, CYL)
			for k = 0, 2 do
				local s = (3 - k) * 3.4
				part("Needles", Vector3.new(s, s * 0.75, s), CFrame.new(x, h * 0.55 + k * 3.6, z), Color3.fromRGB(36 + k * 6, 88 + k * 8, 56), Enum.Material.Grass, BALL)
			end
		end
	end
	-- tents
	local function tent(cf, color)
		part("Tent", Vector3.new(7, 5, 8), cf * CFrame.new(-1.75, 2.5, 0) * CFrame.Angles(0, 0, math.rad(-35)), color, Enum.Material.Fabric)
		part("Tent", Vector3.new(7, 5, 8), cf * CFrame.new(1.75, 2.5, 0) * CFrame.Angles(0, 0, math.rad(35)), color:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Fabric)
	end
	tent(CFrame.new(-16, 0, 10) * CFrame.Angles(0, math.rad(30), 0), Color3.fromRGB(196, 120, 70))
	tent(CFrame.new(18, 0, 14) * CFrame.Angles(0, math.rad(-25), 0), Color3.fromRGB(90, 130, 160))
	-- logs around the fire
	for i, a in ipairs({ 0.4, 2.3, 4.0 }) do
		part("Log", Vector3.new(6, 1.6, 1.6), CFrame.new(math.cos(a) * 7, 0.8, math.sin(a) * 7) * CFrame.Angles(0, -a + math.pi / 2, 0), Color3.fromRGB(110, 76, 50), Enum.Material.Wood, CYL)
	end
	-- campfire
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		part("Stone", Vector3.new(1.2, 0.8, 1.2), CFrame.new(math.cos(a) * 2.2, 0.4, math.sin(a) * 2.2), Color3.fromRGB(120, 120, 126), Enum.Material.Slate, BALL)
	end
	local fire = part("Campfire", Vector3.new(2.6, 0.6, 2.6), CFrame.new(0, 0.3, 0), Color3.fromRGB(60, 40, 30), Enum.Material.Wood)
	game:GetService("CollectionService"):AddTag(fire, "Heat")
	local fx = Instance.new("Fire")
	fx.Size = 7
	fx.Heat = 9
	fx.Parent = fire
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 2.5
	light.Color = Color3.fromRGB(255, 160, 80)
	light.Parent = fire
	-- lanterns
	for _, pos in ipairs({ Vector3.new(-10, 0, -4), Vector3.new(11, 0, -2) }) do
		part("Post", Vector3.new(5, 0.4, 0.4), CFrame.new(pos + Vector3.new(0, 2.5, 0)) * UPR, Color3.fromRGB(80, 60, 44), Enum.Material.Wood, CYL)
		local lamp = part("Lamp", Vector3.new(0.9, 1.1, 0.9), CFrame.new(pos + Vector3.new(0, 5.3, 0)), Color3.fromRGB(255, 210, 130), Enum.Material.Neon)
		local l = Instance.new("PointLight")
		l.Range = 14
		l.Brightness = 1.4
		l.Color = Color3.fromRGB(255, 190, 110)
		l.Parent = lamp
	end
	local function marker(name, cf)
		local p = part(name, Vector3.new(1, 1, 1), cf, Color3.new(), nil)
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		return p
	end
	marker("Stand", CFrame.new(5.5, 0, -5) * CFrame.Angles(0, math.rad(200), 0))
	marker("CamPos", CFrame.new(-1, 6.5, -24))
	local look = marker("CamLook", CFrame.new(1.5, 3.2, 0))
	return look
end

function Lobby.start(remotes)
	Lobby.remotes = remotes
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if bought and passId == Config.EXTRA_ROOMS_PASS then
			passCache[player] = true
			remotes.Notify:FireClient(player, "bought")
		end
	end)
	-- answers to join requests come back from the room servers
	pcall(function()
		MessagingService:SubscribeAsync("RoomResp", function(msg)
			local d = msg.Data
			if type(d) ~= "table" then return end
			local player = Players:GetPlayerByUserId(d.uid)
			local p = player and pendingReq[d.uid]
			if not p or p.code ~= d.code then return end
			pendingReq[d.uid] = nil
			if d.ok then
				local rec = Rooms.get(d.code)
				if rec then Rooms.teleport(player, rec) end
			else
				remotes.Notify:FireClient(player, d.reason or "requestDeclined")
			end
		end)
	end)
	local focus = scene()
	local function setup(player)
		pcall(function() player.ReplicationFocus = focus end)
		Data.loadProfile(player)
	end
	Players.PlayerAdded:Connect(setup)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(setup, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
		passCache[player] = nil
		pendingReq[player.UserId] = nil
	end)
	remotes.Lobby.OnServerInvoke = function(player, action, a, b)
		if type(action) ~= "string" or not actions[action] then return { ok = false } end
		if throttled(player, action) then return { ok = false, err = "wait" } end
		local profile = Data.waitProfile(player, 20)
		if not profile then return { ok = false, err = "busy" } end
		local ok, res = pcall(actions[action], player, profile, a, b)
		if not ok then
			warn("Lobby action failed:", action, res)
			return { ok = false, err = "busy" }
		end
		return res
	end
end

return Lobby
