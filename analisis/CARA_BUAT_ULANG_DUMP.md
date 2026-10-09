# Cara membuat ulang dump RAM

Dump RAM (2 MB per frame) **tidak disimpan** di repositori: isinya salinan kode dan data game berhak cipta. Karena emulator deterministik (input yang sama menghasilkan memori yang sama persis di frame yang sama), dump apa pun bisa dibuat ulang. Berkas `*.bin` dan `*.raw` sengaja diabaikan lewat `.gitignore`.

## Perintah dasar

Skrip: `redux/lua_mine/probe.lua`, peluncur: `redux/run_headless.sh` (sesuaikan path `.cue` dan lokasi emulator di dalamnya).

```
OUTDIR=/tmp/dump INPUTS=<jadwal.txt> MAXF=<frame_berhenti> DUMPS="<frame> <frame>" \
  SHOTS="<frame>" POKES="frame@alamat_hex@lebar@nilai,..." \
  ./run_headless.sh /path/ke/probe.lua <batas_detik>
```
Hasil: `OUTDIR/r_<frame 5 digit>.bin` (RAM 2 MB, alamat game = 0x80000000 + offset), `f<frame>.raw` (screenshot 320x240). Format baris jadwal: `<frame_mulai> <TOMBOL> <lama_frame>`.

## Dump yang pernah dibuat

| Dump | Jadwal input | Perintah / tujuan | Bisa dibuat ulang? |
|---|---|---|---|
| Party Mode, frame 7000 (dan 7600) | `inputs/inputs_base.txt` (baris dengan frame < 6900) | `MAXF=7050 DUMPS="7000"`; berisi tabel petak Hutan Konoha di RAM | Ya |
| Layar pilih kartu Party Mode | `inputs/inputs_cp.txt` / `inputs_cq.txt` / `inputs_cr.txt` | kartu muncul ±frame 7720; chakra Sasuke 1500 -> 1900 setelah kartu +400 | Ya |
| Story tutorial: 9300, 10040, 10075, 10755, 10790, 14200, 14600, 14640, 15560, 15580 | jadwal tutorial (HILANG) | sebelum/sesudah klaim, sewa, dan bonus +525 di petak start | Tidak persis, jadwal harus disusun ulang |
| Uji poke bonus | jadwal tutorial (HILANG) | `POKES="15400@13C81E@2@460,15400@13C148@2@120"` -> bonus tetap 525 | Tidak persis |
| Uji poke sewa | jadwal tutorial (HILANG) | `POKES="14000@13C820@2@133"` -> uang berpindah 133 | Tidak persis |

## Cara membaca dump

- Tabel petak: pasangan u16 (harga, sewa) di `0x8013BA6E` (record #0) dengan jarak antar record `0x124` (292 byte). Offset di dump = alamat - 0x80000000.
- Uang mode 2 pemain: `0x801EFBBC` (P1) dan `0x801EFC4C` (P2). Alamat uang untuk 4 pemain belum dicari.

```python
import struct
d = open('r_07000.bin', 'rb').read()
for k in range(-2, 20):
    harga, sewa = struct.unpack_from('<HH', d, 0x13BA6E + k * 0x124)
    print(k, harga, sewa)
```
