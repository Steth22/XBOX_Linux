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
-- Avatar joints are AnimationConstraints now (Motor6D on older rigs). Both have a Transform that the
-- Animator writes every frame, so each pose here is an extra offset (a CFrameValue we tween) laid on
-- top of the Animator's pose right after it runs (PreSimulation), before the frame is drawn.
local offsets = setmetatable({}, { __mode = "k" }) -- joint -> CFrameValue
local function isJoint(m) return m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) end
local function motor(char, r15, r6parent, r6)
	local p = char:FindFirstChild(r15[1])
	local m = p and p:FindFirstChild(r15[2])
	if not isJoint(m) then
		local t = char:FindFirstChild(r6parent)
		m = t and t:FindFirstChild(r6)
	end
	if isJoint(m) then
		local v = offsets[m]
		if not v then
			v = Instance.new("CFrameValue")
			offsets[m] = v
		end
		return v, CFrame.new()
	end
	return nil
end
local function tw(v, base, cf, t, style)
	TweenService:Create(v, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = base * cf }):Play()
end
local baseT, wrote = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
RunService.PreSimulation:Connect(function()
	for joint, v in pairs(offsets) do
		if joint.Parent then
			local cur = joint.Transform
			-- if nothing animated this joint since our last write, start again from the pose under it
			if wrote[joint] and cur == wrote[joint] then cur = baseT[joint] or cur end
			if v.Value ~= CFrame.identity then
				baseT[joint] = cur
				joint.Transform = cur * v.Value
				wrote[joint] = joint.Transform
			elseif wrote[joint] then
				joint.Transform = cur
				wrote[joint], baseT[joint] = nil, nil
			end
		else
			offsets[joint] = nil
		end
	end
end)
local rad = math.rad

-- Photo-mode poses: the character's own animations are stopped (and its Animate script paused), then
-- every joint is set to the pose directly, before each physics step and before each frame is drawn,
-- so nothing can pull the body out of it.
local POSE_JOINTS = {
	arm = { "RightUpperArm", "RightShoulder" }, larm = { "LeftUpperArm", "LeftShoulder" },
	rlow = { "RightLowerArm", "RightElbow" }, llow = { "LeftLowerArm", "LeftElbow" },
	head = { "Head", "Neck" }, waist = { "UpperTorso", "Waist" },
	rleg = { "RightUpperLeg", "RightHip" }, lleg = { "LeftUpperLeg", "LeftHip" },
}
local held = {} -- [character] = { joints = { [joint] = CFrame }, conns = {} }
function E.isPosed(char) return held[char] ~= nil end
function E.photoPose(char, angles)
	if not char then return false end
	local h = held[char]
	if not angles then
		if h then
			for _, cn in ipairs(h.conns) do cn:Disconnect() end
			for j in pairs(h.joints) do if j.Parent then j.Transform = CFrame.identity end end
			local animate = char:FindFirstChild("Animate")
			if animate then animate.Disabled = false end
			held[char] = nil
		end
		return true
	end
	if not h then
		h = { joints = {}, conns = {} }
		held[char] = h
		local animate = char:FindFirstChild("Animate")
		if animate then animate.Disabled = true end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do tr:Stop(0.1) end end
		local function hold()
			for j, cf in pairs(h.joints) do if j.Parent then j.Transform = cf end end
		end
		table.insert(h.conns, RunService.PreSimulation:Connect(hold))
		table.insert(h.conns, RunService.PreRender:Connect(hold))
		table.insert(h.conns, RunService.PostSimulation:Connect(hold))
	end
	h.joints = {}
	for key, path in pairs(POSE_JOINTS) do
		local part = char:FindFirstChild(path[1])
		local j = part and part:FindFirstChild(path[2])
		if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
			local a = angles[key]
			h.joints[j] = a and CFrame.Angles(math.rad(a[1] or 0), math.rad(a[2] or 0), math.rad(a[3] or 0)) or CFrame.identity
		end
	end
	return true
