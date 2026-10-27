#!/usr/bin/env python3
"""Pindai string (ASCII dan Shift-JIS, diakhiri NUL, diawali NUL/awal berkas) di exe.bin (basis 0x80010000).
Pakai: cari_string.py EXE_BIN KELUARAN_STR [BASIS_HEX]
KELUARAN_STR (sementara, di runner, TIDAK dikomit): baris  ALAMAT<TAB>ENC<TAB>PANJANG<TAB>TAG<TAB>TEKS
stdout (boleh masuk log/ringkasan): hanya angka dan alamat, tanpa teks game."""
import sys

exe, outp = sys.argv[1], sys.argv[2]
base = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0x80010000
b = open(exe, "rb").read()
n = len(b)

# kata kunci dialog yang teramati di layar (lihat STATUS_RINGKAS.md); tag ASCII supaya aman dicetak
KUNCI = {
    "kekkai": "結界",
    "chakra": "チャクラ",
    "kougeki": "攻撃",
    "reberu": "レベル",
    "hari": "はりますか",
    "taikyu": "耐久値",
    "nanjutsu": "忍術",
    "hissu": "必要",
}
ENCS = ["shift_jis", "euc_jp", "utf-8"]


def sjis_valid_pair(c1, c2):
    return (0x81 <= c1 <= 0x9F or 0xE0 <= c1 <= 0xFC) and (0x40 <= c2 <= 0x7E or 0x80 <= c2 <= 0xFC)


res = []
i = 0
while i < n:
    if b[i] == 0:
        i += 1
        continue
    j = i
    dbl = 0
    ok = True
    while j < n and b[j] != 0:
        c = b[j]
        if 0x20 <= c < 0x7F or c == 0x0A:
            j += 1
        elif j + 1 < n and sjis_valid_pair(c, b[j + 1]):
            dbl += 1
            j += 2
        elif 0xA1 <= c <= 0xDF:
            j += 1
        else:
            ok = False
            break
    if ok and j < n and b[j] == 0:
        ln = j - i
        raw = b[i:j]
        if dbl >= 2 and ln >= 4:
            try:
                txt = raw.decode("shift_jis")
                res.append((i, "sjis", ln, txt, raw))
            except UnicodeDecodeError:
                pass
        elif dbl == 0 and ln >= 5 and all(0x20 <= c < 0x7F for c in raw):
            res.append((i, "ascii", ln, raw.decode("ascii"), raw))
        i = j + 1
    else:
        while j < n and b[j] != 0:
            j += 1
        i = j + 1

kb = {t: {e: k.encode(e) for e in ENCS} for t, k in KUNCI.items()}
nflag = 0
with open(outp, "w", encoding="utf-8") as f:
    for off, enc, ln, txt, raw in res:
        tags = [t for t in KUNCI if kb[t]["shift_jis"] in raw] if enc == "sjis" else []
        if tags:
            nflag += 1
        t1 = txt.replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t").replace("\r", "")
        f.write("%08X\t%s\t%d\t%s\t%s\n" % (base + off, enc, ln, "+".join(tags) if tags else "-", t1))

print("CARI_STRING: berkas=%d byte basis=0x%08X" % (n, base))
print("  string_ascii=%d string_sjis=%d (ditandai kata kunci: %d)" % (
    sum(1 for r in res if r[1] == "ascii"), sum(1 for r in res if r[1] == "sjis"), nflag))
print("  pencarian kata kunci di SELURUH berkas (jumlah kemunculan per pengkodean; alamat pertama):")
for t in KUNCI:
    parts = []
    for e in ENCS:
        k = kb[t][e]
        cnt = b.count(k)
        first = b.find(k)
        parts.append("%s=%d%s" % (e, cnt, (" @0x%08X" % (base + first)) if cnt else ""))
    print("   %-9s %s" % (t, "  ".join(parts)))
