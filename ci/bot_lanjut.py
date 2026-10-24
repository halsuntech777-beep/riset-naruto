#!/usr/bin/env python3
"""Ubah log tekan-tombol bot (baris 'SVS BOT <frame> <TOMBOL> <lama>' di chg.log) menjadi jadwal replay.
Pemakaian: bot_lanjut.py LOG BASE OUT [--upto F] [--cfg 'K=10 stable=3 ...']
  BASE = jadwal dasar (mis. inputs/r13_a.txt). OUT = BASE + tekan bot (yang selesai <= F) + '# BOT from=G'.
  Tanpa --upto: semua tekan dipakai, G = akhir tekan terakhir (bot lanjut tepat di sana).
Hanya angka/teks jadwal; tidak ada data game."""
import re, sys
a = sys.argv[1:]
if len(a) < 3: sys.exit(__doc__)
log, base, out = a[:3]
upto = int(a[a.index('--upto') + 1]) if '--upto' in a else None
cfg = a[a.index('--cfg') + 1] if '--cfg' in a else None
rx = re.compile(r'^SVS BOT (\d+) ([A-Z][A-Z0-9]*) (\d+)\s*$')
pres = []
for ln in open(log, encoding='utf-8', errors='replace'):
    m = rx.match(ln)
    if m: pres.append((int(m[1]), m[2], int(m[3])))
pres = sorted(set(pres))
if upto is not None: pres = [p for p in pres if p[0] + p[2] <= upto]
lines = [l.rstrip('\n') for l in open(base, encoding='utf-8') if not re.match(r'^#\s*BOT(CFG)?\s', l)]
g = max([p[0] + p[2] for p in pres] + [upto or 0])
body = lines + ['%d %s %d' % p for p in pres]
if cfg: body.append('# BOTCFG ' + cfg)
body.append('# BOT from=%d' % g)
open(out, 'w', encoding='utf-8').write('\n'.join(body) + '\n')
print('tekan=%d from=%d keluar=%s' % (len(pres), g, out))
