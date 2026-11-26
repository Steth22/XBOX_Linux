-- Photo mode (admin): hides the interface, free camera, cinematic filters, depth of field, lens,
-- time of day, weather, poses, and creatures that hold still. For taking the game's pictures.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local P = {}
local active = false

local FILTERS = {
	{ key = "natural", cc = { sat = 0.06, con = 0.06, tint = Color3.fromRGB(255, 255, 255), bri = 0 }, bloom = 0.35, rays = 0.05 },
	{ key = "golden", cc = { sat = 0.22, con = 0.12, tint = Color3.fromRGB(255, 228, 192), bri = 0.02 }, bloom = 0.6, rays = 0.16, haze = { 0.32, Color3.fromRGB(255, 200, 150) } },
	{ key = "cinema", cc = { sat = 0.12, con = 0.22, tint = Color3.fromRGB(236, 244, 255), bri = -0.02 }, bloom = 0.5, rays = 0.1, bars = true, haze = { 0.25, Color3.fromRGB(190, 205, 225) } },
	{ key = "night", cc = { sat = -0.05, con = 0.15, tint = Color3.fromRGB(185, 205, 255), bri = -0.03 }, bloom = 0.85, rays = 0 },
	{ key = "drama", cc = { sat = -1, con = 0.35, tint = Color3.fromRGB(255, 255, 255), bri = 0 }, bloom = 0.4, rays = 0.08, bars = true },
}
local TIMES = { 6.4, 9, 12.5, 17.3, 18.6, 21.5 }
local WEATHER = { "clear", "wind", "rain", "storm" }

