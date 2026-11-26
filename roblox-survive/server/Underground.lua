-- The underground layer at runtime: minecarts on the rail lines, poison gas, falling rocks, the ruins' vault.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debug = require(script.Parent.Debug)

local U = {}
local ctx, Inventory, Data
local rng = Random.new()

---------------------------------------------------------------- minecarts
local tracks = {} -- [name] = { pts, cum, total }
local carts = {} -- [model] = { track, s, v, throttle, driver }
local function parseTrack(model)
	local pts = {}
	for x, y, z in string.gmatch(model:GetAttribute("Points") or "", "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)") do
		table.insert(pts, Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
	end
	if #pts < 2 then return nil end
	local cum = { 0 }
	for k = 2, #pts do cum[k] = cum[k - 1] + (pts[k] - pts[k - 1]).Magnitude end
	return { pts = pts, cum = cum, total = cum[#cum] }
end
-- position and heading at distance s along a track
local function sample(tr, s)
	s = math.clamp(s, 0, tr.total)
	local lo, hi = 1, #tr.cum
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if tr.cum[mid] <= s then lo = mid else hi = mid end
	end
	local a, b = tr.pts[lo], tr.pts[hi]
	local seg = tr.cum[hi] - tr.cum[lo]
	local t = seg > 0 and (s - tr.cum[lo]) / seg or 0
	return a:Lerp(b, t), (b - a).Unit
end
local function placeCart(m, st)
	local p, dir = sample(st.track, st.s)
	if dir.Magnitude ~= dir.Magnitude or dir.Magnitude < 0.5 then return end
	m:PivotTo(CFrame.lookAt(p, p + dir) * CFrame.new(0, 1.4, 0))
end

function U.throttle(player, value)
	for m, st in pairs(carts) do
		if st.driver == player then st.throttle = math.clamp(tonumber(value) or 0, -1, 1) end
	end
end

---------------------------------------------------------------- gas, falling rocks, vault
local gasParts = {}
local function inGas(pos)
	for _, z in ipairs(gasParts) do
		local rel = z.CFrame:PointToObjectSpace(pos)
		local h = z.Size / 2
		if math.abs(rel.X) < h.X and math.abs(rel.Y) < h.Y + 2 and math.abs(rel.Z) < h.Z then return true end
	end
	return false
end

local function dropRock(at, owner)
	local r = Instance.new("Part")
	r.Name = "FallingRock"
	r.Shape = Enum.PartType.Ball
	r.Size = Vector3.one * rng:NextNumber(2.2, 3.6)
	r.Color = Color3.fromRGB(110, 106, 100)
	r.Material = Enum.Material.Slate
	r.CFrame = CFrame.new(at)
	r.CanQuery = false
	r.Parent = workspace
	local hit = {}
	r.Touched:Connect(function(other)
		local char = other:FindFirstAncestorOfClass("Model")
		local pl = char and Players:GetPlayerFromCharacter(char)
		if pl and not hit[pl] then
			hit[pl] = true
			ctx.hurt(pl, rng:NextInteger(12, 24), "rockfall")
		end
	end)
	task.delay(4, function() if r.Parent then r:Destroy() end end)
end

function U.start(c, inv, data)
	ctx, Inventory, Data = c, inv, data
	local under = workspace:FindFirstChild("Underground")
	if not under then return end
	-- carts
	local tf = under:FindFirstChild("Tracks")
	for _, t in ipairs(tf and tf:GetChildren() or {}) do
		local tr = parseTrack(t)
		if tr then tracks[t.Name] = tr end
	end
	local cf = under:FindFirstChild("Minecarts")
	for _, m in ipairs(cf and cf:GetChildren() or {}) do
		local tr = tracks[m:GetAttribute("Track") or ""]
		if tr and m.PrimaryPart then
			-- turn the cart's parts (built around the origin) into a model we can move as one
			local origin = CFrame.new()
			for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Anchored = true end end
			m:PivotTo(origin)
			local st = { track = tr, s = tr.total * (m:GetAttribute("Start") or 0), v = 0, throttle = 0 }
			carts[m] = st
			placeCart(m, st)
			local seat = m:FindFirstChild("Seat")
			if seat then
				local pr = Instance.new("ProximityPrompt")
				pr.ActionText = "Ride"
				pr.ObjectText = "Minecart"
				pr.MaxActivationDistance = 8
				pr.RequiresLineOfSight = false
				pr:SetAttribute("Key", "ride")
				pr:SetAttribute("Obj", "cart")
				pr.Parent = m.PrimaryPart
				pr.Triggered:Connect(function(player)
					local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 and not seat.Occupant then seat:Sit(hum) end
				end)
				seat:GetPropertyChangedSignal("Occupant"):Connect(function()
					local hum = seat.Occupant
					st.driver = hum and Players:GetPlayerFromCharacter(hum.Parent) or nil
					st.throttle = 0
					if st.driver then ctx.notify(st.driver, "cartHint") end
				end)
			end
		end
	end
	RunService.Heartbeat:Connect(function(dt)
		for m, st in pairs(carts) do
			if m.Parent then
				local target = st.throttle * 46
				local acc = st.driver and 26 or 14
				if st.v < target then st.v = math.min(target, st.v + acc * dt) elseif st.v > target then st.v = math.max(target, st.v - acc * dt) end
				if math.abs(st.v) > 0.01 then
					st.s += st.v * dt
					if st.s <= 0 or st.s >= st.track.total then
						st.s = math.clamp(st.s, 0, st.track.total)
						st.v = 0
					end
					placeCart(m, st)
				end
			end
		end
	end)
	-- gas zones
	local gf = under:FindFirstChild("GasZones")
	for _, z in ipairs(gf and gf:GetChildren() or {}) do table.insert(gasParts, z) end
	-- the vault door
	local ruins = under:FindFirstChild("Ruins")
	local door = ruins and ruins:FindFirstChild("VaultDoor")
	if door then
		local closed = door.CFrame
		local pr = door:FindFirstChildWhichIsA("ProximityPrompt")
		local opened = false
		pr.Triggered:Connect(function(player)
			if opened then return end
			local room = Data.room(player)
			if not room or not Inventory.remove(room.inv, "ancient_key", 1) then
				ctx.notify(player, "needKey")
				return
			end
			opened = true
			pr.Enabled = false
			ctx.notify(player, "vaultOpen")
			ctx.fx("skillUp", player.Character)
			ctx.push(player)
			door.CFrame = closed * CFrame.new(0, -7.4, 0)
			task.delay(120, function()
				door.CFrame = closed
				opened = false
				pr.Enabled = true
			end)
		end)
	end
	-- every second: gas hurts, rocks fall in unstable caverns
	local rockCaverns = {}
	for _, cv in ipairs(workspace:FindFirstChild("Caves") and workspace.Caves:GetChildren() or {}) do
		if cv:GetAttribute("Rockfall") then table.insert(rockCaverns, cv) end
	end
	local warned = {}
	local nextRock = {}
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(function()
				for _, pl in ipairs(Players:GetPlayers()) do
					local char = pl.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if hrp and hum and hum.Health > 0 then
						if #gasParts > 0 and inGas(hrp.Position) and not (ctx.buff and ctx.buff(pl, "antidote")) then
							ctx.hurt(pl, 7, "gas")
							if not warned[pl] or os.clock() - warned[pl] > 5 then warned[pl] = os.clock() ctx.notify(pl, "gas") end
						end
						for _, cv in ipairs(rockCaverns) do
							local c = cv:GetAttribute("Center")
							local rad = cv:GetAttribute("Radius") or 30
							if c and (hrp.Position - c).Magnitude < rad and os.clock() > (nextRock[pl] or 0) then
								nextRock[pl] = os.clock() + rng:NextNumber(12, 25)
								ctx.notify(pl, "rockfall")
								ctx.fx("crate", hrp.Position + Vector3.new(0, 10, 0))
								for k = 1, 3 do
									local off = Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
									task.delay(1 + k * 0.4, function() dropRock(hrp.Position + off + Vector3.new(0, 18, 0)) end)
								end
							end
						end
					end
				end
			end)
			if not ok then Debug.log("underground", err) end
		end
	end)
	Debug.log("underground", string.format("tracks %d, carts %d, gas %d, rockfall %d", (function() local n = 0 for _ in pairs(tracks) do n += 1 end return n end)(), (function() local n = 0 for _ in pairs(carts) do n += 1 end return n end)(), #gasParts, #rockCaverns))
end

return U
