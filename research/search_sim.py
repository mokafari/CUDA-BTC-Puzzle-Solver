import random,subprocess,re,os,sys
from concurrent.futures import ThreadPoolExecutor
random.seed(7)
def run(cfg,trials):
    N,J,mm,sp,TS,JD,TW=cfg
    env={**os.environ,'TS':str(TS),'JD':str(JD),'TW':str(TW)}
    o=subprocess.run(['/tmp/sim','1','30',str(N),str(mm),str(trials),str(J),str(sp),'1'],capture_output=True,text=True,env=env).stdout
    m=re.search(r'meanK=([\d.]+) median=([\d.]+).*fails=(\d+)',o); return (float(m[1]),float(m[2]),int(m[3])) if m else (9,9,999)
cfgs=[(random.choice([64,128,256,512,1024]),random.choice([128,512,2048,4096]),round(random.uniform(.1,.6),2),round(random.choice([.02,.1,.3,.6,1.0]),2),random.choice([.5,.7,1,1.4,2]),random.choice([0,1]),random.choice([.4,.45,.5])) for _ in range(48)]
with ThreadPoolExecutor(4) as ex: res=list(ex.map(lambda c:run(c,250),cfgs))
top=sorted(zip(res,cfgs))[:5]
print('screen top5:'); [print(r,c) for r,c in top]
base=(256,512,.3,.1,1,0,.5); print('confirm (1500 trials):')
with ThreadPoolExecutor(4) as ex: conf=list(ex.map(lambda c:run(c,1500),[c for _,c in top]+[base]))
for c,r in zip([c for _,c in top]+[base],conf): print(r,c)
