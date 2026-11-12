#!/usr/bin/env python3
"""Reject private state and mismatched runtime packages before distribution."""
import json
from pathlib import Path
import sys

root=Path(__file__).resolve().parents[1]
bundle=Path(sys.argv[1]) if len(sys.argv)>1 else root/'dist/archive-books'
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
if sorted(map(key,json.loads((runtime/'packages.json').read_text())))!=sorted(map(key,json.loads((root/'packaging/runtime.lock.json').read_text()))):
    raise SystemExit('Release refused: runtime does not match packaging/runtime.lock.json')
for name in ('resources.rcc','runtime/app/server.py','runtime/app/parser.py'):
    if (bundle/name).stat().st_mode&0o044!=0o044:
        raise SystemExit(f'Release refused: {name} must be readable by the unprivileged worker')
if not (bundle/'backend/entry').stat().st_mode&0o111:raise SystemExit('Backend must be executable')
print('Bundle checked: locked runtime, readable worker and no private state')
