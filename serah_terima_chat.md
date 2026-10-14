# Serah terima chat: riset Naruto Jintori Gassen dan topik desain game

Berkas ini dibuat agar chat baru bisa melanjutkan tanpa akses ke riwayat chat lama. Isinya: cara pakai, status terakhir, aturan kerja, lalu dua lampiran (ringkasan semua topik dan catatan riset lengkap).

## Cara pakai di chat baru

1. Lampirkan berkas ini ke chat baru (tombol lampiran), atau tempel isinya.
2. Kirim pesan seperti ini, lalu pilih SATU target dari "Status terakhir":
   "Baca berkas serah terima terlampir. Aku melanjutkan riset game PS1 Naruto: Shinobi no Sato no Jintori Gassen sebagai referensi TileDuel. Jangan ulangi hal yang sudah bertanda [TERBUKTI] atau [TERAMATI]. Target sesi ini: [pilih satu]. Hemat token, kerjakan satu target per sesi, jalankan emulator di latar belakang dengan run <= 9 menit."
3. Unggah ulang bila perlu: emulator PCSX-Redux (Linux x86_64), file game `.bin` dan `.cue`, dan zip TileDuel. File di sandbox lama tidak terbawa.
4. Repositori `halsuntech777-beep/riset-naruto` (privat) berisi skrip, jadwal input, tabel papan, dan versi terbaru berkas ini. Menulis ke sana butuh token baru yang kamu buat sendiri; token tidak disimpan di memori.

## Status terakhir

- **Bonus di petak start (結界源):** struktur terbukti dari layar laporan chakra di game: hadiah tetap **+400** ditambah bagian dari nilai barrier. Pada sampel P1: 7 barrier -> +235, total bonus 635. **Dugaan kuat:** bagian barrier = 25% dari total nilai barrier (235 = 25% x 940, dengan petak level 1 bernilai 120). Belum terbukti penuh.
- **Belum dikerjakan (pilih satu sebagai target):**
  1. Baca layar laporan bonus P2 (3 barrier, harapan +130). Run deterministik 2 pemain, screenshot frame 16640-16960 (jadwal: `inputs/inputs_2lap.txt`).
  2. Baca panel peta untuk nilai barrier (結界価値) petak level 1; harapan 120.
  3. Satu sampel dengan semua barrier level 0 dan total berbeda.
  4. Verifikasi tabel roda di executable (`0x8006491C`) dengan membaca roda tiap karakter di layar.
  5. Daftar kartu Chance (baru tampil: maju 7 petak, serang +1/+2, pulih 400, pulih 250, Ichiraku Ramen +150).
- **Hal yang sudah dicoba dan buntu:** pencarian kode lewat konstanta di executable dan RAM; pencarian status kepemilikan logika sebagai array atau bitmask di RAM; ubah-memori pada rekaman tampilan petak (bonus tidak berubah); breakpoint tulis/baca emulator (tidak menangkap kode game).
- **Lingkungan:** sandbox 1 core CPU, jaringan GitHub biasanya terbuka (cek di awal sesi); proses latar belakang yang berjalan lebih dari ±10 menit pernah mati saat sandbox dijeda, jadi pecah run <= 9 menit. Pemuatan save-state dari Lua membuat emulator segfault; gunakan pemutaran ulang input.

## Aturan kerja (preferensi pengguna)

- Hemat token dan batas pemakaian 5 jam; pakai artefak/berkas bila perlu; ingatkan membuka chat baru saat chat sangat panjang.
- Kirim hasil kerja ke repositori GitHub miliknya (`halsuntech777-beep/riset-naruto`) agar tidak hilang; tanda keyakinan wajib: [TERBUKTI]/[TERAMATI]/[DUGAAN]/[BELUM].
- Jangan mengekstrak atau menyimpan sprite maupun musik game; screenshot emulator hanya untuk navigasi dan membaca angka/teks. Jangan mengunggah game, emulator, screenshot, atau dump RAM ke repositori.
- Token GitHub tidak disimpan di memori; jangan dicetak ulang tanpa diminta.
- Jawab dalam bahasa Indonesia yang ringkas.

---

# Lampiran A: Ringkasan semua topik di chat sebelumnya

# Ringkasan percakapan (semua topik)

Disusun dari isi chat panjang (Sep–Okt 2026). Ini ringkasan, bukan transkrip kata demi kata. Angka industri berasal dari pencarian web pada saat itu dan perlu dicek ulang bila dipakai untuk keputusan penting. Riset game Naruto yang rinci ada di `catatan_riset.md`.

## 1. Video "Why Hybrid Casual Games Work (and Make Millions)"

Video 4 menit 36 detik, 854×480, caption terbakar di gambar, ada logo Liftoff.

- Hybrid-casual = aksesibilitas hypercasual + retensi game core/midcore. Slide menampilkan ±5,1 miliar unduhan dan ±$1,4 miliar pendapatan (App Store + Google Play, 2019–2022).
- Tiga faktor retensi: **simple mastery loop**, **constant rewards**, **long-term progression** ("dopamine design": mulai karena mudah, bertahan karena sudah berinvestasi).
- Monetisasi: hypercasual hampir sepenuhnya iklan (banner + rewarded); hybrid = **Ads + IAP + "keep on playing"** (retensi dari upgrade).
- **Core loop + meta loop**: sesi pendek berulang (gelombang musuh, merge, rintangan) + lapisan antar-sesi (upgrade, bangun base, progres ala RPG, unsur prosedural/roguelike).
- Publisher besar (Voodoo, Supersonic, Zynga) beralih ke hybrid. Formula penutup: *simple to start, want to continue, difficult to quit*.

## 2. Data iklan vs IAP (survei AdInMo, via ExchangeWire, Okt 2024)

