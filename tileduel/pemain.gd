extends "res://pemain_jaringan.gd"
# ========================================================================
# PEMAIN.GD
# ALUR PERMAINAN: _ready/_process/input, mulai peta, giliran (dadu, melangkah, menu aksi), akhir permainan, Quick Match, hadiah profil
# pemain.gd dipecah BERTINGKAT (Fase 3): tiap file meneruskan (extends) file
# sebelumnya, jadi semuanya tetap SATU node Pemain -- variabel & fungsi dari file
# lain dipakai langsung seperti dulu. Urutan: pemain_dasar.gd -> pemain_tampilan.gd -> pemain_papan.gd -> pemain_kartu.gd -> pemain_duel.gd -> pemain_jaringan.gd -> pemain.gd
# ========================================================================

# --- PANEL SYARAT MENANG & AKHIR PERMAINAN ---
signal siap_mulai_diklik

var _giliran_berjalan: bool = false  # sejak START ditekan semua (kecepatan 1,5x)

# --- SISTEM CABANG & VALIDASI ---
signal arah_cabang_terpilih(node_tujuan)
# Multiplayer (lihat _pilih_arah_cabang): klik arah di device ini, jawaban
# client yang ditunggu host, dan panel "tonton" di client.
signal cabang_lokal_diklik(indeks)

func _ready():
	# Kecepatan Quick Match dari pertandingan sebelumnya dikembalikan (Engine global,
	# tidak ikut ter-reset saat adegan dimuat ulang).
	if StatusJaringan.skala_waktu_dasar >= 0.0:
		Engine.time_scale = StatusJaringan.skala_waktu_dasar
		StatusJaringan.skala_waktu_dasar = -1.0
	add_to_group("grup_pemain") # Wajib agar menu grafis bisa menemukan skrip ini
	mesin_acak.randomize()

	# Bagian B1: kalau ada koneksi jaringan aktif (datang dari LocalPlay.tscn), isi slot
	# sesuai role host/client. Kalau tidak ada koneksi sama sekali, perilaku solo vs AI
	# di bawah ini SAMA PERSIS seperti sebelumnya — tidak berubah.
	if StatusJaringan.peran_multiplayer == "":
		daftar_pemain = [
			DataPemain.new(DataPemain.JenisKontrol.MANUSIA_LOKAL, "Pemain"),
			DataPemain.new(DataPemain.JenisKontrol.AI, "Musuh"),
		]
	else:
		# Susunan slot (2-4 pemain, manusia/AI) ditentukan host di lobby.
		_susun_slot_jaringan()

	for p in daftar_pemain:
		p.bintang = 4 # nilai awal bintang sesuai game aslinya

	if StatusJaringan.peran_multiplayer != "":
		_siapkan_indikator_jaringan()
		# Lempar koin penentu seri: tiap kali pemain di device ini memilih sisi
		# koin, pilihannya diteruskan ke device lawan.
		ui_elemen.koin_lokal_dikunci.connect(_saat_koin_seri_lokal_dipilih)
	ui_elemen.paksa_seri = UJI_SERI

	anim_pemain.play("idle")
	anim_musuh.play("idle")
	target_kamera = model_pemain 
	
	# MEWARNAI KARAKTER SAAT GAME DIMULAI
	_warnai_karakter(model_pemain, Color(0.2, 0.5, 1.0)) # Pemain jadi Biru
	_warnai_karakter(model_musuh, Color(1.0, 0.2, 0.2))  # Musuh jadi Merah
	# Karakter slot 3-4 (hijau, kuning) dibuat di sini kalau jumlah pemainnya
	# sudah diketahui (multiplayer). Solo: menyusul setelah jumlah lawan dipilih.
	_siapkan_slot_pemain(true)

	# --------------------------------------------------------
	# CATATAN:
	# Blok pengecekan error array kosong, kalkulasi batas kamera, 
	# dan loop UIPetak SUDAH DIHAPUS dari sini, karena semuanya
	# sekarang dikerjakan oleh fungsi _siapkan_peta_dan_mulai().
	# --------------------------------------------------------
	
	# Cetak tombol jebakan baru sebelum UI Elegan memproses gaya visualnya
	UiDinamis.buat_tombol_jebakan_via_kode(self)
	
	UiDinamis.setup_ui_elegan(self)
	UiDinamis.buat_ui_cabang_dasar(self) # <--- TAMBAHKAN BARIS INI
	update_ui_status()
	
	# Setup Audio & Grafis
	AudioGrafis.setup_sistem_audio(self)
	AudioGrafis.muat_seting_grafis(self)

	# Peluncuran pertama: belum ada setelan tersimpan sama sekali. Ukur diam-diam
	# lalu terapkan seketika — tanpa dialog, tanpa mengusir pemain. Bagian yang
	# tidak bisa berubah di tengah jalan (rumput, efek jebakan) berlaku penuh saat
	# game dibuka berikutnya.
	if not AudioGrafis.ada_setelan_tersimpan():
		_jalankan_auto_detect_pertama()

	_pemanasan_shader.call_deferred()

	# SETUP SISTEM MAIN MENU TERINTEGRASI
	# 1. Simpan rotasi isometrik kamera asli dari editor
	rotasi_kamera_awal = kamera.rotation_degrees
	
	# 2. Pusat papan sementara untuk kamera Menu Utama berputar
	pusat_papan = Vector3.ZERO
	
	# 3. Sembunyikan UI Gameplay (Pastikan benar-benar tersembunyi di awal)
	teks_dadu.hide()
	teks_uang.hide()
	teks_bintang.hide()
	menu_aksi.hide()

	if StatusJaringan.peran_multiplayer != "":
		# Bagian B2: multiplayer lewati menu utama sama sekali — semua device
		# langsung masuk permainan, di peta yang dipilih host di lobby.
		# call_deferred WAJIB di sini — kalau dipanggil langsung, Godot menolak
		# add_child() di dalam _siapkan_peta_dan_mulai() karena scene tree masih
		# dalam proses setup (_ready() milik node ini belum selesai sepenuhnya).
		# Ini beda dari mode solo, di mana fungsi ini baru terpanggil belakangan
		# lewat klik menu — sudah pasti lewat dari fase riskan itu.
		var peta_mp = StatusJaringan.peta_multiplayer if StatusJaringan.peta_multiplayer != "" else "alam"
		_siapkan_peta_dan_mulai.call_deferred(peta_mp, daftar_pemain.size() - 1, StatusJaringan.mode_quick)
	else:
		# --- TAMBAHKAN 3 BARIS INI ---
		var peta_bg = load("res://PetaAlam.tscn").instantiate()
		peta_bg.name = "PetaAlam"
		get_parent().call_deferred("add_child", peta_bg)
		# -----------------------------

		# 4. Muat file Main Menu yang baru dibuat
		var script_menu = preload("res://main_menu.gd")
		var menu_ui = script_menu.new()
		add_child(menu_ui)

		# 5. Pasang kabel sinyal untuk menyiapkan peta dan menjatuhkan kamera
		menu_ui.mulai_game.connect(_siapkan_peta_dan_mulai)

func _process(delta):
	_atur_kecepatan_permainan()
	_atur_posisi_label_ronde()
	# UPDATE ANGKA FPS SECARA REALTIME SETIAP FRAME
	if label_fps and label_fps.visible:
		label_fps.text = "FPS: " + str(Engine.get_frames_per_second())
	# ========================================================
	# LOGIKA KAMERA DRONE: BERPUTAR DI LANGIT SAAT MAIN MENU
	# ========================================================
	if di_main_menu:
		sudut_drone += delta * 0.15
		var radius_drone = 35.0
		var tinggi_drone = 25.0
		var pos_udara = pusat_papan + Vector3(cos(sudut_drone) * radius_drone, tinggi_drone, sin(sudut_drone) * radius_drone)
		
		# Terbang perlahan
		kamera.global_position = kamera.global_position.lerp(pos_udara, delta * 2.0)
		
		# Terus menatap ke tengah papan
		var target_transform = kamera.global_transform.looking_at(pusat_papan, Vector3.UP)
		kamera.global_transform = kamera.global_transform.interpolate_with(target_transform, delta * 2.0)
		return # Hentikan proses geser kamera normal di sini

	# ========================================================
	# LOGIKA KAMERA NORMAL (GAMEPLAY)
	# ========================================================
	var bisa_geser = _boleh_geser_kamera()

	if bisa_geser:
		var arah_geser = Vector3.ZERO
		if Input.is_action_pressed("ui_right"): arah_geser.x += 1
		if Input.is_action_pressed("ui_left"): arah_geser.x -= 1
		if Input.is_action_pressed("ui_down"): arah_geser.z += 1
		if Input.is_action_pressed("ui_up"): arah_geser.z -= 1
		geser_kamera += arah_geser.normalized() * 15.0 * delta

	if target_kamera != null:
		var fokus_x = target_kamera.global_position.x + geser_kamera.x
		var fokus_z = target_kamera.global_position.z + geser_kamera.z

		if fokus_x < batas_kamera_min.x:
			geser_kamera.x = batas_kamera_min.x - target_kamera.global_position.x
		elif fokus_x > batas_kamera_max.x:
			geser_kamera.x = batas_kamera_max.x - target_kamera.global_position.x

		if fokus_z < batas_kamera_min.y:
			geser_kamera.z = batas_kamera_min.y - target_kamera.global_position.z
		elif fokus_z > batas_kamera_max.y:
			geser_kamera.z = batas_kamera_max.y - target_kamera.global_position.z
		
		var posisi_ideal = target_kamera.global_position + (kamera.global_transform.basis.z * 30.0) + geser_kamera
		kamera.global_position = kamera.global_position.lerp(posisi_ideal, delta * 4.0)
		
func _mulai_transisi_game():
	di_main_menu = false 
	
	var tw_kamera = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tw_kamera.tween_property(kamera, "rotation_degrees", rotasi_kamera_awal, 1.5)
	
	await tw_kamera.finished
	
	# Saat kamera sudah mendarat di punggung karakter, munculkan UI Gameplay!
	teks_uang.show()
	teks_bintang.show()
	teks_dadu.show()
	if label_ronde:
		label_ronde.show()
		_atur_posisi_label_ronde()

	# ---> TAMBAHKAN BARIS INI <---
	tombol_seting.show() 
	
	# Panel penjelasan syarat kemenangan. Di multiplayer kedua device harus
	# menekan START dulu -- kalau tidak, host sudah melempar dadu sementara layar
	# client masih tertutup panel.
	var generasi = _generasi_jaringan
	await _tunggu_kesiapan_mulai()
	# Quick Match mulai 1,5x di sini -- SEBELUM pemeriksaan generasi, supaya device
	# yang meneruskan permainan setelah host keluar di panel ini tetap 1,5x.
	_giliran_berjalan = true
	if generasi != _generasi_jaringan:
		# Host keluar selama panel masih tampil: device ini sudah meneruskan
		# permainan (lanjut sendiri / migrasi host) -- jangan mulai giliran pertama lagi.
		PengelolaIklan.tampilkan_banner()
		return

	fase_giliran = "awal"
	teks_dadu.text = "YOUR TURN! Choose Action or Roll Dice."
	periksa_status_petak()
	
	PengelolaIklan.tampilkan_banner()

func _baris_syarat_menang() -> Array:
	# Syarat dibaca dari aturan yang sungguhan dipakai di bergerak_maju(), jadi
	# kalau angkanya diubah, panel ini ikut berubah sendiri.
	var baris = []
	if mode_quick:
		baris.append("QUICK MATCH: %d rounds, then the richest player wins" % batas_ronde)
		baris.append("Richest = coins + tiles + towers")
		if target_permata_menang > 0:
			baris.append(_teks_syarat_permata())
			baris.append("Win early: reach START with %d+ coins and %s" % [SYARAT_KOIN_MENANG, "the gem" if target_permata_menang == 1 else "the gems"])
		else:
			baris.append("Win early: reach START with %d+ coins" % SYARAT_KOIN_MENANG)
		baris.append("Salary at START: +500, +10 per tile you own, +3 stars")
		baris.append("Buy a tile, then STOP on it again to build a tower")
		return baris
	if target_permata_menang > 0:
		baris.append(_teks_syarat_permata())
		baris.append("Pass START with the gems complete to get your salary")
	baris.append("Reach START with %d+ coins to win" % SYARAT_KOIN_MENANG)
	baris.append("Salary at START: +500, +10 per tile you own, +3 stars")
	baris.append("Buy a tile, then STOP on it again to build a tower")
	return baris

