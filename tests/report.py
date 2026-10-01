"""Summarize emulated cycles from public PET captures."""
import array,hashlib,json,math,re,statistics,sys,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def profile(build,capture):
    m=json.loads((build/'build.json').read_text());addr={m['labels'][n]:n for n in ('render_frame_begin','geometry_done','render_frame_end','presentation_done')}
    events=[]
    for line in (capture/'trace.log').read_text().splitlines():
        match=re.match(r'\.C:([0-9a-fA-F]{4}).*?\s+(\d+)\s*$',line)
        if match and int(match[1],16) in addr:events.append((int(match[2]),addr[int(match[1],16)]))
    # Monitor captures and trace points can log the same presentation twice.
    events=list(dict.fromkeys(events)); first=next(c for c,n in events if n=='render_frame_begin')
    lo=first+2_000_000;hi=lo+20_000_000
    presents=[c for c,n in events if n=='presentation_done' and lo<=c<hi]
    intervals=[b-a for a,b in zip(presents,presents[1:])]
    phases={n:[] for n in ('geometry','composition','presentation')};frame={};frames=[]
    for c,n in events:
        if n=='render_frame_begin':frame={'begin':c}
        elif frame:
            frame[n]=c
            if n=='presentation_done' and lo<=c<hi and 'render_frame_end' in frame:
                phases['geometry'].append(frame['geometry_done']-frame['begin'])
                phases['composition'].append(frame['render_frame_end']-frame['geometry_done'])
                phases['presentation'].append(c-frame['render_frame_end'])
                frames.append(frame)
    assert hi<=max(c for c,n in events),'Benchmark shorter than 20 s + 2 s warm-up'
    report=dict(emulator='VICE 3.10 xpet PET4032, 6502 1 MHz',method='Emulated CPU cycles, UI active, three-tone readability + exact boundary highlights, audio absent',windowStartCycles=lo,windowEndCycles=hi,completeViews=len(presents),fps=len(presents)/20,
                intervalMean=statistics.mean(intervals),intervalMedian=statistics.median(intervals),intervalP95=sorted(intervals)[math.ceil(.95*len(intervals))-1],intervalWorst=max(intervals),
                phaseMean={k:statistics.mean(v) for k,v in phases.items()})
    if (capture/'verification.json').exists():
        v=json.loads((capture/'verification.json').read_text())['results']
        report['meanDdaSteps']=statistics.mean(x['ddaSteps'] for x in v);report['observedStreamShifts']=v[-1]['streamShifts'];report['observedRooms']=v[-1]['rooms']
    (capture/'benchmark.json').write_text(json.dumps(report,indent=2));return report

def silence(capture):
    with wave.open(str(capture/'sound.wav')) as w:
        rate=w.getframerate();channels=w.getnchannels();pcm=w.readframes(w.getnframes());seconds=w.getnframes()/rate
    values=array.array('h',pcm)
    if sys.byteorder!='little':values.byteswap()
    # VICE's integer audio filter leaves a constant +3 LSB DC residual.
    # Require a constant signal, not a relaxed threshold on oscillating audio.
    assert values and len(set(values))==1 and abs(values[0])<=3,'Unexpected CB2 waveform'
    result=dict(recording='Actual xpet output with emulator sound enabled',seconds=seconds,rate=rate,dcSample=values[0],peakAC=0,result='PASS: no sound waveform; constant emulator DC only')
    (capture/'silence.json').write_text(json.dumps(result,indent=2));return result

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);p.add_argument('--capture',type=Path,required=True);p.add_argument('--silence',action='store_true');a=p.parse_args()
    print(json.dumps(silence(a.capture) if a.silence else profile(a.build,a.capture),indent=2))
