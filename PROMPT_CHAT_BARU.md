# PROMPT CHAT BARU (sesi x6). Ganti <TOKEN> dengan token asli; JANGAN commit token asli ke repo.
Aku melanjutkan riset game PS1 "Naruto: Shinobi no Sato no Jintori Gassen" (referensi TileDuel). Tujuan: BOT ATURAN TETAP (Lua di emulator, tanpa LLM/API key) + fitur LANJUT KE TENGAH PERMAINAN lewat replay log input, diuji di papan 1. Story mode ~7-8 papan, tiap papan unik.

Repo (PUBLIK): halsuntech777-beep/riset-naruto
TOKEN: <TOKEN>
(fine-grained, hanya repo itu; Contents + Workflows + Actions read/write; tanpa Administration dan Secrets). Pakai git -c "http.extraheader=Authorization: Basic <base64 x-access-token:TOKEN>"; JANGAN simpan token di disk, repo, env antar-perintah, atau memori; sisipkan inline tiap perintah (alat/kerja.sh membaca env T hanya untuk satu perintah: `T=<token> bash alat/kerja.sh ...`). Pakai git clone, bukan raw.githubusercontent.com. Hanya chat ini yang menulis ke repo; selalu git pull --rebase sebelum push (runner meng-commit hasil).

LANGKAH AWAL: (1) clone, baca STATUS_RINGKAS.md (bagian "Sesi x5"), lalu STATUS.md bila perlu; (2) buat kunci RSA baru di sandbox DI LUAR repo (chmod 600), commit hanya ci/shot_pub.pem; (3) HEMAT PANGGILAN ALAT (sesi lalu kehabisan batas): pakai alat/kerja.sh dan alat/ringkas.py, gabungkan langkah dalam satu panggilan bash, satu panggilan tunggu maks ~285 dtk, baca hasil lewat ringkasan angka; bila run masih lama akhiri giliran dengan laporan singkat.

BATAS: ikuti "Batas tetap" di STATUS_RINGKAS.md. Jangan ubah workflow/skrip yang memakai secret tanpa persetujuanku (satu-satunya perubahan yang sudah kusetujui: kata `BOT` di saringan chg.log ci/run_remote.sh); jangan aktifkan loop tanpa pengawasan; tidak ada STATE_KEY/checkpoint. Aturan いいえ buta ditolak (lowchakra=0) sampai ada deteksi fase/dialog. Lapor di mana bot macet dan apa yang perlu kuputuskan.

ATURAN: hemat token dan batas 5 jam; yang lama jalankan di runner, banyak kandidat = run paralel per label; minta hasil berupa angka, hindari membaca gambar kecuali perlu. Tandai tiap temuan [TERBUKTI]/[TERAMATI]/[DUGAAN]/[BELUM]. Push dan perbarui STATUS.md serta STATUS_RINGKAS.md sesering mungkin; verifikasi dengan clone ulang tanpa token. Bila chat sudah sangat panjang: hentikan, perbarui berkas, ingatkan aku membuka chat baru. Ingatkan aku merevoke token di akhir sesi. Jawab dalam bahasa Indonesia yang ringkas.
