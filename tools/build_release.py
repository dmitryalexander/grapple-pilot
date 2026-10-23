"""Build a manifest-verified release using only Python's standard library."""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'MANIFEST.json').read_text())
addon=root/manifest['name']
actual={p.relative_to(addon).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in addon.rglob('*') if p.is_file()}
assert actual==manifest['files'],'Payload differs from reviewed manifest'
assert not any(p.suffix.lower() in {'.exe','.dll','.sys','.cmd','.bat','.ps1'} for p in addon.rglob('*') if p.is_file()),'Unexpected executable in addon'
out=root/'dist';out.mkdir(exist_ok=True)
archive=out/('Grapple-Pilot-'+manifest['version']+'.zip')
docs=['README.md','INSTALL.md','VALIDATION.md','THIRD_PARTY_NOTICES.txt','Install.ps1','MANIFEST.json','offline-validation.json']
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for name in docs:z.write(root/name,name)
    for rel in sorted(actual):z.write(addon/rel,manifest['name']+'/'+rel)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for rel,digest in actual.items():assert hashlib.sha256(z.read(manifest['name']+'/'+rel)).hexdigest()==digest
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
archive.with_name(archive.name+'.sha256').write_text(digest+'  '+archive.name+'\n')
print(json.dumps({'zip':str(archive),'size':archive.stat().st_size,'sha256':digest,'payloadFiles':len(actual)},indent=2))
