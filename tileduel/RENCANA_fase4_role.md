# RENCANA FASE 4: Role elemen & skill tree

Disusun Opus, 25-09. STATUS: DIKERJAKAN 25-09 -- Fase 3 dikonfirmasi lolos uji HP user, Langkah A (Sonnet)
mulai ditulis. Rencana dikunci (K1-K5 = a; K6-K12 = saran Opus, pilihan pertama).
Sudah ditinjau agen terpisah terhadap kode (2 penghalang + belasan catatan, semuanya sudah dimasukkan).
Patokan panjang Quick SEBELUM Fase 4 sudah diukur (lihat bagian 9 U3, `PATOKAN_panjang_quick_sebelum_fase4.md`).

ATURAN USER yang tetap berlaku: balas dalam Bahasa Indonesia; teks untuk pemain = bahasa Inggris sederhana;
saklar UJI_DUEL, UJI_SERI (pemain_dasar.gd), UJI_SELALU_PEDANG (petak_kartu.gd) WAJIB false di produksi;
edit hanya baris/bagian yang relevan (jangan tulis ulang file); kirim SET LENGKAP terbaru dalam SATU pesan
dan minta unduhan lama dibuang; `ID_INTERSTISIAL_ASLI` masih kosong (isi sebelum rilis); FPS = prioritas,
setiap efek baru wajib punya versi ringan Very Low; pengacak permainan = `mesin_acak` (di host), JANGAN
randi()/randf()/pick_random()/shuffle() global.

## 0. Ringkas

Setiap pemain (termasuk AI) memilih 1 dari 5 role elemen. Role menentukan: jebakan wajib, ketahanan terhadap
2 jenis jebakan lain, dan (langkah B) pohon skill untuk menaikkan jebakannya & ketahanannya. Level Pemain
menentukan berapa jenis jebakan yang dibawa di solo (2-5); di multiplayer semua membawa 3.

Dikerjakan dua langkah dalam fase yang sama (K5a):
- LANGKAH A (role dasar): pilih role (solo & lobby), jebakan role wajib, jumlah jenis jebakan, ketahanan Lv1
  tetap, AI ber-role + AI MEMASANG JEBAKAN (baru sama sekali), tampilan role di HUD, uji keseimbangan.
  -> dikirim ke user untuk uji HP, TIDAK di-upload ke Play Store.
- LANGKAH B (pohon penuh): Level Role 1-20 + XP Role + SP, 5 pohon (3 node jebakan + 2 ketahanan + Ultimate),
  layar pohon, Guard, Arena Build 12 SP + preset, reset gratis, sinkron build, keseimbangan ulang.
  -> dikirim untuk uji HP, lalu A+B dirilis SEKALI.

## 1. Keputusan

Sudah diputuskan user (25-09, semua "a"):
- K1. AI solo tanpa pilihan kesulitan: level role AI = level role pemain untuk role yang sedang dipakai
  pemain, build AI = preset Balanced dengan SP sebanyak itu. Pilihan kesulitan ditunda ke Duel Road (Fase 8).
- K2. Stone Thorns hanya berlaku saat petak yang diserang punya jebakan tanah milik pemain role Tanah.
- K3. Jebakan tanah hanya boleh dipasang di petak SENDIRI (sekarang: petak siapa pun yang sudah dimiliki).
- K4. Anggaran Arena mulai 12 SP; angka akhir ditentukan uji keseimbangan.
- K5. Langkah A dikirim dulu untuk uji HP (tanpa upload), baru langkah B, lalu dirilis sekali.

Dari dokumen desain (tidak diubah): matriks ketahanan = tabel menang-kalah duel; Level Role 1-20 terpisah per
role; XP Role (pasang +10, kena +30, tahan +15, menang duel dengan elemen role +20, selesai +50, menang +100;
Lv2 butuh 100 XP, tiap level +50); node Lv1-3 berbiaya 1/2/3 SP, Ultimate 4 SP, total pohon 34 SP; slot
jebakan solo menurut Level Pemain (Lv1: 2, Lv3: 3, Lv6: 4, Lv10: 5); multiplayer 3 jenis; role boleh kembar;
role selalu aktif (Quick & Classic); reset SP gratis di luar pertandingan; semua angka = angka awal.

Tafsiran teknis Opus (tidak perlu persetujuan, boleh dikoreksi):
- Level Role L memberi L SP (Lv1 = 1 SP, Lv20 = 20 SP = "SP maksimal 20").
- "Terbuka di Level Role 1/5/10/15" = TINGKAT node: Lv1 node mana pun terbuka di Level Role 1, Lv2 di 5, Lv3
  di 10, Ultimate di 15. Arena: semua tingkat terbuka.
- (U3 mengubah api -> 60 koin/giliran dan angin -> 10%, lihat 13.2.)
- Angka dasar (tanpa node) = perilaku SEKARANG: api 50 koin/giliran x 3 giliran; angin rampas 15% lalu
  disebar ke papan; air lempar ke petak acak + gelembung 2; petir lumpuh (sisa_paralisis 2); tanah +1 HP
  untuk satu duel; penyerang kalah duel bayar x1,2; semua jebakan 1 bintang.
- Ketahanan (selain Guard) paling besar -50% dan dihitung PALING AKHIR (setelah node penyerang).
- Guard = sekali per pertandingan, jebakan pertama jenis itu yang mengenai pemain tidak berefek sama sekali
  (jebakannya tetap hilang). Otomatis, tidak bisa disimpan.
- Rock Breaker memotong TAMBAHAN denda kalah duel, bukan dendanya: pengali = 1 + (p - 1) x (1 - r). Contoh
  x1,2 dengan -50% = x1,1; Stone Thorns x1,5 dengan -25% = x1,375. Dengan begitu Fight tidak pernah lebih murah
  dari Give Up (x1,0) -- kalau dipotong dari dendanya, x1,2 -25% = x0,9 dan Fight selalu menang hitungan.
- Sacred Ground + Fortress Lv3 tidak boleh membuat petak kebal selamanya: jebakan Sacred Ground memakai
  Fortress paling tinggi Lv2 (menahan 2 serangan). Petaknya tetap bisa direbut lewat duel.
- Chain Lightning & Frozen Bubble Lv3 = "lemparan dadu berikutnya LOW ROLL". Durasi dadu dihitung mundur di
  awal giliran SEBELUM melempar, jadi disimpan sebagai durasi 2 (durasi 1 langsung habis tanpa efek); tidak
  menimpa kartu LOW/HIGH ROLL yang durasinya lebih panjang.
- Di langkah A setiap role memiliki kedua node ketahanannya di Lv1 (gratis, tetap). Di langkah B Lv1 itu
  dibayar dengan SP seperti node lain.

PERLU PERSETUJUAN USER (K6-K12):
- K6. Alur solo: SINGLE PLAYER -> jumlah lawan -> SELECT STAGE -> layar ROLE (baru) -> START. Layar ROLE
  sudah memilih role & jebakan terakhir, jadi cukup tekan START (tambah 1 ketukan). Pertama kali main,
  role harus dipilih dulu (START mati sampai memilih).
  Alternatif: role dipilih sekali di menu utama, tidak ditanya tiap main (lebih cepat, tapi pemain jarang
  mengganti role/jebakan melawan lawan tertentu).
- K7. Frozen Bubble ditulis ulang. TEMUAN: selama melayang di gelembung pemain manusia SUDAH tidak bisa memakai
  kartu (kode sekarang menyembunyikan "Use Card"), jadi Lv1-Lv2 versi dokumen tidak berefek apa-apa. Usulan:
  Lv1 kartu korban terkunci 1 giliran SESUDAH gelembung pecah; Lv2 2 giliran; Lv3 2 giliran + lemparan dadu
  pertama sesudah gelembung jadi LOW ROLL (1-3). Sekalian: AI sekarang MASIH memakai kartu saat melayang
  (ai_musuh.gd tidak memeriksa gelembung) -- disamakan dengan manusia (tidak boleh).
- K8. Arti gerakan:
  - Rapid Current: korban dilempar MUNDUR, minimal 3/6/9 petak lebih jauh dari gaji START berikutnya
    (sekarang: petak acak mana pun, bisa malah maju).
  - Steady Feet Lv2: petak jatuh paling jauh 6 petak dari jebakan (maju atau mundur).
  - Whirlwind: korban kehilangan 1/2/3 langkah dari lemparan dadunya (tidak berjalan mundur; lebih jelas di
    layar & lebih mudah disinkronkan). Kalau langkahnya habis, korban berhenti di petak jebakan angin.
  - Tsunami: lawan lain yang berdiri dalam jarak 2 petak didorong mundur 2 petak; petak tujuan TIDAK memicu
    jebakan/koin/permata.
- K9. Role AI di lobby multiplayer: diundi host saat mode dipilih, terlihat semua pemain di lobby (supaya
  pemain bisa memilih jebakan melawannya). Host tidak bisa mengganti role AI (sederhana).
- K10. Tombol WATCH AD: DOUBLE REWARDS ikut menggandakan XP Role (langkah B).
- K11. Syarat "seimbang" (bagian 9): di 2 pemain tiap role menang 44-56% (gabungan semua lawan); di 4 pemain
  tiap role menang 20-30% per penampilan (K15, dulu tertulis 15-25%); tidak ada pasangan role yang > 65%. Kalau belum tercapai, Opus
  menyetel angka di data_role.gd lalu uji ulang (angka tidak perlu persetujuan per perubahan; laporan akhir
  mencantumkan semua angka yang berubah).
- K12. BUG LAMA yang ikut memengaruhi jebakan petir: korban petir yang berhenti di petak lawan membayar denda
  DUA KALI -- sekali saat berhenti, lalu sekali lagi di giliran lumpuhnya (giliran yang dilewati tetap masuk
  "fase akhir" di petak yang sama, Fight terkunci, jadi harus bayar lagi). Usulan: diperbaiki di langkah A --
  giliran lumpuh hanya mengambil kartu/permata seperti sekarang, tanpa konfrontasi kedua. (Tanpa perbaikan,
  jebakan petir di petak sendiri jadi terlalu kuat dan AI akan terus memakainya.)

## 2. Temuan dari kode yang membentuk rencana ini

1. AI TIDAK PERNAH memasang jebakan (ai_musuh.gd: beli, bangun, duel, serang jarak jauh, kartu saja). Langkah A
   membuat otak jebakan AI dari nol (bagian 6). Akibatnya permainan solo & multiplayer dengan AI ikut berubah
   (lebih banyak jebakan di papan, animasi 1,5 dtk per jebakan) -> panjang pertandingan diukur (bagian 9).
2. Jebakan tanah bisa dipasang di petak milik pemain lain (syaratnya hanya "petak sudah dimiliki") -> K3.
3. x1,2 (penyerang kalah duel) berlaku di semua duel (`_hasil_duel_petak` -> `_bayar_denda(..., 1.2)`, tombol
   "Fight (Risk: ...)" di `periksa_status_petak`) -> K2.
4. Frozen Bubble -> K7.
5. Serangan jarak jauh punya DUA salinan logika: manusia (`eksekusi_serangan`, pemain_papan.gd) dan AI (di
   `logika_ai_fase_awal`, ai_musuh.gd). Fortress harus dipasang di keduanya lewat satu fungsi bersama.
6. Hanya jebakan air yang langsung disiarkan saat dipasang (`_siarkan_jebakan_dipasang`); jenis lain muncul di
   client lewat siaran state 1,5 dtk kemudian, tanpa teks. Langkah A: semua jenis disiarkan saat dipasang
   (A3). Jebakan siluman (Stealth Charge) di langkah B butuh info tambahan di data jebakan (bagian 7).
7. Uji simulasi cincin (uji_sim.gd) pertandingannya sangat pendek (sering selesai di giliran ke-5) -> tidak
   mewakili untuk keseimbangan. Uji keseimbangan memakai peta asli (uji_nyata.gd). Lama per pertandingan di
   rig belum pasti (Classic kira-kira 45 dtk dari log uji Fase 3) -> diukur dulu dengan uji coba (U3).
8. (Tinjauan) Handler tombol jebakan (`_on_tombol_air_pressed` dst.) bekerja atas `slot_giliran_ui`, yang
   hanya diisi `periksa_status_petak` -- giliran AI tidak pernah lewat situ, dan tiap handler diakhiri
   `periksa_status_petak` (membuka menu manusia di tengah giliran AI). AI TIDAK BOLEH memanggil handler
   tombol -> dibuat satu fungsi inti tanpa UI (A3).
9. (Tinjauan) Urutan jebakan tanah: `_pantau_duel_berlangsung` bangun pada sinyal `duel_selesai` (akhir layar
   duel), SEBELUM `_hasil_duel_petak` memindahkan pemilik petak & membayar denda; jebakannya juga sudah
   `queue_free`. Jadi "ada jebakan tanah saat duel" harus dicatat saat `_mulai_duel` mulai, dan keputusan
   jebakan tetap/hilang (Hard Rock, Sacred Ground) dibuat SESUDAH pemilik petak ditentukan (B4).
10. (Tinjauan) Client yang aksinya ditolak host bisa macet: menu client sudah disembunyikan sebelum permintaan
   dikirim, dan host yang menolak diam saja (sudah terjadi sekarang kalau bintang < 1). Setiap penolakan
   wajib memanggil `periksa_status_petak(slot)` supaya menu client muncul lagi. `rpc_minta_aksi` menerima
   `trap_*` di fase apa pun -> validasi di fungsi inti.
11. (Tinjauan) Pemain yang melayang di gelembung tidak mendapat gaji saat lewat START (`bergerak_maju`). Jadi
   Steady Feet Lv1 ("gelembung 1" = tidak ada giliran melayang) cukup kuat -- dipantau di uji keseimbangan.
12. (Tinjauan) Serangan jarak jauh AI selalu membidik petak menara Lv2 yang sama; dengan Fortress (B) AI akan
   membuang 5 bintang tiap giliran -> AI harus melewati petak yang dilindungi Fortress.
13. Pelajaran rig 25-09: proses uji di latar MATI saat giliran balasan Claude selesai. Uji panjang (regresi 37
   skenario, keseimbangan ribuan pertandingan) harus dijalankan SELAMA Claude masih bekerja, dipecah per
   potongan <= 1 jam, dan hasilnya ditulis per pertandingan supaya bisa dilanjutkan (lewati benih yang sudah
   ada hasilnya).

## 3. File

Rantai pemain (aturan Fase 3 no. 8): file baru `pemain_role.gd` DI ANTARA pemain_tampilan.gd dan
pemain_papan.gd, supaya papan/kartu/duel/jaringan/pemain.gd (semuanya di atasnya) bisa memanggil aturan role
tanpa deklarasi @abstract baru:
`pemain_dasar -> pemain_tampilan -> pemain_role -> pemain_papan -> pemain_kartu -> pemain_duel ->
pemain_jaringan -> pemain.gd`

| File | Baru/ubah | Isi |
|---|---|---|
| `data_role.gd` | BARU | `class_name DataRole`, hanya konstanta & fungsi static murni: daftar role, nama, warna, ketahanan, SEMUA angka node, preset, slot jebakan, XP Role. SATU-SATUNYA tempat menyetel angka. |
| `pemain_role.gd` | BARU | `@abstract`, extends pemain_tampilan.gd. Aturan role di dalam pertandingan: menyiapkan role tiap slot, jebakan yang dibawa, hitungan ketahanan/node, Guard, syarat pasang jebakan, jarak antar petak, kemas/terapkan state role. |
| `ai_jebakan.gd` | BARU | `class_name AiJebakan` (static, seperti AiMusuh): pilih role/jebakan/build AI, dan keputusan AI memasang jebakan. |
| `ui_role.gd` | BARU | `class_name UiRole` (static, seperti UiProfil): layar pilih role & jebakan (solo + lobby); langkah B: layar pohon & Arena Build. |
| pemain_papan.gd | ubah | `extends "res://pemain_role.gd"`; menu Set Trap hanya jenis yang dibawa; tanah hanya petak sendiri; validasi di host; Fortress; (B) Sacred Ground, Tornado, Phoenix, Stealth. |
| pemain.gd | ubah | titik picu jebakan di `bergerak_maju` & efek tiap giliran di `_mulai_giliran`; siapkan role di `_siapkan_peta_dan_mulai`; label Fight Risk; Grounded. |
| pemain_duel.gd | ubah | tanah saat duel (Hard Rock, Rock Breaker, Stone Thorns), pengali kalah duel. |
| pemain_kartu.gd | ubah (B) | Card Magnet, kunci kartu Frozen Bubble. |
| pemain_jaringan.gd | ubah | state role di `_siarkan_state_giliran` & penerapannya; data jebakan tambahan. |
| data_pemain.gd | ubah | field role per slot (bagian 4). |
| jebakan_air.gd | ubah | durasi gelembung & petak jatuh lewat fungsi main_node (Steady Feet, Rapid Current). |
| jebakan_tanah.gd | ubah | (B) bertahan beberapa duel, tanda Sacred Ground. |
| jebakan_api/angin/petir.gd | ubah (B) | Phoenix, Tornado, Stealth (+ versi Very Low). |
| ai_musuh.gd | ubah | panggil AiJebakan di akhir giliran AI; Fortress di serangan AI; AI boleh Fight saat lumpuh bila Grounded. |
| main_menu.gd | ubah | langkah ROLE di solo; (B) tombol ROLES di menu utama. |
| layar_local_play.gd | ubah | pilih role di lobby, role terlihat di daftar PLAYERS, dikirim saat START. |
| status_jaringan.gd | ubah | `role_slot` (data role semua slot dari lobby), dikosongkan di `reset_susunan`. |
| profil_pemain.gd | ubah | VERSI 2: role terakhir, jebakan per role; (B) XP role, build solo, Arena build. |
| ui_profil.gd | ubah (B) | baris XP Role di kartu hadiah akhir pertandingan. |
| ui_dinamis.gd | ubah | tanda role di HUD (2 pemain & 3-4 pemain). |

Aturan Fase 3 ikut diperbarui: `cek_nama_ganda.py` (8 file), `DAFTAR` di `cek_muat_f3.gd` (+4 file baru),
skrip sinkron rig (+4 file), jumlah file di set kiriman (22 -> 26).

## 4. Data

### 4a. data_role.gd (angka awal; semuanya bisa disetel)
- `ROLE := ["api", "air", "tanah", "petir", "angin"]` (urutan sama dengan segi lima duel).
- `NAMA := {"api": "FIRE", "air": "WATER", "tanah": "EARTH", "petir": "LIGHTNING", "angin": "WIND"}`, warna =
  warna elemen di ui_elemen.gd `DATA_ELEMEN`.
- `NODE_JEBAKAN := {"api": "JebakanApi", "air": "JebakanAir", "tanah": "JebakanTanah", "petir": "JebakanPetir",
  "angin": "JebakanAngin"}`.
- `TAHAN := {"tanah": ["petir","angin"], "petir": ["api","air"], "angin": ["petir","air"], "api": ["tanah","angin"],
  "air": ["api","tanah"]}`. Rig memeriksa bahwa ini SAMA dengan `menang_lawan` di `DATA_ELEMEN`.
- `NODE_TAHAN := {"api": "heat_skin", "air": "steady_feet", "angin": "heavy_pockets", "petir": "grounded",
  "tanah": "rock_breaker"}` (kunci = elemen jebakan yang ditahan).
- `DASAR`: bakar 50/giliran, 3 giliran; rampas angin 0,15; gelembung 2; paralisis 2; pengali kalah duel 1,2;
  HP tanah +1 untuk 1 duel; biaya jebakan 1 bintang.
- `NODE` (id -> role, nilai per Lv1/Lv2/Lv3):

| Role | Node | Lv1 | Lv2 | Lv3 |
|---|---|---|---|---|
| api | hot_flames (bakar/giliran, 14.1) | 70 | 80 | 90 |
| api | fire_tax (bagian bakaran untuk pemasang) | 25% | 50% | 75% |
| api | long_burn | 4 giliran | 4 + korban tak bisa pasang jebakan | 5 + tak bisa pasang |
| api | ULT phoenix | jebakan aktif lagi sekali untuk korban berikutnya | | |
| air | rapid_current (mundur minimal) | 3 | 6 | 9 |
| air | high_tide | 50% +1 bintang | +1 bintang | +1 bintang +100 koin |
| air | frozen_bubble (K7) | kartu terkunci 1 giliran | 2 giliran | 2 giliran + LOW ROLL sekali |
| air | ULT tsunami | lawan lain <= 2 petak didorong mundur 2 | | |
| tanah | hard_rock | +1 HP bertahan 2 duel | 3 duel | 3 duel, duel pertama +2 HP |
| tanah | stone_thorns (pengali kalah duel) | 1,3 | 1,4 | 1,5 |
| tanah | fortress (serangan jarak jauh ditahan) | 1 | 2 | semua selama jebakan ada |
| tanah | ULT sacred_ground | sekali/pertandingan tanah gratis, bertahan sampai petak ganti pemilik | | |
| petir | shock (korban kehilangan koin) | 50 | 100 | 150 |
| petir | chain_lightning (LOW ROLL 1 giliran untuk lawan lain) | petak sama | jarak 1 | jarak 2 |
| petir | card_magnet (curi 1 kartu korban) | 25% | 50% | 75% |
| petir | ULT stealth_charge | tak terlihat lawan sampai terkena | | |
| angin | strong_wind (rampas, 14.1) | 12% | 14% | 16% |
| angin | homing_wind (bagian rampasan langsung ke pemasang) | 25% | 50% | 75% |
| angin | whirlwind (K8: langkah hilang) | 1 | 2 | 3 |
| angin | ULT tornado | pindah ke petak kosong acak, aktif sekali lagi | | |
| (tahan) | heat_skin vs api: bakaran | -25% | -50% | -50% + Guard |
| (tahan) | steady_feet vs air | gelembung 1 | + jatuh maks 6 petak dari jebakan | + Guard |
| (tahan) | heavy_pockets vs angin: rampasan | -25% | -50% | -50% + Guard |
| (tahan) | grounded vs petir (K13) | giliran berikut tidak terlewat | + boleh Fight saat lumpuh | + Guard |
| (tahan) | rock_breaker vs tanah (K14) | 50% bonus +1 HP tanah gagal | + tambahan denda kalah duel -50% | + Guard |