func _teks_syarat_permata() -> String:
	if target_permata_menang == 1 and jumlah_permata_peta <= 1:
		return "Collect the gem on the board"
	if target_permata_menang < jumlah_permata_peta:
		return "Collect %d of the %d gems on the board" % [target_permata_menang, jumlah_permata_peta]
	return "Collect all %d gems on the board" % target_permata_menang

func _tunggu_kesiapan_mulai() -> void:
	# Penanda TIDAK di-reset di sini: kalau device lawan menekan START lebih dulu
	# (papannya selesai dibangun lebih cepat), kabarnya sudah masuk sebelum baris
	# ini dijalankan -- me-reset di sini akan membuat kabar itu hilang.
	# Solo: tawaran iklan berhadiah "FREE CARD" (hanya kalau iklannya sudah siap).
	var tawarkan = StatusJaringan.peran_multiplayer == "" and PengelolaIklan.rewarded_tersedia()
	var panel = UiDinamis.tampilkan_panel_syarat_menang(self, _baris_syarat_menang(), tawarkan)
	await siap_mulai_diklik

	if StatusJaringan.peran_multiplayer == "client":
		rpc_id(1, "rpc_client_siap_mulai")
		UiDinamis.tandai_menunggu_lawan(panel, "WAITING FOR HOST...")
		await _tunggu_penanda("_host_mulai_permainan", 60.0)
	elif StatusJaringan.peran_multiplayer == "host":
		UiDinamis.tandai_menunggu_lawan(panel, "WAITING FOR OPPONENT..." if _peer_client_aktif().size() <= 1 else "WAITING FOR PLAYERS...")
		await _tunggu_penanda("_client_siap_mulai", 30.0)
		rpc("rpc_mulai_permainan")

	if is_instance_valid(panel):
		panel.queue_free()

func _tunggu_penanda(nama_penanda: String, batas_detik: float) -> void:
	# Menunggu sebuah penanda bool jadi true, tapi TIDAK selamanya: kalau device
	# lawan tidak pernah menjawab (mis. aplikasinya ditutup), permainan tetap jalan.
	var berlalu = 0.0
	while not get(nama_penanda) and berlalu < batas_detik:
		await get_tree().process_frame
		berlalu += get_process_delta_time()

@rpc("any_peer", "call_remote", "reliable")
func rpc_client_siap_mulai() -> void:
	# Diterima di HOST: pemain client sudah menekan START.
	if not multiplayer.is_server():
		return
	_klien_siap[multiplayer.get_remote_sender_id()] = true
	_periksa_kesiapan_klien()

@rpc("authority", "call_remote", "reliable")
func rpc_mulai_permainan() -> void:
	# Diterima di CLIENT: kedua device siap, panel boleh ditutup.
	_host_mulai_permainan = true
	
# ========================================================
# PERBAIKAN: Menggunakan _unhandled_input agar klik pada 
# tombol UI tidak tembus memicu penembakan raycast 3D.
# ========================================================
func _unhandled_input(event):
	# ========================================================
	# PROTEKSI MUTLAK MENCEGAH SOFTLOCK UI CABANG & TARGET KARTU
	# ========================================================
	var panel_cabang_aktif = is_instance_valid(panel_ui_cabang) and panel_ui_cabang.visible
	var panel_target_aktif = is_instance_valid(panel_ui_target) and panel_ui_target.visible
	
	if panel_cabang_aktif or panel_target_aktif:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled() 
		return

	# 1. LOGIKA UNTUK MENUTUP MENU DENGAN TOMBOL
	if event.is_action_pressed("ui_accept") and menu_aksi.visible and not mode_membidik:
		_on_tombol_tutup_pressed()

	# 2. LOGIKA KLIK / SENTUH UNTUK MENEMBAK (MODE BIDIK)
	if mode_membidik:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			tembak_raycast_ke_petak(event.position)

	# ========================================================
	# PERBAIKAN: DETEKSI SENTUHAN GESER (DRAG) UNTUK HP ANDROID
	# ========================================================
	var bisa_geser = _boleh_geser_kamera()

	if bisa_geser:
		# Menangkap pergerakan jari di layar (touchscreen) ATAU klik-tahan mouse kiri
		if event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			# Nilai sensitivitas usapan jari
			var sensitivitas = 0.05 
			
			# Mengubah arah gesekan layar 2D (X/Y) menjadi arah pergerakan kamera 3D (X/Z)
			# Digunakan operator minus (-=) agar arah usapan natural (seperti menarik kertas peta)
			geser_kamera.x -= event.relative.x * sensitivitas
			geser_kamera.z -= event.relative.y * sensitivitas

func _boleh_geser_kamera() -> bool:
	# Kamera boleh digeser bebas untuk melihat-lihat papan di AWAL giliran
	# (sebelum dadu dilempar) selama tidak ada karakter yang bergerak -- atau
	# kapan pun saat sedang membidik petak.
	if mode_membidik:
		return true
	if fase_giliran != "awal" or sedang_bergerak:
		return false
	if StatusJaringan.peran_multiplayer == "":
		# Solo: hanya di giliran pemain manusia (perilaku asli -- giliran AI tidak).
		return _slot_dari_aktor(giliran_sekarang) == slot_lokal
	# Multiplayer: di giliran SIAPA PUN, di kedua device. Dulu syaratnya
	# giliran_sekarang == "pemain" -- padahal "pemain" = slot 0 = HOST, jadi saat
	# giliran client kamera terkunci di kedua device.
	return true

func lempar_dadu(aktor):
	geser_kamera = Vector3.ZERO
	var slot_pelempar = _slot_dari_aktor(aktor)
	var tipe_dadu = tipe_dadu_slot[slot_pelempar]
	var hasil_dadu = 1
	
	if tipe_dadu == "rendah":
		hasil_dadu = mesin_acak.randi_range(1, 3)
	elif tipe_dadu == "tinggi":
		hasil_dadu = mesin_acak.randi_range(10, 12)
	else:
		if mode_rolet_double:
			hasil_dadu = mesin_acak.randi_range(2, 12)
			# Quick Match: dadu 2-12 sepanjang pertandingan di peta mana pun.
			if get_parent().get_node_or_null("PetaPantai") == null and not mode_quick:
				mode_rolet_double = false
				rolet.is_double = false
		else:
			hasil_dadu = mesin_acak.randi_range(1, 6)
	
	if UJI_DUEL:
		hasil_dadu = UJI_DADU_ANGKA
	_tambah_stat(slot_pelempar, "dadu_total", hasil_dadu)
	_tambah_stat(slot_pelempar, "dadu_kali")

	# Beritahu client hasil dadunya SEBELUM animasi diputar, supaya rolet berputar
	# bersamaan di kedua layar dengan angka yang sama persis.
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_mainkan_rolet", hasil_dadu, tipe_dadu, aktor)

	teks_uang.hide()
	teks_bintang.hide()
	teks_dadu.hide()
		
	await rolet.putar_rolet(hasil_dadu, tipe_dadu) # <--- Kirim parameter tipe_dadu
	
	teks_dadu.show()
	teks_dadu.text = _teks_hasil_dadu(slot_pelempar, hasil_dadu)

	await get_tree().create_timer(1.5).timeout
	rolet.hide()
	
	teks_uang.show()
	teks_bintang.show()
	
	bergerak_maju(hasil_dadu, aktor)

