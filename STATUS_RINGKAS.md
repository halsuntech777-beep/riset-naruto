# STATUS_RINGKAS (baca ini dulu; detail ada di STATUS.md bagian "Sesi x4", lalu "Sesi x3")
Repo PUBLIK halsuntech777-beep/riset-naruto. Tujuan: bot aturan tetap (Lua, tanpa LLM/API key) yang main dan menamatkan story mode Naruto: Shinobi no Sato no Jintori Gassen (PS1) sendiri di GitHub Actions; hasil riset = aturan main pasti untuk TileDuel. Story mode ~7-8 papan, tiap papan unik dan syarat menangnya sendiri [pemilik].

## Keputusan pemilik
- Bangun bot aturan tetap LANGSUNG, beserta fitur lanjut ke tengah permainan. Tanpa LLM/API key (tidak punya kartu; hanya langganan Claude).
- Tahap lanjut: replay log input dulu (tanpa secret). Checkpoint terenkripsi (STATE_KEY, ditambah pemilik sendiri) hanya bila replay mendekati ~20 mnt; minta persetujuan sebelum mengubah workflow berahasia.
- Loop mandiri (tahap 4) baru setelah melapor cara menghentikannya: berkas STOP, batas run harian/total, berhenti saat tamat/macet; GITHUB_TOKEN actions:write + cron cadangan.

## Cara kerja
- Jalankan: POST /repos/halsuntech777-beep/riset-naruto/actions/workflows/emulator-run.yml/dispatches, ref main, inputs (maks 10): jadwal, maxf, pokes, orpokes, dumps, addrs, modus, label. Hasil di hasil/<label>_<run>/ (chg.log, ringkasan.txt, dump_angka.csv, shot_*.enc.txt). Runner meng-commit hasil: selalu git pull --rebase sebelum push.
- Jalur baku r13 (WAJIB, kalau tidak nilai beda 3500): jadwal inputs/r13_a.txt, maxf=33100, pokes=9000@70EB8@4@5000,13000@70EB8@4@5000, orpokes=14000-36000@70EBC@4@0x3000. Header jadwal: # SPUSPEED 4, # NODEBUG, # SCAN/SCANH/SCANB/SCANP/SCANMAX (README.txt), # SVS from= step= dan # SHOT f... (butuh modus=svs).
- Tangkapan layar terenkripsi hibrida: buat kunci RSA baru tiap sesi di sandbox DI LUAR repo (openssl genrsa -out priv.pem 3072; pub ke ci/shot_pub.pem; commit hanya pub); dekripsi: python3 ci/dekripsi_shot.py priv.pem shot_F.enc.txt out.png.
- Kecepatan ~232 frame/dtk (33.100 frame = 140-145 dtk); job 30 mnt = ~380 ribu frame tanpa beban bot. Deterministik (sc2 identik dengan r13a).

## Pengetahuan teguh
- [TERBUKTI] Chakra dari B1..B4 = 0x70EB8, 0x70F6C (B1,B2 terbukti; B3 0x71020, B4 0x710D4 dugaan). Tidak ditimpa saat duel. A1..A4 dan P1 ditimpa saat duel; posisi P1 0x70F28 hanya sahih saat papan.
- [TERAMATI] HUD atas = chakra. Dialog: 結界をレベルアップしますか？ dan ここを攻撃しますか？ (はい/いいえ, kursor awal はい; DOWN lalu CIRCLE = いいえ).
- Alur duel (Sesi x3): tolak = bayar toll 220; serang = kartu +1, pilih jurus (CIRCLE=クナイ 攻3/50, CROSS=なぐる 攻4/150, TRIANGLE=多重影分身 攻5/50), roulette bertahan otomatis, roulette penyerang berhenti dengan CIRCLE. Jalur lengkap sampai barrier direbut: inputs/r13_a.txt (~f 33.100).
- [BELUM] Alamat durabilitas (0x16C280 = kebetulan, jangan dipakai), fase menu/dialog, giliran, pemetaan frame-henti-roulette -> nilai, syarat menang papan 1, kasus serangan gagal, rumus damage, stage 2, adegan kalah/game over/kredit.

## Batas tetap
Jangan unggah/commit file game (.bin/.cue), gambar mentah, dump RAM/VRAM, save-state tidak terenkripsi ke repo, release, artefak, cache, atau log; tanpa upload-artifact; hanya angka, teks bantuan emulator, gambar terenkripsi (hibrida AES-256-CBC + RSA-OAEP), state terenkripsi. Jangan minta ROM, jangan sentuh repo aset, jangan ganti/bangun emulator tanpa persetujuan. Penjaga ekstensi/ukuran di ci/run_remote.sh tetap. Token jangan disimpan di disk/repo/env/memori; sisipkan inline per perintah dengan git -c "http.extraheader=Authorization: Basic <base64 x-access-token:TOKEN>". Tandai temuan [TERBUKTI]/[TERAMATI]/[DUGAAN]/[BELUM]. Ingatkan pemilik merevoke token di akhir sesi.

## Rencana bot v0 (kerjakan berurutan)
1. redux/lua_mine/bot.lua dimuat probe.lua (header # BOT): baca B1..B4 dan hash layar tiap ~10 frame; tabel adegan (berkas angka di repo) hash -> aksi; bawaan CIRCLE periodik (~100 frame); layar statis lama -> eskalasi tombol (CIRCLE, DOWN+CIRCLE, CROSS, TRIANGLE, START); watchdog -> status MACET; catat hash adegan baru (angka) dan SHOT terenkripsi terbatas untuk adegan baru.
2. Fitur lanjut: bot merekam input ke log (RLE) yang bisa diputar ulang; run berikut memutar log lalu bot mengambil alih. Uji: replay sampai f=33.100 lalu bot mengambil alih.
3. Uji papan 1 lewat run terbatas, laporkan di mana macet. Perbarui STATUS.md dan push tiap kemajuan; verifikasi clone ulang tanpa token.

## Catatan akhir Sesi x4
Ada draf BOT v0 di probe.lua yang ASAL-USULNYA TIDAK JELAS (tidak ditulis di chat ini; merujuk ci/bot_lanjut.py yang tidak ada). Disimpan HANYA di cabang `bot-v0-belum-diuji`, tidak di main. Tinjau dan uji dulu; jangan percaya apa adanya. Boleh dipakai sebagai bahan atau ditulis ulang.