- `TAHAN_ROLE := {"tanah": ["grounded","heavy_pockets"], "petir": ["heat_skin","steady_feet"], "angin":
  ["grounded","steady_feet"], "api": ["rock_breaker","heavy_pockets"], "air": ["heat_skin","rock_breaker"]}`.
- `BIAYA_NODE := [1, 2, 3]`, `BIAYA_ULTIMATE := 4`, `BUKA_TINGKAT := [1, 5, 10]`, `BUKA_ULTIMATE := 15`,
  `LEVEL_ROLE_MAKS := 20`, `SP_ARENA := 12`.
- `SLOT_JEBAKAN_SOLO := [[10, 5], [6, 4], [3, 3], [1, 2]]` (Level Pemain minimal -> jumlah jenis),
  `SLOT_JEBAKAN_MP := 3`.
- `XP_ROLE := {"pasang": 10, "kena": 30, "tahan": 15, "duel_elemen": 20, "selesai": 50, "menang": 100}`,
  `XP_ROLE_LV2 := 100`, `XP_ROLE_TAMBAH := 50`; pengali mode sama dengan XP profil (Quick 1,0 / Classic 1,6).
- `PRESET` (B): per role, "attack"/"defense"/"balanced" = urutan pembelian node; fungsi
  `build_dari_preset(role, preset, sp, level_role)` membeli node menurut urutan itu sampai SP habis, hanya
  tingkat yang sudah terbuka. Dipakai AI, Arena preset, dan tombol preset di layar pohon.
- Fungsi static: `slot_jebakan_solo(level_pemain)`, `sp_dari_level(lv)`, `info_level_role(xp)`,
  `biaya_build(build)`, `build_sah(build, role, sp, level_role) -> bool`.

### 4b. data_pemain.gd (field baru per slot; kosong = tanpa role = perilaku lama)
- A: `role: String = ""`, `jebakan_dibawa: Array = []` (elemen, role selalu termasuk), `build: Dictionary = {}`
  (node_id -> level; langkah A = 2 node ketahanan Lv1).
- B: `guard_terpakai: Dictionary = {}`, `sacred_terpakai: bool`, `bakar_per_giliran: int = 50`,
  `bakar_pemilik: int = -1`, `bakar_larang_jebakan: bool`, `kunci_kartu: int = 0`, `low_roll_bubble: bool`.

### 4c. Profil (profil_pemain.gd, VERSI 2 -- berkas VERSI 1 dimuat dengan nilai bawaan, tanpa hilang data)
- A: `role_terakhir := ""`, `jebakan_role := {}` (role -> pilihan jebakan tambahan terakhir).
- B: `xp_role := {}` (role -> XP), `build_solo := {}` (role -> {node: lv}), `arena := {}` (role -> {"preset":
  "balanced"|"attack"|"defense"|"custom", "node": {...}}); `catat_akhir_match` menambah XP Role dari statistik
  slot lokal: stat baru `jebakan_role_pasang`, `jebakan_role_kena`, `tahan_kurangi`; menang duel dengan elemen
  role dihitung dari stat elemen yang sudah ada (`_tambah_stat_elemen`).

## 5. Langkah A -- role dasar

A1. data_role.gd, data_pemain.gd (field A), status_jaringan.gd (`role_slot: Array = []`, kosongkan di
    `reset_susunan`), profil VERSI 2 (field A).
A2. pemain_role.gd:
  - `_siapkan_role_semua()` dipanggil di `_siapkan_peta_dan_mulai` setelah slot tersusun & `mesin_acak`
    siap. Solo: slot 0 dari profil (`role_terakhir`, `jebakan_role`), jumlah jenis = `slot_jebakan_solo(Level
    Pemain)`; slot AI dari `AiJebakan.pilih_role_ai` (acak `mesin_acak`, utamakan role yang belum dipakai)
    dengan jumlah jenis sama. Multiplayer: dari `StatusJaringan.role_slot` (host sudah memvalidasi); slot
    yang diambil alih AI tetap memakai role-nya.
  - `_jebakan_boleh(slot, elemen) -> bool`, `_lv_node(slot, id) -> int`, `_tahan(slot, elemen) -> int`
    (level node ketahanan untuk elemen itu), `_kurangi_tahan(slot_korban, elemen, jumlah) -> int`
    (-25%/-50%, maks 50%, tambah stat `tahan_kurangi` bila berkurang, teks "HEAT SKIN! Burn reduced to 38").
  - `_boleh_pasang_jebakan_di(slot) -> bool`: syarat SAMA PERSIS dengan tombol Set Trap sekarang (bukan START,
    belum ada jebakan, tidak di gelembung, tidak lumpuh di fase akhir, bukan petak khusus di fase akhir,
    BUKAN fase "konfrontasi") + bintang >= 1 -- satu fungsi yang dipakai menu manusia, validasi host, dan AI.
    Semua yang dibaca (`fase_giliran`, `daftar_pemain`, `rute_papan`) ada di pemain_dasar.gd, jadi aman di
    pemain_role.gd.
  - `_boleh_tanah_di(slot) -> bool`: petak tempat berdiri milik slot itu (K3).
  - `_jarak_maju(dari, ke, maks) -> int` (BFS lewat `referensi_node_selanjutnya`, -1 kalau > maks) dan
    `_petak_mundur(dari, n) -> int` (peta pendahulu dibuat sekali setelah `rute_papan` terisi; kalau ada >1
    pendahulu pilih indeks terkecil). Dipakai AI (A) dan node gerak (B).
  - `_kemas_role() -> Dictionary` / `_terapkan_role(data)` untuk siaran state (bagian 7).
  - `_tanah_saat_duel: Dictionary` (variabel privat, dideklarasikan DI pemain_role.gd karena dibaca di sini):
    diisi `_mulai_duel` saat duel mulai (petak, pemilik jebakan, ada/tidak, Sacred), dibaca
    `_pengali_kalah_duel`, dikosongkan setelah hasil duel.
  - Fungsi di pemain_role.gd TIDAK memanggil apa pun dari file di atasnya: `_kurangi_tahan` hanya
    mengembalikan angka + mencatat stat; teks/siaran kerugian tetap dilakukan pemanggilnya.
A3. pemain_papan.gd: `extends "res://pemain_role.gd"`.
  - FUNGSI INTI BARU `_pasang_jebakan(slot, elemen) -> bool` (tanpa UI): cek `_boleh_pasang_jebakan_di`,
    `_jebakan_boleh`, tanah hanya petak sendiri (K3); kurangi bintang; buat node jebakan; stat
    `jebakan_pasang` (+ `jebakan_role_pasang` bila jenisnya = role); siarkan pemasangan untuk SEMUA jenis
    (sekarang hanya air, jenis lain tanpa teks di client) lewat `_siarkan_jebakan_dipasang`; kembalikan
    false kalau ditolak.
  - Kelima handler tombol tetap ada: `_teruskan_aksi_ke_host(...)` lalu `if not _pasang_jebakan(
    slot_giliran_ui, "air"): periksa_status_petak(slot_giliran_ui); return` lalu teks/jeda/menu seperti
    sekarang. Penolakan selalu memunculkan menu lagi (temuan 10). Fungsi `pass` kosong
    `_on_tombol_tanah_pressed`/`_on_tombol_petir_pressed` dibiarkan.
  - `_on_tombol_set_trap_pressed` hanya menampilkan tombol jenis yang dibawa (lainnya `hide()`), teks tanah
    "Earth Trap (1 Star, your tile)" dan mati kalau bukan petak sendiri.
A4. Ketahanan Lv1 (semua di host, hasilnya ikut state):
  - heat_skin: di `_mulai_giliran` potongan bakar `50` -> `_kurangi_tahan(slot, "api", 50)`. Angka 50 juga
    tertulis di: `_teks_terbakar` ("Lost 50", pemain_dasar.gd -- `_umumkan` perlu membawa angka kerugian),
    stat `50 * maxi(0, 3 - sisa_bakar)` di `bergerak_maju`, `rpc_teks_kerugian`, dan
    `jebakan_api.gd proses_penderitaan_giliran`; semuanya memakai angka hasil yang SAMA. Teks "Burning for 3
    turns" (pemain.gd & pemain_papan.gd `rpc_mainkan_efek_jebakan`) dan "Bubble for 2 turns" (jebakan_air.gd)
    memakai angka sebenarnya.
  - steady_feet: jebakan_air.gd `sisa_gelembung = 2` -> `node_utama._durasi_gelembung(slot_korban)` (2 atau 1).
  - heavy_pockets: di `bergerak_maju` `koin_hilang = int(uang * 0.15)` -> dikurangi ketahanan; yang disebar ke
    papan = angka hasil.
  - grounded: `periksa_status_petak` (tombol Fight tidak dikunci saat lumpuh bila punya grounded) dan
    ai_musuh.gd `logika_ai_musuh_setelah_jalan` (AI boleh duel saat lumpuh bila grounded).
  - rock_breaker: `_pengali_kalah_duel(slot_penyerang, posisi) -> float` di pemain_role (1,2; langkah B
    Stone Thorns; lalu rumus Rock Breaker di bagian 1 bila penyerang punya rock_breaker DAN `_tanah_saat_duel`
    mencatat jebakan tanah di petak itu). Dipakai `_hasil_duel_petak`, teks "Fight (Risk: ...)" (sebelum duel:
    pakai jebakan tanah yang terlihat di petak), dan perkiraan risiko AI (ai_musuh.gd baris `denda * 1.2`).
A5. AI: `AiJebakan.pertimbangkan(main_node, slot)` dipanggil di `logika_ai_musuh_setelah_jalan` tepat sebelum
    `_siarkan_state_ai` terakhir (setelah beli/bangun) -- bagian 6. AI memasang lewat `_pasang_jebakan(slot,
    elemen)`, BUKAN handler tombol. Kartu AI (`logika_ai_fase_awal`) tidak dipakai saat melayang (K7).
A5b. K12: di `_mulai_giliran`, giliran lumpuh yang dilewati tidak lagi menjalankan konfrontasi di petak lawan
    (manusia: `periksa_status_petak` cabang konfrontasi; AI: `logika_ai_musuh_setelah_jalan`) -- korban hanya
    mengakhiri giliran. Mengambil kartu/permata setelah lumpuh tetap seperti sekarang.
A6. UI:
  - ui_role.gd `buka_pilih_role(induk, konteks, selesai: Callable)`: judul "CHOOSE YOUR ROLE", 5 tombol role
    berwarna elemen, keterangan role terpilih ("FIRE - Your trap: Fire Trap. Tough against: Earth and Wind
    traps."), baris "TRAPS YOU BRING 2/3" berisi 4 jenis lain (sentuh untuk pilih; jebakan role selalu
    ikut & terkunci; "Level 3: bring 3 traps" sebagai petunjuk berikutnya), tombol START (solo) / OK (lobby).
    Tata letak diuji di 1280x720 & 1600x720.
  - main_menu.gd: tombol peta memanggil layar ROLE; START di layar ROLE yang memancarkan `mulai_game`
    (tanda tangan sinyal TIDAK berubah; role dibaca dari profil). Pilihan disimpan ke profil.
  - layar_local_play.gd: kolom kanan dapat tombol "MY ROLE: FIRE" di bawah PLAYERS; tiap baris pemain
    menampilkan role-nya ("P2  PLAYER (YOU)  FIRE"); client mengirim `rpc_id(1, "rpc_role_lobby", role,
    jebakan)` setiap kali memilih; host menyimpan per peer, mengundi role AI (K9) saat mode dipilih, dan
    menyiarkan ulang lewat `rpc_info_lobby` (parameter baru: daftar role per slot). START mati dengan info
    "Waiting for players to choose a role..." sampai semua manusia punya role. Saat START, host membuat
    `data_role` per slot (role, jebakan, build), MEMVALIDASI (role sah, jebakan 3 jenis unik termasuk role;
    kalau tidak sah -> jebakan diganti pilihan bawaan), lalu mengirimnya di `rpc_mulai_dari_lobby`.
  - HUD (ui_dinamis.gd / pemain_tampilan.gd): nama role berwarna di samping nama tiap pemain (2 pemain & HUD
    3-4 pemain), supaya ketahanan lawan terlihat. pemain_tampilan.gd ada DI BAWAH pemain_role.gd, jadi nama &
    warna diambil dari `DataRole` (static) + `daftar_pemain[s].role`, bukan dari fungsi pemain_role.
  - Role AI di lobby (K9) diundi dengan pengacak milik layar lobby (bukan `mesin_acak`, yang belum ada di
    sana); jebakan AI dipilih host saat START dengan `DataRole.jebakan_bawaan_ai(role, role_lawan)` (tanpa
    acak: jenis yang paling sedikit ditahan lawan, seri -> urutan ROLE), lalu ikut divalidasi seperti slot lain.
A7. Rig (bagian 9).

## 6. Otak jebakan AI (ai_jebakan.gd)

- `pilih_role_ai(main_node, slot)` (solo): acak dengan `mesin_acak`, utamakan role yang belum dipakai slot
  lain. Rig keseimbangan tidak memakai undian ini (role diberikan lewat argumen, bagian 9).
- Jebakan AI = `DataRole.jebakan_bawaan_ai(role, role_lawan, jumlah)`: role + jenis tambahan yang PALING
  SEDIKIT ditahan role lawan (seri -> urutan ROLE). Tanpa acak, jadi sama di solo & lobby.
- `pertimbangkan(main_node, slot)` di akhir giliran AI (petak tempat ia berhenti):
  1. Syarat: `_boleh_pasang_jebakan_di(slot)`, bintang >= 1, dan sisakan bintang untuk serangan jarak jauh:
     pasang hanya kalau bintang >= 6, atau bintang >= 2 dan tidak ada petak lawan bermenara Lv2.
  2. Untuk tiap lawan: `j = _jarak_maju(posisi_lawan, petak_ini, 12)`; peluang lewat = peluang lemparan
     lawan >= j (dadu 1-6: (7-j)/6; dadu 2-12 / Quick: hitung dari dua dadu; LOW/HIGH ROLL sesuai kartunya);
     jebakan air & petir menghentikan korban, jadi untuk keduanya dipakai peluang lemparan >= j juga (cukup
     lewat). Lawan dengan `sisa_gelembung >= 2` dilewati (masih melayang di giliran berikutnya).
  3. Nilai per jenis yang dibawa (x peluang, dikali 0,6 kalau lawan itu menahan jenis tersebut):
     api = bakar x giliran; angin = persen rampas x uang lawan; petir = denda petak ini kalau petak milik AI
     (korban berhenti di petaknya & tidak bisa Fight) atau 100; air = 80; tanah (hanya petak sendiri,
     tidak perlu lawan lewat) = denda petak x 0,5. Jenis = role x 1,2.
  4. Pasang jenis bernilai tertinggi kalau nilai >= 80 dan `mesin_acak` 1-100 <= 70, lewat fungsi inti
     `_pasang_jebakan(slot, elemen)` yang sama dengan manusia (bukan handler tombol), jadi siaran, statistik &
     teks sama. Teks untuk semua layar: "<nama> set a Fire Trap!".
- Angka di atas = angka awal; disetel di uji keseimbangan (target: AI memasang 2-6 jebakan per Quick 2 pemain).
- Langkah B: serangan jarak jauh AI melewati petak yang dilindungi Fortress (`_benteng_aktif(petak)`, cek tanpa
  memakai hitungannya) dan memilih target lain / tidak menyerang.
- AI mengikuti aturan manusia: di fase akhir, Buy dan Build langsung mengakhiri giliran manusia, jadi AI
  yang baru membeli/membangun di giliran itu TIDAK memasang jebakan. Pilihannya: beli/bangun ATAU pasang
  jebakan -- AI memasang jebakan hanya kalau ia memutuskan tidak membeli/membangun di petak itu.

## 7. Jaringan & migrasi

- Awal pertandingan: semua HP menerima `data_role` semua slot (lobby) -> `StatusJaringan.role_slot` ->
  disalin ke `DataPemain` di `_siapkan_role_semua`. SESUDAH itu `DataPemain` satu-satunya sumber:
  `reset_susunan` (lewat `keluar_dari_sesi`) bisa berjalan DI TENGAH pertandingan (host keluar, lanjut
  sendiri) dan mengosongkan `role_slot` + `peran_multiplayer`; jumlah jenis jebakan tidak pernah dihitung
  ulang dari mode setelah pertandingan mulai.
- Perubahan tanda tangan `rpc_info_lobby` / `rpc_mulai_dari_lobby` ikut diubah di robot rig
  (uji_robot_mp.gd) supaya regresi multiplayer tetap jalan.
- `_siarkan_state_giliran`: tambah `"role": _kemas_role()` (per slot: role, jebakan_dibawa, build, dan field
  B). `rpc_terima_state_giliran` memanggil `_terapkan_role`. Host baru (migrasi) & "lanjut sendiri" memakai
  state terakhir ini -- tidak ada jalur khusus.
- Data jebakan `[petak, nama, pemilik]` -> `[petak, nama, pemilik, info]`; `info` Dictionary (B: `sisa_duel`,
  `sacred`, `aktif_ulang`, `siluman`, `sisa_tahan_serangan`). `_terapkan_data_jebakan` memperbarui info juga
  pada jebakan yang sudah ada, termasuk memunculkan lagi & `aktif = true` jebakan tanah yang masih ada di
  host tapi tersembunyi di client (sekarang tidak pernah dimunculkan lagi -> salah setelah migrasi). Elemen
  ke-4 boleh tidak ada (baca dengan aman).
- Jalur tayangan client yang sekarang menghapus jebakan sendiri (`rpc_mainkan_efek_jebakan`, replay air,
  `rpc_jebakan_tanah_aktif` -> `_pantau_duel_berlangsung`) harus mengikuti keputusan host: jebakan Phoenix /
  Hard Rock / Sacred Ground / Tornado TIDAK dihapus di client; host mengirim flag "jebakan tetap" di perintah
  efeknya.
- Semua undian efek role (High Tide, Card Magnet, Rock Breaker Lv2, Tornado, petak jatuh) di HOST dengan
  `mesin_acak`, hasilnya dikirim bersama perintah efek (pola `rpc_jebakan_air_aktif` yang mengirim petak jatuh).
- RPC baru hanya untuk tayangan: `rpc_efek_role(jenis: String, data: Dictionary)` satu pintu (Guard, Tsunami,
  Tornado, Chain Lightning, Card Magnet, Phoenix) supaya jumlah RPC tidak membengkak.
- Validasi di host untuk semua permintaan client (jenis dibawa, tanah petak sendiri, build Arena sah).

## 8. Langkah B -- pohon penuh

B1. Profil: XP Role, level, build solo, Arena build (4c). Kartu hadiah akhir pertandingan: baris
    "FIRE ROLE +180 XP (Lv 4)" + batang; DOUBLE ikut menggandakan (K10).
B2. Layar pohon (ui_role.gd), dibuka dari tombol ROLES di menu utama: tab 5 role, Level Role + batang XP,
    SP tersisa, pohon: 3 node jebakan (3 tingkat), 2 node ketahanan, Ultimate (terkunci sampai Lv15, tertulis
    "Unlocks at Role Lv 15"), sentuh node = beli tingkat berikutnya (konfirmasi), RESET (gratis), tab ARENA:
    12 SP semua tingkat terbuka + tombol ATTACK / DEFENSE / BALANCED / CUSTOM. Teks node bahasa Inggris
    sederhana dari data_role.gd.
B3. Solo: build pemain = `build_solo[role]` (disaring `build_sah`); AI = preset Balanced dengan level role
    pemain (K1). Multiplayer: build = Arena build pemain (dikirim di lobby bersama role; host memvalidasi
    <= 12 SP).
