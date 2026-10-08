extends Control
## Layar "Local Play" — otomatis mendeteksi apakah ada pemain lain di jaringan
## yang sama (lewat hotspot/WiFi), lalu jadi Client kalau ketemu, atau jadi
## Host kalau tidak ketemu siapa-siapa dalam beberapa detik. Pemain tidak
## perlu tahu istilah "host"/"client"/"IP address" sama sekali.
##
## CATATAN PENTING: kalau di-export ke Android, pastikan izin "INTERNET"
## dicentang di Project > Export > preset Android > Options > Permissions.
## Kalau lupa, semua komunikasi jaringan diblokir diam-diam tanpa error jelas.

const PORT_DISKAVERI = 7778
const PORT_GAME = 7777
const PESAN_DISCOVER = "TILEDUEL_DISCOVER"
const PESAN_HOST_ADA = "TILEDUEL_HOST_HERE"
const BATAS_WAKTU_PENCARIAN = 2.0

@onready var label_status: Label = $LabelStatus
@onready var tombol_refresh: Button = $TombolRefresh

var udp_diskaveri: PacketPeerUDP
var mode_saat_ini: String = "" # "mencari", "host", "client", "lobby_client", "host_hilang", "terhubung"
var waktu_pencarian: float = 0.0

# Peer yang BENAR-BENAR kita buat sendiri. Tidak boleh mengandalkan
# multiplayer.multiplayer_peer untuk cek "ada koneksi atau tidak" — di Godot 4
# properti itu selalu terisi peer default walau belum pernah connect ke siapa pun.
var peer_jaringan: ENetMultiplayerPeer = null
# Cegah change_scene dipanggil dua kali (client menerima DUA sinyal sekaligus:
# connected_to_server DAN peer_connected).
var sudah_pindah_scene: bool = false
var waktu_broadcast_terakhir: float = 0.0
var waktu_siaran_host: float = 0.0

# --- LOBBY: host memilih mode & peta, menunggu pemain lain, lalu START ---
# "manusia" = host / pemain di device lain, "ai" = dijalankan AI di device host.
const MODE_LOBBY = [
	{"nama": "1 VS 1", "jenis": ["manusia", "manusia"]},
	{"nama": "2 PLAYERS + 1 AI", "jenis": ["manusia", "manusia", "ai"]},
	{"nama": "2 PLAYERS + 2 AI", "jenis": ["manusia", "manusia", "ai", "ai"]},
	{"nama": "3 PLAYERS", "jenis": ["manusia", "manusia", "manusia"]},
	{"nama": "3 PLAYERS + 1 AI", "jenis": ["manusia", "manusia", "manusia", "ai"]},
	{"nama": "4 PLAYERS", "jenis": ["manusia", "manusia", "manusia", "manusia"]},
]
const PETA_LOBBY = [["alam", "Grassland"], ["pantai", "Night Beach"]]
const MAKS_CLIENT = 3 # mode terbesar: 4 pemain manusia = host + 3 client

var panel_lobby: PanelContainer
var tombol_mode_lobby: Array = []
var tombol_peta_lobby: Array = []
var label_pemain_lobby: RichTextLabel
var label_info_lobby: Label
var tombol_mulai_lobby: Button
var indeks_mode_lobby: int = 0
var peta_lobby: String = "alam"
# Fase 4 (A6): role dipilih tiap pemain di lobby. role_peer: peer_id (host = 1)
# -> {"role": String, "jebakan": Array}. role_ai_lobby: indeks slot AI -> role,
# diundi HOST saat mode dipilih (K9) dengan pengacak MILIK LAYAR INI (bukan
# mesin_acak, yang belum ada sampai panggung_utama.tscn dimuat).
var role_peer: Dictionary = {}
var role_ai_lobby: Dictionary = {}
var tombol_role_saya: Button
var _rng_lobby := RandomNumberGenerator.new()
# QUICK MATCH / CLASSIC (Fase 1): dipilih host, pilihan terakhir diingat.
var quick_lobby: bool = true
var tombol_panjang_lobby: Array = []
const WARNA_QUICK := Color(0.85, 0.5, 0.1)
const WARNA_CLASSIC := Color(0.35, 0.35, 0.6)
# peer_id client sesuai urutan gabung (diisi host; client menerima salinannya).
# Client pertama = P2, kedua = P3, ketiga = P4.
var urutan_client: Array = []

func _ready() -> void:
	tombol_refresh.pressed.connect(_on_tombol_refresh_pressed)
	multiplayer.peer_connected.connect(_saat_pemain_lain_gabung)
	multiplayer.peer_disconnected.connect(_saat_pemain_keluar_lobby)
	multiplayer.connected_to_server.connect(_saat_berhasil_connect)
	multiplayer.connection_failed.connect(_saat_gagal_connect)
	multiplayer.server_disconnected.connect(_saat_host_keluar_lobby)

	_rng_lobby.randomize()
	quick_lobby = StatusJaringan.baca_pilihan_quick()
	_atur_tampilan_tombol_refresh()
	_buat_panel_lobby()
	mulai_pencarian()

