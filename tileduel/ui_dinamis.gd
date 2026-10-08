class_name UiDinamis
extends RefCounted
## Dipindah dari pemain.gd (Fase 2 - pemecahan file, giliran 1 dari 2).
## Baru berisi 3 fungsi yang paling sedikit ketergantungannya ke pemain.gd.
## Sisanya (_setup_ui_elegan, _buat_tombol_jebakan_via_kode, _munculkan_ui_cabang,
## _munculkan_ui_pilih_target) menyusul di giliran berikutnya karena lebih rumit.

static func upgrade_ke_richtext(node_lama, gaya):
	if node_lama is Label:
		var rtf = RichTextLabel.new()
		rtf.bbcode_enabled = true
		rtf.clip_contents = false
		rtf.layout_mode = node_lama.layout_mode
		rtf.anchors_preset = node_lama.anchors_preset
		rtf.position = node_lama.position
		rtf.size = node_lama.size

		rtf.fit_content = true
		rtf.autowrap_mode = TextServer.AUTOWRAP_OFF

		if node_lama.has_theme_font_size_override("font_size"):
			rtf.add_theme_font_size_override("normal_font_size", node_lama.get_theme_font_size("font_size"))
		else:
			rtf.add_theme_font_size_override("normal_font_size", 24)

		rtf.add_theme_stylebox_override("normal", gaya)
		node_lama.get_parent().add_child(rtf)
		node_lama.hide()
		return rtf
	elif node_lama is RichTextLabel:
		node_lama.bbcode_enabled = true
		node_lama.fit_content = true
		node_lama.autowrap_mode = TextServer.AUTOWRAP_OFF
		node_lama.add_theme_stylebox_override("normal", gaya)
		return node_lama

	return node_lama

static func buka_menu_jeda(main_node: Node) -> void:
	var canvas_jeda = CanvasLayer.new()
	canvas_jeda.layer = 105 # Pastikan di atas layer gameplay biasa

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_jeda.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 25)
	canvas_jeda.add_child(vbox)

	var judul = Label.new()
	judul.text = "GAME PAUSED"
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judul.add_theme_font_size_override("font_size", 40)
	judul.add_theme_color_override("font_outline_color", Color.BLACK)
	judul.add_theme_constant_override("outline_size", 8)
	vbox.add_child(judul)

	# --- TOMBOL 1: GRAPHICS SETTINGS ---
	var btn_grafis = Button.new()
	btn_grafis.text = "GRAPHICS SETTINGS"
	btn_grafis.custom_minimum_size = Vector2(350, 65)
	btn_grafis.add_theme_font_size_override("font_size", 22)
	btn_grafis.pressed.connect(func():
		var script_seting = preload("res://menu_grafis.gd")
		var menu_grafis_node = script_seting.new()
		main_node.get_tree().current_scene.add_child(menu_grafis_node)
		canvas_jeda.queue_free()
	)
	vbox.add_child(btn_grafis)

	# --- TOMBOL 2: EXIT TO MAIN MENU ---
	var btn_exit = Button.new()
	btn_exit.text = "EXIT TO MAIN MENU"
	btn_exit.custom_minimum_size = Vector2(350, 65)
	btn_exit.add_theme_font_size_override("font_size", 22)
	btn_exit.pressed.connect(func():
		keluar_ke_main_menu(main_node)
	)
	vbox.add_child(btn_exit)

	# --- TOMBOL 3: RESUME ---
	var btn_resume = Button.new()
	btn_resume.text = "RESUME GAME"
	btn_resume.custom_minimum_size = Vector2(350, 65)
	btn_resume.add_theme_font_size_override("font_size", 22)
	btn_resume.pressed.connect(func():
		canvas_jeda.queue_free()
	)
	vbox.add_child(btn_resume)

	# --- Gaya/Style Tombol Cepat ---
	for btn in [btn_grafis, btn_exit, btn_resume]:
		var style = StyleBoxFlat.new()
		if btn == btn_exit: style.bg_color = Color(0.8, 0.2, 0.2)
		elif btn == btn_resume: style.bg_color = Color(0.4, 0.4, 0.4)
		else: style.bg_color = Color(0.2, 0.4, 0.6)

		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_right = 12
		style.corner_radius_bottom_left = 12
		style.border_width_bottom = 5
		style.border_color = style.bg_color.darkened(0.4)
		btn.add_theme_stylebox_override("normal", style)

		var style_hover = style.duplicate()
		style_hover.bg_color = style.bg_color.lightened(0.2)
		btn.add_theme_stylebox_override("hover", style_hover)

	main_node.get_tree().current_scene.add_child(canvas_jeda)

static func keluar_ke_main_menu(main_node: Node) -> void:
	# Di multiplayer scene TIDAK boleh langsung dimuat ulang: peran jaringan
	# disimpan di autoload StatusJaringan dan koneksi ENet menempel di SceneTree,
	# jadi keduanya selamat dari reload. Akibatnya pemain.gd melihat peran masih
	# "host"/"client" lalu langsung memulai permainan baru — itulah yang selama ini
	# terlihat seperti "restart". Putuskan sesinya dulu, baru muat ulang; dengan
	# peran kosong pemain.gd masuk ke jalur solo, yaitu main menu.
	if StatusJaringan.peran_multiplayer != "":
		StatusJaringan.keluar_dari_sesi()
	main_node.get_tree().reload_current_scene()

