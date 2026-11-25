-- Picks the lobby or world screens depending on the server mode.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local mode = ReplicatedStorage:WaitForChild("Mode")

local gui = Instance.new("ScreenGui")
gui.Name = "GameUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

task.spawn(function()
	local ok, err = pcall(function() require(script:WaitForChild("Effects")).start(remotes) end)
	if not ok then warn("Effects:", err) end
end)

if mode.Value == "world" then
	require(script:WaitForChild("WorldUI")).start(gui, remotes)
else
	require(script:WaitForChild("LobbyUI")).start(gui, remotes)
end
