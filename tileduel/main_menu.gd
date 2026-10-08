extends CanvasLayer

signal mulai_game(nama_peta, jumlah_ai, quick)

var panel_utama: VBoxContainer
var panel_map: VBoxContainer
# QUICK MATCH / CLASSIC (Fase 1) -- pilihan terakhir diingat (StatusJaringan).
var quick_dipilih: bool = true
var tombol_quick: Button
var tombol_classic: Button
var label_ket_mode: Label
const WARNA_QUICK := Color(0.85, 0.5, 0.1)
const WARNA_CLASSIC := Color(0.35, 0.35, 0.6)
# Penjaga ketuk dua kali pada tombol peta (lihat _proses_tombol_peta).
var _sudah_mulai: bool = false
# Fase 4 (A6): penjaga layar ROLE supaya ketukan ganda tombol peta tidak
# membuka dua layar ROLE sekaligus (lihat _proses_tombol_peta).
var _role_terbuka: bool = false
# Fase 2: bar profil (kiri atas) & tombol MISSIONS (kanan atas) -- dibuat UiProfil.
var bar_profil: Button = null
var tombol_misi: Button = null
# Menu SINGLE PLAYER: pilih dulu berapa lawan AI (1-3), baru pilih peta.
var panel_lawan: VBoxContainer
var jumlah_ai_dipilih: int = 1
var panel_multiplayer: VBoxContainer
var judul: RichTextLabel
var latar_belakang: ColorRect
var sfx_player: AudioStreamPlayer
var suara_hover: AudioStreamWAV
var suara_boom: AudioStreamWAV

