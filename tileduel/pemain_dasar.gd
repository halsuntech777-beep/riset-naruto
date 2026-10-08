@abstract
extends Node3D
# ========================================================================
# PEMAIN_DASAR.GD
# DATA BERSAMA & PEMBANTU: slot 2-4 pemain, teks sudut pandang, narasi, statistik, deklarasi fungsi alur
# pemain.gd dipecah BERTINGKAT (Fase 3): tiap file meneruskan (extends) file
# sebelumnya, jadi semuanya tetap SATU node Pemain -- variabel & fungsi dari file
# lain dipakai langsung seperti dulu. Urutan: pemain_dasar.gd -> pemain_tampilan.gd -> pemain_papan.gd -> pemain_kartu.gd -> pemain_duel.gd -> pemain_jaringan.gd -> pemain.gd
# @abstract = file ini bagian dari pemain.gd, tidak dipasang sendiri ke node.
# ========================================================================

# --- Fungsi alur yang DIPANGGIL dari file bawah, ISINYA ada di file atas ---
# (Godot hanya mengizinkan memanggil fungsi yang sudah dikenal di file ini/di bawahnya.)
@abstract func _jalankan_ai_di_tengah_giliran(slot: int) -> void  # isi: pemain_jaringan.gd
@abstract func periksa_status_petak(slot_index: int = 0)  # isi: pemain.gd
@abstract func _mulai_duel(slot_a: int) -> void  # isi: pemain_duel.gd
@abstract func _proses_tombol_tutup() -> void  # isi: pemain.gd
@abstract func ganti_giliran()  # isi: pemain.gd
@abstract func cek_game_over()  # isi: pemain.gd

var rute_papan: Array[Node3D] = [] 
@export var material_pemain: StandardMaterial3D
@export var material_musuh: StandardMaterial3D 

@onready var anim_pemain = $beras/AnimationPlayer
@onready var model_pemain = $beras
@onready var musuh = $"../Musuh"
@onready var anim_musuh = $"../Musuh/beras/AnimationPlayer"
@onready var model_musuh = $"../Musuh/beras"

@onready var teks_dadu = $"../CanvasLayer/TeksDadu"
@onready var menu_aksi = $"../CanvasLayer/MenuAksi"
@onready var teks_uang = $"../CanvasLayer/TeksUang"
@onready var teks_bintang = $"../CanvasLayer/TeksBintang" 

@onready var tombol_beli = $"../CanvasLayer/MenuAksi/VBoxContainer/TombolBeli"
@onready var tombol_bangun = $"../CanvasLayer/MenuAksi/VBoxContainer/TombolBangun"
@onready var tombol_serang = $"../CanvasLayer/MenuAksi/VBoxContainer/TombolSerang" 

@onready var tombol_tanah = $"../CanvasLayer/MenuAksi/VBoxContainer/TombolTanah"
@onready var tombol_petir = $"../CanvasLayer/MenuAksi/VBoxContainer/TombolPetir"

# Variabel khusus untuk jebakan elemen (dicetak via kode)
var tombol_set_trap: Button
var tombol_trap_air: Button
var tombol_trap_api: Button
var tombol_trap_tanah: Button
var tombol_trap_petir: Button
var tombol_trap_angin: Button
var tombol_trap_batal: Button
@onready var tombol_tutup = $"../CanvasLayer/MenuAksi/VBoxContainer/TombolTutup"
@onready var kamera = $"../Camera3D"
@onready var rolet = $"../CanvasLayer/Rolet"
@onready var ui_elemen = $"../CanvasLayer/UIElemen"

# ---> TAMBAHKAN BARIS INI <---
var tombol_seting: Button 

var target_kamera: Node3D
var geser_kamera = Vector3.ZERO
var label_fps: Label
var sedang_bergerak = false
var giliran_sekarang = "pemain" 

var fase_giliran = "awal" 
var mode_membidik = false 
var sudah_serang_giliran_ini = false
var mode_jual_aset = false 
# Slot yang sedang menjual aset karena hutang. Dulu selalu dianggap slot 0, jadi
# di multiplayer client tidak pernah bisa menjual petaknya sendiri.
var slot_jual_aset: int = 0
var mode_rolet_double = false
var daftar_pemain: Array[DataPemain] = []

