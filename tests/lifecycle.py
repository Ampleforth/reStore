#!/usr/bin/env python3
"""Real AppLoad SOCK_SEQPACKET framing plus protected loopback HTTP."""
import json
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
from urllib.request import Request,urlopen

with tempfile.TemporaryDirectory(prefix="archive-books-lifecycle-") as tmp:
    path=Path(tmp)
    (path/'library').mkdir()
    with socket.socket(socket.AF_UNIX,socket.SOCK_SEQPACKET) as listener:
        listener.bind(str(path/'lifecycle.sock'));listener.listen(1);listener.settimeout(5)
        with socket.socket() as port:
            port.bind(('127.0.0.1',0));address=f'127.0.0.1:{port.getsockname()[1]}'
        process=subprocess.Popen([sys.argv[1],'-listen',address,'-library',str(path/'library'),'-config',str(path/'config.json'),'-staging',str(path/'staging'),str(path/'lifecycle.sock')],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        try:
            connection,_=listener.accept()
            with connection:
                req=Request(f'http://{address}/settings',headers={'X-ArchiveBooks-Request':'app'})
                with urlopen(req,timeout=5) as r:
                    value=json.load(r)
                    assert value['folders']==[{'id':'','name':'My files','parent':''}],value
                connection.send(struct.pack('=II',1,3));connection.send(b'abc')
                assert process.poll() is None
                connection.send(struct.pack('=II',0xffffffff,0))
                assert process.wait(timeout=5)==0
            print('AppLoad lifecycle and loopback API passed')
        finally:
            if process.poll() is None:process.kill()
            process.communicate(timeout=5)
