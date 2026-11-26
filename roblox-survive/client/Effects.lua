-- Client-side juice: 3D sounds, character animations, particles, debris, footprints, ambience.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sounds"))

local E = {}
local rng = Random.new()
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

---------------------------------------------------------------- sound
local function soundId(name)
	local list = Sounds[name]
	if not list then return nil end
	return "rbxassetid://" .. list[rng:NextInteger(1, #list)]
end

function E.play(name, where, volume, pitch)
	local id = soundId(name)
	if not id then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.7
	s.PlaybackSpeed = pitch or rng:NextNumber(0.92, 1.08)
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 140
	if typeof(where) == "Vector3" then
		local a = Instance.new("Attachment")
		a.WorldPosition = where
		a.Parent = workspace.Terrain
		s.Parent = a
		Debris:AddItem(a, 8)
	elseif typeof(where) == "Instance" then
		s.Parent = where
		Debris:AddItem(s, 8)
	else
		s.Parent = SoundService
		Debris:AddItem(s, 8)
	end
	s:Play()
	return s
end

function E.ui(name)
	E.play(name or "click", nil, 0.5, 1)
end

---------------------------------------------------------------- particles + debris
local function emitter(pos, props, count, life)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local p = Instance.new("ParticleEmitter")
	p.Enabled = false
	for k, v in pairs(props) do p[k] = v end
	p.Parent = a
	p:Emit(count)
	Debris:AddItem(a, life or 3)
	return p
end

function E.dust(pos, color, count, size)
	emitter(pos, {
		Texture = SMOKE, Color = ColorSequence.new(color or Color3.fromRGB(170, 150, 120)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 1.2), NumberSequenceKeypoint.new(1, (size or 1.2) * 2.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(3, 7), SpreadAngle = Vector2.new(180, 180),
		Drag = 3, Acceleration = Vector3.new(0, 2, 0), LightInfluence = 1, Rotation = NumberRange.new(0, 360),
	}, count or 10, 3)
end

function E.sparkle(pos, color, count)
	emitter(pos, {
		Texture = SPARK, Color = ColorSequence.new(color or Color3.fromRGB(255, 220, 120)), LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(6, 12), SpreadAngle = Vector2.new(180, 180),
		Drag = 2, Acceleration = Vector3.new(0, 4, 0),
	}, count or 20, 2)
end

function E.chunks(pos, color, count, size, material)
	for _ = 1, count do
		local p = Instance.new("Part")
		local s = rng:NextNumber(0.25, 0.6) * (size or 1)
		p.Size = Vector3.new(s, s * rng:NextNumber(0.5, 1), s)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanQuery = false
		p.CanTouch = false
		p.CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 1), rng:NextNumber(-0.6, 0.6))) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		p.Parent = workspace
		p.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(10, 22), rng:NextNumber(-14, 14))
		p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
		task.delay(1.4, function()
			if p.Parent then TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1 }):Play() end
		end)
		Debris:AddItem(p, 2.1)
	end
end

---------------------------------------------------------------- character animations (procedural, on every client)
local orig = setmetatable({}, { __mode = "k" })
local function motor(char, r15, r6parent, r6)
	local p = char:FindFirstChild(r15[1])
	local m = p and p:FindFirstChild(r15[2])
	if not m then
		local t = char:FindFirstChild(r6parent)
		m = t and t:FindFirstChild(r6)
	end
	if m and m:IsA("Motor6D") then
		if not orig[m] then orig[m] = m.C0 end
		return m, orig[m]
	end
	return nil
end
local function tw(m, base, cf, t, style)
	TweenService:Create(m, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = base * cf }):Play()
end
local rad = math.rad