func _ready():
	layer = 10 # Pastikan selalu berada di atas segalanya
	_racik_efek_suara()
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)
	
	# 1. Latar Belakang Gelap Vignette
	latar_belakang = ColorRect.new()
	latar_belakang.set_anchors_preset(Control.PRESET_FULL_RECT)
	latar_belakang.color = Color(0.05, 0.05, 0.1, 0.4) # Gelap transparan
	add_child(latar_belakang)
	
	# 2. Judul Game Animasi
	judul = RichTextLabel.new()
	judul.bbcode_enabled = true
	judul.text = "[center][b]TILE\n[font_size=24][color=cyan]DUEL[/color][/font_size][/b][/center]"
	judul.add_theme_font_size_override("normal_font_size", 70)
	judul.add_theme_constant_override("outline_size", 12)
	judul.add_theme_color_override("font_outline_color", Color.BLACK)
	judul.set_anchors_preset(Control.PRESET_TOP_WIDE)
	judul.position.y = 80
	judul.fit_content = true
	judul.clip_contents = false
	add_child(judul)
	
	# Animasi Judul Melayang
	var tw_judul = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_judul.tween_property(judul, "position:y", 65.0, 1.5)
	tw_judul.tween_property(judul, "position:y", 80.0, 1.5)
	
	# 3. Setup Panel Utama
	panel_utama = VBoxContainer.new()
	_setup_container(panel_utama)
	
	var btn_offline = _buat_tombol_menu("SINGLE PLAYER", Color(0.15, 0.45, 0.8))
	btn_offline.pressed.connect(_ke_menu_lawan)
	panel_utama.add_child(btn_offline)
	
	var btn_online = _buat_tombol_menu("MULTIPLAYER", Color(0.15, 0.6, 0.55))
	btn_online.pressed.connect(_ke_menu_multiplayer)
	panel_utama.add_child(btn_online)
	
	var btn_seting = _buat_tombol_menu("⚙ SETTINGS", Color(0.5, 0.2, 0.6))
	btn_seting.pressed.connect(_buka_menu_seting)
	panel_utama.add_child(btn_seting)
	
	# 4. Setup Panel Map (Disembunyikan di awal)
	panel_map = VBoxContainer.new()
	_setup_container(panel_map)
	panel_map.hide()
	
	var label_map = Label.new()
	label_map.text = "- SELECT STAGE -"
	label_map.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_map.add_theme_font_size_override("font_size", 24)
	label_map.add_theme_color_override("font_outline_color", Color.BLACK)
	label_map.add_theme_constant_override("outline_size", 6)
	panel_map.add_child(label_map) # HARUS tetap anak ke-0 (dipakai _proses_tombol_peta)

	# Sakelar QUICK MATCH / CLASSIC di atas tombol peta.
	quick_dipilih = StatusJaringan.baca_pilihan_quick()
	var baris_mode = HBoxContainer.new()
	baris_mode.alignment = BoxContainer.ALIGNMENT_CENTER
	baris_mode.add_theme_constant_override("separation", 10)
	panel_map.add_child(baris_mode)
	tombol_quick = _buat_tombol_menu("QUICK MATCH", WARNA_QUICK)
	tombol_classic = _buat_tombol_menu("CLASSIC", WARNA_CLASSIC)
	for b in [tombol_quick, tombol_classic]:
		b.custom_minimum_size = Vector2(170, 56)
		b.add_theme_font_size_override("font_size", 20)
		baris_mode.add_child(b)
	tombol_quick.pressed.connect(_pilih_panjang_match.bind(true))
	tombol_classic.pressed.connect(_pilih_panjang_match.bind(false))
	label_ket_mode = Label.new()
	label_ket_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_ket_mode.add_theme_font_size_override("font_size", 18)
	label_ket_mode.add_theme_color_override("font_outline_color", Color.BLACK)
	label_ket_mode.add_theme_constant_override("outline_size", 5)
	panel_map.add_child(label_ket_mode)
	_segarkan_pilihan_mode()

	var btn_map1 = _buat_tombol_menu("Grassland", Color(0.2, 0.6, 0.3))
	btn_map1.pressed.connect(_proses_tombol_peta.bind("alam")) # <-- Ubah ini
	panel_map.add_child(btn_map1)
	
	# --- TAMBAHAN TOMBOL PANTAI ---
	var btn_map2 = _buat_tombol_menu("Night Beach", Color(0.1, 0.2, 0.5))
	btn_map2.pressed.connect(_proses_tombol_peta.bind("pantai"))
	panel_map.add_child(btn_map2)
	
	var btn_kembali = _buat_tombol_menu("Back", Color(0.6, 0.2, 0.2))
	btn_kembali.pressed.connect(_kembali_ke_utama)
	panel_map.add_child(btn_kembali)

	# 4a. Setup Panel Jumlah Lawan AI (Disembunyikan di awal)
	panel_lawan = VBoxContainer.new()
	_setup_container(panel_lawan)
	panel_lawan.hide()

	var label_lawan = Label.new()
	label_lawan.text = "- HOW MANY OPPONENTS? -"
	label_lawan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_lawan.add_theme_font_size_override("font_size", 24)
	label_lawan.add_theme_color_override("font_outline_color", Color.BLACK)
	label_lawan.add_theme_constant_override("outline_size", 6)
	panel_lawan.add_child(label_lawan)

	var warna_lawan = [Color(0.8, 0.25, 0.25), Color(0.2, 0.6, 0.3), Color(0.85, 0.65, 0.1)]
	for n in range(1, 4):
		var teks = "1 AI ENEMY" if n == 1 else str(n) + " AI ENEMIES"
		var btn_lawan = _buat_tombol_menu(teks, warna_lawan[n - 1])
		btn_lawan.pressed.connect(_pilih_jumlah_lawan.bind(n))
		panel_lawan.add_child(btn_lawan)

	var btn_kembali_lawan = _buat_tombol_menu("Back", Color(0.6, 0.2, 0.2))
	btn_kembali_lawan.pressed.connect(_kembali_ke_utama)
	panel_lawan.add_child(btn_kembali_lawan)

	# 4b. Setup Panel Multiplayer (Disembunyikan di awal)
	panel_multiplayer = VBoxContainer.new()
	_setup_container(panel_multiplayer)
	panel_multiplayer.hide()

	var label_multiplayer = Label.new()
	label_multiplayer.text = "- MULTIPLAYER -"
	label_multiplayer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_multiplayer.add_theme_font_size_override("font_size", 24)
	label_multiplayer.add_theme_color_override("font_outline_color", Color.BLACK)
	label_multiplayer.add_theme_constant_override("outline_size", 6)
	panel_multiplayer.add_child(label_multiplayer)

	var btn_local_play = _buat_tombol_menu("LOCAL PLAY", Color(0.15, 0.6, 0.55))
	btn_local_play.pressed.connect(_ke_local_play)
	panel_multiplayer.add_child(btn_local_play)

	var btn_online_play = _buat_tombol_menu("ONLINE PLAY (Coming Soon)", Color(0.4, 0.4, 0.4))
	btn_online_play.disabled = true
	panel_multiplayer.add_child(btn_online_play)

	var btn_kembali_mp = _buat_tombol_menu("Back", Color(0.6, 0.2, 0.2))
	btn_kembali_mp.pressed.connect(_kembali_ke_utama)
	panel_multiplayer.add_child(btn_kembali_mp)

	# 5. Fase 2: profil pemain -- bar kiri atas, MISSIONS kanan atas, hadiah login harian.
	ProfilPemain.segarkan_hari()
	UiProfil.pasang_di_menu(self)
	ProfilPemain.profil_berubah.connect(_segarkan_profil_menu)
	if ProfilPemain.login_bisa_diklaim():
		call_deferred("_tampilkan_login_harian")

