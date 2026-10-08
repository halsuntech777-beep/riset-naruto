@abstract
extends "res://pemain_papan.gd"
# ========================================================================
# PEMAIN_KARTU.GD
# KARTU: petak kartu, kartu simpan (Use Card), kartu pedang saat menyerang, kartu hadiah iklan
# pemain.gd dipecah BERTINGKAT (Fase 3): tiap file meneruskan (extends) file
# sebelumnya, jadi semuanya tetap SATU node Pemain -- variabel & fungsi dari file
# lain dipakai langsung seperti dulu. Urutan: pemain_dasar.gd -> pemain_tampilan.gd -> pemain_papan.gd -> pemain_kartu.gd -> pemain_duel.gd -> pemain_jaringan.gd -> pemain.gd
# @abstract = file ini bagian dari pemain.gd, tidak dipasang sendiri ke node.
# ========================================================================

# Kartu di multiplayer (petak kartu & kartu pedang saat duel).
var _sistem_kartu_aktif = null # PetakKartu yang UI-nya sedang tampil di device ini
var _slot_aktor_kartu: int = -1 # host: slot yang sedang memilih/membuang kartu
var _kartu_menunggu_jaringan: String = "" # host: "gacha"/"buang" = menunggu pilihan dari client
var _slot_penyerang_pedang: int = -1 # host: slot penyerang yang ditunggu memilih pedang
var _jawaban_pedang_client: int = -2 # -2 = belum dijawab, -1 = tidak memakai pedang
signal pedang_client_dijawab(indeks)
# UI tawaran pedang mode "tonton" yang sedang tampil di device CLIENT saat
# client menjadi pembela (lihat rpc_lawan_memilih_pedang) -- bukan yang diklik.
var _ui_pedang_tonton_aktif = null # PetakKartu (dipinjam UI-nya saja)

# ========================================================
# IKLAN BERHADIAH PILIHAN PEMAIN (Fase 1, solo saja)
# ========================================================
func _tonton_iklan_kartu_awal(panel: CanvasLayer) -> void:
	# Tombol "WATCH AD: FREE CARD" di panel HOW TO WIN.
	# Selama iklan berjalan panel turun ke bawah layer 100: plugin AdMob versi lama
	# menggambar iklan TIRUAN (saat dijalankan dari editor) di CanvasLayer 100, jadi
	# tertutup panel ini (106) dan pemain malah menekan START. Iklan asli di HP selalu
	# di atas aplikasi, jadi di HP tidak ada bedanya.
	var layer_panel = panel.layer
	panel.layer = 99
	var dapat = await PengelolaIklan.tonton_rewarded()
	# START bisa sudah ditekan sebelum iklan muncul -> panel sudah dibuang.
	var panel_ada = is_instance_valid(panel)
	if panel_ada:
		panel.layer = layer_panel
	var teks = "No ad right now. Try again later."
	var nama = ""
	if dapat:
		var kartu = _kartu_hadiah_acak()
		if not kartu.is_empty():
			daftar_pemain[slot_lokal].inventaris_kartu.append(kartu)
			nama = str(kartu["teks"]).split("\n")[0]
			# Pedang tidak bisa lewat Use Card (petak_kartu.gd: "Swords can only be used when attacking!").
			if str(kartu["id"]).begins_with("pedang"):
				teks = "You got %s! It helps when you attack." % nama
			else:
				teks = "You got %s! Tap Use Card in your turn." % nama
	if panel_ada:
		UiDinamis.tandai_menunggu_lawan(panel, teks) # mengisi label status panel
	elif nama != "":
		# Hadiah tetap diberikan walau permainan sudah dimulai.
		UiDinamis.tampilkan_spanduk(self, "FREE CARD: " + nama, Color(1.0, 0.85, 0.2))

func _kartu_hadiah_acak() -> Dictionary:
	# Data kartu diambil dari petak kartu di papan (satu sumber dengan petak_kartu.gd).
	# Pengacak SENDIRI: bukan mesin_acak (urutan acak permainan tidak bergeser), dan
	# bukan acak global -- lingkungan_pantai.gd mengunci benih global dengan angka
	# tetap, jadi di Night Beach "kartu acak" akan selalu sama.
	var pengacak = RandomNumberGenerator.new()
	pengacak.randomize()
	for petak in rute_papan:
		if petak.get("is_petak_kartu") and petak.get("node_sistem_kartu") != null:
			var pilihan = []
			for k in petak.node_sistem_kartu.database_efek:
				if KARTU_HADIAH_IKLAN.has(k["id"]):
					pilihan.append(k)
			if not pilihan.is_empty():
				return pilihan[pengacak.randi_range(0, pilihan.size() - 1)].duplicate(true)
	return {}