- Donut chart di video: 44,7% studio melihat porsi IAP naik, 38,3% tidak berubah, 17,9% porsi iklan naik.
- 72% berencana menerapkan/memperluas monetisasi hybrid; 63% fokus menaikkan konversi IAP; 49% berencana menambah iklan immersive.

## 3. IAP dan pay-to-win

- IAP tidak otomatis pay-to-win. Spektrumnya: **kosmetik → convenience → catch-up/percepat → power eksklusif** (yang terakhir baru pay-to-win sungguhan).
- Ekonomi whale (mwm.ai, Moloco): ±2–5% pemain pembayar menyumbang ±80% pendapatan F2P; 70–80% pemain nyaris tidak menghasilkan; median game F2P yang menghasilkan ±$441 per 30 hari; porsi whale tumbuh dari bulan pertama ke bulan kesepuluh.
- Saran untuk game strategi indie: hindari power eksklusif untuk hal yang memengaruhi hasil pertandingan; monetisasi lewat kosmetik, convenience, konten tambahan; iklan rewarded untuk mayoritas yang tidak membayar. Alasan: indie bergantung pada retensi organik dan rating, anggaran iklan kecil (rencana Meta Ads Rp100.000), dan keadilan adalah nilai inti genre strategi.

## 4. Leaderboard dan sistem sosial (follow/like)

- Free player adalah audiens dan lawan main; tanpa mereka panggung whale tidak bernilai.
- **Follower/like dan rank tidak boleh bisa dibeli**; yang dijual adalah hal yang membuat pemain layak diikuti (frame profil, tema papan, gelar musiman, animasi menang).
- Profil pemain jadi titik temu: rank (terlindungi, murni skill), kosmetik (gratis lewat rank atau beli), statistik sosial.
- Contoh: chess.com (rating terpisah dari Follow di profil), Mobile Legends (border rank gratis + border berbayar terpisah).
- Tombol bagikan ke luar app (WhatsApp, dll.) = pemasaran organik, relevan untuk anggaran kecil.

## 5. Game Facebook (Zynga/FarmVille)

- Keberhasilannya terutama dari **distribusi gratis lewat grafik sosial Facebook**, bukan gameplay semata.
- Mekanik: core loop asinkron, kewajiban sosial/resiprositas, timer dengan tiga pilihan (tunggu, minta bantu teman, bayar), F2P + IAP.
- Basis pengguna tumbuh ±10× dalam setahun setelah feed Facebook diubah jadi real-time (2009), lalu runtuh saat Facebook membalik kebijakan (akhir 2009–2012). Zynga IPO Des 2011 (±$7 miliar), diakuisisi Take-Two 2022 (±$12,7 miliar).
- Pelajaran: pertumbuhan yang bergantung pada celah satu platform rapuh. Prinsip yang masih berlaku: asinkron, resiprositas, share sebagai bagian gameplay.

## 6. Monopoly GO (Scopely, rilis 11 April 2023)

- $6 miliar pendapatan IAP lifetime tercepat sepanjang sejarah game mobile (1.275 hari); ±$200 juta/bulan; 150 juta+ unduhan; anggaran pemasaran sangat besar.
- Dadu sebagai energi (regenerasi 1 per 10 menit, simpan maks 100); Community Chest (hadiah timbal balik teman); Bank Heist/Shutdown (serang teman); sticker album sebagai meta loop; turnamen (poin bisa dipercepat dengan dadu berbayar, jadi tidak murni skill).
- Pelajaran: tiru dadu-sebagai-energi, gifting timbal balik, ajak teman, koleksi ringan. Hati-hati menyalin turnamen pay-to-climb dan FOMO agresif untuk game strategi indie.

## 7. Roguelike

- Ciri: level acak (procedural) + permadeath. **Roguelite**: mati tetap ulang dari awal tapi ada progres permanen antar-run. Itu core loop (satu run) + meta loop (progres permanen).

## 8. Review TileDuel (zip FaseB_b8)

- 30 file GDScript (Godot 4) + `RENCANA_fase4_role.md`; salinan ada di folder `tileduel/`.
- Sudah ada: dadu 2d6, kepemilikan petak + level menara, kartu gacha di petak kartu, 5 elemen jebakan, role + pohon skill, Arena 12 SP yang disamakan, XP/Crowns/misi harian/login 7 hari, iklan (banner, interstisial di EXIT, rewarded), jaringan (migrasi host).
- Belum ada: IAP, leaderboard, fitur sosial; layar pohon skill (B-e) belum terlihat di build ini; Crowns belum punya tempat belanja.
- Saran: beri Crowns tempat belanja kosmetik (fondasi IAP kosmetik), selesaikan layar pohon, beri alasan naik level di multiplayer, produk IAP pertama paling aman "Remove Ads", dan waspadai snowballing kepemilikan petak.

## 9. Riset game Naruto Jintori Gassen (PS1)

Seluruh hasil (disk, emulator, tabel papan, aturan, kartu, hal yang belum diketahui) ada di `catatan_riset.md`. Skrip pendukung di `redux/`, `inputs/`, `analisis/`.

## 10. Preferensi kerja dan infrastruktur

- Pengguna meminta hemat token dan batas pemakaian 5 jam, memakai artefak bila perlu, dan diingatkan membuka chat baru saat chat sudah sangat panjang.
- Sandbox kadang dibersihkan; folder output bertahan. Jaringan sandbox awalnya memblokir GitHub, belakangan terbuka; push ke GitHub butuh token fine-grained (satu repositori, izin Contents read/write, masa berlaku pendek).
- Artefak catatan: https://claude.ai/artifact/M92Spevha8qcHj93jyoDb8


---

# Lampiran B: Catatan riset lengkap game Naruto Jintori Gassen

