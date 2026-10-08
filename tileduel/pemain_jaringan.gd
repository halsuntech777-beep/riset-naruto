@abstract
extends "res://pemain_duel.gd"
# ========================================================================
# PEMAIN_JARINGAN.GD
# MULTIPLAYER: susunan slot, siaran state, langkah client, pemain keluar, AI ambil alih, migrasi host
# pemain.gd dipecah BERTINGKAT (Fase 3): tiap file meneruskan (extends) file
# sebelumnya, jadi semuanya tetap SATU node Pemain -- variabel & fungsi dari file
# lain dipakai langsung seperti dulu. Urutan: pemain_dasar.gd -> pemain_tampilan.gd -> pemain_papan.gd -> pemain_kartu.gd -> pemain_duel.gd -> pemain_jaringan.gd -> pemain.gd
# @abstract = file ini bagian dari pemain.gd, tidak dipasang sendiri ke node.
# ========================================================================

var _permainan_selesai: bool = false    # panel pemenang sudah tampil
var _panel_putus_terbuka: bool = false  # panel "OPPONENT LEFT" sedang tampil
var _client_siap_mulai: bool = false   # host: SEMUA client sudah menekan START
var _klien_siap: Dictionary = {}        # host: peer_id client yang sudah menekan START
var _host_mulai_permainan: bool = false # client: host sudah memberi aba-aba

# Hasil akhir -- dipakai robot uji sekarang, XP di Fase 2.
var _alasan_akhir: String = "start"  # "start" | "ronde" | "ronde_koin"
var _slot_pemenang_akhir: int = -1
var _papan_skor_akhir: Array = []
var _akhir_diterima: bool = false    # client: kabar akhir dari host sudah tiba (lihat rpc_permainan_selesai)

# "cari" (mencari host baru) | "gabung" (menyambung) | "tergabung" (menunggu START NOW)
# | "host" (host baru) | "host_lama" (P1 menunggu pemain kembali) | "tamat" (tidak bisa gabung)
var _peran_migrasi: String = ""
var _slot_host_lama: int = -1       # host yang baru putus (tidak mungkin kembali sebagai client)
var _slot_host_migrasi: int = -1    # client: host baru yang sedang diikuti
var _panel_migrasi: CanvasLayer = null
var _nomor_gabung: int = 0          # client: penjaga batas waktu menyambung
var _status_migrasi_khusus: String = "" # teks status panel migrasi yang bukan bawaan

var _menunggu_pemain_kembali: bool = false # giliran berikutnya ditahan sampai START NOW
var _dijeda_di_awal_giliran: bool = false
signal pemain_kembali_selesai
var _putus_tertunda: Array = []     # host: slot yang putus, keputusannya ditunda 3 dtk
var _ip_sesi_host: String = ""      # host: IP device ini di jaringan permainan

signal cabang_client_dijawab(indeks)
var _jawaban_cabang_client: int = -1
var _slot_pemilih_cabang: int = -1 # host: slot yang sedang ditunggu memilih arah
var _cabang_tonton_terbuka: bool = false
var _pilihan_cabang_tertunda: int = -1

func _susun_slot_jaringan() -> void:
	# Isi daftar_pemain dari susunan lobby: StatusJaringan.jenis_slot ("manusia"/
	# "ai" per slot) dan peer_slot (peer_id -> slot). Kosong = jalur lama 1v1:
	# host slot 0, client pertama slot 1.
	var jenis: Array = StatusJaringan.jenis_slot.duplicate()
	var peer_slot: Dictionary = StatusJaringan.peer_slot.duplicate()
	if jenis.is_empty():
		jenis = ["manusia", "manusia"]
		peer_slot = {1: 0} # host selalu id 1 di ENet
		if StatusJaringan.peran_multiplayer == "host":
			var peers_terhubung = multiplayer.get_peers()
			if peers_terhubung.size() > 0:
				peer_slot[peers_terhubung[0]] = 1
			else:
				push_warning("Host: tidak ada peer terhubung saat panggung_utama.tscn dimuat.")
		else:
			peer_slot[multiplayer.get_unique_id()] = 1
	slot_lokal = int(peer_slot.get(multiplayer.get_unique_id(), 0))
	daftar_pemain.clear()
	for s in range(jenis.size()):
		var kontrol = DataPemain.JenisKontrol.MANUSIA_JARINGAN
		if jenis[s] == "ai":
			kontrol = DataPemain.JenisKontrol.AI
		elif s == slot_lokal:
			kontrol = DataPemain.JenisKontrol.MANUSIA_LOKAL
		daftar_pemain.append(DataPemain.new(kontrol, "P%d" % (s + 1)))
	for id in peer_slot:
		var s2 = int(peer_slot[id])
		if s2 >= 0 and s2 < daftar_pemain.size() and s2 != slot_lokal:
			daftar_pemain[s2].id_jaringan = int(id)

# --- Bagian B1: indikator debug jaringan, cuma aktif kalau datang dari LocalPlay.tscn ---
func _siapkan_indikator_jaringan():
	var peran = "HOST" if StatusJaringan.peran_multiplayer == "host" else "CLIENT"

	label_debug_jaringan = Label.new()
	label_debug_jaringan.add_theme_font_size_override("font_size", 18)
	label_debug_jaringan.add_theme_color_override("font_color", Color.WHITE)
	label_debug_jaringan.add_theme_color_override("font_outline_color", Color.BLACK)
	label_debug_jaringan.add_theme_constant_override("outline_size", 4)
	label_debug_jaringan.position = Vector2(16, 16)
	label_debug_jaringan.text = "[NET DEBUG] Aku: Slot %d (%s) | Role: %s | peer_id: %d" % [
		slot_lokal,
		DataPemain.JenisKontrol.keys()[daftar_pemain[slot_lokal].jenis_kontrol],
		peran,
		multiplayer.get_unique_id(),
	]
	$"../CanvasLayer".add_child(label_debug_jaringan)

	# Kedua sinyal disambungkan SEKALI untuk semua peran -- peran device ini bisa
	# berubah di tengah permainan (client -> host baru saat migrasi host).
	multiplayer.peer_disconnected.connect(_saat_peer_jaringan_disconnect)
	multiplayer.server_disconnected.connect(_saat_peer_jaringan_disconnect)
	multiplayer.connected_to_server.connect(_saat_tersambung_host_baru)
	multiplayer.connection_failed.connect(_saat_gagal_sambung_host_baru)
	migrasi = MigrasiHost.new()
	migrasi.name = "MigrasiHost"
	add_child(migrasi)
	migrasi.host_ditemukan.connect(_saat_host_baru_ditemukan)
	migrasi.harus_mengalah.connect(_saat_harus_mengalah)
	if StatusJaringan.peran_multiplayer == "host":
		_catat_ip_sesi_host()

