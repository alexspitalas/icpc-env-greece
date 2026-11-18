#!/usr/bin/env python3
# s.py inspects the active X11 window on the contestant desktop and outputs JSON
# with window metadata and its process tree (for IDE/editor usage statistics).
import subprocess
import os
import json
import time
from pathlib import Path

os.environ.setdefault("DISPLAY", ":0")
if "XAUTHORITY" not in os.environ and os.path.exists("/home/contestant/.Xauthority"):
    os.environ["XAUTHORITY"] = "/home/contestant/.Xauthority"

def get_process_children(pid):
    # Define a recursive function to find children of the given PID
    def find_children(ppid):
        childs = []
        try:
            # Read the contents of the /proc/<pid>/task/<pid>/children file
            with open(f'/proc/{ppid}/task/{ppid}/children') as children_file:
                children = children_file.read().strip().split()
                for child in children:
                    child_pid = int(child)
                    child_info = find_children(child_pid)
                    if child_info is not None:
                        childs.append(child_info)
        except (FileNotFoundError, PermissionError, ProcessLookupError, ValueError):
            # Skip processes that cannot be accessed
            pass

        try:
            exe = os.readlink(f'/proc/{ppid}/exe')
        except OSError:
            exe = None
        try:
            cmdline = Path(f'/proc/{ppid}/cmdline').read_text().strip('\u0000').split('\u0000')
        except OSError:
            cmdline = []
        try:
            comm = Path(f'/proc/{ppid}/comm').read_text().strip()
        except OSError:
            comm = None

        ret = {
            'exe': exe,
            'cmdline': cmdline,
            'comm': comm,
            'pid': int(ppid),
        }
        if len(childs) > 0:
            ret['children'] = childs
        return ret
    # Call the recursive function to populate the process_children list
    return find_children(pid)

# Use xprop to get the foreground window and some info about it
result = subprocess.run([
    '/bin/bash', '-c',
    'win_id=$(xprop -root -f _NET_ACTIVE_WINDOW 0x " \\$0\\n" _NET_ACTIVE_WINDOW 2>/dev/null | awk "{print \\$2}"); '
    '[ -n "$win_id" ] && [ "$win_id" != "0x0" ] && xprop -notype -id "$win_id" WM_NAME WM_CLASS WM_WINDOW_ROLE _NET_WM_PID 2>/dev/null'
    ], stdout=subprocess.PIPE)

if result.returncode != 0:
    print(json.dumps({"error": "failed to find active window", "ts": int(time.time())}))
    exit(1)
result = result.stdout.decode('utf-8').strip()

# Remap the info we get from xprop
MAPPING={
    "WM_NAME": "name",
    "_NET_WM_PID": "pid",
    "WM_WINDOW_ROLE": "window_role",
    "WM_CLASS": "window_class"
}
# Parse the xprop info, remap it, and split/extract it into a pretty hash
info = {MAPPING.get(i.split(' = ')[0],i.split(' = ')[0]): i.split(' = ')[1].strip('"') for i in result.split('\n') if ' = ' in i}
# get the children/process info of the active window (so we can tell e.g. if they're running vim inside bash)
if "pid" in info and str(info["pid"]).isdigit():
    info['process'] = get_process_children(info["pid"])
else:
    info['process'] = None
# Add the current timestamp
info['ts'] = int(time.time())

print(json.dumps(info, indent=2))

