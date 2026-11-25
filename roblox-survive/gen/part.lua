local function part(parent, name, size, cf, color, material, shape, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.Parent = parent
	return p
end

