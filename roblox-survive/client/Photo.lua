-- Photo studio (admin): a small bottom bar with tabs, and a panel for the open tab.
--   Look    filter, time of day (slider), weather
--   Camera  follow / free camera, lens and focus sliders, up / down
--   Pose    your character: ready-made poses, or each limb with sliders
--   Objects tap your character, a creature or an effect to select it; drag it on the ground,
--           turn it, tilt it, raise it, remove it
--   Effects put fire, smoke, embers, sparks, fireflies, snow, glow or a light where you tap
--   Hide    hides everything for the shot (a faint dot brings it back)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local P = {}
local active = false
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local FILTERS = {
	{ key = "natural", sat = 0.06, con = 0.06, tint = Color3.fromRGB(255, 255, 255), bri = 0, bloom = 0.35, rays = 0.05 },
	{ key = "golden", sat = 0.22, con = 0.12, tint = Color3.fromRGB(255, 228, 192), bri = 0.02, bloom = 0.6, rays = 0.16, haze = { 0.32, Color3.fromRGB(255, 200, 150) } },
	{ key = "cinema", sat = 0.12, con = 0.22, tint = Color3.fromRGB(236, 244, 255), bri = -0.02, bloom = 0.5, rays = 0.1, bars = true, haze = { 0.25, Color3.fromRGB(190, 205, 225) } },
	{ key = "night", sat = -0.05, con = 0.15, tint = Color3.fromRGB(185, 205, 255), bri = -0.03, bloom = 0.85, rays = 0 },
	{ key = "drama", sat = -1, con = 0.35, tint = Color3.fromRGB(255, 255, 255), bri = 0, bloom = 0.4, rays = 0.08, bars = true },
}
local WEATHER = { "clear", "wind", "rain", "storm" }
local FX = { "fire", "smoke", "embers", "sparks", "fireflies", "snow", "glow", "light" }

-- a placed effect: an invisible part carrying emitters / a light
local function makeFx(kind, at, folder)
	local p = Instance.new("Part")
	p.Name = "PhotoFx"
	p.Anchored, p.CanCollide, p.CanTouch = true, false, false
	p.CanQuery = true
	p.Transparency = 1
	p.Size = Vector3.new(3, 3, 3)
	p.CFrame = CFrame.new(at)
	p:SetAttribute("Kind", kind)
	p:SetAttribute("Scale", 1)
	local function em(props)
		local e = Instance.new("ParticleEmitter")
		for k, v in pairs(props) do e[k] = v end
		e.Parent = p
		return e
	end
	if kind == "fire" then
		em({ Texture = FIRE, Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 70, 20)), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0.2) }), Speed = NumberRange.new(5, 9), Lifetime = NumberRange.new(0.6, 1.1), Rate = 40, SpreadAngle = Vector2.new(12, 12), Transparency = NumberSequence.new(0.1, 1) })
		local l = Instance.new("PointLight") l.Color = Color3.fromRGB(255, 150, 70) l.Range = 22 l.Brightness = 3 l.Shadows = true l.Parent = p
	elseif kind == "smoke" then
		em({ Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(110, 106, 100)), Size = NumberSequence.new(3, 12), Speed = NumberRange.new(3, 6), Lifetime = NumberRange.new(4, 7), Rate = 8, RotSpeed = NumberRange.new(-30, 30), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.6), NumberSequenceKeypoint.new(1, 1) }) })
	elseif kind == "embers" then
		em({ Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 90, 30)), LightEmission = 1, Size = NumberSequence.new(0.3, 0.05), Speed = NumberRange.new(3, 8), Lifetime = NumberRange.new(2, 4), Rate = 30, SpreadAngle = Vector2.new(40, 40), Acceleration = Vector3.new(0.8, 1.5, 0) })
	elseif kind == "sparks" then
		em({ Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(255, 240, 180)), LightEmission = 1, Size = NumberSequence.new(0.4, 0), Speed = NumberRange.new(10, 22), Lifetime = NumberRange.new(0.3, 0.7), Rate = 60, SpreadAngle = Vector2.new(180, 180), Drag = 3 })
	elseif kind == "fireflies" then
		em({ Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(230, 255, 140)), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 0) }), Speed = NumberRange.new(0.5, 1.5), Lifetime = NumberRange.new(4, 7), Rate = 12, SpreadAngle = Vector2.new(180, 180) })
		p.Size = Vector3.new(30, 8, 30)
	elseif kind == "snow" then
		em({ Texture = SPARK, Color = ColorSequence.new(Color3.new(1, 1, 1)), Size = NumberSequence.new(0.3), Speed = NumberRange.new(4, 7), Lifetime = NumberRange.new(5, 8), Rate = 120, EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(15, 15), RotSpeed = NumberRange.new(-60, 60) })
		p.Size = Vector3.new(60, 1, 60)
		p.CFrame = CFrame.new(at + Vector3.new(0, 30, 0))
	elseif kind == "glow" then
		em({ Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(170, 120, 255)), LightEmission = 1, Size = NumberSequence.new(4, 0), Speed = NumberRange.new(0.5, 2), Lifetime = NumberRange.new(1, 2), Rate = 25, SpreadAngle = Vector2.new(180, 180) })
		local l = Instance.new("PointLight") l.Color = Color3.fromRGB(170, 120, 255) l.Range = 18 l.Brightness = 2 l.Parent = p
	elseif kind == "light" then
		local l = Instance.new("PointLight") l.Color = Color3.fromRGB(255, 220, 170) l.Range = 30 l.Brightness = 3 l.Shadows = true l.Parent = p
	end
	p.Parent = folder
	return p
