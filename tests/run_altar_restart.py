"""World-owned free summon and paid appearance survive separate processes."""
import os,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1];base=Path(tempfile.mkdtemp(prefix='ember-altar-restart-'))
env=dict(os.environ,XDG_DATA_HOME=str(base/'data'),XDG_CONFIG_HOME=str(base/'config'),XDG_CACHE_HOME=str(base/'cache'))
for mode in ['write','read']:
 r=subprocess.run(['godot','--headless','--path',str(root),'--script','tests/altar_restart.gd','--',mode,'--with-save'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=40)
 print(r.stdout)
 if r.returncode or 'ERROR' in r.stdout:raise SystemExit(1)