# ========================================================
# PANEL SYARAT MENANG (sebelum permainan dimulai)
# ========================================================
static func tampilkan_panel_syarat_menang(main_node: Node, baris: Array, tawaran_iklan: bool = false) -> CanvasLayer:
	var canvas = CanvasLayer.new()
	canvas.layer = 106

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 16)
	canvas.add_child(vbox)

	var judul = Label.new()
	judul.text = "HOW TO WIN"
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judul.add_theme_font_size_override("font_size", 46)
	judul.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	judul.add_theme_color_override("font_outline_color", Color.BLACK)
	judul.add_theme_constant_override("outline_size", 8)
	vbox.add_child(judul)

	for isi in baris:
		var lbl = Label.new()
		lbl.text = "•  " + str(isi)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 25)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 5)
		vbox.add_child(lbl)

	var status = Label.new()
	status.text = ""
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(status)
	canvas.set_meta("label_status", status)

	# Fase 1 (solo): iklan berhadiah PILIHAN pemain -- menolak tidak menghalangi apa pun.
	if tawaran_iklan:
		var btn_iklan = Button.new()
		btn_iklan.text = "WATCH AD: FREE CARD"
		btn_iklan.custom_minimum_size = Vector2(350, 60)
		btn_iklan.add_theme_font_size_override("font_size", 22)
		_gaya_tombol(btn_iklan, Color(0.75, 0.55, 0.1))
		btn_iklan.pressed.connect(func():
			btn_iklan.disabled = true
			btn_iklan.hide()
			main_node._tonton_iklan_kartu_awal(canvas)
		)
		vbox.add_child(btn_iklan)
		canvas.set_meta("tombol_iklan", btn_iklan)

	var btn = Button.new()
	btn.text = "START GAME"
	btn.custom_minimum_size = Vector2(350, 68)
	btn.add_theme_font_size_override("font_size", 24)
	_gaya_tombol(btn, Color(0.15, 0.55, 0.25))
	btn.pressed.connect(func():
		btn.disabled = true
		main_node.emit_signal("siap_mulai_diklik")
	)
	vbox.add_child(btn)
	canvas.set_meta("tombol_mulai", btn)

	main_node.get_tree().current_scene.add_child(canvas)
	return canvas

static func tandai_menunggu_lawan(panel: CanvasLayer, teks: String) -> void:
	# Dipakai di multiplayer: tombol START sudah ditekan di device ini, tinggal
	# menunggu device satunya.
	if not is_instance_valid(panel):
		return
	var status = panel.get_meta("label_status", null)
	if status and is_instance_valid(status):
		status.text = teks

# ========================================================
# FASE 1: TAWARAN IKLAN BERHADIAH SAAT HUTANG (solo)
# Mengembalikan true kalau pemain memilih menonton iklan.
# ========================================================
static func tanya_iklan_hutang(main_node: Node) -> bool:
	var canvas = CanvasLayer.new()
	canvas.layer = 107

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 18)
	canvas.add_child(vbox)

	var judul = Label.new()
	judul.text = "IN DEBT!"
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judul.add_theme_font_size_override("font_size", 44)
	judul.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	judul.add_theme_color_override("font_outline_color", Color.BLACK)
	judul.add_theme_constant_override("outline_size", 8)
	vbox.add_child(judul)

	var ket = Label.new()
	ket.text = "Watch an ad to get +300 coins?"
	ket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ket.add_theme_font_size_override("font_size", 24)
	vbox.add_child(ket)

	var hasil = [null]
	var btn_ya = Button.new()
	btn_ya.text = "WATCH AD: +300 COINS"
	btn_ya.custom_minimum_size = Vector2(350, 64)
	btn_ya.add_theme_font_size_override("font_size", 22)
	_gaya_tombol(btn_ya, Color(0.75, 0.55, 0.1))
	vbox.add_child(btn_ya)

	var btn_tidak = Button.new()
	btn_tidak.text = "NO THANKS"
	btn_tidak.custom_minimum_size = Vector2(350, 64)
	btn_tidak.add_theme_font_size_override("font_size", 22)
	_gaya_tombol(btn_tidak, Color(0.4, 0.4, 0.4))
	vbox.add_child(btn_tidak)

	# Ketukan pertama mengunci kedua tombol (ketuk dua kali tidak dihitung lagi).
	var pilih = func(nilai: bool):
		if hasil[0] != null:
			return
		hasil[0] = nilai
		btn_ya.disabled = true
		btn_tidak.disabled = true
	btn_ya.pressed.connect(pilih.bind(true))
	btn_tidak.pressed.connect(pilih.bind(false))

	var tree = main_node.get_tree()
	tree.current_scene.add_child(canvas)
	while hasil[0] == null and is_instance_valid(canvas):
		await tree.process_frame
	if is_instance_valid(canvas):
		canvas.queue_free()
	return hasil[0] == true

# ========================================================
# FASE 1: QUICK MATCH -- label ronde di bawah TeksDadu & spanduk besar
# ========================================================
static func buat_label_ronde(main_node: Node) -> RichTextLabel:
	var gaya = StyleBoxFlat.new()
	gaya.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	gaya.set_border_width_all(1)
	gaya.border_width_bottom = 3
	gaya.border_color = Color(1.0, 0.85, 0.2)
	gaya.set_corner_radius_all(10)
	gaya.content_margin_left = 16
	gaya.content_margin_right = 16
	gaya.content_margin_top = 4
	gaya.content_margin_bottom = 4

	var l = RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_stylebox_override("normal", gaya)
	l.add_theme_font_size_override("normal_font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	# Di tengah atas, tepat di bawah TeksDadu (di antara panel koin kiri & kanan).
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.offset_left = -100
	l.offset_right = 100
	l.offset_top = 88
	l.hide()
	main_node.teks_dadu.get_parent().add_child(l)
	return l

static func tampilkan_spanduk(main_node: Node, teks: String, warna: Color) -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 104
	var l = Label.new()
	l.text = teks
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 72)
	l.add_theme_color_override("font_color", warna)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 12)
	l.modulate.a = 0.0
	canvas.add_child(l)
	main_node.get_tree().current_scene.add_child(canvas)
	var tw = l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.3)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(canvas.queue_free)

# ========================================================
# AKHIR PERMAINAN: ANIMASI MENANG/KALAH + PAPAN PERINGKAT
# Animasi dibuat dari bentuk 2D sederhana yang digerakkan tween -- bukan sistem
# partikel -- supaya tidak ada shader baru yang harus disusun tepat di detik
# kemenangan (itu yang bikin HP lemah nge-lag di efek-efek sebelumnya).
# ========================================================
const DURASI_ANIMASI_AKHIR := 3.0

