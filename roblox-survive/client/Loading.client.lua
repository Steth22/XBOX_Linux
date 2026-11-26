-- Runs first: shows the loading screen until the lobby or the room's world is really ready, then tells
-- the server (which lifts the long spawn shield to a short one).
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ContentProvider = game:GetService("ContentProvider")

pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)
local player = Players.LocalPlayer
local Screen = require(script:WaitForChild("Screen"))
-- the language the player picked (the server puts it on the player); until it arrives, guess from Roblox's
local function guess() return string.sub(string.lower(player.LocaleId or ""), 1, 2) == "ar" and "ar" or "en" end
local ui = Screen.build(player:GetAttribute("Lang") or guess())
player:GetAttributeChangedSignal("Lang"):Connect(function() ui.setLang(player:GetAttribute("Lang")) end)
ui.gui.Parent = player:WaitForChild("PlayerGui")
-- the screen shown during the teleport can go now that ours covers it
pcall(function()
	local arriving = TeleportService:GetArrivingTeleportGui()
	if arriving then arriving:Destroy() end
end)

ui.set(0.08, "loading")
if not game:IsLoaded() then game.Loaded:Wait() end
ui.set(0.3, "ready")
local RS = game:GetService("ReplicatedStorage")
local mode = RS:WaitForChild("Mode", 30)
local isWorld = mode and mode.Value == "world"

local function waitFor(check, timeout)
	local t0 = os.clock()
	while not check() and os.clock() - t0 < timeout do task.wait(0.2) end
end

if isWorld then
	ui.set(0.4, "world")
	waitFor(function() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end, 60)
	ui.set(0.55, "ground")
	waitFor(function() return workspace:GetAttribute("TerrainReady") == true end, 60)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		ui.set(0.7, "around")
		pcall(function() player:RequestStreamAroundAsync(hrp.Position, 20) end)
		-- solid ground under the feet
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character }
		waitFor(function()
			local h = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			return h and workspace:Raycast(h.Position, Vector3.new(0, -40, 0), params) ~= nil
		end, 15)
	end
	ui.set(0.85, "finish")
	pcall(function()
		ContentProvider:PreloadAsync({ "rbxassetid://136820448039676", "rbxassetid://96932926831657" })
	end)
	ui.set(1)
	ui.close()
	-- we're in: the server swaps the long shield for a 5 second one
	local remotes = RS:WaitForChild("Remotes", 10)
	local world = remotes and remotes:FindFirstChild("World")
	if world then pcall(function() world:InvokeServer("ready") end) end
else
	ui.set(0.5, "menu")
	waitFor(function() return workspace:FindFirstChild("LobbyScene") ~= nil end, 30)
	pcall(function()
		ContentProvider:PreloadAsync({ "rbxassetid://136820448039676" })
	end)
	ui.set(0.9)
	task.wait(0.6)
	ui.close()
end