func bergerak_maju(jumlah_langkah, aktor):
	sedang_bergerak = true
	var slot = _slot_dari_aktor(aktor)
	var target_node = _node_karakter(slot)
	var target_model = _model(slot)
	var target_anim = _anim(slot)
	var posisi_sekarang = daftar_pemain[slot].posisi_saat_ini

	target_anim.play("run")
	var lewati_start = false
	var syarat_permata_saat_start = false 
	var sisa_langkah = jumlah_langkah
	
	while sisa_langkah > 0:
		var petak_kini = rute_papan[posisi_sekarang]
		var tujuan_node: Node3D = null
		
		if petak_kini.referensi_node_selanjutnya.size() == 1:
			tujuan_node = petak_kini.referensi_node_selanjutnya[0]
		else:
			tujuan_node = await _pilih_arah_cabang(petak_kini, aktor, target_anim)
		
		var petak_selanjutnya = rute_papan.find(tujuan_node)
		var gelembung_aktif = daftar_pemain[slot].sisa_gelembung > 0
		# (Cek jebakan air dipindah ke SETELAH langkah di bawah -- karakter harus
		# berdiri tepat di atas petak jebakan dulu, bukan ditarik ke sana.)

		var total_gaji = 0
		if tujuan_node.is_start_point and not gelembung_aktif:
			lewati_start = true
			_tambah_stat(slot, "lewat_start")
			var koleksi_aktif = koleksi_permata_slot[slot]

			# CEK SYARAT KEMENANGAN (ADAPTIF)
			# Otomatis terpenuhi jika peta tidak memiliki permata (target = 0), ATAU koleksi sudah cukup
			if target_permata_menang == 0 or koleksi_aktif.size() >= target_permata_menang:
				syarat_permata_saat_start = true

				var jumlah_petak_dimiliki = 0
				for j in range(rute_papan.size()):
					if status_kepemilikan_petak[j] and pemilik_petak[j] == slot:
						jumlah_petak_dimiliki += 1

				var bonus_uang_aset = jumlah_petak_dimiliki * 10
				total_gaji = 500 + bonus_uang_aset

				daftar_pemain[slot].uang += total_gaji
				daftar_pemain[slot].bintang = min(daftar_pemain[slot].bintang + 3, 10)
				putaran_slot[slot] += 1

				# Hanya reset koleksi jika sistem permata memang aktif di peta ini
				if target_permata_menang > 0:
					koleksi_aktif.clear() 
			else:
				# JIKA PERMATA KURANG, GAJI HANGUS
				target_anim.play("idle")
				teks_dadu.text = _teks_gaji_gagal(target_permata_menang)
				_siarkan_gaji_gagal(posisi_sekarang)
				await get_tree().create_timer(2.0).timeout
				if sisa_langkah > 1: target_anim.play("run")

		var posisi_target = tujuan_node.global_position
		posisi_target.y = target_model.global_position.y
		target_model.look_at(posisi_target, Vector3.UP)
		
		var tween = create_tween()
		tween.tween_property(target_node, "global_position", tujuan_node.global_position, 0.8)
		
		# Kabari client SETIAP langkah, bukan sekali di awal. Dengan begini kalau
		# host berhenti di tengah jalan (kena jebakan, dll), client ikut berhenti
		# di petak yang sama — tidak lagi jalan terus lalu teleport mundur.
		if StatusJaringan.peran_multiplayer == "host":
			rpc("rpc_langkah_client", petak_selanjutnya, aktor)

		await tween.finished
		posisi_sekarang = petak_selanjutnya
		sisa_langkah -= 1	
				
		# =======================================================
		# CEK JEBAKAN AIR (GEISER) - AKTIF SAAT MENGINJAK
		# Karakter sudah berjalan normal (langkah 0.8 dtk di atas) sampai berdiri
		# TEPAT di atas petak jebakan. Jeda sebentar, baru geisernya meledak dan
		# melempar karakter ke petak acak.
		# =======================================================
		var cek_jebakan = tujuan_node.get_node_or_null("JebakanAir")
		if cek_jebakan and cek_jebakan.aktif and cek_jebakan.pemilik != slot and not gelembung_aktif:
			# B-b (14.2/B4): Guard diperiksa PERTAMA -- jebakan hilang, korban
			# tidak terlempar/tergelembung/kena efek air apa pun.
			if _guard_boleh(slot, "air"):
				_pakai_guard(slot, "air")
				target_anim.play("idle")
				teks_dadu.text = "GUARD! Water Trap blocked!"
				# C5 (B-c, 26-09, perbaikan T2): dulu rpc_mainkan_efek_jebakan -- match
				# di fungsi itu tidak punya kasus "JebakanAir" jadi client tidak
				# pernah melihat teksnya. Sekarang lewat rpc_efek_role "guard".
				if StatusJaringan.peran_multiplayer == "host":
					rpc("rpc_efek_role", "guard", {"elemen": "air", "petak": posisi_sekarang, "aktor": aktor})
				update_ui_status()
				await get_tree().create_timer(1.0).timeout
				if is_instance_valid(cek_jebakan):
					cek_jebakan.queue_free()
				if sisa_langkah > 1: target_anim.play("run")
			else:
				_tambah_stat(cek_jebakan.pemilik, "jebakan_kena")
				if daftar_pemain[cek_jebakan.pemilik].role == "air": # Fase 4 (4c): XP Role "kena"
					_tambah_stat(cek_jebakan.pemilik, "jebakan_role_kena")
				target_anim.play("idle")
				teks_dadu.text = "TRAPPED! Geyser Eruption!"

				# B-b (B4): high_tide -- peluang (Lv1 50%/Lv2-3 100%) pemasang dapat
				# +1 bintang (dibatasi 10, sama seperti bonus lewat Start), Lv3 juga
				# +100 koin. Undian mesin_acak = HOST/solo saja (bagian 7, pola sama
				# card_magnet) -- hasilnya field LAMA (bintang/uang), sudah otomatis
				# ikut _siarkan_state_giliran, tidak butuh RPC baru.
				var angka_air = _angka_jebakan(cek_jebakan.pemilik, "air")
				var peluang_tide = float(angka_air["peluang_tide"])
				if peluang_tide > 0.0 and StatusJaringan.peran_multiplayer != "client" and mesin_acak.randf() < peluang_tide:
					daftar_pemain[cek_jebakan.pemilik].bintang = mini(daftar_pemain[cek_jebakan.pemilik].bintang + 1, 10)
					if bool(angka_air["tide_koin"]):
						daftar_pemain[cek_jebakan.pemilik].uang += 100

				# B-b (B4/K7): frozen_bubble -- kunci Use Card & LOW ROLL Lv3 diatur
				# SAAT KENA (di sini); dihitung mundur/dipicu di _mulai_giliran
				# SESUDAH gelembungnya sendiri habis (steady_feet Lv1 memendekkan
				# gelembung -- tidak berubah, lihat _durasi_gelembung).
				daftar_pemain[slot].kunci_kartu = int(angka_air["kunci_kartu"])
				daftar_pemain[slot].low_roll_bubble = bool(angka_air["low_roll_beku"])

				# Petak jatuhnya diundi DULUAN, lalu dikirim ke client bersama perintah
				# memutar jebakannya -- client memutar urutan yang sama persis (jeda,
				# geiser, terlempar melengkung ke petak yang sama, gelembung).
				# Urutan pemakaian mesin_acak tidak berubah (solo aman).
				# B-b (B4): rapid_current/steady_feet Lv2 menyempitkan kandidat petak
				# jatuh (Lv0 = semua petak, perilaku Langkah A acak murni tetap sama).
				var indeks_jatuh = cek_jebakan.pilih_petak_jatuh(self, slot, petak_selanjutnya, cek_jebakan.pemilik)
				if StatusJaringan.peran_multiplayer == "host":
					rpc("rpc_jebakan_air_aktif", petak_selanjutnya, indeks_jatuh, aktor)

				await get_tree().create_timer(JebakanAir.JEDA_SEBELUM_AKTIF).timeout
				sisa_langkah = 0 # HENTIKAN langkah dadu normal

				# --- LOGIKA BARU: Panggil fungsi dari jebakan_air.gd ---
				# Denda koin dihapus, dan petak jatuhnya sudah diundi di atas
				posisi_sekarang = await cek_jebakan.eksekusi_lemparan_acak(target_node, target_model, aktor, self, indeks_jatuh)

				# Hancurkan jebakan setelah selesai mengeksekusi efek
				if is_instance_valid(cek_jebakan):
					cek_jebakan.queue_free()

				# B-b (B4): Tsunami (Ultimate Air) -- lawan lain (bukan korban & bukan
				# pemasang) dalam jarak <= 2 petak (dua arah) dari petak jebakan ikut
				# terdorong mundur 2 petak, TANPA memicu efek petak tujuan. Posisi
				# barunya tersinkron client lewat _siarkan_state_giliran (field lama,
				# "posisi" memang sudah ada di sana) -- animasi geser di layar CLIENT
				# LAIN sekarang disiarkan lewat rpc_efek_role "tsunami" (C5), dikirim
				# sesudah loop ini; host/solo tetap melihatnya penuh di sini.
				if bool(angka_air["tsunami"]):
					var geser_tsunami: Array = []
					for lain in range(jumlah_pemain()):
						if lain == slot or lain == cek_jebakan.pemilik:
							continue
						var pos_lain = daftar_pemain[lain].posisi_saat_ini
						var maju_tsunami = _jarak_maju(petak_selanjutnya, pos_lain, 4)
						var mundur_tsunami = _jarak_maju(pos_lain, petak_selanjutnya, 4)
						if (maju_tsunami >= 0 and maju_tsunami <= 2) or (mundur_tsunami >= 0 and mundur_tsunami <= 2):
							var pos_baru_tsunami = _petak_mundur(pos_lain, 2)
							if pos_baru_tsunami != pos_lain:
								daftar_pemain[lain].posisi_saat_ini = pos_baru_tsunami
								var node_lain = _node_karakter(lain)
								if node_lain and pos_baru_tsunami >= 0 and pos_baru_tsunami < rute_papan.size():
									var tw_tsunami = create_tween()
									tw_tsunami.tween_property(node_lain, "global_position", rute_papan[pos_baru_tsunami].global_position, 0.6)
								geser_tsunami.append([lain, pos_baru_tsunami])
					if not geser_tsunami.is_empty() and StatusJaringan.peran_multiplayer == "host":
						rpc("rpc_efek_role", "tsunami", {"geser": geser_tsunami})

			break # KELUAR DARI LOOP BERJALAN

		# =======================================================
		# CEK JEBAKAN ANGIN (ANGIN PERAMPAS)
		# =======================================================
		var cek_angin = tujuan_node.get_node_or_null("JebakanAngin")
		if cek_angin and cek_angin.aktif and cek_angin.pemilik != slot and not gelembung_aktif:
			# B-b (14.2/B4): Guard diperiksa PERTAMA -- jebakan hilang, korban
			# tidak kehilangan koin/langkah sama sekali.
			if _guard_boleh(slot, "angin"):
				_pakai_guard(slot, "angin")
				target_anim.play("idle")
				teks_dadu.text = "GUARD! Wind Trap blocked!"
				# C5 (B-c, 26-09, perbaikan T2): rpc_efek_role "guard" gantikan
				# rpc_mainkan_efek_jebakan (lihat komentar cabang Guard Air di atas).
				if StatusJaringan.peran_multiplayer == "host":
					rpc("rpc_efek_role", "guard", {"elemen": "angin", "petak": posisi_sekarang, "aktor": aktor})
				update_ui_status()
				await get_tree().create_timer(1.0).timeout
				if is_instance_valid(cek_angin):
					cek_angin.queue_free()
				if sisa_langkah > 1: target_anim.play("run")
			else:
				target_anim.play("idle")

				# B-b (B4): strong_wind -- persen rampasan dari BUILD PEMASANG
				# (Lv0 = DASAR 10%, sama seperti Langkah A).
				var angka_angin = _angka_jebakan(cek_angin.pemilik, "angin")
				var koin_hilang = int(daftar_pemain[slot].uang * float(angka_angin["persen_rampas"]))
				koin_hilang = _kurangi_tahan(slot, "angin", koin_hilang) # Fase 4 (A4): heavy_pockets
				daftar_pemain[slot].uang -= koin_hilang
				_tambah_stat(cek_angin.pemilik, "jebakan_kena")
				if daftar_pemain[cek_angin.pemilik].role == "angin": # Fase 4 (4c): XP Role "kena"
					_tambah_stat(cek_angin.pemilik, "jebakan_role_kena")
				_tambah_stat(cek_angin.pemilik, "koin_jebakan", koin_hilang)

				teks_dadu.text = "WIND TRAP! Lost " + str(koin_hilang) + " Coins!"

				# C5 (B-c, 26-09): tetap dihitung SEBELUM sisa_pindah dikurangi di
				# bawah (Tornado) -- SELALU dikirim tegas (lihat komentar
				# rpc_mainkan_efek_jebakan, pemain_papan.gd).
				if StatusJaringan.peran_multiplayer == "host":
					rpc("rpc_mainkan_efek_jebakan", "JebakanAngin", posisi_sekarang, aktor, cek_angin.sisa_pindah > 0)
				cek_angin.mainkan_efek_perampas(target_model)
				_siarkan_teks_kerugian(slot, koin_hilang)

				# B-b (B4): homing_wind -- bagian rampasan LANGSUNG ke pemasang
				# (field uang lama, otomatis ikut _siarkan_state_giliran), sisanya
				# disebar seperti sekarang (Lv0 = 0%, semua tetap disebar).
				var koin_homing = int(round(koin_hilang * float(angka_angin["bagian_homing"])))
				var koin_sebar = koin_hilang - koin_homing
				if koin_homing > 0:
					daftar_pemain[cek_angin.pemilik].uang += koin_homing
				var hasil_sebar = cek_angin.eksekusi_sebar_acak(rute_papan, koin_sebar, mesin_acak)
				# Multiplayer: koin tercecer yang sama langsung muncul juga di client
				_siarkan_koin_tercecer(hasil_sebar)

				# B-b (B4/K8): whirlwind -- langkah dadu korban yang TERSISA ikut
				# hilang (Lv0 = 0, tidak berubah).
				var langkah_hilang = int(angka_angin["langkah_hilang"])
				if langkah_hilang > 0:
					sisa_langkah = maxi(0, sisa_langkah - langkah_hilang)

				update_ui_status()
				await get_tree().create_timer(1.5).timeout

				# B-b (B4): Tornado (Ultimate Angin) -- sesudah kena, jebakan
				# pindah ke petak kosong acak (sah untuk jebakan APA PUN) & aktif
				# lagi (bukan dihapus). Undian mesin_acak = HOST/solo saja (bagian
				# 7, pola sama card_magnet/high_tide). Posisi barunya tersinkron
				# client lewat _kumpulkan_data_jebakan/_terapkan_data_jebakan yang
				# memang sudah membandingkan jebakan per petak tiap siaran state --
				# tidak seperti Phoenix, di sini TIDAK ada state tambahan yang
				# hilang, cuma animasi pindah LANGSUNG di client lain yang belum
				# disiarkan RPC khusus (rpc_efek_role "tornado", C5).
				# C7 (B-c, 26-09, perbaikan bug T1): dulu digerbang bool(tornado)
				# SAJA -> pindah & aktif lagi TANPA BATAS (rencana B4: "sekali
				# lagi"). Sekarang digerbang cek_angin.sisa_pindah (diisi 1 di
				# _pasang_jebakan kalau pemasang punya Ultimate, pola Phoenix).
				if is_instance_valid(cek_angin) and cek_angin.sisa_pindah > 0 and StatusJaringan.peran_multiplayer != "client":
					var kandidat_tornado = _petak_kosong_untuk_jebakan()
					if not kandidat_tornado.is_empty():
						var idx_baru_tornado = kandidat_tornado[mesin_acak.randi_range(0, kandidat_tornado.size() - 1)]
						cek_angin.sisa_pindah -= 1
						cek_angin.get_parent().remove_child(cek_angin)
						rute_papan[idx_baru_tornado].add_child(cek_angin)
						cek_angin.aktif = true
						# C5 (B-c, 26-09): dikirim TEPAT setelah pindah -- client lain
						# (bukan host) memindahkan salinan visualnya SEKARANG, tidak
						# menunggu siaran state periodik berikutnya.
						if StatusJaringan.peran_multiplayer == "host":
							rpc("rpc_efek_role", "tornado", {"dari": petak_selanjutnya, "ke": idx_baru_tornado})
						cek_angin = null # jangan ikut dihapus di bawah -- sudah pindah & aktif lagi

				if is_instance_valid(cek_angin):
					cek_angin.queue_free()

				if sisa_langkah > 1: target_anim.play("run")
		
		# =======================================================
		# CEK JEBAKAN API (LUKA BAKAR 3 GILIRAN)
		# =======================================================
		var cek_api = tujuan_node.get_node_or_null("JebakanApi")
		if cek_api and cek_api.aktif and cek_api.pemilik != slot and not gelembung_aktif:
			target_anim.play("idle")

			# B-b (14.2/B4): Guard (node ketahanan Lv3) diperiksa PERTAMA -- kalau
			# aktif, jebakan hilang & korban tidak terkena efek APA PUN.
			if _guard_boleh(slot, "api"):
				_pakai_guard(slot, "api")
				teks_dadu.text = "GUARD! Fire Trap blocked!"
				# C5 (B-c, 26-09, perbaikan T2): rpc_efek_role "guard" gantikan
				# rpc_mainkan_efek_jebakan (lihat komentar cabang Guard Air di atas).
				if StatusJaringan.peran_multiplayer == "host":
					rpc("rpc_efek_role", "guard", {"elemen": "api", "petak": posisi_sekarang, "aktor": aktor})
				update_ui_status()
				await get_tree().create_timer(1.0).timeout
				if is_instance_valid(cek_api):
					cek_api.queue_free()
				if sisa_langkah > 1: target_anim.play("run")
			else:
				# B-b (B4): angka bakar dari BUILD PEMASANG (hot_flames/long_burn) --
				# angka HASIL (bakar_per_giliran) disimpan di korban, dipakai lagi
				# tiap giliran di _mulai_giliran (fire_tax dihitung ulang di sana
				# dari build bakar_pemilik, yang tidak berubah di tengah pertandingan).
				var angka_api = _angka_jebakan(cek_api.pemilik, "api")
				var estimasi_rugi = _kurangi_tahan(slot, "api", int(angka_api["bakar_per_giliran"]))
				# Fase 2: koin yang akan hilang (korban yang masih terbakar hanya diperpanjang).
				_tambah_stat(cek_api.pemilik, "jebakan_kena")
				if daftar_pemain[cek_api.pemilik].role == "api": # Fase 4 (4c): XP Role "kena"
					_tambah_stat(cek_api.pemilik, "jebakan_role_kena")
				_tambah_stat(cek_api.pemilik, "koin_jebakan", estimasi_rugi * maxi(0, int(angka_api["bakar_giliran"]) - daftar_pemain[slot].sisa_bakar))
				# Beri status terbakar (long_burn: giliran lebih lama; K7 pola sama Frozen Bubble)
				daftar_pemain[slot].sisa_bakar = int(angka_api["bakar_giliran"])
				daftar_pemain[slot].bakar_per_giliran = int(angka_api["bakar_per_giliran"])
				daftar_pemain[slot].bakar_pemilik = cek_api.pemilik
				daftar_pemain[slot].bakar_larang_jebakan = bool(angka_api["larang_jebakan"]) # long_burn Lv2/3

				teks_dadu.text = "FIRE TRAP! Burning for %d turns!" % daftar_pemain[slot].sisa_bakar

				# C5 (B-c, 26-09): tetap dihitung SEBELUM sisa_aktif_ulang dikurangi
				# di bawah (Phoenix) -- SELALU dikirim tegas (lihat komentar
				# rpc_mainkan_efek_jebakan, pemain_papan.gd).
				if StatusJaringan.peran_multiplayer == "host":
					rpc("rpc_mainkan_efek_jebakan", "JebakanApi", posisi_sekarang, aktor, cek_api.sisa_aktif_ulang > 0)
				cek_api.tempel_efek_terbakar(target_model) # <-- TAMBAHKAN BARIS INI
				cek_api.mainkan_efek_bakar()

				update_ui_status()
				await get_tree().create_timer(1.5).timeout

				# B-b (B4): Ultimate Phoenix -- korban PERTAMA tidak menghapus jebakan
				# (dipasang lagi otomatis), cuma mengurangi sisa_aktif_ulang. Sinkron
				# tampilan client (jangan ikut hapus lokal) menyusul B-c.
				if is_instance_valid(cek_api):
					if cek_api.sisa_aktif_ulang > 0:
						cek_api.sisa_aktif_ulang -= 1
					else:
						cek_api.queue_free() # <--- TAMBAHKAN INI UNTUK MENGHANCURKAN JEBAKAN

				if sisa_langkah > 1: target_anim.play("run")
			
		# =======================================================
		# CEK JEBAKAN PETIR (PARALISIS & STOP)
		# =======================================================
		var cek_petir = tujuan_node.get_node_or_null("JebakanPetir")
		if cek_petir and cek_petir.aktif and cek_petir.pemilik != slot and not gelembung_aktif:
			# B-b (14.2/B4): Guard diperiksa PERTAMA -- jebakan hilang, korban
			# TIDAK berhenti/lumpuh sama sekali (tidak berefek apa pun).
			if _guard_boleh(slot, "petir"):
				_pakai_guard(slot, "petir")
				target_anim.play("idle")
				teks_dadu.text = "GUARD! Lightning Trap blocked!"
				# C5 (B-c, 26-09, perbaikan T2): rpc_efek_role "guard" gantikan
				# rpc_mainkan_efek_jebakan -- dulu fungsi itu SELALU mengosongkan
				# _antrian_langkah_client untuk JebakanPetir juga di jalur Guard
				# ini, padahal Guard TIDAK menghentikan langkah korban sama sekali
				# (beda dari jebakan petir yang benar2 mengenai, lihat cabang else
				# di bawah). rpc_efek_role "guard" tidak menyentuh antrian itu.
				if StatusJaringan.peran_multiplayer == "host":
					rpc("rpc_efek_role", "guard", {"elemen": "petir", "petak": posisi_sekarang, "aktor": aktor})
				update_ui_status()
				await get_tree().create_timer(1.0).timeout
				if is_instance_valid(cek_petir):
					cek_petir.queue_free()
				if sisa_langkah > 1: target_anim.play("run")
			else:
				_tambah_stat(cek_petir.pemilik, "jebakan_kena")
				if daftar_pemain[cek_petir.pemilik].role == "petir": # Fase 4 (4c): XP Role "kena"
					_tambah_stat(cek_petir.pemilik, "jebakan_role_kena")
				target_anim.play("idle")

				# B-b (K13): giliran lumpuh & boleh-Fight-saat-lumpuh dari level
				# GROUNDED KORBAN (bukan DASAR tetap 2 untuk semua).
				var info_paralisis = _paralisis_untuk(slot)
				daftar_pemain[slot].sisa_paralisis = int(info_paralisis["sisa"])
				# Bagian 5 (#121): Grounded Lv1+ SELALU memendekkan sisa_paralisis dari
				# DASAR 2 -> 1 (lihat GROUNDED_LV, data_role.gd) -- benar2 mengubah hasil,
				# dicatat DI SINI (titik penerapan sungguhan), BUKAN di _paralisis_untuk
				# (dipanggil berkali-kali cuma untuk cek Fight-saat-lumpuh, 14.5).
				if _lv_node(slot, "grounded") > 0:
					_tambah_stat(slot, "tahan_kurangi")

				var angka_petir = _angka_jebakan(cek_petir.pemilik, "petir")
				# B-b (B4): shock -- korban kehilangan koin (HILANG, bukan ke
				# pemasang; grounded tidak mengurangi shock, hanya soal lumpuh).
				var koin_shock = int(angka_petir["koin_hilang"])
				if koin_shock > 0:
					daftar_pemain[slot].uang -= koin_shock
					_tambah_stat(cek_petir.pemilik, "koin_jebakan", koin_shock)

				# B-b (B4): chain_lightning -- lawan lain dalam jarak (maju dari
				# petak jebakan) kena LOW ROLL lemparan berikutnya (bagian 1: durasi
				# 2, tidak menimpa kartu LOW/HIGH ROLL yang durasinya lebih panjang).
				var jarak_rantai = int(angka_petir["jarak_rantai"])
				if jarak_rantai >= 0:
					var sasaran_rantai: Array = []
					for lain in range(jumlah_pemain()):
						if lain == slot or lain == cek_petir.pemilik:
							continue
						var j = _jarak_maju(petak_selanjutnya, daftar_pemain[lain].posisi_saat_ini, jarak_rantai)
						if j != -1 and j <= jarak_rantai and sisa_durasi_dadu_slot[lain] < 2:
							tipe_dadu_slot[lain] = "rendah"
							sisa_durasi_dadu_slot[lain] = 2
							sasaran_rantai.append(lain)
					# C5 (B-c, 26-09): teks saja -- tipe_dadu_slot/sisa_durasi_dadu_slot
					# di atas sudah ikut siaran state periodik (pemain_jaringan.gd),
					# RPC ini cuma supaya client lain langsung tahu SEKARANG.
					if not sasaran_rantai.is_empty() and StatusJaringan.peran_multiplayer == "host":
						rpc("rpc_efek_role", "chain_lightning", {"sasaran": sasaran_rantai})

				# B-b (B4): card_magnet -- curi 1 kartu acak korban. Undian
				# mesin_acak = HOST/solo saja (bagian 7); tanpa batas kartu di
				# kode sekarang, jadi "kartu pemasang sudah penuh" tidak pernah terjadi.
				var peluang_magnet = float(angka_petir["peluang_magnet"])
				if peluang_magnet > 0.0 and StatusJaringan.peran_multiplayer != "client" \
						and daftar_pemain[slot].inventaris_kartu.size() > 0 \
						and mesin_acak.randf() < peluang_magnet:
					var idx_kartu = mesin_acak.randi_range(0, daftar_pemain[slot].inventaris_kartu.size() - 1)
					var kartu_curi = daftar_pemain[slot].inventaris_kartu[idx_kartu]
					daftar_pemain[slot].inventaris_kartu.remove_at(idx_kartu)
					daftar_pemain[cek_petir.pemilik].inventaris_kartu.append(kartu_curi)
					# C5 (B-c, 26-09): teks saja -- inventaris_kartu kedua slot sudah
					# ikut siaran state periodik (pemain_jaringan.gd).
					if StatusJaringan.peran_multiplayer == "host":
						rpc("rpc_efek_role", "card_magnet", {"pencuri": cek_petir.pemilik, "korban": slot})

				# Pastikan karakter pindah ke titik jebakan dulu
				var tween_masuk = create_tween()
				tween_masuk.tween_property(target_node, "global_position", tujuan_node.global_position, 0.3)
				await tween_masuk.finished

				posisi_sekarang = petak_selanjutnya
				sisa_langkah = 0 # Hentikan sisa langkah secara paksa

				teks_dadu.text = "LIGHTNING TRAP! Paralyzed & Stopped!"
				# C5 (B-c, 26-09): petir yang BENAR mengenai selalu hilang -- tetap
				# dikirim tegas false (lihat komentar rpc_mainkan_efek_jebakan,
				# pemain_papan.gd, jangan andalkan nilai bawaan parameter RPC).
				if StatusJaringan.peran_multiplayer == "host":
					rpc("rpc_mainkan_efek_jebakan", "JebakanPetir", petak_selanjutnya, aktor, false)
				await cek_petir.tempel_efek_paralisis(target_model, kamera)

				update_ui_status()

				if is_instance_valid(cek_petir):
					cek_petir.queue_free()

				break # Keluar dari loop berjalan dan langsung masuk ke evaluasi petak

		# =======================================================
		# LOGIKA PENGAMBILAN KOIN TERCECER (SAAT LEWAT)
		# =======================================================
		var koin_jatuh = tujuan_node.get_node_or_null("KoinTercecer")
		if koin_jatuh and not gelembung_aktif:
			target_anim.play("idle")
			var dapet = koin_jatuh.isi_koin

			daftar_pemain[slot].uang += dapet

			teks_dadu.text = _subjek(slot) + " found " + str(dapet) + " Coins!"

			# Multiplayer: client ikut melihat koinnya diambil (koin hilang + "+X")
			if StatusJaringan.peran_multiplayer == "host":
				rpc("rpc_koin_diambil", posisi_sekarang, slot, dapet, daftar_pemain[slot].uang)

			# --- PANGGIL EFEK DARI KOIN SEBELUM DIHANCURKAN ---
			koin_jatuh.munculkan_efek_dapat_koin(target_model)
			
			koin_jatuh.queue_free()
			
			update_ui_status()
			
			await get_tree().create_timer(1.0).timeout
			if sisa_langkah > 1: target_anim.play("run")
			
		# LOGIKA KOLEKSI PERMATA DI TENGAH JALAN
		if tujuan_node.is_petak_permata and not gelembung_aktif:
			tujuan_node.mainkan_efek_permata()
			
			var kode_gambar_permata = tujuan_node.nama_warna_permata
			var koleksi_aktif = koleksi_permata_slot[slot]

			if not koleksi_aktif.has(kode_gambar_permata):
				koleksi_aktif.append(kode_gambar_permata)
				_tambah_stat(slot, "permata")
				_siarkan_permata_diambil(petak_selanjutnya, aktor, kode_gambar_permata, true, false)
				target_anim.play("idle")

				var siapa_yang_ambil = _subjek(slot)
				teks_dadu.text = siapa_yang_ambil + " collected " + kode_gambar_permata + " Gem!"
				update_ui_status()

				await get_tree().create_timer(1.5).timeout
				if sisa_langkah > 0: target_anim.play("run")
			else:
				_siarkan_permata_diambil(petak_selanjutnya, aktor, kode_gambar_permata, false, false)
				teks_dadu.text = "Passed " + kode_gambar_permata + "!"
				await get_tree().create_timer(0.3).timeout

		# =======================================================
		# LOGIKA KARTU GACHA DI TENGAH JALAN
		# =======================================================
		if tujuan_node.get("is_petak_kartu") and tujuan_node.node_sistem_kartu != null and not gelembung_aktif:
			# Multiplayer: host menentukan 3 kartunya & memberi tahu client (solo: kosong)
			var tiga_kartu = _mulai_petak_kartu_jaringan(tujuan_node.node_sistem_kartu, petak_selanjutnya, aktor)
			# 1. MAINKAN EFEK ANIMASI 3D & SUARA TERLEBIH DAHULU
			await tujuan_node.node_sistem_kartu.mainkan_efek_kartu()

			target_anim.play("idle")
			teks_dadu.text = _subjek(slot) + " landed on a Card Tile!"

			# 2. MESIN BERHENTI DI SINI DAN MENUNGGU KARTU DIPILIH DI UI
			var efek_kartu = await tujuan_node.node_sistem_kartu.mulai_gacha_kartu(_aktor_ui_kartu(slot), tiga_kartu, _mode_kartu(aktor), _nama_ui(slot))

			# 3. INTERSEPSI KARTU NORMAL (SIMPAN) ATAU INSTAN
			if efek_kartu.has("tipe_eksekusi") and efek_kartu["tipe_eksekusi"] == "simpan":
				var inv_aktif = daftar_pemain[slot].inventaris_kartu
				inv_aktif.append(efek_kartu)
				
				# Jika lebih dari 3, panggil UI Buang Kartu!
				if inv_aktif.size() > 3:
					await _buang_kartu_sinkron(tujuan_node.node_sistem_kartu, petak_selanjutnya, aktor, inv_aktif)

				teks_dadu.text = "Card saved to Inventory!"
			else:
				# Terapkan efek ke status (Koin/Bintang Instan)
				_terapkan_efek_kartu(efek_kartu, aktor)
			
			await get_tree().create_timer(1.0).timeout
			if sisa_langkah > 0: target_anim.play("run")

		# LOGIKA MELEWATI START TILE
		if tujuan_node.is_start_point and total_gaji > 0:
			target_anim.play("idle")
			teks_dadu.text = _subjek(slot) + " passed Start! Bonus +" + str(total_gaji)
			_siarkan_lewat_start(petak_selanjutnya, aktor, total_gaji)
			await label_petak_3d[petak_selanjutnya].mainkan_efek_lewat_start(total_gaji)
			update_ui_status()
			if sisa_langkah > 0: target_anim.play("run")
		elif not tujuan_node is PetakPermata and not tujuan_node.is_start_point and not tujuan_node.get("is_petak_kartu"):
			target_anim.play("idle")
			await get_tree().create_timer(0.2).timeout 
			if sisa_langkah > 0: target_anim.play("run")

	target_anim.play("idle")

	daftar_pemain[slot].posisi_saat_ini = posisi_sekarang
	_catat_berhenti_di_petak(slot)
	atur_posisi_berbagi_petak()
	await get_tree().create_timer(0.3).timeout

	if lewati_start and daftar_pemain[slot].uang >= SYARAT_KOIN_MENANG and syarat_permata_saat_start:
		await _akhiri_permainan(slot)
		return
	if cek_game_over(): return
	if _is_ai(slot):
		AiMusuh.logika_ai_musuh_setelah_jalan(self, slot)
	else:
		periksa_status_petak(slot)

