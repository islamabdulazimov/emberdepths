import subprocess,time,os,tempfile
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
failed=False
log_dir=Path(tempfile.mkdtemp(prefix="emberdepths-network-"))
env=os.environ.copy()
env.update(XDG_DATA_HOME=str(log_dir/'data'), XDG_CONFIG_HOME=str(log_dir/'config'), XDG_CACHE_HOME=str(log_dir/'cache'))
processes=[]
def launch(role):
 log=(log_dir/(role+'.log')).open('w')
 proc=subprocess.Popen(['godot','--headless','--path',str(root),'--script','tests/network_smoke.gd','--',role],stdout=log,stderr=subprocess.STDOUT,env=env)
 processes.append((role,proc,log))
try:
 launch('host');time.sleep(.5)
 launch('client1');launch('client2');time.sleep(2.7)
 launch('late');time.sleep(.6)
 launch('rejected')
 for role,proc,log in processes:
  code=proc.wait(timeout=20);log.close()
  print(role,'exit',code)
  output=(log_dir/(role+'.log')).read_text()
  print(output)
  if code or 'ERROR:' in output or 'SCRIPT ERROR:' in output: failed=True
finally:
 for _,proc,log in processes:
  if proc.poll() is None: proc.kill()
  log.close()

sys.exit(1 if failed else 0)
