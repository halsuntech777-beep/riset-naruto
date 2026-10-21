#!/usr/bin/env python3
# Analisis struktur protobuf state (HANYA angka: nomor field, tipe, panjang). Tidak mencetak isi byte.
# pemakaian: pbsplit.py struct STATE            -> cetak field tingkat 1 dan 2
#            pbsplit.py list STATE [maks]       -> cetak daftar jalur kandidat (tingkat 1 lalu 2)
#            pbsplit.py drop STATE OUT JALUR    -> tulis state tanpa field JALUR (mis. "5" atau "5.2")
import sys
def rv(b, i):
    r = 0; s = 0
    while True:
        c = b[i]; i += 1; r |= (c & 0x7f) << s
        if not c & 0x80: return r, i
        s += 7
        if s > 70: raise ValueError('varint')
def parse(b, lo=0, hi=None):
    hi = len(b) if hi is None else hi; i = lo; out = []
    while i < hi:
        h0 = i; k, i = rv(b, i); fn, wt = k >> 3, k & 7
        if fn == 0: raise ValueError('field0')
        if wt == 0: _, i = rv(b, i); p0 = p1 = None
        elif wt == 1: p0, i = i, i + 8; p1 = i
        elif wt == 5: p0, i = i, i + 4; p1 = i
        elif wt == 2:
            n, i = rv(b, i); p0, i = i, i + n; p1 = i
        else: raise ValueError('wt')
        if i > hi: raise ValueError('over')
        out.append((fn, wt, h0, i, p0, p1))
    return out
def tryparse(b, lo, hi):
    try:
        r = parse(b, lo, hi)
        return r if len(r) <= 400 else None
    except Exception:
        return None
def main():
    cmd = sys.argv[1]; b = open(sys.argv[2], 'rb').read()
    top = parse(b)
    if cmd == 'struct':
        print('total', len(b), 'campo_tingkat1', len(top))
        for fn, wt, h0, e, p0, p1 in top:
            n = (p1 - p0) if wt == 2 else (e - h0)
            sub = tryparse(b, p0, p1) if wt == 2 and n > 0 else None
            print('f%d wt=%d panjang=%d sub=%s' % (fn, wt, n, 'ya:%d' % len(sub) if sub else 'tidak'))
            if sub:
                for sf, sw, sh, se, sp0, sp1 in sub:
                    sn = (sp1 - sp0) if sw == 2 else (se - sh)
                    print('   f%d.%d wt=%d panjang=%d' % (fn, sf, sw, sn))
    elif cmd == 'list':
        mx = int(sys.argv[3]) if len(sys.argv) > 3 else 120; paths = []
        seen = {}
        for fn, wt, h0, e, p0, p1 in top:
            seen[fn] = seen.get(fn, 0) + 1
            paths.append(str(fn))
        for fn, wt, h0, e, p0, p1 in top:
            if wt != 2 or p1 - p0 < 8: continue
            sub = tryparse(b, p0, p1)
            if sub:
                for sf in sorted(set(x[0] for x in sub)): paths.append('%d.%d' % (fn, sf))
        out = []
        for p in paths:
            if p not in out: out.append(p)
        print(' '.join(out[:mx]))
    elif cmd == 'drop':
        path = sys.argv[4].split('.'); out = bytearray()
        if len(path) == 1:
            drop = int(path[0])
            for fn, wt, h0, e, p0, p1 in top:
                if fn != drop: out += b[h0:e]
        else:
            f1, f2 = int(path[0]), int(path[1])
            for fn, wt, h0, e, p0, p1 in top:
                if fn != f1: out += b[h0:e]; continue
                sub = tryparse(b, p0, p1)
                if not sub: out += b[h0:e]; continue
                body = bytearray()
                for sf, sw, sh, se, sp0, sp1 in sub:
                    if sf != f2: body += b[sh:se]
                # reencode: tag + panjang + isi
                k = (fn << 3) | 2; hdr = bytearray()
                v = k
                while True:
                    c = v & 0x7f; v >>= 7
                    if v: hdr.append(c | 0x80)
                    else: hdr.append(c); break
                n = len(body)
                while True:
                    c = n & 0x7f; n >>= 7
                    if n: hdr.append(c | 0x80)
                    else: hdr.append(c); break
                out += hdr + body
        open(sys.argv[3], 'wb').write(out)
main()
