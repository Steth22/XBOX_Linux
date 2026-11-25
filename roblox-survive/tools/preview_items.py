# Exports every item model (built by shared/Items.lua inside Roblox) and renders a contact sheet with three.js.
#   python3 preview_items.py out.png [id1,id2,...]
import json, os, sys, subprocess
from rbx import run
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = open(os.path.join(HERE, "..", "shared", "Items.lua"), encoding="utf-8").read()
def longstr(src):
    n = 0
    while ("]" + "=" * n + "]") in src: n += 1
    return "[" + "=" * n + "[\n" + src + "]" + "=" * n + "]"
lua = """
local RS = game:GetService("ReplicatedStorage")
local ms = Instance.new("ModuleScript")
ms.Name = "ItemsPreview"
ms.Source = %s
ms.Parent = RS.Shared
local I = require(ms)
local out = {}
local ids = {}
for id in pairs(I.defs) do table.insert(ids, id) end
table.sort(ids)
for _, id in ipairs(ids) do
	local m = I.model(id)
	if m then
		local h = m.PrimaryPart
		local parts = {}
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local rel = h.CFrame:ToObjectSpace(p.CFrame)
				local shape = p:IsA("Part") and p.Shape.Name or "Block"
				table.insert(parts, { s = { p.Size.X, p.Size.Y, p.Size.Z }, c = { rel:GetComponents() }, col = { p.Color.R, p.Color.G, p.Color.B }, m = p.Material.Name, sh = shape, t = p.Transparency })
			end
		end
		table.insert(out, { id = id, name = I.defs[id].ar, parts = parts })
	end
end
ms:Destroy()
return game:GetService("HttpService"):JSONEncode(out)
""" % longstr(SRC)
r = run(lua, timeout=200)
data = (r.get("output") or {}).get("results", [None])[0]
if not data:
    sys.exit(json.dumps(r)[:1500])
items = json.loads(data)
only = sys.argv[2].split(",") if len(sys.argv) > 2 else None
if only: items = [i for i in items if i["id"] in only]
out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "items.png")
json.dump(items, open(os.path.join(HERE, "_items.json"), "w"))
subprocess.run(["node", os.path.join(HERE, "render_items.js"), os.path.join(HERE, "_items.json"), out], check=True)
print("wrote", out, len(items), "items")
