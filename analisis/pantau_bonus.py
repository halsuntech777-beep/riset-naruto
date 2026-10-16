import re, sys
log = sys.argv[1] if len(sys.argv) > 1 else '/tmp/l4.log'
ev = []
for l in open(log, errors='ignore'):
    m = re.match(r'CHG f=(\d+) (B[12]): (\d+|nil) -> (\d+)', l)
    if m and int(m.group(1)) > 6000 and m.group(3) != 'nil':
        a, b = int(m.group(3)), int(m.group(4))
        if a < 20000 and b < 20000: ev.append((int(m.group(1)), m.group(2), a, b))
tx = []
for f, p, a, b in ev:
    if tx and tx[-1][1] == p and f - tx[-1][3] <= 6: tx[-1][3] = f; tx[-1][5] = b
    else: tx.append([f, p, a, f, a, b])
print("transaksi:", len(tx), "| bonus kandidat (kenaikan >= 300):")
for t in tx:
    if t[5] - t[2] >= 300: print(f"  f={t[0]:>6} {t[1]}: {t[2]} -> {t[5]} ({t[5]-t[2]:+d})")
print("frame terakhir di log:", max([e[0] for e in ev]) if ev else None)
