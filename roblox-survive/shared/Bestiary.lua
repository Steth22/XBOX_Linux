-- Every creature, the region lists shown in the index, and what each medal needs.
-- type: peaceful | predator | night | cave | boss | outlaw
local Best = {}

Best.types = { "peaceful", "predator", "night", "cave", "boss", "outlaw" }

Best.kinds = {
	rabbit = "peaceful", deer = "peaceful", boar = "predator", wolf = "predator", bear = "predator", fox = "predator",
	zombie = "night", spider = "night", alpha = "boss",
	ram = "predator",
	hare = "peaceful", snowwolf = "predator", polarbear = "predator", mammoth = "predator", yeti = "boss",
	camel = "peaceful", scorpion = "predator", hyena = "predator", scorpionking = "boss",
	goat = "peaceful", puma = "predator", guardian = "boss",
	turtle = "peaceful", crab = "predator", crabking = "boss",
	monkey = "peaceful", tiger = "predator", snake = "predator", gorilla = "boss",
	lavalizard = "predator", ashwolf = "predator", magma = "boss",
	bat = "cave", crawler = "cave", ghoul = "cave", golem = "boss",
	spiderqueen = "boss", giantworm = "boss", mineguardian = "boss",
	bandit = "outlaw", banditlord = "boss",
}

-- regions (tabs in the index); a medal needs one kill of every creature listed
Best.regions = {
	{ key = "forest", kinds = { "rabbit", "deer", "fox", "boar", "wolf", "bear", "zombie", "spider", "alpha" } },
	{ key = "hills", kinds = { "deer", "boar", "ram", "wolf", "bear", "zombie", "spider" } },
	{ key = "snow", kinds = { "hare", "snowwolf", "polarbear", "mammoth", "zombie", "yeti" } },
	{ key = "desert", kinds = { "camel", "scorpion", "hyena", "spider", "scorpionking" } },
	{ key = "mountains", kinds = { "goat", "wolf", "bear", "puma", "zombie", "guardian" } },
	{ key = "beach", kinds = { "turtle", "crab", "zombie", "crabking" } },
	{ key = "jungle", kinds = { "monkey", "snake", "tiger", "spider", "gorilla" } },
	{ key = "volcano", kinds = { "lavalizard", "ashwolf", "zombie", "magma" } },
	{ key = "caves", kinds = { "bat", "crawler", "ghoul", "golem", "spiderqueen", "giantworm", "mineguardian" } },
	{ key = "bandits", kinds = { "bandit", "banditlord" } },
}

function Best.region(key)
	for _, r in ipairs(Best.regions) do
		if r.key == key then return r end
	end
	return nil
end

-- regions whose medal is now complete (given the kills table)
function Best.completed(kills)
	local out = {}
	for _, r in ipairs(Best.regions) do
		local all = true
		for _, k in ipairs(r.kinds) do
			if not kills[k] or kills[k] < 1 then all = false break end
		end
		if all then table.insert(out, r.key) end
	end
	return out
end

function Best.total()
	local n = 0
	for _ in pairs(Best.kinds) do n += 1 end
	return n
end

return Best
