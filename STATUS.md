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

## Visibilitas repositori (keputusan pemilik: kembali PUBLIK, sesi story3)
- [TERBUKTI] Repositori ini PUBLIK lagi (API: private=false; clone tanpa token berhasil). Alasan pemilik: bebas dari batas 2000 menit Actions repo privat; risiko diterima pemilik. Catatan "privat" di bagian sebelumnya sudah tidak berlaku.
- Konsekuensi: log Actions terlihat semua orang (skrip hanya cetak angka). Save-state lintas run hanya dengan enkripsi (`STATE_KEY` di secret, ditambah pemilik lewat web) atau tidak sama sekali; uji save-state satu run di dalam runner tetap boleh. Dilarang: save-state/dump/screenshot/.bin di repo, release, artefak, log.
- Pemilik berencana revoke token lama dan membuat token baru (Contents, Workflows, Actions; tanpa Administration) di chat baru.

## Sesi ss (uji save-state dalam satu run; 2 dari maks 5 percobaan terpakai)
Target: simpan state di frame 24000 (jadwal inputs/inputs_story3.txt), muat kembali setelah frame 26000, ulangi 24000-26000; periksa (1) rc 0, (2) angka sesudah muat identik dengan tanpa muat. State hanya di memori Lua, tidak pernah ditulis ke disk/repo.
- [TERAMATI] ss1 (run 39383740658, MODUS=nt = simpan/muat lewat PCSX.nextTick): `PCSX.createSaveState` dan `PCSX.loadSaveState` ada (tipe function; ada juga getSaveStateProtoSchema). Simpan di frame 24000 berhasil (ok=true, tipe=table, `#`=21163313). Hash RAM saat simpan sama dengan hash di handler Vsync frame 24000 (247000128), jadi tidak ada geseran frame antara Vsync dan nextTick.
- [TERAMATI] ss1: muat di frame 26000 lewat nextTick **segfault** (rc=139, 443 dtk); baris "SVS muat mulai f=26000" sampai ke stderr, "SVS muat selesai" tidak. Pemeriksaan (1) GAGAL pada modus nt. Pemeriksaan (2): [BELUM] (tak ada data pass 2). Baris pass 1 untuk frame 25500/26000 hilang karena stdout tidak di-flush saat crash (diperbaiki: setvbuf('line')).
- [TERAMATI] ss1: P1 word +0..+116 (struct 0x70EB8) di frame 24000, 24500, 25000 sama: 1220,33000,0,0,4,0,...,b,0. Catatan: cetakan itu BELUM mencakup +120 (uang P1); sudah diperluas ke 32 word (+0..+124) di probe.lua, belum diuji.
- [BELUM] ss2 (run 39384780977, MODUS=ps = pauseEmulator, muat, resumeEmulator): job dibatalkan batas 45 mnt; hanya bantuan.txt kosong yang ter-commit, tidak ada chg.log/emu_tail. Tidak diketahui apakah muat sempat dicoba. [DUGAAN] langkah `-help` (timeout tanpa -k) atau emulator ter-jeda menggantung; keduanya belum dibedakan. Dihitung sebagai percobaan terpakai.
- Perubahan infrastruktur (belum diuji): input workflow savef/loadf/modus; filter chg.log memuat prefiks SVS; timeout-minutes job 30; timeout emulator memakai `-k 20` dan 900 dtk bila SAVEF diisi; teks bantuan CLI hanya dicetak lewat MODUS=bantuan (tanpa menjalankan game, ke hasil/<label>_<run>/bantuan.txt, maks 200 baris x 200 karakter). Daftar nama API PCSX dicetak sebagai baris `SVS apiall` (hanya nama).
- Sisa rencana (3 percobaan): (a) run MODUS=bantuan (murah, bukan percobaan uji) untuk mencari opsi CLI muat-state dan memastikan -help tidak menggantung; (b) MODUS=vs (muat langsung di handler Vsync); (c) alternatif muat sebelum -run / opsi CLI (butuh state di berkas sementara runner dalam run yang sama; JANGAN simpan lintas run kecuali dienkripsi STATE_KEY dari secret yang ditambahkan pemilik sendiri; usulkan rancangan dulu).