# ========================================================
# AKHIR PERMAINAN (MENANG / KALAH)
# Dulu permainan cuma berhenti dengan satu baris teks, dan di multiplayer layar
# client tidak diberi tahu sama sekali sehingga menunggu selamanya.
# ========================================================
func _akhiri_permainan(slot_pemenang: int) -> void:
	sedang_bergerak = true
	if menu_aksi.visible: menu_aksi.hide()
	PengelolaIklan.sembunyikan_banner()

	var papan_skor = _susun_papan_skor(slot_pemenang)
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_permainan_selesai", slot_pemenang, daftar_pemain[slot_pemenang].posisi_saat_ini, papan_skor, _alasan_akhir)
	await _tampilkan_akhir_permainan(slot_pemenang, papan_skor, _alasan_akhir)

func _susun_papan_skor(slot_pemenang: int = -1) -> Array:
	# Urutan untuk panel peringkat di semua device (host menyusun, client memakai
	# salinannya). Classic: koin terbanyak. Quick Match: kekayaan terbesar, seri ->
	# petak terbanyak.
	var hasil = []
	for slot in range(jumlah_pemain()):
		var koleksi = koleksi_permata_slot[slot]
		hasil.append({
			"slot": slot,
			"uang": daftar_pemain[slot].uang,
			"bintang": daftar_pemain[slot].bintang,
			"petak": _jumlah_petak_slot(slot),
			"permata": koleksi.size(),
			"kekayaan": _kekayaan_slot(slot),
			# Fase 2: statistik pertandingan (XP, penghargaan & misi di tiap HP).
			"stat": statistik_slot[slot].duplicate(true) if slot < statistik_slot.size() else ProfilPemain.statistik_kosong(),
		})
	if mode_quick:
		hasil.sort_custom(func(a, b): return a["kekayaan"] > b["kekayaan"] or (a["kekayaan"] == b["kekayaan"] and a["petak"] > b["petak"]))
	else:
		hasil.sort_custom(func(a, b): return a["uang"] > b["uang"])
	# Pemenang selalu di baris pertama. Dulu bisa di baris 2: menang di START dengan
	# koin lebih sedikit daripada lawan yang permatanya belum lengkap.
	for i in range(hasil.size()):
		if int(hasil[i]["slot"]) == slot_pemenang and i > 0:
			hasil.push_front(hasil.pop_at(i))
			break
	# Fase 2: penghargaan akhir dihitung di sini (host/solo) -> sama di semua HP.
	var penghargaan = ProfilPemain.hitung_penghargaan(hasil)
	for baris in hasil:
		baris["penghargaan"] = penghargaan.get(int(baris["slot"]), [])
	return hasil

