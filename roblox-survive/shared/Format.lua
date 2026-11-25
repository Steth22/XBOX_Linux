local F = {}

-- 1088 -> "1088", 10900 -> "10.9K", 136200 -> "136.2K", 1100000 -> "1.1M"
function F.number(n)
	n = math.floor(tonumber(n) or 0)
	if n < 0 then n = 0 end
	if n < 10000 then
		return tostring(n)
	end
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in ipairs(units) do
		if n >= u[1] then
			local v = math.floor(n / u[1] * 10) / 10
			local s = string.format("%.1f", v)
			s = s:gsub("%.0$", "")
			return s .. u[2]
		end
	end
	return tostring(n)
end

-- rank text: exact number, or "+1K" when beyond the scanned range
function F.rank(rank, scanned)
	if rank then
		return F.number(rank)
	end
	scanned = scanned or 1000
	if scanned >= 1000 then
		return "+" .. tostring(math.floor(scanned / 1000)) .. "K"
	end
	return "+" .. tostring(scanned)
end

return F