## Sesi ss lanjutan (chat baru; percobaan uji game terpakai 4 dari maks 5, ss4 di bagian bawah)
- [TERAMATI] Run bantuan (bukan percobaan): `pcsx-redux -help` TANPA `-cli` gagal membuat jendela (galat GLX visual, run bantuan1/2) lalu menggantung sampai di-SIGKILL timeout. Dengan `-cli` (varian `-help`, `--help`, `-h`) tidak menggantung (rc 0) tetapi **tidak mencetak teks bantuan**; hanya log boot. Daftar opsi CLI TIDAK diperoleh dari -help.
- [TERAMATI] Pindai string biner emulator (hanya nama, `hasil/bantuan4_*/bantuan.txt`): ada `createSaveState`, `loadSaveState`, `getSaveStateProtoSchema`, event `ExecutionFlow::SaveStateLoaded`, identifier internal `loadSaveStateFromFile/FromSlice`. Tidak ada string opsi CLI bernama loadstate. [DUGAAN] belum ada opsi CLI muat-state (absennya string bukan bukti mutlak).
- [DUGAAN] Hang ss2 kemungkinan disebabkan langkah `-help` tanpa `-cli` (direproduksi di bantuan1), bukan MODUS=ps. Maka MODUS=ps (pauseEmulator, muat, resumeEmulator) praktis BELUM teruji, tetapi sudah dihitung sebagai percobaan terpakai.
- [TERAMATI] ss3 (run 39413180108, MODUS=vs, savef 24000, loadf 26000, maxf 26300, jadwal story3, pokes/orpokes seperti ss1): simpan ok (ukuran 21163814, ram hash 247000128 sama dengan ss1 di frame 24000; P1 words +0..+124 sama di 24000-26000). Muat langsung di handler Vsync frame 26000: **segfault, rc 139** (439 dtk); "SVS muat selesai" tidak muncul. Pemeriksaan (1) GAGAL; (2) tidak ada data pass 2. Hasil: `hasil/ss3vs_39413180108-1/`.
- [TERAMATI] Diagnostik TANPA game (BIOS bawaan, `redux/lua_mine/apiuji.lua`, MODUS=apiuji; bukan percobaan uji game): `createSaveState` mengembalikan `table` (metatable __index/__len/__newindex/__tostring). Muat objek itu langsung dengan `PCSX.loadSaveState(s)` di handler Vsync: **rc 0, tidak crash**, juga dengan `-debugger` (apiuji2). Jadi segfault pada run game BUKAN karena tipe argumen, handler Vsync, maupun `-debugger`.
- [TERAMATI] Jalur berkas: `Support.File.open(path,'TRUNCATE')` + `writeMoveSlice(state)` menulis **0 byte** (size=0); memuat berkas kosong itu segfault (rc 139). Tidak ada cara serialisasi state ke berkas yang diketahui, jadi "muat sebelum -run lewat berkas" tidak punya jalur yang jelas.
- [DUGAAN] Penyebab segfault pada run game: keadaan khusus game (CD/ISO terpasang saat muat, isi state 21 MB dari game, atau override pad Lua) yang tidak ada di uji tanpa game. Belum dibedakan.
- [BELUM] Pemeriksaan (2) (angka sesudah muat identik) tidak pernah tercapai. Uji berhasil: belum ada. Karena itu tidak ada rancangan STATE_KEY lintas run yang perlu diusulkan.
- Usulan percobaan ke-4 (satu saja, pilih pemilik): (A) MODUS=ps di run game (pause, muat, resume; sebenarnya belum teruji, lihat DUGAAN hang ss2); atau (B) tanpa save-state: pakai pemutaran ulang deterministik dari frame 0 (sudah terbukti identik, ~8-10 mnt per 30000 frame) dengan POKES/ORPOKES, tanpa memuat state. Pilihan B tidak memakai sisa percobaan.
- Perubahan infrastruktur: `ci/run_remote.sh` mode `bantuan` (3 varian `-cli` + pindai string biner) dan mode `apiuji` (menulis `api_uji.txt`: nama/tipe API Lua dan angka, tanpa game; berkas state sementara di temp runner dihapus). Penjaga ekstensi/ukuran di tahap `hasil` tidak diubah. Tidak ada upload-artifact; tidak ada .bin/.cue/screenshot/dump/state di repo.