static func tampilkan_akhir_permainan(main_node: Node, menang: bool, papan_skor: Array, ringkasan: Dictionary = {}) -> void:
	var tingkat = AudioGrafis.baca_tingkat()
	var ukuran = main_node.get_viewport().get_visible_rect().size

	var canvas = CanvasLayer.new()
	canvas.layer = 110
	main_node.get_tree().current_scene.add_child(canvas)

	if menang:
		_efek_kembang_api(canvas, tingkat, ukuran)
	else:
		_efek_hujan_petir(canvas, tingkat, ukuran)

	var judul = Label.new()
	judul.text = "CONGRATULATIONS\nYOU WIN!" if menang else "SORRY\nYOU LOSE"
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judul.set_anchors_preset(Control.PRESET_CENTER)
	judul.grow_horizontal = Control.GROW_DIRECTION_BOTH
	judul.grow_vertical = Control.GROW_DIRECTION_BOTH
	judul.add_theme_font_size_override("font_size", 64 if menang else 58)
	judul.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25) if menang else Color(0.75, 0.82, 1.0))
	judul.add_theme_color_override("font_outline_color", Color.BLACK)
	judul.add_theme_constant_override("outline_size", 12)
	judul.pivot_offset = Vector2(0, 0)
	canvas.add_child(judul)

	judul.scale = Vector2(0.3, 0.3) if menang else Vector2(1.25, 1.25)
	var tw_judul = judul.create_tween()
	tw_judul.tween_property(judul, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await main_node.get_tree().create_timer(DURASI_ANIMASI_AKHIR).timeout

	if is_instance_valid(canvas):
		canvas.queue_free()
	# Tombol ⚙ -> EXIT selama animasi memuat ulang adegan: jangan tampilkan iklan /
	# papan peringkat untuk adegan yang sudah dibuang.
	if not is_instance_valid(main_node) or not main_node.is_inside_tree():
		return
	# Fase 2: interstisial pindah ke tombol EXIT papan peringkat (setelah kartu hadiah
	# & tawaran DOUBLE REWARDS) -- lihat _panel_papan_skor.
	_panel_papan_skor(main_node, menang, papan_skor, ringkasan)

static func _efek_kembang_api(canvas: CanvasLayer, tingkat: String, ukuran: Vector2) -> void:
	var latar = ColorRect.new()
	latar.color = Color(0, 0, 0, 0.35)
	latar.set_anchors_preset(Control.PRESET_FULL_RECT)
	latar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(latar)

	var jumlah_roket = 8
	var percikan = 24
	match tingkat:
		"sangat_rendah":
			jumlah_roket = 3
			percikan = 8
		"rendah":
			jumlah_roket = 4
			percikan = 12
		"sedang":
			jumlah_roket = 6
			percikan = 18

	var warna_pilihan = [Color(1.0, 0.85, 0.25), Color(1.0, 0.45, 0.45), Color(0.45, 0.8, 1.0), Color(0.6, 1.0, 0.55)]
	for r in range(jumlah_roket):
		var pusat = Vector2(randf_range(ukuran.x * 0.15, ukuran.x * 0.85), randf_range(ukuran.y * 0.12, ukuran.y * 0.5))
		var warna = warna_pilihan[r % warna_pilihan.size()]
		var jeda = r * ((DURASI_ANIMASI_AKHIR - 1.4) / max(1, jumlah_roket - 1))
		_jadwalkan(canvas, jeda, func():
			_luncurkan_roket(canvas, pusat, warna, percikan, ukuran))

static func _luncurkan_roket(canvas: CanvasLayer, pusat: Vector2, warna: Color, percikan: int, ukuran: Vector2) -> void:
	# Titik kecil yang naik dari bawah layar dulu, baru meledak — tanpa ini
	# percikannya muncul begitu saja di tengah udara.
	if not is_instance_valid(canvas):
		return
	var roket = Polygon2D.new()
	roket.polygon = _poligon_lingkaran(6.0, 8)
	roket.color = warna
	roket.position = Vector2(pusat.x, ukuran.y + 20.0)
	canvas.add_child(roket)

	var tw = roket.create_tween()
	tw.tween_property(roket, "position", pusat, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(roket): roket.queue_free()
		_ledakkan_kembang_api(canvas, pusat, warna, percikan)
	)

static func _ledakkan_kembang_api(canvas: CanvasLayer, pusat: Vector2, warna: Color, jumlah: int) -> void:
	if not is_instance_valid(canvas):
		return
	for i in range(jumlah):
		var titik = Polygon2D.new()
		titik.polygon = _poligon_lingkaran(9.0, 8)
		titik.color = warna
		titik.position = pusat
		canvas.add_child(titik)

		var sudut = (TAU * i / jumlah) + randf_range(-0.12, 0.12)
		var jarak = randf_range(90.0, 200.0)
		var tujuan = pusat + Vector2(cos(sudut), sin(sudut)) * jarak + Vector2(0, 55)

		var tw = titik.create_tween().set_parallel(true)
		tw.tween_property(titik, "position", tujuan, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(titik, "scale", Vector2(0.45, 0.45), 1.1)
		tw.tween_property(titik, "modulate:a", 0.0, 0.8).set_delay(0.35)
		tw.tween_callback(func():
			if is_instance_valid(titik): titik.queue_free()
		).set_delay(1.15)

static func _efek_hujan_petir(canvas: CanvasLayer, tingkat: String, ukuran: Vector2) -> void:
	var latar = ColorRect.new()
	latar.color = Color(0.02, 0.03, 0.09, 0.6)
	latar.set_anchors_preset(Control.PRESET_FULL_RECT)
	latar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(latar)

	var jumlah_tetes = 150
	var jumlah_kilat = 3
	match tingkat:
		"sangat_rendah":
			jumlah_tetes = 30
			jumlah_kilat = 1
		"rendah":
			jumlah_tetes = 60
			jumlah_kilat = 2
		"sedang":
			jumlah_tetes = 110
			jumlah_kilat = 3

	for i in range(jumlah_tetes):
		var tetes = ColorRect.new()
		tetes.color = Color(0.75, 0.83, 1.0, 0.7)
		tetes.size = Vector2(3.0, randf_range(16.0, 30.0))
		tetes.rotation = deg_to_rad(14)
		tetes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tetes.position = Vector2(randf_range(-ukuran.x * 0.2, ukuran.x), randf_range(-ukuran.y, ukuran.y * 0.9))
		canvas.add_child(tetes)

		var durasi = randf_range(0.45, 0.85)
		var tw = tetes.create_tween().set_loops()
		tw.tween_property(tetes, "position", tetes.position + Vector2(ukuran.y * 0.25, ukuran.y + 60.0), durasi)
		tw.tween_callback(func():
			if is_instance_valid(tetes):
				tetes.position = Vector2(randf_range(-ukuran.x * 0.2, ukuran.x), -40.0)
		)

	var kilat = ColorRect.new()
	kilat.color = Color(1, 1, 1, 0.0)
	kilat.set_anchors_preset(Control.PRESET_FULL_RECT)
	kilat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(kilat)

	for k in range(jumlah_kilat):
		var jeda = 0.35 + k * 0.95
		_jadwalkan(canvas, jeda, func():
			if not is_instance_valid(kilat):
				return
			var tw_kilat = kilat.create_tween()
			tw_kilat.tween_property(kilat, "color:a", 0.7, 0.06)
			tw_kilat.tween_property(kilat, "color:a", 0.0, 0.22)
			tw_kilat.tween_property(kilat, "color:a", 0.45, 0.05)
			tw_kilat.tween_property(kilat, "color:a", 0.0, 0.3))

static func _jadwalkan(canvas: CanvasLayer, detik: float, aksi: Callable) -> void:
	# Timer dipasang sebagai ANAK canvas. Kalau canvas-nya dibuang lebih dulu
	# (animasi selesai / permainan ditutup), timernya ikut mati -- tidak ada lagi
	# callback yang menyentuh node yang sudah dihapus.
	var t = Timer.new()
	t.one_shot = true
	t.wait_time = max(0.05, detik)
	canvas.add_child(t)
	t.timeout.connect(aksi)
	t.start()

static func _poligon_lingkaran(radius: float, sisi: int) -> PackedVector2Array:
	var titik = PackedVector2Array()
	for i in range(sisi):
		var sudut = TAU * i / sisi
		titik.append(Vector2(cos(sudut), sin(sudut)) * radius)
	return titik

static func _panel_papan_skor(main_node: Node, menang: bool, papan_skor: Array, ringkasan: Dictionary = {}) -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 111

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	# Fase 2: isi di tengah area DI ATAS tombol EXIT -- tombol EXIT kini terpasang tetap di
	# bawah layar, supaya tidak pernah terdorong keluar layar oleh kartu hadiah.
	var tengah = CenterContainer.new()
	tengah.set_anchors_preset(Control.PRESET_FULL_RECT)
	tengah.offset_bottom = -110
	canvas.add_child(tengah)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	tengah.add_child(vbox)

	var judul = Label.new()
	judul.text = "YOU WIN!" if menang else "YOU LOSE"
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judul.add_theme_font_size_override("font_size", 40)
	judul.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if menang else Color(0.75, 0.82, 1.0))
	judul.add_theme_color_override("font_outline_color", Color.BLACK)
	judul.add_theme_constant_override("outline_size", 8)
	vbox.add_child(judul)

	var sub = Label.new()
	sub.text = "FINAL STANDINGS"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	vbox.add_child(sub)

	# QUICK MATCH: peringkat menurut kekayaan (koin + petak + menara).
	var quick = bool(main_node.get("mode_quick"))
	if quick:
		var ket_total = Label.new()
		ket_total.text = "Total = coins + tiles + towers"
		ket_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ket_total.add_theme_font_size_override("font_size", 18)
		ket_total.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		vbox.add_child(ket_total)

	# Fase 2: dua kolom -- kiri peringkat (+ penghargaan tiap pemain), kanan kartu hadiah.
	var dua_kolom = HBoxContainer.new()
	dua_kolom.alignment = BoxContainer.ALIGNMENT_CENTER
	dua_kolom.add_theme_constant_override("separation", 36)
	vbox.add_child(dua_kolom)
	var banyak = papan_skor.size() > 3 # 4 pemain: huruf sedikit lebih kecil supaya muat 720 px
	var kolom_kiri = VBoxContainer.new()
	kolom_kiri.add_theme_constant_override("separation", 8 if banyak else 12)
	kolom_kiri.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dua_kolom.add_child(kolom_kiri)

	for i in range(papan_skor.size()):
		var data = papan_skor[i]
		var slot_baris = int(data["slot"])
		var nama = "YOU" if slot_baris == main_node.slot_lokal else "ENEMY"
		if main_node.daftar_pemain.size() > 2:
			nama = "YOU (P%d)" % (slot_baris + 1) if slot_baris == main_node.slot_lokal else "P%d" % (slot_baris + 1)
		var baris = Label.new()
		if quick:
			baris.text = "%d.  %s  —  %d total" % [i + 1, nama, int(data.get("kekayaan", data["uang"]))]
		else:
			baris.text = "%d.  %s  —  %d coins" % [i + 1, nama, int(data["uang"])]
		baris.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		baris.add_theme_font_size_override("font_size", 28 if banyak else 32)
		baris.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if i == 0 else Color.WHITE)
		baris.add_theme_color_override("font_outline_color", Color.BLACK)
		baris.add_theme_constant_override("outline_size", 6)
		kolom_kiri.add_child(baris)

		var detail = Label.new()
		if quick:
			detail.text = "coins %d    tiles %d    stars %d    gems %d" % [int(data["uang"]), int(data["petak"]), int(data["bintang"]), int(data["permata"])]
		else:
			detail.text = "tiles %d    stars %d    gems %d" % [int(data["petak"]), int(data["bintang"]), int(data["permata"])]
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail.add_theme_font_size_override("font_size", 18 if banyak else 20)
		detail.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		kolom_kiri.add_child(detail)

		# Fase 2: penghargaan akhir milik pemain di baris ini (juga AI).
		var daftar_penghargaan: Array = data.get("penghargaan", [])
		if not daftar_penghargaan.is_empty():
			var lbl_penghargaan = Label.new()
			lbl_penghargaan.text = UiProfil.teks_penghargaan(daftar_penghargaan)
			lbl_penghargaan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl_penghargaan.add_theme_font_size_override("font_size", 16)
			lbl_penghargaan.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			kolom_kiri.add_child(lbl_penghargaan)

	if not ringkasan.is_empty():
		dua_kolom.add_child(UiProfil.buat_kartu_hadiah(main_node, ringkasan, canvas))

	var btn_exit = Button.new()
	btn_exit.text = "EXIT TO MAIN MENU"
	btn_exit.custom_minimum_size = Vector2(350, 68)
	btn_exit.add_theme_font_size_override("font_size", 24)
	_gaya_tombol(btn_exit, Color(0.8, 0.2, 0.2))
	btn_exit.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 24)
	btn_exit.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_exit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	btn_exit.pressed.connect(func():
		btn_exit.disabled = true
		# Fase 2: interstisial di sini (jeda alami sebelum kembali ke menu). Panel turun ke
		# bawah layer 100 selama iklan -- iklan TIRUAN plugin AdMob <= 5.1 di editor ada di
		# layer 100. Kalau pemain baru menonton DOUBLE, jeda 3 menit melewatkannya.
		canvas.layer = 99
		await PengelolaIklan.tampilkan_interstisial_akhir_match()
		if is_instance_valid(main_node) and main_node.is_inside_tree():
			keluar_ke_main_menu(main_node)
	)
	canvas.add_child(btn_exit)

	main_node.get_tree().current_scene.add_child(canvas)

