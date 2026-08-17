from __future__ import annotations

import html
import re
from pathlib import Path
from urllib.parse import urlparse

import requests

HTML_PATH = Path('/home/ubuntu/browser_html/meta_ai_ToNDjViMmL_1786976284469.html')
OUT_DIR = Path('/home/ubuntu/Theater-of-War-/incoming_meta_assets')
MANIFEST = OUT_DIR / 'manifest.txt'

text = HTML_PATH.read_text(encoding='utf-8', errors='ignore')
text = html.unescape(text)
pattern = re.compile(r'https://(?:cdn\.fbsbx\.com|scontent\.[^/"\\ ]+\.fbcdn\.net)/[^"\\ ]+')
urls = []
seen = set()
for raw in pattern.findall(text):
    raw = raw.rstrip('\\')
    if raw not in seen:
        seen.add(raw)
        urls.append(raw)

OUT_DIR.mkdir(parents=True, exist_ok=True)
rows = []
headers = {'User-Agent': 'Mozilla/5.0'}
for index, url in enumerate(urls, 1):
    path = urlparse(url).path
    name = Path(path).name
    if not name or name in {'.jpg', '.png', '.webp'}:
        name = f'meta_asset_{index}.bin'
    if not Path(name).suffix:
        name += '.bin'
    dest = OUT_DIR / name
    try:
        response = requests.get(url, headers=headers, timeout=30)
        response.raise_for_status()
        dest.write_bytes(response.content)
        rows.append(f'OK\t{name}\t{len(response.content)}\t{url}')
    except Exception as exc:
        rows.append(f'ERROR\t{name}\t{exc}\t{url}')

MANIFEST.write_text('\n'.join(rows) + '\n', encoding='utf-8')
print(f'found={len(urls)} downloaded={sum(row.startswith("OK") for row in rows)} errors={sum(row.startswith("ERROR") for row in rows)}')
print(MANIFEST)
