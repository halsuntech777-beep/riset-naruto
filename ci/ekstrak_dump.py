#!/usr/bin/env python3
"""Ambil ANGKA saja dari dump RAM (di runner) -> CSV. Dump tidak pernah masuk ke hasil/.
Pakai: ekstrak_dump.py <folder_dump> <keluar.csv> "<alamat[+panjang]:lebar,...>"
Contoh: "0x70EB8:4,0x8006491C+768:4"  (lebar 1/2/4 byte; total <= 1024 byte per dump)"""
import sys, re, glob, os
MAXB = 1024
dumpdir, outcsv, spec = sys.argv[1], sys.argv[2], sys.argv[3]
items, total = [], 0
for tok in filter(None, (t.strip() for t in spec.split(','))):
    m = re.fullmatch(r'(0x[0-9A-Fa-f]+)(?:\+(\d+))?:([124])', tok)
    if not m: sys.exit('ADDRS tidak valid: ' + tok)
    w = int(m.group(3)); ln = int(m.group(2) or w); a = int(m.group(1), 16) % 0x200000
    if ln % w or ln <= 0 or a + ln > 0x200000: sys.exit('panjang/alamat tidak valid: ' + tok)
    total += ln; items.append((a, ln, w))
if total > MAXB: sys.exit('total byte > %d' % MAXB)
rows = ['frame,alamat,hex,desimal']
for f in sorted(glob.glob(os.path.join(dumpdir, 'r_*.bin'))):
    fr = int(re.search(r'r_(\d+)\.bin', f).group(1)); d = open(f, 'rb').read()
    for a, ln, w in items:
        for o in range(a, a + ln, w):
            v = int.from_bytes(d[o:o + w], 'little')
            rows.append('%d,0x%X,0x%0*X,%d' % (fr, o, w * 2, v, v))
open(outcsv, 'w').write('\n'.join(rows) + '\n')
print('baris:', len(rows) - 1)
