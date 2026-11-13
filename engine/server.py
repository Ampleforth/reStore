#!/usr/bin/env python3
"""On-tablet browser worker. Chromium and Python are bundled in its private root.

WebDriver is private to this process. The tablet receives parsed JSON, except
for interactive verification where it receives a screenshot and sends input.
"""
import argparse
import base64
import hmac
import hashlib
import re
import json
import os
from pathlib import Path
import secrets
import signal
import sys
import subprocess
import threading
import time
import zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.parse import urlencode, urlparse, parse_qs
from urllib.request import Request, urlopen

from parser import BASE, challenge, parse_book, parse_search, parse_wait, parse_account



class Browser:
    def __init__(self, driver_url, profile, downloads, headed=False):
        self.driver_url = driver_url
        self.downloads = Path(downloads).resolve()
        self.downloads.mkdir(parents=True, exist_ok=True, mode=0o700)
        Path(profile).mkdir(parents=True, exist_ok=True, mode=0o700)
        args = [f"--user-data-dir={Path(profile).resolve()}", "--window-size=1000,1100", "--disable-dev-shm-usage"]
        if not headed:
            args.append("--headless=new")
        if os.environ.get("RESTORE_ISOLATED") == "1":
            args += ["--no-sandbox", "--disable-gpu", "--disable-breakpad", "--disable-crash-reporter", "--renderer-process-limit=1", "--disk-cache-size=16777216", "--password-store=basic"]
        caps = {"capabilities": {"alwaysMatch": {"browserName": "chrome", "pageLoadStrategy": "eager",
            "goog:loggingPrefs": {"performance": "ALL"},
            "goog:chromeOptions": {"args": args, "prefs": {"download.default_directory": str(self.downloads),
            "download.prompt_for_download": False, "plugins.always_open_pdf_externally": True,
            "profile.default_content_setting_values.cookies": 1, "profile.block_third_party_cookies": False}}}}}
        if os.environ.get("RESTORE_CHROMIUM"):
            caps["capabilities"]["alwaysMatch"]["goog:chromeOptions"]["binary"] = os.environ["RESTORE_CHROMIUM"]
        session = self.raw("POST", "/session", caps)
        self.session = session["sessionId"]
        self.call("POST", "/timeouts", {"pageLoad": 30000, "script": 15000})
        self.call("POST", "/goog/cdp/execute", {"cmd": "Browser.setDownloadBehavior", "params": {
            "behavior": "allow", "downloadPath": str(self.downloads)}})
        self.transfer = {}
        self.file_observed = {}
        self.book = None
        self.allowed_links = set()
        self.download_links = set()
        self.cover_urls = set()
        self.cover_cache = {}
        self.verification_target = None
        self.search_key = None
        self.pending = None
        self.started_download = False
        self.before = set()
        self.selected_url = None
        self.followed_urls=set()
        self.last_follow=0
        self.account = {"signed_in": False, "message": "Not signed in"}
        self.pending_key = None
        self.login_submitted = False

    def raw(self, method, path, data=None):
        req = Request(self.driver_url + path, data=None if data is None else json.dumps(data).encode(),
                      method=method, headers={"Content-Type": "application/json"})
        try:
            with urlopen(req, timeout=90) as response:
                value = json.load(response).get("value")
        except HTTPError as e:
            raise RuntimeError("Browser command failed: " + e.read(2048).decode(errors="replace")) from e
        if isinstance(value, dict) and value.get("error"):
            raise RuntimeError(value.get("message", value["error"]))
        return value

    def call(self, method, path, data=None):
        return self.raw(method, f"/session/{self.session}" + path, data)

    def html(self):
        return self.call("GET", "/source")

    def url(self):
        return self.call("GET", "/url")

    def go(self, url):
        if urlparse(url).scheme not in ("https", "http"):
            raise ValueError("Unsupported page URL")
        try:
            self.call("POST", "/url", {"url": url})
        except RuntimeError as e:
            if '"error":"timeout"' not in str(e).replace(" ", ""):
                raise

    def search(self, query, page):
        self.pending_key = None
        key = (query, page)
        if self.search_key != key or urlparse(self.url()).path != "/search":
            self.go(BASE + "/search?" + urlencode({"index":"", "page":page, "sort":"", "ext":["pdf","epub"], "display":"table", "q":query, "check":"1"}, doseq=True))
            self.search_key = key
        html = self.html()
        if challenge(html):
            self.verification_target = "search"
            return {"browser": True, "message": "Solve the verification, then tap Continue"}
        result = parse_search(html, self.url(), page)
        if not result.pop("recognized"):
            raise ValueError("Search markup was not recognized; the site may have changed")
        self.verification_target = None
        self.allowed_links = {b["url"] for b in result["books"]}
        self.cover_urls.update(b["cover"] for b in result["books"] if b.get("cover"))
        return result

    def details(self, url):
        self.pending_key = None
        if url not in self.allowed_links and (not self.book or url != self.book.get("url")):
            raise ValueError("Choose a book from search results")
        if self.url().split("#")[0] != url:
            self.go(url)
        html = self.html()
        if challenge(html):
            self.verification_target = "book"
            return {"browser": True, "message": "Solve the verification, then tap Continue"}
        result = parse_book(html, url)
        if not result.pop("recognized"):
            raise ValueError("Book markup was not recognized; the site may have changed")
        self.verification_target = None
        self.book = result["book"]
        result["mode"] = "fast" if self.account["signed_in"] else "slow"
        result["links"] = result["fast_links"] if self.account["signed_in"] else result["slow_links"]
        if result["mode"] == "fast" and not result["links"]:
            result["message"] = "No fast download links are available for this book or account. Check your membership in Settings."
        self.download_links = {link["url"] for link in result["links"]}
        if self.book.get("cover"):
            self.cover_urls.add(self.book["cover"])
        return result

    def start(self, url):
        if not self.book or url not in self.download_links:
            raise ValueError("Choose one of this book's download links")
        self.transfer = {}
        self.file_observed = {}
        self.call("POST","/log",{"type":"performance"})
        self.selected_url = url
        self.before = {p.name for p in self.downloads.iterdir()}
        self.pending = None
        self.started_download = False
        self.followed_urls={url}
        self.last_follow=time.monotonic()
        # Reuse a finished earlier transfer only when its content hash matches
        # the selected record. Never import an unrelated cached book.
        match=re.search(r"/md5/([a-fA-F0-9]{32})(?:$|[?#])",self.book.get("url",""))
        if match:
            for path in self.downloads.iterdir():
                if not path.is_file() or path.name.endswith((".crdownload",".tmp")):continue
                if not self.book_format(path):continue
                with path.open("rb") as source:
                    if hashlib.file_digest(source,"md5").hexdigest()!=match[1].lower():continue
                self.before.discard(path.name)
                self.transfer={"state":"completed","receivedBytes":path.stat().st_size,"totalBytes":path.stat().st_size}
                return self.status()
        self.go(url)
        return self.status()

    def transfer_events(self):
        for entry in self.call("POST","/log",{"type":"performance"}):
            event=json.loads(entry["message"])["message"]
            if event["method"]=="Page.downloadProgress":
                self.transfer.update(event["params"])

    def book_format(self, path):
        with path.open("rb") as f:
            header=f.read(1024)
        if b"%PDF-" in header:return "pdf"
        if header.startswith(b"PK"):
            try:
                with zipfile.ZipFile(path) as z:
                    if z.read("mimetype").strip()==b"application/epub+zip":return "epub"
            except (OSError,KeyError,zipfile.BadZipFile):pass
        return None

    def status(self):
        if not self.selected_url:
            return {"state": "idle", "message": "Choose a download link"}
        self.verification_target = None
        self.transfer_events()
        candidates = [p for p in self.downloads.iterdir() if p.is_file() and p.name not in self.before]
        partials = [p for p in candidates if p.name.endswith((".crdownload",".tmp"))]
        progress={"bytes":max(sum(p.stat().st_size for p in candidates),int(self.transfer.get("receivedBytes",0))),
                  "total":int(self.transfer.get("totalBytes",0))}
        if self.transfer.get("state")=="canceled":
            return dict(progress,state="error",message="The server interrupted the download. Choose another server or retry.")
        if partials:
            return dict(progress,state="downloading",message="Downloading book…")
        for path in candidates:
            stat=path.stat();stamp=(stat.st_size,stat.st_mtime_ns)
            previous=self.file_observed.get(path.name)
            self.file_observed[path.name]=(stamp,time.monotonic()) if not previous or previous[0]!=stamp else previous
            # A final filename can lack a suffix; never import an active partial.
            if self.transfer.get("state")!="completed" and time.monotonic()-self.file_observed[path.name][1]<1:
                return dict(progress,state="downloading",message="Finishing download…")
            fmt=self.book_format(path)
            if fmt:
                if path.suffix.lower()!=('.'+fmt):
                    renamed=path.with_name(path.name+'.'+fmt)
                    if renamed.exists():renamed=path.with_name(secrets.token_hex(8)+'.'+fmt)
                    path=path.rename(renamed)
                self.pending=path
                return dict(progress,state="complete",message="Download complete · importing into My files")
            return dict(progress,state="error",message="The server returned a file that is not a PDF or EPUB. Choose another server.")
        html = self.html()
        if challenge(html):
            self.verification_target = "download"
            return {"state":"challenge", "message":"Solve the verification, then tap Continue"}
        result = parse_wait(html, self.url())
        if result["state"] == "ready":
            # The site's own timer has finished and supplied the authorized URL.
            # Use the same browser, cookies, and IP for the transfer.
            target=result.pop("url")
            if target in self.followed_urls:
                if time.monotonic()-self.last_follow>20:
                    return {"state":"unknown","message":"The server has not started a file transfer. Open verification or choose another server."}
                return {"state":"connecting","message":"Waiting for the file transfer to start"}
            if len(self.followed_urls)>=8:
                return {"state":"unknown","message":"The download page is looping; choose another server"}
            self.followed_urls.add(target);self.last_follow=time.monotonic();self.started_download = True
            self.go(target)
            return {"state": "downloading", "message": "Downloading book…"}
        if result["state"]=="unknown" and self.started_download and time.monotonic()-self.last_follow<5:
            return {"state":"connecting","message":"Waiting for the file transfer to start"}
        return result

    def login(self, key, reuse=False):
        if not isinstance(key, str) or not 1 <= len(key.strip()) <= 256:
            raise ValueError("Enter a secret key in Settings first")
        # Do not reuse a previous account when the saved key has changed.
        self.account = {"signed_in": False, "message": "Signing in"}
        self.download_links.clear()
        self.pending_key = key.strip()
        self.login_deadline = time.monotonic() + 45
        self.login_submitted = bool(reuse)
        self.verification_target = "account"
        try:
            self.go(BASE + "/account/")
            return self.resume_account()
        except (RuntimeError, OSError):
            self.pending_key = None
            raise ValueError("Sign-in failed. Complete verification and try again.") from None

    def account_challenge(self):
        self.verification_target = "account"
        return {"browser": True, "account": self.account,
                "message": "Complete verification to sign in. reStore will continue automatically."}

    def resume_account(self):
        try:
            current, base = urlparse(self.url()), urlparse(BASE)
            if (current.scheme, current.netloc) != (base.scheme, base.netloc):
                raise ValueError("Return to the official account page and retry sign-in")
            html = self.html()
            if challenge(html):
                return self.account_challenge()
            if current.path.rstrip("/") != "/account":
                raise ValueError("Return to the official account page and retry sign-in")
            parsed = parse_account(html)
            if not parsed["recognized"]:
                raise ValueError("The account page was not recognized; retry sign-in")
            if self.pending_key and not parsed["signed_in"]:
                self.login_submitted = False
            if not self.login_submitted and self.pending_key:
                # Submit the site's actual password form, preserving its hidden fields.
                # A prior cookie session may belong to a different key; always submit this key.
                if parsed["signed_in"]:
                    self.call("DELETE", "/cookie")
                    self.go(BASE + "/account/")
                    if challenge(self.html()):
                        return self.account_challenge()
                submitted = self.call("POST", "/execute/sync", {
                    "script": """const k=document.querySelector('form[action="/account/"] input[name="key"], form[action="/account"] input[name="key"]');
                        if (!k || k.form.method.toLowerCase()!=='post' || new URL(k.form.action).origin!==location.origin) return false;
                        k.value=arguments[0]; k.form.requestSubmit(); return true;""",
                    "args": [self.pending_key]})
                if not submitted:
                    raise ValueError("The secret-key login form was not recognized")
                self.login_submitted = True
                self.pending_key = None
                for _ in range(30):
                    time.sleep(0.1)
                    html = self.html()
                    if challenge(html):
                        return self.account_challenge()
                    parsed = parse_account(html)
                    if parsed["signed_in"] or parsed["invalid"]:
                        break
                else:
                    return self.account_challenge()
            if self.login_submitted and not parsed["signed_in"] and not parsed["invalid"] and time.monotonic() < self.login_deadline:
                return self.account_challenge()
            if parsed["invalid"] or not parsed["signed_in"]:
                parsed["message"] = "The secret key was not accepted. Check the key and retry."
            self.pending_key = None
            self.account = {k: v for k, v in parsed.items() if k not in ("recognized", "invalid")}
            self.verification_target = None
            return {"account": self.account, "message": self.account["message"]}
        except (RuntimeError, OSError, ValueError):
            self.pending_key = None
            self.account = {"signed_in": False, "message": "Sign-in failed. Check your connection and retry."}
            self.verification_target = None
            # WebDriver errors may include script arguments. Never return credentials.
            raise ValueError(self.account["message"]) from None

    def logout(self):
        self.pending_key = None
        self.login_submitted = False
        self.verification_target = None
        self.download_links.clear()
        self.account = {"signed_in": False, "message": "Secret key removed. Using slow downloads."}
        try:
            self.go(BASE + "/account/")
            current, base = urlparse(self.url()), urlparse(BASE)
            if (current.scheme, current.netloc) != (base.scheme, base.netloc):
                raise ValueError("Could not clear the account session; retry sign-out")
            self.call("DELETE", "/cookie")
        except (RuntimeError, OSError):
            raise ValueError("Could not clear the account session; retry sign-out") from None
        return {"account": self.account, "message": self.account["message"]}

    def verification_ready(self):
        target=self.verification_target
        if not target:return False
        if target=="download" and any(p.is_file() and p.name not in self.before for p in self.downloads.iterdir()):return True
        html=self.html()
        if challenge(html):return False
        url=self.url()
        if target=="account":return urlparse(url).path.rstrip("/")=="/account" and parse_account(html)["recognized"]
        if target=="search":return urlparse(url).path=="/search" and parse_search(html,url)["recognized"]
        if target=="book":return parse_book(html,url)["recognized"]
        return target=="download" and parse_wait(html,url)["state"] in ("waiting","ready")

    def frame(self):
        frame=self.call("POST","/goog/cdp/execute",{"cmd":"Page.captureScreenshot","params":{
            "format":"jpeg","quality":85,"captureBeyondViewport":False,"optimizeForSpeed":True}})
        return {"image": "data:image/jpeg;base64," + frame["data"], "url": self.url(), "verificationReady":self.verification_ready()}

    def cover(self, url):
        if url not in self.cover_urls:
            raise ValueError("Cover is not from a search result")
        if url in self.cover_cache:
            return self.cover_cache[url]
        frame = self.call("POST","/goog/cdp/execute",{"cmd":"Page.getFrameTree","params":{}})["frameTree"]["frame"]["id"]
        resource = self.call("POST","/goog/cdp/execute",{"cmd":"Network.loadNetworkResource","params":{
            "frameId":frame,"url":url,"options":{"disableCache":False,"includeCredentials":True}}})["resource"]
        if not resource.get("success") or resource.get("httpStatusCode") != 200 or not resource.get("stream"):
            raise ValueError("Cover image unavailable")
        mime = next((v for k,v in resource.get("headers",{}).items() if k.lower()=="content-type"),"").split(";")[0]
        stream,content = resource["stream"],bytearray()
        try:
            while True:
                chunk=self.call("POST","/goog/cdp/execute",{"cmd":"IO.read","params":{"handle":stream,"size":65536}})
                content.extend(base64.b64decode(chunk["data"]) if chunk.get("base64Encoded") else chunk["data"].encode())
                if len(content)>4*1024*1024:
                    raise ValueError("Cover image too large")
                if chunk.get("eof"):
                    break
        finally:
            self.call("POST","/goog/cdp/execute",{"cmd":"IO.close","params":{"handle":stream}})
        if mime not in ("image/jpeg","image/png","image/webp","image/gif"):
            raise ValueError("Cover response is not an image")
        if sum(len(v[1]) for v in self.cover_cache.values())+len(content)>16*1024*1024:
            self.cover_cache.clear()
        self.cover_cache[url]=(mime,bytes(content))
        return self.cover_cache[url]

    def input(self, data):
        action = data.get("action")
        if action in ("click","drag"):
            x, y = float(data["x"]), float(data["y"])
            if not 0 <= x <= 1 or not 0 <= y <= 1:
                raise ValueError("Invalid pointer coordinates")
            # Screenshot coordinates use the content viewport, not window chrome.
            size = self.call("POST", "/execute/sync", {"script": "return [innerWidth,innerHeight]", "args": []})
            actions = [
                {"type": "pointerMove", "duration": 0, "x": min(size[0]-1,int(x*size[0])), "y": min(size[1]-1,int(y*size[1]))},
                {"type": "pointerDown", "button": 0}]
            if action=="drag":
                ex,ey=float(data["endX"]),float(data["endY"])
                if not 0<=ex<=1 or not 0<=ey<=1:
                    raise ValueError("Invalid drag coordinates")
                actions.append({"type":"pointerMove","duration":700,"x":min(size[0]-1,int(ex*size[0])),"y":min(size[1]-1,int(ey*size[1]))})
            actions.append({"type":"pointerUp","button":0})
            self.call("POST", "/actions", {"actions": [{"type": "pointer", "id": "touch", "parameters": {"pointerType": "mouse"}, "actions": actions}]})
        elif action == "scroll":
            dy = max(-1200, min(1200, int(data["dy"])))
            self.call("POST", "/execute/sync", {"script": "window.scrollBy(0,arguments[0])", "args": [dy]})
        elif action == "text":
            # CDP targets the actual focused frame, including cross-origin CAPTCHAs.
            self.call("POST","/goog/cdp/execute",{"cmd":"Input.insertText","params":{"text":data.get("text", "")[:2048]}})
        elif action == "key":
            key=data["key"]
            code={"Enter":13,"Backspace":8,"Tab":9}[key]
            for kind in ("keyDown","keyUp"):
                self.call("POST","/goog/cdp/execute",{"cmd":"Input.dispatchKeyEvent","params":{"type":kind,"key":key,"windowsVirtualKeyCode":code}})
        else:
            raise ValueError("Unsupported browser input")
        result=self.frame()
        if action=="click":
            try:
                def editable(depth=0):
                    if depth>8:return False
                    if self.call("POST","/execute/sync",{"script":"return Boolean(document.hasFocus() && document.activeElement && (document.activeElement.isContentEditable || document.activeElement.tagName==='TEXTAREA' || (document.activeElement.tagName==='INPUT' && /^(text|password|email|number|search|tel|url)$/.test(document.activeElement.type))) && !document.activeElement.disabled && !document.activeElement.readOnly)","args":[]}):return True
                    frames=self.call("POST","/elements",{"using":"css selector","value":"iframe,frame"})
                    for frame in frames:
                        self.call("POST","/frame",{"id":frame})
                        try:
                            if editable(depth+1):return True
                        finally:self.call("POST","/frame/parent",{})
                    return False
                try:result["editableFocused"]=bool(editable())
                finally:self.call("POST","/frame",{"id":None})
            except RuntimeError:
                result["editableFocused"]=False
        return result

    def close(self):
        if not getattr(self,"closed",False):
            self.closed=True
            self.call("DELETE", "")