func _terapkan_efek_kartu(data: Dictionary, aktor: String):
	teks_dadu.text = "Card Effect Applied!"
	
	var slot = _slot_dari_aktor(aktor)
	if data["tipe"] == "koin": daftar_pemain[slot].uang += data["nilai"]
	elif data["tipe"] == "bintang": daftar_pemain[slot].bintang = clampi(daftar_pemain[slot].bintang + data["nilai"], 0, 10)
		
	# Paksa UI untuk render perubahan
	update_ui_status()

func _ambil_kartu_setelah_paralisis(aktor: String, petak: Node3D):
	var slot = _slot_dari_aktor(aktor)
	teks_dadu.text = _subjek(slot) + " recovered and draws a Card!"
	var index_petak = rute_papan.find(petak)
	var tiga_kartu = _mulai_petak_kartu_jaringan(petak.node_sistem_kartu, index_petak, aktor, true)

	# Mainkan efek animasi 3D & suara kartu
	await petak.node_sistem_kartu.mainkan_efek_kartu()

	# Buka UI Gacha Kartu
	var efek_kartu = await petak.node_sistem_kartu.mulai_gacha_kartu(_aktor_ui_kartu(slot), tiga_kartu, _mode_kartu(aktor), _nama_ui(slot))
	
	# --- PERBAIKAN: LOGIKA INTERSEPSI KARTU SIMPAN ---
	if efek_kartu.has("tipe_eksekusi") and efek_kartu["tipe_eksekusi"] == "simpan":
		var inv_aktif = daftar_pemain[slot].inventaris_kartu
		inv_aktif.append(efek_kartu)
		
		# Jika lebih dari 3, panggil UI Buang Kartu!
		if inv_aktif.size() > 3:
			await _buang_kartu_sinkron(petak.node_sistem_kartu, index_petak, aktor, inv_aktif)

		teks_dadu.text = "Card saved to Inventory!"
	else:
		# Terapkan efek ke status (Koin/Bintang Instan)
		_terapkan_efek_kartu(efek_kartu, aktor)

	await get_tree().create_timer(1.0).timeout

# ========================================================
# Bagian B2: PETAK KARTU DI MULTIPLAYER
# Yang melewati petak = yang memilih ("lokal"); pemain lain hanya menonton
# ("tonton"). Host yang mengacak 3 kartu dan satu-satunya yang menerapkan
# hasilnya (uang, bintang, inventaris). Semua layar memutar animasi yang sama,
# menampilkan 3 kartu tertutup yang sama, lalu membuka kartu yang sama.
# AI (di host) memilih sendiri ("ai") dan pilihannya diteruskan seperti klik.
# ========================================================

func _mode_kartu(aktor: String) -> String:
	# "" = solo (perilaku asli, termasuk AI), "lokal" = pemain di device ini yang
	# memilih, "ai" = AI yang dijalankan host memilih, "tonton" = hanya menonton.
	if StatusJaringan.peran_multiplayer == "":
		return ""
	var slot = _slot_dari_aktor(aktor)
	if slot == slot_lokal:
		return "lokal"
	if _is_ai(slot) and StatusJaringan.peran_multiplayer == "host":
		return "ai"
	return "tonton"

func _hubungkan_sinyal_kartu(sistem) -> void:
	if not sistem.kartu_gacha_diklik.is_connected(_saat_kartu_gacha_diklik):
		sistem.kartu_gacha_diklik.connect(_saat_kartu_gacha_diklik)
	if not sistem.kartu_buang_diklik.is_connected(_saat_kartu_buang_diklik):
		sistem.kartu_buang_diklik.connect(_saat_kartu_buang_diklik)

