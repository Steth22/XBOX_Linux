import json, sys, time, subprocess, tempfile, os
B="https://apis.roblox.com/cloud/v2/universes/8581501196/places/94804740852799"
def curl(args):
    return subprocess.run(["curl","-s"]+args,capture_output=True,text=True).stdout
def run(src, timeout=290, label=""):
    body=json.dumps({"script":src,"timeout":"280s"})
    BODY = os.path.join(tempfile.gettempdir(), "rbx_body.json")
    open(BODY,"w").write(body)
    r=curl(["-X","POST",B+"/luau-execution-session-tasks","-H","Content-Type: application/json","-d","@" + BODY])
    try: p=json.loads(r)["path"]
    except Exception: return {"state":"SUBMIT_FAIL","raw":r[:500]}
    t0=time.time()
    while time.time()-t0<timeout:
        time.sleep(4)
        d=json.loads(curl(["https://apis.roblox.com/cloud/v2/"+p]))
        if d.get("state") in ("COMPLETE","FAILED","CANCELLED"):
            d.pop("script",None)
            lg=curl(["https://apis.roblox.com/cloud/v2/"+p+"/logs"])
            try: d["logs"]=[m for l in json.loads(lg).get("luauExecutionSessionTaskLogs",[]) for m in l.get("messages",[])]
            except Exception: d["logs_raw"]=lg[:300]
            return d
    return {"state":"TIMEOUT","path":p}
if __name__=="__main__":
    src=open(sys.argv[1]).read()
    print(json.dumps(run(src),ensure_ascii=False,indent=1)[:6000])