func _saat_peer_jaringan_disconnect(id_peer: int = -1):
	var peran = StatusJaringan.peran_multiplayer
	if peran == "":
		return # sesi sudah ditinggalkan (lanjut sendiri melawan AI / keluar)
	if peran == "client" and id_peer != -1:
		return # di client peer_disconnected juga menyala untuk client LAIN -- abaikan
	if peran == "host" and id_peer == -1:
		return # host: server milik device ini sendiri yang ditutup
	if label_debug_jaringan:
		label_debug_jaringan.text += "  [DISCONNECTED]"
		label_debug_jaringan.add_theme_color_override("font_color", Color.RED)
	if _permainan_selesai or _akhir_diterima:
		return
	if _migrasi_berjalan or _mode_jaringan_putus:
		_saat_putus_selama_migrasi(id_peer)
		return
	if peran == "host":
		var slot = _slot_dari_peer(id_peer)
		if slot < 0:
			return
		if _peer_client_aktif().size() >= 2:
			# Masih ada device pemain lain -- tapi bisa jadi yang hilang justru jaringan
			# device INI (hotspot mati): client putus satu per satu. Keputusan ditunda
			# 3 dtk (lihat _putuskan_setelah_jeda).
			if not _putus_tertunda.has(slot):
				_putus_tertunda.append(slot)
			if _putus_tertunda.size() == 1:
				_putuskan_setelah_jeda()
			return
		# Pemain manusia terakhir yang keluar: jawab penantian yang masih menunggu
		# device itu, lalu tanya pemain di sini mau lanjut melawan AI atau keluar.
		_bebaskan_penantian_slot(slot)
	elif _perlu_migrasi_client():
		# Host keluar tapi masih ada pemain manusia lain: tawarkan host baru.
		# Ditandai SEKARANG (sinyal putus bisa datang dua kali), peer-nya diganti
		# setelah pemrosesan jaringan frame ini selesai.
		_slot_host_lama = _slot_dari_peer(1)
		_migrasi_berjalan = true
		_mulai_migrasi_client.call_deferred()
		return
	if _panel_putus_terbuka:
		return
	_panel_putus_terbuka = true
	# Lepaskan dulu semua penantian yang jawabannya harus datang dari device lawan,
	# kalau tidak permainan di device ini menggantung selamanya di balik panel.
	_bebaskan_penantian_jaringan()
	UiDinamis.tampilkan_panel_lawan_keluar(self)

func _bebaskan_penantian_jaringan() -> void:
	_client_siap_mulai = true
	_host_mulai_permainan = true
	if _jawaban_cabang_client < 0 and _slot_pemilih_cabang >= 0:
		# Host sedang menunggu client memilih arah di persimpangan.
		_jawaban_cabang_client = 0
		cabang_client_dijawab.emit(0)

func _bebaskan_penantian_slot(slot: int) -> void:
	# HOST: device pemilik slot ini putus. Setiap hal yang sedang menunggu
	# jawabannya dijawab otomatis supaya permainan tidak menggantung.
	var id_lama = daftar_pemain[slot].id_jaringan
	_klien_siap[id_lama] = true
	_periksa_kesiapan_klien()
	# Arah di persimpangan
	if _slot_pemilih_cabang == slot and _jawaban_cabang_client < 0:
		_jawaban_cabang_client = 0
		cabang_client_dijawab.emit(0)
	# Elemen duel
	if _duel_mengumpulkan and (slot == _duel_slot_penyerang or slot == _duel_slot_pembela) and not _pilihan_elemen_jaringan.has(slot):
		_kunci_elemen_peserta(slot, ui_elemen._pilih_elemen_adaptif("menyerang" if slot == _duel_slot_penyerang else "bertahan"))
	# Lempar koin penentu seri
	if _koin_seri_wajib.has(slot):
		if slot == _duel_slot_pembela and not _koin_seri_pilihan.has(slot):
			_terima_pilihan_koin(slot, "kepala" if randi() % 2 == 0 else "ekor")
		_koin_seri_wajib.erase(slot)
		_undi_koin_seri_jika_lengkap()
	# Kartu (gacha / buang) yang sedang dipilih device itu
	if _slot_aktor_kartu == slot and _kartu_menunggu_jaringan != "" and is_instance_valid(_sistem_kartu_aktif):
		var jenis = _kartu_menunggu_jaringan
		_kartu_menunggu_jaringan = ""
		if jenis == "gacha":
			var i = randi() % 3
			_rpc_ke_klien_kecuali([id_lama], "rpc_kartu_dibuka_host", [i])
			_sistem_kartu_aktif.buka_kartu_jaringan(i)
		else:
			_rpc_ke_klien_kecuali([id_lama], "rpc_kartu_dibuang_host", [0])
			_sistem_kartu_aktif.buang_kartu_jaringan(0)
	# Tawaran kartu pedang penyerang
	if _slot_penyerang_pedang == slot and _jawaban_pedang_client == -2:
		_rpc_ke_klien_kecuali([id_lama], "rpc_pedang_dipilih_host", [-1])
		_jawaban_pedang_client = -1
		pedang_client_dijawab.emit(-1)

func _ambil_alih_slot_ai(slot: int) -> void:
	# HOST: slot manusia jaringan yang device-nya putus dijalankan AI mulai
	# sekarang -- slot, warna, uang, petak, menara, jebakan & kartunya tetap.
	if slot < 0 or slot >= jumlah_pemain() or slot == slot_lokal:
		return
	daftar_pemain[slot].jenis_kontrol = DataPemain.JenisKontrol.AI
	_bebaskan_penantian_slot(slot)
	daftar_pemain[slot].id_jaringan = -1
	if migrasi != null:
		# Device slot ini yang mencari host tahu permainan lanjut tanpa dia.
		migrasi.anggota_mulai.erase(slot)
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_slot_jadi_ai", slot)
	if mode_jual_aset and slot_jual_aset == slot:
		# Sedang menunggu device itu memilih petak yang dijual karena hutang.
		_ai_jual_sampai_lunas(slot)
	elif _menunggu_aksi_slot == slot:
		# Menu gilirannya sedang menunggu klik dari device itu: AI yang melanjutkan.
		_menunggu_aksi_slot = -1
		_jalankan_ai_di_tengah_giliran(slot)

func _jalankan_ai_di_tengah_giliran(slot: int) -> void:
	# AI mengambil alih giliran yang sedang berjalan, sesuai fasenya.
	sedang_bergerak = false
	if fase_giliran == "awal":
		AiMusuh.logika_ai_fase_awal(self, slot)
	else:
		if fase_giliran == "konfrontasi" or fase_giliran == "duel_berlangsung":
			fase_giliran = "akhir"
		AiMusuh.logika_ai_musuh_setelah_jalan(self, slot)

@rpc("authority", "call_remote", "reliable")
func rpc_slot_jadi_ai(slot: int) -> void:
	# Diterima di CLIENT: device pemilik slot ini keluar, mulai sekarang AI di host
	# yang menjalankannya.
	if slot >= 0 and slot < jumlah_pemain() and slot != slot_lokal:
		daftar_pemain[slot].jenis_kontrol = DataPemain.JenisKontrol.AI
		daftar_pemain[slot].id_jaringan = -1

func lanjutkan_dengan_ai() -> void:
	# Tombol "CONTINUE VS AI" di panel OPPONENT LEFT: permainan diteruskan offline
	# dengan seluruh aset, petak, dan menara yang sudah ada. Pemain di device ini
	# TETAP di slot & warnanya sendiri; pemain yang keluar dijalankan AI.
	_panel_putus_terbuka = false
	if StatusJaringan.peran_multiplayer == "client":
		await _ambil_alih_sebagai_client()
		return
	var slot_keluar = []
	for s in range(jumlah_pemain()):
		if daftar_pemain[s].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN:
			slot_keluar.append(s)
	StatusJaringan.keluar_dari_sesi()
	# Slot yang ditinggalkan langsung berpindah ke AI -- warna, petak, menara,
	# jebakan & kartunya tetap milik slot itu (tidak ada tukar slot lagi).
	for s in slot_keluar:
		daftar_pemain[s].jenis_kontrol = DataPemain.JenisKontrol.AI
		daftar_pemain[s].id_jaringan = -1
	daftar_pemain[slot_lokal].jenis_kontrol = DataPemain.JenisKontrol.MANUSIA_LOKAL
	if is_instance_valid(panel_ui_cabang):
		panel_ui_cabang.hide()
	teks_dadu.show()
	teks_dadu.text = "Opponent left. AI takes over!"
	update_ui_status()
	update_semua_label_petak()

	await get_tree().create_timer(1.2).timeout
	for s in slot_keluar:
		_ambil_alih_slot_ai(s)

