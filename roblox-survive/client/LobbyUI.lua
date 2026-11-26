-- Lobby screens: home (character by the campfire), play, ranking, my rooms, look, settings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))
local Format = require(Shared:WaitForChild("Format"))
local Appearance = require(Shared:WaitForChild("Appearance"))
local UI = require(script.Parent:WaitForChild("UI"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local c = UI.c

local M = {}

local ERR = { expired = "expired", notFound = "notFound", full = "full", busy = "busy", wait = "wait",
	roomLimit = "roomLimit", nameBad = "nameBad", friendsOnly = "friendsOnly", fofOnly = "fofOnly", ownerOffline = "ownerOffline", requestSent = "requestSent", passMissing = "passMissing", owned = "owned" }

local function newRig()
	local ok, m = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not m then return nil end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
	return m
end

function M.start(gui, remotes)
	local root = UI.root(gui)
	local lang = "ar"
	local info = { lifeXp = 0, rooms = {}, owned = {}, limit = 1, look = Appearance.default() }
	local busy = false
	local closeModal = nil
	local render, screen

	local function T(k) return Locale.t(lang, k) end
	local function call(action, a, b)
		local ok, res = pcall(function() return remotes.Lobby:InvokeServer(action, a, b) end)
		if ok and type(res) == "table" then return res end
		return { ok = false, err = "busy" }
	end
	local function toast(text) UI.toast(root, text) end
	-- AnchorPoint.X and UDim2 for the start/end edge depending on language
	local function edge(atStart, px, y)
		local right = (lang == "ar") == atStart
		return right and 1 or 0, UDim2.new(right and 1 or 0, right and -px or px, 0, y or 0)
	end
	local function farAlign() return lang == "ar" and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right end

	---------------------------------------------------------------- scene: camera + our character by the fire
	local scene, stand, camPos, camLook, sceneRig
	local function placeRig()
		if not stand then return end
		if not sceneRig then
			sceneRig = newRig()
			if not sceneRig then return end
			local hrp = sceneRig:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.Anchored = true end
			sceneRig.Parent = workspace
		end
		local hum = sceneRig:FindFirstChildOfClass("Humanoid")
		local height = hum and (hum.HipHeight + 3) or 5
		-- stand on the side opposite to the menu, facing the camera
		local sp = stand.Position
		local x = (lang == "ar") and math.abs(sp.X) or -math.abs(sp.X)
		local pos = Vector3.new(x, sp.Y + height / 2 + 0.2, sp.Z)
		local camFlat = camPos and Vector3.new(camPos.Position.X, pos.Y, camPos.Position.Z) or (pos + Vector3.new(0, 0, -10))
		sceneRig:PivotTo(CFrame.lookAt(pos, camFlat))
		Appearance.apply(sceneRig, info.look)
	end
	task.spawn(function()
		scene = workspace:WaitForChild("LobbyScene", 30)
		if not scene then return end
		stand = scene:WaitForChild("Stand", 10)
		camPos = scene:WaitForChild("CamPos", 10)
		camLook = scene:WaitForChild("CamLook", 10)
		placeRig()
	end)
	RunService:BindToRenderStep("LobbyCam", Enum.RenderPriority.Camera.Value + 1, function()
		local cam = workspace.CurrentCamera
		if not cam or not camPos or not camLook then return end
		cam.CameraType = Enum.CameraType.Scriptable
		-- a slow cinematic move: a gentle arc around the fire, drifting in and out, breathing up and down
		local t = os.clock()
		local look = camLook.Position
		local base = camPos.Position - look
		local arc = math.sin(t * 0.07) * math.rad(14)
		local push = 1 + math.sin(t * 0.11) * 0.12
		local off = CFrame.Angles(0, arc, 0):VectorToWorldSpace(base) * push
		local bob = Vector3.new(0, math.sin(t * 0.21) * 0.5 + math.sin(t * 0.09) * 0.8, 0)
		cam.FieldOfView = 52 + math.sin(t * 0.05) * 3
		cam.CFrame = CFrame.lookAt(look + off + bob, look + Vector3.new(math.sin(t * 0.13) * 0.6, 0, 0))
	end)

	---------------------------------------------------------------- preview (look screen)
	local function makePreview(parent, size, pos)
		local vp = UI.new("ViewportFrame", {
			Size = size, Position = pos, BackgroundColor3 = c.card, BackgroundTransparency = 0.3, Ambient = Color3.fromRGB(150, 150, 160),
			LightColor = Color3.fromRGB(255, 240, 220), LightDirection = Vector3.new(-1, -1, -1), ZIndex = 53, Parent = parent,
		})
		UI.corner(vp, 14)
		local world = UI.new("WorldModel", { Parent = vp })
		local cam = UI.new("Camera", { FieldOfView = 32, Parent = vp })
		vp.CurrentCamera = cam
		local model = newRig()
		local base = CFrame.new(0, 0, 0)
		if model then
			model.Parent = world
			model:PivotTo(base)
			Appearance.apply(model, info.look)
			local cf, sz = model:GetBoundingBox()
			local dist = (sz.Y * 0.62) / math.tan(math.rad(16))
			cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 0.3, -dist), cf.Position)
		end
		local angle = math.pi
		local conn = RunService.RenderStepped:Connect(function(dt)
			if model and model.Parent then
				angle += dt * 0.8
				model:PivotTo(base * CFrame.Angles(0, angle, 0))
			end
		end)
		vp.Destroying:Connect(function() conn:Disconnect() end)
		return {
			set = function(look)
				if model then
					model:PivotTo(base * CFrame.Angles(0, angle, 0))
					Appearance.apply(model, look)
				end
			end,
		}
	end

	---------------------------------------------------------------- travel
	local function travel(action, a)
		if busy then return end
		busy = true
		-- the loading screen shows during the teleport (and the room's loader takes over on arrival)
		pcall(function()
			local Screen = require(game:GetService("ReplicatedFirst"):WaitForChild("Loading"):WaitForChild("Screen"))
			local t = Screen.build(lang)
			t.set(0.05, "travel")
			game:GetService("TeleportService"):SetTeleportGui(t.gui)
		end)
		local res = call(action, a)
		if res.ok then
			local veil = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 200, Active = true, Parent = root })
			UI.tween(veil, 0.4, { BackgroundTransparency = 0.25 })
			UI.text({ Text = T("teleporting"), Size = UDim2.fromScale(1, 1), TextSize = 34, ZIndex = 201, Parent = veil })
			task.delay(20, function()
				if veil.Parent then veil:Destroy() end
				busy = false
			end)
		else
			busy = false
			toast(T(ERR[res.err] or "busy"))
		end
	end

	---------------------------------------------------------------- modals
	local function openModal(title, size)
		if closeModal then closeModal() end
		local content, close = UI.modal(root, title, lang, size, function() closeModal = nil end)
		closeModal = close
		return content, close
	end

	local function bigButton(parent, icon, text, color, order, cb)
		local dark = (color == c.accent or color == c.gold)
		local fg = dark and c.bg or c.text
		local b = UI.button({ BackgroundColor3 = color, Text = "", LayoutOrder = order, ZIndex = 53, Parent = parent }, cb)
		Icons.draw(icon, b, 46, fg, UDim2.new(0.5, 0, 0.36, 0), Vector2.new(0.5, 0.5))
		UI.text({ Text = text, Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.62), TextSize = 22, ZIndex = 54, TextColor3 = fg, Parent = b })
		return b
	end

	local playPage

	local function pageMenu(content)
		local grid = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
		UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0.5, -8), CellPadding = UDim2.fromOffset(16, 16), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
		bigButton(grid, "solo", T("solo"), c.accent, 1, function() travel("solo") end)
		bigButton(grid, "quick", T("quick"), c.gold, 2, function() travel("quick") end)
		bigButton(grid, "friend", T("friend"), c.blue, 3, function() playPage("friends") end)
		bigButton(grid, "key", T("roomCode"), c.card2, 4, function() playPage("room") end)
	end

	local function joinRow(list, title, sub, onJoin)
		local row = UI.frame({ Size = UDim2.new(1, -8, 0, sub and 76 or 56), BackgroundColor3 = c.card, ZIndex = 53, Parent = list })
		UI.corner(row, 12)
		local ax, px = edge(true, 16, sub and 8 or 0)
		UI.text({ Text = title, Size = UDim2.new(0.52, 0, 0, sub and 34 or 56), AnchorPoint = Vector2.new(ax, 0), Position = px, TextXAlignment = UI.align(lang), TextSize = sub and 26 or 20, TextColor3 = sub and c.gold or c.text, ZIndex = 54, Parent = row })
		if sub then
			local _, p2 = edge(true, 16, 44)
			UI.text({ Text = sub, Size = UDim2.new(0.52, 0, 0, 28), AnchorPoint = Vector2.new(ax, 0), Position = p2, TextXAlignment = UI.align(lang), TextYAlignment = Enum.TextYAlignment.Top, TextSize = 13, TextColor3 = c.dim, ZIndex = 54, Parent = row })
		end
		local bx, pbx = edge(false, 12)
		UI.button({ Text = T("join"), Size = UDim2.fromOffset(112, 44), AnchorPoint = Vector2.new(bx, 0.5), Position = UDim2.new(pbx.X.Scale, pbx.X.Offset, 0.5, 0), ZIndex = 54, Parent = row }, onJoin)
		return row
	end

	-- how far you have got in a room: a ring-like badge with the percent
	local function progressBadge(row, pct, fromEdge)
		if not pct then return end
		local bx = lang == "ar" and 0 or 1
		local b = UI.frame({ Size = UDim2.fromOffset(64, 44), AnchorPoint = Vector2.new(bx, 0.5), Position = UDim2.new(bx, lang == "ar" and fromEdge or -fromEdge, 0.5, 0), BackgroundColor3 = c.panel, ZIndex = 55, Parent = row })
		UI.corner(b, 12)
		local col = pct >= 100 and c.gold or (pct >= 50 and c.accent or c.blue)
		UI.stroke(b, col, 2)
		UI.text({ Text = pct .. "%", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 3), TextSize = 18, TextColor3 = col, ZIndex = 56, Parent = b })
		local bar = UI.frame({ Size = UDim2.new(1, -14, 0, 5), Position = UDim2.new(0, 7, 1, -11), BackgroundColor3 = c.bg, ZIndex = 56, Parent = b })
		UI.corner(bar, 3)
		local fill = UI.frame({ Size = UDim2.fromScale(math.clamp(pct / 100, 0, 1), 1), BackgroundColor3 = col, ZIndex = 57, Parent = bar })
		UI.corner(fill, 3)
	end

	local function pageFriends(content)
		local status = UI.text({ Text = "...", Size = UDim2.new(1, 0, 0, 40), TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local list = UI.scroll({ Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 46), ZIndex = 53, Parent = content })
		UI.list(list, 8)
		task.spawn(function()
			local res = call("friends")
			if not content.Parent then return end
			if not res.ok or not res.friends or #res.friends == 0 then
				status.Text = T("noFriends")
				return
			end
			status.Text = ""
			for i, f in ipairs(res.friends) do
				local row = joinRow(list, f.name, nil, function() travel("joinFriend", f.userId) end)
				UI.enter(row, i * 0.05, 14)
			end
		end)
	end

	local function pageCode(content, code)
		UI.text({ Text = T("code"), Size = UDim2.new(1, 0, 0, 36), TextSize = 22, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local big = UI.text({ Text = code, Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromOffset(0, 40), TextSize = 66, TextColor3 = c.gold, ZIndex = 53, Parent = content })
		UI.enter(big, 0, 10)
		UI.button({ Text = T("enter"), Size = UDim2.fromOffset(260, 60), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160), ZIndex = 53, Parent = content }, function()
			travel("join", code)
		end)
	end

	local function pageRoom(content)
		local create = UI.button({ Text = T("create"), Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = c.accent, ZIndex = 53, Parent = content }, function()
			if busy then return end
			busy = true
			local res = call("create")
			busy = false
			if res.ok and res.code then
				local r2 = call("info")
				if r2.ok then info.owned = r2.owned or info.owned end
				playPage("code", res.code)
			else
				toast(T(ERR[res.err] or "busy"))
			end
		end)
		Icons.draw("plus", create, 26, c.bg, UDim2.new(lang == "ar" and 1 or 0, lang == "ar" and -46 or 20, 0.5, 0), Vector2.new(0, 0.5))
		local box = UI.new("TextBox", {
			Size = UDim2.new(1, -150, 0, 60), Position = UDim2.fromOffset(lang == "ar" and 150 or 0, 100), BackgroundColor3 = c.card, TextColor3 = c.text,
			PlaceholderText = T("codeHint"), PlaceholderColor3 = c.dim, Font = UI.font, TextSize = 30, ClearTextOnFocus = false,
			Text = "", ZIndex = 53, Parent = content,
		})
		UI.corner(box, 12)
		UI.stroke(box, c.card2, 2)
		UI.button({ Text = T("join"), Size = UDim2.new(0, 136, 0, 60), Position = UDim2.new(lang == "ar" and 0 or 1, lang == "ar" and 0 or -136, 0, 100), ZIndex = 53, Parent = content }, function()
			local code = box.Text:upper():gsub("[^A-Z0-9]", "")
			if #code ~= 6 then toast(T("notFound")) return end
			travel("join", code)
		end)
	end

	function playPage(page, arg)
		local content = openModal(T("play"), UDim2.fromOffset(640, 400))
		if page == "friends" then pageFriends(content)
		elseif page == "room" then pageRoom(content)
		elseif page == "code" then pageCode(content, arg)
		else pageMenu(content) end
	end

	local function boardModal()
		local content = openModal(T("ranking"), UDim2.fromOffset(560, 520))
		local status = UI.text({ Text = "...", Size = UDim2.new(1, 0, 0, 40), TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local list = UI.scroll({ Size = UDim2.new(1, 0, 1, -72), ZIndex = 53, Parent = content })
		UI.list(list, 6)
		local me = UI.frame({ Size = UDim2.new(1, 0, 0, 58), Position = UDim2.new(0, 0, 1, -58), BackgroundColor3 = c.card2, ZIndex = 53, Parent = content })
		UI.corner(me, 12)
		task.spawn(function()
			local res = call("board")
			if not content.Parent then return end
			if not res.ok then status.Text = T(ERR[res.err] or "busy") return end
			status.Text = ""
			local b = res.board
			local medal = { c.gold, Color3.fromRGB(200, 205, 212), Color3.fromRGB(205, 140, 80) }
			for i, e in ipairs(b.top) do
				local row = UI.frame({ Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = e.rank <= 3 and c.card2 or c.card, ZIndex = 53, Parent = list })
				UI.corner(row, 10)
				local ax, px = edge(true, 10)
				local badge = UI.frame({ Size = UDim2.fromOffset(32, 32), AnchorPoint = Vector2.new(ax, 0.5), Position = UDim2.new(px.X.Scale, px.X.Offset, 0.5, 0), BackgroundColor3 = medal[e.rank] or c.panel, ZIndex = 54, Parent = row })
				UI.corner(badge, 16)
				UI.text({ Text = tostring(e.rank), Size = UDim2.fromScale(1, 1), TextSize = 17, TextColor3 = e.rank <= 3 and c.bg or c.text, ZIndex = 55, Parent = badge })
				local _, npx = edge(true, 54)
				UI.text({ Text = e.name, Size = UDim2.new(0.5, 0, 1, 0), AnchorPoint = Vector2.new(ax, 0), Position = npx, TextXAlignment = UI.align(lang), TextSize = 20, ZIndex = 54, Parent = row })
				local ex, epx = edge(false, 14)
				UI.text({ Text = Format.number(e.xp) .. " XP", Size = UDim2.new(0.3, 0, 1, 0), AnchorPoint = Vector2.new(ex, 0), Position = epx, TextXAlignment = farAlign(), TextColor3 = c.accent, TextSize = 20, ZIndex = 54, Parent = row })
				UI.enter(row, i * 0.04, 12)
			end
			local ax, px = edge(true, 16)
			UI.text({ Text = T("rank") .. "   " .. Format.rank(b.meRank, b.scanned), Size = UDim2.new(0.6, 0, 1, 0), AnchorPoint = Vector2.new(ax, 0), Position = px, TextXAlignment = UI.align(lang), TextSize = 22, TextColor3 = c.gold, ZIndex = 54, Parent = me })
			local ex, epx = edge(false, 16)
			UI.text({ Text = Format.number(b.meXp) .. " XP", Size = UDim2.new(0.35, 0, 1, 0), AnchorPoint = Vector2.new(ex, 0), Position = epx, TextXAlignment = farAlign(), TextSize = 22, ZIndex = 54, Parent = me })
		end)
	end

	local roomsModal
	local function settingsModal(room)
		local content = openModal(T("roomSettings") .. "  " .. room.code, UDim2.fromOffset(560, 590))
		local sel = { maxPlayers = room.maxPlayers or 8, access = room.access or "friends", pvp = room.pvp == true }
		-- the room's name
		UI.text({ Text = T("roomName"), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = UI.align(lang), TextSize = 20, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local nameBox = UI.new("TextBox", {
			Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 34), BackgroundColor3 = c.card, TextColor3 = c.text,
			PlaceholderText = room.defaultName or "", PlaceholderColor3 = c.dim, Font = UI.font, TextSize = 22, ClearTextOnFocus = false,
			Text = room.name or "", TextXAlignment = UI.align(lang), ZIndex = 54, Parent = content,
		})
		UI.corner(nameBox, 10)
		UI.stroke(nameBox, c.card2, 2)
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = nameBox })
		local holder = UI.frame({ Size = UDim2.new(1, 0, 1, -96), Position = UDim2.fromOffset(0, 96), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		content = holder
		UI.text({ Text = T("maxPlayers"), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = UI.align(lang), TextSize = 20, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local row = UI.frame({ Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.list(row, 12, Enum.FillDirection.Horizontal)
		local numLabel
		local function step(d)
			sel.maxPlayers = math.clamp(sel.maxPlayers + d, 1, 16)
			numLabel.Text = tostring(sel.maxPlayers)
		end
		local minus = UI.button({ Text = "", Size = UDim2.fromOffset(56, 56), BackgroundColor3 = c.card, ZIndex = 54, Parent = row }, function() step(-1) end)
		UI.frame({ Size = UDim2.fromOffset(22, 4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = c.text, ZIndex = 55, Parent = minus })
		local numBox = UI.frame({ Size = UDim2.fromOffset(90, 56), BackgroundColor3 = c.card2, ZIndex = 54, Parent = row })
		UI.corner(numBox, 12)
		numLabel = UI.text({ Text = tostring(sel.maxPlayers), Size = UDim2.fromScale(1, 1), TextSize = 28, TextColor3 = c.gold, ZIndex = 55, Parent = numBox })
		local plus = UI.button({ Text = "", Size = UDim2.fromOffset(56, 56), BackgroundColor3 = c.card, ZIndex = 54, Parent = row }, function() step(1) end)
		Icons.draw("plus", plus, 22, c.text, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
		UI.text({ Text = T("access"), Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 104), TextXAlignment = UI.align(lang), TextSize = 20, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local chips = UI.frame({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 138), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.list(chips, 10, Enum.FillDirection.Horizontal)
		local btns = {}
		local function mark()
			for id, b in pairs(btns) do
				b.BackgroundColor3 = sel.access == id and c.accent or c.card
				b.TextColor3 = sel.access == id and c.bg or c.text
			end
		end
		for _, id in ipairs({ "public", "friends", "fof", "request" }) do
			btns[id] = UI.button({ Text = T("acc_" .. id), Size = UDim2.fromOffset(122, 48), TextSize = 15, ZIndex = 54, Parent = chips }, function()
				sel.access = id
				mark()
			end)
		end
		mark()
		-- player fighting on / off
		UI.text({ Text = T("pvp"), Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 200), TextXAlignment = UI.align(lang), TextSize = 20, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local pchips = UI.frame({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 234), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.list(pchips, 10, Enum.FillDirection.Horizontal)
		local pbtn = {}
		local function markP()
			for v, bt in pairs(pbtn) do
				local on = sel.pvp == v
				bt.BackgroundColor3 = on and (v and c.danger or c.accent) or c.card
				bt.TextColor3 = on and (v and c.text or c.bg) or c.text
			end
		end
		pbtn[false] = UI.button({ Text = T("pvpOff"), Size = UDim2.fromOffset(160, 48), TextSize = 18, ZIndex = 54, Parent = pchips }, function() sel.pvp = false markP() end)
		pbtn[true] = UI.button({ Text = T("pvpOn"), Size = UDim2.fromOffset(160, 48), TextSize = 18, ZIndex = 54, Parent = pchips }, function() sel.pvp = true markP() end)
		markP()
		UI.button({ Text = T("save"), Size = UDim2.fromOffset(240, 54), Position = UDim2.new(lang == "ar" and 1 or 0, lang == "ar" and -240 or 0, 1, -54), ZIndex = 53, Parent = content }, function()
			local newName = nameBox.Text
			if newName ~= (room.name or "") then
				local rn = call("renameRoom", room.code, newName)
				if not rn.ok then toast(T(ERR[rn.err] or "busy")) return end
			end
			local res = call("roomSettings", room.code, sel)
			if res.ok then
				info.owned = res.owned or info.owned
				toast(T("saved"))
				roomsModal()
			else
				toast(T(ERR[res.err] or "busy"))
			end
		end)
		local armed = false
		local del
		del = UI.button({ Text = T("deleteRoom"), Size = UDim2.fromOffset(200, 54), Position = UDim2.new(lang == "ar" and 0 or 1, lang == "ar" and 0 or -200, 1, -54), BackgroundColor3 = c.danger, TextColor3 = c.text, ZIndex = 53, Parent = content }, function()
			if not armed then
				armed = true
				del.Text = T("confirmDelete")
				task.delay(3, function() if del.Parent then armed = false del.Text = T("deleteRoom") end end)
				return
			end
			local res = call("deleteRoom", room.code)
			if res.ok then
				info.owned = res.owned or {}
				info.rooms = res.rooms or info.rooms
				toast(T("deleted"))
				roomsModal()
			else
				toast(T(ERR[res.err] or "busy"))
			end
		end)
	end

	function roomsModal()
		local content = openModal(T("rooms"), UDim2.fromOffset(640, 520))
		-- header: count, create, buy more
		local head = UI.frame({ Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.text({ Text = Locale.f(lang, "roomsCount", #info.owned, info.limit), Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromScale(lang == "ar" and 0.6 or 0, 0), TextXAlignment = UI.align(lang), TextSize = 20, TextColor3 = c.gold, ZIndex = 54, Parent = head })
		local hb = UI.frame({ Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.fromScale(lang == "ar" and 0 or 0.4, 0), BackgroundTransparency = 1, ZIndex = 54, Parent = head })
		UI.list(hb, 8, Enum.FillDirection.Horizontal, lang == "ar" and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right)
		if #info.owned < info.limit then
			UI.button({ Text = T("create"), Size = UDim2.fromOffset(150, 46), TextSize = 18, ZIndex = 55, Parent = hb }, function()
				if busy then return end
				busy = true
				local res = call("create")
				busy = false
				if res.ok and res.code then
					local r2 = call("info")
					if r2.ok then info.owned = r2.owned or info.owned info.limit = r2.limit or info.limit end
					playPage("code", res.code)
				else
					toast(T(ERR[res.err] or "busy"))
				end
			end)
		end
		if info.limit < 3 then
			UI.button({ Text = T("buyRooms"), Size = UDim2.fromOffset(200, 46), TextSize = 16, BackgroundColor3 = c.gold, ZIndex = 55, Parent = hb }, function()
				local res = call("buyRooms")
				if not res.ok then toast(T(ERR[res.err] or "busy")) end
			end)
		end
		local list = UI.scroll({ Size = UDim2.new(1, 0, 1, -58), Position = UDim2.fromOffset(0, 58), ZIndex = 53, Parent = content })
		UI.list(list, 8)
		local n = 0
		local ownedSet = {}
		local function header(text)
			UI.text({ Text = text, Size = UDim2.new(1, -8, 0, 26), TextXAlignment = UI.align(lang), TextSize = 17, TextColor3 = c.dim, ZIndex = 53, Parent = list })
		end
		if #info.owned > 0 then header(T("rooms")) end
		for i, r in ipairs(info.owned) do
			ownedSet[r.code] = true
			n += 1
			r.defaultName = Locale.f(lang, "roomN", i)
			local sub = string.format("%s  |  %s  |  %s %d", Locale.f(lang, "codeIs", r.code), T("acc_" .. r.access), T("maxPlayers"), r.maxPlayers) .. (r.admin and ("  |  " .. T("adminOnTag")) or "")
			local row = joinRow(list, (r.name or r.defaultName) .. "   (" .. T("myRoom") .. ")", sub, function() travel("join", r.code) end)
			local bx = lang == "ar" and 0 or 1
			local gear = UI.button({ Text = "", Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(bx, 0.5), Position = UDim2.new(bx, lang == "ar" and 132 or -132, 0.5, 0), BackgroundColor3 = c.card2, ZIndex = 55, Parent = row }, function()
				settingsModal(r)
			end)
			Icons.draw("settings", gear, 24, c.text, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			progressBadge(row, r.pct, 186)
			UI.enter(row, n * 0.05, 14)
		end
		local visitedHeader = false
		for _, r in ipairs(info.rooms) do
			if not ownedSet[r.code] then
				if not visitedHeader then visitedHeader = true header(T("visitedRooms")) end
				n += 1
				local sub = string.format("%s %s   |   %s %s", T("coins"), Format.number(r.coins), T("xp"), Format.number(r.xp))
				local row = joinRow(list, r.code, sub, function() travel("join", r.code) end)
				progressBadge(row, r.pct, 130)
				UI.enter(row, n * 0.05, 14)
			end
		end
		if n == 0 then
			UI.text({ Text = T("noRooms"), Size = UDim2.new(1, 0, 0, 80), TextColor3 = c.dim, ZIndex = 53, Parent = list })
		end
	end

	local function lookModal()
		local content = openModal(T("look"), UDim2.fromOffset(780, 520))
		local sel = table.clone(info.look)
		local preview = makePreview(content, UDim2.fromOffset(240, 380), UDim2.fromOffset(lang == "ar" and 516 or 0, 0))
		local right = UI.scroll({ Size = UDim2.new(0, 490, 1, -66), Position = UDim2.fromOffset(lang == "ar" and 0 or 262, 0), ZIndex = 53, Parent = content })
		UI.list(right, 10)
		local function section(title)
			UI.text({ Text = title, Size = UDim2.new(1, -8, 0, 26), TextXAlignment = UI.align(lang), TextSize = 19, TextColor3 = c.dim, ZIndex = 53, Parent = right })
			local row = UI.frame({ Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 53, Parent = right })
			UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 8), HorizontalAlignment = lang == "ar" and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left, Parent = row })
			return row
		end
		local function swatches(title, key, colors)
			local row = section(title)
			local strokes = {}
			local function mark()
				for i, st in ipairs(strokes) do
					st.Thickness = (sel[key] == i) and 4 or 1.5
					st.Color = (sel[key] == i) and c.text or c.card2
				end
			end
			for i, col in ipairs(colors) do
				local b = UI.button({ Text = "", Size = UDim2.fromOffset(42, 42), BackgroundColor3 = col, ZIndex = 54, Parent = row }, function()
					sel[key] = i
					mark()
					preview.set(sel)
				end)
				UI.corner(b, 21)
				table.insert(strokes, UI.stroke(b, c.card2, 1.5))
			end
			mark()
		end
		local function chips(title, key, ids, prefix)
			local row = section(title)
			local btns = {}
			local function mark()
				for id, b in pairs(btns) do
					b.BackgroundColor3 = (sel[key] == id) and c.accent or c.card
					b.TextColor3 = (sel[key] == id) and c.bg or c.text
				end
			end
			for _, id in ipairs(ids) do
				btns[id] = UI.button({ Text = T(prefix .. id), Size = UDim2.fromOffset(114, 40), TextSize = 17, BackgroundColor3 = c.card, TextColor3 = c.text, ZIndex = 54, Parent = row }, function()
					sel[key] = id
					mark()
					preview.set(sel)
				end)
			end
			mark()
		end
		swatches(T("skin"), "skin", Appearance.skins)
		swatches(T("shirt"), "shirt", Appearance.shirts)
		swatches(T("pants"), "pants", Appearance.pants)
		chips(T("hat"), "hat", Appearance.hats, "hat_")
		chips(T("extra"), "extra", Appearance.extras, "ex_")
		UI.button({ Text = T("save"), Size = UDim2.fromOffset(240, 52), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), ZIndex = 53, Parent = content }, function()
			local res = call("setLook", sel)
			if res.ok then
				info.look = res.look
				toast(T("saved"))
				placeRig()
				if closeModal then closeModal() end
			else
				toast(T(ERR[res.err] or "busy"))
			end
		end)
	end

	-- the store: game passes (bought with Robux through the Roblox prompt)
	local function storeModal()
		local content = openModal(T("store"), UDim2.fromOffset(640, 440))
		local list = UI.scroll({ Size = UDim2.fromScale(1, 1), ZIndex = 53, Parent = content })
		UI.list(list, 12)
		local owns = info.store or {}
		for i, it in ipairs({ { "admin", "settings", 250, c.gold }, { "rooms", "home", 30, c.accent } }) do
			local key, icon, price, col = it[1], it[2], it[3], it[4]
			local row = UI.frame({ Size = UDim2.new(1, -8, 0, 150), BackgroundColor3 = c.card, LayoutOrder = i, ZIndex = 54, Parent = list })
			UI.corner(row, 14)
			UI.stroke(row, col, 1.5)
			local ar = lang == "ar"
			local ic = UI.frame({ Size = UDim2.fromOffset(84, 84), AnchorPoint = Vector2.new(ar and 1 or 0, 0.5), Position = UDim2.new(ar and 1 or 0, ar and -16 or 16, 0.5, 0), BackgroundColor3 = c.card2, ZIndex = 55, Parent = row })
			UI.corner(ic, 14)
			Icons.draw(icon, ic, 52, col, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			UI.text({ Text = T("pass_" .. key), Size = UDim2.new(1, -330, 0, 34), Position = UDim2.new(0, ar and 214 or 116, 0, 16), TextXAlignment = UI.align(lang), TextSize = 24, TextColor3 = col, ZIndex = 55, Parent = row })
			UI.text({ Text = T("pass_" .. key .. "_d"), Size = UDim2.new(1, -330, 0, 86), Position = UDim2.new(0, ar and 214 or 116, 0, 52), TextXAlignment = UI.align(lang), TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextSize = 16, TextColor3 = c.dim, ZIndex = 55, Parent = row })
			local bx = ar and 0 or 1
			if owns[key] then
				UI.text({ Text = T("owned"), Size = UDim2.fromOffset(180, 52), AnchorPoint = Vector2.new(bx, 0.5), Position = UDim2.new(bx, ar and 16 or -16, 0.5, 0), TextSize = 20, TextColor3 = c.accent, ZIndex = 55, Parent = row })
			else
				UI.button({ Text = price .. " " .. T("robux"), Size = UDim2.fromOffset(180, 52), AnchorPoint = Vector2.new(bx, 0.5), Position = UDim2.new(bx, ar and 16 or -16, 0.5, 0), TextSize = 20, BackgroundColor3 = col, TextColor3 = c.bg, ZIndex = 55, Parent = row }, function()
					local res = call("buyPass", key)
					if not res.ok then toast(T(ERR[res.err] or res.err or "busy")) end
				end)
			end
		end
	end

	local function settingsModal()
		local content = openModal(T("settings"), UDim2.fromOffset(520, 300))
		UI.text({ Text = T("language"), Size = UDim2.new(1, 0, 0, 36), TextXAlignment = UI.align(lang), TextSize = 22, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local row = UI.frame({ Size = UDim2.new(1, 0, 0, 64), Position = UDim2.fromOffset(0, 46), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.list(row, 12, Enum.FillDirection.Horizontal)
		for _, l in ipairs({ { "ar", "العربية" }, { "en", "English" } }) do
			UI.button({
				Text = l[2], Size = UDim2.fromOffset(200, 56), BackgroundColor3 = lang == l[1] and c.accent or c.card,
				TextColor3 = lang == l[1] and c.bg or c.text, ZIndex = 54, Parent = row,
			}, function()
				lang = l[1]
				call("setLang", l[1])
				render()
				settingsModal()
			end)
		end
	end

	---------------------------------------------------------------- home
	function render()
		if closeModal then closeModal() end
		task.spawn(placeRig)
		if screen then screen:Destroy() end
		screen = UI.frame({ Name = "Screen", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })

		local shade = UI.frame({ Size = UDim2.fromScale(0.62, 1), Position = UDim2.fromScale(lang == "ar" and 0.38 or 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Parent = screen })
		UI.new("UIGradient", { Rotation = lang == "ar" and 180 or 0, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) }), Parent = shade })

		local colX = lang == "ar" and 0.7 or 0.3
		local title = UI.text({ Text = T("title"), Size = UDim2.new(0, 460, 0, 90), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(colX, 0, 0, 96), TextSize = 76, TextColor3 = c.gold, Parent = screen })
		UI.new("UIStroke", { Color = Color3.fromRGB(70, 40, 10), Thickness = 3, Transparency = 0.3, Parent = title })
		UI.enter(title, 0, -20)

		local col = UI.frame({ Size = UDim2.fromOffset(330, 380), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(colX, 0, 0, 200), BackgroundTransparency = 1, Parent = screen })
		UI.list(col, 12)
		local items = {
			{ "play", T("play"), function() playPage() end, true },
			{ "ranking", T("ranking"), boardModal }, { "rooms", T("rooms"), roomsModal },
			{ "coin", T("store"), storeModal },
			{ "look", T("look"), lookModal }, { "settings", T("settings"), settingsModal },
		}
		for i, it in ipairs(items) do
			local primary = it[4]
			local b = UI.button({
				Text = it[2], Size = UDim2.fromOffset(330, primary and 74 or 56), TextSize = primary and 30 or 22,
				BackgroundColor3 = primary and c.accent or c.card, TextColor3 = primary and c.bg or c.text, LayoutOrder = i, Parent = col,
			}, it[3])
			UI.stroke(b, primary and c.accent:Lerp(Color3.new(1, 1, 1), 0.3) or c.card2, 1.5)
			Icons.draw(it[1], b, primary and 30 or 24, primary and c.bg or c.gold, UDim2.new(lang == "ar" and 1 or 0, lang == "ar" and -50 or 22, 0.5, 0), Vector2.new(0, 0.5))
			UI.enter(b, 0.08 + i * 0.07, 30)
			if i == 1 and UI.usingGamepad() then
				task.delay(0.6, function() if b.Parent then game:GetService("GuiService").SelectedObject = b end end)
			end
		end

		-- player card: always top-right (the top-left belongs to Roblox buttons)
		local card = UI.frame({ Size = UDim2.fromOffset(300, 76), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), BackgroundColor3 = c.panel, BackgroundTransparency = 0.08, Parent = screen })
		UI.corner(card, 14)
		UI.stroke(card, c.card2, 2)
		UI.text({ Text = Players.LocalPlayer.DisplayName, Size = UDim2.new(1, -28, 0, 30), Position = UDim2.fromOffset(14, 6), TextXAlignment = UI.align(lang), TextSize = 22, Parent = card })
		local stat = UI.text({ Text = Format.number(info.lifeXp) .. " XP", Size = UDim2.new(1, -28, 0, 28), Position = UDim2.fromOffset(14, 40), TextXAlignment = UI.align(lang), TextSize = 18, TextColor3 = c.accent, Parent = card })
		UI.enter(card, 0.1, -16)
		task.spawn(function()
			local res = call("board")
			if res.ok and stat.Parent then
				local b = res.board
				stat.Text = string.format("%s XP   |   %s %s", Format.number(b.meXp), T("rank"), Format.rank(b.meRank, b.scanned))
			end
		end)
		-- language toggle next to the card
		local lt = UI.button({
			Text = lang == "ar" and "EN" or "ع", Size = UDim2.fromOffset(58, 58), TextSize = 22, BackgroundColor3 = c.card, TextColor3 = c.text,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -326, 0, 23), Parent = screen,
		}, function()
			lang = (lang == "ar") and "en" or "ar"
			call("setLang", lang)
			render()
		end)
		UI.enter(lt, 0.15, -16)
	end

	task.spawn(function()
		local res = call("info")
		if res.ok then
			lang = res.lang or "ar"
			info.lifeXp = res.lifeXp or 0
			info.rooms = res.rooms or {}
			info.look = Appearance.sanitize(res.look)
			info.owned = res.owned or {}
			info.limit = res.limit or 1
			info.store = res.store or {}
		end
		placeRig()
		render()
	end)
	remotes.Notify.OnClientEvent:Connect(function(key, what)
		busy = false
		toast(T(key))
		if key == "bought" and what then
			info.store = info.store or {}
			info.store[what] = true
			if what == "rooms" then info.limit = math.max(info.limit, 3) end
			if closeModal and what then storeModal() end
		end
	end)
	task.spawn(function()
		local ok, data = pcall(function() return game:GetService("TeleportService"):GetLocalPlayerTeleportData() end)
		if ok and type(data) == "table" and type(data.msg) == "string" then
			task.wait(1.5)
			toast(T(data.msg))
		end
	end)
	render()
	return { playPage = playPage, boardModal = boardModal, roomsModal = roomsModal, lookModal = lookModal, settingsModal = settingsModal, storeModal = storeModal }
end

return M