B4. Efek node (di host; semua angka dari data_role.gd; titik kait):
  - hot_flames / long_burn / fire_tax: saat kena api di `bergerak_maju` set `bakar_per_giliran`,
    `sisa_bakar`, `bakar_pemilik`, `bakar_larang_jebakan` dari build PEMASANG; di `_mulai_giliran` bakaran =
    `_kurangi_tahan(korban, "api", bakar_per_giliran)`, bagian fire_tax ke pemilik. Larangan pasang jebakan
    masuk `_boleh_pasang_jebakan_di`.
  - phoenix: jebakan tidak dihapus setelah korban pertama; `info.aktif_ulang` 1 -> 0.
  - rapid_current / steady_feet Lv2: `pilih_petak_jatuh` memanggil `main_node._kandidat_petak_jatuh(korban,
    petak_jebakan, pemasang)`: kandidat = petak dengan jarak ke START >= jarak korban + N; lalu steady_feet
    Lv2 menyaring <= 6 petak dari jebakan (ketahanan menang kalau bertentangan); kosong -> petak sah terjauh.
  - high_tide: bintang/koin pemasang saat kena. frozen_bubble (K7): `kunci_kartu` & `low_roll_bubble` diatur saat
    kena, dihitung mundur saat gelembung pecah; tombol Use Card (pemain.gd `periksa_status_petak`), validasi
    host (pemain_kartu.gd, permintaan pakai kartu) & kartu AI memeriksa `kunci_kartu`; LOW ROLL Lv3 dipasang
    lewat `tipe_dadu_slot` durasi 2 saat gelembung pecah.
  - tsunami: lawan lain dalam `_jarak_maju` <= 2 dari petak jebakan (dua arah) -> `_petak_mundur(pos, 2)`,
    animasi geser 0,6 dtk tanpa memicu apa pun.
  - Siklus jebakan tanah (temuan 9): `_mulai_duel` mengisi `_tanah_saat_duel`; `_pantau_duel_berlangsung`
    HANYA menarik buff HP (seperti sekarang) dan tidak lagi `queue_free`; fungsi baru
    `_selesaikan_tanah_setelah_duel(petak)` dipanggil di `_hasil_duel_petak` SESUDAH pemilik petak ditentukan
    (semua cabang: penyerang menang/kalah, di host; client lewat state/perintah efek): petak berganti pemilik
    -> jebakan dihapus; masih milik pemasang -> hitungan `sisa_duel` dikurangi (Sacred: tidak), kalau masih
    ada: `aktif = true` & tampil lagi, kalau habis: dihapus. Tanpa node Hard Rock/Sacred hasilnya sama dengan
    sekarang (hilang setelah 1 duel).
  - hard_rock: `sisa_duel` 2/3/3; Lv3 duel pertama +2 HP.
  - stone_thorns & rock_breaker: `_pengali_kalah_duel` (A4; K14: Rock Breaker memotong tambahan mulai Lv2)
    + Rock Breaker Lv1+ undi 50% (`mesin_acak`, host) "bonus tanah gagal" sebelum `aktifkan_pelindung_sementara`.
  - grounded (K13): Lv1 = `sisa_paralisis` korban dipasang 1 (bukan 2) -> tetap berhenti, giliran berikut tidak
    terlewat; Lv2 = + boleh Fight saat lumpuh (perilaku Lv1 Langkah A pindah ke sini).
  - fortress: `_benteng_menahan(petak) -> bool` dipanggil di `eksekusi_serangan` DAN serangan AI di ai_musuh.gd
    sebelum `nyawa_petak -= 1`; bintang penyerang tetap terpakai; teks "FORTRESS! The attack was blocked."
    Tombol Attack manusia menandai petak ber-Fortress (teks "Protected") supaya tidak tertipu. Jebakan Sacred
    Ground memakai Fortress paling tinggi Lv2 (bagian 1).
  - sacred_ground: jebakan tanah pertama pemain role Tanah yang punya Ultimate = gratis (tombol "Sacred Earth
    Trap (FREE)"), `info.sacred = true`, tidak habis oleh duel, hilang saat petak berganti pemilik
    (`reset_petak_ke_netral` & rebutan petak).
  - shock: korban kehilangan koin saat kena (koinnya hilang, tidak ke pemasang; grounded tidak mengurangi
    shock -- grounded hanya soal lumpuh).
  - chain_lightning: `tipe_dadu_slot = "rendah"` durasi 2 (= lemparan berikutnya, lihat bagian 1) untuk lawan
    lain dalam jarak. card_magnet: undi, pindahkan 1 kartu acak korban ke pemasang; kalau kartu pemasang
    sudah penuh, pencurian dilewati (tidak membuka layar buang kartu).
  - stealth_charge: jebakan petir milik pemain dengan Ultimate `info.siluman = true`; di HP yang bukan milik
    pemasang, visualnya disembunyikan. Tombol Set Trap di petak itu tetap mati (kebocoran kecil, diterima).
    AI tidak "melihat" jebakan siluman lawan (AI memang tidak menghindari jebakan).
  - strong_wind / homing_wind / heavy_pockets: rampasan = uang x persen(pemasang) lalu ketahanan korban;
    bagian homing langsung ke pemasang, sisanya disebar seperti sekarang. whirlwind (K8): `sisa_langkah -= n`.
  - tornado: setelah kena, jebakan pindah ke petak kosong acak (sah untuk jebakan) & aktif sekali lagi.
  - Guard (Lv3 ketahanan): diperiksa PERTAMA di setiap titik picu; kalau dipakai -> jebakan hilang, korban tidak
    terkena, teks "GUARD! <node> blocked the <trap>!", `guard_terpakai[elemen] = true`.
B5. Tayangan baru (Phoenix menyala lagi, Tsunami, Tornado, Chain Lightning, Card Magnet, Guard, tanda Sacred):
    maks 1,5 dtk; versi Very Low = teks + tween sederhana tanpa partikel/cahaya; dibuat sekali lalu dipakai
    ulang (tidak ada node yang dibuat tiap frame).

## 9. Uji (rig)

Langkah A:
- U1. cek_nama_ganda (8 file) + 0 warning di semua file yang dikirim + `DataRole.TAHAN` == `DATA_ELEMEN`.
  Set kiriman langkah A = 22 file Fase 3 + 4 file baru = 26. Langkah B juga mengubah jebakan_tanah.gd,
  jebakan_angin.gd, jebakan_petir.gd (belum ada di set) -> 29 file.
- U2. Simulasi (uji_sim.gd, benih 7-12, 2-4 pemain) & adegan asli (uji_nyata.gd, Quick/Classic, 2 peta):
  0 script error, STAT_CEK OK, AI benar-benar memasang jebakan. Jejak TIDAK dibandingkan dengan versi lama
  (perilaku memang berubah).
- U2 juga: uji_sim.gd tidak memanggil `_siapkan_peta_dan_mulai`, jadi rig memasang role & peta pendahulu
  sendiri; robot uji_sim.gd & uji_robot_mp.gd hanya menekan tombol jebakan yang TERLIHAT (sekarang mereka
  menekan tombol tersembunyi secara bergiliran).
- U3. Keseimbangan. Perubahan rig dulu (uji_nyata.gd, bukan file produksi):
  - `semua_ai=1` (sekarang `n_manusia = 1` tertulis mati), `role=api,air,...` per slot, `jebakan=` opsional.
  - Role & jebakan dari argumen rig dipasang langsung ke `DataPemain` (bukan diundi), jadi tidak bergantung
    pada `mesin_acak` yang baru diberi benih sesudah START. Layar ROLE dilewati rig dengan menulis
    `role_terakhir` ke profil sementara (HOME baru tiap run) sebelum menu, atau argumen `role0=`.
  - Classic di rig sering berhenti di batas giliran tanpa pemenang -> pemenang batas giliran = terkaya
    (`_pemenang_kekayaan`, sudah ada untuk Quick).
  - Skrip `f4/uji_seimbang.sh` menulis satu baris per pertandingan (benih, peta, role per kursi, pemenang,
    giliran, jebakan dipasang per slot, detik) dan melewati benih yang sudah ada hasilnya (bisa dilanjutkan);
    `f4/ringkas_seimbang.py` menghitung persentase menang per role & per pasangan + rentang keyakinan 95%.
  - Uji coba 20 pertandingan dulu untuk mengukur detik per pertandingan, lalu jumlah di bawah disesuaikan.
  Jumlah (Quick, 2 peta):
  - 2 pemain: 10 pasangan role x 120 pertandingan (60 benih x 2 kursi, dibagi rata 2 peta) = 1.200 -> tiap
    role ~480 pertandingan (rentang keyakinan ~+-4,5%); pasangan dinilai "> 65%" kalau batas bawah rentang
    keyakinannya > 55%.
  - 4 pemain: 400 pertandingan role acak (tiap role ~320 penampilan).
  - 2 pemain Classic: 100 pertandingan (cek arah saja).
  - Syarat K11 + AI memasang 2-6 jebakan per Quick 2 pemain + panjang Quick naik <= 15% dibanding sebelum Fase 4.
    Patokan SUDAH DIUKUR 25-09 (240 pertandingan, rig `uji_nyata.gd` tanpa modifikasi, kode pasca-Fase-3):
    ukuran yang dipakai = rata-rata DETIK dalam-permainan (bukan giliran, karena giliran punya batas atas
    tetap dari `batas_ronde x pemain` yang tidak berubah di Fase 4). 2 pemain: 276,6 dtk -> batas 318,1 dtk;
    3 pemain: 348,2 dtk -> batas 400,4 dtk; 4 pemain: 403,3 dtk -> batas 463,8 dtk. Detail & data mentah di
    `PATOKAN_panjang_quick_sebelum_fase4.md`. U3 mengukur ulang dengan cara sama (2/3/4 pemain, peta sama,
    `panjang=quick`) lalu bandingkan rata-ratanya ke batas ini.
  - Dijalankan per potongan <= 1 jam SELAMA Claude bekerja (temuan 13), 2 proses paralel (rig punya 2 CPU).
- U4. Multiplayer: regresi 37 skenario (uji_f2_t2_a/b.sh, robot memilih role di lobby) + skenario baru:
  role berbeda tiap HP, client ganti role 2x sebelum START, host ganti mode setelah client memilih, client
  keluar & AI mengambil alih (role tetap), migrasi host (role & ketahanan tetap). Syarat: 0 macet, 0 error,
  baris AKHIR sama di semua HP, cetakan ROLE tiap slot sama di semua HP.
- U5. Profil: berkas VERSI 1 dimuat -> semua data lama utuh + role kosong -> layar ROLE minta memilih.
- U6. Iklan tiruan editor (FREE CARD, DOUBLE/EXIT) tetap lolos.
- U7. Foto layar ROLE (solo & lobby) di 1280x720 & 1600x720.

Langkah B: U1-U7 lagi, ditambah:
- U8. Tiap node diuji sendiri di skenario pendek (rig memasang jebakan & build tertentu) -> angka sesuai tabel
  (mis. api Hot Flames Lv3 vs Heat Skin Lv2 = bakar 40).
- U9. Keseimbangan dengan build: tiap role x preset Attack/Defense/Balanced (Arena 12 SP) melawan semua role
  -> syarat K11; plus solo Level Role 1/10/20 (pemain robot vs AI cermin) masuk akal.
- U10. Build tersinkron: cetakan build semua slot sama di semua HP; build tidak sah dari client ditolak host.
- U11. FPS: tayangan baru versi Very Low tidak membuat node baru tiap frame (dicek di rig) + uji HP.

## 10. Yang user uji di HP

Langkah A: solo Quick & Classic dengan 2 role berbeda (jenis jebakan di menu sesuai, pesan ketahanan muncul,
AI memasang jebakan & terasa masuk akal); layar ROLE nyaman di layar HP; multiplayer HP + laptop: pilih role
di lobby, role lawan terlihat, jebakan & ketahanan sama di kedua layar, satu device keluar -> AI melanjutkan
dengan role yang sama; FPS terasa sama.
Langkah B: naik Level Role setelah beberapa pertandingan, beli node, RESET, preset Arena di lobby, tiap
Ultimate minimal sekali terlihat, FPS saat Phoenix/Tsunami/Tornado di Very Low.

## 11. Urutan kerja & arahan model

1. User menyetujui K6-K12 (atau mengubahnya) -> rencana dikunci.
2. Fase 3: selesaikan uji rig, kirim set, user uji HP.
3. Langkah A: Sonnet menulis kode A1-A6 (edit hanya bagian relevan) -> rig U1, U2, U4-U7 (Sonnet) -> U3
   keseimbangan & penyetelan angka (Opus) -> kirim set A (26 file + rencana) -> uji HP user.
4. Langkah B: Opus meninjau ulang bagian 8 dengan hasil uji A (kalau perlu revisi kecil) -> Sonnet menulis ->
   rig -> Opus menyetel keseimbangan -> kirim set B -> uji HP -> rilis A+B.
Pindah ke Opus kalau: AI bertingkah aneh/berulang, keseimbangan tidak mau masuk target, hasil beda antar-HP,
atau ada efek node yang tabelnya ternyata tidak cocok dengan kode.
Perkiraan kasar: langkah A 1-2 sesi kerja + rig 3-4 jam; langkah B 2-3 sesi + rig 4-5 jam.

## 12. Sengaja tidak dikerjakan di Fase 4

Skin jebakan per role, kostum, aura, emblem (Fase 7); bintang Prestige role (nanti); tampilan role di kartu
profil lobby (Fase 6); pilihan kesulitan AI (Fase 8, Duel Road); AI menghindari jebakan lawan saat memilih
cabang; mengganti role di tengah pertandingan.

## 13. Hasil Langkah A di rig (25-09) -- U1-U7 + U3

### 13.1 Bug yang ditemukan saat U3 (sudah diperbaiki)
- `_siapkan_role_semua()` TIDAK PERNAH dipanggil di kode produksi (hanya didefinisikan). Akibatnya di game
  sungguhan semua pemain tanpa role, AI tidak pernah memasang jebakan, ketahanan mati, HUD tanpa role.
  U1-U7 tidak menangkapnya karena rig uji_sim.gd memanggil fungsi itu sendiri, dan pembanding role di robot
  multiplayer membandingkan "" dengan "". Perbaikan (hanya baris relevan):
  - pemain.gd `_siapkan_peta_dan_mulai`: panggil `_siapkan_role_semua()` setelah slot tersusun.
  - pemain_role.gd `_siapkan_role_semua`: client juga menyalin dari `StatusJaringan.role_slot` (datanya
    lengkap & sah dari host, tanpa undian cadangan -> sama di semua HP). Komentar lama menunjuk
    `_terapkan_data_role_lobby` yang tidak pernah ada.
  - pemain_jaringan.gd: siaran state memuat `"role": _kemas_role()`, `rpc_terima_state_giliran` memanggil
    `_terapkan_role` (bagian 7 -- sebelumnya tidak tersambung).
- AI hanya menimbang jebakan di AKHIR giliran, padahal di Quick 2 pemain AI hampir selalu membeli/membangun
  di sana (55/55 kali di uji debug) -> praktis 0 jebakan. Manusia boleh Set Trap di AWAL giliran (petak tempat
  berdiri, sebelum dadu); AI disamakan: `AiJebakan.pertimbangkan` juga dipanggil di `logika_ai_fase_awal`.

### 13.2 Angka & logika AI yang diubah U3 (K11: tanpa persetujuan per perubahan)
data_role.gd (aturan -- berlaku untuk manusia juga):
- `bakar_per_giliran` 50 -> 60 (jebakan api terlalu lemah dibanding angin/petir).
- `rampas_angin` 0,15 -> 0,10 (jebakan angin paling kuat).
- `jebakan_bawaan_ai`: pemecah seri jenis tambahan = `URUTAN_BAWAAN_AI` (angin, petir, air, api, tanah),
  dulu urutan ROLE -> AI selalu membawa api/tanah yang lemah dan angin terakhir (Air kalah 70% dari Angin).
- `BOBOT_TAHAN_AI` (baru): seberapa kuat node ketahanan Lv1 sungguh mengurangi jebakan (api 0,25, angin 0,25,
  air 0,5, petir 0,1, tanah 0,05). Dulu semua dianggap sama; Grounded (hanya membuka Fight saat lumpuh) dan
  Rock Breaker (hanya memotong tambahan x1,2) membuat AI tidak pernah membawa petir/tanah melawan
  pemiliknya -> Tanah & Angin (keduanya punya Grounded) otomatis bebas dari jebakan terkuat (~57%).
ai_jebakan.gd (otak AI saja):
- `AMBANG_NILAI` 80 -> 50, `AMBANG_PELUANG` 70 -> 80 (80 = 1,3 jebakan/AI/Quick 2P).
- petir: `NILAI_PETIR_LUMPUH` 150 (dulu 100 tetap) + denda petak kalau di petak sendiri.
- air: `NILAI_GELEMBUNG_PER_GILIRAN` 75 x durasi gelembung korban (dulu 80 tetap -> role Air TIDAK PERNAH
  memasang jebakannya sendiri, 0,00/pertandingan di 480 pertandingan).
- potongan nilai untuk lawan yang menahan = `1 - BOBOT_TAHAN_AI[jenis]` (dulu x0,6 rata; air lewat durasi).
- `FAKTOR_NILAI_TANAH` 0,5 (angka sama, jadi konstanta).
ai_musuh.gd: peluang AI memilih Fight dibagi dua kalau petaknya ada jebakan tanah lawan (dulu AI tidak
  melihatnya sama sekali; Lv2 100% -> 50%, Lv1 55 -> 27, Lv0 50 -> 25).
Dicoba lalu DIBATALKAN (tidak memperbaiki / memperburuk): `gelembung` 2 -> 3, `rampas_angin` 0,08,
`bakar_per_giliran` 70, `FAKTOR_NILAI_TANAH` 0,4 (jebakan AI turun ke 1,56).

### 13.3 Hasil akhir U3 (rig uji_nyata.gd, adegan & peta asli, semua slot AI kecuali uji panjang)
Alat: `f4/uji_seimbang.sh` (satu baris per pertandingan, bisa dilanjutkan), `f4/ringkas_seimbang.py`
(persen menang + CI95 Wilson, per pasangan, jebakan per AI, detik). Rig: `semua_ai=1`, `role=a,b,..`,
`jenis=N`, pemenang batas giliran = terkaya. 0 script error, 0 macet di SEMUA pertandingan U3.

Quick 2 pemain (10 pasangan x 60 benih x 2 kursi, 2 peta), syarat 44-56% & tak ada pasangan batas bawah > 55%:

| Role  | Awal (sebelum U3) | Akhir, benih penyetelan (1.200) | Akhir, benih BARU (1.200) | Gabungan 2.400 |
|-------|------|------|------|------|
| air   | 43,8 | 46,5 | 47,1 | 46,8 |
| angin | 53,8 | 54,0 | 55,4 | 54,7 |
| api   | 51,5 | 47,1 | 43,5 | 45,3 |
| petir | 43,8 | 46,9 | 48,3 | 47,6 |
| tanah | 57,3 | 55,6 | 55,6 | 55,6 |
Pasangan terburuk awal: angin vs air 70%, tanah vs petir 65% (ditandai). Akhir: tidak ada yang ditandai
(terbesar tanah vs api 61,3% gabungan, batas bawah CI 54,9%). Derau per role per 1.200 pertandingan kira-kira
+-2,3 poin (lihat api 47,1 vs 43,5 di dua set benih) -- menyetel lebih jauh hanya mengejar derau.
Jebakan AI per pertandingan Quick 2P: awal 0 (bug 13.1), akhir rata-rata 2,15-2,18 per AI (median 2;
~4,3 per pertandingan untuk kedua AI).

Quick 4 pemain (400, role acak): air 23,1 / angin 29,0 / api 24,9 / petir 24,8 / tanah 23,3 %.
CATATAN K11: "15-25% per penampilan" tidak mungkin dipenuhi semua role sekaligus (rata-rata di 4 pemain PASTI
25%). Ditafsirkan +-5 di sekitar 25% (20-30%, sejalan dengan 44-56 di 2 pemain) -> lolos. Mohon dikoreksi
kalau maksudnya lain.
Classic 2 pemain (100, cek arah saja): urutan sama dengan Quick (angin 62,5 / tanah 60 / api 52,5 / petir 40 /
air 35, n=40 per role -> CI +-15). Classic di rig panjang (78/100 berhenti di batas 200 giliran), AI memasang
~14 jebakan/pertandingan.

Panjang Quick (cara SAMA dengan patokan: robot di slot 0, role dari layar ROLE, AI role undian, 240 pertandingan):
2P 266,9 dtk (patokan 276,6, batas 318,1) / 3P 309,8 (348,2, batas 400,4) / 4P 380,4 (403,3, batas 463,8)
-> semua LEBIH PENDEK dari sebelum Fase 4, jauh di bawah batas +15%.

### 13.4 U1/U2/U4 diulang sesudah perbaikan 13.1-13.2
- U1: cek_nama_ganda LOLOS (290 fungsi), TAHAN == DATA_ELEMEN, 26 file dimuat, 0 peringatan di file produksi.
- U2: uji_sim 2-4 pemain benih 7-12 (18) + uji_nyata solo Quick/Classic x 2 peta: 0 error, STAT_CEK OK,
  role terpasang di jalur solo sungguhan (layar ROLE -> profil -> `_siapkan_role_solo`).
- U4: 9 skenario (1v1, 3P+1AI, 4P, 4P dadu asli, client keluar -> AI ambil alih, 2 migrasi host, ganti role
  2x, host ganti mode sesudah role dipilih): 0 error, 0 beda, baris SELESAI kini mencetak role+jebakan tiap
  slot dan SAMA di semua HP, tidak kosong, tetap sesudah migrasi. (U4 sebelum 13.1 membandingkan role
  kosong -- hasilnya tidak berarti untuk role.)
- U5-U7 tidak terpengaruh perubahan ini (profil, iklan, layar ROLE tidak diubah).
- Catatan lobby: AI di lobby multiplayer membawa jebakan bawaan tanpa melihat lawan (`_jebakan_sah_lobby`
  memanggil `jebakan_bawaan_ai(role, [])`) -- sesuai A6, dicatat saja.

### 13.5 Arahan model
Langkah A siap uji HP. Langkah B dimulai dengan Opus (meninjau bagian 8 dengan temuan 13.1-13.2, terutama:
Grounded Lv1 hampir tidak mengurangi jebakan petir, Rock Breaker Lv1 hanya memotong x1,2 -> tabel node B
untuk keduanya perlu ditinjau), lalu Sonnet menulis kode dari rencana yang sudah dikunci.

## 14. Tinjauan Opus sebelum Langkah B (26-09)

### 14.1 Angka node yang bentrok dengan hasil U3 (Opus menyetel, tanpa persetujuan -- K11)
- Dasar api sekarang 60/giliran -> `hot_flames` Lv1 60 TIDAK BERPENGARUH. Baru: 70 / 80 / 90.
- Dasar angin sekarang 10% -> `strong_wind` 18/21/25% terlalu melompat (dasar 10 -> Lv1 18). Baru: 12% / 14% / 16%.
- `homing_wind` tetap 25/50/75% (bagian dari rampasan yang sudah kecil). `shock` tetap 50/100/150.
- `bakar_per_giliran` bawaan di data_pemain.gd (4b) = `DataRole.DASAR["bakar_per_giliran"]`, BUKAN angka 50 tertulis.

### 14.2 Otak AI harus ikut membaca build (tidak ada di bagian 6/8 -- WAJIB ditambahkan)
Hasil U3: keseimbangan AI-vs-AI sangat bergantung pada nilai jebakan di ai_jebakan.gd. Kalau node B tidak
masuk ke nilai itu, AI tidak akan memakai node-nya dan uji U9 tidak berarti.
- `pertimbangkan`: nilai per jenis memakai angka PEMASANG (hot_flames x long_burn, strong_wind, shock ditambah
  ke petir, homing/fire_tax x1 tambahan, dst.) lewat fungsi baru di pemain_role.gd, mis.
  `_angka_jebakan(slot_pemasang, elemen) -> Dictionary` -- SATU sumber yang dipakai efek (B4) DAN AI.
- Potongan ketahanan korban memakai LEVEL node korban: `BOBOT_TAHAN_AI` jadi per level (Lv1 seperti sekarang,
  Lv2 dua kali lipat, maks 0,5; Guard yang belum terpakai = nilai jenis itu 0 untuk korban tsb).
- `jebakan_bawaan_ai`: bobot ketahanan lawan ikut level node lawan (lawan multiplayer diketahui dari
  role_slot + build yang dikirim di lobby).
- Keputusan Fight AI membaca stone_thorns/hard_rock pemilik petak (risiko) seperti jebakan tanah sekarang.

### 14.3 K13-K15 -- DISETUJUI user 26-09 (semua usulan)
- K13. Grounded (tahan petir) Lv1 nyaris tidak berefek: hanya membuka Fight saat lumpuh, padahal efek petir
  = berhenti + LEWAT 1 GILIRAN. Di U3 ini membuat AI salah menilai. Usulan: tukar urutan -- Lv1 = giliran
  berikut TIDAK terlewat (tetap berhenti di petak jebakan, tetap tidak bisa Fight saat mendarat), Lv2 = + boleh
  Fight saat lumpuh, Lv3 = + Guard. Setara Steady Feet Lv1 (gelembung 2 -> 1).
- K14. Rock Breaker (tahan tanah) Lv1 hanya memotong TAMBAHAN x1,2 menjadi x1,15 -- hampir nol, sementara efek
  utama jebakan tanah (+1 HP petak di duel) tidak disentuh. Usulan: Lv1 = 50% bonus +1 HP tanah gagal
  (dulu di Lv2), Lv2 = + tambahan denda kalah duel -50% (x1,2 -> x1,1; Stone Thorns x1,5 -> x1,25), Lv3 = + Guard.
- K15. Syarat 4 pemain K11 "15-25%" diganti 20-30% (rata-rata 4 pemain pasti 25%; lihat 13.3).

### 14.4 PRESET (diisi Opus, bagian 4a) -- urutan "beli 1 tingkat berikutnya"
Aturan `build_dari_preset(role, preset, sp, level_role)`: jalani daftar dari awal; tiap entri = naikkan node
itu 1 tingkat KALAU tingkatnya sudah terbuka (BUKA_TINGKAT/BUKA_ULTIMATE, Arena: semua terbuka) DAN SP cukup;
kalau tidak, LEWATI entri itu (jangan berhenti). Selesai kalau daftar habis. Hasil selalu `build_sah`.
Singkatan: J1/J2/J3 = 3 node jebakan role itu (urutan di bawah), T1/T2 = 2 node ketahanan (urutan TAHAN_ROLE),
U = Ultimate.
- attack:   J1 J2 J1 U J3 J2 J1 J3 T1 T2 J2 J3 T1 T2 T1 T2
- defense:  T1 T2 T1 T2 J1 U T1 T2 J2 J1 J3 J2 J1 J3 J2 J3
- balanced: J1 T1 T2 J2 J1 U T1 T2 J3 J2 J1 T1 T2 J3 J2 J3
Urutan J per role (terkuat dulu): api hot_flames, fire_tax, long_burn | air frozen_bubble, rapid_current,
high_tide | tanah hard_rock, fortress, stone_thorns | petir shock, card_magnet, chain_lightning | angin
strong_wind, homing_wind, whirlwind. (Hasil U9 boleh mengubah urutan ini.)
Contoh Arena 12 SP balanced: J1 Lv2 (3) + T1 Lv1 (1) + T2 Lv1 (1) + J2 Lv1 (1) + U (4) = 10, sisa 2 -> T1 Lv2 (2) = 12.

### 14.5 Pelajaran Langkah A untuk Sonnet (bug 13.1 tidak boleh terulang)
- SETIAP fungsi baru harus punya pemanggil di jalur game sungguhan. Rig baru `f4/cek_panggil.py`: daftar
  fungsi di pemain_role.gd, data_role.gd, ai_jebakan.gd, ui_role.gd (dan file baru B) yang tidak dipanggil
  dari file PRODUKSI mana pun -> harus kosong (kecuali daftar pengecualian bertanda di skrip).
- Rig TIDAK boleh memanggil fungsi penyiapan produksi secara manual kalau jalur produksinya ada (uji_nyata.gd
  lewat menu asli; uji_sim.gd tetap boleh karena papannya buatan sendiri, tapi hasilnya tidak dipakai
  sebagai bukti jalur produksi).
- Robot multiplayer mencetak role + jebakan + BUILD tiap slot di baris SELESAI (sudah untuk role/jebakan);
  syarat U4/U10: sama di semua HP DAN tidak kosong.
- XP "tahan +15": stat `tahan_kurangi` hanya bertambah di `_kurangi_tahan` (persen). Steady Feet, Grounded,
  Rock Breaker (versi K13/K14) dan Guard juga harus menambah stat ini saat benar-benar mengubah hasil.

### 14.6 Urutan kerja Langkah B (Sonnet, tiap langkah diperiksa rig sebelum lanjut)
B-a data: data_role.gd (angka 14.1, PRESET 14.4, `build_dari_preset`, tabel K13/K14), data_pemain.gd (4b),
    profil XP Role (4c) + kartu hadiah (B1).
B-b efek node di host (B4) + `_angka_jebakan` (14.2) + Guard + stat tahan -- lalu U8 per node.
B-c jaringan: build di lobby (kirim bersama role, validasi host `build_sah` 12 SP), siaran state (`_kemas_role`
    sudah membawa build), data jebakan `info` (bagian 7), stealth.
B-d AI (14.2) + solo AI Balanced sesuai level role pemain (K1).
B-e UI: layar pohon + ARENA (B2), tombol ROLES di menu, tayangan B5 (+ versi Very Low).
B-f rig lengkap: U1-U7, U8-U11, cek_panggil.py; lalu Opus: U9 keseimbangan dengan build.
Set kiriman B = 26 + jebakan_tanah.gd, jebakan_angin.gd, jebakan_petir.gd = 29 file.

### 14.7 B-a selesai (26-09)
- `data_role.gd`: `hot_flames`/`strong_wind` diperbaiki (14.1); `PRESET_URUTAN_JEBAKAN` + `PRESET` + fungsi
  `build_dari_preset` (14.4); `GROUNDED_LV`/`ROCK_BREAKER_LV` (K13/K14) -- SEMUA masih data murni, BELUM
  dipanggil efek host/AI (B-b/B-d). Dicek lewat skrip sekali-pakai (bukan bagian rig U1-U11 resmi, sudah
  dihapus): build_dari_preset selalu `build_sah` & pas anggaran SP untuk 5 role x 3 preset x 7
  kombinasi level/SP, contoh Arena 14.4 cocok persis, tabel K13/K14 konsisten (Guard cuma Lv3).
- `data_pemain.gd`: 7 field Langkah B (4b) ditambah; `bakar_per_giliran` default dari `DataRole.DASAR`
  (BUKAN angka 50 tertulis di 4b -- sesuai catatan 14.1).
- Stat baru `jebakan_role_kena` (companion `jebakan_role_pasang`/`tahan_kurangi` yang sudah ada dari
  Langkah A): ditambah di 5 titik (pemain.gd: air/angin/api/petir; pemain_duel.gd: tanah) saat elemen
  jebakan = role pemiliknya.
- `pemain.gd` `_data_akhir_profil`: kirim `"role"` (role pemain lokal match ini) ke `catat_akhir_match`.
- `profil_pemain.gd` `catat_akhir_match`: hitung & tambah XP Role dari `XP_ROLE` (selesai/pasang/kena/
  tahan/duel_elemen/menang, pengali quick/classic TANPA BONUS_MENANG supaya "menang" tidak dobel), hasil
  `xp_role_match`/`role_level_awal`/`role_level_akhir` di dict balik. `tambah_double`: WATCH AD ikut
  menggandakan XP Role (K10) lewat `xp_role_double`.
- `ui_profil.gd` `buat_kartu_hadiah` (B1): baris baru "<ROLE> ROLE +<xp> XP (Lv <n>)" + batang progres
  Level Role, warna sesuai role, HANYA muncul kalau match ini role terpilih; ikut disegarkan saat DOUBLE
  (`_tulis_baris_role`, dipanggil ulang dari `_tonton_double`).
- Diverifikasi hidup lewat `uji_nyata.gd` (rig `proj/`): `godot --headless --import` bersih (0 galat parse,
  semua class_name termasuk DataRole/DataPemain terdaftar); 1x match AI-vs-AI role Fire/Water sampai batas
  giliran (0 SCRIPT ERROR, jebakan_role_kena ikut tercatat diam-diam lewat `pasang`/`kena` di baris
  SEIMBANG); 1x Quick Match `profil=1 iklan=1` sampai tuntas -> `PROFIL_CEK OK` (kartu YOUR REWARDS +
  baris Role XP tampil, tombol DOUBLE menggandakan XP profil DAN XP Role tanpa error).
- BELUM disentuh (menyusul B-b dst, sesuai 14.6): efek node itu sendiri di host, AI membaca build,
  build di jaringan/lobby, layar pohon/ARENA.

### 14.8 B-b bagian 1 selesai (26-09) -- infrastruktur + elemen Api + Petir
Lingkup B-b (satu baris di 14.6) ternyata sangat besar (setara mengulang Langkah A untuk 17 node) --
dipecah sendiri jadi beberapa langkah kecil, tiap langkah diverifikasi sebelum lanjut (K11: pemecahan
lingkup ini keputusan Sonnet sendiri, bukan penambahan aturan). Bagian 1 = infrastruktur bersama +
elemen Api + elemen Petir (kecuali stealth_charge, sengaja ditunda -- lihat di bawah).

**Infrastruktur bersama (`pemain_role.gd`, `data_role.gd`), dipakai semua elemen:**
- `_angka_jebakan(slot_pemasang, elemen) -> Dictionary` (14.2): satu fungsi sumber-kebenaran angka efek
  jebakan per level node + flag Ultimate, dirancang dipakai BERSAMA oleh efek host (B-b, sudah) dan
  otak AI (B-d, belum disambung). Level 0 (node belum dibeli -- SELALU begini untuk sekarang, belum ada
  yang punya level node di atas ketahanan Lv1 gratis) jatuh balik ke angka DASAR Langkah A persis --
  jadi seluruh kode baru saat ini TIDAK MENGUBAH PERILAKU sampai B-c/B-d/B-e menyambungkan pembelian
  node sungguhan (sama seperti NODE_LV yang sengaja "tidur" sejak Langkah A/B-a).
- Guard (node ketahanan Lv3): sekali per pertandingan PER ELEMEN, jebakan elemen itu yang pertama kena
  korban dibatalkan total (jebakan hancur, korban tidak kena efek apa pun). `_guard_boleh`/`_pakai_guard`
  di `pemain_role.gd`, dicek PALING AWAL di tiap titik pemicu jebakan di `pemain.gd`.
- K13 (Grounded/tahan petir) ditata ulang: Lv1 = giliran korban TIDAK dilewati (dulu "boleh Fight saat
  lumpuh", nyaris tak berguna sendirian); Lv2 = + boleh Fight saat lumpuh (perilaku Lv1 lama pindah ke
  sini); Lv3 = + Guard. Lewat `_paralisis_untuk(slot)`/`_boleh_fight_saat_lumpuh(slot)` baca
  `DataRole.GROUNDED_LV`.
- K14 (Rock Breaker/tahan tanah) ditata ulang: Lv1 = 50% batal bonus +1 HP jebakan tanah (BELUM
  disambung -- menyusul elemen Tanah); Lv2 = + potongan pengali kalah duel (dulu satu-satunya efek Lv1);
  Lv3 = + Guard. `DataRole.pengali_kalah_duel` tanda tangan berubah dari `(bool,bool,float)` jadi
  `(int level,bool,float)`, baca `ROCK_BREAKER_LV[level]["potongan_kalah_duel"]`.
- K2 (Stone Thorns) diperbaiki: sebelumnya SELALU kena pengali 1.2 tak peduli siapa pemilik jebakan
  tanah di petak duel (bug lama, Stone Thorns dorman total) -- sekarang lewat `_stone_thorns_p_di(posisi)`
  (dipakai teks risiko pra-duel di `pemain.gd`) hanya kena kalau pemilik jebakan tanah di petak itu
  role-nya "tanah".
- `mesin_acak` dikonfirmasi acak SENDIRI-SENDIRI tiap peer (tidak ada seed bersama, dicek lewat grep
  `.seed`/`.randomize()` di semua berkas) -- jadi tiap kode baru yang pakai `mesin_acak` untuk keputusan
  yang memengaruhi game (card_magnet) DIJAGA `StatusJaringan.peran_multiplayer != "client"` (host/solo
  saja), siaran hasil ke client jadi tugas B-c (pola sama seperti jebakan air yang sudah ada).

**Elemen Api (`pemain.gd`, `pemain_papan.gd`, `jebakan_api.gd`, `data_role.gd`):**
- hot_flames: durasi bakar & bakar/giliran naik sesuai level lewat `_angka_jebakan`.
- fire_tax: sebagian kerugian bakar korban tiap tick DIALIHKAN ke dompet pemasang jebakan -- dihitung
  ulang tiap `_mulai_giliran` dari build TERSIMPAN pemilik jebakan (`bakar_pemilik`), aman karena build
  tidak berubah di tengah pertandingan.
- long_burn: `bakar_larang_jebakan` -- korban tidak bisa pasang jebakan baru selama masih terbakar
  (dicek di `_boleh_pasang_jebakan_di`).
- phoenix (Ultimate): lewat medan baru `sisa_aktif_ulang: int` LANGSUNG di `jebakan_api.gd` (BUKAN lewat
  dict jaringan `info` -- itu jatah B-c), diset 1 saat pasang kalau pemasang punya Ultimate Api, dikurangi
  (bukan `queue_free()`) saat kena pertama kali -- jebakan hidup lagi sekali. Client belum tahu jebakan
  ini "hidup lagi" (akan desync visual di client sampai B-c menyambung siaran persistensi) -- risiko
  diketahui & dicatat, bukan bug tersembunyi.

**Elemen Petir (`pemain.gd`, `ai_musuh.gd`):**
- grounded K13: paralisis pakai `_paralisis_untuk`/`_boleh_fight_saat_lumpuh` (lihat infrastruktur di
  atas); `ai_musuh.gd` ikut dibetulkan supaya AI baca fungsi yang sama (dulu baca level node langsung).
- shock: korban kehilangan koin TANPA dialihkan ke pemasang (beda dari fire_tax -- sesuai 14.1/8).
- chain_lightning: efek LOW ROLL (`tipe_dadu_slot`/`sisa_durasi_dadu_slot`) menular ke lawan lain dalam
  jarak node lewat `_jarak_maju` (BFS maju dari petak jebakan) -- satu-satunya primitif jarak yang ada di
  papan bercabang, cocok dengan `NODE_LV["chain_lightning"] = {1:0,2:1,3:2}` (Lv1=0="petak sama").
- card_magnet: mencuri 1 kartu acak korban ke pemasang lewat `mesin_acak`, DIJAGA host/solo (lihat
  infrastruktur). Syarat "kartu pemasang sudah penuh -> batal" di rencana TIDAK diimplementasikan sebagai
  kode mati -- dicek lewat grep, TIDAK ADA batas jumlah kartu (`MAKS_KARTU`) di mana pun di kode saat ini,
  jadi syarat itu selalu salah (dicatat komentar di kode, bukan fitur baru yang dikarang).

**SENGAJA DITUNDA ke B-c (bukan lupa -- rencana bagian 7 memang menaruhnya di B-c):**
stealth_charge (jebakan tak terlihat lawan), dict `info` (elemen ke-4 array jebakan `[petak,nama,
pemilik,info]`), RPC `rpc_efek_role` (siaran satu pintu), siaran state field korban baru (`bakar_per_
giliran`/`bakar_pemilik`/`bakar_larang_jebakan`/`guard_terpakai`/`kunci_kartu`/`low_roll_bubble` --
`_kemas_role` sudah membawa BUILD lewat B-a tapi belum field-field runtime ini), sinkron visual client
untuk keputusan host acak/persisten (Phoenix, nanti Hard Rock/Sacred Ground/Tornado).

**Diverifikasi (26-09):** `godot --headless --import` bersih di kedua salinan rig (`proj/` UJI ON,
`proj_tanpa_uji/` dadu & duel sungguhan) -- 0 galat parse. 5x pertandingan AI-vs-AI nyata di
`proj_tanpa_uji` (dadu asli, bukan mode UJI), role Api & Petir dipaksa semua slot lewat
`semua_ai=1 role=...`: 2P quick, 4P quick campuran api/petir, 4P classic seragam api, 4P classic
seragam petir, 2P classic campuran -- total sampai 201 giliran, ratusan jebakan terpicu (kolom `kena`
di baris SEIMBANG), 0 SCRIPT ERROR di semuanya (satu-satunya "ERROR" yang muncul di log = aset
gambar/audio tak ada di rig scratchpad, bukan galat skrip -- sudah dikenal sejak fase-fase sebelumnya).
BELUM: uji per-node U8 (baru berarti setelah B-c/B-e menyambungkan pembelian node sungguhan -- lihat
catatan "Level 0 selalu" di atas), sesi manual/foto layar.

**BELUM dikerjakan sama sekali (menyusul, sesuai pemecahan sendiri di atas):** elemen Air (rapid_current,
high_tide, frozen_bubble, tsunami -- `jebakan_air.gd`, `pemain_kartu.gd`), elemen Tanah (siklus duel
jebakan tanah di `pemain_duel.gd` sesuai temuan 9, hard_rock, Rock Breaker Lv1 "bonus tanah gagal",
fortress di `pemain_papan.gd::eksekusi_serangan` DAN `ai_musuh.gd`, sacred_ground), elemen Angin
(strong_wind/homing_wind/whirlwind/tornado -- `jebakan_angin.gd`), perluasan stat `tahan_kurangi` supaya
mencakup Steady Feet/Grounded/Rock Breaker/Guard di semua titik yang benar-benar mengubah hasil (pelajaran
14.5), lalu baru U8 per node.

### 14.9 B-b bagian 2 selesai (26-09) -- elemen Air
File berubah dari bagian 1: `pemain.gd`, `pemain_role.gd`, `jebakan_air.gd`, `pemain_kartu.gd`,
`ai_musuh.gd` (5 file; `data_role.gd`/`data_pemain.gd` TIDAK berubah -- datanya sudah lengkap sejak B-a).

**Guard & efek dasar (`pemain.gd`, blok geiser di `bergerak_maju`):** Guard (steady_feet Lv3) diperiksa
PERTAMA, pola sama persis Api/Petir. high_tide: peluang (undi `mesin_acak`, HOST/solo saja seperti
card_magnet) pemasang dapat +1 bintang (dibatasi 10, sama seperti bonus lewat Start) & Lv3 juga +100 koin
-- field `bintang`/`uang` sudah lama ada & disiarkan `_siarkan_state_giliran`, jadi TIDAK butuh RPC baru.
frozen_bubble (K7): `kunci_kartu`/`low_roll_bubble` diisi SAAT KENA dari `_angka_jebakan`; LOW ROLL Lv3
dipicu TEPAT saat gelembungnya sendiri pecah (`_mulai_giliran`), `kunci_kartu` baru mulai dihitung mundur
giliran BERIKUTNYA (elif terpisah dari cabang gelembung, supaya tidak nge-tick di tick yang sama).

**frozen_bubble -- 3 titik gating (sesuai spek, bukan cuma tombol UI):** tombol Use Card
(`periksa_status_petak`, pemain.gd) + validasi HOST (`rpc_minta_pakai_kartu`, pemain_kartu.gd) + AI
(`logika_ai_musuh_sebelum_lempar`, ai_musuh.gd) semua ikut memeriksa `kunci_kartu == 0`, sejajar dengan
`sisa_gelembung`/`sisa_paralisis` yang sudah dicek di tombol UI & AI (host validation TIDAK pernah
memeriksa gelembung/paralisis dari dulu -- celah lama, di luar lingkup, TIDAK ikut dirapikan di sini).

**rapid_current/steady_feet Lv2 (`_kandidat_petak_jatuh`, pemain_role.gd + `pilih_petak_jatuh`,
jebakan_air.gd):** kandidat petak jatuh jebakan air sekarang lewat fungsi baru yang menghitung jarak-dari-
START tiap petak (BFS baru, `_jarak_dari_start`, di-cache lazy, terpisah dari `_jarak_maju`/`_petak_mundur`
yang sudah ada supaya jaraknya BENAR shortest-path, bukan mengandalkan `_peta_pendahulu` yang dibangun
tanpa urutan BFS). **Bug ditemukan & diperbaiki SEBELUM dikirim** (uji sendiri, bukan laporan user): rumus
n_min awal tetap menjalankan penyaringan jarak walau rapid_current level 0 (n_min=0), sehingga petak yang
LEBIH DEKAT ke START daripada posisi korban malah ikut terbuang -- Lv0 seharusnya "semua petak tetap
kandidat" (persis `pilih_petak_jatuh` Langkah A yang lama), BUKAN "n_min=0 dipakai ke rumus jarak". Sudah
diperbaiki: n_min<=0 melewati rumus jarak sama sekali (`kandidat = semua petak`). Diverifikasi ulang
sesudah perbaikan (re-import + 2 pertandingan tambahan, 0 SCRIPT ERROR) -- pelajaran ditulis di sini
supaya kalau nanti Opus/Sonnet menyentuh node lain dengan pola "Lv0 = fallback", periksa jalur KOSONG-nya
literal, bukan cuma "angka fallback dipakai di rumus yang sama".

**tsunami (Ultimate Air, `pemain.gd`):** lawan lain (bukan korban, bukan pemasang) dalam jarak <= 2 petak
DUA ARAH (`_jarak_maju` dari petak jebakan DAN ke petak jebakan, karena papan bercabang & BFS cuma maju
satu arah) dari petak jebakan terdorong mundur 2 petak (`_petak_mundur`) tanpa memicu efek petak tujuan.
Posisi barunya (`posisi_saat_ini`) tersinkron client lewat `_siarkan_state_giliran` (field LAMA, sudah ada
di sana) -- animasi geser 0,6 dtk di layar CLIENT LAIN belum disiarkan RPC khusus (menyusul B-c, sama
seperti Phoenix); host/solo tetap melihatnya penuh.

**Diverifikasi (26-09):** `godot --headless --import` bersih di kedua salinan rig sesudah SEMUA perubahan
(termasuk perbaikan bug rapid_current di atas). 7x pertandingan AI-vs-AI nyata di `proj_tanpa_uji`, role
Air (+ campuran Angin) dipaksa semua slot: 2P & 4P, quick & classic, sampai 201 giliran, puluhan jebakan
air terpicu (kolom `kena`) -- **0 SCRIPT ERROR** di semuanya. BELUM: uji per-node U8 (sama seperti bagian
1, baru berarti setelah B-c/B-e menyambungkan pembelian node sungguhan).

**Masih tersisa (menyusul, tidak berubah dari 14.8):** elemen Tanah (paling rumit -- rewrite siklus duel
jebakan), elemen Angin, perluasan stat `tahan_kurangi`, lalu U8 per node.

### 14.10 B-b bagian 3 selesai (26-09) -- elemen Angin
File berubah dari bagian 2: `pemain.gd`, `pemain_role.gd` (2 file; jebakan_angin.gd TIDAK perlu diubah --
posisinya cukup di-reparent lewat node yang sudah ada, tanpa medan baru seperti Phoenix).

**Guard & efek dasar (`pemain.gd`, blok jebakan angin di `bergerak_maju`):** Guard (heavy_pockets Lv3)
diperiksa PERTAMA, pola sama persis elemen lain. strong_wind: persen rampasan dari BUILD PEMASANG (Lv0 =
DASAR 10%, sama seperti Langkah A) menggantikan konstanta tetap. homing_wind: bagian rampasan LANGSUNG ke
dompet pemasang (field `uang` lama, otomatis ikut `_siarkan_state_giliran`, tidak butuh RPC baru), SISANYA
baru disebar acak seperti sekarang (`eksekusi_sebar_acak`, tidak diubah). whirlwind (K8): langkah dadu
korban yang TERSISA (`sisa_langkah`) ikut berkurang sesuai level, dibatasi tidak sampai negatif (`maxi(0, ..)`).

**Tornado (Ultimate Angin, `pemain.gd` + `_petak_kosong_untuk_jebakan` baru di `pemain_role.gd`):** sesudah
kena, jebakan DIPINDAH (reparent node yang sama: `remove_child`+`add_child` ke tile lain, BUKAN
dihapus+dibuat baru) ke petak kosong acak yang sah menampung jebakan apa pun (bukan petak START, belum ada
jebakan APA PUN di situ -- aturan sama `_boleh_pasang_jebakan_di` tanpa syarat milik pemain bergiliran),
lalu `aktif = true` lagi. Undian `mesin_acak` (pemilihan petak tujuan) dijaga HOST/solo saja, pola sama
card_magnet/high_tide. **Beda dengan Phoenix**: di sini TIDAK ada state tambahan yang perlu disiarkan --
`_kumpulkan_data_jebakan`/`_terapkan_data_jebakan` (dipakai `_siarkan_state_giliran`, sudah ada sejak
Langkah A) memang membandingkan LOKASI jebakan tiap petak setiap siaran state, jadi client otomatis melihat
jebakannya "pindah" (hilang dari petak lama, muncul di petak baru) tanpa kode tambahan apa pun -- satu-
satunya yang belum ada cuma animasi pindah LANGSUNG di layar client lain (menyusul B-c, sama seperti
Phoenix/Tsunami); host/solo tetap melihatnya penuh.

**Diverifikasi (26-09):** `godot --headless --import` bersih di kedua salinan rig. 5x pertandingan AI-vs-AI
nyata di `proj_tanpa_uji`, role Angin (+ campuran elemen lain) dipaksa semua slot: 2P & 4P, quick & classic,
sampai 201 giliran, puluhan jebakan angin terpicu -- **0 SCRIPT ERROR** di semuanya. BELUM: uji per-node U8
(sama seperti bagian 1/2, baru berarti setelah B-c/B-e menyambungkan pembelian node sungguhan).

**Masih tersisa:** elemen Tanah (paling rumit -- rewrite siklus duel jebakan per temuan 9, fortress di DUA
tempat termasuk `ai_musuh.gd`), perluasan stat `tahan_kurangi`, lalu U8 per node.

### 14.11 B-b bagian 4 selesai (26-09) -- elemen Tanah (INTI: temuan 9 + hard_rock + Guard + Rock Breaker)
File berubah dari bagian 3: `jebakan_tanah.gd`, `pemain_duel.gd`, `pemain_papan.gd` (3 file). Bagian 4 ini
SENGAJA dibatasi ke perbaikan siklus duel (temuan 9) + hard_rock + Guard + Rock Breaker Lv1 -- fortress (2
titik) & sacred_ground (Ultimate) dipisah jadi **bagian 5** (lihat "Masih tersisa" di bawah): keduanya
menyentuh menu pasang jebakan (tombol baru) & satu titik lagi di `ai_musuh.gd`, kompleksitasnya sepadan
dengan elemen penuh lain -- pemisahan ini sama seperti Api+Petir/Air/Angin dipisah jadi bagian 1/2/3.

**Perbaikan inti (temuan 9, `jebakan_tanah.gd` + `pemain_duel.gd`):** akar masalah lama:
`_pantau_duel_berlangsung` (jebakan_tanah.gd) menunggu sinyal `duel_selesai` (terpancar SEBELUM
`_hasil_duel_petak` menentukan pemilik petak akhir), lalu langsung `queue_free()` TANPA SYARAT -- jebakan
selalu hilang setelah 1 duel, apapun levelnya, dan keputusan "masih dipertahankan atau tidak" tidak pernah
memakai data pemilik_petak yang sudah mutakhir. Perbaikan: `_pantau_duel_berlangsung` sekarang HANYA menarik
buff HP sementara (jumlahnya disimpan `_hp_terakhir_ditambahkan`, bukan lagi `-1` tetap) dan TIDAK lagi
memanggil `queue_free()`. Fungsi baru `_selesaikan_tanah_setelah_duel(posisi)` (pemain_duel.gd) dipanggil
dari KEDUA cabang `_hasil_duel_petak` (menang & kalah), TEPAT SESUDAH `pemilik_petak[posisi]` pasti mutakhir
untuk duel yang baru selesai, SEBELUM `_tanah_saat_duel` dikosongkan: kalau `pemilik_petak[posisi]` !=
pemilik jebakan -> petak sudah pindah tangan -> jebakan dihapus; kalau masih sama -> Sacred (bagian 5) tidak
berkurang, selainnya `sisa_duel -= 1` -> habis (<=0) dihapus, masih ada -> `aktifkan_kembali()` (fungsi baru
jebakan_tanah.gd: `aktif = true` + tampil lagi, `_sudah_duel_pertama` SENGAJA tidak direset).

**hard_rock (`sisa_duel`, `hp_tambahan_awal`):** field baru `sisa_duel: int = 1` di jebakan_tanah.gd, diisi
`pemain_papan.gd::_pasang_jebakan` dari `_angka_jebakan(slot,"tanah")["sisa_duel"]` saat dipasang (pola sama
persis Phoenix `sisa_aktif_ulang` -- Lv0 = 1, sama dengan perilaku lama; TIDAK menyentuh `rpc_jebakan_dipasang`,
aman/inert sampai B-c sama seperti Phoenix). Bonus +2 HP Lv3 (`hp_tambahan_awal`) hanya berlaku duel PERTAMA
sepanjang umur jebakan (flag `_sudah_duel_pertama`); teks buff 3D & jumlah yang ditarik lagi sekarang
mengikuti angka sesungguhnya (`+1` atau `+3`), bukan `+1` tetap.

**Guard & Rock Breaker Lv1 (`pemain_duel.gd::_mulai_duel`):** Guard (rock_breaker Lv3, `_guard_boleh`/
`_pakai_guard`) diperiksa PERTAMA persis pola elemen lain -- kalau aktif, jebakan hilang & penyerang sama
sekali tidak kena efek tanah. Kalau tidak: Rock Breaker Lv1+ milik PENYERANG (korban efek tanah) diundi 50%
(`ROCK_BREAKER_LV[lv]["peluang_gagal_hp"]`) -- gagal berarti bonus HP tanah duel ini ditiadakan sepenuhnya
(`aktifkan_pelindung_sementara` dilewati), `sisa_duel` tetap berkurang seperti biasa. **Aman soal RNG
jaringan (diperiksa sebelum menulis kode):** `_mulai_duel` HANYA dipanggil dari SATU titik
(`pemain_papan.gd::_on_tombol_bangun_pressed`, baris `if fase_giliran=="konfrontasi": _mulai_duel(...)`),
yang diawali `if _teruskan_aksi_ke_host("bangun"): return` -- ditelusuri ke `_teruskan_aksi_ke_host`
(pemain_dasar.gd): device CLIENT selalu `return true` di sana (baris "if peran_multiplayer == client") SEBELUM
mencapai `_mulai_duel`, jadi `_mulai_duel` (dan undian `mesin_acak` Rock Breaker di dalamnya) TIDAK PERNAH
berjalan di client murni -- hanya host atau solo, sama seperti pola card_magnet/high_tide/tsunami/tornado.
Digating `StatusJaringan.peran_multiplayer != "client"` tetap ditambahkan sebagai jaring pengaman tambahan
(bukan karena reachable, tapi konsisten dengan pola RNG lain di seluruh kode).

**Diverifikasi (26-09):** `godot --headless --import` bersih di kedua salinan rig (proj & proj_tanpa_uji --
`sinkron_uji.sh`/`sinkron_tanpa_uji.sh` diperbaiki sekalian, sebelumnya TIDAK menyalin
jebakan_angin.gd/jebakan_petir.gd/jebakan_tanah.gd sama sekali, celah lama sejak bagian 3). 18x pertandingan
AI-vs-AI nyata di `proj_tanpa_uji`, role Tanah (+ campuran SEMUA elemen lain, termasuk cermin tanah-vs-tanah)
dipaksa berbagai slot: 2P/3P/4P, quick & classic, sampai 81 giliran -- match CLASSIC memicu jebakan tanah
lewat DUEL sungguhan berkali-kali (kolom `kena` sampai 11 per pertandingan, puluhan siklus pasang-duel-hapus
total) -- **0 SCRIPT ERROR** & `STAT_CEK OK` di semuanya. BELUM (sama seperti elemen lain, Lv0 selalu aktif
sekarang): jalur Guard & Rock Breaker roll tidak ikut teruji rig (butuh `rock_breaker` Lv1/Lv3 sungguhan,
sama-sama menunggu U8/B-e); jalur "sisa_duel berkurang tapi belum habis" (hard_rock Lv1+) juga demikian --
di Lv0 `sisa_duel` selalu langsung 1->0 sama seperti sebelumnya.

**Masih tersisa: bagian 5 (fortress + sacred_ground)** -- `_benteng_menahan(petak) -> bool` dipanggil
`pemain_papan.gd::eksekusi_serangan` DAN serangan jarak jauh AI (`ai_musuh.gd`) sebelum `nyawa_petak -= 1`;
sacred_ground (tombol "Sacred Earth Trap (FREE)" di menu pasang jebakan, gratis SEKALI per pertandingan untuk
pemilik Ultimate, `jebakan.sacred = true`, tidak habis oleh duel -- sudah didukung `_selesaikan_tanah_setelah_duel`
di atas, tinggal cara MENGISI field itu jadi true). Sesudah itu: perluasan stat `tahan_kurangi`, lalu U8 per node.

### 14.12 B-b bagian 4b selesai (26-09) -- elemen Tanah LENGKAP (fortress + sacred_ground)
File berubah dari bagian 4: `ai_musuh.gd`, `jebakan_tanah.gd`, `pemain_papan.gd`, `pemain_role.gd`,
`pemain_tampilan.gd`, `ui_petak.gd` (6 file; `pemain_duel.gd`/`data_pemain.gd` TIDAK berubah -- field
`sacred_terpakai` & struktur `_tanah_saat_duel`/`_selesaikan_tanah_setelah_duel` sudah cukup dari bagian 4).
Dengan ini **elemen Tanah selesai penuh** (hard_rock, stone_thorns, fortress, Guard, Rock Breaker Lv1,
sacred_ground) -- sejajar Api/Petir/Air/Angin.

**fortress (`jebakan_tanah.gd` + `pemain_role.gd` + `pemain_papan.gd` + `ai_musuh.gd`):** field baru
`sisa_tahan_serangan: int` (jebakan_tanah.gd, diisi `_angka_jebakan(slot,"tanah")["tahan_serangan"]` saat
pasang, pola sama `sisa_duel`). Fungsi baru `_benteng_menahan(petak) -> bool` (pemain_role.gd): true kalau
ada JebakanTanah aktif milik pemilik petak dengan `sisa_tahan_serangan > 0` (lalu dikurangi 1 sekaligus --
efek sampingnya SENGAJA, satu pemanggilan = satu serangan ditahan). Dipanggil di DUA titik serangan jarak
jauh (bukan duel -- fortress tidak berlaku saat duel, cuma saat petak DISERANG langsung): `pemain_papan.gd::
eksekusi_serangan` (tombol Attack manusia) dan `ai_musuh.gd` (serangan jarak jauh AI), keduanya PERSIS
sebelum `nyawa_petak[target] -= 1` -- kalau ditahan, HP petak tidak berkurang sama sekali, bintang penyerang
tetap terpakai (sudah dipotong sebelum titik ini), teks "FORTRESS! The attack was blocked." (baru,
`rpc_hasil_serangan` dapat parameter ke-6 `ditahan_fortress: bool = false` untuk sinkron teks -- inert sampai
B-c sama seperti pola RPC lain di Fase 4). Label "Protected" di petak ber-Fortress (`ui_petak.gd::
perbarui_tampilan` param baru `dilindungi_fortress`, `pemain_tampilan.gd::update_semua_label_petak` menghitung
`dilindungi` LANGSUNG dari field node (get_node_or_null + baca properti) -- BUKAN memanggil `_benteng_menahan()`,
karena rantai `pemain_tampilan.gd` LEBIH AWAL dari `pemain_role.gd` (tempat `_benteng_menahan` didefinisikan)
dan aturan rantai melarang file awal memanggil fungsi file belakangan; baca properti node langsung tidak
kena aturan itu, cuma pemanggilan fungsi).

**sacred_ground (`pemain_role.gd` + `pemain_papan.gd`):** fungsi baru `_sacred_tersedia(slot) -> bool`:
true kalau slot punya Ultimate Tanah (`_punya_ultimate(slot,"tanah")`) DAN belum pakai `sacred_terpakai`
(field lama, sudah ada dari B-a, sengaja belum dipakai sampai sekarang). `_pasang_jebakan` (pemain_papan.gd)
dapat parameter baru `gratis: bool = false` (2 caller lama, `ai_jebakan.gd`/`pemain_papan.gd` sendiri, sama-sama
bentuk 1-argumen jadi `gratis` default false, tidak terganggu) -- kalau `_sacred_tersedia(slot)` true saat
pasang trap Tanah: `sacred_terpakai = true` (bukan potong bintang), `jebakan.sacred = true`,
`sisa_tahan_serangan` dinaikkan ke MINIMAL Fortress Lv2 (`maxi(nilai_asli, DataRole.NODE_LV["fortress"][2])`,
sesuai rencana "Sacred Ground memakai Fortress paling tinggi Lv2"). `_selesaikan_tanah_setelah_duel`
(bagian 4) SUDAH menangani "sacred tidak berkurang oleh duel" (`if jebakan.sacred: aktifkan_kembali(); return`)
-- tidak perlu diubah lagi. Tombol menu pasang jebakan (`_on_tombol_set_trap_pressed`) berganti teks otomatis
"Sacred Earth Trap (FREE)" / tetap aktif dengan 0 bintang kalau `_sacred_tersedia` true; teks event
(`_teks_jebakan_dipasang`, param baru `sacred: bool = false`) juga beda kalau sacred.

**Diverifikasi (26-09) -- lihat juga pelajaran metode di bawah:** `godot --headless --import` bersih (proj &
proj_tanpa_uji, sudah disinkron ulang dari file produksi, diff nol selain saklar UJI_DUEL/UJI_SERI). Alat rig
BARU (sementara, HANYA di `scratchpad/proj{,_tanpa_uji}/uji_nyata.gd`, TIDAK PERNAH disalin ke `/home/claude`
atau ikut ZIP): argumen CLI `maks_node=1` (fungsi `_build_maks(role)`, set 3 node jebakan + 2 node tahan role
itu ke Lv3 + Ultimate true) -- memaksa level node sungguhan tanpa menunggu toko/pembelian B-c/B-e, sekaligus
menjawab sebagian pertanyaan terbuka #121 ("cara paksa NODE_LV lewat rig"), sangat disarankan dipakai lagi
saat U8. Dengan `maks_node=1` + argumen lama `jenis=1` (`DataRole.jebakan_bawaan_ai` HANYA membawakan elemen
role sendiri, tanpa elemen tambahan -- lihat pelajaran di bawah kenapa ini penting), dikonfirmasi LANGSUNG
lewat gameplay AI-vs-AI sungguhan (bukan cuma baca kode): Fortress menahan serangan jarak jauh AI (dua kali,
sasaran sama, di satu match `maks_node=1` role tanah vs air), Guard menahan earth trap (satu kali), dan
Rock Breaker Lv1 mengundi dengan benar -- sampel bersih 6 sukses dari 14 percobaan (~43%, sejalan target 50%
`ROCK_BREAKER_LV[1]["peluang_gagal_hp"]`, wajar untuk n=14 binomial). BELUM diverifikasi langsung lewat
gameplay (diterima sebagai risiko rendah, BUKAN cacat dari bagian 4b): (1) jalur Fortress dari tombol Attack
MANUSIA -- memanggil `_benteng_menahan()` yang SAMA PERSIS dengan jalur AI yang sudah terkonfirmasi, jadi kode
identik, cuma titik panggilnya beda, tidak mungkin diuji di rig AI-vs-AI murni; (2) AI memilih MEMASANG Sacred
Earth Trap gratis sendiri -- `ai_jebakan.gd::pertimbangkan` belum diubah untuk mengenali `_sacred_tersedia`
sebagai opsi gratis (AI sekarang tidak akan spontan memasangnya di 0 bintang), SENGAJA ditunda ke B-d
bersamaan pekerjaan "AI membaca build" lainnya, bukan bug bagian 4b.

**PELAJARAN METODE (penting untuk sesi berikutnya, jangan terulang):** sempat salah simpul bahwa Rock Breaker
Lv1 "0 dari 6" (gagal total) berdasarkan kolom `kena` di baris SEIMBANG -- ternyata SALAH PREMIS: stat
`jebakan_kena` itu GENERIK dipakai SEMUA 4 elemen jebakan (bukan cuma Tanah), dan `DataRole.jebakan_bawaan_ai()`
(fungsi PRODUKSI LAMA, bukan bug baru, dipakai solo & lobby) sengaja membuat AI role Tanah IKUT membawa 1-2
elemen jebakan LAIN (dipilih dari yang paling sedikit ditahan lawan) selain Tanah -- jadi kolom `kena` bercampur
pukulan dari jebakan Petir/Angin/Api yang juga dibawa AI itu, bukan cuma Tanah. Setelah itu: `print()` untuk
melacak kode di dalam `_mulai_duel`/coroutine JUGA terbukti TIDAK BISA DIPERCAYA di rig ini -- `ai_musuh.gd`
baris `main_node._mulai_duel(slot)` dipanggil TANPA `await`, jadi urutan/kemunculan baris `print()` dari
pemanggilan yang tumpang-tindih bisa kacau atau seret hilang di log, WALAUPUN logika & penambahan stat di
baliknya tetap berjalan benar. Cara yang terbukti benar: tambahkan counter SEMENTARA lewat `_tambah_stat`
(bukan `print()`) di titik yang mau diuji, baca hasil akhirnya lewat baris SEIMBANG (atau `get_stack()` sekali
untuk melacak pemanggil sesungguhnya kalau hasil meragukan) -- angka begitu TIDAK peduli urutan/tumpang-tindih
coroutine, beda dari `teks_dadu.text` (pelajaran 14.5, tidak ke log sama sekali) DAN `print()` (pelajaran BARU
ini, ke log tapi urutannya tidak bisa dipercaya). Semua counter sementara ini sudah dihapus total dari rig
sebelum ZIP ini dibuat (`sinkron_uji.sh`/`sinkron_tanpa_uji.sh` dijalankan ulang, diff nol selain 2 saklar).

**Selanjutnya: bagian 5 / #121** -- perluasan stat `tahan_kurangi` (supaya mencakup Steady Feet/Grounded/
Rock Breaker/Guard di semua titik yang benar-benar mengubah hasil, bukan cuma Rock Breaker seperti sekarang),
lalu U8 (rig per node -- `maks_node=1` di atas sudah bisa dipakai langsung). Sesudah itu B-c (jaringan), B-d
(AI baca build, termasuk celah `ai_jebakan.gd` Sacred Ground di atas), B-e (UI skill-tree), B-f (rig+Opus U9).

