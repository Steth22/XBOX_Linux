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
	local lastSig = ""
	local lastMsig = nil
	local lastDsig = nil

	local function T(k) return Locale.t(lang, k) end
	local function act(action, a, b)
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
		if modalKind == "bag" and bagPanel and bagPanel.Parent and not inside(bagPanel, p) then
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
				local data = state and state.slots[press.index]
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
		end)
		closeModal = close
		return content, panel
	end

	local bagW, bagInfo, bagShape = {}, nil, ""
	local refreshBag
	local function bagModal()
		local content, panel = openModal("bag", T("bag"), UDim2.fromOffset(500, 560))
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
		local hb = UI.frame({ Size = UDim2.new(1, 0, 0, 72), Position = UDim2.fromOffset(0, 28), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.list(hb, 8, Enum.FillDirection.Horizontal)
		for i = 1, Config.HOTBAR do
			local w = slotWidget(hb, 66, i)
			w.button.ZIndex = 54
			register(w, i, function() tap(i) end)
			bagW[i] = w
		end
		local grid = UI.frame({ Size = UDim2.new(1, 0, 0, 3 * 74), Position = UDim2.fromOffset(0, 114), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(66, 66), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
		for k = 1, Config.BAG do
			local i = Config.HOTBAR + k
			local w = slotWidget(grid, 66, k)
			if state.bag then
				register(w, i, function() tap(i) end)
				bagW[i] = w
			else
				local shade = UI.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 8, Parent = w.button })
				UI.corner(shade, 12)
				Icons.draw("lock", shade, 22, c.dim, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			end
		end
		bagInfo = UI.frame({ Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 114 + 3 * 74 + 4), BackgroundTransparency = 1, ZIndex = 53, Parent = content })
		refreshBag()
	end

	function refreshBag()
		if modalKind ~= "bag" or not state then return end
		for i, w in pairs(bagW) do
			if w.button.Parent then w.set(state.slots[i], pending == i) end
		end
		if not bagInfo or not bagInfo.Parent then return end
		bagInfo:ClearAllChildren()
		local d = pending and state.slots[pending]
		if pending and not d then pending = nil end
		if d then
			UI.text({ Text = Items.name(d.id, lang) .. (d.n > 1 and ("  x" .. d.n) or ""), Size = UDim2.new(1, 0, 0, 32), TextSize = 19, TextColor3 = c.gold, ZIndex = 53, Parent = bagInfo })
			local row = UI.frame({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 36), BackgroundTransparency = 1, ZIndex = 53, Parent = bagInfo })
			UI.list(row, 8, Enum.FillDirection.Horizontal)
			local idx = pending
			local function btn(text, color, cb)
				UI.button({ Text = text, Size = UDim2.fromOffset(140, 44), BackgroundColor3 = color, TextColor3 = c.text, TextSize = 17, ZIndex = 54, Parent = row }, cb)
			end
			btn(T("drop1"), c.card2, function() act("discard", idx, 1) end)
			if d.n > 1 then
				btn(T("dropAll"), c.danger, function() act("discard", idx) pending = nil end)
				btn(T("split"), c.blue, function() act("split", idx) end)
			end
		elseif state.armor then
			local ar = UI.frame({ Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = c.card, ZIndex = 53, Parent = bagInfo })
			UI.corner(ar, 12)
			ItemView.new(ar, state.armor, UDim2.fromOffset(46, 46), UDim2.fromOffset(4, 3), 55)
			UI.text({ Text = T("armorLbl") .. ": " .. Items.name(state.armor, lang), Size = UDim2.new(1, -170, 1, 0), Position = UDim2.fromOffset(58, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 16, ZIndex = 54, Parent = ar })
			UI.button({ Text = T("unequip"), Size = UDim2.fromOffset(100, 38), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), BackgroundColor3 = c.card2, TextColor3 = c.text, TextSize = 15, ZIndex = 55, Parent = ar }, function()
				act("unequipArmor")
			end)
		elseif not state.bag then
			UI.text({ Text = T("vendorTip") .. "  -  " .. Locale.f(lang, "buyBag", Config.BAG) .. "  " .. Format.number(state.bagPrice), Size = UDim2.new(1, 0, 0, 44), TextSize = 16, TextColor3 = c.gold, ZIndex = 53, Parent = bagInfo })
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
		local invCount = state.bag and (Config.HOTBAR + Config.BAG) or Config.HOTBAR
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
			for _, folderName in ipairs({ "Camp", "Outposts", "BlackMarkets", "Villages" }) do
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
		local content, panel = openModal("shop", shopId == "black" and T("o_black") or T("o_vendor"), UDim2.fromOffset(540, 560))
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
	local function indexModal()
		local content = openModal("index", T("index"), UDim2.fromOffset(660, 600))
		local dex = state.dex or { seen = {}, kills = {}, medals = {} }
		local seenN = 0
		for _ in pairs(dex.seen or {}) do seenN += 1 end
		local head = UI.frame({ Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = c.card, ZIndex = 53, Parent = content })
		UI.corner(head, 18)
		Icons.draw("book", head, 22, c.gold, UDim2.new(lang == "ar" and 1 or 0, lang == "ar" and -12 or 12, 0.5, 0), Vector2.new(lang == "ar" and 1 or 0, 0.5))
		UI.text({ Text = Locale.f(lang, "found", seenN, Bestiary.total()), Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(lang == "ar" and 10 or 46, 0), TextXAlignment = UI.align(lang), TextSize = 17, TextColor3 = c.gold, ZIndex = 54, Parent = head })
		-- region tabs
		local tabs = UI.scroll({ Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 42), ZIndex = 53, Parent = content })
		tabs.ScrollingDirection = Enum.ScrollingDirection.X
		tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
		tabs.CanvasSize = UDim2.new()
		UI.list(tabs, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left)
		for i, reg in ipairs(Bestiary.regions) do
			local on = indexTab == reg.key
			local b = UI.button({ Text = T("biome_" .. reg.key), LayoutOrder = i, Size = UDim2.fromOffset(112, 38), TextSize = 15, BackgroundColor3 = on and c.gold or c.card, TextColor3 = on and c.bg or c.text, ZIndex = 54, Parent = tabs }, function()
				indexTab = reg.key
				indexModal()
			end)
			if dex.medals and dex.medals[reg.key] then
				local dot = UI.frame({ Size = UDim2.fromOffset(10, 10), Position = UDim2.new(1, -14, 0, 4), BackgroundColor3 = Biomes.medal[reg.key], ZIndex = 56, Parent = b })
				UI.corner(dot, 5)
			end
		end
		local reg = Bestiary.region(indexTab)
		-- the region's necklace
		local medal = UI.frame({ Size = UDim2.new(1, 0, 0, 62), Position = UDim2.fromOffset(0, 92), BackgroundColor3 = c.card, ZIndex = 53, Parent = content })
		UI.corner(medal, 12)
		local got = dex.medals and dex.medals[indexTab]
		local killedKinds = 0
		for _, k in ipairs(reg.kinds) do if dex.kills and (dex.kills[k] or 0) > 0 then killedKinds += 1 end end
		local mi = UI.frame({ Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(lang == "ar" and 1 or 0, 0.5), Position = UDim2.new(lang == "ar" and 1 or 0, lang == "ar" and -8 or 8, 0.5, 0), BackgroundTransparency = 1, ZIndex = 54, Parent = medal })
		Icons.draw("medal", mi, 44, got and Biomes.medal[indexTab] or c.card2, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
		UI.text({ Text = Locale.f(lang, "medal", T("biome_" .. indexTab)) .. "   " .. killedKinds .. "/" .. #reg.kinds, Size = UDim2.new(1, -200, 0, 26), Position = UDim2.new(lang == "ar" and 1 or 0, lang == "ar" and -64 or 64, 0, 6), AnchorPoint = Vector2.new(lang == "ar" and 1 or 0, 0), TextXAlignment = UI.align(lang), TextSize = 17, TextColor3 = got and Biomes.medal[indexTab] or c.text, ZIndex = 54, Parent = medal })
		UI.text({ Text = T("medalNeed"), Size = UDim2.new(1, -200, 0, 20), Position = UDim2.new(lang == "ar" and 1 or 0, lang == "ar" and -64 or 64, 0, 34), AnchorPoint = Vector2.new(lang == "ar" and 1 or 0, 0), TextXAlignment = UI.align(lang), TextSize = 13, TextColor3 = c.dim, ZIndex = 54, Parent = medal })
		if got then
			local wearing = dex.neck == indexTab
			UI.button({ Text = wearing and T("wearing") or T("wear"), Size = UDim2.fromOffset(110, 40), AnchorPoint = Vector2.new(lang == "ar" and 0 or 1, 0.5), Position = UDim2.new(lang == "ar" and 0 or 1, lang == "ar" and 10 or -10, 0.5, 0), BackgroundColor3 = wearing and c.card2 or c.gold, TextColor3 = wearing and c.text or c.bg, TextSize = 16, ZIndex = 55, Parent = medal }, function()
				if not wearing then act("wearMedal", indexTab) end
			end)
		end
		-- creature cards
		local grid = UI.scroll({ Size = UDim2.new(1, 0, 1, -162), Position = UDim2.fromOffset(0, 160), ZIndex = 53, Parent = content })
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(150, 186)
		gl.CellPadding = UDim2.fromOffset(8, 8)
		gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = grid
		for i, kind in ipairs(reg.kinds) do
			local seen = dex.seen and dex.seen[kind]
			local ty = Bestiary.kinds[kind]
			local card = UI.frame({ LayoutOrder = i, BackgroundColor3 = seen and c.card or c.panel, ZIndex = 54, Parent = grid })
			UI.corner(card, 12)
			UI.stroke(card, seen and (TYPE_COLOR[ty] or c.card2) or c.card2, 2)
			local view = UI.frame({ Size = UDim2.new(1, -12, 0, 104), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = c.bg, ZIndex = 55, Parent = card })
			UI.corner(view, 10)
			if seen then
				mobView(view, kind)
				UI.text({ Text = T("mob_" .. kind), Size = UDim2.new(1, -8, 0, 24), Position = UDim2.fromOffset(4, 112), TextSize = 16, ZIndex = 55, Parent = card })
				local chip = UI.frame({ Size = UDim2.fromOffset(84, 20), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 138), BackgroundColor3 = TYPE_COLOR[ty] or c.card2, ZIndex = 55, Parent = card })
				UI.corner(chip, 10)
				UI.text({ Text = T("ty_" .. ty), Size = UDim2.fromScale(1, 1), TextSize = 13, TextColor3 = c.bg, ZIndex = 56, Parent = chip })
				UI.text({ Text = Locale.f(lang, "kills", dex.kills and dex.kills[kind] or 0), Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 162), TextSize = 13, TextColor3 = c.dim, ZIndex = 55, Parent = card })
			else
				UI.text({ Text = "?", Size = UDim2.fromScale(1, 1), TextSize = 54, TextColor3 = c.card2, ZIndex = 56, Parent = view })
				UI.text({ Text = T("unknown"), Size = UDim2.new(1, -8, 0, 40), Position = UDim2.fromOffset(4, 120), TextWrapped = true, TextSize = 14, TextColor3 = c.dim, ZIndex = 55, Parent = card })
			end
			UI.enter(card, i * 0.03, 10)
		end
	end

	---------------------------------------------------------------- world map (only what you have explored)
	local mapPoisList, mapExplored = {}, ""
	local REGION_COLOR = {
		forest = Color3.fromRGB(70, 128, 60), hills = Color3.fromRGB(128, 156, 88), snow = Color3.fromRGB(226, 232, 240),
		desert = Color3.fromRGB(218, 188, 128), mountains = Color3.fromRGB(128, 128, 138), beach = Color3.fromRGB(224, 208, 158),
		jungle = Color3.fromRGB(36, 104, 58), volcano = Color3.fromRGB(82, 52, 46),
	}
	local SEA = Color3.fromRGB(44, 92, 140)
	local function cellColor(x, z)
		local d = math.max(math.abs(x), math.abs(z))
		if d > Biomes.SEA then return SEA end
		local col = REGION_COLOR[Biomes.at(x, z)] or REGION_COLOR.forest
		local n = math.noise(x / 180, z / 180, 5.5) * 0.18
		return n > 0 and col:Lerp(Color3.new(1, 1, 1), n) or col:Lerp(Color3.new(0, 0, 0), -n)
	end
	local mapCells = {} -- index -> Frame (kept between opens)
	local function mapModal()
		local content = openModal("map", T("map"), UDim2.fromOffset(580, 650))
		local N = Config.MAP_CELLS
		local SIZE = 500
		local cell = SIZE / N
		local H = Biomes.HALF
		local seen = 0
		for i = 1, #mapExplored do if mapExplored:sub(i, i) == "1" then seen += 1 end end
		UI.text({ Text = Locale.f(lang, "explored", math.floor(seen / (N * N) * 100 + 0.5)), Size = UDim2.new(1, 0, 0, 22), TextSize = 15, TextColor3 = c.dim, ZIndex = 53, Parent = content })
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
			return mapExplored:sub(i, i) == "1"
		end
		-- terrain of the explored cells
		mapCells = {}
		for i = 1, #mapExplored do
			if mapExplored:sub(i, i) == "1" then
				local cx, cz = (i - 1) % N, (i - 1) // N
				local wx, wz = -H + (cx + 0.5) * (2 * H / N), -H + (cz + 0.5) * (2 * H / N)
				mapCells[i] = UI.frame({ Size = UDim2.fromOffset(math.ceil(cell) + 1, math.ceil(cell) + 1), Position = UDim2.fromOffset(cx * cell, cz * cell), BackgroundColor3 = cellColor(wx, wz), BorderSizePixel = 0, ZIndex = 54, Parent = board })
			end
		end
		-- places
		local function marker(kind, x, z, color, size)
			local holder = UI.frame({ Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Position = toMap(x, z), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BackgroundTransparency = 0.25, ZIndex = 56, Parent = board })
			UI.corner(holder, size / 2)
			Icons.draw(kind, holder, size * 0.72, color, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
			return holder
		end
		local ICON = { village = { "village", c.gold }, trader = { "coin", Color3.fromRGB(255, 210, 90) }, cave = { "cave", Color3.fromRGB(170, 150, 200) } }
		for _, poi in ipairs(mapPoisList) do
			local def = ICON[poi[1]]
			if def and explored(poi[2], poi[3]) then marker(def[1], poi[2], poi[3], def[2], 22) end
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
		for _, l in ipairs({ { "village", c.gold, "leg_village" }, { "coin", Color3.fromRGB(255, 210, 90), "leg_trader" }, { "cave", Color3.fromRGB(170, 150, 200), "leg_cave" }, { "close", Color3.fromRGB(255, 70, 60), "leg_death" }, { "dot", Color3.fromRGB(120, 255, 140), "leg_players" } }) do
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
					local r = pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
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
	mini = UI.button({ Text = "", Size = UDim2.fromOffset(MINI, MINI), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -464, 0, 10), BackgroundColor3 = Color3.fromRGB(16, 18, 22), BackgroundTransparency = 0.1, ClipsDescendants = true, AutoButtonColor = false, Parent = root }, function()
		if modalKind == "map" then closeModal() elseif state then act("map") mapModal() end
	end)
	UI.corner(mini, 14)
	UI.stroke(mini, c.card2, 2)
	local K = MINI / VIEW -- pixels per stud
	local H2 = Biomes.HALF
	local canvas = UI.frame({ Size = UDim2.fromOffset(2 * H2 * K, 2 * H2 * K), BackgroundTransparency = 1, ZIndex = 2, Parent = mini })
	local miniCells, miniPois = {}, {}
	local function miniPos(x, z) return UDim2.fromOffset((x + H2) * K, (z + H2) * K) end
	local function refreshMini()
		local N = Config.MAP_CELLS
		local cw = 2 * H2 / N
		for i = 1, #mapExplored do
			if mapExplored:sub(i, i) == "1" and not miniCells[i] then
				local cx, cz = (i - 1) % N, (i - 1) // N
				miniCells[i] = UI.frame({ Size = UDim2.fromOffset(math.ceil(cw * K) + 1, math.ceil(cw * K) + 1), Position = UDim2.fromOffset(cx * cw * K, cz * cw * K),
					BackgroundColor3 = cellColor(-H2 + (cx + 0.5) * cw, -H2 + (cz + 0.5) * cw), BorderSizePixel = 0, ZIndex = 3, Parent = canvas })
			end
		end
		local ICONS = { village = { "village", c.gold }, trader = { "coin", Color3.fromRGB(255, 210, 90) }, cave = { "cave", Color3.fromRGB(170, 150, 200) } }
		for idx, poi in ipairs(mapPoisList) do
			local cx = math.floor((poi[2] + H2) / cw)
			local cz = math.floor((poi[3] + H2) / cw)
			local i = cz * N + cx + 1
			if not miniPois[idx] and mapExplored:sub(i, i) == "1" and ICONS[poi[1]] then
				local h = UI.frame({ Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(0.5, 0.5), Position = miniPos(poi[2], poi[3]), BackgroundColor3 = Color3.fromRGB(20, 20, 24), BackgroundTransparency = 0.2, ZIndex = 5, Parent = canvas })
				UI.corner(h, 10)
				Icons.draw(ICONS[poi[1]][1], h, 14, ICONS[poi[1]][2], UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
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
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp or not mini.Visible then return end
		if mapExplored ~= lastExplored then
			lastExplored = mapExplored
			refreshMini()
		end
		local p = hrp.Position
		canvas.Position = UDim2.fromOffset(MINI / 2 - (p.X + H2) * K, MINI / 2 - (p.Z + H2) * K)
		local look = hrp.CFrame.LookVector
		meArrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
		if state and state.death then
			deathDot.Visible = true
			deathDot.Position = miniPos(state.death[1], state.death[2])
		else
			deathDot.Visible = false
		end
		for _, pl in ipairs(Players:GetPlayers()) do
			local r = pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
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
			if not pl.Parent or not pl.Character then dot:Destroy() miniOthers[pl] = nil end
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
		UI.text({ Text = T("code") .. ":  " .. tostring(state and state.code or "...") .. ((state and state.locked) and ("   |   " .. T("roomLocked")) or ""), Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 64), TextSize = 22, TextColor3 = c.gold, ZIndex = 53, Parent = content })
		local list = Players:GetPlayers()
		UI.text({ Text = T("inRoom") .. "  " .. #list .. " / " .. Config.MAX_PLAYERS, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 104), TextXAlignment = UI.align(lang), TextSize = 17, TextColor3 = c.dim, ZIndex = 53, Parent = content })
		local scroll = UI.scroll({ Size = UDim2.new(1, 0, 1, -138), Position = UDim2.fromOffset(0, 136), ZIndex = 53, Parent = content })
		UI.list(scroll, 6)
		for i, pl in ipairs(list) do
			local row = UI.frame({ Size = UDim2.new(1, -8, 0, 58), BackgroundColor3 = c.card, LayoutOrder = (pl.UserId == state.ownerId) and 0 or i, ZIndex = 54, Parent = scroll })
			UI.corner(row, 10)
			local tag = (pl.UserId == state.ownerId) and ("  (" .. T("owner") .. ")") or ((pl == player) and ("  (" .. T("you") .. ")") or "")
			UI.text({ Text = pl.DisplayName .. tag, Size = UDim2.new(0.55, 0, 1, 0), Position = UDim2.new(lang == "ar" and 0.45 or 0, lang == "ar" and -12 or 12, 0, 0), TextXAlignment = UI.align(lang), TextSize = 19, TextColor3 = (pl.UserId == state.ownerId) and c.gold or c.text, ZIndex = 55, Parent = row })
			if owner and pl ~= player then
				local bx = lang == "ar" and 0 or 1
				local holder = UI.frame({ Size = UDim2.fromOffset(212, 42), AnchorPoint = Vector2.new(bx, 0.5), Position = UDim2.new(bx, lang == "ar" and 8 or -8, 0.5, 0), BackgroundTransparency = 1, ZIndex = 55, Parent = row })
				UI.list(holder, 8, Enum.FillDirection.Horizontal)
				UI.button({ Text = T("kick"), Size = UDim2.fromOffset(100, 42), TextSize = 17, BackgroundColor3 = c.card2, TextColor3 = c.text, ZIndex = 56, Parent = holder }, function()
					act("kick", pl.UserId)
				end)
				local armed = false
				local banB
				banB = UI.button({ Text = T("ban"), Size = UDim2.fromOffset(100, 42), TextSize = 17, BackgroundColor3 = c.danger, TextColor3 = c.text, ZIndex = 56, Parent = holder }, function()
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

	function refreshModal(force)
		if modalKind == "bag" then
			if bagShape ~= (tostring(state.bag) .. tostring(state.armor)) then bagModal() else refreshBag() end
		elseif modalKind == "stash" then
			rebuilding = true
			stashModal()
			rebuilding = false
		elseif modalKind == "shop" and force then
			rebuilding = true
			shopModal()
			rebuilding = false
		elseif modalKind == "skills" and force then skillsModal() end
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
		local parts = { tostring(s.sel), tostring(s.bag), tostring(s.armor), tostring(s.lamp) }
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
	local feedBox = UI.frame({ Size = UDim2.fromOffset(460, 260), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, UserInputService.TouchEnabled and -235 or -100), BackgroundTransparency = 1, Parent = root })
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
			mapPoisList, mapExplored = a or {}, b or ""
			if modalKind == "map" then mapModal() end
			return
		end
		if key == "explored" then
			mapExplored = a or mapExplored
			return
		end
		if key == "deathBy" then
			deathScreen(a)
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
	return { bagModal = bagModal, shopModal = shopModal, menuModal = menuModal, skillsModal = skillsModal }
end

return M
