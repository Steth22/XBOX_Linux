# Uploads the current scripts (without saving) and runs every test file in one Open Cloud session.
import json, os, sys
from rbx import run
from deploy import build
HERE = os.path.dirname(os.path.abspath(__file__))
src = build(save=False)
src = src[:src.rindex("return {")]
names = ["tests.lua", "t_more.lua", "t_caves.lua", "t_world.lua"]
parts = [src, "local all = {}"]
for n in names:
    body = open(os.path.join(HERE, "..", "tests", n), encoding="utf-8").read()
    parts.append("do local ok, r = pcall(function()\n%s\nend) table.insert(all, ok and r or ('ERROR %s: ' .. tostring(r))) end" % (body, n))
parts.append("return all")
r = run("\n".join(parts), timeout=590)
out = r.get("output") or r
txt = json.dumps(out, ensure_ascii=False)
print(txt[:6000])
print("FAILS:", txt.count("FAIL") + txt.count("ERROR"))