func _tampilkan_akhir_permainan(slot_pemenang: int, papan_skor: Array, alasan: String = "start") -> void:
	_permainan_selesai = true
	_alasan_akhir = alasan
	_slot_pemenang_akhir = slot_pemenang
	_papan_skor_akhir = papan_skor
	PengelolaIklan.catat_match_tuntas()
	_proses_hadiah_akhir(slot_pemenang, papan_skor)
	var menang = (slot_pemenang == slot_lokal)
	var embel = " & Gems" if target_permata_menang > 0 else ""
	teks_dadu.show()
	if alasan == "ronde":
		teks_dadu.text = "TIME UP! " + ("You are the richest!" if menang else _nama_slot(slot_pemenang) + " is the richest!")
	elif alasan == "ronde_koin":
		teks_dadu.text = "TIME UP! Tie! Coin toss winner: " + ("You!" if menang else _nama_slot(slot_pemenang) + "!")
	elif menang:
		teks_dadu.text = "VICTORY! You reached Start with " + str(SYARAT_KOIN_MENANG) + " Coins" + embel + "!"
	else:
		teks_dadu.text = "GAME OVER! " + _nama_slot(slot_pemenang) + " reached Start with " + str(SYARAT_KOIN_MENANG) + " Coins" + embel + "!"
	await UiDinamis.tampilkan_akhir_permainan(self, menang, papan_skor, _ringkasan_hadiah)

@rpc("authority", "call_remote", "reliable")
func rpc_permainan_selesai(slot_pemenang: int, posisi_pemenang: int, papan_skor: Array, alasan: String = "start") -> void:
	# Diterima di CLIENT. Tunggu dulu karakternya benar-benar tiba di layar ini --
	# di HP yang lambat langkahnya masih diputar saat host sudah menyatakan menang.
	# Kabar akhir sudah tiba: host yang terputus (keluar, atau iklan di HP-nya)
	# tidak boleh lagi memunculkan panel HOST LEFT / OPPONENT LEFT di sini.
	_akhir_diterima = true
	# Fase 2: hadiah profil dicatat SEKARANG, sebelum menunggu langkah/replay (bisa 20 dtk).
	_proses_hadiah_akhir(slot_pemenang, papan_skor)
	if alasan == "start":
		await _tunggu_langkah_ke_petak(posisi_pemenang)
	else:
		# Quick Match (ronde habis): giliran terakhir milik siapa saja -- tunggu SEMUA
		# langkah & replay yang masih diputar di layar ini (maks 20 dtk).
		await _selesaikan_replay_lokal()
	if _replay_serangan_berjalan:
		await replay_serangan_selesai
	sedang_bergerak = true
	if menu_aksi.visible: menu_aksi.hide()
	PengelolaIklan.sembunyikan_banner()
	await _tampilkan_akhir_permainan(slot_pemenang, papan_skor, alasan)

