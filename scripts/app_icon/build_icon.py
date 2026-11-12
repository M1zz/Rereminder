import math, json, os, sys
out=sys.argv[1]; os.makedirs(out+'/Assets',exist_ok=True)
C=512; R=368; LW=106; Rm=R-LW/2; Ri=R-LW
BLUE='#0A84FF'; GREEN='#30D158'; PURPLE='#BF5AF2'
b1,b2=1/15,5/15
def pt(f,r):
    a=math.radians(f*360-90); return C+r*math.cos(a), C+r*math.sin(a)
def sector(f0,f1,cap0,cap1):
    """12시에서 시계 방향 f0→f1 의 고리 조각. cap 이 참인 끝은 반원으로 둥글린다."""
    large=1 if (f1-f0)>0.5 else 0
    ox0,oy0=pt(f0,R); ox1,oy1=pt(f1,R); ix1,iy1=pt(f1,Ri); ix0,iy0=pt(f0,Ri)
    d=f'M{ox0:.2f} {oy0:.2f}A{R} {R} 0 {large} 1 {ox1:.2f} {oy1:.2f}'
    d+= f'A{LW/2} {LW/2} 0 0 1 {ix1:.2f} {iy1:.2f}' if cap1 else f'L{ix1:.2f} {iy1:.2f}'
    d+=f'A{Ri} {Ri} 0 {large} 0 {ix0:.2f} {iy0:.2f}'
    d+= f'A{LW/2} {LW/2} 0 0 1 {ox0:.2f} {oy0:.2f}' if cap0 else ''
    return d+'Z'
def circle(cx,cy,r):
    return f'M{cx-r:.2f} {cy:.2f}A{r} {r} 0 1 0 {cx+r:.2f} {cy:.2f}A{r} {r} 0 1 0 {cx-r:.2f} {cy:.2f}Z'
def bell(cx,cy,s):
    d =f'M{cx-s*0.5:.2f} {cy-s*0.12:.2f}A{s*0.5:.2f} {s*0.5:.2f} 0 0 1 {cx+s*0.5:.2f} {cy-s*0.12:.2f}'
    d+=f'L{cx+s*0.66:.2f} {cy+s*0.34:.2f}Q{cx+s*0.74:.2f} {cy+s*0.46:.2f} {cx+s*0.6:.2f} {cy+s*0.46:.2f}'
    d+=f'L{cx-s*0.6:.2f} {cy+s*0.46:.2f}Q{cx-s*0.74:.2f} {cy+s*0.46:.2f} {cx-s*0.66:.2f} {cy+s*0.34:.2f}Z'
    d+=circle(cx,cy+s*0.58,s*0.16)+circle(cx,cy-s*0.66,s*0.1)
    return d
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">{body}</svg>'
def w(name,body): open(f'{out}/Assets/{name}','w').write(svg(body))
# 링: 남은 시간 좌표. 0~1분 보라, 1~5분 초록, 5~15분 파랑
w('ring.svg', f'<path d="{sector(b2,1,False,True)}" fill="{BLUE}"/><path d="{sector(b1,b2,False,False)}" fill="{GREEN}"/><path d="{sector(0,b1,True,False)}" fill="{PURPLE}"/>')
# 종: 흰 노브 + 그 종이 끝내는 구간의 색
kr=LW*0.80; body=''
for f,col in ((b2,BLUE),(b1,GREEN)):
    x,y=pt(f,Rm); body+=f'<path d="{circle(x,y,kr)}" fill="#FFFFFF"/><path d="{bell(x,y-kr*0.02,kr*0.6)}" fill="{col}"/>'
w('bells.svg',body)
digits=open('digits.path').read().strip()
w('digits.svg',f'<path d="{digits}" fill="#14161F"/>')
w('digits-dark.svg',f'<path d="{digits}" fill="#FFFFFF"/>')
def grad(a,b): return {"linear-gradient":[a,b],"orientation":{"start":{"x":0.5,"y":0.0},"stop":{"x":0.5,"y":1.0}}}
def group(name,layers,trans,shadow=0.5):
    return {"layers":layers,"lighting":"individual","name":name,"shadow":{"kind":"neutral","opacity":shadow},
            "specular":True,"translucency":{"enabled":trans>0,"value":trans if trans>0 else 0.35}}
doc={"color-space-for-untagged-svg-colors":"display-p3",
 "fill-specializations":[
   {"value":grad("display-p3:1.00000,1.00000,1.00000,1.00000","display-p3:0.90588,0.92157,0.96471,1.00000")},
   {"appearance":"dark","value":grad("display-p3:0.07843,0.09020,0.15686,1.00000","display-p3:0.01569,0.01961,0.04314,1.00000")}],
 "groups":[
   group("Bells",[{"glass":True,"image-name-specializations":[{"value":"bells.svg"}],"name":"Bells"}],0),
   group("Time",[{"glass":True,"image-name-specializations":[{"value":"digits.svg"},{"appearance":"dark","value":"digits-dark.svg"},{"appearance":"tinted","value":"digits-dark.svg"}],"name":"Time"}],0,0.0),
   group("Ring",[{"glass":True,"image-name-specializations":[{"value":"ring.svg"}],"name":"Ring"}],0.3)],
 "supported-platforms":{"squares":"shared"}}
open(out+'/icon.json','w').write(json.dumps(doc,indent=2))
