"""Host numeric contracts, plus actual installed PET ROM glyph checks."""
import importlib.util,json,math,sys,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.dont_write_bytecode=True
spec=importlib.util.spec_from_file_location('builder',ROOT/'build.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
source,m=b.tables();rom=b.ROM.read_bytes();g=[rom[i*8:i*8+8] for i in range(128)];g+=[bytes(v^255 for v in row) for row in g]
for mask,code in enumerate(m['quadrant']):
    expected=bytes([((240 if mask&1 else 0)|(15 if mask&2 else 0))]*4+[((240 if mask&4 else 0)|(15 if mask&8 else 0))]*4)
    assert g[code]==expected
assert len(set(m['quadrant']))==16
for angle,row in enumerate(m['directions']):
    assert 256<=row[0]+row[1]*256<=65535
    assert 256<=row[2]+row[3]*256<=65535
    if angle in (0,256):assert row[0]+row[1]*256==65535
    if angle in (128,384):assert row[2]+row[3]*256==65535
for column,o in enumerate(m['offsets']):
    assert abs(o*math.tau/512-math.atan(((column+.5)/40*2-1)*math.tan(math.pi/6)))<=math.pi/512
f=40/math.tan(math.pi/6);errors=[]
for d in range(48,8192):
    z=d/256;index=min(511,d>>4)
    for key,scale,sign in (('heightTop',1,-1),('heightBottom',1,1),('heightDoor',.5,-1)):
        exact=max(0,min(44,math.ceil(22+sign*scale*f/z-.5)))
        errors.append(abs(m[key][index]-exact))
assert max(errors)<=2
assert m['darkWallCode']==230 and sum(x.bit_count() for x in g[230])==32
assert g[230]==bytes([85,170]*4)
assert m['floorCode']==46 and m['floorWhiteCoverage']==.0625
assert g[m['sampleCodes'][10]]==g[46]
assert m['sampleCodes'][5] in (160,224)
for wall in (1,3):
    for background in (0,2):
        assert g[m['sampleCodes'][wall*4+background]]==bytes([255]*4+[0]*4)
        assert g[m['sampleCodes'][background*4+wall]]==bytes([0]*4+[255]*4)
assert not any('music_' in line for line in source.splitlines())
result=dict(result='PASS',ROMquadrants=16,directions=512,rayOffsets=40,projectionDepthsTested=8192-48,maxProjectionQuantizationLogicalRows=max(errors),sampleProfiles=m['sampleProfiles'],darkWallCode=230,whiteCoverage=.5,floorWhiteCoverage=.0625,audio=False,edgePolicy=m['edgePolicy'])
out=Path(os.environ.get('PET_TEST_OUT',ROOT/'artifacts/results'));out.mkdir(parents=True,exist_ok=True)
(out/'host-contracts.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