func _mulai_petak_kartu_jaringan(sistem, index_petak: int, aktor: String, dari_paralisis: bool = false) -> Array:
	# HOST: tentukan 3 kartunya di sini, lalu minta semua client ikut memutar
	# animasi dan menampilkan 3 kartu yang SAMA. Solo: kosong -- UI mengacak sendiri.
	if StatusJaringan.peran_multiplayer != "host":
		return []
	var tiga_kartu = sistem.ambil_tiga_kartu()
	_sistem_kartu_aktif = sistem
	_slot_aktor_kartu = _slot_dari_aktor(aktor)
	# Pemain jaringan (termasuk yang device-nya sedang ditunggu kembali, id -1):
	# host menunggu pilihannya -- lihat _bebaskan_penantian_slot.
	_kartu_menunggu_jaringan = "gacha" if _slot_aktor_kartu != slot_lokal and not _is_ai(_slot_aktor_kartu) else ""
	sistem.siapkan_sesi_gacha()
	_hubungkan_sinyal_kartu(sistem)
	rpc("rpc_kartu_mulai", index_petak, _slot_aktor_kartu, tiga_kartu, dari_paralisis)
	return tiga_kartu

func _buang_kartu_sinkron(sistem, index_petak: int, aktor: String, inv_aktif: Array) -> void:
	# Inventaris penuh: yang lewat petak memilih kartu yang dibuang, lainnya menonton.
	# Client tidak memegang data inventaris, jadi daftarnya dikirim host.
	var slot = _slot_dari_aktor(aktor)
	if StatusJaringan.peran_multiplayer == "host":
		_sistem_kartu_aktif = sistem
		_slot_aktor_kartu = slot
		_kartu_menunggu_jaringan = "buang" if slot != slot_lokal and not _is_ai(slot) else ""
		sistem.siapkan_sesi_buang()
		_hubungkan_sinyal_kartu(sistem)
		rpc("rpc_buang_kartu_mulai", index_petak, slot, inv_aktif)
	await sistem.munculkan_ui_buang_kartu(_aktor_ui_kartu(slot), inv_aktif, _mode_kartu(aktor), _nama_ui(slot))

func _saat_kartu_gacha_diklik(indeks: int) -> void:
	# Kartu dipilih di device ini (pemain lokal, atau AI di host) -> teruskan.
	if StatusJaringan.peran_multiplayer == "host":
		_rpc_ke_klien_kecuali([_peer_slot(_slot_aktor_kartu)], "rpc_kartu_dibuka_host", [indeks])
	elif StatusJaringan.peran_multiplayer == "client":
		rpc_id(1, "rpc_kartu_dipilih_client", indeks)

func _saat_kartu_buang_diklik(indeks: int) -> void:
	if StatusJaringan.peran_multiplayer == "host":
		_rpc_ke_klien_kecuali([_peer_slot(_slot_aktor_kartu)], "rpc_kartu_dibuang_host", [indeks])
	elif StatusJaringan.peran_multiplayer == "client":
		rpc_id(1, "rpc_kartu_dibuang_client", indeks)

@rpc("authority", "call_remote", "reliable")
func rpc_kartu_mulai(index_petak: int, slot_aktor: int, tiga_kartu: Array, dari_paralisis: bool) -> void:
	# Diterima di CLIENT: putar animasi petak kartu yang sama, lalu tampilkan 3
	# kartu tertutup yang sama. Hasilnya MURNI TAMPILAN -- host yang menerapkan.
	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	var sistem = rute_papan[index_petak].node_sistem_kartu
	if sistem == null:
		return
	_sistem_kartu_aktif = sistem
	sistem.siapkan_sesi_gacha()
	_hubungkan_sinyal_kartu(sistem)
	var aku_yang_memilih = (slot_aktor == slot_lokal)
	teks_dadu.show()
	teks_dadu.text = _subjek(slot_aktor) + (" recovered and draws a Card!" if dari_paralisis else " landed on a Card Tile!")
	await sistem.mainkan_efek_kartu()
	await sistem.mulai_gacha_kartu("pemain" if aku_yang_memilih else "musuh", tiga_kartu, "lokal" if aku_yang_memilih else "tonton", _nama_ui(slot_aktor))

@rpc("any_peer", "call_remote", "reliable")
func rpc_kartu_dipilih_client(indeks: int) -> void:
	# Diterima di HOST: client (yang lewat petak) memilih kartu ke-indeks.
	if not multiplayer.is_server():
		return
	var pengirim = multiplayer.get_remote_sender_id()
	if pengirim != _peer_slot(_slot_aktor_kartu):
		return
	_kartu_menunggu_jaringan = ""
	# Client lain (yang ikut menonton) juga harus melihat kartu yang sama terbuka.
	_rpc_ke_klien_kecuali([pengirim], "rpc_kartu_dibuka_host", [indeks])
	if _sistem_kartu_aktif:
		_sistem_kartu_aktif.buka_kartu_jaringan(indeks)

