-- Vector-style icons drawn with plain frames (no emoji, no image assets).
local UI = require(script.Parent:WaitForChild("UI"))

local Icons = {}

local function box(parent, x, y, w, h, color, radius, rot, z)
	local f = UI.frame({
		Size = UDim2.fromScale(w, h), Position = UDim2.fromScale(x, y), AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color, Rotation = rot or 0, ZIndex = z or parent.ZIndex + 1, Parent = parent,
	})
	if radius then
		local c = Instance.new("UICorner")
		c.CornerRadius = radius == "round" and UDim.new(1, 0) or UDim.new(radius, 0)
		c.Parent = f
	end
	return f
end

local function ring(parent, x, y, s, color, th)
	local f = box(parent, x, y, s, s, color, "round")
	f.BackgroundTransparency = 1
	UI.stroke(f, color, th or 2)
	return f
end

local D = {}

function D.play(f, c) box(f, 0.45, 0.33, 0.55, 0.16, c, 1, 35) box(f, 0.45, 0.67, 0.55, 0.16, c, 1, -35) end
function D.ranking(f, c) box(f, 0.2, 0.68, 0.24, 0.45, c, 0.2) box(f, 0.5, 0.55, 0.24, 0.7, c, 0.2) box(f, 0.8, 0.75, 0.24, 0.32, c, 0.2) end
function D.rooms(f, c) box(f, 0.5, 0.42, 0.56, 0.56, c, 0.1, 45) box(f, 0.5, 0.7, 0.62, 0.48, c, 0.12) end
function D.person(f, c) box(f, 0.5, 0.28, 0.4, 0.4, c, "round") box(f, 0.5, 0.8, 0.7, 0.45, c, 0.45) end
function D.look(f, c) D.person(f, c) end
function D.settings(f, c)
	for i = 0, 3 do box(f, 0.5, 0.5, 0.2, 0.95, c, 0.3, i * 45) end
	box(f, 0.5, 0.5, 0.7, 0.7, c, "round")
	local hole = box(f, 0.5, 0.5, 0.3, 0.3, Color3.new(0, 0, 0), "round")
	hole.BackgroundTransparency = 0.6
end
function D.solo(f, c) D.person(f, c) end
function D.quick(f, c) box(f, 0.58, 0.3, 0.2, 0.55, c, 0.3, 25) box(f, 0.42, 0.7, 0.2, 0.55, c, 0.3, 25) box(f, 0.5, 0.5, 0.5, 0.16, c, 0.3, -10) end
function D.friend(f, c)
	box(f, 0.33, 0.3, 0.32, 0.32, c, "round") box(f, 0.33, 0.78, 0.52, 0.42, c, 0.45)
	box(f, 0.7, 0.3, 0.32, 0.32, c, "round") box(f, 0.7, 0.78, 0.52, 0.42, c, 0.45)
end
function D.key(f, c) ring(f, 0.3, 0.5, 0.42, c, 3) box(f, 0.68, 0.5, 0.5, 0.13, c, 0.3) box(f, 0.8, 0.64, 0.1, 0.22, c, 0.3) box(f, 0.66, 0.62, 0.1, 0.16, c, 0.3) end
function D.coin(f, c) box(f, 0.5, 0.5, 0.9, 0.9, c, "round") ring(f, 0.5, 0.5, 0.56, c:Lerp(Color3.new(0, 0, 0), 0.3), 2) end
function D.skill(f, c) box(f, 0.5, 0.5, 0.64, 0.64, c, 0.15, 45) box(f, 0.5, 0.5, 0.28, 0.28, c:Lerp(Color3.new(1, 1, 1), 0.5), 0.2, 45) end
function D.heart(f, c) box(f, 0.33, 0.38, 0.44, 0.44, c, "round") box(f, 0.67, 0.38, 0.44, 0.44, c, "round") box(f, 0.5, 0.58, 0.52, 0.52, c, 0.1, 45) end
function D.drop(f, c) box(f, 0.5, 0.64, 0.62, 0.62, c, "round") box(f, 0.5, 0.42, 0.44, 0.44, c, 0.1, 45) end
function D.food(f, c) box(f, 0.4, 0.42, 0.62, 0.62, c, "round") box(f, 0.7, 0.72, 0.36, 0.14, Color3.fromRGB(240, 232, 214), 1, 45) end
function D.temp(f, c) box(f, 0.5, 0.4, 0.24, 0.66, c, 1) box(f, 0.5, 0.75, 0.42, 0.42, c, "round") end
function D.bag(f, c)
	ring(f, 0.5, 0.3, 0.42, c, 3)
	box(f, 0.5, 0.64, 0.78, 0.6, c, 0.25)
	box(f, 0.5, 0.56, 0.78, 0.07, c:Lerp(Color3.new(0, 0, 0), 0.35), 0)
