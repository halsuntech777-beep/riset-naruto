# STATUS (baca ini dulu)

Keadaan terakhir riset game PS1 *Naruto: Shinobi no Sato no Jintori Gassen* untuk TileDuel. Detail: `catatan_riset.md`. Riwayat chat: `riwayat/kronologi_chat.md`.

## Sudah terbukti
- Papan Hutan Konoha: 22 petak, tabel harga/sewa di `DATA.BIN` (juga ke-16 blok lain di `data/tabel_papan.json`); sewa = kolom tabel (85 untuk harga 160 dibayar sungguhan).
- Modal awal 1500; klaim petak dibayar ke bank; kartu di petak kartu (#6 dan #19).
- **Bonus start = 400 + 50% x jumlah 結界価値 semua barrier milik pemain** (結界価値 petak milik = angka sewa saat ini di gem; setara 25% x harga untuk petak tanpa upgrade). Dibaca dari layar "laporan chakra" dan cocok persis di 3 sampel: tutorial P1 (250 -> 125 -> 525), P2 (260 -> 130, laporan: x3 +130 -> 530), P1 (470 -> 235, laporan: x7 +235 -> 635). Tidak lagi butuh asumsi pengali level. Lihat catatan bagian 13.
- Pemicu bonus: kedua kristal terlewati lalu mendarat tepat di start (bendera struct pemain +4, penghitung posisi +112).

## Dugaan kuat
- Tabel di executable `0x8006491C` (16 entri x 48 byte) berisi 12 angka per entri yang tampak seperti isi roda roulette per karakter.

## Terbuka (urut prioritas)
1. Pemeriksaan kecil: baca panel 結界価値 petak level 2 (idx0/idx1, harapan 60); panel hanya terbaca untuk petak di bawah bidak (idx19: level 1, 結界価値 50).
2. Cocokkan tabel roda dengan roda di layar tiap karakter.
3. Biaya/efek level-up, daftar kartu lengkap, jurus dan battle.
4. Nama 8 papan dan 8 karakter terkunci; pemetaan 11 tabel papan ke stage.

## Runner GitHub Actions (sesi ini: rancangan siap, BELUM pernah dijalankan)
- [TERBUKTI] Repositori ini **publik** (API: private=false), padahal `LANJUTKAN_DI_CHAT_BARU.md` menyebut privat. Log Actions repositori publik terlihat semua orang.
- [TERBUKTI] Token yang dipakai hanya Contents read/write: bisa push `ci/`, tapi **tidak** bisa menulis `.github/workflows/`. Karena itu workflow ada di `ci/emulator-run.yml` dan harus disalin pemilik ke `.github/workflows/emulator-run.yml` lewat web GitHub.
- [TERBUKTI] Lolos uji lokal di sandbox: sintaks bash dan YAML, kompilasi `shim243.c` dengan gcc, sintaks dan logika `ORPOKES` di `probe.lua` (luajit), ekstraktor angka `ci/ekstrak_dump.py`, regex validasi input.
- [TERBUKTI] Runner berjalan: run `uji` (Party Mode 2P, `inputs_2p.txt`, MAXF 7000) selesai rc 0 dalam sekitar 2 menit. Run kedua dengan parameter sama menghasilkan `chg.log` identik (md5 ef944b1e1c4c6fd4c023caef78762b83), jadi deterministik di runner. Modal awal 1500 muncul di kedua pemain (B1/B2 di frame 4062; A1/A2 di frame 5151 dan 5191), cocok dengan temuan lama. Hasil: `hasil/uji_39360077180-1/` dan `hasil/uji2_39360327921-1/`.
- [BELUM] Dibandingkan dengan log sandbox (tidak ada log acuan di repositori); hasil runner ini sekarang jadi acuan. Nilai A3/A4 (pemain 3/4) tidak bermakna di run 2 pemain.
- Pelajaran: nama aset di release `aset` bebas; skrip memilih berkas `.bin` sebagai game dan `.AppImage`/`.zip` sebagai emulator (`.cue` diabaikan). Bila unduh gagal, `hasil/<label>_<run>/galat_unduh.txt` memuat diagnosis tanpa data rahasia. Log Actions tidak bisa dibaca dari sandbox (host log diblokir), jadi semua diagnosis lewat berkas di `hasil/`.
- Rancangan: `ci/run_remote.sh` (unduh, bangun, jalankan, hasil), `ci/ekstrak_dump.py`, `probe.lua` kini mendukung `ORPOKES="frame[-frame2]@alamat@lebar@mask"` (OR-kan bit; mask boleh 0x...). Input workflow: jadwal, maxf, pokes, orpokes, dumps, addrs, label.
- Aman hak cipta: game dan emulator diunduh dari release `aset` di repositori **privat** (`game.bin`, `redux.AppImage`/`redux.zip`), hanya di folder sementara runner; skrip menolak bila sumber aset tidak privat. Tidak ada upload-artifact, tidak ada SHOTS. Yang di-commit hanya `hasil/<label>_<run>/` berisi `chg.log`, `ringkasan.txt`, `emu_tail.txt`, `dump_angka.csv` (angka), dengan penjaga ekstensi dan ukuran (maks 300 KB).
- Dua mode: (a) jadikan repositori ini privat, taruh release `aset` di sini, tanpa secret; (b) tetap publik, secret `PRIVATE_REPO` dan `PRIVATE_TOKEN` (Contents: read pada repositori privat). **Diputuskan pemilik: mode (b)** (repositori ini tetap publik; repositori privat terpisah menyimpan release `aset`; secret `PRIVATE_REPO` dan `PRIVATE_TOKEN`).
- Langkah berikutnya: kerjakan riset terbuka nomor 1 di runner (ORPOKES bendera kristal P1 + CROSS lalu DOWN + CIRCLE pada layar macet), satu langkah per sesi. Revoke token workflow sementara bila sudah tidak dipakai.

## Cara bekerja (pelajaran penting)
- Sandbox dibersihkan antar sesi dan proses latar belakang bisa dimatikan saat jeda lama. Jaga tiap run <= ±9 menit, pantau dengan `sleep` <= 295 detik, dan push hasil sesering mungkin.
- Run emulator deterministik: input yang sama = kejadian di frame yang sama. Jadwal input ada di `inputs/` (Party Mode 2 pemain: `inputs_2p.txt` dan `inputs_2lap.txt`).
- Memuat save-state dari Lua menyebabkan segfault; breakpoint Lua tidak menangkap kode game. Gunakan pemutaran ulang + dump RAM + ubah-memori (`probe.lua`).
- Unggah ulang di chat baru: PCSX-Redux (zip), `.bin` dan `.cue` game; emulator butuh shim glibc (`redux/`).
- Jangan simpan ke repo: game, emulator, screenshot, dump RAM (berhak cipta). Token tidak pernah disimpan di berkas.

## Rute buka papan lewat Story (percobaan 1: macet)
- Lihat `catatan_riset.md` bagian 14 dan `inputs/inputs_story.txt`. Papan pertama belum tamat; kartu memori masih kosong; belum ada papan lain terbuka. Langkah berikut: paksa bendera kristal P1 dan tangani layar macet (CROSS, DOWN + CIRCLE), lalu cek apakah tamat papan 1 membuka stage 2 di Party Mode.

## Sesi story1 (riset terbuka no. 1, satu langkah)
- Run `story1_39362950273-1`: jadwal `inputs/inputs_story2.txt` (= inputs_story sampai frame 21000, lalu tiap 160 frame: CIRCLE, RIGHT, CIRCLE, CROSS, DOWN, CIRCLE), MAXF 36000, POKES chakra P1=5000 di frame 9000 dan 13000, ORPOKES `14000-36000@70EBC@4@0x3000`. Selesai rc 0, 605 detik. Hasil di `hasil/story1_39362950273-1/`.
- [TERAMATI] ORPOKES bekerja: bendera struct P1 +4 berubah 0x30000 -> 0x33000 di frame 14000 dan tetap 0x33000 sampai 36000.
- [TERAMATI] Perubahan chakra terakhir di frame 19819 (P1 4640, P2 1680). Sesudahnya tidak ada CHG sama sekali sampai frame 36000.
- [TERAMATI] Dump angka struct P1 (0x70EB8, 120 byte): penghitung posisi (+112, 0x70F28) 9 di frame 20000, 11 di 24000, lalu tetap 11 sampai 36000; 0x70EC8 3 -> 4 lalu tetap 4. Jadi dari frame 24000 keadaan membeku, bukan lanjut bermain.
- [TERAMATI] Tidak ada bonus start atau akhir papan terlihat di angka (tidak ada lonjakan chakra).
- [DUGAAN] Layar macet belum teratasi oleh pola buta CROSS lalu DOWN + CIRCLE; mungkin butuh tombol lain (misal LEFT/RIGHT untuk memilih barrier) atau waktu berbeda. Tanpa layar, urutan tombol ditebak.
- [BELUM] Apakah tamat papan 1 membuka stage 2 di Party Mode; apakah progres tersimpan di kartu memori (tidak diukur di run ini; kartu memori tidak bisa dibaca tanpa mengubah skrip runner).
- Langkah berikutnya (usulan, satu sesi): tambahkan ke `probe.lua` hash angka framebuffer/RAM tiap N frame (hanya angka keluar) agar bisa mendeteksi apakah layar berubah saat tombol ditekan, lalu coba variasi tombol di frame 21000-24000. Bisa juga cetak angka ukuran berkas kartu memori (hanya angka).

## Sesi story3 (riset terbuka no. 1, satu langkah: hash + sapuan tombol)
- Perubahan: `probe.lua` kini mencetak `HSH f= ram=` (hash RAM penuh) dan `HSF f= fb= n=` (hash framebuffer) tiap 20 frame sejak frame 19000 (env HFROM/HSTEP); `ci/run_remote.sh` hanya menambah prefiks HSH|HSF pada penyaring chg.log (penjaga ekstensi/ukuran tidak disentuh). Jadwal baru `inputs/inputs_story3.txt` = story2 sampai frame 24000, lalu sapuan 14 tombol (UP DOWN LEFT RIGHT CROSS CIRCLE TRIANGLE SQUARE START SELECT L1 R1 L2 R2), jarak 200 frame; putaran 1 tekan 6 frame (mulai 24000), putaran 2 tekan 30 frame (mulai 26800).
- Run `story3_39378572071-1`: MAXF 30000, POKES/ORPOKES sama dengan story1, dump 22000 24000 27000 30000 (struct P1 0x70EB8+120). rc 0, 505 detik. Hasil: `hasil/story3_39378572071-1/`.
- [TERBUKTI] Instrumentasi tidak mengubah emulasi: baris CHG sebelum frame 24000 identik dengan story1, dan dump struct P1 di frame 24000 identik.
- [TERAMATI] `input=518`: semua nama tombol di jadwal terbaca probe.
- [TERAMATI] Hash framebuffer TIDAK berfungsi di runner: semua 551 sampel `fb=0 n=0` (takeScreenShot menghasilkan 0 byte di softgpu/xvfb, tanpa galat). Deteksi layar lewat screenshot gagal; jangan diulang tanpa cara lain.
- [TERAMATI] Hash RAM penuh berbeda di semua 551 sampel: RAM selalu berubah (penghitung/timer), jadi game tidak hang total di tingkat CPU; tetapi hash RAM penuh tidak bisa membedakan "layar menunggu tombol" dari "layar bergerak".
- [TERAMATI] Game TIDAK beku permanen. Dengan sapuan tombol, chakra P2 turun 1680 -> 1530 di frame 25575-25585 (5 langkah -10 tiap 2 frame, lalu -100 di frame 25585); P1 tetap 4640. Pada story1 (pola CIRCLE/RIGHT/CROSS/DOWN) tidak ada perubahan chakra sama sekali setelah frame 19819; di story3 juga tidak ada perubahan antara 19819 dan 25575.
- [TERAMATI] Struct P1: tidak berubah antara frame 22000, 24000 dan 27000 (penghitung posisi tetap 11); `0x70EC8` berubah 4 -> 5 di antara frame 27000 dan 30000 (di story1 tetap 4 sampai 36000).
- [DUGAAN] Pemicu ada di antara tombol yang ditekan sebelum frame 25575: UP 24000, DOWN 24200, LEFT 24400, RIGHT 24600, CROSS 24800, CIRCLE 25000, TRIANGLE 25200, SQUARE 25400. CIRCLE/RIGHT/CROSS/DOWN sudah gagal sendiri di story2, jadi kandidat terkuat UP, LEFT, TRIANGLE, SQUARE atau kombinasi/urutan tertentu; latensi tombol -> efek tidak diketahui. START (25600) ditekan sesudah perubahan, jadi bukan pemicunya.
- [DUGAAN] Penurunan 150 hanya di P2 dan P1 tidak berubah: bukan pembayaran sewa ke P1; sifat pastinya belum diketahui.
- [BELUM] Papan 1 tamat, stage 2 di Party Mode, progres di kartu memori (tidak diukur).
- Langkah berikutnya (usulan, satu sesi): bisect pemicu dengan run pendek (MAXF ~27000, jadwal = story2 sampai 24000 lalu SATU kandidat saja, mis. SQUARE di 24000; ulangi per kandidat) dan lihat apakah CHG P2 muncul dan berapa frame sesudahnya; tambahkan penghitung "jumlah kata RAM berubah per sampel" (angka) sebagai ukuran aktivitas bila perlu. Setelah pemicu diketahui, lanjutkan ke tamat papan 1 dan ukuran kartu memori (angka saja).

## Aturan yang direvisi (permintaan pemilik: lanjut dari tengah permainan, setelah sesi story3)
- Dilonggarkan: (1) percobaan save-state (simpan dan muat) boleh, asalkan berkas state hanya ada di folder sementara runner dalam satu run dan yang keluar tetap angka. Tujuan: uji apakah segfault muat-state bisa dihindari (muat sebelum -run, opsi CLI, API Lua lain). [BELUM]. (2) Run paralel per label boleh (ubah `concurrency` workflow menjadi per label). (3) Teks bantuan/versi emulator (bukan isi game) boleh dicetak ke `hasil/*.txt` untuk mencari opsi CLI.
- Syarat sebelum state boleh disimpan LINTAS run: pemilik menjadikan repositori ini PRIVAT lewat web GitHub (token sesi tidak punya izin Administration). Alasan: cache/artefak/log repositori publik bisa dijangkau pihak lain, dan state berisi isi RAM game (berhak cipta). Setelah privat: `actions/cache` untuk state (tanpa secret). Belum diputuskan.
- Tetap berlaku (alasan hak cipta dan keamanan, bukan sekadar kenyamanan): tidak ada .bin/.cue, screenshot, dump RAM, atau save-state di repositori/release/artefak/log publik; penjaga ekstensi dan ukuran di `ci/run_remote.sh` tetap; sesi chat tidak memakai atau meminta izin Secrets dan tidak menyentuh repositori aset.

## Visibilitas repositori (diubah pemilik, sesi story3)
- [TERBUKTI] Repositori ini sekarang PRIVAT (API dengan token: private=true; clone tanpa token ditolak). Catatan lama yang menyebut "publik" di STATUS.md/README sudah tidak berlaku.
- Akibat: syarat "repo privat" untuk menyimpan state lintas run terpenuhi; `actions/cache` boleh dicoba untuk save-state (tanpa secret). Larangan save-state/dump/screenshot di release/artefak publik tetap berlaku. Uji save-state dalam satu run (simpan di frame 24000, muat di 26000, bandingkan angka struct P1) tetap langkah pertama; bila segfault berlanjut, penyimpanan lintas run tidak perlu dikerjakan.
- Minta pemilik mengurangi/revoke izin Administration pada token setelah sesi.