@rpc("authority", "call_remote", "reliable")
func rpc_kartu_dibuka_host(indeks: int) -> void:
	# Diterima di CLIENT: pemain yang lewat petak (host/AI/client lain) memilih kartu ke-indeks.
	if _sistem_kartu_aktif:
		_sistem_kartu_aktif.buka_kartu_jaringan(indeks)

@rpc("authority", "call_remote", "reliable")
func rpc_buang_kartu_mulai(index_petak: int, slot_aktor: int, daftar_kartu: Array) -> void:
	# Diterima di CLIENT: tampilkan UI buang kartu dengan isi inventaris dari host.
	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	var sistem = rute_papan[index_petak].node_sistem_kartu
	if sistem == null:
		return
	_sistem_kartu_aktif = sistem
	sistem.siapkan_sesi_buang()
	_hubungkan_sinyal_kartu(sistem)
	var aku_yang_memilih = (slot_aktor == slot_lokal)
	await sistem.munculkan_ui_buang_kartu("pemain" if aku_yang_memilih else "musuh", daftar_kartu, "lokal" if aku_yang_memilih else "tonton", _nama_ui(slot_aktor))

@rpc("any_peer", "call_remote", "reliable")
func rpc_kartu_dibuang_client(indeks: int) -> void:
	# Diterima di HOST: client memilih kartu yang dibuang.
	if not multiplayer.is_server():
		return
	var pengirim = multiplayer.get_remote_sender_id()
	if pengirim != _peer_slot(_slot_aktor_kartu):
		return
	_kartu_menunggu_jaringan = ""
	_rpc_ke_klien_kecuali([pengirim], "rpc_kartu_dibuang_host", [indeks])
	if _sistem_kartu_aktif:
		_sistem_kartu_aktif.buang_kartu_jaringan(indeks)

@rpc("authority", "call_remote", "reliable")
func rpc_kartu_dibuang_host(indeks: int) -> void:
	# Diterima di CLIENT: kartu yang dibuang sudah dipilih.
	if _sistem_kartu_aktif:
		_sistem_kartu_aktif.buang_kartu_jaringan(indeks)

# ========================================================
# Bagian B2: KARTU PEDANG SAAT MENYERANG
# Tawarannya WAJIB muncul (bisa diklik) di device penyerang sendiri. Pembela
# ikut melihat tawaran yang SAMA di layarnya -- tombol nonaktif, hanya
# menonton, sama seperti pola "tonton" di petak kartu. Begitu penyerang
# mengklik (kartu pedang atau NO, SAVE IT), pilihannya LANGSUNG dikirim ke
# device lawan, lalu kedua layar mengumumkannya bersamaan selama 1.5 dtk
# (petak_kartu._umumkan_pilihan_pedang) sebelum duel dimulai.
# ========================================================

func _pilih_pedang_ai_terlihat(slot_ai: int) -> int:
	# AI (HOST): tawaran kartu pedang yang SAMA persis dengan milik penyerang
	# manusia, terlihat di host DAN semua client mode "tonton" -- termasuk
	# kesempatan AI menekan NO, SAVE IT (lihat AiMusuh.pilih_pedang_ai). Polanya
	# sama persis dengan jalur penyerang client di _pilih_pedang_penyerang di
	# bawah. Berlaku juga di solo (rpc-rpc di bawah otomatis dilewati).
	var daftar_pedang = []
	for k in daftar_pemain[slot_ai].inventaris_kartu:
		if k["id"].begins_with("pedang"): daftar_pedang.append(k)
	if daftar_pedang.is_empty():
		return 0

	var kartu = AiMusuh.pilih_pedang_ai(self, slot_ai)
	var indeks = daftar_pedang.find(kartu) if kartu != null else -1

	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_lawan_memilih_pedang", daftar_pedang, slot_ai)
	var UI = preload("res://petak_kartu.gd").new()
	UI.is_petak_kartu = false
	add_child(UI)
	# TANPA await -- UI-nya baru ditutup lewat pedang_jaringan() di bawah, sama
	# seperti jalur client-penonton di _pilih_pedang_penyerang.
	UI.munculkan_ui_pedang_penyerang(daftar_pedang, "tonton", _nama_ui(slot_ai))
	await get_tree().create_timer(1.0).timeout # AI "berpikir" ±1 detik
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_pedang_dipilih_host", indeks)
	UI.pedang_jaringan(indeks)
	await UI.pedang_terpilih
	UI.queue_free()

	if kartu == null:
		return 0
	var idx_asli = daftar_pemain[slot_ai].inventaris_kartu.find(kartu)
	if idx_asli != -1: daftar_pemain[slot_ai].inventaris_kartu.remove_at(idx_asli)
	return int(kartu["id"].right(1))

