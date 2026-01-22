import os
from pathlib import Path

ver = os.environ.get("VER")
if not ver:
    raise SystemExit("VER not set")

p = Path("PKGBUILD")
lines = p.read_text().splitlines()
out = []
for line in lines:
    if line.startswith("pkgver="):
        out.append(f"pkgver={ver}")
    elif line.startswith("pkgrel="):
        out.append("pkgrel=1")
    elif line.startswith("source=("):
        out.append(f'source=("https://github.com/Arcodify/pbwrap/archive/refs/tags/v{ver}.tar.gz" "pbwrap.install")')
    elif line.startswith("sha256sums="):
        out.append("sha256sums=('SKIP' 'SKIP')")
    else:
        out.append(line)
p.write_text("\n".join(out) + "\n")