function P.start(env)
	if active then return end
	active = true
	local player = Players.LocalPlayer
	local T, act, Effects, UI, mainGui = env.T, env.act, env.Effects, env.UI, env.gui
	local c = UI.c
	local cam = workspace.CurrentCamera
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	-- hide everything else
	local hidden = {}
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if (g:IsA("ScreenGui") or g:IsA("BillboardGui")) and g.Enabled then g.Enabled = false table.insert(hidden, g) end
	end
	local billboards = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BillboardGui") and d.Enabled then d.Enabled = false table.insert(billboards, d) end
	end
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
	Effects.photo = true
	act("admin", "freezeTime", true)

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

	-- the panel
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
		b.Parent = gui
		table.insert(bars, b)
	end
	local panel = UI.frame({ Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), BackgroundColor3 = c.panel, BackgroundTransparency = 0.15, ZIndex = 10, Parent = gui })
	UI.corner(panel, 14)
	UI.pad(panel, 8)
	UI.list(panel, 6)
	local show = UI.button({ Text = "", Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), BackgroundColor3 = c.panel, BackgroundTransparency = 0.6, Visible = false, ZIndex = 10, Parent = gui }, function() end)
	local state = { filter = 2, time = 4, weather = 1, pose = 1, free = false, held = false, fov = 50, dof = false }
	local function applyFilter()
		local f = FILTERS[state.filter]
		cc.Saturation, cc.Contrast, cc.TintColor, cc.Brightness = f.cc.sat, f.cc.con, f.cc.tint, f.cc.bri
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
	local rows = {}
	local function row(label, cb, order)
		local b = UI.button({ Text = "", Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = c.card, LayoutOrder = order, ZIndex = 11, Parent = panel }, cb)
		local t = UI.text({ Text = label, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 15, ZIndex = 12, Parent = b })
		rows[order] = t
		return b, t
	end
	local function pair(label, minus, plus, order)
		local f = UI.frame({ Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = c.card, LayoutOrder = order, ZIndex = 11, Parent = panel })
		UI.corner(f, 10)
		local t = UI.text({ Text = label, Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(50, 0), TextSize = 15, ZIndex = 12, Parent = f })
		UI.button({ Text = "-", Size = UDim2.fromOffset(40, 34), Position = UDim2.fromOffset(4, 3), TextSize = 22, BackgroundColor3 = c.card2, ZIndex = 12, Parent = f }, minus)
		UI.button({ Text = "+", Size = UDim2.fromOffset(40, 34), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 3), TextSize = 22, BackgroundColor3 = c.card2, ZIndex = 12, Parent = f }, plus)
		return t
	end
	local labels = {}
	local function refresh()
		labels.filter.Text = T("ph_filter") .. ": " .. T("phf_" .. FILTERS[state.filter].key)
		labels.time.Text = T("ph_time") .. ": " .. string.format("%d:%02d", math.floor(TIMES[state.time]), math.floor((TIMES[state.time] % 1) * 60))
		labels.weather.Text = T("ph_weather") .. ": " .. T("wx_" .. WEATHER[state.weather])
		labels.pose.Text = T("ph_pose") .. ": " .. T("php_" .. Effects.POSE_LIST[state.pose])
		labels.cam.Text = state.free and T("ph_free") or T("ph_follow")
		labels.held.Text = state.held and T("ph_heldOn") or T("ph_heldOff")
		labels.fov.Text = T("ph_lens") .. "  " .. state.fov .. "°"
		labels.dof.Text = state.dof and (T("ph_focus") .. "  " .. math.floor(dof.FocusDistance)) or T("ph_focusOff")
	end
	local _, l1 = row("", function() state.filter = state.filter % #FILTERS + 1 applyFilter() refresh() end, 1) labels.filter = l1
	local _, l2 = row("", function() state.time = state.time % #TIMES + 1 act("admin", "clock", TIMES[state.time]) refresh() end, 2) labels.time = l2
	local _, l3 = row("", function() state.weather = state.weather % #WEATHER + 1 act("admin", "weather", WEATHER[state.weather]) refresh() end, 3) labels.weather = l3
	local _, l4 = row("", function()
		state.pose = state.pose % #Effects.POSE_LIST + 1
		if player.Character then Effects.pose(player.Character, Effects.POSE_LIST[state.pose]) end
		refresh()
	end, 4) labels.pose = l4
	local _, l5 = row("", function()
		state.free = not state.free
		local h = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if h then h.Anchored = state.free end
		cam.CameraType = state.free and Enum.CameraType.Scriptable or Enum.CameraType.Custom
		refresh()
	end, 5) labels.cam = l5
	local _, l6 = row("", function() state.held = not state.held act("admin", "holdMobs", state.held) refresh() end, 6) labels.held = l6
	labels.fov = pair("", function() state.fov = math.max(15, state.fov - 5) refresh() end, function() state.fov = math.min(100, state.fov + 5) refresh() end, 7)
	labels.dof = pair("", function()
		if not state.dof then state.dof = true dof.Enabled = true else dof.FocusDistance = math.max(4, dof.FocusDistance - 4) end
		refresh()
	end, function()
		if not state.dof then state.dof = true dof.Enabled = true else dof.FocusDistance = math.min(200, dof.FocusDistance + 4) end
		refresh()
	end, 8)
	-- free camera: up / down
	local vert = 0
	local ud = UI.frame({ Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 9, ZIndex = 11, Parent = panel })
	for k, dir in ipairs({ 1, -1 }) do
		local b = UI.button({ Text = dir > 0 and T("ph_up") or T("ph_down"), Size = UDim2.new(0.5, -3, 1, 0), Position = UDim2.new(k == 1 and 0 or 0.5, k == 1 and 0 or 3, 0, 0), TextSize = 15, BackgroundColor3 = c.card2, ZIndex = 12, Parent = ud }, function() end)
		b.MouseButton1Down:Connect(function() vert = dir end)
		b.MouseButton1Up:Connect(function() vert = 0 end)
		b.MouseLeave:Connect(function() if vert == dir then vert = 0 end end)
	end
	local hideB = row(T("ph_hide"), function() panel.Visible = false show.Visible = true end, 10)
	hideB.BackgroundColor3 = c.blue
	local exitB = row(T("ph_exit"), function() P.stop() end, 11)
	exitB.BackgroundColor3 = c.danger
	show.MouseButton1Click:Connect(function() panel.Visible = true show.Visible = false end)
	UI.corner(show, 22)
	local dot = UI.frame({ Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.3, ZIndex = 11, Parent = show })
	UI.corner(dot, 7)
	applyFilter()
	act("admin", "clock", TIMES[state.time])
	refresh()

	-- free camera: move with the stick / keys, look by dragging
	local controls = nil
	pcall(function() controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 5)):GetControls() end)
	local yaw, pitch = 0, 0
	do
		local lv = cam.CFrame.LookVector
		yaw = math.atan2(-lv.X, -lv.Z)
		pitch = math.asin(math.clamp(lv.Y, -1, 1))
	end
	local conns = {}
	table.insert(conns, UserInputService.InputChanged:Connect(function(input, processed)
		if not state.free or processed then return end
		if input.UserInputType == Enum.UserInputType.Touch or (input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)) then
			yaw -= input.Delta.X * 0.006
			pitch = math.clamp(pitch - input.Delta.Y * 0.006, -1.45, 1.45)
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			yaw -= input.Position.X * 0.05
			pitch = math.clamp(pitch + input.Position.Y * 0.04, -1.45, 1.45)
		end
	end))
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		cam.FieldOfView = state.fov
		if state.free then
			cam.CameraType = Enum.CameraType.Scriptable
			local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
			local mv = controls and controls:GetMoveVector() or Vector3.zero
			local up = vert
			if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonR1) then up = 1 end
			if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL1) then up = -1 end
			local speed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 60 or 22
			local pos = cam.CFrame.Position + (rot:VectorToWorldSpace(Vector3.new(mv.X, 0, mv.Z)) + Vector3.new(0, up, 0)) * speed * dt
			cam.CFrame = CFrame.new(pos) * rot
		end
	end))

	function P.stop()
		if not active then return end
		active = false
		for _, cn in ipairs(conns) do cn:Disconnect() end
		gui:Destroy()
		for _, o in ipairs({ cc, bloom, rays, dof, atm }) do if o then o:Destroy() end end
		Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.FogStart, Lighting.FogEnd, Lighting.FogColor, Lighting.ExposureCompensation = saved[1], saved[2], saved[3], saved[4], saved[5], saved[6], saved[7]
		cam.FieldOfView = saved[8]
		cam.CameraType = Enum.CameraType.Custom
		local h = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if h then h.Anchored = false end
		if player.Character then Effects.pose(player.Character, "none") end
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
