# STATUS_RINGKAS (baca ini dulu; detail ada di STATUS.md bagian "Sesi x4", lalu "Sesi x3")
Repo PUBLIK halsuntech777-beep/riset-naruto. Tujuan: bot aturan tetap (Lua, tanpa LLM/API key) yang main dan menamatkan story mode Naruto: Shinobi no Sato no Jintori Gassen (PS1) sendiri di GitHub Actions; hasil riset = aturan main pasti untuk TileDuel. Story mode ~7-8 papan, tiap papan unik dan syarat menangnya sendiri [pemilik].

## Serah-terima Sesi x8 (dari chat x7; chat x7 TIDAK menulis ke repo lagi setelah ini)
Tujuan (keputusan pengguna): bot aturan tetap menamatkan PAPAN 1 secara MANDIRI (tanpa poke RAM). Story mode penuh ditunda (terlalu besar).
Fakta kunci:
- [TERAMATI] Papan 1 berakhir saat satu pemain mencapai chakra target lalu kembali ke start. Poke B1 sama di f9000+f13000 (tanpa bendera kristal): 2500 -> TIDAK tamat (B1 puncak 2997), 3000 -> tamat f50337, 3500/4000 -> tamat f49377. [DUGAAN kuat] target = 3000 (Clear Chakra bawaan). Kristal terlewati alami (h1 tamat tanpa poke bendera).
- [TERAMATI] COM (B2) bisa menang: x7m1 B2 3170 (f107425), papan berakhir f109105 saat B1=363 -> KALAH. Tanda reset sama untuk menang/kalah (c=1500,1500,0,0 p=0,0). Pakai `python3 alat/menang.py LABEL...` (menang B1 = pemenang kita; B2 = kalah).
- [TERAMATI] Tanpa poke, 110000 frame: tidak ada kemenangan kita; B1 maks 2781 (k2000/k3000 = hampir selalu menolak beli). B1 tak tumbuh karena sewa ke petak COM; COM bisa lebih dulu mencapai target.
- [TERAMATI] Beku 1: dialog ジャンプする水晶玉をえらんでください -> ext=1 (arah/bahu lalu CIRCLE) memecahkannya (g1/g2).
- [TERAMATI] Beku 2 (m2, tanpa poke): layar peta/info petak (空き地, tombol ✕もどる) f~49000-78938; RAM pantau statis. [DUGAAN] CIRCLE menjebak di peta; ext=2 (CROSS, arah, CIRCLE) dikirim untuk diuji. m3 beku f~97000 (layar belum dilihat).
- [TERAMATI] Jadwal diturunkan dari inputs/x7_e2.txt (f1-f5) gagal (timeout 1502 dtk + "unknown exception", penyebab [BELUM]). Bangun jadwal dari x6_q1.txt/x6_p6.txt + log, bukan dari jadwal turunan.
- Rute: replay input f0-f33100 (x6_p6) lalu bot (`# BOT from=33100`). Emulator deterministik, jadi variasi waktu tekan (gap/max) mengubah dadu; jadwal pemenang bisa direkam sebagai rute menang (replay log).
Alat: alat/kerja.sh (dorong/jalan/tunggu/lihat; env `PK= OPK=` = tanpa poke), alat/ringkas.py, alat/menang.py (BARU), ci/bot_lanjut.py, probe.lua cfg ext=0/1/2 (ext=1 arah/bahu->CIRCLE; ext=2 menambah CROSS->arah->CIRCLE didahulukan), lowchakra=N (tolak beli bila B1<N; 99999 = selalu tolak).
Gelombang 6 (12 run, TANPA poke, ext=2, stuck=1500 dead=40000, shots=0, maxf 170000, jadwal x6_p6; lowchakra {0,1000,1400,1800,2400,inf} x timing a=gap30/max100, b=gap45/max150): x7n0a=40180586552 x7n0b=40180594073 x7n1000a=40180601138 x7n1000b=40180608508 x7n1400a=40180615573 x7n1400b=40180622379 x7n1800a=40180629499 x7n1800b=40180636759 x7n2400a=40180643883 x7n2400b=40180650948 x7ninfa=40180657881 x7ninfb=40180665242
 Perkiraan selesai 09:41 UTC (16:41 WIB); baca aman mulai 09:47 UTC (16:47 WIB). Baca dengan: `python3 alat/menang.py x7n0a x7n0b x7n1000a x7n1000b x7n1400a x7n1400b x7n1800a x7n1800b x7n2400a x7n2400b x7ninfa x7ninfb` (setelah `git pull --rebase`).
