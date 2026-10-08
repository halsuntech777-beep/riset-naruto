@abstract
extends "res://pemain_role.gd"
# ========================================================================
# PEMAIN_PAPAN.GD
# AKSI DI PETAK: beli, bangun, jebakan, serangan jarak jauh, jual aset & hutang, denda, koin/permata/Start (+ sinkron multiplayer-nya)
# pemain.gd dipecah BERTINGKAT (Fase 3): tiap file meneruskan (extends) file
# sebelumnya, jadi semuanya tetap SATU node Pemain -- variabel & fungsi dari file
# lain dipakai langsung seperti dulu. Urutan (Fase 4 menyisipkan pemain_role.gd):
# pemain_dasar.gd -> pemain_tampilan.gd -> pemain_role.gd -> pemain_papan.gd ->
# pemain_kartu.gd -> pemain_duel.gd -> pemain_jaringan.gd -> pemain.gd
# @abstract = file ini bagian dari pemain.gd, tidak dipasang sendiri ke node.
# ========================================================================

# CLIENT: true selama animasi duel masih diputar ulang di layar ini. Kabar
# "petak direbut" dari host ditahan dulu sampai layar duel tertutup, supaya
# efek rebutnya terlihat di papan -- bukan tersembunyi di balik layar duel.
var _replay_duel_berjalan: bool = false
signal replay_duel_selesai
# CLIENT: true selama lemparan jebakan air masih diputar ulang di layar ini.
# Siaran state dari host ditahan dulu sampai karakternya mendarat -- kalau
# tidak, posisinya dikoreksi di tengah udara dan menu muncul terlalu cepat.
var _replay_jebakan_air_berjalan: bool = false
signal replay_jebakan_air_selesai

var _sedang_proses_langkah: bool = false

# CLIENT: petak yang koinnya sedang menunggu efek "diambil" diputar.
var _koin_menunggu_diambil: Dictionary = {}
# CLIENT: true selama efek residu paralisis (getar tubuh + teks "PARALYSIS")
# masih diputar ulang di layar ini -- ganti_giliran() yang memicunya cuma
# berjalan di host, jadi ini disiarkan lewat rpc_mainkan_efek_sisa_paralisis.
# Siaran state ditahan dulu selama efeknya main supaya posisi karakter tidak
# dikoreksi di tengah-tengah getarannya.
var _replay_paralisis_berjalan: bool = false
signal replay_paralisis_selesai
# CLIENT: true selama animasi serangan jarak jauh diputar ulang di layar ini
# (lihat rpc_efek_serangan). Hasil & siaran state ditahan sampai selesai.
var _replay_serangan_berjalan: bool = false
signal replay_serangan_selesai
# CLIENT: bertambah setiap kali siaran state dari host TIBA. Kabar "diambil"
# (koin/permata) yang harus menunggu karakternya tiba dulu memakai angka ini:
# kalau selama menunggu sudah datang siaran state yang lebih baru, nilai uang/
# koleksi di kabar itu sudah basi (mis. koleksi permata sudah di-reset saat
# melewati Start) -- jangan ditimpakan lagi.
var _versi_state: int = 0

# Host: slot manusia jaringan yang menu giliran-nya sedang ditunggu (-1 = tidak
# ada). Dipakai saat device itu putus: AI langsung mengambil alih giliran itu.
var _menunggu_aksi_slot: int = -1

var _iklan_hutang_terpakai: bool = false # +300 koin sudah dipakai di pertandingan ini

func _atur_berhenti_petak(index_petak: int, nilai: int) -> void:
	# Penjaga ukuran: array ini baru terisi saat papan dibangun, sedangkan
	# pembelian/duel bisa terjadi di jalur lain (mis. rig uji).
	if index_petak >= 0 and index_petak < berhenti_di_petak_sendiri.size():
		berhenti_di_petak_sendiri[index_petak] = nilai

func _catat_berhenti_di_petak(slot: int) -> void:
	# Dipanggil setiap kali langkah selesai. Syarat menara memakai angka ini:
	# pemain harus BERHENTI lagi di petak miliknya sendiri (berhenti ke-2 di petak
	# itu, karena berhenti pertama dipakai untuk membelinya).
	var posisi = daftar_pemain[slot].posisi_saat_ini
	if posisi < 0 or posisi >= berhenti_di_petak_sendiri.size():
		return
	if status_kepemilikan_petak.size() > posisi and status_kepemilikan_petak[posisi] and pemilik_petak[posisi] == slot:
		berhenti_di_petak_sendiri[posisi] += 1

func _on_tombol_tanah_pressed():
	pass
	
func _on_tombol_trap_tanah_pressed():
	if _teruskan_aksi_ke_host("trap_tanah"): return
	if not _pasang_jebakan(slot_giliran_ui, "tanah"):
		periksa_status_petak(slot_giliran_ui)
		return
	menu_aksi.hide()
	# B-b bagian 4b: teks berbeda kalau ini pemasangan Sacred Ground gratis --
	# dicek dari jebakan yang BARU SAJA dipasang, bukan sacred_terpakai (yang
	# sudah true selamanya sesudah pemasangan ini, termasuk untuk jebakan tanah
	# BERIKUTNYA yang dipasang normal berbayar).
	var posisi = daftar_pemain[slot_giliran_ui].posisi_saat_ini
	var jebakan_baru = rute_papan[posisi].get_node_or_null("JebakanTanah")
	var sacred = jebakan_baru != null and bool(jebakan_baru.sacred)
	teks_dadu.text = _teks_jebakan_dipasang("JebakanTanah", slot_giliran_ui == slot_lokal, slot_giliran_ui, sacred)
	update_ui_status()
	await get_tree().create_timer(1.5).timeout
	periksa_status_petak(slot_giliran_ui)

func _on_tombol_petir_pressed():
	pass

func _on_tombol_set_trap_pressed():
	# Sembunyikan semua tombol di menu utama
	tombol_beli.hide()
	tombol_bangun.hide()
	tombol_serang.hide()
	tombol_set_trap.hide()
	tombol_tutup.hide()
	if tombol_tanah: tombol_tanah.hide()
	if tombol_petir: tombol_petir.hide()

	var slot = slot_giliran_ui
	var cukup_bintang = daftar_pemain[slot].bintang >= 1

	# Fase 4 (A3): hanya jenis yang DIBAWA role ini yang ditampilkan.
	tombol_trap_air.visible = _jebakan_boleh(slot, "air")
	tombol_trap_air.text = "Water Trap (1 Star)"
	tombol_trap_air.disabled = not cukup_bintang

	tombol_trap_api.visible = _jebakan_boleh(slot, "api")
	tombol_trap_api.text = "Fire Trap (1 Star)"
	tombol_trap_api.disabled = not cukup_bintang

	tombol_trap_tanah.visible = _jebakan_boleh(slot, "tanah")
	# B-b bagian 4b: Sacred Ground (Ultimate Tanah) -- tombol berubah jadi
	# GRATIS kalau belum dipakai sekali pun di pertandingan ini.
	var sacred_tersedia = _sacred_tersedia(slot)
	tombol_trap_tanah.text = "Sacred Earth Trap (FREE)" if sacred_tersedia else "Earth Trap (1 Star, your tile)"
	# K3: jebakan tanah hanya di petak SENDIRI (dulu: petak siapa pun yang sudah dimiliki).
	tombol_trap_tanah.disabled = (not (cukup_bintang or sacred_tersedia)) or not _boleh_tanah_di(slot)

	tombol_trap_petir.visible = _jebakan_boleh(slot, "petir")
	tombol_trap_petir.text = "Lightning Trap (1 Star)"
	tombol_trap_petir.disabled = not cukup_bintang

	tombol_trap_angin.visible = _jebakan_boleh(slot, "angin")
	tombol_trap_angin.text = "Wind Trap (1 Star)"
	tombol_trap_angin.disabled = not cukup_bintang

	tombol_trap_batal.show()
	tombol_trap_batal.text = "Cancel"

func _on_tombol_trap_batal_pressed():
	# Muat ulang UI kembali ke tampilan awal
	periksa_status_petak(slot_giliran_ui)

# Nama node jebakan -> skripnya. Dipakai client untuk membuat salinan jebakan
# (_terapkan_data_jebakan & rpc_jebakan_dipasang).
const PATH_SCRIPT_JEBAKAN = {
	"JebakanAir": "res://jebakan_air.gd",
	"JebakanApi": "res://jebakan_api.gd",
	"JebakanAngin": "res://jebakan_angin.gd",
	"JebakanPetir": "res://jebakan_petir.gd",
	"JebakanTanah": "res://jebakan_tanah.gd",
}

func _kumpulkan_data_jebakan() -> Array:
	# Daftar jebakan yang saat ini terpasang di papan: [index_petak, nama_node,
	# pemilik, info]. C4 (B-c, 26-09): elemen ke-4 (info) dari ambil_info()
	# masing-masing jenis -- field runtime yang belum tentu sama dengan nilai
	# bawaan _init() (mis. sisa_aktif_ulang Phoenix, sisa_pindah Tornado, siluman
	# stealth_charge, sisa_duel/sacred/sisa_tahan_serangan/aktif jebakan tanah).
	var hasil = []
	var nama_jebakan = ["JebakanAir", "JebakanApi", "JebakanAngin", "JebakanPetir", "JebakanTanah"]
	for i in range(rute_papan.size()):
		for nama in nama_jebakan:
			var node_jebakan = rute_papan[i].get_node_or_null(nama)
			if node_jebakan:
				hasil.append([i, nama, node_jebakan.pemilik, node_jebakan.ambil_info()])
	return hasil