func _pilih_pedang_penyerang(slot_penyerang: int):
	# Mengembalikan data kartu pedang yang dipilih penyerang, atau null.
	var inventaris = daftar_pemain[slot_penyerang].inventaris_kartu
	var daftar_pedang = []
	for k in inventaris:
		if k["id"].begins_with("pedang"): daftar_pedang.append(k)
	if StatusJaringan.peran_multiplayer != "" and slot_penyerang != slot_lokal:
		# Penyerangnya client. Client tidak memegang data inventaris, jadi daftar
		# pedangnya dikirim dari sini, lalu tunggu jawabannya.
		_jawaban_pedang_client = -2
		_slot_penyerang_pedang = slot_penyerang
		var id_penyerang = _peer_slot(slot_penyerang)

		# Device INI (dan client lain) ikut menampilkan tawaran yang SAMA secara
		# visual -- tombol nonaktif, hanya menonton -- bukan cuma teks placeholder,
		# meniru pola "tonton" yang sudah dipakai di petak kartu.
		var UI_Pedang_Tonton = preload("res://petak_kartu.gd").new()
		UI_Pedang_Tonton.is_petak_kartu = false
		add_child(UI_Pedang_Tonton)
		UI_Pedang_Tonton.munculkan_ui_pedang_penyerang(daftar_pedang, "tonton", _nama_ui(slot_penyerang))

		if id_penyerang > 1: # -1 = device-nya sedang ditunggu kembali (dijawab otomatis)
			rpc_id(id_penyerang, "rpc_minta_pilih_pedang", daftar_pedang)
		_rpc_ke_klien_kecuali([id_penyerang], "rpc_lawan_memilih_pedang", [daftar_pedang, slot_penyerang])
		var indeks = _jawaban_pedang_client
		if indeks == -2:
			indeks = await pedang_client_dijawab
		_slot_penyerang_pedang = -1

		# Umumkan pilihan asli penyerang di layar ini (1.5 dtk -- client
		# mengirim jawabannya SAAT mengklik, jadi pengumuman di semua layar
		# berjalan bersamaan), baru lanjut ke duel setelah pengumumannya selesai.
		UI_Pedang_Tonton.pedang_jaringan(indeks)
		await UI_Pedang_Tonton.pedang_terpilih
		UI_Pedang_Tonton.queue_free()

		if indeks < 0 or indeks >= daftar_pedang.size():
			return null
		return daftar_pedang[indeks]

	# Penyerangnya pemain di device ini (solo, atau host yang menyerang).
	if StatusJaringan.peran_multiplayer == "host":
		# Kirim daftar pedang yang SAMA ke semua client supaya pemain lain juga
		# melihat tawarannya secara visual (mode "tonton"), bukan cuma teks placeholder.
		rpc("rpc_lawan_memilih_pedang", daftar_pedang, slot_penyerang)
	var UI_Pedang = preload("res://petak_kartu.gd").new()
	UI_Pedang.is_petak_kartu = false
	add_child(UI_Pedang)
	if StatusJaringan.peran_multiplayer == "host":
		# Kabari client SAAT host mengklik -- bukan setelah pengumuman 1.5 dtk
		# di layar ini selesai -- supaya pengumuman di semua layar bersamaan.
		UI_Pedang.pedang_diklik.connect(func(i): rpc("rpc_pedang_dipilih_host", i))
	var pedang_dipilih = await UI_Pedang.munculkan_ui_pedang_penyerang(inventaris)
	UI_Pedang.queue_free()
	return pedang_dipilih

@rpc("authority", "call_remote", "reliable")
func rpc_minta_pilih_pedang(daftar_pedang: Array) -> void:
	# Diterima di CLIENT (penyerang): tampilkan tawaran pedang di layar ini.
	# HUD disembunyikan seperti di host (di sana terjadi di awal fase duel).
	teks_uang.hide()
	teks_bintang.hide()
	teks_dadu.hide()
	var UI_Pedang = preload("res://petak_kartu.gd").new()
	UI_Pedang.is_petak_kartu = false
	add_child(UI_Pedang)
	# Jawaban dikirim SAAT diklik (indeks pedang, atau -1 = NO, SAVE IT), jadi
	# host langsung memutar pengumuman yang sama, bersamaan dengan layar ini.
	UI_Pedang.pedang_diklik.connect(func(i):
		if StatusJaringan.peran_multiplayer == "client":
			rpc_id(1, "rpc_jawab_pilih_pedang", i))
	await UI_Pedang.munculkan_ui_pedang_penyerang(daftar_pedang)
	UI_Pedang.queue_free()

