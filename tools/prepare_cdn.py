"""Package the Web export within Cloudflare's individual asset size limit."""
from pathlib import Path
import gzip, shutil

shutil.copyfile('web/field-backdrop.jpg','build/web/field-backdrop.jpg')
shutil.copyfile('assets/DelaGothicOne-Regular.ttf','build/web/DelaGothicOne-Regular.ttf')
source=Path('build/web');target=Path('build/cdn');target.mkdir(parents=True,exist_ok=True)
for p in source.iterdir():
    if not p.is_file() or p.suffix=='.import':continue
    if p.name=='index.wasm':
        (target/'index.wasm.gz').write_bytes(gzip.compress(p.read_bytes(),compresslevel=9,mtime=0))
    else:shutil.copyfile(p,target/p.name)
for p in target.iterdir():
    assert p.stat().st_size<25*1024*1024,p.name
(target/'_headers').write_text('/index.html\n  Cache-Control: no-cache\n/index.js\n  Cache-Control: no-cache\n/index.pck\n  Cache-Control: no-cache\n')
print('CDN assets prepared')
