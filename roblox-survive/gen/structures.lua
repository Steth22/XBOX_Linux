-- camp + market, cabins, caves, region outposts, world walls, spawn
local Appearance = require(game:GetService("ReplicatedStorage").Shared.Appearance)
local Items = require(game:GetService("ReplicatedStorage").Shared.Items)
for _, n in ipairs({ "Resources", "Decor", "MapWalls", "ForestSpawn", "Camp", "Cabins", "Caves", "Outposts" }) do
	local o = workspace:FindFirstChild(n)
	if o then o:Destroy() end
end
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local zones = {}
local resources = Instance.new("Folder"); resources.Name = "Resources"; resources.Parent = workspace
local decor = Instance.new("Folder"); decor.Name = "Decor"; decor.Parent = workspace