@rpc("any_peer", "call_remote", "reliable")
func rpc_jawab_pilih_pedang(indeks: int) -> void:
	# Diterima di HOST: jawaban client (indeks pedang, atau -1 = disimpan).
	if not multiplayer.is_server():
		return
	var pengirim = multiplayer.get_remote_sender_id()
	if _slot_penyerang_pedang < 0 or pengirim != _peer_slot(_slot_penyerang_pedang):
		return
	if _jawaban_pedang_client != -2:
		return # sudah dijawab
	# Client lain yang ikut menonton langsung memutar pengumuman yang sama.
	_rpc_ke_klien_kecuali([pengirim], "rpc_pedang_dipilih_host", [indeks])
	_jawaban_pedang_client = indeks
	pedang_client_dijawab.emit(indeks)

@rpc("authority", "call_remote", "reliable")
func rpc_lawan_memilih_pedang(daftar_pedang: Array, slot_penyerang: int = 0) -> void:
	# Diterima di CLIENT yang bukan penyerang: penyerang sedang memilih kartu
	# pedang -- tampilkan tawaran yang sama di layar ini, mode "tonton"
	# (tombol nonaktif). Pilihannya datang lewat rpc_pedang_dipilih_host;
	# layar ini baru ditutup setelah pengumuman 1.5 dtk-nya selesai.
	teks_uang.hide()
	teks_bintang.hide()
	teks_dadu.hide()
	var UI_Pedang_Tonton = preload("res://petak_kartu.gd").new()
	UI_Pedang_Tonton.is_petak_kartu = false
	add_child(UI_Pedang_Tonton)
	_ui_pedang_tonton_aktif = UI_Pedang_Tonton
	await UI_Pedang_Tonton.munculkan_ui_pedang_penyerang(daftar_pedang, "tonton", _nama_ui(slot_penyerang))
	if _ui_pedang_tonton_aktif == UI_Pedang_Tonton:
		_ui_pedang_tonton_aktif = null
	UI_Pedang_Tonton.queue_free()

@rpc("authority", "call_remote", "reliable")
func rpc_pedang_dipilih_host(indeks: int) -> void:
	# Diterima di CLIENT penonton: penyerang baru saja mengklik (indeks pedang,
	# atau -1 = NO, SAVE IT). Putar pengumuman yang sama di UI tonton,
	# bersamaan dengan pengumuman di layar penyerang.
	if is_instance_valid(_ui_pedang_tonton_aktif):
		_ui_pedang_tonton_aktif.pedang_jaringan(indeks)

# ========================================================
# SISTEM PENGGUNAAN KARTU NORMAL (SIMPAN)
# ========================================================
func _on_tombol_gunakan_kartu_pressed():
	if daftar_pemain[slot_giliran_ui].inventaris_kartu.size() == 0: return

	# Hapus penyaringan pedang di sini. Biarkan seluruh kartu dikirim ke UI.
	# Logika pembatasan penggunaan pedang akan diurus di dalam UI itu sendiri.
	menu_aksi.hide()

	var UI_Kartu = preload("res://petak_kartu.gd").new()
	UI_Kartu.is_petak_kartu = false
	add_child(UI_Kartu)

	# Kirim inventaris utuh tanpa disaring
	var kartu_terpilih = await UI_Kartu.munculkan_ui_gunakan_kartu(daftar_pemain[slot_giliran_ui].inventaris_kartu)
	UI_Kartu.queue_free()

	if kartu_terpilih != null:
		if kartu_terpilih["id"] == "dadu_rendah" or kartu_terpilih["id"] == "dadu_tinggi":
			await UiDinamis.munculkan_ui_pilih_target(self, kartu_terpilih)
		elif StatusJaringan.peran_multiplayer == "client":
			_minta_pakai_kartu(kartu_terpilih, "")
		else:
			var indeks_kartu = daftar_pemain[slot_giliran_ui].inventaris_kartu.find(kartu_terpilih)
			if indeks_kartu != -1:
				daftar_pemain[slot_giliran_ui].inventaris_kartu.remove_at(indeks_kartu)

			teks_dadu.text = "You used: " + kartu_terpilih["id"]
			await _eksekusi_kartu_simpan(kartu_terpilih, aktor_giliran_ui, "", indeks_kartu)

			fase_giliran = "awal"
			teks_dadu.text = "YOUR TURN! Choose Action or Roll Dice."
			periksa_status_petak(slot_giliran_ui)
	else:
		periksa_status_petak(slot_giliran_ui)

