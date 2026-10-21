# Cara lanjut di chat baru (tanpa token; token diberikan pemilik di prompt chat, tidak pernah disimpan di repo)
1. Clone repo dengan header sementara (git -c "http.extraheader=Authorization: Basic <base64 x-access-token:TOKEN>"), jangan simpan token di disk/repo/memori. Jangan pakai raw.githubusercontent.com.
2. Baca README.md dan STATUS.md (bagian "Sesi x1" dan "Sesi s5" paling baru).
3. Buat kunci RSA baru: openssl genrsa -out priv.pem 3072; openssl rsa -in priv.pem -pubout -out ci/shot_pub.pem; commit pub saja.
4. Semua jadwal baru: tambahkan header "# SPUSPEED 4" dan "# NODEBUG" (replay 26300 frame = ±2 menit, hash identik).
5. Aturan tetap: tanpa file game, gambar mentah, dump RAM, atau state tidak terenkripsi di repo/log/artefak.