static func tampilkan_panel_lawan_keluar(main_node: Node) -> void:
	# Muncul di device yang MASIH hidup ketika lawannya keluar/putus koneksi.
	var canvas = CanvasLayer.new()
	canvas.layer = 112

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 18)
	canvas.add_child(vbox)

	var judul = Label.new()
	judul.text = "OPPONENT LEFT"
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judul.add_theme_font_size_override("font_size", 44)
	judul.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	judul.add_theme_color_override("font_outline_color", Color.BLACK)
	judul.add_theme_constant_override("outline_size", 8)
	vbox.add_child(judul)

	var ket = Label.new()
	ket.text = "The other device is no longer connected."
	ket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ket.add_theme_font_size_override("font_size", 24)
	vbox.add_child(ket)

	var btn_ai = Button.new()
	btn_ai.text = "CONTINUE VS AI"
	btn_ai.custom_minimum_size = Vector2(350, 68)
	btn_ai.add_theme_font_size_override("font_size", 24)
	_gaya_tombol(btn_ai, Color(0.2, 0.45, 0.7))
	btn_ai.pressed.connect(func():
		canvas.queue_free()
		main_node.lanjutkan_dengan_ai()
	)
	vbox.add_child(btn_ai)

	var btn_exit = Button.new()
	btn_exit.text = "EXIT TO MAIN MENU"
	btn_exit.custom_minimum_size = Vector2(350, 68)
	btn_exit.add_theme_font_size_override("font_size", 24)
	_gaya_tombol(btn_exit, Color(0.8, 0.2, 0.2))
	btn_exit.pressed.connect(func():
		keluar_ke_main_menu(main_node)
	)
	vbox.add_child(btn_exit)

	var ket2 = Label.new()
	ket2.text = "AI continues with all tiles, towers and coins already on the board."
	ket2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ket2.add_theme_font_size_override("font_size", 18)
	ket2.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(ket2)

	main_node.get_tree().current_scene.add_child(canvas)