# Catatan riset: Naruto – Shinobi no Sato no Jintori Gassen (PS1) sebagai referensi TileDuel

Dibuat dari satu chat panjang, untuk dilanjutkan di chat baru. Tingkat keyakinan di tiap poin:

- **[TERBUKTI]** diukur atau diuji langsung (termasuk uji ubah-memori)
- **[TERAMATI]** terlihat di layar atau dialog, belum diuji
- **[DUGAAN]** masuk akal, belum diverifikasi
- **[BELUM]** belum diketahui

Semua angka berasal dari satu papan (Hutan Konoha) kecuali disebut lain.

---

## 1. Identitas game dan file

| Hal | Isi |
|---|---|
| Judul | NARUTO -ナルト- 忍の里の陣取り合戦 (PS1, Jepang) |
| Kode / penerbit | SLPS-03553 / BANDAI. Mastering ISO 3 April 2003. Menurut katalog komunitas rilis 26 Juni 2003, pengembang Denyusha & Dimps |
| Genre | Board game 1–4 pemain: dadu/roulette, kepemilikan petak, kartu jurus, pertarungan |
| Citra disk | 1 track MODE2/2352, 138.601 sektor, 325.989.552 byte |
| Integritas | Semua sektor Form1 (EDC+ECC) dan Form2 (EDC) valid, tanpa sektor hilang atau ganda |
| Hash | CRC32 `dfe1f8b3`; MD5 `82e1dcfd2e09b954f59b9cdfd71c155b`; SHA-1 `b1ec331c9939dd599b52b692d90ae7e163b979c2`; SHA-256 `58c389a794375b7b81b3a18877ef7965356a1332285a3590170efbf2359a3b88`. Tidak ditemukan halaman database dump publik yang memuatnya |

Isi file system (6 file, tanpa subfolder):

| File | Ukuran | Catatan |
|---|---|---|
| `SYSTEM.CNF` | 68 B | BOOT = `cdrom:\SLPS_035.53;1` |
| `SLPS_035.53` | 385.024 B | PS-X EXE, dimuat di 0x80010000, PC 0x80011448 |
| `DATA.BIN` | 66.015.232 B | mulai LBA 212; berisi 696 gambar TIM valid dan **tabel papan** |
| `XASECT.BIN` | 692 B | 173 nilai 32-bit, fungsi belum dipastikan |
| `DATA2.BIN` | 166.428.672 B | mulai LBA 32447; 53.143 sektor data + 28.121 sektor audio XA (16 kanal, round-robin) |
| `DUMMY.BIN` | 50.667.520 B | semua nol (padding) |

Nama folder developer yang tertinggal di disk: `STG01`–`STG08`, `STG12`, `STG13` (varian A/B/C), `TITLE`, `TREASURE` (≥41 cue `T_xx`). Itu nama internal, bukan nama yang tampil di game.

Teks game tidak tersimpan sebagai string Shift-JIS biasa (pemindaian gagal; hasilnya false-positive dari data grafis). Executable sendiri hanya berisi tabel sistem/SDK (register hardware, tabel interupsi, tabel interpolasi animasi), bukan tabel aturan. **Jangan habiskan waktu di sana lagi.**

---

## 2. Cara riset dilakukan dan jebakannya

Sandbox: 1 core CPU, ±4 GB RAM, tanpa GPU, tanpa jaringan keluar (host download ditolak `host_not_allowed`). Kamu perlu mengunggah ulang file di chat baru.

**Emulator:** PCSX-Redux (AppImage Linux x86_64) dijalankan tanpa layar lewat Xvfb: `-cli -interpreter -softgpu -debugger -fastboot -loadiso <cue> -run -dofile <skrip.lua>`, dengan OpenBIOS bawaan.

- Game ber-ID `SLPS03553`, boot normal sekitar 19 detik.
- Kecepatan ±55 frame/detik emulasi. Run 7.000 frame ≈ 2 menit, 15.000 frame ≈ 5 menit.
- AppImage butuh versi glibc lebih baru dari yang ada di sandbox (2.39). Sebelumnya diatasi dengan shim kecil (`LD_PRELOAD`) + tambal versi pada binary. Siapkan ulang bila perlu.
- Run **deterministik**: input yang sama menghasilkan kejadian di frame yang sama. Dipakai untuk mengulang kejadian dan menyisipkan perubahan memori.

**Kontrol lewat Lua:**
- `PCSX.Events.createEventListener('GPU::Vsync', fn)` untuk hitung frame
- `PCSX.SIO0.slots[1].pads[1].setOverride/clearOverride(tombol)` untuk menekan tombol
- `PCSX.getMemPtr()` + `ffi` untuk membaca/menulis RAM 2 MB
- `PCSX.GPU.takeScreenShot()` untuk screenshot mentah (RGB555 320×240)
- `PCSX.quit(0)` untuk keluar
- ID tombol: CIRCLE=13, CROSS=14, TRIANGLE=12, SQUARE=15, START=3, SELECT=0, UP=4, DOWN=6, LEFT=7, RIGHT=5, L1=10, R1=11, L2=8, R2=9. Tombol ditekan ±5 frame.

**Jebakan yang sudah dialami:**
1. Breakpoint tulis/baca (Lua) **tidak menangkap** akses kode game ke RAM biasa; hanya BIOS dan DMA yang tertangkap. Jadi penulis uang tidak bisa dilacak dengan cara itu.
2. Memuat save-state dari Lua menyebabkan segfault. Gunakan pemutaran ulang input.
3. Ubah-memori (poke) lewat `ffi` bekerja baik dan menjadi alat uji paling berguna.
4. Perintah `pkill -f` dengan pola yang cocok dengan shell sendiri mematikan shell; pakai `pkill -x pcsx-redux`.
5. Run panjang sebaiknya di latar belakang (`nohup ... &`) lalu dipantau dengan `sleep`.

