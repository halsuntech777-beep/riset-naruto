# STATUS ANALISIS STATIS ROM (jalur "logika game dari ROM")

Jalur terpisah dari jalur bot (STATUS_RINGKAS.md). Catat semua kemajuan jalur ini di berkas ini; sebelum dorong jalankan `git pull --rebase` (chat jalur bot mungkin menulis juga).


## RINGKASAN TERKINI (serah-terima ke chat baru, 27 Okt 2026) - BACA INI DULU

**SERAH-TERIMA (27 Okt 2026, akhir chat 2):** langkah 0-4 belum semua tuntas (1, 2, 3 TUNTAS; 0 dan 4 SEBAGIAN; 5-10 belum). Berikutnya: langkah 5 (buat kunci RSA baru dulu).
- Kunci privat RSA lama ada di sandbox chat lama dan HILANG. Ekspor terenkripsi hasil_analisis/l3_40514439054-1/*.enc.txt tak terbaca lagi. Bila perlu membacanya, buat kunci baru (privat di /home/claude/.kunci/, chmod 600; publik ke ci/shot_pub.pem), lalu jalankan ulang `alat/analisis.sh 3`; hash polos di out/ghidra_ekspor_manifest.txt untuk verifikasi (dekripsi: ci/dekripsi_berkas.py).
- Alat satu panggilan: `T=<token> bash alat/analisis.sh LANGKAH [DETIK<=280] [ALAMAT]` (dispatch + tunggu + tarik + ringkasan); `T=<token> bash alat/kerja.sh dorong "pesan"`.
- Ghidra 12.2 butuh JDK 25 (kelas versi 69). Uji kompilasi skrip lokal: apt-get update; apt-get install openjdk-25-jdk-headless; ambil jar dari rilis publik Ghidra_12.2_build (unzip '*.jar'), lalu javac -proc:none -cp <jar> skrip.java. Mencegah putaran runner yang sia-sia.
- Temuan penting L3 untuk langkah berikutnya: pemuat berkas kandidat = fungsi 0x800172EC (merujuk \\DATA2.BIN;1 dan \\XASECT.BIN;1); teks dialog Jepang tidak di EXE (cari di DATA.BIN/DATA2.BIN, langkah 7).
- Langkah 4(b)(d) dan 6 BLOKIR: butuh emulator/alamat RAM dari pemilik.

Aturan kerja ada di PROMPT_RISET.md (kriteria TUNTAS ketat, keyakinan PASTI/MUNGKIN/TEBAKAN, satu langkah per putaran, laporan 4 bagian). Bagian lama di bawah memakai label [TERBUKTI]/[TERAMATI]/[DUGAAN]/[BELUM] dan klaim "SELESAI" untuk langkah 3-4: abaikan klaim itu, pakai tabel ini.

| Langkah | Status | Ada (bukti) | Kurang |
|---|---|---|---|
| 0 alat/workflow | SEBAGIAN | out/versions.txt, out/izin_workflow.txt, ci/versi_pin.txt, uji kosong ok (run 40475745620) | bukti "tak ada rahasia di log" (log tak terbaca dari sandbox); pin versi pip |
| 1 inventaris disc | TUNTAS | out/inventory.txt (hash, BOOT, status calon overlay), cek repo bebas ISO | - |
| 2 header PS-X EXE | TUNTAS | out/header.txt (run 40477280135): entry 0x80011448, muat 0x80010000, teks 0x5D800, GP 0, SP 0x801FFFF0, BSS/data tak dideklarasikan, selisih ukuran 0 | - |
| 3 Ghidra | TUNTAS | out/ghidra_ringkas.txt + hasil_analisis/l3_40514439054-1 (ekspor fungsi/string/xref/wilayah-gagal terenkripsi; manifest out/ghidra_ekspor_manifest.txt) | - |
| 4 RNG | SEBAGIAN | kandidat 0x80035D78 (konstanta 0x41C64E6D, 48 B), pemanggil langsung di 0x80015ADC, 0x80015B7C, 0x8001A328, 0x80020BF4 (hasil_analisis/l4_*) | (a) state/RAM/seed, (b) uji determinisme, (d) verifikasi dinamis, (e) RNG ganda/non-fungsi, pemanggil tak langsung |
| 5-10 | belum | ci/ghidra/DekompilFn.java ditulis tetapi BELUM diuji | semua |

Temuan kunci: DATA.BIN [MUNGKIN] berisi kode MIPS (calon overlay; 16 byte awal = kata 4 + lui/addiu, 1577 jr ra, 269 sektor TIM, nama tak ada di EXE); DATA2.BIN [MUNGKIN] data/stream, dirujuk EXE (\DATA2.BIN;1 di RAM 0x8001003D); DUMMY.BIN [PASTI] pengisi nol. RAM chakra/posisi lama (0x70EB8.., 0x70F28) di atas akhir EXE (0x8006D800) => kode topik kemungkinan di overlay (langkah 7 penting). README memuat analisis/analisis_data_bin.py (pemindai tabel petak/TIM di DATA.BIN) sebagai bahan.

Cara kerja yang terbukti:
- Workflow: .github/workflows/analisis-statis.yml (salinan ci/analisis-statis.yml), hanya workflow_dispatch, input `langkah` (mis. "0", "1", "3,4") dan `alamat`. Skrip: ci/analisis_statis.sh (blok per langkah; Ghidra bersama untuk langkah 3/4; langkah 5+ belum). Skrip Ghidra: ci/ghidra/{SeedJal,StatFungsi,FindRng,DekompilFn}.java. Inventaris: ci/inventaris.py. Hasil angka dikomit runner ke hasil_analisis/l<langkah>_<runid>-1/ dan out/.
- Dispatch + tunggu (satu panggilan bash): POST /repos/.../actions/workflows/analisis-statis.yml/dispatches {"ref":"main","inputs":{"langkah":"N"}}, tunggu 8 dtk, ambil id run terbaru, loop status maks ~255 dtk, lalu `alat/kerja.sh tarik` dan baca berkas hasil. Run langkah 0-4 selesai 11-52 dtk.
- Log run TIDAK terbaca dari sandbox (host log diblokir); diagnosa lewat API /actions/runs/ID/jobs (nama langkah gagal) dan nalar. Skrip memakai `set -euo pipefail`: hati-hati pipeline yang gagal di dalam $( ) pada assignment.
- Jangan pakai `bash -c '...'` dengan tanda kutip tunggal di dalamnya; tulis skrip dengan create_file lalu jalankan.
- Kunci RSA untuk hasil mentah terenkripsi BELUM dibuat (kunci lama hilang): buat baru di sandbox (privat di luar repo, chmod 600), komit hanya ci/shot_pub.pem; pola enkripsi hibrida ada di ci/enkripsi_shot.py (AES-256-CBC + RSA-OAEP via openssl), dekripsi ci/dekripsi_shot.py. Kunci hilang bila sandbox berakhir: selesaikan langkah yang butuh dekripsi dalam satu chat.
- Pintu masuk cepat langkah 5: fungsi 0x80035D78 dan 4 pemanggilnya (maks ~8 fungsi per putaran).

## Tujuan dan persetujuan
- Tujuan pemilik: mendapatkan logika game PS1 "Naruto: Shinobi no Sato no Jintori Kassen" (SLPS-03553) langsung dari ROM: roulette, klaim wilayah, biaya/rampas chakra, rumus battle, syarat menang, RNG.
- [TERBUKTI] Persetujuan pemilik (27 Okt 2026, chat x13): BOLEH membuat workflow BARU `ci/analisis-statis.yml` (hanya `workflow_dispatch`) yang memakai secret PRIVATE_REPO dan PRIVATE_TOKEN (hanya baca) untuk mengunduh game.bin di runner. `ci/emulator-run.yml` dan `ci/run_remote.sh` TIDAK boleh diubah tanpa persetujuan baru. Tanpa loop tanpa pengawasan.
- Cakram hanya ada di runner: release "aset" di repo privat (lihat ci/run_remote.sh sekitar baris 20-54: PRIVATE_REPO/PRIVATE_TOKEN -> api.github.com releases/tags/aset -> game.bin; cue ada di redux/game/naruto.cue).

## 10 langkah (prompt pemilik)
1. Bongkar disc (dumpsxiso/mkpsxiso). Catat executable utama (biasanya SLPS_035.53) dan file besar lain (calon overlay).
2. Baca header PS-X EXE: alamat muat, entry point, ukuran.
3. Ghidra headless: MIPS little-endian 32-bit, alamat dasar dari header (atau loader PS1 komunitas). Ekspor daftar fungsi.
4. Cari generator angka acak (panggilan BIOS atau rumus sendiri). Daftar semua pemanggilnya.
5. Dekompilasi para pemanggil ke out/. Bandingkan dengan m2c untuk fungsi yang sama.
6. Cocokkan dengan alamat dari uji coba lama (chakra, level barrier, giliran). Cari kode yang menulis ke alamat itu.
7. Kode battle/roulette tak ketemu? Curigai overlay: impor file lain di alamat muatnya.
8. Jelaskan tiap fungsi dengan bahasa biasa: input, rumus, tabel yang dipakai.
9. Verifikasi: emulasi fungsi terisolasi (Unicorn) atau cocokkan dengan hasil uji save state. Catat cocok atau tidak.
10. Hasil akhir: out/logic.md per topik, berisi alamat, rumus, keyakinan, dan bukti.
Aturan pemilik: simpan hasil sebagai teks di out/; kerja per fungsi, jangan dump seluruh program; jawaban singkat, satu langkah per putaran; tandai keyakinan; macet 2 putaran = berhenti dan laporkan.

## Kesepakatan tambahan (dari saran Claude, disetujui pemilik)
- Tanda keyakinan memakai 4 tanda repo [TERBUKTI]/[TERAMATI]/[DUGAAN]/[BELUM]; "pasti" = [TERBUKTI] hanya bila cocok dengan log emulator/RAM.
- Repo PUBLIK + "Batas tetap": JANGAN taruh listing kode, dekompilasi, atau dump ROM di repo. Hasil mentah (daftar fungsi besar, dekompilasi) hanya dikirim terenkripsi (buat kunci RSA baru per chat, privat di luar repo, commit hanya ci/shot_pub.pem; lihat ci/enkripsi_shot.py dan ci/dekripsi_shot.py). Yang dikomit: out/logic.md (alamat, rumus, keyakinan, bukti) dengan kata-kata sendiri, serta angka/metadata (nama dan ukuran berkas, field header, jumlah fungsi).
- Langkah 4 (RNG): tujuan kita STRATEGI UMUM, bukan memprediksi dadu; catat RNG sebagai fakta bila ditemukan, jangan dipakai bot. Unicorn opsional; verifikasi utama = cocokkan dengan log RAM/emulator. Batasi sekitar 8 fungsi dibaca per putaran. Dekompilasi MIPS tanpa simbol (GTE, overlay) mudah salah tafsir: tiap temuan wajib bertanda dan dicocokkan dengan alamat RAM terbukti.

## Alamat RAM terbukti (untuk langkah 6; offset RAM PS1, KSEG0 = 0x80000000 + offset)
- Chakra pemain u32: B1 0x70EB8, B2 0x70F6C, B3 0x71020, B4 0x710D4 (jarak 0xB4). Posisi: P1 0x70F28, P2 0x70FDC (papan 22 petak; petak = pos mod 22).
- Harga di prompt beli: u16 0x1FFB90 (daerah tumpukan; valid saat prompt tampil).
- Data petak (level, harga/sewa): lihat BOT.tiles di redux/lua_mine/probe.lua dan data/tabel_papan.json; temuan game: STATUS_RINGKAS.md ("Hasil gelombang x17/x18", level-up dua langkah, prompt beli/serang).

## Rencana implementasi (usulan; belum dikerjakan)
- ci/analisis-statis.yml: input `langkah` dan `alamat`; unduh game.bin (pola run_remote.sh), mkpsxiso/dumpsxiso (rilis GitHub Lameguy64/mkpsxiso), Ghidra (rilis NationalSecurityAgency/ghidra; butuh JDK 21, ada di runner ubuntu); cek loader PSX bawaan, bila tidak ada impor mentah MIPS:LE:32 di alamat muat dari header. Satu putaran = satu run; hasil angka ke hasil_analisis/, mentah terenkripsi.

## Hasil kerja lama yang BOLEH dan SEBAIKNYA dipakai untuk 10 langkah (hanya bila membantu)
- Alamat RAM terbukti (bagian di atas) = jangkar langkah 6: cari kode yang menulis/membaca alamat itu. Harga di prompt beli = u16 0x1FFB90 (tumpukan): cari fungsi yang menghitung harga lalu memasangnya sebagai argumen/lokal sebelum dialog tampil.
- data/tabel_papan.json (harga, dan sewa bila ada, per petak) dan baris `BOT# I0 hs=` di STATUS: cari nilai-nilai ini sebagai tabel data statis di EXE/overlay (lokasi sumber tabel) lalu telusuri kode yang membacanya (klaim wilayah, sewa/biaya).
- Teks dialog Jepang terbukti dari layar: 「ここに結界をはりますか？ 必要チャクラ N」, 「ここを攻撃しますか？」 (kotak kiri: nama pemilik, レベル/結界価値/耐久値), 「結界をレベルアップしますか？」, 「レベルアップする結界をえらんでください」 (○ けってい / ✕ もどる), 「結界レベルが2になりました。」. Cari tabel string ini di EXE/overlay (coba Shift-JIS dan pengkodean khusus game) lalu cari kode yang merujuknya = pintu masuk logika beli/serang/level-up.
- Log emulator sebagai kunci jawaban rumus (langkah 9): hasil/*/chg.log (baris `CHG f= B1: a -> b` = perubahan chakra per frame, `P1:` posisi, serta `BOT# Q/R/Y/S/H`, `BOT# V/L/L6/W` untuk x17/x18) dari 16 dadu x beberapa gelombang. Petunjuk angka (BUKAN fakta, cocokkan dengan kode): harga beli teramati 60-260; chakra pelaku turun sekitar 50-150 pada level-up (COM 100-150); pada serang giliran COM chakra pelaku turun 60/72/84 pada banyak episode; level-up Naruto butuh dua langkah (pilih barrier lalu konfirmasi); serang giliran Naruto tak mengubah chakra dalam +1200 frame.
- Alat: `python3 alat/menang.py LABEL...` (definisi menang/kalah dan puncak chakra), `alat/ringkas.py`, `alat/analisis_v5v6.py`, redux/lua_mine/probe.lua (BOT.tiles, pembaca RAM, alat selisih RAM wdiff/scanfind), ci/pbx.py dan ci/pbsplit.py (kemungkinan pembaca save state PCSX-Redux; cek isinya untuk langkah 9), ci/ekstrak_dump.py (cek isinya).
- Pelajaran jalur bot yang relevan: run emulator deterministik pada v5 (16/16 identik) tetapi v6 menggeser hasil; untuk verifikasi langkah 9 pakai instrumen v5 (commit 53bf754) atau run tanpa instrumen tambahan, dan jangan menyimpulkan dari satu run.
- Hal yang TIDAK tersedia: gambar shot lama (kunci hilang; teksnya sudah dicatat di atas dan di STATUS_RINGKAS.md).

