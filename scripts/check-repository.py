"""Fail on accidental runtime data, credentials, or disabled XCTest tests in source control."""
from pathlib import Path
import subprocess
import re
files = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard'], text=True).splitlines()
blocked = []
for name in files:
    path = Path(name)
    if path.suffix in {'.lifebackup', '.original', '.pem', '.key', '.db', '.sqlite', '.log'} or path.name in {'library.json', '.env', 'credentials.json'}:
        blocked.append(name)
    if path.is_file() and path.suffix in {'.swift', '.md', '.sh', '.json', '.py'}:
        text = path.read_text()
        if re.search(r'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', text):
            blocked.append(name + ': credential pattern')
        if name.startswith(('Tests/', 'UITests/')) and ('XCTSkip' in text or '.disabled(' in text):
            blocked.append(name + ': disabled or skipped test')
assert not blocked, 'Repository check failed: ' + ', '.join(blocked)
print(f'Repository check passed: {len(files)} files; no runtime data, credentials or disabled tests detected.')
