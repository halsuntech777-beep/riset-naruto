#!/usr/bin/env python3
"""Ringkas hasil papan 1 dari hasil/<LABEL>_*/chg.log (hanya angka). Pemakaian: menang.py LABEL [LABEL...]
Tamat = CHG P1 -> 0 (posisi reset) atau BOT# S c=1500,1500,0,0 p=0,0. Pemenang = pemain dengan chakra puncak tertinggi 3000 frame sebelum reset
(menang B1 = pemain kita; B2 = COM menang = KALAH). END = alasan berhenti bot (MAXF/MACET)."""
import glob, re, sys
for lab in sys.argv[1:]:
    ds = sorted(glob.glob('hasil/%s_*' % lab))
    if not ds: print(lab, '-- belum ada hasil'); continue
    L = open(ds[-1] + '/chg.log', encoding='utf-8', errors='replace').read().split('\n')
    h = [[] for _ in range(4)]; clear = None; end = 'END?'; sig = None
    for l in L:
        m = re.match(r'CHG f=(\d+) B([1-4]): (\d+) -> (\d+)', l)
        if m: h[int(m[2]) - 1].append((int(m[1]), int(m[4])))
        m = re.match(r'CHG f=(\d+) P1: (\d+) -> 0\b', l)
        if m and clear is None and int(m[2]) > 0 and int(m[1]) > 34000: clear = int(m[1])
        m = re.match(r'BOT# S f=(\d+) c=1500,1500,0,0 p=0,0', l)
        if m and sig is None and int(m[1]) > 34000: sig = int(m[1])
        if l.startswith('BOT# END'): end = l[5:].strip()
    F = clear or sig
    b1 = max([v for f, v in h[0]] or [0])
    if F is None: print('%s: %s | belum tamat | B1 maks=%d' % (lab, end, b1)); continue
    pk = []
    for k in range(4):
        before = [v for f, v in h[k] if f < F]; win = [v for f, v in h[k] if F - 3000 <= f < F]
        pk.append(max(win + before[-1:] or [0]))
    w = max(range(4), key=lambda k: pk[k]) + 1
    print('%s: %s | TAMAT@%d%s | pemenang=B%d (%s) puncak=%s | B1 maks=%d' % (lab, end, F, '' if clear else '(dari S)', w, 'MENANG' if w == 1 else 'KALAH', pk, b1))