## Status
- [TERBUKTI] 27 Okt 2026: ci/analisis_statis.sh + ci/analisis-statis.yml (salinan di .github/workflows/) ditulis dan didorong; hanya workflow_dispatch (input langkah, alamat); memakai secret hanya-baca untuk unduh game.bin; hasil angka ke hasil_analisis/l<langkah>_<id>/ringkas.txt. Menyentuh langkah 1-2 saja; Ghidra (langkah 3+) belum dipasang di skrip.
- [TERBUKTI] Langkah 1-2 (run 40446736859, hasil_analisis/l1_2_40446736859-1/ringkas.txt): disc 7 berkas; exe utama SLPS_035.53 (385024 B); besar: DATA2.BIN 189832704, DATA.BIN 66015232, DUMMY.BIN 50667520 (tanpa header PS-X EXE). Header: muat 0x80010000, entry 0x80011448, ukuran teks 382976 (0x5D800), akhir kode 0x8006D800, sp 0x801FFFF0, gp 0.
- [TERAMATI] Alamat RAM terbukti (chakra 0x70EB8.., posisi 0x70F28) berada di atas akhir EXE (0x6D800): data/BSS pasca-EXE atau overlay, bukan teks EXE.
- [BELUM] Langkah 3 (Ghidra headless, BinaryLoader MIPS LE 32 basis 0x80010000, benih = entry + target jal): ci/ghidra/SeedJal.java dan StatFungsi.java; 
- [TERBUKTI] Langkah 3 SELESAI (run 40446987320, hasil_analisis/l3_40446987320-1/): Ghidra 12.2, JDK 21, loader BinaryLoader MIPS:LE:32:default basis 0x80010000, blok 382976 B. jal total 4265; target unik dalam rentang 899 (semua berhasil jadi benih). Fungsi total 1209 (entry 0x80011448 ada); cakupan 254192 B (66% blok); instruksi 64438; ukuran fungsi min 8 / median 100 / p90 516 / maks 3816; >=1000B: 37. [DUGAAN] sisa 34% = data/tabel di dalam teks atau kode yang hanya dicapai lewat jr/jalr (tabel lompat, penunjuk fungsi). Daftar fungsi rinci belum diekspor (perlu kunci RSA baru bila mau terenkripsi).
- [TERBUKTI] Langkah 4 SELESAI (run 40447340909, hasil_analisis/l4_40447340909-1/rng.txt; run pertama 40447284831 gagal karena skrip belum membongkar disc untuk langkah 4, sudah diperbaiki): kandidat LCG = 1: konstanta pengali 0x41C64E6D (1103515245) pada 0x80035D84 di fungsi 0x80035D78 (ukuran 48 B), pemanggil langsung (jal) 4 situs di 4 fungsi: 0x80015ADC, 0x80015B7C, 0x8001A328, 0x80020BF4. Stub BIOS rand/srand (A0:0x2F/0x30) = 0. [DUGAAN] 0x80035D78 = rand() gaya Psy-Q (next=next*1103515245+12345); belum dibaca isinya, belum dicocokkan dengan log. Pemanggil lewat jalr/penunjuk fungsi tak terhitung. Tujuan tetap strategi umum: dicatat saja, tidak dipakai bot.