# --- STATE MENU GILIRAN AKTIF (Tahap A: parameterisasi periksa_status_petak) ---
# Diset oleh periksa_status_petak(slot_index) tiap kali menu aksi dibangun untuk
# satu slot tertentu. slot_giliran_ui/aktor_giliran_ui = "aku" (slot yg gilirannya
# aktif); slot_lawan_ui = lawan dari slot itu. TIDAK dipakai untuk soal kepemilikan
# aset (pemilik_petak, siapa_punya di luar fungsi ini tetap hardcode 0/1 permanen).
var slot_giliran_ui: int = 0
var aktor_giliran_ui: String = "pemain"
var slot_lawan_ui: int = 1
var material_giliran_ui: StandardMaterial3D

# --- Bagian B1: indikator debug jaringan (LocalPlay -> panggung_utama) ---
var label_debug_jaringan: Label
# Bagian B2: slot mana yang dikendalikan device INI. Host selalu 0, client
# selalu 1 (khusus 2 pemain — akan berubah saat dukungan 4 pemain ditambah).
# Di mode solo, nilainya tidak dipakai sama sekali (guard di bawah selalu
# memeriksa peran_multiplayer != "" dulu sebelum membandingkan ke slot_lokal).
var slot_lokal: int = 0
# ========================================================
# MODE UJI DUEL — SEMENTARA, matikan sebelum rilis!
# Saat true, dadu selalu menghasilkan angka tetap. Karena kedua pemain mulai
# dari petak yang sama dan melangkah sama jauh, mereka selalu mendarat di petak
# yang sama juga: host membeli/memasang jebakan, lalu client menyusul ke petak
# itu — duel dan jebakan tanah langsung terpicu tiap giliran, tanpa perlu
# menunggu kebetulan angka dadu yang pas.
# Satu saklar untuk SEMUA bantuan pengujian duel — supaya tidak ada yang lupa
# dimatikan. Saat true: (1) dadu selalu UJI_DADU_ANGKA, (2) membeli petak tidak
# langsung mengakhiri giliran, sehingga sempat memasang jebakan tanah dulu
# (jebakan tanah hanya bisa dipasang di petak yang sudah dimiliki).
const UJI_DUEL := false
const UJI_DADU_ANGKA := 3
# Saklar uji lempar koin: true = angka rolet sengaja dipilih supaya skor akhir
# duel SERI, jadi lempar koin penentu seri muncul di SETIAP duel (solo maupun
# multiplayer). Pasangkan dengan UJI_DUEL = true supaya duelnya cepat terpicu.
# WAJIB false sebelum rilis.
const UJI_SERI := false
# Penanda: host sedang menjalankan aksi ATAS NAMA pemain jaringan (bukan input
# lokal). Tanpa ini, penjaga di _teruskan_aksi_ke_host() akan menolak eksekusi
# host sendiri karena melihat "ini bukan giliran slot lokal".
var _sedang_eksekusi_dari_rpc: bool = false

# CLIENT: jumlah animasi pemakaian kartu (rpc_animasi_pakai_kartu) yang masih
# diputar di layar ini. Selama > 0, narasi dari host (rpc_umumkan) ditahan dulu
# sampai animasinya selesai -- animasi di client bisa mulai sedikit lebih lambat
# daripada di host (jeda jaringan / device lebih lambat), jadi tanpa ini kalimat
# "P4 inflicted LOW ROLL..." bisa muncul sebelum kartunya selesai masuk ke target.
var _animasi_kartu_klien: int = 0
signal animasi_kartu_klien_selesai
# Antrian langkah gerakan di sisi client, diproses berurutan satu per satu.
var _antrian_langkah_client: Array = []

# CLIENT: petak tujuan langkah yang SEDANG diputar (-1 = tidak ada) -- supaya
# kejadian di sebuah petak (mis. koin diambil) baru diputar setelah karakternya
# benar-benar tiba di sana (lihat _tunggu_langkah_ke_petak).
var _langkah_diputar: int = -1

