# STATUS_RINGKAS (baca ini dulu; detail ada di STATUS.md bagian "Sesi x4", lalu "Sesi x3")
Repo PUBLIK halsuntech777-beep/riset-naruto. Tujuan: bot aturan tetap (Lua, tanpa LLM/API key) yang main dan menamatkan story mode Naruto: Shinobi no Sato no Jintori Gassen (PS1) sendiri di GitHub Actions; hasil riset = aturan main pasti untuk TileDuel. Story mode ~7-8 papan, tiap papan unik dan syarat menangnya sendiri [pemilik].

## Sesi x6 (TERBARU) - penanda fase di RAM untuk aturan いいえ (keputusan pemilik: lewat RAM)
- [TERAMATI] Penanda prompt Ya/Tidak papan: byte RAM 0x139F46 = 5 saat prompt terbuka, 0 di fase lain. Dump angka 40 frame di jalur baku (x6v1, x6v2): bernilai 5 di f24100-24800, f25500, f27400-27530; bernilai 0 di f15000, 20000, 23000, 24810-25200, 26000-27300, 27560-32000 (menu giliran, dialog teks, duel). Ditemukan dengan fitur DISC (kelas A prompt vs B bukan: x6d1; tangkapan terdekripsi memberi label, x6s).
- [TERAMATI] Kursor prompt: byte 0x1CECF0 = 0 (はい) -> 1 (いいえ) setelah DOWN, identik di dua prompt berbeda (naik level f24520, serang f27520; x6d2 dan x6d3; irisan 7 alamat, ini yang paling masuk akal). Nilai 0 di semua frame jalur baku tanpa DOWN.
- [TERAMATI] Prompt kartu (この札をつかいますか, sekitar f28500) TIDAK menyalakan 0x139F46 (bernilai 0 di f28450-28700): layar duel memakai mekanisme lain. [BELUM] layar sebenarnya di f25500 (flag=5, tampak prompt lain), apakah alamat sama di papan 2+, pemetaan jenis prompt.
- Alat baru: probe.lua `# DISC nama f...` + `# DISCQ q A B [cap] [maxv]` (cetak alamat byte konstan per kelas dan beda antar kelas; hanya angka, maks cap baris, awalan SCNDSC lolos saringan); alat/kerja.sh `jalan LABEL JADWAL MAXF [MODUS] [DUMPS] [ADDRS]`.
- ci/enkripsi_shot.py diperbaiki (izin pemilik): urut menurut frame numerik; nama shot_<frame> untuk frame<100000, shot_<frame/10> untuk >=100000 (penjaga run_remote.sh hanya menerima 5 digit; frame asli ada di baris SHOT_ENC f= arq=). Penjaga tidak diubah.
- [TERAMATI] KOREKSI penanda: 0x139F46 = 5 BUKAN khusus prompt Ya/Tidak; juga 5 di layar pilih kartu chance "ゲットする札をえらべ！" (x6p1 f39801; flag 5 sekitar f36728-40786). Di layar itu DOWN (+-40 kali) tidak menggerakkan kursor RAM 0x1CECF0 (tetap 0). Arti aman: jendela menunggu masukan [DUGAAN]. Saat jendela terbuka flag berjalan 2,3,4,5 tiap 2 frame, saat ditutup 0 [TERAMATI]. Kelas B di DISC tidak memuat layar ini (itu sebabnya lolos).
- [TERAMATI] Kursor RAM tetap 1 setelah prompt ditutup (f34904: flag 0, kursor 1): tidak boleh dipercaya sebagai posisi awal prompt berikutnya.
- [TERAMATI] x6p1/p2 (aturan lama: DOWN selama kursor RAM=0): macet +-4000 frame di layar pilih kartu (f36728-40786), lolos hanya lewat eskalasi stuck. lowchakra 4700 dan 4850 identik karena B1 (4565-4590) di bawah keduanya. Ketiga run (p1-p3) tamat papan 1 tanpa MACET 2: B1 -> 0 -> 1500 di f48357 (p1), 48417 (p2), 49197 (p3); sesudahnya c=1500,1500,0,0 (t3: 2000,2000,2000,0; sebab beda [BELUM]). p3 bukan kontrol murni (ada aturan UP). Run x6p4-p9 BATAL/tidak berguna (terkirim sebelum probe.lua baru ter-push; aturan lama; dorong gagal diam-diam saat indeks kotor).
- Bot (diperbaiki): satu episode flag=5 -> giliran 1 DOWN, giliran berikut CIRCLE (kursor RAM hanya dicatat; S line: ref= episode dengan kursor bergerak, fb= tanpa gerak). Uji ulang: x6pa (lowchakra 4700), x6pb (4400), x6pc (kontrol lowchakra=0, harus sama dengan t3).

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
