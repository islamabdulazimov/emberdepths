"""Three actual ENet peers: ready, skip, free summon and paid remote repeat."""
from pathlib import Path
import os,subprocess,tempfile,time
root=Path(__file__).resolve().parents[1];base=Path(tempfile.mkdtemp(prefix='ember-altar-net-'));processes=[]
def launch(role):
 log=(base/(role+'.log')).open('w');env=dict(os.environ,XDG_DATA_HOME=str(base/role/'data'),XDG_CONFIG_HOME=str(base/role/'config'),XDG_CACHE_HOME=str(base/role/'cache'))
 p=subprocess.Popen(['godot','--headless','--path',str(root),'--script','tests/network_altar_smoke.gd','--',role,'--with-save'],env=env,stdout=log,stderr=subprocess.STDOUT);processes.append((role,p,log))
def wait_marker(role,marker):
 limit=time.monotonic()+10
 while marker not in (base/(role+'.log')).read_text():
  if time.monotonic()>limit:raise RuntimeError('Timeout: '+str(base))
  time.sleep(.05)
failed=False
try:
 launch('host');wait_marker('host','ALTAR_HOST_READY');launch('fighter');time.sleep(.45);launch('observer')
 for _,p,_ in processes:p.wait(timeout=22)
except Exception as exc:print(exc);failed=True
finally:
 for role,p,log in processes:
  if p.poll() is None:p.kill();p.wait()
  log.close();out=(base/(role+'.log')).read_text();print(role,out);failed|=p.returncode!=0 or 'ERROR:' in out
print('LOGS',base);raise SystemExit(failed)