var harga_tanah = 300
var harga_menara_lv1 = 500
var harga_menara_lv2 = 800 
# ========================================================
# 2-4 PEMAIN: SLOT & DATA PER SLOT
# Slot 0 = node ini sendiri (biru), slot 1 = node Musuh (merah), slot 2-3 dibuat
# dari salinan node Musuh (hijau, kuning). Nama aktor slot 0/1 sengaja tetap
# "pemain"/"musuh" seperti dulu, jadi semua kode & RPC lama tetap berlaku untuk
# permainan 2 pemain.
# ========================================================
const MAKS_PEMAIN := 4
const NAMA_AKTOR = ["pemain", "musuh", "pemain3", "pemain4"]
const WARNA_SLOT = [Color(0.2, 0.5, 1.0), Color(1.0, 0.2, 0.2), Color(0.15, 0.8, 0.3), Color(1.0, 0.8, 0.1)]
var daftar_node_karakter: Array = [] # node yang digerakkan per slot
var daftar_model: Array = []         # model "beras" per slot
var daftar_anim: Array = []          # AnimationPlayer per slot
var _material_slot_cadangan: Array = [] # material warna slot 2-3 (slot 0-1 pakai export)
# Data yang dulu ditulis dua kali (versi _pemain & _musuh) kini satu array per
# slot. Nama lamanya tetap ada sebagai alias ke slot 0/1 (lihat di bawah).
var tipe_dadu_slot: Array = ["normal", "normal", "normal", "normal"]
var sisa_durasi_dadu_slot: Array = [0, 0, 0, 0]
var putaran_slot: Array = [0, 0, 0, 0]
var kemarahan_slot: Array = [0, 0, 0, 0] # "dendam" AI di slot itu pada penyerangnya
var sasaran_dendam_slot: Array = [-1, -1, -1, -1] # siapa yang terakhir menyerang petak slot itu
var koleksi_permata_slot: Array = [_array_teks(), _array_teks(), _array_teks(), _array_teks()]

# ---> TAMBAHAN VARIABEL DADU BARU <---
var tipe_dadu_pemain: String:
	get: return tipe_dadu_slot[0]
	set(nilai): tipe_dadu_slot[0] = nilai
var sisa_durasi_dadu_pemain: int:
	get: return sisa_durasi_dadu_slot[0]
	set(nilai): sisa_durasi_dadu_slot[0] = nilai
var tipe_dadu_musuh: String:
	get: return tipe_dadu_slot[1]
	set(nilai): tipe_dadu_slot[1] = nilai
var sisa_durasi_dadu_musuh: int:
	get: return sisa_durasi_dadu_slot[1]
	set(nilai): sisa_durasi_dadu_slot[1] = nilai
var panel_ui_target: ColorRect
var putaran_pemain: int:
	get: return putaran_slot[0]
	set(nilai): putaran_slot[0] = nilai
var putaran_musuh: int:
	get: return putaran_slot[1]
	set(nilai): putaran_slot[1] = nilai

var kemarahan_musuh: int:
	get: return kemarahan_slot[1]
	set(nilai): kemarahan_slot[1] = nilai
var ai_probabilitas_beli_tanah = 100

var status_kepemilikan_petak = [] 
# --- TAMBAHAN VARIABEL UNTUK ANIMASI UI ELEGAN ---
# (per slot; nama lama _pemain/_musuh = alias slot 0/1)
var uang_tampil_slot: Array = [2500, 2500, 2500, 2500]
var warna_hex_slot: Array = ["#ffffff", "#ffffff", "#ffffff", "#ffffff"]
var tween_uang_slot: Array = [null, null, null, null]
var uang_pemain_tampil: int:
	get: return uang_tampil_slot[0]
	set(nilai): uang_tampil_slot[0] = nilai
var uang_musuh_tampil: int:
	get: return uang_tampil_slot[1]
	set(nilai): uang_tampil_slot[1] = nilai
var warna_pemain_hex: String:
	get: return warna_hex_slot[0]
	set(nilai): warna_hex_slot[0] = nilai
var warna_musuh_hex: String:
	get: return warna_hex_slot[1]
	set(nilai): warna_hex_slot[1] = nilai
var pemilik_petak: Array[int] = []
var level_menara_petak = [] 
var nyawa_petak = []
# Berapa kali PEMILIK petak ini berhenti tepat di atasnya sejak membelinya (atau
# sejak menara terakhir dibangun). Syarat bangun/upgrade menara: minimal 1 --
# artinya pemain harus berhenti lagi di petaknya sendiri, bukan menunggu putaran.
var berhenti_di_petak_sendiri: Array[int] = []
var label_petak_3d = [] 
var batas_kamera_min: Vector2
var batas_kamera_max: Vector2
var pemutar_bgm: AudioStreamPlayer
var pemutar_bgm_duel: AudioStreamPlayer
var mode_kritis = false
var mesin_acak = RandomNumberGenerator.new() # <--- TAMBAHKAN BARIS INI
var koleksi_permata_pemain: Array[String]:
	get: return koleksi_permata_slot[0]
	set(nilai): koleksi_permata_slot[0] = nilai
