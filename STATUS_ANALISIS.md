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

## Status
- Belum ada langkah dikerjakan (27 Okt 2026).