func _terapkan_data_jebakan(daftar: Array) -> void:
	# Samakan jebakan di papan client dengan daftar dari host: buang yang tidak
	# ada di daftar, tambahkan yang belum ada.
	# C4 (B-c, 26-09): elemen ke-4 (info) OPSIONAL (item.size() > 3 -- data lama
	# tanpa info tetap aman) diterapkan lewat terapkan_info() baik untuk jebakan
	# yang BARU dibuat (SEBELUM add_child, supaya _ready()/siluman langsung benar
	# sejak awal) MAUPUN yang SUDAH ADA (memperbaiki mismatch -- inilah yang
	# memunculkan lagi jebakan tanah yang tersembunyi di client, lihat
	# jebakan_tanah.gd::terapkan_info).
	var path_script = PATH_SCRIPT_JEBAKAN
	var seharusnya_ada = {}
	for item in daftar:
		var info: Dictionary = item[3] if item.size() > 3 and item[3] is Dictionary else {}
		seharusnya_ada[str(item[0]) + "|" + item[1]] = [item[2], info]

	for i in range(rute_papan.size()):
		for nama in path_script.keys():
			var kunci = str(i) + "|" + nama
			var node_jebakan = rute_papan[i].get_node_or_null(nama)
			if seharusnya_ada.has(kunci) and node_jebakan == null:
				var data_baru: Array = seharusnya_ada[kunci]
				var jebakan = load(path_script[nama]).new()
				jebakan.name = nama
				jebakan.pemilik = data_baru[0]
				jebakan.terapkan_info(data_baru[1])
				rute_papan[i].add_child(jebakan)
				if nama == "JebakanPetir":
					_terapkan_siluman(jebakan)
			elif seharusnya_ada.has(kunci) and node_jebakan != null:
				var data_ada: Array = seharusnya_ada[kunci]
				node_jebakan.terapkan_info(data_ada[1])
				if nama == "JebakanPetir":
					_terapkan_siluman(node_jebakan)
			elif not seharusnya_ada.has(kunci) and node_jebakan != null:
				node_jebakan.queue_free()

func _teks_jebakan_dipasang(nama: String, milik_sendiri: bool, slot_pemasang: int = 1, sacred: bool = false) -> String:
	# Teks saat jebakan dipasang, dari sudut pandang layar yang menampilkannya.
	# Fase 4 (A3, temuan 6): SEMUA jenis punya teks -- dulu hanya Air.
	match nama:
		"JebakanAir":
			return "Water Trap placed on your spot!" if milik_sendiri else _nama_slot(slot_pemasang) + " placed a Water Trap!"
		"JebakanApi":
			return "Fire Trap set! (Burns victim for 3 turns)" if milik_sendiri else _nama_slot(slot_pemasang) + " set a Fire Trap!"
		"JebakanTanah":
			# B-b bagian 4b: Sacred Ground -- pemasangan gratis, tidak habis oleh duel.
			if sacred:
				return "SACRED EARTH TRAP set for FREE!" if milik_sendiri else _nama_slot(slot_pemasang) + " set a Sacred Earth Trap!"
			return "Earth Trap set! (+1 HP in combat)" if milik_sendiri else _nama_slot(slot_pemasang) + " set an Earth Trap!"
		"JebakanPetir":
			return "Lightning Trap set! (Paralyzes victim)" if milik_sendiri else _nama_slot(slot_pemasang) + " set a Lightning Trap!"
		"JebakanAngin":
			return "Wind Trap set! Wait for victim." if milik_sendiri else _nama_slot(slot_pemasang) + " set a Wind Trap!"
	return "Trap set!" if milik_sendiri else _nama_slot(slot_pemasang) + " set a trap!"

func _terapkan_siluman(node) -> void:
	# C6 (B-c, 26-09): stealth_charge (Ultimate Petir) -- jebakan petir dengan
	# siluman=true TIDAK TERLIHAT (mesh & efeknya) bagi siapa pun selain
	# pemiliknya, termasuk di SOLO terhadap AI musuh (slot_lokal manusia tetap
	# tetap, jadi jebakan AI yang siluman otomatis tersembunyi darinya). SATU
	# sumber dipanggil sesudah jebakan petir dipasang/dibuat di mana pun:
	# _pasang_jebakan (host/solo), rpc_jebakan_dipasang & _terapkan_data_jebakan
	# (client). node sengaja tidak diberi tipe -- JebakanPetir tidak punya
	# class_name (dipanggil generik seperti node jebakan lain di file ini).
	if node == null or not is_instance_valid(node) or node.name != "JebakanPetir":
		return
	node.visible = not (bool(node.siluman) and int(node.pemilik) != slot_lokal)

func _siarkan_jebakan_dipasang(nama: String, index_petak: int, pemilik: int, info: Dictionary) -> void:
	# Jebakan baru dipasang di host. Tanpa ini, device lawan baru melihatnya
	# 1.5 dtk kemudian (lewat siaran state di periksa_status_petak), tanpa teks
	# apapun -- dan bintang pemasangnya juga baru berkurang saat itu.
	# C4 (B-c, 26-09): info (ambil_info()) ikut dikirim supaya salinan client
	# langsung benar sejak awal (mis. siluman stealth_charge, sacred Sacred Ground).
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_jebakan_dipasang", nama, index_petak, pemilik, daftar_pemain[pemilik].bintang, info)

# ========================================================
# FASE 4 (A3): FUNGSI INTI PASANG JEBAKAN -- TANPA UI.
# Dipakai KELIMA handler tombol (manusia/host) DAN AiJebakan (A5). AI TIDAK
# BOLEH memanggil handler tombol (temuan 8): handler bekerja atas
# slot_giliran_ui, yang cuma diisi periksa_status_petak (jalur menu manusia,
# tidak pernah dilewati giliran AI).
# ========================================================
func _pasang_jebakan(slot: int, elemen: String) -> bool:
	if not DataRole.NODE_JEBAKAN.has(elemen):
		return false
	# B-b bagian 4b: Sacred Ground (Ultimate Tanah) -- jebakan tanah PERTAMA
	# pemain ini gratis, sekali per pertandingan.
	var gratis_sacred = elemen == "tanah" and _sacred_tersedia(slot)
	if not _boleh_pasang_jebakan_di(slot, gratis_sacred):
		return false
	if not _jebakan_boleh(slot, elemen):
		return false
	if elemen == "tanah" and not _boleh_tanah_di(slot): # K3
		return false
	if gratis_sacred:
		daftar_pemain[slot].sacred_terpakai = true
	else:
		daftar_pemain[slot].bintang -= DataRole.DASAR["biaya_jebakan"]
	_tambah_stat(slot, "jebakan_pasang")
	if elemen == daftar_pemain[slot].role:
		_tambah_stat(slot, "jebakan_role_pasang")
	var nama_node: String = DataRole.NODE_JEBAKAN[elemen]
	var posisi = daftar_pemain[slot].posisi_saat_ini
	var petak_target = rute_papan[posisi]
	var jebakan = load(PATH_SCRIPT_JEBAKAN[nama_node]).new()
	jebakan.name = nama_node
	jebakan.pemilik = slot
	if elemen == "api" and _punya_ultimate(slot, "api"): # B-b (B4): Ultimate Phoenix
		jebakan.sisa_aktif_ulang = 1
	if elemen == "angin" and _punya_ultimate(slot, "angin"): # C7 (B-c, 26-09): Ultimate Tornado (perbaikan T1)
		jebakan.sisa_pindah = 1
	if elemen == "petir" and _punya_ultimate(slot, "petir"): # C6 (B-c, 26-09): Ultimate stealth_charge -- SEMUA jebakan petirnya
		jebakan.siluman = true
	if elemen == "tanah": # B-b bagian 4 (hard_rock) + 4b (fortress/Sacred Ground)
		jebakan.sisa_duel = int(_angka_jebakan(slot, "tanah")["sisa_duel"])
		jebakan.sisa_tahan_serangan = int(_angka_jebakan(slot, "tanah")["tahan_serangan"])
		if gratis_sacred:
			jebakan.sacred = true
			# Sacred Ground memakai Fortress paling tinggi Lv2 (B4 bagian 1) --
			# jangan MENURUNKAN kalau pemasang sudah punya fortress lebih tinggi sendiri.
			jebakan.sisa_tahan_serangan = maxi(jebakan.sisa_tahan_serangan, int(DataRole.NODE_LV["fortress"][2]))
	petak_target.add_child(jebakan)
	if elemen == "petir":
		_terapkan_siluman(jebakan)
	_siarkan_jebakan_dipasang(nama_node, posisi, slot, jebakan.ambil_info())
	return true

@rpc("authority", "call_remote", "reliable")
func rpc_jebakan_dipasang(nama: String, index_petak: int, pemilik: int, bintang_pemilik: int, info: Dictionary = {}) -> void:
	# Diterima di CLIENT: pasang salinan jebakannya SAAT ITU JUGA + teks dari sudut
	# pandang layar ini. Siaran state 1.5 dtk kemudian tinggal mencocokkan saja.
	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	if not PATH_SCRIPT_JEBAKAN.has(nama) or pemilik < 0 or pemilik >= jumlah_pemain():
		return
	var jebakan = rute_papan[index_petak].get_node_or_null(nama)
	if jebakan == null:
		jebakan = load(PATH_SCRIPT_JEBAKAN[nama]).new()
		jebakan.name = nama
		jebakan.pemilik = pemilik
		# C4 (B-c, 26-09): terapkan_info SEBELUM add_child -- supaya field seperti
		# siluman sudah benar begitu _ready() jalan.
		jebakan.terapkan_info(info)
		rute_papan[index_petak].add_child(jebakan)
	if nama == "JebakanPetir":
		_terapkan_siluman(jebakan)
	daftar_pemain[pemilik].bintang = bintang_pemilik
	update_ui_status()
	# C6 (B-c, 26-09): stealth_charge -- LAWAN (bukan pemiliknya) TIDAK melihat
	# teks pemasangan sama sekali kalau jebakan petir ini siluman (bintang
	# pemasang tetap terlihat berkurang -- kebocoran kecil yang diterima).
	var milik_sendiri = pemilik == slot_lokal
	var siluman = nama == "JebakanPetir" and bool(info.get("siluman", false))
	if not (siluman and not milik_sendiri):
		teks_dadu.show()
		teks_dadu.text = _teks_jebakan_dipasang(nama, milik_sendiri, pemilik, info.get("sacred", false))