var koleksi_permata_musuh: Array[String]:
	get: return koleksi_permata_slot[1]
	set(nilai): koleksi_permata_slot[1] = nilai
var target_permata_menang: int = 0

# ---> TAMBAHKAN BARIS INI <---
var tombol_gunakan_kartu: Button

const SYARAT_KOIN_MENANG := 3000        # dipakai syarat menang DAN panel HOW TO WIN

# --- QUICK MATCH (Fase 1) ---
const KECEPATAN_QUICK := 1.5
var mode_quick: bool = false
var batas_ronde: int = 0             # 0 = tanpa batas (Classic)
var ronde_sekarang: int = 1
var jumlah_permata_peta: int = 0     # permata di peta (target Quick = separuh)

var label_ronde: RichTextLabel = null

# --- IKLAN BERHADIAH PILIHAN PEMAIN (Fase 1, solo saja) ---
const KARTU_HADIAH_IKLAN = ["dadu_rendah", "dadu_tinggi", "pelindung", "pedang_1"]

# --- FASE 2: statistik pertandingan per slot (untuk XP, penghargaan, misi) ---
# Dihitung di device yang menjalankan logika (solo / host), ikut siaran state ke client,
# ikut baris papan skor di akhir pertandingan.
var statistik_slot: Array = []
var _hadiah_akhir_diproses: bool = false  # hadiah profil sudah dicatat (sekali per pertandingan)
var _ringkasan_hadiah: Dictionary = {}    # hasil ProfilPemain.catat_akhir_match untuk layar akhir

# --- MIGRASI HOST: host keluar -> pemain lain lanjut BERSAMA (lihat bagian MIGRASI HOST) ---
var migrasi = null                  # migrasi_host.gd (UDP & ENet selama migrasi)
var _migrasi_berjalan: bool = false # panel HOST LEFT / host baru / WAITING FOR PLAYERS tampil

const MigrasiHost = preload("res://migrasi_host.gd")
# Host lama (P1) yang jaringannya sendiri hilang (hotspot mati tidak sengaja):
var _mode_jaringan_putus: bool = false

# HANYA diubah robot uji: rig satu mesin tidak bisa mematikan jaringan sungguhan.
var uji_paksa_jaringan_putus: bool = false

var panel_ui_cabang: PanelContainer
var wadah_tombol_cabang: HBoxContainer # <--- VARIABEL BARU
# --- VARIABEL UNTUK MAIN MENU ---
var di_main_menu = true
var sudut_drone = 0.0
var pusat_papan = Vector3.ZERO
var rotasi_kamera_awal: Vector3

# ========================================================
# 2-4 PEMAIN: PEMBANTU SLOT
# Semua kode yang dulu memilih "pemain"/"musuh" (slot 0/1) sekarang lewat
# pembantu ini, jadi berlaku untuk slot mana pun.
# ========================================================
static func _array_teks() -> Array[String]:
	var a: Array[String] = []
	return a

func jumlah_pemain() -> int:
	return daftar_pemain.size()

func _slot_dari_aktor(aktor: String) -> int:
	var s = NAMA_AKTOR.find(aktor)
	return s if s >= 0 else 0

func _aktor_dari_slot(slot: int) -> String:
	return NAMA_AKTOR[clampi(slot, 0, MAKS_PEMAIN - 1)]

func _slot_berikutnya(slot: int) -> int:
	return (slot + 1) % maxi(1, jumlah_pemain())

func _node_karakter(slot: int) -> Node3D:
	if slot >= 0 and slot < daftar_node_karakter.size():
		return daftar_node_karakter[slot]
	return self if slot == 0 else musuh

func _model(slot: int) -> Node3D:
	if slot >= 0 and slot < daftar_model.size():
		return daftar_model[slot]
	return model_pemain if slot == 0 else model_musuh

func _anim(slot: int):
	if slot >= 0 and slot < daftar_anim.size():
		return daftar_anim[slot]
	return anim_pemain if slot == 0 else anim_musuh

func _model_aktor(aktor: String) -> Node3D:
	# Dipakai ui_petak.gd (efek serangan) untuk mengarahkan kamera.
	return _model(_slot_dari_aktor(aktor))

func _slot_dari_model(model: Node3D) -> int:
	for s in range(daftar_model.size()):
		if daftar_model[s] == model:
			return s
	return 0 if model == model_pemain else 1

