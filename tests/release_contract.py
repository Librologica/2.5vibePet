"""Verify exact permanent tree, manifest, package identity and delivered PRGs."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest().upper()
def verify(root=ROOT):
    metadata=json.loads((root/'PACKAGE-MANIFEST.json').read_text())
    assert (root/'VERSION').read_text().strip()==metadata['version']=='1.0.0'
    assert metadata['name']=='2.5vibePet'
    expected={}
    for line in (root/'MANIFEST.sha256').read_text().splitlines():
        sha,name=line.split('  ',1)
        assert name not in expected and not Path(name).is_absolute() and '..' not in Path(name).parts
        expected[name]=sha
        assert digest(root/name)==sha,('Manifest mismatch',name)
    actual={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and '.git' not in p.relative_to(root).parts and not p.relative_to(root).as_posix().startswith(('artifacts/','__pycache__/','tests/__pycache__/'))}
    assert actual==set(expected)|{'MANIFEST.sha256'},('Unexpected/missing files',actual^ (set(expected)|{'MANIFEST.sha256'}))
    assert len(actual)==metadata['permanentFiles']
    for name,sha in metadata['referenceSHA256'].items():assert digest(root/name)==sha
    print('PASS release contract:',len(actual),'permanent files')
    return metadata
if __name__=='__main__':verify()
