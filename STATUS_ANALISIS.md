# STATUS ANALISIS STATIS ROM (jalur "logika game dari ROM")

Jalur terpisah dari jalur bot (STATUS_RINGKAS.md). Catat semua kemajuan jalur ini di berkas ini; sebelum dorong jalankan `git pull --rebase` (chat jalur bot mungkin menulis juga).

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
- [BELUM] Hasil run langkah 1-2 (lihat bagian di bawah bila sudah diisi).