func _warna_slot(slot: int) -> Color:
	return WARNA_SLOT[clampi(slot, 0, MAKS_PEMAIN - 1)]

func _material_slot(slot: int) -> StandardMaterial3D:
	if slot == 0: return material_pemain
	if slot == 1: return material_musuh
	while _material_slot_cadangan.size() <= slot:
		_material_slot_cadangan.append(null)
	if _material_slot_cadangan[slot] == null:
		var m = StandardMaterial3D.new()
		m.albedo_color = _warna_slot(slot)
		_material_slot_cadangan[slot] = m
	return _material_slot_cadangan[slot]

func _nama_slot(slot: int) -> String:
	# Nama pemain lain di teks. Permainan 2 pemain tetap "Enemy" seperti dulu;
	# 3-4 pemain memakai "P1".."P4" (P1 biru, P2 merah, P3 hijau, P4 kuning).
	if jumlah_pemain() <= 2:
		return "Enemy"
	return "P%d" % (slot + 1)

func _subjek(slot: int) -> String:
	# "You" untuk pemain di device ini, selain itu nama slotnya.
	return "You" if slot == slot_lokal else _nama_slot(slot)

func _nama_ui(slot: int) -> String:
	# Nama untuk layar-layar pendukung (kartu, persimpangan, duel). Kosong =
	# permainan 2 pemain -> layar itu tetap memakai kalimat lamanya ("ENEMY ...").
	if jumlah_pemain() <= 2:
		return ""
	return "P%d" % (slot + 1)

func _aktor_ui_kartu(slot: int) -> String:
	# petak_kartu.gd mengenal dua sisi: "pemain" = pemain di device ini, "musuh"
	# = pemain lain (di solo, AI di sisi ini memilih kartunya sendiri).
	return "pemain" if slot == slot_lokal and not _is_ai(slot) else "musuh"

func _is_ai(slot: int) -> bool:
	return slot >= 0 and slot < jumlah_pemain() and daftar_pemain[slot].jenis_kontrol == DataPemain.JenisKontrol.AI

func _siapkan_slot_pemain(tunda_tambah: bool = false) -> void:
	# Node, model & AnimationPlayer tiap slot. Slot 0 & 1 dari scene; slot 2-3
	# dibuat dari SALINAN node Musuh lalu diwarnai hijau/kuning. Aman dipanggil
	# berulang: node yang sudah ada dipakai lagi. tunda_tambah = true saat dipanggil
	# dari _ready (scene induk masih sibuk menyiapkan anak-anaknya).
	daftar_node_karakter = [self, musuh]
	daftar_model = [model_pemain, model_musuh]
	daftar_anim = [anim_pemain, anim_musuh]
	for s in range(2, jumlah_pemain()):
		var nama = "Pemain%d" % (s + 1)
		var node = get_parent().get_node_or_null(nama)
		var baru = node == null
		if baru:
			node = musuh.duplicate()
			node.name = nama
			for nm in ["EfekGelembung", "EfekTerbakar"]:
				var sisa = node.get_node_or_null("beras/" + nm)
				if sisa: sisa.free()
			node.position = musuh.position
		var model = node.get_node("beras")
		var anim = model.get_node("AnimationPlayer")
		daftar_node_karakter.append(node)
		daftar_model.append(model)
		daftar_anim.append(anim)
		if baru:
			_warnai_karakter(model, _warna_slot(s))
			if tunda_tambah:
				get_parent().add_child.call_deferred(node)
				anim.play.call_deferred("idle")
			else:
				get_parent().add_child(node)
				anim.play("idle")

# --- Teks dari sudut pandang device INI (2 pemain: kalimat lama apa adanya) ---
func _teks_hasil_dadu(slot: int, angka: int) -> String:
	if slot == slot_lokal:
		return "Your Roll: " + str(angka)
	return _nama_slot(slot) + " Roll: " + str(angka)

func _teks_dadu_habis(slot: int) -> String:
	if slot == slot_lokal:
		return "Your dice effect worn off!"
	return _nama_slot(slot) + " dice effect worn off!"

func _teks_terbakar(slot: int, sisa: int, jumlah_rugi: int = -1) -> String:
	# Fase 4 (A4): jumlah_rugi dititipkan lewat parameter slot_lain milik
	# _umumkan/_teks_narasi (dipakai ulang -- bukan berarti "slot lain" untuk
	# kunci "terbakar"). -1 (pemanggil lama/belum mengisi) = angka dasar
	# DataRole (class_name global, aman dirujuk dari file paling bawah ini).
	var rugi = jumlah_rugi if jumlah_rugi >= 0 else DataRole.DASAR["bakar_per_giliran"]
	if slot == slot_lokal:
		return "You are burning! Lost " + str(rugi) + " Coins. (" + str(sisa) + " turns left)"
	return _nama_slot(slot) + " is burning! Lost " + str(rugi) + " Coins. (" + str(sisa) + " turns left)"