## Sesi ss4 (percobaan ke-4, A: MODUS=ps) - GAGAL
- Run 39418535315 (label ss4ps): savef 24000, loadf 26000, maxf 26300, jadwal story3, pokes `9000@70EB8@4@5000,13000@70EB8@4@5000`, orpokes `14000-36000@70EBC@4@0x3000`. Hasil: `hasil/ss4ps_39418535315-1/`.
- [TERAMATI] Simpan ok di frame 24000 (tipe table, ukuran 21163313, ram hash 247000128, sama dengan ss1/ss3 di frame yang sama, jadi pemutaran ulang tetap deterministik). Di frame 26000 `pauseEmulator` dan `resumeEmulator` bertipe function; baris "SVS muat mulai" tercetak.
- [TERAMATI] Sesudah itu **segfault, rc 139** (441 dtk). Baris "SVS muat kembali" dan "SVS sesudah_muat" tidak pernah muncul, jadi crash terjadi di dalam `PCSX.loadSaveState` (atau tepat sebelumnya). Pemeriksaan (1) GAGAL; pemeriksaan (2) tidak tercapai (CHG2 = 0 baris).
- [BELUM] Apakah `pauseEmulator` sungguh berhasil: hasil pcall-nya tidak dicatat, jadi tidak diketahui. Yang pasti: pause+muat tidak mencegah segfault.
- [DUGAAN] Penyebab bukan tipe argumen/handler Vsync/-debugger/hang -help (sudah disingkirkan di ss3 dan apiuji). Tersisa: ISO terpasang saat muat, atau override pad Lua aktif saat muat, atau isi state 21 MB khusus game.
- Sisa percobaan uji game: **1** (dari maks 5). Belum dipakai.
- Kendala opsi (a): API Lua yang ada hanya `openIso` dan `getCurrentIso` (tidak ada closeIso), dan state hanya hidup di memori proses (serialisasi ke berkas 0 byte). Jadi "muat sebelum ISO dipasang" di proses yang sama belum punya jalur jelas. Opsi (b) (lepas semua override pad sebelum muat; bisa disertai pause) mudah dipasang dan menguji satu penyebab.
- Menunggu keputusan pemilik: pakai percobaan terakhir untuk (b), untuk (a) bila ada jalur, atau lewati ke cadangan pemutaran ulang deterministik dari frame 0 (tidak memakai percobaan; bisa dicoba `-dynarec` lalu cek hasil identik). Tidak membangun emulator dari sumber tanpa persetujuan.