func _atur_tampilan_tombol_refresh() -> void:
	# Diatur lewat kode (bukan di editor) supaya ukuran & posisinya pasti benar
	# di layar HP maupun laptop, tidak tertutup label lain.
	tombol_refresh.text = "TRY AGAIN"
	tombol_refresh.add_theme_font_size_override("font_size", 24)
	tombol_refresh.anchor_left = 0.5
	tombol_refresh.anchor_right = 0.5
	tombol_refresh.anchor_top = 1.0
	tombol_refresh.anchor_bottom = 1.0
	tombol_refresh.offset_left = -140
	tombol_refresh.offset_right = 140
	tombol_refresh.offset_top = -150
	tombol_refresh.offset_bottom = -80

	var gaya = StyleBoxFlat.new()
	gaya.bg_color = Color(0.15, 0.6, 0.55)
	gaya.corner_radius_top_left = 10
	gaya.corner_radius_top_right = 10
	gaya.corner_radius_bottom_right = 10
	gaya.corner_radius_bottom_left = 10
	gaya.border_width_bottom = 4
	gaya.border_color = gaya.bg_color.darkened(0.4)
	tombol_refresh.add_theme_stylebox_override("normal", gaya)

	var gaya_hover = gaya.duplicate()
	gaya_hover.bg_color = gaya.bg_color.lightened(0.2)
	tombol_refresh.add_theme_stylebox_override("hover", gaya_hover)

func _kumpulkan_alamat_siaran() -> Array:
	# Selain alamat broadcast umum (255.255.255.255), hitung juga alamat broadcast
	# khusus tiap jaringan yang sedang aktif (mis. 192.168.43.255 untuk hotspot HP).
	# Ini penting: di Android, siaran ke 255.255.255.255 sering salah jalur — dikirim
	# lewat data seluler, bukan lewat hotspot-nya sendiri.
	var daftar = ["255.255.255.255"]
	for ip in IP.get_local_addresses():
		if ip.count(".") != 3:
			continue # lewati alamat IPv6
		if ip.begins_with("127."):
			continue # lewati alamat lokal komputer sendiri
		var bagian = ip.split(".")
		var alamat_siaran = "%s.%s.%s.255" % [bagian[0], bagian[1], bagian[2]]
		if not daftar.has(alamat_siaran):
			daftar.append(alamat_siaran)
	return daftar

func _kirim_siaran(pesan: String) -> void:
	if udp_diskaveri == null:
		return
	for alamat in _kumpulkan_alamat_siaran():
		udp_diskaveri.set_dest_address(alamat, PORT_DISKAVERI)
		udp_diskaveri.put_packet(pesan.to_utf8_buffer())

func _alamat_lokal_sendiri() -> Array:
	var hasil = []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127."):
			hasil.append(ip)
	return hasil

func _ip_ke_angka(ip: String) -> int:
	# Ubah "192.168.43.7" jadi satu angka, supaya dua alamat bisa dibandingkan
	# besar-kecilnya secara pasti (dipakai untuk menentukan siapa yang mengalah).
	var bagian = ip.split(".")
	if bagian.size() != 4:
		return 0
	return int(bagian[0]) * 16777216 + int(bagian[1]) * 65536 + int(bagian[2]) * 256 + int(bagian[3])

func _ip_ku_yang_sejaringan(ip_lawan: String) -> String:
	# Cari alamat milik kita sendiri yang berada di jaringan yang sama dengan lawan
	# (3 angka pertamanya sama), supaya perbandingannya adil.
	var awalan = ip_lawan.rsplit(".", true, 1)[0]
	for ip in _alamat_lokal_sendiri():
		if ip.begins_with(awalan + "."):
			return ip
	return ""

func mulai_pencarian() -> void:
	# Bersihkan koneksi/pencarian lama dulu — penting supaya tombol refresh
	# tidak nabrak dengan koneksi sebelumnya yang mungkin masih menyala.
	_bersihkan_semua()

	mode_saat_ini = "mencari"
	_sembunyikan_lobby()
	label_status.text = "Searching for other player..."
	waktu_pencarian = 0.0
	waktu_broadcast_terakhir = 0.0
	waktu_siaran_host = 0.0
	sudah_pindah_scene = false

	udp_diskaveri = PacketPeerUDP.new()
	udp_diskaveri.set_broadcast_enabled(true)
	udp_diskaveri.bind(PORT_DISKAVERI)

	# Teriak ke seluruh jaringan lokal: "ada host di sini?"
	_kirim_siaran(PESAN_DISCOVER)