# ========================================================
# PANEL MIGRASI HOST -- satu panel untuk semua keadaan (HOST LEFT, YOU ARE THE
# NEW HOST, CONNECTION LOST, WAITING FOR PLAYERS). Isinya diatur pemain.gd lewat
# atur_panel_migrasi; tombol hijau berganti arti sesuai keadaan.
# ========================================================
static func buat_panel_migrasi(main_node: Node) -> CanvasLayer:
	var canvas = CanvasLayer.new()
	canvas.layer = 113

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.add_theme_constant_override("separation", 14)
	canvas.add_child(vbox)

	var judul = Label.new()
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judul.add_theme_font_size_override("font_size", 42)
	judul.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	judul.add_theme_color_override("font_outline_color", Color.BLACK)
	judul.add_theme_constant_override("outline_size", 8)
	vbox.add_child(judul)

	var ket = Label.new()
	ket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ket.add_theme_font_size_override("font_size", 21)
	vbox.add_child(ket)

	var daftar = RichTextLabel.new()
	daftar.bbcode_enabled = true
	daftar.fit_content = true
	daftar.scroll_active = false
	daftar.custom_minimum_size = Vector2(560, 0)
	daftar.add_theme_font_size_override("normal_font_size", 28)
	vbox.add_child(daftar)

	var status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(status)

	var btn_utama = Button.new()
	btn_utama.custom_minimum_size = Vector2(350, 64)
	btn_utama.add_theme_font_size_override("font_size", 24)
	_gaya_tombol(btn_utama, Color(0.15, 0.55, 0.25))
	btn_utama.pressed.connect(func(): main_node._tekan_tombol_utama_migrasi())
	vbox.add_child(btn_utama)

	var catatan = Label.new()
	catatan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	catatan.add_theme_font_size_override("font_size", 17)
	catatan.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	vbox.add_child(catatan)

	var btn_sendiri = Button.new()
	btn_sendiri.text = "PLAY ALONE VS AI"
	btn_sendiri.custom_minimum_size = Vector2(350, 64)
	btn_sendiri.add_theme_font_size_override("font_size", 24)
	_gaya_tombol(btn_sendiri, Color(0.2, 0.45, 0.7))
	btn_sendiri.pressed.connect(func(): main_node.lanjut_sendiri_dari_migrasi())
	vbox.add_child(btn_sendiri)

	var btn_exit = Button.new()
	btn_exit.text = "EXIT TO MAIN MENU"
	btn_exit.custom_minimum_size = Vector2(350, 64)
	btn_exit.add_theme_font_size_override("font_size", 24)
	_gaya_tombol(btn_exit, Color(0.8, 0.2, 0.2))
	btn_exit.pressed.connect(func(): keluar_ke_main_menu(main_node))
	vbox.add_child(btn_exit)

	canvas.set_meta("judul", judul)
	canvas.set_meta("ket", ket)
	canvas.set_meta("daftar", daftar)
	canvas.set_meta("status", status)
	canvas.set_meta("tombol_utama", btn_utama)
	canvas.set_meta("catatan", catatan)
	main_node.get_tree().current_scene.add_child(canvas)
	return canvas

static func atur_panel_migrasi(panel: CanvasLayer, isi: Dictionary) -> void:
	# isi: judul, ket, daftar (bbcode), status, tombol_utama, catatan. Yang kosong
	# disembunyikan.
	if not is_instance_valid(panel):
		return
	var btn: Button = panel.get_meta("tombol_utama")
	var teks_tombol = str(isi.get("tombol_utama", ""))
	if btn.text != "" and teks_tombol != "" and btn.text != teks_tombol:
		# Arti tombol hijau baru saja berganti (mis. BECOME HOST -> START NOW):
		# ketukan kedua yang tidak sengaja jangan langsung menjalankan arti barunya.
		btn.disabled = true
		panel.get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(btn):
				btn.disabled = false
		)
	for kunci in ["judul", "ket", "daftar", "status", "catatan", "tombol_utama"]:
		var node = panel.get_meta(kunci)
		node.text = str(isi.get(kunci, ""))
		node.visible = node.text != ""