func _teks_lumpuh(slot: int) -> String:
	if slot == slot_lokal:
		return "You are paralyzed! Cannot move this turn."
	return _nama_slot(slot) + " is paralyzed! Cannot move this turn."

func _teks_denda(slot_pembayar: int, jumlah: int, kalah_duel: bool) -> String:
	if kalah_duel:
		return _subjek(slot_pembayar).to_upper() + " LOST THE FIGHT! Extra fine: " + str(jumlah) + " Coins."
	if slot_pembayar == slot_lokal:
		return "You gave up. Paid fine: " + str(jumlah) + " Coins."
	return _nama_slot(slot_pembayar) + " gave up. Paid fine: " + str(jumlah) + " Coins."

func _teks_rebut(slot_pemenang: int, slot_korban: int) -> String:
	if slot_pemenang == slot_lokal:
		return "FIGHT WON! This tile is now yours!"
	if slot_korban == slot_lokal or jumlah_pemain() <= 2:
		return _nama_slot(slot_pemenang).to_upper() + " WON! Your tile is stolen!"
	return _nama_slot(slot_pemenang) + " WON! " + _nama_slot(slot_korban) + "'s tile is stolen!"

func _teks_petak_lawan(slot_pemilik: int, denda: int) -> String:
	if jumlah_pemain() <= 2:
		return "Enemy Tile! Give Up (Pay " + str(denda) + ") or Fight?"
	return _nama_slot(slot_pemilik) + "'s Tile! Give Up (Pay " + str(denda) + ") or Fight?"

func _peer_slot(slot: int) -> int:
	# Peer ENet pemilik slot (manusia jaringan), -1 kalau bukan.
	if slot < 0 or slot >= jumlah_pemain():
		return -1
	if daftar_pemain[slot].jenis_kontrol != DataPemain.JenisKontrol.MANUSIA_JARINGAN:
		return -1
	return daftar_pemain[slot].id_jaringan

func _peer_client_aktif() -> Array:
	# HOST: semua peer client yang masih memegang slot manusia.
	var hasil = []
	for d in daftar_pemain:
		if d.jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN and d.id_jaringan > 1 and not hasil.has(d.id_jaringan):
			hasil.append(d.id_jaringan)
	return hasil

func _rpc_ke_klien_kecuali(kecuali: Array, nama_rpc: String, argumen: Array = []) -> void:
	# HOST: kirim RPC ke setiap client KECUALI peer di daftar "kecuali". Dipakai
	# saat satu device memilih sesuatu dan device lainnya cuma menonton.
	for id in multiplayer.get_peers():
		if kecuali.has(id):
			continue
		match argumen.size():
			0: rpc_id(id, nama_rpc)
			1: rpc_id(id, nama_rpc, argumen[0])
			2: rpc_id(id, nama_rpc, argumen[0], argumen[1])
			3: rpc_id(id, nama_rpc, argumen[0], argumen[1], argumen[2])
			_: rpc_id(id, nama_rpc, argumen[0], argumen[1], argumen[2], argumen[3])

func _slot_dari_peer(id_peer: int) -> int:
	for s in range(jumlah_pemain()):
		if daftar_pemain[s].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN and daftar_pemain[s].id_jaringan == id_peer:
			return s
	return -1

func _teks_gaji_gagal(jumlah_permata: int) -> String:
	# Target 1 (Grassland, dan semua peta di Quick Match): kalimat tunggal. Lebih
	# dari 1: kalimat lama PERSIS (jejak uji sim Classic memakai target 2).
	if jumlah_permata == 1:
		return "SALARY FAILED! Need 1 gem!"
	return "SALARY FAILED! Need " + str(jumlah_permata) + " unique gems!"

func _tunggu_langkah_ke_petak(index_petak: int) -> void:
	# CLIENT: tunggu sampai langkah menuju petak ini -- yang sedang diputar
	# maupun yang masih antri -- selesai diputar di layar ini.
	while _langkah_diputar == index_petak or _antrian_berisi_petak(index_petak):
		await get_tree().process_frame