func _process(delta: float) -> void:
	if mode_saat_ini == "mencari":
		waktu_pencarian += delta

		# Ulangi broadcast berkala. UDP itu tidak dijamin sampai — kalau cuma
		# dikirim sekali di awal lalu hilang di jalan, pencarian gagal tanpa sebab jelas.
		waktu_broadcast_terakhir += delta
		if waktu_broadcast_terakhir >= 0.4:
			waktu_broadcast_terakhir = 0.0
			_kirim_siaran(PESAN_DISCOVER)

		if udp_diskaveri.get_available_packet_count() > 0:
			var data = udp_diskaveri.get_packet().get_string_from_utf8()
			var ip_pengirim = udp_diskaveri.get_packet_ip()
			if data == PESAN_HOST_ADA:
				_jadi_client(ip_pengirim)
				return

		if waktu_pencarian >= BATAS_WAKTU_PENCARIAN:
			# Tidak ada yang menyahut dalam 2 detik -> kita yang jadi host
			_jadi_host()

	elif mode_saat_ini == "host":
		# Umumkan keberadaan secara berkala, jangan cuma menunggu ditanya.
		# Alasannya: siaran dari HP Android sering tidak sampai ke perangkat lain
		# (salah jalur ke data seluler). Dengan host yang aktif mengumumkan diri,
		# koneksi tetap terjalin selama SALAH SATU arah siaran berhasil.
		waktu_siaran_host += delta
		if waktu_siaran_host >= 0.5:
			waktu_siaran_host = 0.0
			_kirim_siaran(PESAN_HOST_ADA)

		# Tetap balas juga kalau ada yang bertanya langsung
		if udp_diskaveri and udp_diskaveri.get_available_packet_count() > 0:
			var data = udp_diskaveri.get_packet().get_string_from_utf8()
			var ip_pengirim = udp_diskaveri.get_packet_ip()
			if data == PESAN_DISCOVER:
				udp_diskaveri.set_dest_address(ip_pengirim, PORT_DISKAVERI)
				udp_diskaveri.put_packet(PESAN_HOST_ADA.to_utf8_buffer())
			elif data == PESAN_HOST_ADA:
				# Ternyata ada host LAIN di jaringan yang sama — ini terjadi kalau
				# kedua pemain menekan Local Play hampir bersamaan. Diselesaikan
				# otomatis: yang alamatnya lebih besar mengalah jadi client.
				# Perbandingannya pasti sama di kedua sisi, jadi tidak mungkin
				# dua-duanya mengalah atau dua-duanya bertahan.
				if not _alamat_lokal_sendiri().has(ip_pengirim):
					var ip_ku = _ip_ku_yang_sejaringan(ip_pengirim)
					if ip_ku != "" and _ip_ke_angka(ip_ku) > _ip_ke_angka(ip_pengirim):
						_jadi_client(ip_pengirim)

func _jadi_host() -> void:
	mode_saat_ini = "host"
	label_status.text = "Waiting for other player to join..."

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT_GAME, MAKS_CLIENT) # host + 3 client = 4 pemain manusia
	if error != OK:
		label_status.text = "Something went wrong. Tap Refresh to try again."
		return
	peer_jaringan = peer
	multiplayer.multiplayer_peer = peer
	# udp_diskaveri SENGAJA dibiarkan tetap hidup (tidak ditutup) di sini,
	# supaya bisa terus membalas pemain lain yang menyusul cari kita.
	urutan_client.clear()
	role_peer.clear()
	role_ai_lobby.clear()
	_tampilkan_lobby()

func _jadi_client(ip_host: String) -> void:
	mode_saat_ini = "client"
	_sembunyikan_lobby()
	label_status.text = "Found a game! Connecting..."

	if udp_diskaveri:
		udp_diskaveri.close()
		udp_diskaveri = null

	# Kalau sebelumnya kita sempat jadi host (kasus dua-duanya jadi host lalu
	# mengalah), tutup dulu server lamanya sebelum menyambung sebagai client.
	if peer_jaringan:
		peer_jaringan.close()
		peer_jaringan = null
		multiplayer.multiplayer_peer = null

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_host, PORT_GAME)
	if error != OK:
		label_status.text = "Something went wrong. Tap Refresh to try again."
		return
	peer_jaringan = peer
	multiplayer.multiplayer_peer = peer

func _saat_pemain_lain_gabung(id_peer: int) -> void:
	# PENTING: sinyal peer_connected juga menyala di sisi CLIENT (saat berhasil
	# nyambung ke host). Tanpa penjagaan ini, client akan salah mencatat dirinya
	# sebagai "host" dan memanggil change_scene untuk kedua kalinya.
	if mode_saat_ini != "host":
		return
	if sudah_pindah_scene:
		return
	# Belum pindah scene: pemain yang gabung masuk LOBBY dulu. Host yang memilih
	# mode & peta lalu menekan START (lihat _mulai_dari_lobby).
	if not urutan_client.has(id_peer):
		urutan_client.append(id_peer)
	_segarkan_lobby()
	_kirim_info_lobby()

func _saat_berhasil_connect() -> void:
	if sudah_pindah_scene:
		return
	# Client menunggu di lobby sampai host menekan START.
	label_status.text = "Connected!"
	mode_saat_ini = "lobby_client"
	_tampilkan_lobby()

func _saat_gagal_connect() -> void:
	label_status.text = "Connection failed. Tap Refresh to try again."
	mode_saat_ini = ""

func _on_tombol_refresh_pressed() -> void:
	mulai_pencarian()