end
function D.backpack(f, c)
	local dark = c:Lerp(Color3.new(0, 0, 0), 0.35)
	box(f, 0.5, 0.58, 0.7, 0.78, c, 0.3)
	box(f, 0.5, 0.36, 0.72, 0.3, dark, 0.35)
	box(f, 0.5, 0.74, 0.42, 0.26, dark, 0.25)
	ring(f, 0.5, 0.14, 0.3, c, 2.5)
end
function D.flame(f, c)
	box(f, 0.5, 0.64, 0.62, 0.62, c, "round")
	box(f, 0.5, 0.44, 0.44, 0.44, c, 0.1, 45)
	box(f, 0.5, 0.66, 0.28, 0.28, c:Lerp(Color3.new(1, 1, 0.6), 0.6), "round")
end
function D.snow(f, c)
	for i = 0, 2 do box(f, 0.5, 0.5, 0.95, 0.13, c, 1, i * 60) end
	box(f, 0.5, 0.5, 0.26, 0.26, c, "round")
end
function D.shield(f, c)
	box(f, 0.5, 0.36, 0.72, 0.5, c, 0.2)
	box(f, 0.5, 0.58, 0.52, 0.52, c, 0.12, 45)
	box(f, 0.5, 0.42, 0.08, 0.5, c:Lerp(Color3.new(1, 1, 1), 0.4), 1)
end
function D.menu(f, c) for i = 0, 2 do box(f, 0.5, 0.25 + i * 0.25, 0.8, 0.13, c, 1) end end
function D.close(f, c) box(f, 0.5, 0.5, 0.9, 0.13, c, 1, 45) box(f, 0.5, 0.5, 0.9, 0.13, c, 1, -45) end
function D.plus(f, c) box(f, 0.5, 0.5, 0.8, 0.16, c, 1) box(f, 0.5, 0.5, 0.16, 0.8, c, 1) end
function D.lock(f, c) ring(f, 0.5, 0.35, 0.44, c, 3) box(f, 0.5, 0.66, 0.7, 0.5, c, 0.2) end
function D.trash(f, c) box(f, 0.5, 0.22, 0.8, 0.1, c, 1) box(f, 0.5, 0.62, 0.6, 0.66, c, 0.15) end
function D.sun(f, c) for i = 0, 3 do box(f, 0.5, 0.5, 0.1, 0.95, c, 1, i * 45) end box(f, 0.5, 0.5, 0.55, 0.55, c, "round") end
function D.moon(f, c, bg) box(f, 0.5, 0.5, 0.8, 0.8, c, "round") local cut = box(f, 0.7, 0.36, 0.66, 0.66, bg or Color3.fromRGB(24, 36, 32), "round") end
function D.home(f, c) D.rooms(f, c) end
function D.xp(f, c) D.skill(f, c) end

-- returns the icon frame
function Icons.draw(name, parent, size, color, pos, anchor, bg)
	local f = UI.frame({
		Name = "Icon", Size = typeof(size) == "UDim2" and size or UDim2.fromOffset(size, size),
		Position = pos or UDim2.new(), AnchorPoint = anchor or Vector2.new(), BackgroundTransparency = 1,
		ZIndex = (parent:IsA("GuiObject") and parent.ZIndex or 1) + 1, Parent = parent,
	})
	local fn = D[name]
	if fn then fn(f, color or UI.c.text, bg) end
	return f
end

return Icons
