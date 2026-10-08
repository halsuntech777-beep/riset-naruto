# Cara membuat ulang dump RAM (tanpa menyimpannya)

Dump RAM berisi kode dan data game berhak cipta, jadi **tidak disimpan di repositori**. Run emulator ini deterministik (jadwal input yang sama menghasilkan memori yang sama persis), jadi dump bisa dibuat ulang kapan saja dari skrip di repositori ini.

## Prasyarat
Emulator PCSX-Redux (diekstrak dan ditambal, lihat `README.txt`), file game `.bin` + `.cue`, dan folder `redux/` serta `inputs/` dari repositori ini. Sesuaikan path `.cue` di `redux/run_headless.sh`.

## Contoh: dump Party Mode (frame 7000, papan Hutan Konoha berjalan)
```
cd redux
awk '$1 < 6900' ../inputs/inputs_base.txt > /tmp/inputs_rd.txt
mkdir -p /tmp/rd
OUTDIR=/tmp/rd INPUTS=/tmp/inputs_rd.txt MAXF=7050 DUMPS="7000" ./run_headless.sh $PWD/lua_mine/probe.lua 200
```
Hasil: `/tmp/rd/r_07000.bin` (2 MB = seluruh RAM PS1). Alamat RAM = `0x80000000` + offset berkas.

Opsi lain di `probe.lua` (lewat variabel lingkungan): `DUMPS="f1 f2 ..."` (dump), `SHOTS="f1 f2 ..."` (screenshot mentah 320x240), `POKES="frame@alamathex@lebar@nilai"` (ubah memori), `MAXF` (frame akhir).

## Alamat penting di dump papan Hutan Konoha
| Hal | Alamat |
|---|---|
| Tabel petak, record #0 (harga u16, lalu sewa u16) | `0x8013BA6E`, jarak antar record `0x124` (292 byte) |
| Uang pemain 1 dan 2 (mode 2 pemain, tutorial) | `0x801EFBBC` dan `0x801EFC4C` |

Mencari tabel di dump (pasangan harga/sewa beruntun dengan jarak 292 byte):
```python
import struct
d = open('r_07000.bin', 'rb').read()
pat = struct.pack('<2H', 100, 50)
i = d.find(pat)
while i != -1:
    if d[i+292:i+296] == pat and d[i+584:i+588] == struct.pack('<2H', 120, 60):
        print(hex(0x80000000 + i))   # harapan: 0x8013ba6e
    i = d.find(pat, i + 1)
```

## Yang tidak bisa dibuat ulang
Dump dari jalur tutorial Story Mode: jadwal inputnya hilang. Tabel petak hasil jalur itu sudah tersimpan di `data/tabel_papan.json`.