func _segarkan_profil_menu() -> void:
	# Metode (bukan lambda): sambungannya putus sendiri saat menu dibuang.
	UiProfil.segarkan_menu(self)

func _tampilkan_login_harian() -> void:
	if not _sudah_mulai:
		UiProfil.tampilkan_popup_login(self)

func _setup_container(container: VBoxContainer):
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.add_theme_constant_override("separation", 20)
	add_child(container)

func _buat_tombol_menu(teks: String, warna_dasar: Color) -> Button:
	var btn = Button.new()
	btn.text = teks
	btn.custom_minimum_size = Vector2(350, 70)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 5)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var style = StyleBoxFlat.new()
	style.bg_color = warna_dasar
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.border_width_bottom = 6
	style.border_color = warna_dasar.darkened(0.4)
	
	var style_hover = style.duplicate()
	style_hover.bg_color = warna_dasar.lightened(0.2)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("disabled", style.duplicate())
	
	btn.mouse_entered.connect(func():
		if not btn.disabled:
			sfx_player.stream = suara_hover
			sfx_player.pitch_scale = 1.0
			sfx_player.play()
	)
	
	return btn

func _ke_menu_lawan():
	sfx_player.stream = suara_hover
	sfx_player.pitch_scale = 1.5
	sfx_player.play()
	panel_utama.hide()
	panel_lawan.show()

func _pilih_jumlah_lawan(jumlah: int):
	jumlah_ai_dipilih = jumlah
	_ke_menu_map()

func _ke_menu_map():
	sfx_player.stream = suara_hover
	sfx_player.pitch_scale = 1.5
	sfx_player.play()
	panel_utama.hide()
	panel_lawan.hide()
	panel_map.show()
	_segarkan_pilihan_mode() # jumlah ronde Quick tergantung jumlah lawan

func _pilih_panjang_match(quick: bool) -> void:
	quick_dipilih = quick
	StatusJaringan.simpan_pilihan_quick(quick)
	sfx_player.stream = suara_hover
	sfx_player.pitch_scale = 1.2
	sfx_player.play()
	_segarkan_pilihan_mode()

func _segarkan_pilihan_mode() -> void:
	if tombol_quick == null:
		return
	_gaya_pilihan_mode(tombol_quick, WARNA_QUICK, quick_dipilih)
	_gaya_pilihan_mode(tombol_classic, WARNA_CLASSIC, not quick_dipilih)
	if quick_dipilih:
		var ronde = StatusJaringan.BATAS_RONDE_QUICK.get(jumlah_ai_dipilih + 1, 8)
		label_ket_mode.text = "%d rounds. The richest player wins." % ronde
	else:
		label_ket_mode.text = "No round limit. Reach START with 3000 coins."

func _gaya_pilihan_mode(b: Button, warna: Color, terpilih: bool) -> void:
	# Yang terpilih: warna penuh + bingkai emas. Lainnya lebih gelap (seperti lobby).
	var g = StyleBoxFlat.new()
	g.bg_color = warna if terpilih else warna.darkened(0.5)
	g.set_corner_radius_all(12)
	g.border_width_bottom = 6
	g.border_color = warna.darkened(0.4)
	if terpilih:
		g.set_border_width_all(3)
		g.border_color = Color(1.0, 0.85, 0.2)
	var h = g.duplicate()
	h.bg_color = g.bg_color.lightened(0.15)
	b.add_theme_stylebox_override("normal", g)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", g)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1.0 if terpilih else 0.6))

func _kembali_ke_utama():
	sfx_player.stream = suara_hover
	sfx_player.pitch_scale = 0.8
	sfx_player.play()
	panel_map.hide()
	panel_lawan.hide()
	panel_multiplayer.hide()
	panel_utama.show()

func _ke_menu_multiplayer():
	sfx_player.stream = suara_hover
	sfx_player.pitch_scale = 1.5
	sfx_player.play()
	panel_utama.hide()
	panel_multiplayer.show()

func _ke_local_play():
	sfx_player.stream = suara_hover
	sfx_player.pitch_scale = 1.0
	sfx_player.play()
	get_tree().change_scene_to_file("res://LocalPlay.tscn")

func _mulai_terjun_ke_game(pilihan: String):
	panel_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sfx_player.stream = suara_boom
	sfx_player.pitch_scale = 1.0
	sfx_player.play()
	
	# EMIT SIGNAL MEMBAWA DATA PETA, JUMLAH LAWAN AI & PANJANG PERTANDINGAN
	mulai_game.emit(pilihan, jumlah_ai_dipilih, quick_dipilih)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(latar_belakang, "modulate:a", 0.0, 1.0)
	tw.tween_property(judul, "modulate:a", 0.0, 1.0)
	tw.tween_property(panel_map, "modulate:a", 0.0, 1.0)
	for b in [bar_profil, tombol_misi]:
		if b != null:
			tw.tween_property(b, "modulate:a", 0.0, 1.0)
	await tw.finished
	queue_free()