func _bersihkan_semua() -> void:
	if udp_diskaveri:
		udp_diskaveri.close()
		udp_diskaveri = null
	# Hanya tutup peer yang memang kita buat sendiri. Mengecek
	# multiplayer.multiplayer_peer langsung tidak bisa dipakai — nilainya selalu
	# terisi peer default, jadi cek itu selalu benar walau belum pernah connect.
	if peer_jaringan:
		peer_jaringan.close()
		peer_jaringan = null
		multiplayer.multiplayer_peer = null
	role_peer.clear()
	role_ai_lobby.clear()

# ========================================================
# LOBBY MULTIPLAYER (2-4 pemain)
# Host: pilih mode (6 pilihan) & peta, lihat siapa saja yang sudah gabung, lalu
# START -- tombolnya baru aktif kalau jumlah pemain manusia pas dengan mode.
# Client: melihat pilihan host secara langsung dan menunggu START.
# Saat START, host mengirim susunan permainan ke semua device (jenis tiap slot,
# peer -> slot, peta), lalu semuanya pindah ke panggung_utama.tscn bersamaan.
# ========================================================
func _buat_panel_lobby() -> void:
	panel_lobby = PanelContainer.new()
	var gaya = StyleBoxFlat.new()
	gaya.bg_color = Color(0.06, 0.07, 0.1, 0.94)
	gaya.border_color = Color(1.0, 0.85, 0.2)
	gaya.set_border_width_all(2)
	gaya.set_corner_radius_all(14)
	gaya.content_margin_left = 30
	gaya.content_margin_right = 30
	gaya.content_margin_top = 16
	gaya.content_margin_bottom = 20
	panel_lobby.add_theme_stylebox_override("panel", gaya)
	# Menempel di atas-tengah supaya tidak menutupi tombol TRY AGAIN di bawah.
	panel_lobby.anchor_left = 0.5
	panel_lobby.anchor_right = 0.5
	panel_lobby.anchor_top = 0.0
	panel_lobby.anchor_bottom = 0.0
	panel_lobby.offset_top = 16
	panel_lobby.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(panel_lobby)
	panel_lobby.hide()

	var isi = VBoxContainer.new()
	isi.add_theme_constant_override("separation", 12)
	panel_lobby.add_child(isi)

	var judul = _label_lobby("LOBBY", 30)
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	isi.add_child(judul)

	var kolom = HBoxContainer.new()
	kolom.add_theme_constant_override("separation", 40)
	isi.add_child(kolom)

	var kiri = VBoxContainer.new()
	kiri.add_theme_constant_override("separation", 9)
	kolom.add_child(kiri)
	kiri.add_child(_label_lobby("GAME MODE", 20))
	for i in range(MODE_LOBBY.size()):
		var b = _tombol_lobby(MODE_LOBBY[i]["nama"], Vector2(300, 48))
		b.pressed.connect(_pilih_mode_lobby.bind(i))
		kiri.add_child(b)
		tombol_mode_lobby.append(b)
	kiri.add_child(_label_lobby("STAGE", 20))
	var baris_peta = HBoxContainer.new()
	baris_peta.add_theme_constant_override("separation", 10)
	kiri.add_child(baris_peta)
	for data in PETA_LOBBY:
		var b = _tombol_lobby(data[1], Vector2(145, 48))
		b.pressed.connect(_pilih_peta_lobby.bind(data[0]))
		baris_peta.add_child(b)
		tombol_peta_lobby.append(b)

	var kanan = VBoxContainer.new()
	kanan.add_theme_constant_override("separation", 12)
	kanan.custom_minimum_size = Vector2(360, 0)
	kolom.add_child(kanan)
	kanan.add_child(_label_lobby("PLAYERS", 20))
	label_pemain_lobby = RichTextLabel.new()
	label_pemain_lobby.bbcode_enabled = true
	label_pemain_lobby.fit_content = true
	label_pemain_lobby.scroll_active = false
	label_pemain_lobby.custom_minimum_size = Vector2(360, 150)
	label_pemain_lobby.add_theme_font_size_override("normal_font_size", 22)
	label_pemain_lobby.add_theme_font_size_override("bold_font_size", 22)
	kanan.add_child(label_pemain_lobby)
	# Fase 4 (A6): tiap pemain (host & client) pilih role sendiri-sendiri di sini.
	tombol_role_saya = _tombol_lobby("MY ROLE: —", Vector2(360, 48))
	tombol_role_saya.pressed.connect(_buka_role_lobby)
	kanan.add_child(tombol_role_saya)
	var pengisi = Control.new()
	pengisi.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kanan.add_child(pengisi)
	kanan.add_child(_label_lobby("MATCH", 20))
	var baris_panjang = HBoxContainer.new()
	baris_panjang.add_theme_constant_override("separation", 10)
	kanan.add_child(baris_panjang)
	for data in [[true, "QUICK"], [false, "CLASSIC"]]:
		var b = _tombol_lobby(data[1], Vector2(175, 48))
		b.pressed.connect(_pilih_panjang_lobby.bind(data[0]))
		baris_panjang.add_child(b)
		tombol_panjang_lobby.append(b)
	tombol_mulai_lobby = _tombol_lobby("START GAME", Vector2(360, 62))
	tombol_mulai_lobby.add_theme_font_size_override("font_size", 26)
	tombol_mulai_lobby.pressed.connect(_mulai_dari_lobby)
	kanan.add_child(tombol_mulai_lobby)
	label_info_lobby = _label_lobby("", 18)
	label_info_lobby.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_info_lobby.custom_minimum_size = Vector2(360, 0)
	label_info_lobby.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kanan.add_child(label_info_lobby)

