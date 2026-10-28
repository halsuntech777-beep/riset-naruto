# progress.md — jalur analisis KODE (agen otonom; pengguna tidak menjawab)
Dibuat 2026-10-28 (chat x14). Alamat ditulis lengkap 0x80xxxxxx (0x70EB8 = 0x80070EB8).

## Status langkah
| Langkah | Status | Kriteria kurang |
|---|---|---|
| 1 Dump RAM netral | SEBAGIAN (run ak1 dikirim) | uji netral 3/3, dump identik antar-run, daftar frame tercatat — menunggu hasil run |
| 2 Impor dump ke Ghidra | belum | |
| 3 P1 RNG + roulette | belum | |
| 4 P2 klaim petak/harga/bonus | belum | |
| 5 P3 battle/level/menang | belum | |
| 6 Dokumentasi akhir | belum | |

## Keputusan dan alasan
- D1: probe_dump.lua = salinan probe.lua v5 (commit 53bf754), BUKAN v6 di main (v6 tidak netral 8/16). v5 sudah punya DUMPS (2 MB ke folder sementara runner). Jadwal replay: r13_a (papan->serang->duel) dan s4_F (roulette->prompt beli 260), diberi header SPUSPEED 4 + NODEBUG (kecepatan saja; terbukti netral di STATUS.md x1) dan tanpa SVS/SHOT/BOT. Poke jalur baku r13 (chakra B1 5000 @9000/@13000; ORPOKES bendera kristal 14000-36000).
- D2: workflow BARU .github/workflows/analisis-kode.yml + ci/analisis_kode.sh; file lama tidak diubah. Memakai secret PRIVATE_REPO/PRIVATE_TOKEN hanya-baca (sama dengan analisis-statis, sudah disetujui pemilik).
- D3: tiga emulator paralel per lot (salinan squashfs-root terpisah) agar muat 30 menit: baseline, dump#1, dump#2. Dump antar-run dibandingkan byte demi byte; chg (POKE/ORPOKE/CHG) dibandingkan dengan baseline.
- D4: frame dump: A=r13_a: 24500 (dialog papan), 26659 (satu frame sebelum CIRCLE penghenti@26660), 26900 (setelah berhenti), 27500 (prompt serang), 28700 (menu duel). B=s4_F: 26699 (sebelum CIRCLE@26700), 27000 (prompt beli 260), 27200 (setelah beli). Alasan: keadaan papan diam, roulette, prompt beli, duel; frame -1 untuk uji prediksi roulette (langkah 3d).
- D5: xref dilakukan di Python (pelacak konstanta lui/addiu/ori -> alamat load/store) pada dump; Ghidra dipakai untuk impor, fungsi, dan nanti dekompilasi. Keluaran hanya alamat/angka.
- D6: kunci publik ci/shot_pub.pem tidak dipakai; tidak ada bahan mentah yang dikomit.

## Run dipakai (anggaran: maks 6 emulator + 10 Ghidra per langkah; 50 total)
- ak1: run 40635403327 (tahap E,P; emulator 6 replay paralel, tanpa Ghidra), dikirim 04:59 UTC (11:59 WIB), perkiraan selesai 05:17 UTC (12:17 WIB), baca aman 05:22 UTC (12:22 WIB). Pemakaian: emulator 1/6, Ghidra 0/10, total 1/50.

## Rencana berikutnya
1. Baca hasil ak1 (analisis_kode/hasil/ak1_*/ringkas.txt dan analisis.txt): netral, identik, peta wilayah, pencocokan overlay ke DATA.BIN/DATA2.BIN/XASECT.BIN, xref penulis chakra.
2. Bila lolos: jalankan tahap E,P,G (Ghidra) dan catat; lanjut langkah 2 lalu 3.
