-- UI kit shared by lobby + world screens: theme, builders, animations.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local UI = {}

UI.c = {
	bg = Color3.fromRGB(14, 22, 20),
	panel = Color3.fromRGB(24, 36, 32),
	card = Color3.fromRGB(36, 54, 48),
	card2 = Color3.fromRGB(52, 76, 66),
	accent = Color3.fromRGB(78, 196, 118),
	gold = Color3.fromRGB(255, 200, 70),
	text = Color3.fromRGB(240, 245, 240),
	dim = Color3.fromRGB(150, 172, 162),
	danger = Color3.fromRGB(216, 88, 78),
	blue = Color3.fromRGB(80, 150, 230),
}

UI.font = Enum.Font.GothamBold

function UI.new(class, props, children)
	local o = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else o[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = o end
	if parent then o.Parent = parent end
	return o
end

function UI.corner(parent, r)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, r or 10), Parent = parent })
end

function UI.stroke(parent, color, th, tr)
	return UI.new("UIStroke", { Color = color or UI.c.card2, Thickness = th or 1.5, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end

function UI.pad(parent, px)
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px), Parent = parent,
	})
end

function UI.list(parent, gap, dir, hAlign)
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, gap or 8),
		FillDirection = dir or Enum.FillDirection.Vertical,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function UI.frame(props, children)
	local p = { BackgroundColor3 = UI.c.panel, BorderSizePixel = 0 }
	for k, v in pairs(props or {}) do p[k] = v end
	return UI.new("Frame", p, children)
end

function UI.text(props)
	local p = {
		BackgroundTransparency = 1, Font = UI.font, TextColor3 = UI.c.text, TextSize = 20,
		Text = "", TextWrapped = true, BorderSizePixel = 0,
	}
	for k, v in pairs(props or {}) do p[k] = v end
	return UI.new("TextLabel", p)
end

function UI.align(lang)
	return lang == "ar" and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
end

function UI.tween(obj, t, goal, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

function UI.button(props, onClick)
	local p = {
		BackgroundColor3 = UI.c.accent, TextColor3 = Color3.fromRGB(10, 24, 16), Font = UI.font,
		TextSize = 22, AutoButtonColor = false, BorderSizePixel = 0, Text = "", TextWrapped = true,
	}
	for k, v in pairs(props or {}) do p[k] = v end
	local b = UI.new("TextButton", p)
	UI.corner(b, 12)
	local sc = UI.new("UIScale", { Parent = b })
	local base = b.BackgroundColor3
	b:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		if not b:GetAttribute("Hover") then base = b.BackgroundColor3 end
	end)
	b.MouseEnter:Connect(function()
		b:SetAttribute("Hover", true)
		UI.tween(b, 0.12, { BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.12) })
		UI.tween(sc, 0.12, { Scale = 1.03 })
	end)
	b.MouseLeave:Connect(function()
		UI.tween(b, 0.12, { BackgroundColor3 = base })
		UI.tween(sc, 0.12, { Scale = 1 })
		task.delay(0.13, function() b:SetAttribute("Hover", nil) end)
	end)
	b.MouseButton1Down:Connect(function() UI.tween(sc, 0.08, { Scale = 0.93 }) end)
	b.MouseButton1Up:Connect(function() UI.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back) end)
	b.Activated:Connect(function()
		local ok, fx = pcall(function() return require(script.Parent:FindFirstChild("Effects")) end)
		if ok and fx then fx.ui("click") end
	end)
	if onClick then b.Activated:Connect(onClick) end
	return b
end