**Alamat RAM penting (papan Hutan Konoha):**

| Hal | Alamat |
|---|---|
| Tabel petak, record #0 (pasangan harga, sewa u16) | `0x8013BA6E`, jarak antar record 0x124 (292 byte) |
| Uang pemain 1 / pemain 2 (mode 2 pemain, sama dengan angka HUD) | `0x801EFBBC` / `0x801EFC4C` |

Alamat uang untuk 4 pemain belum dicari.

**Kerangka waktu (frame, skrip input pada saat itu):**
- Judul ±2100; Mode Select ±2700
- Party Mode: jumlah pemain ±3000, manusia/COM ±3200, kontroler 3400–3900, pilih karakter ±4300, pilih stage ±5200, Clear Chakra ±5400, urutan giliran ±5700, HUD 4 pemain ±6900
- Story (tutorial): intro Akademi ±3300, HUD 2 pemain ±4200, roulette pertama ±5500, pilih arah ±6000, dialog petak kartu ±6300

Jalur Party Mode yang berhasil: spam CIRCLE/START bergantian tiap ±30 frame sejak ±1500 sampai <2600, lalu `2800 RIGHT; 2900 CIRCLE; 3100,3300,3500,3700,3900 CIRCLE; 4100,4350,4600,4850,5100,5350 CIRCLE;` lalu CIRCLE tiap 80 frame mulai 5600 (ini juga yang dipakai sampai angka roulette Sasuke = 5 di ±7500).

Lanjutan jalur ke petak kartu (Party Mode, 4 pemain, giliran pertama = Sasuke): lanjutkan spam CIRCLE tiap 80 frame dari 5600 sampai 7440; roll pertama keluar 5. Lalu `7520 RIGHT 8; 7580 CIRCLE 5` memilih arah kanan; bidak mendarat di petak kartu #6 dan layar pilih kartu muncul ±frame 7720. `7800 RIGHT 5` dan `7940 RIGHT 5` menggeser kursor kartu; `8080 CIRCLE 5` memilih; `8200 CIRCLE` dan `8330 CIRCLE` menutup dialog. Urutan HUD empat pemain: Sasuke, Naruto, Sakura, Kakashi, masing-masing mulai 1500.

Contoh mendarat di petak kartu (Party Mode): hentikan spam CIRCLE setelah frame 7600, lalu `7700 RIGHT; 7760 CIRCLE`. Bidak mendarat di petak kartu ±7800, kartu tertutup muncul ±7870 dan terbuka ±7945. Geser kursor: `8000 RIGHT; 8100 RIGHT`; pilih: `8200 CIRCLE`.

---

## 3. Menu dan mode

**[TERAMATI]** Mode Select: **Story Mode** (1 pemain), **Party Mode** (battle bersama), **Treasure BOX** (lihat harta tersembunyi yang didapat), **Bingo Book** (data rival). Urutan kursor melingkar.

- Party Mode: atur jumlah pemain (default 4), jumlah manusia vs komputer, kontroler tiap pemain, pilih karakter, pilih stage, **Clear Chakra** (default 03000, bisa dinaikkan/diturunkan), lalu layar urutan giliran.
- Pilih pemain: 12 slot; hanya 4 terbuka di save baru. Bingo Book: 14 kartu, semuanya tertutup di save baru.
- Pilih stage: **9 stage** (kursor melingkar setelah 9 kali geser). Hanya satu terbuka: **ホノ葉の森** (kemungkinan 木ノ葉の森, "Hutan Konoha"); 8 lainnya "???".

**Karakter terbuka di awal [TERAMATI, dari deskripsi di layar]:**

| Karakter | Sifat |
|---|---|
| Naruto | jurus serangan bervariasi |
| Sasuke | kuat serangan jarak jauh, agresif |
| Sakura | banyak jurus pertahanan |
| Kakashi | seimbang serang/bertahan |

Story Mode tutorial: lawan Mizuki, pemandu Iruka (hanya memberi penjelasan). Nama stage dan karakter yang terkunci **[BELUM]**.

---

## 4. Aturan permainan

### 4.1 Papan Hutan Konoha: 22 petak melingkar [TERBUKTI]

Tabel yang sama persis ada di `DATA.BIN`, di RAM saat Story tutorial, dan di RAM saat Party Mode. Titik (x,y) berasal dari kolom di tabel; jarak antar petak 40, membentuk lintasan tertutup. Pemain memilih arah di start (kanan atau bawah).

| # | idx | Harga / sewa | (x,y) | Jenis |
|---|---|---|---|---|
| 1 | −2 | – | (199,150) | **Start 結界源** (ikon yin-yang) |
| 2 | −1 | 60 / 35 | (239,150) | dibeli |
| 3 | 0 | 100 / 50 | (279,150) | dibeli |
| 4 | 1 | 100 / 50 | (319,150) | dibeli |
| 5 | 2 | 120 / 60 | (359,150) | dibeli |
| 6 | 3 | – | (399,150) | **petak kartu** [TERBUKTI di Party Mode] |
| 7 | 4 | 120 / 60 | (399,186) | dibeli |
| 8 | 5 | **160 / 85** | (439,186) | dibeli |
| 9 | 6 | 140 / 70 | (439,222) | dibeli |
| 10 | 7 | 140 / 70 | (439,258) | dibeli |
| 11 | 8 | 120 / 60 | (439,294) | dibeli |
| 12 | 9 | – | (439,330) | spesial, bola merah |
| 13 | 10 | 200 / 100 | (399,330) | dibeli |
| 14 | 11 | 220 / 110 | (359,330) | dibeli |
| 15 | 12 | 260 / 130 | (319,330) | dibeli |
| 16 | 13 | 220 / 110 | (279,330) | dibeli |
| 17 | 14 | 200 / 100 | (239,330) | dibeli |
| 18 | 15 | – | (239,294) | spesial, bola biru |
| 19 | 16 | – | (199,294) | spesial, **petak kartu (札所)** [TERBUKTI] |
| 20 | 17 | 140 / 70 | (199,258) | dibeli |
| 21 | 18 | 120 / 60 | (199,222) | dibeli |
| 22 | 19 | 100 / 50 | (199,186) | dibeli |