### 14.13 B-b bagian 5 selesai (26-09) -- perluasan stat `tahan_kurangi` + U8 (rig per node)
File berubah: `pemain.gd`, `jebakan_air.gd`, `pemain_role.gd` (3 file). Menutup task #121.

**Perluasan `tahan_kurangi` (3 titik baru, semua dicek dulu SUNGGUH mengubah hasil -- 14.5):**
- **Grounded** (`pemain.gd`, titik penerapan `sisa_paralisis` sesudah trap Petir kena): Lv1+ SELALU
  memendekkan dari DASAR 2 giliran -> 1 (lihat GROUNDED_LV, tidak ada Lv yang balik ke 2) -- jadi cukup cek
  `_lv_node(slot,"grounded") > 0`, TIDAK perlu bandingkan angka sebelum/sesudah. Dicatat di titik PENERAPAN
  (bukan `_paralisis_untuk` sendiri, yang dipanggil BERKALI-KALI cuma untuk cek boleh-Fight-saat-lumpuh
  lewat `_boleh_fight_saat_lumpuh` -- kalau dicatat di sana, hasilnya dobel-hitung tiap kali AI/UI mengecek).
- **Steady Feet Lv1** (`jebakan_air.gd`, titik penerapan `sisa_gelembung` sesudah trap Air kena): sama
  persis pola Grounded -- DASAR gelembung 2 giliran, Lv1+ SELALU jadi 1, dicatat di titik penerapan
  (bukan `_durasi_gelembung` sendiri, yang JUGA dipanggil `ai_jebakan.gd` cuma untuk estimasi AI).
  Steady Feet Lv2 (penyempitan petak jatuh ke <=6 dari posisi jebakan, `_kandidat_petak_jatuh`) SENGAJA
  TIDAK ikut dicatat -- itu mengubah PETAK TUJUAN (pilihan lokasi acak), bukan memotong suatu ANGKA/durasi,
  beda jenis dari makna "tahan_kurangi" di titik lain; tidak selalu jelas "menguntungkan" korban juga
  (bisa saja tetap mendarat di petak buruk, cuma lebih dekat).