local lastLocal = {}
local reported = false
function E.anim(char, kind, isLocal)
	if not char or not char.Parent then return end
	-- the owner already played it the moment they tapped; skip the copy from the server
	local lp = Players.LocalPlayer
	if lp and char == lp.Character then
		if isLocal then
			lastLocal[kind] = os.clock()
		elseif lastLocal[kind] and os.clock() - lastLocal[kind] < 0.6 then
			return
		end
	end
	local arm, armBase = motor(char, { "RightUpperArm", "RightShoulder" }, "Torso", "Right Shoulder")
	local larm, larmBase = motor(char, { "LeftUpperArm", "LeftShoulder" }, "Torso", "Left Shoulder")
	local waist, waistBase = motor(char, { "UpperTorso", "Waist" }, "HumanoidRootPart", "RootJoint")
	local head = char:FindFirstChild("Head")
	local root = char:FindFirstChild("HumanoidRootPart")
	local function reset(t)
		if arm then tw(arm, armBase, CFrame.new(), t) end
		if larm then tw(larm, larmBase, CFrame.new(), t) end
		if waist then tw(waist, waistBase, CFrame.new(), t) end
	end
	if arm and not reported and E.report and lp and char == lp.Character then
		reported = true
		local before = arm.C0
		task.delay(0.1, function()
			pcall(E.report, string.format("anim %s: arm moved %.2f rad", kind, select(2, (before:Inverse() * arm.C0):ToAxisAngle())))
		end)
	end
	task.spawn(function()
		if (kind == "chop" or kind == "swing") and arm then
			-- overhead chop: raise, lean back, then drive down with the body
			tw(arm, armBase, CFrame.Angles(rad(95), 0, rad(-10)), 0.14)
			if larm then tw(larm, larmBase, CFrame.Angles(rad(60), 0, rad(15)), 0.14) end
			if waist then tw(waist, waistBase, CFrame.Angles(rad(10), rad(-12), 0), 0.14) end
			task.wait(0.15)
			E.play("swing", root, 0.55)
			tw(arm, armBase, CFrame.Angles(rad(-70), 0, rad(8)), 0.09, Enum.EasingStyle.Back)
			if larm then tw(larm, larmBase, CFrame.Angles(rad(-30), 0, rad(-10)), 0.09) end
			if waist then tw(waist, waistBase, CFrame.Angles(rad(-18), rad(8), 0), 0.09) end
			task.wait(0.22)
			reset(0.25)
		elseif kind == "mine" and arm then
			-- pickaxe: high lift, hard downward strike towards the ground
			tw(arm, armBase, CFrame.Angles(rad(95), 0, 0), 0.16)
			if larm then tw(larm, larmBase, CFrame.Angles(rad(80), 0, rad(10)), 0.16) end
			if waist then tw(waist, waistBase, CFrame.Angles(rad(14), 0, 0), 0.16) end
			task.wait(0.17)
			E.play("swing", root, 0.5, 0.85)
			tw(arm, armBase, CFrame.Angles(rad(-70), 0, 0), 0.08, Enum.EasingStyle.Back)
			if larm then tw(larm, larmBase, CFrame.Angles(rad(-50), 0, 0), 0.08) end
			if waist then tw(waist, waistBase, CFrame.Angles(rad(-28), 0, 0), 0.08) end
			task.wait(0.25)
			reset(0.28)
		elseif kind == "slash" and arm then
			-- sword: wide horizontal slash with a body twist
			tw(arm, armBase, CFrame.Angles(rad(20), rad(70), rad(-50)), 0.12)
			if waist then tw(waist, waistBase, CFrame.Angles(0, rad(35), 0), 0.12) end
			task.wait(0.13)
			E.play("swing", root, 0.6, 1.1)
			tw(arm, armBase, CFrame.Angles(rad(10), rad(-80), rad(-40)), 0.1, Enum.EasingStyle.Quad)
			if waist then tw(waist, waistBase, CFrame.Angles(0, rad(-40), 0), 0.1) end
			task.wait(0.2)
			reset(0.22)
		elseif kind == "thrust" and arm then
			-- spear: pull back, then a straight jab
			tw(arm, armBase, CFrame.new(0, 0, 0.6) * CFrame.Angles(rad(-15), 0, 0), 0.12)
			if waist then tw(waist, waistBase, CFrame.Angles(0, rad(-12), 0), 0.12) end
			task.wait(0.13)
			E.play("swing", root, 0.55, 1.2)
			tw(arm, armBase, CFrame.new(0, 0, -1.2) * CFrame.Angles(rad(8), 0, 0), 0.07, Enum.EasingStyle.Back)
			if waist then tw(waist, waistBase, CFrame.Angles(rad(-8), rad(14), 0), 0.07) end
			task.wait(0.2)
			reset(0.22)
		elseif kind == "gun" and arm then
			-- pistol: aim, recoil kick
			tw(arm, armBase, CFrame.Angles(rad(8), 0, 0), 0.05)
			task.wait(0.05)
			tw(arm, armBase, CFrame.Angles(rad(28), 0, 0), 0.05)
			if waist then tw(waist, waistBase, CFrame.Angles(rad(5), 0, 0), 0.05) end
			task.wait(0.07)
			reset(0.2)
		elseif kind == "bow" and arm then
			-- bow: front arm up, pull back, release
			if larm then tw(larm, larmBase, CFrame.Angles(rad(85), rad(-30), 0), 0.12) end
			tw(arm, armBase, CFrame.Angles(rad(30), rad(-40), rad(-30)), 0.18)
			task.wait(0.2)
			tw(arm, armBase, CFrame.Angles(rad(10), rad(-10), 0), 0.06, Enum.EasingStyle.Back)
			task.wait(0.25)
			reset(0.25)
		elseif kind == "aim" and arm then
			tw(arm, armBase, CFrame.Angles(rad(20), 0, 0), 0.08)
			task.wait(0.3)
			reset(0.25)
		elseif (kind == "eat" or kind == "heal") and arm then
			tw(arm, armBase, CFrame.Angles(rad(45), 0, rad(-35)), 0.2)
			task.wait(0.2)
			if kind == "eat" then
				E.play("eat", head, 0.8)
				for _ = 1, 3 do
					if head then E.chunks(head.Position - head.CFrame.LookVector * 0.6, Color3.fromRGB(176, 52, 110), 2, 0.4) end
					task.wait(0.22)
				end
			else
				E.play("pop", head, 0.6)
				if head then E.sparkle(head.Position - Vector3.new(0, 1.5, 0), Color3.fromRGB(120, 255, 150), 25) end
				task.wait(0.5)
			end
			reset(0.25)
		elseif kind == "place" and waist then
			tw(waist, waistBase, CFrame.Angles(rad(-35), 0, 0), 0.18)
			if arm then tw(arm, armBase, CFrame.Angles(rad(-30), 0, 0), 0.18) end
			task.wait(0.35)
			reset(0.25)
		end
	end)