## Sesi ss5 (percobaan ke-5, opsi (b): MODUS=pc) - muat BERHASIL tanpa crash; hash RAM penuh tidak identik
- Perubahan: `probe.lua` modus baru `pc` (modus nt/vs/ps tidak diubah): di frame muat -> `pauseEmulator` (pcall, hasil dicatat), `pad.clearOverride` untuk semua tombol di jadwal (14 tombol, pcall, hasil dicatat), `loadSaveState`, pasang ulang override sesuai frame setelah muat (aktif=1), `resumeEmulator`. Log (say) ditulis sebelum tiap langkah. Run 39515048504 (label ss5b), parameter seperti ss4. Hasil: `hasil/ss5b_39515048504-1/`.
- [TERAMATI] Pemeriksaan (1) LOLOS: rc 0 (476 dtk), sampai frame 26300. Baris: `pc pause ok=true`, `pc clearOverride tombol=14 ok=14`, `muat kembali ok=true`, `override_pasang_ulang f=24000 aktif=1`, `pc resume ok=true`, `muat selesai ok=true`.
- [TERAMATI] Hash RAM tepat sesudah muat = 247000128 = hash saat simpan di frame 24000 (RAM terpulihkan persis di titik muat).
- [TERAMATI] Beda prosedur satu-satunya dibanding ss4 (segfault): override pad dilepas sebelum muat. Di ss1/ss3/ss4 ada override aktif saat muat (jadwal story3: L1 dipasang di frame 26000). [DUGAAN, DILEMAHKAN oleh ss6] penyebab segfault = override pad Lua aktif saat muat; ss6 (override juga dilepas) tetap segfault, lihat bagian ss6.
- [TERAMATI] Pemeriksaan (2), angka yang dipantau IDENTIK: CHG pass 1 (24000-26000) vs CHG2 pass 2 = 12 baris sama persis (P2 chakra 1680 -> 1530 di frame 25575-25585, A2 dan B2); CHG2 = 12 baris juga identik dengan baseline TANPA muat (story3, 24000-26300). Kata struct P1 (+0..+124) di 24500, 25000, 25500, 26000 sama di pass 1 dan pass 2.
- [TERAMATI] Pemeriksaan (2), hash RAM penuh TIDAK identik: pass 2 vs baseline tanpa muat 0 dari 115 sampel sama (divergen sejak frame 24020), sedangkan pass 1 vs baseline story3/ss3/ss4/ss1 sama 100% (101/101, 100/100, 101/101, 70/70), jadi baseline deterministik dan instrumentasi tidak mengubah emulasi.
- [DUGAAN] Hash penuh mencakup area yang tidak ikut state atau tidak deterministik sesudah muat (penghitung waktu, buffer CD/SPU/DMA, jadwal siklus emulator). Tidak diketahui seberapa banyak kata RAM yang beda atau di mana. [BELUM] apakah muat berulang dari state yang sama menghasilkan lintasan yang sama satu sama lain (dua pass sesudah muat).
- [TERAMATI] Serialisasi state ke berkas tetap 0 byte (ss lanjutan), jadi state tidak bisa lintas run; tidak ada rancangan STATE_KEY yang perlu diusulkan. Penggunaan praktis: percabangan DI DALAM satu run (simpan di 24000, muat berkali-kali dengan variasi input per cabang).
- Opsi (a) dilewati sesuai aturan (b berhasil); uji apiuji tidak dijalankan. Percobaan uji game terpakai 5 dari maks 6; sisa 1.
- Usulan percobaan ke-6 (belum dijalankan, menunggu pemilik): muat DUA kali dari state yang sama (pass 2 dan pass 3), bandingkan hash RAM pass 2 vs pass 3 dan tambahkan hash per halaman 4 KB (angka saja) untuk melihat seberapa lebar divergensi; bila pass 2 = pass 3, percabangan in-run sahih (bandingkan antar cabang, bukan terhadap baseline).

## Sesi ss6 (percobaan ke-6, MODUS=pd: muat dua kali dari state yang sama) - GAGAL, segfault di muat PERTAMA
- Perubahan: `probe.lua` modus `pd` (= prosedur `pc` + muat kedua kali di frame 26000 pass 2 + hash per halaman 4 KB dicetak sebagai baris `SVS hsp` di frame 24000/24020/24100/24500/25000/26000/26300; CHG diberi nomor pass: CHG, CHG2, CHG3). Modus lain tidak diubah. Run 39516647332 (label ss6pd), parameter sama dengan ss5b. Hasil: `hasil/ss6pd_39516647332-1/`.
- [TERAMATI] rc 139 (segfault, 441 dtk). Urutan log: `muat mulai` -> `pc pause ok=true` -> `pc clearOverride tombol=14 ok=14` -> (crash). `muat kembali` tidak pernah tercetak: crash di dalam `PCSX.loadSaveState` pada muat PERTAMA, dengan prosedur yang sama dengan ss5b (pause + override dilepas) yang sebelumnya berhasil. Muat kedua tidak pernah tercapai.
- [TERAMATI] Pass 1 identik dengan ss5b dan baseline: hash RAM 247000128 (24000), 257979692 (24500), 1318570883 (25000), 2417048136 (25500), 291065347 (26000); kata struct P1 sama. Hash per halaman di pass 1 tercetak (6 baris `SVS hsp`), tetapi tanpa pass 2/3 tidak ada pembanding, jadi belum berguna.
- [TERAMATI] Rekap muat di run game: override aktif saat muat -> crash 3 dari 3 (ss1, ss3, ss4); override dilepas + pause -> berhasil 1 (ss5b), crash 1 (ss6). Beda ss6 dari ss5b hanya kode tambahan (hash halaman di pass 1 lewat pcall, modus pd). Ukuran state tiap simpan sedikit berbeda (21163313..21163814 byte), tanda isi state bukan salinan identik.
- [DUGAAN] Muat bersifat tidak stabil (kadang lolos, kadang segfault) dan bergantung pada sesuatu yang belum diketahui (kondisi memori/GC Lua, waktu, atau kode tambahan di pass 1); override pad tidak cukup menjelaskan. Dengan n=2 untuk konfigurasi ini, ss5b tidak bisa dianggap bukti bahwa muat andal. [BELUM] apakah ss5b persis (modus pc tanpa hash halaman) bisa diulang.
- [BELUM] Muat dua kali dari state yang sama (pass 2 = pass 3) dan lebar divergensi hash RAM ss5b: tidak teruji.
- Kesimpulan yang boleh dipakai: muat state di run game TIDAK andal (1 dari 5 percobaan berhasil), dan bahkan yang berhasil tidak menghasilkan hash RAM penuh identik (ss5b). Percabangan in-run lewat save-state belum bisa dipercaya. Angka yang dipantau (CHG, struct P1) identik di ss5b, tetapi itu satu sampel.
- Percobaan uji game terpakai **6 dari 6 (batas habis)**. Tidak ada percobaan lagi tanpa pemilik menaikkan batas.
- Pilihan berikutnya (pemilik memutuskan): (1) cadangan pemutaran ulang deterministik dari frame 0 (tidak memakai percobaan; terbukti identik di runner, sekitar 8-10 mnt per 30000 frame; bisa coba -dynarec lalu cek hasil sama); (2) naikkan batas dan ulangi ss5b persis N kali (mis. 3 run paralel label berbeda) untuk mengukur keandalan; (3) bangun emulator dari sumber (butuh persetujuan; tidak dilakukan).