17 petak bisa dibeli, total harga 2520. **Petak kartu terbukti di nomor 19** (empat langkah ke bawah dari start) **dan nomor 6** (lima langkah ke kanan dari start; di Party Mode pemain berhenti di sana dan layar pilih kartu muncul). Dua petak bola kemungkinan kristal (水晶玉) yang disebut tutorial **[DUGAAN]**. Petak mi cup (+50 chakra) belum bisa ditempatkan **[BELUM]**.

**Layout record 30 byte di disc** (15 nilai u16): harga, sewa, lalu 4 nilai, lalu 3 nilai, x, y, dua kode, `65535`, `255`.

| Harga | 4 nilai berurutan (arti belum diketahui) | 3 nilai (arti belum diketahui) |
|---|---|---|
| 100 | 110, 220, 440, 880 | 50, 35, 70 |
| 120 | 140, 265, 530, 1050 | 100, 70, 84 |
| 140 | 160, 310, 620, 1250 | 100, 70, 98 |
| 160 | 180, 360, 710, 1410 | 120, 84, 112 |
| 200 | 220, 440, 880, 1760 | 150, 105, 140 |
| 220 | 250, 490, 980, 1940 | 150, 105, 154 |
| 260 | 290, 580, 1150, 2290 | 200, 140, 182 |

Dugaan: deret empat nilai terkait level barrier (level-up), tetapi belum diuji **[DUGAAN]**. Dua kode setelah (x,y) tampak seperti penanda jenis dan tautan antar petak (pola bertambah 0x0101) **[DUGAAN]**.

**Lokasi di disc:** `DATA.BIN`, offset byte 18.735.172 untuk record idx 0; stride 30 byte.

### 4.2 Uang, klaim, sewa [TERBUKTI]

- Modal awal tiap pemain **1500** (HUD = RAM). Satu-satunya sumber daya adalah chakra.
- **Klaim petak kosong** = bayar harga (nilai barrier, 結界価値) ke bank. Lawan tidak menerima apa pun.
- **Mendarat di petak lawan** = bayar sewa ke pemilik; jumlah berpindah utuh (130: P1 +130, P2 −130).
- **Sewa diambil dari kolom sewa di tabel, bukan dihitung 50% harga.** Uji: sewa petak 260 diubah di memori dari 130 menjadi 133 → yang berpindah 133.
- Pemetaan harga → sewa **sama di semua papan di disc**: 60→35, 100→50, 120→60, 140→70, 160→85, 180→90, 200→100, 220→110, 240→120, 260→130, 280→140, 300→150, 320→160, 350→175. Hanya 60 dan 160 yang bukan setengah harga.
- Layar peta menampilkan properti petak: level, nilai barrier (harga), ketahanan (耐久値).

### 4.3 Start (結界源), kristal, target [TERAMATI dari dialog, kecuali disebut]

- Dialog tutorial (parafrase): maju sejumlah angka roulette; lewati **semua kristal** di peta lalu **kembali ke 結界源**: dapat bonus chakra; kumpulkan chakra sampai **chakra target** (目標チャクラ), lalu kembali ke 結界源.
- Di peta, petak 結界源 bertuliskan bahwa pemain bisa menerima bonus chakra.
- Party Mode punya setelan Clear Chakra (default 3000); kemungkinan itu chakra target **[DUGAAN]**. Apakah memenuhi syarat itu langsung mengakhiri permainan, dan nasib pemain lain, **[BELUM]**.
- Dialog lain: makin besar nilai barrier yang dimiliki, makin besar bonus.

### 4.4 Giliran dan roulette

- Menu tiap giliran **[TERAMATI]**: Roulette (ルーレット), Jurus (忍術), Info (情報), Lihat Peta.
- Roulette berupa roda berangka **1–6** (ada angka ganda di roda). Angka yang pernah keluar: 3, 4, 5, 6. Bobot peluang **[BELUM]**.
- Urutan giliran ditampilkan sebelum main (di run Party Mode, P2 berjalan pertama).

### 4.5 Kartu dan jurus

- **[TERAMATI]** Berhenti **tepat** di petak kartu → pilih satu dari kartu menghadap atas → dapat kartu Chance. Kartu berfungsi sebagai jurus (忍術) yang dipakai lewat menu giliran, dan bisa dipakai untuk menyerang atau menjegal lawan.
- **[TERAMATI, Party Mode]** Berhenti tepat di petak kartu memunculkan layar "pilih kartu yang diambil": tiga kartu tertutup (punggung berlambang 忍) lalu terbuka. Kunjungan pertama menawarkan:
  1. **Attack Up +2** (攻撃力アップ): saat menyerang, kekuatan serangan +2
  2. **Attack Up +1**: saat menyerang, kekuatan serangan +1
  3. **Kartu segel tangan "+400"** (nama terbaca 印速結び): teks efek "pulihkan 400 chakra"
  Kursor digeser dengan RIGHT, deskripsi kartu yang disorot tampil di kotak bawah, CIRCLE memilih. **[TERBUKTI]** Memilih kartu ketiga menampilkan teks "chakra pulih 400", dan HUD Sasuke langsung naik 1500→1900 (Naruto, Sakura, Kakashi tetap 1500). Petak kartu yang dipakai adalah #6 (lima langkah ke kanan dari start).
