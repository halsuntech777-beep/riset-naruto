# progress.md — jalur analisis KODE (agen otonom; pengguna tidak menjawab)
Dibuat 2026-10-28 (chat x14). Alamat ditulis lengkap 0x80xxxxxx (0x70EB8 = 0x80070EB8).

## Status langkah
| Langkah | Status | Kriteria kurang |
|---|---|---|
| 1 Dump RAM netral | **TUNTAS** (run ak1 40635403327) | semua terpenuhi: 8 dump di 5+3 keadaan (dialog papan, sebelum CIRCLE penghenti, setelah berhenti, prompt serang, menu duel, prompt beli 260, setelah beli); uji netral POKE/ORPOKE/CHG identik dengan baseline 4/4 (A: 126 CHG, B: 94 CHG, rc=0); 8/8 dump identik byte-demi-byte antar-run; frame dan alasan di D4 |
| 2 Impor dump ke Ghidra | SEBAGIAN | belum: impor Ghidra (ak2 tahap G), pencocokan fungsi exe di hasil impor; sudah: basis 0x80000000 terbukti (exe cocok 99,66% kata, blok 64K 100% sampai 0x8004FFFF, 97% di 0x80060000), overlay dicocokkan ke DATA.BIN, peta tetap/berganti |
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

## Temuan (keyakinan: PASTI = bukti kode + uji; MUNGKIN = kode/data saja)
- PASTI: dump RAM replay deterministik dan netral (ak1). Waktu replay: lot 3 emulator paralel 130 dtk (A, 28.800 frame) dan 123 dtk (B, 27.300 frame).
- PASTI: kode game di atas exe tersimpan MENTAH (tak terkompresi) di DATA.BIN: 20 dari 20 jendela 128 B dari 5 wilayah kode cocok; pemetaan linear tunggal: alamat RAM 0x800B5000 = DATA.BIN+0x10C2BB0, dan selisihnya konsisten untuk wilayah 0x800C7000 (+0x10D4BB0), 0x800E3000 (+0x10F0BB0), 0x800F6000 (+0x1103BB0), 0x800FF000 (+0x110CBB0). Offset 0x10C2BB0 tidak sejajar sektor (mod 2048 = 944): awal blob overlay lebih rendah dari 0x800B5000; belum ditentukan.
- PASTI: wilayah kode zona atas identik di semua 8 dump (termasuk menu duel A28700): 0x800B5000-0x800C4000, 0x800C7000-0x800D2000, 0x800DF000-0x800E1000, 0x800E3000-0x800E9000, 0x800EB000-0x800EC000, 0x800F2000-0x800F4000, 0x800F6000-0x800FC000, 0x800FF000-0x8013A000 (59 halaman, 551 prolog). Papan->duel hanya mengganti data dan wilayah lain (22 rentang halaman, mis. 0x80070000-0x80073000, 0x80139000-0x80165000) — logika papan dan duel kemungkinan satu overlay.
- PASTI: exe di dump cocok 99,66% (321 kata beda, di data/BSS 0x80050000-0x8006D800).
- MUNGKIN: 0x80035D78 dipanggil 148 kali (4 di exe + 144 di overlay) — terlalu banyak untuk rand() khusus roulette; mungkin rand() umum (efek/AI) — roulette perlu dicari lewat tabel roda/fungsi lain.
- MUNGKIN (hasil negatif pelacak linear, bisa meleset di cabang): struct pemain 0x80070EB8 tidak terlihat diakses lewat konstanta lui/addiu di kode mana pun (akses=0, juga PRICE, TILES, CURSOR, WHEEL); hanya FLAG 0x80139F40-4C yang punya 48 akses (stor 28) di fungsi overlay 0x800F1290, 0x800F2490, 0x800F2A9C, 0x800F3100, 0x800F32B4, 0x800F34D0, 0x800F3658, 0x800F6078. Hipotesis: akses lewat gp (gp di header exe = 0) atau pointer — diuji di ak2 (deteksi gp, pemindai pointer ke 0x80070E00-0x80071200, pemindai konstanta 0xB4/0x124).

## Run dipakai (anggaran: maks 6 emulator + 10 Ghidra per langkah; 50 total)
- ak1: run 40635403327 (tahap E,P; emulator 6 replay paralel, tanpa Ghidra), dikirim 04:59 UTC (11:59 WIB), perkiraan selesai 05:17 UTC (12:17 WIB), baca aman 05:22 UTC (12:22 WIB). Hasil: sukses 05:22 UTC. Pemakaian: emulator 1/6, Ghidra 0/10, total 1/50.

- ak2: tahap E,P,G (dump + xref dengan gp + Ghidra B27000), dikirim setelah perbaikan an_dump.py. Pemakaian bila jalan: emulator 2/6, Ghidra 1/10, total 2/50.

## Rencana berikutnya
1. Baca hasil ak1 (analisis_kode/hasil/ak1_*/ringkas.txt dan analisis.txt): netral, identik, peta wilayah, pencocokan overlay ke DATA.BIN/DATA2.BIN/XASECT.BIN, xref penulis chakra.
2. Bila lolos: jalankan tahap E,P,G (Ghidra) dan catat; lanjut langkah 2 lalu 3.
