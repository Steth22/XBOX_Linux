-- Powers, unlocked and levelled with tokens (Skills window, "Power" tab):
--   fire  - fire orbits you; creatures that come close are hit, and after a few hits they burn
--   ice   - ice orbits you; creatures that come close are hit, and after a few hits they freeze
--   blast - when luck saves you from death, you explode and hurt everything around you
local Players = game:GetService("Players")

local P = {}
P.KINDS = { "fire", "ice", "blast" }
P.MAX = 5
local ctx, Mobs, Data, Inventory
local hits = {} -- [mob model] = { fire = n, ice = n }
local burning = {} -- [mob model] = { untilT, dps, owner }

-- tokens to go from level (n - 1) to level n
function P.cost(n) return n end

function P.of(room)
	room.powers = type(room.powers) == "table" and room.powers or {}
	local pw = room.powers
	for _, k in ipairs(P.KINDS) do pw[k] = math.clamp(math.floor(tonumber(pw[k]) or 0), 0, P.MAX) end
	pw.off = type(pw.off) == "table" and pw.off or {}
	return pw
end

-- shows the auras on the character (every client draws the orbiting fire / ice)
function P.apply(player)
	local room = Data.room(player)
	local char = player.Character
	if not room or not char then return end
	local pw = P.of(room)
	char:SetAttribute("AuraFire", (pw.fire > 0 and not pw.off.fire) and pw.fire or nil)
	char:SetAttribute("AuraIce", (pw.ice > 0 and not pw.off.ice) and pw.ice or nil)
end

function P.upgrade(player, room, kind)
	if not table.find(P.KINDS, kind) then return end
	local pw = P.of(room)
	if pw[kind] >= P.MAX then return end
	local need = P.cost(pw[kind] + 1)
	if Inventory.count(room.inv, "token") < need then ctx.notify(player, "needTokens", need) return end
	Inventory.remove(room.inv, "token", need)
	pw[kind] += 1
	pw.off[kind] = nil
	ctx.notify(player, pw[kind] == 1 and "powerUnlocked" or "powerUp", "pw_" .. kind)
	if ctx.bump then ctx.bump(player, "powers", 1) end
	if player.Character then ctx.fx("skillUp", player.Character) end
	P.apply(player)
	ctx.push(player)
end

function P.toggle(player, room, kind)
	if kind ~= "fire" and kind ~= "ice" then return end
	local pw = P.of(room)
	if pw[kind] <= 0 then return end
	pw.off[kind] = not pw.off[kind] or nil
	P.apply(player)
	ctx.push(player)
end

-- the last-stand blast: called when luck saves the player
function P.blast(player, room)
	local pw = P.of(room)
	local lvl = pw.blast
	if lvl <= 0 then return false end
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	local radius = 14 + lvl * 2.5
	local dmg = 60 + lvl * 35
	for _, m in ipairs(Mobs.near(hrp.Position, radius)) do
		Mobs.damage(m, dmg, player, { class = "blast" })
	end
	ctx.fx("explode", hrp.Position)
	ctx.notify(player, "blastSaved")
	return true
end

-- extra chance for luck to save you (blast level)
function P.saveChance(room)
	local lvl = P.of(room).blast
	return lvl > 0 and (0.06 + 0.04 * lvl) or 0
end

function P.start(c, mobs, data, inv)
	ctx, Mobs, Data, Inventory = c, mobs, data, inv
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(function()
				local now = os.clock()
				-- the auras hit what comes near
				for _, pl in ipairs(Players:GetPlayers()) do
					local char = pl.Character
					local hrp = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if hrp and hum and hum.Health > 0 then
						for _, kind in ipairs({ "fire", "ice" }) do
							local lvl = char:GetAttribute(kind == "fire" and "AuraFire" or "AuraIce")
							if lvl then
								for _, m in ipairs(Mobs.near(hrp.Position, 7 + lvl)) do
									local h = hits[m] or {}
									hits[m] = h
									h[kind] = (h[kind] or 0) + 1
									Mobs.damage(m, kind == "fire" and (2 + 1.5 * lvl) or (1 + lvl), pl, { class = kind })
									if h[kind] >= 4 then
										h[kind] = 0
										if kind == "fire" then
											burning[m] = { untilT = now + 4, dps = 3 + 2.5 * lvl, owner = pl }
											m:SetAttribute("Burning", true)
										else
											Mobs.freeze(m, 2 + 0.6 * lvl)
										end
									end
								end
							end
						end
					end
				end
				-- burning creatures keep taking damage
				for m, b in pairs(burning) do
					if not m.Parent or now > b.untilT then
						burning[m] = nil
						if m.Parent then m:SetAttribute("Burning", nil) end
					else
						Mobs.damage(m, b.dps * 0.5, b.owner and b.owner.Parent and b.owner or nil, { class = "fire" })
					end
				end
				for m in pairs(hits) do if not m.Parent then hits[m] = nil end end
			end)
			if not ok then warn("powers", err) end
		end
	end)
end

return P