## Sesi gui (uji mode GUI + Mesa tanpa game; BUKAN percobaan uji game, tidak dihitung)
- Tujuan (permintaan pemilik): dapatkan layar lewat Mesa di runner, dan lihat apakah mode GUI (tanpa `-cli`) memperbaiki screenshot kosong dan crash muat-state. Perubahan: mode `guiuji` di `ci/run_remote.sh` dan `redux/lua_mine/guiuji.lua` (angka/tipe saja; modus lain tidak diubah). Hasil: `hasil/gui1_*`, `hasil/gui2_*`.
- [TERAMATI] Mesa di runner ubuntu-24.04 bekerja: `glxinfo` melaporkan llvmpipe (LLVM 20.1.2), OpenGL core 4.5, Mesa 25.2.8, direct rendering Yes, 320 visual GLX pada Xvfb depth 24.
- [TERAMATI] Emulator (AppImage yang ada) tanpa `-cli` GAGAL membuat jendela di 4 konfigurasi Xvfb: "Unable to create main window: Couldn't find matching GLX visual" (depth 24, +iglx, -ac; depth 32 gagal lebih awal: "Failed to initialize SDL: No available video device"). Proses menggantung sampai di-kill (rc 137). Jadi layar via GUI BELUM didapat; penyebabnya bukan Mesa/glibc, tetapi atribut framebuffer yang diminta emulator tidak cocok dengan visual Xvfb.
- [DUGAAN] Screenshot kosong di mode `-cli` karena tidak ada konteks GL; segfault muat-state di run game mungkin juga terkait ketiadaan konteks GL saat softgpu memuat VRAM (BIOS-only aman karena state kecil/tanpa game). Belum teruji: butuh GUI jalan dulu, lalu percobaan game (batas 6 sudah habis; menunggu keputusan pemilik).
- [BELUM] Build "PCSX-Redux anylinux": pencarian tidak menemukan paket itu (repo Anylinux-AppImages tidak mencantumkan pcsx-redux pada daftar yang terlihat). AppImage resmi dibuat dengan appimage-builder di wadah. Tidak diverifikasi lebih jauh.
- Langkah berikut yang disarankan (tanpa game, murah): coba Xorg dummy (xserver-xorg-video-dummy) atau Xvfb dengan visual lain agar jendela GL terbentuk; lalu ambil screenshot dan ukur angka (byte, nonzero, hash) di dua frame untuk deteksi perubahan layar. Gambar tidak boleh keluar dari runner.

