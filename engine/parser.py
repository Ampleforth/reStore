"""Parse Anna's Archive HTML into native app data; no page styling reaches QML."""
import re
from urllib.parse import urljoin, urlparse, parse_qs
from bs4 import BeautifulSoup, Comment

BASE = "https://annas-archive.gl"


def document(html):
    soup = BeautifulSoup(html, "html.parser")
    # AA defers some results inside HTML comments. Parse these without executing
    # their contents or accidentally treating scripts as book metadata.
    for comment in list(soup.find_all(string=lambda s: isinstance(s, Comment))):
        if re.search(r'href=["\']/md5/', str(comment)):
            comment.replace_with(BeautifulSoup(str(comment), "html.parser"))
    for node in soup.select("script, style, nav, header, footer"):
        node.decompose()
    return soup


def text(node):
    return node.get_text(" ", strip=True) if node else ""


def metadata(value):
    fmt = re.search(r"\b(epub|pdf)\b", value, re.I)
    size = re.search(r"\b\d+(?:[.,]\d+)?\s*(?:[KMGT]i?B)\b", value, re.I)
    pages = re.search(r"\b(\d+)\s*(?:pages?|pp\.)\b", value, re.I)
    if not pages:
        pages = re.search(r"\b(?:pages?|page count)\s*:?\s*(\d+)\b", value, re.I)
    year = re.search(r"\b(?:18|19|20)\d{2}\b", value)
    language = re.search(r"(?:^|[·,])\s*([^·,]+\[[a-z-]+\])", value, re.I)
    return {"format": fmt[1].lower() if fmt else "", "size": size[0] if size else "",
            "pages": pages[1] if pages else "", "year": year[0] if year else "",
            "language": language[1].strip() if language else ""}


def cover(node, base):
    img = node.select_one("img")
    value = (img.get("data-src") or img.get("src") or "") if img else ""
    return urljoin(base, value) if value else ""


def parse_search(html, base=BASE, page=1):
    soup = document(html)
    books, seen = [], set()
    # Table output provides discrete metadata fields and is explicitly requested.
    for row in soup.select("tr"):
        cells = row.find_all("td", recursive=False)
        a = row.select_one('a[href^="/md5/"]')
        if not a or len(cells) < 11:
            continue
        url = urljoin(base, a["href"])
        if url in seen:
            continue
        seen.add(url)
        b = {"url": url, "title": text(cells[1]), "author": text(cells[2]),
             "publisher": text(cells[3]), "year": text(cells[4]),
             "language": text(cells[-5]), "format": text(cells[-3]).lower(),
             "size": text(cells[-2]), "cover": cover(row, base), "pages": ""}
        b.update({k: v for k, v in metadata(text(row)).items() if v and not b.get(k)})
        if b["format"] in ("pdf", "epub"):
            books.append(b)
    # Retain compatibility with the regular list output if the site ignores display.
    for a in soup.select('a.js-vim-focus[href^="/md5/"], h3 a[href^="/md5/"]'):
        url = urljoin(base, a["href"])
        if url in seen:
            continue
        row = a
        while row.parent and row.parent.name not in ("body", "html", "[document]"):
            if row.select_one('img, [id^="list_cover_"]'):
                break
            row = row.parent
        b = {"url": url, "title": text(a), "cover": cover(row, base)}
        b.update(metadata(text(row)))
        author = row.select_one('a:has([class*="user-edit"])')
        publisher = row.select_one('a:has([class*="company"])')
        b.update(author=text(author), publisher=text(publisher))
        if b["format"] in ("epub", "pdf"):
            books.append(b)
            seen.add(url)
    next_page = any(str(page + 1) in parse_qs(urlparse(a.get("href", "")).query).get("page", [])
                    for a in soup.select("a[href]"))
    known = bool(soup.select_one('.js-aarecord-list-outer, form[action="/search"]'))
    return {"books": books, "next": next_page, "recognized": known or bool(books)}