## Penilaian ulang dengan kriteria TUNTAS ketat (prompt baru, 27 Okt 2026)
Skala keyakinan sekarang PASTI/MUNGKIN/TEBAKAN (terpisah dari status langkah TUNTAS/SEBAGIAN/BLOKIR). Ringkasan lama "selesai" untuk langkah 3 dan 4 DIBATALKAN: keduanya SEBAGIAN.
- Langkah 0: SEBAGIAN. Ada: out/versions.txt (Ghidra_12.2_build, mkpsxiso v2.30, m2c c632946, JDK 21.0.12.1, objdump 2.42, splat64 0.50.1, unicorn 2.1.4), out/izin_workflow.txt, uji jalan kosong berhasil (run 40475745620), versi Ghidra/mkpsxiso/m2c dipin di ci/versi_pin.txt. Kurang: bukti "tak ada rahasia di log" (log run tak terbaca dari sandbox; secara desain langkah 0 tak memakai secret); versi pip belum dipin.
- Langkah 1: SEBAGIAN. Ada angka berkas dan BOOT. Kurang: out/inventory.txt dengan hash semua berkas, status calon overlay + alasan untuk DATA.BIN/DATA2.BIN/DUMMY.BIN.
- Langkah 2: SEBAGIAN. Angka header ada di hasil_analisis/l1_2_*; kurang: out/header.txt dengan penjelasan selisih ukuran.
- Langkah 3: SEBAGIAN. Impor MIPS LE ok, 1209 fungsi, entry ada. Kurang: ekspor daftar fungsi/string/xref, bukti string punya xref ke kode, catatan area gagal disassemble dan instruksi GTE.
- Langkah 4: SEBAGIAN. Kandidat RNG 0x80035D78 (konstanta 0x41C64E6D) dan 4 pemanggil langsung. Kurang: (a) variabel state/alamat RAM/seed, (b) uji determinisme, (d) verifikasi dinamis (butuh emulator), (e) cek RNG ganda/sumber non-fungsi; pemanggil tak langsung belum ditandai.
- Catatan kebijakan: prompt baru menyebut dekompilasi mentah "privat di out/", tetapi repo PUBLIC: kesepakatan lama dipertahankan (mentah hanya terenkripsi; out/ hanya angka, metadata, kata-kata sendiri).