## Sesi gui (lanjutan, gui3-gui5; tanpa game, bukan percobaan uji game)
- [TERAMATI] Bukan soal Xvfb: Xorg dummy (gui3) juga gagal "Couldn't find matching GLX visual". AppImage membawa SDL3 sendiri (`libSDL3.so.0`) dan TIDAK membawa libGL/libEGL; ia memakai OpenGL host. Memaksa pustaka GL host lewat LD_PRELOAD tidak membantu (gui4); mendahulukan pustaka host merusak SDL3 bawaan (libxkbcommon V_1.10.0 tidak ada).
- [TERAMATI] **`SDL_VIDEO_FORCE_EGL=1` membuat jendela berhasil** di atas Mesa llvmpipe (gui5): varian egl_x11, egl_x11+x11drv, offscreen, offscreen+egl semuanya jalan sampai handler Vsync (frame 60/120/180 tercetak). Jadi Mesa cocok dengan emulator yang sekarang lewat jalur EGL; GLX-lah yang gagal.
- [TERAMATI] Di mode GUI, `takeScreenShot` memberi width=640 height=478 tetapi data tetap 0 byte (hash 0). Jadi konteks GL sendiri belum membuat piksel terbaca lewat jalur `writeMoveSlice(ss.data)`. [BELUM] apakah itu karena cara baca (Slice) atau karena softgpu; alternatif yang perlu dicek: API baca VRAM langsung (nama API di baris `SVS apiall`/ cetak keys PCSX.GPU).
- [TERAMATI] Keempat varian berakhir rc 124 (timeout 100 dtk): baris `createSaveState` (frame 200) dan `selesai` (frame 260) TIDAK muncul. [BELUM] sebabnya: mode GUI + llvmpipe mungkin jauh lebih lambat dari mode -cli, atau createSaveState menggantung di mode GUI. Kecepatan penting: bila GUI jauh lebih lambat, pemutaran ulang 24000 frame tidak muat dalam batas 30 menit.
- Langkah berikut yang disarankan (tanpa game, murah): (1) ukur frame per detik di mode GUI+EGL (cetak frame dan waktu tiap 20 frame, tanpa createSaveState); (2) cetak daftar keys PCSX.GPU dan cari API VRAM; (3) bila VRAM terbaca, hitung hash/statistik area tampilan sebagai pengganti layar (angka saja), yang mungkin juga jalan di mode -cli. Setelah itu baru uji muat state di mode GUI+EGL dengan game (butuh persetujuan pemilik menaikkan batas percobaan).

## Sesi gui (gui6-gui7; tanpa game): LAYAR TERBACA SEBAGAI ANGKA, koreksi temuan lama
- [TERAMATI] `PCSX.GPU.takeScreenShot()` dan `PCSX.GPU.getVRAM()` MEMBERI PIKSEL NYATA di runner, di mode `-cli` DAN di mode GUI+EGL. Cara baca yang benar: `tostring(slice)` mengembalikan byte mentah (screenshot 611840 byte = 640x478x2; VRAM 1048576 byte). Hash dan jumlah byte tidak nol berubah antar frame (frame 40/120/200: nonzero 405865/382137/398825; hash 1142421948/3323435741/713460860). Hasil -cli dan GUI+EGL IDENTIK (hash sama persis).
- Koreksi: catatan lama "screenshot kosong / hash framebuffer tidak berfungsi di runner" disebabkan cara baca (tulis ke berkas lewat `Support.File.open` lalu `io.open` = 0 byte), bukan emulator atau GPU. Larangan "jangan diulang" dicabut: pakai `tostring(ss.data)` dan `tostring(PCSX.GPU.getVRAM())`. Hanya angka (byte, nonzero, hash, statistik) yang boleh keluar dari runner; gambar tidak.
- [TERAMATI] Mesa/GUI tidak diperlukan untuk membaca layar: `-softgpu` merender di CPU dan `-cli` sudah cukup. Mode GUI+EGL (`SDL_VIDEO_FORCE_EGL=1`, Mesa llvmpipe) juga jalan dengan kecepatan sama (~56 fps: 300 frame dalam 5,36 dtk vs 5,17 dtk di -cli).
- [TERAMATI] Di BIOS tanpa game, `createSaveState` + `loadSaveState` sukses di GUI+EGL dan -cli (rc 0). Timeout di gui5 (rc 124) kemungkinan disebabkan skrip uji lama (screenshot lewat berkas di frame 60/120/180); belum dibuktikan.
- Dampak: sweep tombol bisa memakai "hash layar berubah atau tidak" sebagai sinyal pengganti penglihatan, di run replay biasa (tidak memakai muat state, jadi tidak termasuk batas percobaan muat). [BELUM] hash layar di run game (probe.lua belum memakainya). [BELUM] uji muat state di mode GUI+EGL dengan game (butuh persetujuan pemilik menaikkan batas).
- API baru yang tercatat: PCSX.GPU = DumpPlayer, getDumpFrames, getGuestFPS, getVRAM, isDumpArmed, isDumping, startDump, stopDump, takeScreenShot; skema state memuat `bytes vram = 3` dan `GPU gpu = 5`.