end
-- ready-made poses (angles in degrees for each joint)
local POSES = {
	none = nil,
	sword = { arm = { 160, 0, -8 }, larm = { 40, 0, 20 }, waist = { 0, -12, 0 }, rleg = { -15, 0, 0 }, lleg = { 18, 0, 0 } },
	slash = { arm = { 20, 70, -50 }, larm = { 30, 0, 25 }, waist = { 0, 35, 0 }, rleg = { -20, 0, 0 }, lleg = { 20, 0, 0 } },
	victory = { arm = { 170, 0, -20 }, larm = { 170, 0, 20 }, waist = { -8, 0, 0 }, head = { -15, 0, 0 } },
	point = { arm = { 90, 0, 0 }, larm = { 0, 0, 10 }, waist = { 0, -20, 0 }, head = { 0, -15, 0 } },
	guard = { arm = { 70, 30, -20 }, larm = { 80, -30, 20 }, waist = { 8, 0, 0 }, rleg = { -25, 0, 0 }, lleg = { 25, 0, 0 } },
	lantern = { arm = { 0, 0, 0 }, larm = { 85, 0, 10 }, waist = { 0, 10, 0 }, head = { 0, 15, 0 } },
	run = { arm = { -50, 0, 0 }, larm = { 60, 0, 0 }, rlow = { 40, 0, 0 }, llow = { 40, 0, 0 }, rleg = { 50, 0, 0 }, lleg = { -40, 0, 0 }, waist = { 12, 0, 0 } },
}
E.POSE_LIST = { "none", "sword", "slash", "guard", "victory", "point", "lantern", "run" }
E.JOINT_LIST = { "arm", "larm", "rlow", "llow", "head", "waist", "rleg", "lleg" }
-- a copy of a ready-made pose, to start editing from
function E.poseAngles(name)
	local out = {}
	for k, v in pairs(POSES[name] or {}) do out[k] = { v[1], v[2], v[3] } end
	return out
end
function E.pose(char, name)
	if name == "none" or not POSES[name] then return E.photoPose(char, nil) end
	return E.photoPose(char, E.poseAngles(name))
end

local lastLocal = {}
function E.anim(char, kind, isLocal)
	if not char or not char.Parent then return end
	if E.photo then return end -- photo mode: taps must not swing (that would undo the pose)
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
			-- hand up to the mouth, a few bites
			local fore, foreBase = motor(char, { "RightLowerArm", "RightElbow" }, "Torso", "Right Shoulder")
			tw(arm, armBase, CFrame.Angles(rad(70), 0, rad(-28)), 0.18)
			if fore and fore ~= arm then tw(fore, foreBase, CFrame.Angles(rad(80), 0, 0), 0.18) end
			task.wait(0.2)
			if kind == "eat" then
				for k = 1, 3 do
					E.play("eat", head, 0.85)
					if head then E.chunks(head.Position - head.CFrame.LookVector * 0.6, Color3.fromRGB(176, 52, 110), 2, 0.4) end
					tw(arm, armBase, CFrame.Angles(rad(58), 0, rad(-24)), 0.1)
					task.wait(0.11)
					tw(arm, armBase, CFrame.Angles(rad(72), 0, rad(-28)), 0.1)
					task.wait(0.13)
				end
				if fore and fore ~= arm then tw(fore, foreBase, CFrame.new(), 0.25) end
			else
				E.play("pop", head, 0.6)
				if head then E.sparkle(head.Position - Vector3.new(0, 1.5, 0), Color3.fromRGB(120, 255, 150), 25) end
				task.wait(0.5)
			end
			reset(0.25)
			if fore and fore ~= arm then tw(fore, foreBase, CFrame.new(), 0.25) end
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
function handlers.craft(pos)
	E.play("place", pos, 0.9, 0.7)
	E.dust(pos, Color3.fromRGB(170, 130, 80), 10, 1)
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

