"""Membuat data/tabel_papan.json dari DATA.BIN (disc SLPS-03553).
Pakai: python3 buat_tabel_papan_json.py <path.bin> <keluaran.json>
Record 30 byte (15 u16): [0]=harga [1]=sewa [2..5]=4 nilai [6..8]=3 nilai [9]=x [10]=y [11]=kode1 [12]=kode2 [13]=65535 [14]=255."""
import mmap, struct, sys, json
import numpy as np
P, OUT = sys.argv[1], sys.argv[2]
f = open(P, 'rb'); mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
LBA, LEN = 212, 66015232
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
            blok.append((2 * (res + 15 * s), int(e - s)))
blok.sort()
groups = {}
for off, n in blok:
    recs = []
    for k in range(n):
        v = struct.unpack_from('<15H', data, off + 30 * k)
        if 0 < v[9] < 2000 and 0 < v[10] < 2000:
            recs.append([k, v[0], v[1], v[9], v[10], list(v[2:6]), list(v[6:9]), v[11], v[12]])
    key = json.dumps([[x[1], x[2], x[3], x[4]] for x in recs])
    groups.setdefault(key, {'offs': [], 'recs': recs})['offs'].append(off)
papan = sorted(groups.values(), key=lambda g: g['offs'][0])
h2s = {}
for g in papan:
    for x in g['recs']:
        if x[1] > 0: h2s.setdefault(x[1], set()).add(x[2])
meta = {"sumber": "DATA.BIN (LBA 212) disc SLPS-03553, Naruto: Shinobi no Sato no Jintori Gassen (PS1)",
        "format_petak": ["k_dalam_blok", "harga", "sewa", "x", "y", "empat_nilai(arti belum diketahui)", "tiga_nilai(arti belum diketahui)", "kode1", "kode2"],
        "catatan": "Harga=0 berarti petak tidak bisa dibeli (start/kartu/bola). Koordinat x,y berjarak 40 antar petak. Papan B1 terbukti identik dengan tabel di RAM saat stage Hutan Konoha (Party Mode dan tutorial). Pemetaan papan lain ke stage belum diketahui."}
lines = ['{', '"meta": ' + json.dumps(meta, ensure_ascii=False) + ',',
         '"harga_ke_sewa": ' + json.dumps({str(k): sorted(v) for k, v in sorted(h2s.items())}) + ',', '"papan": [']
blocks = []
for i, g in enumerate(papan, 1):
    recs = g['recs']; pr = [x[1] for x in recs if x[1] > 0]
    head = {"id": "B%d" % i, "offset_data_bin": g['offs'], "jumlah_petak": len(recs), "jumlah_petak_berharga": len(pr), "total_harga": sum(pr)}
    if i == 1: head["stage"] = "Hutan Konoha (ホノ葉の森), terbukti"
    blocks.append(json.dumps(head, ensure_ascii=False)[:-1] + ',"petak":[\n' + ',\n'.join(json.dumps(x) for x in recs) + ']}')
lines.append(',\n'.join(blocks)); lines.append(']'); lines.append('}')
open(OUT, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
d = json.load(open(OUT, encoding='utf-8'))
print("papan unik:", len(d['papan']), "| blok total:", sum(len(b['offset_data_bin']) for b in d['papan']), "| ukuran:", len(open(OUT, 'rb').read()), "byte")
for b in d['papan']: print(b['id'], "petak", b['jumlah_petak'], "berharga", b['jumlah_petak_berharga'], "total", b['total_harga'], "salinan", len(b['offset_data_bin']))
