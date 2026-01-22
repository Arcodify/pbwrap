import os
from pathlib import Path

ver = os.environ.get("VER")
if not ver:
    raise SystemExit("VER not set")

p = Path("PKGBUILD")
lines = p.read_text().splitlines()
out = []
skip_mode = None

for line in lines:
    # Skip lines inside multi-line arrays we're replacing
    if skip_mode:
        if line.strip().endswith(")"):
            skip_mode = None
        continue

    if line.startswith("pkgver="):
        out.append(f"pkgver={ver}")
    elif line.startswith("pkgrel="):
        out.append("pkgrel=1")
    elif line.startswith("source=("):
        out.append(
            f'source=("https://github.com/Arcodify/pbwrap/archive/refs/tags/v${{pkgver}}.tar.gz"'
        )
        out.append('        "pbwrap.install")')
        # If original was multi-line, skip until closing paren
        if not line.strip().endswith(")"):
            skip_mode = "source"
    elif line.startswith("sha256sums=("):
        out.append("sha256sums=('SKIP'")
        out.append("            'SKIP')")
        # If original was multi-line, skip until closing paren
        if not line.strip().endswith(")"):
            skip_mode = "sha256sums"
    else:
        out.append(line)

p.write_text("\n".join(out) + "\n")
