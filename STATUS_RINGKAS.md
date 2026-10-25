# STATUS_RINGKAS (baca ini dulu; detail ada di STATUS.md bagian "Sesi x4", lalu "Sesi x3")
Repo PUBLIK halsuntech777-beep/riset-naruto. Tujuan: bot aturan tetap (Lua, tanpa LLM/API key) yang main dan menamatkan story mode Naruto: Shinobi no Sato no Jintori Gassen (PS1) sendiri di GitHub Actions; hasil riset = aturan main pasti untuk TileDuel. Story mode ~7-8 papan, tiap papan unik dan syarat menangnya sendiri [pemilik].

## Sesi x6 (TERBARU) - penanda fase RAM, aturan いいえ, perbaikan alat, serah-terima ke Sesi x7
- [TERAMATI] Penanda RAM 0x139F46 = "jendela menunggu masukan": saat jendela terbuka berjalan 2,3,4,5 (tiap 2 frame), 5 = menunggu, 0 = tutup/tidak ada. Bernilai 5 di prompt Ya/Tidak (f24100-24800, f27400-27530) DAN di layar pilih kartu chance "ゲットする札をえらべ！" (x6p1 f39801); bernilai 0 di menu giliran, dialog teks, transisi, pilih kartu duel, menu duel (dump 40 frame, x6v1/x6v2). Ditemukan dengan fitur DISC (x6d1: kelas prompt vs bukan), lalu DIKOREKSI: bukan khusus Ya/Tidak. Prompt kartu duel (この札, f~28500) tidak menyalakannya.
- [TERAMATI] Kursor Ya/Tidak 0x1CECF0: 0 -> 1 setelah DOWN di prompt naik level (f24520) dan prompt serang (f27520) (x6d2, x6d3). Tidak bergerak di layar pilih kartu; tetap 1 setelah prompt ditutup => hanya dicatat, TIDAK dipercaya.
- [TERAMATI] Aturan lama (DOWN sampai kursor RAM=1) macet +-4000 frame di layar pilih kartu (x6p1/p2: f36728-40786). Aturan baru "satu episode flag=5: DOWN lalu CIRCLE" (x6pa lowchakra 4700, x6pb 4400, x6pc kontrol 0; jalur r13_bot_base, bot dari f33100, maxf 55500): tidak ada episode flag=5 >600 frame, tidak ada MACET 2, papan 1 tamat (B1 -> 0 -> 1500) di f44517 (pa), f49437 (pb), f49197 (pc). S akhir: pa ref=2 fb=3 (2 penolakan nyata dengan kursor bergerak), pb ref=0 fb=5, pc ref=0 fb=0. [DUGAAN] lowchakra=4700 mempercepat tamat papan 1 ~4700 frame (satu run per ambang; perlu ulangan).
- [TERAMATI] Jalur kode baru (hashrate=9999 baku) berakhir di c=1500,1500,0,0 (B1 -> 0 -> 1500), BEDA dari t3/t5/t8 (c=2000,2000,2000,0; B1 4905 -> 2000 di f~54095). [DUGAAN kuat] t3 memakai default lama (kemajuan = hash layar) sehingga tekanannya beda. Rute sah untuk lanjut tetap replay log t3 -> t8 (terbukti sampai f114000). Arti B1->0 / 1500 [BELUM].
- Alat: probe.lua `# DISC nama f...` + `# DISCQ q A B [cap] [maxv]` (keluaran SCNDSC, hanya angka, maks cap baris); alat/kerja.sh `jalan LABEL JADWAL MAXF [MODUS] [DUMPS] [ADDRS]`; `dorong` kini mengatur identitas git (pull --rebase butuh identitas committer; tanpa itu rebase macet diam-diam saat runner menambah commit: gejala `.git/rebase-merge` tersisa dan indeks kotor). ci/enkripsi_shot.py diperbaiki (izin pemilik): nama shot_<frame> untuk frame<100000, shot_<frame/10> untuk >=100000 (tabrakan nama dinaikkan satu; frame asli di baris SHOT_ENC f= arq=).
- Pelajaran proses: run yang dikirim sebelum kode ter-push sia-sia (enam run x6p4-p9). SEBELUM `jalan`, verifikasi `git show origin/main:redux/lua_mine/probe.lua | grep <penanda>`; setelah `dorong`, verifikasi isi origin, bukan hanya pesan commit.

