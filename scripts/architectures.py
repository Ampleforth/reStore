"""Architecture names shared by runtime assembly and release validation."""
from pathlib import Path
import struct

TARGETS={
    'armv7': {'debian':'armhf','elf_class':1,'machine':40,'lock':'runtime.lock.json'},
    'aarch64': {'debian':'arm64','elf_class':2,'machine':183,'lock':'runtime.aarch64.lock.json'},
}

def lock_path(root, arch):
    return Path(root)/'packaging'/TARGETS[arch]['lock']

def check_elf(path, arch):
    with Path(path).open('rb') as source:header=source.read(20)
    target=TARGETS[arch]
    if (len(header)<20 or header[:4]!=b'\x7fELF' or header[4]!=target['elf_class']
            or header[5]!=1 or struct.unpack('<H',header[18:20])[0]!=target['machine']):
        raise ValueError(f'{path} is not a little-endian {arch} ELF binary')

def check_package_architecture(records, arch):
    suffix='_'+TARGETS[arch]['debian']+'.deb'
    if not records or any(not r['Filename'].endswith((suffix,'_all.deb')) for r in records):
        raise ValueError(f'Runtime package list contains packages for a different architecture than {arch}')
