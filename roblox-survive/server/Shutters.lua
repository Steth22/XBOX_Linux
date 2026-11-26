-- Every trader on the surface closes a striped curtain over the front of the stall when night falls
-- (it rolls down), and opens it again in the morning (it rolls up).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local S = {}
local shutters = {} -- { { stripes = { {part, topCf, h} }, roll = part } }
local RED, WHITE = Color3.fromRGB(196, 70, 60), Color3.fromRGB(240, 230, 210)

local function make(counter, trader, folder)
	local tr = trader:FindFirstChild("HumanoidRootPart")
	if not tr then return end
	local front = counter.Position - tr.Position
	front = Vector3.new(front.X, 0, front.Z)
	if front.Magnitude < 0.1 then return end
	front = front.Unit
	local long = math.max(counter.Size.X, counter.Size.Z)
	local big = long > 10
	local bottom = counter.Position.Y - counter.Size.Y / 2
	-- the stall's opening: a big camp / outpost stall, or a small village counter
	local width = big and 19.4 or 9.4
	local floorY = big and (bottom - 0.8) or bottom
	local topY = floorY + (big and 9.9 or 6.2)
	local out = big and 2.4 or 1.4
	local center = Vector3.new(counter.Position.X, topY, counter.Position.Z) + front * out
	local frame = CFrame.lookAt(center, center + front) -- -Z faces the customers
	local model = Instance.new("Model")
	model.Name = "Shutter"
	model.Parent = folder
	local roll = Instance.new("Part")
	roll.Name = "Roll"
	roll.Anchored = true
	roll.CanCollide = false
	roll.Shape = Enum.PartType.Cylinder
	roll.Size = Vector3.new(width + 0.6, 0.9, 0.9)
	roll.CFrame = frame * CFrame.new(0, 0.2, 0)
	roll.Color = Color3.fromRGB(110, 76, 48)
	roll.Material = Enum.Material.Wood
	roll.Parent = model
	local h = topY - floorY
	local n = big and 10 or 5
	local sw = width / n
	local list = {}
	for i = 1, n do
		local p = Instance.new("Part")
		p.Name = "Stripe"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = Enum.Material.Fabric
		p.Color = (i % 2 == 0) and WHITE or RED
		local top = frame * CFrame.new(-width / 2 + sw * (i - 0.5), 0, 0)
		p.Size = Vector3.new(sw, 0.1, 0.15)
		p.CFrame = top * CFrame.new(0, -0.05, 0)
		p.Transparency = 1
		p.Parent = model
		table.insert(list, { p = p, top = top, h = h, w = sw })
	end
	table.insert(shutters, { stripes = list, trader = trader })
end

local function set(closed, instant)
	for _, sh in ipairs(shutters) do
		for k, st in ipairs(sh.stripes) do
			local hh = closed and st.h or 0.1
			local goal = { Size = Vector3.new(st.w, hh, 0.15), CFrame = st.top * CFrame.new(0, -hh / 2, 0) }
			if closed then st.p.Transparency = 0 end
			if instant then
				st.p.Size, st.p.CFrame = goal.Size, goal.CFrame
				if not closed then st.p.Transparency = 1 end
			else
				-- the stripes follow one another a little, like cloth unrolling
				task.delay((k - 1) * 0.04, function()
					local t = TweenService:Create(st.p, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), goal)
					t:Play()
					if not closed then t.Completed:Connect(function() if not ReplicatedStorage:GetAttribute("Night") then st.p.Transparency = 1 end end) end
				end)
			end
		end
	end
end

-- vendors = { { part = counter, shop = "forest" | ... } } (the world's list)
function S.start(vendors, ctx)
	local folder = Instance.new("Folder")
	folder.Name = "Shutters"
	folder.Parent = workspace
	for _, v in ipairs(vendors) do
		local c = v.part
		if c and c.Parent and v.shop ~= "black" and v.shop ~= "dwarf" and c.Position.Y > -26 then
			-- the trader of this stall: the nearest one
			local best, bd = nil, 14
			for _, d in ipairs(c.Parent:GetDescendants()) do
				if d:IsA("Model") and d.Name == "Trader" and d:FindFirstChild("HumanoidRootPart") then
					local dist = (d.HumanoidRootPart.Position - c.Position).Magnitude
					if dist < bd then best, bd = d, dist end
				end
			end
			if not best then
				for _, d in ipairs(workspace.Camp:GetDescendants()) do
					if d:IsA("Model") and d.Name == "Trader" and d:FindFirstChild("HumanoidRootPart") and (d.HumanoidRootPart.Position - c.Position).Magnitude < 14 then best = d end
				end
			end
			if best then pcall(make, c, best, folder) end
		end
	end
	local night = ReplicatedStorage:GetAttribute("Night") == true
	set(night, true)
	ReplicatedStorage:GetAttributeChangedSignal("Night"):Connect(function()
		local now = ReplicatedStorage:GetAttribute("Night") == true
		if now == night then return end
		night = now
		set(night, false)
		if ctx and ctx.fx then
			for _, sh in ipairs(shutters) do
				-- the trader reaches up and pulls the curtain
				if sh.trader and sh.trader.Parent then pcall(ctx.fx, "anim", sh.trader, "place") end
			end
		end
	end)
	return #shutters
end

return S
