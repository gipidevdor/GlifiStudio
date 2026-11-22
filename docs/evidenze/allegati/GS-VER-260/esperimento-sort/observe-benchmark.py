#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
"""Compare frozen binaries through the same public Core summarize API."""
from pathlib import Path
import datetime,hashlib,json,subprocess,sys,time,os
ROOT=Path(os.environ['GLIFI_SORT_EVIDENCE_DIRECTORY'])
WORK=Path(os.environ['GLIFI_SORT_WORKTREE'])

def snapshot(owned_root=None):
    rows=[]
    for line in subprocess.check_output(['ps','-axo','pid=,ppid=,%cpu=,etime=,stat=,comm='],text=True).splitlines():
        parts=line.split(None,5)
        if len(parts)==6:
            pid,ppid,cpu,elapsed,state,command=parts
            rows.append({'pid':int(pid),'ppid':int(ppid),'cpu':float(cpu),'elapsed':elapsed,'state':state,'executable':Path(command).name})
    owned=set() if owned_root is None else {owned_root}
    while True:
        before=len(owned)
        owned.update(row['pid'] for row in rows if row['ppid'] in owned)
        if before==len(owned): break
    names={'xcodebuild','swift-build','swift-test','swift-run','swift-frontend','swiftc','swift-driver','clang','clang++','ld','metal','metallib','coremlc','GlifiBenchmark','GlifiBenchmark-native','GlifiBenchmark-reference','xctest'}
    external=[row for row in rows if row['pid'] not in owned and 'Z' not in row['state']]
    relevant=[row for row in external if row['executable'] in names or row['executable'].startswith(('GlifiCorePackageTests','GlifiKitPackageTests'))]
    return {'observedAtUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'externalRelevantProcesses':[{'processName':row['executable'],'PID':row['pid'],'CPU':row['cpu']} for row in relevant],'sanitization':'Only relevant processName/PID/CPU retained; no command lines, paths or unrelated top-CPU list.'}

def probe(label='binary-quiescence-probe'):
    rows=[]
    for _ in range(11):
        rows.append(snapshot())
        time.sleep(0.5)
    ROOT.joinpath(label+'.json').write_text(json.dumps(rows,indent=2)+'\n')
    return all(not row['externalRelevantProcesses'] for row in rows)

if sys.argv[1]=='probe':
    print(json.dumps({'quietForAllSamples':probe()}));sys.exit(0)
role,label=sys.argv[1:3]
assert role in {'reference','native'}
binary=ROOT/'binaries'/('GlifiBenchmark-'+role)
args=['--apple-descriptive-sort','--candidate-only',*sys.argv[3:]]
observations=[snapshot()]
with ROOT.joinpath(label+'.json').open('w') as out, ROOT.joinpath(label+'-time.txt').open('w') as err:
    child=subprocess.Popen(['/usr/bin/time','-l',str(binary),*args],cwd=WORK,stdout=out,stderr=err)
    print(json.dumps({'binaryRole':role,'benchmarkPID':child.pid,'label':label}),flush=True)
    while child.poll() is None:
        observations.append(snapshot(child.pid));time.sleep(0.5)
    code=child.returncode
observations.append(snapshot())
ROOT.joinpath(label+'-processes.json').write_text(json.dumps(observations,indent=2)+'\n')
assessment={'label':label,'binaryRole':role,'binarySHA256':hashlib.sha256(binary.read_bytes()).hexdigest(),'runnerArgumentMeaning':'--candidate-only invokes the same public GlifiDescriptiveStatistics.summarize API in both executables; binaryRole selects the frozen pre-patch or Accelerate implementation','exitCode':code,'contentionObserved':any(row['externalRelevantProcesses'] for row in observations),'observationCount':len(observations)}
if code==0:
    report=json.loads(ROOT.joinpath(label+'.json').read_text())
    assessment['sourceHashes']=report['sourceHashes']
    assessment['allResultsMatchReferenceBitwise']=all(row['allResultsMatchReferenceBitwise'] for row in report['measurements'])
    assessment['cases']=[{'identifier':row['identifier'],'inputSHA256':row['inputSHA256'],'outputSHA256':row['outputSHA256'],'medianSeconds':row['candidate']['medianSeconds'],'minimumSeconds':row['candidate']['minimumSeconds'],'maximumSeconds':row['candidate']['maximumSeconds'],'rawSeconds':row['candidate']['rawSeconds']} for row in report['measurements']]
ROOT.joinpath(label+'-assessment.json').write_text(json.dumps(assessment,indent=2)+'\n')
print(json.dumps(assessment),flush=True)
sys.exit(code)
