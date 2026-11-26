import json, os, re, sys
from rbx import run
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo layout: shared/ server/ client/ next to tools/

# (path in game, class, source file)
FILES = [
 ("ReplicatedStorage/Shared/Config","ModuleScript","shared/Config.lua"),
 ("ReplicatedStorage/Shared/Format","ModuleScript","shared/Format.lua"),
 ("ReplicatedStorage/Shared/Locale","ModuleScript","shared/Locale.lua"),
 ("ReplicatedStorage/Shared/Items","ModuleScript","shared/Items.lua"),
 ("ReplicatedStorage/Shared/Appearance","ModuleScript","shared/Appearance.lua"),
 ("ReplicatedStorage/Shared/Sounds","ModuleScript","shared/Sounds.lua"),
 ("ReplicatedStorage/Shared/Biomes","ModuleScript","shared/Biomes.lua"),
 ("ReplicatedStorage/Shared/Bestiary","ModuleScript","shared/Bestiary.lua"),
 ("ServerScriptService/Services/Inventory","ModuleScript","server/Inventory.lua"),
 ("ServerScriptService/Services/Data","ModuleScript","server/Data.lua"),
 ("ServerScriptService/Services/Rooms","ModuleScript","server/Rooms.lua"),
 ("ServerScriptService/Services/Resources","ModuleScript","server/Resources.lua"),
 ("ServerScriptService/Services/Lobby","ModuleScript","server/Lobby.lua"),
 ("ServerScriptService/Services/Debug","ModuleScript","server/Debug.lua"),
 ("ServerScriptService/Services/Ground","ModuleScript","server/Ground.lua"),
 ("ServerScriptService/Services/TerrainFix","ModuleScript","server/TerrainFix.lua"),
 ("ServerScriptService/Services/Mobs","ModuleScript","server/Mobs.lua"),
 ("ServerScriptService/Services/Loot","ModuleScript","server/Loot.lua"),
 ("ServerScriptService/Services/Survival","ModuleScript","server/Survival.lua"),
 ("ServerScriptService/Services/Villages","ModuleScript","server/Villages.lua"),
 ("ServerScriptService/Services/Underground","ModuleScript","server/Underground.lua"),
 ("ServerScriptService/Services/Furnace","ModuleScript","server/Furnace.lua"),
 ("ServerScriptService/Services/Weather","ModuleScript","server/Weather.lua"),
 ("ServerScriptService/Services/World","ModuleScript","server/World.lua"),
 ("ServerScriptService/Main","Script","server/Main.server.lua"),
 ("StarterPlayer/StarterPlayerScripts/Client","LocalScript","client/Client.client.lua"),
 ("StarterPlayer/StarterPlayerScripts/Client/UI","ModuleScript","client/UI.lua"),
 ("StarterPlayer/StarterPlayerScripts/Client/Icons","ModuleScript","client/Icons.lua"),
 ("StarterPlayer/StarterPlayerScripts/Client/ItemView","ModuleScript","client/ItemView.lua"),
 ("StarterPlayer/StarterPlayerScripts/Client/Effects","ModuleScript","client/Effects.lua"),
 ("StarterPlayer/StarterPlayerScripts/Client/LobbyUI","ModuleScript","client/LobbyUI.lua"),
 ("StarterPlayer/StarterPlayerScripts/Client/WorldUI","ModuleScript","client/WorldUI.lua"),
]

def longstr(src):
    n = 0
    while ("]" + "=" * n + "]") in src:
        n += 1
    return "[" + "=" * n + "[\n" + src + "]" + "=" * n + "]"

def build(save=True):
    parts = ["local files = {"]
    for path, cls, f in FILES:
        src = open(os.path.join(ROOT, f), encoding="utf-8").read()
        parts.append("{%s, %s, %s}," % (json.dumps(path), json.dumps(cls), longstr(src)))
    parts.append("}")
    parts.append('''
local function ensure(parent, name, className)
	local c = parent:FindFirstChild(name)
	if c and c.ClassName ~= className and className ~= "Folder" then c:Destroy(); c = nil end
	if not c then
		c = Instance.new(className)
		c.Name = name
		c.Parent = parent
	end
	return c
end
for _, f in ipairs(files) do
	local segs = string.split(f[1], "/")
	local cur = game:GetService(segs[1])
	for i = 2, #segs - 1 do
		local nxt = cur:FindFirstChild(segs[i])
		if not nxt then nxt = Instance.new("Folder"); nxt.Name = segs[i]; nxt.Parent = cur end
		cur = nxt
	end
	local s = ensure(cur, segs[#segs], f[2])
	s.Source = f[3]
end
local sp = game:GetService("StarterPlayer")
pcall(function() sp.LoadCharacterAppearance = false end)
pcall(function() sp.GameSettingsAvatar = Enum.GameAvatarType.R15 end)
pcall(function() workspace.StreamingEnabled = true end)
local out = {}
out.maxPlayers = pcall(function() game:GetService("Players").MaxPlayers = 16 end)
''')
    if save:
        parts.append('game:GetService("AssetService"):SavePlaceAsync()')
    parts.append('return { scripts = #files, saved = %s, maxPlayers = out.maxPlayers }' % ("true" if save else "false"))
    return "\n".join(parts)

if __name__ == "__main__":
    save = "--nosave" not in sys.argv
    src = build(save)
    print("script bytes:", len(src))
    r = run(src)
    r.pop("path", None)
    print(json.dumps(r, ensure_ascii=False, indent=1)[:3000])