---------------------------------------------------------------- weather: rain, snow, wind, lightning, thunder, tornado
local RAIN_TEX = "rbxassetid://71434446598916"
local FLAKE_TEX = "rbxassetid://121235542395120"
local function loopSound(name)
	local id = Sounds[name] and Sounds[name][1]
	local s = Instance.new("Sound")
	s.SoundId = id and ("rbxassetid://" .. id) or ""
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	return s
end
local function startWeather()
	local Biomes = require(ReplicatedStorage.Shared.Biomes)
	local Lighting = game:GetService("Lighting")
	-- a big invisible sheet above the camera sends the rain down around you
	local sky = Instance.new("Part")
	sky.Name = "WeatherSky"
	sky.Anchored = true
	sky.CanCollide = false
	sky.CanQuery = false
	sky.CanTouch = false
	sky.Transparency = 1
	sky.Size = Vector3.new(130, 1, 130)
	local rain = Instance.new("ParticleEmitter")
	rain.Texture = RAIN_TEX
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Speed = NumberRange.new(110, 130)
	rain.Lifetime = NumberRange.new(0.7, 0.9)
	rain.Size = NumberSequence.new(0.5)
	rain.Squash = NumberSequence.new(-1.2)
	rain.Transparency = NumberSequence.new(0.35)
	rain.LightInfluence = 0.6
	rain.Rate = 0
	rain.WindAffectsDrag = true
	rain.Drag = 0.2
	rain.Parent = sky
	local snow = Instance.new("ParticleEmitter")
	snow.Texture = FLAKE_TEX
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Speed = NumberRange.new(10, 16)
	snow.Lifetime = NumberRange.new(5, 7)
	snow.Size = NumberSequence.new(0.35, 0.5)
	snow.SpreadAngle = Vector2.new(20, 20)
	snow.RotSpeed = NumberRange.new(-60, 60)
	snow.Rate = 0
	snow.WindAffectsDrag = true
	snow.Drag = 1.2
	snow.Parent = sky
	-- wind: dust and leaves blowing past
	local gustBox = Instance.new("Part")
	gustBox.Name = "WeatherGust"
	gustBox.Anchored, gustBox.CanCollide, gustBox.CanQuery, gustBox.CanTouch = true, false, false, false
	gustBox.Transparency = 1
	gustBox.Size = Vector3.new(90, 20, 90)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = SMOKE
	dust.Color = ColorSequence.new(Color3.fromRGB(196, 186, 160))
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.85), NumberSequenceKeypoint.new(1, 1) })
	dust.Size = NumberSequence.new(4, 9)
	dust.Speed = NumberRange.new(0, 1)
	dust.Lifetime = NumberRange.new(2.5, 4)
	dust.Rate = 0
	dust.WindAffectsDrag = true
	dust.Drag = 2
	dust.Parent = gustBox
	local leaves = Instance.new("ParticleEmitter")
	leaves.Texture = SPARK
	leaves.Color = ColorSequence.new(Color3.fromRGB(90, 140, 60), Color3.fromRGB(150, 120, 60))
	leaves.Size = NumberSequence.new(0.25)
	leaves.Speed = NumberRange.new(0, 2)
	leaves.Lifetime = NumberRange.new(2, 3)
	leaves.RotSpeed = NumberRange.new(-200, 200)
	leaves.Rate = 0
	leaves.WindAffectsDrag = true
	leaves.Drag = 1.5
	leaves.Parent = gustBox
	local sRainL, sRainH, sWind, sWindS, sTornado = loopSound("rainLight"), loopSound("rainHeavy"), loopSound("wind"), loopSound("windStrong"), loopSound("tornado")
	for _, snd in ipairs({ sRainL, sRainH, sWind, sWindS }) do snd:Play() end
	local vol = { [sRainL] = 0, [sRainH] = 0, [sWind] = 0, [sWindS] = 0, [sTornado] = 0 }
	-- a lightning bolt far away, then the thunder a moment later
	local function bolt(origin)
		local cam = workspace.CurrentCamera
		if not cam then return end
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(140, 320)
		local base = origin + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local hit = workspace:Raycast(base + Vector3.new(0, 300, 0), Vector3.new(0, -500, 0))
		local ground = hit and hit.Position or base
		local top = ground + Vector3.new(rng:NextNumber(-30, 30), 260, rng:NextNumber(-30, 30))
		local folder = Instance.new("Folder")
		folder.Name = "Lightning"
		folder.Parent = cam
		local prev = top
		for k = 1, 10 do
			local t = k / 10
			local p = top:Lerp(ground, t) + (k < 10 and Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12)) or Vector3.zero)
			local seg = Instance.new("Part")
			seg.Anchored, seg.CanCollide, seg.CanQuery, seg.CanTouch = true, false, false, false
			seg.Material = Enum.Material.Neon
			seg.Color = Color3.fromRGB(220, 230, 255)
			local len = (p - prev).Magnitude
			seg.Size = Vector3.new(0.9, 0.9, len)
			seg.CFrame = CFrame.lookAt((p + prev) / 2, p)
			seg.Parent = folder
			prev = p
		end
		local light = Instance.new("PointLight")
		light.Range = 60
		light.Brightness = 8
		light.Color = Color3.fromRGB(200, 215, 255)
		light.Parent = folder:GetChildren()[10]
		E.flash = 0.35
		E.play("lightning", nil, 0.45)
		task.delay(0.07, function() E.flash = 0 end)
		task.delay(0.14, function() E.flash = 0.25 end)
		task.delay(0.22, function() E.flash = 0 folder:Destroy() end)
		task.delay(d / 340 * 3, function() E.play("thunder", nil, 0.9 * (1 - d / 500)) end)
	end
	-- the tornado: drawn here around the part the server moves, spinning smoothly
	local tornadoView = nil
	local function buildTornado(core)
		local m = Instance.new("Model")
		m.Name = "TornadoView"
		local rings = {}
		for k = 1, 14 do
			local t = (k - 1) / 13
			local r = 5 + t ^ 1.6 * 34
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Cylinder
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.Material = Enum.Material.SmoothPlastic
			p.Color = Color3.fromRGB(120, 118, 112):Lerp(Color3.fromRGB(80, 82, 88), t)
			p.Transparency = 0.45 + t * 0.2
			p.Size = Vector3.new(7, r * 2, r * 2)
			p.Parent = m
			table.insert(rings, { part = p, h = 3 + k * 6.5, r = r, ph = rng:NextNumber(0, 6) })
		end
		local dustE = Instance.new("ParticleEmitter")
		dustE.Texture = SMOKE
		dustE.Color = ColorSequence.new(Color3.fromRGB(110, 100, 86))
		dustE.Size = NumberSequence.new(8, 18)
		dustE.Transparency = NumberSequence.new(0.5, 1)
		dustE.Speed = NumberRange.new(10, 20)
		dustE.SpreadAngle = Vector2.new(180, 20)
		dustE.Lifetime = NumberRange.new(2, 3)
		dustE.Rate = 30
		dustE.RotSpeed = NumberRange.new(-90, 90)
		local base = rings[1].part
		dustE.Parent = base
		m.Parent = workspace
		sTornado.Parent = base
		sTornado.RollOffMaxDistance = 400
		sTornado.RollOffMinDistance = 30
		sTornado:Play()
		return { model = m, rings = rings, core = core }
	end
	local lastBolt = 0
	local nextBolt = 0
	local level = { rain = 0, wind = 0 }
	local flung = 0
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera
		if not cam then return end
		local w = ReplicatedStorage:GetAttribute("Weather") or "clear"
		local wd = ReplicatedStorage:GetAttribute("WindDir") or Vector3.new(1, 0, 0)
		local pos = cam.CFrame.Position
		local lp = Players.LocalPlayer
		local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		local here = hrp and hrp.Position or pos
		local under = here.Y < -26
		-- a roof of rock or a building overhead keeps the rain off
		local covered = under
		if not covered and math.floor(os.clock() * 4) % 2 == 0 then
			local hit = workspace:Raycast(here + Vector3.new(0, 3, 0), Vector3.new(0, 60, 0))
			E.weatherCovered = hit ~= nil
		end
		covered = covered or E.weatherCovered == true
		local targetRain = (w == "rain" and 0.55 or w == "storm" and 1 or 0)
		local targetWind = (w == "wind" and 0.8 or w == "storm" and 1 or w == "rain" and 0.3 or 0.08)
		level.rain += (targetRain - level.rain) * math.min(1, dt * 0.5)
		level.wind += (targetWind - level.wind) * math.min(1, dt * 0.5)
		E.weatherDim = level.rain * 0.9 + (w == "wind" and 0.1 or 0)
		workspace.GlobalWind = wd * (6 + level.wind * 44)
		local biome = Biomes.at(here.X, here.Z)
		local snowy = biome == "snow" or (biome == "mountains" and here.Y > 120)
		local outside = not under
		sky.Parent = outside and cam or nil
		gustBox.Parent = outside and cam or nil
		sky.CFrame = CFrame.new(pos + Vector3.new(0, 45, 0)) + wd * -level.wind * 18
		gustBox.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0)) - wd * 30
		rain.Rate = (not snowy and outside) and level.rain * 1400 or 0
		snow.Rate = (snowy and outside) and level.rain * 500 or 0
		dust.Rate = outside and (level.wind > 0.5 and (level.wind - 0.5) * 14 or 0) * (biome == "desert" and 3 or 1) or 0
		leaves.Rate = outside and (biome ~= "desert" and biome ~= "snow") and math.max(0, level.wind - 0.4) * 40 or 0
		-- sounds: quieter under a roof, silent deep underground
		local muffle = under and 0 or (covered and 0.35 or 1)
		vol[sRainL] = (not snowy) and math.clamp(level.rain * 1.6, 0, 1) * (1 - level.rain) * 1.6 * 0.6 * muffle or 0
		vol[sRainH] = (not snowy) and math.max(0, level.rain - 0.5) * 2 * 0.8 * muffle or 0
		vol[sWind] = math.clamp(level.wind - 0.1, 0, 0.7) * 0.7 * muffle
		vol[sWindS] = math.max(0, level.wind - 0.6) * 1.6 * 0.6 * muffle
		for snd, v in pairs(vol) do
			if snd ~= sTornado then snd.Volume += (v - snd.Volume) * math.min(1, dt * 2) end
		end
		-- lightning in a storm
		if w == "storm" and outside and os.clock() > nextBolt then
			nextBolt = os.clock() + rng:NextNumber(7, 18)
			if os.clock() - lastBolt > 5 then lastBolt = os.clock() task.spawn(bolt, here) end
		end
		if w ~= "storm" and E.flash and E.flash ~= 0 then E.flash = 0 end
		-- tornado
		local core = workspace:FindFirstChild("Tornado")
		if core and not tornadoView then tornadoView = buildTornado(core) end
		if tornadoView and (not core or tornadoView.core ~= core) then
			sTornado:Stop()
			sTornado.Parent = SoundService
			tornadoView.model:Destroy()
			tornadoView = nil
		end
		if tornadoView then
			local c = core.Position
			local t = os.clock()
			for k, rg in ipairs(tornadoView.rings) do
				local sway = Vector3.new(math.sin(t * 0.8 + k * 0.35) * k * 0.9, 0, math.cos(t * 0.6 + k * 0.3) * k * 0.9)
				rg.part.CFrame = CFrame.new(c + Vector3.new(0, rg.h, 0) + sway) * CFrame.Angles(0, t * 4 + rg.ph, math.pi / 2)
			end
			sTornado.Volume = 1
			-- pulled in, then thrown up and around when too close
			if hrp and outside then
				local flat = Vector3.new(c.X - here.X, 0, c.Z - here.Z)
				local d = flat.Magnitude
				if d < 70 and d > 1 then
					local pull = flat.Unit * (1 - d / 70) * 28
					hrp.AssemblyLinearVelocity += pull * dt * 3
				end
				if d < 20 and os.clock() - flung > 1.2 then
					flung = os.clock()
					local side = Vector3.new(-flat.Z, 0, flat.X).Unit
					hrp.AssemblyLinearVelocity = Vector3.new(0, 70, 0) + side * 45
					E.play("gust", hrp, 1)
				end
			end
		end
	end)
	-- a gust now and then when it is windy
	task.spawn(function()
		while true do
			task.wait(rng:NextNumber(5, 11))
			local w = ReplicatedStorage:GetAttribute("Weather")
			local lp = Players.LocalPlayer
			local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
			if (w == "wind" or w == "storm") and hrp and hrp.Position.Y > -26 and not E.weatherCovered then
				E.play("gust", nil, 0.5)
			end
		end
	end)
