Aku melanjutkan riset game PS1 "Naruto: Shinobi no Sato no Jintori Gassen" (referensi TileDuel). Tujuan sesi ini: bangun BOT ATURAN TETAP (Lua di emulator, tanpa LLM/API key) beserta fitur LANJUT KE TENGAH PERMAINAN lewat replay log input, lalu uji di papan 1. Story mode ~7-8 papan, tiap papan unik.

Repo (PUBLIK): halsuntech777-beep/riset-naruto
TOKEN: <TEMPEL TOKEN BARU DI SINI> (fine-grained, hanya repo itu; Contents + Workflows + Actions read/write; tanpa Administration dan Secrets). Pakai git -c "http.extraheader=Authorization: Basic <base64 x-access-token:TOKEN>"; JANGAN simpan token di disk, repo, env antar-perintah, atau memori; sisipkan inline tiap perintah. Pakai git clone, bukan raw.githubusercontent.com. Hanya chat ini yang menulis ke repo; selalu git pull --rebase sebelum push (runner meng-commit hasil).

LANGKAH AWAL: (1) clone, baca STATUS_RINGKAS.md dulu, lalu bagian "Sesi x4" di STATUS.md bila perlu; (2) buat kunci RSA baru di sandbox DI LUAR repo (chmod 600), commit hanya ci/shot_pub.pem.

BATAS: ikuti bagian "Batas tetap" di STATUS_RINGKAS.md. Jangan ubah workflow yang memakai secret tanpa persetujuanku; jangan aktifkan loop tanpa pengawasan; tidak ada STATE_KEY/checkpoint pada sesi ini. Rencana kerja: ikuti "Rencana bot v0" di STATUS_RINGKAS.md. Laporkan padaku di mana bot macet dan apa yang perlu kuputuskan.

ATURAN: hemat token dan batas 5 jam; jalankan yang lama di runner; banyak kandidat = run paralel per label; minta hasil berupa angka, hindari membaca gambar kecuali perlu. Tandai tiap temuan [TERBUKTI]/[TERAMATI]/[DUGAAN]/[BELUM]. Push dan perbarui STATUS.md serta STATUS_RINGKAS.md sesering mungkin; verifikasi dengan clone ulang tanpa token. Bila chat sudah sangat panjang: hentikan, perbarui berkas, ingatkan aku membuka chat baru. Ingatkan aku merevoke token di akhir sesi. Jawab dalam bahasa Indonesia yang ringkas.