def parse_book(html, url):
    soup = document(html)
    title = soup.select_one("div.text-2xl.font-semibold, h1")
    if title:
        title = BeautifulSoup(str(title), "html.parser")
        for extra in title.select("a, .select-none"):
            extra.decompose()
    author = soup.select_one('a:has([class*="user-edit"])')
    publisher = soup.select_one('a:has([class*="company"])')
    top = soup.select_one('[id^="cover_aarecord_id__"]')
    desc = soup.select_one(".js-md5-top-box-description")
    b = {"url": url, "title": text(title), "author": text(author), "publisher": text(publisher),
         "cover": cover(top, url) if top else "", "description": text(desc)}
    bottom = soup.select_one('div.text-gray-800.font-semibold')
    b.update(metadata(text(bottom) + " " + text(desc) + " " + text(publisher)))
    links, fast_links, seen = [], [], set()
    # Restrict to the actual Slow downloads section, excluding fast/external links.
    for heading in soup.find_all(re.compile("^h[1-6]$")):
        label=text(heading)
        if not re.search(r"(?:slow|fast)\s+downloads?", label, re.I):
            continue
        destination=fast_links if re.search(r"fast\s+downloads?",label,re.I) else links
        section = heading.parent
        for a in section.select('a.js-download-link[href]'):
            link = urljoin(url, a["href"])
            if link not in seen:
                destination.append({"label": text(a), "url": link})
                seen.add(link)
    return {"book": b, "links": links, "slow_links":links, "fast_links":fast_links, "recognized": bool(title and (desc or bottom))}


def parse_account(html):
    soup=document(html)
    signed=bool(soup.select_one('form[onsubmit*="/dyn/account/logout"]'))
    key_form=soup.select_one('form[action="/account/"] input[name="key"], form[action="/account"] input[name="key"]')
    memberships=[]
    if signed:
        for a in soup.select('a[href^="/donate?tier="]'):
            row=a.find_parent("div")
            if row and not set(row.get("class",[])).intersection({"line-through","italic"}):
                memberships.append(text(row))
    return {"signed_in":signed,"member":bool(memberships),"recognized":signed or bool(key_form),
            "invalid":bool(key_form and soup.select_one(".text-red-500")),
            "message":("Paid membership active" if memberships else "Signed in without an active membership") if signed else "Not signed in"}


def challenge(html):
    soup = BeautifulSoup(html, "html.parser")
    title = text(soup.title).lower()
    return (any(s in title for s in ("ddos-guard", "just a moment", "security check", "captcha"))
            or bool(soup.select_one('iframe[src*="captcha"], iframe[src*="challenges.cloudflare"], .g-recaptcha, .h-captcha, .cf-turnstile, #challenge-form, [data-ddg-origin]')))


def parse_wait(html, url):
    soup = document(html)
    countdown = soup.select_one(".js-partner-countdown")
    if countdown:
        value = re.search(r"-?\d+", text(countdown))
        return {"state": "waiting", "seconds": max(0, int(value[0])) if value else None,
                "message": "Waiting for the slow download slot"}
    # Partner template's large download link; never pick ads or unrelated links.
    for p in soup.select("p.text-xl.font-bold"):
        a = p.select_one('a[href^="https://"], a[href^="http://"]')
        if a:
            return {"state": "ready", "url": urljoin(url, a["href"]), "message": "Download slot ready"}
    # The partner's copy-only variant contains the authorized URL as text in
    # its clipboard control rather than an anchor. Do not follow unrelated ads.
    for button in soup.select('button[onclick*="clipboard.writeText"]'):
        for label in button.find_next_siblings("span"):
            value=text(label).strip()
            parsed=urlparse(value)
            if parsed.scheme in ("http","https") and parsed.netloc and not re.search(r"\s",value):
                return {"state":"ready","url":value,"message":"Opening the supplied download URL"}
    instructions=soup.find(string=re.compile(r"copy.*(?:url|link).*paste",re.I))
    if instructions:
        scope=instructions.find_parent(["p","div"])
        if scope:
            for block in list(scope.find_next_siblings())[:3]:
                for candidate in block.select("input[readonly], textarea[readonly], code, pre"):
                    value=(candidate.get("value") or text(candidate)).strip()
                    parsed=urlparse(value)
                    if parsed.scheme in ("http","https") and parsed.netloc and not re.search(r"\s",value):
                        return {"state":"ready","url":value,"message":"Opening the supplied download URL"}
    return {"state": "challenge" if challenge(html) else "unknown", "message": "Verification required" if challenge(html) else "The download page needs attention"}
