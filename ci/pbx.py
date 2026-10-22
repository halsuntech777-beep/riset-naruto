#!/usr/bin/env python3
# Operasi protobuf pada state sementara di runner. HANYA struktur/angka dicetak; isi byte tidak pernah dicetak.
#   pbx.py subs STATE PATH           -> nomor sub-field unik di bawah PATH (mis. 6.6), dipisah spasi
#   pbx.py shape STATE PATH          -> jumlah elemen PATH + bentuk (nomor:tipe:panjang) 2 elemen pertama
#   pbx.py drop STATE OUT PATH       -> tulis STATE tanpa semua kemunculan PATH (kedalaman bebas, mis. 6.6.3)
#   pbx.py nums STATE PATH N        -> angka sub-field (varint/fixed; panjang untuk byte) N elemen pertama PATH
#   pbx.py swap A B OUT PATH         -> A dengan PATH diganti PATH milik B (semua kemunculan; ditaruh di akhir induk)
import sys


def rv(b, i):
    r = 0
    s = 0
    while True:
        c = b[i]
        i += 1
        r |= (c & 0x7f) << s
        if not c & 0x80:
            return r, i
        s += 7
        if s > 70:
            raise ValueError('varint')


def enc(v):
    o = bytearray()
    while True:
        c = v & 0x7f
        v >>= 7
        if v:
            o.append(c | 0x80)
        else:
            o.append(c)
            return bytes(o)


def parse(b, lo, hi):
    i = lo
    out = []
    while i < hi:
        h0 = i
        k, i = rv(b, i)
        fn, wt = k >> 3, k & 7
        if fn == 0:
            raise ValueError('field0')
        if wt == 0:
            _, i = rv(b, i)
            p0 = p1 = None
        elif wt == 1:
            p0, i = i, i + 8
            p1 = i
        elif wt == 5:
            p0, i = i, i + 4
            p1 = i
        elif wt == 2:
            n, i = rv(b, i)
            p0, i = i, i + n
            p1 = i
        else:
            raise ValueError('wt')
        if i > hi:
            raise ValueError('over')
        out.append((fn, wt, h0, i, p0, p1))
    return out


def spans(b, lo, hi, path):
    """payload (p0,p1) tiap kemunculan PATH."""
    res = []
    for fn, wt, h0, e, p0, p1 in parse(b, lo, hi):
        if fn != path[0] or wt != 2:
            continue
        if len(path) == 1:
            res.append((p0, p1))
        else:
            res += spans(b, p0, p1, path[1:])
    return res


def drop_path(b, lo, hi, path):
    out = bytearray()
    for fn, wt, h0, e, p0, p1 in parse(b, lo, hi):
        if fn != path[0]:
            out += b[h0:e]
            continue
        if len(path) == 1:
            continue
        if wt != 2:
            out += b[h0:e]
            continue
        body = drop_path(b, p0, p1, path[1:])
        out += enc((fn << 3) | 2) + enc(len(body)) + body
    return bytes(out)


def collect(b, lo, hi, path):
    res = []
    for fn, wt, h0, e, p0, p1 in parse(b, lo, hi):
        if fn != path[0]:
            continue
        if len(path) == 1:
            res.append(b[h0:e])
        elif wt == 2:
            res += collect(b, p0, p1, path[1:])
    return res


def put(b, lo, hi, path, items):
    out = bytearray()
    for fn, wt, h0, e, p0, p1 in parse(b, lo, hi):
        if fn != path[0]:
            out += b[h0:e]
            continue
        if len(path) == 1:
            continue
        if wt != 2:
            out += b[h0:e]
            continue
        body = put(b, p0, p1, path[1:], items)
        out += enc((fn << 3) | 2) + enc(len(body)) + body
    if len(path) == 1:
        out += b''.join(items)
    return bytes(out)


def main():
    cmd = sys.argv[1]
    if cmd == 'swap':
        a = open(sys.argv[2], 'rb').read()
        bb = open(sys.argv[3], 'rb').read()
        path = [int(x) for x in sys.argv[5].split('.')]
        items = collect(bb, 0, len(bb), path)
        open(sys.argv[4], 'wb').write(put(a, 0, len(a), path, items))
        print('swap ok jumlah_elemen_B=%d' % len(items))
        return
    b = open(sys.argv[2], 'rb').read()
    if cmd == 'drop':
        path = [int(x) for x in sys.argv[4].split('.')]
        open(sys.argv[3], 'wb').write(drop_path(b, 0, len(b), path))
        return
    path = [int(x) for x in sys.argv[3].split('.')]
    sp = spans(b, 0, len(b), path)
    if cmd == 'subs':
        seen = set()
        for p0, p1 in sp:
            for fn, wt, h0, e, q0, q1 in parse(b, p0, p1):
                seen.add(fn)
        print(' '.join(str(x) for x in sorted(seen)))
    elif cmd == 'nums':
        nmax = int(sys.argv[4])
        for p0, p1 in sp[:nmax]:
            row = []
            for fn, wt, h0, e, q0, q1 in parse(b, p0, p1):
                if wt == 0:
                    v, _ = rv(b, h0 + len(enc(fn << 3)))
                    row.append('%d=%d' % (fn, v))
                elif wt in (1, 5):
                    row.append('%d=%d' % (fn, int.from_bytes(b[q0:q1], 'little')))
                else:
                    row.append('%d:len%d' % (fn, q1 - q0))
            print(' '.join(row[:60]))
    elif cmd == 'shape':
        print('elemen', len(sp))
        for p0, p1 in sp[:2]:
            try:
                row = []
                for fn, wt, h0, e, q0, q1 in parse(b, p0, p1):
                    n = (q1 - q0) if wt == 2 else (e - h0)
                    row.append('%d:%d:%d' % (fn, wt, n))
                print(' '.join(row))
            except Exception:
                print('(bukan protobuf bersarang) panjang', p1 - p0)


main()
