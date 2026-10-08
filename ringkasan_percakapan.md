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
