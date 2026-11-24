"""Builds "Urax Display", the UraxOS brand display font (Latin caps, digits, punctuation).

Monoline rounded strokes (echoing the bold rounded U of the logo) defined as skeletons, offset with
round caps/joins, converted to TrueType outlines. Lowercase maps to the same capitals (display style).
The period is a four-point sparkle, the logo's signature shape.
Arabic text uses Cairo as the fallback. Run: python3 tools/build_font.py
"""
import math, os, sys
from shapely.geometry import LineString, Polygon
from shapely.ops import unary_union
from shapely.geometry.polygon import orient
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

R = 62          # half stroke width (stroke = 124 units)
SB = 46         # side bearing beyond stroke
UPM = 1000

def arc(cx, cy, rx, ry, a0, a1, n=28):
    return [(cx + rx*math.cos(math.radians(a0 + (a1-a0)*i/n)),
             cy + ry*math.sin(math.radians(a0 + (a1-a0)*i/n))) for i in range(n+1)]

def ell(cx, cy, rx, ry): return arc(cx, cy, rx, ry, 90, 450, 48)
def join(*parts):
    out = []
    for p in parts: out += p
    return out

def bowl_p(): return join([(0,700),(270,700)], arc(270,520,270-270+190,180,90,-90,24), [(270,340),(0,340)])
G = {}
G['A'] = [[(0,0),(250,700),(500,0)], [(95,235),(405,235)]]
G['B'] = [[(0,0),(0,700)], join([(0,700),(280,700)], arc(280,525,175,175,90,-90), [(280,350),(0,350)]),
          join([(0,350),(300,350)], arc(300,175,175,175,90,-90), [(300,0),(0,0)])]
G['C'] = [arc(250,350,250,350,45,315,40)]
G['D'] = [[(0,0),(0,700)], join([(0,700),(190,700)], arc(190,350,300,350,90,-90,36), [(190,0),(0,0)])]
G['E'] = [[(500,700),(0,700),(0,0),(500,0)], [(0,350),(380,350)]]
G['F'] = [[(500,700),(0,700),(0,0)], [(0,350),(380,350)]]
G['G'] = [arc(250,350,250,350,40,360,44), [(500,350),(280,350)]]
G['H'] = [[(0,0),(0,700)], [(500,0),(500,700)], [(0,350),(500,350)]]
G['I'] = [[(0,0),(0,700)]]
G['J'] = [join([(450,700),(450,200)], arc(250,200,200,200,0,-180,28), [(50,260)])]
G['K'] = [[(0,0),(0,700)], [(480,700),(0,260)], [(130,380),(500,0)]]
G['L'] = [[(0,700),(0,0),(450,0)]]
G['M'] = [[(0,0),(0,700),(280,250),(560,700),(560,0)]]
G['N'] = [[(0,0),(0,700),(480,0),(480,700)]]
G['O'] = [ell(250,350,250,350)]
G['P'] = [[(0,0),(0,700)], join([(0,700),(280,700)], arc(280,515,185,185,90,-90), [(280,330),(0,330)])]
G['Q'] = [ell(250,350,250,350), [(310,170),(520,-40)]]
G['R'] = [[(0,0),(0,700)], join([(0,700),(280,700)], arc(280,515,185,185,90,-90), [(280,330),(0,330)]), [(230,330),(500,0)]]
G['S'] = [join(arc(250,525,235,175,25,270,30), arc(250,175,235,175,90,-155,36))]
G['T'] = [[(0,700),(500,700)], [(250,700),(250,0)]]
G['U'] = [join([(0,700),(0,250)], arc(250,250,250,250,180,360,32), [(500,700)])]
G['V'] = [[(0,700),(250,0),(500,700)]]
G['W'] = [[(0,700),(140,0),(280,500),(420,0),(560,700)]]
G['X'] = [[(0,0),(500,700)], [(0,700),(500,0)]]
G['Y'] = [[(0,700),(250,360),(500,700)], [(250,360),(250,0)]]
G['Z'] = [[(0,700),(500,700),(0,0),(500,0)]]
G['0'] = [ell(250,350,250,350)]
G['1'] = [[(40,560),(250,700),(250,0)]]
G['2'] = [join(arc(250,500,230,200,165,-40,30), [(0,0),(500,0)])]
G['3'] = [join(arc(250,525,215,175,150,-90,30), arc(250,175,245,175,90,-150,32))]
G['4'] = [[(380,0),(380,700),(0,200),(520,200)]]
G['5'] = [join([(460,700),(60,700),(47,345)], arc(250,230,235,230,150,-150,36))]
G['6'] = [ell(250,235,240,235), join([(10,235),(10,400)], arc(250,400,240,300,180,60,24))]
G['7'] = [[(0,700),(500,700),(150,0)]]
G['8'] = [ell(250,540,200,160), ell(250,175,235,175)]
G['9'] = [ell(250,465,240,235), join([(490,465),(490,300)], arc(250,300,240,300,0,-120,24))]
G[','] = [[(60,40),(0,-140)]]
G[':'] = [ell(0,0,1,1), ell(0,440,1,1)]
G['-'] = [[(0,320),(300,320)]]
G['_'] = [[(0,-60),(500,-60)]]
G['='] = [[(0,240),(420,240)], [(0,440),(420,440)]]
G['+'] = [[(0,350),(400,350)], [(200,150),(200,550)]]
G['!'] = [[(0,700),(0,240)], ell(0,0,1,1)]
G['?'] = [join(arc(230,520,215,180,160,-50,26), [(230,340),(230,240)]), ell(230,0,1,1)]
G["'"] = [[(0,700),(0,500)]]
G['"'] = [[(0,700),(0,520)], [(150,700),(150,520)]]
G['/'] = [[(0,0),(320,700)]]
G['('] = [arc(260,350,260,450,100,260,24)]
G[')'] = [arc(0,350,260,450,80,-80,24)]
G['•'] = [ell(0,350,1,1)]

