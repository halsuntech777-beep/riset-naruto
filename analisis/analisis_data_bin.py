"""Analisis DATA.BIN dari citra .bin PS1 (MODE2/2352), disc SLPS-03553.
Pakai: python3 analisis_data_bin.py <path.bin> [--rinci]
Mencari (1) tabel petak: record 30 byte, u16 pertama = harga, u16 kedua = sewa;
        (2) jumlah gambar TIM valid (panjang blok harus tepat = lebar*tinggi*2 + 12)."""
import mmap, struct, sys
import numpy as np
P = sys.argv[1]
f = open(P, 'rb'); mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
LBA, LEN = 212, 66015232          # DATA.BIN pada disc ini
def read_extent(lba, length):
    out = bytearray()
    for i in range((length + 2047) // 2048):
        out += mm[(lba + i) * 2352 + 24: (lba + i) * 2352 + 24 + 2048]
    return bytes(out[:length])
data = read_extent(LBA, LEN)
a = np.frombuffer(data, dtype='<u2', count=len(data) // 2).astype(np.int32)
m = len(a) - 16; p, r = a[:m], a[1:m + 1]
valid = ((p == 0) & (r == 0)) | ((p >= 10) & (p <= 3000) & (p % 10 == 0) & (r * 10 >= p * 4) & (r * 10 <= p * 6))
nz = (p > 0) & valid
blok = []
for res in range(15):
    v, z = valid[res::15], nz[res::15]
    edge = np.diff(np.concatenate(([0], v.astype(np.int8), [0])))
    for s, e in zip(np.where(edge == 1)[0], np.where(edge == -1)[0]):
        if e - s >= 10 and z[s:e].sum() >= 8:
            j = res + 15 * s
            blok.append((2 * j, [(int(p[j + 15 * k]), int(r[j + 15 * k])) for k in range(e - s)]))
blok.sort()
print("blok tabel petak:", len(blok), "offset:", [o for o, _ in blok])
if '--rinci' in sys.argv:
    for off, pairs in blok: print(off, [x for x in pairs if x[0] > 0])
def scan_tim(d):
    n, hits = len(d), 0
    i = d.find(b'\x10\x00\x00\x00')
    while i != -1:
        ok = False
        try:
            flag = struct.unpack_from('<I', d, i + 4)[0]
            pm, clut, pos = flag & 7, bool(flag & 8), i + 8
            ok = (flag & ~0xF) == 0 and pm <= 4
            if ok and clut:
                ln, x, y, w, h = struct.unpack_from('<IHHHH', d, pos)
                ok = 0 < w <= 256 and 0 < h <= 256 and ln - 12 == w * h * 2 and pos + ln <= n
                pos += ln
            if ok:
                ln, x, y, w, h = struct.unpack_from('<IHHHH', d, pos)
                ok = 0 < w <= 1024 and 0 < h <= 1024 and ln - 12 == w * h * 2 and pos + ln <= n
        except struct.error:
            ok = False
        if ok:
            hits += 1; i = pos + ln
        else:
            i += 1
        i = d.find(b'\x10\x00\x00\x00', i)
    return hits
print("gambar TIM valid:", scan_tim(data))