## Sesi svs (sweep tombol berbasis hash layar) + tangkapan layar TERENKRIPSI
- Perubahan: `probe.lua` modus `svs` (hash layar/VRAM + selisih kata + grid 4x4, angka saja; parameter lewat header jadwal `# SVS from= step=`; frame gambar lewat `# SHOT f1 f2 ...`). Workflow: concurrency per label (run paralel). `ci/buat_jadwal.py` membuat jadwal kandidat. Penjaga ekstensi/ukuran `run_remote.sh` tetap; ditambah penjaga: berkas `shot_*` harus bernama `shot_NNNNN.enc.txt`, berawalan `ENC1`, maks 8.
- Aturan gambar diubah pemilik: Claude boleh melihat tampilan game. Cara aman (repo PUBLIK): runner mengubah layar jadi PNG di memori, mengenkripsi hibrida (AES-256-CBC + RSA-OAEP, kunci publik `ci/shot_pub.pem`) lalu commit `hasil/<label>_<run>/shot_NNNNN.enc.txt`. Kunci PRIVAT hanya di sandbox Claude (`/home/claude/kunci/priv.pem`, TIDAK di repo) dan hilang saat sandbox dibersihkan. Di chat baru: buat pasangan kunci baru (`openssl genrsa 3072`), ganti `ci/shot_pub.pem`, jalankan ulang run; gambar lama tidak terbaca lagi. Dekripsi: `ci/dekripsi_shot.py PRIV ENC OUT.png`. Mentah/PNG tidak pernah ditulis ke luar folder sementara runner.
- [TERAMATI] Screenshot di run game 320x240, 16 bpp (153600 byte), format piksel PS1 555 terbaca benar.
- [TERAMATI] Ronde 1 (14 tombol tunggal di frame 24000 + kontrol): hash layar identik dengan kontrol sampai 25600; kontrol punya transisi besar sampai ~24020 lalu layar tenang. [DUGAAN] tombol di 24000 jatuh di transisi.
- [TERBUKTI, replay ini] Ronde 2 (leave-one-out sapuan story3): CROSS di frame 24800 adalah pemicu peristiwa P2 chakra 1680 -> 1530 (frame 25575-25585). Tanpa CROSS itu tidak ada CHG sesudah 24000. LEFT/RIGHT/CIRCLE/TRIANGLE/SQUARE di sapuan tidak berpengaruh pada hash layar; DOWN di 24200 mengubah layar tetapi tidak perlu untuk peristiwa itu.
- [TERAMATI] Dari gambar (run s1shot, jadwal `inputs/s1_shot.txt`, frame 24100/24790/25000/25400/25700/26000): layar yang "macet" adalah dialog ya/tidak berteks Jepang "結界をレベルアップしますか？" (naikkan level barrier?) dengan pilihan はい/いいえ; HUD: P1 Naruto 4640, P2 Mizuki 1680. Setelah CROSS di 24800: animasi efek, P2 jadi 1530, angka pada gem petak 100 (24790/25400) -> 70 berkedip (25700) -> 220 (26000). [DUGAAN] CROSS memilih はい; P2 membayar 150 untuk naik level barrier (nilai gem 100 -> 220); pemain mana yang giliran belum dipastikan.
- [BELUM] Analisis ronde 3 (`hasil/r3*_*`: dasar prefix+CROSS@24800, kandidat tombol di 25700; bandingkan dengan r3NONE: frame divergensi pertama, besar sd, CHG). Papan 1 tamat, stage 2 Party Mode, aturan angka baru, dan biaya/efek level-up lengkap masih belum.
- Batas uji muat-state tetap 6/6 (tidak dipakai). Ingatkan pemilik merevoke token di akhir sesi.