- **Rock Breaker Lv2/3** (`pemain_role.gd::_pengali_kalah_duel`): potongan tambahan pengali-kalah-duel
  (`ROCK_BREAKER_LV[lv]["potongan_kalah_duel"]`, 0 di Lv1, >0 di Lv2/3) SEBELUMNYA tidak pernah dicatat sama
  sekali (beda dari Lv1 rolling "gagal HP" yang sudah dicatat sejak bagian 4). Dicatat dengan membandingkan
  hasil `DataRole.pengali_kalah_duel(...)` SEBELUM & SESUDAH terhadap `stone_thorns_p` -- kalau `hasil <
  stone_thorns_p` berarti benar2 terpotong (otomatis TIDAK kena di Lv1, karena `potongan_kalah_duel=0.0` ->
  `hasil == stone_thorns_p` selalu di kode DataRole, lihat `data_role.gd::pengali_kalah_duel`).

**U8 (rig per node) -- keputusan: UJI SEKARANG, tidak ditunda ke B-e.** Alasan: `maks_node=1` (bagian 4b)
sudah menjawab "cara paksa NODE_LV lewat rig" untuk Lv3; tinggal kurang cara memaksa Lv1/Lv2 KHUSUSNYA untuk
Grounded & Rock Breaker, satu-satunya 2 node yang perilakunya BEDA JENIS per tingkat (bukan cuma beda besar
seperti heat_skin/steady_feet/heavy_pockets yang generik lewat `potongan_tahan()`, lihat komentar
data_role.gd baris ~285). Alat rig BARU (sementara, HANYA `scratchpad/proj{,_tanpa_uji}/uji_nyata.gd`, TIDAK
PERNAH ikut ZIP): argumen `maks_lv=1|2|3` (bawaan 3, dipakai `_build_maks` menggantikan angka 3 yang dulu
tertulis tetap) -- gabung `maks_node=1 maks_lv=N` memaksa SEMUA node role itu ke level N persis.