func _ambil_alih_sebagai_client() -> void:
	# Host keluar: device ini meneruskan permainannya sendiri. Slot, warna,
	# petak & jebakan pemain di sini TIDAK berubah; semua slot lain dijalankan AI.
	_generasi_jaringan += 1
	StatusJaringan.keluar_dari_sesi()
	for s in range(jumlah_pemain()):
		if s != slot_lokal:
			daftar_pemain[s].jenis_kontrol = DataPemain.JenisKontrol.AI
			daftar_pemain[s].id_jaringan = -1
	daftar_pemain[slot_lokal].jenis_kontrol = DataPemain.JenisKontrol.MANUSIA_LOKAL
	daftar_pemain[slot_lokal].id_jaringan = -1
	teks_dadu.show()
	teks_dadu.text = "Opponent left. AI takes over!"
	_tutup_ui_jaringan_client()

	# Animasi yang masih diputar ulang di layar ini diselesaikan dulu.
	await _selesaikan_replay_lokal()
	await get_tree().create_timer(1.2).timeout
	_lanjutkan_dari_state_terakhir()

func _selesaikan_replay_lokal() -> void:
	# CLIENT: tunggu animasi yang masih diputar ulang di layar ini selesai (paling
	# lama 20 dtk) sebelum device ini menjalankan logika permainan sendiri.
	var batas = 0.0
	while (_sedang_proses_langkah or _replay_duel_berjalan or _replay_jebakan_air_berjalan or _replay_paralisis_berjalan or _replay_serangan_berjalan) and batas < 20.0:
		await get_tree().process_frame
		batas += get_process_delta_time()
	_antrian_langkah_client.clear()

func _lanjutkan_dari_state_terakhir() -> void:
	# Device yang tadinya CLIENT mulai menjalankan logika permainan dari keadaan
	# terakhir yang diterima dari host (lanjut sendiri, atau host baru migrasi).
	sedang_bergerak = false
	teks_uang.show()
	teks_bintang.show()
	teks_dadu.show()
	ui_elemen.hide()
	atur_posisi_berbagi_petak()
	update_ui_status()
	update_semua_label_petak()
	var slot_giliran = _slot_dari_aktor(giliran_sekarang)
	target_kamera = _model(slot_giliran)
	if mode_jual_aset:
		if slot_jual_aset == slot_lokal:
			# Pemain di sini sedang memilih petak yang dijual -- tinggal ketuk.
			mode_membidik = true
			teks_dadu.text = "TAP YOUR TILE TO SELL (30% Discount)"
		else:
			# Juga pemain jaringan yang sedang menjual (kasus langka setelah migrasi).
			_siarkan_state_ai(slot_jual_aset)
			_ai_jual_sampai_lunas(slot_jual_aset)
		return
	if fase_giliran == "konfrontasi" or fase_giliran == "duel_berlangsung":
		fase_giliran = "akhir"
	if slot_giliran == slot_lokal or daftar_pemain[slot_giliran].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN:
		# Host baru migrasi: periksa_status_petak sekaligus menyiarkan state, dan
		# menampilkan menu di device pemilik giliran.
		periksa_status_petak(slot_giliran)
	else:
		_siarkan_state_ai(slot_giliran) # host baru: papan client disamakan dulu
		_jalankan_ai_di_tengah_giliran(slot_giliran)

func _tutup_ui_jaringan_client() -> void:
	# Layar-layar "tonton" yang menunggu kabar dari host ditutup dengan jawaban
	# bawaan, supaya tidak menutupi papan selamanya.
	menu_aksi.hide()
	mode_membidik = false
	if is_instance_valid(panel_ui_cabang):
		panel_ui_cabang.hide()
	_cabang_tonton_terbuka = false
	_pilihan_cabang_tertunda = -1
	if is_instance_valid(_sistem_kartu_aktif) and is_instance_valid(_sistem_kartu_aktif.kanvas_ui):
		_sistem_kartu_aktif.buka_kartu_jaringan(0)
		_sistem_kartu_aktif.buang_kartu_jaringan(0)
	if is_instance_valid(_ui_pedang_tonton_aktif):
		_ui_pedang_tonton_aktif.pedang_jaringan(-1)
	# Lempar koin penentu seri yang sedang menunggu pilihan/hasil dari host.
	if ui_elemen.has_method("terima_hasil_koin"):
		var sisi = "kepala" if randi() % 2 == 0 else "ekor"
		ui_elemen.terima_pilihan_koin_lawan(sisi)
		ui_elemen.terima_hasil_koin(sisi)
	if not _replay_duel_berjalan:
		ui_elemen.hide()
		# Musik duel (dimulai rpc_duel_dimulai/rpc_minta_pilihan_elemen_duel sejak
		# awal fase pilih elemen) belum tentu sempat kembali normal lewat
		# rpc_mulai_replay_duel kalau host keluar sebelum replay duel dimulai.
		if pemutar_bgm_duel and pemutar_bgm_duel.playing:
			AudioGrafis.kembali_ke_musik_normal(self)

func _periksa_kesiapan_klien() -> void:
	# HOST: panel HOW TO WIN baru ditutup setelah SEMUA client menekan START.
	for id in _peer_client_aktif():
		if not _klien_siap.has(id):
			return
	_client_siap_mulai = true

# ========================================================
# MIGRASI HOST (3-4 pemain): host putus -> pemain lain lanjut BERSAMA.
# - CLIENT yang kehilangan host, kalau masih ada pemain manusia di device lain:
#   panel HOST LEFT, device ini otomatis mencari host baru. Satu pemain menyalakan
#   hotspot lalu menekan BECOME HOST; yang lain menyambung sendiri. Host baru
#   menekan START NOW -> permainan lanjut dari keadaan terakhir, slot yang tidak
#   kembali dijalankan AI (AI selalu dijalankan host).
# - HOST yang jaringannya sendiri hilang (hotspot mati tidak sengaja): panel
#   CONNECTION LOST, giliran berikutnya ditahan. WAIT FOR PLAYERS -> pemain yang
#   masih di panel HOST LEFT menyambung kembali ke host ini.
# UDP & peer ENet-nya diurus migrasi_host.gd.
# ========================================================
func _catat_ip_sesi_host() -> void:
	# HOST: alamat device ini di jaringan permainan. Kalau alamat ini hilang dari
	# IP.get_local_addresses(), berarti hotspot/WiFi device ini sendiri yang mati.
	_ip_sesi_host = ""
	var peer = multiplayer.multiplayer_peer
	if not peer is ENetMultiplayerPeer:
		return
	for id in multiplayer.get_peers():
		var pp = peer.get_peer(id)
		if pp == null:
			continue
		var ip_ku = MigrasiHost.ip_ku_yang_sejaringan(pp.get_remote_address())
		if ip_ku != "":
			_ip_sesi_host = ip_ku
			return

func _putuskan_setelah_jeda() -> void:
	# HOST: satu pemain putus sementara pemain lain masih ada. Setelah 3 dtk:
	# alamat jaringan device ini hilang / semua pemain lain ikut putus -> jaringan
	# device INI yang mati (CONNECTION LOST, pemain ditunggu kembali). Selain itu
	# memang pemain itu yang keluar -> AI mengambil alih slotnya (alur lama).
	# Quick Match: 3 dtk NYATA (jam permainan dipercepat 1,5x); Classic tidak berubah.
	await get_tree().create_timer(3.0, true, false, mode_quick).timeout
	var daftar = _putus_tertunda.duplicate()
	_putus_tertunda.clear()
	if _permainan_selesai or StatusJaringan.peran_multiplayer != "host" or _migrasi_berjalan or _mode_jaringan_putus:
		return
	var masih = multiplayer.get_peers()
	var ada_yang_tersambung = false
	for s in range(jumlah_pemain()):
		var d = daftar_pemain[s]
		if not daftar.has(s) and d.jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN and masih.has(d.id_jaringan):
			ada_yang_tersambung = true
	var ip_hilang = _ip_sesi_host != "" and not IP.get_local_addresses().has(_ip_sesi_host)
	if uji_paksa_jaringan_putus or ip_hilang or not ada_yang_tersambung:
		_masuk_mode_jaringan_putus()
		return
	for s in daftar:
		if daftar_pemain[s].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN:
			# Masih ada device pemain lain: permainan mereka jalan terus. AI mengambil
			# alih slot yang keluar, lengkap dengan semua aset & petaknya.
			_ambil_alih_slot_ai(s)
			_umumkan("keluar", s)

