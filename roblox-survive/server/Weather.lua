-- The sky over the room: clear, wind, rain or a storm (heavy rain, lightning and thunder), and now and
-- then a tornado during a storm. The state lives in ReplicatedStorage attributes; every client draws it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Biomes = require(ReplicatedStorage.Shared.Biomes)

local W = {}
local rng = Random.new()
local ctx
-- weight, shortest and longest time (seconds)
local STATES = {
	{ "clear", 50, 180, 360 },
	{ "wind", 16, 100, 200 },
	{ "rain", 20, 120, 240 },
	{ "storm", 14, 100, 180 },
}

function W.current() return ReplicatedStorage:GetAttribute("Weather") or "clear" end

local function set(state)
	ReplicatedStorage:SetAttribute("Weather", state)
	local a = rng:NextNumber(0, math.pi * 2)
	ReplicatedStorage:SetAttribute("WindDir", Vector3.new(math.cos(a), 0, math.sin(a)))
	if ctx and ctx.broadcast and state ~= "clear" then ctx.broadcast("weather_" .. state) end
end

local function pickState(prev)
	local total = 0
	for _, s in ipairs(STATES) do if s[1] ~= prev then total += s[2] end end
	local r = rng:NextNumber(0, total)
	for _, s in ipairs(STATES) do
		if s[1] ~= prev then
			r -= s[2]
			if r <= 0 then return s end
		end
	end
	return STATES[1]
end

---------------------------------------------------------------- tornado
local tornado = nil -- { part, vel, untilT }
local hitCd = {}
local function groundY(x, z)
	local hit = workspace:Raycast(Vector3.new(x, 320, z), Vector3.new(0, -400, 0))
	return hit and hit.Position.Y or nil
end
local function spawnTornado()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp.Position.Y > -20 then table.insert(list, hrp) end
	end
	if #list == 0 then return end
	local target = list[rng:NextInteger(1, #list)]
	local a = rng:NextNumber(0, math.pi * 2)
	local d = rng:NextNumber(150, 220)
	local x, z = target.Position.X + math.cos(a) * d, target.Position.Z + math.sin(a) * d
	if math.max(math.abs(x), math.abs(z)) > Biomes.SEA - 60 then return end
	local y = groundY(x, z)
	if not y then return end
	local p = Instance.new("Part")
	p.Name = "Tornado"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(4, 4, 4)
	p.Position = Vector3.new(x, y, z)
	p.Parent = workspace
	local dir = (Vector3.new(target.Position.X, 0, target.Position.Z) - Vector3.new(x, 0, z)).Unit
	tornado = { part = p, dir = dir, untilT = os.clock() + rng:NextNumber(60, 90), target = target }
	if ctx and ctx.feed then ctx.feed("tornado", "") end
	if ctx and ctx.broadcast then ctx.broadcast("tornadoNear") end
end

-- admin: force a weather (or a tornado right now)
function W.force(state)
	if state == "tornado" then
		if W.current() ~= "storm" then set("storm") end
		if not tornado then spawnTornado() end
	elseif state == "clear" or state == "wind" or state == "rain" or state == "storm" then
		set(state)
	end
end

function W.start(c)
	ctx = c
	set("clear")
	-- the weather cycle
	task.spawn(function()
		local prev = "clear"
		task.wait(rng:NextNumber(120, 240))
		while true do
			local s = pickState(prev)
			prev = s[1]
			set(s[1])
			local dur = rng:NextNumber(s[3], s[4])
			if s[1] == "storm" and rng:NextNumber() < 0.45 then
				task.delay(rng:NextNumber(15, 40), function()
					if W.current() == "storm" and not tornado then spawnTornado() end
				end)
			end
			task.wait(dur)
		end
	end)
	-- move the tornado: it drifts towards players, weaving a little, and stays on the ground
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if not tornado then return end
		local p = tornado.part
		if os.clock() > tornado.untilT or not p.Parent then
			if p.Parent then p:Destroy() end
			tornado = nil
			return
		end
		local pos = p.Position
		local tgt = tornado.target
		if tgt and tgt.Parent then
			local want = (Vector3.new(tgt.Position.X, 0, tgt.Position.Z) - Vector3.new(pos.X, 0, pos.Z))
			if want.Magnitude > 1 then tornado.dir = (tornado.dir + want.Unit * dt * 0.35).Unit end
		end
		local wob = math.sin(os.clock() * 0.7) * 0.5
		local dir = (CFrame.Angles(0, wob * dt, 0) * tornado.dir)
		local nx, nz = pos.X + dir.X * 13 * dt, pos.Z + dir.Z * 13 * dt
		acc += dt
		local ny = pos.Y
		if acc > 0.3 then
			acc = 0
			ny = groundY(nx, nz) or pos.Y
		end
		p.Position = Vector3.new(nx, ny, nz)
		-- players caught in it are hurt (the client throws them around)
		for _, pl in ipairs(Players:GetPlayers()) do
			local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local flat = Vector3.new(hrp.Position.X - nx, 0, hrp.Position.Z - nz).Magnitude
				if flat < 20 and math.abs(hrp.Position.Y - ny) < 70 and os.clock() > (hitCd[pl] or 0) then
					hitCd[pl] = os.clock() + 1.5
					if ctx and ctx.hurt then ctx.hurt(pl, 9, "tornado") end
				end
			end
		end
	end)
end

-- how much colder the weather makes it (rain and storms chill you)
function W.chill()
	local s = W.current()
	return s == "storm" and 6 or s == "rain" and 3 or s == "wind" and 2 or 0
end

return W
