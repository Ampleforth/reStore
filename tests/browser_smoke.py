#!/usr/bin/env python3
"""Exercise real Chromium against controlled HTML, countdown, and download pages.

No books are downloaded from Anna's Archive by this test.
"""
import base64
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time
from urllib.parse import parse_qs,urlparse
from urllib.request import urlopen

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'engine'))
import server as engine

PDF=b'%PDF-1.7\n% reStore integration fixture\n'+b'0'*1024*1024
PNG=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')
book_id='a'*32


class Fixture(BaseHTTPRequestHandler):
    started=None
    account_challenge=False
    post_challenge=False
    submitted_keys=[]
    def do_POST(self):
        if urlparse(self.path).path != '/account/':
            self.send_error(404);return
        form=parse_qs(self.rfile.read(int(self.headers['Content-Length'])).decode())
        key=form.get('key',[''])[0];Fixture.submitted_keys.append(key)
        if key=='fixture-paid-key':
            if Fixture.post_challenge:Fixture.account_challenge=True
            self.send_response(303);self.send_header('Set-Cookie','accountSession=paid; Path=/; Max-Age=3600; SameSite=Lax')
            self.send_header('Location','/account/');self.end_headers()
        else:
            payload=b'<div class="text-red-500">Invalid key</div><form method="post" action="/account/"><input name="key" type="password"><button>Log in</button></form>'
            self.send_response(200);self.send_header('Content-Length',str(len(payload)));self.end_headers();self.wfile.write(payload)
    def log_message(self,*_):pass
    def do_GET(self):
        path=urlparse(self.path).path
        payload=b'';mime='text/html'
        if path=='/account/':
            if Fixture.account_challenge:
                payload=b'<title>CAPTCHA</title><input id="answer">'
            elif 'accountSession=paid' in self.headers.get('Cookie',''):
                payload=b"<h1>Account</h1><form onsubmit=\"window.submitForm(event, '/dyn/account/logout/')\"><button>Log out</button></form><div>Membership <a href='/donate?tier=1'>Extend</a></div>"
            else:
                payload=b'<form method="post" action="/account/"><input name="key" type="password"><button>Log in</button></form>'
        elif path=='/search':
            query=parse_qs(urlparse(self.path).query)
            assert query['ext']==['pdf','epub'],query
            assert query['check']==['1'],query
            payload=f'''<div class="js-aarecord-list-outer"><table><tr>
            <td><a href="/md5/{book_id}"><img src="/cover.png"></a></td>
            <td>Integration Book</td><td>Example Author</td><td>Example Publisher</td><td>2026</td><td>book.pdf</td>
            <td>Example Library</td><td>English [en]</td><td>Book</td><td>pdf</td><td>1 MB</td><td>MD5</td>
            </tr></table></div>'''.encode()
        elif path.startswith('/md5/'):
            payload=f'''<div class="font-semibold text-2xl">Integration Book</div>
            <div class="text-gray-800 font-semibold">English [en], PDF, 1 MB</div>
            <div class="js-md5-top-box-description">10 pages</div>
            <div><h3>Fast downloads</h3><a class="js-download-link" href="/get/fast.pdf">Fast server 1</a></div>
            <div><h3>Slow downloads</h3><a class="js-download-link" href="/slow_download/{book_id}/0/0">Slow server 1</a>
            <a class="js-download-link" href="/slow_download/{book_id}/0/1">Slow server 2</a></div>'''.encode()
        elif path.startswith('/slow_download/'):
            if Fixture.started is None:Fixture.started=time.monotonic()
            if time.monotonic()-Fixture.started<2:
                payload=b'''<span class="js-partner-countdown">2</span><script>let end=Date.now()+2000;setInterval(()=>{let left=Math.ceil((end-Date.now())/1000);document.querySelector('.js-partner-countdown').textContent=left;if(left<=0)location.reload()},200)</script>'''
            else:
                payload=b'<p class="text-xl font-bold"><a href="/copy/book">Download now</a></p>'
                # Real AA uses absolute download URLs.
                payload=payload.replace(b'/copy/book',f'http://127.0.0.1:{self.server.server_port}/copy/book'.encode())
        elif path in ('/get/book.pdf','/get/fast.pdf'):
            payload=PDF;mime='application/pdf'
        elif path=='/copy/book':
            file_url=f'http://127.0.0.1:{self.server.server_port}/get/book.pdf'
            payload=f'''<p>To download, copy this URL and then paste it in your browser:</p>
            <p><span class="whitespace-nowrap"><button onclick='navigator.clipboard.writeText("{file_url}")'>Copy</button><span>{file_url}</span></span></p>'''.encode()
        elif path=='/cover.png':
            if 'fixtureSession=yes' not in self.headers.get('Cookie',''):
                self.send_error(403);return
            payload=PNG;mime='image/png'
        elif path=='/framed':
            payload=f'<iframe src="http://localhost:{self.server.server_port}/captcha" style="position:absolute;left:0;top:0;width:900px;height:800px;border:0"></iframe>'.encode()
        elif path=='/captcha':
            payload=b'<title>CAPTCHA</title><input id="answer" style="position:absolute;left:40px;top:60px;width:300px;height:70px">'
        else:
            self.send_error(404);return
        self.send_response(200);self.send_header('Content-Type',mime);self.send_header('Content-Length',str(len(payload)))
        if path=='/search':self.send_header('Set-Cookie','fixtureSession=yes; Path=/; Max-Age=3600; SameSite=Lax')
        if path in ('/get/book.pdf','/get/fast.pdf'):self.send_header('Content-Disposition','attachment; filename="download"')
        self.end_headers()
        if path in ('/get/book.pdf','/get/fast.pdf'):
            for offset in range(0,len(payload),65536):
                self.wfile.write(payload[offset:offset+65536]);self.wfile.flush();time.sleep(0.12)
        else:self.wfile.write(payload)


