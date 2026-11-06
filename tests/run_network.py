import subprocess,time,os,tempfile
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
combat_mode="--combat" in sys.argv
crafting_mode="--crafting" in sys.argv
logging_mode="--logging" in sys.argv
healing_mode="--healing" in sys.argv
shelter_mode="--shelter" in sys.argv
storage_mode="--storage" in sys.argv
script="tests/network_shelter_smoke.gd" if shelter_mode else ("tests/network_healing_smoke.gd" if healing_mode else ("tests/network_logging_smoke.gd" if logging_mode else ("tests/network_combat_smoke.gd" if combat_mode else ("tests/network_crafting_smoke.gd" if crafting_mode else "tests/network_smoke.gd"))))
if storage_mode: script="tests/network_storage_smoke.gd"
failed=False
log_dir=Path(tempfile.mkdtemp(prefix="emberdepths-network-"))
env=os.environ.copy()
env.update(XDG_DATA_HOME=str(log_dir/'data'), XDG_CONFIG_HOME=str(log_dir/'config'), XDG_CACHE_HOME=str(log_dir/'cache'))
processes=[]
def launch(role):
 log=(log_dir/(role+'.log')).open('w')
 proc=subprocess.Popen(['godot','--headless','--path',str(root),'--script',script,'--',role],stdout=log,stderr=subprocess.STDOUT,env=dict(env, XDG_DATA_HOME=str(log_dir/role/'data')))

 processes.append((role,proc,log))
try:
 launch('host');time.sleep(.5)
 if storage_mode:
  launch("builder")
  deadline=time.monotonic()+8
  while "STORAGE_READY" not in (log_dir/"host.log").read_text():
   if time.monotonic()>deadline:
    raise RuntimeError("Host did not reach storage fixture; logs: "+str(log_dir))
   time.sleep(.05)
  launch("late")
 elif shelter_mode:
  launch('builder')
  deadline=time.monotonic()+8
  while 'DOOR_OPEN' not in (log_dir/'host.log').read_text():
   if time.monotonic()>deadline:
    raise RuntimeError('Host did not reach door fixture; logs: '+str(log_dir))
   time.sleep(.05)
  launch('late')
 elif healing_mode:
  launch('healer')
  deadline=time.monotonic()+8
  while 'HEALED' not in (log_dir/'host.log').read_text():
   if time.monotonic()>deadline:
    raise RuntimeError('Host did not reach healing fixture; logs: '+str(log_dir))
   time.sleep(.05)
  launch('late')
 elif logging_mode:
  launch('logger')
  deadline=time.monotonic()+8
  while 'TREE_CUT' not in (log_dir/'host.log').read_text():
   if time.monotonic()>deadline:
    raise RuntimeError('Host did not reach tree harvest; logs: '+str(log_dir))
   time.sleep(.05)
  launch('late')
 elif combat_mode:
  launch('fighter')
  deadline=time.monotonic()+6
  while 'DEATH_READY' not in (log_dir/'host.log').read_text():
   if time.monotonic()>deadline:
    raise RuntimeError('Host did not reach death fixture; logs: '+str(log_dir))
   time.sleep(.05)
  launch('late')
 elif crafting_mode:
  launch('builder');time.sleep(3.0)
  launch('late')
 else:
  launch('client1');launch('client2');time.sleep(2.7)
  launch('late');time.sleep(.6)
  launch('rejected')
 for role,proc,log in processes:
  code=proc.wait(timeout=40 if healing_mode else 20);log.close()
  print(role,'exit',code)
  output=(log_dir/(role+'.log')).read_text()
  print(output)
  if code or 'ERROR:' in output or 'SCRIPT ERROR:' in output: failed=True
finally:
 for _,proc,log in processes:
  if proc.poll() is None: proc.kill()
  log.close()

sys.exit(1 if failed else 0)
