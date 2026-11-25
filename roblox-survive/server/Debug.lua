-- Tiny live-server log saved to a DataStore so problems in real servers can be read back later.
local DataStoreService = game:GetService("DataStoreService")
local Debug = {}
local buffer = {}
local store = DataStoreService:GetDataStore("Debug_v1")

function Debug.log(tag, msg)
	table.insert(buffer, string.format("%s [%s] %s: %s", os.date("!%m-%d %H:%M:%S"), string.sub(game.JobId, 1, 6), tostring(tag), tostring(msg)))
	if #buffer > 40 then table.remove(buffer, 1) end
end

local function flush()
	if #buffer == 0 then return end
	local items = buffer
	buffer = {}
	pcall(function()
		store:UpdateAsync("log", function(old)
			old = type(old) == "table" and old or {}
			for _, l in ipairs(items) do table.insert(old, l) end
			while #old > 120 do table.remove(old, 1) end
			return old
		end)
	end)
end

task.spawn(function()
	while true do
		task.wait(30)
		flush()
	end
end)
game:BindToClose(flush)

return Debug
