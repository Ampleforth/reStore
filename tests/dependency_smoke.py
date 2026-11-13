"""ABI/dependency checks for emulated hosts; does not claim renderer coverage."""
import ssl
import subprocess
import sys
from pathlib import Path
from bs4 import BeautifulSoup

assert ssl.OPENSSL_VERSION
assert BeautifulSoup('<p>runtime ready</p>','html.parser').p.text=='runtime ready'
for binary,args,expected in [('/tests/entry',['-h'],'probe-search'),('/usr/bin/chromedriver',['--version'],'ChromeDriver'),('/usr/lib/chromium/chromium',['--version'],'Chromium')]:
    result=subprocess.run([binary,*args],capture_output=True,text=True,timeout=30)
    assert result.returncode==0,(binary,result.stderr)
    assert expected in result.stdout+result.stderr,(binary,result.stdout,result.stderr)
print('Bundled dependency smoke passed: backend, Python, SSL, Beautiful Soup, ChromeDriver and Chromium executable startup; renderer not tested')
