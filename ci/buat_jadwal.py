#!/usr/bin/env python3
"""Buat jadwal input: awalan (baris dengan frame mulai < BATAS dari berkas dasar) + baris tambahan, plus header SVS.
Pemakaian: buat_jadwal.py DASAR.txt BATAS KELUAR.txt SVSFROM SVSSTEP "frame TOMBOL durasi" ..."""
import sys
dasar, batas, keluar, sf, ss, *extra = sys.argv[1:]
batas = int(batas)
rows = [l.rstrip("\n") for l in open(dasar) if l.strip() and int(l.split()[0]) < batas]
with open(keluar, "w") as f:
    f.write(f"# SVS from={sf} step={ss}\n")
    f.write("\n".join(rows + extra) + "\n")