## Sesi s2 (chat baru): analisis ronde 3 + tangkapan layar dengan kunci baru
- Kunci RSA baru dibuat (privat hanya di sandbox, TIDAK di repo); `ci/shot_pub.pem` diganti. Gambar lama tak terbaca.
- [TERAMATI] Ronde 3 (`hasil/r3*_*`, 14 tombol tunggal di 25700 vs r3NONE): hash layar identik dengan kontrol di SEMUA sampel (25600-26600), CHG sama, maxsd sama (35490). Tombol di frame 25700 tidak berpengaruh pada satu kandidat pun. Penjelasan dari gambar: 25700 masih di tengah animasi/pesan, bukan di dialog yang menunggu tombol.
- [TERAMATI] Run s2shot (jadwal `inputs/s2_shot.txt`, prefix + CROSS@24800, SHOT 25500..26600; gambar didekripsi di sandbox):
  - 25500: gem petak 100, chakra P2 1680 (HUD: Naruto 4640, Mizuki 1680).
  - 25650/25700: efek partikel, chakra Mizuki 1530, angka kecil 70.
  - 25800: kotak pesan 「結界レベルが2になりました。」 (level barrier jadi 2), gem 220.
  - 25950: dialog Mizuki 「オレさまに勝てるか？ ククククク・・・」.
  - 26200-26600: dialog Naruto 「いくぞ、いくぞ、いくぞぉ」 menunggu tombol (indikator merah di kotak); layar statis, sd ~1000-2000 (derau animasi idle).
- [TERAMATI -> lebih kuat dari DUGAAN lama] CROSS@24800 memilih はい; P2 (Mizuki) membayar 150 chakra (1680 -> 1530); barrier petaknya naik ke level 2; nilai gem 100 -> 220.
- [BELUM] Apa yang terjadi sesudah dialog Naruto dibuang (roulette giliran Naruto?).
- Langkah: run paralel s3A/s3B/s3C (CROSS@26300 sekali / +26500 / +26700), SHOT tiap ~300 frame sampai 28200.

## Sesi s3/s4 (chat baru): tombol yang benar = CIRCLE; satu giliran penuh terbaca di layar
- [TERAMATI] Run s3A/B/C (CROSS di 26300 / +26500 / +26700): hash layar IDENTIK dengan s2shot dan satu sama lain; dialog Naruto 「いくぞ…」 tidak maju sampai 28200. CROSS = batal, tidak memajukan dialog.
- [TERAMATI] Run s4D/E/F (jadwal `inputs/s4_D/E/F.txt` = prefix story3 + CROSS@24800 + CIRCLE di 26300 [,26500,26700,26900,27100]): CIRCLE memajukan layar (lonjakan sd mulai 26320). Urutan di run F (gambar didekripsi):
  - 26400: menu giliran Naruto: ルーレット / 忍術 / チャンス札 / 情報 / マップを見る.
  - 26600-26800: roulette berputar, berhenti di angka 3 (CIRCLE@26700 menghentikan).
  - 27000: prompt 「ここに結界をはりますか？ 必要チャクラ 260」 (pasang barrier di sini? butuh 260 chakra) pilihan はい/いいえ.
  - 27200: Naruto 4640 -> 4380 (= -260 persis; CHG mulai f=27105, turun bertahap 10 per langkah); ada petak baru dengan angka 60.
  - 27500-28300: giliran Mizuki: 「なにもかも手にいれてやる！」, layar pilih kartu 「ゲットする札をえらべ！」 (3 kartu menghadap bawah), lalu 「チャクラが２５０回復」; Mizuki 1530 -> 1780.
- [TERBUKTI, replay ini] Biaya pasang barrier di petak kosong yang dimaksud = 260 chakra (hanya satu sampel; petak ke-? belum dipastikan, harga petaknya perlu dicocokkan ke data/tabel_papan.json). Biaya level-up barrier sebelumnya = 150 (Mizuki, 1680 -> 1530; gem 100 -> 220).
- [BELUM] Kondisi menang papan 1 dan apakah stage 2 terbuka; posisi petak Naruto/Mizuki sekarang.
