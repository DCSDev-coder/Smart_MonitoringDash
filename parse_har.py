import json

with open(r'c:\DCStack\Smart Monitoring\tools\API_Source\PUE.har', encoding='utf-8') as f:
    har = json.load(f)

entries = har.get('log', {}).get('entries', [])
out = []
for e in entries:
    req = e.get('request', {})
    res = e.get('response', {})
    url = req.get('url', '').lower()
    if 'pue' in url or 'energy' in url or 'power' in url or 'total' in url:
        text = res.get('content', {}).get('text', '')
        out.append({'url': url, 'text': text[:500]})

with open('pue_responses.json', 'w', encoding='utf-8') as f:
    json.dump(out, f, indent=2)
