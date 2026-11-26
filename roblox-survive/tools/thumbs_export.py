# Exports a scene for the thumbnail renderer: python3 thumbs_export.py name cx cz r y0 y1 'mobs-json' 'items-json' 'ground-json' out.json
import json, sys, time
from rbx import run
name, cx, cz, r, y0, y1 = sys.argv[1], *map(float, sys.argv[2:7])
mobs, items, ground, out = sys.argv[7], sys.argv[8], sys.argv[9], sys.argv[10]
def lua_list(v):
    if isinstance(v, list): return "{" + ", ".join(lua_list(x) for x in v) + "}"
    if isinstance(v, str): return json.dumps(v)
    if v is None: return "nil"
    return repr(v)
head = "local CX, CZ, R, Y0, Y1 = %s, %s, %s, %s, %s\nlocal MOBS = %s\nlocal ITEMS = %s\nlocal GROUND = %s\n" % (cx, cz, r, y0, y1, lua_list(json.loads(mobs)), lua_list(json.loads(items)), lua_list(json.loads(ground)))
src = head + open("scene_export.lua", encoding="utf-8").read()
for attempt in range(4):
    t = time.time()
    res = run(src, timeout=280)
    o = (res.get("output") or {}).get("results")
    if o:
        open(out, "w").write(o[0])
        print(name, "ok", "%.0fs" % (time.time() - t), len(o[0]) // 1024, "KB")
        break
    print(name, "retry", str(res.get("error") or res.get("state"))[:300])
    time.sleep(20)