def main():
    fixture=ThreadingHTTPServer(('127.0.0.1',0),Fixture)
    threading.Thread(target=fixture.serve_forever,daemon=True).start()
    base=f'http://127.0.0.1:{fixture.server_port}'
    engine.BASE=base
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0));driverport=sock.getsockname()[1]
    driver=subprocess.Popen(['chromedriver',f'--port={driverport}','--allowed-ips=127.0.0.1'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    browser=None
    try:
        for _ in range(50):
            try:
                with urlopen(f'http://127.0.0.1:{driverport}/status',timeout=1):break
            except OSError:time.sleep(0.1)
        with tempfile.TemporaryDirectory(prefix='restore-browser-test-') as tmp:
            browser=engine.Browser(f'http://127.0.0.1:{driverport}',Path(tmp)/'profile',Path(tmp)/'downloads')
            result=browser.search('Integration Book',1)
            assert len(result['books'])==1,result
            mime,image=browser.cover(result['books'][0]['cover'])
            assert mime=='image/png' and image==PNG
            details=browser.details(result['books'][0]['url'])
            assert len(details['links'])==2,details
            assert details['book']['pages']=='10',details
            status=browser.start(details['links'][0]['url'])
            assert status['state']=='waiting' and status['seconds']>0,status
            seen=[status['state']];progress=[]
            for _ in range(50):
                time.sleep(0.2);status=browser.status();seen.append(status['state']);progress.append(status)
                if status['state']=='complete':break
            assert status['state']=='complete',status
            assert 'downloading' in seen,seen
            assert browser.pending.read_bytes()==PDF
            assert browser.pending.suffix=='.pdf'
            assert any(p.get('bytes',0)>0 and p['state']=='downloading' for p in progress),progress
            assert any(p.get('total',0)>0 for p in progress),progress
            # Exercise the real browser form, not a mocked login API.
            Fixture.account_challenge=True
            reply=browser.login('fixture-paid-key')
            assert reply['browser'] and not browser.account['signed_in'],reply
            assert not browser.verification_ready()
            Fixture.account_challenge=False
            browser.go(base+'/account/')
            assert browser.verification_ready()
            reply=browser.resume_account()
            assert reply['account']['signed_in'],reply
            assert Fixture.submitted_keys==['fixture-paid-key'],Fixture.submitted_keys
            details=browser.details(result['books'][0]['url'])
            assert details['mode']=='fast' and len(details['links'])==1,details
            assert '/get/fast.pdf' in details['links'][0]['url'],details
            try:
                browser.start(base+'/slow_download/'+book_id+'/0/0')
                raise AssertionError('stale slow link accepted in fast mode')
            except ValueError:pass
            # A direct fast file uses the same transfer/import path as slow files.
            browser.pending.unlink();browser.selected_url=None
            status=browser.start(details['links'][0]['url'])
            for _ in range(50):
                if status['state']=='complete':break
                time.sleep(0.2);status=browser.status()
            assert status['state']=='complete' and browser.pending.read_bytes()==PDF,status
            # Reuse a persisted session without resubmitting the secret.
            reply=browser.login('fixture-paid-key',reuse=True)
            assert reply['account']['signed_in'] and len(Fixture.submitted_keys)==1,reply
            reply=browser.login('fixture-invalid-key')
            assert not reply['account']['signed_in'] and 'not accepted' in reply['message'],reply
            details=browser.details(result['books'][0]['url'])
            assert details['mode']=='slow' and len(details['links'])==2,details
            Fixture.post_challenge=True
            reply=browser.login('fixture-paid-key')
            assert reply['browser'] and browser.pending_key is None,reply
            Fixture.account_challenge=False;Fixture.post_challenge=False
            browser.go(base+'/account/')
            reply=browser.resume_account()
            assert reply['account']['signed_in'],reply
            submitted_count=len(Fixture.submitted_keys)
            browser.close()
            browser=engine.Browser(f'http://127.0.0.1:{driverport}',Path(tmp)/'profile',Path(tmp)/'downloads')
            reply=browser.login('fixture-paid-key',reuse=True)
            assert reply['account']['signed_in'] and len(Fixture.submitted_keys)==submitted_count,reply
            browser.logout()
            assert not browser.account['signed_in']
            browser.go(base+'/account/')
            assert not engine.parse_account(browser.html())['signed_in']
            # Restore the unrelated session cookie for the restart check below.
            browser.search('Integration Book',1)
            browser.go(base+'/captcha')
            frame=browser.frame();assert frame['image'].startswith('data:image/jpeg;base64,')
            assert base64.b64decode(frame['image'].split(',',1)[1]).startswith(b'\xff\xd8')
            viewport=browser.call('POST','/execute/sync',{'script':'return [innerWidth,innerHeight]','args':[]})
            result=browser.input({'action':'click','x':100/viewport[0],'y':90/viewport[1]})
            assert result.get('editableFocused'),result.keys()
            browser.input({'action':'text','text':'human answer'})
            value=browser.call('POST','/execute/sync',{'script':"return document.getElementById('answer').value",'args':[]})
            assert value=='human answer',value
            browser.go(base+'/framed')
            result=browser.input({'action':'click','x':100/viewport[0],'y':90/viewport[1]})
            assert result.get('editableFocused'),'cross-origin text field was not detected'
            browser.input({'action':'text','text':'iframe answer'})
            iframe=browser.call('POST','/element',{'using':'css selector','value':'iframe'})
            browser.call('POST','/frame',{'id':iframe})
            assert browser.call('POST','/execute/sync',{'script':"return document.getElementById('answer').value",'args':[]})=='iframe answer'
            browser.call('POST','/frame',{'id':None})
            browser.close()
            browser=engine.Browser(f'http://127.0.0.1:{driverport}',Path(tmp)/'profile',Path(tmp)/'downloads')
            browser.go(base+'/captcha')
            cookies=browser.call('GET','/cookie')
            assert any(c['name']=='fixtureSession' and c['value']=='yes' for c in cookies),'persistent cookie was lost after restarting Chromium'
            browser.close();browser=None
            print('Chromium integration passed: parsing, session covers, slow links, countdown, PDF download, JPEG frames, verification input, paid login, fast download, invalid keys, login CAPTCHAs, sign-out and cookies across browser restarts')
    finally:
        if browser:browser.close()
        driver.terminate();driver.wait(timeout=10)
        fixture.shutdown();fixture.server_close()


if __name__=='__main__':main()