func _masuk_mode_jaringan_putus() -> void:
	# HOST: slot manusia jaringan TIDAK diambil AI -- mereka ditunggu kembali.
	# Giliran yang sedang berjalan boleh tuntas; giliran berikutnya ditahan di
	# awal _mulai_giliran sampai START NOW / PLAY ALONE VS AI.
	_mode_jaringan_putus = true
	_menunggu_pemain_kembali = true
	_migrasi_berjalan = false
	_peran_migrasi = ""
	_slot_host_lama = -1
	for s in range(jumlah_pemain()):
		if s != slot_lokal and daftar_pemain[s].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN:
			_bebaskan_penantian_slot(s)
			daftar_pemain[s].id_jaringan = -1
	StatusJaringan.peer_slot = {1: slot_lokal}
	migrasi.berhenti()
	migrasi.tutup_peer()
	_jawab_penantian_selama_putus()
	_buka_panel_migrasi()

func _jawab_penantian_selama_putus() -> void:
	# Selama pemain ditunggu kembali, logika di sini bisa saja masih menunggu jawaban
	# dari device mereka (arah persimpangan, elemen duel, koin, kartu, pedang) --
	# dijawab otomatis supaya aksi yang sedang berjalan tetap tuntas.
	while _mode_jaringan_putus and not _permainan_selesai:
		for s in range(jumlah_pemain()):
			if s != slot_lokal and daftar_pemain[s].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN:
				_bebaskan_penantian_slot(s)
		await get_tree().create_timer(0.5).timeout

func _perlu_migrasi_client() -> bool:
	# CLIENT, host putus: migrasi hanya kalau masih ada pemain manusia di device
	# LAIN (bukan host yang putus, bukan AI). Kalau tidak -> alur lama (lanjut sendiri).
	var slot_host = _slot_dari_peer(1)
	for s in range(jumlah_pemain()):
		if s != slot_lokal and s != slot_host and daftar_pemain[s].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN:
			return true
	return false

func _mulai_migrasi_client() -> void:
	_peran_migrasi = "cari"
	_slot_host_migrasi = -1
	_generasi_jaringan += 1
	_bebaskan_penantian_jaringan()
	_tutup_ui_jaringan_client()
	# Semua slot manusia jaringan kini MENUNGGU (id -1). Keputusan akhir AI/manusia
	# tiap slot datang dari host saat START NOW (rpc_lanjut_setelah_migrasi) -- host
	# lama pun tetap manusia dulu: bisa saja P1 sendiri yang kembali jadi host.
	for s in range(jumlah_pemain()):
		if s != slot_lokal and daftar_pemain[s].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN:
			daftar_pemain[s].id_jaringan = -1
	StatusJaringan.peer_slot = {}
	migrasi.tutup_peer()
	teks_dadu.show()
	if _slot_host_lama >= 0:
		teks_dadu.text = _nama_slot(_slot_host_lama) + " (host) left the game."
	_buka_panel_migrasi()
	migrasi.mulai_cari(StatusJaringan.id_sesi, slot_lokal)

func _saat_putus_selama_migrasi(id_peer: int) -> void:
	if StatusJaringan.peran_multiplayer == "host":
		# Pemain yang sudah kembali putus lagi sebelum START NOW: ditunggu lagi.
		var slot = _slot_dari_peer(id_peer)
		if slot >= 0:
			daftar_pemain[slot].id_jaringan = -1
			StatusJaringan.peer_slot.erase(id_peer)
			_segarkan_panel_migrasi()
		return
	# CLIENT: host baru yang sedang diikuti hilang sebelum START NOW -> cari lagi.
	if _peran_migrasi == "gabung" or _peran_migrasi == "tergabung":
		_kembali_mencari.call_deferred()

func _kembali_mencari() -> void:
	if not _migrasi_berjalan:
		return
	_peran_migrasi = "cari"
	_slot_host_migrasi = -1
	_status_migrasi_khusus = ""
	_nomor_gabung += 1
	for s in range(jumlah_pemain()):
		if s != slot_lokal and daftar_pemain[s].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN:
			daftar_pemain[s].id_jaringan = -1
	migrasi.tutup_peer()
	StatusJaringan.peran_multiplayer = "client"
	StatusJaringan.peer_slot = {}
	migrasi.mulai_cari(StatusJaringan.id_sesi, slot_lokal)
	_segarkan_panel_migrasi()

func _saat_host_baru_ditemukan(ip: String, port: int, slot_host: int, anggota: Array) -> void:
	if not _migrasi_berjalan or _peran_migrasi != "cari":
		return
	if not anggota.is_empty():
		if anggota.has(slot_lokal):
			return # host itu belum sadar device ini putus -- nanti ia menunggu kita lagi
		# Host itu sudah melanjutkan permainan tanpa device ini.
		_peran_migrasi = "tamat"
		migrasi.berhenti()
		_segarkan_panel_migrasi("%s already continued the game without this phone." % _nama_slot(slot_host))
		return
	_peran_migrasi = "gabung"
	_slot_host_migrasi = slot_host
	_status_migrasi_khusus = ""
	migrasi.berhenti()
	_segarkan_panel_migrasi()
	if not migrasi.sambung_ke(ip, port):
		_kembali_mencari()
		return
	# Tidak diterima dalam 6 dtk (host lain, jaringan macet) -> cari lagi.
	_nomor_gabung += 1
	var nomor = _nomor_gabung
	await get_tree().create_timer(6.0).timeout
	if _peran_migrasi == "gabung" and nomor == _nomor_gabung:
		_kembali_mencari()

func _saat_tersambung_host_baru() -> void:
	if _migrasi_berjalan and _peran_migrasi == "gabung":
		rpc_id(1, "rpc_minta_gabung_ulang", StatusJaringan.id_sesi, slot_lokal)

func _saat_gagal_sambung_host_baru() -> void:
	if _migrasi_berjalan and _peran_migrasi == "gabung":
		_kembali_mencari.call_deferred()

@rpc("any_peer", "call_remote", "reliable")
func rpc_minta_gabung_ulang(id_sesi: int, slot: int) -> void:
	# Diterima di HOST BARU (atau P1 yang menunggu pemain kembali).
	if not multiplayer.is_server():
		return
	var pengirim = multiplayer.get_remote_sender_id()
	var sah = _migrasi_berjalan and (_peran_migrasi == "host" or _peran_migrasi == "host_lama") \
		and id_sesi == StatusJaringan.id_sesi and slot >= 0 and slot < jumlah_pemain() \
		and slot != slot_lokal and slot != _slot_host_lama \
		and daftar_pemain[slot].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN
	if not sah:
		rpc_id(pengirim, "rpc_gabung_ulang_ditolak")
		return
	var id_lama = daftar_pemain[slot].id_jaringan
	if id_lama > 1 and id_lama != pengirim and multiplayer.get_peers().has(id_lama):
		# Device yang sama menyambung ulang (WiFi-nya sempat putus) sebelum host
		# sempat mendeteksi koneksi lamanya hilang: koneksi lama diputus.
		StatusJaringan.peer_slot.erase(id_lama)
		multiplayer.multiplayer_peer.disconnect_peer(id_lama)
	daftar_pemain[slot].id_jaringan = pengirim
	StatusJaringan.peer_slot[pengirim] = slot
	rpc_id(pengirim, "rpc_gabung_ulang_diterima", slot_lokal)
	_segarkan_panel_migrasi()

