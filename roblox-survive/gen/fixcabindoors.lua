-- widens the door of every old log cabin: the two front logs beside the door get shorter on the door side
local n = 0
for _, m in ipairs(workspace.Cabins:GetChildren()) do
	local floor = m:FindFirstChild("Floor")
	if floor and not m:GetAttribute("WideDoor") then
		local base = floor.CFrame * CFrame.new(0, -0.3, 0)
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Log" then
				local rel = base:ToObjectSpace(p.CFrame)
				local pos = rel.Position
				if math.abs(pos.Z - 6) < 0.3 and math.abs(math.abs(pos.X) - 4.5) < 0.3 and math.abs(p.Size.X - 5.4) < 0.2 then
					local side = pos.X > 0 and 1 or -1
					p.Size = Vector3.new(p.Size.X - 0.8, p.Size.Y, p.Size.Z)
					p.CFrame = base * CFrame.new(pos.X + side * 0.4, pos.Y, pos.Z) * (rel - rel.Position)
					n += 1
				end
			end
		end
		m:SetAttribute("WideDoor", true)
	end
end
local ok = pcall(function() game:GetService("AssetService"):SavePlaceAsync() end)
return { saved = ok, logs = n }
