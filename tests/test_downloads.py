import sys
import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'engine'))
from server import Browser


class DownloadTests(unittest.TestCase):
    def browser(self, folder):
        browser=Browser.__new__(Browser)
        browser.downloads=Path(folder)
        browser.selected_url='https://example.org/book'
        browser.before=set()
        browser.pending=None
        browser.transfer={'state':'completed'}
        browser.file_observed={}
        browser.transfer_events=lambda:None
        browser.html=lambda:'<title>CAPTCHA</title>'
        return browser

    def test_extensionless_epub_is_importable_even_if_page_still_has_captcha(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'download'
            with zipfile.ZipFile(path,'w') as archive:
                archive.writestr('mimetype','application/epub+zip')
            browser=self.browser(folder)
            self.assertEqual(browser.status()['state'],'complete')
            self.assertEqual(browser.pending.suffix,'.epub')
            self.assertTrue(browser.pending.is_file())

    def test_retry_recovers_only_matching_completed_book(self):
        with tempfile.TemporaryDirectory() as folder:
            data=b'%PDF-1.7\nprevious download'
            (Path(folder)/'download').write_bytes(data)
            browser=self.browser(folder)
            browser.book={'url':'https://example.org/md5/'+hashlib.md5(data).hexdigest()}
            browser.slow_links={'https://example.org/slow'}
            browser.call=lambda *args:[]
            browser.go=lambda url:self.fail('A matching cached book should not be downloaded again')
            self.assertEqual(browser.start('https://example.org/slow')['state'],'complete')
            self.assertEqual(browser.pending.read_bytes(),data)

    def test_auto_continue_waits_for_recognized_site_output(self):
        browser=Browser.__new__(Browser)
        browser.verification_target="download"
        with tempfile.TemporaryDirectory() as folder:
            browser.downloads=Path(folder);browser.before=set()
            browser.url=lambda:'https://example.org/slow_download/book/0/0'
            browser.html=lambda:'<title>CAPTCHA</title><input>'
            self.assertFalse(browser.verification_ready())
            browser.html=lambda:'<h1>Server unavailable</h1>'
            self.assertFalse(browser.verification_ready())
            browser.html=lambda:'<span class="js-partner-countdown">20</span>'
            self.assertTrue(browser.verification_ready())

    def test_partial_pdf_is_not_imported(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder)/'download.crdownload').write_bytes(b'%PDF-1.7\npartial')
            browser=self.browser(folder)
            browser.transfer={'state':'inProgress','receivedBytes':16,'totalBytes':100}
            status=browser.status()
            self.assertEqual(status['state'],'downloading')
            self.assertEqual(status['total'],100)
            self.assertIsNone(browser.pending)

    def test_html_disguised_as_pdf_is_not_imported(self):
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder)/'error.pdf').write_text('<h1>Server unavailable</h1>')
            browser=self.browser(folder)
            self.assertEqual(browser.status()['state'],'error')
            self.assertIsNone(browser.pending)