## Langkah 1 (27 Okt 2026, run 40476611966): TUNTAS
Bukti: out/inventory.txt (7 berkas dengan nama, ukuran, sha256, atribut disc.xml; BOOT dibaca; exe utama dikonfirmasi; status calon overlay + alasan untuk berkas besar). Cek repo: tak ada ISO/BIN cakram di repo (lihat hasil cek di laporan putaran). Temuan kunci: DATA.BIN [MUNGKIN] berisi kode MIPS (calon overlay, tanpa string nama di EXE); DATA2.BIN [MUNGKIN] data/stream (dirujuk EXE); DUMMY.BIN [PASTI] pengisi nol; XASECT.BIN dan license_data.dat bukan kode [MUNGKIN].

## Langkah 2 (27 Okt 2026, run 40477280135): TUNTAS
Bukti: out/header.txt (dibuat ci/header_exe.py di runner; angka dibaca dari 0x800 byte header, isi kode tidak dicetak). Semua kriteria terpenuhi: PC awal 0x80011448, alamat muat 0x80010000, ukuran teks 382976 (0x5D800), GP 0 (tak diatur), SP 0x801FFFF0 (dasar; offset 0); ukuran berkas 385024 = 0x800 + 0x5D800, selisih 0 (header satu sektor CD, tanpa trailer); entry di dalam rentang teks dan sejajar 4 byte. Catatan: SYSTEM.CNF memuat STACK = 801fff00 (nilai tumpukan untuk BIOS), beda dari SP awal di header (0x801FFFF0): dua hal terpisah, keduanya dicatat. Alat baru: alat/analisis.sh (dispatch + tunggu + ringkasan dalam satu panggilan: `T=<token> bash alat/analisis.sh LANGKAH [DETIK] [ALAMAT]`).

