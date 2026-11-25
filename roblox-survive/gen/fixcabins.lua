-- Lifts every cabin onto a level dirt pad (no grass growing through the floor) and clears terrain inside it.
local T = workspace.Terrain
local fixed, raised = 0, 0
for _, m in ipairs(workspace.Cabins:GetChildren()) do
	local floor = m:FindFirstChild("Floor")
	if floor then
		local W, D = floor.Size.X, floor.Size.Z
		local gMin, gMax = math.huge, -math.huge
		for _, ox in ipairs({ -W / 2 - 1.5, 0, W / 2 + 1.5 }) do
			for _, oz in ipairs({ -D / 2 - 1.5, 0, D / 2 + 3 }) do
				local p = (floor.CFrame * CFrame.new(ox, 0, oz)).Position
				local g = ground(p.X, p.Z)
				gMin, gMax = math.min(gMin, g), math.max(gMax, g)
			end
		end
		local base = floor.Position.Y - floor.Size.Y / 2
		local want = gMax + 0.35
		if want > base then
			m:PivotTo(m:GetPivot() + Vector3.new(0, want - base, 0))
			raised += 1
			base = want
		end
		local rot = floor.CFrame - floor.CFrame.Position
		local c = floor.Position
		local bottom = gMin - 6
		T:FillBlock(CFrame.new(c.X, (bottom + base - 0.3) / 2, c.Z) * rot * CFrame.new(0, 0, 1), Vector3.new(W + 5, base - 0.3 - bottom, D + 7), Enum.Material.Ground)
		T:FillBlock(CFrame.new(c.X, base + 15, c.Z) * rot * CFrame.new(0, 0, 1), Vector3.new(W + 3, 30, D + 5), Enum.Material.Air)
		fixed += 1
	end
end
local ok = pcall(function() game:GetService("AssetService"):SavePlaceAsync() end)
return { saved = ok, cabins = fixed, raised = raised }