end
local function scaleFx(p, s)
	local old = p:GetAttribute("Scale") or 1
	for _, d in ipairs(p:GetChildren()) do
		if d:IsA("ParticleEmitter") then
			local ks = {}
			for _, k in ipairs(d.Size.Keypoints) do table.insert(ks, NumberSequenceKeypoint.new(k.Time, k.Value / old * s, k.Envelope)) end
			d.Size = NumberSequence.new(ks)
			d.Rate = d.Rate / old * s
		elseif d:IsA("PointLight") then
			d.Range = math.clamp(d.Range / old * s, 2, 60)
		end
	end
	p:SetAttribute("Scale", s)
end

function P.start(env)
	if active then return end
	active = true
	local player = Players.LocalPlayer
	local T, act, Effects, UI = env.T, env.act, env.Effects, env.UI
	local c = UI.c
	local lang = env.lang or "ar"
	local cam = workspace.CurrentCamera

	-- hide everything else
	local hidden, billboards = {}, {}
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if (g:IsA("ScreenGui") or g:IsA("BillboardGui")) and g.Enabled then g.Enabled = false table.insert(hidden, g) end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BillboardGui") and d.Enabled then d.Enabled = false table.insert(billboards, d) end
	end
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
	Effects.photo = true
	act("admin", "freezeTime", true)
	act("admin", "holdMobs", true)

	-- the look
	local cc = Instance.new("ColorCorrectionEffect") cc.Name = "PhotoCC" cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect") bloom.Name = "PhotoBloom" bloom.Size = 32 bloom.Threshold = 1.2 bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect") rays.Name = "PhotoRays" rays.Spread = 0.55 rays.Parent = Lighting
	local dof = Instance.new("DepthOfFieldEffect") dof.Name = "PhotoDOF" dof.FarIntensity = 0.45 dof.NearIntensity = 0.25 dof.InFocusRadius = 12 dof.FocusDistance = 20 dof.Enabled = false dof.Parent = Lighting
	local atm = nil
	local saved = { Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.FogStart, Lighting.FogEnd, Lighting.FogColor, Lighting.ExposureCompensation, cam.FieldOfView }
	Lighting.FogStart, Lighting.FogEnd = 200, 1400
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(110, 114, 124)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 144, 152)
	Lighting.ExposureCompensation = 0
	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "PhotoFx"
	fxFolder.Parent = workspace

	local st = { filter = 2, weather = 1, free = false, fov = 50, dof = false, clock = 17.3, tab = "look", mode = "move", fx = "fire", limb = "arm", placing = false }
	local joints = {} -- [limb] = { x, y, z }

	-- ---------------------------------------------------------------- the interface
	local gui = Instance.new("ScreenGui")
	gui.Name = "PhotoUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player.PlayerGui
	local bars = {}
	for _, top in ipairs({ true, false }) do
		local b = Instance.new("Frame")
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.Size = UDim2.new(1, 0, 0.11, 0)
		b.Position = top and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 0.89)
		b.Visible = false
		b.ZIndex = 1
		b.Parent = gui
		table.insert(bars, b)
	end
	local ui = Instance.new("Frame")
	ui.Size = UDim2.fromScale(1, 1)
	ui.BackgroundTransparency = 1
	ui.Parent = gui
	-- bottom tab bar
	local bar = UI.frame({ Size = UDim2.fromOffset(6 * 84 + 10, 66), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), BackgroundColor3 = c.panel, BackgroundTransparency = 0.12, ZIndex = 10, Parent = ui })
	UI.corner(bar, 16)
	UI.pad(bar, 5)
	UI.list(bar, 4, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
	-- the panel above the bar
	local panel = UI.frame({ Size = UDim2.fromOffset(520, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -84), BackgroundColor3 = c.panel, BackgroundTransparency = 0.12, ZIndex = 10, Parent = ui })
	UI.corner(panel, 16)
	UI.pad(panel, 8)
	UI.list(panel, 6)
	local status = UI.text({ Text = "", Size = UDim2.new(1, -20, 0, 26), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), TextSize = 16, TextColor3 = c.gold, TextStrokeTransparency = 0.3, ZIndex = 10, Parent = ui })
	local restore = UI.button({ Text = "", Size = UDim2.fromOffset(36, 36), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.75, Visible = false, ZIndex = 10, Parent = gui }, function() end)
	UI.corner(restore, 18)

	local panelConns = {}
	local function clearPanel()
		for _, cn in ipairs(panelConns) do cn:Disconnect() end
		panelConns = {}
		for _, ch in ipairs(panel:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
	end
	local order = 0
	local function line(h)
		order += 1
		local f = UI.frame({ Size = UDim2.new(1, 0, 0, h or 44), BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 11, Parent = panel })
		UI.list(f, 6, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center)
		return f
	end
	local function btn(parent, text, on, cb, w)
		return UI.button({ Text = text, Size = UDim2.new(w or 0, w and 0 or 92, 1, 0), TextSize = 15, BackgroundColor3 = on and c.gold or c.card, TextColor3 = on and c.bg or c.text, ZIndex = 12, Parent = parent }, cb)
	end
	-- a slider: drag the knob; calls back with the value while dragging
	local function slider(label, min, max, value, fmt, onChange)
		order += 1
		local f = UI.frame({ Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = c.card, LayoutOrder = order, ZIndex = 11, Parent = panel })
		UI.corner(f, 10)
		local lbl = UI.text({ Text = "", Size = UDim2.fromOffset(130, 44), Position = UDim2.fromOffset(10, 0), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 14, ZIndex = 12, Parent = f })
		local track = UI.frame({ Size = UDim2.new(1, -170, 0, 8), Position = UDim2.new(0, 150, 0.5, -4), BackgroundColor3 = c.bg, ZIndex = 12, Parent = f })
		UI.corner(track, 4)
		local fill = UI.frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = c.gold, ZIndex = 13, Parent = track })
		UI.corner(fill, 4)
		local knob = UI.frame({ Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 14, Parent = track })
		UI.corner(knob, 12)
		local function set(v, fire)
			v = math.clamp(v, min, max)
			local a = (v - min) / (max - min)
			fill.Size = UDim2.fromScale(a, 1)
			knob.Position = UDim2.fromScale(a, 0.5)
			lbl.Text = label .. "  " .. fmt(v)
			if fire then onChange(v) end
		end
		set(value, false)
		local dragging = nil
		local hit = UI.button({ Text = "", Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(140, 0), BackgroundTransparency = 1, ZIndex = 15, Parent = f }, function() end)
		local function at(x) set(min + (max - min) * math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1), true) end
		hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = input at(input.Position.X) end
		end)
		table.insert(panelConns, UserInputService.InputChanged:Connect(function(input)
			if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseMovement) then at(input.Position.X) end
		end))
		table.insert(panelConns, UserInputService.InputEnded:Connect(function(input)
			if input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = nil end
		end))
		return set
	end
	local function holdBtn(parent, text, onHold, w)
		local b = UI.button({ Text = text, Size = UDim2.new(0, w or 70, 1, 0), TextSize = 18, BackgroundColor3 = c.card2, ZIndex = 12, Parent = parent }, function() end)
		local held = false
		b.MouseButton1Down:Connect(function()
			held = true
			task.spawn(function()
				while held and b.Parent do onHold() task.wait(0.05) end
			end)
		end)
		b.MouseButton1Up:Connect(function() held = false end)
		b.MouseLeave:Connect(function() held = false end)
		return b
	end

	-- ---------------------------------------------------------------- selection (tap in the world)
	local selected = nil -- { kind = "me" | "mob" | "fx", model = Instance }
	local hl = Instance.new("Highlight")
	hl.FillTransparency = 1
	hl.OutlineColor = c.gold
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = gui
	local function select(obj, kind)
		selected = obj and { kind = kind, model = obj } or nil
		hl.Adornee = obj
		status.Text = obj and (T("ph_sel") .. ": " .. (kind == "me" and T("you") or kind == "fx" and T("phfx_" .. (obj:GetAttribute("Kind") or "fire")) or T("mob_" .. (obj:GetAttribute("Kind") or obj.Name)))) or ""
	end
	local function pivotOf(obj) return obj:IsA("Model") and obj:GetPivot() or obj.CFrame end
	local function setPivot(obj, kind, cf)
		if kind == "mob" then
			act("admin", "photoMove", { obj, cf })
			obj:PivotTo(cf) -- show it at once on this screen too
		elseif kind == "me" then
			local hrp = obj:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.Anchored = true end
			obj:PivotTo(cf)
		else
			obj.CFrame = cf
		end
	end
	local function rayFrom(pos, ignore)
		local r = cam:ScreenPointToRay(pos.X, pos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore or {}
		return workspace:Raycast(r.Origin, r.Direction * 800, params)
	end
	local function pick(pos)
		local hit = rayFrom(pos, { gui })
		if not hit then return nil end
		local inst = hit.Instance
		if inst:IsDescendantOf(fxFolder) then return inst, "fx" end
		local char = player.Character
		if char and inst:IsDescendantOf(char) then return char, "me" end
		local mobs = workspace:FindFirstChild("Mobs")
		if mobs and inst:IsDescendantOf(mobs) then
			local m = inst
			while m.Parent ~= mobs do m = m.Parent end
			return m, "mob"
		end
		return nil
	end
	-- dragging the selected thing over the ground
	local dragTouch, lastMove = nil, 0
	local conns = {}
	table.insert(conns, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if st.placing then
			local hit = rayFrom(pos, { gui, fxFolder })
			if hit then
				local p = makeFx(st.fx, hit.Position + Vector3.new(0, 1.5, 0), fxFolder)
				select(p, "fx")
				st.placing = false
			end
			return
		end
		if st.tab ~= "objects" then return end
		local obj, kind = pick(pos)
		if obj then
			select(obj, kind)
			dragTouch = input
		end
	end))
	table.insert(conns, UserInputService.InputChanged:Connect(function(input)
		if dragTouch and selected and (input == dragTouch or (input.UserInputType == Enum.UserInputType.MouseMovement and dragTouch.UserInputType == Enum.UserInputType.MouseButton1)) then
			local ignore = { gui, fxFolder, selected.model }
			if player.Character then table.insert(ignore, player.Character) end
			local hit = rayFrom(Vector2.new(input.Position.X, input.Position.Y), ignore)
			if hit then
				local old = pivotOf(selected.model)
				local lift = 0
				if selected.kind ~= "fx" then
					local cf, size = selected.model:GetBoundingBox()
					lift = old.Position.Y - (cf.Position.Y - size.Y / 2)
				else
					lift = old.Position.Y - hit.Position.Y
					lift = math.max(lift, 0.5)
				end
				local cf = CFrame.new(hit.Position + Vector3.new(0, lift, 0)) * old.Rotation
				-- creatures: send at most ten moves a second
				if selected.kind == "mob" and os.clock() - lastMove < 0.1 then selected.model:PivotTo(cf) return end
				lastMove = os.clock()
				setPivot(selected.model, selected.kind, cf)
			end
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if input == dragTouch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			if dragTouch and selected and selected.kind == "mob" then setPivot(selected.model, "mob", pivotOf(selected.model)) end
			dragTouch = nil
		end
	end))
	local function nudge(rot, up)
		if not selected or not selected.model.Parent then return end
		local cf = pivotOf(selected.model)
		local nc = CFrame.new(cf.Position + Vector3.new(0, up or 0, 0)) * cf.Rotation * (rot or CFrame.identity)
		if selected.kind == "mob" and os.clock() - lastMove < 0.1 then selected.model:PivotTo(nc) return end
		lastMove = os.clock()
		setPivot(selected.model, selected.kind, nc)
	end

	-- ---------------------------------------------------------------- the light and the look
	local function applyFilter()
		local f = FILTERS[st.filter]
		cc.Saturation, cc.Contrast, cc.TintColor, cc.Brightness = f.sat, f.con, f.tint, f.bri
		bloom.Intensity = f.bloom
		rays.Intensity = f.rays
		for _, b in ipairs(bars) do b.Visible = f.bars == true end
		if atm then atm:Destroy() atm = nil end
		if f.haze then
			atm = Instance.new("Atmosphere")
			atm.Name = "PhotoAtmosphere"
			atm.Density = f.haze[1]
			atm.Color = f.haze[2]
			atm.Decay = Color3.fromRGB(110, 100, 120)
			atm.Haze = 1.4
			atm.Glare = 0.3
			atm.Parent = Lighting
		end
	end
	applyFilter()
	act("admin", "clock", st.clock)

	-- ---------------------------------------------------------------- the tabs
	local TABS = { { "look", "sun" }, { "camera", "map" }, { "pose", "person" }, { "objects", "dot" }, { "effects", "flame" }, { "hide", "close" } }
	local tabButtons = {}
	local render
	local function openTab(key)
		if key == "hide" then
			ui.Visible = false
			restore.Visible = true
			hl.Adornee = nil
			return
		end
		st.tab = key
		st.placing = false
		for k, b in pairs(tabButtons) do b.BackgroundColor3 = (k == key) and c.gold or c.card end
		render()
	end
	for _, t in ipairs(TABS) do
		local b = UI.button({ Text = "", Size = UDim2.fromOffset(80, 56), BackgroundColor3 = c.card, ZIndex = 11, Parent = bar }, function() openTab(t[1]) end)
		env.Icons.draw(t[2], b, 24, c.text, UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0.5))
		UI.text({ Text = T("pht_" .. t[1]), Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -21), TextSize = 12, ZIndex = 12, Parent = b })
		tabButtons[t[1]] = b
	end
	restore.MouseButton1Click:Connect(function()
		ui.Visible = true
		restore.Visible = false
		if selected then hl.Adornee = selected.model end
	end)

	function render()
		clearPanel()
		order = 0
		if st.tab == "look" then
			local l1 = line(40)
			for i, f in ipairs(FILTERS) do
				btn(l1, T("phf_" .. f.key), i == st.filter, function() st.filter = i applyFilter() render() end, 0)
			end
			for _, b in ipairs(l1:GetChildren()) do if b:IsA("GuiButton") then b.Size = UDim2.new(0.2, -5, 1, 0) end end
			local lastSent = 0
			slider(T("ph_time"), 0, 24, st.clock, function(v) return string.format("%d:%02d", math.floor(v), math.floor((v % 1) * 60)) end, function(v)
				st.clock = v
				if os.clock() - lastSent > 0.15 then lastSent = os.clock() act("admin", "clock", v) end
			end)
			local l2 = line(40)
			for i, w in ipairs(WEATHER) do
				btn(l2, T("wx_" .. w), i == st.weather, function() st.weather = i act("admin", "weather", w) render() end, 0)
			end
			for _, b in ipairs(l2:GetChildren()) do if b:IsA("GuiButton") then b.Size = UDim2.new(0.25, -5, 1, 0) end end
		elseif st.tab == "camera" then
			local l1 = line(40)
			btn(l1, T("ph_follow2"), not st.free, function()
				st.free = false
				cam.CameraType = Enum.CameraType.Custom
				render()
			end, 0).Size = UDim2.new(0.5, -3, 1, 0)
			btn(l1, T("ph_free2"), st.free, function()
				st.free = true
				local lv = cam.CFrame.LookVector
				st.yaw, st.pitch = math.atan2(-lv.X, -lv.Z), math.asin(math.clamp(lv.Y, -1, 1))
				render()
			end, 0).Size = UDim2.new(0.5, -3, 1, 0)
			slider(T("ph_lens"), 15, 100, st.fov, function(v) return math.floor(v) .. "°" end, function(v) st.fov = v end)
			slider(T("ph_focus"), 0, 150, st.dof and dof.FocusDistance or 0, function(v) return v < 1 and T("ph_off") or math.floor(v) end, function(v)
				st.dof = v >= 1
				dof.Enabled = st.dof
				if st.dof then dof.FocusDistance = v end
			end)
			slider(T("ph_blur"), 0, 1, dof.FarIntensity, function(v) return math.floor(v * 100) .. "%" end, function(v) dof.FarIntensity = v dof.NearIntensity = v * 0.6 end)
			if st.free then
				local l2 = line(44)
				holdBtn(l2, T("ph_up"), function() st.vert = 1 task.delay(0.06, function() st.vert = 0 end) end, 120)
				holdBtn(l2, T("ph_down"), function() st.vert = -1 task.delay(0.06, function() st.vert = 0 end) end, 120)
			end
		elseif st.tab == "pose" then
			local l1 = line(40)
			for _, name in ipairs(Effects.POSE_LIST) do
				local b = btn(l1, T("php_" .. name), false, function()
					joints = {}
					if player.Character then Effects.pose(player.Character, name) end
				end, 0)
				b.Size = UDim2.new(1 / #Effects.POSE_LIST, -5, 1, 0)
				b.TextSize = 12
			end
			local l2 = line(40)
			for _, k in ipairs(Effects.JOINT_LIST) do
				local b = btn(l2, T("phj_" .. k), st.limb == k, function() st.limb = k render() end, 0)
				b.Size = UDim2.new(1 / #Effects.JOINT_LIST, -5, 1, 0)
				b.TextSize = 12
			end
			local j = joints[st.limb] or { 0, 0, 0 }
			joints[st.limb] = j
			local function apply() if player.Character then Effects.setJoint(player.Character, st.limb, j[1], j[2], j[3]) end end
			local fmt = function(v) return math.floor(v) .. "°" end
			slider(T("ph_bend"), -180, 180, j[1], fmt, function(v) j[1] = v apply() end)
			slider(T("ph_twist"), -180, 180, j[2], fmt, function(v) j[2] = v apply() end)
			slider(T("ph_side"), -180, 180, j[3], fmt, function(v) j[3] = v apply() end)
		elseif st.tab == "objects" then
			UI.text({ Text = T("ph_tapSelect"), Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, TextSize = 14, TextColor3 = c.dim, ZIndex = 12, Parent = panel })
			local l1 = line(44)
			holdBtn(l1, "⟲", function() nudge(CFrame.Angles(0, math.rad(4), 0)) end, 70)
			holdBtn(l1, "⟳", function() nudge(CFrame.Angles(0, math.rad(-4), 0)) end, 70)
			holdBtn(l1, T("ph_tiltUp"), function() nudge(CFrame.Angles(math.rad(3), 0, 0)) end, 80)
			holdBtn(l1, T("ph_tiltDown"), function() nudge(CFrame.Angles(math.rad(-3), 0, 0)) end, 80)
			holdBtn(l1, T("ph_up"), function() nudge(nil, 0.3) end, 70)
			holdBtn(l1, T("ph_down"), function() nudge(nil, -0.3) end, 70)
			local l2 = line(40)
			btn(l2, T("ph_selMe"), false, function() if player.Character then select(player.Character, "me") end end, 0).Size = UDim2.new(0.34, -4, 1, 0)
			btn(l2, T("ph_level"), false, function()
				if not selected then return end
				local cf = pivotOf(selected.model)
				local _, ry = cf:ToEulerAnglesYXZ()
				setPivot(selected.model, selected.kind, CFrame.new(cf.Position) * CFrame.Angles(0, ry, 0))
			end, 0).Size = UDim2.new(0.33, -4, 1, 0)
			local del = btn(l2, T("ph_remove"), false, function()
				if not selected then return end
				if selected.kind == "mob" then act("admin", "photoRemove", selected.model) selected.model:Destroy()
				elseif selected.kind == "fx" then selected.model:Destroy() end
				select(nil)
			end, 0)
			del.Size = UDim2.new(0.33, -4, 1, 0)
			del.BackgroundColor3 = c.danger
		elseif st.tab == "effects" then
			local l1 = line(40)
			for _, k in ipairs({ "fire", "smoke", "embers", "sparks" }) do
				btn(l1, T("phfx_" .. k), st.fx == k, function() st.fx = k st.placing = true status.Text = T("ph_tapPlace") render() end, 0).Size = UDim2.new(0.25, -5, 1, 0)
			end
			local l2 = line(40)
			for _, k in ipairs({ "fireflies", "snow", "glow", "light" }) do
				btn(l2, T("phfx_" .. k), st.fx == k, function() st.fx = k st.placing = true status.Text = T("ph_tapPlace") render() end, 0).Size = UDim2.new(0.25, -5, 1, 0)
			end
			if selected and selected.kind == "fx" and selected.model.Parent then
				local p = selected.model
				slider(T("ph_size"), 0.3, 4, p:GetAttribute("Scale") or 1, function(v) return string.format("x%.1f", v) end, function(v) scaleFx(p, v) end)
			end
			UI.text({ Text = T("ph_fxTip"), Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 99, TextSize = 13, TextColor3 = c.dim, ZIndex = 12, Parent = panel })
		end
		-- every tab: leave photo mode
		local lx = line(40)
		lx.LayoutOrder = 1000
		local ex = btn(lx, T("ph_exit"), false, function() P.stop() end, 0)
		ex.Size = UDim2.new(1, 0, 1, 0)
		ex.BackgroundColor3 = c.danger
	end
	openTab("look")

	-- ---------------------------------------------------------------- free camera
	local controls = nil
	pcall(function() controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 5)):GetControls() end)
	st.yaw, st.pitch, st.vert = 0, 0, 0
	table.insert(conns, UserInputService.InputChanged:Connect(function(input, processed)
		if not st.free or processed or dragTouch then return end
		if input.UserInputType == Enum.UserInputType.Touch or (input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then
			st.yaw -= input.Delta.X * 0.006
			st.pitch = math.clamp(st.pitch - input.Delta.Y * 0.006, -1.45, 1.45)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			st.yaw -= input.Position.X * 0.05
			st.pitch = math.clamp(st.pitch + input.Position.Y * 0.04, -1.45, 1.45)
		end
	end))
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		cam.FieldOfView = st.fov
		if st.free then
			cam.CameraType = Enum.CameraType.Scriptable
			local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.Anchored = true end
			local rot = CFrame.Angles(0, st.yaw, 0) * CFrame.Angles(st.pitch, 0, 0)
			local mv = controls and controls:GetMoveVector() or Vector3.zero
			local up = st.vert
			if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonR1) then up = 1 end
			if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL1) then up = -1 end
			local speed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 60 or 20
			cam.CFrame = CFrame.new(cam.CFrame.Position + (rot:VectorToWorldSpace(Vector3.new(mv.X, 0, mv.Z)) + Vector3.new(0, up, 0)) * speed * dt) * rot
		end
	end))

	function P.stop()
		if not active then return end
		active = false
		for _, cn in ipairs(conns) do cn:Disconnect() end
		clearPanel()
		gui:Destroy()
		fxFolder:Destroy()
		for _, o in ipairs({ cc, bloom, rays, dof, atm }) do if o then o:Destroy() end end
		Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.FogStart, Lighting.FogEnd, Lighting.FogColor, Lighting.ExposureCompensation = saved[1], saved[2], saved[3], saved[4], saved[5], saved[6], saved[7]
		cam.FieldOfView = saved[8]
		cam.CameraType = Enum.CameraType.Custom
		local h = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if h then h.Anchored = false end
		if player.Character then
			Effects.pose(player.Character, "none")
			for _, k in ipairs(Effects.JOINT_LIST) do Effects.setJoint(player.Character, k, 0, 0, 0) end
		end
		Effects.photo = false
		for _, g in ipairs(hidden) do if g.Parent then g.Enabled = true end end
		for _, b in ipairs(billboards) do if b.Parent then b.Enabled = true end end
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
		act("admin", "freezeTime", false)
		act("admin", "holdMobs", false)
	end
end

function P.active() return active end

return P
