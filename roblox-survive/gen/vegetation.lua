-- vegetation + ores for every region (structures must exist already: their areas are kept clear)
local resources = workspace:FindFirstChild("Resources") or Instance.new("Folder")
resources.Name = "Resources"; resources.Parent = workspace
local decor = workspace:FindFirstChild("Decor") or Instance.new("Folder")
decor.Name = "Decor"; decor.Parent = workspace
for _, c in ipairs(resources:GetChildren()) do
	if c.Name ~= "Ore_gold" and c.Name ~= "Ore_diamond" and c.Name ~= "Ore_iron" then c:Destroy() end
end
decor:ClearAllChildren()
local zones = { { 0, 0, 34 } }
local function addZone(model, r)
	local ok, p = pcall(function() return model:GetPivot().Position end)
	if ok then table.insert(zones, { p.X, p.Z, r }) end
end
if workspace:FindFirstChild("Camp") then addZone(workspace.Camp, 34) end
for _, f in ipairs({ { "Cabins", 18 }, { "Outposts", 36 } }) do
	local folder = workspace:FindFirstChild(f[1])
	if folder then for _, m in ipairs(folder:GetChildren()) do addZone(m, f[2]) end end
end
if workspace:FindFirstChild("Caves") then
	for _, m in ipairs(workspace.Caves:GetChildren()) do
		local e = m:GetAttribute("Entry")
		if e then table.insert(zones, { e.X, e.Z, 18 }) end
	end
end
local function blocked(x, z)
	for _, zn in ipairs(zones) do
		if (x - zn[1]) ^ 2 + (z - zn[2]) ^ 2 < zn[3] ^ 2 then return true end
	end
	return false
end
