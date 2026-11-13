#!/usr/bin/env python3
"""Assemble a private architecture-specific browser root from Debian packages; never install them."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import lzma
from pathlib import Path
import re
import subprocess
from urllib.request import urlopen
from architectures import TARGETS, lock_path, check_elf, check_package_architecture

REPOSITORIES=[('https://deb.debian.org/debian/','dists/bookworm/main/binary-{debian}/Packages.xz'),
              ('https://security.debian.org/debian-security/','dists/bookworm-security/main/binary-{debian}/Packages.xz')]
ROOTS=['gcc-12-base','chromium','chromium-common','chromium-driver','python3.11-minimal','libpython3.11-stdlib','python3-bs4','fonts-dejavu-core','fontconfig-config','ca-certificates']

def main():
    p=argparse.ArgumentParser();p.add_argument('--arch',choices=TARGETS,default='armv7');p.add_argument('--write-lock',action='store_true',help='save explicitly refreshed package metadata');p.add_argument('--refresh',action='store_true',help='resolve new Debian versions instead of the release lock');p.add_argument('--output',type=Path,default=None);p.add_argument('--cache',type=Path,default=Path('/tmp/restore-runtime-cache'));args=p.parse_args()
    if args.write_lock and not args.refresh:p.error('--write-lock requires --refresh')
    root=Path(__file__).resolve().parents[1]
    args.output=args.output or root/'dist'/args.arch/'archive-books/runtime'
    debian=TARGETS[args.arch]['debian']
    args.cache.mkdir(parents=True,exist_ok=True);args.output.mkdir(parents=True,exist_ok=True)
    lock=lock_path(root,args.arch)
    if not lock.exists() and not args.refresh:raise RuntimeError(f'Missing release lock for {args.arch}; use --refresh --write-lock deliberately')
    if not args.refresh:
        selected={}
        for record in json.loads(lock.read_text()):
            pkg=dict(record);pkg['base']=pkg['URL'][:-len(pkg['Filename'])]
            selected[pkg['Package']]=pkg
    else:
        packages={}
        for index,(base,path) in enumerate(REPOSITORIES):
            cache=args.cache/f'index-{args.arch}-{index}.xz'
            path=path.format(debian=debian)
            if args.refresh or not cache.exists():
                with urlopen(base+path,timeout=90) as r:cache.write_bytes(r.read())
            for block in lzma.decompress(cache.read_bytes()).decode().split('\n\n'):
                fields={};key=None
                for line in block.splitlines():
                    if line.startswith(' ') and key:fields[key]+=' '+line.strip()
                    elif ': ' in line:key,value=line.split(': ',1);fields[key]=value
                if 'Package' in fields:
                    fields['base']=base;packages[fields['Package']]=fields
        selected={};queue=list(ROOTS)
        while queue:
            name=queue.pop()
            if name in selected:continue
            if name not in packages:raise RuntimeError('Missing package '+name)
            pkg=packages[name];selected[name]=pkg
            for dep in (pkg.get('Depends','')+','+pkg.get('Pre-Depends','')).split(','):
                alternatives=[re.split(r'[ (:]',part.strip())[0].split(':')[0] for part in dep.split('|')]
                # Headless Chromium does not need desktop launchers, init scripts,
                # package-manager helpers or multimedia device services.
                for candidate in alternatives:
                    if candidate in packages and (candidate.startswith(('lib','python','fonts-','fontconfig')) or candidate in ('chromium','chromium-common','zlib1g')):
                        queue.append(candidate);break
    check_package_architecture(list(selected.values()),args.arch)
    def download(item):
        name,pkg=item;path=args.cache/Path(pkg['Filename']).name
        if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest()!=pkg['SHA256']:
            with urlopen(pkg['base']+pkg['Filename'],timeout=180) as r:path.write_bytes(r.read())
        if hashlib.sha256(path.read_bytes()).hexdigest()!=pkg['SHA256']:raise RuntimeError('Checksum mismatch: '+name)
        return name,path
    print(f'Downloading {len(selected)} {args.arch} runtime packages',flush=True)
    with ThreadPoolExecutor(max_workers=8) as pool:downloads=list(pool.map(download,selected.items()))
    for name,deb in downloads:
        members=subprocess.check_output(['bsdtar','-tf',str(deb)],text=True).splitlines()
        data=next(m for m in members if m.startswith('data.tar'))
        extract=subprocess.Popen(['bsdtar','-xOf',str(deb),data],stdout=subprocess.PIPE)
        subprocess.run(['bsdtar','-xpf','-','-C',str(args.output)],stdin=extract.stdout,check=True)
        extract.stdout.close()
        if extract.wait()!=0:raise RuntimeError('Could not extract '+name)
    for directory in ['proc','dev','tmp','state','app','etc/ssl/certs']:(args.output/directory).mkdir(parents=True,exist_ok=True)
    (args.output/'tmp').chmod(0o1777)
    certs=sorted((args.output/'usr/share/ca-certificates').rglob('*.crt'))
    (args.output/'etc/ssl/certs/ca-certificates.crt').write_bytes(b'\n'.join(f.read_bytes() for f in certs))
    (args.output/'etc/nsswitch.conf').write_text('hosts: files dns\npasswd: files\ngroup: files\n')
    (args.output/'etc/hosts').write_text('127.0.0.1 localhost\n::1 localhost\n')
    (args.output/'etc/passwd').write_text('nobody:x:65534:65534:Browser:/state:/usr/sbin/nologin\n')
    (args.output/'etc/group').write_text('nogroup:x:65534:\n')
    manifest=[dict({k:pkg[k] for k in ('Package','Version','SHA256','Filename')},URL=pkg['base']+pkg['Filename']) for pkg in selected.values()]
    (args.output/'packages.json').write_text(json.dumps(manifest,indent=2)+'\n')
    for binary in ('usr/lib/chromium/chromium','usr/bin/chromedriver','usr/bin/python3.11'):
        check_elf(args.output/binary,args.arch)
    if args.write_lock:lock.write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'Runtime assembled at {args.output}',flush=True)

if __name__=='__main__':main()
