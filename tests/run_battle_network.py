"""Existing ENet transport: authoritative defense and active melee, three peers."""
import os,subprocess,tempfile,time,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=Path(tempfile.mkdtemp(prefix="ember-battle-net-"))
processes=[]
failed=False
def launch(role):
    log=(base/(role+".log")).open("w")
    env=dict(os.environ,XDG_DATA_HOME=str(base/role/"data"),XDG_CONFIG_HOME=str(base/role/"config"),XDG_CACHE_HOME=str(base/role/"cache"))
    p=subprocess.Popen(["godot","--headless","--path",str(root),"--script","tests/network_battle_smoke.gd","--",role],env=env,stdout=log,stderr=subprocess.STDOUT)
    processes.append((role,p,log))
def wait_marker(marker):
    deadline=time.monotonic()+8
    while marker not in (base/"host.log").read_text():
        if time.monotonic()>deadline: raise RuntimeError("Battle fixture timed out: "+str(base))
        time.sleep(.05)
try:
    launch("host");wait_marker("BATTLE_HOST_READY")
    launch("duelist");wait_marker("DUELIST_ADMITTED")
    launch("observer")
    for _,p,_ in processes: p.wait(timeout=20)
finally:
    for role,p,log in processes:
        if p.poll() is None: p.kill();p.wait()
        log.close()
        out=(base/(role+".log")).read_text()
        print(role,p.returncode);print(out)
        if p.returncode or "ERROR:" in out: failed=True
sys.exit(1 if failed else 0)
