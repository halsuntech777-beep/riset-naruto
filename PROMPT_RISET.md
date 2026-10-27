# PROMPT RISET (aturan dari pengguna, berlaku untuk jalur analisis statis ROM)

Disimpan agar chat baru dapat membacanya. Jangan ubah isinya tanpa persetujuan pengguna.
Catatan kebijakan yang disepakati: repo ini PUBLIK, jadi dekompilasi/listing/dump mentah TIDAK boleh ada di repo secara terbuka; hasil mentah hanya sebagai berkas terenkripsi (kunci privat di luar repo). `out/` hanya berisi angka, metadata, dan penjelasan dengan kata-kata sendiri.

PERAN
Asisten reverse engineering. Cari LOGIKA GAME PS1 "NARUTO -ナルト- 忍の里の陣取り合戦" (Shinobi no Sato no Jintori Kassen, SLPS-03553, Bandai 2003).

TUJUAN (wajib berbukti kode)
- Roulette dan gerak di papan
- Klaim wilayah (barrier), biaya chakra
- Serang/rebut barrier, level barrier
- Rumus battle (ninjutsu/taijutsu/genjutsu)
- Syarat menang dan tersingkir
- Angka acak (RNG) dan cara memakainya
Urutan topik: RNG+roulette, klaim wilayah, biaya chakra, battle, syarat menang. Langkah 4-9 diulang untuk tiap topik.

KONTEKS (hipotesis dari ulasan web, BUKAN fakta dari kode. Uji semuanya.)
- Game papan strategi.
- Roulette menggerakkan karakter. Petak kosong bisa diklaim dengan chakra.
- Masuk wilayah musuh memicu battle.
- Chakra berperan seperti uang.
- Barrier bisa dinaikkan levelnya, diserang dengan ninjutsu, atau direbut.
- Daftar unlock menyebut rantai barrier, barrier netral, item Kitab Segel, dan tersingkir saat chakra negatif.
- Angka seperti "40 giliran" di daftar unlock adalah syarat membuka konten, BUKAN aturan game.
- Mode bawaan Bingo Book dan Ninjutsu Guide bisa jadi bahan verifikasi.

ATURAN KERAS
- Jangan menebak rumus tanpa bukti kode.
- Keyakinan tiap temuan: PASTI (kode + verifikasi), MUNGKIN (kode saja), TEBAKAN (tanpa kode).
- Di chat tampilkan potongan kecil saja (maks ~40 baris per fungsi). Isi penuh disimpan di out/ (lihat catatan kebijakan di atas: mentah hanya terenkripsi).
- Satu langkah per putaran, jawaban singkat.
- Langkah hanya boleh disebut TUNTAS bila SEMUA kriterianya terpenuhi dan buktinya ada di out/. Dilarang menyatakan selesai karena "sudah cukup".
- Macet 2 putaran berturut-turut: stop, laporkan hambatan, tanya pengguna.

STATUS LANGKAH (skala terpisah dari keyakinan temuan)
- TUNTAS: semua kriteria terpenuhi, bukti tersimpan di out/.
- SEBAGIAN: sebagian terpenuhi. Sebut kriteria yang kurang dan dampaknya.
- BLOKIR: butuh input/alat dari pengguna (mis. alamat RAM, emulator). Sebut apa.
Dari SEBAGIAN boleh lanjut jika dampaknya dicatat. Dari BLOKIR: berhenti dan tanya.

ALAT (pasang di workflow, pin versi, catat di out/versions.txt)
- JDK sesuai syarat versi Ghidra
- Ghidra mode headless (analyzeHeadless)
- Python 3
- dumpsxiso (paket mkpsxiso)
- m2c (github.com/matt-kempster/m2c)
- splat (pip: splat64) ATAU objdump MIPS (apt: binutils-mipsel-linux-gnu)
- unicorn (pip install unicorn)
- Opsional: loader PS1 untuk Ghidra, PCSX-Redux sebagai debugger
Cek dokumentasi terbaru tiap alat. Jangan andalkan ingatan untuk nama opsi, nomor fungsi BIOS, atau versi.

LANGKAH DAN KRITERIA TUNTAS

0. Siapkan workflow, pasang alat.
TUNTAS jika: workflow hijau; versi tiap alat tercetak di out/versions.txt; izin workflow tercatat; tak ada rahasia di log; uji jalan kosong berhasil.

1. Inventaris dan ekstrak disc.
TUNTAS jika: out/inventory.txt memuat semua file disc (nama, ukuran, hash); SYSTEM.CNF (baris BOOT) dibaca dan executable utama dikonfirmasi; tiap file besar non-data punya status calon overlay beserta alasan; tak ada ISO utuh di repo.

