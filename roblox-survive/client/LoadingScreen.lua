-- The loading screen: used when the game starts, while teleporting, and while a room's world loads.
local S = {}

function S.build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Loading"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(14, 18, 16)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(34, 46, 36), Color3.fromRGB(10, 12, 12))
	grad.Parent = bg
	-- slow drifting embers
	local embers = {}
	for i = 1, 26 do
		local e = Instance.new("Frame")
		local s = math.random(3, 7)
		e.Size = UDim2.fromOffset(s, s)
		e.Position = UDim2.fromScale(math.random(), math.random())
		e.BackgroundColor3 = Color3.fromRGB(255, math.random(140, 200), 70)
		e.BackgroundTransparency = math.random(30, 70) / 100
		e.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = e
		e.Parent = bg
		embers[i] = { f = e, sp = math.random(20, 60) / 1000, sw = math.random() * 6 }
	end
	local function text(t, size, color, y)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, size + 10)
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.new(0.5, 0, 0.5, y)
		l.Font = Enum.Font.GothamBold
		l.TextSize = size
		l.TextColor3 = color
		l.Text = t
		l.Parent = bg
		return l
	end
	local title = text("البقاء  |  SURVIVE", 64, Color3.fromRGB(242, 193, 78), -70)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(70, 40, 10)
	st.Thickness = 3
	st.Parent = title
	local status = text("", 20, Color3.fromRGB(200, 210, 200), 40)
	-- progress bar
	local track = Instance.new("Frame")
	track.Size = UDim2.fromOffset(420, 12)
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.new(0.5, 0, 0.5, 10)
	track.BackgroundColor3 = Color3.fromRGB(40, 48, 42)
	track.BorderSizePixel = 0
	track.Parent = bg
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(1, 0)
	tc.Parent = track
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(242, 193, 78)
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(230, 150, 50))
	fg.Parent = fill
	local tip = text("", 16, Color3.fromRGB(150, 160, 150), 110)
	local TIPS = {
		"اطبخ اللحم في الفرن قبل أن تأكله  •  Cook meat in a furnace before eating it",
		"نم على سرير ليصير نقطة رسبن  •  Sleep in a bed to make it your respawn point",
		"تاجر الأقزام في الكهوف يدفع أكثر للخامات  •  Dwarves pay more for ore",
		"لكل زعيم نقطة ضعف  •  Every boss has a weak point",
		"التوكن يفتح القوى  •  Tokens unlock powers",
		"العب مع أصدقائك لتحصل على Boost  •  Play with friends for a boost",
	}
	tip.Text = TIPS[math.random(1, #TIPS)]
	local shown = 0
	local target = 0
	local alive = true
	task.spawn(function()
		local last = os.clock()
		while alive do
			local now = os.clock()
			local dt = now - last
			last = now
			shown += (target - shown) * math.min(1, dt * 6)
			fill.Size = UDim2.fromScale(math.clamp(shown, 0, 1), 1)
			for _, e in ipairs(embers) do
				local p = e.f.Position
				local y = p.Y.Scale - e.sp * dt * 3
				if y < -0.05 then y = 1.05 end
				e.f.Position = UDim2.fromScale(p.X.Scale + math.sin(now + e.sw) * 0.0006, y)
			end
			task.wait()
		end
	end)
	local api = { gui = gui }
	function api.set(frac, msg)
		target = math.max(target, frac)
		if msg then status.Text = msg end
	end
	function api.close()
		target = 1
		task.wait(0.35)
		local ts = game:GetService("TweenService")
		local info = TweenInfo.new(0.6)
		ts:Create(bg, info, { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(bg:GetDescendants()) do
			if d:IsA("TextLabel") then ts:Create(d, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif d:IsA("Frame") then ts:Create(d, info, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then ts:Create(d, info, { Transparency = 1 }):Play() end
		end
		task.wait(0.65)
		alive = false
		gui:Destroy()
	end
	return api
end

return S
