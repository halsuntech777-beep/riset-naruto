# Kronologi chat (ringkasan berurutan)

Bukan transkrip kata demi kata. Urutan topik, permintaan pengguna, hasil, dan keputusan.

1. **Video hybrid-casual** (mp4 4:36): dianalisis lewat frame dan caption terbakar. Hasil: definisi, tiga faktor retensi, core+meta loop, monetisasi Ads+IAP, data pasar.
2. **Data iklan vs IAP** (survei AdInMo) dan **IAP vs pay-to-win**: spektrum kosmetik-convenience-catch-up-power; ekonomi whale; saran untuk indie strategi.
3. **Leaderboard + sistem sosial** (follow/like): rank terlindungi, kosmetik prestise, profil sebagai titik temu; contoh chess.com dan Mobile Legends.
4. **Game Facebook (Zynga)** dan **Monopoly GO**: pelajaran distribusi, ketergantungan platform, mekanik sosial. **Roguelike** dijelaskan singkat.
5. **TileDuel** (zip FaseB_b8, Godot 4): ditinjau terhadap kerangka hybrid-casual; saran Crowns, IAP kosmetik, Remove Ads.
6. **Godot di sandbox**: tidak terpasang saat itu; opsi dijelaskan. Kemudian jaringan sandbox terbuka.
7. **Disk PS1 Naruto Jintori Gassen** (.bin + .cue): dianalisis sektor demi sektor (valid), file system, executable, hash; 696 gambar TIM terdeteksi (tidak diekstrak). Keputusan: **sprite dan musik tidak diekstrak** (hak cipta); hanya aturan/fakta fungsional.
8. **Bedah executable MIPS** (decoder buatan sendiri): hanya tabel sistem; jalan buntu untuk tabel aturan lewat frekuensi rujukan.
9. **Emulator PCSX-Redux** (diunggah pengguna): dijalankan tanpa layar; input terjadwal; dump RAM; ubah-memori. Temuan: uang 1500, klaim, sewa dari tabel, tabel papan di `DATA.BIN` (16 blok, 11 unik), papan Hutan Konoha 22 petak.
10. **Party Mode, karakter, kartu**: Party Mode 4 dan 2 pemain; 9 stage (1 terbuka); 12 slot karakter (4 terbuka: Naruto, Sasuke, Sakura, Kakashi); petak kartu #6 dan #19; kartu yang terbaca.
11. **Artefak dan GitHub**: catatan dipublikasikan sebagai artefak; repositori privat `halsuntech777-beep/riset-naruto`; token fine-grained dipakai lewat header sementara (tidak pernah disimpan).
12. **Bonus start**: dari satu sampel (+525) ke tiga sampel; uji ubah-memori negatif; layar laporan chakra membuktikan 400 + 25% x total barrier.

## Keputusan dan preferensi pengguna
- Hemat token dan batas pemakaian 5 jam; pakai artefak bila perlu; ingatkan membuka chat baru saat chat sangat panjang.
- Selalu kirim hasil kerja ke repositori GitHub agar tidak hilang.
- Pengguna ingin klaim dibuktikan, bukan dugaan; selalu beri tanda TERBUKTI/TERAMATI/DUGAAN/BELUM.
- Bahasa: Indonesia, ringkas, jujur soal batas bukti.

## Kendala teknis berulang
- Berkas kerja di `/tmp` dan `/home/claude` hilang antar sesi; hanya folder output yang bertahan.
- Proses latar belakang bisa mati saat jam sandbox melompat atau jeda lama.
- Sempat ada beberapa sesi Claude menulis ke repositori yang sama (commit saling menimpa); satu chat saja yang menulis pada satu waktu.