end

local function flash(model, color)
	local hl = Instance.new("Highlight")
	hl.FillColor = color
	hl.FillTransparency = 0.5
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = model
	Debris:AddItem(hl, 0.18)
end

---------------------------------------------------------------- world events
local fallen = {}
local function treeFall(node)
	if not node or not node.Parent or fallen[node] then return end
	fallen[node] = true
	local pivot = node:GetPivot()
	local base = node:GetAttribute("Base") or (pivot.Position - Vector3.new(0, 6, 0))
	local dirAngle = rng:NextNumber(0, math.pi * 2)
	local axis = Vector3.new(math.cos(dirAngle), 0, math.sin(dirAngle))
	local rel = CFrame.new(base):Inverse() * pivot
	E.play("treeFall", base, 0.9)
	E.play("leaves", base + Vector3.new(0, 8, 0), 0.6)
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		if node.Parent then node:PivotTo(CFrame.new(base) * CFrame.fromAxisAngle(axis, a) * rel) end
	end)
	local t = TweenService:Create(v, TweenInfo.new(1.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = math.rad(86) })
	t:Play()
	t.Completed:Connect(function()
		local landing = base + Vector3.new(axis.Z, 0, -axis.X) * 0 + (CFrame.fromAxisAngle(axis, math.rad(86)) * Vector3.new(0, 7, 0))
		E.dust(landing, Color3.fromRGB(140, 120, 90), 18, 2)
		E.chunks(landing, Color3.fromRGB(70, 130, 60), 10, 1.4, Enum.Material.Grass)
		E.chunks(base + Vector3.new(0, 1, 0), Color3.fromRGB(150, 110, 70), 6, 0.8, Enum.Material.Wood)
		task.delay(0.5, function()
			v:Destroy()
			if node.Parent then node:PivotTo(pivot) end
			fallen[node] = nil
		end)
	end)
end