# ========================================================
# KOIN TERCECER (hasil jebakan angin) -- MULTIPLAYER
# Petak & jumlahnya diacak di host. Client hanya menampilkan tumpukan koin yang
# sama persis, lalu melihatnya diambil saat karakter menginjak petak itu.
# ========================================================

func _kumpulkan_data_koin() -> Array:
	# Semua tumpukan koin tercecer di papan: [index_petak, isi_koin]
	var hasil = []
	for i in range(rute_papan.size()):
		var koin = rute_papan[i].get_node_or_null("KoinTercecer")
		if koin and not koin.is_queued_for_deletion():
			hasil.append([i, koin.isi_koin])
	return hasil

func _buat_koin_tercecer(index_petak: int, isi: int) -> void:
	var lama = rute_papan[index_petak].get_node_or_null("KoinTercecer")
	if lama:
		lama.name = "KoinTercecerLama" # bebaskan namanya untuk tumpukan baru
		lama.queue_free()
	var koin_baru = preload("res://koin_tercecer.gd").new()
	koin_baru.name = "KoinTercecer"
	koin_baru.isi_koin = isi
	rute_papan[index_petak].add_child(koin_baru)

func _terapkan_data_koin(daftar: Array) -> void:
	# CLIENT: samakan tumpukan koin di papan dengan daftar dari host (pengaman
	# kalau ada kabar yang terlewat, mis. petak di-reset ke netral di host).
	var seharusnya = {}
	for item in daftar:
		seharusnya[int(item[0])] = int(item[1])
	for i in range(rute_papan.size()):
		var koin = rute_papan[i].get_node_or_null("KoinTercecer")
		var ada = koin != null and not koin.is_queued_for_deletion()
		if seharusnya.has(i):
			if ada: koin.isi_koin = seharusnya[i]
			else: _buat_koin_tercecer(i, seharusnya[i])
		elif ada and not _koin_menunggu_diambil.has(i):
			# (Yang sedang menunggu efek "diambil"-nya diputar dibiarkan dulu --
			# rpc_koin_diambil yang akan melenyapkannya.)
			koin.queue_free()

func _siarkan_koin_tercecer(hasil_sebar: Array) -> void:
	# Dipanggil host tepat setelah jebakan angin menyebar koin. Isi akhir tiap
	# tumpukan ikut dikirim supaya angkanya pasti sama di client.
	if StatusJaringan.peran_multiplayer != "host" or hasil_sebar.is_empty():
		return
	var data = []
	for item in hasil_sebar:
		var koin = rute_papan[item[0]].get_node_or_null("KoinTercecer")
		data.append([item[0], item[1], koin.isi_koin if koin else item[1]])
	rpc("rpc_koin_tercecer", data)

@rpc("authority", "call_remote", "reliable")
func rpc_koin_tercecer(data: Array) -> void:
	# Diterima di CLIENT, bersamaan dengan efek jebakan anginnya: koin jatuh di
	# petak-petak ini. Tumpukan lama bertambah (berdenyut), yang baru muncul.
	for item in data:
		var idx = int(item[0])
		if idx < 0 or idx >= rute_papan.size():
			continue
		var koin = rute_papan[idx].get_node_or_null("KoinTercecer")
		if koin and not koin.is_queued_for_deletion():
			koin.tambah_koin(int(item[1]))
			koin.isi_koin = int(item[2])
		else:
			_buat_koin_tercecer(idx, int(item[2]))

@rpc("authority", "call_remote", "reliable")
func rpc_koin_diambil(index_petak: int, slot_pengambil: int, jumlah: int, uang_baru: int) -> void:
	# Diterima di CLIENT: koin di petak ini diambil. Tunggu sampai karakternya
	# benar-benar tiba di petak itu di layar ini (langkahnya bisa masih diputar),
	# baru koinnya lenyap dengan efek "+X" -- sama seperti urutan di host.
	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	if slot_pengambil < 0 or slot_pengambil >= jumlah_pemain():
		return
	_koin_menunggu_diambil[index_petak] = true
	var versi_awal = _versi_state
	await _tunggu_langkah_ke_petak(index_petak)
	_koin_menunggu_diambil.erase(index_petak)

	var target_model = _model(slot_pengambil)
	teks_dadu.show()
	teks_dadu.text = _subjek(slot_pengambil) + " found " + str(jumlah) + " Coins!"
	var koin = rute_papan[index_petak].get_node_or_null("KoinTercecer")
	if koin and not koin.is_queued_for_deletion():
		koin.isi_koin = jumlah # angka "+X" yang melayang pasti sama dengan host
		koin.munculkan_efek_dapat_koin(target_model)
		koin.queue_free()
	# Kalau selama menunggu sudah tiba siaran state yang lebih baru (mis. client
	# tertinggal dan host sudah lewat Start + dapat gaji), uang di siaran itu yang
	# benar -- jangan ditimpa angka lama.
	if _versi_state == versi_awal:
		daftar_pemain[slot_pengambil].uang = uang_baru
	update_ui_status()

# ========================================================
# PERMATA -- MULTIPLAYER
# Koleksi permata cuma dihitung host. Client diberi tahu SAAT ITU JUGA (efek,
# teks, isi koleksi), lalu siaran state mencocokkan ulang koleksinya.
# ========================================================

func _siarkan_permata_diambil(index_petak: int, aktor: String, kode_permata: String, baru: bool, pulih_paralisis: bool) -> void:
	# HOST: dipanggil tepat saat permata diambil (atau dilewati karena sudah punya).
	if StatusJaringan.peran_multiplayer != "host":
		return
	var slot = _slot_dari_aktor(aktor)
	var koleksi = koleksi_permata_slot[slot]
	rpc("rpc_permata_diambil", index_petak, slot, kode_permata, baru, pulih_paralisis, koleksi.duplicate())

@rpc("authority", "call_remote", "reliable")
func rpc_permata_diambil(index_petak: int, slot: int, kode_permata: String, baru: bool, pulih_paralisis: bool, koleksi: Array) -> void:
	# Diterima di CLIENT. Efek & teksnya baru diputar setelah karakternya benar-
	# benar tiba di petak permata di layar ini -- sama seperti rpc_koin_diambil.
	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	if slot < 0 or slot >= jumlah_pemain():
		return
	var versi_awal = _versi_state
	await _tunggu_langkah_ke_petak(index_petak)

	var petak = rute_papan[index_petak]
	if petak.has_method("mainkan_efek_permata"):
		petak.mainkan_efek_permata()

	# Koleksi hanya ditulis kalau belum ada siaran state yang lebih baru selama
	# menunggu (siaran itu sudah membawa koleksi final, mis. sudah di-reset di Start).
	if _versi_state == versi_awal:
		koleksi_permata_slot[slot].assign(koleksi)

	# Teks dari sudut pandang layar INI -- "You" kalau permatanya milik pemain di device ini.
	var siapa = _subjek(slot)
	teks_dadu.show()
	if pulih_paralisis:
		teks_dadu.text = (siapa + " recovered & collected " + kode_permata + " Gem!") if baru else ("Recovered, but already have " + kode_permata + "!")
	else:
		teks_dadu.text = (siapa + " collected " + kode_permata + " Gem!") if baru else ("Passed " + kode_permata + "!")
	update_ui_status()

# ========================================================
# PETAK START -- MULTIPLAYER
# Gaji dihitung host SEBELUM karakter melangkah ke Start (lihat bergerak_maju).
# Client diberi tahu efek, teks, dan angka akhirnya begitu karakternya tiba.
# ========================================================

func _siarkan_lewat_start(index_petak: int, aktor: String, total_gaji: int) -> void:
	# HOST: tepat saat efek "passed Start" diputar di host.
	if StatusJaringan.peran_multiplayer != "host":
		return
	var slot = _slot_dari_aktor(aktor)
	var koleksi = koleksi_permata_slot[slot]
	rpc("rpc_lewat_start", index_petak, slot, total_gaji, daftar_pemain[slot].uang, daftar_pemain[slot].bintang, koleksi.duplicate())

@rpc("authority", "call_remote", "reliable")
func rpc_lewat_start(index_petak: int, slot: int, total_gaji: int, uang_baru: int, bintang_baru: int, koleksi: Array) -> void:
	# Diterima di CLIENT: urutan sama dengan host -- teks + efek pilar & "+X KOIN",
	# lalu koin/bintang/koleksi permata (yang di-reset saat gajian) diperbarui.
	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	if slot < 0 or slot >= jumlah_pemain():
		return
	var versi_awal = _versi_state
	await _tunggu_langkah_ke_petak(index_petak)

	teks_dadu.show()
	teks_dadu.text = _subjek(slot) + " passed Start! Bonus +" + str(total_gaji)
	if index_petak < label_petak_3d.size() and is_instance_valid(label_petak_3d[index_petak]):
		await label_petak_3d[index_petak].mainkan_efek_lewat_start(total_gaji)

	# Sama seperti koin/permata: jangan timpa siaran state yang lebih baru.
	if _versi_state == versi_awal:
		daftar_pemain[slot].uang = uang_baru
		daftar_pemain[slot].bintang = bintang_baru
		koleksi_permata_slot[slot].assign(koleksi)
	update_ui_status()

func _siarkan_gaji_gagal(index_petak: int) -> void:
	# HOST: gaji hangus karena permata belum lengkap -- karakter berhenti di petak
	# SEBELUM Start (index_petak) selama 2 dtk. Tanpa kabar ini, di client karakter
	# cuma diam tanpa penjelasan.
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_gaji_gagal", index_petak, target_permata_menang)

@rpc("authority", "call_remote", "reliable")
func rpc_gaji_gagal(index_petak: int, jumlah_permata: int) -> void:
	# Diterima di CLIENT.
	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	await _tunggu_langkah_ke_petak(index_petak)
	teks_dadu.show()
	teks_dadu.text = _teks_gaji_gagal(jumlah_permata)