@rpc("authority", "call_remote", "reliable")
func rpc_gabung_ulang_diterima(slot_host: int) -> void:
	if not _migrasi_berjalan or _peran_migrasi != "gabung":
		return
	_peran_migrasi = "tergabung"
	_slot_host_migrasi = slot_host
	if slot_host >= 0 and slot_host < jumlah_pemain():
		daftar_pemain[slot_host].id_jaringan = 1
	_segarkan_panel_migrasi()

@rpc("authority", "call_remote", "reliable")
func rpc_gabung_ulang_ditolak() -> void:
	if not _migrasi_berjalan or _peran_migrasi != "gabung":
		return
	_peran_migrasi = "tamat"
	_nomor_gabung += 1
	migrasi.berhenti()
	migrasi.tutup_peer.call_deferred()
	_segarkan_panel_migrasi("Could not join. Tap PLAY ALONE VS AI.")

func _saat_harus_mengalah(slot_pemenang: int, _anggota: Array) -> void:
	# Ada host lain untuk permainan yang sama (lihat aturan di migrasi_host.gd).
	if _peran_migrasi == "host":
		# Host baru yang belum START NOW: mengalah, lalu ikut host yang menang.
		_kembali_mencari()
	elif _peran_migrasi == "host_lama":
		# P1: logika permainan di sini masih berjalan -- tidak boleh berubah jadi
		# client di tengah jalan (risiko langkah dobel). Tinggal lanjut sendiri/keluar.
		_peran_migrasi = "tamat"
		migrasi.berhenti()
		migrasi.tutup_peer()
		_segarkan_panel_migrasi("%s is already the new host. This phone can't join now." % _nama_slot(slot_pemenang))

func _reset_penantian_host() -> void:
	# Host baru: penantian yang tercatat saat device ini masih client tidak berlaku.
	_klien_siap.clear()
	_client_siap_mulai = true
	_koin_seri_pilihan.clear()
	_koin_seri_wajib.clear()
	_pilihan_elemen_jaringan.clear()
	_duel_mengumpulkan = false
	_menunggu_aksi_slot = -1
	_slot_pemilih_cabang = -1
	_jawaban_cabang_client = -1
	_kartu_menunggu_jaringan = ""
	_slot_aktor_kartu = -1
	_slot_penyerang_pedang = -1
	_jawaban_pedang_client = -2

# --- tombol panel migrasi ---
func _tekan_tombol_utama_migrasi() -> void:
	if _mode_jaringan_putus and _peran_migrasi == "":
		tunggu_pemain_kembali()
	elif _peran_migrasi == "host" or _peran_migrasi == "host_lama":
		mulai_sekarang_migrasi()
	elif _peran_migrasi == "cari" or _peran_migrasi == "gabung":
		jadi_host_baru()

func jadi_host_baru() -> void:
	# BECOME HOST (client di panel HOST LEFT).
	if not _migrasi_berjalan or not (_peran_migrasi == "cari" or _peran_migrasi == "gabung"):
		return
	_nomor_gabung += 1 # batalkan batas waktu menyambung yang mungkin sedang berjalan
	if not migrasi.jadi_host(StatusJaringan.id_sesi, slot_lokal, false):
		_kembali_mencari()
		_segarkan_panel_migrasi("Could not start. Check your hotspot, then try again.")
		return
	StatusJaringan.peran_multiplayer = "host"
	StatusJaringan.peer_slot = {1: slot_lokal}
	_peran_migrasi = "host"
	_status_migrasi_khusus = ""
	for s in range(jumlah_pemain()):
		if s != slot_lokal and daftar_pemain[s].jenis_kontrol == DataPemain.JenisKontrol.MANUSIA_JARINGAN:
			daftar_pemain[s].id_jaringan = -1
	_reset_penantian_host()
	_segarkan_panel_migrasi()

func tunggu_pemain_kembali() -> void:
	# WAIT FOR PLAYERS (P1, setelah hotspot/WiFi-nya menyala lagi).
	if not _mode_jaringan_putus or _migrasi_berjalan:
		return
	if not migrasi.jadi_host(StatusJaringan.id_sesi, slot_lokal, true):
		_segarkan_panel_migrasi("Could not start. Check your hotspot, then try again.")
		return
	_migrasi_berjalan = true
	_peran_migrasi = "host_lama"
	_status_migrasi_khusus = ""
	_segarkan_panel_migrasi()

func mulai_sekarang_migrasi() -> void:
	# START NOW: permainan lanjut dari keadaan terakhir; slot manusia yang belum
	# kembali dijalankan AI mulai sekarang.
	if not _migrasi_berjalan or not (_peran_migrasi == "host" or _peran_migrasi == "host_lama"):
		return
	var host_lama = _peran_migrasi == "host_lama"
	var peer = multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.refuse_new_connections = true
	var tersambung = multiplayer.get_peers()
	var peer_slot_baru = {1: slot_lokal}
	var jadi_ai = []
	for s in range(jumlah_pemain()):
		var d = daftar_pemain[s]
		if s == slot_lokal or d.jenis_kontrol != DataPemain.JenisKontrol.MANUSIA_JARINGAN:
			continue
		if tersambung.has(d.id_jaringan):
			peer_slot_baru[d.id_jaringan] = s
		else:
			jadi_ai.append(s)
	var kontrol = []
	var anggota = []
	for s in range(jumlah_pemain()):
		var ai = daftar_pemain[s].jenis_kontrol == DataPemain.JenisKontrol.AI or jadi_ai.has(s)
		kontrol.append("ai" if ai else "manusia")
		if not ai:
			anggota.append(s)
	StatusJaringan.peer_slot = peer_slot_baru
	migrasi.tandai_mulai(anggota)
	_migrasi_berjalan = false
	_peran_migrasi = ""
	_slot_host_lama = -1
	_tutup_panel_migrasi()
	rpc("rpc_lanjut_setelah_migrasi", peer_slot_baru, kontrol, jadi_ai)
	if _permainan_selesai:
		# Permainan sempat berakhir selama CONNECTION LOST (mis. menang di START):
		# pemain yang kembali langsung diberi layar akhir yang sama. Posisi -1 =
		# tidak ada langkah yang perlu ditunggu.
		_mode_jaringan_putus = false
		_menunggu_pemain_kembali = false
		_catat_ip_sesi_host()
		rpc("rpc_permainan_selesai", _slot_pemenang_akhir, -1, _papan_skor_akhir, _alasan_akhir)
		return
	teks_dadu.show()
	teks_dadu.text = _teks_setelah_migrasi(jadi_ai)
	_catat_ip_sesi_host()
	if host_lama:
		_lanjutkan_setelah_pemain_kembali(jadi_ai)
		return
	for s in jadi_ai:
		daftar_pemain[s].jenis_kontrol = DataPemain.JenisKontrol.AI
		daftar_pemain[s].id_jaringan = -1
	_reset_penantian_host()
	await _selesaikan_replay_lokal()
	await get_tree().create_timer(1.2).timeout
	if not _permainan_selesai:
		_lanjutkan_dari_state_terakhir()

