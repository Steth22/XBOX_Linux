-- Bootstrap: creates remotes, then starts either the lobby or the world.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = script.Parent:WaitForChild("Services")

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, n in ipairs({ "Lobby", "World" }) do
	local f = Instance.new("RemoteFunction")
	f.Name = n
	f.Parent = remotes
end
for _, n in ipairs({ "State", "Notify", "Fx" }) do
	local e = Instance.new("RemoteEvent")
	e.Name = n
	e.Parent = remotes
end

local isWorld = game.PrivateServerId ~= ""
local RunService = game:GetService("RunService")
if RunService:IsStudio() and script.Parent:GetAttribute("ForceWorld") then
	isWorld = true
end

local mode = Instance.new("StringValue")
mode.Name = "Mode"
mode.Value = isWorld and "world" or "lobby"
mode.Parent = ReplicatedStorage
remotes.Parent = ReplicatedStorage

local Data = require(Services.Data)
Data.start()

if isWorld then
	require(Services.World).start(remotes)
else
	game:GetService("Players").CharacterAutoLoads = false
	require(Services.Lobby).start(remotes)
end