static func _gaya_tombol(btn: Button, warna: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = warna
	style.set_corner_radius_all(12)
	style.border_width_bottom = 5
	style.border_color = warna.darkened(0.4)
	btn.add_theme_stylebox_override("normal", style)
	var style_hover = style.duplicate()
	style_hover.bg_color = warna.lightened(0.2)
	btn.add_theme_stylebox_override("hover", style_hover)
	var style_mati = style.duplicate()
	style_mati.bg_color = warna.darkened(0.5)
	btn.add_theme_stylebox_override("disabled", style_mati)

static func buat_ui_cabang_dasar(main_node: Node) -> void:
	main_node.panel_ui_cabang = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	main_node.panel_ui_cabang.add_theme_stylebox_override("panel", style)
	main_node.panel_ui_cabang.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_node.panel_ui_cabang.hide()

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 40)
	main_node.panel_ui_cabang.add_child(vbox)

	var label = Label.new()
	label.text = "PILIH ARAH LANGKAH!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 45)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	vbox.add_child(label)

	# SIMPAN REFERENSI LANGSUNG, BEBAS DARI EROR PATH
	main_node.wadah_tombol_cabang = HBoxContainer.new()
	main_node.wadah_tombol_cabang.alignment = BoxContainer.ALIGNMENT_CENTER
	main_node.wadah_tombol_cabang.add_theme_constant_override("separation", 30)
	vbox.add_child(main_node.wadah_tombol_cabang)

	main_node.teks_dadu.get_parent().call_deferred("add_child", main_node.panel_ui_cabang)

static func buat_tombol_jebakan_via_kode(main_node: Node) -> void:
	var vbox = main_node.get_node("../CanvasLayer/MenuAksi/VBoxContainer")

	main_node.tombol_set_trap = Button.new()
	main_node.tombol_set_trap.name = "TombolSetTrap"
	main_node.tombol_set_trap.pressed.connect(main_node._on_tombol_set_trap_pressed)
	vbox.add_child(main_node.tombol_set_trap)

	main_node.tombol_gunakan_kartu = Button.new()
	main_node.tombol_gunakan_kartu.name = "TombolGunakanKartu"
	main_node.tombol_gunakan_kartu.pressed.connect(main_node._on_tombol_gunakan_kartu_pressed)
	vbox.add_child(main_node.tombol_gunakan_kartu)

	main_node.tombol_trap_air = Button.new()
	main_node.tombol_trap_air.name = "TombolTrapAir"
	main_node.tombol_trap_air.pressed.connect(main_node._on_tombol_air_pressed)
	vbox.add_child(main_node.tombol_trap_air)

	main_node.tombol_trap_api = Button.new()
	main_node.tombol_trap_api.name = "TombolTrapApi"
	main_node.tombol_trap_api.pressed.connect(main_node._on_tombol_api_pressed)
	vbox.add_child(main_node.tombol_trap_api)

	main_node.tombol_trap_tanah = Button.new()
	main_node.tombol_trap_tanah.name = "TombolTrapTanah"
	main_node.tombol_trap_tanah.pressed.connect(main_node._on_tombol_trap_tanah_pressed)
	vbox.add_child(main_node.tombol_trap_tanah)

	main_node.tombol_trap_petir = Button.new()
	main_node.tombol_trap_petir.name = "TombolTrapPetir"
	main_node.tombol_trap_petir.pressed.connect(main_node._on_tombol_trap_petir_pressed)
	vbox.add_child(main_node.tombol_trap_petir)

	main_node.tombol_trap_angin = Button.new()
	main_node.tombol_trap_angin.name = "TombolTrapAngin"
	main_node.tombol_trap_angin.pressed.connect(main_node._on_tombol_angin_pressed)
	vbox.add_child(main_node.tombol_trap_angin)

	main_node.tombol_trap_batal = Button.new()
	main_node.tombol_trap_batal.name = "TombolTrapBatal"
	main_node.tombol_trap_batal.pressed.connect(main_node._on_tombol_trap_batal_pressed)
	vbox.add_child(main_node.tombol_trap_batal)

	# Mencegah eror urutan: Pindah TombolTutup fisik ke paling bawah
	if main_node.tombol_tutup:
		vbox.move_child(main_node.tombol_tutup, -1)