end

---------------------------------------------------------------- powers: fire / ice orbiting players, burning and frozen creatures
local function startPowers()
	local folder = Instance.new("Folder")
	folder.Name = "PowerFX"
	folder.Parent = workspace
	local rigs = {} -- [character] = { fire = {parts}, ice = {parts} }
	local function orb(kind)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.CastShadow = false
		if kind == "fire" then
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.new(0.9, 0.9, 0.9)
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(255, 120, 30)
			local f = Instance.new("Fire")
			f.Size = 2.2
			f.Heat = 4
			f.Color = Color3.fromRGB(255, 140, 40)
			f.SecondaryColor = Color3.fromRGB(255, 60, 20)
			f.Parent = p
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(255, 140, 60)
			l.Range = 8
			l.Brightness = 1.2
			l.Parent = p
		else
			p.Size = Vector3.new(0.5, 1.3, 0.5)
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(170, 225, 255)
			local sp = Instance.new("Sparkles")
			sp.SparkleColor = Color3.fromRGB(200, 235, 255)
			sp.Parent = p
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(150, 210, 255)
			l.Range = 7
			l.Brightness = 0.9
			l.Parent = p
		end
		p.Parent = folder
		return p
	end
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local seen = {}
		for _, pl in ipairs(Players:GetPlayers()) do
			local char = pl.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				seen[char] = true
				local rg = rigs[char] or { fire = {}, ice = {} }
				rigs[char] = rg
				for _, kind in ipairs({ "fire", "ice" }) do
					local lvl = char:GetAttribute(kind == "fire" and "AuraFire" or "AuraIce")
					local list = rg[kind]
					local want = lvl and (2 + math.min(lvl, 3)) or 0
					while #list < want do table.insert(list, orb(kind)) end
					while #list > want do table.remove(list):Destroy() end
					local n = #list
					for k, p in ipairs(list) do
						local dir = kind == "fire" and 1 or -1
						local a = t * 2.6 * dir + (k - 1) / n * math.pi * 2
						local rad = 4 + (lvl or 0) * 0.3
						local y = kind == "fire" and 0.4 or -0.6
						local pos = hrp.Position + Vector3.new(math.cos(a) * rad, y + math.sin(t * 3 + k) * 0.35, math.sin(a) * rad)
						p.CFrame = CFrame.new(pos) * CFrame.Angles(0, -a, kind == "ice" and 0.5 or 0)
					end
				end
			end
		end
		for char, rg in pairs(rigs) do
			if not seen[char] then
				for _, l in pairs(rg) do for _, p in ipairs(l) do p:Destroy() end end
				rigs[char] = nil
			end
		end
	end)
	-- creatures on fire / frozen
	task.spawn(function()
		while true do
			task.wait(0.3)
			local mobs = workspace:FindFirstChild("Mobs")
			for _, m in ipairs(mobs and mobs:GetChildren() or {}) do
				local root = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
				if root then
					local fire = root:FindFirstChild("PowerFire")
					if m:GetAttribute("Burning") and not fire then
						fire = Instance.new("Fire")
						fire.Name = "PowerFire"
						fire.Size = math.clamp(root.Size.Magnitude * 1.2, 4, 12)
						fire.Heat = 9
						fire.Parent = root
					elseif not m:GetAttribute("Burning") and fire then
						fire:Destroy()
					end
					local ice = m:FindFirstChild("PowerIce")
					if m:GetAttribute("Frozen") and not ice then
						ice = Instance.new("Highlight")
						ice.Name = "PowerIce"
						ice.FillColor = Color3.fromRGB(150, 215, 255)
						ice.FillTransparency = 0.3
						ice.OutlineColor = Color3.fromRGB(230, 245, 255)
						ice.OutlineTransparency = 0.2
						ice.Parent = m
						E.play("rockHit", root.Position, 0.5, 1.6)
					elseif not m:GetAttribute("Frozen") and ice then
						ice:Destroy()
					end
				end
			end
		end
	end)
