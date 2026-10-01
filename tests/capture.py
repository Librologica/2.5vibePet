"""Real xpet execution, emulated-cycle timings; no host speed measurements."""
import argparse,json,os,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def run(build,tag,cycles,frames,standard='pal',audio=False,extra=(),sweep=False,override=None):
    build=Path(build).resolve(); out=Path(os.environ.get('PET_TEST_OUT',ROOT/'artifacts'))/'vice'/tag;out.mkdir(parents=True,exist_ok=False)
    labels=json.loads((build/'build.json').read_text())['labels']; fc=labels['frame_count']
    phases=['render_frame_begin','geometry_done','render_frame_end','presentation_done']
    lines=[f'logname "{out.as_posix()}/trace.log"','log on','disable 1','sidefx off',f'load_labels "{build.as_posix()}/labels.txt"']
    lines+=['trace exec .'+n for n in phases]
    # VICE 3.10 does not recognize the stock 60 Hz editor for autostart.
    # Let ROM initialization reach its first IRQ, then load at the PRG address.
    # Both qualified BASIC4 editor ROMs have the IRQ prologue at $E442.
    if standard=='ntsc':
        lines += [f'load "{build.as_posix()}/pet.prg" 0', 'r SP=$ff', 'r PC=$1000']
    for idx,frame in enumerate(frames,2+len(phases)):
        stem=f'frame-{frame:04d}'
        capture=[f'bsave "{out.as_posix()}/{stem}-ram.bin" 0 $0000 $7fff',f'bsave "{out.as_posix()}/{stem}-screen.bin" 0 $8000 $83ff',f'bsave "{out.as_posix()}/{stem}-via.bin" 0 $e840 $e84f',f'bsave "{out.as_posix()}/{stem}-pia.bin" 0 $e810 $e813',f'disable {idx}','x']
        (out/f'{stem}.mon').write_text('\n'.join(capture)+'\n')
        lines+=[f'break exec .presentation_done if (@cpu:${fc:04x} == ${frame&255:02x}) && (@cpu:${fc+1:04x} == ${frame>>8:02x})',f'command {idx} "playback \\"{out.as_posix()}/{stem}.mon\\""']
    if override is not None:
        assert not sweep,'Override and pose sweep are separate contracts'
        idx=2+len(phases)+len(frames);patch=out/'override.mon'
        patch.write_text(f'> ${labels["input_override"]:04x} ${override:02x}\ndisable {idx}\nx\n')
        lines+=[f'break exec .main_loop',f'command {idx} "playback \\"{patch.as_posix()}\\""']
    if sweep:
        angles=[0,1,63,64,127,128,129,191,192,255,256,257,319,320,383,384,385,447,448,511]
        assert len(frames)==len(angles),'Sweep requires exactly 20 frames'
        for idx,(frame,angle) in enumerate(zip(frames,angles),2+len(phases)+len(frames)):
            pose=labels['pose_x']; patch=out/f'pose-{frame:04d}.mon'
            fraction=(48,128,208)[(frame-1)%3]
            patch.write_text(f'> ${pose:04x} ${fraction:02x} $14 ${fraction:02x} $14 ${angle&255:02x} ${angle>>8:02x}\ndisable {idx}\nx\n')
            lines+=[f'break exec .render_frame_begin if (@cpu:${fc:04x} == ${(frame-1)&255:02x}) && (@cpu:${fc+1:04x} == ${(frame-1)>>8:02x})',f'command {idx} "playback \\"{patch.as_posix()}\\""']
    lines+=list(extra)+['x']; (out/'run.mon').write_text('\n'.join(lines)+'\n')
    exe=os.environ.get('XPET_EXE') or shutil.which('xpet'); assert exe,'xpet absent'
    assert standard in ('pal','ntsc'),'Standard must be pal or ntsc'
    editor_name='edit-4-40-n-50Hz.901498-01.bin' if standard=='pal' else 'edit-4-40-n-60Hz.901499-01.bin'
    editor=Path(os.environ.get('PET_EDITOR_'+standard.upper(),Path(exe).resolve().parent.parent/'PET'/editor_name))
    assert editor.is_file(),f'Set PET_EDITOR_{standard.upper()} to installed {editor_name}'
    cmd=[exe,'-default','+confirmonexit','-console','-logfile',str(out/'vice.log'),'-model','4032','-'+standard,'-editor',str(editor),'-CRTCfilter','0','-autostartprgmode','1','-initbreak','0xe442' if standard=='ntsc' else '0x1000','-moncommands',str(out/'run.mon'),'-limitcycles',str(cycles),'-exitscreenshot',str(out/'screen.png')]
    if audio:cmd+=['+warp','-sound','-soundrecdev','wav','-soundrecarg',str(out/'sound.wav')]
    else:cmd+=['-warp','+sound']
    if standard!='ntsc':cmd+=[str(build/'pet.prg')]
    startup=None
    if os.name=='nt':
        startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    r=subprocess.run(cmd,cwd=out,capture_output=True,timeout=180,startupinfo=startup)
    (out/'console.log').write_bytes(r.stdout+r.stderr);(out/'run.json').write_text(json.dumps(dict(command=cmd,returncode=r.returncode),indent=2))
    print(out,r.returncode,flush=True)
    if not (out/'trace.log').exists():raise RuntimeError((out/'vice.log').read_text(errors='replace')[-6000:] if (out/'vice.log').exists() else (r.stdout+r.stderr).decode(errors='replace')[-6000:])
    return out

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);p.add_argument('--tag',required=True);p.add_argument('--cycles',type=int,default=6000000);p.add_argument('--frames',default='1,2,10');p.add_argument('--standard',default='pal');p.add_argument('--audio',action='store_true');p.add_argument('--sweep',action='store_true');p.add_argument('--override',type=int);a=p.parse_args()
    run(a.build,a.tag,a.cycles,[int(s) for s in a.frames.split(',') if s],a.standard,a.audio,sweep=a.sweep,override=a.override)
