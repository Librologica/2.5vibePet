"""2.5vibePet 1.0.0 standalone PET4032 builder.
Copyright 2026 librologica.digital. PolyForm Noncommercial 1.0.0.
"""
import argparse, hashlib, importlib.util, json, math, os, shutil, subprocess, sys
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
REF = ROOT / 'src' / 'reference'
def chargen_path():
    explicit = os.environ.get('PET_CHARGEN')
    if explicit:
        return Path(explicit)
    emulator = os.environ.get('XPET_EXE') or shutil.which('xpet')
    if emulator:
        candidate = Path(emulator).resolve().parent.parent/'PET/characters-2.901447-10.bin'
        if candidate.is_file():
            return candidate
    raise RuntimeError('Set PET_CHARGEN to the installed graphics character ROM characters-2.901447-10.bin (ROM not distributed).')
ROM = chargen_path()

def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m

def emit(name, values):
    return name+':\n'+''.join(' .byte '+','.join(f'${v&255:02x}' for v in values[i:i+16])+'\n'
                            for i in range(0,len(values),16))

def replace(s, old, new):
    assert s.count(old)==1, (old,s.count(old))
    return s.replace(old,new)

def raycode():
    s=(REF/'raycast.asm').read_text()
    start=s.index('ray_t_lo=$3a00'); end=s.index('\ninit_camera:')
    s=s[:start]+s[end:]
    start=s.index(' ; map pointer ='); end=s.index(' lda delta_x\n',start)
    s=s[:start]+''' ldy cell_y
 lda world_row_lo,y
 clc
 adc cell_x
 sta map_ptr
 lda world_row_hi,y
 adc #0
 sta map_ptr+1
 lda #0
 sta door_count
 sta door_active
 ldx ray_index
 sta ray_doors,x
'''+s[end:]
    s=s.replace('cmp #32','cmp #40').replace('adc #32','adc #40').replace('sbc #32','sbc #40')
    assert s.count(' lda (map_ptr),y\n bne ray_hit')==2
    s=s.replace(' lda (map_ptr),y\n bne ray_hit',' lda (map_ptr),y\n jsr pet_cell\n bcs ray_hit')
    start=s.index(' lda hit_t\n sta mul_a\n',s.index('ray_hit:')); end=s.index('\nray_store:',start)
    s=s[:start]+' jsr pet_depth\n'+s[end:]
    start=s.index(' lda hit_u\n sta ray_u,x'); end=start+len(' lda hit_u\n sta ray_u,x\n')
    s=s[:start]+s[end:]
    s=replace(s,' cmp #80\n',' cmp #40\n')
    start=s.index('; Exact floor(')
    s=s[:start]+(REF/'multiply.asm').read_text()
    s+='''
load_direction:
 ldy angle
 lda angle+1
 bne load_direction_high
 lda direction_dx_lo,y
 sta delta_x
 lda direction_dx_hi,y
 sta delta_x+1
 eor #$ff
 sta dir_x
 lda direction_dy_lo,y
 sta delta_y
 lda direction_dy_hi,y
 sta delta_y+1
 eor #$ff
 sta dir_y
 lda direction_sign,y
 sta dir_sign
 jmp load_direction_done
load_direction_high:
 lda direction_dx_lo+256,y
 sta delta_x
 lda direction_dx_hi+256,y
 sta delta_x+1
 eor #$ff
 sta dir_x
 lda direction_dy_lo+256,y
 sta delta_y
 lda direction_dy_hi+256,y
 sta delta_y+1
 eor #$ff
 sta dir_y
 lda direction_sign+256,y
 sta dir_sign
load_direction_done:
 lda #0
 sta dir_x+1
 sta dir_y+1
 rts
'''
    return s