static func setup_ui_elegan(main_node: Node) -> void:
	var gaya_papan = StyleBoxFlat.new()
	gaya_papan.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	gaya_papan.border_width_bottom = 3
	gaya_papan.border_width_top = 1
	gaya_papan.border_width_left = 1
	gaya_papan.border_width_right = 1
	gaya_papan.border_color = Color(1.0, 0.85, 0.2)
	gaya_papan.corner_radius_top_left = 12
	gaya_papan.corner_radius_top_right = 12
	gaya_papan.corner_radius_bottom_right = 12
	gaya_papan.corner_radius_bottom_left = 12

	gaya_papan.content_margin_left = 25
	gaya_papan.content_margin_right = 25
	gaya_papan.content_margin_top = 10
	gaya_papan.content_margin_bottom = 10
	gaya_papan.shadow_color = Color(0, 0, 0, 0.4)
	gaya_papan.shadow_size = 4

	main_node.teks_dadu = upgrade_ke_richtext(main_node.teks_dadu, gaya_papan)
	if main_node.teks_dadu is RichTextLabel:
		main_node.teks_dadu.set_anchors_preset(Control.PRESET_CENTER_TOP)
		main_node.teks_dadu.grow_horizontal = Control.GROW_DIRECTION_BOTH
		main_node.teks_dadu.position.y = 30

	main_node.teks_uang = upgrade_ke_richtext(main_node.teks_uang, gaya_papan)
	main_node.teks_bintang = upgrade_ke_richtext(main_node.teks_bintang, gaya_papan)

	if main_node.teks_bintang != null:
		main_node.teks_bintang.modulate = Color(1, 1, 1, 1)

	if main_node.menu_aksi is Control:
		main_node.menu_aksi.self_modulate = Color(1, 1, 1, 0)
		if main_node.menu_aksi is Panel or main_node.menu_aksi is PanelContainer:
			main_node.menu_aksi.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var vbox = main_node.tombol_beli.get_parent() if main_node.tombol_beli else null
	if vbox and vbox is VBoxContainer:
		vbox.add_theme_constant_override("separation", 18)

	var style_btn_normal = StyleBoxFlat.new()
	style_btn_normal.bg_color = Color(0.12, 0.35, 0.6, 0.95)
	style_btn_normal.border_width_bottom = 5
	style_btn_normal.border_color = Color(0.05, 0.15, 0.3)
	style_btn_normal.corner_radius_top_left = 10
	style_btn_normal.corner_radius_top_right = 10
	style_btn_normal.corner_radius_bottom_right = 10
	style_btn_normal.corner_radius_bottom_left = 10
	style_btn_normal.content_margin_top = 12
	style_btn_normal.content_margin_bottom = 12
	style_btn_normal.shadow_color = Color(0, 0, 0, 0.5)
	style_btn_normal.shadow_size = 4

	var style_btn_hover = style_btn_normal.duplicate()
	style_btn_hover.bg_color = Color(0.2, 0.45, 0.75, 0.95)

	var style_btn_pressed = style_btn_normal.duplicate()
	style_btn_pressed.bg_color = Color(0.08, 0.25, 0.45, 0.95)
	style_btn_pressed.border_width_bottom = 0
	style_btn_pressed.border_width_top = 5

	var style_btn_disabled = style_btn_normal.duplicate()
	style_btn_disabled.bg_color = Color(0.25, 0.25, 0.25, 0.8)
	style_btn_disabled.border_color = Color(0.15, 0.15, 0.15)
	style_btn_disabled.border_width_bottom = 2
	style_btn_disabled.shadow_size = 1

	var daftar_tombol = [main_node.tombol_beli, main_node.tombol_bangun, main_node.tombol_serang, main_node.tombol_tutup, main_node.tombol_tanah, main_node.tombol_petir, main_node.tombol_set_trap, main_node.tombol_trap_air, main_node.tombol_trap_api, main_node.tombol_trap_tanah, main_node.tombol_trap_petir, main_node.tombol_trap_angin, main_node.tombol_trap_batal, main_node.tombol_gunakan_kartu]
	for btn in daftar_tombol:
		if btn and btn is Button:
			btn.add_theme_stylebox_override("normal", style_btn_normal)
			btn.add_theme_stylebox_override("hover", style_btn_hover)
			btn.add_theme_stylebox_override("pressed", style_btn_pressed)
			btn.add_theme_stylebox_override("disabled", style_btn_disabled)

			btn.add_theme_font_size_override("font_size", 20)
			btn.add_theme_constant_override("outline_size", 4)
			btn.add_theme_color_override("font_outline_color", Color.BLACK)

	main_node.tombol_seting = Button.new()
	main_node.tombol_seting.text = "⚙"
	main_node.tombol_seting.custom_minimum_size = Vector2(50, 50)
	main_node.tombol_seting.add_theme_font_size_override("font_size", 28)

	var style_seting = StyleBoxFlat.new()
	style_seting.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style_seting.corner_radius_top_left = 10
	style_seting.corner_radius_top_right = 10
	style_seting.corner_radius_bottom_right = 10
	style_seting.corner_radius_bottom_left = 10
	style_seting.border_width_top = 2
	style_seting.border_width_bottom = 2
	style_seting.border_width_left = 2
	style_seting.border_width_right = 2
	style_seting.border_color = Color(0.8, 0.8, 0.8)
	main_node.tombol_seting.add_theme_stylebox_override("normal", style_seting)

	main_node.tombol_seting.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	main_node.tombol_seting.position = Vector2(-70, 20)

	main_node.tombol_seting.hide()

	main_node.tombol_seting.pressed.connect(buka_menu_jeda.bind(main_node))

	var canvas_utama = main_node.teks_dadu.get_parent()
	canvas_utama.add_child(main_node.tombol_seting)

	main_node.label_fps = Label.new()
	main_node.label_fps.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main_node.label_fps.position = Vector2(20, 20)
	main_node.label_fps.add_theme_font_size_override("font_size", 24)
	main_node.label_fps.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	main_node.label_fps.add_theme_color_override("font_outline_color", Color.BLACK)
	main_node.label_fps.add_theme_constant_override("outline_size", 4)
	main_node.label_fps.hide()

	canvas_utama.add_child(main_node.label_fps)

# Lama pengumuman arah yang dipilih (multiplayer), tampil di KEDUA layar.
const JEDA_UMUMKAN_CABANG := 0.8

static func munculkan_ui_cabang(main_node: Node, petak_cabang: Node3D, mode: String = "", nama_pemilih: String = "") -> void:
	# mode "" = solo (perilaku asli). Multiplayer: "lokal" = pemain di device ini
	# yang memilih, "tonton" = cuma melihat pemain lain memilih (tombol mati).
	# nama_pemilih kosong = permainan 2 pemain (teks lama "ENEMY ...").
	for anak in main_node.wadah_tombol_cabang.get_children():
		# Dilepas dulu (bukan cuma queue_free) supaya urutan tombol baru langsung
		# sesuai indeks arah -- dipakai umumkan_pilihan_cabang.
		main_node.wadah_tombol_cabang.remove_child(anak)
		anak.queue_free()

	var judul = _label_judul_cabang(main_node)
	judul.modulate = Color.WHITE
	var nama_lawan = nama_pemilih if nama_pemilih != "" else "ENEMY"
	judul.text = (nama_lawan + " IS CHOOSING A PATH...") if mode == "tonton" else "PILIH ARAH LANGKAH!"

	for i in range(petak_cabang.referensi_node_selanjutnya.size()):
		var btn = Button.new()
		btn.text = petak_cabang.nama_arah[i]
		btn.add_theme_font_size_override("font_size", 35)
		btn.custom_minimum_size = Vector2(200, 80)
		btn.disabled = (mode == "tonton")

		var node_tujuan = petak_cabang.referensi_node_selanjutnya[i]
		var indeks = i
		btn.pressed.connect(func():
			for tombol in main_node.wadah_tombol_cabang.get_children():
				if tombol is Button:
					tombol.disabled = true

			if mode == "lokal":
				# Pilihan langsung dikabarkan (pemain.gd meneruskannya ke lawan);
				# panel baru ditutup setelah pengumuman di umumkan_pilihan_cabang.
				main_node.emit_signal("cabang_lokal_diklik", indeks)
				return
			main_node.panel_ui_cabang.hide()
			main_node.emit_signal("arah_cabang_terpilih", node_tujuan)
		)
		main_node.wadah_tombol_cabang.add_child(btn)

	main_node.panel_ui_cabang.show()