func _racik_efek_suara():
	# 1. Suara Tick Cepat untuk Hover
	suara_hover = AudioStreamWAV.new()
	suara_hover.format = AudioStreamWAV.FORMAT_16_BITS
	suara_hover.mix_rate = 44100
	var data_h = PackedByteArray()
	for i in range(int(44100 * 0.05)):
		var env = 1.0 - (i / float(44100 * 0.05))
		var val = int(sin(i / 44100.0 * TAU * 800.0) * env * 8000)
		data_h.append(val & 0xFF)
		data_h.append((val >> 8) & 0xFF)
	suara_hover.data = data_h
	
	# 2. Suara Boom/Swoosh Angin untuk Eksekusi Play
	suara_boom = AudioStreamWAV.new()
	suara_boom.format = AudioStreamWAV.FORMAT_16_BITS
	suara_boom.mix_rate = 44100
	var data_b = PackedByteArray()
	for i in range(int(44100 * 1.5)):
		var env = exp(-i / 15000.0)
		var freq = max(30.0, 200.0 - (i / 150.0))
		var noise = randf_range(-1.0, 1.0) * env * 0.4 # Efek tiupan angin
		var bass = sin(i / 44100.0 * TAU * freq) * env * 0.6
		var val = int(clamp(bass + noise, -1.0, 1.0) * 20000)
		data_b.append(val & 0xFF)
		data_b.append((val >> 8) & 0xFF)
	suara_boom.data = data_b

func _buka_menu_seting():
	sfx_player.stream = suara_hover
	sfx_player.play()
	var script_seting = preload("res://menu_grafis.gd")
	add_child(script_seting.new())

func _proses_tombol_peta(pilihan: String):
	# Fase 1: tanpa iklan wajib -- solo langsung dimulai, dengan atau tanpa internet
	# (kebijakan AdMob: iklan berhadiah harus pilihan pemain dan menolaknya tidak
	# boleh menghalangi pemakaian aplikasi).
	# Fase 4 (A6/K6): SELECT STAGE -> layar ROLE -> START (dulu STAGE langsung
	# memulai permainan). Penjaga ketuk dua kali dipindah ke _role_terbuka --
	# _sudah_mulai baru dipakai sesudah START ditekan di layar ROLE.
	if _sudah_mulai or _role_terbuka:
		return
	_role_terbuka = true
	sfx_player.stream = suara_hover
	sfx_player.play()
	_buka_layar_role(pilihan)

func _buka_layar_role(pilihan: String) -> void:
	# Layar ROLE sudah memilih role & jebakan TERAKHIR dari profil (kalau ada),
	# jadi biasanya cukup tekan START; pertama kali main (role_terakhir == "")
	# START mati sampai memilih (ditangani ui_role.gd sendiri).
	var level_pemain = ProfilPemain.level_sekarang()
	var role0 = ProfilPemain.role_terakhir
	var konteks = {
		"role": role0,
		"jebakan": ProfilPemain.jebakan_role.get(role0, []),
		"jumlah_jenis": DataRole.slot_jebakan_solo(level_pemain),
		"teks_tombol": "START",
		"petunjuk_level": true,
		"boleh_batal": true,
		"batal": func(): _role_terbuka = false,
		"lapisan": 11,
	}
	UiRole.buka_pilih_role(self, konteks, func(role: String, jebakan: Array):
		ProfilPemain.role_terakhir = role
		ProfilPemain.jebakan_role[role] = jebakan
		ProfilPemain.simpan()
		_mulai_sesudah_role(pilihan)
	)

func _mulai_sesudah_role(pilihan: String) -> void:
	# Penjaga ketuk dua kali: mouse_filter panel TIDAK menghalangi tombol anaknya, dan
	# tanpa jeda iklan ketukan kedua selama fade 1 dtk memulai permainan dua kali.
	if _sudah_mulai:
		return
	_sudah_mulai = true
	panel_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fase 2: bar profil & MISSIONS tidak boleh dibuka selama menu memudar.
	for b in [bar_profil, tombol_misi]:
		if b != null:
			b.disabled = true
	panel_map.get_child(0).text = "- STARTING... -"
	sfx_player.stream = suara_hover
	sfx_player.play()
	# KIRIMKAN PILIHAN PETA KE PEMAIN.GD
	_mulai_terjun_ke_game(pilihan)
