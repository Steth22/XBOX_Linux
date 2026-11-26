# Regenerates the whole map through Open Cloud, stage by stage (each stage saves the place).
#   python3 genworld.py all            -> terrain, structures, villages, caves, vegetation
#   python3 genworld.py terrain 5      -> terrain from batch 5 on
#   python3 genworld.py structures | villages | caves | vegetation
import json, os, sys, time
from rbx import run

GEN = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "gen")
def g(name): return open(os.path.join(GEN, name), encoding="utf-8").read()
SAVE = '\nlocal okSave = pcall(function() game:GetService("AssetService"):SavePlaceAsync() end)\nreturn { saved = okSave }\n'
HALF, RES, BATCHES = 1536, 4, 32

def go(label, src):
    for attempt in range(8):
        t = time.time()
        r = run(src, timeout=600)
        out = r.get("output") or {}
        print(label, r.get("state"), "%.0fs" % (time.time() - t), json.dumps(out, ensure_ascii=False)[:400], (r.get("error") or {}).get("message", "")[:400] if isinstance(r.get("error"), dict) else str(r.get("error") or "")[:400], flush=True)
        if r.get("state") == "COMPLETE":
            return True
        time.sleep(30 if r.get("state") == "SUBMIT_FAIL" else 5)
        if r.get("state") == "SUBMIT_FAIL": print("  raw:", str(r.get("raw"))[:200], flush=True)
    return False

def terrain(start=0):
    cols = 2 * HALF // RES
    step = cols // BATCHES
    for b in range(start, BATCHES):
        a = -HALF // RES + b * step
        src = g("common.lua") + "\nlocal XFROM, XTO = %d, %d\n" % (a, a + step) + g("terrain.lua") + SAVE
        if not go("terrain %d/%d" % (b + 1, BATCHES), src):
            sys.exit("terrain batch %d failed" % b)

def structures():
    return go("structures", g("common.lua") + g("structures.lua"))

def villages():
    return go("villages", g("common.lua") + g("part.lua") + g("villages.lua"))

def caves():
    return go("underground", g("common.lua") + g("part.lua") + g("ore.lua") + g("underground.lua"))

def fixcabins():
    return go("fixcabins", g("common.lua") + g("fixcabins.lua"))

def fixcabindoors():
    return go("fixcabindoors", g("fixcabindoors.lua"))

def vegetation():
    ok = True
    for part in (1, 2):
        ok = go("vegetation %d" % part, g("common.lua") + "\nlocal PART = %d\n" % part + g("vegetation.lua")) and ok
    return ok

if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "terrain"):
        terrain(int(sys.argv[2]) if len(sys.argv) > 2 and what == "terrain" else 0)
    if what in ("all", "structures"): structures()
    if what == "all": fixcabins(); fixcabindoors()
    if what in ("all", "villages"): villages()
    if what in ("all", "caves"): caves()
    if what in ("all", "vegetation"): vegetation()
    if what in ("all", "fixcabins"): fixcabins()
    if what == "fixcabindoors": fixcabindoors()