func _lanjutkan_setelah_pemain_kembali(jadi_ai: Array) -> void:
	# P1 (jaringannya sempat hilang): logika permainan di sini TIDAK pernah
	# berhenti, jadi giliran jangan dijalankan ulang -- cukup lepaskan jeda dan
	# kirim ulang menu yang sedang ditunggu.
	_mode_jaringan_putus = false
	var dijeda = _dijeda_di_awal_giliran
	_menunggu_pemain_kembali = false
	for s in jadi_ai:
		_ambil_alih_slot_ai(s)
	if dijeda:
		pemain_kembali_selesai.emit() # _mulai_giliran lanjut & menyiarkan state sendiri
		return
	var slot_jual = slot_jual_aset
	if mode_jual_aset and slot_jual != slot_lokal and _peer_slot(slot_jual) > 1:
		_siarkan_state_giliran(slot_giliran_ui)
		rpc_id(_peer_slot(slot_jual), "rpc_minta_jual_aset", slot_jual)
	elif _menunggu_aksi_slot >= 0 and _peer_slot(_menunggu_aksi_slot) > 1:
		periksa_status_petak(_menunggu_aksi_slot) # menu dikirim ulang ke device yang kembali
	elif slot_giliran_ui == slot_lokal and menu_aksi.visible:
		periksa_status_petak(slot_lokal)
	# Selain itu logika sedang berjalan (mis. AI menuntaskan aksinya): siaran
	# state berikutnya menyusul dengan sendirinya.

func _teks_setelah_migrasi(jadi_ai: Array) -> String:
	if jadi_ai.is_empty():
		return "Everyone is back! The game continues."
	var nama = PackedStringArray()
	for s in jadi_ai:
		nama.append(_nama_slot(int(s)))
	return " & ".join(nama) + " left. AI takes over!"

@rpc("authority", "call_remote", "reliable")
func rpc_lanjut_setelah_migrasi(peer_slot: Dictionary, kontrol: Array, jadi_ai: Array) -> void:
	# Diterima di CLIENT yang sudah menyambung kembali: host menekan START NOW.
	if not _migrasi_berjalan or _peran_migrasi != "tergabung":
		return
	var peer_dari_slot = {}
	for id in peer_slot:
		peer_dari_slot[int(peer_slot[id])] = int(id)
	for s in range(mini(jumlah_pemain(), kontrol.size())):
		var d = daftar_pemain[s]
		if s == slot_lokal:
			d.jenis_kontrol = DataPemain.JenisKontrol.MANUSIA_LOKAL
			d.id_jaringan = -1
		elif kontrol[s] == "ai":
			d.jenis_kontrol = DataPemain.JenisKontrol.AI
			d.id_jaringan = -1
		else:
			d.jenis_kontrol = DataPemain.JenisKontrol.MANUSIA_JARINGAN
			d.id_jaringan = peer_dari_slot.get(s, -1)
	StatusJaringan.peer_slot = peer_slot
	StatusJaringan.peran_multiplayer = "client"
	_migrasi_berjalan = false
	_peran_migrasi = ""
	_slot_host_lama = -1
	migrasi.berhenti()
	_tutup_panel_migrasi()
	teks_dadu.show()
	teks_dadu.text = _teks_setelah_migrasi(jadi_ai)
	update_ui_status()

func lanjut_sendiri_dari_migrasi() -> void:
	# PLAY ALONE VS AI di panel migrasi mana pun.
	_tutup_panel_migrasi()
	migrasi.berhenti()
	_migrasi_berjalan = false
	_peran_migrasi = ""
	_nomor_gabung += 1
	if _mode_jaringan_putus:
		# P1: logika di sini masih berjalan -- semua pemain jaringan jadi AI (sama
		# seperti CONTINUE VS AI), lalu jeda giliran dilepas.
		_mode_jaringan_putus = false
		_menunggu_pemain_kembali = false
		var dijeda = _dijeda_di_awal_giliran
		lanjutkan_dengan_ai()
		if dijeda:
			pemain_kembali_selesai.emit()
		return
	await _ambil_alih_sebagai_client()

# --- panel migrasi (tampilannya di ui_dinamis.gd) ---
func _buka_panel_migrasi() -> void:
	if not is_instance_valid(_panel_migrasi):
		_panel_migrasi = UiDinamis.buat_panel_migrasi(self)
	_status_migrasi_khusus = ""
	_segarkan_panel_migrasi()

func _tutup_panel_migrasi() -> void:
	if is_instance_valid(_panel_migrasi):
		_panel_migrasi.queue_free()
	_panel_migrasi = null
	_status_migrasi_khusus = ""

func _segarkan_panel_migrasi(pesan: String = "") -> void:
	if pesan != "":
		_status_migrasi_khusus = pesan
	if not is_instance_valid(_panel_migrasi):
		return
	var k = {"status": _status_migrasi_khusus}
	var nama_host = _nama_slot(_slot_host_migrasi) if _slot_host_migrasi >= 0 else "the host"
	if _peran_migrasi == "host" or _peran_migrasi == "host_lama":
		k["judul"] = "YOU ARE THE NEW HOST" if _peran_migrasi == "host" else "WAITING FOR PLAYERS"
		k["ket"] = "Keep your hotspot on. Players back:"
		var bagian = PackedStringArray()
		for s in range(jumlah_pemain()):
			var d = daftar_pemain[s]
			if s == slot_lokal or s == _slot_host_lama or d.jenis_kontrol != DataPemain.JenisKontrol.MANUSIA_JARINGAN:
				continue
			if multiplayer.get_peers().has(d.id_jaringan):
				bagian.append("[color=#55ee77]%s OK[/color]" % _nama_slot(s))
			else:
				bagian.append("[color=#8a8a8a]%s ...[/color]" % _nama_slot(s))
		k["daftar"] = "[center]" + "     ".join(bagian) + "[/center]"
		k["tombol_utama"] = "START NOW"
		k["catatan"] = "Players not back will be played by AI."
	elif _mode_jaringan_putus:
		k["judul"] = "CONNECTION LOST"
		if _peran_migrasi == "":
			k["ket"] = "The other players are no longer connected.\nIf your hotspot or WiFi turned off, turn it on again,\nthen tap WAIT FOR PLAYERS."
			k["tombol_utama"] = "WAIT FOR PLAYERS"
	else:
		k["judul"] = "HOST LEFT"
		k["ket"] = "To keep playing together:\n1. One player turns on a hotspot and taps BECOME HOST.\n2. Other players connect WiFi to that hotspot.\n    This screen joins by itself."
		match _peran_migrasi:
			"cari":
				k["tombol_utama"] = "BECOME HOST"
				if k["status"] == "": k["status"] = "Searching for the new host..."
			"gabung":
				k["tombol_utama"] = "BECOME HOST"
				if k["status"] == "": k["status"] = "Found %s! Joining..." % nama_host
			"tergabung":
				if k["status"] == "": k["status"] = "Joined! Waiting for %s to start..." % nama_host
	UiDinamis.atur_panel_migrasi(_panel_migrasi, k)

# ========================================================
# Bagian B2: LAPISAN JARINGAN — siklus giliran dasar
# Host tetap satu-satunya yang menjalankan logika (lempar_dadu, bergerak_maju,
# ganti_giliran TIDAK diubah sama sekali). Fungsi di bawah ini cuma jembatan:
# client MEMINTA, host MENJALANKAN, host MENYIARKAN hasilnya balik.
# ========================================================

