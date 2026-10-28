#!/usr/bin/env python3
# Analisis dump RAM PS1 (2 MB) di runner. Keluaran HANYA angka dan alamat (tanpa byte kode, tanpa disassembly).
# Pakai: an_dump.py EXE.bin DISCDIR [--xref=L1,L2] LABEL=dump.bin [LABEL=dump.bin ...]
import sys, os, struct, mmap, collections

BASE = 0x80000000
SZ = 0x200000
EXE_END = 0x8006D800
LO, HI = 0x80010000, 0x80200000


def load(p):
    d = open(p, 'rb').read()
    if len(d) != SZ:
        raise SystemExit('ukuran dump %d != %d: %s' % (len(d), SZ, p))
    return d


def W(d):
    return struct.unpack('<%dI' % (len(d) // 4), d)


def page_stats(d):
    w = W(d)
    out = []
    for pg in range(SZ // 4096):
        s = w[pg * 1024:(pg + 1) * 1024]
        nz = sum(1 for x in s if x)
        pr = sum(1 for x in s if (x >> 16) == 0x27BD and (x & 0x8000))
        jr = sum(1 for x in s if x == 0x03E00008)
        out.append((nz, pr, jr))
    return out


def regions(ps):
    n = len(ps)
    code = [i >= 0x10 and ps[i][1] >= 2 and ps[i][2] >= 2 for i in range(n)]
    reg = []
    i = 0
    while i < n:
        if code[i]:
            j = i
            while j + 1 < n and (code[j + 1] or (j + 2 < n and code[j + 2])):
                j += 1
            while not code[j]:
                j -= 1
            reg.append((i, j))
            i = j + 1
        else:
            i += 1
    return reg


def fmt_reg(ps, r):
    a, b = r
    pr = sum(ps[i][1] for i in range(a, b + 1))
    jr = sum(ps[i][2] for i in range(a, b + 1))
    return '0x%08X-0x%08X halaman=%d prolog=%d jr_ra=%d' % (BASE + a * 4096, BASE + (b + 1) * 4096, b - a + 1, pr, jr)


def exe_compare(d, exe):
    n = len(exe)
    seg = d[0x10000:0x10000 + n]
    eq = sum(1 for i in range(0, n, 4) if seg[i:i + 4] == exe[i:i + 4])
    tot = n // 4
    print('  exe vs dump @0x80010000: kata sama %d/%d (%.2f%%)' % (eq, tot, 100.0 * eq / tot))
    blk = []
    for b in range(0, n, 0x10000):
        m = min(0x10000, n - b)
        e = sum(1 for i in range(b, b + m, 4) if seg[i:i + 4] == exe[i:i + 4])
        blk.append('0x%X:%d%%' % (BASE + 0x10000 + b, 100 * e // (m // 4)))
    print('  per blok 64K (alamat:persen sama):', ' '.join(blk))


def page_diff(a, b):
    out = []
    for pg in range(0x10, SZ // 4096):
        if a[pg * 4096:(pg + 1) * 4096] != b[pg * 4096:(pg + 1) * 4096]:
            out.append(pg)
    return out


def ranges(pages):
    out = []
    for p in pages:
        if out and p == out[-1][1] + 1:
            out[-1][1] = p
        else:
            out.append([p, p])
    return out


def find_files(disc):
    out = {}
    for dp, _, fn in os.walk(disc):
        for f in fn:
            if f.upper() in ('DATA.BIN', 'DATA2.BIN', 'XASECT.BIN'):
                out[f.upper()] = os.path.join(dp, f)
    return out


def match_region(d, maps, r, maxwin=4):
    a = r[0] * 4096
    b = (r[1] + 1) * 4096
    res = []
    for k in range(1, maxwin + 1):
        pos = (a + (b - a) * k // (maxwin + 1)) & ~15
        ok = False
        for _ in range(24):
            win = d[pos:pos + 128]
            if len(win) == 128 and sum(1 for z in struct.unpack('<32I', win) if z) >= 22 and len(set(win)) > 20:
                ok = True
                break
            pos += 128
        if not ok:
            continue
        hits = []
        for name, mm in maps.items():
            off = mm.find(win)
            if off >= 0:
                hits.append((name, off, off % 2048, off - (pos - a)))
        res.append((BASE + pos, hits))
    return res


TARGETS = [
    ('PLAYERS', 0x80070EB8, 0x80070EB8 + 4 * 180, 0x80070EB8, 180),
    ('TILES', 0x8013BA6E - 0x80, 0x8013BA6E + 22 * 0x124, 0x8013BA6E, 0x124),
    ('PRICE', 0x801FFB8C, 0x801FFB94, 0x801FFB8C, 0x1000),
    ('FLAG', 0x80139F40, 0x80139F4C, 0x80139F40, 0x1000),
    ('CURSOR', 0x801CECF0, 0x801CECF4, 0x801CECF0, 0x1000),
    ('WHEEL', 0x8006491C, 0x8006491C + 16 * 48, 0x8006491C, 48),
]
CALLEES = (0x80035D78, 0x800172EC)
LOADS = {0x20: 1, 0x21: 2, 0x23: 4, 0x24: 1, 0x25: 2}
STORES = {0x28: 1, 0x29: 2, 0x2B: 4}
KEEP = set(range(16, 24)) | {28, 29, 30}


def xref(d):
    w = W(d)
    const = {}
    clear_in = -1
    fn = 0
    hits = {t[0]: [] for t in TARGETS}
    callers = {c: [] for c in CALLEES}
    i0 = (LO - BASE) // 4
    i1 = (HI - BASE) // 4
    for i in range(i0, i1):
        x = w[i]
        pc = BASE + i * 4
        op = x >> 26
        rs = (x >> 21) & 31
        rt = (x >> 16) & 31
        imm = x & 0xFFFF
        simm = imm - 0x10000 if imm & 0x8000 else imm
        if op == 0x0F:
            const[rt] = imm << 16
        elif op in (0x08, 0x09):
            if op == 0x09 and rs == 29 and rt == 29 and simm < -4:
                fn = pc
            v = 0 if rs == 0 else const.get(rs)
            if v is not None:
                const[rt] = (v + simm) & 0xFFFFFFFF
            else:
                const.pop(rt, None)
        elif op == 0x0D:
            v = 0 if rs == 0 else const.get(rs)
            if v is not None:
                const[rt] = v | imm
            else:
                const.pop(rt, None)
        elif op in LOADS or op in STORES:
            base = const.get(rs)
            if base is not None:
                addr = (base + simm) & 0xFFFFFFFF
                for name, lo, hi, fb, st in TARGETS:
                    if lo <= addr < hi:
                        hits[name].append((pc, 'L' if op in LOADS else 'S', LOADS.get(op) or STORES.get(op), addr, fn, (addr - fb) % st))
            if op in LOADS:
                const.pop(rt, None)
        elif op == 0:
            funct = x & 63
            rd = (x >> 11) & 31
            if funct == 0x08:
                clear_in = i + 1
                const_keep = None
            elif funct == 0x09:
                clear_in = i + 1
                const_keep = KEEP
            else:
                const.pop(rd, None)
        elif op == 3:
            tg = (BASE & 0xF0000000) | ((x & 0x3FFFFFF) << 2)
            if tg in callers:
                callers[tg].append((pc, fn))
            clear_in = i + 1
        elif op == 2:
            clear_in = i + 1
        elif op in (1, 4, 5, 6, 7):
            pass
        elif op in (0x0A, 0x0B, 0x0C, 0x0E, 0x22, 0x26):
            const.pop(rt, None)
        if i == clear_in:
            if op == 0 and (x & 63) == 0x09:
                for r in list(const):
                    if r not in KEEP:
                        const.pop(r)
            else:
                const.clear()
            clear_in = -1
    return hits, callers


def print_xref(label, hits, callers):
    print('XREF %s (konstanta lui/addiu/ori ke alamat; hanya alamat instruksi, bukan isi)' % label)
    for name, lst in hits.items():
        nl = sum(1 for h in lst if h[1] == 'L')
        ns = len(lst) - nl
        fns = len({h[4] for h in lst})
        print('  T %s: akses=%d (load=%d store=%d) fungsi_unik=%d' % (name, len(lst), nl, ns, fns))
        byf = collections.defaultdict(list)
        for h in lst:
            byf[h[5]].append(h)
        order = sorted(byf.items(), key=lambda kv: -len(kv[1]))[:12]
        for off, hh in order:
            l = sum(1 for h in hh if h[1] == 'L')
            s = len(hh) - l
            ex = ['%X@%X' % (h[0], h[4]) for h in hh if h[1] == 'S'][:5]
            print('    +0x%X: L=%d S=%d contoh_S(pc@fn)=%s' % (off, l, s, ','.join(ex)))
    for c, lst in callers.items():
        print('  pemanggil jal 0x%08X: %d  %s' % (c, len(lst), ' '.join('%X@%X' % p for p in lst[:12])))


def main():
    a = sys.argv[1:]
    if len(a) < 3:
        raise SystemExit(__doc__)
    exe = open(a[0], 'rb').read()
    disc = a[1]
    xl = []
    items = []
    for t in a[2:]:
        if t.startswith('--xref='):
            xl = t[7:].split(',')
        else:
            k, v = t.split('=', 1)
            items.append((k, v))
    dumps = collections.OrderedDict((k, load(v)) for k, v in items)
    print('ANALISIS DUMP: %d dump: %s' % (len(dumps), ' '.join(dumps)))
    stats = {}
    for k, d in dumps.items():
        ps = page_stats(d)
        stats[k] = ps
        nzp = sum(1 for p in ps if p[0])
        reg = regions(ps)
        ovl = [r for r in reg if BASE + r[0] * 4096 >= EXE_END - 0x1000]
        print('DUMP %s: halaman_tak_kosong=%d/512 wilayah_kode=%d (di zona overlay >=0x8006D000: %d)' % (k, nzp, len(reg), len(ovl)))
        for r in ovl[:10]:
            print('   ', fmt_reg(ps, r))
    first = next(iter(dumps))
    print('KESELARASAN EXE:')
    exe_compare(dumps[first], exe)
    keys = list(dumps)
    print('PERBEDAAN HALAMAN 4K (zona exe 0x80010000-0x8006D000 | zona atas):')
    for i in range(len(keys)):
        for j in range(i + 1, len(keys)):
            pg = page_diff(dumps[keys[i]], dumps[keys[j]])
            lo = [p for p in pg if BASE + p * 4096 < EXE_END - 0x1000]
            hi = [p for p in pg if BASE + p * 4096 >= EXE_END - 0x1000]
            print('  %s vs %s: exe=%d atas=%d' % (keys[i], keys[j], len(lo), len(hi)))
    # peta tetap/berganti zona atas untuk pasangan papan(A24500) vs duel(A28700) bila ada
    if 'A24500' in dumps and 'A28700' in dumps:
        pg = page_diff(dumps['A24500'], dumps['A28700'])
        rr = ranges([p for p in pg if BASE + p * 4096 >= EXE_END - 0x1000])
        print('  halaman berganti papan->duel (zona atas), %d rentang; 14 pertama:' % len(rr), ' '.join('0x%X-0x%X' % (BASE + a0 * 4096, BASE + (b0 + 1) * 4096) for a0, b0 in rr[:14]))
    files = find_files(disc)
    print('BERKAS DISC untuk pencocokan:', {k: os.path.getsize(v) for k, v in files.items()})
    maps = {}
    for k, v in files.items():
        f = open(v, 'rb')
        maps[k] = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
    for k in keys:
        if k not in ('A24500', 'A28700', 'B27000'):
            continue
        ps = stats[k]
        reg = [r for r in regions(ps) if BASE + r[0] * 4096 >= EXE_END - 0x1000 and r[1] - r[0] >= 2]
        print('PENCOCOKAN OVERLAY %s: %d wilayah >=3 halaman' % (k, len(reg)))
        for r in reg[:8]:
            res = match_region(dumps[k], maps, r)
            for addr, hits in res:
                print('   jendela@0x%08X wilayah=0x%08X: %s' % (addr, BASE + r[0] * 4096, ' '.join('%s+0x%X(mod2048=%d,awal_wilayah=0x%X)' % h for h in hits) if hits else 'tak ketemu'))
    for k in xl:
        if k in dumps:
            h, c = xref(dumps[k])
            print_xref(k, h, c)


if __name__ == '__main__':
    main()
