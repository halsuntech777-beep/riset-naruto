# Prompt untuk chat baru

Salin ke chat baru, ganti `<TOKEN_GITHUB>` dengan token fine-grained milikmu (jangan commit token ke repositori).
Token yang dibutuhkan: hanya untuk repo `riset-naruto`, izin Contents, Workflows, dan Actions masing-masing read/write, masa berlaku pendek. Jangan beri izin Secrets, dan jangan beri akses ke `riset-naruto-aset`.

```
Aku melanjutkan riset game PS1 "Naruto: Shinobi no Sato no Jintori Gassen" sebagai referensi untuk TileDuel (strategi papan Android).

Repo (PUBLIK): halsuntech777-beep/riset-naruto
Token GitHub (fine-grained, hanya repo itu, Contents + Workflows + Actions read/write): <TOKEN_GITHUB>

Langkah pertama: clone repo dengan header sementara (git -c "http.extraheader=Authorization: Basic <base64 x-access-token:TOKEN>"), jangan simpan token di disk, repo, atau memori. Baca README.md dan STATUS.md. Jangan ulangi yang sudah ditandai TERBUKTI/TERAMATI.

Keadaan: emulator PCSX-Redux sudah berjalan di GitHub Actions (workflow .github/workflows/emulator-run.yml, skrip ci/run_remote.sh). Game dan emulator diunduh dari release privat di repo lain; kamu tidak punya dan tidak perlu mengaksesnya. Jangan minta aku mengunggah ROM ke chat.

Cara menjalankan: POST ke api.github.com/repos/halsuntech777-beep/riset-naruto/actions/workflows/emulator-run.yml/dispatches dengan {"ref":"main","inputs":{jadwal, maxf, pokes, orpokes, dumps, addrs, label}}, lalu pantau status run lewat API (sleep <= 295 detik). Log Actions tidak bisa dibaca dari sandbox (host log diblokir); hasil dibaca dari berkas yang di-commit runner ke hasil/<label>_<run>/ (git pull): chg.log, ringkasan.txt, emu_tail.txt, dump_angka.csv, galat_*.txt. Run 2 pemain 7000 frame makan sekitar 2 menit. Satu chat saja yang menulis ke repo pada satu waktu.

Target sesi ini (satu saja): riset terbuka nomor 1: tamatkan papan Story pertama. Paksa bendera kristal P1 (struct 0x80070EB8 +4, bit 0x1000 dan 0x2000, ORPOKES "frame[-frame2]@alamathex@lebar@mask", mis. alamat 70EBC, mask 0x3000), dan tangani layar macet "pilih barrier untuk di-level-up" dengan CROSS lalu DOWN + CIRCLE. Pakai inputs/inputs_story.txt (macet di frame ±21000); buat jadwal baru di inputs/ bila perlu. Lalu cek apakah tamat papan 1 membuka stage 2 di Party Mode dan apakah progres tersimpan di kartu memori.

Batasan keras:
- JANGAN unggah/commit file game (.bin/.cue), screenshot, atau dump RAM ke repo publik, release publik, atau artefak. Jangan tambah upload-artifact, jangan cetak isi game ke log (log Actions repo publik terlihat semua orang). Yang boleh keluar dari runner hanya angka.
- Jangan ubah ci/run_remote.sh agar mengirim berkas non-angka; penjaga ekstensi/ukuran harus tetap ada.
- Jangan minta atau pakai izin Secrets; jangan menyentuh repo aset.

Aturan kerja: hemat token dan batas 5 jam, satu langkah per sesi, jalankan lama di runner bukan di sandbox. Tandai tiap temuan [TERBUKTI]/[TERAMATI]/[DUGAAN]/[BELUM], jangan klaim lebih dari bukti. Push hasil ke repo lalu verifikasi dengan clone ulang, perbarui STATUS.md di akhir. Ingatkan aku membuka chat baru bila chat sudah sangat panjang, dan ingatkan aku merevoke token di akhir sesi. Jawab dalam bahasa Indonesia yang ringkas.
```