func _antrian_berisi_petak(index_petak: int) -> bool:
	for item in _antrian_langkah_client:
		if item[0] == index_petak:
			return true
	return false

func _teruskan_aksi_ke_host(nama_aksi: String) -> bool:
	# Dipanggil di awal tiap handler tombol. Mengembalikan TRUE artinya handler
	# harus berhenti (aksinya sudah diteruskan ke host, atau memang diabaikan).
	if fase_giliran == "duel_berlangsung":
		# Duel sedang jalan — tombol apapun harus diabaikan. Tanpa penjaga ini,
		# menekan "Fight" untuk kedua kalinya akan dibaca sebagai tombol "bangun
		# menara" (karena fasenya sudah bukan "konfrontasi" lagi), lalu petak
		# lawan malah ter-upgrade.
		return true
	if StatusJaringan.peran_multiplayer == "":
		return false # mode solo — proses normal seperti biasa
	if _migrasi_berjalan or _mode_jaringan_putus:
		return true # permainan sedang ditahan (migrasi host) — abaikan
	if _sedang_eksekusi_dari_rpc:
		return false # host menjalankan atas nama pemain jaringan — lanjutkan
	if slot_giliran_ui != slot_lokal:
		return true # bukan giliran device ini — abaikan sepenuhnya
	if StatusJaringan.peran_multiplayer == "client":
		# Sembunyikan menunya begitu aksi dikirim, supaya pemain tidak menekan
		# tombol yang sama berkali-kali sementara menunggu balasan host.
		menu_aksi.hide()
		rpc_id(1, "rpc_minta_aksi", nama_aksi)
		return true # client tidak punya otoritas — host yang menjalankan
	return false # host, dan memang gilirannya sendiri

# --- NARASI GILIRAN: teks yang sama maknanya di semua device, dari sudut
# pandang masing-masing (host menyiarkan kunci + slot, bukan kalimat jadinya) ---
func _umumkan(kunci: String, slot: int, angka: int = 0, slot_lain: int = -1) -> void:
	teks_dadu.text = _teks_narasi(kunci, slot, angka, slot_lain)
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_umumkan", kunci, slot, angka, slot_lain)

@rpc("authority", "call_remote", "reliable")
func rpc_umumkan(kunci: String, slot: int, angka: int, slot_lain: int) -> void:
	if slot < 0 or slot >= jumlah_pemain():
		return
	while _animasi_kartu_klien > 0:
		await animasi_kartu_klien_selesai # tunggu animasi kartu di layar ini selesai
	if slot >= jumlah_pemain():
		return
	teks_dadu.show()
	teks_dadu.text = _teks_narasi(kunci, slot, angka, slot_lain)

func _teks_narasi(kunci: String, slot: int, angka: int = 0, slot_lain: int = -1) -> String:
	var nama = _nama_slot(slot)
	match kunci:
		"dadu_habis": return _teks_dadu_habis(slot)
		"terbakar": return _teks_terbakar(slot, angka, slot_lain)
		"lumpuh": return _teks_lumpuh(slot)
		"ai_berpikir": return nama.to_upper() + " TURN! " + nama + " is thinking..."
		"ai_serang": return nama + " attacks from far away!"
		"ai_pakai_kartu": return nama + " is using a card!"
		"ai_lempar_dadu": return nama + " is rolling dice..."
		"ai_gelembung": return nama + " is trapped in Bubble. Skips action."
		"ai_cabang": return nama + " stops on Branch Tile. Turn ends."
		"ai_permata": return nama + " stops on Gem Tile. Turn ends."
		"ai_kartu": return nama + " stops on Card Tile. Turn ends."
		"ai_start": return nama + " rests at Start (Safe Zone)."
		"ai_mendarat":
			if slot_lain == slot_lokal or jumlah_pemain() <= 2:
				return nama + " lands on your tile! " + nama + " is thinking..."
			return nama + " lands on " + _nama_slot(slot_lain) + "'s tile! " + nama + " is thinking..."
		"ai_pedang": return nama + " uses Sword Card! (+" + str(angka) + " ATK)"
		"ai_beli": return nama + " bought this tile!"
		"ai_hemat": return nama + " saves money and skips this tile."
		"ai_bangun": return nama + " builds a tower!"
		"ai_upgrade": return "DANGER! " + nama + " upgrades Tower to Level 2!"
		"ai_lumpuh_akhir": return nama + " is paralyzed. End turn."
		"ai_selesai": return nama + " ends turn."
		"tanah_aktif": return "EARTH TRAP ACTIVATED! Tile HP +1"
		"keluar": return nama + " left the game. AI takes over!"
		"kartu_rendah": return _teks_kartu_dadu("LOW ROLL", slot, slot_lain, angka == 1)
		"kartu_tinggi": return _teks_kartu_dadu("HIGH ROLL", slot, slot_lain, angka == 1)
		"kartu_perisai":
			# 3-4 pemain: sebutkan siapa yang memakainya (2 pemain: kalimat lama).
			if jumlah_pemain() > 2 and slot != slot_lokal:
				return nama + " activated a Shield! (Recovered 500 Coins)"
			return "Shield activated! (Recovered 500 Coins)"
	return ""

