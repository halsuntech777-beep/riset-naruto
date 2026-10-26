#!/usr/bin/env python3
"""Analisis gelombang instrumen v5/v6 (hanya angka). Pakai: python3 alat/analisis_v5v6.py PREV NEW  (mis. x17 x18).
Cetak: netral NEW vs PREV (baris BOT lama + CHG), cocok bacaan langsung 0x1FFB90 vs turunnya chakra (BOT# W), ringkasan BOT# L / L6, jumlah menang."""
import glob, re, sys, collections, subprocess
PREV, NEW_ = sys.argv[1], sys.argv[2]
N = 'g30m110 g30m130 g35m100 g35m120 g40m110 g40m140 g45m130 g50m140 g50m170 g55m160 g60m150 g60m190 g70m200 g80m240 n0a n0b'.split()
def rd(lab):
    ds = sorted(glob.glob('hasil/%s_*' % lab))
    return open(ds[-1] + '/chg.log', encoding='utf-8', errors='replace').read().split('\n') if ds else None
NEWL = re.compile(r'^(SVS )?BOT# (V |V5|L |L6|W )'); KEEP = re.compile(r'^((SVS )?BOT|CHG)')
same = 0; bad = []; err = 0; W = []; L = {}; L6 = {}
f = lambda s: None if s == '-' else [int(x) for x in s.split(',')]
for n in N:
    a = rd(PREV + n); b = rd(NEW_ + n)
    if b is None: bad.append((n, 'hilang')); continue
    err += sum('V5ERR' in l for l in b)
    if a:
        fa = [l for l in a if KEEP.match(l) and not NEWL.match(l)]; fb = [l for l in b if KEEP.match(l) and not NEWL.match(l)]
        if fa == fb: same += 1
        else: bad.append((n, next((k for k, (x, y) in enumerate(zip(fa, fb)) if x != y), min(len(fa), len(fb)))))
    for l in b:
        m = re.match(r'BOT# W f=(\d+) t=(\w) mv=(\d) d=(-?\d+) dur=(\d+) r0=(\S+) r1=(\S+) r2=(\S+)', l)
        if m: W.append(dict(f=int(m[1]), t=m[2], mv=int(m[3]), d=int(m[4]), r0=f(m[6]), r1=f(m[7]), r2=f(m[8])))
        m = re.match(r'BOT# L f=(\d+) t=(\w) mv=(\d) c0=(\S+) c1=\S+ lv0=(\S+) lv1=\S+ np=(\d+)', l)
        if m: L[(n, int(m[1]), m[2], int(m[3]))] = ([int(x) for x in m[4].split(',')], m[5], int(m[6]))
        m = re.match(r'BOT# L6 f=(\d+) t=(\w) mv=(\d) c=(\S+) lv=(\S+)', l)
        if m: L6[(n, int(m[1]), m[2], int(m[3]))] = ([int(x) for x in m[4].split(',')], m[5])
print('NETRAL %s vs %s: %d/16 identik; beda(dadu, indeks baris pertama)=%s; V5ERR=%d' % (NEW_, PREV, same, bad[:8], err))
nm = ['1FFB8E', '1FFB90', '1FFB92', '1EEE06', '1EEE08']
for mv in (1, 3):
    B = [w for w in W if w['t'] == 'B' and w['mv'] == mv and w['d'] > 0]
    if B: print('BELI mv=%d d>0 n=%d cocok-d @muncul %s | @hilang %s' % (mv, len(B), dict(zip(nm, [sum(1 for w in B if w['r0'][i] == w['d']) for i in range(5)])), dict(zip(nm, [sum(1 for w in B if w['r2'][i] == w['d']) for i in range(5)]))))
for t in 'USL':
    X = [w for w in W if w['t'] == t]
    if X: print('tipe %s n=%d nilai 0x1FFB90 terbanyak %s' % (t, len(X), collections.Counter((w['r1'] or w['r0'])[1] for w in X).most_common(4)))
rise = lambda a, b: any(x.isdigit() and y.isdigit() and int(y) > int(x) for x, y in zip(a, b))
for t in 'US':
    for mv in (1, 3):
        ks = [k for k in L if k[2] == t and k[3] == mv and k in L6]
        if ks:
            g = 0 if mv == 1 else 1
            print('L6 t=%s mv=%d n=%d lv_naik=%d np>0=%d selisih chakra pelaku (c0-c6) %s' % (t, mv, len(ks), sum(1 for k in ks if rise(L[k][1], L6[k][1])), sum(1 for k in ks if L[k][2] > 0), collections.Counter(L[k][0][g] - L6[k][0][g] for k in ks).most_common(4)))
out = subprocess.run(['python3', 'alat/menang.py'] + [NEW_ + n for n in N], capture_output=True, text=True).stdout
print('menang %s: %d/16' % (NEW_, out.count('MENANG)')))