class Handler(BaseHTTPRequestHandler):
    server_version = "ArchiveBooks/0.1"

    def log_message(self, *_):
        pass  # URLs and queries can be private.

    def serve(self):
        if self.headers.get("Origin") or not hmac.compare_digest(self.headers.get("Authorization", ""), "Bearer " + self.server.token):
            self.send_error(403)
            return
        try:
            with self.server.lock:
                b = self.server.browser
                if self.path.startswith("/cover?") and self.command=="GET":
                    mime,payload=b.cover(parse_qs(urlparse(self.path).query).get("url",[""])[0])
                    self.send_response(200);self.send_header("Content-Type",mime);self.send_header("Content-Length",str(len(payload)));self.end_headers();self.wfile.write(payload)
                    return
                if self.path == "/file" and self.command == "GET":
                    if not b.pending or not b.pending.is_file():
                        raise ValueError("No completed book download")
                    self.send_response(200)
                    self.send_header("Content-Type", "application/octet-stream")
                    self.send_header("X-Book-Format", b.pending.suffix[1:].lower())
                    self.send_header("Content-Length", str(b.pending.stat().st_size))
                    self.end_headers()
                    with b.pending.open("rb") as source:
                        while chunk := source.read(1024*1024):
                            self.wfile.write(chunk)
                    return
                data = {}
                if self.command == "POST":
                    length = int(self.headers.get("Content-Length", "0"))
                    if not 0 <= length <= 16384:
                        raise ValueError("Request too large")
                    data = json.loads(self.rfile.read(length) or b"{}")
                if self.path == "/search" and self.command == "POST":
                    query, page = str(data["query"]).strip(), int(data.get("page", 1))
                    if not query or len(query)>1000 or not 1<=page<=10000:
                        raise ValueError("Invalid search")
                    result = b.search(query, page)
                elif self.path == "/book" and self.command == "POST":
                    result = b.details(data["url"])
                elif self.path == "/account" and self.command == "POST":
                    result = b.login(data.get("key"), reuse=data.get("reuse") is True)
                elif self.path == "/account/resume" and self.command == "POST":
                    result = b.resume_account()
                elif self.path == "/account/logout" and self.command == "POST":
                    result = b.logout()
                elif self.path == "/start" and self.command == "POST":
                    result = b.start(data["url"])
                elif self.path == "/status" and self.command == "GET":
                    result = b.status()
                elif self.path == "/ack" and self.command == "POST":
                    if b.pending:
                        b.pending.unlink(missing_ok=True)
                    b.pending=None;b.selected_url=None
                    result={"ok":True}
                elif self.path == "/browser":
                    result = b.input(data) if self.command == "POST" else b.frame()
                else:
                    self.send_error(404)
                    return
                encoded = json.dumps(result).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", str(len(encoded)))
                self.end_headers()
                self.wfile.write(encoded)
        except (ValueError, RuntimeError, OSError, KeyError) as e:
            payload = json.dumps({"error": str(e)}).encode()
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    do_GET = serve
    do_POST = serve