# ========================================================
# FASE 2: STATISTIK PERTANDINGAN & HADIAH PROFIL
# Statistik dihitung di solo/host (sinkron, tanpa await & tanpa pengacak -- jejak
# permainan tidak berubah), ikut siaran state, dan ikut baris papan skor akhir.
# ========================================================
func _reset_statistik() -> void:
	statistik_slot = []
	for s in range(jumlah_pemain()):
		statistik_slot.append(ProfilPemain.statistik_kosong())
	if statistik_slot.size() > 0:
		statistik_slot[0]["giliran"] = 1 # giliran pertama P1 tidak lewat ganti_giliran
	_hadiah_akhir_diproses = false
	_ringkasan_hadiah = {}

func _tambah_stat(slot: int, kunci: String, n: int = 1) -> void:
	# Hanya device yang menjalankan logika (solo / host). Client menerima lewat siaran state.
	if StatusJaringan.peran_multiplayer == "client" or slot < 0 or slot >= statistik_slot.size():
		return
	statistik_slot[slot][kunci] = int(statistik_slot[slot].get(kunci, 0)) + n

func _tambah_stat_elemen(slot: int, elemen: String) -> void:
	if StatusJaringan.peran_multiplayer == "client" or slot < 0 or slot >= statistik_slot.size():
		return
	var per_elemen: Dictionary = statistik_slot[slot]["menang_elemen"]
	if per_elemen.has(elemen):
		per_elemen[elemen] = int(per_elemen[elemen]) + 1

# ========================================================
# FUNGSI BARU: PEWARNAAN KARAKTER OTOMATIS (SMART RECOLOR)
# ========================================================
func _warnai_karakter(model: Node3D, warna_target: Color):
	# 1. Cari semua objek jaring (Mesh) di dalam model .glb secara rekursif
	var daftar_mesh = model.find_children("*", "MeshInstance3D", true)
	
	for mesh in daftar_mesh:
		if mesh.mesh == null:
			continue
			
		# 2. Periksa setiap material (surface) yang menempel pada mesh tersebut
		for i in range(mesh.mesh.get_surface_count()):
			var mat_asli = mesh.get_active_material(i)
			
			if mat_asli and mat_asli is StandardMaterial3D:
				# 3. WAJIB DIDUPLIKAT! Agar warna Pemain & Musuh punya memori sendiri-sendiri
				var mat_baru = mat_asli.duplicate()
				
				var warna_lama = mat_baru.albedo_color
				
				# 4. DETEKSI PINTAR: Cari tahu apakah material ini adalah kulit badannya
				# Ciri-ciri kulit badannya di gambar 3.jpg adalah warna Merah (r) sangat dominan
				# Syarat ini akan MENGABAIKAN sarung tangan (putih) dan sepatu (abu-abu)
				if warna_lama.r > warna_lama.g + 0.1 and warna_lama.r > warna_lama.b + 0.1:
					mat_baru.albedo_color = warna_target
					
				# 5. Pasang kembali material yang sudah diperbarui secara paksa (override)
				mesh.set_surface_override_material(i, mat_baru)

func _teks_kartu_dadu(jenis: String, slot: int, slot_target: int, ada_target: bool) -> String:
	# "You inflicted LOW ROLL to Enemy for 3 Turns!" -- dari sudut pandang device ini.
	var nama_target = "Yourself"
	if ada_target:
		if slot_target == slot:
			nama_target = "Yourself" if slot == slot_lokal else _nama_slot(slot)
		else:
			nama_target = "You" if slot_target == slot_lokal else _nama_slot(slot_target)
	return _subjek(slot) + " inflicted " + jenis + " to " + nama_target + " for 3 Turns!"