func periksa_status_petak(slot_index: int = 0):
	if status_kepemilikan_petak.size() == 0:
		return

	# Bagian B2: host menyiarkan state terbaru ke client setiap kali fungsi ini
	# dipanggil — ini titik yang SELALU dilewati tiap kali giliran berganti,
	# apapun aksi yang baru terjadi (dadu, beli, bangun, dst), jadi cukup satu
	# titik ini saja untuk menjaga kedua layar tetap sinkron.
	if StatusJaringan.peran_multiplayer == "host":
		_siarkan_state_giliran(slot_index)

	# PENTING: pembaruan state ini harus di ATAS penjaga di bawahnya. Host perlu
	# tetap tahu giliran siapa yang sedang berjalan walau bukan gilirannya sendiri
	# — kalau tidak, validasi RPC dari client akan memeriksa slot yang salah.
	slot_giliran_ui = slot_index
	aktor_giliran_ui = _aktor_dari_slot(slot_index)
	slot_lawan_ui = 1 - slot_index
	material_giliran_ui = _material_slot(slot_index)
	# Host: menu ini sekarang menunggu aksi dari device slot itu (kalau device
	# itu putus di sini, AI yang melanjutkan gilirannya). Slot manusia jaringan
	# yang device-nya sedang ditunggu kembali (migrasi host) tetap dicatat.
	_menunggu_aksi_slot = slot_index if slot_index >= 0 and slot_index < jumlah_pemain() and daftar_pemain[slot_index].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN else -1

	if StatusJaringan.peran_multiplayer != "":
		# Di mode solo, kamera diarahkan dari dalam logika AI. Karena AI dimatikan
		# untuk slot jaringan, pengarahan kamera harus dilakukan di sini — kalau
		# tidak, layar host tetap menyorot karakternya sendiri saat giliran lawan.
		target_kamera = _model(slot_index)

	if StatusJaringan.peran_multiplayer != "" and slot_index != slot_lokal:
		# Bukan giliran device ini. JANGAN return di sini — fungsi ini bukan cuma
		# menggambar menu, tapi juga menetapkan state penting seperti fase_giliran
		# ("konfrontasi" saat mendarat di petak lawan). Kalau host berhenti di sini,
		# host tidak pernah tahu sedang konfrontasi, lalu salah menafsirkan tombol
		# "Give Up" dari client sebagai tombol "Beli".
		# Jadi: biarkan seluruh logikanya jalan, sembunyikan menunya setelah selesai.
		_sembunyikan_menu_giliran_lawan.call_deferred()

	if StatusJaringan.peran_multiplayer != "" and teks_dadu.text.begins_with("Waiting for "):
		# Bagian B2: bersihkan sisa teks "menunggu" dari giliran sebelumnya —
		# tanpa ini, teksnya menempel terus di layar walau menu asli sudah
		# tampil, dan menutupi/mengganggu tombol di baliknya secara visual.
		teks_dadu.hide()

	var sudah_dibeli = status_kepemilikan_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini]
	var siapa_punya = pemilik_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini]
	var level_menara = level_menara_petak[daftar_pemain[slot_giliran_ui].posisi_saat_ini]
	
	tombol_beli.show()
	tombol_bangun.show()
	tombol_serang.show()
	tombol_tutup.show()
	
	tombol_beli.text = "Buy Tile"
	tombol_bangun.text = "Build Tower (500)"
	tombol_serang.text = "Attack Tile (Needs 5 Stars)"
	
	tombol_beli.disabled = true
	tombol_bangun.disabled = true
	tombol_serang.disabled = true
	tombol_tutup.disabled = false 
	
	if tombol_tanah: tombol_tanah.hide()
	if tombol_petir: tombol_petir.hide()
	if tombol_gunakan_kartu: tombol_gunakan_kartu.hide() # <--- TAMBAHKAN PROTEKSI INI
	
	# --- RESET TAMPILAN SUB-MENU JEBAKAN ---
	tombol_trap_air.hide()
	tombol_trap_api.hide()
	tombol_trap_tanah.hide()
	tombol_trap_petir.hide()
	tombol_trap_angin.hide()
	tombol_trap_batal.hide()
	
	# --- LOGIKA TOMBOL SET TRAP UTAMA ---
	tombol_set_trap.show()
	tombol_set_trap.text = "Set Trap"
	
	var petak_kini = rute_papan[daftar_pemain[slot_giliran_ui].posisi_saat_ini]
	# Memeriksa ketersediaan kelima tipe jebakan sekaligus
	var ada_jebakan = petak_kini.has_node("JebakanAir") or \
					  petak_kini.has_node("JebakanApi") or \
					  petak_kini.has_node("JebakanAngin") or \
					  petak_kini.has_node("JebakanPetir") or \
					  petak_kini.has_node("JebakanTanah")

	# Tombol nyala jika: bukan di Start, belum ada jebakan, tidak di dalam gelembung
	if daftar_pemain[slot_giliran_ui].posisi_saat_ini != 0 and not ada_jebakan and daftar_pemain[slot_giliran_ui].sisa_gelembung == 0:
		tombol_set_trap.disabled = false
	else:
		tombol_set_trap.disabled = true

	# =======================================================
	# PERBAIKAN: KHUSUS PETAK NON-TANAH HANYA BERLAKU SAAT SELESAI MELANGKAH (FASE AKHIR)
	# =======================================================
	var is_petak_khusus = petak_kini.referensi_node_selanjutnya.size() > 1 \
		or petak_kini.get("is_petak_permata") \
		or petak_kini.get("is_petak_kartu") \
		or petak_kini.get("is_start_point") or daftar_pemain[slot_giliran_ui].posisi_saat_ini == 0

	if fase_giliran == "akhir" and is_petak_khusus:
		tombol_beli.hide()
		tombol_bangun.hide()
		tombol_serang.hide()
		tombol_set_trap.hide() # <--- TAMBAHKAN BARIS INI
		tombol_tutup.text = "End Turn"
		menu_aksi.show()
		return

	if daftar_pemain[slot_giliran_ui].sisa_gelembung > 0 and fase_giliran == "akhir":
		tombol_beli.hide()
		tombol_bangun.hide()
		tombol_serang.hide()
		tombol_set_trap.hide() # <--- TAMBAHKAN BARIS INI
		tombol_tutup.text = "Floating (End Turn)"
		menu_aksi.show()
		return

	# =======================================================
	# PENGATURAN MENU FASE AWAL (SAAT PLAYER BARU MENDAPAT GILIRAN)
	# =======================================================
	if fase_giliran == "awal":
		tombol_tutup.text = "Roll Dice"
		tombol_beli.hide()
		tombol_bangun.hide()
		
		# ---> TAMBAHKAN LOGIKA INI <---
		if daftar_pemain[slot_giliran_ui].inventaris_kartu.size() > 0 and daftar_pemain[slot_giliran_ui].sisa_paralisis == 0 and daftar_pemain[slot_giliran_ui].sisa_gelembung == 0 and daftar_pemain[slot_giliran_ui].kunci_kartu == 0: # B-b (B4/K7): frozen_bubble
			tombol_gunakan_kartu.show()
			tombol_gunakan_kartu.text = "Use Card (" + str(daftar_pemain[slot_giliran_ui].inventaris_kartu.size()) + ")"
		else:
			tombol_gunakan_kartu.hide()
	else:
		tombol_tutup.text = "End Turn"
		if tombol_gunakan_kartu: tombol_gunakan_kartu.hide() # Sembunyikan di fase akhir

	# LOGIKA KONFRONTASI DENGAN PETAK MUSUH (petak milik pemain LAIN mana pun)
	if fase_giliran == "akhir" and sudah_dibeli and siapa_punya >= 0 and siapa_punya != slot_giliran_ui:
		var denda = 100
		if level_menara == 1: denda = 300
		elif level_menara == 2: denda = 600

		fase_giliran = "konfrontasi"
		slot_lawan_ui = siapa_punya
		teks_dadu.text = _teks_petak_lawan(siapa_punya, denda)
		
		tombol_beli.text = "Give Up (Pay " + str(denda) + ")"
		tombol_beli.disabled = false
		
		# Fase 4 (A4): Rock Breaker -- sebelum duel dimulai, pakai jebakan tanah
		# yang TERLIHAT di petak sekarang (bukan _tanah_saat_duel, yang baru
		# terisi saat duel sungguhan dimulai).
		var ada_tanah_di_sini = rute_papan[daftar_pemain[slot_giliran_ui].posisi_saat_ini].has_node("JebakanTanah")
		var lv_rock_breaker = _lv_node(slot_giliran_ui, "rock_breaker")
		var stone_thorns_p_sini = _stone_thorns_p_di(daftar_pemain[slot_giliran_ui].posisi_saat_ini)
		var denda_kalah = int(denda * DataRole.pengali_kalah_duel(lv_rock_breaker, ada_tanah_di_sini, stone_thorns_p_sini))
		tombol_bangun.text = "Fight (Risk: " + str(denda_kalah) + ")"

		# JIKA SEDANG PARALISIS, KUNCI TOMBOL FIGHT -- kecuali Grounded Lv2/3 (K13).
		if daftar_pemain[slot_giliran_ui].sisa_paralisis > 0 and not _boleh_fight_saat_lumpuh(slot_giliran_ui):
			tombol_bangun.disabled = true
			tombol_bangun.text += " (Disabled: Paralyzed)"
		else:
			tombol_bangun.disabled = false
		
		tombol_serang.hide()
		if tombol_set_trap: tombol_set_trap.hide()
		tombol_tutup.disabled = true 
		menu_aksi.show()
		return

	# LOGIKA JUAL BELI DAN UPGRADE BANGUNAN
	if daftar_pemain[slot_giliran_ui].posisi_saat_ini != 0 and fase_giliran == "akhir":
		if not sudah_dibeli:
			if daftar_pemain[slot_giliran_ui].uang >= harga_tanah: tombol_beli.disabled = false
		elif sudah_dibeli and siapa_punya == slot_giliran_ui:
			# Syaratnya BUKAN jumlah putaran papan, melainkan berapa kali pemain
			# berhenti tepat di petak ini sejak memilikinya (lihat _catat_berhenti_di_petak).
			var posisi_ui = daftar_pemain[slot_giliran_ui].posisi_saat_ini
			var berhenti_ulang = berhenti_di_petak_sendiri[posisi_ui] if posisi_ui < berhenti_di_petak_sendiri.size() else 0
			if level_menara == 0:
				if berhenti_ulang >= 1:
					tombol_bangun.text = "Build Tower (500)"
					if daftar_pemain[slot_giliran_ui].uang >= harga_menara_lv1: tombol_bangun.disabled = false
				else:
					tombol_bangun.text = "Build (Stop Here Again)"
					tombol_bangun.disabled = true
			elif level_menara == 1:
				if berhenti_ulang >= 1:
					tombol_bangun.text = "Upgrade Lv.2 (800)"
					if daftar_pemain[slot_giliran_ui].uang >= harga_menara_lv2: tombol_bangun.disabled = false
				else:
					tombol_bangun.text = "Upgrade (Stop Here Again)"
					tombol_bangun.disabled = true
			elif level_menara == 2:
				tombol_bangun.text = "Max Tower"
				tombol_bangun.disabled = true

	# --- PROTEKSI TAMBAHAN JIKA PARALISIS (Petak sendiri / kosong) ---
	if daftar_pemain[slot_giliran_ui].sisa_paralisis > 0 and fase_giliran == "akhir":
		tombol_beli.disabled = true
		tombol_bangun.disabled = true
		tombol_serang.disabled = true
		if tombol_set_trap: tombol_set_trap.disabled = true

	# LOGIKA KETENTUAN SERANGAN JARAK JAUH (ada petak milik pemain lain mana pun)
	var musuh_punya_tanah = false
	for i in range(rute_papan.size()):
		if pemilik_petak[i] >= 0 and pemilik_petak[i] != slot_giliran_ui: musuh_punya_tanah = true

	if daftar_pemain[slot_giliran_ui].bintang >= 5 and musuh_punya_tanah and fase_giliran == "awal" and not sudah_serang_giliran_ini:
		tombol_serang.disabled = false 

	menu_aksi.show()

# ========================================================
# PETAK CABANG (PERSIMPANGAN)
# Solo: perilaku asli (pemain memilih lewat UI, AI mengacak). Multiplayer:
# pemilik karakter yang memilih di device-nya sendiri, lawannya melihat panel
# yang sama dalam mode "tonton", lalu pilihannya diumumkan di kedua layar.
# Dulu karakter client dipilihkan acak oleh host (mesin_acak).
# ========================================================

func _pilih_arah_cabang(petak_kini: Node3D, aktor: String, target_anim) -> Node3D:
	var pilihan = petak_kini.referensi_node_selanjutnya
	var slot = _slot_dari_aktor(aktor)
	if StatusJaringan.peran_multiplayer == "" or _is_ai(slot):
		if not _is_ai(slot):
			target_anim.play("idle")
			UiDinamis.munculkan_ui_cabang(self, petak_kini)
			var tujuan = await self.arah_cabang_terpilih
			target_anim.play("run")
			return tujuan
		# AI (solo, atau dijalankan host di multiplayer) memilih acak; device
		# lain cukup melihat karakternya berbelok.
		var indeks_acak = mesin_acak.randi_range(0, pilihan.size() - 1)
		return pilihan[indeks_acak]

	# MULTIPLAYER (host)
	target_anim.play("idle")
	var index_petak = rute_papan.find(petak_kini)
	var indeks: int
	if slot == slot_lokal:
		# Karakter host: host memilih, semua client menonton.
		rpc("rpc_lawan_memilih_cabang", index_petak, slot)
		UiDinamis.munculkan_ui_cabang(self, petak_kini, "lokal")
		indeks = await cabang_lokal_diklik
		rpc("rpc_cabang_dipilih", indeks, slot) # saat itu juga, bukan setelah pengumuman
		await UiDinamis.umumkan_pilihan_cabang(self, indeks, true)
	else:
		# Karakter client: client itu yang memilih, host & client lain menonton.
		_jawaban_cabang_client = -1
		_slot_pemilih_cabang = slot
		var id_pemilih = _peer_slot(slot)
		if id_pemilih > 1: # -1 = device-nya sedang ditunggu kembali (dijawab otomatis)
			rpc_id(id_pemilih, "rpc_minta_pilih_cabang", index_petak)
		_rpc_ke_klien_kecuali([id_pemilih], "rpc_lawan_memilih_cabang", [index_petak, slot])
		UiDinamis.munculkan_ui_cabang(self, petak_kini, "tonton", _nama_ui(slot))
		indeks = _jawaban_cabang_client # bisa saja sudah datang duluan
		if indeks < 0:
			indeks = await cabang_client_dijawab
		_slot_pemilih_cabang = -1
		_rpc_ke_klien_kecuali([id_pemilih], "rpc_cabang_dipilih", [indeks, slot])
		await UiDinamis.umumkan_pilihan_cabang(self, indeks, false, _nama_ui(slot))
	target_anim.play("run")
	return pilihan[clampi(indeks, 0, pilihan.size() - 1)]