def simcode():
    s=(REF/'simulation.asm').read_text()
    start=s.index('input_normal:'); end=s.index('\ncollision_check:',start)
    s=s[:start]+'''input_normal:
.if AUTO_RUN
 jsr eg_nav_input
 rts
.else
 lda #0
 sta keys
 lda #3
 sta $e810
 lda $e812
 and #1
 bne input_no_w
 inc keys
input_no_w:
 lda #5
 sta $e810
 lda $e812
 and #1
 bne input_no_s
 lda keys
 ora #2
 sta keys
input_no_s:
 lda #4
 sta $e810
 lda $e812
 sta key_row
 and #1
 bne input_no_a
 lda keys
 ora #4
 sta keys
input_no_a:
 lda key_row
 and #2
 bne input_no_d
 lda keys
 ora #8
 sta keys
input_no_d:
 rts
.endif
'''+s[end:]
    s=s.replace('cmp #32','cmp #40')
    s=replace(s,' sta move_y\n lda keys\n',' sta move_y\n.if AUTO_RUN\n jsr nav_scale_speed\n.endif\n lda keys\n')
    start=s.index('collision_row:');end=s.index('\ncollision_blocked:',start)
    s=s[:start]+'''collision_row:
 tay
 lda world_row_lo,y
 sta collision_ptr
 lda world_row_hi,y
 sta collision_ptr+1
 ldy box_x0
 lda (collision_ptr),y
 jsr eg_collision_value
 bcs collision_blocked
 ldy box_x1
 lda (collision_ptr),y
 jsr eg_collision_value
 rts
'''+s[end:]
    return s