func _label_lobby(teks: String, ukuran: int) -> Label:
	var l = Label.new()
	l.text = teks
	l.add_theme_font_size_override("font_size", ukuran)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l

func _tombol_lobby(teks: String, ukuran: Vector2) -> Button:
	var b = Button.new()
	b.text = teks
	b.custom_minimum_size = ukuran
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 4)
	return b

func _gaya_tombol_lobby(b: Button, warna: Color, terpilih: bool) -> void:
	# Pilihan yang aktif: warna penuh + bingkai emas. Lainnya: lebih gelap.
	var g = StyleBoxFlat.new()
	g.bg_color = warna if terpilih else warna.darkened(0.5)
	g.set_corner_radius_all(10)
	g.border_width_bottom = 4
	g.border_color = warna.darkened(0.5)
	if terpilih:
		g.set_border_width_all(3)
		g.border_color = Color(1.0, 0.85, 0.2)
	var h = g.duplicate()
	h.bg_color = g.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("normal", g)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", g)
	b.add_theme_stylebox_override("disabled", g)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.95 if terpilih else 0.5))

func _jumlah_client_dibutuhkan() -> int:
	return MODE_LOBBY[indeks_mode_lobby]["jenis"].count("manusia") - 1

func _tampilkan_lobby() -> void:
	label_status.hide()
	panel_lobby.show()
	_segarkan_lobby()

func _sembunyikan_lobby() -> void:
	if panel_lobby:
		panel_lobby.hide()
	label_status.show()

func _segarkan_lobby() -> void:
	if panel_lobby == null:
		return
	var host = mode_saat_ini == "host"
	for i in range(tombol_mode_lobby.size()):
		_gaya_tombol_lobby(tombol_mode_lobby[i], Color(0.15, 0.45, 0.8), i == indeks_mode_lobby)
		tombol_mode_lobby[i].disabled = not host
	for i in range(tombol_peta_lobby.size()):
		var warna_peta = Color(0.2, 0.6, 0.3) if PETA_LOBBY[i][0] == "alam" else Color(0.15, 0.3, 0.65)
		_gaya_tombol_lobby(tombol_peta_lobby[i], warna_peta, PETA_LOBBY[i][0] == peta_lobby)
		tombol_peta_lobby[i].disabled = not host
	for i in range(tombol_panjang_lobby.size()):
		var quick = (i == 0)
		_gaya_tombol_lobby(tombol_panjang_lobby[i], WARNA_QUICK if quick else WARNA_CLASSIC, quick == quick_lobby)
		tombol_panjang_lobby[i].disabled = not host

	# Daftar pemain: slot, warna karakter, dan siapa yang menempatinya.
	var jenis: Array = MODE_LOBBY[indeks_mode_lobby]["jenis"]
	var id_saya = multiplayer.get_unique_id() if peer_jaringan else 0
	var baris = []
	var ke = 0
	var saya_dapat_slot = host
	var semua_role_terisi = true
	for s in range(jenis.size()):
		var nama = ""
		var peer_di_slot = -1
		if s == 0:
			nama = "HOST" + (" (YOU)" if host else "")
			peer_di_slot = 1
		elif jenis[s] == "ai":
			nama = "AI"
		else:
			if ke < urutan_client.size():
				peer_di_slot = urutan_client[ke]
				var milik_saya = (not host) and peer_di_slot == id_saya
				saya_dapat_slot = saya_dapat_slot or milik_saya
				nama = "PLAYER" + (" (YOU)" if milik_saya else "")
			else:
				nama = "[color=#8a8a8a]waiting for player...[/color]"
			ke += 1
		# Fase 4 (A6): role berwarna di samping tiap nama ("P2  PLAYER (YOU)  FIRE").
		var teks_role = ""
		var role_slot_ini = ""
		if jenis[s] == "ai":
			role_slot_ini = str(role_ai_lobby.get(s, ""))
		elif peer_di_slot >= 0:
			role_slot_ini = str((role_peer.get(peer_di_slot, {}) as Dictionary).get("role", ""))
			if role_slot_ini == "":
				semua_role_terisi = false
		if role_slot_ini != "":
			teks_role = "  [color=#%s]%s[/color]" % [DataRole.warna_role(role_slot_ini).to_html(false), DataRole.nama_role(role_slot_ini)]
		baris.append("[b][color=#%s]P%d[/color][/b]   %s%s" % [UIPetak.warna_slot(s).to_html(false), s + 1, nama, teks_role])
	var lebih = urutan_client.size() - _jumlah_client_dibutuhkan()
	if lebih > 0:
		baris.append("[color=#ff9955]+%d more player%s connected[/color]" % [lebih, "" if lebih == 1 else "s"])
	label_pemain_lobby.text = "\n".join(baris)

	# Fase 4 (A6): tombol MY ROLE -- terlihat & aktif untuk host maupun client,
	# menampilkan pilihan sendiri (kosong = belum pernah memilih).
	if tombol_role_saya:
		var role_saya = str((role_peer.get(id_saya, {}) as Dictionary).get("role", "")) if id_saya > 0 else ""
		tombol_role_saya.text = "MY ROLE: %s" % (DataRole.nama_role(role_saya) if role_saya != "" else "—")
		tombol_role_saya.disabled = id_saya <= 0 or not saya_dapat_slot
		_gaya_tombol_lobby(tombol_role_saya, DataRole.warna_role(role_saya) if role_saya != "" else Color(0.35, 0.35, 0.4), role_saya != "")

	tombol_mulai_lobby.visible = host
	if host:
		var kurang = -lebih
		tombol_mulai_lobby.disabled = kurang != 0 or not semua_role_terisi
		_gaya_tombol_lobby(tombol_mulai_lobby, Color(0.15, 0.6, 0.55), kurang == 0 and semua_role_terisi)
		if kurang > 0:
			label_info_lobby.text = "Waiting for %d more player%s...\nThey open LOCAL PLAY on the same WiFi / hotspot." % [kurang, "" if kurang == 1 else "s"]
		elif kurang < 0:
			label_info_lobby.text = "Too many players for this mode.\nChoose a mode with more players."
		elif not semua_role_terisi:
			label_info_lobby.text = "Waiting for players to choose a role..."
		else:
			label_info_lobby.text = "Everyone is here. Press START!"
	elif not saya_dapat_slot:
		label_info_lobby.text = "This mode is full.\nWaiting for the host to choose another mode..."
	elif not semua_role_terisi:
		label_info_lobby.text = "Waiting for players to choose a role..."
	else:
		label_info_lobby.text = "Waiting for the host to start..."

