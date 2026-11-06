"""Real ENet disconnect/restart/rejoin, including an actual >60-second window."""
from pathlib import Path
import os,subprocess,tempfile,time
root=Path(__file__).resolve().parents[1];base=Path(tempfile.mkdtemp(prefix='ember-boss-return-net-'));processes=[]
def launch(role):
 profile='host' if role=='host' else 'same_client'
 log=(base/(role+'.log')).open('w');env=dict(os.environ,XDG_DATA_HOME=str(base/profile/'data'),XDG_CONFIG_HOME=str(base/profile/'config'),XDG_CACHE_HOME=str(base/profile/'cache'))
 p=subprocess.Popen(['godot','--headless','--path',str(root),'--script','tests/network_boss_return.gd','--',role,'--with-save'],env=env,stdout=log,stderr=subprocess.STDOUT);processes.append((role,p,log));return p
def wait_marker(role,marker,timeout=12):
 end=time.monotonic()+timeout
 while marker not in (base/(role+'.log')).read_text():
  if time.monotonic()>end:raise RuntimeError('Timeout '+marker+' '+str(base))
  if 'ERROR:' in (base/(role+'.log')).read_text():raise RuntimeError('Script error '+str(base))
  time.sleep(.1)
failed=False
try:
 host=launch('host');wait_marker('host','RETURN_HOST_READY');first=launch('first');first.wait(timeout=15);wait_marker('host','RETURN_FIRST_HELD')
 early=launch('early');early.wait(timeout=15);wait_marker('host','RETURN_SECOND_HELD');print('REAL_60_SECOND_WINDOW_RUNNING',flush=True)
 wait_marker('host','RETURN_LATE_READY',70);late=launch('late');late.wait(timeout=15);host.wait(timeout=10)
except Exception as exc:print(exc,flush=True);failed=True
finally:
 for role,p,log in processes:
  if p.poll() is None:p.kill();p.wait()
  log.close();out=(base/(role+'.log')).read_text();print(role,out,flush=True);failed|=p.returncode!=0 or 'ERROR:' in out
print('LOGS',base,flush=True);raise SystemExit(failed)