func _siarkan_state_giliran(slot_index: int) -> void:
	# Kirim SELURUH state yang menentukan tampilan papan, bukan cuma angka pemain.
	# Dikemas jadi satu Dictionary supaya gampang ditambah field baru nanti tanpa
	# harus mengubah tanda tangan fungsi RPC-nya.
	var posisi = []; var uang = []; var bintang = []; var gelembung = []
	var paralisis = []; var bakar = []; var permata = []; var kontrol = []
	for s in range(jumlah_pemain()):
		var d = daftar_pemain[s]
		posisi.append(d.posisi_saat_ini); uang.append(d.uang); bintang.append(d.bintang)
		gelembung.append(d.sisa_gelembung); paralisis.append(d.sisa_paralisis); bakar.append(d.sisa_bakar)
		permata.append(koleksi_permata_slot[s].duplicate())
		kontrol.append("ai" if d.jenis_kontrol == DataPemain.JenisKontrol.AI else "manusia")
	var data = {
		"posisi": posisi,
		"uang": uang,
		"bintang": bintang,
		"gelembung": gelembung,
		"paralisis": paralisis,
		"bakar": bakar,
		# Slot yang sudah diambil alih AI (device-nya putus) ikut dikabarkan.
		"kontrol": kontrol,
		"fase_giliran": fase_giliran,
		"giliran_sekarang": giliran_sekarang,
		"status_kepemilikan": status_kepemilikan_petak,
		"pemilik": pemilik_petak,
		"level_menara": level_menara_petak,
		"nyawa": nyawa_petak,
		"jebakan": _kumpulkan_data_jebakan(),
		"koin": _kumpulkan_data_koin(),
		# Koleksi permata dulu tidak ikut sama sekali -- client selalu mengira
		# belum ada yang punya permata.
		"permata": permata,
		# Tanpa ini tombol Attack di client aktif lagi setelah menyerang (host
		# menolaknya, tapi tombolnya menipu).
		"sudah_serang": sudah_serang_giliran_ini,
		# Tanpa ini tombol "Build Tower" di client memakai angka miliknya sendiri
		# yang tidak pernah bertambah (langkah dijalankan di host).
		"berhenti_petak": berhenti_di_petak_sendiri.duplicate(),
		# Efek kartu dadu (LOW/HIGH ROLL) yang masih berjalan -- supaya tidak hilang
		# kalau host keluar dan client meneruskan permainan melawan AI.
		"tipe_dadu": tipe_dadu_slot.duplicate(),
		"durasi_dadu": sisa_durasi_dadu_slot.duplicate(),
		# Hitungan putaran & dendam AI -- tanpa ini device yang meneruskan permainan
		# (host baru migrasi, atau lanjut sendiri) memakai angka yang basi.
		"putaran": putaran_slot.duplicate(),
		"kemarahan": kemarahan_slot.duplicate(),
		"dendam": sasaran_dendam_slot.duplicate(),
		# Quick Match: ronde yang sedang berjalan (label ROUND x/y di semua HP).
		"ronde": ronde_sekarang,
		# Fase 2: statistik pertandingan per slot (host baru melanjutkan hitungannya).
		"statistik": statistik_slot.duplicate(true),
		# Fase 4 (bagian 7): role, jebakan dibawa, build per slot.
		"role": _kemas_role(),
	}
	# Kartu simpanan tiap slot. Tanpa ini client tidak pernah melihat kartunya
	# sendiri (tombol "Use Card" tidak muncul) dan kartunya hilang kalau host keluar.
	var kartu = []
	for s in range(jumlah_pemain()):
		kartu.append(daftar_pemain[s].inventaris_kartu.duplicate(true))
	data["kartu"] = kartu
	rpc("rpc_terima_state_giliran", slot_index, data)

@rpc("authority", "call_remote", "reliable")
func rpc_mainkan_rolet(hasil_dadu: int, tipe_dadu: String, aktor: String) -> void:
	# Diterima di CLIENT. Memutar animasi rolet yang sama dengan di host, lalu
	# menjalankan karakter langkah demi langkah. Ini MURNI TAMPILAN — tidak ada
	# logika permainan di sini; hasil sebenarnya tetap dihitung host dan dikoreksi
	# lewat siaran state di akhir giliran.
	var slot_pelempar = _slot_dari_aktor(aktor)

	# Sama seperti di host: begitu dadu dilempar, kamera kembali menyorot karakter
	# yang akan berjalan (lempar_dadu) dan geser dikunci selama bergerak
	# (bergerak_maju). Dibuka lagi oleh siaran state berikutnya.
	geser_kamera = Vector3.ZERO
	sedang_bergerak = true

	teks_uang.hide()
	teks_bintang.hide()
	teks_dadu.hide()

	await rolet.putar_rolet(hasil_dadu, tipe_dadu)

	teks_dadu.show()
	teks_dadu.text = _teks_hasil_dadu(slot_pelempar, hasil_dadu)

	await get_tree().create_timer(1.5).timeout
	rolet.hide()
	teks_uang.show()
	teks_bintang.show()

@rpc("authority", "call_remote", "reliable")
func rpc_langkah_client(index_petak: int, aktor: String) -> void:
	# Diterima di CLIENT, satu kali per langkah yang benar-benar dijalankan host.
	# Dimasukkan antrian supaya langkah-langkah diproses berurutan walau pesannya
	# datang lebih cepat daripada durasi animasinya.
	_antrian_langkah_client.append([index_petak, aktor])
	if not _sedang_proses_langkah:
		_proses_antrian_langkah()

func _proses_antrian_langkah() -> void:
	_sedang_proses_langkah = true
	while _antrian_langkah_client.size() > 0:
		var item = _antrian_langkah_client.pop_front()
		_langkah_diputar = item[0]
		await _langkah_satu_petak(item[0], item[1])
		_langkah_diputar = -1
	_sedang_proses_langkah = false

func _langkah_satu_petak(index_petak: int, aktor: String) -> void:
	# MURNI TAMPILAN — meniru satu langkah di host dengan durasi yang sama (0.8s).
	if index_petak < 0 or index_petak >= rute_papan.size():
		return
	var slot = _slot_dari_aktor(aktor)
	var target_node = _node_karakter(slot)
	var target_model = _model(slot)
	var target_anim = _anim(slot)
	var tujuan_node = rute_papan[index_petak]

	target_anim.play("run")
	var arah_pandang = tujuan_node.global_position
	arah_pandang.y = target_model.global_position.y
	target_model.look_at(arah_pandang, Vector3.UP)

	var tween = create_tween()
	tween.tween_property(target_node, "global_position", tujuan_node.global_position, 0.8)
	await tween.finished

	# Kembali ke idle hanya kalau tidak ada langkah lain menyusul — inilah yang
	# membuat gerakannya terasa "selangkah, berhenti sejenak" seperti di host.
	if _antrian_langkah_client.size() == 0:
		target_anim.play("idle")

func _selaraskan_efek_menempel() -> void:
	# Efek yang menempel di karakter (gelembung air, asap terbakar) dilepas oleh
	# ganti_giliran() — yang cuma berjalan di host. Di client efeknya jadi menempel
	# selamanya. Fungsi ini menyamakannya dengan angka status yang sudah disinkronkan:
	# angka habis berarti efeknya harus ikut hilang.
	for i in range(jumlah_pemain()):
		var model = _model(i)
		if daftar_pemain[i].sisa_gelembung <= 0:
			var g = model.get_node_or_null("EfekGelembung")
			if g: g.queue_free()
		if daftar_pemain[i].sisa_bakar <= 0:
			var b = model.get_node_or_null("EfekTerbakar")
			if b: b.queue_free()

func _bangun_ulang_menara_client() -> void:
	# Bangun menara fisik di petak yang levelnya > 0 tapi belum punya bentuk 3D-nya.
	for i in range(rute_papan.size()):
		if level_menara_petak[i] > 0 and not rute_papan[i].has_node("EmbossMenara"):
			var bahan = _material_slot(pemilik_petak[i])
			_bangun_fisik_menara(i, bahan, level_menara_petak[i])
		elif level_menara_petak[i] == 0 and rute_papan[i].has_node("EmbossMenara"):
			# Petak kembali netral (mis. hancur diserang) tapi menaranya masih ada
			# di layar ini -- dulu tidak pernah dibongkar di client.
			for anak in rute_papan[i].get_children():
				if anak.name.begins_with("Emboss"):
					anak.queue_free()

