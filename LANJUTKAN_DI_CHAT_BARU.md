# Prompt untuk chat baru

Salin ke chat baru, ganti `<TOKEN_GITHUB>` dengan token fine-grained milikmu (jangan commit token ke repositori).

```
Aku melanjutkan riset game PS1 "Naruto: Shinobi no Sato no Jintori Gassen" sebagai referensi untuk game buatanku, TileDuel (strategi papan Android). Semua pekerjaan sebelumnya ada di repositori GitHub privatku.

Repo: halsuntech777-beep/riset-naruto
Token GitHub (fine-grained, hanya repo itu, Contents read/write): <TOKEN_GITHUB>

Langkah awal, urut:
1. Tes jaringan sandbox ke github.com. Clone repo dengan header sementara (git -c "http.extraheader=Authorization: Basic <base64 x-access-token:TOKEN>"), jangan simpan token di disk, repo, atau memori. Kalau token ditolak atau kedaluwarsa, minta aku membuat token baru.
2. Baca README.md, STATUS.md, catatan_riset.md, dan riwayat/kronologi_chat.md. Itu ringkasan lengkap chat sebelumnya.
3. Minta aku mengunggah: PCSX-Redux (zip), file .bin dan .cue game, dan (opsional) zip TileDuel. Skrip emulator, jadwal input, dan analisis ada di repo.

Aturan kerja:
- Hemat token dan batas 5 jam: satu target per sesi, run emulator di latar belakang dan <= 9 menit, hasil dipadatkan, pakai artefak bila perlu.
- Tandai tiap temuan [TERBUKTI]/[TERAMATI]/[DUGAAN]/[BELUM]; jangan klaim lebih dari bukti.
- Jangan ekstrak atau simpan sprite, musik, screenshot, atau dump RAM ke repo (berhak cipta).
- Push hasil ke repo sesering mungkin (sandbox dibersihkan antar sesi) lalu verifikasi dengan clone ulang. Satu chat saja yang menulis ke repo pada satu waktu.
- Ingatkan aku membuka chat baru bila chat sudah sangat panjang. Jawab dalam bahasa Indonesia yang ringkas.

Target sesi ini: [pilih satu]
 a. Tutup bukti rumus bonus start: baca nilai barrier level 1+ dari panel peta (結界価値) atau cari sampel bersih lain.
 b. Cocokkan tabel roda di executable dengan roda tiap karakter.
 c. Daftar lengkap kartu / fungsi poin jurus.
 d. Rancang ekonomi Crowns TileDuel dari temuan riset ini.
```
