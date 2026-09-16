#!/usr/bin/env python3
"""Render original vector Game Center artwork; requires rsvg-convert and ImageMagick."""
from pathlib import Path
import math
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "artwork"
ART.mkdir(exist_ok=True)

def star(cx, cy, outer, inner, n=5):
    pts = []
    for i in range(n * 2):
        a = -math.pi / 2 + i * math.pi / n
        r = outer if i % 2 == 0 else inner
        pts.append(f"{cx + math.cos(a) * r:.1f},{cy + math.sin(a) * r:.1f}")
    return '<polygon points="' + ' '.join(pts) + '"/>'

def diamond(cx, cy, r):
    return f'<path d="M{cx} {cy-r} L{cx+r} {cy} L{cx} {cy+r} L{cx-r} {cy} Z"/>'

def orb(cx=512, cy=495, r=146):
    return f'<circle cx="{cx}" cy="{cy+18}" r="{r+12}" fill="#07081B" opacity=".45"/><circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#orb)" stroke="#EED8FF" stroke-width="5"/><ellipse cx="{cx-r*.30}" cy="{cy-r*.44}" rx="{r*.25}" ry="{r*.14}" transform="rotate(-28 {cx-r*.3} {cy-r*.44})" fill="#FFFFFF" opacity=".88"/>'

def badge(number):
    return f'<rect x="387" y="658" width="250" height="118" rx="59" fill="#15132F" stroke="#DAC5FF" stroke-width="3"/><text x="512" y="740" text-anchor="middle" font-family="Arial, Helvetica, sans-serif" font-weight="700" font-size="81" fill="#FFF8FF">{number}</text>'

def motif(kind):
    if kind == "first_maze":
        return '<path d="M308 594 V344 H552 V454 H692 V634" fill="none" stroke="url(#metal)" stroke-width="38" stroke-linejoin="round"/>' + orb(512,508,119)
    if kind.startswith("classic_"):
        n = kind.split('_')[1]
        if n == "25":
            m = '<path d="M304 589 V354 H484 V481 H696 V588" fill="none" stroke="url(#metal)" stroke-width="42" stroke-linecap="round" stroke-linejoin="round"/>' + orb(484,465,95)
        elif n == "100":
            m = '<path d="M306 554 L392 342 L512 424 L629 342 L718 554 Z" fill="url(#metal)" stroke="#FFF4DC" stroke-width="5"/>' + diamond(512,481,54).replace('/>', ' fill="url(#orb)"/>')
        else:
            m = '<path d="M310 370 L406 439 L512 302 L618 439 L714 370 L668 574 H356 Z" fill="url(#metal)" stroke="#FFF4DC" stroke-width="6"/>' + orb(512,472,77)
        return m + badge(n)
    if kind.startswith("perfect_"):
        n = kind.split('_')[1]
        if n == "1":
            m = diamond(512,482,186).replace('/>', ' fill="url(#metal)" stroke="#FFFAF0" stroke-width="5"/>')
            m += '<path d="M423 482 L487 546 L604 422" fill="none" stroke="#6A32A4" stroke-width="39" stroke-linecap="round" stroke-linejoin="round"/>'
        elif n == "25":
            m = '<g fill="url(#metal)" stroke="#FFFAF0" stroke-width="4">' + diamond(369,473,91) + diamond(655,473,91) + diamond(512,399,126) + '</g>'
            m += orb(512,437,51)
        else:
            m = '<g fill="url(#metal)" stroke="#FFFAF0" stroke-width="4">' + star(512,466,197,111,8) + '</g>' + orb(512,466,86)
        return m + badge(n)
    if kind == "limited_25":
        return '<path d="M340 350 H556 L679 473 L552 600 H343" fill="none" stroke="url(#metal)" stroke-width="43" stroke-linecap="round" stroke-linejoin="round"/><path d="M424 274 L340 350 L424 426" fill="none" stroke="url(#metal)" stroke-width="43" stroke-linecap="round" stroke-linejoin="round"/>' + orb(532,472,74) + badge(25)
    if kind == "rush_10":
        return '<rect x="457" y="282" width="110" height="44" rx="18" fill="url(#metal)"/><circle cx="512" cy="487" r="165" fill="#1E153C" stroke="url(#metal)" stroke-width="31"/><path d="M527 366 L438 502 H514 L482 593 L591 449 H519 Z" fill="url(#metal)"/>' + badge(10)
    if kind.startswith("daily_"):
        rays = ''.join(f'<path d="M{512+math.cos(a)*180:.1f} {474+math.sin(a)*180:.1f} L{512+math.cos(a)*212:.1f} {474+math.sin(a)*212:.1f}"/>' for a in [i*math.pi/6 for i in range(12)])
        m = '<g stroke="url(#metal)" stroke-width="23" stroke-linecap="round">' + rays + '</g>' + orb(512,474,132)
        return m + badge(kind.split('_')[1])
    if kind == "coins_100":
        m = ''.join(f'<circle cx="{cx}" cy="{cy}" r="110" fill="url(#metal)" stroke="#FFF4DC" stroke-width="6"/><circle cx="{cx}" cy="{cy}" r="83" fill="none" stroke="#8A4689" stroke-width="7"/>' for cx,cy in [(385,425),(642,425),(512,527)])
        return m + diamond(512,527,54).replace('/>', ' fill="url(#orb)"/>') + badge(100)
    raise ValueError(kind)