func _pilih_mode_lobby(indeks: int) -> void:
	if mode_saat_ini != "host":
		return
	indeks_mode_lobby = indeks
	_undi_role_ai_lobby()
	_segarkan_lobby()
	_kirim_info_lobby()

func _undi_role_ai_lobby() -> void:
	# K9: role AI diundi HOST setiap kali mode dipilih (pengacak milik layar
	# ini sendiri, BUKAN mesin_acak -- lihat komentar di deklarasi role_peer).
	# Host tidak bisa mengganti role AI satu-satu (sederhana, sesuai K9).
	var jenis: Array = MODE_LOBBY[indeks_mode_lobby]["jenis"]
	role_ai_lobby.clear()
	for s in range(jenis.size()):
		if jenis[s] == "ai":
			role_ai_lobby[s] = DataRole.ROLE[_rng_lobby.randi_range(0, DataRole.ROLE.size() - 1)]

func _buka_role_lobby() -> void:
	# Fase 4 (A6): host maupun client bisa membuka layar ROLE untuk dirinya
	# sendiri kapan saja selama di lobby.
	var id_saya = multiplayer.get_unique_id() if peer_jaringan else 0
	if id_saya <= 0:
		return
	var data_saya: Dictionary = role_peer.get(id_saya, {})
	var konteks = {
		"role": str(data_saya.get("role", "")),
		"jebakan": data_saya.get("jebakan", []),
		"jumlah_jenis": DataRole.SLOT_JEBAKAN_MP,
		"teks_tombol": "OK",
		"petunjuk_level": false,
		"boleh_batal": true,
		"batal": func(): pass,
		"lapisan": 15,
	}
	UiRole.buka_pilih_role(self, konteks, func(role: String, jebakan: Array):
		# C2 (B-c, 26-09): build Arena dihitung SEKALI di sini (host & client) --
		# SATU sumber DataRole.build_arena, dari simpanan ProfilPemain.arena milik
		# HP ini sendiri (K16: kosong/tidak sah -> preset Balanced 12 SP).
		var build_saya: Dictionary = DataRole.build_arena(role, ProfilPemain.arena.get(role, {}))
		if mode_saat_ini == "host":
			role_peer[id_saya] = {"role": role, "jebakan": jebakan, "build": build_saya}
			_segarkan_lobby()
			_kirim_info_lobby()
		else:
			rpc_id(1, "rpc_role_lobby", role, jebakan, build_saya)
	)

func _jebakan_sah_lobby(role: String, dibawa: Array) -> Array:
	# Sama seperti pemain_role.gd _jebakan_sah (A2), disalin ringkas di sini
	# karena layar ini di luar rantai pemain_*.gd: role selalu ikut & terkunci;
	# sisanya dari "dibawa" kalau sah; dilengkapi bawaan otomatis kalau kurang.
	var hasil: Array = [role]
	for e in dibawa:
		if typeof(e) == TYPE_STRING and DataRole.ROLE.has(e) and not hasil.has(e) and hasil.size() < DataRole.SLOT_JEBAKAN_MP:
			hasil.append(e)
	if hasil.size() < DataRole.SLOT_JEBAKAN_MP:
		for e in DataRole.jebakan_bawaan_ai(role, [], DataRole.SLOT_JEBAKAN_MP):
			if not hasil.has(e) and hasil.size() < DataRole.SLOT_JEBAKAN_MP:
				hasil.append(e)
	return hasil