@rpc("authority", "call_remote", "reliable")
func rpc_mainkan_efek_jebakan(nama: String, index_petak: int, aktor: String, tetap: bool = false) -> void:
	# Diterima di CLIENT. MURNI TAMPILAN — angka efeknya (bakar, paralisis, uang)
	# tetap dihitung host dan datang lewat siaran state di akhir giliran.
	# Hanya jebakan petir yang benar-benar MENGHENTIKAN langkah di sini.
	# Api & angin tidak — karakter tetap melanjutkan sisa langkahnya. Kalau
	# antriannya ikut dikosongkan, client berhenti terlalu cepat lalu teleport
	# menyusul di akhir giliran.
	# (Jebakan air punya jalurnya sendiri: rpc_jebakan_air_aktif.)
	# C5 (B-c, 26-09, perbaikan T2): fungsi ini SEKARANG hanya dipakai jebakan
	# yang BENAR mengenai korban -- Guard punya jalur sendiri, rpc_efek_role
	# "guard" (dulu Guard ikut memakai fungsi ini: match di bawah tidak punya
	# kasus Air/Tanah jadi teksnya basi, dan antrian client di atas ikut
	# dikosongkan walau langkah Guard tidak pernah berhenti).
	# tetap: jebakan ini SELAMAT (Phoenix/sisa_aktif_ulang atau Tornado/
	# sisa_pindah masih > 0 di host) -- pemanggil WAJIB mengirim nilainya
	# tegas (true/false), jangan andalkan nilai bawaan parameter RPC ini.
	if nama == "JebakanPetir":
		_antrian_langkah_client.clear()

	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	var node_jebakan = rute_papan[index_petak].get_node_or_null(nama)
	var target_model = _model(_slot_dari_aktor(aktor))
	var target_anim = _anim(_slot_dari_aktor(aktor))
	target_anim.play("idle")

	teks_dadu.show()
	match nama:
		"JebakanAngin": teks_dadu.text = "WIND TRAP! Coins scattered!"
		"JebakanApi":
			# C5 (B-c, 26-09): dulu selalu DASAR["bakar_giliran"] -- salah kalau
			# pemasangnya punya long_burn (durasi build-nya lebih lama dari
			# dasar). Sekarang dari _angka_jebakan, SATU sumber yang sama
			# dipakai host (pemain.gd) & AI.
			var bakar_giliran_api = int(DataRole.DASAR["bakar_giliran"])
			if node_jebakan != null:
				bakar_giliran_api = int(_angka_jebakan(node_jebakan.pemilik, "api")["bakar_giliran"])
			teks_dadu.text = "FIRE TRAP! Burning for %d turns!" % bakar_giliran_api
		"JebakanPetir": teks_dadu.text = "LIGHTNING TRAP! Paralyzed & Stopped!"

	if node_jebakan == null:
		return # jebakan sudah terlanjur dibersihkan — teksnya saja sudah cukup

	match nama:
		"JebakanAngin":
			node_jebakan.mainkan_efek_perampas(target_model)
		"JebakanApi":
			# Beratnya efek ini sekarang ditangani di jebakan_api.gd lewat setelan
			# grafis perangkat masing-masing, bukan lagi dengan melewatinya di client.
			node_jebakan.tempel_efek_terbakar(target_model)
			node_jebakan.mainkan_efek_bakar()
		"JebakanPetir":
			await node_jebakan.tempel_efek_paralisis(target_model, kamera)

	await get_tree().create_timer(1.5).timeout
	# C5 (B-c, 26-09): tetap (Phoenix/Tornado selamat) -- jangan ikut dihapus
	# di client, biarkan tampil sampai siaran state berikutnya menegaskan lagi.
	if is_instance_valid(node_jebakan) and not tetap:
		node_jebakan.queue_free()

@rpc("authority", "call_remote", "reliable")
func rpc_efek_role(jenis: String, data: Dictionary) -> void:
	# Diterima di CLIENT. C5 (B-c, 26-09) -- SATU pintu baru untuk efek "peran"
	# yang MURNI tayangan (angka resminya tetap dihitung host, datang lewat
	# siaran state seperti biasa): Guard (menggantikan 5 panggilan lama ke
	# rpc_mainkan_efek_jebakan di cabang Guard -- bug T2, lihat komentar di
	# fungsi itu), lalu Tornado/Tsunami/card_magnet/chain_lightning yang
	# sebelumnya animasinya cuma tampil penuh di host/solo (client baru
	# melihat lewat siaran state periodik, tanpa animasi langsung). Host
	# mengirim HANYA kalau peran_multiplayer == "host" (dicek di titik
	# panggil, bukan di sini).
	match jenis:
		"guard":
			var elemen_guard: String = str(data.get("elemen", ""))
			var petak_guard: int = int(data.get("petak", -1))
			var aktor_guard: String = str(data.get("aktor", ""))
			if aktor_guard != "":
				_anim(_slot_dari_aktor(aktor_guard)).play("idle")
			teks_dadu.show()
			match elemen_guard:
				"air": teks_dadu.text = "GUARD! Water Trap blocked!"
				"angin": teks_dadu.text = "GUARD! Wind Trap blocked!"
				"api": teks_dadu.text = "GUARD! Fire Trap blocked!"
				"petir": teks_dadu.text = "GUARD! Lightning Trap blocked!"
				"tanah": teks_dadu.text = "GUARD! Earth Trap blocked!"
			update_ui_status()
			await get_tree().create_timer(1.0).timeout
			if petak_guard >= 0 and petak_guard < rute_papan.size():
				var nama_guard: String = DataRole.NODE_JEBAKAN.get(elemen_guard, "")
				if nama_guard != "":
					var node_guard = rute_papan[petak_guard].get_node_or_null(nama_guard)
					if is_instance_valid(node_guard):
						node_guard.queue_free()

		"tornado":
			var dari_tornado: int = int(data.get("dari", -1))
			var ke_tornado: int = int(data.get("ke", -1))
			if dari_tornado < 0 or dari_tornado >= rute_papan.size() or ke_tornado < 0 or ke_tornado >= rute_papan.size():
				return
			var node_tornado = rute_papan[dari_tornado].get_node_or_null("JebakanAngin")
			if is_instance_valid(node_tornado):
				node_tornado.get_parent().remove_child(node_tornado)
				rute_papan[ke_tornado].add_child(node_tornado)
				node_tornado.aktif = true
			teks_dadu.show()
			teks_dadu.text = "TORNADO! The Wind Trap moved!"
			update_ui_status()

		"tsunami":
			var daftar_geser: Array = data.get("geser", [])
			for pasang in daftar_geser:
				if not (pasang is Array) or pasang.size() < 2:
					continue
				var slot_tsunami: int = int(pasang[0])
				var pos_baru_tsunami: int = int(pasang[1])
				if pos_baru_tsunami < 0 or pos_baru_tsunami >= rute_papan.size():
					continue
				var node_lain_tsunami = _node_karakter(slot_tsunami)
				if node_lain_tsunami:
					var tw_tsunami = create_tween()
					tw_tsunami.tween_property(node_lain_tsunami, "global_position", rute_papan[pos_baru_tsunami].global_position, 0.6)

		"card_magnet":
			var pencuri_magnet: int = int(data.get("pencuri", -1))
			var korban_magnet: int = int(data.get("korban", -1))
			if pencuri_magnet < 0 or korban_magnet < 0:
				return
			teks_dadu.show()
			teks_dadu.text = "CARD MAGNET! " + _nama_slot(pencuri_magnet) + " stole a card from " + _nama_slot(korban_magnet) + "!"
			update_ui_status()

		"chain_lightning":
			var sasaran_rantai: Array = data.get("sasaran", [])
			if sasaran_rantai.is_empty():
				return
			var nama_sasaran: Array = []
			for s in sasaran_rantai:
				nama_sasaran.append(_nama_slot(int(s)))
			teks_dadu.show()
			teks_dadu.text = "CHAIN LIGHTNING! " + ", ".join(nama_sasaran) + " will roll LOW next turn!"
			update_ui_status()

@rpc("authority", "call_remote", "reliable")
func rpc_mainkan_efek_sisa_paralisis(aktor: String) -> void:
	# Diterima di CLIENT. Efek residu paralisis (giliran di-skip karena kena
	# jebakan petir sebelumnya) dipicu dari dalam ganti_giliran() yang HOST-ONLY,
	# jadi tanpa ini getaran tubuh & teks "PARALYSIS" cuma muncul di layar host.
	# MURNI TAMPILAN -- sisa_paralisis resminya tetap dihitung host dan datang
	# lewat siaran state (rpc_terima_state_giliran) seperti biasa.
	var target_model = _model(_slot_dari_aktor(aktor))
	if not is_instance_valid(target_model): return

	_replay_paralisis_berjalan = true

	var script_petir = preload("res://jebakan_petir.gd")
	var efek_petir = script_petir.new()
	efek_petir.mode_residu = true
	add_child(efek_petir)

	_munculkan_teks_paralysis(target_model)
	await efek_petir.mainkan_efek_sisa_paralisis(target_model, kamera)
	efek_petir.queue_free()

	_replay_paralisis_berjalan = false
	replay_paralisis_selesai.emit()

