from pathlib import Path

path = Path("/app/backend/open_webui/retrieval/web/utils.py")
text = path.read_text()

old = """                    async with session.get(
                        url,
                        **(self.requests_kwargs | kwargs),
                        allow_redirects=AIOHTTP_CLIENT_ALLOW_REDIRECTS,
                    ) as response:
"""

new = """                    async with session.get(
                        url,
                        **(self.requests_kwargs | kwargs),
                    ) as response:
"""

if old in text:
    path.write_text(text.replace(old, new))
    print("Patched SafeWebBaseLoader duplicate allow_redirects")
elif new in text:
    print("SafeWebBaseLoader patch already present")
else:
    raise SystemExit("SafeWebBaseLoader patch target not found")