def tables(floor_style='dots'):
    w=module('pet_world',REF/'world.py')
    d=[]
    for a in range(512):
        x=math.sin(a*math.tau/512); y=math.cos(a*math.tau/512)
        dx=min(65535,round(256/abs(x))) if abs(x)>1e-10 else 65535
        dy=min(65535,round(256/abs(y))) if abs(y)>1e-10 else 65535
        d.append((dx&255,dx>>8,dy&255,dy>>8,(1 if x< -1e-10 else 0)|(2 if y< -1e-10 else 0)))
    src='*=$4000\n'
    for i,n in enumerate(('dx_lo','dx_hi','dy_lo','dy_hi','sign')):src+=emit('direction_'+n,[v[i] for v in d])
    offsets=[round(math.atan(((2*c+1)/40-1)*math.tan(math.pi/6))*512/math.tau) for c in range(40)]
    src+=emit('ray_offset_lo',offsets)+emit('ray_offset_hi',[v>>8 for v in offsets])
    src+=emit('ray_cos',[min(255,round(256*math.cos(v*math.tau/512))) for v in offsets])
    src+=emit('ray_cos_axis',[int(v==0) for v in offsets])
    for axis,n in ((math.sin,'x'),(math.cos,'y')):src+=emit('movement_'+n,[round(axis(a*math.tau/512)*6) for a in range(512)])
    src+=emit('nav_atan',[round(math.atan(v/128)*512/math.tau) for v in range(128)])
    src+=' .align 256\n'
    qs=[(i*i)//4 for i in range(512)]
    src+=emit('quarter_lo',qs)+emit('quarter_hi',[q>>8 for q in qs])
    f=40/math.tan(math.pi/6)
    top=[];bottom=[];door=[]
    for i in range(512):
        z=max(i/16,1/256)
        top.append(max(0,min(44,math.ceil(22-f/z-.5))))
        bottom.append(max(0,min(44,math.ceil(22+f/z-.5))))
        door.append(max(0,min(44,math.ceil(22-.5*f/z-.5))))
    src+=' .align 256\n'+emit('height_top',top)+emit('height_bottom',bottom)+emit('height_door',door)
    src+=emit('world_row_lo',[0x3000+40*i for i in range(40)])+emit('world_row_hi',[(0x3000+40*i)>>8 for i in range(40)])
    src+=emit('screen_row_lo',[0x3b00+120+40*i for i in range(22)])+emit('screen_row_hi',[(0x3b00+120+40*i)>>8 for i in range(22)])
    src+=emit('eg_perm_a',list(w.PERM_A))+emit('eg_perm_b',list(w.PERM_B))
    rom=ROM.read_bytes()
    if len(rom)!=2048:raise ValueError('PET_CHARGEN must contain exactly 2048 bytes')
    glyphs=[rom[i*8:i*8+8] for i in range(128)]
    glyphs += [bytes(b^255 for b in g) for g in glyphs]
    quadrant=[]
    for mask in range(16):
        g=bytes([((0xf0 if mask&1 else 0)|(15 if mask&2 else 0))]*4+[((0xf0 if mask&4 else 0)|(15 if mask&8 else 0))]*4)
        quadrant.append(glyphs.index(g))
    # Three clearly separated brightness levels: white wall 100%, side 50%,
    # dotted floor 6.25%. Floor glyph halves need not have equal patterns.
    floor_code={'dots':46,'sparse':58,'black':32,'checker':102}[floor_style]
    floor_glyph=glyphs[floor_code]
    top_patterns=[bytes(4),bytes([255]*4),floor_glyph[:4],bytes([85,170,85,170])]
    bottom_patterns=[bytes(4),bytes([255]*4),floor_glyph[4:],bytes([85,170,85,170])]
    # Exclude letter/punctuation substitutions at mixed edges. Only geometric
    # ROM graphics plus the deliberately selected floor glyph are candidates.
    candidates=sorted(set(quadrant+list(range(64,128))+list(range(192,256))+[floor_code]))
    palette=[]
    for a in range(4):
        for b in range(4):
            desired=top_patterns[a]+bottom_patterns[b]
            # Prioritize clean wall/sky edges over decorative floor dots.
            weights=[(1 if a==2 else 3)]*4+[(1 if b==2 else 3)]*4
            costs=[sum((x^y).bit_count()*w for x,y,w in zip(g,desired,weights)) for g in glyphs]
            wall_a=a in (1,3); wall_b=b in (1,3)
            if wall_a != wall_b:
                # Highlight a boundary without inventing pixels in the sky:
                # exact solid half-block over the covered half only.
                code=quadrant[3 if wall_a else 12]
            elif wall_a and a!=b:
                code=quadrant[15] # clean highlight at an internal shade transition
            else:
                code=min(candidates,key=lambda n:(costs[n],n))
            palette.append(code)
    src+=emit('quadrant_codes',quadrant)+emit('sample_codes',palette)
    packed=palette
    src+=emit('packed_sample_codes',packed)
    profiles=[];indices={}
    for shade in (1,3):
        profile_indices=[]
        for lo,hi in zip(top,bottom):
            samples=[0]*22+[2]*22
            samples[lo:hi]=[shade]*(hi-lo)
            if samples not in profiles:profiles.append(samples)
            profile_indices.append(profiles.index(samples))
        indices[shade]=profile_indices
    for i,values in enumerate(profiles):src+=emit(f'samples_profile_{i}',values)
    src+=' .align 256\n'
    for shade,name in ((1,'sample_profile'),(3,'dark_profile')):
        for prefix,plane in (('<','lo'),('>','hi')):
            src+=f'{name}_{plane}:\n'+''.join(' .byte '+','.join(f'{prefix}samples_profile_{v}' for v in indices[shade][i:i+16])+'\n' for i in range(0,512,16))
    src+='door_shade: .fill 320,0\n'
    src+='tables_end:\n .cerror * > $8000, "PET tables overflow 32 KB"\n'
    assert glyphs[palette[15]]==top_patterns[3]*2 and palette[15]==230
    assert palette[10]==floor_code
    return src,dict(offsets=offsets,quadrant=quadrant,sampleCodes=palette,sampleProfiles=len(profiles),darkWallCode=palette[15],darkWallWhiteCoverage=.5,floorCode=floor_code,floorWhiteCoverage=sum(v.bit_count() for v in floor_glyph)/64,edgePolicy='exact solid half-block highlights; no glyph approximation at wall/sky or wall/floor boundaries',
                    heightTop=top,heightBottom=bottom,heightDoor=door,directions=d)

def main():
    p=argparse.ArgumentParser();p.add_argument('--run',choices=('auto','interactive'),default='auto');p.add_argument('--out',type=Path,required=True)
    p.add_argument('--seed',type=lambda s:int(s,0),default=0x251c2026)
    a=p.parse_args();out=a.out.resolve()
    if not 0<=a.seed<=0xffffffff:p.error('Seed must be an unsigned 32-bit integer')
    assembler=os.environ.get('TASS64_EXE') or shutil.which('64tass')
    if not assembler:p.error('64tass absent: add it to PATH or set TASS64_EXE')
    if out.exists():p.error('Output must be a new directory')
    out.mkdir(parents=True)
    world=(REF/'world-runtime.asm').read_text()
    # No VIC/CIA access retained even in the inactive entropy branch.
    start=world.index('.else\n',world.index('eg_init:'));end=world.index('.endif',start)
    world=world[:start]+'''.else
 lda $e844
 sta eg_seed
 lda $e845
 sta eg_seed+1
 lda $e848
 sta eg_seed+2
 lda $e849
 sta eg_seed+3
'''+world[end:]
    t,meta=tables()
    runtime=(ROOT/'src/pet-runtime.asm').read_text()
    copy=' ldy #0\n'+''.join(f' lda (line_ptr),y\n sta column_samples+{i}\n'+(' iny\n' if i<43 else '') for i in range(44))
    stores=' ldx column\n'+''.join(f' lda column_samples+{row*2}\n asl\n asl\n ora column_samples+{row*2+1}\n tay\n lda packed_sample_codes,y\n sta back_screen+{120+row*40},x\n' for row in range(22))
    runtime=replace(runtime,'__COPY_COLUMN__',copy)
    runtime=replace(runtime,'__STORE_COLUMN__',stores)
    code=f''' .cpu "6502"
AUTO_RUN={int(a.run=='auto')}
WORLD_FIXED_SEED=${a.seed:08x}
WORLD_SIZE=40
WORLD_CENTRE=20
WORLD_MAP=$3000
INITIAL_X=$1480
INITIAL_Y=$1480
INITIAL_ANGLE=0
*=$0401
 .word basic_end
 .word 10
 .byte $9e
 .text "4096"
 .byte 0
basic_end: .word 0
*=$1000
'''+runtime+raycode()+simcode()+world+(REF/'world-navigation.asm').read_text()+'''
code_end:
 .cerror * > $3000, "PET code overlaps map"
*=$3000
 .fill 1600,0
*=$3700
ray_t_lo: .fill 40,0
ray_t_hi: .fill 40,0
depth_lo: .fill 40,0
depth_hi: .fill 40,0
ray_mat: .fill 40,0
ray_side: .fill 40,0
ray_steps: .fill 40,0
ray_doors: .fill 40,0
door_top: .fill 320,0
door_bottom: .fill 320,0
 .cerror * > $3b00, "PET descriptors overlap back screen"
*=$3b00
back_screen: .fill 1000,32
 .cerror * > $4000, "PET screen overflow"
'''+t
    source=out/'pet.asm';source.write_text(code)
    cmd=[assembler,'-a','-B','--m6502','--vice-labels-numeric',f'--labels={out}/labels.txt',f'--list={out}/listing.txt',f'--map={out}/memory.map','-o',str(out/'pet.prg'),str(source)]
    r=subprocess.run(cmd,capture_output=True,text=True);(out/'assembler.log').write_text(r.stdout+r.stderr)
    if r.returncode:raise RuntimeError(r.stdout+r.stderr)
    labels={line.split()[2].lstrip('.'):int(line.split()[1],16) for line in (out/'labels.txt').read_text().splitlines() if line.startswith('al ')}
    meta.update(run=a.run,seed=a.seed,audio=False,labels=labels,prgSHA256=hashlib.sha256((out/'pet.prg').read_bytes()).hexdigest().upper(),
                memory=dict(codeAndState=labels['code_end']-0x1000,map=1600,descriptorAllocated=1024,backScreen=1000,tables=labels['tables_end']-0x4000,freeTop=0x8000-labels['tables_end']))
    (out/'build.json').write_text(json.dumps(meta,indent=2)+'\n');print(json.dumps(meta['memory']));print(out/'pet.prg')

if __name__=='__main__':main()
