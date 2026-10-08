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