## Langkah 3 (27 Okt 2026, run 40514439054): TUNTAS
Alat baru: ci/ghidra/ExportLangkah3.java, ci/cari_string.py, ci/enkripsi_berkas.py (+ ci/dekripsi_berkas.py, hanya di sandbox pemilik kunci). Kunci RSA BARU: privat di sandbox di luar repo (chmod 600, hilang bila sandbox direset; kalau hilang buat kunci baru, hasil lama tak terbaca), publik ci/shot_pub.pem sudah diganti. Hash polos tiap berkas ada di out/ghidra_ekspor_manifest.txt dan cocok setelah dekripsi.
- [PASTI] Ghidra MIPS:LE:32:default, basis 0x80010000, 382976 byte, 1209 fungsi, 64418 instruksi, entry 0x80011448 jadi fungsi (172 byte, 2 panggilan keluar). Cakupan fungsi 66% blok; 304 fungsi tanpa pemanggil langsung (kemungkinan dipanggil lewat penunjuk/tabel; MUNGKIN).
- [PASTI] String di EXE hanya 78 (ascii 68, sjis 10). Ascii: 57 punya xref ke kode. Dua di antaranya nama berkas disc (\\DATA2.BIN;1 @0x8001003C, \\XASECT.BIN;1 @0x8001004C), keduanya dirujuk fungsi 0x800172EC: kandidat rutin pemuat berkas untuk langkah 7. 10 string sjis berukuran 4-7 byte tanpa xref: [MUNGKIN] salah deteksi.
- [TERAMATI] Teks dialog Jepang tidak ada di EXE: 8 kata kunci (結界, チャクラ, 攻撃, レベル, はりますか, 耐久値, 忍術, 必要) 0 kemunculan di Shift-JIS/EUC-JP/UTF-8. [DUGAAN] teks ada di DATA.BIN/DATA2.BIN atau memakai tabel huruf khusus.
- [PASTI] GTE: Ghidra mengenali MFC2/CFC2/MTC2/CTC2 (55 dari 56 kata) tetapi hanya 6 dari 13 kata perintah COP2 (0x4A/0x4B...) dan 19 dari 29 kata LWC2/SWC2 menjadi instruksi. 11 fungsi memuat kata GTE: 0x8003E3B0, 0x80043988, 0x80044588, 0x800445B8, 0x800445D8, 0x800445E8, 0x800450E8, 0x800459A8, 0x80045A38, 0x80045BB8, 0x80045E38 (kelompok 0x80043988-0x80045E38: [MUNGKIN] kode grafis, bukan logika). Kata COP2 yang tak terdisassemble: [MUNGKIN] sebagian data yang kebetulan mirip.
- [PASTI] Wilayah tak tercakup (bukan instruksi/data terdefinisi): 535 wilayah, 118352 byte (30% blok), 62532 byte kata nol. Hanya 6 kata prolog fungsi (addiu sp,sp,-N) di dalamnya, 117 wilayah memuat jr ra. Terbesar: 0x80055CF0 (61320 byte), 0x80068940 (16844), 0x80065DF4 (4136), 0x8001491C (3000), 0x80067D94 (2560); [MUNGKIN] tabel data, bukan kode. [MUNGKIN] ada fungsi daun tanpa prolog yang terlewat.
