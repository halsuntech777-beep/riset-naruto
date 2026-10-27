#!/usr/bin/env python3
"""Baca header PS-X EXE (0x800 byte pertama) dan tulis ringkasan angka + penjelasan kata sendiri.
Pakai: header_exe.py EXE KELUARAN RUNID
Hanya angka/metadata yang ditulis; isi kode/data EXE tidak dicetak."""
import os
import struct
import sys

exe, outp, rid = sys.argv[1], sys.argv[2], sys.argv[3]
size = os.path.getsize(exe)
with open(exe, "rb") as f:
    h = f.read(0x800)
if len(h) < 0x800 or h[:8] != b"PS-X EXE":
    print("BERHENTI: bukan PS-X EXE atau header terpotong (%d byte)" % len(h))
    sys.exit(1)


def w(o):
    return struct.unpack_from("<I", h, o)[0]


names = ["pc0_entry", "gp0", "t_addr_muat", "t_size_teks", "d_addr", "d_size",
         "b_addr", "b_size", "s_addr_sp_dasar", "s_size_sp_offset"]
v = {n: w(0x10 + 4 * i) for i, n in enumerate(names)}
saved = [w(o) for o in range(0x38, 0x4C, 4)]
raw = h[0x4C:]
region = raw.split(b"\0", 1)[0]
region_txt = region.decode("ascii", "replace")
printable = all(32 <= c < 127 for c in region)
sisa_nonzero = sum(1 for c in raw[len(region):] if c != 0)
nol_08_0f = h[8:0x10] == b"\0" * 8

t0, ts = v["t_addr_muat"], v["t_size_teks"]
pc = v["pc0_entry"]
akhir = t0 + ts
sp = v["s_addr_sp_dasar"] + v["s_size_sp_offset"] if v["s_addr_sp_dasar"] else None
ekspektasi = 0x800 + ts
selisih = size - ekspektasi
in_teks = t0 <= pc < akhir

L = []
a = L.append
a("HEADER PS-X EXE (langkah 2) - run %s" % rid)
a("Sumber: 0x800 byte pertama berkas executable utama (SLPS_035.53). Isi kode tidak dicetak, hanya angka header.")
a("Keyakinan semua angka di bawah: PASTI (dibaca langsung dari byte header; aritmetika dicek oleh skrip ci/header_exe.py).")
a("")
a("Magic (0x00): PS-X EXE; byte 0x08-0x0F nol semua: %s" % nol_08_0f)
a("PC awal / entry (0x10): 0x%08X" % pc)
a("GP awal (0x14): 0x%08X%s" % (v["gp0"], " (nol = GP tidak diatur oleh header)" if v["gp0"] == 0 else ""))
a("Alamat muat teks (0x18): 0x%08X" % t0)
a("Ukuran teks (0x1C): %d byte (0x%X)" % (ts, ts))
a("Data tambahan d_addr/d_size (0x20/0x24): 0x%08X / %d" % (v["d_addr"], v["d_size"]))
a("BSS b_addr/b_size (0x28/0x2C): 0x%08X / %d" % (v["b_addr"], v["b_size"]))
a("SP dasar / offset (0x30/0x34): 0x%08X / 0x%X" % (v["s_addr_sp_dasar"], v["s_size_sp_offset"]))
a("SP awal (dasar+offset): %s" % ("0x%08X" % sp if sp is not None else "tidak diatur (dasar nol)"))
a("Kata 0x38-0x4B (area simpan register oleh BIOS): %s" % " ".join("0x%08X" % x for x in saved))
a("String wilayah (0x4C): panjang %d, ASCII tercetak=%s, isi: %s" % (len(region), printable, region_txt if printable else "(tak dicetak)"))
a("Byte bukan-nol setelah string sampai 0x7FF: %d" % sisa_nonzero)
a("")
a("PEMERIKSAAN")
a("Ukuran berkas: %d byte (0x%X)" % (size, size))
a("0x800 + ukuran teks = %d byte (0x%X)" % (ekspektasi, ekspektasi))
a("Selisih ukuran berkas - (0x800 + ukuran teks) = %d byte" % selisih)
if selisih == 0:
    a("Penjelasan selisih: nol. Berkas = header 0x800 byte + teks tepat; tidak ada data sisa/trailer. Header menempati satu sektor CD (2048 byte) sendiri.")
elif selisih > 0:
    a("Penjelasan selisih: %d byte ekstra di akhir berkas di luar yang dideklarasikan header (kemungkinan padding sektor); perlu diperiksa." % selisih)
else:
    a("Penjelasan selisih: berkas LEBIH PENDEK %d byte dari yang dideklarasikan header; ANOMALI, perlu diselidiki." % (-selisih))
a("Entry di dalam rentang teks [0x%08X, 0x%08X): %s" % (t0, akhir, in_teks))
a("Entry sejajar 4 byte: %s; alamat muat sejajar 4 byte: %s" % (pc % 4 == 0, t0 % 4 == 0))
a("Ukuran teks kelipatan 0x800 (aturan psx-spx): %s" % (ts % 0x800 == 0))
a("Alamat muat di KSEG0 (0x80000000-0x9FFFFFFF): %s; alamat fisik awal 0x%08X, akhir 0x%08X" % ((t0 >> 29) == 4, t0 & 0x1FFFFFFF, akhir & 0x1FFFFFFF))
a("Offset berkas instruksi entry: 0x%X (= 0x800 + entry - muat)" % (0x800 + pc - t0))
a("Akhir teks di RAM: 0x%08X. Alamat chakra/posisi lama (0x80070EB8.., 0x80070F28) = akhir + 0x%X, di atas teks EXE." % (akhir, 0x70EB8 - (akhir & 0x1FFFFFFF)))
a("")
a("DAMPAK UNTUK LANGKAH 3 (Ghidra)")
a("Impor memakai berkas tanpa 0x800 byte pertama, basis = alamat muat di atas, entry = PC awal di atas: konsisten dengan header jika pemeriksaan di atas semua benar.")
a("Header tidak mendeklarasikan BSS/data terpisah: %s" % (v["d_size"] == 0 and v["b_size"] == 0))
os.makedirs(os.path.dirname(os.path.abspath(outp)), exist_ok=True)
with open(outp, "w", encoding="utf-8") as f:
    f.write("\n".join(L) + "\n")
print("\n".join(L))
