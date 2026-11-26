-- In-world screens: HUD, hotbar, bag, trader shop, skills, menu, aiming, prompts, creature labels.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared:WaitForChild("Locale"))
local Format = require(Shared:WaitForChild("Format"))
local Config = require(Shared:WaitForChild("Config"))
local Items = require(Shared:WaitForChild("Items"))
local UI = require(script.Parent:WaitForChild("UI"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local ItemView = require(script.Parent:WaitForChild("ItemView"))
local Effects = require(script.Parent:WaitForChild("Effects"))
local Bestiary = require(Shared:WaitForChild("Bestiary"))
local Biomes = require(Shared:WaitForChild("Biomes"))
local c = UI.c

local M = {}

function M.start(gui, remotes)
	task.spawn(function()
		for _ = 1, 10 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			end)
			if ok then break end
			task.wait(1)
		end
	end)

	local player = Players.LocalPlayer
	local root = UI.root(gui)
	local state = nil
	local lang = "ar"
	local closeModal, modalKind
	local pending = nil
	local refreshModal
	local furnaceData, refreshFurnace, furnaceModal -- the furnace window (built further down)
	local furnaceBagSize = ""
	local lastSig = ""
	local lastMsig = nil
	local lastDsig = nil

	local function T(k) return Locale.t(lang, k) end
	-- sounds for handling items: moving/swapping, throwing away, picking a tool, equipping
	local ACT_SOUND = { move = { "pop", 0.45, 1.05 }, discard = { "swing", 0.5, 0.8 }, select = { "clickBright", 0.4, 1 },
		unequipArmor = { "pop", 0.45, 0.9 }, unequipOff = { "pop", 0.45, 0.9 } }
	local function act(action, a, b)
		local snd = ACT_SOUND[action]
		if snd then pcall(Effects.play, snd[1], nil, snd[2], snd[3]) end
		task.spawn(function() pcall(function() remotes.World:InvokeServer(action, a, b) end) end)
	end

	---------------------------------------------------------------- slot widget
	local function slotWidget(parent, size, order)
		local b = UI.button({ Text = "", Size = UDim2.fromOffset(size, size), BackgroundColor3 = c.card, LayoutOrder = order or 0, Parent = parent })
		local st = UI.stroke(b, c.card2, 2)
		local w = { button = b, stroke = st, id = nil }
		w.count = UI.text({ Text = "", Size = UDim2.fromOffset(size * 0.6, 18), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -5, 1, -3), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6, Parent = b })
		local durBg = UI.frame({ Size = UDim2.new(1, -12, 0, 4), Position = UDim2.new(0, 6, 1, -7), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, ZIndex = 6, Visible = false, Parent = b })
		UI.corner(durBg, 2)
		local dur = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = c.accent, ZIndex = 7, Parent = durBg })
		UI.corner(dur, 2)
		w.durBg, w.dur = durBg, dur
		function w.set(data, selected)
			local id = data and data.id or nil
			if id ~= w.id then
				if w.view then w.view:Destroy() w.view = nil end
				w.id = id
				if id then
					w.view = ItemView.new(b, id, UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4), 4)
					local sc = UI.new("UIScale", { Scale = 0.6, Parent = w.view })
					UI.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
				end
			end
			local newN = data and data.n or 0
			local oldN = (w.lastId == id) and (w.lastN or 0) or newN
			w.lastId, w.lastN = id, newN
			if id and newN > oldN and oldN > 0 or (id and newN > 1 and oldN == 0 and w.seen) then
				local from = (oldN > 0) and oldN or 0
				local nv = Instance.new("NumberValue")
				nv.Value = from
				nv.Changed:Connect(function(v) if w.count.Parent then w.count.Text = tostring(math.floor(v + 0.5)) end end)
				local t = UI.tween(nv, 0.45, { Value = newN })
				t.Completed:Connect(function() nv:Destroy() end)
				local sc = w.button:FindFirstChildOfClass("UIScale")
				if sc then
					UI.tween(sc, 0.08, { Scale = 1.15 })
					task.delay(0.09, function() UI.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back) end)
				end
				local fl = UI.text({ Text = "+" .. (newN - from), Size = UDim2.fromOffset(60, 22), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 0), TextSize = 18, TextColor3 = c.gold, TextStrokeTransparency = 0.4, ZIndex = 20, Parent = w.button })
				UI.tween(fl, 0.8, { Position = UDim2.new(0.5, 0, 0, -36), TextTransparency = 1, TextStrokeTransparency = 1 })
				task.delay(0.85, function() fl:Destroy() end)
			else
				w.count.Text = (data and data.n > 1) and tostring(data.n) or ""
			end
			if data and data.n <= 1 then w.count.Text = "" end
			w.seen = true
			local def = id and Items.get(id)
			if def and def.dur and data.d then
				w.durBg.Visible = true
				local r = math.clamp(data.d / def.dur, 0, 1)
				w.dur.Size = UDim2.fromScale(r, 1)
				w.dur.BackgroundColor3 = r > 0.5 and c.accent or (r > 0.2 and c.gold or c.danger)
			else
				w.durBg.Visible = false
			end
			UI.tween(st, 0.15, { Color = selected and c.gold or c.card2, Thickness = selected and 3.5 or 2 })
		end
		return w
	end

	---------------------------------------------------------------- drag & drop (touch + mouse)
	local slotsReg = {} -- [button] = { index, onTap, w }
	local press = nil -- { button, index, input, start, dragging, ghost }
	local dropZone = nil
	local bagPanel = nil
	local hoverStroke = nil

	-- the ScreenGui ignores the top-bar inset, so input positions and AbsolutePosition share the same space
	local function screenPos(input)
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	local function inside(obj, p)
		if not obj or not obj.Parent or not obj.Visible then return false end
		local a, s = obj.AbsolutePosition, obj.AbsoluteSize
		return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
	end
	local function targetAt(p)
		if modalKind ~= "bag" then return nil end
		for btn, reg in pairs(slotsReg) do
			if btn.Parent and btn:IsDescendantOf(root) and inside(btn, p) then return btn, reg end
		end
		return nil
	end
	local function setHover(btn)
		if hoverStroke then
			hoverStroke.Color = hoverStroke:GetAttribute("C") or c.card2
			hoverStroke.Thickness = hoverStroke:GetAttribute("T") or 2
			hoverStroke = nil
		end
		local st = btn and btn:FindFirstChildOfClass("UIStroke")
		if st then
			st:SetAttribute("C", st.Color)
			st:SetAttribute("T", st.Thickness)
			st.Color = c.accent
			st.Thickness = 4
			hoverStroke = st
		end
	end

	local function register(w, index, onTap)
		slotsReg[w.button] = { index = index, onTap = onTap, w = w }
		w.button.InputBegan:Connect(function(input)
			if press then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				press = { button = w.button, index = index, input = input, start = Vector2.new(input.Position.X, input.Position.Y), dragging = false }
			end
		end)
		w.button.Destroying:Connect(function() slotsReg[w.button] = nil end)
		-- controller "A / X" press = a tap (no dragging with a gamepad)
		w.button.Activated:Connect(function()
			if UI.usingGamepad() then onTap() end
		end)
	end

	local function startDrag(data)
		press.dragging = true
		local ghost = UI.frame({ Size = UDim2.fromOffset(70, 70), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = c.card, BackgroundTransparency = 0.2, ZIndex = 300, Parent = gui })
		UI.corner(ghost, 14)
		UI.stroke(ghost, c.gold, 3)
		ItemView.new(ghost, data.id, UDim2.new(1, -8, 1, -8), UDim2.fromOffset(4, 4), 301)
		if data.n > 1 then
			UI.text({ Text = tostring(data.n), Size = UDim2.fromOffset(40, 18), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -2), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 302, Parent = ghost })
		end
		local sc = UI.new("UIScale", { Scale = 0.7, Parent = ghost })
		UI.tween(sc, 0.15, { Scale = 1.1 }, Enum.EasingStyle.Back)
		press.ghost = ghost
		if press.button.Parent then press.button.BackgroundTransparency = 0.6 end
		if dropZone and dropZone.Parent then UI.tween(dropZone, 0.15, { BackgroundTransparency = 0 }) end
		Effects.ui("pop")
	end

	local function endDrag(pr, p)
		if pr.ghost then pr.ghost:Destroy() end
		if pr.button.Parent then pr.button.BackgroundTransparency = 0 end
		setHover(nil)
		if dropZone and dropZone.Parent then UI.tween(dropZone, 0.15, { BackgroundTransparency = 0.35 }) end
		if modalKind == "bag" and bagPanel and bagPanel.Parent and not inside(bagPanel, p) and pr.index < 100 then
			act("discard", pr.index)
			pending = nil
			return
		end
		local btn, reg = targetAt(p)
		if reg and reg.index ~= pr.index then
			act("move", pr.index, reg.index)
			pending = nil
			Effects.ui("click")
		end
	end

	UserInputService.InputChanged:Connect(function(input)
		if not press then return end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and input == press.input) then
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if not press.dragging and (pos - press.start).Magnitude > 12 then
				local fd = furnaceData or {}
				local data = state and (press.index == 100 and state.armor and { id = state.armor, n = 1 } or press.index == 101 and state.off
					or press.index == 201 and fd.input or press.index == 202 and fd.fuel or press.index == 203 and fd.out or state.slots[press.index])
				if not data then press = nil return end
				startDrag(data)
			end
			if press.dragging then
				local p = screenPos(input)
				press.ghost.Position = UDim2.fromOffset(p.X, p.Y)
				local btn = targetAt(p)
				if btn ~= press.button then setHover(btn) else setHover(nil) end
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not press then return end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or (t == Enum.UserInputType.Touch and input == press.input) then
			local pr = press
			press = nil
			if pr.dragging then
				endDrag(pr, screenPos(input))
			else
				local reg = slotsReg[pr.button]
				if reg and reg.onTap then reg.onTap() end
			end
		end
	end)

	---------------------------------------------------------------- hotbar
	local hotbar = UI.frame({ Size = UDim2.fromOffset(Config.HOTBAR * 74, 72), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), BackgroundTransparency = 1, Parent = root })
	UI.list(hotbar, 8, Enum.FillDirection.Horizontal)
	local hot = {}
	for i = 1, Config.HOTBAR do
		local w = slotWidget(hotbar, 66, i)
		UI.text({ Text = tostring(i), Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(5, 3), TextSize = 13, TextColor3 = c.dim, ZIndex = 6, TextXAlignment = Enum.TextXAlignment.Left, Parent = w.button })
		w.button.Activated:Connect(function()
			if not state then return end
			act("select", state.sel == i and 0 or i)
		end)
		hot[i] = w
	end
	UI.enter(hotbar, 0.2, 40)
	UI.keyHint(hotbar, nil, Enum.KeyCode.ButtonL1, UDim2.new(0, -6, 0, -10), Vector2.new(1, 0.5))
	UI.keyHint(hotbar, nil, Enum.KeyCode.ButtonR1, UDim2.new(1, 6, 0, -10), Vector2.new(0, 0.5))

	local function sideButton(icon, offsetX, cb)
		local b = UI.button({ Text = "", Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, offsetX, 1, -16), BackgroundColor3 = c.card, Parent = root }, cb)
		UI.stroke(b, c.card2, 2)
		Icons.draw(icon, b, 30, c.text, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
		return b
	end

	---------------------------------------------------------------- HUD (top, right of the Roblox buttons): level, coins, skill points, day + full-width XP bar
	local hud = UI.frame({ Size = UDim2.fromOffset(440, 82), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), BackgroundColor3 = c.panel, BackgroundTransparency = 0.12, Parent = root })
	UI.corner(hud, 16)
	UI.stroke(hud, c.card2, 2)
	UI.enter(hud, 0.1, -30)
	local levelText = UI.text({ Text = "", Size = UDim2.fromOffset(86, 34), Position = UDim2.fromOffset(12, 8), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 19, TextColor3 = c.gold, Parent = hud })
	local function chip(x, w, icon, color)
		local f = UI.frame({ Size = UDim2.fromOffset(w, 34), Position = UDim2.fromOffset(x, 8), BackgroundColor3 = c.card, Parent = hud })
		UI.corner(f, 17)
		Icons.draw(icon, f, 18, color, UDim2.new(0, 9, 0.5, 0), Vector2.new(0, 0.5))
		return UI.text({ Text = "", Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(32, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, TextColor3 = color, Parent = f })
	end
	local coinsText = chip(100, 108, "coin", c.gold)
	local shownCoins = nil
	local function setCoins(n)
		if shownCoins == nil then
			shownCoins = n
			coinsText.Text = Format.number(n)
			return
		end
		if n == shownCoins then return end
		local from = shownCoins
		shownCoins = n
		local nv = Instance.new("NumberValue")
		nv.Value = from
		nv.Changed:Connect(function(v) coinsText.Text = Format.number(math.floor(v + 0.5)) end)
		local t = UI.tween(nv, 0.6, { Value = n })
		t.Completed:Connect(function() nv:Destroy() coinsText.Text = Format.number(n) end)
		local chipF = coinsText.Parent
		local sc = chipF:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = chipF })
		UI.tween(sc, 0.08, { Scale = 1.15 })
		task.delay(0.09, function() UI.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back) end)
		if n > from then
			local fl = UI.text({ Text = "+" .. Format.number(n - from), Size = UDim2.fromOffset(80, 22), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0), TextSize = 17, TextColor3 = c.gold, TextStrokeTransparency = 0.4, ZIndex = 20, Parent = chipF })
			UI.tween(fl, 0.9, { Position = UDim2.new(0.5, 0, 1, 26), TextTransparency = 1, TextStrokeTransparency = 1 })
			task.delay(0.95, function() fl:Destroy() end)
		end
	end
	local spText = chip(214, 70, "skill", c.blue)
	local dayFrame = UI.frame({ Size = UDim2.fromOffset(110, 34), Position = UDim2.fromOffset(290, 8), BackgroundColor3 = c.card, Parent = hud })
	UI.corner(dayFrame, 17)
	local clockIcon = UI.frame({ Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 7, 0.5, 0), BackgroundTransparency = 1, Parent = dayFrame })
	local dayText = UI.text({ Text = "", Size = UDim2.new(1, -38, 1, 0), Position = UDim2.fromOffset(34, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, Parent = dayFrame })
	local codeText = { Text = "" } -- the room code lives in the menu now
	local lastNight = nil
	-- XP bar across the whole panel, numbers on the other side
	local xpBg = UI.frame({ Size = UDim2.new(1, -150, 0, 12), Position = UDim2.fromOffset(12, 56), BackgroundColor3 = c.card, Parent = hud })
	UI.corner(xpBg, 6)
	local xpFill = UI.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = c.accent, Parent = xpBg })
	UI.corner(xpFill, 6)
	UI.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(150, 255, 170), Color3.new(1, 1, 1)), Rotation = 90, Parent = xpFill })
	local xpText = UI.text({ Text = "", Size = UDim2.fromOffset(126, 20), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 52), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 15, TextColor3 = c.accent, Parent = hud })

	---------------------------------------------------------------- vitals (right column, under the HUD): health, hunger, armor, temperature gauge
	local buffBar = UI.frame({ Size = UDim2.fromOffset(600, 30), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -92), BackgroundTransparency = 1, Parent = root })
	UI.list(buffBar, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
	local sleepShade = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.15, ZIndex = 90, Visible = false, Parent = root })
	local sleepText = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.42, 0), TextSize = 28, ZIndex = 91, Parent = sleepShade })
	UI.text({ Text = "", Name = "Hint", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0.42, 44), TextSize = 17, TextColor3 = c.dim, ZIndex = 91, Parent = sleepShade })
	UI.button({ Text = "", Name = "Wake", Size = UDim2.fromOffset(200, 50), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.42, 84), ZIndex = 92, Parent = sleepShade }, function() act("wake") end)
	UserInputService.JumpRequest:Connect(function()
		if sleepShade.Visible then act("wake") end
	end)
	local vitals = UI.frame({ Size = UDim2.fromOffset(440, 118), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 100), BackgroundColor3 = c.panel, BackgroundTransparency = 0.15, Parent = root })
	UI.corner(vitals, 16)
	UI.stroke(vitals, c.card2, 2)
	UI.enter(vitals, 0.15, -20)
	local function bar(y, h, w, icon, color, iconSize)
		Icons.draw(icon, vitals, iconSize, color, UDim2.fromOffset(14, y + h / 2), Vector2.new(0, 0.5))
		local bg = UI.frame({ Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(20 + iconSize, y), BackgroundColor3 = c.card, Parent = vitals })
		UI.corner(bg, h / 2)
		local fill = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, Parent = bg })
		UI.corner(fill, h / 2)
		UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)), Parent = fill })
		return bg, fill
	end
	local hpBg, hpFill = bar(14, 28, 262, "heart", Color3.fromRGB(226, 76, 76), 26)
	local hpText = UI.text({ Text = "", Size = UDim2.fromScale(1, 1), TextSize = 16, ZIndex = 4, TextStrokeTransparency = 0.5, Parent = hpBg })
	local _, foodFill = bar(54, 16, 266, "food", Color3.fromRGB(232, 152, 70), 22)
	-- armor bar under hunger: how much damage the worn armor blocks (45% = full)
	local armorBg, armorFill = bar(84, 16, 266, "shield", Color3.fromRGB(120, 180, 250), 22)
	local armorText = UI.text({ Text = "", Size = UDim2.fromScale(1, 1), TextSize = 13, ZIndex = 4, TextStrokeTransparency = 0.5, Parent = armorBg })

	-- temperature gauge: a smooth arc, needle right = cold, left = hot, value underneath
	local gauge = UI.frame({ Size = UDim2.fromOffset(112, 88), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), BackgroundTransparency = 1, Parent = vitals })
	local cx, cy, R = 56, 54, 40
	local back = UI.frame({ Size = UDim2.fromOffset(2 * R + 18, 2 * R + 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Parent = gauge })
	UI.corner(back, R + 9)
	UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0), NumberSequenceKeypoint.new(0.56, 1), NumberSequenceKeypoint.new(1, 1) }), Parent = back })
	local SEG = 26
	for i = 0, SEG do
		local t = i / SEG
		local ang = math.pi * (1 - t)
		local col
		if t < 0.5 then col = Color3.fromRGB(235, 80, 55):Lerp(Color3.fromRGB(110, 215, 120), t * 2)
		else col = Color3.fromRGB(110, 215, 120):Lerp(Color3.fromRGB(80, 160, 245), (t - 0.5) * 2) end
		local seg = UI.frame({ Size = UDim2.fromOffset(6, (i % 13 == 0) and 15 or 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx + math.cos(ang) * R, cy - math.sin(ang) * R), Rotation = 90 - math.deg(ang), BackgroundColor3 = col, Parent = gauge })
		UI.corner(seg, 3)
	end
	local needleHolder = UI.frame({ Size = UDim2.fromOffset(2 * (R - 6), 2 * (R - 6)), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), BackgroundTransparency = 1, Parent = gauge })
	local needleShadow = UI.frame({ Size = UDim2.fromOffset(5, R - 10), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 1.5, 0.5, 1.5), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Parent = needleHolder })
	UI.corner(needleShadow, 3)
	local needle = UI.frame({ Size = UDim2.fromOffset(5, R - 10), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = c.text, Parent = needleHolder })
	UI.corner(needle, 3)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 120, 90)), Parent = needle })
	local hub = UI.frame({ Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), BackgroundColor3 = c.text, Parent = gauge })
	UI.corner(hub, 7)
	UI.stroke(hub, c.panel, 2)
	Icons.draw("flame", gauge, 16, Color3.fromRGB(240, 110, 60), UDim2.fromOffset(cx - R - 2, cy + 14), Vector2.new(0.5, 0.5))
	Icons.draw("snow", gauge, 16, Color3.fromRGB(120, 190, 255), UDim2.fromOffset(cx + R + 2, cy + 14), Vector2.new(0.5, 0.5))
	local tempText = UI.text({ Text = "", Size = UDim2.fromOffset(70, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, cy + 10), TextSize = 14, Parent = gauge })

	---------------------------------------------------------------- modals
	local rebuilding = false
	local cinematic -- defined with the shop below
	local mini -- the minimap (built further down)
	local function openModal(kind, title, size)
		if closeModal then closeModal() end
		modalKind = kind
		local thisKind = kind
		local content, close, panel = UI.modal(root, title, lang, size, function()
			closeModal, modalKind = nil, nil
			pending = nil
			if press then
				if press.ghost then press.ghost:Destroy() end
				press = nil
			end
			if thisKind == "shop" and not rebuilding then cinematic(false) end
			if thisKind == "furnace" then act("closeFurnace") end
		end)
		closeModal = close
		return content, panel
	end

	local bagW, bagInfo, bagShape = {}, nil, ""
	local bagEq = {}
	local refreshBag
	local function bagModal()
		local big = state.bag == "big"
		local content, panel = openModal("bag", T("bag"), UDim2.fromOffset(big and 700 or 500, 540))
		bagPanel, bagW = panel, {}
		bagShape = tostring(state.bag) .. tostring(state.armor)
		UI.text({ Text = T("dropOutside"), Size = UDim2.new(1, 0, 0, 22), TextSize = 14, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local function tap(i)
			if not state then return end
			if pending == nil then
				if state.slots[i] then pending = i end
			elseif pending == i then
				pending = nil
			else
				act("move", pending, i)
				pending = nil
			end
			refreshBag()
		end
		local hb = UI.frame({ Size = UDim2.new(1, 0, 0, 62), Position = UDim2.fromOffset(0, 26), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.list(hb, 8, Enum.FillDirection.Horizontal)
		for i = 1, Config.HOTBAR do
			local w = slotWidget(hb, 60, i)
			w.button.ZIndex = 54
			register(w, i, function() tap(i) end)
			bagW[i] = w
		end
		local grid = UI.frame({ Size = UDim2.new(1, 0, 0, 3 * 66), Position = UDim2.fromOffset(0, 98), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(60, 60), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
		for k = 1, big and Config.BIG_BAG or Config.BAG do
			local i = Config.HOTBAR + k
			local w = slotWidget(grid, 60, k)
			if state.bag then
				register(w, i, function() tap(i) end)
				bagW[i] = w
			else
				local shade = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 8, Parent = w.button })
				UI.corner(shade, 12)
				Icons.draw("lock", shade, 22, c.dim, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			end
		end
		-- armor and off-hand slots, same look as the bag slots, with a label under each
		bagEq = {}
		local eqY = 98 + 3 * 66 + 8
		for k, info in ipairs({ { 100, "armorLbl", "shield" }, { 101, "offhand", "flame" } }) do
			local holder = UI.frame({ Size = UDim2.fromOffset(110, 84), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(k == 1 and 0.27 or 0.73, 0, 0, eqY), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
			local w = slotWidget(holder, 60, 0)
			w.button.AnchorPoint = Vector2.new(0.5, 0)
			w.button.Position = UDim2.fromScale(0.5, 0)
			w.button.ZIndex = 54
			local ghostIcon = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = w.button })
			Icons.draw(info[3], ghostIcon, 26, c.card2, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			w.empty = ghostIcon
			UI.text({ Text = T(info[2]), Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 63), TextSize = 13, TextColor3 = c.dim, ZIndex = 54, Parent = holder })
			local idx = info[1]
			register(w, idx, function()
				-- tap: put the selected bag item here, or take this item back out
				if pending and pending < 100 then
					act("move", pending, idx)
					pending = nil
				elseif (idx == 100 and state.armor) or (idx == 101 and state.off) then
					act(idx == 100 and "unequipArmor" or "unequipOff")
				end
				refreshBag()
			end)
			local base = w.set
			w.set = function(data, sel)
				base(data, sel)
				ghostIcon.Visible = data == nil
			end
			bagEq[idx] = w
		end
		bagInfo = UI.frame({ Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, eqY + 88), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		refreshBag()
	end

	function refreshBag()
		if modalKind ~= "bag" or not state then return end
		for i, w in pairs(bagW) do
			if w.button.Parent then w.set(state.slots[i], pending == i) end
		end
		if not bagInfo or not bagInfo.Parent then return end
		bagInfo:ClearAllChildren()
		local ar = lang == "ar"
		-- equipment slots (100 = armor, 101 = off hand); drag items in and out like any bag slot
		if bagEq[100] and bagEq[100].button.Parent then
			bagEq[100].set(state.armor and { id = state.armor, n = 1 } or nil, pending == 100)
			bagEq[101].set(state.off or nil, pending == 101)
		end
		local d = pending and state.slots[pending]
		if pending and not d then pending = nil end
		local below = UI.frame({ Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 53, Parent = bagInfo })
		if d then
			local row = UI.frame({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 8), BackgroundTransparency = 1, ZIndex = 53, Parent = below })
			UI.list(row, 8, Enum.FillDirection.Horizontal)
			local idx = pending
			local function btn(text, color, cb)
				UI.button({ Text = text, Size = UDim2.fromOffset(112, 44), BackgroundColor3 = color, TextColor3 = c.text, TextSize = 16, ZIndex = 54, Parent = row }, cb)
			end
			UI.text({ Text = Items.name(d.id, lang) .. (d.n > 1 and ("  x" .. d.n) or ""), Size = UDim2.fromOffset(110, 44), TextWrapped = true, TextSize = 15, TextColor3 = c.gold, ZIndex = 54, Parent = row })
			btn(T("drop1"), c.card2, function() act("discard", idx, 1) end)
			if d.n > 1 then
				btn(T("dropAll"), c.danger, function() act("discard", idx) pending = nil end)
				btn(T("split"), c.blue, function() act("split", idx) end)
			end
		elseif not state.bag then
			UI.text({ Text = T("vendorTip") .. "  -  " .. Locale.f(lang, "buyBag", Config.BAG) .. "  " .. Format.number(state.bagPrice), Size = UDim2.fromScale(1, 1), TextWrapped = true, TextSize = 15, TextColor3 = c.gold, ZIndex = 53, Parent = below })
		end
	end

	---------------------------------------------------------------- storage
	local function stashModal()
		local content = openModal("stash", T("stash"), UDim2.fromOffset(820, 560))
		local function grid(parent, slots, count, onTap)
			local g = UI.scroll({ Size = UDim2.fromScale(1, 1), ZIndex = 53, Parent = parent })
			UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(62, 62), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = g })
			for i = 1, count do
				local w = slotWidget(g, 62, i)
				w.button.ZIndex = 54
				w.set(slots[i], false)
				w.button.Activated:Connect(function() onTap(i) end)
			end
		end
		local left = UI.frame({ Size = UDim2.new(0.42, -8, 1, -40), Position = UDim2.fromOffset(0, 34), BackgroundColor3 = c.card, BackgroundTransparency = 0.5, ZIndex = 53, Parent = content })
		UI.corner(left, 12)
		UI.pad(left, 6)
		UI.text({ Text = T("yourItems"), Size = UDim2.new(0.42, 0, 0, 28), TextSize = 17, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local invCount = Config.HOTBAR + Config.bagSlots(state.bag)
		grid(left, state.slots, invCount, function(i) if state.slots[i] then act("stashPut", i) end end)
		local right = UI.frame({ Size = UDim2.new(0.58, -8, 1, -40), Position = UDim2.new(0.42, 8, 0, 34), BackgroundColor3 = c.card, BackgroundTransparency = 0.5, ZIndex = 53, Parent = content })
		UI.corner(right, 12)
		UI.pad(right, 6)
		local stash = state.stash or {}
		UI.text({ Text = T("stash") .. "  " .. #stash .. "  |  " .. T("tapToMove"), Size = UDim2.new(0.58, -150, 0, 28), Position = UDim2.new(0.42, 8, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		grid(right, stash, #stash, function(j) if stash[j] then act("stashTake", j) end end)
		if state.stashCost then
			local up = UI.button({ Text = T("upgradeStash") .. "  " .. Format.number(state.stashCost), Size = UDim2.fromOffset(150, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, -2), BackgroundColor3 = c.gold, TextSize = 15, ZIndex = 54, Parent = content }, function()
				act("stashUpgrade")
			end)
		end
	end

	-- a crate's contents (its own items, not your storage)
	local crateOpen = nil -- { id, view }
	local function crateModal()
		if not crateOpen then return end
		local id, v = crateOpen.id, crateOpen.view
		local content = openModal("crate", T("o_crate"), UDim2.fromOffset(520, 460))
		UI.text({ Text = T("crateTip"), Size = UDim2.new(1, 0, 0, 24), TextSize = 15, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local box = UI.frame({ Size = UDim2.new(1, 0, 1, -96), Position = UDim2.fromOffset(0, 30), BackgroundColor3 = c.card, BackgroundTransparency = 0.5, ZIndex = 53, Parent = content })
		UI.corner(box, 12)
		UI.pad(box, 8)
		local g = UI.scroll({ Size = UDim2.fromScale(1, 1), ZIndex = 53, Parent = box })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(74, 74), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = g })
		if (v.coins or 0) > 0 then
			local cb = UI.button({ Text = "", LayoutOrder = 0, BackgroundColor3 = c.card2, ZIndex = 54, Parent = g }, function() act("crateTake", id, 0) end)
			Icons.draw("coin", cb, 38, c.gold, UDim2.new(0.5, 0, 0.42, 0), Vector2.new(0.5, 0.5))
			UI.text({ Text = Format.number(v.coins), Size = UDim2.new(1, -6, 0, 18), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), TextSize = 15, TextColor3 = c.gold, ZIndex = 56, Parent = cb })
		end
		for i, it in ipairs(v.items or {}) do
			local w = slotWidget(g, 74, i)
			w.button.ZIndex = 54
			w.set({ id = it.id, n = it.n }, false)
			w.button.Activated:Connect(function() act("crateTake", id, i) end)
		end
		if (v.coins or 0) == 0 and #(v.items or {}) == 0 then
			UI.text({ Text = T("crateEmpty"), Size = UDim2.new(1, 0, 0, 60), TextColor3 = c.dim, ZIndex = 55, Parent = g })
		end
		UI.button({ Text = T("takeAll"), Size = UDim2.new(1, 0, 0, 54), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = c.gold, TextColor3 = c.bg, TextSize = 20, ZIndex = 54, Parent = content }, function()
			act("crateTake", id, "all")
		end)
	end

	local shopTab = "buy"
	local shopCat = "tools"
	local shopId = "forest"
	local camState = nil
	local bars = nil
	function cinematic(on)
		local cam = workspace.CurrentCamera
		if not cam then return end
		if on and not camState then
			-- the trader nearest to the player (camp, outposts or the secret markets)
			local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local hrp, best
			for _, folderName in ipairs({ "Camp", "Outposts", "BlackMarkets", "Villages", "UnderCamps" }) do
				local f = workspace:FindFirstChild(folderName)
				if f then
					for _, d in ipairs(f:GetDescendants()) do
						if d:IsA("Model") and d.Name == "Trader" then
							local r = d:FindFirstChild("HumanoidRootPart")
							local dist = r and me and (r.Position - me.Position).Magnitude or math.huge
							if r and (not best or dist < best) then hrp, best = r, dist end
						end
					end
				end
			end
			if not hrp or (best or math.huge) > 60 then return end
			camState = { type = cam.CameraType, cf = cam.CFrame }
			local look = hrp.CFrame.LookVector
			local up = Vector3.new(0, 1, 0)
			local camRight = (-look):Cross(up).Unit
			local focus = hrp.Position + Vector3.new(0, 0.5, 0)
			local pos = focus + look * 11 + camRight * 1.5 + up * 2.5
			local target = focus + camRight * 3.4 - up * 0.6
			cam.CameraType = Enum.CameraType.Scriptable
			UI.tween(cam, 0.9, { CFrame = CFrame.lookAt(pos, target), FieldOfView = 50 }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
			bars = {}
			for _, top in ipairs({ true, false }) do
				local b = UI.frame({ Size = UDim2.new(1, 0, 0.09, 0), AnchorPoint = Vector2.new(0, top and 1 or 0), Position = UDim2.fromScale(0, top and 0 or 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 40, Parent = gui })
				UI.tween(b, 0.6, { AnchorPoint = Vector2.new(0, top and 0 or 1) })
				table.insert(bars, b)
			end
			hotbar.Visible, hud.Visible, vitals.Visible = false, false, false
			if mini then mini.Visible = false end
		elseif not on and camState then
			local st = camState
			camState = nil
			local char = player.Character
			local head = char and char:FindFirstChild("Head")
			local back = head and CFrame.lookAt(head.Position - head.CFrame.LookVector * 12 + Vector3.new(0, 4, 0), head.Position) or st.cf
			local t = UI.tween(cam, 0.6, { CFrame = back, FieldOfView = 70 }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
			t.Completed:Connect(function()
				if not camState then cam.CameraType = Enum.CameraType.Custom end
			end)
			for _, b in ipairs(bars or {}) do
				UI.tween(b, 0.4, { AnchorPoint = Vector2.new(0, b.AnchorPoint.Y == 0 and 1 or 0) })
				task.delay(0.45, function() b:Destroy() end)
			end
			bars = nil
			hotbar.Visible, hud.Visible, vitals.Visible = true, true, true
			if mini then mini.Visible = true end
		end
	end
	local function shopModal()
		local content, panel = openModal("shop", (shopId == "black" and T("o_black")) or (shopId == "dwarf" and T("o_dwarf")) or T("o_vendor"), UDim2.fromOffset(540, 560))
		cinematic(true)
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.new(1, -28, 0.5, 0)
		local overlay = panel.Parent
		task.delay(0.22, function() if overlay.Parent then UI.tween(overlay, 0.3, { BackgroundTransparency = 1 }) end end)
		local tabs = UI.frame({ Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.list(tabs, 8, Enum.FillDirection.Horizontal, lang == "ar" and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left)
		for _, t in ipairs({ { "buy", T("buy") }, { "sell", T("sell") } }) do
			UI.button({ Text = t[2], Size = UDim2.fromOffset(140, 40), BackgroundColor3 = shopTab == t[1] and c.accent or c.card, TextColor3 = shopTab == t[1] and c.bg or c.text, TextSize = 19, ZIndex = 54, Parent = tabs }, function()
				shopTab = t[1]
				rebuilding = true
				shopModal()
				rebuilding = false
			end)
		end
		local money = UI.frame({ Size = UDim2.fromOffset(150, 40), AnchorPoint = Vector2.new(lang == "ar" and 0 or 1, 0), Position = UDim2.new(lang == "ar" and 0 or 1, 0, 0, 2), BackgroundColor3 = c.card, ZIndex = 53, Parent = content })
		UI.corner(money, 20)
		Icons.draw("coin", money, 20, c.gold, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
		UI.text({ Text = Format.number(state.coins), Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(36, 0), TextSize = 20, TextColor3 = c.gold, ZIndex = 54, Parent = money })
		local listTop = 52
		if shopTab == "buy" then
			local cats = UI.frame({ Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 50), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
			UI.list(cats, 6, Enum.FillDirection.Horizontal, lang == "ar" and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left)
			local catList = Items.shops[shopId] or Items.shopCats
			local valid = false
			for _, cat in ipairs(catList) do if cat.key == shopCat then valid = true end end
			if not valid then shopCat = catList[1].key end
			for _, cat in ipairs(catList) do
				local on = shopCat == cat.key
				UI.button({ Text = T("cat_" .. cat.key), Size = UDim2.fromOffset(112, 36), TextSize = 16, BackgroundColor3 = on and c.gold or c.card, TextColor3 = on and c.bg or c.text, ZIndex = 54, Parent = cats }, function()
					shopCat = cat.key
					rebuilding = true
					shopModal()
					rebuilding = false
				end)
			end
			listTop = 96
		end
		local list = UI.scroll({ Size = UDim2.new(1, 0, 1, -listTop - 2), Position = UDim2.fromOffset(0, listTop), ZIndex = 53, Parent = content })
		UI.list(list, 8)
		local n = 0
		local function row(id, name, price, btnText, btnColor, cb)
			n += 1
			local r = UI.frame({ Size = UDim2.new(1, -8, 0, 66), BackgroundColor3 = c.card, ZIndex = 53, Parent = list })
			UI.corner(r, 12)
			local iconX = lang == "ar" and 1 or 0
			local holder = UI.frame({ Size = UDim2.fromOffset(56, 56), AnchorPoint = Vector2.new(iconX, 0.5), Position = UDim2.new(iconX, lang == "ar" and -6 or 6, 0.5, 0), BackgroundColor3 = c.panel, ZIndex = 54, Parent = r })
			UI.corner(holder, 10)
			if id then ItemView.new(holder, id, UDim2.fromScale(1, 1), nil, 55) else Icons.draw("bag", holder, 34, c.gold, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)) end
			UI.text({ Text = name, Size = UDim2.new(0.5, 0, 0, 30), Position = UDim2.new(lang == "ar" and 0.5 or 0, lang == "ar" and -72 or 72, 0, 6), AnchorPoint = Vector2.new(lang == "ar" and 0.5 or 0, 0), TextXAlignment = UI.align(lang), TextSize = 18, ZIndex = 54, Parent = r })
			local pf = UI.frame({ Size = UDim2.new(0.4, 0, 0, 22), Position = UDim2.new(lang == "ar" and 0.5 or 0, lang == "ar" and -72 or 72, 0, 38), AnchorPoint = Vector2.new(lang == "ar" and 0.5 or 0, 0), BackgroundTransparency = 1, ZIndex = 54, Parent = r })
			Icons.draw("coin", pf, 16, c.gold, UDim2.new(lang == "ar" and 1 or 0, lang == "ar" and -16 or 0, 0.5, 0), Vector2.new(0, 0.5))
			UI.text({ Text = price, Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(lang == "ar" and 0 or 22, 0), TextXAlignment = UI.align(lang), TextSize = 15, TextColor3 = c.gold, ZIndex = 55, Parent = pf })
			local bx = lang == "ar" and 0 or 1
			UI.button({ Text = btnText, Size = UDim2.fromOffset(116, 42), AnchorPoint = Vector2.new(bx, 0.5), Position = UDim2.new(bx, lang == "ar" and 10 or -10, 0.5, 0), BackgroundColor3 = btnColor, TextSize = 17, ZIndex = 55, Parent = r }, cb)
			UI.enter(r, n * 0.03, 10)
		end
		if shopTab == "buy" then
			if not state.bag and shopCat == "supplies" and shopId == "forest" then
				row(nil, Locale.f(lang, "buyBag", Config.BAG), Format.number(state.bagPrice), T("buy"), c.gold, function() act("buyBag") end)
			end
			if state.bag ~= "big" and shopCat == "supplies" and shopId == "dwarf" then
				row(nil, Locale.f(lang, "buyBigBag", Config.BIG_BAG), Format.number(Config.BIG_BAG_PRICE), T("buy"), state.coins >= Config.BIG_BAG_PRICE and c.gold or c.card2, function() act("buyBigBag") end)
			end
			local ids = {}
			for _, cat in ipairs(Items.shops[shopId] or Items.shopCats) do
				if cat.key == shopCat then ids = cat.ids end
			end
			local owned = {}
			for _, sl in ipairs(state.slots) do if sl then owned[sl.id] = (owned[sl.id] or 0) + sl.n end end
			if state.armor then owned[state.armor] = (owned[state.armor] or 0) + 1 end
			for _, id in ipairs(ids) do
				local d = Items.get(id)
				local qty = d.buyQty and (" x" .. d.buyQty) or ""
				local stats = {}
				if d.dmg then table.insert(stats, T("st_dmg") .. " " .. d.dmg) end
				if d.class == "axe" then table.insert(stats, T("st_power") .. " " .. d.tree) end
				if d.class == "pickaxe" then table.insert(stats, T("st_power") .. " " .. d.rock) end
				if d.kind == "light" then table.insert(stats, T("st_time") .. " " .. string.format("%d:00", d.dur // 60))
				elseif d.kind == "potion" then table.insert(stats, T("buff_" .. d.buff) .. " " .. string.format("%d:%02d", d.time // 60, d.time % 60))
				elseif d.dur then table.insert(stats, T("st_dur") .. " " .. d.dur) end
				if d.reduce then table.insert(stats, T("st_armor") .. " " .. math.floor(d.reduce * 100) .. "%") end
				if owned[id] then table.insert(stats, T("owned") .. " " .. owned[id]) end
				local price = tostring(d.buy) .. ((#stats > 0) and ("   |   " .. table.concat(stats, "  -  ")) or "")
				row(id, Items.name(id, lang) .. qty, price, T("buy"), state.coins >= d.buy and c.accent or c.card2, function() act("buy", id, shopId) end)
			end
		else
			local totals, order = {}, {}
			for _, s in ipairs(state.slots) do
				if s and Items.get(s.id).sell then
					if not totals[s.id] then totals[s.id] = 0 table.insert(order, s.id) end
					totals[s.id] += s.n
				end
			end
			if #order == 0 then UI.text({ Text = T("empty"), Size = UDim2.new(1, 0, 0, 60), TextColor3 = c.dim, ZIndex = 53, Parent = list }) end
			for _, id in ipairs(order) do
				local d = Items.get(id)
				row(id, Items.name(id, lang) .. "  x" .. totals[id], tostring(d.sell * totals[id]), T("sellAll"), c.gold, function() act("sell", id) end)
			end
		end
	end

	---------------------------------------------------------------- creature index
	local indexTab = "forest"
	local TYPE_COLOR = { peaceful = Color3.fromRGB(110, 200, 120), predator = Color3.fromRGB(240, 150, 70), night = Color3.fromRGB(150, 130, 240),
		cave = Color3.fromRGB(170, 110, 255), boss = Color3.fromRGB(255, 200, 70), outlaw = Color3.fromRGB(230, 80, 80) }
	local function mobView(parent, kind)
		local f = ReplicatedStorage:FindFirstChild("MobTemplates")
		local tpl = f and f:FindFirstChild(kind)
		if not tpl then return end
		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.fromScale(1, 1)
		vp.BackgroundTransparency = 1
		vp.Ambient = Color3.fromRGB(170, 170, 175)
		vp.LightColor = Color3.fromRGB(255, 245, 230)
		vp.LightDirection = Vector3.new(-1, -2, -1)
		vp.ZIndex = parent.ZIndex + 1
		vp.Parent = parent
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		cam.Parent = vp
		vp.CurrentCamera = cam
		local m = tpl:Clone()
		m.Parent = vp
		local cf, sz = m:GetBoundingBox()
		local dist = (sz.Magnitude / 2) / math.tan(math.rad(15)) * 1.05
		local dir = Vector3.new(-1.1, 0.55, -1.3).Unit -- three-quarter view from the front
		cam.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
	end
	-- region necklaces: a round medal with a picture of the region (one image sheet)
	local MEDALS = "rbxassetid://96932926831657"
	local MEDAL_AT = { forest = { 0, 0 }, hills = { 256, 0 }, snow = { 512, 0 }, desert = { 768, 0 }, mountains = { 0, 256 },
		beach = { 256, 256 }, jungle = { 512, 256 }, volcano = { 768, 256 }, caves = { 0, 512 }, bandits = { 256, 512 } }
	local function medalImage(parent, key, size, got, pos, anchor)
		local at = MEDAL_AT[key] or MEDAL_AT.forest
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromOffset(size, size)
		img.Position = pos or UDim2.fromScale(0.5, 0.5)
		img.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
		img.Image = MEDALS
		img.ImageRectOffset = Vector2.new(at[1], at[2])
		img.ImageRectSize = Vector2.new(256, 256)
		img.ImageColor3 = got and Color3.new(1, 1, 1) or Color3.fromRGB(80, 84, 88)
		img.ImageTransparency = got and 0 or 0.15
		img.ZIndex = parent.ZIndex + 1
		img.Parent = parent
		return img
	end
	local indexSel = nil -- the creature shown on the right
	local indexSpin = nil
	local function indexModal()
		local content = openModal("index", T("index"), UDim2.fromOffset(960, 560))
		if indexSpin then indexSpin:Disconnect() indexSpin = nil end
		local dex = state.dex or { seen = {}, kills = {}, medals = {} }
		dex.seen, dex.kills, dex.medals = dex.seen or {}, dex.kills or {}, dex.medals or {}
		local seenN = 0
		for _ in pairs(dex.seen) do seenN += 1 end
		local reg = Bestiary.region(indexTab) or Bestiary.regions[1]
		if not indexSel or not table.find(reg.kinds, indexSel) then indexSel = reg.kinds[1] end
		local LW, GAP = 560, 16
		local left = UI.frame({ Size = UDim2.new(0, LW, 1, 0), BackgroundTransparency = 1, ZIndex = 52, Parent = content })
		local right = UI.frame({ Size = UDim2.new(1, -(LW + GAP), 1, 0), Position = UDim2.fromOffset(LW + GAP, 0), BackgroundColor3 = c.card, ZIndex = 52, Parent = content })
		UI.corner(right, 14)

		-- left: count, region tabs (two rows), the region's necklace, creature cards
		-- how many creatures you have discovered: in all, and in this region
		local regSeen = 0
		for _, k in ipairs(reg.kinds) do if dex.seen[k] then regSeen += 1 end end
		local head = UI.frame({ Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = c.card, ZIndex = 53, Parent = left })
		UI.corner(head, 17)
		local ar0 = lang == "ar"
		Icons.draw("book", head, 20, c.gold, UDim2.new(ar0 and 1 or 0, ar0 and -12 or 12, 0.5, 0), Vector2.new(ar0 and 1 or 0, 0.5))
		UI.text({ Text = Locale.f(lang, "found", seenN, Bestiary.total()), Size = UDim2.fromOffset(190, 34), AnchorPoint = Vector2.new(ar0 and 1 or 0, 0), Position = UDim2.new(ar0 and 1 or 0, ar0 and -42 or 42, 0, 0), TextXAlignment = UI.align(lang), TextSize = 15, TextColor3 = c.gold, ZIndex = 54, Parent = head })
		local hb = UI.frame({ Size = UDim2.new(1, -420, 0, 8), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, ar0 and -50 or 50, 0.5, 0), BackgroundColor3 = c.bg, ZIndex = 54, Parent = head })
		UI.corner(hb, 4)
		local hf = UI.frame({ Size = UDim2.fromScale(seenN / math.max(1, Bestiary.total()), 1), AnchorPoint = Vector2.new(ar0 and 1 or 0, 0), Position = UDim2.fromScale(ar0 and 1 or 0, 0), BackgroundColor3 = c.gold, ZIndex = 55, Parent = hb })
		UI.corner(hf, 4)
		UI.text({ Text = T("biome_" .. reg.key) .. "  " .. regSeen .. " / " .. #reg.kinds, Size = UDim2.fromOffset(130, 34), AnchorPoint = Vector2.new(ar0 and 0 or 1, 0), Position = UDim2.new(ar0 and 0 or 1, ar0 and 14 or -14, 0, 0), TextXAlignment = ar0 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, TextSize = 15, TextColor3 = regSeen == #reg.kinds and c.accent or c.text, ZIndex = 54, Parent = head })
		local tabs = UI.frame({ Size = UDim2.new(1, 0, 0, 72), Position = UDim2.fromOffset(0, 40), BackgroundTransparency = 1, ZIndex = 53, Parent = left })
		local tg = Instance.new("UIGridLayout")
		tg.CellSize = UDim2.new(0.2, -5, 0, 33)
		tg.CellPadding = UDim2.fromOffset(6, 6)
		tg.SortOrder = Enum.SortOrder.LayoutOrder
		tg.HorizontalAlignment = lang == "ar" and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
		tg.Parent = tabs
		for i, rg in ipairs(Bestiary.regions) do
			local on = indexTab == rg.key
			local b = UI.button({ Text = T("biome_" .. rg.key), LayoutOrder = i, TextSize = 14, BackgroundColor3 = on and c.gold or c.card, TextColor3 = on and c.bg or c.text, ZIndex = 54, Parent = tabs }, function()
				indexTab = rg.key
				indexSel = nil
				indexModal()
			end)
			if dex.medals[rg.key] then
				local dot = UI.frame({ Size = UDim2.fromOffset(8, 8), Position = UDim2.new(1, -12, 0, 4), BackgroundColor3 = Biomes.medal[rg.key] or c.gold, ZIndex = 56, Parent = b })
				UI.corner(dot, 4)
			end
		end
		local got = dex.medals[reg.key]
		local killedKinds = 0
		for _, k in ipairs(reg.kinds) do if (dex.kills[k] or 0) > 0 then killedKinds += 1 end end
		local medal = UI.frame({ Size = UDim2.new(1, 0, 0, 76), Position = UDim2.fromOffset(0, 118), BackgroundColor3 = c.card, ZIndex = 53, Parent = left })
		UI.corner(medal, 12)
		local ar = lang == "ar"
		medalImage(medal, reg.key, 64, got, UDim2.new(ar and 1 or 0, ar and -42 or 42, 0.5, 0))
		local tx = ar and -84 or 84
		UI.text({ Text = Locale.f(lang, "medal", T("biome_" .. reg.key)), Size = UDim2.new(1, -220, 0, 24), Position = UDim2.new(ar and 1 or 0, tx, 0, 10), AnchorPoint = Vector2.new(ar and 1 or 0, 0), TextXAlignment = UI.align(lang), TextSize = 17, TextColor3 = got and (Biomes.medal[reg.key] or c.gold) or c.text, ZIndex = 54, Parent = medal })
		local bar = UI.frame({ Size = UDim2.new(1, -220, 0, 10), Position = UDim2.new(ar and 1 or 0, tx, 0, 40), AnchorPoint = Vector2.new(ar and 1 or 0, 0), BackgroundColor3 = c.bg, ZIndex = 54, Parent = medal })
		UI.corner(bar, 5)
		local fill = UI.frame({ Size = UDim2.fromScale(killedKinds / math.max(1, #reg.kinds), 1), AnchorPoint = Vector2.new(ar and 1 or 0, 0), Position = UDim2.fromScale(ar and 1 or 0, 0), BackgroundColor3 = got and (Biomes.medal[reg.key] or c.gold) or c.accent, ZIndex = 55, Parent = bar })
		UI.corner(fill, 5)
		UI.text({ Text = got and T("medalGot") or (killedKinds .. " / " .. #reg.kinds .. "   " .. T("medalNeed")), Size = UDim2.new(1, -220, 0, 16), Position = UDim2.new(ar and 1 or 0, tx, 0, 54), AnchorPoint = Vector2.new(ar and 1 or 0, 0), TextXAlignment = UI.align(lang), TextSize = 12, TextColor3 = c.dim, ZIndex = 54, Parent = medal })
		if got then
			local wearing = dex.neck == reg.key
			UI.button({ Text = wearing and T("wearing") or T("wear"), Size = UDim2.fromOffset(110, 40), AnchorPoint = Vector2.new(ar and 0 or 1, 0.5), Position = UDim2.new(ar and 0 or 1, ar and 12 or -12, 0.5, 0), BackgroundColor3 = wearing and c.card2 or c.gold, TextColor3 = wearing and c.text or c.bg, TextSize = 16, ZIndex = 55, Parent = medal }, function()
				if not wearing then act("wearMedal", reg.key) end
			end)
		end
		local grid = UI.scroll({ Size = UDim2.new(1, 0, 1, -204), Position = UDim2.fromOffset(0, 204), ZIndex = 53, Parent = left })
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 4), UDim.new(0, 8), UDim.new(0, 4), UDim.new(0, 10)
		pad.Parent = grid
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(128, 132)
		gl.CellPadding = UDim2.fromOffset(8, 8)
		gl.HorizontalAlignment = ar and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = grid

		-- right: details of the chosen creature
		local function details(kind)
			for _, ch in ipairs(right:GetChildren()) do if not ch:IsA("UICorner") then ch:Destroy() end end
			if indexSpin then indexSpin:Disconnect() indexSpin = nil end
			local seen = kind and dex.seen[kind]
			local view = UI.frame({ Size = UDim2.new(1, -20, 0, 210), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = c.bg, ZIndex = 53, Parent = right })
			UI.corner(view, 12)
			if not seen then
				UI.text({ Text = "?", Size = UDim2.fromScale(1, 1), TextSize = 90, TextColor3 = c.card2, ZIndex = 54, Parent = view })
				UI.text({ Text = kind and T("unknown") or T("pickCreature"), Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, 236), TextWrapped = true, TextSize = 18, TextColor3 = c.dim, ZIndex = 53, Parent = right })
				return
			end
			mobView(view, kind)
			local vp = view:FindFirstChildWhichIsA("ViewportFrame")
			local cam = vp and vp.CurrentCamera
			if cam then
				-- turn slowly so the whole creature can be seen
				local m = vp:FindFirstChildWhichIsA("Model")
				local cf, sz = m:GetBoundingBox()
				local dist = (sz.Magnitude / 2) / math.tan(math.rad(15)) * 1.0
				local t0 = os.clock()
				indexSpin = RunService.Heartbeat:Connect(function()
					if not vp.Parent then indexSpin:Disconnect() indexSpin = nil return end
					local a = math.rad(210) + (os.clock() - t0) * 0.5
					cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(math.sin(a), 0.42, math.cos(a)).Unit * dist, cf.Position)
				end)
			end
			local ty = Bestiary.kinds[kind]
			local col = TYPE_COLOR[ty] or c.card2
			local info = UI.scroll({ Size = UDim2.new(1, -20, 1, -234), Position = UDim2.fromOffset(10, 228), ZIndex = 53, Parent = right })
			UI.list(info, 6)
			local n = 0
			local function line(props)
				n += 1
				props.LayoutOrder = n
				props.Size = props.Size or UDim2.new(1, -8, 0, 0)
				props.AutomaticSize = Enum.AutomaticSize.Y
				props.TextWrapped = true
				props.TextXAlignment = UI.align(lang)
				props.ZIndex = 54
				props.Parent = info
				return UI.text(props)
			end
			line({ Text = T("mob_" .. kind), TextSize = 26, TextColor3 = c.text })
			n += 1
			local chipRow = UI.frame({ Size = UDim2.new(1, -8, 0, 24), LayoutOrder = n, BackgroundTransparency = 1, ZIndex = 54, Parent = info })
			local chip = UI.frame({ Size = UDim2.fromOffset(110, 24), AnchorPoint = Vector2.new(ar and 1 or 0, 0), Position = UDim2.fromScale(ar and 1 or 0, 0), BackgroundColor3 = col, ZIndex = 55, Parent = chipRow })
			UI.corner(chip, 12)
			UI.text({ Text = T("ty_" .. ty), Size = UDim2.fromScale(1, 1), TextSize = 14, TextColor3 = c.bg, ZIndex = 56, Parent = chip })
			UI.text({ Text = Locale.f(lang, "kills", dex.kills[kind] or 0), Size = UDim2.new(1, -124, 1, 0), Position = UDim2.fromOffset(ar and 0 or 124, 0), TextXAlignment = UI.align(lang), TextSize = 15, TextColor3 = c.dim, ZIndex = 55, Parent = chipRow })
			line({ Text = T("tyd_" .. ty), TextSize = 16, TextColor3 = c.dim })
			local homes = {}
			for _, h in ipairs(Bestiary.homes(kind)) do table.insert(homes, T("biome_" .. h)) end
			line({ Text = T("livesIn") .. ":  " .. table.concat(homes, ar and "، " or ", "), TextSize = 16, TextColor3 = c.text })
			local ab = Bestiary.abilities[kind]
			if ab then
				line({ Text = T("abilities"), TextSize = 18, TextColor3 = c.gold })
				for _, a in ipairs(ab) do line({ Text = "•  " .. T("ab_" .. a), TextSize = 15, TextColor3 = c.text }) end
				local w = Locale.t(lang, "weak_" .. kind)
				if (dex.kills[kind] or 0) > 0 and w ~= "weak_" .. kind then
					line({ Text = Locale.f(lang, "weakness", w), TextSize = 16, TextColor3 = Color3.fromRGB(255, 140, 110) })
				else
					line({ Text = T("weakHidden"), TextSize = 15, TextColor3 = c.dim })
				end
			end
		end

		for i, kind in ipairs(reg.kinds) do
			local seen = dex.seen[kind]
			local ty = Bestiary.kinds[kind]
			local on = kind == indexSel
			local card = UI.button({ Text = "", LayoutOrder = i, BackgroundColor3 = on and c.card2 or (seen and c.card or c.panel), AutoButtonColor = true, ZIndex = 54, Parent = grid }, function()
				indexSel = kind
				for _, cd in ipairs(grid:GetChildren()) do
					if cd:IsA("GuiButton") then
						local st = cd:FindFirstChildWhichIsA("UIStroke")
						local mine = cd:GetAttribute("Kind") == kind
						cd.BackgroundColor3 = mine and c.card2 or (dex.seen[cd:GetAttribute("Kind")] and c.card or c.panel)
						if st then st.Thickness = mine and 3 or 1.5 st.Color = mine and c.gold or (cd:GetAttribute("Col") or c.card2) end
					end
				end
				details(kind)
			end)
			card:SetAttribute("Kind", kind)
			local sc = seen and (TYPE_COLOR[ty] or c.card2) or c.card2
			card:SetAttribute("Col", sc)
			UI.corner(card, 12)
			UI.stroke(card, on and c.gold or sc, on and 3 or 1.5)
			local view = UI.frame({ Size = UDim2.new(1, -12, 0, 90), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = c.bg, ZIndex = 55, Parent = card })
			UI.corner(view, 10)
			if seen then
				mobView(view, kind)
				UI.text({ Text = T("mob_" .. kind), Size = UDim2.new(1, -10, 0, 30), Position = UDim2.fromOffset(5, 98), TextTruncate = Enum.TextTruncate.AtEnd, TextSize = 15, ZIndex = 55, Parent = card })
				local dot = UI.frame({ Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = TYPE_COLOR[ty] or c.card2, ZIndex = 57, Parent = card })
				UI.corner(dot, 5)
			else
				UI.text({ Text = "?", Size = UDim2.fromScale(1, 1), TextSize = 44, TextColor3 = c.card2, ZIndex = 56, Parent = view })
				UI.text({ Text = T("unknown"), Size = UDim2.new(1, -10, 0, 30), Position = UDim2.fromOffset(5, 98), TextSize = 14, TextColor3 = c.dim, ZIndex = 55, Parent = card })
			end
		end
		details(indexSel)
	end

	---------------------------------------------------------------- world map (only what you have explored)
	local mapPoisList, mapExplored, mapExplored2, caveMask, maskN = {}, "", "", "", 96
	-- which map to show: the caves map once you are deep underground
	local function currentLayer()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		return (hrp and hrp.Position.Y < -26) and "under" or "surface"
	end
	local CAVE_COLOR = {
		forest = Color3.fromRGB(128, 112, 92), hills = Color3.fromRGB(128, 112, 92), mountains = Color3.fromRGB(112, 112, 124),
		snow = Color3.fromRGB(170, 205, 228), desert = Color3.fromRGB(204, 172, 120), jungle = Color3.fromRGB(74, 118, 82),
		volcano = Color3.fromRGB(160, 74, 40), beach = Color3.fromRGB(196, 186, 156),
	}
	local ROCK = Color3.fromRGB(34, 32, 36)
	local cellColor, terrainColor, caveColor -- defined just below
	-- draws the explored part of a layer into `parent` (px = pixels per map cell).
	-- Each row is drawn as a few long strips of one colour (not one frame per cell), and only
	-- rows whose explored cells changed are redrawn, so switching maps stays smooth.
	local function drawLayer(parent, px, layer, z, cache)
		local N = Config.MAP_CELLS
		local H = Biomes.HALF
		local ex = layer == "under" and mapExplored2 or mapExplored
		cache = cache or {}
		cache.rows = cache.rows or {}
		cache.sig = cache.sig or {}
		if #ex < N * N then return cache end
		local fine = layer == "under" and #caveMask == maskN * maskN
		local sub = fine and maskN // N or 1
		local R = N * sub -- rows / columns at drawing resolution
		local step = px / sub
		for cz = 0, N - 1 do
			local sig = ex:sub(cz * N + 1, cz * N + N)
			if cache.sig[cz] ~= sig then
				cache.sig[cz] = sig
				for _, f in ipairs(cache.rows[cz] or {}) do f:Destroy() end
				local frames = {}
				cache.rows[cz] = frames
				if sig:find("1", 1, true) then
					for rz = cz * sub, cz * sub + sub - 1 do
						local runStart, runColor = nil, nil
						local function flush(endX)
							if runStart then
								table.insert(frames, UI.frame({ Size = UDim2.fromOffset(math.ceil((endX - runStart) * step) + 1, math.ceil(step) + 1), Position = UDim2.fromOffset(math.floor(runStart * step), math.floor(rz * step)), BackgroundColor3 = runColor, BorderSizePixel = 0, ZIndex = z, Parent = parent }))
							end
							runStart, runColor = nil, nil
						end
						for rx = 0, R do
							local col = nil
							if rx < R then
								local cx = rx // sub
								if sig:sub(cx + 1, cx + 1) == "1" then
									local wx, wz = -H + (rx + 0.5) * (2 * H / R), -H + (rz + 0.5) * (2 * H / R)
									if layer == "under" and caveColor(rx, rz, R) then
										col = caveColor(rx, rz, R)
									elseif fine then
										local k = rz * maskN + rx + 1
										col = caveMask:sub(k, k) == "1" and (CAVE_COLOR[Biomes.at(wx, wz)] or CAVE_COLOR.forest) or ROCK
									elseif layer == "under" then
										col = ROCK
									else
										col = terrainColor(rx, rz, R) or cellColor(wx, wz)
									end
								end
							end
							if col ~= runColor then
								flush(rx)
								if col then runStart, runColor = rx, col end
							end
						end
					end
				end
			end
		end
		return cache
	end
	local POI_ICON = { village = { "village", Color3.fromRGB(242, 193, 78) }, trader = { "coin", Color3.fromRGB(255, 210, 90) }, cave = { "cave", Color3.fromRGB(170, 150, 200) },
		dwarf = { "coin", Color3.fromRGB(255, 170, 70) }, camp = { "home", Color3.fromRGB(255, 200, 120) }, ruins = { "medal", Color3.fromRGB(242, 193, 78) } }
	local function poiLayer(poi) return poi[4] == "under" and "under" or "surface" end
	local REGION_COLOR = {
		forest = Color3.fromRGB(70, 128, 60), hills = Color3.fromRGB(128, 156, 88), snow = Color3.fromRGB(226, 232, 240),
		desert = Color3.fromRGB(218, 188, 128), mountains = Color3.fromRGB(128, 128, 138), beach = Color3.fromRGB(224, 208, 158),
		jungle = Color3.fromRGB(36, 104, 58), volcano = Color3.fromRGB(82, 52, 46),
	}
	local SEA = Color3.fromRGB(44, 92, 140)
	-- the real ground of each map cell, sampled from the world (workspace TerrainMap)
	local TPAL = { Color3.fromRGB(30, 78, 130), Color3.fromRGB(52, 110, 170), Color3.fromRGB(86, 140, 66), Color3.fromRGB(44, 104, 58),
		Color3.fromRGB(120, 100, 70), Color3.fromRGB(96, 78, 56), Color3.fromRGB(222, 200, 140), Color3.fromRGB(196, 150, 100),
		Color3.fromRGB(236, 242, 248), Color3.fromRGB(180, 214, 236), Color3.fromRGB(128, 128, 134), Color3.fromRGB(230, 96, 30),
		Color3.fromRGB(70, 62, 62), Color3.fromRGB(200, 196, 180), Color3.fromRGB(190, 160, 112), Color3.fromRGB(168, 78, 54) }
	local TSHADE = { 0.86, 0.94, 1, 1.08 }
	local tcache = {}
	function terrainColor(rx, rz, R)
		local tm = workspace:GetAttribute("TerrainMap")
		local tn = workspace:GetAttribute("TerrainMapN")
		if type(tm) ~= "string" or type(tn) ~= "number" or #tm ~= tn * tn then return nil end
		local x, z = rx * tn // R, rz * tn // R
		local k = z * tn + x + 1
		local v = string.byte(tm, k) - 48
		local col = tcache[v]
		if not col then
			local base = TPAL[v // 4 + 1] or TPAL[11]
			local f = TSHADE[v % 4 + 1]
			col = Color3.new(math.min(1, base.R * f), math.min(1, base.G * f), math.min(1, base.B * f))
			tcache[v] = col
		end
		return col
	end
	-- the caves, sampled the same way (workspace CaveMap): floors by material, water, lava, solid rock
	local CPAL = { ROCK, Color3.fromRGB(52, 110, 170), Color3.fromRGB(240, 110, 30), Color3.fromRGB(150, 128, 100), Color3.fromRGB(120, 122, 132),
		Color3.fromRGB(200, 224, 240), Color3.fromRGB(210, 186, 130), Color3.fromRGB(96, 124, 72), Color3.fromRGB(116, 88, 80), Color3.fromRGB(206, 200, 178) }
	local CSHADE = { 0.8, 0.9, 1, 1.1 }
	local ccache = {}
	function caveColor(rx, rz, R)
		local cm = workspace:GetAttribute("CaveMap")
		local tn = workspace:GetAttribute("TerrainMapN")
		if type(cm) ~= "string" or type(tn) ~= "number" or #cm ~= tn * tn then return nil end
		local x, z = rx * tn // R, rz * tn // R
		local v = string.byte(cm, z * tn + x + 1) - 48
		local col = ccache[v]
		if not col then
			local p = v // 4
			local base = CPAL[p + 1] or ROCK
			local f = p == 0 and 1 or CSHADE[v % 4 + 1]
			col = Color3.new(math.min(1, base.R * f), math.min(1, base.G * f), math.min(1, base.B * f))
			ccache[v] = col
		end
		return col
	end
	function cellColor(x, z)
		local d = math.max(math.abs(x), math.abs(z))
		if d > Biomes.SEA then return SEA end
		local col = REGION_COLOR[Biomes.at(x, z)] or REGION_COLOR.forest
		local n = math.floor(math.noise(x / 180, z / 180, 5.5) * 0.18 / 0.06 + 0.5) * 0.06
		if n == 0 then return col end
		return n > 0 and col:Lerp(Color3.new(1, 1, 1), n) or col:Lerp(Color3.new(0, 0, 0), -n)
	end
	local mapCells = {} -- index -> Frame (kept between opens)
	local function mapModal(layerOverride)
		local layer = layerOverride or currentLayer()
		local content = openModal("map", T("map") .. "  |  " .. T(layer == "under" and "mapCaves" or "mapSurface"), UDim2.fromOffset(580, 650))
		local N = Config.MAP_CELLS
		local SIZE = 500
		local cell = SIZE / N
		local H = Biomes.HALF
		local ex = layer == "under" and mapExplored2 or mapExplored
		local seen = 0
		for i = 1, #ex do if ex:sub(i, i) == "1" then seen += 1 end end
		UI.text({ Text = Locale.f(lang, "explored", math.floor(seen / (N * N) * 100 + 0.5)), Size = UDim2.new(0.6, 0, 0, 22), TextXAlignment = UI.align(lang), Position = UDim2.fromScale(lang == "ar" and 0.4 or 0, 0), TextSize = 15, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		-- switch between the surface and cave maps
		UI.button({ Text = T(layer == "under" and "mapSurface" or "mapCaves"), Size = UDim2.fromOffset(120, 24), AnchorPoint = Vector2.new(lang == "ar" and 0 or 1, 0), Position = UDim2.new(lang == "ar" and 0 or 1, 0, 0, -2), TextSize = 14, BackgroundColor3 = c.card2, TextColor3 = c.text, ZIndex = 54, Parent = content }, function()
			mapModal(layer == "under" and "surface" or "under")
		end)
		local board = UI.frame({ Size = UDim2.fromOffset(SIZE, SIZE), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), BackgroundColor3 = Color3.fromRGB(16, 18, 22), ClipsDescendants = true, ZIndex = 53, Parent = content })
		UI.corner(board, 10)
		UI.stroke(board, c.card2, 2)
		local function toMap(x, z)
			return UDim2.fromOffset((x + H) / (2 * H) * SIZE, (z + H) / (2 * H) * SIZE)
		end
		local function explored(x, z)
			local cx, cz = math.floor((x + H) / (2 * H) * N), math.floor((z + H) / (2 * H) * N)
			if cx < 0 or cz < 0 or cx >= N or cz >= N then return false end
			local i = cz * N + cx + 1
			return ex:sub(i, i) == "1"
		end
		-- the explored cells of this layer
		mapCells = drawLayer(board, cell, layer, 54, {})
		-- the mine rails, where you have been
		if layer == "under" then
			local under = workspace:FindFirstChild("Underground")
			local tracks = under and under:FindFirstChild("Tracks")
			for _, t in ipairs(tracks and tracks:GetChildren() or {}) do
				local pts = {}
				for x, _, z in string.gmatch(t:GetAttribute("Points") or "", "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
					local p = Vector2.new(tonumber(x), tonumber(z))
					-- keep only points a few pixels apart (fewer pieces to draw)
					if #pts == 0 or (p - pts[#pts]).Magnitude > 40 then table.insert(pts, p) end
				end
				for k = 2, #pts do
					local a, b = pts[k - 1], pts[k]
					local mid = (a + b) / 2
					if explored(mid.X, mid.Y) then
						local pa = Vector2.new((a.X + H) / (2 * H) * SIZE, (a.Y + H) / (2 * H) * SIZE)
						local pb = Vector2.new((b.X + H) / (2 * H) * SIZE, (b.Y + H) / (2 * H) * SIZE)
						local d = pb - pa
						if d.Magnitude > 0.5 then
							UI.frame({ Size = UDim2.fromOffset(d.Magnitude + 2, 3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((pa.X + pb.X) / 2, (pa.Y + pb.Y) / 2), Rotation = math.deg(math.atan2(d.Y, d.X)), BackgroundColor3 = Color3.fromRGB(176, 120, 70), BorderSizePixel = 0, ZIndex = 55, Parent = board })
						end
					end
				end
			end
		end
		-- places
		local function marker(kind, x, z, color, size)
			local holder = UI.frame({ Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Position = toMap(x, z), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BackgroundTransparency = 0.25, ZIndex = 56, Parent = board })
			UI.corner(holder, size / 2)
			Icons.draw(kind, holder, size * 0.72, color, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			return holder
		end
		for _, poi in ipairs(mapPoisList) do
			local def = POI_ICON[poi[1]]
			-- cave entrances show on both maps
			if def and (poiLayer(poi) == layer or poi[1] == "cave") and explored(poi[2], poi[3]) then marker(def[1], poi[2], poi[3], def[2], 22) end
		end
		if state.death then
			marker("close", state.death[1], state.death[2], Color3.fromRGB(255, 70, 60), 24)
		end
		-- you (an arrow that turns with you) and the other players
		local me = UI.frame({ Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 58, Parent = board })
		local tip = UI.frame({ Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Rotation = 45, BackgroundColor3 = Color3.fromRGB(80, 200, 255), ZIndex = 58, Parent = me })
		UI.stroke(tip, Color3.new(1, 1, 1), 2)
		local nose = UI.frame({ Size = UDim2.fromOffset(6, 10), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.35), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 59, Parent = me })
		UI.corner(nose, 3)
		local meTag = UI.text({ Text = T("leg_you"), Size = UDim2.fromOffset(60, 16), AnchorPoint = Vector2.new(0.5, 1), TextSize = 13, TextColor3 = Color3.fromRGB(120, 210, 255), TextStrokeTransparency = 0.2, ZIndex = 60, Parent = board })
		local others = {}
		-- legend
		local legend = UI.frame({ Size = UDim2.new(1, 0, 0, 34), ClipsDescendants = false, Position = UDim2.new(0, 0, 0, SIZE + 34), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.list(legend, 14, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
		local legendList = layer == "under"
			and { { "coin", Color3.fromRGB(255, 170, 70), "leg_dwarf" }, { "home", Color3.fromRGB(255, 200, 120), "leg_camp" }, { "medal", c.gold, "leg_ruins" }, { "cave", Color3.fromRGB(170, 150, 200), "leg_cave" }, { "close", Color3.fromRGB(255, 70, 60), "leg_death" } }
			or { { "village", c.gold, "leg_village" }, { "coin", Color3.fromRGB(255, 210, 90), "leg_trader" }, { "cave", Color3.fromRGB(170, 150, 200), "leg_cave" }, { "close", Color3.fromRGB(255, 70, 60), "leg_death" }, { "dot", Color3.fromRGB(120, 255, 140), "leg_players" } }
		for _, l in ipairs(legendList) do
			local item = UI.frame({ Size = UDim2.fromOffset(104, 30), BackgroundTransparency = 1, ZIndex = 53, Parent = legend })
			local ic = UI.frame({ Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(20, 20, 24), ZIndex = 54, Parent = item })
			UI.corner(ic, 12)
			Icons.draw(l[1], ic, 17, l[2], UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			UI.text({ Text = T(l[3]), Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(30, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14, ZIndex = 54, Parent = item })
		end
		task.spawn(function()
			while modalKind == "map" and board.Parent do
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					me.Position = toMap(hrp.Position.X, hrp.Position.Z)
					meTag.Position = me.Position - UDim2.fromOffset(0, 10)
					local look = hrp.CFrame.LookVector
					me.Rotation = math.deg(math.atan2(look.X, -look.Z))
				end
				for _, pl in ipairs(Players:GetPlayers()) do
					local r = pl ~= player and not (state and state.pvp) and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
					if r then
						local dot = others[pl]
						if not dot then
							dot = UI.frame({ Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(120, 255, 140), ZIndex = 57, Parent = board })
							UI.corner(dot, 6)
							UI.stroke(dot, Color3.new(0, 0, 0), 1.5)
							UI.text({ Text = pl.DisplayName, Size = UDim2.fromOffset(120, 16), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), TextSize = 13, TextColor3 = Color3.fromRGB(170, 255, 180), TextStrokeTransparency = 0.2, ZIndex = 60, Parent = dot })
							others[pl] = dot
						end
						dot.Position = toMap(r.Position.X, r.Position.Z)
					end
				end
				for pl, dot in pairs(others) do
					if not pl.Parent or not pl.Character then dot:Destroy() others[pl] = nil end
				end
				task.wait(0.1)
			end
		end)
	end

	---------------------------------------------------------------- minimap (top right, follows you; tap it for the full map)
	local MINI = 208
	local VIEW = 420 -- studs shown across the minimap
	mini = UI.button({ Text = "", Size = UDim2.fromOffset(MINI, MINI), AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 60, 0, 108), BackgroundColor3 = Color3.fromRGB(16, 18, 22), BackgroundTransparency = 0.1, ClipsDescendants = true, AutoButtonColor = false, Parent = root }, function()
		if modalKind == "map" then closeModal() elseif state then act("map") mapModal() end
	end)
	UI.corner(mini, 14)
	UI.stroke(mini, c.card2, 2)
	local K = MINI / VIEW -- pixels per stud
	local H2 = Biomes.HALF
	local canvasS = UI.frame({ Size = UDim2.fromOffset(2 * H2 * K, 2 * H2 * K), BackgroundTransparency = 1, ZIndex = 2, Parent = mini })
	local canvasU = UI.frame({ Size = UDim2.fromOffset(2 * H2 * K, 2 * H2 * K), BackgroundTransparency = 1, ZIndex = 2, Visible = false, Parent = mini })
	local canvas = canvasS
	local miniCells, miniCellsU, miniPois = {}, {}, {}
	local function miniPos(x, z) return UDim2.fromOffset((x + H2) * K, (z + H2) * K) end
	local function refreshMini()
		local N = Config.MAP_CELLS
		local cw = 2 * H2 / N
		drawLayer(canvasS, cw * K, "surface", 3, miniCells)
		drawLayer(canvasU, cw * K, "under", 3, miniCellsU)
		for idx, poi in ipairs(mapPoisList) do
			local cx = math.floor((poi[2] + H2) / cw)
			local cz = math.floor((poi[3] + H2) / cw)
			local i = cz * N + cx + 1
			local layer = poiLayer(poi)
			local ex = layer == "under" and mapExplored2 or mapExplored
			if not miniPois[idx] and ex:sub(i, i) == "1" and POI_ICON[poi[1]] then
				local h = UI.frame({ Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = miniPos(poi[2], poi[3]), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BackgroundTransparency = 0.2, ZIndex = 5, Parent = layer == "under" and canvasU or canvasS })
				UI.corner(h, 10)
				Icons.draw(POI_ICON[poi[1]][1], h, 14, POI_ICON[poi[1]][2], UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
				miniPois[idx] = h
			end
		end
	end
	local deathDot = UI.frame({ Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(20, 20, 24), Visible = false, ZIndex = 6, Parent = canvas })
	UI.corner(deathDot, 10)
	Icons.draw("close", deathDot, 14, Color3.fromRGB(255, 70, 60), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local meArrow = UI.frame({ Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 9, Parent = mini })
	local mtip = UI.frame({ Size = UDim2.fromOffset(11, 11), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Rotation = 45, BackgroundColor3 = Color3.fromRGB(80, 200, 255), ZIndex = 9, Parent = meArrow })
	UI.stroke(mtip, Color3.new(1, 1, 1), 2)
	local mnose = UI.frame({ Size = UDim2.fromOffset(5, 9), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.35), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 10, Parent = meArrow })
	UI.corner(mnose, 3)
	local north = UI.text({ Text = "N", Size = UDim2.fromOffset(20, 18), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), TextSize = 14, TextColor3 = Color3.fromRGB(255, 120, 110), TextStrokeTransparency = 0.3, ZIndex = 9, Parent = mini })
	local miniOthers = {}
	local lastExplored = ""
	local miniUnder = nil
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or not mini.Visible then return end
		local sig = mapExplored .. mapExplored2
		if sig ~= lastExplored then
			lastExplored = sig
			refreshMini()
		end
		local p = hrp.Position
		local under = p.Y < -26
		if under ~= miniUnder then
			miniUnder = under
			canvasS.Visible, canvasU.Visible = not under, under
			mini.BackgroundColor3 = under and Color3.fromRGB(26, 24, 28) or Color3.fromRGB(16, 18, 22)
			north.Text = under and (lang == "ar" and "كهوف" or "CAVES") or "N"
			north.Size = UDim2.fromOffset(under and 60 or 20, 18)
		end
		canvasS.Position = UDim2.fromOffset(MINI / 2 - (p.X + H2) * K, MINI / 2 - (p.Z + H2) * K)
		canvasU.Position = canvasS.Position
		local look = hrp.CFrame.LookVector
		meArrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
		if state and state.death then
			deathDot.Visible = true
			deathDot.Position = miniPos(state.death[1], state.death[2])
		else
			deathDot.Visible = false
		end
		for _, pl in ipairs(Players:GetPlayers()) do
			local r = pl ~= player and not (state and state.pvp) and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local dot = miniOthers[pl]
				if not dot then
					dot = UI.frame({ Size = UDim2.fromOffset(9, 9), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(120, 255, 140), ZIndex = 8, Parent = canvas })
					UI.corner(dot, 5)
					UI.stroke(dot, Color3.new(0, 0, 0), 1)
					miniOthers[pl] = dot
				end
				dot.Position = miniPos(r.Position.X, r.Position.Z)
			end
		end
		for pl, dot in pairs(miniOthers) do
			if not pl.Parent or not pl.Character or (state and state.pvp) then dot:Destroy() miniOthers[pl] = nil end
		end
	end)

	---------------------------------------------------------------- on-screen markers: your dropped items and the other players (not when fighting is on)
	local markerRoot = typeof(player) == "Instance" and player:WaitForChild("PlayerGui") or gui
	local function makeMarker(color, iconName)
		local anchor = Instance.new("Part")
		anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Parent = workspace.CurrentCamera
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(180, 46)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 1e6
		bb.LightInfluence = 0
		bb.ResetOnSpawn = false
		bb.Adornee = anchor
		bb.Parent = markerRoot
		local pill = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(14, 16, 20), BackgroundTransparency = 0.3, Parent = bb })
		UI.corner(pill, 12)
		UI.stroke(pill, color, 2)
		if iconName then Icons.draw(iconName, pill, 26, color, UDim2.new(0, 8, 0.5, 0), Vector2.new(0, 0.5)) end
		local label = UI.text({ Text = "", Size = UDim2.new(1, iconName and -42 or -12, 1, 0), Position = UDim2.fromOffset(iconName and 38 or 6, 0), TextSize = 16, TextColor3 = color, TextStrokeTransparency = 0.4, Parent = pill })
		return { anchor = anchor, bb = bb, label = label }
	end
	local deathMarker = makeMarker(Color3.fromRGB(255, 90, 80), "close")
	local playerMarkers = {}
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local cam = workspace.CurrentCamera
		local me = char and char:FindFirstChild("HumanoidRootPart")
		local from = (me and me.Position) or (cam and cam.CFrame.Position) or Vector3.zero
		-- your items
		if state and state.death then
			local p = Vector3.new(state.death[1], (state.death[3] or from.Y) + 4, state.death[2])
			deathMarker.anchor.Position = p
			deathMarker.bb.Enabled = true
			deathMarker.label.Text = T("yourItems2") .. "  " .. Locale.f(lang, "meters", math.floor((p - from).Magnitude))
		else
			deathMarker.bb.Enabled = false
		end
		-- other players
		local pvp = state and state.pvp
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= player then
				local r = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
				local mk = playerMarkers[pl]
				if r and not pvp then
					if not mk then
						mk = makeMarker(Color3.fromRGB(130, 255, 150), nil)
						mk.bb.Size = UDim2.fromOffset(170, 34)
						playerMarkers[pl] = mk
					end
					local dist = (r.Position - from).Magnitude
					mk.anchor.Position = r.Position + Vector3.new(0, 4.5, 0)
					mk.bb.Enabled = true
					mk.label.Text = pl.DisplayName .. "  " .. Locale.f(lang, "meters", math.floor(dist))
				elseif mk then
					mk.bb.Enabled = false
				end
			end
		end
		for pl, mk in pairs(playerMarkers) do
			if not pl.Parent then mk.anchor:Destroy() mk.bb:Destroy() playerMarkers[pl] = nil end
		end
	end)

	---------------------------------------------------------------- boss health bar (top centre) and minecart driving
	local bossBar = UI.frame({ Size = UDim2.fromOffset(460, 46), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), BackgroundColor3 = Color3.fromRGB(16, 14, 18), BackgroundTransparency = 0.2, Visible = false, Parent = root })
	UI.corner(bossBar, 12)
	UI.stroke(bossBar, Color3.fromRGB(200, 60, 50), 2)
	local bossName = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 3), TextSize = 16, TextColor3 = Color3.fromRGB(255, 200, 120), Parent = bossBar })
	local bossBg = UI.frame({ Size = UDim2.new(1, -24, 0, 12), Position = UDim2.fromOffset(12, 27), BackgroundColor3 = Color3.fromRGB(50, 20, 20), Parent = bossBar })
	UI.corner(bossBg, 6)
	local bossFill = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(220, 60, 50), Parent = bossBg })
	UI.corner(bossFill, 6)
	local lastThrottle = 0
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		-- nearest boss within 120 studs
		local best, bd
		local mobsF = workspace:FindFirstChild("Mobs")
		if hrp and mobsF then
			for _, m in ipairs(mobsF:GetChildren()) do
				if m:GetAttribute("Boss") and (m:GetAttribute("HP") or 0) > 0 then
					local r = m:FindFirstChild("HumanoidRootPart")
					local d = r and (r.Position - hrp.Position).Magnitude
					if d and d < 120 and (not bd or d < bd) then best, bd = m, d end
				end
			end
		end
		bossBar.Visible = best ~= nil and not camState
		if best then
			bossName.Text = T("mob_" .. tostring(best:GetAttribute("Kind"))) .. "   Lv " .. tostring(best:GetAttribute("Level") or 1)
			bossFill.Size = UDim2.fromScale(math.clamp((best:GetAttribute("HP") or 0) / math.max(1, best:GetAttribute("MaxHP") or 1), 0, 1), 1)
		end
		-- minecart: W / S (or the stick forward / back) drive it
		local seat = hum and hum.SeatPart
		if seat and seat:GetAttribute("Cart") then
			local v = 0
			if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then v = 1 end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then v = -1 end
			if v == 0 and hum.MoveDirection.Magnitude > 0.3 then
				v = hum.MoveDirection:Dot(seat.CFrame.LookVector) >= 0 and 1 or -1
			end
			if v ~= lastThrottle then
				lastThrottle = v
				act("cart", v)
			end
		elseif lastThrottle ~= 0 then
			lastThrottle = 0
		end
	end)

	local function skillsModal()
		local content = openModal("skills", T("skills"), UDim2.fromOffset(560, 560))
		local head = UI.frame({ Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = c.card, ZIndex = 53, Parent = content })
		UI.corner(head, 20)
		Icons.draw("skill", head, 22, c.blue, UDim2.new(0, 12, 0.5, 0), Vector2.new(0, 0.5))
		UI.text({ Text = T("sp") .. ":  " .. tostring(state.sp), Size = UDim2.new(1, -50, 1, 0), Position = UDim2.fromOffset(44, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 19, TextColor3 = c.blue, ZIndex = 54, Parent = head })
		local list = UI.scroll({ Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50), ZIndex = 53, Parent = content })
		UI.list(list, 8)
		for i, k in ipairs(Config.SKILLS) do
			local lvl = state.skills and state.skills[k] or 0
			local r = UI.frame({ Size = UDim2.new(1, -8, 0, 70), BackgroundColor3 = c.card, ZIndex = 53, Parent = list })
			UI.corner(r, 12)
			local cap = Config.SKILL_CAP[k]
			UI.text({ Text = T("sk_" .. k) .. "   " .. lvl .. (cap and ("/" .. cap) or ""), Size = UDim2.new(0.62, 0, 0, 30), Position = UDim2.new(lang == "ar" and 1 or 0, lang == "ar" and -14 or 14, 0, 6), AnchorPoint = Vector2.new(lang == "ar" and 1 or 0, 0), TextXAlignment = UI.align(lang), TextSize = 19, ZIndex = 54, Parent = r })
			UI.text({ Text = T("skd_" .. k), Size = UDim2.new(0.62, 0, 0, 20), Position = UDim2.new(lang == "ar" and 1 or 0, lang == "ar" and -14 or 14, 0, 38), AnchorPoint = Vector2.new(lang == "ar" and 1 or 0, 0), TextXAlignment = UI.align(lang), TextSize = 14, TextColor3 = c.dim, ZIndex = 54, Parent = r })
			local barBg = UI.frame({ Size = UDim2.new(0.62, 0, 0, 4), Position = UDim2.new(lang == "ar" and 1 or 0, lang == "ar" and -14 or 14, 1, -8), AnchorPoint = Vector2.new(lang == "ar" and 1 or 0, 0), BackgroundColor3 = c.panel, ZIndex = 54, Parent = r })
			UI.frame({ Size = UDim2.fromScale(cap and (lvl / cap) or math.min(1, (lvl % 10) / 10 + (lvl > 0 and lvl % 10 == 0 and 1 or 0)), 1), BackgroundColor3 = c.blue, ZIndex = 55, Parent = barBg })
			local bx = lang == "ar" and 0 or 1
			local can = state.sp > 0 and (not cap or lvl < cap)
			local b = UI.button({ Text = "", Size = UDim2.fromOffset(52, 52), AnchorPoint = Vector2.new(bx, 0.5), Position = UDim2.new(bx, lang == "ar" and 10 or -10, 0.5, 0), BackgroundColor3 = can and c.blue or c.panel, ZIndex = 55, Parent = r }, function()
				act("skill", k)
			end)
			Icons.draw("plus", b, 22, can and c.text or c.dim, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			UI.enter(r, i * 0.04, 10)
		end
	end

	---------------------------------------------------------------- admin tools (the server only obeys admin accounts)
	local adminLocal = { fly = false, noclip = false }
	local flyBV, flyBG
	RunService.Stepped:Connect(function()
		local char = player.Character
		if not char then return end
		if adminLocal.noclip then
			for _, p in ipairs(char:GetDescendants()) do
				if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
			end
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if adminLocal.fly and hrp and hum then
			if not flyBV or flyBV.Parent ~= hrp then
				flyBV = Instance.new("BodyVelocity")
				flyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
				flyBV.Parent = hrp
				flyBG = Instance.new("BodyGyro")
				flyBG.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
				flyBG.P = 2e4
				flyBG.Parent = hrp
			end
			local cam = workspace.CurrentCamera
			local md = hum.MoveDirection
			local look = cam.CFrame.LookVector
			local flatL = Vector3.new(look.X, 0, look.Z).Unit
			local flatR = Vector3.new(-flatL.Z, 0, flatL.X)
			local v = cam.CFrame.LookVector * md:Dot(flatL) + cam.CFrame.RightVector * md:Dot(flatR)
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) or hum.Jump then v += Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then v -= Vector3.new(0, 1, 0) end
			local speed = (state and state.admin and state.admin.speed) or 70
			flyBV.Velocity = v.Magnitude > 0 and v.Unit * math.max(speed, 40) or Vector3.zero
			flyBG.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flatL)
		elseif flyBV then
			flyBV:Destroy() flyBV = nil
			if flyBG then flyBG:Destroy() flyBG = nil end
		end
	end)
	local adminTab = "main"
	local spawnLevel, spawnCount, giveQty = 10, 1, 10
	local function adminModal()
		local content = openModal("admin", T("adminTools"), UDim2.fromOffset(760, 620))
		local ad = (state and state.admin) or {}
		local tabs = UI.frame({ Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.list(tabs, 6, Enum.FillDirection.Horizontal)
		for _, t in ipairs({ { "main", "ad_toggles" }, { "spawn", "ad_spawn" }, { "give", "ad_give" }, { "tp", "ad_tp" } }) do
			local on = adminTab == t[1]
			UI.button({ Text = T(t[2]), Size = UDim2.fromOffset(176, 40), TextSize = 16, BackgroundColor3 = on and c.gold or c.card, TextColor3 = on and c.bg or c.text, ZIndex = 54, Parent = tabs }, function()
				adminTab = t[1]
				adminModal()
			end)
		end
		local body = UI.scroll({ Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50), ZIndex = 53, Parent = content })
		UI.list(body, 8)
		local order = 0
		local function section(title)
			order += 1
			UI.text({ Text = title, LayoutOrder = order, Size = UDim2.new(1, -8, 0, 26), TextXAlignment = UI.align(lang), TextSize = 17, TextColor3 = c.dim, ZIndex = 54, Parent = body })
		end
		local function row(h)
			order += 1
			local r = UI.frame({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, h or 46), BackgroundTransparency = 1, ZIndex = 54, Parent = body })
			UI.list(r, 6, Enum.FillDirection.Horizontal)
			return r
		end
		local function grid(cell)
			order += 1
			local g = UI.frame({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 54, Parent = body })
			UI.new("UIGridLayout", { CellSize = cell or UDim2.fromOffset(170, 40), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = g })
			return g
		end
		local function btn(parent, text, color, cb, w)
			return UI.button({ Text = text, Size = UDim2.fromOffset(w or 170, 40), TextSize = 15, BackgroundColor3 = color or c.card, TextColor3 = (color == c.gold or color == c.accent) and c.bg or c.text, ZIndex = 55, Parent = parent }, cb)
		end
		local function stepper(parent, label, values, current, onPick)
			local idx = 1
			for i, v in ipairs(values) do if v == current then idx = i end end
			local f = UI.frame({ Size = UDim2.fromOffset(350, 40), BackgroundColor3 = c.card, ZIndex = 55, Parent = parent })
			UI.corner(f, 10)
			UI.text({ Text = label, Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.fromOffset(8, 0), TextXAlignment = UI.align(lang), TextSize = 15, ZIndex = 56, Parent = f })
			local val = UI.text({ Text = tostring(values[idx]), Size = UDim2.fromOffset(80, 40), Position = UDim2.new(1, -130, 0, 0), TextSize = 17, TextColor3 = c.gold, ZIndex = 56, Parent = f })
			local function go(d)
				idx = math.clamp(idx + d, 1, #values)
				val.Text = tostring(values[idx])
				onPick(values[idx])
			end
			UI.button({ Text = "-", Size = UDim2.fromOffset(40, 34), Position = UDim2.new(1, -176, 0, 3), TextSize = 22, BackgroundColor3 = c.card2, TextColor3 = c.text, ZIndex = 56, Parent = f }, function() go(-1) end)
			UI.button({ Text = "+", Size = UDim2.fromOffset(40, 34), Position = UDim2.new(1, -46, 0, 3), TextSize = 22, BackgroundColor3 = c.card2, TextColor3 = c.text, ZIndex = 56, Parent = f }, function() go(1) end)
		end
		if adminTab == "main" then
			section(T("ad_toggles"))
			local r = row()
			btn(r, T("ad_god"), ad.god and c.accent or c.card, function() act("admin", "god", not ad.god) task.delay(0.4, adminModal) end, 200)
			btn(r, T("ad_fly"), adminLocal.fly and c.accent or c.card, function() adminLocal.fly = not adminLocal.fly adminModal() end, 200)
			btn(r, T("ad_noclip"), adminLocal.noclip and c.accent or c.card, function()
				adminLocal.noclip = not adminLocal.noclip
				if not adminLocal.noclip and player.Character then
					for _, p in ipairs(player.Character:GetDescendants()) do
						if p:IsA("BasePart") and (p.Name == "HumanoidRootPart" or p.Name:find("Torso") or p.Name == "Head") then p.CanCollide = p.Name ~= "HumanoidRootPart" or false end
					end
				end
				adminModal()
			end, 200)
			section(T("ad_stats"))
			local g = grid(UDim2.fromOffset(350, 40))
			stepper(g, T("ad_speed"), { 16, 24, 32, 50, 80, 120, 200, 300 }, ad.speed or 16, function(v) act("admin", "speed", v) end)
			stepper(g, T("ad_hp"), { 100, 250, 500, 1000, 5000, 100000 }, ad.hp or 100, function(v) act("admin", "hp", v) end)
			stepper(g, T("ad_dmg"), { 1, 2, 5, 10, 50, 100, 1000 }, ad.dmg or 1, function(v) act("admin", "dmg", v) end)
			stepper(g, T("ad_jump"), { 50, 80, 120, 200, 300 }, ad.jump or 50, function(v) act("admin", "jump", v) end)
			section(T("ad_world"))
			local w = grid()
			btn(w, T("ad_heal"), c.accent, function() act("admin", "heal") end)
			btn(w, T("ad_day"), nil, function() act("admin", "time", "day") end)
			btn(w, T("ad_night"), nil, function() act("admin", "time", "night") end)
			btn(w, T("ad_skip"), nil, function() act("admin", "time", "skip") end)
			for _, wx in ipairs({ "clear", "wind", "rain", "storm", "tornado" }) do
				btn(w, T("wx_" .. wx), wx == "tornado" and c.danger or nil, function() act("admin", "weather", wx) end)
			end
			btn(w, T("ad_reveal"), nil, function() act("admin", "reveal") end)
			btn(w, T("ad_medals"), nil, function() act("admin", "medals") end)
			btn(w, T("ad_clearMobs"), nil, function() act("admin", "clearMobs") end)
			btn(w, T("ad_clearBag"), c.danger, function() act("admin", "clearBag") end)
			section(T("ad_money"))
			local mrow = grid()
			btn(mrow, "+1,000 " .. T("coins"), c.gold, function() act("admin", "coins", 1000) end)
			btn(mrow, "+100,000 " .. T("coins"), c.gold, function() act("admin", "coins", 100000) end)
			btn(mrow, "+5,000 XP", nil, function() act("admin", "xp", 5000) end)
			btn(mrow, "+5 " .. T("sp"), nil, function() act("admin", "sp", 5) end)
		elseif adminTab == "spawn" then
			local r = grid(UDim2.fromOffset(350, 40))
			stepper(r, T("ad_level"), { 1, 5, 10, 15, 20, 30, 40, 50, 75, 99 }, spawnLevel, function(v) spawnLevel = v end)
			stepper(r, T("ad_count"), { 1, 2, 3, 5, 10 }, spawnCount, function(v) spawnCount = v end)
			for _, reg in ipairs(Bestiary.regions) do
				section(T("biome_" .. reg.key))
				local g = grid()
				for _, k in ipairs(reg.kinds) do
					btn(g, T("mob_" .. k), Bestiary.kinds[k] == "boss" and c.danger or nil, function() act("admin", "spawn", { kind = k, level = spawnLevel, count = spawnCount }) end)
				end
			end
		elseif adminTab == "give" then
			local r = row()
			stepper(r, T("ad_qty"), { 1, 5, 10, 20, 50, 99 }, giveQty, function(v) giveQty = v end)
			local ids = {}
			for id in pairs(Items.defs) do table.insert(ids, id) end
			table.sort(ids, function(a, b) return Items.name(a, lang) < Items.name(b, lang) end)
			local g = grid(UDim2.fromOffset(170, 54))
			for _, id in ipairs(ids) do
				local b = btn(g, "", nil, function() act("admin", "give", { id = id, n = giveQty }) end)
				b.Size = UDim2.fromOffset(170, 54)
				ItemView.new(b, id, UDim2.fromOffset(46, 46), UDim2.new(0, 4, 0.5, -23), 56)
				UI.text({ Text = Items.name(id, lang), Size = UDim2.new(1, -56, 1, 0), Position = UDim2.fromOffset(52, 0), TextSize = 13, TextWrapped = true, ZIndex = 57, Parent = b })
			end
		elseif adminTab == "tp" then
			section(T("ad_players"))
			local pg = grid(UDim2.fromOffset(350, 40))
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl ~= player then
					local f = UI.frame({ BackgroundColor3 = c.card, ZIndex = 55, Parent = pg })
					UI.corner(f, 10)
					UI.text({ Text = pl.DisplayName, Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.fromOffset(8, 0), TextXAlignment = UI.align(lang), TextSize = 15, ZIndex = 56, Parent = f })
					UI.button({ Text = T("ad_goto"), Size = UDim2.fromOffset(86, 32), Position = UDim2.new(1, -182, 0, 4), TextSize = 14, ZIndex = 56, Parent = f }, function() act("admin", "tpTo", pl.UserId) end)
					UI.button({ Text = T("ad_bring"), Size = UDim2.fromOffset(86, 32), Position = UDim2.new(1, -92, 0, 4), TextSize = 14, BackgroundColor3 = c.gold, TextColor3 = c.bg, ZIndex = 56, Parent = f }, function() act("admin", "bring", pl.UserId) end)
				end
			end
			local names = { village = "leg_village", trader = "leg_trader", cave = "leg_cave" }
			local counts = {}
			for _, kind in ipairs({ "village", "trader", "cave" }) do
				section(T(names[kind]))
				local g = grid()
				for _, poi in ipairs(mapPoisList) do
					if poi[1] == kind then
						counts[kind] = (counts[kind] or 0) + 1
						local region = T("biome_" .. Biomes.at(poi[2], poi[3]))
						btn(g, region .. " " .. counts[kind], nil, function() act("admin", "tp", { poi[2], poi[3] }) end)
					end
				end
			end
		end
	end

	-- switching admin on can't be undone: warn first
	local function adminWarnModal()
		local content = openModal("adminWarn", T("adminWarnTitle"), UDim2.fromOffset(440, 250))
		Icons.draw("lock", content, 40, c.danger, UDim2.new(0.5, 0, 0, 22), Vector2.new(0.5, 0.5))
		UI.text({ Text = T("adminWarn"), Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 50), TextSize = 22, TextColor3 = c.text, ZIndex = 53, Parent = content })
		UI.button({ Text = T("activate"), Size = UDim2.new(0.5, -6, 0, 52), Position = UDim2.new(lang == "ar" and 0.5 or 0, lang == "ar" and 6 or 0, 1, -52), BackgroundColor3 = c.danger, TextColor3 = c.text, TextSize = 20, ZIndex = 54, Parent = content }, function()
			act("adminActivate")
			task.delay(0.7, function()
				if state and state.adminOn then act("map") adminModal() elseif closeModal then closeModal() end
			end)
		end)
		UI.button({ Text = T("cancel"), Size = UDim2.new(0.5, -6, 0, 52), Position = UDim2.new(lang == "ar" and 0 or 0.5, lang == "ar" and 0 or 6, 1, -52), BackgroundColor3 = c.card2, TextColor3 = c.text, TextSize = 20, ZIndex = 54, Parent = content }, function()
			if closeModal then closeModal() end
		end)
	end

	local function menuModal()
		local content = openModal("menu", T("menu"), UDim2.fromOffset(520, 600))
		local owner = state and state.isOwner
		local top = UI.frame({ Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		local b = UI.button({ Text = T("lobby"), Size = UDim2.new(owner and 0.5 or 1, owner and -6 or 0, 1, 0), BackgroundColor3 = c.danger, TextColor3 = c.text, TextSize = 22, ZIndex = 54, Parent = top }, function()
			act("leave")
			UI.toast(root, T("teleporting"))
		end)
		Icons.draw("home", b, 24, c.text, UDim2.new(0, 16, 0.5, 0), Vector2.new(0, 0.5))
		if owner then
			local locked = state.locked
			local lb = UI.button({ Text = locked and T("unlockRoom") or T("lockRoom"), Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.new(0.5, 6, 0, 0), BackgroundColor3 = locked and c.gold or c.card, TextColor3 = locked and c.bg or c.text, TextSize = 20, ZIndex = 54, Parent = top }, function()
				act("lock", not locked)
				task.delay(0.6, function() if modalKind == "menu" then menuModal() end end)
			end)
			Icons.draw("lock", lb, 22, locked and c.bg or c.text, UDim2.new(0, 14, 0.5, 0), Vector2.new(0, 0.5))
		end
		local shift = 0
		if state and state.canAdmin then
			shift = 54
			UI.button({ Text = T("adminTools"), Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 62), BackgroundColor3 = c.gold, TextColor3 = c.bg, TextSize = 19, ZIndex = 54, Parent = content }, function()
				if state.adminOn then
					act("map")
					adminModal()
				else
					adminWarnModal()
				end
			end)
		end
		UI.text({ Text = T("code") .. ":  " .. tostring(state and state.code or "...") .. ((state and state.locked) and ("   |   " .. T("roomLocked")) or ""), Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 64 + shift), TextSize = 22, TextColor3 = c.gold, ZIndex = 53, Parent = content })
		-- everyone can see whether admin was switched on in this room
		local adm = state and state.adminOn and state.code ~= "TEST00"
		UI.text({ Text = adm and Locale.f(lang, "adminUsed", state.adminBy or "?") or T("adminNotUsed"), Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 96 + shift), TextSize = 15, TextColor3 = adm and c.danger or c.dim, ZIndex = 53, Parent = content })
		shift += 22
		local list = Players:GetPlayers()
		UI.text({ Text = T("inRoom") .. "  " .. #list .. " / " .. Config.MAX_PLAYERS, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 104 + shift), TextXAlignment = UI.align(lang), TextSize = 17, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local scroll = UI.scroll({ Size = UDim2.new(1, 0, 1, -138 - shift), Position = UDim2.fromOffset(0, 136 + shift), ZIndex = 53, Parent = content })
		UI.list(scroll, 6)
		for i, pl in ipairs(list) do
			local row = UI.frame({ Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = c.card, LayoutOrder = (pl.UserId == state.ownerId) and 0 or i, ZIndex = 54, Parent = scroll })
			UI.corner(row, 10)
			local plMod = state.mods and state.mods[tostring(pl.UserId)] == true
			local tag = (pl.UserId == state.ownerId) and ("  (" .. T("owner") .. ")") or (plMod and ("  (" .. T("moderator") .. ")") or ((pl == player) and ("  (" .. T("you") .. ")") or ""))
			UI.text({ Text = pl.DisplayName .. tag, Size = UDim2.new(owner and 0.4 or 0.55, 0, 1, 0), Position = UDim2.new(lang == "ar" and (owner and 0.6 or 0.45) or 0, lang == "ar" and -12 or 12, 0, 0), TextXAlignment = UI.align(lang), TextTruncate = Enum.TextTruncate.AtEnd, TextSize = owner and 16 or 19, TextColor3 = (pl.UserId == state.ownerId) and c.gold or (plMod and c.blue or c.text), ZIndex = 55, Parent = row })
			-- the owner manages everyone; a moderator may remove players who are neither the owner nor moderators
			local canRemove = pl ~= player and pl.UserId ~= state.ownerId and (owner or (state.isMod and not plMod))
			if canRemove then
				local bx = lang == "ar" and 0 or 1
				local holder = UI.frame({ Size = UDim2.fromOffset(owner and 290 or 196, 42), AnchorPoint = Vector2.new(bx, 0.5), Position = UDim2.new(bx, lang == "ar" and 8 or -8, 0.5, 0), BackgroundTransparency = 1, ZIndex = 55, Parent = row })
				UI.list(holder, 6, Enum.FillDirection.Horizontal)
				if owner then
					UI.button({ Text = plMod and T("unmod") or T("makeMod"), Size = UDim2.fromOffset(94, 42), TextSize = 14, BackgroundColor3 = plMod and c.blue or c.card2, TextColor3 = c.text, LayoutOrder = 0, ZIndex = 56, Parent = holder }, function()
						act("mod", pl.UserId, not plMod)
						task.delay(0.6, function() if modalKind == "menu" then menuModal() end end)
					end)
				end
				UI.button({ Text = T("kick"), Size = UDim2.fromOffset(92, 42), TextSize = 17, BackgroundColor3 = c.card2, TextColor3 = c.text, LayoutOrder = 1, ZIndex = 56, Parent = holder }, function()
					act("kick", pl.UserId)
				end)
				local armed = false
				local banB
				banB = UI.button({ Text = T("ban"), Size = UDim2.fromOffset(92, 42), TextSize = 17, LayoutOrder = 2, BackgroundColor3 = c.danger, TextColor3 = c.text, ZIndex = 56, Parent = holder }, function()
					if not armed then
						armed = true
						banB.Text = T("confirmBan")
						banB.TextSize = 12
						task.delay(3, function() if banB.Parent then armed = false banB.Text = T("ban") banB.TextSize = 17 end end)
						return
					end
					act("ban", pl.UserId)
				end)
			end
		end
	end
	Players.PlayerAdded:Connect(function() if modalKind == "menu" then menuModal() end end)
	Players.PlayerRemoving:Connect(function() task.defer(function() if modalKind == "menu" then menuModal() end end) end)

	---------------------------------------------------------------- furnace (bag on the left, furnace on the right)
	local furnaceW, furnaceBag, furnaceArrow, furnaceFlame, furnaceWood = {}, {}, nil, nil, nil
	function refreshFurnace()
		if modalKind ~= "furnace" or not state or not furnaceData then return end
		for i, w in pairs(furnaceBag) do if w.button.Parent then w.set(state.slots[i], pending == i) end end
		local f = furnaceData
		if furnaceW[201] then
			furnaceW[201].set(f.input or nil, false)
			furnaceW[202].set(f.fuel or nil, false)
			furnaceW[203].set(f.out or nil, false)
		end
		local burning = f.t and f.t > 0
		if furnaceArrow and furnaceArrow.Parent then
			furnaceArrow.Size = UDim2.fromScale(math.clamp((f.t or 0) / (f.time or 3), 0, 1), 1)
		end
		if furnaceFlame and furnaceFlame.Parent then
			for _, d in ipairs(furnaceFlame:GetDescendants()) do
				if d:IsA("ImageLabel") then
					d.ImageColor3 = burning and Color3.new(1, 1, 1) or Color3.fromRGB(110, 110, 110)
					d.ImageTransparency = burning and 0 or 0.45
				end
			end
		end
		if furnaceWood and furnaceWood.Parent then
			local wood = f.fuel and f.fuel.n or 0
			local uses = wood // (f.need or 5)
			furnaceWood.Text = Locale.f(lang, "fuelLeft", uses)
			furnaceWood.TextColor3 = uses > 0 and c.gold or c.danger
		end
	end
	function furnaceModal()
		local content = openModal("furnace", T("furnace"), UDim2.fromOffset(880, 470))
		furnaceW, furnaceBag = {}, {}
		furnaceBagSize = tostring(state.bag)
		local ar = lang == "ar"
		-- tap a bag item: wood goes to the fuel slot, anything that cooks goes in on top
		local function tapBag(i)
			local sl = state and state.slots[i]
			if not sl then return end
			if sl.id == "wood" then act("move", i, 202)
			elseif Items.smelt[sl.id] then act("move", i, 201)
			else UI.toast(root, T("cantSmelt")) end
		end
		-- left: the bag
		local left = UI.frame({ Size = UDim2.new(0, 452, 1, 0), BackgroundColor3 = c.card, BackgroundTransparency = 0.5, ZIndex = 53, Parent = content })
		UI.corner(left, 14)
		UI.text({ Text = T("yourItems"), Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 6), TextXAlignment = UI.align(lang), TextSize = 17, TextColor3 = c.dim, ZIndex = 54, Parent = left })
		local hb = UI.frame({ Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 42), BackgroundTransparency = 1, ZIndex = 54, Parent = left })
		UI.list(hb, 8, Enum.FillDirection.Horizontal)
		for i = 1, Config.HOTBAR do
			local w = slotWidget(hb, 60, i)
			w.button.ZIndex = 55
			register(w, i, function() tapBag(i) end)
			furnaceBag[i] = w
		end
		UI.frame({ Size = UDim2.new(1, -40, 0, 2), Position = UDim2.fromOffset(20, 112), BackgroundColor3 = c.card2, BackgroundTransparency = 0.4, ZIndex = 54, Parent = left })
		local bigF = state.bag == "big"
		local cell = bigF and 40 or 60
		local grid = UI.frame({ Size = UDim2.new(1, 0, 0, 3 * (cell + 6)), Position = UDim2.fromOffset(0, 124), BackgroundTransparency = 1, ZIndex = 54, Parent = left })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(cell, cell), CellPadding = UDim2.fromOffset(bigF and 4 or 6, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
		for k = 1, bigF and Config.BIG_BAG or Config.BAG do
			local i = Config.HOTBAR + k
			local w = slotWidget(grid, cell, k)
			if state.bag then
				register(w, i, function() tapBag(i) end)
				furnaceBag[i] = w
			else
				local shade = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 8, Parent = w.button })
				UI.corner(shade, 12)
				Icons.draw("lock", shade, 22, c.dim, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			end
		end
		UI.text({ Text = T("furnaceTip"), Size = UDim2.new(1, -24, 0, 36), Position = UDim2.new(0, 12, 1, -44), TextWrapped = true, TextSize = 14, TextColor3 = c.dim, ZIndex = 54, Parent = left })

		-- right: the furnace (input on top, fire, fuel below, arrow, output)
		local right = UI.frame({ Size = UDim2.new(1, -468, 1, 0), Position = UDim2.fromOffset(468, 0), BackgroundColor3 = c.card, ZIndex = 53, Parent = content })
		UI.corner(right, 14)
		UI.stroke(right, c.card2, 1.5)
		local area = UI.frame({ Size = UDim2.fromOffset(330, 260), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), BackgroundTransparency = 1, ZIndex = 54, Parent = right })
		local function slotAt(idx, size, x, y, label, hint)
			local holder = UI.frame({ Size = UDim2.fromOffset(size, size + 22), Position = UDim2.fromOffset(x, y), BackgroundTransparency = 1, ZIndex = 54, Parent = area })
			local w = slotWidget(holder, size, 0)
			w.button.ZIndex = 55
			local empty = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 4, Parent = w.button })
			if hint then
				Icons.draw(hint, empty, size * 0.42, c.card2, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
				for _, d in ipairs(empty:GetDescendants()) do
					if d:IsA("ImageLabel") then d.ImageTransparency = 0.7 d.ImageColor3 = Color3.fromRGB(150, 150, 150) end
				end
			end
			local base = w.set
			w.set = function(data, sel) base(data, sel) empty.Visible = data == nil end
			UI.text({ Text = label, Size = UDim2.new(1, 20, 0, 18), Position = UDim2.new(0, -10, 0, size + 3), TextSize = 13, TextColor3 = c.dim, ZIndex = 55, Parent = holder })
			register(w, idx, function() act("move", idx, 0) end)
			furnaceW[idx] = w
			return w
		end
		-- the furnace reads left to right in both languages, like Minecraft
		slotAt(201, 66, 20, 0, T("fIn"), "food")
		furnaceFlame = UI.frame({ Size = UDim2.fromOffset(66, 40), Position = UDim2.fromOffset(20, 92), BackgroundTransparency = 1, ZIndex = 54, Parent = area })
		Icons.draw("flame", furnaceFlame, 34, c.card2, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
		slotAt(202, 66, 20, 140, T("fFuel"), "flame")
		local track = UI.frame({ Size = UDim2.fromOffset(104, 14), Position = UDim2.fromOffset(110, 105), BackgroundColor3 = c.bg, ZIndex = 54, Parent = area })
		UI.corner(track, 7)
		furnaceArrow = UI.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = c.gold, ZIndex = 55, Parent = track })
		UI.corner(furnaceArrow, 7)
		slotAt(203, 84, 238, 70, T("fOut"), nil).stroke.Color = c.gold
		furnaceWood = UI.text({ Text = "", Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 0, 252), TextSize = 16, ZIndex = 54, Parent = right })
		-- recipes
		local rec = UI.frame({ Size = UDim2.new(1, -24, 0, 100), Position = UDim2.new(0, 12, 1, -110), BackgroundColor3 = c.bg, BackgroundTransparency = 0.3, ZIndex = 54, Parent = right })
		UI.corner(rec, 10)
		UI.text({ Text = T("recipes") .. "   (" .. Locale.f(lang, "perItem", 5, 3) .. ")", Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 4), TextXAlignment = UI.align(lang), TextSize = 14, TextColor3 = c.gold, ZIndex = 55, Parent = rec })
		local list = UI.frame({ Size = UDim2.new(1, -16, 1, -32), Position = UDim2.fromOffset(8, 30), BackgroundTransparency = 1, ZIndex = 55, Parent = rec })
		UI.list(list, 4)
		local n = 0
		for from, to in pairs(Items.smelt) do
			n += 1
			local row = UI.frame({ Size = UDim2.new(1, 0, 0, 28), LayoutOrder = n, BackgroundTransparency = 1, ZIndex = 55, Parent = list })
			local iconA = UI.frame({ Size = UDim2.fromOffset(26, 26), Position = UDim2.fromScale(ar and 1 or 0, 0), AnchorPoint = Vector2.new(ar and 1 or 0, 0), BackgroundTransparency = 1, ZIndex = 56, Parent = row })
			ItemView.new(iconA, from, UDim2.fromScale(1, 1), nil, 57)
			UI.text({ Text = Items.name(from, lang) .. (ar and "  ←  " or "  →  ") .. Items.name(to, lang), Size = UDim2.new(1, -66, 1, 0), Position = UDim2.new(ar and 1 or 0, ar and -34 or 34, 0, 0), AnchorPoint = Vector2.new(ar and 1 or 0, 0), TextXAlignment = UI.align(lang), TextSize = 14, ZIndex = 56, Parent = row })
			local iconB = UI.frame({ Size = UDim2.fromOffset(26, 26), Position = UDim2.fromScale(ar and 0 or 1, 0), AnchorPoint = Vector2.new(ar and 0 or 1, 0), BackgroundTransparency = 1, ZIndex = 56, Parent = row })
			ItemView.new(iconB, to, UDim2.fromScale(1, 1), nil, 57)
		end
		refreshFurnace()
	end

	function refreshModal(force)
		if modalKind == "bag" then
			if bagShape ~= (tostring(state.bag) .. tostring(state.armor)) then bagModal() else refreshBag() end
		elseif modalKind == "furnace" and force and furnaceBagSize ~= tostring(state.bag) then
			furnaceModal()
		elseif modalKind == "stash" then
			rebuilding = true
			stashModal()
			rebuilding = false
		elseif modalKind == "shop" and force then
			rebuilding = true
			shopModal()
			rebuilding = false
		elseif modalKind == "skills" and force then skillsModal()
		elseif modalKind == "furnace" then refreshFurnace() end
	end

	local half = (Config.HOTBAR * 74) / 2 + 42
	local bagB = sideButton("backpack", half, function()
		if modalKind == "bag" then closeModal() elseif state then pending = nil bagModal() end
	end)
	local skB = sideButton("skill", -half, function()
		if modalKind == "skills" then closeModal() elseif state then skillsModal() end
	end)
	UI.keyHint(bagB, "B", Enum.KeyCode.ButtonY, UDim2.new(1, 4, 0, -4))
	UI.keyHint(skB, "K", Enum.KeyCode.DPadUp, UDim2.new(1, 4, 0, -4))
	local mb = UI.button({ Text = "", Size = UDim2.fromOffset(52, 52), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 228), BackgroundColor3 = c.card, Parent = root }, function()
		if modalKind == "menu" then closeModal() elseif state then menuModal() end
	end)
	Icons.draw("menu", mb, 24, c.text, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	local ib = UI.button({ Text = "", Size = UDim2.fromOffset(52, 52), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -74, 0, 228), BackgroundColor3 = c.card, Parent = root }, function()
		if modalKind == "index" then closeModal() elseif state then indexModal() end
	end)
	Icons.draw("book", ib, 26, c.gold, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UI.keyHint(ib, "I", Enum.KeyCode.DPadLeft, UDim2.new(0, -4, 1, 4), Vector2.new(1, 0))
	local mapB = UI.button({ Text = "", Size = UDim2.fromOffset(52, 52), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -134, 0, 228), BackgroundColor3 = c.card, Parent = root }, function()
		if modalKind == "map" then closeModal() elseif state then act("map") mapModal() end
	end)
	Icons.draw("map", mapB, 26, Color3.fromRGB(150, 200, 120), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UI.keyHint(mapB, "N", Enum.KeyCode.DPadRight, UDim2.new(0, -4, 1, 4), Vector2.new(1, 0))
	UI.keyHint(mb, "M", Enum.KeyCode.DPadDown, UDim2.new(0, -4, 1, 4), Vector2.new(1, 0))

	---------------------------------------------------------------- aiming for ranged tools
	local cross = UI.frame({ Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = c.text, Visible = false, Parent = gui })
	UI.corner(cross, 5)
	UI.stroke(cross, Color3.new(0, 0, 0), 1.5)
	local function aimDir()
		local char = player.Character
		local head = char and char:FindFirstChild("Head")
		local cam = workspace.CurrentCamera
		if not head or not cam then return nil end
		local target
		if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
			target = player:GetMouse().Hit.Position
		else
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { char }
			local res = workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 400, rp)
			target = res and res.Position or (cam.CFrame.Position + cam.CFrame.LookVector * 400)
		end
		return (target - head.Position).Unit
	end
	local ANIM_FOR = { axe = "chop", hammer = "chop", pickaxe = "mine", spear = "thrust", sword = "slash" }
	local lastSwing = 0
	local function watchCharacter(char)
		char.ChildAdded:Connect(function(t)
			if t:IsA("Tool") then
				local def = Items.get(t:GetAttribute("ItemId") or "")
				local kind = def and def.kind == "tool" and ANIM_FOR[def.class or ""]
				if kind then
					t.Activated:Connect(function()
						if os.clock() - lastSwing < 0.55 then return end
						lastSwing = os.clock()
						Effects.anim(char, kind, true)
					end)
				end
			end
			if t:IsA("Tool") and t:GetAttribute("Ranged") then
				cross.Visible = true
				t.Activated:Connect(function()
					local dir = aimDir()
					if dir and state then act("shoot", state.sel, dir) end
				end)
				t.AncestryChanged:Connect(function()
					if not t:IsDescendantOf(char) then cross.Visible = false end
				end)
			end
		end)
	end
	if player.Character then watchCharacter(player.Character) end
	player.CharacterAdded:Connect(watchCharacter)

	---------------------------------------------------------------- shift lock: the character faces where the camera looks
	local locked = false
	local lockBtn
	local function applyLock()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.AutoRotate = not locked
			hum.CameraOffset = locked and Vector3.new(1.7, 0.4, 0) or Vector3.zero
		end
		if not locked then UserInputService.MouseBehavior = Enum.MouseBehavior.Default end
		cross.Visible = locked or (char and char:FindFirstChildOfClass("Tool") and char:FindFirstChildOfClass("Tool"):GetAttribute("Ranged")) == true
		if lockBtn then
			UI.tween(lockBtn, 0.15, { BackgroundColor3 = locked and c.accent or c.card })
		end
	end
	local function setLock(on)
		locked = on
		applyLock()
		Effects.ui("click")
	end
	lockBtn = UI.button({ Text = "", Size = UDim2.fromOffset(58, 58), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -40, 1, -190), BackgroundColor3 = c.card, Parent = root }, function()
		setLock(not locked)
	end)
	UI.stroke(lockBtn, c.card2, 2)
	Icons.draw("lock", lockBtn, 28, c.text, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UI.keyHint(lockBtn, "Ctrl", Enum.KeyCode.ButtonR3, UDim2.new(0, -4, 0, -4), Vector2.new(1, 0))
	-- on PC / console the lock button sits above the hotbar's right side instead of the touch jump area
	local function placeLock()
		local touch = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
		lockBtn.Position = touch and UDim2.new(1, -40, 1, -190) or UDim2.new(1, -24, 1, -24)
	end
	placeLock()
	UserInputService.LastInputTypeChanged:Connect(placeLock)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid", 10)
		applyLock()
	end)
	pcall(function()
		game:GetService("RunService"):BindToRenderStep("ShiftLock", Enum.RenderPriority.Camera.Value + 1, function()
			if not locked then return end
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local cam = workspace.CurrentCamera
			if not hrp or not cam or not hum or hum.Health <= 0 then return end
			local look = cam.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat.Unit)
			end
			if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			end
		end)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if (not processed and input.KeyCode == Enum.KeyCode.LeftControl) or input.KeyCode == Enum.KeyCode.ButtonR3 then setLock(not locked) end
	end)

	---------------------------------------------------------------- localized prompts
	ProximityPromptService.PromptShown:Connect(function(prompt)
		local key = prompt:GetAttribute("Key")
		if key then prompt.ActionText = T("p_" .. key) end
		local obj = prompt:GetAttribute("Obj")
		local itemId = prompt:GetAttribute("ItemId")
		if itemId then
			local n = prompt:GetAttribute("Count") or 1
			prompt.ObjectText = Items.name(itemId, lang) .. (n > 1 and (" x" .. n) or "")
		elseif obj then prompt.ObjectText = T("o_" .. obj)
		elseif key == "pick" then prompt.ObjectText = T("o_berries")
		elseif key == "trade" and prompt:GetAttribute("Shop") == "black" then
			prompt.ObjectText = T("o_black")
		elseif key == "trade" and prompt:GetAttribute("Shop") == "dwarf" then
			prompt.ObjectText = T("o_dwarf")
		elseif key == "trade" then
			prompt.ObjectText = T("o_vendor") .. (ReplicatedStorage:GetAttribute("Night") and ("  (" .. T("shopClosed") .. ")") or "")
		end
	end)

	---------------------------------------------------------------- creature labels (local, in the player's language)
	local function label(m)
		local kind = m:GetAttribute("Kind")
		if not kind then return end
		local hrp = m:WaitForChild("HumanoidRootPart", 5)
		if not hrp then return end
		local boss = m:GetAttribute("Boss") == true
		local bb = UI.new("BillboardGui", { Size = UDim2.fromOffset(boss and 200 or 120, 34), StudsOffsetWorldSpace = Vector3.new(0, hrp.Size.Y / 2 + (boss and 4 or 2), 0), AlwaysOnTop = false, MaxDistance = boss and 200 or 80, Adornee = hrp, Parent = m })
		local lvl = m:GetAttribute("Level") or 1
		UI.text({ Text = T("mob_" .. kind) .. "  Lv " .. lvl, Size = UDim2.new(1, 0, 0, 18), TextSize = boss and 18 or 14, TextColor3 = boss and c.gold or c.text, TextStrokeTransparency = 0.4, Parent = bb })
		local bg = UI.frame({ Size = UDim2.new(1, 0, 0, 8), Position = UDim2.fromOffset(0, 22), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.4, Parent = bb })
		UI.corner(bg, 4)
		local fill = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = boss and c.gold or c.danger, Parent = bg })
		UI.corner(fill, 4)
		local function upd()
			local hp, mx = m:GetAttribute("HP") or 0, m:GetAttribute("MaxHP") or 1
			UI.tween(fill, 0.2, { Size = UDim2.fromScale(math.clamp(hp / mx, 0, 1), 1) })
		end
		upd()
		m:GetAttributeChangedSignal("HP"):Connect(upd)
	end
	task.spawn(function()
		local mobs = workspace:WaitForChild("Mobs", 30)
		if not mobs then return end
		mobs.ChildAdded:Connect(function(m) task.spawn(label, m) end)
		for _, m in ipairs(mobs:GetChildren()) do task.spawn(label, m) end
	end)

	---------------------------------------------------------------- input
	local function cycleHotbar(dir)
		if not state then return end
		local i = state.sel or 0
		i = ((i - 1 + dir) % Config.HOTBAR) + 1
		if state.sel == 0 then i = dir > 0 and 1 or Config.HOTBAR end
		act("select", i)
	end
	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel and not modalKind then
			cycleHotbar(input.Position.Z > 0 and -1 or 1)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not state then return end
		local k = input.KeyCode
		-- controller buttons (PlayStation / Xbox); work even while a menu has focus
		if k == Enum.KeyCode.ButtonL1 and not modalKind then cycleHotbar(-1) return end
		if k == Enum.KeyCode.ButtonR1 and not modalKind then cycleHotbar(1) return end
		if k == Enum.KeyCode.ButtonY then
			if modalKind == "bag" then closeModal() elseif not modalKind then pending = nil bagModal() end
			return
		end
		if k == Enum.KeyCode.DPadUp and not modalKind then skillsModal() return end
		if k == Enum.KeyCode.DPadDown and not modalKind then menuModal() return end
		if k == Enum.KeyCode.DPadLeft and not modalKind then indexModal() return end
		if k == Enum.KeyCode.DPadRight and not modalKind then act("map") mapModal() return end
		if processed then return end
		if k == Enum.KeyCode.M then
			if modalKind == "menu" then closeModal() elseif not modalKind then menuModal() end
			return
		end
		local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }
		for i, k in ipairs(keys) do
			if input.KeyCode == k then act("select", state.sel == i and 0 or i) end
		end
		if input.KeyCode == Enum.KeyCode.B then
			if modalKind == "bag" then closeModal() else pending = nil bagModal() end
		elseif input.KeyCode == Enum.KeyCode.K then
			if modalKind == "skills" then closeModal() else skillsModal() end
		elseif input.KeyCode == Enum.KeyCode.N then
			if modalKind == "map" then closeModal() else act("map") mapModal() end
		elseif input.KeyCode == Enum.KeyCode.I then
			if modalKind == "index" then closeModal() else indexModal() end
		end
	end)

	---------------------------------------------------------------- server events
	remotes.State.OnClientEvent:Connect(function(s)
		local first = state == nil
		state = s
		if first then act("map") end
		lang = s.lang or lang
		levelText.Text = T("level") .. " " .. s.level
		UI.tween(xpFill, 0.35, { Size = UDim2.fromScale(math.clamp(s.into / math.max(1, s.need), 0, 1), 1) })
		xpText.Text = Format.number(s.into) .. " / " .. Format.number(s.need) .. " XP"
		dayText.Text = Locale.f(lang, "day", s.day or 1)
		setCoins(s.coins)
		spText.Text = Format.number(s.sp)
		codeText.Text = tostring(s.code or "...")
		local hpR = math.clamp(s.hp / math.max(1, s.maxHp), 0, 1)
		UI.tween(hpFill, 0.3, { Size = UDim2.fromScale(hpR, 1) })
		hpFill.BackgroundColor3 = hpR < 0.3 and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(226, 76, 76)
		hpText.Text = math.floor(s.hp + 0.5) .. " / " .. math.floor(s.maxHp)
		UI.tween(foodFill, 0.3, { Size = UDim2.fromScale(math.clamp(s.hunger / 100, 0, 1), 1) })
		foodFill.BackgroundColor3 = s.hunger < 20 and Color3.fromRGB(255, 90, 60) or Color3.fromRGB(232, 152, 70)
		-- cold pushes the needle right, heat pushes it left
		local tilt = math.clamp((37 - s.temp) / 2.5, -1, 1) * 80
		UI.tween(needleHolder, 0.5, { Rotation = tilt }, Enum.EasingStyle.Back)
		tempText.Text = string.format("%.1f°", s.temp)
		tempText.TextColor3 = (s.temp < 35 and Color3.fromRGB(120, 190, 255)) or (s.temp > 39.5 and Color3.fromRGB(255, 120, 90)) or c.text
		local ad = s.armor and Items.get(s.armor)
		local red = ad and ad.reduce or 0
		UI.tween(armorFill, 0.3, { Size = UDim2.fromScale(math.clamp(red / 0.45, 0, 1), 1) })
		armorText.Text = ad and (Items.name(s.armor, lang) .. "  " .. math.floor(red * 100 + 0.5) .. "%") or "0%"
		-- active potions
		local bsig = ""
		for k, v in pairs(s.buffs or {}) do bsig ..= k .. math.floor(v / 5) end
		if bsig ~= (buffBar:GetAttribute("Sig") or "") then
			buffBar:SetAttribute("Sig", bsig)
			for _, ch in ipairs(buffBar:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
			for k, v in pairs(s.buffs or {}) do
				local chip = UI.frame({ Size = UDim2.fromOffset(150, 28), BackgroundColor3 = c.panel, BackgroundTransparency = 0.15, Parent = buffBar })
				UI.corner(chip, 14)
				UI.text({ Text = T("buff_" .. k) .. "  " .. string.format("%d:%02d", v // 60, v % 60), Size = UDim2.fromScale(1, 1), TextSize = 15, TextColor3 = c.gold, Parent = chip })
			end
		end
		Effects.vision = s.buffs ~= nil and s.buffs.vision ~= nil
		sleepShade.Visible = s.sleeping == true
		sleepShade.Hint.Text = T("sleepHint")
		sleepShade.Wake.Text = T("wake")
		if s.night ~= lastNight then
			lastNight = s.night
			clockIcon:ClearAllChildren()
			Icons.draw(s.night and "moon" or "sun", clockIcon, 22, s.night and Color3.fromRGB(200, 210, 255) or c.gold, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), c.card)
		end
		-- slots: only rebuild what changed
		local parts = { tostring(s.sel), tostring(s.bag), tostring(s.armor), tostring(s.off and (s.off.id .. ":" .. tostring(s.off.d))) }
		for i, sl in ipairs(s.slots) do parts[#parts + 1] = sl and (sl.id .. ":" .. sl.n .. ":" .. tostring(sl.d)) or "-" end
		local sig = table.concat(parts, "|")
		local sk = {}
		for _, k in ipairs(Config.SKILLS) do sk[#sk + 1] = tostring(s.skills and s.skills[k] or 0) end
		local msig = sig .. "#" .. s.sp .. "#" .. s.coins .. "#" .. table.concat(sk, ",")
		if sig ~= lastSig then
			lastSig = sig
			for i = 1, Config.HOTBAR do hot[i].set(s.slots[i], s.sel == i or s.lamp == i) end
			if modalKind then refreshModal(true) end
		elseif msig ~= (lastMsig or "") and (modalKind == "skills" or modalKind == "shop") then
			refreshModal(true)
		end
		lastMsig = msig
		local dsig = ""
		if s.dex then
			local n, k = 0, 0
			for _ in pairs(s.dex.seen or {}) do n += 1 end
			for _, v in pairs(s.dex.kills or {}) do k += v end
			local m = 0
			for _ in pairs(s.dex.medals or {}) do m += 1 end
			dsig = n .. ":" .. k .. ":" .. m .. ":" .. tostring(s.dex.neck)
		end
		if dsig ~= (lastDsig or "") and modalKind == "index" then indexModal() end
		lastDsig = dsig
	end)

	---------------------------------------------------------------- event feed (bottom left, like a game chat)
	local feedBox = UI.frame({ Size = UDim2.fromOffset(460, 190), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, UserInputService.TouchEnabled and -235 or -100), BackgroundTransparency = 1, Parent = root })
	local fl = UI.list(feedBox, 4, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left)
	if fl then fl.VerticalAlignment = Enum.VerticalAlignment.Bottom end
	local feedN = 0
	local function esc(t) return (tostring(t):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
	local function nameTag(n) return '<font color="#ffd35a">' .. esc(n) .. "</font>" end
	local function mobTag(k) return '<font color="#ff8a6a">' .. esc(T("mob_" .. tostring(k))) .. "</font>" end
	local function feedLine(d)
		local k, a, b = d.k, d.a, d.b
		local text
		if k == "death" then
			if Bestiary.kinds[b] then text = Locale.f(lang, "f_deathMob", nameTag(a), mobTag(b))
			elseif type(b) == "string" and b:sub(1, 1) == "@" then text = Locale.f(lang, "f_deathPlayer", nameTag(a), nameTag(b:sub(2)))
			else text = Locale.f(lang, "f_death", nameTag(a), esc(T("cause_" .. tostring(b)))) end
		elseif k == "level" then text = Locale.f(lang, "f_level", nameTag(a), tostring(b))
		elseif k == "medal" then text = Locale.f(lang, "f_medal", nameTag(a), esc(T("biome_" .. tostring(b))))
		elseif k == "bossSpawn" then text = Locale.f(lang, "f_bossSpawn", mobTag(a))
		elseif k == "bossDown" then text = Locale.f(lang, "f_bossDown", nameTag(b), mobTag(a))
		elseif k == "blackMoved" then text = T("f_blackMoved")
		else text = Locale.f(lang, "f_" .. tostring(k), nameTag(a)) end
		feedN += 1
		-- right-to-left mark keeps Arabic sentences in order even when they start with a latin name
		if lang == "ar" then text = utf8.char(0x200F) .. text end
		local line = UI.text({ Text = text, RichText = true, LayoutOrder = feedN, Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, TextColor3 = Color3.fromRGB(240, 242, 245), BackgroundColor3 = Color3.fromRGB(12, 14, 18), BackgroundTransparency = 0.35, TextStrokeTransparency = 1, Parent = feedBox })
		UI.new("UISizeConstraint", { MaxSize = Vector2.new(460, 200), Parent = line })
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = line })
		UI.corner(line, 8)
		local lines = {}
		for _, ch in ipairs(feedBox:GetChildren()) do if ch:IsA("TextLabel") then table.insert(lines, ch) end end
		table.sort(lines, function(x, y) return x.LayoutOrder < y.LayoutOrder end)
		while #lines > 7 do table.remove(lines, 1):Destroy() end
		task.delay(9, function()
			if line.Parent then
				UI.tween(line, 1, { TextTransparency = 1, BackgroundTransparency = 1, TextStrokeTransparency = 1 })
				task.delay(1.05, function() line:Destroy() end)
			end
		end)
	end

	local deathShade = nil
	local function deathScreen(cause)
		if deathShade then deathShade:Destroy() end
		if closeModal then closeModal() end
		local shade = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(40, 0, 0), BackgroundTransparency = 1, ZIndex = 200, Parent = root })
		deathShade = shade
		UI.tween(shade, 0.8, { BackgroundTransparency = 0.25 })
		local title = UI.text({ Text = T("youDied"), Size = UDim2.new(1, 0, 0, 70), Position = UDim2.new(0, 0, 0.32, 0), TextSize = 56, TextColor3 = Color3.fromRGB(255, 90, 80), TextTransparency = 1, ZIndex = 201, Parent = shade })
		UI.tween(title, 0.8, { TextTransparency = 0 })
		local who = Bestiary.kinds[cause] and T("mob_" .. cause)
			or (type(cause) == "string" and cause:sub(1, 1) == "@" and cause:sub(2))
			or T("cause_" .. tostring(cause))
		UI.text({ Text = Locale.f(lang, "killedBy", who), Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.32, 78), TextSize = 22, ZIndex = 201, Parent = shade })
		UI.text({ Text = T("itemsLeft"), Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0.32, 112), TextSize = 16, TextColor3 = c.dim, ZIndex = 201, Parent = shade })
		local count = UI.text({ Text = "", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0.32, 150), TextSize = 30, TextColor3 = c.gold, ZIndex = 201, Parent = shade })
		Effects.ui("closed")
		task.spawn(function()
			for i = 5, 1, -1 do
				if not shade.Parent then return end
				count.Text = Locale.f(lang, "respawnIn", i)
				task.wait(1)
			end
		end)
	end
	player.CharacterAdded:Connect(function()
		if deathShade then
			local d = deathShade
			deathShade = nil
			UI.tween(d, 0.5, { BackgroundTransparency = 1 })
			for _, ch in ipairs(d:GetChildren()) do if ch:IsA("TextLabel") then UI.tween(ch, 0.4, { TextTransparency = 1 }) end end
			task.delay(0.6, function() d:Destroy() end)
		end
	end)

	remotes.Notify.OnClientEvent:Connect(function(key, a, b)
		if key == "openShop" then
			shopId = a or "forest"
			if state then shopModal() end
			return
		end
		if key == "feed" then
			if type(a) == "table" then pcall(feedLine, a) end
			return
		end
		if key == "mapData" then
			mapPoisList = a or {}
			if type(b) == "table" then
				mapExplored, mapExplored2, caveMask, maskN = b[1] or "", b[2] or "", b[3] or "", b[4] or 96
			end
			if modalKind == "map" then mapModal() end
			return
		end
		if key == "explored" then
			mapExplored = a or mapExplored
			mapExplored2 = b or mapExplored2
			return
		end
		if key == "deathBy" then
			deathScreen(a)
			return
		end
		if key == "openCrate" or key == "crateData" then
			if key == "crateData" and not (crateOpen and crateOpen.id == a and modalKind == "crate") then return end
			crateOpen = { id = a, view = b or { items = {}, coins = 0 } }
			if state then crateModal() end
			if key == "crateData" and #crateOpen.view.items == 0 and (crateOpen.view.coins or 0) == 0 then
				task.delay(0.6, function() if modalKind == "crate" and closeModal then closeModal() end end)
			end
			return
		end
		if key == "openFurnace" or key == "furnace" then
			furnaceData = a
			if key == "openFurnace" and state then pending = nil furnaceModal()
			elseif modalKind == "furnace" then refreshFurnace() end
			return
		end
		if key == "openStash" then
			if state then stashModal() end
			return
		end
		if key == "joinRequest" then
			local box = UI.frame({ Size = UDim2.fromOffset(420, 120), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), BackgroundColor3 = c.panel, ZIndex = 120, Parent = root })
			UI.corner(box, 16)
			UI.stroke(box, c.gold, 2)
			UI.enter(box, 0, -20)
			UI.text({ Text = Locale.f(lang, "joinRequest", tostring(a)), Size = UDim2.new(1, -20, 0, 46), Position = UDim2.fromOffset(10, 6), TextSize = 20, ZIndex = 121, Parent = box })
			local function answer(ok)
				act("answerReq", b, ok)
				box:Destroy()
			end
			UI.button({ Text = T("accept"), Size = UDim2.fromOffset(180, 46), Position = UDim2.fromOffset(20, 60), ZIndex = 121, Parent = box }, function() answer(true) end)
			UI.button({ Text = T("decline"), Size = UDim2.fromOffset(180, 46), Position = UDim2.fromOffset(220, 60), BackgroundColor3 = c.danger, TextColor3 = c.text, ZIndex = 121, Parent = box }, function() answer(false) end)
			Effects.ui("clickBright")
			task.delay(45, function() if box.Parent then answer(false) end end)
			return
		end
		local text
		if key == "picked" then text = string.format("+%d %s", b or 1, Items.name(a, lang))
		elseif key == "levelUp" then text = Locale.f(lang, "levelUp", a or 1)
		elseif key == "sold" then text = Locale.f(lang, "sold", a or 0)
		elseif key == "coinsGot" then text = Locale.f(lang, "coinsGot", a or 0)
		elseif key == "skillUp" then text = Locale.f(lang, "skillUp", T("sk_" .. tostring(a)))
		elseif key == "spGot" then text = Locale.f(lang, "spGot", a or 1)
		elseif key == "newDay" then text = Locale.f(lang, "newDay", a or 1)
		elseif key == "stashUp" then text = Locale.f(lang, "stashUp", a or 10)
		elseif key == "discovered" then text = Locale.f(lang, "discovered", T("mob_" .. tostring(a))) Effects.ui("pop")
		elseif key == "medalGot" then text = Locale.f(lang, "medalGot", T("biome_" .. tostring(a))) Effects.ui("skill")
		elseif key == "weakHit" then text = T("weakHit") Effects.ui("skill")
		elseif key == "adminDone" then text = Locale.f(lang, "adminDone", a or 0)
		elseif key == "drank" then text = Locale.f(lang, "drank", Items.name(a, lang)) Effects.ui("skill")
		elseif key == "buffEnd" then text = Locale.f(lang, "buffEnd", T("buff_" .. tostring(a)))
		elseif key == "sleepCount" then
			sleepText.Text = Locale.f(lang, "sleeping", a or 0, b or 1)
			return
		elseif key == "sleepStart" or key == "woke" then return
		elseif key == "bossSpawn" then text = Locale.f(lang, "bossSpawnX", T("mob_" .. tostring(a or "guardian")))
		elseif key == "bossDown" then text = Locale.f(lang, "bossDownX", T("mob_" .. tostring(a or "guardian")))
		else text = T(key) end
		local color = (key == "bossSpawn" or key == "died") and Color3.fromRGB(90, 30, 30) or nil
		if key == "picked" then
			local ore = (a == "stone" or a == "iron" or a == "gold" or a == "diamond" or a == "crystal" or a == "obsidian")
			Effects.ui(a == "wood" and "collectWood" or (ore and "collectStone" or "pop"))
		elseif key == "coinsGot" then Effects.ui("coin")
		elseif key == "sold" then Effects.ui("sell")
		elseif key == "bought" then
			Effects.ui("buy")
			-- little burst of gold sparks from the centre of the screen
			for i = 1, 14 do
				local d = UI.frame({ Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.72, 0.5), BackgroundColor3 = c.gold, ZIndex = 150, Parent = root })
				UI.corner(d, 5)
				local ang = i / 14 * math.pi * 2
				UI.tween(d, 0.6, { Position = UDim2.new(0.72, math.cos(ang) * 140, 0.5, math.sin(ang) * 140), BackgroundTransparency = 1, Size = UDim2.fromOffset(4, 4) })
				task.delay(0.62, function() d:Destroy() end)
			end
		elseif key == "skillUp" or key == "spGot" then Effects.ui("skill")
		elseif key == "shopClosed" then Effects.ui("closed") end
		UI.toast(root, text, color)
	end)

	Effects.report = function(msg) act("report", msg) end
	Effects.onRegion = function(b)
		UI.toast(root, T("biome_" .. b))
	end
	Effects.onCave = function()
		UI.toast(root, T("caveIn"))
	end
	act("state")
	task.delay(5, function() if state then UI.toast(root, T("tip")) end end)
	return { bagModal = bagModal, shopModal = shopModal, menuModal = menuModal, skillsModal = skillsModal, adminWarnModal = adminWarnModal, indexModal = indexModal }
end

return M