@rpc("authority", "call_remote", "reliable")
func rpc_minta_pilih_cabang(index_petak: int) -> void:
	# Diterima di CLIENT: karakter client tiba di persimpangan, pemain client memilih.
	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	await _tunggu_langkah_ke_petak(index_petak) # berdiri di persimpangan dulu
	UiDinamis.munculkan_ui_cabang(self, rute_papan[index_petak], "lokal")
	var generasi = _generasi_jaringan
	var indeks = await cabang_lokal_diklik
	if generasi != _generasi_jaringan or StatusJaringan.peran_multiplayer != "client":
		return
	rpc_id(1, "rpc_jawab_pilih_cabang", indeks)
	await UiDinamis.umumkan_pilihan_cabang(self, indeks, true)

@rpc("any_peer", "call_remote", "reliable")
func rpc_jawab_pilih_cabang(indeks: int) -> void:
	# Diterima di HOST: arah yang dipilih pemain client.
	if not multiplayer.is_server():
		return
	if _slot_pemilih_cabang < 0 or multiplayer.get_remote_sender_id() != _peer_slot(_slot_pemilih_cabang):
		return
	if _jawaban_cabang_client >= 0:
		return # sudah dijawab
	_jawaban_cabang_client = indeks
	cabang_client_dijawab.emit(indeks)

@rpc("authority", "call_remote", "reliable")
func rpc_lawan_memilih_cabang(index_petak: int, slot_pemilih: int = 0) -> void:
	# Diterima di CLIENT: karakter pemain LAIN tiba di persimpangan -- panel "tonton".
	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	_pilihan_cabang_tertunda = -1
	await _tunggu_langkah_ke_petak(index_petak)
	UiDinamis.munculkan_ui_cabang(self, rute_papan[index_petak], "tonton", _nama_ui(slot_pemilih))
	_cabang_tonton_terbuka = true
	if _pilihan_cabang_tertunda >= 0:
		# Pemiliknya sudah memilih selagi karakternya masih berjalan di layar ini.
		var indeks = _pilihan_cabang_tertunda
		_pilihan_cabang_tertunda = -1
		_cabang_tonton_terbuka = false
		await UiDinamis.umumkan_pilihan_cabang(self, indeks, false, _nama_ui(slot_pemilih))

@rpc("authority", "call_remote", "reliable")
func rpc_cabang_dipilih(indeks: int, slot_pemilih: int = 0) -> void:
	# Diterima di CLIENT: pemilik karakter sudah memilih arah.
	if not _cabang_tonton_terbuka:
		_pilihan_cabang_tertunda = indeks # panel tonton belum muncul -- simpan dulu
		return
	_cabang_tonton_terbuka = false
	await UiDinamis.umumkan_pilihan_cabang(self, indeks, false, _nama_ui(slot_pemilih))

func _on_tombol_tutup_pressed():
	# Selama membidik, tombol ini jadi "Cancel". Membidik cuma terjadi di device
	# ini, jadi batalnya juga di sini -- dulu di client ikut diteruskan ke host
	# sebagai "tutup", dan host malah melempar dadu untuk client.
	if mode_membidik and StatusJaringan.peran_multiplayer == "client":
		_proses_tombol_tutup()
		return
	if _teruskan_aksi_ke_host("tutup"): return
	_proses_tombol_tutup()

func _proses_tombol_tutup() -> void:
	if mode_membidik:
		mode_membidik = false
		geser_kamera = Vector3.ZERO
		teks_dadu.text = "Attack canceled."
		periksa_status_petak(slot_giliran_ui)
		return

	menu_aksi.hide()

	if fase_giliran == "awal":
		fase_giliran = "akhir"
		teks_dadu.text = "You are rolling dice..."
		lempar_dadu(aktor_giliran_ui)
	else: ganti_giliran()

func ganti_giliran():
	geser_kamera = Vector3.ZERO 
	sudah_serang_giliran_ini = false
	if menu_aksi.visible: menu_aksi.hide()
	
	# Giliran berpindah ke slot berikutnya: 0 -> 1 -> ... -> N-1 -> 0.
	var slot = _slot_berikutnya(_slot_dari_aktor(giliran_sekarang))
	# QUICK MATCH: giliran kembali ke P1 = satu ronde selesai.
	if batas_ronde > 0 and slot == 0:
		# CONNECTION LOST (P1 menunggu pemain kembali): hitung ronde SETELAH mereka
		# kembali. Kalau ronde terakhir diakhiri di sini, HP lain tidak pernah tahu.
		# Keputusan putus yang masih tertunda 3 dtk (_putuskan_setelah_jeda) ditunggu
		# dulu -- giliran AI bisa selesai lebih cepat daripada keputusan itu. Lalu pola
		# yang sama dengan awal _mulai_giliran (sinyal & penanda yang sama).
		while not _putus_tertunda.is_empty():
			await get_tree().process_frame
		while _menunggu_pemain_kembali:
			_dijeda_di_awal_giliran = true
			await pemain_kembali_selesai
		_dijeda_di_awal_giliran = false
		if ronde_sekarang + 1 > batas_ronde:
			await _akhiri_karena_ronde_habis()
			return
		ronde_sekarang += 1
		_perbarui_label_ronde()
	_tambah_stat(slot, "giliran")
	giliran_sekarang = _aktor_dari_slot(slot)
	fase_giliran = "awal"
	await _mulai_giliran(slot)

func _mulai_giliran(slot: int) -> void:
	# Efek-efek awal giliran (durasi dadu, gelembung, terbakar, paralisis), lalu
	# giliran diserahkan ke AI atau ke menu pemain manusia. Sama untuk semua slot.
	# Jaringan host sempat hilang (CONNECTION LOST): giliran berikutnya ditahan di
	# sini sampai host menekan START NOW / PLAY ALONE VS AI.
	while _menunggu_pemain_kembali:
		_dijeda_di_awal_giliran = true
		await pemain_kembali_selesai
	_dijeda_di_awal_giliran = false
	var data = daftar_pemain[slot]
	var model = _model(slot)
	
	# ---> TAMBAHAN DURASI DADU <---
	if sisa_durasi_dadu_slot[slot] > 0:
		sisa_durasi_dadu_slot[slot] -= 1
		if sisa_durasi_dadu_slot[slot] == 0:
			tipe_dadu_slot[slot] = "normal"
			_umumkan("dadu_habis", slot)
			await get_tree().create_timer(1.0).timeout
	
	# Kuras durasi gelembung
	if data.sisa_gelembung > 0:
		data.sisa_gelembung -= 1
		if data.sisa_gelembung == 0:
			var hancur = model.get_node_or_null("EfekGelembung")
			if hancur: hancur.queue_free()
			# B-b (B4/K7): frozen_bubble Lv3 -- LOW ROLL sekali TEPAT saat
			# gelembung pecah (bukan menunggu kunci_kartu habis).
			if data.low_roll_bubble:
				data.low_roll_bubble = false
				tipe_dadu_slot[slot] = "rendah"
				sisa_durasi_dadu_slot[slot] = 2
	elif data.kunci_kartu > 0:
		# B-b (B4/K7): kunci Use Card dihitung mundur SESUDAH gelembungnya
		# sendiri habis (giliran sendiri berikutnya, bukan tick yang sama saat
		# gelembung pecah) -- dibaca tombol Use Card (periksa_status_petak),
		# validasi host pemakaian kartu (pemain_kartu.gd), & AI (ai_musuh.gd).
		data.kunci_kartu -= 1

	# EFEK TERBAKAR
	if data.sisa_bakar > 0:
		data.sisa_bakar -= 1
		# B-b (B4): heat_skin memotong kerugian (level-aware, -25%/-50%). Angka
		# HASIL yang sama dipakai di semua tempat (umumkan, RPC, efek visual).
		# bakar_per_giliran disimpan di korban SAAT kena (hot_flames pemasang).
		var jumlah_rugi_bakar = _kurangi_tahan(slot, "api", data.bakar_per_giliran)
		data.uang -= jumlah_rugi_bakar
		# fire_tax: bagian bakaran -> pemilik jebakan (build pemilik tidak
		# berubah di tengah pertandingan, aman dihitung ulang tiap giliran).
		if data.bakar_pemilik >= 0 and data.bakar_pemilik < daftar_pemain.size() and data.bakar_pemilik != slot:
			var pajak_api = float(_angka_jebakan(data.bakar_pemilik, "api").get("fire_tax", 0.0))
			if pajak_api > 0.0:
				var koin_pajak = roundi(jumlah_rugi_bakar * pajak_api)
				if koin_pajak > 0:
					daftar_pemain[data.bakar_pemilik].uang += koin_pajak
		_umumkan("terbakar", slot, data.sisa_bakar, jumlah_rugi_bakar)
		update_ui_status()

		# Suntik Skrip Residu
		var script_api = preload("res://jebakan_api.gd")
		var efek_api = script_api.new()
		efek_api.mode_residu = true
		add_child(efek_api)

		if StatusJaringan.peran_multiplayer == "host":
			rpc("rpc_teks_kerugian", slot, jumlah_rugi_bakar)
		await efek_api.proses_penderitaan_giliran(model, kamera, self, jumlah_rugi_bakar)
		efek_api.queue_free()
		
		if data.sisa_bakar == 0:
			var hancur = model.get_node_or_null("EfekTerbakar")
			if hancur: hancur.queue_free()
			
	# EFEK PARALISIS (SKIP GILIRAN & KLAIM ITEM SETELAH SEMBUH)
	if data.sisa_paralisis > 0:
		data.sisa_paralisis -= 1
		if data.sisa_paralisis > 0:
			target_kamera = model
			if slot == slot_lokal:
				sedang_bergerak = false
			
			var pos_ideal = model.global_position + (kamera.global_transform.basis.z * 30.0)
			if kamera.global_position.distance_to(pos_ideal) > 40.0:
				kamera.global_position = pos_ideal
				
			_umumkan("lumpuh", slot)

			# Siarkan ke client SEBELUM diputar lokal (bukan sesudah) supaya getaran
			# & teks "PARALYSIS" muncul di semua layar nyaris bersamaan -- pola sama
			# dipakai pengumuman kartu pedang (lihat rpc_pedang_dipilih_host).
			if StatusJaringan.peran_multiplayer == "host":
				rpc("rpc_mainkan_efek_sisa_paralisis", _aktor_dari_slot(slot))

			var script_petir = preload("res://jebakan_petir.gd")
			var efek_petir = script_petir.new()
			efek_petir.mode_residu = true
			add_child(efek_petir)

			_munculkan_teks_paralysis(model)
			await efek_petir.mainkan_efek_sisa_paralisis(model, kamera)
			efek_petir.queue_free()
			
			fase_giliran = "akhir"
			# Fase 4 (A5b / K12): giliran lumpuh yang DILEWATI (masih lumpuh setelah
			# dikurangi) tidak lagi menjalankan konfrontasi di petak lawan -- dulu
			# periksa_status_petak (manusia) / logika_ai_musuh_setelah_jalan (AI) bisa
			# menagih denda petak lawan KEDUA KALINYA (sekali saat mendarat & berhenti,
			# sekali lagi di giliran yang cuma dilewati). Korban di sini hanya
			# mengakhiri giliran; ambil kartu/permata tetap di cabang "paralisis
			# selesai" di bawah, tidak berubah.
			if _is_ai(slot):
				_siarkan_state_ai(slot)
			ganti_giliran()
			return
		else:
			# --- PARALISIS SELESAI: CEK PETAK UNTUK KARTU/PERMATA ---
			target_kamera = model
			var petak_kini = rute_papan[data.posisi_saat_ini]
			if petak_kini.is_petak_permata:
				await _ambil_permata_setelah_paralisis(_aktor_dari_slot(slot), petak_kini)
			elif petak_kini.get("is_petak_kartu") and petak_kini.node_sistem_kartu != null:
				await _ambil_kartu_setelah_paralisis(_aktor_dari_slot(slot), petak_kini)

	# Gerakan di giliran sebelumnya sudah tuntas. Tanpa ini sedang_bergerak tetap
	# true sepanjang giliran berikutnya, dan kamera host tidak bisa digeser.
	sedang_bergerak = false
	if _is_ai(slot):
		_siarkan_state_ai(slot)
		AiMusuh.logika_ai_fase_awal(self, slot)
	elif slot == slot_lokal:
		target_kamera = model 
		teks_dadu.text = "YOUR TURN! Choose Action or Roll Dice."
		periksa_status_petak(slot)
	else:
		periksa_status_petak(slot)