-- entrance animation: slide up + pop
function UI.enter(obj, delay, dy)
	local pos = obj.Position
	obj.Position = pos + UDim2.fromOffset(0, dy or 24)
	local sc = obj:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = obj })
	sc.Scale = 0.88
	task.delay(delay or 0, function()
		if not obj.Parent then return end
		UI.tween(obj, 0.4, { Position = pos }, Enum.EasingStyle.Back)
		UI.tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

function UI.scroll(props)
	local p = {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, ScrollBarImageColor3 = UI.c.card2,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	for k, v in pairs(props or {}) do p[k] = v end
	return UI.new("ScrollingFrame", p)
end

-- Fits Root to the screen at a comfortable scale on every device.
function UI.root(gui)
	local root = UI.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	local scale = UI.new("UIScale", { Parent = root })
	local function fit()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local s = math.clamp(math.min(vp.Y / 720, vp.X / 1000), 0.6, 1.6)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	fit()
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
	return root
end

local function drawX(parent, color)
	for _, rot in ipairs({ 45, -45 }) do
		local bar = UI.frame({ Size = UDim2.fromOffset(20, 3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = rot, BackgroundColor3 = color, ZIndex = parent.ZIndex + 1, Parent = parent })
		UI.corner(bar, 2)
	end
end

-- centered modal. returns content, close(), panel, closeNow(). `instant`: no opening animation
-- (used when a window is rebuilt in place, so it doesn't flicker)
function UI.modal(root, title, lang, size, onClose, instant)
	local overlay = UI.frame({
		Name = "Modal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1, ZIndex = 50, Active = true, Parent = root,
	})
	local panel = UI.frame({
		Size = size or UDim2.fromOffset(640, 440), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UI.c.panel, ZIndex = 51, Parent = overlay,
	})
	UI.corner(panel, 18)
	UI.stroke(panel, UI.c.card2, 2)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 212, 208)), Parent = panel })
	local sc = UI.new("UIScale", { Scale = instant and 1 or 0.82, Parent = panel })
	if instant then
		overlay.BackgroundTransparency = 0.45
	else
		UI.tween(overlay, 0.2, { BackgroundTransparency = 0.45 })
		UI.tween(sc, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	UI.text({
		Text = title, Size = UDim2.new(1, -90, 0, 44), Position = UDim2.fromOffset(18, 10), TextSize = 26, ZIndex = 52,
		TextXAlignment = UI.align(lang), Parent = panel,
	})
	local closing = false
	local function close()
		if closing then return end
		closing = true
		UI.tween(overlay, 0.15, { BackgroundTransparency = 1 })
		UI.tween(sc, 0.15, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.16, function() overlay:Destroy() end)
		if onClose then onClose() end
	end
	-- gone at once, without the closing animation
	local function closeNow()
		if closing then return end
		closing = true
		overlay:Destroy()
		if onClose then onClose() end
	end
	local x = UI.button({
		Text = "", Size = UDim2.fromOffset(42, 42), Position = lang == "ar" and UDim2.new(0, 12, 0, 10) or UDim2.new(1, -54, 0, 10),
		BackgroundColor3 = UI.c.card, ZIndex = 53, Parent = panel,
	}, close)
	drawX(x, UI.c.text)
	local content = UI.frame({
		Size = UDim2.new(1, -36, 1, -74), Position = UDim2.fromOffset(18, 62), BackgroundTransparency = 1, ZIndex = 52, Parent = panel,
	})
	-- controller: circle / B closes, and the first button gets selected so the stick can move around
	local backConn = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonB then close() end
	end)
	overlay.Destroying:Connect(function()
		backConn:Disconnect()
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(overlay) then GuiService.SelectedObject = nil end
	end)
	if UI.usingGamepad() then
		task.delay(0.35, function()
			if not overlay.Parent then return end
			for _, d in ipairs(content:GetDescendants()) do
				if d:IsA("GuiButton") and d.Visible and d.Selectable then
					GuiService.SelectedObject = d
					return
				end
			end
			GuiService.SelectedObject = x
		end)
	end
	return content, close, panel, closeNow
end

function UI.usingGamepad()
	local t = UserInputService:GetLastInputType()
	return t.Name:find("Gamepad") ~= nil
end

-- a small badge with the real button glyph of the current device (PlayStation / Xbox / keyboard)
function UI.keyHint(parent, keyboardText, gamepadKey, pos, anchor)
	local f = UI.frame({ Name = "KeyHint", Size = UDim2.fromOffset(28, 28), Position = pos, AnchorPoint = anchor or Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, ZIndex = 30, Parent = parent })
	UI.corner(f, 8)
	local img = UI.new("ImageLabel", { Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 31, Parent = f })
	local txt = UI.text({ Text = keyboardText or "", Size = UDim2.fromScale(1, 1), TextSize = 14, ZIndex = 31, Parent = f })
	local function update()
		local pad = UI.usingGamepad()
		local touch = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
		f.Visible = not touch and (pad and gamepadKey ~= nil or (not pad and keyboardText ~= nil))
		if pad and gamepadKey then
			local ok, image = pcall(function() return UserInputService:GetImageForKeyCode(gamepadKey) end)
			img.Image = ok and image or ""
			img.Visible = true
			txt.Visible = false
		else
			img.Visible = false
			txt.Visible = true
			f.Size = UDim2.fromOffset(math.max(28, #(keyboardText or "") * 9 + 12), 28)
		end
	end
	update()
	UserInputService.LastInputTypeChanged:Connect(update)
	return f
end

local toastBox
function UI.toast(root, text, color)
	if not toastBox or not toastBox.Parent then
		toastBox = UI.frame({ Name = "Toasts", Size = UDim2.new(1, 0, 0, 0), Position = UDim2.fromOffset(0, 112), BackgroundTransparency = 1, ZIndex = 100, Parent = root })
		UI.list(toastBox, 6)
	end
	local kids = {}
	for _, k in ipairs(toastBox:GetChildren()) do if k:IsA("Frame") then table.insert(kids, k) end end
	if #kids >= 4 then kids[1]:Destroy() end
	local t = UI.frame({
		Size = UDim2.fromOffset(0, 42), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = color or UI.c.panel,
		BackgroundTransparency = 0.05, ZIndex = 100, Parent = toastBox,
	})
	UI.corner(t, 21)
	local st = UI.stroke(t, UI.c.accent, 1.5)
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), Parent = t })
	local label = UI.text({
		Text = text, Size = UDim2.fromOffset(0, 42), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false,
		TextSize = 19, ZIndex = 101, TextTransparency = 1, Parent = t,
	})
	local sc = UI.new("UIScale", { Scale = 0.7, Parent = t })
	UI.tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.tween(label, 0.2, { TextTransparency = 0 })
	task.delay(2.6, function()
		if t.Parent then
			UI.tween(t, 0.3, { BackgroundTransparency = 1 })
			UI.tween(label, 0.3, { TextTransparency = 1 })
			UI.tween(st, 0.3, { Transparency = 1 })
			task.wait(0.32)
			t:Destroy()
		end
	end)
end

return UI
