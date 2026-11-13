import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'engine'))
from parser import parse_account, parse_book
from server import Browser

FORM='<form method="post" action="/account/"><input name="key" type="password"></form>'
SIGNED='''<form onsubmit="window.submitForm(event, '/dyn/account/logout/')"></form>'''

class AccountTests(unittest.TestCase):
    def test_signed_in_requires_account_evidence(self):
        self.assertFalse(parse_account(FORM)['signed_in'])
        self.assertFalse(parse_account('<a href="/account/">Account</a>')['recognized'])
        self.assertTrue(parse_account(SIGNED)['signed_in'])
        self.assertFalse(parse_account(SIGNED)['member'])
        self.assertTrue(parse_account(FORM+'<p class="text-red-500">Invalid key</p>')['invalid'])

    def test_shared_wrapper_keeps_download_sections_separate(self):
        parsed=parse_book('''<h1>Book</h1><div class="js-md5-top-box-description">PDF</div>
        <main><h3>Fast downloads</h3><a class="js-download-link" href="/fast/1">Fast 1</a>
        <h3>Slow downloads</h3><a class="js-download-link" href="/slow/1">Slow 1</a>
        <h3>External downloads</h3><a class="js-download-link" href="https://ads.example">External</a></main>''','https://annas-archive.gl/md5/example')
        self.assertEqual([l['label'] for l in parsed['fast_links']],['Fast 1'])
        self.assertEqual([l['label'] for l in parsed['slow_links']],['Slow 1'])

    def test_key_never_submitted_to_unexpected_origin(self):
        browser=Browser.__new__(Browser)
        browser.pending_key='fixture-secret';browser.login_submitted=False
        browser.url=lambda:'https://untrusted.example/account/'
        browser.call=lambda *args:self.fail('Credentials submitted to a foreign origin')
        with self.assertRaises(ValueError) as result:browser.resume_account()
        self.assertNotIn('fixture-secret',str(result.exception))
        self.assertIsNone(browser.pending_key)
        self.assertFalse(browser.account['signed_in'])

    def test_driver_error_cannot_echo_secret_key(self):
        browser=Browser.__new__(Browser)
        browser.pending_key='fixture-secret';browser.login_submitted=False
        browser.url=lambda:'https://annas-archive.gl/account/'
        browser.html=lambda:FORM
        def failed(*args):raise RuntimeError('WebDriver echoed fixture-secret')
        browser.call=failed
        with self.assertRaises(ValueError) as result:browser.resume_account()
        self.assertNotIn('fixture-secret',str(result.exception))
        self.assertIsNone(browser.pending_key)