- Tutorial menawarkan satu kartu saja (diatur skrip tutorial): **"maju 7 petak"**, dipakai ke lawan, lawan dimajukan 7 petak.
- Jadi sejauh ini ada tiga jenis efek: kenaikan kekuatan serangan (+1, +2), pemulihan chakra (+400), dan gerak (maju 7 petak, bisa ke lawan). Adanya "kekuatan serangan" menandakan battle memakai angka serangan. Apakah kartu serangan disimpan lalu habis dipakai, dan berapa maksimal kartu di tangan, **[BELUM]**.
- Sumber web sekunder (belum diverifikasi): ada kartu pemulih, jebakan, dan percobaan merebut petak lawan.
- Daftar lengkap, jumlah, dan peluang kartu **[BELUM]** (butuh kunjungan tambahan ke petak kartu).

### 4.6 Level-up barrier

- Mendarat di 結界源 setelah punya barrier memunculkan pertanyaan "level-up barrier? Ya/Tidak".
- Memilih Ya membuka layar pilih-barrier yang gagal saya selesaikan (kursor tidak bergerak ke barrier valid, permainan macet). Batal dengan CROSS, lalu "Tidak" (DOWN + CIRCLE) membuat giliran lanjut.
- Biaya dan efek level-up **[BELUM]**.

---

## 5. Peristiwa uang terukur (papan tutorial, 2 pemain, run deterministik)

| Frame | Pemain | Perubahan | Kejadian |
|---|---|---|---|
| 10049 | P1 | 1500→1240 (−260) | klaim petak 260 (satu-satunya petak berharga 260 = idx 12) |
| 10763 | P2 | 1500→1340 (−160) | klaim petak 160 (idx 5, harga unik) |
| 11805 | P1 | 1240→1100 (−140) | klaim petak 140 |
| 12437 | P2 | 1340→1200 (−140) | klaim petak 140 |
| 13371 | P1 | +50 | petak mi cup, teks "pulihkan 50 chakra" |
| 13559 | P1 | 1150→1050 (−100) | klaim petak 100 |
| 14627–14633 | P2→P1 | 130 | P2 mendarat di petak P1 (label −130), sewa petak 260 |
| 15571 | P1 | 1180→1705 (+525) | berhenti di 結界源 dengan barrier 260+140+100=500 |
| 16455–16463 | P1 | 1705→1565 (−140) | setelah memilih "Tidak" di dialog level-up; penyebab belum diverifikasi |
| 8080–8400 (run Party Mode) | P2 (Sasuke) | 1500→1900 (+400) | memilih kartu "pulih 400 chakra" di petak kartu #6; pemain lain tetap 1500 |

Perubahan uang tampil bertahap tiap 2 frame (10 per langkah, lalu 100), jadi satu transaksi tampak sebagai beberapa perubahan.

**Bonus +525 [BELUM terjelaskan]:**
- Kemungkinan besar bonus kembali ke 結界源 (lihat 4.3).
- Uji poke: harga petak 260 diubah ke 460 dan sewa petak 140 diubah ke 120 → bonus **tetap 525**. Jadi bonus tidak membaca kolom harga/sewa tabel saat itu.
- Tidak ada variabel di RAM yang bernilai 260 lalu 500 (P1) atau 160 lalu 300 (P2), jadi "total nilai barrier" tidak disimpan sebagai jumlah biasa.
- Rumus 500+25 atau 500×1,05 hanya kecocokan satu sampel; belum bisa dibedakan.

---

## 6. Papan lain di disc [TERBUKTI keberadaannya, pemakaiannya BELUM]

Pemindaian `DATA.BIN` menemukan **16 blok tabel** dengan layout yang sama; isinya kembar sebagian, jadi **11 papan berbeda**. Offset blok (byte di `DATA.BIN`, urut): 18733612, 19079724, 19425836, 19755564, 20101676, 20443692, 20789804, 21116456, 21445164, 21791276, 22137388, 22483500, 22829612, 23175724, 23521836, 23863852 (jarak antar blok biasanya 346.112 byte). Verifikasi ulang sebelum dipakai.

| Tabel | Salinan | Petak berharga | Total harga | Harga min–maks |
|---|---|---|---|---|
| T1 (Hutan Konoha) | 1 | 17 | 2520 | 60–260 |
| T2 | 1 | 25 | 4040 | 60–280 |
| T3 | 1 | 25 | 4100 | 60–280 |
| T4 | 1 | 24 | 3880 | 60–280 |
| T5 | 1 | 25 | 3720 | 60–280 |
| T6 | 1 | 32 | 5920 | 100–300 |
| T7 | 2 | 28 | 4960 | 60–320 |
| T8 | 1 | 24 | 5050 | 60–350 |
| T9 | 1 | 17 | 3240 | 120–260 |
| T10 | 5 | 25 | 5340 | 60–350 |
| T11 | 1 | 27 | 4660 | 100–300 |

Pemetaan tabel → stage (9 di Party Mode, 13 folder `STG`) belum dicocokkan.

---

## 7. Belum diketahui (urut prioritas)

1. Sisa daftar kartu/jurus, efek kartu serangan, dan peluang munculnya (baru 4 kartu terlihat; perlu kunjungan tambahan di Party Mode, bisa diatur lewat waktu tekan roulette)
2. Arti kolom 4 nilai dan 3 nilai di record petak, biaya dan efek level-up barrier
3. Rumus bonus di 結界源 dan arti persis chakra target; apakah sekadar melewati atau harus berhenti
4. Bobot peluang angka roulette (perlu puluhan sampel)
5. Sistem battle, damage jurus, dan efek tiap petak spesial (termasuk mi cup)
6. Nama stage dan karakter yang terkunci; pemetaan tabel ke stage
7. Penyebab −140 di frame 16455