@rpc("authority", "call_remote", "reliable")
func rpc_jebakan_air_aktif(index_jebakan: int, indeks_jatuh: int, aktor: String) -> void:
	# Diterima di CLIENT. Memutar ulang urutan jebakan air yang SAMA PERSIS dengan
	# host (bergerak_maju): berdiri di petak jebakan -> jeda sebentar -> geiser ->
	# terlempar melengkung ke petak jatuh -> gelembung -> teks "Landed randomly!".
	# Petak jatuhnya sudah diundi host, jadi client tidak mengacak apapun sendiri.
	# MURNI TAMPILAN: posisi & sisa_gelembung resminya tetap dari siaran state.
	if index_jebakan < 0 or index_jebakan >= rute_papan.size():
		return
	if indeks_jatuh < 0 or indeks_jatuh >= rute_papan.size():
		return
	_replay_jebakan_air_berjalan = true

	# Langkah-langkah sampai ke petak jebakan adalah langkah SUNGGUHAN di host
	# (termasuk langkah terakhir yang menginjak petak jebakan itu sendiri). Kalau
	# layar ini masih memutarnya, tunggu sampai habis -- jangan dibuang -- supaya
	# karakter benar-benar berdiri di atas petak jebakan dulu, seperti di host.
	while _sedang_proses_langkah:
		await get_tree().process_frame

	var slot_korban = _slot_dari_aktor(aktor)
	var target_node = _node_karakter(slot_korban)
	var target_model = _model(slot_korban)
	var target_anim = _anim(slot_korban)
	var petak_jebakan = rute_papan[index_jebakan]

	var cek_jebakan = petak_jebakan.get_node_or_null("JebakanAir")
	if cek_jebakan == null:
		# Salinan jebakannya belum ada di layar ini (mestinya tidak terjadi) --
		# buat sementara supaya animasinya tetap sama dengan host.
		cek_jebakan = preload("res://jebakan_air.gd").new()
		cek_jebakan.name = "JebakanAir"
		petak_jebakan.add_child(cek_jebakan)

	# Pengaman: normalnya karakter sudah tepat di petak jebakan (langkahnya baru
	# selesai diputar di atas). Kalau ternyata belum (kasus janggal), geser dulu.
	if target_node.global_position.distance_to(petak_jebakan.global_position) > 0.05:
		var tween_masuk = create_tween()
		tween_masuk.tween_property(target_node, "global_position", petak_jebakan.global_position, 0.3)
		await tween_masuk.finished

	target_anim.play("idle")
	teks_dadu.show()
	teks_dadu.text = "TRAPPED! Geyser Eruption!"

	await get_tree().create_timer(JebakanAir.JEDA_SEBELUM_AKTIF).timeout
	await cek_jebakan.eksekusi_lemparan_acak(target_node, target_model, aktor, self, indeks_jatuh)
	if is_instance_valid(cek_jebakan):
		cek_jebakan.queue_free()

	_replay_jebakan_air_berjalan = false
	replay_jebakan_air_selesai.emit()

func _on_tombol_beli_pressed():
	if _teruskan_aksi_ke_host("beli"): return
	if fase_giliran == "konfrontasi":
		# Menyerah: bayar denda ke pemilik petak ini.
		var pemilik_ini = pemilik_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini]
		_bayar_denda(slot_giliran_ui, pemilik_ini, 1.0)
		return

	# Menu disembunyikan selama jeda di bawah: tanpa ini ketukan kedua (Buy lagi, End
	# Turn, Roll) ikut dijalankan -- petak terbayar dua kali / giliran terlewat.
	menu_aksi.hide()
	daftar_pemain[slot_giliran_ui].uang -= harga_tanah
	_tambah_stat(slot_giliran_ui, "petak_beli")
	status_kepemilikan_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini] = true
	pemilik_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini] = slot_giliran_ui
	nyawa_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini] = 3
	# Berhenti yang sedang berlangsung ini dipakai untuk MEMBELI; menara baru boleh
	# dibangun kalau pemain berhenti lagi di petak ini.
	_atur_berhenti_petak(daftar_pemain[slot_giliran_ui].posisi_saat_ini, 0)

	update_semua_label_petak()
	update_ui_status()

	await get_tree().create_timer(0.8).timeout # <--- JEDA 800ms DITAMBAHKAN

	if fase_giliran == "awal": periksa_status_petak(slot_giliran_ui)
	elif UJI_DUEL: periksa_status_petak(slot_giliran_ui) # tetap di menu untuk pasang jebakan tanah
	else: ganti_giliran()

func _on_tombol_bangun_pressed():
	if _teruskan_aksi_ke_host("bangun"): return
	if fase_giliran == "konfrontasi":
		# Jebakan tanah, kartu pedang, duel, lalu hasilnya -- sama untuk semua
		# slot, manusia maupun AI (lihat _mulai_duel).
		_mulai_duel(slot_giliran_ui)
		return

	# Menu disembunyikan selama animasi & jeda: tanpa ini Build Tower bisa diketuk lagi
	# (Lv1 lalu Lv2 dalam satu pemberhentian) dan giliran bisa berganti dua kali.
	menu_aksi.hide()
	var level_sekarang = level_menara_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini]
	if level_sekarang == 0:
		daftar_pemain[slot_giliran_ui].uang -= harga_menara_lv1
		level_menara_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini] = 1
		nyawa_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini] += 1
		_tambah_stat(slot_giliran_ui, "menara_bangun")

		# --- TUNGGU EFEK VISUAL BANGUN LV 1 ---
		await label_petak_3d[daftar_pemain[slot_giliran_ui].posisi_saat_ini].mainkan_efek_bangun(1)

		_bangun_fisik_menara(daftar_pemain[slot_giliran_ui].posisi_saat_ini, material_giliran_ui, 1)
	elif level_sekarang == 1:
		daftar_pemain[slot_giliran_ui].uang -= harga_menara_lv2
		level_menara_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini] = 2
		nyawa_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini] += 1
		_tambah_stat(slot_giliran_ui, "menara_bangun")
		_tambah_stat(slot_giliran_ui, "menara_lv2")

		# --- TUNGGU EFEK VISUAL BANGUN LV 2 ---
		await label_petak_3d[daftar_pemain[slot_giliran_ui].posisi_saat_ini].mainkan_efek_bangun(2)

		_bangun_fisik_menara(daftar_pemain[slot_giliran_ui].posisi_saat_ini, material_giliran_ui, 2)

	# Satu bangunan per pemberhentian: untuk level berikutnya pemain harus
	# berhenti lagi di petak ini.
	_atur_berhenti_petak(daftar_pemain[slot_giliran_ui].posisi_saat_ini, 0)
	update_semua_label_petak()
	update_ui_status()

	await get_tree().create_timer(0.8).timeout # <--- JEDA 800ms DITAMBAHKAN

	if fase_giliran == "awal": periksa_status_petak(slot_giliran_ui)
	else: ganti_giliran()

func _on_tombol_serang_pressed():
	tombol_beli.hide()
	tombol_bangun.hide()
	tombol_serang.hide()
	
	tombol_tutup.text = "Cancel"
	mode_membidik = true 
	teks_dadu.text = "ATTACK MODE: Tap enemy tile (or Cancel)!"

func _on_tombol_air_pressed():
	if _teruskan_aksi_ke_host("trap_air"): return
	if not _pasang_jebakan(slot_giliran_ui, "air"):
		periksa_status_petak(slot_giliran_ui)
		return
	menu_aksi.hide()
	# Saat client yang memasang, host menjalankan fungsi ini atas namanya --
	# jadi teks di layar host harus berbunyi dari sudut pandang host sendiri.
	teks_dadu.text = _teks_jebakan_dipasang("JebakanAir", slot_giliran_ui == slot_lokal, slot_giliran_ui)
	update_ui_status()
	await get_tree().create_timer(1.5).timeout
	periksa_status_petak(slot_giliran_ui)

func _on_tombol_angin_pressed():
	if _teruskan_aksi_ke_host("trap_angin"): return
	if not _pasang_jebakan(slot_giliran_ui, "angin"):
		periksa_status_petak(slot_giliran_ui)
		return
	menu_aksi.hide()
	teks_dadu.text = _teks_jebakan_dipasang("JebakanAngin", slot_giliran_ui == slot_lokal, slot_giliran_ui)
	update_ui_status()
	await get_tree().create_timer(1.5).timeout
	periksa_status_petak(slot_giliran_ui)

func _on_tombol_api_pressed():
	if _teruskan_aksi_ke_host("trap_api"): return
	if not _pasang_jebakan(slot_giliran_ui, "api"):
		periksa_status_petak(slot_giliran_ui)
		return
	menu_aksi.hide()
	teks_dadu.text = _teks_jebakan_dipasang("JebakanApi", slot_giliran_ui == slot_lokal, slot_giliran_ui)
	update_ui_status()
	await get_tree().create_timer(1.5).timeout
	periksa_status_petak(slot_giliran_ui)

func _on_tombol_trap_petir_pressed():
	if _teruskan_aksi_ke_host("trap_petir"): return
	if not _pasang_jebakan(slot_giliran_ui, "petir"):
		periksa_status_petak(slot_giliran_ui)
		return
	menu_aksi.hide()
	# C6 (B-c, 26-09): stealth_charge -- device INI bisa jadi bystander (host
	# menjalankan handler ini atas nama client lewat _teruskan_aksi_ke_host,
	# lihat pemain_jaringan.gd) -- kalau jebakan yang baru dipasang siluman &
	# device ini bukan pemiliknya, teks pemasangan TIDAK ditampilkan sama sekali.
	var posisi_petir = daftar_pemain[slot_giliran_ui].posisi_saat_ini
	var jebakan_baru_petir = rute_papan[posisi_petir].get_node_or_null("JebakanPetir")
	var siluman_petir = jebakan_baru_petir != null and bool(jebakan_baru_petir.siluman)
	var milik_sendiri_petir = slot_giliran_ui == slot_lokal
	if not (siluman_petir and not milik_sendiri_petir):
		teks_dadu.text = _teks_jebakan_dipasang("JebakanPetir", milik_sendiri_petir, slot_giliran_ui)
	update_ui_status()
	await get_tree().create_timer(1.5).timeout
	periksa_status_petak(slot_giliran_ui)