@rpc("authority", "call_remote", "reliable")
func rpc_terima_state_giliran(slot_index: int, data: Dictionary) -> void:
	# Diterima di CLIENT. Bukan menjalankan ulang logikanya — cuma menyamakan
	# seluruh tampilan papan dengan kondisi yang sudah final di host.
	# Lemparan jebakan air yang masih diputar di sini harus mendarat dulu (lihat
	# rpc_jebakan_air_aktif) -- di host pun siaran ini baru dikirim setelahnya.
	_versi_state += 1 # dihitung saat TIBA (urutan tiba = urutan kirim host)
	if _replay_jebakan_air_berjalan:
		await replay_jebakan_air_selesai
	if _replay_paralisis_berjalan:
		await replay_paralisis_selesai
	if _replay_serangan_berjalan:
		await replay_serangan_selesai
	for i in range(mini(jumlah_pemain(), data["posisi"].size())):
		daftar_pemain[i].posisi_saat_ini = data["posisi"][i]
		daftar_pemain[i].uang = data["uang"][i]
		daftar_pemain[i].bintang = data["bintang"][i]
		daftar_pemain[i].sisa_gelembung = data["gelembung"][i]
		daftar_pemain[i].sisa_paralisis = data["paralisis"][i]
		daftar_pemain[i].sisa_bakar = data["bakar"][i]
		# Slot manusia yang device-nya putus dan kini dijalankan AI di host.
		if data.has("kontrol") and i != slot_lokal and data["kontrol"][i] == "ai":
			daftar_pemain[i].jenis_kontrol = DataPemain.JenisKontrol.AI

	# fase_giliran WAJIB ikut disamakan — tanpa ini client salah mengira gilirannya
	# baru mulai lagi setelah beraksi, lalu menampilkan tombol dadu untuk kedua kali.
	fase_giliran = data["fase_giliran"]
	if giliran_sekarang != data["giliran_sekarang"]:
		geser_kamera = Vector3.ZERO # giliran berganti -- host melakukannya di ganti_giliran()
	giliran_sekarang = data["giliran_sekarang"]
	# Siaran state = gerakan di host sudah tuntas; boleh-tidaknya kamera digeser
	# selanjutnya ditentukan fase_giliran dari host (lihat _boleh_geser_kamera).
	sedang_bergerak = false
	sudah_serang_giliran_ini = data.get("sudah_serang", sudah_serang_giliran_ini)

	status_kepemilikan_petak = data["status_kepemilikan"]
	# pemilik_petak bertipe Array[int]. Array dari RPC datang tanpa tipe, jadi
	# tidak bisa ditugaskan langsung — assign() yang menyalin sekaligus mengonversi.
	pemilik_petak.assign(data["pemilik"])
	level_menara_petak = data["level_menara"]
	nyawa_petak = data["nyawa"]
	if data.has("berhenti_petak"):
		berhenti_di_petak_sendiri.assign(data["berhenti_petak"])
	if data.has("tipe_dadu"):
		for i in range(mini(MAKS_PEMAIN, data["tipe_dadu"].size())):
			tipe_dadu_slot[i] = data["tipe_dadu"][i]
			sisa_durasi_dadu_slot[i] = data["durasi_dadu"][i]
	if data.has("putaran"):
		for i in range(mini(MAKS_PEMAIN, data["putaran"].size())):
			putaran_slot[i] = data["putaran"][i]
			kemarahan_slot[i] = data["kemarahan"][i]
			sasaran_dendam_slot[i] = data["dendam"][i]
	if data.has("ronde"):
		# Quick Match -- spanduk FINAL ROUND muncul sendiri saat ronde terakhir mulai.
		ronde_sekarang = int(data["ronde"])
		_perbarui_label_ronde()
	if data.has("statistik"):
		statistik_slot = data["statistik"].duplicate(true)
	if data.has("role"):
		_terapkan_role(data["role"])
	if data.has("kartu"):
		for i in range(mini(jumlah_pemain(), data["kartu"].size())):
			daftar_pemain[i].inventaris_kartu.assign(data["kartu"][i])

	_terapkan_data_jebakan(data["jebakan"])
	_terapkan_data_koin(data.get("koin", []))
	if data.has("permata"):
		# Array[String] -- assign() yang menyalin sekaligus mengonversi tipenya.
		for i in range(mini(jumlah_pemain(), data["permata"].size())):
			koleksi_permata_slot[i].assign(data["permata"][i])
	_bangun_ulang_menara_client()
	_selaraskan_efek_menempel()

	# Buang sisa langkah yang belum sempat dianimasikan. Siaran state ini adalah
	# kebenaran terakhir dari host — kalau langkah basi dibiarkan jalan, karakter
	# akan bergerak lagi setelah posisinya dikoreksi.
	_antrian_langkah_client.clear()

	# Angka saja tidak cukup — model karakter 3D dan kamera tidak ikut bergerak
	# hanya karena posisi_saat_ini berubah. Fungsi ini yang benar-benar memindahkan
	# kedua model ke petaknya (sudah menangani kasus dua karakter di petak sama).
	atur_posisi_berbagi_petak()
	target_kamera = _model(slot_index)

	update_semua_label_petak()
	update_ui_status()
	if _migrasi_berjalan or StatusJaringan.peran_multiplayer != "client":
		# Host putus saat siaran ini masih menunggu replay selesai: keadaannya tetap
		# dipakai, tapi menu jangan dimunculkan di balik panel migrasi.
		return
	periksa_status_petak(slot_index)

func _sembunyikan_menu_giliran_lawan() -> void:
	# Dipanggil tertunda (call_deferred) supaya jalan SETELAH periksa_status_petak
	# selesai sepenuhnya — apapun jalur return yang diambil di dalamnya.
	if slot_giliran_ui == slot_lokal:
		# Basi: dua siaran state tiba di frame yang sama (akhir giliran lawan lalu
		# awal giliran device ini). Menu giliran sendiri jangan ikut disembunyikan --
		# dulu permainan macet di "Waiting for P2..." pada HP P2 sendiri.
		return
	menu_aksi.hide()
	if _is_ai(slot_giliran_ui):
		return # teks giliran AI (narasi dari host) jangan ditimpa
	teks_dadu.show()
	if jumlah_pemain() <= 2:
		teks_dadu.text = "Waiting for opponent..."
	else:
		teks_dadu.text = "Waiting for " + _nama_slot(slot_giliran_ui) + "..."

@rpc("any_peer", "call_remote", "reliable")
func rpc_minta_aksi(nama_aksi: String) -> void:
	# Diterima di HOST. Client mengirim niatnya, host yang benar-benar menjalankan.
	if not multiplayer.is_server() or _migrasi_berjalan or _mode_jaringan_putus:
		return
	var id_pengirim = multiplayer.get_remote_sender_id()
	if _peer_slot(slot_giliran_ui) != id_pengirim:
		return # bukan giliran pengirim ini — tolak

	_menunggu_aksi_slot = -1 # aksinya sudah datang, host tidak menunggu lagi
	_sedang_eksekusi_dari_rpc = true
	match nama_aksi:
		"tutup": _proses_tombol_tutup()
		"beli": _on_tombol_beli_pressed()
		"bangun": _on_tombol_bangun_pressed()
		"trap_air": _on_tombol_air_pressed()
		"trap_angin": _on_tombol_angin_pressed()
		"trap_api": _on_tombol_api_pressed()
		"trap_petir": _on_tombol_trap_petir_pressed()
		"trap_tanah": _on_tombol_trap_tanah_pressed()
	_sedang_eksekusi_dari_rpc = false

func _siarkan_state_ai(slot: int) -> void:
	# Giliran AI tidak pernah lewat periksa_status_petak (titik siaran state yang
	# biasa), jadi di multiplayer keadaan papannya dikirim dari sini: awal giliran
	# AI dan setiap kali AI mengubah papan (beli, bangun, dst).
	if StatusJaringan.peran_multiplayer == "host":
		_siarkan_state_giliran(slot)