func _nama_layar(slot: int) -> String:
	# Nama pemakai kartu untuk animasi _putar_animasi_pakai_kartu (beda dari
	# _nama_slot: "YOU" untuk device sendiri, bukan cuma nama slot).
	if slot == slot_lokal:
		return "YOU"
	if jumlah_pemain() <= 2:
		return "ENEMY"
	return "P%d" % (slot + 1)

func _putar_animasi_pakai_kartu(daftar_id: Array, indeks: int, slot: int, slot_target: int) -> void:
	# Animasi pemakaian kartu simpanan yang sama persis diputar di HOST dan semua
	# CLIENT (lihat rpc_animasi_pakai_kartu & _eksekusi_kartu_simpan):
	# semua kartu simpanan pemakai tampil (pedang redup) -> kartu terpilih emas,
	# sisanya menghilang -> 2 dtk -> keterangan target -> 1 dtk -> kamera menyorot
	# target -> kartu mengecil masuk ke tubuh target -> 1 dtk -> normal lagi.
	var id_kartu = str(daftar_id[indeks]) if indeks >= 0 and indeks < daftar_id.size() else ""
	var nama = _nama_layar(slot)
	var judul_awal = "YOUR CARDS" if slot == slot_lokal else nama + "'S CARDS"
	var judul_pakai = "YOU USED A CARD!" if slot == slot_lokal else nama + " USED A CARD!"
	var teks_target = ""
	if id_kartu == "dadu_rendah" or id_kartu == "dadu_tinggi":
		var jenis = "LOW ROLL" if id_kartu == "dadu_rendah" else "HIGH ROLL"
		var nama_t = "YOU" if slot_target == slot_lokal else _nama_layar(slot_target)
		if slot_target == slot and slot_target != slot_lokal:
			nama_t = _nama_layar(slot_target) + " (SELF)"
		teks_target = jenis + " for " + nama_t + " (3 turns)"
	elif id_kartu == "pelindung":
		teks_target = "+500 COINS for " + _nama_layar(slot)

	var UI = preload("res://petak_kartu.gd").new()
	UI.is_petak_kartu = false
	add_child(UI)
	await UI.tampilkan_kartu_pakai(daftar_id, indeks, judul_awal, judul_pakai, teks_target, WARNA_SLOT[slot], WARNA_SLOT[slot_target])

	# Sorot target dengan kamera (geseran kamera pemain dinolkan dulu supaya
	# targetnya pas di tengah), sambil latar gelapnya memudar.
	var kamera_lama = target_kamera
	var geser_lama = geser_kamera
	var model_target = _model(slot_target)
	target_kamera = model_target
	geser_kamera = Vector3.ZERO
	await UI.lepas_latar_kartu_pakai()
	await get_tree().create_timer(0.8).timeout # kamera (lerp) sampai di target
	if is_instance_valid(model_target) and is_instance_valid(kamera):
		var titik = model_target.global_position + Vector3(0, 1.0, 0)
		await UI.masukkan_kartu_pakai(kamera.unproject_position(titik))
	await get_tree().create_timer(1.0).timeout
	UI.tutup_kartu_pakai()
	UI.queue_free()
	# Kembali normal: kamera ke yang disorot sebelumnya (kalau belum dipindah
	# bagian lain selama animasi).
	if target_kamera == model_target:
		target_kamera = kamera_lama
		geser_kamera = geser_lama

@rpc("authority", "call_remote", "reliable")
func rpc_animasi_pakai_kartu(daftar_id: Array, indeks: int, slot: int, slot_target: int) -> void:
	# Diterima di CLIENT: tampilan animasinya saja -- efek sebenarnya (uang,
	# durasi dadu) datang lewat siaran state seperti biasa.
	if slot < 0 or slot >= jumlah_pemain() or slot_target < 0 or slot_target >= jumlah_pemain():
		return
	_animasi_kartu_klien += 1
	await _putar_animasi_pakai_kartu(daftar_id, indeks, slot, slot_target)
	_animasi_kartu_klien -= 1
	if _animasi_kartu_klien <= 0:
		_animasi_kartu_klien = 0
		animasi_kartu_klien_selesai.emit()

