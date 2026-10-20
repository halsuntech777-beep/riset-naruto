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
- [BELUM] Emulator berjalan di runner; daftar paket apt (`xvfb libgl1 libegl1 ...`) adalah tebakan terbaik dan mungkin perlu ditambah setelah run pertama. Hasil run pendek (inputs_2p.txt, MAXF 7000) belum dibandingkan dengan sandbox; sandbox belum punya log acuan di repositori, jadi hasil run pertama jadi acuan dan cek kewarasan: modal awal 1500 muncul di empat alamat pantau.
- Rancangan: `ci/run_remote.sh` (unduh, bangun, jalankan, hasil), `ci/ekstrak_dump.py`, `probe.lua` kini mendukung `ORPOKES="frame[-frame2]@alamat@lebar@mask"` (OR-kan bit; mask boleh 0x...). Input workflow: jadwal, maxf, pokes, orpokes, dumps, addrs, label.
- Aman hak cipta: game dan emulator diunduh dari release `aset` di repositori **privat** (`game.bin`, `redux.AppImage`/`redux.zip`), hanya di folder sementara runner; skrip menolak bila sumber aset tidak privat. Tidak ada upload-artifact, tidak ada SHOTS. Yang di-commit hanya `hasil/<label>_<run>/` berisi `chg.log`, `ringkasan.txt`, `emu_tail.txt`, `dump_angka.csv` (angka), dengan penjaga ekstensi dan ukuran (maks 300 KB).
- Dua mode: (a) jadikan repositori ini privat, taruh release `aset` di sini, tanpa secret; (b) tetap publik, secret `PRIVATE_REPO` dan `PRIVATE_TOKEN` (Contents: read pada repositori privat). **Diputuskan pemilik: mode (b)** (repositori ini tetap publik; repositori privat terpisah menyimpan release `aset`; secret `PRIVATE_REPO` dan `PRIVATE_TOKEN`).
- Langkah berikutnya (mode b): buat repositori privat baru untuk aset, buat release `aset`, salin workflow, jalankan "Run workflow" dengan nilai bawaan, lalu bandingkan `hasil/uji_*/ringkasan.txt`. Setelah itu baru riset terbuka nomor 1-3 di bawah (ORPOKES untuk bendera kristal: struct 0x80070EB8+4, mask 0x3000).
- Token percobaan sesi ini kedaluwarsa 2026-11-07; hapus/revoke bila sudah tidak dipakai.

## Cara bekerja (pelajaran penting)
- Sandbox dibersihkan antar sesi dan proses latar belakang bisa dimatikan saat jeda lama. Jaga tiap run <= ±9 menit, pantau dengan `sleep` <= 295 detik, dan push hasil sesering mungkin.
- Run emulator deterministik: input yang sama = kejadian di frame yang sama. Jadwal input ada di `inputs/` (Party Mode 2 pemain: `inputs_2p.txt` dan `inputs_2lap.txt`).
- Memuat save-state dari Lua menyebabkan segfault; breakpoint Lua tidak menangkap kode game. Gunakan pemutaran ulang + dump RAM + ubah-memori (`probe.lua`).
- Unggah ulang di chat baru: PCSX-Redux (zip), `.bin` dan `.cue` game; emulator butuh shim glibc (`redux/`).
- Jangan simpan ke repo: game, emulator, screenshot, dump RAM (berhak cipta). Token tidak pernah disimpan di berkas.

## Rute buka papan lewat Story (percobaan 1: macet)
- Lihat `catatan_riset.md` bagian 14 dan `inputs/inputs_story.txt`. Papan pertama belum tamat; kartu memori masih kosong; belum ada papan lain terbuka. Langkah berikut: paksa bendera kristal P1 dan tangani layar macet (CROSS, DOWN + CIRCLE), lalu cek apakah tamat papan 1 membuka stage 2 di Party Mode.
