class_name DataPemain
extends RefCounted
## Representasi satu slot pemain — bisa manusia lokal, manusia lewat jaringan, atau AI.
## Menggantikan variabel terpisah seperti uang_pemain/uang_musuh, posisi_pemain/posisi_musuh, dst,
## yang sebelumnya membuat banyak fungsi harus ditulis dua kali (versi "pemain" & versi "musuh").

enum JenisKontrol { MANUSIA_LOKAL, MANUSIA_JARINGAN, AI }

var jenis_kontrol: JenisKontrol
var id_jaringan: int = -1        # peer ID Godot untuk multiplayer; -1 kalau lokal atau AI
var nama_tampilan: String = ""   # dipakai di teks UI, gantinya "YOU"/"ENEMY" yang hardcode

var uang: int = 2500
var bintang: int = 0
var posisi_saat_ini: int = 0
var sisa_gelembung: int = 0      # sisa perlindungan dari jebakan air
var sisa_paralisis: int = 0      # sisa giliran terkena efek jebakan petir
var sisa_bakar: int = 0          # sisa giliran terkena efek jebakan api
var inventaris_kartu: Array = []
var sudah_bangkrut: bool = false

# --- Fase 4: role elemen (Langkah A) ---
var role: String = ""                # "" = belum pilih role = perilaku lama (sebelum Fase 4)
var jebakan_dibawa: Array = []        # jenis elemen jebakan yang boleh dipasang (role selalu termasuk)
var build: Dictionary = {}            # node_id -> level; Langkah A = 2 node ketahanan Lv1 (gratis)

# --- Fase 4: role elemen (Langkah B -- field disiapkan di sini, BELUM dibaca/
# diisi kode host/UI mana pun; B-b menyambungkan efek node yang memakainya) ---
var guard_terpakai: Dictionary = {}   # elemen -> true sesudah Guard (node tahan Lv3) dipakai sekali
var sacred_terpakai: bool = false     # Sacred Ground (Ultimate Tanah) sudah dipakai sekali di match ini
var bakar_per_giliran: int = DataRole.DASAR["bakar_per_giliran"] # 14.1: BUKAN angka 50 tertulis di rencana
var bakar_pemilik: int = -1           # slot pemasang jebakan api yang sedang membakar (fire_tax)
var bakar_larang_jebakan: bool = false # long_burn Lv2/3: korban tak bisa pasang jebakan selama terbakar
var kunci_kartu: int = 0              # sisa giliran Use Card terkunci (frozen_bubble)
var low_roll_bubble: bool = false     # frozen_bubble Lv3: LOW ROLL sekali sesudah gelembung pecah

func _init(kontrol: JenisKontrol = JenisKontrol.AI, nama: String = "") -> void:
	jenis_kontrol = kontrol
	nama_tampilan = nama

func is_manusia() -> bool:
	return jenis_kontrol != JenisKontrol.AI