func tembak_raycast_ke_petak(posisi_sentuh_layar):
	var kamera_aktif = get_viewport().get_camera_3d() 
	var space_state = get_world_3d().direct_space_state
	var ray_origin = kamera_aktif.project_ray_origin(posisi_sentuh_layar)
	var ray_end = ray_origin + kamera_aktif.project_ray_normal(posisi_sentuh_layar) * 2000.0
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var hasil_klik = space_state.intersect_ray(query)

	if hasil_klik:
		var objek_terklik = hasil_klik.collider
		for i in range(rute_papan.size()):
			if rute_papan[i].is_ancestor_of(objek_terklik):
				if mode_jual_aset: _jual_petak(i)
				else: _serang_petak(i)
				return
				
	if mode_jual_aset: 
		teks_dadu.text = "Tap your tile to sell!"
	else:
		mode_membidik = false
		geser_kamera = Vector3.ZERO 
		teks_dadu.text = "Attack canceled."
		periksa_status_petak(slot_giliran_ui) # solo: selalu 0, sama seperti dulu

func _serang_petak(target_index: int) -> void:
	# Petak yang dibidik di device ini (hasil raycast). Solo & host: langsung
	# dieksekusi. Client: dicek dulu di sini, lalu dikirim ke host -- host yang
	# menerapkan serangannya dan memutar efeknya di kedua layar.
	if StatusJaringan.peran_multiplayer != "client":
		eksekusi_serangan(target_index)
		return
	if pemilik_petak[target_index] < 0 or pemilik_petak[target_index] == slot_lokal:
		teks_dadu.text = "WRONG TARGET! Tap enemy tile."
		mode_membidik = false
		periksa_status_petak(slot_giliran_ui)
		return
	mode_membidik = false
	geser_kamera = Vector3.ZERO
	menu_aksi.hide()
	teks_dadu.text = "Launching long range attack!"
	rpc_id(1, "rpc_minta_serang", target_index)

@rpc("any_peer", "call_remote", "reliable")
func rpc_minta_serang(target_index: int) -> void:
	# Diterima di HOST: petak yang dibidik pemain client di device-nya.
	if not multiplayer.is_server() or _migrasi_berjalan or _mode_jaringan_putus:
		return
	if multiplayer.get_remote_sender_id() != _peer_slot(slot_giliran_ui):
		return # bukan giliran pengirim ini
	var sah = target_index >= 0 and target_index < rute_papan.size() \
		and fase_giliran == "awal" and not sudah_serang_giliran_ini \
		and daftar_pemain[slot_giliran_ui].bintang >= 5 \
		and pemilik_petak[target_index] >= 0 and pemilik_petak[target_index] != slot_giliran_ui
	_menunggu_aksi_slot = -1
	if not sah:
		# Ditolak: siarkan ulang state supaya menu client muncul lagi.
		periksa_status_petak(slot_giliran_ui)
		return
	eksekusi_serangan(target_index)

func _jual_petak(target_index: int) -> void:
	# Petak yang diketuk di device ini saat mode jual aset. Solo & host langsung
	# mengeksekusi; client mengirim permintaannya ke host (host yang berwenang).
	if StatusJaringan.peran_multiplayer != "client":
		eksekusi_jual_aset(target_index)
		return
	if pemilik_petak[target_index] != slot_lokal:
		teks_dadu.text = "WRONG! You can only sell your own tile."
		return
	mode_membidik = false
	rpc_id(1, "rpc_minta_jual", target_index)

@rpc("any_peer", "call_remote", "reliable")
func rpc_minta_jual(target_index: int) -> void:
	# Diterima di HOST: petak yang dipilih pemain client untuk dijual.
	if not multiplayer.is_server() or _migrasi_berjalan or _mode_jaringan_putus:
		return
	if not mode_jual_aset:
		return
	if multiplayer.get_remote_sender_id() != _peer_slot(slot_jual_aset):
		return
	if target_index < 0 or target_index >= rute_papan.size():
		return
	eksekusi_jual_aset(target_index)

func eksekusi_jual_aset(target_index):
	var slot = slot_jual_aset
	if pemilik_petak[target_index] != slot:
		teks_dadu.text = "WRONG! You can only sell your own tile."
		return
		
	mode_membidik = false 
	
	var level_aset = level_menara_petak[target_index]
	var nilai_total = harga_tanah
	if level_aset >= 1: nilai_total += harga_menara_lv1
	if level_aset == 2: nilai_total += harga_menara_lv2
	
	var harga_jual = int(nilai_total * 0.7)
	daftar_pemain[slot].uang += harga_jual
	
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_efek_jual", target_index, slot, harga_jual, daftar_pemain[slot].uang)
	
	await label_petak_3d[target_index].mainkan_efek_jual(harga_jual)
	await get_tree().create_timer(0.8).timeout
	
	reset_petak_ke_netral(target_index)
	update_ui_status()
	
	teks_dadu.text = _teks_hasil_jual(slot == slot_lokal, harga_jual, slot)
	await get_tree().create_timer(1.5).timeout
	
	if daftar_pemain[slot].uang >= 0:
		mode_jual_aset = false
		mode_membidik = false
		teks_dadu.text = "Debt CLEARED!"
		if StatusJaringan.peran_multiplayer == "host":
			rpc("rpc_jual_selesai")
		await get_tree().create_timer(1.5).timeout
		if not cek_game_over(): ganti_giliran()
	else: 
		teks_dadu.text = _teks_lanjut_jual(slot == slot_lokal, slot)
		mode_membidik = (slot == slot_lokal)
		if StatusJaringan.peran_multiplayer == "host" and slot != slot_lokal and daftar_pemain[slot].id_jaringan > 1:
			rpc_id(daftar_pemain[slot].id_jaringan, "rpc_minta_jual_aset", slot)

func _teks_hasil_jual(milik_sendiri: bool, harga: int, slot_penjual: int = 1) -> String:
	if milik_sendiri:
		return "Tile sold: +" + str(harga) + " Coins!"
	return _nama_slot(slot_penjual) + " sold a tile: +" + str(harga) + " Coins!"

func _teks_lanjut_jual(milik_sendiri: bool, slot_penjual: int = 1) -> String:
	if milik_sendiri:
		return "Still in minus! Tap another tile to sell."
	return _nama_slot(slot_penjual) + " is still in minus and keeps selling..."

@rpc("authority", "call_remote", "reliable")
func rpc_teks_bangkrut(slot: int) -> void:
	# Diterima di CLIENT: pengumuman bangkrut, dari sudut pandang layar ini.
	teks_dadu.show()
	teks_dadu.text = _subjek(slot).to_upper() + " BANKRUPT! Money is minus."

@rpc("authority", "call_remote", "reliable")
func rpc_minta_jual_aset(slot: int) -> void:
	# Diterima di CLIENT: giliran pemain di device ini memilih petak yang dijual.
	slot_jual_aset = slot
	mode_jual_aset = true
	mode_membidik = (slot == slot_lokal)
	menu_aksi.hide()
	teks_dadu.show()
	teks_dadu.text = "TAP YOUR TILE TO SELL (30% Discount)" if slot == slot_lokal else _nama_slot(slot) + " is selling a tile..."

@rpc("authority", "call_remote", "reliable")
func rpc_efek_jual(target_index: int, slot: int, harga_jual: int, uang_baru: int) -> void:
	# Diterima di CLIENT: efek & akibat penjualan diputar sama seperti di host.
	if target_index < 0 or target_index >= label_petak_3d.size():
		return
	if slot < 0 or slot >= jumlah_pemain():
		return
	daftar_pemain[slot].uang = uang_baru
	update_ui_status()
	await label_petak_3d[target_index].mainkan_efek_jual(harga_jual)
	await get_tree().create_timer(0.8).timeout
	reset_petak_ke_netral(target_index)
	update_semua_label_petak()
	teks_dadu.show()
	teks_dadu.text = _teks_hasil_jual(slot == slot_lokal, harga_jual, slot)

@rpc("authority", "call_remote", "reliable")
func rpc_jual_selesai() -> void:
	# Diterima di CLIENT: hutang lunas, mode jual ditutup di kedua layar.
	mode_jual_aset = false
	mode_membidik = false
	teks_dadu.show()
	teks_dadu.text = "Debt CLEARED!"

func eksekusi_serangan(target_index):
	# Penyerang = pemilik giliran. Solo: pemain manusia -- sama persis seperti
	# dulu. Multiplayer: bisa juga client (lewat rpc_minta_serang).
	var slot = slot_giliran_ui
	var aktor = _aktor_dari_slot(slot)
	var model_penyerang = _model(slot)
	var korban = pemilik_petak[target_index]
	if korban < 0 or korban == slot:
		teks_dadu.text = "WRONG TARGET! Tap enemy tile."
		mode_membidik = false
		periksa_status_petak(slot)
		return
		
	menu_aksi.hide()
		
	sudah_serang_giliran_ini = true 
	# AI yang petaknya diserang jadi "dendam" pada penyerangnya (lihat ai_musuh.gd).
	kemarahan_slot[korban] += 2 
	sasaran_dendam_slot[korban] = slot
	mode_membidik = false
	daftar_pemain[slot].bintang -= 5
	
	# Multiplayer: animasi serangan yang sama diputar di layar lain, saat ini juga.
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_efek_serangan", target_index, slot, daftar_pemain[slot].bintang, korban)

	teks_dadu.text = _teks_serangan_mulai(slot)
	await label_petak_3d[target_index].mainkan_efek_serangan(model_penyerang.global_position, aktor, self)
	await get_tree().create_timer(0.8).timeout
	
	target_kamera = model_penyerang

	# B-b bagian 4b: Fortress (node ketahanan milik PEMILIK PETAK yang diserang,
	# lewat jebakan tanah miliknya sendiri di petak itu) bisa menahan serangan
	# jarak jauh ini SEBELUM nyawa_petak berkurang -- bintang penyerang TETAP
	# terpakai (sudah dikurangi di atas).
	if _benteng_menahan(target_index):
		update_semua_label_petak() # refresh label "(Protected)" kalau jatahnya baru habis
		update_ui_status()
		if StatusJaringan.peran_multiplayer == "host":
			rpc("rpc_hasil_serangan", target_index, slot, false, nyawa_petak[target_index], korban, true)
		teks_dadu.text = "FORTRESS! The attack was blocked."
		await get_tree().create_timer(2.5).timeout
		periksa_status_petak(slot)
		return

	nyawa_petak[target_index] -= 1
	update_semua_label_petak()
	update_ui_status()

	var hancur = nyawa_petak[target_index] <= 0
	if hancur:
		reset_petak_ke_netral(target_index)
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_hasil_serangan", target_index, slot, hancur, nyawa_petak[target_index], korban)
	teks_dadu.text = _teks_hasil_serangan(slot, korban, hancur, nyawa_petak[target_index])

	await get_tree().create_timer(2.5).timeout
	periksa_status_petak(slot)