**Diverifikasi (26-09) -- gameplay AI-vs-AI nyata, seed & matchup SAMA per 3 level supaya bisa dibandingkan
langsung:** `godot --headless --import` bersih (proj & proj_tanpa_uji, disinkron ulang, diff nol selain 2
saklar UJI). Grounded (role petir vs angin, `jenis=1` supaya SEMUA trap kena murni Petir, seed 4401):
Lv1 `kena=13, tahan_kurangi=13` (PAS SAMA -- tidak ada Guard, semua kena masuk hitungan) -- Lv2
`kena=17, tahan_kurangi=17` (PAS SAMA lagi -- Guard MASIH belum aktif di Lv2, sesuai rencana) -- Lv3 (v5_1,
seed beda) `kena=7, tahan_kurangi=8` (SELISIH 1 -- persis 1x Guard terpakai, TIDAK dihitung ke `kena` tapi
IKUT `tahan_kurangi` lewat `_pakai_guard`). Rock Breaker (role tanah vs api, `jenis=1`, seed 4406): Lv1
`kena=8, tahan_kurangi=4` (~50%, PAS peluang roll Lv1 SAJA, potongan kalah duel 0 -> tidak nambah) -- Lv2
`kena=8, tahan_kurangi=8` (naik jelas dari Lv1 -- potongan kalah duel Lv2 mulai ikut menyumbang, sesuai
rencana) -- Lv3 `kena=4 (turun -- sebagian dialihkan ke Guard), tahan_kurangi=7`. Tiga level MENUNJUKKAN
PERILAKU BEDA sesuai tabel GROUNDED_LV/ROCK_BREAKER_LV, bukan cuma jalan tanpa error. 6 pertandingan regresi
tambahan (macam-macam role/2P/3P/quick/classic) juga 0 SCRIPT ERROR + STAT_CEK OK.

**Selanjutnya: B-c (jaringan)** -- build dikirim dari lobby, host `build_sah` validasi, perluasan siaran
state untuk field per-korban baru (`sisa_duel`/`sisa_tahan_serangan`/`sacred`/dll, sengaja masih lembam sejak
bagian 4/4b), `info` dict jaringan + `rpc_efek_role`, stealth_charge, sinkron visual client untuk
Phoenix/Tornado/Tanah (hard_rock/fortress/sacred_ground). Lalu B-d (AI baca build, termasuk celah
`ai_jebakan.gd` Sacred Ground), B-e (UI skill-tree), B-f (rig+Opus U9, tinjau keseimbangan penuh).

### 14.14 Tinjauan Opus + rencana TERKUNCI B-c (jaringan) -- 26-09
Ditulis Opus setelah membaca kode jaringan sungguhan (`pemain_jaringan.gd` siaran/terima state,
`pemain_papan.gd` data jebakan & RPC efek, `layar_local_play.gd` lobby, `jebakan_*.gd`, rig
`uji_robot_mp.gd`). Sonnet mengeksekusi urutan C1-C8 di bawah APA ADANYA, satu langkah diverifikasi rig
sebelum lanjut (pola 14.6). Kalau kode ternyata beda dari yang tertulis di sini: BERHENTI & catat, jangan
mengarang jalan lain.

**K16 (DISETUJUI user 26-09):** build multiplayer = Arena build pemain; kalau `ProfilPemain.arena[role]`
kosong/tidak sah -> **preset Balanced 12 SP** (`build_dari_preset(role,"balanced",SP_ARENA,LEVEL_ROLE_MAKS)`).
Slot AI di multiplayer juga Balanced 12 SP. Akibat: sejak B-c, node & Ultimate AKTIF SUNGGUHAN di
multiplayer (solo TIDAK berubah -- tetap `_build_lv1` sampai B-d/B-e). **B-c tidak boleh dirilis ke Play
Store sendirian** -- keseimbangan build baru ditinjau di B-f/U9.

**Dua bug B-b ditemukan saat tinjauan (ikut diperbaiki di B-c, bukan disembunyikan):**
- **T1 Tornado tanpa batas.** Rencana B4: "pindah & aktif SEKALI lagi". Kode `pemain.gd` (blok angin)
  memindahkan jebakan SETIAP kali kena, tanpa hitungan -> jebakan angin pemilik Ultimate abadi. Perbaikan:
  field baru `sisa_pindah: int = 0` di `jebakan_angin.gd`, diisi 1 di `_pasang_jebakan` kalau
  `_punya_ultimate(slot,"angin")` (pola SAMA Phoenix `sisa_aktif_ulang`); blok tornado hanya jalan kalau
  `cek_angin.sisa_pindah > 0`, lalu `sisa_pindah -= 1`.
- **T2 Tampilan Guard salah di client.** Kelima cabang Guard (pemain.gd air/angin/api/petir,
  pemain_duel.gd tanah) mengirim `rpc_mainkan_efek_jebakan` biasa -> di client muncul "FIRE TRAP! Burning..."
  + efek bakar menempel di korban (padahal dilindungi), dan untuk Petir antrian langkah client DIKOSONGKAN
  (korban berhenti di layar client, padahal di host jalan terus). Perbaikan di C5 (`rpc_efek_role("guard")`).

**C1. Data murni (`data_role.gd`)** -- fungsi statis baru `build_arena(role: String, simpanan) -> Dictionary`:
kalau `simpanan` Dictionary berisi `"node"` Dictionary DAN `build_sah(node, role, SP_ARENA,
LEVEL_ROLE_MAKS)` -> kembalikan `node.duplicate()`; selain itu -> `build_dari_preset(role, "balanced",
SP_ARENA, LEVEL_ROLE_MAKS)`. SATU sumber, dipakai lobby (kirim & validasi host) dan pemain_role.gd (C2).

**C2. Lobby (`layar_local_play.gd`) + `pemain_role.gd`:**
- `role_peer[id]` jadi `{"role","jebakan","build"}`. Host sendiri & client: saat OK di layar role, build =
  `DataRole.build_arena(role, ProfilPemain.arena.get(role, {}))`.
- `rpc_role_lobby(role, jebakan)` -> `rpc_role_lobby(role, jebakan, build: Dictionary)`; host menyimpan
  `DataRole.build_arena(role, {"node": build})` (validasi ulang -- client bisa mengirim apa saja).
- `_bangun_role_slot`: tiap slot tambah `"build"` -- manusia dari role_peer (divalidasi lagi lewat
  `build_arena(role_s, {"node": d.get("build",{})})`), AI = `build_arena(role_s, {})` (Balanced). Role
  cadangan (role kosong diundi) -> build ikut dihitung dari role BARU itu (bukan build role lama).
- `pemain_role.gd::_siapkan_role_multiplayer`: `daftar_pemain[s].build = DataRole.build_arena(role_s,
  {"node": data_slot.get("build", {})})` (menggantikan `_build_lv1`). Host & client menghitung dari data
  yang SAMA -> hasil sama. `_siapkan_role_solo` TIDAK disentuh.
- Rig: `uji_robot_mp.gd` ikut tanda tangan baru (pelajaran bagian 7) + argumen `arena=attack|defense|
  custom_ilegal` (robot menulis `ProfilPemain.arena[role]` SEBELUM memilih role; `custom_ilegal` = node
  Lv3 semua + Ultimate = jauh di atas 12 SP -> host HARUS jatuh balik ke Balanced). Baris SELESAI mencetak
  build tiap slot (14.5: sama di semua HP & tidak kosong).

**C3. State pemain di siaran (`pemain_role.gd::_kemas_role`/`_terapkan_role`)** -- tambah per slot: `guard_terpakai`,
`sacred_terpakai`, `bakar_per_giliran`, `bakar_pemilik`, `bakar_larang_jebakan`, `kunci_kartu`,
`low_roll_bubble` (Dictionary di-`duplicate()`, baca dengan `.get(..., nilai_lama)` supaya aman).
Alasan per field: client memakai `sacred_terpakai` (teks & aktif tombol "Sacred Earth Trap (FREE)"),
`bakar_larang_jebakan` (tombol Set Trap), `kunci_kartu` (tombol Use Card -- sekarang MENIPU di client);
sisanya wajib untuk host baru (migrasi) & "lanjut sendiri".

**C4. Data jebakan `[petak, nama, pemilik, info]` (`pemain_papan.gd`)** -- fungsi baru di jebakan masing-
masing: `ambil_info() -> Dictionary` & `terapkan_info(d: Dictionary)`:
- api `{aktif_ulang}` (= `sisa_aktif_ulang`); angin `{sisa_pindah}` (T1); petir `{siluman}` (C6);
  tanah `{aktif, sisa_duel, sacred, sisa_tahan_serangan, sudah_duel_pertama}`; air `{}`.
- `_kumpulkan_data_jebakan` menambah `node.ambil_info()` sebagai elemen ke-4. `_terapkan_data_jebakan`:
  elemen ke-4 boleh TIDAK ada (`item.size() > 3`); kunci jadi `petak|nama` -> `[pemilik, info]`; untuk
  jebakan BARU dibuat -> `terapkan_info` SEBELUM `add_child` (supaya `_ready`/siluman benar); untuk jebakan
  yang SUDAH ada -> `terapkan_info` juga (ini yang memunculkan lagi jebakan tanah tersembunyi di client:
  tanah `terapkan_info` dengan `aktif=true` sementara node sedang `aktif=false` -> panggil `aktifkan_kembali()`).
- `rpc_jebakan_dipasang(nama, idx, pemilik, bintang)` -> `+ info: Dictionary`; host mengirim
  `jebakan.ambil_info()`; client `terapkan_info` lalu teks `_teks_jebakan_dipasang(..., info.get("sacred",false))`.

**C5. `rpc_efek_role(jenis: String, data: Dictionary)` satu pintu (`pemain_papan.gd`, authority, reliable)**
-- MURNI tayangan di client (angka resmi tetap dari siaran state). Teks bahasa Inggris sederhana; visual
mewah B5 menyusul B-e. Host mengirim HANYA kalau `peran_multiplayer == "host"`.
- `"guard"` `{elemen, petak, aktor}`: GANTIKAN 5 panggilan `rpc_mainkan_efek_jebakan` di cabang Guard (T2).
  Client: teks "GUARD! <Water/Wind/Fire/Lightning/Earth> Trap blocked!", hapus salinan jebakan di petak itu,
  TIDAK mengosongkan antrian langkah.
- `"tornado"` `{dari, ke}`: dikirim host tepat setelah jebakan pindah; client memindahkan node salinannya
  (`remove_child`/`add_child`, `aktif=true`) + teks "TORNADO! The Wind Trap moved!".
- `"tsunami"` `{geser: [[slot, pos_baru], ...]}`: dikirim host sesudah loop tsunami; client tween 0,6 dtk
  model slot itu ke petak baru (sama persis host).
- `"card_magnet"` `{pencuri, korban}`, `"chain_lightning"` `{sasaran: [slot,...]}`: teks saja.
- `rpc_mainkan_efek_jebakan(nama, idx, aktor)` -> `+ tetap: bool` (SELALU dikirim lengkap, jangan andalkan
  argumen bawaan RPC): host isi `true` untuk Api kalau `sisa_aktif_ulang > 0` (Phoenix) dan Angin kalau
  tornado akan jalan (`sisa_pindah > 0`); client TIDAK `queue_free` kalau `tetap`. Teks Api di client pakai
  `_angka_jebakan(node.pemilik,"api")["bakar_giliran"]` (build tersinkron) -- bukan DASAR (salah untuk long_burn).
- Tanah: `rpc_jebakan_tanah_aktif(idx)` -> `+ bonus_hp: int` (0 = Rock Breaker meniadakan). Host: pindahkan
  `_siarkan_jebakan_tanah_aktif` ke SESUDAH undian Rock Breaker (sekarang dikirim sebelum undi -> client
  selalu melihat "+1 HP"). `jebakan_tanah.gd`: pisahkan hitungan bonus ke `hitung_bonus_hp(main_node) -> int`
  (tanpa efek samping); `aktifkan_pelindung_sementara(main, idx, ui, bonus_hp: int)` menerima angkanya
  (host menghitung sekali & memakai angka yang sama untuk dirinya + RPC). Client bonus 0 -> teks
  "ROCK BREAKER! Earth Trap bonus negated!", jebakan tidak disentuh.

**C6. stealth_charge (`jebakan_petir.gd`, `pemain_papan.gd`)** -- field `siluman: bool = false`; diisi true
di `_pasang_jebakan` kalau `_punya_ultimate(slot,"petir")` (SEMUA jebakan petirnya, sesuai B4). Fungsi
`pemain_papan.gd::_terapkan_siluman(node)`: kalau `node.siluman and node.pemilik != slot_lokal` ->
sembunyikan visual (juga di solo terhadap AI). Dipanggil sesudah pasang (host/solo), di `rpc_jebakan_dipasang`,
dan `_terapkan_data_jebakan`. Teks pemasangan untuk LAWAN: tidak ditampilkan sama sekali (bintang turun =
kebocoran kecil yang diterima, sama seperti tombol Set Trap mati di petak itu). Saat kena -> tampil normal.

**C7. Perbaikan T1** (lihat atas) -- dikerjakan bersama C4 karena `sisa_pindah` ikut `info` angin.

**C8. Verifikasi (sebelum kirim):**
- `godot --import` bersih; regresi solo `uji_nyata.gd` (0 SCRIPT ERROR + STAT_CEK OK) -- solo tidak boleh berubah.
- Multiplayer nyata `jalankan_mp3.sh` (ENet sungguhan, beberapa proses): 2P/3P/4P, 2 peta, skenario migrasi
  host (keluar di tengah) -- `cek_gagal=0` dengan PERBANDINGAN state DIPERLUAS (build + 7 field C3 + info
  tiap jebakan ikut dibandingkan host vs client di `uji_robot_mp.gd`), build SELESAI sama semua HP &
  tidak kosong, `arena=custom_ilegal` -> build host = Balanced (bukti validasi).