@rpc("any_peer", "call_remote", "reliable")
func rpc_role_lobby(role: String, jebakan: Array, build: Dictionary) -> void:
	# Diterima HOST: client memilih rolenya sendiri. Divalidasi ulang di sini
	# (client bisa mengirim data sembarangan) -- validasi PENUH sekali lagi
	# juga terjadi saat START (_bangun_role_slot), jadi ini cukup penjaga dasar.
	if mode_saat_ini != "host":
		return
	var sender = multiplayer.get_remote_sender_id()
	if sender <= 0 or not DataRole.ROLE.has(role):
		return
	# C2 (B-c, 26-09): build_arena divalidasi ULANG dari sisi host (client bisa
	# mengirim build apa saja) -- kalau tidak sah, jatuh balik ke Balanced (K16).
	role_peer[sender] = {"role": role, "jebakan": _jebakan_sah_lobby(role, jebakan), "build": DataRole.build_arena(role, {"node": build})}
	_segarkan_lobby()
	_kirim_info_lobby()

func _pilih_peta_lobby(peta: String) -> void:
	if mode_saat_ini != "host":
		return
	peta_lobby = peta
	_segarkan_lobby()
	_kirim_info_lobby()

func _pilih_panjang_lobby(quick: bool) -> void:
	if mode_saat_ini != "host":
		return
	quick_lobby = quick
	StatusJaringan.simpan_pilihan_quick(quick)
	_segarkan_lobby()
	_kirim_info_lobby()

func _kirim_info_lobby() -> void:
	# HOST: kabari semua client isi lobby terbaru.
	if mode_saat_ini != "host" or peer_jaringan == null:
		return
	rpc("rpc_info_lobby", indeks_mode_lobby, peta_lobby, urutan_client, quick_lobby, role_peer, role_ai_lobby)

@rpc("authority", "call_remote", "reliable")
func rpc_info_lobby(indeks_mode: int, peta: String, urutan: Array, quick: bool, role_peer_baru: Dictionary, role_ai_baru: Dictionary) -> void:
	# Diterima di CLIENT.
	if sudah_pindah_scene:
		return
	indeks_mode_lobby = clampi(indeks_mode, 0, MODE_LOBBY.size() - 1)
	peta_lobby = peta
	urutan_client = urutan
	quick_lobby = quick
	# Fase 4 (A6): role tiap peer (termasuk AI) -- lihat komentar di role_peer.
	role_peer = role_peer_baru
	role_ai_lobby = role_ai_baru
	if mode_saat_ini == "lobby_client" and not panel_lobby.visible:
		_tampilkan_lobby()
	_segarkan_lobby()

func _saat_pemain_keluar_lobby(id_peer: int) -> void:
	# HOST: pemain yang sudah di lobby keluar sebelum START.
	if mode_saat_ini != "host" or sudah_pindah_scene:
		return
	urutan_client.erase(id_peer)
	role_peer.erase(id_peer)
	_segarkan_lobby()
	_kirim_info_lobby()

func _saat_host_keluar_lobby() -> void:
	# CLIENT: host menutup lobby sebelum START -> cari permainan lagi.
	if mode_saat_ini != "lobby_client" or sudah_pindah_scene:
		return
	mode_saat_ini = "host_hilang"
	_sembunyikan_lobby()
	label_status.text = "The host left the lobby. Searching again..."
	await get_tree().create_timer(1.5).timeout
	if mode_saat_ini == "host_hilang":
		mulai_pencarian()

func _mulai_dari_lobby() -> void:
	# HOST menekan START GAME.
	if mode_saat_ini != "host" or sudah_pindah_scene:
		return
	if urutan_client.size() != _jumlah_client_dibutuhkan():
		return
	sudah_pindah_scene = true
	var jenis: Array = MODE_LOBBY[indeks_mode_lobby]["jenis"].duplicate()
	# Host selalu slot 0 (peer id 1); client menurut urutan gabung mengisi slot
	# manusia berikutnya; sisanya AI.
	var peer_slot = {1: 0}
	var ke = 0
	for s in range(1, jenis.size()):
		if jenis[s] == "manusia":
			peer_slot[urutan_client[ke]] = s
			ke += 1
	# Fase 4 (A6): data_role per slot -- dibangun & DIVALIDASI ULANG di sini
	# (bukan cuma memakai role_peer/role_ai_lobby apa adanya).
	var role_slot = _bangun_role_slot(jenis, peer_slot)
	# Permainan sudah dimulai: tidak menerima pemain baru lagi.
	peer_jaringan.refuse_new_connections = true
	# Nomor acak permainan ini -- dipakai migrasi host kalau host keluar nanti.
	var id_sesi = randi_range(1, 2000000000)
	rpc("rpc_mulai_dari_lobby", jenis, peer_slot, peta_lobby, id_sesi, quick_lobby, role_slot)
	_masuk_permainan("host", jenis, peer_slot, peta_lobby, id_sesi, quick_lobby, role_slot)

