import sys
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"engine"))
from parser import parse_search,parse_book,parse_wait,challenge


class ParserTests(unittest.TestCase):
    def test_table_results_formats_pagination_and_missing_pages(self):
        def row(fmt,hash):
            return f'''<tr><td><a href="/md5/{hash}"><img src="/cover.jpg"></a></td>
            <td>Against Intellectual Monopoly</td><td>Michele Boldrin; David K. Levine</td>
            <td>Cambridge University Press</td><td>2008</td><td>book.{fmt}</td><td>Library</td>
            <td>English [en]</td><td>Book</td><td>{fmt}</td><td>2.4 MB</td><td>MD5</td></tr>'''
        html='<div class="js-aarecord-list-outer"><table>'+row('pdf','a'*32)+row('epub','b'*32)+row('mobi','c'*32)+'</table><!-- <table>'+row('epub','d'*32)+'</table> --></div><a href="/search?page=2">2</a>'
        value=parse_search(html)
        self.assertTrue(value['recognized'])
        self.assertTrue(value['next'])
        self.assertEqual([b['format'] for b in value['books']],['pdf','epub','epub'])
        self.assertEqual(value['books'][0]['pages'],'')
        self.assertEqual(value['books'][0]['cover'],'https://annas-archive.gl/cover.jpg')
        self.assertEqual(value['books'][0]['language'],'English [en]')

    def test_detail_all_slow_links_only_and_page_metadata(self):
        html='''<div id="cover_aarecord_id__md5:abc"><img src="https://covers.example/book.jpg"></div>
        <div class="font-semibold text-2xl">Against Intellectual Monopoly<span class="select-none"><a>Search</a></span></div>
        <a><span class="icon-[mdi--user-edit]"></span>Boldrin and Levine</a>
        <a><span class="icon-[mdi--company]"></span>Cambridge</a>
        <div class="text-gray-800 font-semibold">English [en], PDF, 2.4 MB</div>
        <div class="js-md5-top-box-description"><div>Pages</div><div>312</div></div>
        <div><h3>Fast downloads</h3><a class="js-download-link" href="/fast/1">Fast</a></div>
        <div><h3>Slow downloads</h3><ul>
        <li><a class="js-download-link" href="/slow_download/abc/0/0">Slow server 1</a></li>
        <li><a class="js-download-link" href="/slow_download/abc/0/1">Slow server 2</a></li>
        <li><a class="js-download-link" href="/slow_download/abc/1/0">Slow server 3</a></li></ul></div>
        <div><h3>External downloads</h3><a class="js-download-link" href="https://other.example/book">External</a></div>'''
        value=parse_book(html,'https://annas-archive.gl/md5/abc')
        self.assertTrue(value['recognized'])
        self.assertEqual(value['book']['title'],'Against Intellectual Monopoly')
        self.assertEqual(value['book']['pages'],'312')
        self.assertEqual(len(value['links']),3)
        self.assertTrue(all('/slow_download/' in l['url'] for l in value['links']))

    def test_countdown_zero_is_not_permission_to_skip_server(self):
        for seconds in [240,1,0,-1]:
            v=parse_wait(f'<span class="js-partner-countdown">{seconds}</span>','https://annas-archive.gl/slow_download/x/0/0')
            self.assertEqual(v['state'],'waiting')
            self.assertEqual(v['seconds'],max(0,seconds))
        v=parse_wait('<p class="text-xl font-bold"><a href="https://files.example/book.pdf">Download</a></p>','https://annas-archive.gl')
        self.assertEqual(v['state'],'ready')

    def test_challenges_and_unknown_output_are_not_empty_results(self):
        for html in ['<title>DDoS-Guard</title>','<div class="cf-turnstile"></div>','<iframe src="https://captcha.example/"></iframe>']:
            self.assertTrue(challenge(html))
            self.assertEqual(parse_wait(html,'https://example.org')['state'],'challenge')
        self.assertFalse(parse_search('<h1>Service unavailable</h1>')['recognized'])

    def test_copy_only_download_url(self):
        html='''<p>To download, copy this URL and then paste it in your browser's URL bar:</p>
        <p><span class="whitespace-nowrap"><button onclick='navigator.clipboard.writeText("https://files.example/book.pdf?token=sample")'>Copy</button>
        <span class="bg-gray-200">https://files.example/book.pdf?token=sample</span></span></p>'''
        value=parse_wait(html,'https://annas-archive.gl/slow_download/example/0/0')
        self.assertEqual(value['state'],'ready')
        self.assertEqual(value['url'],'https://files.example/book.pdf?token=sample')
        html='<p>Copy this URL and paste it into your browser:</p><div><input readonly value="https://files.example/book.epub"></div>'
        self.assertEqual(parse_wait(html,'https://annas-archive.gl')['url'],'https://files.example/book.epub')
        self.assertEqual(parse_wait('<a href="https://advertisement.example">Visit our sponsor</a>','https://annas-archive.gl')['state'],'unknown')


if __name__=='__main__':
    unittest.main()
