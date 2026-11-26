local C = {}
C.HOTBAR = 5
C.BAG = 15
C.BAG_PRICE = 150
C.MAX_PLAYERS = 16
C.ROOM_TTL = 72 * 3600
C.START_COINS = 50
C.START_ITEMS = { { "wood_axe", 1 }, { "berries", 4 } }
C.CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
C.CODE_LEN = 6
C.LB_SIZE = 10
C.RANK_SCAN = 1000
C.SKILLS = { "health", "strength", "luck", "speed", "resist", "aid" }
C.SKILL_MAX = 10 -- kept for old saves
C.SKILL_CAP = { speed = 10, resist = 14 } -- skills not listed here have no limit
C.DAY_LENGTH = 20 * 60 -- seconds for a full day/night
C.VENDOR_RANGE = 24
C.BAG_OWNER_TIME = 300 -- dropped items belong to their owner for this long
C.BAG_LIFETIME = 900
C.BASE_ROOMS = 1 -- rooms a player may own
C.EXTRA_ROOMS = 2 -- extra rooms from the game pass
C.EXTRA_ROOMS_PASS = 2101924888 -- "+2 Rooms" game pass (30 Robux)
C.ADMIN_PASS = 2099748271 -- "Admin" game pass (250 Robux): admin tools in rooms you own
C.ROOM_ACCESS = { "public", "friends", "request" }
C.SKILL_DROP_CHANCE = 0.01
C.STASH_BASE = 10 -- storage slots at level 1
C.STASH_STEP = 10 -- extra slots per upgrade
C.STASH_MAX_LVL = 6
C.MAP_CELLS = 48
C.ADMINS = { [4402005457] = true } -- accounts with the admin tools -- the world map is a 48 x 48 grid of cells that get revealed as you explore
function C.stashCost(lvl) -- price to go from lvl to lvl + 1
	return math.floor(150 * lvl ^ 1.6 / 10) * 10
end

-- XP needed to go from level l to l+1
function C.xpForLevel(l)
	return 100 + (l - 1) * 60
end

-- returns level, xp inside level, xp needed for next level
function C.levelFromXp(xp)
	local l = 1
	local need = C.xpForLevel(l)
	while xp >= need do
		xp -= need
		l += 1
		need = C.xpForLevel(l)
	end
	return l, xp, need
end

return C
