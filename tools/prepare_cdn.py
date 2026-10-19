"""Package the Web export within Cloudflare's individual asset size limit."""

from pathlib import Path
import gzip, shutil

shutil.copyfile("web/field-backdrop.jpg", "build/web/field-backdrop.jpg")
for font in ["Fredoka-Semibold.ttf", "DelaGothicOne-Regular.ttf"]:
    shutil.copyfile("assets/" + font, "build/web/" + font)
source = Path("build/web")
target = Path("build/cdn")
# Never deploy leftover files from an earlier export/package.
if target.exists():
    shutil.rmtree(target)
target.mkdir(parents=True)
for p in source.iterdir():
    if not p.is_file() or p.suffix == ".import":
        continue
    if p.name == "index.wasm":
        (target / "index.wasm.gz").write_bytes(
            gzip.compress(p.read_bytes(), compresslevel=9, mtime=0)
        )
    else:
        shutil.copyfile(p, target / p.name)
for p in target.iterdir():
    if p.stat().st_size > 25 * 1024 * 1024:
        raise ValueError(f"Asset exceeds Cloudflare 25 MiB limit: {p.name}")
(target / "_headers").write_text(
    "/\n  Cache-Control: no-cache\n/index.html\n  Cache-Control: no-cache\n/index.js\n  Cache-Control: no-cache\n/index.pck\n  Cache-Control: no-cache\n"
)
print("CDN assets prepared")