def svg(kind, index):
    accents = [('#CB75FF','#FF639E'),('#B88AFF','#EC8CFF'),('#CCACFF','#798CFF'),('#F3C682','#DB79FF'),('#FBA3D3','#966BFF'),('#B1E8EF','#C394FF'),('#FFDABB','#C995FF'),('#A7DAFF','#A287FF'),('#FFADBA','#FF679F'),('#FFDB94','#FF97BF'),('#B3E9FF','#B891FF'),('#FFEAB7','#EE9DCE')]
    a,b = accents[index]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
<radialGradient id="bg" cx="48%" cy="38%" r="74%"><stop stop-color="#38214D"/><stop offset=".56" stop-color="#15122C"/><stop offset="1" stop-color="#070B20"/></radialGradient>
<linearGradient id="edge" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{a}"/><stop offset=".48" stop-color="#6E508B"/><stop offset="1" stop-color="{b}"/></linearGradient>
<linearGradient id="metal" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#FFFBEF"/><stop offset=".5" stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>
<radialGradient id="orb" cx="33%" cy="23%" r="81%"><stop stop-color="#E9A6FF"/><stop offset=".26" stop-color="#B42AFF"/><stop offset=".59" stop-color="#5E00D2"/><stop offset=".79" stop-color="#E432BC"/><stop offset="1" stop-color="#FF6B88"/></radialGradient>
</defs>
<rect width="1024" height="1024" fill="url(#bg)"/>
<g fill="none" stroke="#9873C7" stroke-width="3" opacity=".12"><path d="M0 205 H205 V80 H800 V247 H1024 M0 793 H165 V916 H835 V782 H1024 M102 0 V110 H295 M1024 504 H908 V362 H842 M0 540 H124 V682 H187"/></g>
<circle cx="512" cy="512" r="390" fill="none" stroke="url(#edge)" stroke-width="4" opacity=".55"/>
<circle cx="512" cy="512" r="365" fill="none" stroke="url(#edge)" stroke-width="2" opacity=".24"/>
<path d="M190 292 A388 388 0 0 1 530 124" fill="none" stroke="{a}" stroke-width="8" stroke-linecap="round"/>
<path d="M834 732 A388 388 0 0 1 494 900" fill="none" stroke="{b}" stroke-width="8" stroke-linecap="round"/>
{motif(kind)}
<g fill="url(#metal)">{star(297,229,14,6)}{star(761,679,15,6)}{star(237,683,10,4)}</g>
</svg>'''

KINDS = ['first_maze','classic_25','classic_100','classic_500','perfect_1','perfect_25','perfect_100','limited_25','rush_10','daily_1','daily_7','coins_100']
for i,kind in enumerate(KINDS):
    source = ART / f'{kind}.svg'
    png = ART / f'{kind}.png'
    source.write_text(svg(kind,i))
    subprocess.run(['rsvg-convert','--width','1024','--height','1024','--output',str(png),str(source)],check=True)
    subprocess.run(['magick',str(png),'-units','PixelsPerInch','-density','72','-colorspace','sRGB','-alpha','off',str(png)],check=True)
subprocess.run(['magick','montage','-font','/System/Library/Fonts/Supplemental/Arial.ttf',*[str(ART/f'{kind}.png') for kind in KINDS],'-thumbnail','256x256','-tile','4x3','-geometry','256x256+12+12','-background','#070B20',str(ART/'contact-sheet.png')],check=True)
print(f'Rendered {len(KINDS)} achievement icons and contact sheet in {ART}')

# Wide, text-free activity artwork keeps the gameplay motif inside Apple's crop area.
for name,kind,index in [('classic','first_maze',0),('time_rush','rush_10',8),('daily','daily_1',9)]:
    square = svg(kind,index)
    if name == 'time_rush':
        square = square.replace(badge(10),'')
    if name == 'daily':
        square = square.replace(badge(1),'')
    content = square[square.index('<defs>'):square.rindex('</svg>')]
    wide = f'''<svg xmlns="http://www.w3.org/2000/svg" width="3840" height="2160" viewBox="0 0 3840 2160">
<rect width="3840" height="2160" fill="#070B20"/>
<g stroke="#8060C0" stroke-width="6" fill="none" opacity=".23"><path d="M0 404 H430 V682 H855 M0 1580 H515 V1318 H1000 M3840 460 H3410 V755 H2995 M3840 1676 H3370 V1390 H2940"/><path d="M155 0 V203 H808 V498 M3685 2160 V1957 H3032 V1662"/></g>
<g transform="translate(896 56) scale(2)">{content}</g>
</svg>'''
    source = ART / f'activity_{name}.svg'
    png = ART / f'activity_{name}.png'
    source.write_text(wide)
    subprocess.run(['rsvg-convert','--output',str(png),str(source)],check=True)
    subprocess.run(['magick',str(png),'-units','PixelsPerInch','-density','72','-colorspace','sRGB','-alpha','off',str(png)],check=True)
print('Rendered 3 activity images at 3840 x 2160')
