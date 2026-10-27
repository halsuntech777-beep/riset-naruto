#!/usr/bin/env python3
"""Langkah 1: inventaris berkas disc. Hanya metadata/angka (nama, ukuran, sha256, LBA, statistik, offset string). Tanpa isi berkas.
Pemakaian: inventaris.py DISC_DIR DISC_XML OUT.txt RUN_ID"""
import sys, os, re, hashlib, math, collections
import xml.etree.ElementTree as ET

disc, xmlp, outp, rid = sys.argv[1:5]
files = []
for dp, _, fn in os.walk(disc):
    for f in fn:
        p = os.path.join(dp, f)
        files.append((os.path.relpath(p, disc), os.path.getsize(p), p))
files.sort(key=lambda x: -x[1])

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()

attrs = {}
try:
    for el in ET.parse(xmlp).iter("file"):
        d = {k: v for k, v in el.attrib.items() if k not in ("source",)}
        attrs[(el.get("name") or "").upper()] = d
except Exception as e:
    attrs["_galat"] = {"xml": str(e)[:60]}

MAG = {b"\x10\x00\x00\x00": "TIM", b"\x41\x00\x00\x00": "TMD", b"pBAV": "VAB", b"pQES": "SEQ", b"RIFF": "RIFF", b"PS-X": "PSX"}
ZERO = bytes(2048)

def stat(p, size):
    nz = 0; jr = 0; sec = 0; sec_zero = 0; mags = collections.Counter(); psx = 0
    samp = collections.Counter(); nsamp = 0; uniq = set()
    with open(p, "rb") as f:
        head = f.read(16); f.seek(0)
        toc = [int.from_bytes(f.read(4), "little") for _ in range(512)]
        f.seek(0)
        while True:
            c = f.read(1 << 20)
            if not c:
                break
            nz += c.count(0)
            jr += c.count(b"\x08\x00\xe0\x03")
            for i in range(0, len(c) - 2047, 2048):
                s = c[i:i + 2048]
                if s == ZERO:
                    sec_zero += 1
                if s[:4] in MAG:
                    mags[MAG[s[:4]]] += 1
                if s[:8] == b"PS-X EXE":
                    psx += 1
                if sec % 64 == 0:
                    samp.update(s); nsamp += len(s); uniq.add(hash(s))
                sec += 1
    ent = -sum((v / nsamp) * math.log2(v / nsamp) for v in samp.values()) if nsamp else 0
    asc = sum(1 for a, b in zip(toc, toc[1:]) if b > a and a % 2048 == 0 and b % 2048 == 0 and b <= size)
    mb = size / 1048576
    return dict(head=head.hex(), nol=100 * nz / size, jr_per_mb=jr / mb if mb else 0, jr=jr, sektor=sec, sektor_nol=sec_zero,
                sektor_unik_sampel=f"{len(uniq)}/{nsamp // 2048}", entropi=ent, magic=dict(mags), psx_exe_sektor=psx, toc_naik=asc)

L = []
L.append(f"# Inventaris disc SLPS-03553 (dibuat ci/inventaris.py, run {rid}; hanya metadata/angka, tanpa isi berkas)")
L.append("# nama | ukuran(byte) | sha256 | atribut dari disc.xml (lba dsb)")
for n, s, p in files:
    L.append(f"{n} | {s} | {sha(p)} | {attrs.get(os.path.basename(n).upper(), {})}")
L.append(f"total_berkas={len(files)} total_byte={sum(f[1] for f in files)}")

cnf = [f for f in files if f[0].upper().endswith("SYSTEM.CNF")]
boot = None
if cnf:
    t = open(cnf[0][2], "rb").read().decode("ascii", "replace")
    L.append("SYSTEM.CNF: " + " ; ".join(re.sub(r"[^\x20-\x7e]", "?", l.strip()) for l in t.splitlines() if l.strip()))
    m = re.search(r"BOOT\s*=\s*cdrom:\\?([^;\s]+)", t, re.I)
    boot = m.group(1).split("\\")[-1] if m else None
exe = next((f for f in files if boot and os.path.basename(f[0]).upper() == boot.upper()), None)
L.append(f"exe_utama_dari_BOOT={boot}; berheader_PS-X_EXE={bool(exe) and open(exe[2],'rb').read(8)==b'PS-X EXE'}")

L.append("## Bukti calon overlay / berkas besar (angka)")
for n, s, p in files:
    if s < 1 << 20 or n.upper().endswith("SYSTEM.CNF"):
        continue
    if exe and p == exe[2]:
        continue
    st = stat(p, s)
    L.append(f"{n}: ukuran={s} magic16={st['head']} nol={st['nol']:.1f}% entropi_sampel={st['entropi']:.2f}b/byte sektor={st['sektor']} sektor_nol={st['sektor_nol']} sektor_unik_sampel={st['sektor_unik_sampel']}")
    L.append(f"   jr_ra_total={st['jr']} ({st['jr_per_mb']:.1f}/MB) magic_sektor={st['magic']} PS-X_EXE_sektor={st['psx_exe_sektor']} tabel_offset_naik={st['toc_naik']}/511")

if exe:
    d = open(exe[2], "rb").read()
    base = 0x80010000
    jrE = d.count(b"\x08\x00\xe0\x03")
    L.append(f"pembanding EXE utama: jr_ra_total={jrE} ({jrE / (len(d) / 1048576):.0f}/MB)")
    L.append("## String nama berkas di EXE utama (offset berkas -> alamat RAM, string)")
    seen = set()
    for needle in (b"DATA", b"DUMMY", b"XASECT", b"license", b".BIN", b".dat", b"cdrom"):
        for m in re.finditer(re.escape(needle), d, re.I):
            a, b = m.start(), m.end()
            while a > 0 and 0x20 <= d[a - 1] < 0x7f and m.start() - a < 24:
                a -= 1
            while b < len(d) and 0x20 <= d[b] < 0x7f and b - m.end() < 24:
                b += 1
            if needle in (b"DATA", b"license") and b"." not in d[a:b]:
                continue
            if (a, b) in seen:
                continue
            seen.add((a, b))
            L.append(f"  0x{m.start():X} -> 0x{base + m.start() - 0x800:08X}: {d[a:b].decode('ascii', 'replace')}")
open(outp, "w", encoding="utf-8").write("\n".join(L) + "\n")
print(f"INVENTARIS: berkas={len(files)} baris={len(L)}")
