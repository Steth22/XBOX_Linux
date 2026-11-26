-- Hunger, thirst, body temperature, regeneration and the day/night cycle.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage.Shared.Config)
local Biomes = require(ReplicatedStorage.Shared.Biomes)
local Items = require(ReplicatedStorage.Shared.Items)

local S = {}
local ctx
local temps = {} -- [Player] = body temperature
local warned = {}

local function isNight()
	local t = Lighting.ClockTime
	return t < 6 or t > 18.5
end

local function nearHeat(pos)
	for _, p in ipairs(CollectionService:GetTagged("Heat")) do
		if p:IsA("BasePart") and (p.Position - pos).Magnitude < 16 then return true end
	end
	return false
end

local function inWater(hum, pos)
	if hum:GetState() == Enum.HumanoidStateType.Swimming then return true end
	local ok, mats = pcall(function()
		local base = Vector3.new(math.floor(pos.X / 4) * 4, math.floor((pos.Y - 4) / 4) * 4, math.floor(pos.Z / 4) * 4)
		return workspace.Terrain:ReadVoxels(Region3.new(base, base + Vector3.new(4, 4, 4)), 4)
	end)
	return ok and mats[1] and mats[1][1] and mats[1][1][1] == Enum.Material.Water
end

-- outdoor temperature at a position (biomes can extend this later)
function S.envTemp(pos, wet, heat, armorId)
	local biome = Biomes.at(pos.X, pos.Z)
	local t = Biomes.temp[biome] or 22
	if pos.Y < -26 then
		-- deep underground the air is cool and steady (hot under the volcanoes, freezing under the snow)
		t = ({ snow = 4, volcano = 40, desert = 26 })[biome] or 16
		return t + (wet and -6 or 0) + (heat and 18 or 0)
	end
	if isNight() then t -= Biomes.nightDrop[biome] or 14 end
	if pos.Y > 70 then t -= (pos.Y - 70) / 8 end -- high peaks are colder
	local armor = armorId and Items.get(armorId)
	if armor and armor.warm and t < 22 then t = math.min(22, t + armor.warm) end
	if armor and armor.cool and t > 22 then t = math.max(22, t - armor.cool) end
	if wet then t -= 6 end
	if heat then t += 18 end
	return t
end

function S.temp(player)
	return temps[player] or 37
end

function S.reset(player)
	temps[player] = 37
end

local function tick(player)
	local room = ctx.room(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not room or not hum or not hrp or hum.Health <= 0 then return end
	local sk = room.skills
	local mult = math.max(0.15, 1 - 0.06 * (sk.resist or 0))

	room.hunger = math.max(0, room.hunger - 0.1 * mult)
	room.thirst = 100 -- thirst was removed from the game
	local wet = inWater(hum, hrp.Position)

	local heat = nearHeat(hrp.Position)
	local env = S.envTemp(hrp.Position, wet, heat, room.inv.armor)
	if ctx.buff and ctx.buff(player, "warmth") then env = 22 end
	local body = temps[player] or 37
	if env < 10 then
		body -= (10 - env) * 0.004 * mult
	elseif env > 32 then
		body += (env - 32) * 0.004 * mult
	else
		body += (37 - body) * 0.06
	end
	body = math.clamp(body, 30, 43)
	temps[player] = body

	local dmg = 0
	local cause = nil
	if room.hunger <= 0 then dmg += 1 cause = "hunger" end
	-- cold and heat hurt more the further the body is from normal
	if body < 35 then
		dmg += 3 + math.floor((35 - body) * 2)
		cause = "cold"
	elseif body > 39.5 then
		dmg += 3 + math.floor((body - 39.5) * 2)
		cause = "heat"
	end
	-- lava burns
	local okL, under = pcall(function()
		local p = hrp.Position - Vector3.new(0, 3.5, 0)
		local base = Vector3.new(math.floor(p.X / 4) * 4, math.floor(p.Y / 4) * 4, math.floor(p.Z / 4) * 4)
		local mats = workspace.Terrain:ReadVoxels(Region3.new(base, base + Vector3.new(4, 4, 4)), 4)
		return mats[1][1][1]
	end)
	if okL and under == Enum.Material.CrackedLava then
		ctx.hurt(player, 12, "lava")
		if not warned[player] or os.clock() - warned[player] > 6 then
			warned[player] = os.clock()
			ctx.notify(player, "lava")
		end
	end
	if dmg > 0 then
		ctx.hurt(player, dmg, cause)
		local key = room.hunger <= 0 and "starving" or "freezing"
		if not warned[player] or os.clock() - warned[player] > 20 then
			warned[player] = os.clock()
			ctx.notify(player, key)
		end
	elseif room.hunger > 80 and hum.Health < hum.MaxHealth then
		-- slow natural healing, only when well fed
		hum.Health = math.min(hum.MaxHealth, hum.Health + 0.2 * (1 + 0.15 * (sk.aid or 0)))
	end
end

-- everyone slept: jump to the morning and start a new day
function S.skipNight()
	Lighting.ClockTime = 6.3
	local day = (ReplicatedStorage:GetAttribute("Day") or 1) + 1
	ReplicatedStorage:SetAttribute("Day", day)
	ReplicatedStorage:SetAttribute("Night", false)
	if ctx and ctx.newDay then pcall(ctx.newDay, day) end
end

function S.start(c)
	ctx = c
	Lighting.ClockTime = 8
	if not ReplicatedStorage:GetAttribute("Day") then ReplicatedStorage:SetAttribute("Day", 1) end
	local perSecond = 24 / Config.DAY_LENGTH
	task.spawn(function()
		while true do
			task.wait(1)
			local before = Lighting.ClockTime
			Lighting.ClockTime = (Lighting.ClockTime + perSecond) % 24
			if before < 6 and Lighting.ClockTime >= 6 then
				local day = (ReplicatedStorage:GetAttribute("Day") or 1) + 1
				ReplicatedStorage:SetAttribute("Day", day)
				if ctx.newDay then pcall(ctx.newDay, day) end
			end
			ReplicatedStorage:SetAttribute("Night", isNight())
			for _, pl in ipairs(Players:GetPlayers()) do
				local ok, err = pcall(tick, pl)
				if not ok then warn("Survival tick:", err) end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(pl)
		temps[pl] = nil
		warned[pl] = nil
	end)
end

return S
