#!/usr/bin/env python3
"""Host half of the UI screenshot tour (integration_test/ui_tour_test.dart).

Polls the app's Documents/tour dir on the simulator for req_<n>.txt files,
takes a real simulator screenshot for each into OUT_DIR/<relative path>, and
acknowledges with ack_<n>. Exits when the test writes `finished`.

usage: snap_watcher.py <sim-udid> <bundle-id> <out-dir>
"""
import os
import subprocess
import sys
import time

udid, bundle, out = sys.argv[1], sys.argv[2], sys.argv[3]


def container():
    try:
        return subprocess.check_output(
            ['xcrun', 'simctl', 'get_app_container', udid, bundle, 'data'],
            text=True, stderr=subprocess.DEVNULL).strip()
    except subprocess.CalledProcessError:
        return None


tour = None
next_seq = 1
seen_done = set()
started = time.time()
while True:
    if tour is None or not os.path.isdir(tour):
        c = container()
        cand = c and os.path.join(c, 'Documents', 'tour')
        if cand and os.path.exists(os.path.join(cand, 'ready')):
            tour, next_seq = cand, 1
            print(f'[watcher] attached to {tour}', flush=True)
        else:
            time.sleep(1)
            continue
    req = os.path.join(tour, f'req_{next_seq}.txt')
    if os.path.exists(req):
        rel = open(req).read().strip()
        dest = os.path.join(out, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        subprocess.run(['xcrun', 'simctl', 'io', udid, 'screenshot', '--type=png', dest],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        open(os.path.join(tour, f'ack_{next_seq}'), 'w').close()
        os.remove(req)
        print(f'[watcher] {next_seq:5d} {rel}', flush=True)
        next_seq += 1
        continue
    for f in os.listdir(tour):
        if f.startswith('done_') and f not in seen_done:
            seen_done.add(f)
            print(f'[watcher] done {f[5:]}', flush=True)
    if os.path.exists(os.path.join(tour, 'finished')):
        print(f'[watcher] finished after {next_seq - 1} shots, {time.time() - started:.0f}s', flush=True)
        break
    if not os.path.exists(os.path.join(tour, 'ready')):
        tour = None  # test restarted and wiped the dir
    time.sleep(0.05)
