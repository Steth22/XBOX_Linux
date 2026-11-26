-- Achievements (kept with the player's profile, across every room). Each one watches a counter;
-- reaching the goal unlocks it and gives a reward in the room you are playing.
local A = {}

-- key, counter, goal, reward { coins = n } or { token = n }, icon
A.list = {
	{ key = "firstKill", stat = "kills", goal = 1, reward = { coins = 50 }, icon = "heart" },
	{ key = "hunter", stat = "kills", goal = 100, reward = { coins = 500 }, icon = "heart" },
	{ key = "slayer", stat = "kills", goal = 1000, reward = { token = 1 }, icon = "heart" },
	{ key = "bossOne", stat = "bosses", goal = 1, reward = { coins = 300 }, icon = "shield" },
	{ key = "bossTen", stat = "bosses", goal = 10, reward = { token = 2 }, icon = "shield" },
	{ key = "medalOne", stat = "medals", goal = 1, reward = { coins = 300 }, icon = "medal" },
	{ key = "medalAll", stat = "medals", goal = 10, reward = { token = 3 }, icon = "medal" },
	{ key = "dexHalf", stat = "discovered", goal = 20, reward = { coins = 300 }, icon = "book" },
	{ key = "dexAll", stat = "discovered", goal = 41, reward = { token = 2 }, icon = "book" },
	{ key = "caves", stat = "caves", goal = 1, reward = { coins = 100 }, icon = "cave" },
	{ key = "dwarf", stat = "dwarfSales", goal = 1, reward = { coins = 150 }, icon = "coin" },
	{ key = "lumber", stat = "trees", goal = 200, reward = { coins = 300 }, icon = "drop" },
	{ key = "miner", stat = "rocks", goal = 150, reward = { coins = 300 }, icon = "cave" },
	{ key = "chef", stat = "cooked", goal = 50, reward = { coins = 250 }, icon = "flame" },
	{ key = "level10", stat = "level", goal = 10, reward = { coins = 200 }, icon = "skill" },
	{ key = "level30", stat = "level", goal = 30, reward = { coins = 1000 }, icon = "skill" },
	{ key = "level60", stat = "level", goal = 60, reward = { token = 2 }, icon = "skill" },
	{ key = "firstToken", stat = "tokens", goal = 1, reward = { coins = 150 }, icon = "coin" },
	{ key = "power", stat = "powers", goal = 1, reward = { coins = 300 }, icon = "flame" },
	{ key = "tornado", stat = "tornado", goal = 1, reward = { coins = 300 }, icon = "snow" },
	{ key = "friends", stat = "party", goal = 3, reward = { coins = 200 }, icon = "friend" },
	{ key = "rich", stat = "coins", goal = 10000, reward = { coins = 500 }, icon = "coin" },
}

-- counters that keep the highest value seen instead of adding up
A.highest = { level = true, discovered = true, medals = true, party = true, coins = true, caves = true }

return A
