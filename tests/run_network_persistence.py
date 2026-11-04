"""Persist a remote avatar through disconnect, reconnect and host restart."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

root = Path(__file__).resolve().parents[1]
directory = Path(tempfile.mkdtemp(prefix="emberdepths-net-save-"))
processes = []
failed = False

def launch(role, identity):
    log_path = directory / (role + ".log")
    log = log_path.open("w")
    env = dict(os.environ, XDG_DATA_HOME=str(directory / identity / "data"),
               XDG_CONFIG_HOME=str(directory / identity / "config"),
               XDG_CACHE_HOME=str(directory / "cache"))
    process = subprocess.Popen(["godot", "--headless", "--path", str(root),
                                "--script", "tests/network_persistence.gd", "--", role],
                               stdout=log, stderr=subprocess.STDOUT, env=env)
    processes.append((role, process, log, log_path))
    return process

def wait_for_text(role, text):
    deadline = time.monotonic() + 8
    while text not in (directory / (role + ".log")).read_text():
        if time.monotonic() > deadline:
            raise RuntimeError("Host not ready; logs: " + str(directory))
        time.sleep(0.05)

def finish(process):
    if process.wait(timeout=20):
        raise RuntimeError("Godot check failed; logs: " + str(directory))

try:
    host = launch("host_write", "host")
    wait_for_text("host_write", "HOST_READY")
    finish(launch("first", "client"))
    finish(launch("reconnect", "client"))
    finish(host)
    host = launch("host_read", "host")
    wait_for_text("host_read", "HOST_READY")
    finish(launch("restart", "client"))
    finish(launch("wrong", "client"))
    finish(host)
except Exception as error:
    failed = True
    print(error)
finally:
    for role, process, log, path in processes:
        if process.poll() is None:
            process.kill()
            process.wait()
        log.close()
        output = path.read_text()
        print(role, "exit", process.returncode)
        print(output)
        if process.returncode or "ERROR:" in output:
            failed = True
sys.exit(1 if failed else 0)
