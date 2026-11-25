local results2 = {}
local function check2(name, fn)
	local ok, err = pcall(fn)
	table.insert(results2, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
end
local SSS2 = game:GetService("ServerScriptService")
local notes = {}
local fake = {
	notify = function(_, k) table.insert(notes, k) end, broadcast = function(k) table.insert(notes, k) end,
	reward = function() end, giveItem = function(_, it) return 0 end, give = function() return 0 end,
	space = function() return 50 end, lucky = function() return false end, hurt = function() end, drop = function() end,
	room = function() return nil end, fx = function() end, power = function() return 3 end, addSp = function() end,
}
check2("Mobs spawn+kill", function()
	local Mobs = require(SSS2.Services.Mobs)
	Mobs.start(fake)
	for _, k in ipairs({ "rabbit", "deer", "wolf", "zombie", "guardian", "boar", "bear", "spider", "alpha", "hare", "snowwolf", "polarbear", "yeti", "camel", "goat", "scorpion", "scorpionking" }) do
		local m = Mobs.spawn(k, Vector3.new(0, 20, 0), 12)
		assert(m:GetAttribute("Level") == 12 and m:GetAttribute("MaxHP") > 20, "level " .. k)
		assert(m and m:FindFirstChild("HumanoidRootPart"), k)
		Mobs.damage(m, 5, nil)
		assert(m:GetAttribute("HP") < m:GetAttribute("MaxHP"), "hp " .. k)
		Mobs.damage(m, 99999, nil)
	end
	task.wait(1.5)
	assert(#workspace.Mobs:GetChildren() == 0, "mobs not cleaned: " .. #workspace.Mobs:GetChildren())
end)
check2("Loot drop", function()
	local Loot = require(SSS2.Services.Loot)
	Loot.init(fake)
	local b = Loot.drop(Vector3.new(5, 30, 5), { { id = "wood", n = 3 }, { id = "wood_axe", n = 1, d = 10 } }, 1)
	assert(b and b.Parent == workspace.Loot)
	for _, id in ipairs({ "wood", "wood_axe", "bow", "berries", "trap" }) do
		local d = Loot.dropItem(Vector3.new(8, 30, 8), { id = id, n = 3 })
		assert(d and d.Parent == workspace.Loot and d.PrimaryPart:FindFirstChildOfClass("ProximityPrompt"), "dropItem " .. id)
	end
end)
check2("Survival temp", function()
	local S = require(SSS2.Services.Survival)
	assert(type(S.envTemp(Vector3.new(), false, true)) == "number")
end)
check2("Items models + tools", function()
	local I = require(game.ReplicatedStorage.Shared.Items)
	for id in pairs(I.defs) do
		local m = I.model(id)
		assert(m and m.PrimaryPart, "model " .. id)
		local t = I.buildTool(id)
		assert(t and t:FindFirstChild("Handle"), "tool " .. id)
	end
end)
check2("Icons draw", function()
	local Icons = require(SSS2.Parent.StarterPlayer.StarterPlayerScripts.Client.Icons)
	local f = Instance.new("Frame")
	for _, n in ipairs({ "play", "ranking", "rooms", "look", "settings", "solo", "quick", "friend", "key", "coin", "skill", "heart", "drop", "food", "temp", "bag", "menu", "close", "plus", "lock", "trash", "sun", "moon", "home" }) do
		Icons.draw(n, f, 24, Color3.new(1, 1, 1))
	end
end)
check2("Effects handlers", function()
	local E = require(SSS2.Parent.StarterPlayer.StarterPlayerScripts.Client.Effects)
	local ev = { h = {} }
	function ev.Connect(self, f) table.insert(self.h, f) end
	E.start({ Fx = { OnClientEvent = ev } })
	local fire = ev.h[1]
	local rig = game.Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	rig.Parent = workspace
	local tree
	for _, mm in ipairs(workspace.Resources:GetChildren()) do if mm.Name == "Tree" then tree = mm break end end
	local p = Vector3.new(0, 20, 0)
	fire("anim", rig, "chop") fire("anim", rig, "thrust") fire("explode", Vector3.new(0, 20, 0)) fire("anim", rig, "mine") fire("anim", rig, "slash") fire("anim", rig, "gun") fire("anim", rig, "bow") fire("skillUp", rig) fire("anim", rig, "eat") fire("anim", rig, "aim") fire("anim", rig, "place") fire("anim", rig, "heal")
	fire("hitTree", tree:GetPivot().Position, tree) fire("treeFall", tree) fire("hitRock", p) fire("rockBreak", p) fire("pick", p)
	fire("hitMob", p, "wolf") fire("mobDie", p, "guardian") fire("mobAttack", p, "zombie") fire("hurt", rig)
	fire("shoot", p, p + Vector3.new(30, 0, 0), "arrow") fire("shoot", p, p + Vector3.new(30, 0, 0), "ammo")
	fire("levelUp", rig) fire("cook", p) fire("place", p) fire("crate", p)
	task.wait(2.5)
end)
return { results, results2 }