local MOB_SOUND = { wolf = "wolf", zombie = "zombie", guardian = "guardian", rabbit = "rabbit", deer = "deer", boar = "boar", bear = "bear", spider = "spider", alpha = "wolf",
	hare = "rabbit", snowwolf = "wolf", polarbear = "bear", yeti = "guardian", camel = "camel", goat = "deer", scorpion = "spider", scorpionking = "spider",
	bat = "spider", crawler = "spider", ghoul = "zombie", golem = "guardian",
	fox = "wolf", ram = "deer", mammoth = "bear", hyena = "wolf", puma = "bear", turtle = "rabbit", crab = "spider", crabking = "spider",
	monkey = "rabbit", tiger = "bear", snake = "spider", gorilla = "guardian", lavalizard = "spider", ashwolf = "wolf", magma = "guardian",
	bandit = "zombie", banditlord = "zombie" }

local handlers = {}
function handlers.anim(char, kind) E.anim(char, kind) end
-- a boss attack is coming: a red circle on the ground that fills up until it lands
function handlers.telegraph(pos, radius, delay)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = true, false, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 60, 50)
	ring.Transparency = 0.75
	ring.Size = Vector3.new(0.2, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	local core = ring:Clone()
	core.Size = Vector3.new(0.25, 0.2, 0.2)
	core.Transparency = 0.4
	core.Parent = workspace
	TweenService:Create(core, TweenInfo.new(math.max(0.05, delay), Enum.EasingStyle.Linear), { Size = Vector3.new(0.25, radius * 2, radius * 2) }):Play()
	task.delay(delay + 0.15, function() ring:Destroy() core:Destroy() end)
end
function handlers.hitTree(pos, node)
	E.play("chop", pos, 0.8)
	E.chunks(pos + Vector3.new(0, 1, 0), Color3.fromRGB(176, 130, 84), 5, 0.6, Enum.Material.Wood)
	if node and node.Parent and not fallen[node] then
		local pv = node:GetPivot()
		node:PivotTo(pv * CFrame.Angles(math.rad(2), 0, math.rad(2)))
		task.delay(0.07, function() if node.Parent and not fallen[node] then node:PivotTo(pv) end end)
		for _, p in ipairs(node:GetChildren()) do
			if p:IsA("BasePart") and p.Material == Enum.Material.Grass then
				E.chunks(p.Position, p.Color, 2, 0.7, Enum.Material.Grass)
				break
			end
		end
	end
end
function handlers.hitRock(pos)
	E.play("rockHit", pos, 0.8)
	E.chunks(pos + Vector3.new(0, 1, 0), Color3.fromRGB(130, 130, 136), 5, 0.6, Enum.Material.Slate)
	E.sparkle(pos + Vector3.new(0, 1, 0), Color3.fromRGB(255, 230, 180), 6)
end
function handlers.treeFall(node) treeFall(node) end
function handlers.rockBreak(pos)
	E.play("rockBreak", pos, 1)
	E.chunks(pos + Vector3.new(0, 1, 0), Color3.fromRGB(125, 126, 132), 14, 1.6, Enum.Material.Slate)
	E.dust(pos, Color3.fromRGB(150, 150, 150), 16, 1.8)
end
function handlers.pick(pos)
	E.play("leaves", pos, 0.6)
	E.chunks(pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(176, 40, 90), 5, 0.5)
end
function handlers.hitMob(pos, kind)
	E.play("hurt", pos, 0.7)
	if MOB_SOUND[kind] and rng:NextNumber() < 0.5 then E.play(MOB_SOUND[kind], pos, 0.7) end
	E.dust(pos, Color3.fromRGB(230, 230, 230), 6, 0.8)
end
function handlers.mobDie(pos, kind)
	E.play("poof", pos, 0.9)
	if MOB_SOUND[kind] then E.play(MOB_SOUND[kind], pos, 0.8, 0.8) end
	E.dust(pos, Color3.fromRGB(240, 240, 240), kind == "guardian" and 40 or 16, kind == "guardian" and 4 or 1.6)
	E.sparkle(pos, Color3.fromRGB(255, 230, 140), kind == "guardian" and 60 or 14)
end
function handlers.mobAttack(pos, kind)
	if MOB_SOUND[kind] then E.play(MOB_SOUND[kind], pos, 0.9) end
end
function handlers.hurt(char)
	flash(char, Color3.fromRGB(255, 70, 60))
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then E.play("hurt", hrp, 0.7) end
	local waist, base = motor(char, { "UpperTorso", "Waist" }, "HumanoidRootPart", "RootJoint")
	if waist then
		tw(waist, base, CFrame.Angles(rad(14), 0, 0), 0.06)
		task.delay(0.1, function() tw(waist, base, CFrame.new(), 0.2) end)
	end
end
function handlers.shoot(from, to, ammo)
	E.play(ammo == "arrow" and "bow" or "gun", from, ammo == "arrow" and 0.7 or 1)
	local dist = (to - from).Magnitude
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = ammo == "arrow" and Color3.fromRGB(210, 180, 130) or Color3.fromRGB(255, 225, 140)
	p.Size = Vector3.new(0.1, 0.1, dist)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.12), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.15)
	if ammo ~= "arrow" then E.sparkle(from, Color3.fromRGB(255, 200, 100), 8) end
	E.play(ammo == "arrow" and "arrowHit" or "rockHit", to, 0.5)
	E.dust(to, Color3.fromRGB(200, 190, 170), 4, 0.6)
