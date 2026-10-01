"""Public runner: always qualify a temporary SDK copy, never the frozen source."""
import argparse,hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
def command(cwd,*args):
    subprocess.run([sys.executable,'-B',*map(str,args)],cwd=cwd,check=True)
def main():
    p=argparse.ArgumentParser();p.add_argument('--emulator',action='store_true');a=p.parse_args()
    command(ROOT,'tests/release_contract.py')
    work=Path(tempfile.mkdtemp(prefix='25vibePet-qualification-'));sdk=work/'sdk'
    shutil.copytree(ROOT,sdk,ignore=shutil.ignore_patterns('.git','artifacts','__pycache__'))
    print('Qualification copy:',sdk,flush=True)
    command(sdk,'tests/contracts.py')
    for run in ('auto','interactive'):
        build=sdk/'artifacts'/run
        command(sdk,'build.py','--run',run,'--out',build)
        assert (build/'pet.prg').read_bytes()==(sdk/'demos'/f'infinite-{run}.prg').read_bytes(),run
    print('PASS auto/interactive byte-exact rebuilds',flush=True)
    if a.emulator:
        assert os.environ.get('XPET_EXE') or shutil.which('xpet'),'xpet absent: emulator qualification BLOCKED'
        for standard in ('pal','ntsc'):
            build=sdk/'artifacts/auto';tag=f'final-{standard}'
            command(sdk,'tests/capture.py','--build',build,'--tag',tag,'--standard',standard,'--cycles','38000000','--frames',','.join(map(str,range(1,121))))
            capture=sdk/'artifacts/vice'/tag
            command(sdk,'tests/verify.py','--build',build,'--capture',capture)
            command(sdk,'tests/report.py','--build',build,'--capture',capture)
        build=sdk/'artifacts/interactive'
        for override in (1,2,4,8):
            tag=f'input-{override}'
            command(sdk,'tests/capture.py','--build',build,'--tag',tag,'--override',override,'--cycles','8000000','--frames','1,2,3,4')
            command(sdk,'tests/verify.py','--build',build,'--capture',sdk/'artifacts/vice'/tag)
        command(sdk,'tests/capture.py','--build',build,'--tag','angles','--sweep','--cycles','12000000','--frames',','.join(map(str,range(1,21))))
        command(sdk,'tests/verify.py','--build',build,'--capture',sdk/'artifacts/vice/angles')
        print('PASS actual emulator frame/numeric contracts; physical hardware NOT TESTED')
    else:print('NOT RUN: emulator tests (use --emulator); physical hardware NOT TESTED')
    command(ROOT,'tests/release_contract.py')
    print('Artifacts retained:',work)
if __name__=='__main__':main()