---

## 8. Ide yang bisa diadaptasi untuk TileDuel

- **Sewa sebagai kolom data**, bukan rumus: bebas membuat pengecualian harga↔sewa tanpa mengubah kode.
- **Bonus start yang bergantung pada total nilai milik pemain** dan syarat melewati titik wajib (kristal) mendorong pemain memutari papan penuh dan tetap berinvestasi di petak.
- **Syarat menang "kumpulkan target lalu kembali ke start"** mencegah menang dengan hanya menimbun.
- **Petak kartu yang hanya aktif bila berhenti tepat** menciptakan tegangan antara langkah aman dan peluang kartu.
- **Set jurus berbeda per karakter** (variatif, jarak jauh, bertahan, seimbang).
- **Papan membesar bertahap**: dari 17 petak berharga (total 2520) sampai 32 (total 5920), harga maks 300–350.
- **Pilihan arah di start** memberi keputusan taktis di tiap putaran.

Catatan snowballing: kepemilikan petak membuat unggul awal membesar sendiri. Game 2003 ini tampaknya menerimanya karena bermain lokal; untuk TileDuel kompetitif online, perlu pengimbang (misalnya hasil menurun per level menara, atau jalan comeback).

---

## 9. Batas pekerjaan

- Sprite dan musik **tidak diekstrak**: hanya jumlah dan ukuran yang dicatat (696 gambar TIM valid; 16 kanal XA).
- Screenshot emulator hanya dipakai untuk navigasi dan membaca angka/teks, tidak disimpan sebagai hasil.
- Dokumen ini berisi fakta aturan dan parafrase singkat, bukan isi aset berhak cipta.
- Pengawas memori Lua tidak menangkap kode game, jadi kode penghitung uang/bonus belum ditemukan.

---

## 10. Melanjutkan di chat baru

1. Unggah ulang: PCSX-Redux (AppImage atau zip), `.bin` dan `.cue` game, dan (bila perlu) zip TileDuel. File sandbox lama kemungkinan hilang.
2. Tempel dokumen ini, lalu pilih satu target dari bagian 7 (disarankan: kartu di Party Mode, lalu bobot roulette).
3. Minta saya tetap hemat token: jalankan di latar belakang, kurangi percobaan beruntun, dan kerjakan satu target per sesi.

---

## 11. Temuan lanjutan: bonus 結界源, struct pemain, dan tabel di executable

### 11.1 Bonus di petak start (結界源)

- **Pemicu [TERBUKTI dari memori]:** kata di struct pemain +4 memuat dua bit penanda kristal (0x1000 dan 0x2000). Saat bonus keluar, kedua bit terhapus (P2: 0x33000 → 0x30001; P1: 0x33400 → 0x30401) dan bit rendah naik 1 (penghitung bonus). Jadi bonus dibayar saat pemain yang sudah melewati **kedua** kristal kembali ke start.
- **Tiga sampel besar bonus:**

| Sampel | Total harga barrier milik pemain | Bonus |
|---|---|---|
| Tutorial, P1 | 260+140+100 = 500 | +525 |
| Party Mode 2 pemain, P2 (frame 16741) | 120+140+260 = 520 | +530 |
| Party Mode 2 pemain, P1 (frame 21541) | 900 (7 petak; dua petak harga 100 sudah level 1) | +635 |

- **Dugaan rumus [DUGAAN KUAT]:** bonus = **400 + 25% × total nilai barrier**. Dua sampel tanpa level-up membentuk garis tepat (kemiringan 0,25, awal 400). Angka 400 sama dengan konstanta di tabel executable (11.3), sebagai bukti independen. Sampel ketiga cocok bila tiap petak 100 yang naik ke level 1 bernilai 20 lebih tinggi (jadi 120); itu asumsi yang belum diverifikasi.
- Bonus dihitung bertahap 20 per 2 frame di layar (klaim dan sewa 10 per 2 frame).
- **Uji ubah-memori [TERBUKTI, hasil negatif]:** sebelum bonus P1 (frame 21500), level dua petak P1 diubah ke 0 dan satu petak harga 220 dijadikan milik P1 pada **rekaman petak** (bidang pemilik dan level); ubahan bertahan, tetapi bonus tetap +635. Jadi bonus tidak membaca bidang itu secara langsung. Rekaman petak (292 byte) tampaknya objek tampilan; status logika kepemilikan, level, dan total nilai barrier ada di tempat lain yang **belum ditemukan**.
- Bidang di rekaman petak (offset relatif ke pasangan harga/sewa, u16): −4 = level (256 = level 1), +44 = pemilik (242 kosong, 245 P1, 246 P2), −8 = 1 untuk petak P2.

### 11.2 Struct pemain: `0x80070EB8`, jarak 180 byte, P1..P4 [TERBUKTI]

- +0 chakra (sama dengan HUD). Set kedua di `0x801EFBBC` (jarak 144 byte) juga mencerminkan chakra, tetapi tertimpa overlay saat layar battle dimuat; pakai set `0x80070EB8`.
- +4 bendera: slot pemain, penanda kristal (0x1000/0x2000), penghitung bonus. +112 mirip penghitung giliran (belum dipastikan).

### 11.3 Tabel di executable: `0x8006491C`, entri 48 byte [TERBUKTI keberadaannya; arti kolom DUGAAN]

Tiap entri: u32 `[chakra awal, chakra target, 400, 1027, ...]`, 12 byte angka (offset 30–41), lalu 4 byte `[id, a, b, 0]` (offset 44–47). Dua kelompok: entri berawalan 1500/3000 dan 2500/5000. Angka 400 sama di semua entri.
**Dugaan kuat:** 12 byte itu adalah isi 12 segmen roda roulette (roda yang tampil memang 12 segmen, angka 1–6 dengan duplikat), satu roda per karakter. Belum dicocokkan dengan roda di layar tiap karakter.

