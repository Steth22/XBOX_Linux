local results = {}
local function check(name, fn)
	local ok, err = pcall(fn)
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (ok and "" or (": " .. tostring(err))))
end
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

check("Format", function()
	local F = require(RS.Shared.Format)
	assert(F.number(136200) == "136.2K" and F.number(1088) == "1088" and F.number(10900) == "10.9K" and F.number(1100000) == "1.1M" and F.number(3) == "3")
end)
check("Locale", function()
	local L = require(RS.Shared.Locale)
	assert(L.t("ar", "play") == "العب" and L.f("en", "hoursLeft", 5) == "Ends in 5h")
end)
check("Items.buildTool", function()
	local I = require(RS.Shared.Items)
	for id in pairs(I.defs) do
		local t = I.buildTool(id)
		assert(t and t:FindFirstChild("Handle"), id)
	end
end)
check("Inventory", function()
	local Inv = require(SSS.Services.Inventory)
	local inv = Inv.new()
	assert(Inv.add(inv, "wood", 60) == 0 and inv.slots[1].n == 50 and inv.slots[2].n == 10)
	assert(not Inv.usable(inv, 6)); inv.bag = true; assert(Inv.usable(inv, 6) and not Inv.usable(inv, 21))
end)
check("Data/Rooms/World/Lobby/Resources require", function()
	for _, n in ipairs({"Data", "Rooms", "Resources", "World", "Lobby", "Furnace", "Powers", "Weather", "Achieve"}) do
		local m = require(SSS.Services[n])
		assert(type(m) == "table", n)
	end
end)
check("Appearance.apply R15", function()
	local A = require(RS.Shared.Appearance)
	local m = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	A.apply(m, { skin = 3, shirt = 2, pants = 2, hat = "cowboy", extra = "backpack" })
	local acc = 0
	for _, c in ipairs(m:GetChildren()) do if c:IsA("Accessory") then acc += 1 end end
	assert(acc == 0, "accessories=" .. acc)
	assert(m:FindFirstChild("Body") and #m.Body:GetChildren() > 25, "body parts " .. #m.Body:GetChildren())
	assert(m.Head.Transparency == 1 and not m.Head:FindFirstChildOfClass("Decal"), "faceless")
	for _, h in ipairs(A.hats) do for _, e in ipairs(A.extras) do A.apply(m, { skin = 1, shirt = 1, pants = 1, hat = h, extra = e }) end end
end)
check("Appearance.apply R6", function()
	local A = require(RS.Shared.Appearance)
	local m = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R6)
	A.apply(m, { skin = 1, shirt = 1, pants = 1, hat = "helmet", extra = "scarf" })
end)

-- UI construction with mock remotes
local function fakeEvent()
	local e = { handlers = {} }
	function e.Connect(self, fn) table.insert(self.handlers, fn) return { Disconnect = function() end } end
	return e
