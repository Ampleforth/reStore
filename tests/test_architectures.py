import importlib.util
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from architectures import TARGETS,check_elf,check_package_architecture,lock_path

class ArchitectureTests(unittest.TestCase):
    def test_wrong_architecture_elf_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'entry'
            for arch,target in TARGETS.items():
                header=bytearray(20);header[:6]=b'\x7fELF'+bytes([target['elf_class'],1]);header[18:20]=struct.pack('<H',target['machine']);path.write_bytes(header)
                check_elf(path,arch)
                other=next(name for name in TARGETS if name!=arch)
                with self.assertRaises(ValueError):check_elf(path,other)
            path.write_text('not an executable')
            with self.assertRaises(ValueError):check_elf(path,'aarch64')

    def test_release_locks_are_architecture_specific(self):
        for arch in TARGETS:
            records=json.loads(lock_path(ROOT,arch).read_text())
            check_package_architecture(records,arch)
            self.assertEqual(len({r['Package'] for r in records}),len(records))
            for name in ('chromium','chromium-driver','python3.11-minimal'):
                self.assertIn(name,{r['Package'] for r in records})
            other=next(name for name in TARGETS if name!=arch)
            with self.assertRaises(ValueError):check_package_architecture(records,other)