func _bangun_role_slot(jenis: Array, peer_slot: Dictionary) -> Array:
	# slot -> {"role", "jebakan", "build"} akhir yang dikirim ke semua HP (bagian
	# 7): AI dari role_ai_lobby, manusia dari role_peer (lewat peer_slot dibalik).
	# Kalau ternyata tidak sah (role kosong/belum pernah memilih -- seharusnya
	# tidak terjadi karena START mati sampai semua_role_terisi, tapi tetap
	# dijaga di sini) -- diundi cadangan + jebakan diganti pilihan bawaan.
	# C2 (B-c, 26-09): build juga divalidasi ULANG di sini lewat DataRole.build_arena
	# -- manusia dari build role_peer (kalau role diundi cadangan, dihitung ULANG
	# dari role BARU, bukan build role lama); AI TIDAK punya build tersimpan
	# sendiri (role_ai_lobby cuma String role) -> selalu preset Balanced (K16).
	# D3 (B-d/P5): dipecah 2 putaran -- putaran 1 role+build SEMUA slot (urutan
	# undian cadangan _rng_lobby PERSIS sama seperti sebelumnya, s=0..N-1
	# berurutan); putaran 2 jebakan per slot, AI sekarang baca build_lawan
	# SUNGGUHAN semua lawan (baru lengkap sesudah putaran 1) lewat
	# jebakan_bawaan_ai LANGSUNG (bukan _jebakan_sah_lobby, itu tidak diubah &
	# tidak punya parameter build_lawan); manusia tetap _jebakan_sah_lobby biasa.
	var slot_peer: Dictionary = {}
	for peer in peer_slot:
		slot_peer[int(peer_slot[peer])] = int(peer)
	var hasil: Array = []
	hasil.resize(jenis.size())
	for s in range(jenis.size()):
		var role_s := ""
		var build_kiriman: Dictionary = {}
		var ai_slot: bool = (jenis[s] == "ai")
		if ai_slot:
			role_s = str(role_ai_lobby.get(s, ""))
		elif slot_peer.has(s):
			var d: Dictionary = role_peer.get(slot_peer[s], {})
			role_s = str(d.get("role", ""))
			build_kiriman = d.get("build", {})
		if role_s == "" or not DataRole.ROLE.has(role_s):
			role_s = DataRole.ROLE[_rng_lobby.randi_range(0, DataRole.ROLE.size() - 1)]
		var build_s: Dictionary = DataRole.build_arena(role_s, {}) if ai_slot else DataRole.build_arena(role_s, {"node": build_kiriman})
		hasil[s] = {"role": role_s, "build": build_s}
	for s in range(jenis.size()):
		if jenis[s] == "ai":
			var role_lawan: Array = []
			var build_lawan: Array = []
			for t in range(jenis.size()):
				if t != s:
					role_lawan.append(hasil[t]["role"])
					build_lawan.append(hasil[t]["build"])
			hasil[s]["jebakan"] = DataRole.jebakan_bawaan_ai(hasil[s]["role"], role_lawan, DataRole.SLOT_JEBAKAN_MP, build_lawan)
		else:
			var jebakan_s: Array = []
			if slot_peer.has(s):
				var d: Dictionary = role_peer.get(slot_peer[s], {})
				jebakan_s = d.get("jebakan", [])
			hasil[s]["jebakan"] = _jebakan_sah_lobby(hasil[s]["role"], jebakan_s)
	return hasil

@rpc("authority", "call_remote", "reliable")
func rpc_mulai_dari_lobby(jenis: Array, peer_slot: Dictionary, peta: String, id_sesi: int, quick: bool, role_slot: Array) -> void:
	# Diterima di CLIENT: host menekan START.
	if sudah_pindah_scene:
		return
	sudah_pindah_scene = true
	_masuk_permainan("client", jenis, peer_slot, peta, id_sesi, quick, role_slot)

func _masuk_permainan(peran: String, jenis: Array, peer_slot: Dictionary, peta: String, id_sesi: int, quick: bool, role_slot: Array) -> void:
	mode_saat_ini = "terhubung"
	label_info_lobby.text = "Starting..."
	tombol_mulai_lobby.disabled = true
	if udp_diskaveri:
		udp_diskaveri.close()
		udp_diskaveri = null
	StatusJaringan.peran_multiplayer = peran
	StatusJaringan.jenis_slot = jenis
	StatusJaringan.peer_slot = peer_slot
	StatusJaringan.peta_multiplayer = peta
	StatusJaringan.id_sesi = id_sesi
	StatusJaringan.mode_quick = quick
	# Fase 4 (A6/bagian 7): role semua slot -- disalin ke DataPemain di
	# pemain_role.gd _siapkan_role_semua (HOST) sesudah scene ini pindah.
	StatusJaringan.role_slot = role_slot
	get_tree().change_scene_to_file("res://panggung_utama.tscn")
