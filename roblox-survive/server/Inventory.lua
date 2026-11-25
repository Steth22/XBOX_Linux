-- Pure inventory logic. Slots 1..HOTBAR are the hotbar, the rest are the bag (needs `bag = true`).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)

local Inv = {}
local TOTAL = Config.HOTBAR + Config.BAG

function Inv.new()
	local slots = {}
	for i = 1, TOTAL do
		slots[i] = false
	end
	return { slots = slots, bag = false, armor = false }
end

-- sanitize data loaded from DataStore
function Inv.fix(inv)
	if type(inv) ~= "table" or type(inv.slots) ~= "table" then
		return Inv.new()
	end
	local s = {}
	for i = 1, TOTAL do
		local v = inv.slots[i]
		if type(v) == "table" and Items.get(v.id) and type(v.n) == "number" and v.n >= 1 then
			s[i] = { id = v.id, n = math.min(math.floor(v.n), Items.stack(v.id)) }
			local dur = Items.get(v.id).dur
			if dur then s[i].d = math.clamp(tonumber(v.d) or dur, 1, dur) end
		else
			s[i] = false
		end
	end
	local armor = false
	if type(inv.armor) == "string" then
		local d = Items.get(inv.armor)
		if d and d.kind == "armor" then armor = inv.armor end
	end
	return { slots = s, bag = inv.bag == true, armor = armor }
end

function Inv.usable(inv, i)
	if type(i) ~= "number" or i ~= math.floor(i) or i < 1 or i > TOTAL then
		return false
	end
	return i <= Config.HOTBAR or inv.bag == true
end

local function limit(inv)
	return inv.bag and TOTAL or Config.HOTBAR
end

-- how many more of `id` fit
function Inv.space(inv, id)
	local max = Items.stack(id)
	local free = 0
	for i = 1, limit(inv) do
		local s = inv.slots[i]
		if not s then
			free += max
		elseif s.id == id then
			free += max - s.n
		end
	end
	return free
end

-- returns leftover that did not fit. `d` = durability for a single tool (defaults to full)
function Inv.add(inv, id, n, d)
	local def = Items.get(id)
	if not def then return n end
	local max = Items.stack(id)
	for i = 1, limit(inv) do
		local s = inv.slots[i]
		if n > 0 and s and s.id == id and s.n < max then
			local put = math.min(n, max - s.n)
			s.n += put
			n -= put
		end
	end
	for i = 1, limit(inv) do
		if n > 0 and not inv.slots[i] then
			local put = math.min(n, max)
			inv.slots[i] = { id = id, n = put }
			if def.dur then inv.slots[i].d = d or def.dur end
			n -= put
		end
	end
	return n
end

function Inv.count(inv, id)
	local c = 0
	for i = 1, TOTAL do
		local s = inv.slots[i]
		if s and s.id == id then c += s.n end
	end
	return c
end

function Inv.remove(inv, id, n)
	if Inv.count(inv, id) < n then return false end
	for i = TOTAL, 1, -1 do
		local s = inv.slots[i]
		if n > 0 and s and s.id == id then
			local take = math.min(n, s.n)
			s.n -= take
			n -= take
			if s.n <= 0 then inv.slots[i] = false end
		end
	end
	return true
end

function Inv.removeSlot(inv, i, n)
	local s = inv.slots[i]
	if not s then return false end
	n = n or s.n
	if n > s.n then return false end
	s.n -= n
	if s.n <= 0 then inv.slots[i] = false end
	return true
end

function Inv.move(inv, a, b)
	if a == b or not Inv.usable(inv, a) or not Inv.usable(inv, b) then return false end
	local sa, sb = inv.slots[a], inv.slots[b]
	if not sa then return false end
	if sb and sb.id == sa.id and Items.stack(sa.id) > 1 then
		local put = math.min(sa.n, Items.stack(sa.id) - sb.n)
		sb.n += put
		sa.n -= put
		if sa.n <= 0 then inv.slots[a] = false end
		return true
	end
	inv.slots[a], inv.slots[b] = sb, sa
	return true
end

---------------------------------------------------------------- personal storage
local STASH_LIMIT = Config.STASH_BASE + Config.STASH_STEP * (Config.STASH_MAX_LVL - 1)

function Inv.newStash()
	return { slots = {}, lvl = 1 }
end

function Inv.fixStash(st)
	local out = Inv.newStash()
	if type(st) ~= "table" then return out end
	out.lvl = math.clamp(math.floor(tonumber(st.lvl) or 1), 1, Config.STASH_MAX_LVL)
	if type(st.slots) == "table" then
		for i = 1, STASH_LIMIT do
			local v = st.slots[i]
			if type(v) == "table" and Items.get(v.id) and type(v.n) == "number" and v.n >= 1 then
				out.slots[i] = { id = v.id, n = math.min(math.floor(v.n), Items.stack(v.id)), d = tonumber(v.d) }
			else
				out.slots[i] = false
			end
		end
	end
	return out
end

function Inv.stashCap(st)
	return Config.STASH_BASE + Config.STASH_STEP * (st.lvl - 1)
end

-- puts a whole stack into storage, returns how many were stored
function Inv.stashPut(st, it)
	local cap = Inv.stashCap(st)
	local max = Items.stack(it.id)
	local n = it.n
	if not it.d then
		for i = 1, cap do
			local s = st.slots[i]
			if n > 0 and s and s.id == it.id and s.n < max then
				local put = math.min(n, max - s.n)
				s.n += put
				n -= put
			end
		end
	end
	for i = 1, cap do
		if n > 0 and not st.slots[i] then
			local put = math.min(n, max)
			st.slots[i] = { id = it.id, n = put, d = it.d }
			n -= put
		end
	end
	return it.n - n
end

function Inv.stashView(st)
	local out = {}
	for i = 1, Inv.stashCap(st) do
		local s = st.slots[i]
		out[i] = s and { id = s.id, n = s.n, d = s.d } or false
	end
	return out
end

-- removes and returns every item (used when the player dies)
function Inv.takeAll(inv)
	local out = {}
	for i = 1, TOTAL do
		local s = inv.slots[i]
		if s then
			table.insert(out, { id = s.id, n = s.n, d = s.d })
			inv.slots[i] = false
		end
	end
	return out
end

-- value sent to the client
function Inv.view(inv)
	local out = {}
	for i = 1, TOTAL do
		local s = inv.slots[i]
		out[i] = s and { id = s.id, n = s.n, d = s.d } or false
	end
	return out
end

return Inv