func cek_game_over(): return false

# ========================================================
# QUICK MATCH (Fase 1): ronde, kekayaan, kecepatan 1,5x
# ========================================================
func _atur_kecepatan_permainan() -> void:
	# QUICK MATCH: 1,5x selama giliran berjalan normal; panel yang menghentikan
	# permainan kembali 1x (batas waktu jaringan di sana memakai jam permainan).
	# Classic TIDAK PERNAH menyentuh Engine.time_scale (rig & uji lama tetap sama).
	if not mode_quick:
		return
	if StatusJaringan.skala_waktu_dasar < 0.0:
		StatusJaringan.skala_waktu_dasar = Engine.time_scale # 1 di HP, 3 di rig uji
	var cepat = _giliran_berjalan and not _permainan_selesai and not _migrasi_berjalan \
		and not _mode_jaringan_putus and not _panel_putus_terbuka
	var target = StatusJaringan.skala_waktu_dasar * (KECEPATAN_QUICK if cepat else 1.0)
	if not is_equal_approx(Engine.time_scale, target):
		Engine.time_scale = target

func _jumlah_petak_slot(slot: int) -> int:
	var n = 0
	for i in range(rute_papan.size()):
		if status_kepemilikan_petak[i] and pemilik_petak[i] == slot:
			n += 1
	return n

func _kekayaan_slot(slot: int) -> int:
	# Koin + nilai beli semua petak & menara (Quick Match). Nilainya sama dengan
	# harga beli, jadi membeli petak/menara tidak mengubah kekayaan.
	var total = daftar_pemain[slot].uang
	for i in range(rute_papan.size()):
		if status_kepemilikan_petak[i] and pemilik_petak[i] == slot:
			total += harga_tanah
			if level_menara_petak[i] >= 1: total += harga_menara_lv1
			if level_menara_petak[i] == 2: total += harga_menara_lv2
	return total

func _pemenang_kekayaan() -> Dictionary:
	# Kekayaan terbesar -> petak terbanyak -> lempar koin (mesin_acak; hanya host/solo).
	var calon = []
	var terbaik = -2147483648
	for s in range(jumlah_pemain()):
		var k = _kekayaan_slot(s)
		if k > terbaik:
			terbaik = k
			calon = [s]
		elif k == terbaik:
			calon.append(s)
	if calon.size() > 1:
		var paling = -1
		var sisa = []
		for s in calon:
			var n = _jumlah_petak_slot(s)
			if n > paling:
				paling = n
				sisa = [s]
			elif n == paling:
				sisa.append(s)
		calon = sisa
	if calon.size() > 1:
		return {"slot": calon[mesin_acak.randi_range(0, calon.size() - 1)], "koin": true}
	return {"slot": calon[0], "koin": false}

func _akhiri_karena_ronde_habis() -> void:
	var hasil = _pemenang_kekayaan()
	_alasan_akhir = "ronde_koin" if hasil["koin"] else "ronde"
	await _akhiri_permainan(hasil["slot"])

func _proses_hadiah_akhir(slot_pemenang: int, papan_skor: Array) -> void:
	# Hadiah profil untuk pemain di HP ini, SEKALI per pertandingan, langsung tersimpan
	# (sebelum animasi/menunggu replay -- HP yang ditutup di layar akhir tetap dapat).
	if _hadiah_akhir_diproses:
		return
	_hadiah_akhir_diproses = true
	_ringkasan_hadiah = ProfilPemain.catat_akhir_match(_data_akhir_profil(slot_pemenang, papan_skor))

func _data_akhir_profil(slot_pemenang: int, papan_skor: Array) -> Dictionary:
	var stat_lokal = {}
	var peng_lokal = []
	for baris in papan_skor:
		if int(baris["slot"]) == slot_lokal:
			stat_lokal = baris.get("stat", {})
			peng_lokal = baris.get("penghargaan", [])
	# Fase 4 (4c): role dikirim supaya ProfilPemain tahu bucket xp_role[role] mana yang
	# ditambah -- "" (belum pilih role, mis. uji lama) = tidak ada XP Role.
	return {"menang": slot_pemenang == slot_lokal, "quick": mode_quick,
		"multiplayer": StatusJaringan.peran_multiplayer != "", "stat": stat_lokal, "penghargaan": peng_lokal,
		"role": daftar_pemain[slot_lokal].role if slot_lokal >= 0 and slot_lokal < daftar_pemain.size() else ""}

func _siapkan_peta_dan_mulai(pilihan_peta: String, jumlah_ai: int = 1, quick: bool = false):
	di_main_menu = false
	# Quick Match (Fase 1): dipilih di menu solo atau oleh host di lobby.
	mode_quick = quick
	ronde_sekarang = 1
	_ronde_spanduk = -1
	_iklan_hutang_terpakai = false

	if StatusJaringan.peran_multiplayer == "":
		# Solo: 1 pemain manusia (slot 0) + 1-3 lawan AI, dipilih di menu SINGLE PLAYER.
		var jumlah_total = clampi(1 + jumlah_ai, 2, MAKS_PEMAIN)
		while daftar_pemain.size() < jumlah_total:
			var d = DataPemain.new(DataPemain.JenisKontrol.AI, "P%d" % (daftar_pemain.size() + 1))
			d.bintang = 4
			daftar_pemain.append(d)
		_siapkan_slot_pemain()
	# Fase 4 (A2): role + jebakan dibawa + build tiap slot (solo: profil & AI;
	# multiplayer: StatusJaringan.role_slot dari lobby). Sesudah slot tersusun.
	_siapkan_role_semua()
	if jumlah_pemain() > 2:
		# HUD 3-4 pemain: panel besar YOU di kiri + daftar lawan di kanan.
		UiDinamis.atur_hud_banyak_pemain(self)
		update_ui_status()
	batas_ronde = StatusJaringan.BATAS_RONDE_QUICK.get(jumlah_pemain(), 8) if mode_quick else 0
	_reset_statistik()

	var peta_lama = get_parent().get_node_or_null("PetaAlam")
	if peta_lama:
		peta_lama.queue_free()
		
	var scene_peta_baru = null
	if pilihan_peta == "pantai":
		scene_peta_baru = load("res://PetaPantai.tscn").instantiate()
		scene_peta_baru.name = "PetaPantai"
		mode_rolet_double = true # <--- PENANDA ROLET DOUBLE
		rolet.is_double = true   # <--- MENGUBAH FISIK ROLET 2D
		
		# =======================================================
		# PERUBAHAN BGM LINGKUNGAN PANTAI
		# =======================================================
		if pemutar_bgm:
			pemutar_bgm.stream = load("res://Moonlit_Cove.ogg") 
			pemutar_bgm.play()
	else:
		scene_peta_baru = load("res://PetaAlam.tscn").instantiate()
		scene_peta_baru.name = "PetaAlam"
		mode_rolet_double = false # <--- PENANDA ROLET STANDAR
		rolet.is_double = false   # <--- MENGUBAH FISIK ROLET 2D
		
		# Mengembalikan BGM alam jika user memilih peta alam
		if pemutar_bgm:
			pemutar_bgm.stream = load("res://Mellow Shore.ogg")
			pemutar_bgm.play()
	# Quick Match: dadu 2-12 di peta mana pun.
	if mode_quick:
		mode_rolet_double = true
		rolet.is_double = true

	get_parent().add_child(scene_peta_baru)
	
	rute_papan.clear()
	var papan = scene_peta_baru.get_node("PapanPermainan")
	for anak in papan.get_children():
		if anak.name.begins_with("Petak"):
			rute_papan.append(anak)
			
	# === SISTEM VALIDASI & PERAKITAN GRAPH JALUR ===
	var status_peta = ValidasiPeta.cek(self)
	if status_peta != "OK":
		ValidasiPeta.tampilkan_error(self, status_peta)
		return # HENTIKAN PROSES GAME, JANGAN MULAI
		
	# --- SISTEM ADAPTIF: HITUNG JUMLAH PERMATA DI PETA INI ---
	target_permata_menang = 0
	for petak in rute_papan:
		if petak.get("is_petak_permata"):
			target_permata_menang += 1
	# Quick Match: syarat permata separuh, dibulatkan ke atas (Grassland 1 -> 1,
	# Night Beach 2 -> 1).
	jumlah_permata_peta = target_permata_menang
	if mode_quick and target_permata_menang > 1:
		target_permata_menang = ceili(target_permata_menang / 2.0)
	if mode_quick:
		label_ronde = UiDinamis.buat_label_ronde(self)
		_perbarui_label_ronde()

	var min_x = 99999.0; var max_x = -99999.0
	var min_z = 99999.0; var max_z = -99999.0
	for petak in rute_papan:
		if petak.global_position.x < min_x: min_x = petak.global_position.x
		if petak.global_position.x > max_x: max_x = petak.global_position.x
		if petak.global_position.z < min_z: min_z = petak.global_position.z
		if petak.global_position.z > max_z: max_z = petak.global_position.z
	batas_kamera_min = Vector2(min_x - 15.0, min_z - 15.0)
	batas_kamera_max = Vector2(max_x + 15.0, max_z + 15.0)
	
	status_kepemilikan_petak.clear()
	pemilik_petak.clear()
	level_menara_petak.clear()
	nyawa_petak.clear()
	berhenti_di_petak_sendiri.clear()
	label_petak_3d.clear()
	
	var script_ui_petak = preload("res://ui_petak.gd")
	for i in range(rute_papan.size()):
		status_kepemilikan_petak.append(false)
		pemilik_petak.append(-1) 
		level_menara_petak.append(0) 
		nyawa_petak.append(0) 
		berhenti_di_petak_sendiri.append(0)
		
		var teks_menempel = script_ui_petak.new()
		rute_papan[i].add_child(teks_menempel)
		label_petak_3d.append(teks_menempel)
		
		# 1. Logika Petak Start
		if i == 0:
			teks_menempel.jadikan_petak_start()
			
		# 2. Logika Petak Cabang (TAMBAHAN BARU)
		# Jika ukuran array petak_selanjutnya lebih dari 1, berarti ini persimpangan
		if rute_papan[i].petak_selanjutnya.size() > 1:
			# Kirimkan array nama_arah dari Inspector ke fungsi UI
			teks_menempel.jadikan_petak_cabang(rute_papan[i].nama_arah)
			
	update_semua_label_petak()
	if jumlah_pemain() > 2:
		# 3-4 karakter di petak Start: sebar ke sudut-sudut petak supaya tidak menumpuk.
		atur_posisi_berbagi_petak()
	_mulai_transisi_game()