## Serah-terima Sesi x7 (kerjakan berurutan)
Tujuan: bot aturan tetap menamatkan story mode (+-7-8 papan) mandiri, dengan lanjut ke tengah permainan lewat replay log.
0. Run latar belakang x6q1 (inputs/x6_q1.txt = bot_t8 + kode baru, lowchakra=0, maxf=190000, SHOT 110000 130000 150000 170000 190000, modus svs) dikirim di akhir Sesi x6: baca hasilnya DULU dengan alat/ringkas.py (sejauh mana, di mana macet, S/END, c=/p=, episode flag >600 frame, BOT# P). Waktu run +-20 menit.
1. Tentukan frame terjauh yang sehat dari log x6q1, buat jadwal lanjut dengan ci/bot_lanjut.py (log -> replay + `# BOT from=F`), jalankan beberapa run paralel per label dengan cfg berbeda (stuck, gap, lowchakra) agar satu giliran menghasilkan banyak data.
2. Deteksi akhir papan dari RAM (B1 -> 0 atau c= berubah) dan awal papan baru; catat tabel aksi per papan ke berkas angka (mis. persimpangan t8: RIGHT di f102602).
3. Perluas penanda fase hanya bila perlu; aturan いいえ tetap lowchakra=0 kecuali ada bukti manfaat.
4. Loop mandiri HANYA setelah melapor cara berhenti (berkas STOP, batas run harian/total, berhenti saat tamat/macet) dan persetujuan pemilik.

## Sesi x5 - BOT aturan tetap + lanjut lewat replay log
Alat (hemat panggilan): `T=<token> bash alat/kerja.sh dorong|jalan|tunggu|lihat` (token hanya env satu perintah), `alat/ringkas.py DIR` (ringkasan angka), `ci/bot_lanjut.py LOG BASE OUT --upto F --cfg '...'` (log tekan bot -> jadwal replay + `# BOT from=F`). Dasar jadwal: `inputs/r13_bot_base.txt`.
Bot: blok BOT di `redux/lua_mine/probe.lua`, aktif bila jadwal punya `# BOT from=F`; `# BOTCFG k=v` (K stable gap max stuck dead maxlog shots hashrate lowchakra refuse). Keluaran: `BOT f TOMBOL lama` (tekan, = baris jadwal), `BOT# N/S/END`. Saringan chg.log di `ci/run_remote.sh` kini memuat `BOT` (disetujui pemilik; satu kata, penjaga ekstensi/ukuran tidak diubah).
Temuan:
- [TERBUKTI] Replay: CHG f<=33100 identik dengan baseline sc2 (md5 f770298dc3bf). Replay log tekan bot (t2) menghasilkan CHG (33100,40000] identik dengan run bot asli t1 (md5 b5c3150767f7); t5/t8 mencapai keadaan persimpangan yang sama dengan t3 (c=2000,2000,2000,0 p=0,0).
- [TERAMATI] Bot CIRCLE periodik memainkan papan 1 tanpa macet (t1 f33100-45000: 132 tekan; t3: B1 4905->2000 di f~54095, lalu c=2000,2000,2000,0 p=0,0, cutscene "木ノ葉丸だコレ!" di f60000, papan baru di f100000). [DUGAAN] tamat papan 1 membuka papan/stage berikutnya; syarat menang [BELUM] (layar status menampilkan 目標チャクラ 3000).
- [TERAMATI] MACET 1: persimpangan arah di papan baru (panah kiri/kanan di sekitar karakter, CIRCLE berlabel マップ). t3 macet >=96 ribu frame, t5 35 ribu frame; RAM statis. Penyebab penjaga gagal: animasi terus menghasilkan hash layar baru (40-150 per 1000 frame), jadi "hash baru = kemajuan" salah. Default sekarang kemajuan = RAM pantau saja (hashrate=9999).
- [TERAMATI] Hash layar persis tidak bisa jadi tabel adegan (animasi): ~1000 hash baru per 12 ribu frame.
- [TERAMATI] MACET 2: aturan いいえ buta (DOWN+CIRCLE di t4/t7, CROSS di t6) menghentikan permainan sejak f~36000: layar masuk status/peta (ステータス, マップ, info 結界, ×もどる); RAM statis sampai f52000; eskalasi (esc>=107) tidak memulihkan. [DUGAAN] tombol arah/CROSS di fase non-dialog membuka layar status/peta. Maka `lowchakra` default 0 (mati) sampai ada deteksi fase/dialog.
- [TERAMATI] Pesan "ミズキの結界をうばいとりました" di f36201 (t6) = hasil rebut barrier.
- [TERAMATI] Kecepatan ~235 f/s (papan 1) dan ~131 f/s (papan 2, t3); timeout emulator 1500 dtk ~ 195 ribu frame per run; replay 100 ribu frame ~ 7 menit.
- [TERAMATI] Nama tangkapan: `s%05d.raw` -> frame >=100000 jadi 6 digit dan ci/enkripsi_shot.py membaca [1:6]: `shot_10000` = frame 100000, `shot_14000` = 140000, dst (frame/10). Tidak diubah (perlu persetujuan). Maks 8 tangkapan per run.
- t8 (replay log t3 sampai 100000 lalu bot v2, kemajuan RAM saja, stuck=2500): [TERBUKTI] eskalasi memulihkan persimpangan: bot ambil alih di f=100000 (stuck=2500, kemajuan RAM saja); tekan RIGHT (makro eskalasi pertama) di f=102602 -> P1 0->4 dalam 76 frame dan permainan lanjut (B2 f105632, B3 f111468, 158 tekan sampai f=114000, tanpa macet permanen). Ada jeda tanpa perubahan RAM f~107650-110150 lalu makro eskalasi berulang (esc 2->17); apakah makro atau hal alami yang melanjutkan = [DUGAAN].
Keputusan terbuka untuk pemilik: (1) cara deteksi fase/dialog untuk aturan いいえ: RAM (cari penanda fase lewat dump/diff) atau wilayah layar; (2) izin memperbaiki parsing nama di ci/enkripsi_shot.py (satu baris).
Langkah berikut: cari penanda fase di RAM, uji tamat papan 1 dari replay (t3 sampai f~54000), baru bangun aturan いいえ; kurangi eskalasi saat jeda wajar (jeda normal RAM bisa ~4000 frame).

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
