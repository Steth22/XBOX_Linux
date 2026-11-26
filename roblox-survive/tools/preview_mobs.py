# Builds every creature with the local server/Mobs.lua inside Roblox, exports the parts, renders a contact sheet.
#   python3 preview_mobs.py out.png [kind1,kind2,...]
import json, os, sys, subprocess
from rbx import run
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = open(os.path.join(HERE, "..", "server", "Mobs.lua"), encoding="utf-8").read()
def longstr(src):
    n = 0
    while ("]" + "=" * n + "]") in src: n += 1
    return "[" + "=" * n + "[\n" + src + "]" + "=" * n + "]"
lua = """
local SSS = game:GetService("ServerScriptService")
local ms = Instance.new("ModuleScript")
ms.Name = "MobsPreview"
ms.Source = %s
ms.Parent = SSS.Services
local M = require(ms)
local Best = require(game:GetService("ReplicatedStorage").Shared.Bestiary)
local kinds = {}
for k in pairs(Best.kinds) do table.insert(kinds, k) end
table.sort(kinds)
local out = {}
for _, k in ipairs(kinds) do
	local ok, m = pcall(M.spawn, k, Vector3.new(0, 500, 0), 1)
	if ok and m then
		local h = m.PrimaryPart
		local parts = {}
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local rel = h.CFrame:ToObjectSpace(p.CFrame)
				table.insert(parts, { s = { p.Size.X, p.Size.Y, p.Size.Z }, c = { rel:GetComponents() }, col = { p.Color.R, p.Color.G, p.Color.B }, m = p.Material.Name, sh = p:IsA("Part") and p.Shape.Name or "Block", t = p.Transparency })
			end
		end
		table.insert(out, { id = k, name = "", parts = parts })
		m:Destroy()
	else
		table.insert(out, { id = k .. " ERROR " .. tostring(m), name = "", parts = {} })
	end
end
ms:Destroy()
return game:GetService("HttpService"):JSONEncode(out)
""" % longstr(SRC)
r = run(lua, timeout=200)
data = (r.get("output") or {}).get("results", [None])[0]
if not data: sys.exit(json.dumps(r)[:1500])
items = json.loads(data)
only = sys.argv[2].split(",") if len(sys.argv) > 2 else None
if only: items = [i for i in items if i["id"].split(" ")[0] in only]
out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "mobs.png")
p = os.path.join(HERE, "_mobs.json")
json.dump(items, open(p, "w"))
subprocess.run(["node", os.path.join(HERE, "render_items.js"), p, out], check=True, env=dict(os.environ, CAMDIR="-1.2,0.6,-1.1"))
os.remove(p)
print("wrote", out, len(items))
