# Lanjutkan di chat baru (TANPA token)

Pemilik memberi token GitHub (fine-grained, hanya repo ini) di pesan pertama chat baru; JANGAN taruh token di repo, disk, atau memori.

Urutan: (1) clone dengan header sementara (`git -c "http.extraheader=Authorization: Basic <base64 x-access-token:TOKEN>" clone ...`), bukan raw.githubusercontent.com; (2) baca README.md dan STATUS.md ("Sesi x2" dulu, lalu "Sesi x1"); (3) buat kunci RSA baru (privat hanya di sandbox, `ci/shot_pub.pem` diganti); (4) jalankan di runner (workflow `emulator-run.yml`), hasil angka di `hasil/<label>_<run>/`.

Keadaan ringkas (detail di STATUS.md "Sesi x2"):
- Replay cepat terbukti: header jadwal `# SPUSPEED 4` dan `# NODEBUG` (26300 frame +-115 dtk).
- Muat state di proses baru BERHASIL: titik muat `LSITE=nt` + perbaikan sub-field 6.6.1.8 (`ci/pbx.py fixptr`); RAM sesudah muat = RAM simpanan (247000128 di frame 24000); lanjutan deterministik, tetapi 4 blok RAM 64 KB (0, 6, 10, 31) beda dari replay penuh sejak 24020 (selisih belum dipahami).
- Mode `xv` (banyak varian state per run) dan header jadwal `# SAVEF2`, `# ONLY`, `# VTO`, `# LSITE`, `# HANG`, `# HBLK`; contoh jadwal `inputs/xv_blk.txt`.

Batas tetap: jangan unggah/commit file game, gambar mentah, dump RAM/VRAM, atau save-state TIDAK terenkripsi (repo, release, artefak, cache publik, log); jangan tambah upload-artifact; jangan minta/pakai izin Secrets; jangan bangun/ganti emulator tanpa persetujuan pemilik. Yang boleh keluar: angka, nama/tipe API, teks bantuan emulator, gambar terenkripsi (AES-256-CBC + RSA-OAEP, `ci/shot_pub.pem`), state terenkripsi dengan STATE_KEY.

Di akhir sesi: perbarui STATUS.md, push, verifikasi dengan clone ulang tanpa token, ingatkan pemilik merevoke token.
