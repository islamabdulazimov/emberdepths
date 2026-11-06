"""Two actual ENet peers, isolated local profiles, server-owned equipment."""
import os,subprocess,tempfile,time
from pathlib import Path
root=Path(__file__).resolve().parents[1];base=Path(tempfile.mkdtemp(prefix='ember-equipment-net-'));processes=[]
def launch(role):
 log=(base/(role+'.log')).open('w');env=dict(os.environ,XDG_DATA_HOME=str(base/role/'data'),XDG_CONFIG_HOME=str(base/role/'config'),XDG_CACHE_HOME=str(base/role/'cache'))
 p=subprocess.Popen(['godot','--headless','--path',str(root),'--script','tests/network_adventure_smoke.gd','--',role],env=env,stdout=log,stderr=subprocess.STDOUT);processes.append((role,p,log))
try:
 launch('host');deadline=time.monotonic()+12
 while 'ADVENTURE_HOST_READY' not in (base/'host.log').read_text():
  if time.monotonic()>deadline:raise RuntimeError('Host timeout: '+str(base))
  time.sleep(.05)
 launch('client')
 for _,p,_ in processes:p.wait(timeout=20)
finally:
 for _,p,log in processes:
  if p.poll() is None:p.kill();p.wait()
  log.close()
failed=False
for role,p,_ in processes:
 output=(base/(role+'.log')).read_text();print(role,output);failed|=p.returncode!=0 or 'ERROR' in output
raise SystemExit(failed)
