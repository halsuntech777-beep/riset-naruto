#!/usr/bin/env python3
"""Ringkasan ANGKA satu folder hasil/<label>_<run>/ dalam satu panggilan (hemat token). Pakai: ringkas.py DIR"""
import re, sys, os, collections
d = sys.argv[1]
def rd(n):
    p = os.path.join(d, n)
    return open(p, encoding='utf-8', errors='replace').read().splitlines() if os.path.exists(p) else []
print('\n'.join(l[:150] for l in rd('ringkasan.txt')[:2]))
lg = rd('chg.log')
print('baris', len(lg), dict(collections.Counter(l.split(' ', 1)[0] for l in lg).most_common(7)))
RX = r'^(?:SVS )?BOT'
pr = [(int(m[1]), m[2], int(m[3])) for l in lg for m in [re.match(RX + r' (\d+) ([A-Z0-9]+) (\d+)', l)] if m]
if pr:
    print('tekan', len(pr), 'pertama', pr[0][0], 'terakhir', pr[-1][0], dict(collections.Counter(p[1] for p in pr)))
    print('jeda terbanyak', collections.Counter(b[0] - a[0] for a, b in zip(pr, pr[1:])).most_common(4))
st = [l for l in lg if re.match(RX + r'# S', l)]
for l in (st[:2] + st[len(st) // 2:len(st) // 2 + 1] + st[-3:] if len(st) > 6 else st): print(' ', l[:130])
print('END', [l[:90] for l in lg if re.match(RX + r'# END', l)][-1:])
ch = [l for l in lg if re.match(r'^CHG f=\d+ [BP]\d', l)]
for l in ch[::max(1, len(ch) // 10)][:11]: print(' ', l[:70])
print('shot', sorted(f for f in os.listdir(d) if f.startswith('shot_')), '| ekor:', ' / '.join(x[:60] for x in rd('emu_tail.txt')[-2:]))
