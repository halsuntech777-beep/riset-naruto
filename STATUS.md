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

## Cara bekerja (pelajaran penting)
- Sandbox dibersihkan antar sesi dan proses latar belakang bisa dimatikan saat jeda lama. Jaga tiap run <= ±9 menit, pantau dengan `sleep` <= 295 detik, dan push hasil sesering mungkin.
- Run emulator deterministik: input yang sama = kejadian di frame yang sama. Jadwal input ada di `inputs/` (Party Mode 2 pemain: `inputs_2p.txt` dan `inputs_2lap.txt`).
- Memuat save-state dari Lua menyebabkan segfault; breakpoint Lua tidak menangkap kode game. Gunakan pemutaran ulang + dump RAM + ubah-memori (`probe.lua`).
- Unggah ulang di chat baru: PCSX-Redux (zip), `.bin` dan `.cue` game; emulator butuh shim glibc (`redux/`).
- Jangan simpan ke repo: game, emulator, screenshot, dump RAM (berhak cipta). Token tidak pernah disimpan di berkas.