end

function E.start(remotes)
	task.spawn(function()
		local okP, errP = pcall(startPowers)
		if not okP then warn("powers", errP) end
	end)
	task.spawn(function()
		local ok, err = pcall(startWeather)
		if not ok then warn("weather", err) end
	end)
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
		local lift = 0
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
			-- night vision potion: a green glow
			nv += ((E.vision and 1 or 0) - nv) * math.min(1, dt * 2)
			-- the admin's night vision: simply takes the dark away (normal colours), as strong as chosen
			lift += ((E.visionAdmin or 0) - lift) * math.min(1, dt * 3)
			if E.photo then continue end -- photo mode sets the light itself
			local cave = cave * (1 - lift)
			local t = Lighting.ClockTime
			local night = nightFactor(t) * (1 - lift)
			local dark = math.max(night, cave)
			-- day -> pitch black
			local amb = mix(Color3.fromRGB(100, 108, 118), Color3.fromRGB(3, 3, 6), dark)
			local out = mix(Color3.fromRGB(128, 136, 148), Color3.fromRGB(4, 4, 9), night)
			out = mix(out, Color3.new(0, 0, 0), cave)
			local wdim = (E.weatherDim or 0) * (1 - cave)
			local bright = 2.4 + (0.04 - 2.4) * dark
			bright *= 1 - 0.45 * wdim
			amb = mix(amb, Color3.fromRGB(70, 74, 82), wdim * 0.5 * (1 - dark))
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
			cc.Saturation = -0.35 * dark * (1 - nv) - 0.25 * wdim
			cc.Brightness = E.flash or 0
			-- distance fog (the Atmosphere object would cancel it, so it is removed)
			if atm then atm:Destroy() end
			if current then
				local f = Biomes.fog[current]
				local dawn = (t > 4.5 and t < 8.5) and 0.6 or 1 -- thicker morning mist
				local finish = f.finish * dawn
				finish = finish + (110 - finish) * night * 0.55 -- you see less at night
				finish = finish + (85 - finish) * cave
				finish = finish + (f.finish - finish) * nv * 0.85 -- night vision sees further in the dark
				finish = finish * (1 - 0.45 * wdim)
				Lighting.FogStart = f.start * dawn * (1 - cave * 0.8) * (1 - 0.6 * wdim)
				Lighting.FogEnd = finish
				Lighting.FogColor = mix(mix(mix(f.color, Color3.fromRGB(104, 110, 120), wdim * 0.7), Color3.fromRGB(8, 8, 14), night), Color3.new(0, 0, 0), cave)
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
							if m and (m:IsA("Motor6D") or m:IsA("AnimationConstraint")) then w.j[n] = m end
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
		if E.freezeMobs then return end -- photo mode: legs stay exactly where they are
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