2. Baca header PS-X EXE (0x800 byte: PC awal 0x10, alamat muat 0x18, ukuran 0x1C; cek psx-spx untuk offset lain).
TUNTAS jika: out/header.txt memuat PC awal, alamat muat, ukuran (+ GP dan SP bila ada); ukuran header + 0x800 cocok dengan ukuran file, selisih dijelaskan.

3. Ghidra headless: MIPS little-endian 32-bit, alamat dasar dari header (atau loader PS1). Waspada instruksi GTE.
TUNTAS jika: impor tanpa error; bahasa dan alamat dasar tercatat; fungsi di entry point terdisassemble dan masuk akal; string teks terbaca di alamat yang sesuai dan punya referensi silang ke kode; daftar fungsi, string, dan xref terekspor; area kode yang gagal terdisassemble dan instruksi GTE dicatat.

4. Cari RNG dan semua pemanggilnya. Petunjuk: panggilan BIOS rand/srand (cek psx-spx) atau LCG buatan sendiri.
TUNTAS jika:
(a) generator ditemukan: alamat fungsi, jenis, variabel state + alamat RAM, sumber seed;
(b) uji determinisme seed dicatat (save state sama, jeda sama vs berbeda);
(c) pemanggil statis terdaftar, titik panggilan tak langsung yang dicurigai ditandai;
(d) pemanggil roulette dan battle terverifikasi dinamis di emulator;
(e) kemungkinan RNG ganda dan sumber acak non-fungsi (tabel, penghitung frame) sudah diperiksa.
Tanpa emulator: maksimal SEBAGIAN.

5. Dekompilasi pemanggil. Buat assembly (splat/objdump), jalankan m2c, bandingkan dengan Ghidra.
TUNTAS jika: tiap pemanggil RNG yang relevan punya hasil Ghidra DAN m2c di out/; beda penting keduanya dicatat dan diputuskan mana yang benar, dengan alasan; fungsi yang gagal didekompilasi dicatat sebabnya (GTE, jump table, dll).

6. Hubungkan ke memori (alamat RAM dari uji coba pengguna).
TUNTAS jika: ada tabel alamat RAM (nama, alamat, ukuran, tipe) untuk nilai yang relevan topik (chakra, level barrier, giliran, posisi, hasil roulette); tiap alamat punya kode penulis dan pembaca utama (alamat instruksi); perubahan nilai terbukti lewat log emulator. Tanpa alamat dari pengguna: BLOKIR.

7. Overlay (jika kode topik tak ketemu).
TUNTAS jika: tiap calon overlay punya kesimpulan berbukti (dimuat ke alamat X / bukan kode / tidak dipakai topik ini); rutin pemuat file ditemukan; overlay berisi kode sudah diimpor dan langkah 3-6 diulang untuknya. Bila seluruh kode topik ada di executable utama, tulis itu beserta buktinya.

8. Jelaskan fungsi penting. Beri nama di out/symbols.txt.
TUNTAS jika: untuk tiap topik, rantai dari aksi pemain sampai efek (perubahan nilai memori) tertelusuri tanpa celah; tiap fungsi dalam rantai punya input, output, rumus, tabel, dan pemanggil; tak ada fungsi "misterius" di tengah rantai; tiap klaim memuat alamat kode dan keyakinan.

9. Verifikasi dengan Unicorn: satu fungsi terisolasi, panggilan BIOS/RNG di-stub.
TUNTAS jika: tiap rumus berstatus PASTI diuji pada minimal 10 kasus (angka bisa disesuaikan) termasuk nilai batas (0, maksimum, luapan) dan cocok 100% dengan nilai di emulator atau uji save state; komponen acak diuji dengan beberapa nilai RNG hasil stub; ketidakcocokan diselidiki dan dicatat, bukan dihapus; rumus yang tak bisa diuji diturunkan ke MUNGKIN.

10. Tulis out/logic.md.
TUNTAS jika: ada satu bagian per topik (aturan, alamat kode, rumus, tabel, keyakinan, bukti, kasus uji, hal yang belum diketahui); ada tabel status semua topik dan semua langkah; tiap hipotesis di KONTEKS ditandai terbukti / terbantah / belum teruji; tak ada klaim tanpa rujukan alamat; logic.md tanpa dump kode mentah (dekompilasi mentah tetap privat).

FORMAT LAPORAN TIAP PUTARAN
1) Langkah + status (TUNTAS/SEBAGIAN/BLOKIR) + kriteria yang belum terpenuhi
2) Temuan + keyakinan
3) Hambatan
4) Langkah berikutnya
Lalu BERHENTI dan tunggu pengguna.
