#!/usr/bin/env python3
"""Create deterministic, allowlisted release assets and a checksum-pinned VELBUILD."""
import gzip
import hashlib
import os
from pathlib import Path
import subprocess
import tarfile

root=Path(__file__).resolve().parents[1]
version=(root/'VERSION').read_text().strip()
output=root/'dist/release';output.mkdir(parents=True,exist_ok=True)
epoch=int(os.environ.get('SOURCE_DATE_EPOCH','0'))

def archive(path,base,paths,prefix,source_modes=False):
    with path.open('wb') as raw,gzip.GzipFile(filename='',mode='wb',fileobj=raw,mtime=epoch) as zipped,tarfile.open(fileobj=zipped,mode='w') as tar:
        for item in sorted(paths):
            name=prefix+'/'+item.relative_to(base).as_posix()
            info=tar.gettarinfo(str(item),arcname=name)
            info.uid=info.gid=0;info.uname=info.gname='';info.mtime=epoch
            if source_modes:info.mode=0o755 if info.isdir() or info.mode&0o111 else 0o644
            if item.is_file() and not item.is_symlink():
                with item.open('rb') as source:tar.addfile(info,source)
            else:tar.addfile(info)

allowed=['.gitignore','.github','VERSION','LICENSE','LICENSE.upstream.md','THIRD_PARTY_NOTICES.md','CHANGELOG.md','README.md','go.mod','config.example.json','engine_linux.go','engine_test.go','library.go','library_test.go','main.go','main_test.go','qml','engine','packaging','scripts','tests','docs']
paths=[]
for name in allowed:
    item=root/name
    if not item.exists():raise SystemExit(f'Missing release input: {name}')
    for entry in ([item]+list(item.rglob('*')) if item.is_dir() else [item]):
        if '__pycache__' in entry.parts or entry.suffix=='.pyc':continue
        # A checksum cannot include the VELBUILD containing that same checksum.
        if entry==root/'packaging/vellum/VELBUILD':continue
        paths.append(entry)
source=output/f'reStore-{version}-source.tar.gz'
archive(source,root,paths,f'reStore-{version}',source_modes=True)
sha512=hashlib.sha512(source.read_bytes()).hexdigest()
recipe=(root/'packaging/vellum/VELBUILD.in').read_text().replace('@VERSION@',version).replace('@SOURCE_SHA512@',sha512)
(root/'packaging/vellum/VELBUILD').write_text(recipe)
(output/'VELBUILD').write_text(recipe)
subprocess.run(['python3',str(root/'scripts/check-bundle.py')],check=True)
bundle=root/'dist/archive-books'
archive(output/f'reStore-{version}-armv7.tar.gz',bundle,list(bundle.rglob('*')),'archive-books')
assets=[source,output/f'reStore-{version}-armv7.tar.gz',output/'VELBUILD']
(output/'SHA256SUMS').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in assets))
print(f'Release prepared in {output}')