func _teks_serangan_mulai(slot_penyerang: int) -> String:
	if slot_penyerang == slot_lokal:
		return "Launching long range attack!"
	return _nama_slot(slot_penyerang) + " attacks from far away!"

func _teks_hasil_serangan(slot_penyerang: int, slot_korban: int, hancur: bool, sisa_hp: int) -> String:
	# Dari sudut pandang layar yang menampilkannya (teks penyerang = teks lama
	# pemain, teks yang diserang = teks lama serangan AI; 3-4 pemain: penonton).
	if jumlah_pemain() <= 2:
		if slot_penyerang == slot_lokal:
			return "SUCCESS! You destroyed enemy tile!" if hancur else "Attack Hit! Enemy tile HP left: " + str(sisa_hp)
		return "REVENGE! Enemy destroyed your tile!" if hancur else "Enemy shoots your tile! HP left: " + str(sisa_hp)
	var korban = "your" if slot_korban == slot_lokal else _nama_slot(slot_korban) + "'s"
	if slot_penyerang == slot_lokal:
		return ("SUCCESS! You destroyed " + korban + " tile!") if hancur else ("Attack Hit! " + _nama_slot(slot_korban) + "'s tile HP left: " + str(sisa_hp))
	var penyerang = _nama_slot(slot_penyerang)
	return (penyerang + " destroyed " + korban + " tile!") if hancur else (penyerang + " shoots " + korban + " tile! HP left: " + str(sisa_hp))

@rpc("authority", "call_remote", "reliable")
func rpc_efek_serangan(target_index: int, slot: int, bintang_penyerang: int, _korban: int = -1) -> void:
	# Diterima di CLIENT: serangan jarak jauh dimulai -- animasi yang sama dengan host.
	if target_index < 0 or target_index >= label_petak_3d.size():
		return
	if slot < 0 or slot >= jumlah_pemain():
		return
	_replay_serangan_berjalan = true
	mode_membidik = false
	menu_aksi.hide()
	daftar_pemain[slot].bintang = bintang_penyerang
	if slot == slot_lokal:
		sudah_serang_giliran_ini = true
	update_ui_status()
	teks_dadu.show()
	teks_dadu.text = _teks_serangan_mulai(slot)
	var model_penyerang = _model(slot)
	await label_petak_3d[target_index].mainkan_efek_serangan(model_penyerang.global_position, _aktor_dari_slot(slot), self)
	_replay_serangan_berjalan = false
	replay_serangan_selesai.emit()

@rpc("authority", "call_remote", "reliable")
func rpc_hasil_serangan(target_index: int, slot: int, hancur: bool, sisa_hp: int, korban: int = -1, ditahan_fortress: bool = false) -> void:
	# Diterima di CLIENT: host sudah menerapkan kerusakannya. Ditampilkan setelah
	# animasi di layar ini selesai (bisa tertinggal sedikit dari host).
	# ditahan_fortress (B-b bagian 4b): serangan ditahan Fortress, hancur selalu
	# false & sisa_hp tidak berubah -- teksnya beda dari hasil serangan normal.
	if _replay_serangan_berjalan:
		await replay_serangan_selesai
	if target_index < 0 or target_index >= rute_papan.size():
		return
	if slot < 0 or slot >= jumlah_pemain():
		return
	target_kamera = _model(slot)
	nyawa_petak[target_index] = sisa_hp
	if hancur:
		reset_petak_ke_netral(target_index) # termasuk membongkar menaranya di layar ini
	update_semua_label_petak()
	teks_dadu.show()
	teks_dadu.text = "FORTRESS! The attack was blocked." if ditahan_fortress else _teks_hasil_serangan(slot, korban, hancur, sisa_hp)

func reset_petak_ke_netral(posisi_index):
	status_kepemilikan_petak[posisi_index] = false
	pemilik_petak[posisi_index] = -1
	level_menara_petak[posisi_index] = 0
	nyawa_petak[posisi_index] = 0
	_atur_berhenti_petak(posisi_index, 0)
	var petak_target = rute_papan[posisi_index]
	var _balok_lantai = petak_target.get_child(0) 
	
	for anak in petak_target.get_children():
		# Hanya mengecek dan menghapus JebakanTanah
		if anak.name.begins_with("Emboss") or anak is CSGCylinder3D or (anak is CSGBox3D and anak != _balok_lantai) or anak.name == "KoinTercecer" or anak.name == "JebakanTanah":
			anak.queue_free()
	update_semua_label_petak()

func _tawarkan_iklan_hutang(slot: int) -> bool:
	# SOLO: +300 koin dari iklan berhadiah, sekali per pertandingan. true = hutang
	# lunas dan giliran sudah diteruskan (pemanggil berhenti). Tanpa tawaran fungsi
	# ini kembali tanpa menunggu satu frame pun (jejak uji Classic tetap identik).
	if StatusJaringan.peran_multiplayer != "" or slot != slot_lokal or _is_ai(slot):
		return false
	if _iklan_hutang_terpakai or not PengelolaIklan.rewarded_tersedia():
		return false
	var mau = await UiDinamis.tanya_iklan_hutang(self)
	if not mau:
		return false
	var dapat = await PengelolaIklan.tonton_rewarded()
	if not dapat:
		teks_dadu.text = "No ad right now."
		await get_tree().create_timer(1.5).timeout
		return false
	_iklan_hutang_terpakai = true
	daftar_pemain[slot].uang += 300
	update_ui_status()
	teks_dadu.text = "+300 Coins!"
	await get_tree().create_timer(1.5).timeout
	if daftar_pemain[slot].uang >= 0:
		teks_dadu.text = "Debt cleared!"
		await get_tree().create_timer(1.5).timeout
		if not cek_game_over(): ganti_giliran()
		return true
	teks_dadu.text = "Still in minus. Sell a tile."
	await get_tree().create_timer(1.5).timeout
	return false

func _bayar_denda(slot_pembayar: int, slot_penerima: int, pengali) -> void:
	# Pembayar berdiri di petak milik penerima: menyerah (x1.0) atau kalah duel (x1.2).
	var posisi = daftar_pemain[slot_pembayar].posisi_saat_ini
	var level_menara = level_menara_petak[posisi]
	var denda_dasar = 100
	if level_menara == 1: denda_dasar = 300
	elif level_menara == 2: denda_dasar = 600
	var total_denda = int(denda_dasar * pengali)
	daftar_pemain[slot_pembayar].uang -= total_denda
	daftar_pemain[slot_penerima].uang += total_denda
	
	teks_dadu.text = _teks_denda(slot_pembayar, total_denda, pengali > 1.0)
	_siarkan_pesan_denda(slot_pembayar, total_denda, pengali > 1.0, posisi)
		
	tombol_tutup.disabled = false
	menu_aksi.hide()
	
	await label_petak_3d[posisi].mainkan_efek_denda(total_denda)
	await get_tree().create_timer(0.8).timeout 
	
	update_ui_status()
	await get_tree().create_timer(2.5).timeout
	await sita_aset_untuk_hutang(_aktor_dari_slot(slot_pembayar))

func bayar_denda_ke_musuh(pengali):
	await _bayar_denda(0, 1, pengali)

func bayar_denda_ke_pemain(pengali):
	await _bayar_denda(1, 0, pengali)

func sita_aset_untuk_hutang(aktor):
	var slot_hutang = _slot_dari_aktor(aktor)
	var cek_uang = daftar_pemain[slot_hutang].uang
	if cek_uang >= 0: 
		if not cek_game_over(): ganti_giliran()
		return
		
	teks_dadu.text = _subjek(slot_hutang).to_upper() + " BANKRUPT! Money is minus."
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_teks_bangkrut", slot_hutang)
	await get_tree().create_timer(2.0).timeout

	# Solo: tawaran iklan berhadiah +300 koin (sekali per pertandingan).
	var lunas_iklan = await _tawarkan_iklan_hutang(slot_hutang)
	if lunas_iklan:
		return

	if _is_ai(slot_hutang):
		await _ai_jual_sampai_lunas(slot_hutang)
	else:
		# Pemain manusia (solo, host, atau client) memilih sendiri petak mana yang
		# dijual. Dulu cabang ini dikunci ke slot 0, jadi hutang client selalu
		# ditangani seolah-olah itu petak host.
		slot_jual_aset = slot_hutang
		var punya_aset = false
		for i in range(rute_papan.size()):
			if pemilik_petak[i] == slot_hutang:
				punya_aset = true
				break
				
		if punya_aset:
			mode_jual_aset = true
			mode_membidik = (slot_hutang == slot_lokal)
			menu_aksi.hide()
			teks_dadu.text = "TAP YOUR TILE TO SELL (30% Discount)" if slot_hutang == slot_lokal else _nama_slot(slot_hutang) + " is selling a tile..."
			if StatusJaringan.peran_multiplayer == "host" and slot_hutang != slot_lokal and daftar_pemain[slot_hutang].id_jaringan > 1:
				rpc_id(daftar_pemain[slot_hutang].id_jaringan, "rpc_minta_jual_aset", slot_hutang)
		else:
			teks_dadu.text = "No more tiles! " + ("You carry the debt." if slot_hutang == slot_lokal else _nama_slot(slot_hutang) + " carries the debt.")
			await get_tree().create_timer(2.5).timeout
			if not cek_game_over(): ganti_giliran()