static func umumkan_pilihan_cabang(main_node: Node, indeks: int, milik_sendiri: bool, nama_pemilih: String = "") -> void:
	# Multiplayer: arah yang dipilih disorot emas di KEDUA layar selama
	# JEDA_UMUMKAN_CABANG, baru panelnya ditutup -- pola yang sama dengan
	# pengumuman kartu pedang.
	var tombol = []
	for t in main_node.wadah_tombol_cabang.get_children():
		if t is Button: tombol.append(t)
	var arah = ""
	for k in range(tombol.size()):
		var t = tombol[k]
		t.disabled = true
		if k != indeks:
			t.modulate = Color(1, 1, 1, 0.3)
			continue
		arah = t.text
		var gaya_sorot = StyleBoxFlat.new()
		gaya_sorot.bg_color = Color(0.25, 0.2, 0.05)
		gaya_sorot.set_border_width_all(6)
		gaya_sorot.border_color = Color(1.0, 0.85, 0.2)
		gaya_sorot.set_corner_radius_all(10)
		t.add_theme_stylebox_override("normal", gaya_sorot)
		t.add_theme_stylebox_override("disabled", gaya_sorot)
		t.add_theme_color_override("font_disabled_color", Color(1.0, 0.85, 0.2))

	var judul = _label_judul_cabang(main_node)
	judul.modulate = Color(1.0, 0.85, 0.2) # emas = pengumuman
	var nama_lawan = nama_pemilih if nama_pemilih != "" else "ENEMY"
	judul.text = ("YOU CHOSE: " if milik_sendiri else nama_lawan + " CHOSE: ") + arah

	await main_node.get_tree().create_timer(JEDA_UMUMKAN_CABANG, true).timeout
	main_node.panel_ui_cabang.hide()
	judul.modulate = Color.WHITE

static func _label_judul_cabang(main_node: Node) -> Label:
	# Judul panel = anak pertama VBox yang juga berisi wadah tombol
	# (lihat buat_ui_cabang_dasar).
	return main_node.wadah_tombol_cabang.get_parent().get_child(0)

static func munculkan_ui_pilih_target(main_node: Node, kartu: Dictionary) -> void:
	main_node.panel_ui_target = ColorRect.new()
	main_node.panel_ui_target.color = Color(0, 0, 0, 0.85)
	main_node.panel_ui_target.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_node.panel_ui_target.mouse_filter = Control.MOUSE_FILTER_STOP

	var kanvas = CanvasLayer.new()
	kanvas.layer = 20
	kanvas.add_child(main_node.panel_ui_target)
	main_node.add_child(kanvas)

	var penengah_layar = CenterContainer.new()
	penengah_layar.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_node.panel_ui_target.add_child(penengah_layar)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	penengah_layar.add_child(vbox)

	var lbl = Label.new()
	lbl.text = "CHOOSE TARGET FOR EFFECT:\n" + kartu["teks"].replace("\n", " ")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 35)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	vbox.add_child(lbl)

	var slot_aku = main_node.slot_giliran_ui
	var target_pilihan = [""]
	var daftar_tombol = []

	var btn_diri = Button.new()
	btn_diri.text = "Use on Yourself"
	btn_diri.custom_minimum_size = Vector2(400, 70)
	btn_diri.add_theme_font_size_override("font_size", 25)
	btn_diri.pressed.connect(func(): target_pilihan[0] = main_node._aktor_dari_slot(slot_aku); kanvas.queue_free())
	vbox.add_child(btn_diri)
	daftar_tombol.append(btn_diri)

	# Satu tombol untuk tiap lawan (2 pemain: tetap satu tombol "Use on Enemy").
	for s in range(main_node.jumlah_pemain()):
		if s == slot_aku:
			continue
		var btn_lawan = Button.new()
		btn_lawan.text = "Use on " + ("Enemy" if main_node.jumlah_pemain() <= 2 else "P%d" % (s + 1))
		btn_lawan.custom_minimum_size = Vector2(400, 70)
		btn_lawan.add_theme_font_size_override("font_size", 25)
		var slot_target = s
		btn_lawan.pressed.connect(func(): target_pilihan[0] = main_node._aktor_dari_slot(slot_target); kanvas.queue_free())
		vbox.add_child(btn_lawan)
		daftar_tombol.append(btn_lawan)

	var btn_batal = Button.new()
	btn_batal.text = "Cancel"
	btn_batal.custom_minimum_size = Vector2(400, 70)
	btn_batal.add_theme_font_size_override("font_size", 25)
	btn_batal.pressed.connect(func(): target_pilihan[0] = "cancel"; kanvas.queue_free())
	vbox.add_child(btn_batal)

	await kanvas.tree_exited

	if target_pilihan[0] == "cancel" or target_pilihan[0] == "":
		main_node.periksa_status_petak(slot_aku)
		return

	if StatusJaringan.peran_multiplayer == "client":
		# Client hanya memilih; host yang menjalankan efek kartunya.
		main_node._minta_pakai_kartu(kartu, target_pilihan[0])
		return

	var indeks_kartu = main_node.daftar_pemain[slot_aku].inventaris_kartu.find(kartu)
	if indeks_kartu != -1:
		main_node.daftar_pemain[slot_aku].inventaris_kartu.remove_at(indeks_kartu)

	await main_node._eksekusi_kartu_simpan(kartu, main_node._aktor_dari_slot(slot_aku), target_pilihan[0], indeks_kartu)

	main_node.fase_giliran = "awal"
	main_node.teks_dadu.text = "YOUR TURN! Choose Action or Roll Dice."
	main_node.periksa_status_petak(slot_aku)

static func atur_hud_banyak_pemain(main_node: Node) -> void:
	# 3-4 pemain: panel kanan berubah jadi DAFTAR lawan (satu baris per pemain),
	# jadi lebarnya menyesuaikan isi dan tumbuh ke KIRI supaya tidak keluar layar.
	var kanan = main_node.teks_bintang
	if kanan == null or not (kanan is Control):
		return
	var atas = kanan.position.y
	kanan.anchor_left = 1.0
	kanan.anchor_right = 1.0
	kanan.anchor_top = 0.0
	kanan.anchor_bottom = 0.0
	kanan.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	kanan.offset_right = -20.0
	# Fase 4 (A6): dilebarkan sedikit (dulu -320) supaya nama role di tiap
	# baris lawan (mis. "LIGHTNING") tidak berdesakan dengan Coins/Gems.
	kanan.offset_left = -370.0
	kanan.offset_top = atas
	kanan.offset_bottom = atas + 40.0
	if kanan is RichTextLabel:
		kanan.fit_content = true
		kanan.autowrap_mode = TextServer.AUTOWRAP_OFF
