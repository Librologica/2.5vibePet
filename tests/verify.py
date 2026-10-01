"""Check actual 6502 dumps against independent host DDA/compositor/world."""
import argparse,hashlib,importlib.util,json,math,sys
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('world',ROOT/'src/reference/world.py');world=importlib.util.module_from_spec(spec);spec.loader.exec_module(world)

def word(r,a):return r[a]+256*r[a+1]
def project(z,m):return min(511,z>>4)
def depth(t,c):return t*c//256

def cast(grid,x,y,yaw,ray,m):
    a=(yaw+m['offsets'][ray])&511
    dxlo,dxhi,dylo,dyhi,sign=m['directions'][a];dx=dxlo+256*dxhi;dy=dylo+256*dyhi
    cx,cy=x>>8,y>>8
    sx=(dx*(x&255))>>8;sy=(dy*(y&255))>>8
    if not sign&1:sx=dx-sx
    if not sign&2:sy=dy-sy
    if dx==65535:sx=65535
    if dy==65535:sy=65535
    c=min(255,round(256*math.cos(m['offsets'][ray]*math.tau/512)))
    doors=[];active=False;t=65535;side=0;mat=0;z=65535
    for steps in range(1,65):
        side=int(sy<sx)
        if side: t=sy;cy+=-1 if sign&2 else 1
        else: t=sx;cx+=-1 if sign&1 else 1
        if not (0<=cx<40 and 0<=cy<40):break
        value=grid[cy*40+cx]
        z=depth(t,c);idx=project(z,m)
        if active:doors[-1][1]=m['heightDoor'][idx];active=False
        if value==9:
            if len(doors)==8:mat=1;break
            doors.append([m['heightTop'][idx],m['heightDoor'][idx],3 if side else 1]);active=True
        elif value:mat=value;break
        if side:sy=min(65535,sy+dy)
        else:sx=min(65535,sx+dx)
    else: steps=65;t=z=65535;mat=0
    if not (0<=cx<40 and 0<=cy<40):t=z=65535;mat=0
    return dict(t=t,depth=z,side=side,material=mat,steps=steps,doors=doors)

def verify(build,capture):
    m=json.loads((build/'build.json').read_text());l=m['labels'];files=sorted(capture.glob('frame-*-ram.bin'));assert files,'No captures'
    results=[]
    for file in files:
        r=file.read_bytes();screen=(capture/(file.stem[:-4]+'-screen.bin')).read_bytes()
        grid=r[0x3000:0x3640];ox=int.from_bytes(r[l['eg_origin_x']:l['eg_origin_x']+4],'little');oy=int.from_bytes(r[l['eg_origin_y']:l['eg_origin_y']+4],'little')
        seed=int.from_bytes(r[l['eg_seed']:l['eg_seed']+4],'little')
        assert grid==world.world(ox,oy,seed),f'World differs {file}'
        x,y,yaw=(word(r,l[n]) for n in ('pose_x','pose_y','pose_angle'))
        expected=bytearray(r[0x3b00:0x3b00+1000]);max_doors=0;total_steps=0
        for ray in range(40):
            v=cast(grid,x,y,yaw,ray,m);total_steps+=v['steps'];max_doors=max(max_doors,len(v['doors']))
            for n,key in (('ray_t','t'),('depth','depth')):
                actual=r[l[n+'_lo']+ray]+256*r[l[n+'_hi']+ray]
                assert actual==v[key],(file,ray,key,actual,v[key])
            for n,key in (('ray_mat','material'),('ray_side','side'),('ray_steps','steps')):
                assert r[l[n]+ray]==v[key],(file,ray,key,r[l[n]+ray],v[key])
            assert r[l['ray_doors']+ray]==len(v['doors']),(file,ray,'doorCount')
            for i,(top,bottom,shade) in enumerate(v['doors']):
                assert r[l['door_top']+ray*8+i]==top,(file,ray,i,'doorTop')
                assert r[l['door_bottom']+ray*8+i]==bottom,(file,ray,i,'doorBottom')
                assert r[l['door_shade']+ray*8+i]==shade,(file,ray,i,'doorShade')
            samples=[0]*22+[2]*22
            index=project(v['depth'],m)
            spans=[(m['heightTop'][index],m['heightBottom'][index],3 if v['side'] else 1)]+v['doors']
            for top,bottom,shade in spans:
                for z in range(top,bottom):samples[z]=shade
            for row in range(22):expected[120+row*40+ray]=m['sampleCodes'][samples[2*row]*4+samples[2*row+1]]
        assert bytes(expected)==r[0x3b00:0x3b00+1000],f'Back buffer differs {file}'
        assert screen[:1000]==expected,f'Screen RAM differs {file}'
        ticks=word(r,l['tick_count'])
        via=(capture/(file.stem[:-4]+'-via.bin')).read_bytes()
        assert via[11]&28==0,(file,'Shift register audio must be disabled')
        assert not m['audio'] and not any(k.startswith('music_') for k in l)
        results.append(dict(file=file.name,pose=[x,y,yaw],ticks=ticks,streamShifts=word(r,l['eg_generation_count']),rooms=word(r,l['eg_rooms']),ddaSteps=total_steps,maxDoors=max_doors))
    (capture/'verification.json').write_text(json.dumps(dict(result='PASS',frames=len(files),results=results),indent=2));print('PASS',len(files),'actual PET frames, world/DDA/depth/shaded doors/screen/audio disabled')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);p.add_argument('--capture',type=Path,required=True);a=p.parse_args();verify(a.build,a.capture)