- Sekali pakai (hapus sesudahnya, pelajaran 14.12): counter `_tambah_stat` sementara di cabang Guard/Tornado/
  Phoenix/Tanah-bonus-0 untuk membuktikan jalurnya BENAR-BENAR terlewati di match MP (Balanced 12 SP berisi
  Ultimate + node Lv1-2, jadi Phoenix/Tornado/Sacred/stealth memang bisa muncul).
- Set kiriman: 28 + `jebakan_angin.gd` + `jebakan_petir.gd` = **30 file** (keduanya belum pernah diubah
  sejak 20-09, baru masuk set sekarang karena disentuh C4/C6/T1).

**Di LUAR lingkup B-c (jangan dikerjakan):** AI membaca build (B-d), layar pohon/ARENA & visual B5 (B-e),
build solo/XP role -> build (B-d/B-e), celah AI tidak memakai Sacred Ground (B-d).

### 14.15 B-c (jaringan) SELESAI, C1-C8 -- 26-09
Dieksekusi Sonnet mengikuti 14.14 APA ADANYA, satu langkah diverifikasi rig sebelum lanjut (pola 14.6).
File berubah: `pemain_papan.gd`, `pemain.gd`, `pemain_duel.gd`, `jebakan_tanah.gd`, `jebakan_air.gd`,
`jebakan_api.gd`, `jebakan_angin.gd`, `jebakan_petir.gd`, `pemain_role.gd`, `data_role.gd`,
`layar_local_play.gd` (11 file produksi). Rig-only (tidak ikut ZIP): `uji_robot_mp.gd`, `uji_tanah.gd`,
`uji_tanah2.gd`, `jalankan_mp3.sh`.

**C1 (`data_role.gd::build_arena`)** -- SATU sumber build Arena: `build_sah(...)` sah -> pakai build
kiriman; tidak sah/kosong -> jatuh balik preset Balanced 12 SP (K16). Dipakai lobby (kirim & terima) DAN
`pemain_role.gd::_siapkan_role_multiplayer`.

**C2 (`layar_local_play.gd`)** -- build_arena dipanggil di 3 titik (bertahan berlapis, client bisa
mengirim apa saja): (1) saat pemain pilih role di lobby (host & client, dari `ProfilPemain.arena` milik
sendiri), (2) `rpc_role_lobby` sisi host memvalidasi ULANG kiriman client, (3) `_bangun_role_slot` saat
START memvalidasi ULANG lagi (role yang diundi cadangan dihitung ulang dari role BARU; slot AI selalu
Balanced, tidak punya `arena` tersimpan).

**C3 (`pemain_role.gd::_kemas_role`/`_terapkan_role`)** -- 7 field `data_pemain.gd` Langkah B yang
efeknya sudah aktif sejak B-b tapi belum ikut siaran: `guard_terpakai`, `sacred_terpakai`,
`bakar_per_giliran`, `bakar_pemilik`, `bakar_larang_jebakan`, `kunci_kartu`, `low_roll_bubble`. Dibaca
lewat `.get(..., nilai_lama)` (aman kalau pengirim versi lama). `migrasi_host.gd` tidak disentuh -- host
baru pakai `daftar_pemain` miliknya sendiri, sudah lengkap dari `_terapkan_role` terakhir sebelum host
lama putus.

**C4 (`pemain_papan.gd::_kumpulkan_data_jebakan`/`_terapkan_data_jebakan` + tiap `jebakan_*.gd`)** --
elemen ke-4 (`info`, dari `ambil_info()`/`terapkan_info()` polimorfik per jenis) ditambahkan ke data
jebakan yang disiarkan, OPSIONAL (`item.size() > 3`, data lama tanpa info tetap aman). Menutup celah nyata:
jebakan tanah yang tersembunyi (Sacred Ground) bisa balik terlihat salah di client karena field itu
sebelumnya tidak pernah disinkronkan ulang. Diterapkan SEBELUM `add_child` untuk jebakan baru (siluman
langsung benar sejak awal) dan juga untuk jebakan yang sudah ada (perbaiki mismatch).

**C5 (`rpc_efek_role` + perluasan `rpc_mainkan_efek_jebakan`)** -- satu pintu RPC efek dict-payload
(`guard`/`tornado`/`tsunami`/`card_magnet`/`chain_lightning`) gantikan banyak variasi panggilan lama;
`tetap: bool` SELALU dikirim tegas (bukan default arg) supaya client tidak menghapus jebakan Phoenix/Tornado
yang sedang "hidup lagi". Tanah: `bonus_hp` dihitung SEKALI (`hitung_bonus_hp`, murni tanpa efek samping)
SESUDAH undian Rock Breaker, dipakai IDENTIK untuk RPC maupun efek lokal -- host & client tidak mungkin
desync soal angka ini (bukti-lewat-konstruksi, bukan cuma bukti-lewat-pengamatan). Detail penuh & kode di
riwayat kerja sesi ini (lihat commit/checkpoint C5).

**C6 (`jebakan_petir.gd` + `pemain_papan.gd::_terapkan_siluman`)** -- Ultimate stealth_charge: SEMUA
jebakan petir pemasangnya jadi `siluman=true`; disembunyikan (mesh & efek) dari siapa pun selain pemilik,
termasuk solo vs AI (`node.visible = not (siluman and pemilik != slot_lokal)`, dicek per-viewer, tidak
perlu jaringan tambahan). Teks pemasangan untuk lawan tidak tampil sama sekali (bintang tetap turun --
kebocoran kecil yang diterima).

**C7 (perbaikan bug T1, `pemain.gd`)** -- Tornado (Ultimate Angin) dulu digerbang `bool(tornado)` SAJA ->
jebakan pindah & aktif lagi TANPA BATAS setiap kali kena (menyalahi rencana "sekali lagi"). Sekarang
digerbang `cek_angin.sisa_pindah` (diisi 1 di `_pasang_jebakan` kalau pemasang punya Ultimate Angin, pola
identik Phoenix `sisa_aktif_ulang`) -- berkurang 1 tiap kena, habis = jebakan hilang seperti biasa.

**C8. Verifikasi -- ringkasan temuan (26-09):**
- `godot --headless --import` bersih (0 SCRIPT ERROR) di `proj` & `proj_tanpa_uji` di SETIAP langkah C1-C7
  dan lagi di akhir sesudah bersih-bersih counter sementara.
- Regresi solo penuh (9 skenario `batch_reg10.sh`: takeover/solo/kartu/koin/pedang/pedang_tonton/tanah2/
  kamera_hud/cabang) -- 0 GAGAL semua. RNG determinisme dicek 2 skenario (air/angin, 5 seed) lewat
  `rng_setelah` (state RNG akhir): **identik byte-per-byte di ke-5 seed keduanya** -- C1-C8 TIDAK menambah/
  mengurangi satu pun undian acak. `uji_angin_solo` teks/besaran koin (`koin tersisa`/`uang korban`/teks
  "Enemy found"/"You found") BEDA dari referensi `rng_r4` (berkas 20-09, SEBELUM Bagian B-b/B-c ada) --
  dicek TIDAK terkait perubahan C1-C8 manapun (grep: fitur koin tercecer & tekstnya tidak disentuh sesi
  ini); referensi itu sekadar basi, sebaiknya di-refresh sesi lain (di luar lingkup B-c).
- Perluasan perbandingan state `uji_robot_mp.gd::_potret()` -- build + 7 field C3 + `info` tiap jebakan,
  host vs client, dibandingkan tiap siaran state.
- Guard (`rpc_efek_role "guard"`) **terbukti live** 3 match MP terpisah (build khusus rig, ketahanan Lv3 +
  Ultimate + 1 node jebakan, 12 SP pas): `cek_c5_guard=1` per match, `cek_gagal=0`. Ini yang tervalidasi
  paling penting -- membuktikan arsitektur dict-payload `rpc_efek_role` end-to-end sekaligus perbaikan T2.
- Phoenix (Ultimate Api) **terbukti live 5x** lewat 4 match MP terpisah **dengan build Balanced 12 SP baku**
  (bukan build khusus) -- migrasi host (`cek_c5_phoenix=1`, dilihat dari 3 sisi client sesudah host lama
  putus), 3P (`=2`), pantai (`=1`), custom_ilegal (`=1`); semua `cek_gagal=0`. Membuktikan Balanced BENAR
  membawa Ultimate (K16, sesuai catatan 14.14) dan Phoenix sungguhan terpicu di gameplay AI-vs-AI biasa.
- Migrasi host: **`migrasi=1`, `cek_ok_migrasi=16`, `cek_gagal=0`** (skenario `host_keluar_migrasi`, 4P,
  giliran 8) -- state (termasuk 7 field C3 & info jebakan C4) tetap sinkron sesudah host baru mengambil
  alih.
- 3P (`mode=3`, peta alam): `cek_ok=22, cek_gagal=0, scripterr=0`.
- Peta pantai (`mode=0`, `peta=pantai`): `cek_ok=12, cek_gagal=0, scripterr=0`.
- `arena=custom_ilegal` re-konfirmasi: `data_role.gd::build_arena` (dipanggil C1/C2) balik ke preset
  Balanced 12 SP persis (build host sama numeriknya dengan 3 match lain yang memang minta Balanced) --
  `cek_gagal=0, scripterr=0`. Build ilegal (semua node Lv3+Ultimate, jauh di atas 12 SP) tidak pernah
  dipakai sebagai apa adanya.
- Tornado & Rock-Breaker-negasi (bonus_hp=0) **TIDAK terpicu live sesi ini** -- Tornado terbukti SECARA
  KODE tidak mungkin dites lewat rig robot 4-role: `_pasang_jebakan` mensyaratkan `_punya_ultimate(slot,
  "angin")`, dan tidak ada satupun dari 4 slot (host+3 client) yang PERNAH mendapat role "angin" --
  `uji_robot_mp.gd` menetapkan role deterministik dari `DataRole.ROLE[indeks % 5]` = api/air/tanah/petir
  untuk indeks 0-3; role ke-5 (angin) butuh slot ke-5 yang tidak ada di mode terbesar (4 PLAYERS, maks 3
  client). Ini keterbatasan HARNESS, bukan cacat kode -- jalur `rpc_efek_role "tornado"` memakai arsitektur
  dict-payload IDENTIK dengan Guard/Phoenix yang sudah terbukti. Rock-Breaker-negasi butuh Tanah trap
  benar2 kena (jarang dipasang & dipijak robot walau gerbang frekuensi sudah dilonggarkan + Tanah ditambah
  ke kandidat -- perbaikan rig permanen, disimpan di `uji_robot_mp.gd`); mekanisme rollnya sendiri (50%
  Lv1, `ROCK_BREAKER_LV`) sudah diverifikasi DETERMINISTIK di 14.13 (rig `maks_lv`, SEBELUM sesi B-c ini,
  tidak disentuh perubahan C5) -- C5 hanya memindah waktu siar & satu-sumber-kan `bonus_hp`, dibuktikan
  lewat konstruksi (lihat C5 di atas), bukan lewat pengamatan acak.
- Counter `_tambah_stat("cek_c5_*")` sementara (8 baris, `pemain.gd` x6 + `pemain_duel.gd` x2) sudah
  DIHAPUS dari kedua file produksi sebelum ZIP ini; rig-only (`uji_robot_mp.gd`: blok cetak `CEK_C5`,
  preset uji `custom_guard`) DIBIARKAN (tidak pernah ikut ZIP, tidak ada risiko kirim). Perbaikan rig
  permanen yang DISIMPAN (murni menguntungkan sesi uji berikutnya, tidak pernah ikut ZIP): `jalankan_mp3.sh`
  meneruskan `$EXTRA` ke proses client juga (dulu cuma host); `uji_robot_mp.gd` melonggarkan gerbang
  frekuensi pasang-trap & menambahkan tombol Trap Tanah ke kandidat (dulu robot TIDAK PERNAH mencoba Tanah
  sama sekali).
- Set kiriman: 28 file rantai/pendukung (termasuk `jebakan_angin.gd`/`jebakan_petir.gd`, sesuai 14.14) +
  `jebakan_dasar.gd` (dependensi `class_name JebakanDasar` yang dipakai `jebakan_air.gd`, ternyata SELAMA
  INI tidak pernah ikut set kiriman manapun -- ditemukan & diputuskan ikut sekarang, lihat catatan) =
  **29 file .gd**, + `RENCANA_fase4_role.md` = **30 file** dalam `TileDuel_FaseB_b7.zip`. Ini beda +1 file
  dari target "30" tertulis di 14.14 (yang tidak menghitung `jebakan_dasar.gd` maupun dokumen RENCANA
  sendiri) -- dicatat di sini, bukan disembunyikan, sesuai pola "BERHENTI & catat" 14.14.

**Selanjutnya: B-d** -- AI membaca build (termasuk celah `ai_jebakan.gd` tidak memakai Sacred Ground),
lalu B-e (layar pohon/ARENA & visual, build solo/XP role -> build), B-f (rig+Opus U9, tinjau keseimbangan
penuh).

### 14.16 Tinjauan Opus + rencana TERKUNCI B-d (AI baca build) -- 26-09
Ditulis Opus setelah membaca kode sungguhan: `ai_jebakan.gd`, `ai_musuh.gd`, `pemain_role.gd`, `data_role.gd`,
`pemain_papan.gd` (`_pasang_jebakan` dan menu Set Trap), titik picu jebakan di `pemain.gd`, `pemain_duel.gd`
(`_mulai_duel`/`_hasil_duel_petak`), `jebakan_tanah.gd` (`hitung_bonus_hp`), `layar_local_play.gd`
(`_bangun_role_slot`), serta rig `uji_nyata.gd`/`uji_robot_mp.gd`/`batch_reg10.sh`/`jalankan_mp3.sh`.

Sonnet mengeksekusi D0-D7 APA ADANYA, satu langkah diverifikasi rig sebelum lanjut (pola 14.6/14.14). Kalau
kode ternyata beda dari yang tertulis di sini: BERHENTI & catat, jangan mengarang jalan lain. Nomor baris =
kode 26-09 sesudah B-c; cari dengan TEKS, bukan nomor. Edit HANYA baris/bagian yang disebut, jangan menulis
ulang file.

**STATUS: K17-K19 DISETUJUI user 26-09 -- semua opsi (a) (saran Opus).** D0-D7 siap dieksekusi Sonnet APA
ADANYA, tanpa perlu balik ke Opus dulu.

**Temuan tinjauan (melanjutkan T1/T2 dari 14.14):**
- **T3.** AI belum membaca build sama sekali. `_angka_jebakan` punya 0 pemanggil di `ai_jebakan.gd`/
  `ai_musuh.gd`. Nilai jebakan memakai `DataRole.DASAR` ditambah potongan flat `BOBOT_TAHAN_AI` lewat
  `role_tahan_elemen` (per ROLE, bukan per level build). Akibatnya node pemasang milik AI (hot_flames,
  shock, dst.) dan level ketahanan korban (Lv2/Lv3/Guard) tidak pernah terbaca.
- **T4.** Bobot petir 0,1 dan tanah 0,05 disetel U3 SEBELUM K13/K14. Sejak B-b, Grounded Lv1 = giliran
  lumpuh 2 jadi 1; Rock Breaker Lv1 = peluang 50% bonus HP tanah batal. Keduanya SUDAH aktif di solo
  sekarang (Lv1 gratis dari `_build_lv1`). AI masih menilai petir terhadap Tanah/Angin 90% dan tanah
  terhadap Api/Air 100% -- arahnya salah.
- **T5.** Sacred Ground sebenarnya SUDAH terpakai AI di multiplayer, tapi tidak sengaja: `_pasang_jebakan`
  otomatis gratis kalau `_sacred_tersedia` true, jadi jebakan tanah PERTAMA yang dipilih AI Tanah (Balanced
  12 SP membawa Ultimate, K16) lewat jalur nilai biasa otomatis jadi Sacred, di petak sendiri mana pun
  (termasuk menara Lv0). Yang benar-benar tidak ada: pemasangan saat bintang 0-1, dan pemilihan petak yang
  pantas.
- **T6.** Teks pemasangan AI (`_teks_jebakan_dipasang`) tidak mengirim parameter sacred -> teks "Earth Trap
  set!" padahal jebakan itu Sacred. Client sudah benar lewat `info.sacred` (C4).
- **T7.** Fight AI hanya tahu ada/tidaknya jebakan tanah (peluang dibagi dua) -- tidak membaca hard_rock
  Lv3, stone_thorns pemilik petak, Rock Breaker/Guard milik AI sendiri. `logika_ai_fase_awal` memanggil
  `pengali_kalah_duel` tanpa argumen ke-3.
- **T8.** Bagian 6 ("serangan jarak jauh AI melewati petak Fortress") belum dikerjakan di bagian 4b -- AI
  tetap membidik & membuang 5 bintang ke petak Fortress.
- **T9.** Jebakan bawaan AI tidak melihat semua lawan (lobby `_bangun_role_slot` memanggil
  `_jebakan_sah_lobby(role, [])`; solo `_siapkan_role_solo` membaca role slot yang belum diisi di 3-4
  pemain) -- menyimpang dari A6/bagian 6.

**K17 (BUTUH PERSETUJUAN user) -- cara AI menilai ketahanan korban per level, termasuk Guard.**
(a, saran Opus) Keputusan PASANG (`ai_jebakan.gd`, per korban) pakai MEKANIK ASLI yang sama dengan efeknya:
Guard belum terpakai -> nilai korban 0 (kebal); api/angin -> x(1 - `potongan_tahan`), 0/25/50/50%; air ->
tetap `_durasi_gelembung`; petir -> BERHENTI 75 + LEWAT_GILIRAN 75x(sisa-1), Grounded Lv2+ boleh Fight ->
denda petak x0,5; tanah -> bonus HP x(1-0,5) kalau Rock Breaker korban >=1, pengali kalah duel dari
`pengali_kalah_duel(lv_rb_korban, true, stone_thorns_AI)`. Keputusan BAWA (`jebakan_bawaan_ai`, sekali di
awal, belum ada papan) pakai tabel kasar `bobot_tahan_ai(elemen, lv)`: Lv0=0, Lv1=`BOBOT_TAHAN_AI`,
Lv2/Lv3=2x (maks 0,5), Guard diabaikan (cuma menahan 1 jebakan). `BOBOT_TAHAN_AI` petir 0,1->0,5, tanah
0,05->0,5 (T4). AI baca build & `guard_terpakai` lawan langsung dari `daftar_pemain` (host sudah memegang
data ini sejak B-c, tidak ada RPC baru). Akibat terlihat pemain (berlaku di solo SEKARANG juga): AI jauh
lebih jarang memasang petir ke Tanah/Angin dan tanah ke Api/Air; AI tidak pernah memasang jenis X ke korban
yang Guard-X-nya belum terpakai (di 2P berarti sepanjang pertandingan -- diterima, Lv3 berharga 6 SP,
disetel lagi di B-f/U9 kalau perlu).
(b) Rumus 14.2 harfiah saja (bobot flat x level, Guard=0) tanpa memecah petir/tanah -- perubahan lebih
sedikit tapi AI tetap salah menilai Grounded/Rock Breaker versi K13/K14, dan U9 akan mengukur kesalahan AI
bukan keseimbangan.

**K18 (BUTUH PERSETUJUAN user) -- kapan AI memasang Sacred Ground.**
(a, saran Opus) Cabang KHUSUS di awal `pertimbangkan`: prioritas nomor 1, TANPA gerbang bintang & TANPA
undian `mesin_acak`, hanya kalau `_sacred_tersedia`+`_jebakan_boleh`+`_boleh_tanah_di`+
`_boleh_pasang_jebakan_di(slot,true)` semua terpenuhi DAN menara petak >= Lv1 (`AMBANG_MENARA_SACRED=1`).
Selama Sacred masih tersedia, jalur nilai biasa TIDAK memilih tanah (mencegah T5 -- Sacred terbuang di
petak murah). Alasan: Sacred sekali per pertandingan, bertahan sampai petak ganti pemilik, bawa Fortress
Lv2 -- paling berharga di petak bermenara. Sama seperti manusia (tombol "Sacred Earth Trap (FREE)" selalu
didahulukan).
(b) Ikut skema nilai biasa dengan biaya 0 (= perilaku tidak sengaja sekarang, T5).
(c) Langsung di petak sendiri pertama yang diinjak -- paling sederhana, paling boros.
Terlihat di multiplayer sekarang (AI Tanah Balanced 12 SP); di solo baru terlihat sesudah B-e (Ultimate
butuh Level Role 15).

