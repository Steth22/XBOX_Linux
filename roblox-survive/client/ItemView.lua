-- Renders an item's real 3D model inside a ViewportFrame.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Items = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Items"))

local ItemView = {}

function ItemView.new(parent, id, size, pos, z)
	local vp = Instance.new("ViewportFrame")
	vp.Size = size or UDim2.fromScale(1, 1)
	vp.Position = pos or UDim2.new()
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(170, 170, 175)
	vp.LightColor = Color3.fromRGB(255, 245, 230)
	vp.LightDirection = Vector3.new(-1, -2, -1)
	vp.ZIndex = z or 3
	vp.Parent = parent
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local m = Items.model(id)
	if m then
		m.Parent = vp
		local cf, sz = m:GetBoundingBox()
		local radius = sz.Magnitude / 2
		local dist = radius / math.tan(math.rad(15)) * 1.02
		local dir = Vector3.new(1, 0.85, 1.25).Unit
		cam.CFrame = CFrame.lookAt(cf.Position + dir * dist, cf.Position)
	end
	return vp
end

return ItemView