end
function handlers.levelUp(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	E.play("levelUp", hrp, 0.9)
	E.sparkle(hrp.Position, Color3.fromRGB(255, 215, 90), 50)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 215, 90)
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, 16, 16), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.8)
end
function handlers.skillUp(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	E.play("skill", hrp, 0.9)
	E.sparkle(hrp.Position, Color3.fromRGB(110, 170, 255), 45)
	for i = 0, 1 do
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(110, 170, 255)
		ring.Size = Vector3.new(0.15, 3, 3)
		ring.CFrame = CFrame.new(hrp.Position + Vector3.new(0, -2.5 + i * 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Transparency = 0.2
		ring.Parent = workspace
		TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Size = Vector3.new(0.15, 11, 11), Transparency = 1, CFrame = ring.CFrame + Vector3.new(0, 3, 0) }):Play()
		Debris:AddItem(ring, 0.9)
	end
end
function handlers.explode(pos)
	E.play("explode", pos, 1)
	local ex = Instance.new("Explosion")
	ex.Position = pos
	ex.BlastPressure = 0
	ex.BlastRadius = 14
	ex.DestroyJointRadiusPercent = 0
	ex.Parent = workspace
	E.dust(pos, Color3.fromRGB(120, 110, 100), 30, 3)
	E.chunks(pos + Vector3.new(0, 1, 0), Color3.fromRGB(110, 100, 90), 16, 1.4, Enum.Material.Slate)
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - pos).Magnitude < 60 then
		task.spawn(function()
			for i = 1, 8 do
				cam.CFrame = cam.CFrame * CFrame.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4), 0)
				task.wait(0.03)
			end
		end)
	end
end
function handlers.cook(pos)
	E.play("eat", pos, 0.4, 0.6)
	E.dust(pos + Vector3.new(0, 2, 0), Color3.fromRGB(120, 120, 120), 10, 1)
end
function handlers.place(pos)
	E.play("place", pos, 0.8)
	E.dust(pos, Color3.fromRGB(150, 130, 100), 8, 0.9)
end
function handlers.crate(pos)
	E.play("crate", pos, 0.9)
	E.sparkle(pos + Vector3.new(0, 2, 0), Color3.fromRGB(255, 220, 120), 30)
end