**K19 (BUTUH PERSETUJUAN user) -- Fight AI membaca jebakan tanah milik pemilik petak.**
(a, saran Opus) Peluang Fight lama (Lv2 100/Lv1 55/Lv0 50) dikali faktor kontinu `_faktor_fight_tanah` (D5),
TANPA ambang batal: `faktor = clamp(0,5^hp_harapan x (1,2/pengali_kalah), 0, 1)`. Dasar (+1 HP, tanpa Rock
Breaker) = 0,5 PERSIS perilaku sekarang. Contoh: Rock Breaker Lv1 -> 0,71 (70/38/35); hard_rock Lv3 +
stone_thorns Lv3 -> 0,10 (10/5/5); Guard tanah AI belum terpakai -> faktor 1 (kebal). Tanpa ambang karena:
dengan ambang, petak Sacred+hard_rock jadi KEBAL selamanya dari AI -- bertentangan dengan bagian 1 ("petak
tetap bisa direbut lewat duel").
(b) Ambang batal: faktor < 0,15 -> AI tidak pernah Fight di petak itu.
Sudah terlihat di solo sekarang: AI Api/Air (Rock Breaker Lv1 gratis) lebih sering Fight di petak
ber-jebakan tanah (menara Lv1: 27% -> 38%).

**P1 (Opus menyetel, tanpa persetujuan) -- pemasang vs korban di tiap titik panggil AI:** tabel lengkap ada
di laporan kerja; intinya `_angka_jebakan(slot AI,...)` dipanggil SEKALI per elemen di luar loop lawan;
`_faktor_fight_tanah` DILARANG memanggil `_angka_jebakan` (baca `hitung_bonus_hp`/`_stone_thorns_p_di` yang
sudah murni); fungsi yang punya efek samping stat (`_kurangi_tahan`, `_pengali_kalah_duel`, `_pakai_guard`)
DILARANG dipanggil dari `ai_*.gd` untuk MENILAI.

**P2 (Opus menyetel) -- AI multiplayer ikut kena.** Semua keputusan AI jalan di HOST lewat `AiMusuh`/
`AiJebakan` yang sama untuk slot AI lobby, pemain yang diambil-alih AI, dan "lanjut sendiri" -- build
multiplayer sudah aktif sejak B-c jadi efek B-d langsung terlihat di sana. JANGAN tambah cabang
`peran_multiplayer` di fungsi penilaian; tidak ada RPC/siaran baru. D7 WAJIB menyertakan multiplayer.

**P3 (Opus menyetel) -- serangan jarak jauh AI melewati petak Fortress** (bagian 6, T8), lewat fungsi murni
baru `_benteng_aktif` (D2), syarat identik label "Protected".

**P4 (Opus menyetel) -- `logika_ai_fase_awal` baca stone_thorns** (T7): tambah argumen ke-3, tanpa
stone_thorns hasilnya identik sekarang.

**P5 (Opus menyetel) -- jebakan bawaan AI baca SEMUA lawan** (T9, sesuai A6/bagian 6): lobby & solo
dikerjakan dua putaran (role+build dulu, jebakan sesudahnya); solo 2 pemain hasil identik sekarang.

**P6 (Opus menyetel; koreksi urutan 14.6) -- K1 (AI solo = Balanced sesuai Level Role pemain) DIPINDAH ke
B-e**, karena pemain solo baru punya build di B-e -- kalau AI diganti duluan, di Level Role rendah AI malah
KEHILANGAN ketahanan Lv1 gratisnya (di Level Role tinggi AI jadi jauh lebih kuat dari pemain). Di B-d, solo
tetap `_build_lv1`.

**D0. Rig pembanding (HANYA scratchpad, TIDAK ikut ZIP) -- SEBELUM ubah file produksi apa pun:** tambah
`preset=balanced|attack|defense`+`sp=N` dan pemindai papan (`JEBAKAN_AI s=.. e=.. petak=.. menara=..
sacred=0|1`) ke `proj/uji_nyata.gd`; sinkron; salin `proj_tanpa_uji` jadi `proj_sebelum_bd` (pembanding
beku); jalankan pembanding M1-M5 (lihat D7) di sana dan simpan lognya.

**D1. `data_role.gd`:** `BOBOT_TAHAN_AI` petir 0,1->0,5, tanah 0,05->0,5 (K17); fungsi baru
`bobot_tahan_ai(elemen, level)`; `jebakan_bawaan_ai` +parameter ke-4 `build_lawan: Array = []` (bawaan
kosong, pemanggil lama tetap sah); `_jumlah_menahan` baca level node lawan dari `build_lawan[i]` kalau ada,
else fallback role_tahan_elemen lama. JANGAN ubah `potongan_tahan`/`pengali_kalah_duel`/`NODE_LV`/preset.

**D2. `pemain_role.gd`:** fungsi murni baru `_benteng_aktif(petak) -> bool` (dipakai `_benteng_menahan`
tanpa ubah perilaku); `_siapkan_role_solo` dipecah 2 putaran (role+build dulu, jebakan_bawaan_ai dgn
build_lawan sesudahnya, urutan undian sama). JANGAN ubah `_angka_jebakan`/`_guard_boleh`/`_sacred_tersedia`
dkk.

**D3. `layar_local_play.gd::_bangun_role_slot`:** dipecah 2 putaran (build semua slot dulu, lalu
jebakan_bawaan_ai dgn build_lawan utk slot AI / `_jebakan_sah_lobby` seperti biasa utk slot manusia). JANGAN
ubah `_jebakan_sah_lobby`/`rpc_role_lobby`/tanda tangan RPC.

**D4. `ai_jebakan.gd`:** konstanta nilai baru (`NILAI_PETIR_BERHENTI`, dst, lihat laporan lengkap); hapus
`NILAI_PETIR_LUMPUH`; fungsi baru `_nilai_korban`, `_nilai_tanah`, `_sacred_layak`, `_pilih_elemen_biasa`
(isi dari blok 107-179 lama, dipindah & diubah sesuai K17/K18); `pertimbangkan` pakai `_sacred_layak` dulu
baru `_pilih_elemen_biasa`; perbaikan T6 (kirim flag sacred ke `_teks_jebakan_dipasang`). Pengingat tipe
GDScript 4: `:=` dari nilai Variant = SCRIPT ERROR, pakai tipe eksplisit/`float()`/`int()`.

**D5. `ai_musuh.gd`:** fungsi baru `_faktor_fight_tanah` (lihat rumus K19); `logika_ai_musuh_setelah_jalan`
pakai faktor ini menggantikan gerbang tanah biner lama; `logika_ai_fase_awal` +argumen ke-3 stone_thorns
(P4); pemilihan target serangan jarak jauh melewati petak `_benteng_aktif` (P3). File mungkin read-only
(`-r--r--r--`) -- `chmod u+w` kalau perlu, catat. JANGAN ubah baris `randi()` global (di luar lingkup, lihat
bawah).

**D6. Rig fungsi baru + counter sementara:** `uji_nyata.gd` argumen `cek_nilai=1` (jalankan kasus tabel D7
langsung ke fungsi murni baru, cetak OK/GAGAL lalu keluar); `uji_robot_mp.gd` argumen `role_ai=<r>[,<r>]` +
cetak `CEK_BD_JEBAKAN_AI`. Counter sementara DI PRODUKSI (WAJIB dihapus sebelum ZIP, pelajaran 14.12):
`cek_bd_sacred`, `cek_bd_guard_nol`, `cek_bd_fight_faktor`, `cek_bd_benteng_lewati`,
`cek_bd_benteng_tahan_ai`.

**D7. Verifikasi (sebelum kirim) -- ringkas (detail penuh & angka pasti di laporan kerja sesi ini):**
1. Import bersih 0 SCRIPT ERROR tiap langkah D1-D6; `cek_nama_ganda.py` lolos; grep pemastian fungsi
   lama/baru terpakai/tidak terpakai sesuai daftar di atas.
2. `cek_nilai=1`: semua kasus tabel (api/angin/air/petir/tanah/`_faktor_fight_tanah`/`jebakan_bawaan_ai`,
   nilai persis ada di laporan kerja) = OK.
3. Regresi solo `batch_reg10.sh` = 0 GAGAL; RNG boleh beda dari B-c (dijelaskan di risiko di bawah).
4. AI-vs-AI nyata `proj_tanpa_uji` vs `proj_sebelum_bd` (benih 301-312, 2 peta, Quick 2P `semua_ai=1`) = 0
   SCRIPT ERROR + STAT_CEK OK, DAN skenario M1-M5 (jumlah jebakan petir/tanah turun sesuai K17; Sacred hanya
   di menara>=1 & minimal 1x di 12 pertandingan; Fortress dilewati & tidak pernah "tertahan" AI; Guard api
   slot pemasang bikin AI TIDAK PERNAH pasang api lawan itu) semua terbukti sesuai target di laporan kerja.
5. Multiplayer `jalankan_mp3.sh` (mode 2P+2AI & 3P+1AI 2 peta, client keluar diambil AI, migrasi host) =
   `cek_gagal=0`, `scripterr=0`, `CEK_BD_JEBAKAN_AI OK`, `cek_bd_sacred>=1` di minimal 1 match.
6. Bersih-bersih: grep `cek_bd_` di `/home/claude` = 0; sinkron+import+regresi pendek ulang.
7. Set kiriman: TETAP 29 .gd + RENCANA = 30 file (5 berubah: `data_role.gd`, `pemain_role.gd`,
   `layar_local_play.gd`, `ai_jebakan.gd`, `ai_musuh.gd`). **B-d tidak boleh dirilis sendirian** (sama
   seperti B-c).

**Risiko RNG diterima (bukan disembunyikan):** tidak ada undian baru/global baru, tapi urutan `mesin_acak`
BISA bergeser karena (1) nilai pasang berubah -> undian AMBANG_PELUANG terjadi/tidak terjadi berbeda
(berlaku solo SEKARANG utk petir/tanah, multiplayer utk semua build); (2) cabang Sacred tanpa undian; (3)
Fight dgn faktor != 0,5/1,0 mengubah peluang (jumlah undian sama, Guard tanah AI di menara Lv2 bikin undian
hilang total); (4) petak Fortress dilewati -> undian target bisa hilang/beda; (5) jenis bawaan beda di solo
3-4 pemain. TIDAK berubah di solo sebelum B-e: Sacred (solo belum punya Ultimate), Fortress, nilai node
penyerang (AI solo masih Lv0) -- semua baru terlihat di multiplayer & rig.

**Di LUAR lingkup B-d (jangan dikerjakan):** build solo pemain & K1 AI solo (P6, masuk B-e); layar
pohon/ARENA & tayangan B5; AI menghindari jebakan saat pilih cabang (bagian 12); AI melihat jebakan siluman;
penilaian node kecil (whirlwind, larangan long_burn, chain_lightning, tsunami, stealth_charge -- AI tetap
bawa/pasang jenisnya, cuma komponen nilai itu belum dihitung, ditinjau B-f); `ai_musuh.gd` baris 173
`randi()` global pilih kartu AI (melanggar aturan `mesin_acak` tapi cuma jalan di host jadi tidak
menyebabkan desync -- memperbaikinya menggeser RNG solo, butuh keputusan user tersendiri, di luar B-d).

**Arahan model:** D0-D7 dikerjakan Sonnet. Pindah ke Opus lagi kalau: user pilih selain (a) di K17-K19 dan
perlu penyesuaian rencana; ada `cek_nilai` GAGAL yang bukan salah ketik; M3/M5 tidak memenuhi syarat; AI
bertingkah aneh/berulang; ada beda state antar-HP di multiplayer.

**Selanjutnya:** **B-e** -- layar pohon+ARENA (B2), tombol ROLES, tayangan B5+versi Very Low, build solo
pemain dari profil, K1 AI solo Balanced sesuai Level Role pemain (dipindah dari B-d, P6; butuh K baru soal
build solo bawaan utk profil kosong, karena di Langkah B Level Role 1 = 1 SP saja, ketahanan Lv1 gratis dari
Langkah A hilang). **B-f** -- rig lengkap U1-U11 + `cek_panggil.py`, Opus U9 tinjau keseimbangan penuh
(termasuk setel ulang K17-K19 & `BOBOT_TAHAN_AI`, K11).

### 14.17 B-d (AI membaca build) SELESAI, D0-D7 -- 26-09
Dieksekusi Sonnet mengikuti 14.16 APA ADANYA, satu langkah diverifikasi rig sebelum lanjut (pola 14.6/14.14).
File berubah: `data_role.gd`, `pemain_role.gd`, `layar_local_play.gd`, `ai_jebakan.gd`, `ai_musuh.gd` (5 file
produksi -- SAMA seperti target 14.16, tidak ada file produksi baru/hilang). Rig-only (tidak ikut ZIP):
`uji_nyata.gd` (D0 board scanner + D6 `cek_nilai=1`), `uji_robot_mp.gd` (D6 `role_ai=` + cetak
`CEK_BD_JEBAKAN_AI`/`CEK_BD`).

**D1-D5 (ringkas, kode di riwayat kerja sesi ini):**
- **D1** `data_role.gd` -- `BOBOT_TAHAN_AI` petir 0,1->0,5, tanah 0,05->0,5 (K17a); `bobot_tahan_ai(elemen,
  level)` baru (tabel flatter, HANYA dipakai keputusan "jebakan mana dibawa" pra-match); `jebakan_bawaan_ai`/
  `_jumlah_menahan` +param ke-4 `build_lawan` opsional.
- **D2** `pemain_role.gd` -- `_benteng_aktif(petak)` baru (versi murni `_benteng_menahan`, tanpa mengurangi
  jatah tahan -- dipakai D5 lihat status Fortress tanpa ikut memakainya); `_siapkan_role_solo` dipecah 2
  putaran (role dulu, baru `build_lawan` dari SEMUA slot).
- **D3** `layar_local_play.gd::_bangun_role_slot` -- pola pecah 2-putaran yang sama seperti D2, untuk slot MP.
- **D4** `ai_jebakan.gd` -- `NILAI_PETIR_BERHENTI`(75)+`NILAI_PETIR_LEWAT_GILIRAN`(75) gantikan
  `NILAI_PETIR_LUMPUH` flat; `AMBANG_MENARA_SACRED`(1); `_nilai_korban`/`_nilai_tanah` (nilai per-korban
  pakai mekanik SUNGGUHAN, K17a); `_sacred_layak`/`_pilih_elemen_biasa` baru; `pertimbangkan` ditulis ulang --
  Sacred Ground jadi cabang prioritas #1 MUTLAK (tanpa gerbang bintang/undian, K18a) kalau layak.
- **D5** `ai_musuh.gd` -- `_faktor_fight_tanah` baru (faktor kontinu 0-1 TANPA ambang batal, K19a); Fortress
  (petak "Protected") dilewati dari kandidat serangan jarak jauh di `logika_ai_fase_awal` (P3); `stone_thorns`
  SUNGGUHAN masuk ke `pengali_kalah_duel` (dulu selalu dasar); keputusan Fight di
  `logika_ai_musuh_setelah_jalan` pakai `peluang_dasar x faktor_tanah` (dulu gerbang biner ada/tidak jebakan).

**Verifikasi (D7):**
- Import bersih (0 SCRIPT ERROR) di `proj` & `proj_tanpa_uji`, di SETIAP langkah D1-D6 dan lagi sesudah
  bersih-bersih D7.6.
- `cek_nilai=1` (uji matematis langsung, D6): **5/5 OK**, cocok PERSIS dengan 3 contoh hitung manual K19a
  (`faktor_fight_tanah` dasar=0,5000; +RockBreaker Lv1=0,7071; hard_rock3+stone_thorns3=0,1000) + 2 contoh
  K17a (`nilai_korban` Guard-kebal-api=0,0000; api-potongan Lv1=135,0000). Diulang lagi SESUDAH D7.6 (baris
  counter dihapus) -- angka identik, membuktikan penghapusan counter tidak mengubah logika.
- Regresi solo `batch_reg10.sh` (9 skenario): **0 GAGAL**, sebelum & sesudah D7.6. RNG: `uji_air_solo` sama
  dengan referensi `rng_r4`; `uji_angin_solo` BEDA -- **diterima, sesuai "Risiko RNG diterima" 14.16 sendiri**
  (nilai petir/tanah berubah -> undian AMBANG_PELUANG solo bergeser).
  AI-vs-AI (`proj_tanpa_uji` vs `proj_sebelum_bd` beku, M1-M5 x seed 301-303 = 15 run): 0 SCRIPT ERROR semua;
  tren jumlah jebakan petir/tanah turun (sesuai K17a); Sacred terbukti menyala di skenario M3 (menara>=1,
  solo/AI-vs-AI, di luar `cek_bd_` -- lewat teks pemasangan jebakan).
- MP (`jalankan_mp3.sh`): **10 match nyata** dijalankan total -- 6 skenario rencana (2P+2AI x2 peta, 3P+1AI x2
  peta, client-keluar-diambil-AI, migrasi host; giliran 20) + 4 tambahan (giliran 50, 2 di antaranya
  `role_ai=tanah` dipaksa di slot manusia-robot). **Semua 10: `cek_gagal=0`, `scripterr=0`** (host & semua
  client), `CEK_BD_JEBAKAN_AI` tercetak benar & konsisten tiap slot (role/jebakan_dibawa/build sama di semua
  HP), migrasi tervalidasi (`migrasi=1, cek_ok_migrasi=8/8`, skenario `host_keluar_migrasi`).
- **Temuan (dicatat, bukan disembunyikan, sesuai "BERHENTI & catat"):** 5 counter `cek_bd_*`
  (sacred/guard_nol/fight_faktor/benteng_lewati/benteng_tahan_ai) **TETAP 0 di ke-10 match MP** (giliran 20-51),
  termasuk match dengan 2 slot AI tanah+Fortress sekaligus & match 51-giliran. Ditinjau lewat baca kode
  (`_sacred_tersedia`/`_boleh_tanah_di`/`_sacred_layak`, `pemain_role.gd`+`ai_jebakan.gd`) -- BUKAN bug:
  - Sacred butuh AI tanah berhenti di petak MILIKNYA SENDIRI yang SUDAH bermenara >=1 -- itu perlu AI singgah
    di petak yang SAMA 3x berturut (beli, bangun menara Lv1, baru Sacred bisa terpicu), kejadian gabungan yang
    genuinely jarang dalam ~12-13 giliran/pemain.
  - `fight_faktor`/`benteng_lewati`/`benteng_tahan_ai` butuh AI mendarat TEPAT di petak lawan yang SUDAH
    punya JebakanTanah aktif (lawan itu sendiri harus sudah memasang tanah di petak SPESIFIK itu giliran
    sebelumnya) -- juga kejadian gabungan yang jarang dalam jumlah giliran yang diuji.
  - `role_ai=tanah` yang dipaksakan ke slot manusia-robot **tidak membantu Sacred** (`pertimbangkan` hanya
    dipanggil untuk slot AI, dibuktikan lewat baca kode, bukan cuma diasumsikan) -- tetap berguna untuk
    4 counter lain (peduli korban tanah siapa pun pemiliknya), tapi juga nihil di 10 match ini.
  - Diterima sebagai celah residual per kalimat 14.16 sendiri ("mungkin perlu beberapa seed/skenario lagi") --
    ditopang bukti lain yang SUDAH ada: rumus terverifikasi benar (`cek_nilai=1`), kode terbaca benar
    terpasang di jalur keputusan AI sungguhan, dan Sacred pernah terbukti menyala di konteks solo/AI-vs-AI
    (M3 di atas). Bukan syarat wajib D7.5 (yang tertulis di 14.16 cuma `cek_bd_sacred>=1` sebagai target,
    bukan kelima counter) -- ditinjau lagi kalau B-f/rig lebih lama membuka kesempatan.
- D7.6: 6 baris `_tambah_stat("cek_bd_*")` sementara (`ai_musuh.gd` x3 + `ai_jebakan.gd` x3) **DIHAPUS** dari
  kedua file produksi sebelum ZIP -- `grep cek_bd_ /home/claude/*.gd` = 0. Rig-only (`uji_nyata.gd` D0/D6,
  `uji_robot_mp.gd` D6) DIBIARKAN, tidak pernah ikut ZIP. Sesudah hapus: sinkron ulang kedua rig (diff bersih
  selain 2 baris saklar `UJI_DUEL`/`UJI_SERI` yang memang disengaja), import bersih lagi (0 SCRIPT ERROR),
  `cek_nilai=1` ulang 5/5 OK (angka identik), `batch_reg10.sh` ulang 0 GAGAL (pola RNG sama seperti sebelum
  D7.6) -- membuktikan penghapusan counter murni kosmetik, tidak menyentuh logika.
- **Catatan implementasi (Sonnet, di luar rumus harfiah 14.16, ditinjau lagi B-f/U9):** `_nilai_tanah`
  merata-rata (bukan menjumlah) nilai per-lawan -- teks 14.16/K17a hanya memberi 2 faktor diskon per-lawan,
  tidak menyebut cara menggabungkan lintas-lawan; dipilih rata-rata supaya nilai satu petak tidak melonjak
  hanya karena jumlah pemain lebih banyak (beda dari api/angin/petir/air yang memang menjumlah peluang
  independen tiap lawan lewat lintasan papan). Ditandai jelas di komentar kode, bukan disembunyikan.
- Set kiriman: TETAP **29 file .gd** + `RENCANA_fase4_role.md` = **30 file** (5 berubah, 24 sama seperti
  `TileDuel_FaseB_b7.zip`; tidak ada file produksi baru/hilang dari B-d).

**Selanjutnya: B-e** -- layar pohon+ARENA (B2), tombol ROLES, tayangan B5+versi Very Low, build solo pemain
dari profil, K1 AI solo Balanced sesuai Level Role pemain (P6). **B-f** -- rig lengkap U1-U11 +
`cek_panggil.py`, Opus U9 tinjau keseimbangan penuh (termasuk setel ulang K17-K19 & `BOBOT_TAHAN_AI`, dan
celah counter `cek_bd_*` MP di atas kalau rig U9 punya giliran lebih panjang).
