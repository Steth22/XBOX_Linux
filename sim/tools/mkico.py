import sys
from PIL import Image, ImageDraw
src=Image.open(sys.argv[1]).convert('RGBA')
px=src.load()
for y in range(src.size[1]):
    for x in range(src.size[0]):
        r,g,b,a=px[x,y];m=max(r,g,b)
        px[x,y]=(r,g,b,0 if m<40 else (255 if m>90 else int((m-40)*5.1)))
# crop to content
bbox=src.getbbox();src=src.crop(bbox)
S=512
bg=Image.new('RGBA',(S,S),(0,0,0,0))
d=ImageDraw.Draw(bg)
d.rounded_rectangle([0,0,S-1,S-1],radius=110,fill=(11,18,32,255))
w,h=src.size;sc=min(S*0.72/w,S*0.72/h);src=src.resize((int(w*sc),int(h*sc)),Image.LANCZOS)
bg.alpha_composite(src,((S-src.size[0])//2,(S-src.size[1])//2))
bg.save(sys.argv[2],sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
bg.resize((256,256),Image.LANCZOS).save(sys.argv[2].replace('.ico','.png'))
print('icon ok')