---------------------------------------------------------------- footprints
local prints = {}
local lastPrint = {}
local function footprints()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.new()
	for _, pl in ipairs(Players:GetPlayers()) do
		local char = pl.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 and (hrp.Position - camPos).Magnitude < 90 then
			local mat = hum.FloorMaterial
			if mat ~= Enum.Material.Air and mat ~= Enum.Material.Water and hum.MoveDirection.Magnitude > 0.1 then
				local last = lastPrint[pl]
				if not last or (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(last.p.X, 0, last.p.Z)).Magnitude > 2.1 then
					local side = (last and last.side or 1) * -1
					lastPrint[pl] = { p = hrp.Position, side = side }
					local look = hrp.CFrame.LookVector
					local right = hrp.CFrame.RightVector
					local origin = hrp.Position + right * 0.45 * side
					local rp = RaycastParams.new()
					rp.FilterType = Enum.RaycastFilterType.Exclude
					rp.FilterDescendantsInstances = { char }
					local res = workspace:Raycast(origin, Vector3.new(0, -8, 0), rp)
					if res and res.Instance == workspace.Terrain then
						local p = Instance.new("Part")
						p.Anchored = true
						p.CanCollide = false
						p.CanQuery = false
						p.CanTouch = false
						p.CastShadow = false
						p.Size = Vector3.new(0.55, 0.06, 0.95)
						p.Color = Color3.fromRGB(62, 48, 36)
						p.Material = Enum.Material.SmoothPlastic
						p.Transparency = 0.35
						p.CFrame = CFrame.lookAt(res.Position + Vector3.new(0, 0.03, 0), res.Position + Vector3.new(look.X, 0, look.Z) + Vector3.new(0, 0.03, 0))
						p.Parent = workspace
						TweenService:Create(p, TweenInfo.new(9, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
						Debris:AddItem(p, 9.2)
						table.insert(prints, p)
						if #prints > 80 then
							local old = table.remove(prints, 1)
							if old then old:Destroy() end
						end
						if mat == Enum.Material.Mud or mat == Enum.Material.Ground then
							E.dust(res.Position, Color3.fromRGB(120, 100, 80), 1, 0.5)
						end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- ambience + fires
local function loopSound(name, parent, volume, maxDist)
	local s = Instance.new("Sound")
	s.SoundId = soundId(name)
	s.Looped = true
	s.Volume = volume
	if maxDist then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 6
		s.RollOffMaxDistance = maxDist
	end
	s.Parent = parent
	s:Play()
	return s
end

function E.fireSounds()
	local function add(part)
		if not part:IsA("BasePart") or part:FindFirstChild("FireLoop") then return end
		local s = loopSound("fire", part, 0.6, 45)
		s.Name = "FireLoop"
		local a = Instance.new("Attachment")
		a.Parent = part
		local p = Instance.new("ParticleEmitter")
		p.Texture = SPARK
		p.Color = ColorSequence.new(Color3.fromRGB(255, 170, 70))
		p.LightEmission = 1
		p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		p.Lifetime = NumberRange.new(0.8, 1.6)
		p.Rate = 6
		p.Speed = NumberRange.new(3, 6)
		p.SpreadAngle = Vector2.new(25, 25)
		p.Acceleration = Vector3.new(0, 3, 0)
		p.Parent = a
	end
	for _, p in ipairs(CollectionService:GetTagged("Heat")) do add(p) end
	CollectionService:GetInstanceAddedSignal("Heat"):Connect(add)
end

function E.ambience()
	local day = loopSound("dayAmbience", SoundService, 0)
	local night = loopSound("nightAmbience", SoundService, 0)
	local function update()
		local isNight = ReplicatedStorage:GetAttribute("Night") == true
		TweenService:Create(day, TweenInfo.new(4), { Volume = isNight and 0 or 0.22 }):Play()
		TweenService:Create(night, TweenInfo.new(4), { Volume = isNight and 0.28 or 0 }):Play()
	end
	update()
	ReplicatedStorage:GetAttributeChangedSignal("Night"):Connect(update)
end

function E.start(remotes)
	remotes.Fx.OnClientEvent:Connect(function(kind, a, b, c)
		local h = handlers[kind]
		if h then
			local ok, err = pcall(h, a, b, c)
			if not ok then warn("Fx", kind, err) end
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			pcall(footprints)
		end
	end)
	-- splash when the local player enters water
	local function watch(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if not hum then return end
		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Swimming then
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if hrp then
					E.play("splash", hrp.Position, 0.9)
					E.dust(hrp.Position, Color3.fromRGB(200, 230, 255), 14, 1.2)
				end
			end
		end)
	end
	local lp = Players.LocalPlayer
	if lp then
		if lp.Character then task.spawn(watch, lp.Character) end
		lp.CharacterAdded:Connect(watch)
	end
	E.fireSounds()
	E.ambience()
	-- light: real darkness at night and inside caves, thick regional fog, night vision
	task.spawn(function()
		local Biomes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Biomes"))
		local Lighting = game:GetService("Lighting")
		local cc = Lighting:FindFirstChild("LocalGrade") or Instance.new("ColorCorrectionEffect")
		cc.Name = "LocalGrade"
		cc.Parent = Lighting
		local terrainOnly = RaycastParams.new()
		terrainOnly.FilterType = Enum.RaycastFilterType.Include
		terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
		local current = nil
		local cave, caveT, nv = 0, false, 0
		local function mix(a, b, t) return a:Lerp(b, math.clamp(t, 0, 1)) end
		local function nightFactor(t)
			if t >= 6.5 and t <= 17.5 then return 0 end
			if t > 17.5 and t < 19.5 then return (t - 17.5) / 2 end
			if t >= 4.5 and t < 6.5 then return 1 - (t - 4.5) / 2 end
			return 1
		end
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = now - last
			last = now
			local lp = Players.LocalPlayer
			local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			local atm = Lighting:FindFirstChildOfClass("Atmosphere")
			if hrp then
				local b = Biomes.at(hrp.Position.X, hrp.Position.Z)
				if b ~= current then
					current = b
					E.regionChanged = b
					if E.onRegion then pcall(E.onRegion, b) end
				end
				-- under solid rock = inside a cave
				local up = workspace:Raycast(hrp.Position + Vector3.new(0, 2, 0), Vector3.new(0, 90, 0), terrainOnly)
				local inCave = up ~= nil
				if inCave ~= caveT then
					caveT = inCave
					if inCave and E.onCave then pcall(E.onCave) end
				end
			end
			cave += ((caveT and 1 or 0) - cave) * math.min(1, dt * 1.6)
			nv += ((E.vision and 1 or 0) - nv) * math.min(1, dt * 2)
			local t = Lighting.ClockTime
			local night = nightFactor(t)
			local dark = math.max(night, cave)
			-- day -> pitch black
			local amb = mix(Color3.fromRGB(100, 108, 118), Color3.fromRGB(3, 3, 6), dark)
			local out = mix(Color3.fromRGB(128, 136, 148), Color3.fromRGB(4, 4, 9), night)
			out = mix(out, Color3.new(0, 0, 0), cave)
			local bright = 2.4 + (0.04 - 2.4) * dark
			local expo = -0.7 * dark
			-- night vision lifts everything to a green glow
			amb = mix(amb, Color3.fromRGB(60, 95, 60), nv * dark)
			out = mix(out, Color3.fromRGB(70, 110, 70), nv * dark)
			bright += nv * dark * 1.2
			expo += nv * dark * 0.9
			Lighting.Ambient = amb
			Lighting.OutdoorAmbient = out
			Lighting.Brightness = bright
			Lighting.ExposureCompensation = expo
			cc.TintColor = mix(Color3.new(1, 1, 1), Color3.fromRGB(170, 255, 170), nv * dark)
			cc.Saturation = -0.35 * dark * (1 - nv)
			-- distance fog (the Atmosphere object would cancel it, so it is removed)
			if atm then atm:Destroy() end
			if current then
				local f = Biomes.fog[current]
				local dawn = (t > 4.5 and t < 8.5) and 0.6 or 1 -- thicker morning mist
				local finish = f.finish * dawn
				finish = finish + (110 - finish) * night * 0.55 -- you see less at night
				finish = finish + (85 - finish) * cave
				Lighting.FogStart = f.start * dawn * (1 - cave * 0.8)
				Lighting.FogEnd = finish
				Lighting.FogColor = mix(mix(f.color, Color3.fromRGB(8, 8, 14), night), Color3.new(0, 0, 0), cave)
				-- a ring of fog-coloured walls right at the fog's end: nothing behind it can be seen at all
				local cam = workspace.CurrentCamera
				if cam then
					local ring = cam:FindFirstChild("FogWall")
					if not ring then
						ring = Instance.new("Folder")
						ring.Name = "FogWall"
						ring.Parent = cam
						for i = 1, 28 do
							local p = Instance.new("Part")
							p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
							p.Material = Enum.Material.SmoothPlastic
							p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
							p.Parent = ring
						end
					end
					local R = finish + 6
					local c0 = cam.CFrame.Position
					local w = 2 * math.pi * R / 28 * 1.08
					for i, p in ipairs(ring:GetChildren()) do
						local a = (i / 28) * math.pi * 2
						p.Size = Vector3.new(w, 900, 2)
						p.Color = Lighting.FogColor
						p.CFrame = CFrame.lookAt(c0 + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R), c0)
					end
				end
			end
		end
	end)
	-- village people: swing arms and legs while they walk (they have no animation scripts)
	local people = {}
	RunService.Heartbeat:Connect(function(dt)
		local v = workspace:FindFirstChild("Villages")
		local cam = workspace.CurrentCamera
		if not v or not cam then return end
		local camPos = cam.CFrame.Position
		for _, village in ipairs(v:GetChildren()) do
			local npcs = village:FindFirstChild("NPCs")
			for _, rig in ipairs(npcs and npcs:GetChildren() or {}) do
				local hrp = rig:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - camPos).Magnitude < 150 then
					local w = people[rig]
					if not w then
						w = { last = hrp.Position, phase = 0, speed = 0, j = {} }
						for _, n in ipairs({ "LeftHip", "RightHip", "LeftShoulder", "RightShoulder" }) do
							local m = rig:FindFirstChild(n, true)
							if m and m:IsA("Motor6D") then w.j[n] = m end
						end
						people[rig] = w
					end
					local p = hrp.Position
					local sp = (Vector3.new(p.X, 0, p.Z) - Vector3.new(w.last.X, 0, w.last.Z)).Magnitude / math.max(dt, 1e-3)
					w.last = p
					w.speed += (sp - w.speed) * math.min(1, dt * 8)
					local amt = math.clamp(w.speed / 12, 0, 1)
					w.phase += dt * (3 + w.speed * 0.6)
					local sw = math.sin(w.phase) * 0.8 * amt
					if w.j.LeftHip then w.j.LeftHip.Transform = CFrame.Angles(sw, 0, 0) end
					if w.j.RightHip then w.j.RightHip.Transform = CFrame.Angles(-sw, 0, 0) end
					if w.j.LeftShoulder then w.j.LeftShoulder.Transform = CFrame.Angles(-sw * 0.8, 0, 0) end
					if w.j.RightShoulder and not rig:FindFirstChildOfClass("Tool") then w.j.RightShoulder.Transform = CFrame.Angles(sw * 0.8, 0, 0) end
				end
			end
		end
		for rig in pairs(people) do if not rig.Parent then people[rig] = nil end end
	end)
	-- creatures: swing the limbs with their real speed (runs on every client, smooth at render rate)
	local walkers = {}
	RunService.Heartbeat:Connect(function(dt)
		local mobs = workspace:FindFirstChild("Mobs")
		local cam = workspace.CurrentCamera
		if not mobs or not cam then return end
		local camPos = cam.CFrame.Position
		for _, m in ipairs(mobs:GetChildren()) do
			local hrp = m:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - camPos).Magnitude < 160 then
				local w = walkers[m]
				if not w then
					w = { last = hrp.Position, phase = 0, speed = 0, limbs = {} }
					for _, j in ipairs(hrp:GetChildren()) do
						if j:IsA("Motor6D") and j.Name == "Limb" then table.insert(w.limbs, j) end
					end
					walkers[m] = w
				end
				local p = hrp.Position
				local v = (Vector3.new(p.X, 0, p.Z) - Vector3.new(w.last.X, 0, w.last.Z)).Magnitude / math.max(dt, 1e-3)
				w.last = p
				w.speed += (v - w.speed) * math.min(1, dt * 8)
				local amt = math.clamp(w.speed / 10, 0, 1)
				w.phase += dt * (4 + w.speed * 0.7)
				for _, j in ipairs(w.limbs) do
					if j.Parent then
						j.Transform = CFrame.Angles(math.sin(w.phase + (j:GetAttribute("Phase") or 0)) * 0.7 * amt, 0, 0)
					end
				end
			end
		end
		for m in pairs(walkers) do
			if not m.Parent then walkers[m] = nil end
		end
	end)
end

return E
