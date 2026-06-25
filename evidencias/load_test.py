import sys,time,threading,urllib.request
url=sys.argv[1]; dur=int(sys.argv[2]); conc=int(sys.argv[3])
stop=time.time()+dur; c=[0]
def w():
    while time.time()<stop:
        try:
            urllib.request.urlopen(url,timeout=5).read(); c[0]+=1
        except Exception: pass
ts=[threading.Thread(target=w) for _ in range(conc)]
for t in ts: t.start()
for t in ts: t.join()
print("total requests:",c[0])