Rencana Sesi x8:
 1. Baca gelombang 6 dengan menang.py. Bila ada run MENANG tanpa poke: catat jadwalnya (inputs/x7_n*.txt + presses di chg.log -> ci/bot_lanjut.py) sebagai RUTE MENANG, lalu ULANGI run yang sama untuk bukti deterministik.
 2. Bila belum ada: cari penyebab MACET (dd. shot dengan kunci baru; shots>=1), tambah makro/aturan, dan variasikan lowchakra/gap/max lebih banyak (ratusan variasi dadu murah di runner). Pertimbangkan aturan beli yang lebih cerdas (hanya beli petak murah, hanya saat B1 tinggi).
 3. Buat kunci RSA BARU di sandbox chat baru (kunci chat x7 hilang; shot gelombang 6 sengaja tanpa gambar).
 4. Jangan aktifkan loop tanpa pengawasan; usulkan dulu cara berhenti (berkas STOP, batas run). Jangan ubah workflow/skrip yang memakai secret tanpa persetujuan.
Keputusan menunggu pengguna: tidak ada yang mendesak; setelah ada rute menang, putuskan apakah bot dianggap "mandiri" jika kemenangan berasal dari pemilihan variasi waktu (deterministik) atau harus strategi umum.

## Sesi x7 - hasil x6q1, kunci gambar baru
- [TERBUKTI] ci/shot_pub.pem diganti kunci RSA 3072 baru (db8e41e); kunci privat hanya di sandbox chat x7, di luar repo. Shot dari run sebelum db8e41e (termasuk x6q1) memakai kunci lama.
- [TERAMATI] x6q1 (run 40159762435, jadwal x6_q1, maxf 190000, pokes baku, lowchakra=0): completed success, emulator 681 dtk. Bot menekan 741 kali dari f100002 (CIRCLE 381, CROSS 90, RIGHT 60, LEFT 60, lainnya 30 tiap tombol), lalu BOT# END f=161006 why=MACET (maxf 190000 tidak tercapai).
- [TERAMATI] S: f102000 c=2000,2000,2000,0 p=0,0; f104000 p=4,0; f132000 sampai f160000 c=1930,1300,1450,0 p=25,26 tidak berubah, seen 3118 -> 5760, esc 25 -> 290, ref=0, fb=0. CHG terakhir di ringkasan: P3 24 -> 25 di f130989. Keadaan beku +-f131000-f161006 sementara bot terus menekan.
- [BELUM] fase/layar saat macet (5 shot x6q1 terenkripsi kunci lama, tak terbaca), arti c=/p=/seen/esc, penyebab macet.
- Rencana: lanjut dari +-f130000 lewat ci/bot_lanjut.py; run paralel dengan ADDRS penanda fase (0x139F46, 0x1CECF0) dan SHOT di +-f135000/f145000 (kunci baru).
- [TERAMATI] Gelombang 1 (rute x6q1 + tekan bot <= f128000, semua success; id x7d1=40161134226 x7e1=40161140692 x7e2=40161147154 x7e3=40161153651 x7e4=40161160439 x7e5=40161166770 x7c1=40161172925): d1/e1/e3/e4/e5 membeku di keadaan sama (c=1930,1300,1450,0 p=25,26) sampai f148000 (e5 hashrate=30 sampai f188000, tetap beku). HANYA e2 (gap=60 max=200) lolos: f148000 c=2305,840,1557,0 p=27,30, sehat sampai f149906 (B1 turun 10 per 2 frame).
- [TERAMATI] Layar beku (shot d1 f131500/136000/145000, hanya di sandbox): dialog "ジャンプする水晶玉をえらんでください" + tombol けってい (pilih bola kristal tujuan lompat); sprite terus beranimasi sehingga hash layar selalu baru. Makro eskalasi lama tidak punya kombinasi RIGHT/LEFT -> CIRCLE dan tidak memuat L1/R1/L2/R2/SELECT. [DUGAAN] perlu arah/bahu lalu CIRCLE. [BELUM] dump RAM d1 hanya 1 frame per sesi (tak bisa lihat perubahan).
- [TERAMATI] Kontrol tanpa poke x7c1 (x6_p6, maxf 55500): f54000 c=1405,1767,0,0 p=65560,22; tanda tamat papan 1 (c=1500,1500,0,0 p=0,0) TIDAK muncul, sedangkan x6pc (poke baku) memunculkannya di f50000. [DUGAAN kuat] tamat papan 1 jalur ini bergantung pada poke B1=5000/bendera kristal; bot BELUM terbukti menang papan 1 tanpa poke.
- alat/kerja.sh: env PK= OPK= (kosong) = tanpa poke. probe.lua: cfg ext=1 = makro eskalasi arah/bahu(R1,L1,R2,L2) -> CIRCLE.
- Gelombang 2 (lanjut dari e2 f148000, maxf 190000; tanpa poke maxf 110000 untuk c2/c3): x7f1=40176978103 x7f2=40176985516 x7f3=40176992346 x7f4=40176999477 x7f5=40177006757 x7c2=40177013765 x7c3=40177020598
- Gelombang 3 (rute x6q1 <= f128000, ext=1, maxf 150000): x7g1=40177145272 x7g2=40177152581
- [KEPUTUSAN PENGGUNA] Fokus dulu: bot menamatkan PAPAN 1 secara mandiri (tanpa poke); story mode penuh terlalu besar.
- Gelombang 4 (tanpa poke, jadwal x6_p6, maxf 110000): k600/k900/k1200/k1500/k2000/k3000 = lowchakra tsb (PK= OPK=); h1 = hanya poke chakra B1 (OPK=), h2 = hanya bendera kristal (PK=). Id: x7k600=40177519927 x7k900=40177528073 x7k1200=40177536080 x7k1500=40177543468 x7k2000=40177550674 x7k3000=40177557636 x7h1=40177564658 x7h2=40177571835
- [TERAMATI] g1/g2 (ext=1, rute x6q1 yang beku): lolos beku; g2 f136000 c=2382,1180,1640 p=27,26; g1 f140000 sama; f148000 p=30,26; END MAXF f150000. Makro arah/bahu+CIRCLE memecahkan layar pilih bola kristal.
- [TERAMATI] f1-f5 GAGAL: rc_emulator=124 (timeout 1502 dtk), "An unknown exception occured" di emu_tail, log berhenti +-f32182. [BELUM] penyebab (jadwal diturunkan dari x7_e2.txt; jadwal dari x6_q1.txt + log berhasil). Batas job 30 menit (timeout-minutes: 30).
- [TERAMATI] h1 (hanya poke chakra B1=5000, TANPA bendera kristal; x6_p6): tamat papan 1 tetap terjadi (B1 5005 -> 0 di f49377, -> 1500 di f49524). Kristal terlewati secara alami; penghambat = chakra B1. Setelah tamat bot MACET f79525 (adegan setelah papan 1).
- [TERAMATI] Tanpa poke 110000 frame (x7c2, c3, k600..k3000): tidak ada tamat. B1 maks 2781 (k2000/k3000, selalu menolak beli, f96000); makin sering menolak beli makin tumbuh chakra. Hitungan (fb, ref) k600..k3000 = (6,1) (12,1) (9,3) (20,5) (28,6) (29,6).
- Gelombang 5: v2000..v4000 = poke B1 sama di f9000+f13000 tanpa bendera kristal (maxf 70000; cari ambang chakra tamat); m1/m2/m3 = tanpa poke, lowchakra=99999 (selalu menolak beli), ext=1, maxf 240000 (m2 gap=60 max=200; m3 stuck=6000 dead=60000). Perkiraan selesai: v 09:08 UTC, m 09:20 UTC. Id: x7v2000=40178832146 x7v2500=40178841690 x7v3000=40178850729 x7v3500=40178859178 x7v4000=40178867460 x7m1=40178875690 x7m2=40178884297 x7m3=40178892756

## Sesi x6 - penanda fase RAM, aturan いいえ, perbaikan alat, serah-terima ke Sesi x7
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