end
check("WorldUI build", function()
	local gui = Instance.new("ScreenGui")
	local remotes = { State = { OnClientEvent = fakeEvent() }, Notify = { OnClientEvent = fakeEvent() }, World = { InvokeServer = function() return true end } }
	local wsrc = SSS.Parent.StarterPlayer.StarterPlayerScripts.Client.WorldUI
	local wcopy = wsrc:Clone()
	wcopy.Source = wsrc.Source:gsub("local player = Players%.LocalPlayer", "local player = { Character = nil, CharacterAdded = { Connect = function() end } }")
	wcopy.Name = "WorldUITest"
	wcopy.Parent = wsrc.Parent
	local api = require(wcopy).start(gui, remotes)
	local slots = {}
	for i = 1, 20 do slots[i] = false end
	slots[1] = { id = "wood_axe", n = 1, d = 40 }; slots[2] = { id = "berries", n = 3 }; slots[4] = { id = "wood", n = 12 }
	local state = { coins = 50, sp = 2, xp = 20, level = 1, into = 20, need = 100, slots = slots, bag = false, sel = 1, code = "ABC234", lang = "ar", players = 1, bagPrice = 150, hunger = 80, thirst = 15, temp = 36.2, hp = 70, maxHp = 100, skills = { health = 1, strength = 0, luck = 2, speed = 0, resist = 0, aid = 0 }, night = true, clock = 21 }
	for _, h in ipairs(remotes.State.OnClientEvent.handlers) do h(state) end
	for _, h in ipairs(remotes.Notify.OnClientEvent.handlers) do h("picked", "wood", 3) h("levelUp", 2) end
	local count = 0
	for _ in ipairs(gui:GetDescendants()) do count += 1 end
	assert(count > 60, "descendants=" .. count)
	state.lang = "en"; state.bag = true
	api.bagModal() api.shopModal() api.menuModal() api.skillsModal()
	for _, h in ipairs(remotes.Notify.OnClientEvent.handlers) do h("openShop") h("bossSpawn") h("coinsGot", 12) end
	state.bag = false; for _, h in ipairs(remotes.State.OnClientEvent.handlers) do h(state) end api.bagModal() api.shopModal()
	for _, h in ipairs(remotes.State.OnClientEvent.handlers) do h(state) end
	-- owner with the admin pass, admin not on yet, a moderator in the list
	state.armor = "iron_armor"; state.off = { id = "lantern", n = 1, d = 500 }; state.bag = true
	for _, h in ipairs(remotes.State.OnClientEvent.handlers) do h(state) end
	api.bagModal()
	state.isOwner = true; state.canAdmin = true; state.adminOn = false; state.ownerId = 1; state.mods = { ["2"] = true }
	for _, h in ipairs(remotes.State.OnClientEvent.handlers) do h(state) end
	api.menuModal() api.adminWarnModal()
	state.adminOn = true; state.adminBy = "Owner"; state.isOwner = false; state.isMod = true
	for _, h in ipairs(remotes.State.OnClientEvent.handlers) do h(state) end
	api.menuModal()
	state.dex = { seen = { wolf = true, alpha = true, rabbit = true }, kills = { wolf = 3, alpha = 1 }, medals = { forest = true }, neck = "forest" }
	for _, h in ipairs(remotes.State.OnClientEvent.handlers) do h(state) end
	api.indexModal()
	state.powers = { fire = 2, ice = 0, blast = 1, off = { fire = true } }
	for _, h in ipairs(remotes.State.OnClientEvent.handlers) do h(state) end
	api.skillsModal()
	state.ach = { stats = { kills = 40, level = 12 }, done = { firstKill = true, level10 = true } }; state.boost = 1.2
	for _, h in ipairs(remotes.State.OnClientEvent.handlers) do h(state) end
	api.achModal()
	for _, h in ipairs(remotes.Notify.OnClientEvent.handlers) do h("achieved", "hunter") h("feed", { k = "achieved", a = "Me", b = "hunter" }) end
	for _, h in ipairs(remotes.Notify.OnClientEvent.handlers) do
		h("openFurnace", { id = "f1", input = { id = "meat_raw", n = 3 }, fuel = { id = "wood", n = 12 }, out = false, t = 1.5, time = 3, need = 5 })
		h("furnace", { id = "f1", input = false, fuel = false, out = { id = "meat_cooked", n = 3 }, t = 0, time = 3, need = 5 })
	end
	state.lang = "ar"; for _, h in ipairs(remotes.State.OnClientEvent.handlers) do h(state) end
	api.indexModal()
	for _, h in ipairs(remotes.Notify.OnClientEvent.handlers) do h("feed", { k = "adminOn", a = "Owner" }) h("feed", { k = "modOn", a = "Friend" }) end
end)
check("LobbyUI build", function()
	local src = SSS.Parent.StarterPlayer.StarterPlayerScripts.Client.LobbyUI
	local copy = src:Clone()
	local code = src.Source:gsub("Players%.LocalPlayer%.DisplayName", '"Tester"')
	code = code:gsub("RunService%.RenderStepped:Connect", "RunService.Heartbeat:Connect")
	code = code:gsub("RunService:BindToRenderStep%(", ";(function(...) end)(")
	copy.Source = code
	copy.Name = "LobbyUITest"
	copy.Parent = src.Parent
	local gui = Instance.new("ScreenGui")
	local ret = { ok = true, lang = "ar", lifeXp = 12500, look = { skin = 2, shirt = 1, pants = 1, hat = "explorer", extra = "backpack" },
		rooms = { { code = "ABC234", coins = 80, xp = 500, hours = 70, pct = 42 }, { code = "XYZ789", coins = 5, xp = 10, hours = 20, pct = 7 } }, owned = { { code = "ABC234", maxPlayers = 8, access = "friends", hours = 70, pct = 42 } }, limit = 1, friends = {}, board = { top = { { rank = 1, name = "A", xp = 136200 } }, meRank = nil, meXp = 12500, scanned = 1000 } }
	local remotes = { Lobby = { InvokeServer = function(_, action) return ret end }, Notify = { OnClientEvent = fakeEvent() } }
	local api = require(copy).start(gui, remotes)
	task.wait(1.5)
	api.playPage() api.playPage("friends") api.playPage("room") api.playPage("code", "ABC234")
	api.boardModal() task.wait(1.2) api.roomsModal() api.lookModal() task.wait(1) api.settingsModal() api.storeModal()
	ret.store = { admin = true }; ret.owned[1].admin = true; api.storeModal() api.roomsModal()
	task.wait(0.5)
	local count = 0
	for _ in ipairs(gui:GetDescendants()) do count += 1 end
	assert(count > 40, "descendants=" .. count)
	copy:Destroy()
end)
return results