def sparkle(cx, cy, ro=135, ri=44):
    pts = []
    for i in range(8):
        a = math.radians(90 + i*45); r = ro if i % 2 == 0 else ri
        pts.append((cx + r*math.cos(a), cy + r*math.sin(a)))
    return Polygon(pts)

def glyph_geom(name):
    shapes = []
    for s in G[name]:
        pts = s if len(s) > 1 else s*2
        if len(set(pts)) == 1: pts = [pts[0], (pts[0][0]+0.01, pts[0][1])]
        shapes.append(LineString(pts).buffer(R, quad_segs=10, cap_style='round', join_style='round'))
    return unary_union(shapes)

def to_glyph(geom, lsb_to=None):
    minx, miny, maxx, maxy = geom.bounds
    dx = SB + R - minx - R + 0   # place leftmost outline at SB
    dx = SB - minx
    from shapely.affinity import translate
    g = translate(geom, xoff=dx, yoff=R)   # lift so skeleton y=0 -> y=R, baseline at outline bottom
    adv = int(round(maxx - minx + 2*SB))
    pen = TTGlyphPen(None)
    polys = list(g.geoms) if g.geom_type == 'MultiPolygon' else [g]
    for p in polys:
        p = orient(p, sign=-1.0)
        for ring in [p.exterior] + list(p.interiors):
            c = [(int(round(x)), int(round(y))) for x, y in ring.coords[:-1]]
            pen.moveTo(c[0]); [pen.lineTo(q) for q in c[1:]]; pen.closePath()
    return pen.glyph(), adv

order = ['.notdef', 'space']
glyphs, adv = {}, {}
empty = TTGlyphPen(None).glyph()
glyphs['.notdef'], adv['.notdef'] = to_glyph(glyph_geom('O'))[0], 640
glyphs['space'], adv['space'] = empty, 320
cmap = {32: 'space'}
NAMES = {',':'comma',':':'colon','-':'hyphen','_':'underscore','=':'equal','+':'plus','!':'exclam','?':'question',
         "'":'quotesingle','"':'quotedbl','/':'slash','(':'parenleft',')':'parenright','•':'bullet'}
for ch in G:
    nm = NAMES.get(ch, ch if ch.isalpha() and ch.isupper() else {'0':'zero','1':'one','2':'two','3':'three','4':'four','5':'five','6':'six','7':'seven','8':'eight','9':'nine'}.get(ch, ch))
    glyphs[nm], adv[nm] = to_glyph(glyph_geom(ch))
    order.append(nm); cmap[ord(ch)] = nm
    if ch.isalpha(): cmap[ord(ch.lower())] = nm
# sparkle period (and U+2726)
sp = sparkle(0, 105 - R)
glyphs['period'], adv['period'] = to_glyph(sp.buffer(0))
glyphs['period'] = glyphs['period']; order.append('period'); cmap[ord('.')] = 'period'; cmap[0x2726] = 'period'
# sparkle must not be lifted by R: rebuild with baseline-aligned centre
from shapely.affinity import translate
g2, a2 = to_glyph(translate(sparkle(0, 0), yoff=135 - R))
glyphs['period'], adv['period'] = g2, a2

fb = FontBuilder(UPM, isTTF=True)
fb.setupGlyphOrder(order)
fb.setupCharacterMap(cmap)
fb.setupGlyf(glyphs)
fb.setupHorizontalMetrics({n: (adv[n], 0) for n in order})
fb.setupHorizontalHeader(ascent=860, descent=-220)
fb.setupNameTable({'familyName': 'Urax Display', 'styleName': 'Bold',
                   'copyright': 'UraxOS brand font, created for the UraxOS project.', 'uniqueFontIdentifier': 'UraxDisplay-Bold-0.1',
                   'fullName': 'Urax Display Bold', 'psName': 'UraxDisplay-Bold', 'version': 'Version 0.1'})
fb.setupOS2(sTypoAscender=860, sTypoDescender=-220, usWinAscent=900, usWinDescent=260, sCapHeight=700+2*R, usWeightClass=700)
fb.setupPost()
fb.setupDummyDSIG = None
out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'fonts')
fb.save(os.path.join(out, 'UraxDisplay-Bold.ttf'))
fb.font.flavor = 'woff2'
fb.save(os.path.join(out, 'UraxDisplay-Bold.woff2'))
print('ok', len(order), 'glyphs')