def main():
    browser=None
    lifecycle_fd=os.environ.get("RESTORE_LIFECYCLE_FD")
    if lifecycle_fd:
        def watch_parent():
            try:
                while os.read(int(lifecycle_fd),1):
                    pass
            finally:
                if browser:
                    def flush_profile():
                        try:browser.close()
                        except (RuntimeError,OSError):pass
                    closing=threading.Thread(target=flush_profile,daemon=True)
                    closing.start();closing.join(timeout=5)
                # The worker and its descendants have their own process group.
                if os.getpgrp()==os.getpid():
                    os.killpg(os.getpgrp(),signal.SIGKILL)
                os._exit(0)
        threading.Thread(target=watch_parent,daemon=True).start()
    p = argparse.ArgumentParser()
    p.add_argument("--listen", choices=["127.0.0.1"], default="127.0.0.1")
    p.add_argument("--port", type=int, default=38768)
    p.add_argument("--driver-port", type=int, default=38769)
    p.add_argument("--state", type=Path, default=Path.home()/".local/share/archive-books-browser")
    p.add_argument("--headed", action="store_true")
    args = p.parse_args()
    args.state.mkdir(parents=True, exist_ok=True, mode=0o700)
    tokenfile = args.state / "token"
    if not tokenfile.exists():
        fd = os.open(tokenfile, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(secrets.token_urlsafe(32))
    token = tokenfile.read_text().strip()
    if len(token)<32:
        raise ValueError("Local engine token must have at least 32 characters")
    driver_output=sys.stderr if os.environ.get("RESTORE_ISOLATED")=="1" else subprocess.DEVNULL
    driver = subprocess.Popen(["chromedriver", f"--port={args.driver_port}", "--allowed-ips=127.0.0.1"], stdout=driver_output, stderr=driver_output)
    browser = None
    try:
        for _ in range(50):
            try:
                with urlopen(f"http://127.0.0.1:{args.driver_port}/status", timeout=1):
                    break
            except OSError:
                if driver.poll() is not None:
                    raise RuntimeError("ChromeDriver exited")
                time.sleep(0.1)
        browser = Browser(f"http://127.0.0.1:{args.driver_port}", args.state/"profile", args.state/"downloads", args.headed)
        server = ThreadingHTTPServer((args.listen,args.port), Handler)
        server.browser, server.token, server.lock = browser, token, threading.Lock()
        print(f"Local browser engine listening on {args.listen}:{args.port}; token file: {tokenfile}", flush=True)
        server.serve_forever()
    finally:
        if browser:
            browser.close()
        driver.terminate()
        driver.wait(timeout=10)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    main()
