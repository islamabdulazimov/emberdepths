"""Two actual Godot processes with an isolated persistent test profile."""
import os, subprocess, tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
base=Path(tempfile.mkdtemp(prefix='ember-survival-restart-'))
env=dict(os.environ,XDG_DATA_HOME=str(base/'data'),XDG_CONFIG_HOME=str(base/'config'),XDG_CACHE_HOME=str(base/'cache'))
for mode in ['write','read','read']:
    r=subprocess.run(['godot','--headless','--path',str(root),'--script','tests/survival_restart.gd','--',mode,'--with-save','--profile=survival'],env=env,capture_output=True,text=True,timeout=30)
    print(r.stdout+r.stderr)
    if r.returncode or 'ERROR:' in r.stdout+r.stderr:raise SystemExit(1)
