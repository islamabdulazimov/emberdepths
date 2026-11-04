"""Run two Godot processes against the same isolated persistent directory."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
temporary = Path(tempfile.mkdtemp(prefix="emberdepths-restart-"))
environment = dict(os.environ, XDG_DATA_HOME=str(temporary / "data"),
                   XDG_CONFIG_HOME=str(temporary / "config"),
                   XDG_CACHE_HOME=str(temporary / "cache"))
for mode, profile in (("write", "restart"), ("read", "restart"), ("close_write", "close"), ("read", "close")):
    result = subprocess.run(["godot", "--headless", "--path", str(root),
                             "--script", "tests/save_restart.gd", "--", mode,
                             "--with-save", "--profile=" + profile],
                            env=environment, capture_output=True, text=True, timeout=30)
    output = result.stdout + result.stderr
    print(output)
    if result.returncode or "ERROR:" in output:
        sys.exit(1)

# Reproduce two independent processes sharing a profile, then an abrupt crash.
import time
holder_log_path = temporary / "lock-holder.log"
with holder_log_path.open("w") as holder_log:
    holder = subprocess.Popen(["godot", "--headless", "--path", str(root),
                               "--script", "tests/profile_lock.gd", "--", "hold",
                               "--with-save", "--profile=locktest"],
                              env=environment, stdout=holder_log, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 5
        while "LOCK_READY" not in holder_log_path.read_text():
            if time.monotonic() > deadline:
                raise RuntimeError("Profile lock owner did not start")
            time.sleep(0.05)
        for role in ("probe", "recover"):
            if role == "recover":
                holder.kill()
                holder.wait()
            result = subprocess.run(["godot", "--headless", "--path", str(root),
                                     "--script", "tests/profile_lock.gd", "--", role,
                                     "--with-save", "--profile=locktest"],
                                    env=environment, capture_output=True, text=True, timeout=10)
            output = result.stdout + result.stderr
            print(output)
            if result.returncode or "ERROR:" in output:
                sys.exit(1)
    finally:
        if holder.poll() is None:
            holder.kill()
            holder.wait()
owner_output = holder_log_path.read_text()
print(owner_output)
if "ERROR:" in owner_output:
    sys.exit(1)

# Actual menu round trip: normal world -> ephemeral arena -> original save.
result = subprocess.run(["godot", "--headless", "--path", str(root),
                         "--script", "tests/arena_transition_smoke.gd", "--",
                         "--with-save", "--profile=arena_transition"],
                        env=environment, capture_output=True, text=True, timeout=30)
output = result.stdout + result.stderr
print(output)
if result.returncode or "ERROR:" in output:
    sys.exit(1)
