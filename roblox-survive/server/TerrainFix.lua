-- Terrain saved from build sessions has no collision data on the server (raycasts miss, ragdolls fall through).
-- Clearing a chunk and writing the same voxels back makes the engine rebuild its collision. Done once per server,
-- nearest chunks to the spawn first, spread over time so the server stays smooth.
local Debug = require(script.Parent.Debug)
local TerrainFix = {}

function TerrainFix.run(half, onDone)
	task.spawn(function()
		local T = workspace.Terrain
		local CH = 64
		local chunks = {}
		for x = -half, half - CH, CH do
			for z = -half, half - CH, CH do
				table.insert(chunks, Vector2.new(x, z))
			end
		end
		table.sort(chunks, function(a, b)
			return (a + Vector2.new(CH / 2, CH / 2)).Magnitude < (b + Vector2.new(CH / 2, CH / 2)).Magnitude
		end)
		local t0 = os.clock()
		local done = 0
		for i, c in ipairs(chunks) do
			local ok, err = pcall(function()
				local region = Region3.new(Vector3.new(c.X, -64, c.Y), Vector3.new(c.X + CH, 216, c.Y + CH)):ExpandToGrid(4)
				local m, o = T:ReadVoxels(region, 4)
				T:FillRegion(region, 4, Enum.Material.Air)
				T:WriteVoxels(region, 4, m, o)
			end)
			if ok then done += 1 elseif i == 1 then Debug.log("terrainfix", err) end
			if i % 4 == 0 then task.wait() end
		end
		Debug.log("terrainfix", string.format("rebuilt %d/%d chunks in %.1fs", done, #chunks, os.clock() - t0))
		if onDone then onDone() end
	end)
end

return TerrainFix