func _ai_jual_sampai_lunas(slot: int) -> void:
	# AI menjual petak termahalnya satu per satu sampai uangnya tidak minus lagi.
	# Dipakai juga saat AI mengambil alih pemain yang putus di tengah menjual aset.
	mode_jual_aset = false
	mode_membidik = false
	while daftar_pemain[slot].uang < 0:
		var petak_dijual = -1
		var harga_jual_termahal = -1
		
		for i in range(rute_papan.size()):
			if status_kepemilikan_petak[i] and pemilik_petak[i] == slot:
				var level_aset = level_menara_petak[i]
				var nilai_total = harga_tanah
				if level_aset >= 1: nilai_total += harga_menara_lv1
				if level_aset == 2: nilai_total += harga_menara_lv2
				var simulasi_harga_jual = int(nilai_total * 0.7)
				if simulasi_harga_jual > harga_jual_termahal:
					harga_jual_termahal = simulasi_harga_jual
					petak_dijual = i
				
		if petak_dijual == -1:
			teks_dadu.text = "No more tiles! " + _nama_slot(slot) + " accepts debt."
			await get_tree().create_timer(2.5).timeout
			break
			
		target_kamera = rute_papan[petak_dijual]
		geser_kamera = Vector3.ZERO 
		teks_dadu.text = _nama_slot(slot) + " is picking a tile to sell..."
		await get_tree().create_timer(1.0).timeout
		
		daftar_pemain[slot].uang += harga_jual_termahal
		# Multiplayer: efek & akibat penjualannya diputar juga di device lain.
		if StatusJaringan.peran_multiplayer == "host":
			rpc("rpc_efek_jual", petak_dijual, slot, harga_jual_termahal, daftar_pemain[slot].uang)
		
		await label_petak_3d[petak_dijual].mainkan_efek_jual(harga_jual_termahal)
		await get_tree().create_timer(0.8).timeout 
		
		reset_petak_ke_netral(petak_dijual)
		update_ui_status()
		teks_dadu.text = _nama_slot(slot) + " sells best tile for " + str(harga_jual_termahal) + " Coins!"
		await get_tree().create_timer(2.0).timeout
		
	if daftar_pemain[slot].uang >= 0:
		teks_dadu.text = _nama_slot(slot) + " debt cleared!"
		await get_tree().create_timer(1.5).timeout
	if not cek_game_over(): ganti_giliran()

# ========================================================
# LOGIKA PENGAMBILAN ITEM SETELAH EFEK PARALISIS SELESAI
# ========================================================
func _ambil_permata_setelah_paralisis(aktor: String, petak: Node3D):
	petak.mainkan_efek_permata()
	var slot = _slot_dari_aktor(aktor)
	var kode_gambar_permata = petak.nama_warna_permata
	var koleksi_aktif = koleksi_permata_slot[slot]
	
	if not koleksi_aktif.has(kode_gambar_permata):
		koleksi_aktif.append(kode_gambar_permata)
		_tambah_stat(slot, "permata")
		_siarkan_permata_diambil(rute_papan.find(petak), aktor, kode_gambar_permata, true, true)
		var siapa_yang_ambil = _subjek(slot)
		teks_dadu.text = siapa_yang_ambil + " recovered & collected " + kode_gambar_permata + " Gem!"
		update_ui_status()
		await get_tree().create_timer(1.5).timeout
	else:
		_siarkan_permata_diambil(rute_papan.find(petak), aktor, kode_gambar_permata, false, true)
		teks_dadu.text = "Recovered, but already have " + kode_gambar_permata + "!"
		await get_tree().create_timer(1.0).timeout

# ========================================================
# FUNGSI MUNCULKAN TEKS KERUGIAN DARI TUBUH KARAKTER
# ========================================================
func _siarkan_pesan_denda(slot_pembayar: int, jumlah: int, kalah_duel: bool, index_petak: int = -1) -> void:
	# Kirim DATA-nya saja (siapa membayar, berapa), bukan kalimat jadinya —
	# kalimat aslinya ditulis dari kacamata slot 0 ("ENEMY LOST"), jadi kalau
	# disalin mentah ke client artinya jadi terbalik.
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_pesan_denda", slot_pembayar, jumlah, kalah_duel, index_petak)

@rpc("authority", "call_remote", "reliable")
func rpc_pesan_denda(slot_pembayar: int, jumlah: int, kalah_duel: bool, index_petak: int = -1) -> void:
	# Angka denda merah yang melayang dari petak juga dimainkan di sini —
	# efek itu dijalankan label_petak_3d di host, yang tidak pernah tersentuh client.
	if index_petak >= 0 and index_petak < label_petak_3d.size():
		label_petak_3d[index_petak].mainkan_efek_denda(jumlah)
	teks_dadu.show()
	if slot_pembayar < 0 or slot_pembayar >= jumlah_pemain():
		return
	teks_dadu.text = _teks_denda(slot_pembayar, jumlah, kalah_duel)

func _siarkan_jebakan_tanah_aktif(index_petak: int, bonus_hp: int) -> void:
	# Jebakan tanah dipicu di host tepat sebelum duel. Tanpa ini, client tidak
	# melihat batu raksasa & "+1 Tile HP" sama sekali, dan label HP petaknya tidak
	# ikut bertambah.
	# C5 (B-c, 26-09): bonus_hp sekarang DIKIRIM (bukan diundi ulang di client)
	# -- host menghitungnya SEKALI lewat jebakan_tanah.gd::hitung_bonus_hp lalu
	# memakai angka yang sama untuk dirinya sendiri & RPC ini. Dipanggil host
	# SESUDAH undian Rock Breaker (dulu SEBELUM -> client selalu melihat "+1
	# HP" walau Rock Breaker meniadakannya di host, lihat pemain_duel.gd).
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_jebakan_tanah_aktif", index_petak, bonus_hp)

@rpc("authority", "call_remote", "reliable")
func rpc_jebakan_tanah_aktif(index_petak: int, bonus_hp: int) -> void:
	# Diterima di CLIENT. Mainkan efek yang sama memakai salinan jebakan milik
	# client sendiri (dibuat lewat siaran state saat jebakan dipasang). Buff di
	# sini hanya tampilan -- angka resminya tetap dari host -- dan ditarik lagi
	# otomatis saat duel yang diputar ulang di layar ini selesai.
	# C5 (B-c, 26-09): bonus_hp <= 0 (Rock Breaker meniadakan di host) -- jangan
	# sentuh jebakannya sama sekali, cuma tampilkan teks negasinya.
	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	teks_uang.hide()
	teks_bintang.hide()
	teks_dadu.show()
	if bonus_hp <= 0:
		teks_dadu.text = "ROCK BREAKER! Earth Trap bonus negated!"
		await get_tree().create_timer(1.5).timeout
		teks_dadu.hide()
		return
	teks_dadu.text = "EARTH TRAP ACTIVATED! Tile HP +%d" % bonus_hp
	var cek_tanah = rute_papan[index_petak].get_node_or_null("JebakanTanah")
	if cek_tanah and cek_tanah.aktif:
		await cek_tanah.aktifkan_pelindung_sementara(self, index_petak, ui_elemen, bonus_hp)
	else:
		# Salinan jebakannya belum ada di sini: tetap tampilkan teksnya selama
		# durasi efek yang sama seperti di host.
		await get_tree().create_timer(2.3).timeout
	teks_dadu.hide()

func _siarkan_kondisi_petak(index_petak: int, efek_rebut: bool, pemilik_lama: int = -1) -> void:
	# Petak berubah di tengah giliran karena hasil duel: direbut penyerang
	# (efek_rebut = true), atau HP-nya berkurang walau pembela menang. Tanpa
	# ini, client baru tahu saat giliran berganti -- telat beberapa detik dan
	# tanpa animasi rebut.
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_kondisi_petak", index_petak, status_kepemilikan_petak[index_petak], pemilik_petak[index_petak], nyawa_petak[index_petak], efek_rebut, pemilik_lama)

@rpc("authority", "call_remote", "reliable")
func rpc_kondisi_petak(index_petak: int, dimiliki: bool, pemilik: int, nyawa: int, efek_rebut: bool, pemilik_lama: int = -1) -> void:
	# Diterima di CLIENT. Kalau layar duel di sini masih berjalan, tunggu sampai
	# tertutup dulu -- di host, efek ini juga baru muncul setelah duel selesai.
	if _replay_duel_berjalan:
		await replay_duel_selesai
	if index_petak < 0 or index_petak >= label_petak_3d.size():
		return
	status_kepemilikan_petak[index_petak] = dimiliki
	pemilik_petak[index_petak] = pemilik
	nyawa_petak[index_petak] = nyawa
	update_semua_label_petak()
	if efek_rebut and pemilik >= 0 and pemilik < jumlah_pemain():
		teks_dadu.show()
		teks_dadu.text = _teks_rebut(pemilik, pemilik_lama)
		# Warna efek mengikuti SLOT (0 biru, 1 merah, 2 hijau, 3 kuning) -- sama di semua layar.
		label_petak_3d[index_petak].mainkan_efek_rebut(_aktor_dari_slot(pemilik))

func _siarkan_teks_kerugian(slot: int, jumlah: int) -> void:
	# Angka kerugian melayang hanya muncul di host, karena semua efek status
	# (terbakar, angin, dll) diproses di sana. Siarkan supaya client ikut melihat.
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_teks_kerugian", slot, jumlah)
	_munculkan_teks_kerugian(_model(slot), jumlah)

@rpc("authority", "call_remote", "reliable")
func rpc_teks_kerugian(slot: int, jumlah: int) -> void:
	if slot < 0 or slot >= jumlah_pemain():
		return
	_munculkan_teks_kerugian(_model(slot), jumlah)