func _eksekusi_kartu_simpan(data_kartu: Dictionary, aktor: String, target_khusus: String = "", indeks_asal: int = -1):
	# indeks_asal = posisi kartu ini di inventaris SEBELUM dihapus pemanggil
	# (-1 = tidak diketahui, kartunya ditaruh paling belakang) -- dipakai supaya
	# animasi menampilkan urutan kartu simpanan yang sama seperti di inventaris.
	var id = data_kartu["id"]
	var slot = _slot_dari_aktor(aktor)
	_tambah_stat(slot, "kartu_pakai")
	var slot_target = _slot_dari_aktor(target_khusus) if target_khusus != "" else slot
	var ada_target = 1 if target_khusus != "" else 0

	var daftar_id = []
	for k in daftar_pemain[slot].inventaris_kartu:
		daftar_id.append(str(k.get("id", "")))
	var indeks_anim = indeks_asal if indeks_asal >= 0 and indeks_asal <= daftar_id.size() else daftar_id.size()
	daftar_id.insert(indeks_anim, id)

	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_animasi_pakai_kartu", daftar_id, indeks_anim, slot, slot_target)
	await _putar_animasi_pakai_kartu(daftar_id, indeks_anim, slot, slot_target)

	if id == "dadu_rendah":
		tipe_dadu_slot[slot_target] = "rendah"
		sisa_durasi_dadu_slot[slot_target] = 3
		_umumkan("kartu_rendah", slot, ada_target, slot_target)
		await get_tree().create_timer(1.0).timeout

	elif id == "dadu_tinggi":
		tipe_dadu_slot[slot_target] = "tinggi"
		sisa_durasi_dadu_slot[slot_target] = 3
		_umumkan("kartu_tinggi", slot, ada_target, slot_target)
		await get_tree().create_timer(1.0).timeout

	elif id == "pelindung":
		daftar_pemain[slot].uang += 500
		_umumkan("kartu_perisai", slot)
		update_ui_status()
		await get_tree().create_timer(1.0).timeout

# --- Kartu simpanan milik pemain CLIENT: client memilih, host menjalankan ---
func _minta_pakai_kartu(kartu: Dictionary, target_aktor: String) -> void:
	# CLIENT: kirim pilihan kartu (+ targetnya) ke host. Efeknya dijalankan host,
	# lalu state baru (uang, efek dadu, sisa kartu) dan menu dikirim balik.
	var indeks = daftar_pemain[slot_lokal].inventaris_kartu.find(kartu)
	menu_aksi.hide()
	rpc_id(1, "rpc_minta_pakai_kartu", indeks, str(kartu.get("id", "")), target_aktor)

@rpc("any_peer", "call_remote", "reliable")
func rpc_minta_pakai_kartu(indeks: int, id_kartu: String, target_aktor: String) -> void:
	# Diterima di HOST.
	if not multiplayer.is_server() or _migrasi_berjalan or _mode_jaringan_putus:
		return
	var slot = slot_giliran_ui
	if _peer_slot(slot) != multiplayer.get_remote_sender_id():
		return # bukan giliran pengirim ini
	var inv = daftar_pemain[slot].inventaris_kartu
	if fase_giliran != "awal" or indeks < 0 or indeks >= inv.size() or str(inv[indeks].get("id", "")) != id_kartu \
			or daftar_pemain[slot].kunci_kartu > 0: # B-b (B4/K7): frozen_bubble
		periksa_status_petak(slot) # tolak: kirim ulang keadaan yang benar, menu client kembali
		return
	if target_aktor != "" and _slot_dari_aktor(target_aktor) >= jumlah_pemain():
		target_aktor = ""
	_menunggu_aksi_slot = -1
	var kartu = inv[indeks]
	inv.remove_at(indeks)
	await _eksekusi_kartu_simpan(kartu, _aktor_dari_slot(slot), target_aktor, indeks)
	fase_giliran = "awal"
	if _is_ai(slot):
		# Device itu putus saat efek kartunya diputar: AI meneruskan gilirannya.
		_jalankan_ai_di_tengah_giliran(slot)
	else:
		periksa_status_petak(slot)
