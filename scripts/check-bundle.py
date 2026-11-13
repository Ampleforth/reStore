#!/usr/bin/env python3
"""Reject private state and mismatched runtime packages before distribution."""
import json
from pathlib import Path
import sys
import argparse
from architectures import TARGETS, lock_path, check_elf, check_package_architecture

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--arch',choices=TARGETS,default='armv7');parser.add_argument('bundle',nargs='?',type=Path)
args=parser.parse_args();bundle=args.bundle or root/'dist'/args.arch/'archive-books'
runtime=bundle/'runtime'
expected={'app','dev','etc','lib','proc','state','tmp','usr','packages.json'}
if any(p.name not in expected for p in runtime.iterdir()):
    raise SystemExit('Release refused: unexpected top-level runtime files (possibly private data)')
for name in ('state','tmp','proc','dev'):
    path=runtime/name
    if path.exists() and any(path.iterdir()):
        raise SystemExit(f'Release refused: runtime/{name} must be empty (preserve local data elsewhere)')
for name in ('engine.log','chromedriver.log'):
    if (runtime/name).exists():raise SystemExit(f'Release refused: runtime/{name} is private')
key=lambda row:(row['Package'],row['Version'],row['SHA256'],row['Filename'])
if sorted(map(key,json.loads((runtime/'packages.json').read_text())))!=sorted(map(key,json.loads(lock_path(root,args.arch).read_text()))):
    raise SystemExit('Release refused: runtime does not match packaging/runtime.lock.json')
for name in ('resources.rcc','runtime/app/server.py','runtime/app/parser.py'):
    if (bundle/name).stat().st_mode&0o044!=0o044:
        raise SystemExit(f'Release refused: {name} must be readable by the unprivileged worker')
if not (bundle/'backend/entry').stat().st_mode&0o111:raise SystemExit('Backend must be executable')
check_package_architecture(json.loads((runtime/'packages.json').read_text()),args.arch)
for binary in ('backend/entry','runtime/usr/lib/chromium/chromium','runtime/usr/bin/chromedriver','runtime/usr/bin/python3.11'):
    check_elf(bundle/binary,args.arch)
print('Bundle checked: ' + args.arch + ' locked runtime, readable worker and no private state')