| Entri | Chakra awal | Chakra target | u32 #3 | u32 #4 | Angka 12 segmen (dugaan roda) | [id,a,b,0] |
|---|---|---|---|---|---|---|
| 0 | 1500 | 3000 | 400 | 1027 | [1, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6] | [1, 11, 1, 0] |
| 1 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8] | [2, 12, 2, 0] |
| 2 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8] | [3, 20, 3, 0] |
| 3 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8] | [4, 14, 4, 0] |
| 4 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9] | [5, 15, 5, 0] |
| 5 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9] | [6, 16, 6, 0] |
| 6 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9] | [7, 17, 7, 0] |
| 7 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9] | [8, 10, 4, 0] |
| 8 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 8] | [9, 5, 4, 0] |
| 9 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9] | [10, 10, 4, 0] |
| 10 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9] | [11, 10, 4, 0] |
| 11 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9] | [12, 10, 4, 0] |
| 12 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9] | [13, 10, 4, 0] |
| 13 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9] | [14, 10, 4, 0] |
| 14 | 1500 | 3000 | 400 | 1027 | [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9] | [15, 15, 5, 0] |
| 15 | 2500 | 5000 | 400 | 1027 | [1, 2, 3, 4, 4, 5, 5, 6, 6, 7, 8, 9] | [16, 18, 8, 0] |

### 11.4 Temuan lain dari run 2 pemain dan 4 pemain

- **Sewa 85 terbukti dibayar sungguhan** (Kakashi → Naruto, petak 160/85, ±frame 23034, run 4 pemain).
- **Battle:** saat dua pemain bertemu, muncul layar serang/bertahan dengan roulette "tambahan kekuatan serang"; kartu serangan menambah kekuatan (terlihat Naruto lawan Sakura dengan kartu +2). Chakra juga berubah akibat battle.
- Satu kenaikan +250 pada P2 (frame 20621, langkah 10 per 2 frame) belum teridentifikasi.
- Jalur Party Mode **2 pemain**: lihat `inputs/inputs_2p.txt` (sampai pertandingan, turun dua kali di layar jumlah pemain) dan `inputs/inputs_2lap.txt` (satu putaran penuh). `probe.lua` kini melacak 8 alamat chakra (set A dan B).
- Uji poke dengan format `POKES="21500@13BA6A@2@0,21500@13BB8E@2@0,21500@13C74E@2@245"`.

### 11.5 Masih terbuka

1. Lokasi status logika kepemilikan/level/total nilai barrier, dan nilai barrier tiap level (apakah level 1 = harga + 20%).
2. Konfirmasi rumus bonus dengan sampel bersih ketiga, atau lewat ubah-memori di lokasi logika.
3. Verifikasi tabel roda (11.3) dengan membaca roda tiap karakter di layar.
4. Biaya dan efek level-up, kenaikan +250, sistem battle.

---

## 12. Pembuktian bonus 結界源 (sesi lanjutan)

- **Layar laporan chakra (チャクラ報告書)** muncul saat pemain tiba di start dan merinci bonus: ごほうび (hadiah), 結界数 ×N (jumlah barrier) dengan angkanya, ついかチャクラ合計 (tambahan total), dan 合計チャクラ.
- **Sampel P1 [TERBUKTI dari layar game]:** Party Mode 2 pemain, frame 21500-21700: hadiah **+400**; 結界数 **×7 -> +235**; tambahan total 635; chakra 600 -> 1235. Cocok dengan lonjakan +635 yang tercatat di memori.
- **Bagian barrier 235 = 25% x 940 [DUGAAN KUAT]**, bila dua petak harga 100 yang sudah level 1 dihitung 120 (tujuh petak: 120+120+140+120+200+140+100 = 940). Dukungan: label sewa petak level 1 di layar = 60 (= 1,2 x 50). Nilai barrier level 1 belum dibaca langsung dari panel peta.
- **Status rumus:** struktur "400 tetap + bagian dari nilai barrier" terbukti langsung dari game. Faktor 25% dan nilai level 1 = 120 masih dugaan kuat (cocok persis di sampel P1; sampel tutorial 500 -> 525 dan P2 520 -> 530 juga konsisten).
- **Belum terbaca:** laporan bonus P2 (3 barrier, harapan +130; screenshot frame 16640-16960 belum sempat dibaca) dan panel peta untuk petak level 1.
- **Kartu:** kenaikan +250 yang sebelumnya tak terjelaskan = kartu "kontrol chakra berhasil, pulihkan 250". Kartu lain yang tampil: "Ichiraku Ramen +150" (efek persis belum dibaca) dan satu kartu biru yang tidak terbaca.
- **Menu giliran:** Roulette, Jurus, **Kartu Chance** (muncul hanya bila memegang kartu), Info, Lihat Peta.
- **Struct pemain +112** = penghitung posisi di jalur (0-22; 22 = start). Bonus dibayar saat tiba tepat di start dengan kedua bit kristal; bit lalu terhapus.
- **Logika kepemilikan** tidak ditemukan sebagai array per petak atau bitmask sederhana di RAM (hanya rekaman tampilan yang cocok); uji ubah-memori pada rekaman tampilan tidak memengaruhi bonus.
- **Lingkungan:** proses latar belakang yang berjalan lebih dari ±10 menit beberapa kali mati saat sandbox dijeda. Pecah eksperimen menjadi run <= 9 menit.
- **Langkah berikutnya:** (1) baca laporan P2; (2) baca panel peta untuk 結界価値 petak level 1; (3) satu sampel dengan semua barrier level 0 dan total berbeda.

