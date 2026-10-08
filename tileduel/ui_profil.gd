class_name UiProfil
# ============================================================
# UI PROFIL (Fase 2): kartu hadiah di layar akhir, bar profil & tombol MISSIONS di
# main menu, panel PROFILE, panel misi harian, popup hadiah login.
# Semua fungsi static, dipanggil lewat nama kelas (UiProfil.xxx). Data dari autoload
# ProfilPemain. Teks untuk pemain: bahasa Inggris sederhana.
# ============================================================

const EMAS := Color(1.0, 0.85, 0.2)
const ABU := Color(0.75, 0.75, 0.8)
const HIJAU := Color(0.45, 0.95, 0.5)
const MERAH := Color(1.0, 0.45, 0.4)
const WARNA_IKLAN := Color(0.75, 0.55, 0.1)
const MAKS_BARIS_HADIAH := 3

# ------------------------------------------------------------
# PEMBANTU
# ------------------------------------------------------------
static func _label(teks: String, ukuran: int, warna: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = teks
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", ukuran)
	l.add_theme_color_override("font_color", warna)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l

static func _tombol(teks: String, warna: Color, ukuran: Vector2, huruf: int = 20) -> Button:
	var b = Button.new()
	b.text = teks
	b.custom_minimum_size = ukuran
	b.add_theme_font_size_override("font_size", huruf)
	UiDinamis._gaya_tombol(b, warna)
	return b

static func _gaya_kartu(bingkai: Color = EMAS) -> StyleBoxFlat:
	var g = StyleBoxFlat.new()
	g.bg_color = Color(0.07, 0.07, 0.11, 0.96)
	g.set_border_width_all(2)
	g.border_color = bingkai
	g.set_corner_radius_all(14)
	g.content_margin_left = 20
	g.content_margin_right = 20
	g.content_margin_top = 14
	g.content_margin_bottom = 14
	return g

static func _batang_xp(lebar: float, tinggi: float) -> ProgressBar:
	var b = ProgressBar.new()
	b.custom_minimum_size = Vector2(lebar, tinggi)
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var isi = StyleBoxFlat.new()
	isi.bg_color = EMAS
	isi.set_corner_radius_all(5)
	var latar = StyleBoxFlat.new()
	latar.bg_color = Color(0.2, 0.2, 0.25)
	latar.set_corner_radius_all(5)
	b.add_theme_stylebox_override("fill", isi)
	b.add_theme_stylebox_override("background", latar)
	return b

static func _isi_batang(batang: ProgressBar, info: Dictionary) -> void:
	batang.max_value = float(info["xp_butuh"])
	batang.value = float(info["xp_dalam"])

static func _layar_gelap(induk: Node, lapisan: int) -> CanvasLayer:
	# CanvasLayer + latar gelap penuh (menahan ketukan ke menu di belakangnya).
	var kanvas = CanvasLayer.new()
	kanvas.layer = lapisan
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	kanvas.add_child(bg)
	induk.add_child(kanvas)
	return kanvas

static func _kartu_tengah(kanvas: CanvasLayer, atas: bool) -> VBoxContainer:
	# Kartu di tengah layar (atas = di tengah-ATAS, supaya keyboard HP tidak menutupinya).
	var kartu = PanelContainer.new()
	kartu.add_theme_stylebox_override("panel", _gaya_kartu())
	if atas:
		kartu.set_anchors_preset(Control.PRESET_CENTER_TOP)
		kartu.offset_top = 16
		kartu.grow_vertical = Control.GROW_DIRECTION_END
	else:
		kartu.set_anchors_preset(Control.PRESET_CENTER)
		kartu.grow_vertical = Control.GROW_DIRECTION_BOTH
	kartu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	kanvas.add_child(kartu)
	var isi = VBoxContainer.new()
	isi.add_theme_constant_override("separation", 10)
	kartu.add_child(isi)
	return isi

static func nama_slot_papan(main_node: Node, slot: int) -> String:
	# Nama seperti di papan peringkat: YOU / ENEMY (2 pemain), YOU / Pn (3-4 pemain).
	if slot == int(main_node.slot_lokal):
		return "YOU"
	if main_node.daftar_pemain.size() <= 2:
		return "ENEMY"
	return "P%d" % (slot + 1)

static func teks_penghargaan(daftar: Array) -> String:
	var nama_nama = []
	for p in daftar:
		nama_nama.append(str(ProfilPemain.NAMA_PENGHARGAAN.get(str(p), str(p))))
	return "  ".join(nama_nama)

# ------------------------------------------------------------
# KARTU HADIAH (kolom kanan papan peringkat)
# ------------------------------------------------------------
static func buat_kartu_hadiah(_main_node: Node, r: Dictionary, canvas: CanvasLayer) -> Control:
	var kartu = PanelContainer.new()
	kartu.add_theme_stylebox_override("panel", _gaya_kartu())
	kartu.custom_minimum_size = Vector2(430, 0)
	kartu.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var isi = VBoxContainer.new()
	isi.add_theme_constant_override("separation", 10)
	kartu.add_child(isi)

	isi.add_child(_label("YOUR REWARDS", 24, EMAS))
	isi.add_child(_label(ProfilPemain.nama, 18, ABU))
	var lbl_angka = _label("", 30, EMAS)
	isi.add_child(lbl_angka)

	var baris_lv = HBoxContainer.new()
	baris_lv.alignment = BoxContainer.ALIGNMENT_CENTER
	baris_lv.add_theme_constant_override("separation", 10)
	isi.add_child(baris_lv)
	var lbl_lv = _label("", 20)
	baris_lv.add_child(lbl_lv)
	var batang = _batang_xp(240, 14)
	baris_lv.add_child(batang)
	var lbl_xp = _label("", 16, ABU)
	baris_lv.add_child(lbl_xp)

	# Fase 4 (B1): baris XP Role, HANYA kalau pemain sudah pilih role match ini
	# ("FIRE ROLE +180 XP (Lv 4)" + batang terpisah dari XP/Level profil di atas).
	var lbl_role: Label = null
	var batang_role: ProgressBar = null
	if str(r.get("role", "")) != "" and DataRole.ROLE.has(str(r.get("role", ""))):
		lbl_role = _label("", 18, DataRole.warna_role(str(r["role"])))
		isi.add_child(lbl_role)
		var baris_role = HBoxContainer.new()
		baris_role.alignment = BoxContainer.ALIGNMENT_CENTER
		isi.add_child(baris_role)
		batang_role = _batang_xp(240, 10)
		baris_role.add_child(batang_role)
		_tulis_baris_role(lbl_role, batang_role, r)

	var kotak_baris = VBoxContainer.new()
	kotak_baris.add_theme_constant_override("separation", 4)
	isi.add_child(kotak_baris)

	_tulis_angka(lbl_angka, r)
	_isi_baris_hadiah(kotak_baris, r)
	_animasikan_batang(batang, lbl_lv, lbl_xp, int(r["xp_total_awal"]), int(r["xp_total"]))

	# Satu slot di bawah: tombol DOUBLE, lalu diganti label hasilnya.
	if bool(r.get("bisa_double", false)) and not bool(r.get("sudah_double", false)) and PengelolaIklan.rewarded_tersedia():
		var btn = _tombol("WATCH AD: DOUBLE REWARDS", WARNA_IKLAN, Vector2(330, 56), 20)
		isi.add_child(btn)
		var lbl_hasil = _label("", 20, HIJAU)
		lbl_hasil.hide()
		isi.add_child(lbl_hasil)
		btn.pressed.connect(func():
			btn.disabled = true
			btn.hide()
			_tonton_double(r, canvas, lbl_angka, kotak_baris, batang, lbl_lv, lbl_xp, lbl_hasil, lbl_role, batang_role)
		)
	return kartu

static func _tulis_baris_role(lbl: Label, batang: ProgressBar, r: Dictionary) -> void:
	# K10: DOUBLE menambah xp_role_double DI ATAS xp_role_match, sama seperti
	# _tulis_angka membaca xp_double di atas xp_match/xp_penghargaan.
	var role: String = str(r.get("role", ""))
	var xp_match = int(r.get("xp_role_match", 0)) + int(r.get("xp_role_double", 0))
	var lv = int(r.get("role_level_akhir", r.get("role_level_awal", 1)))
	lbl.text = "%s ROLE  +%d XP (Lv %d)" % [DataRole.nama_role(role), xp_match, lv]
	var info = DataRole.info_level_role(int(ProfilPemain.xp_role.get(role, 0)))
	if int(info["xp_perlu"]) > 0:
		batang.max_value = float(info["xp_perlu"])
		batang.value = float(info["xp_di_level"])
	else:
		batang.max_value = 1.0
		batang.value = 1.0 # Level Role maks (20)

static func _tonton_double(r: Dictionary, canvas: CanvasLayer, lbl_angka: Label, kotak_baris: VBoxContainer, batang: ProgressBar, lbl_lv: Label, lbl_xp: Label, lbl_hasil: Label, lbl_role: Label = null, batang_role: ProgressBar = null) -> void:
	# Panel turun ke bawah layer 100 selama iklan: iklan TIRUAN plugin AdMob <= 5.1
	# (saat dijalankan dari editor) tergambar di layer 100. Di HP iklan asli selalu di atas.
	var layer_semula = canvas.layer
	canvas.layer = 99
	var dapat = await PengelolaIklan.tonton_rewarded()
	# Panel bisa sudah dibuang (EXIT ditekan saat iklan belum muncul): cek dulu SEMUA node.
	if is_instance_valid(canvas):
		canvas.layer = layer_semula
	var xp_sebelum = int(r["xp_total"])
	var berhasil = dapat and ProfilPemain.tambah_double(r)
	if not is_instance_valid(lbl_hasil):
		return
	lbl_hasil.show()
	if not berhasil:
		lbl_hasil.text = "No ad right now."
		lbl_hasil.add_theme_color_override("font_color", ABU)
		return
	lbl_hasil.text = "DOUBLED!"
	if is_instance_valid(lbl_angka):
		_tulis_angka(lbl_angka, r)
	if is_instance_valid(kotak_baris):
		_isi_baris_hadiah(kotak_baris, r)
	if is_instance_valid(batang) and is_instance_valid(lbl_lv) and is_instance_valid(lbl_xp):
		_animasikan_batang(batang, lbl_lv, lbl_xp, xp_sebelum, int(r["xp_total"]))
	if is_instance_valid(lbl_role) and is_instance_valid(batang_role):
		_tulis_baris_role(lbl_role, batang_role, r)

static func _tulis_angka(lbl: Label, r: Dictionary) -> void:
	var xp = int(r["xp_match"]) + int(r["xp_penghargaan"]) + int(r.get("xp_misi", 0)) + int(r.get("xp_double", 0))
	var cr = int(r["crowns_match"]) + int(r["crowns_penghargaan"]) + int(r.get("crowns_misi", 0)) \
		+ int(r.get("crowns_naik_level", 0)) + int(r.get("crowns_double", 0))
	lbl.text = "+%d XP     +%d CROWNS" % [xp, cr]

static func _isi_baris_hadiah(kotak: VBoxContainer, r: Dictionary) -> void:
	# Paling banyak 3 baris: naik level, misi selesai, penghargaan sendiri.
	for anak in kotak.get_children():
		anak.queue_free()
	var daftar = []
	if int(r["level_akhir"]) > int(r["level_awal"]):
		daftar.append(["LEVEL UP! Lv %d  +%d Crowns" % [int(r["level_akhir"]), int(r.get("crowns_naik_level", 0))], HIJAU])
	for m in r.get("misi_selesai", []):
		daftar.append(["MISSION DONE: %s" % str(m["teks"]), EMAS])
	for p in r.get("penghargaan", []):
		daftar.append(["%s  +%d XP  +%d Crowns" % [str(ProfilPemain.NAMA_PENGHARGAAN.get(str(p), str(p))), ProfilPemain.XP_PENGHARGAAN, ProfilPemain.CROWNS_PENGHARGAAN], Color.WHITE])
	var tampil = daftar
	if daftar.size() > MAKS_BARIS_HADIAH:
		tampil = daftar.slice(0, MAKS_BARIS_HADIAH - 1)
		tampil.append(["+%d more rewards" % (daftar.size() - MAKS_BARIS_HADIAH + 1), ABU])
	for isi_baris in tampil:
		kotak.add_child(_label(str(isi_baris[0]), 18, isi_baris[1]))

static func _animasikan_batang(batang: ProgressBar, lbl_lv: Label, lbl_xp: Label, xp_dari: int, xp_ke: int) -> void:
	# SATU tween berantai, tanpa await; tween milik batang -> ikut mati kalau panel dibuang.
	var awal = ProfilPemain.info_level(xp_dari)
	var akhir = ProfilPemain.info_level(xp_ke)
	_isi_batang(batang, awal)
	lbl_lv.text = "Lv %d" % int(awal["level"])
	lbl_xp.text = "%d/%d XP" % [int(awal["xp_dalam"]), int(awal["xp_butuh"])]
	var tw = batang.create_tween()
	if int(akhir["level"]) > int(awal["level"]):
		tw.tween_property(batang, "value", float(awal["xp_butuh"]), 0.6)
		tw.tween_callback(func():
			lbl_lv.text = "Lv %d" % int(akhir["level"])
			batang.max_value = float(akhir["xp_butuh"])
			batang.value = 0.0
		)
	tw.tween_property(batang, "value", float(akhir["xp_dalam"]), 0.6)
	tw.tween_callback(func():
		lbl_xp.text = "%d/%d XP" % [int(akhir["xp_dalam"]), int(akhir["xp_butuh"])]
	)

# ------------------------------------------------------------
# MAIN MENU: bar profil (kiri atas) & tombol MISSIONS (kanan atas)
# ------------------------------------------------------------
static func pasang_di_menu(menu: Node) -> void:
	var bar = Button.new()
	bar.flat = false
	bar.custom_minimum_size = Vector2(410, 66)
	bar.position = Vector2(16, 16)
	var g = _gaya_kartu()
	g.content_margin_top = 6
	g.content_margin_bottom = 6
	g.content_margin_left = 12
	g.content_margin_right = 12
	var g_hover = g.duplicate()
	g_hover.bg_color = Color(0.13, 0.13, 0.2, 0.96)
	bar.add_theme_stylebox_override("normal", g)
	bar.add_theme_stylebox_override("hover", g_hover)
	bar.add_theme_stylebox_override("pressed", g)
	bar.add_theme_stylebox_override("disabled", g)
	var baris = HBoxContainer.new()
	baris.set_anchors_preset(Control.PRESET_FULL_RECT)
	baris.offset_left = 12
	baris.offset_right = -12
	baris.add_theme_constant_override("separation", 14)
	baris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(baris)
	var kiri = VBoxContainer.new()
	kiri.alignment = BoxContainer.ALIGNMENT_CENTER
	kiri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kiri.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	baris.add_child(kiri)
	var lbl_nama = _label("", 20)
	lbl_nama.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_nama.name = "Nama"
	kiri.add_child(lbl_nama)
	var baris_lv = HBoxContainer.new()
	baris_lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	baris_lv.add_theme_constant_override("separation", 8)
	kiri.add_child(baris_lv)
	var lbl_lv = _label("", 16, EMAS)
	lbl_lv.name = "Lv"
	baris_lv.add_child(lbl_lv)
	var batang = _batang_xp(110, 10)
	batang.name = "Batang"
	baris_lv.add_child(batang)
	var lbl_xp = _label("", 14, ABU)
	lbl_xp.name = "Xp"
	baris_lv.add_child(lbl_xp)
	var lbl_crowns = _label("", 20, EMAS)
	lbl_crowns.name = "Crowns"
	lbl_crowns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	baris.add_child(lbl_crowns)
	bar.pressed.connect(func(): buka_panel_profil(menu))
	menu.add_child(bar)

	var tombol = _tombol("MISSIONS", Color(0.2, 0.45, 0.75), Vector2(190, 56), 20)
	tombol.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tombol.offset_left = -16 - 190
	tombol.offset_right = -16
	tombol.offset_top = 20
	tombol.offset_bottom = 20 + 56
	tombol.pressed.connect(func(): buka_panel_misi(menu))
	menu.add_child(tombol)

	menu.bar_profil = bar
	menu.tombol_misi = tombol
	segarkan_menu(menu)

static func segarkan_menu(menu: Node) -> void:
	var bar = menu.get("bar_profil")
	if bar != null and is_instance_valid(bar):
		var info = ProfilPemain.info_level()
		bar.find_child("Nama", true, false).text = ProfilPemain.nama
		bar.find_child("Lv", true, false).text = "Lv %d" % int(info["level"])
		_isi_batang(bar.find_child("Batang", true, false), info)
		bar.find_child("Xp", true, false).text = "%d/%d" % [int(info["xp_dalam"]), int(info["xp_butuh"])]
		bar.find_child("Crowns", true, false).text = "CROWNS %d" % ProfilPemain.crowns
	var tombol = menu.get("tombol_misi")
	if tombol != null and is_instance_valid(tombol):
		tombol.text = "MISSIONS %d/3%s" % [ProfilPemain.jumlah_misi_selesai(), "  !" if ProfilPemain.login_bisa_diklaim() else ""]

# ------------------------------------------------------------
# PANEL PROFILE
# ------------------------------------------------------------
static func buka_panel_profil(menu: Node) -> void:
	var kanvas = _layar_gelap(menu, 11)
	var isi = _kartu_tengah(kanvas, true)
	isi.add_child(_label("PROFILE", 32, EMAS))

	var baris_nama = HBoxContainer.new()
	baris_nama.alignment = BoxContainer.ALIGNMENT_CENTER
	baris_nama.add_theme_constant_override("separation", 10)
	isi.add_child(baris_nama)
	var kotak = LineEdit.new()
	kotak.text = ProfilPemain.nama
	kotak.max_length = 12
	kotak.custom_minimum_size = Vector2(260, 48)
	kotak.add_theme_font_size_override("font_size", 22)
	baris_nama.add_child(kotak)
	var btn_simpan = _tombol("SAVE", Color(0.15, 0.55, 0.25), Vector2(110, 48), 20)
	baris_nama.add_child(btn_simpan)
	var lbl_pesan = _label("", 16, MERAH)
	isi.add_child(lbl_pesan)
	btn_simpan.pressed.connect(func():
		var pesan = ProfilPemain.ganti_nama(kotak.text)
		if pesan == "":
			kotak.text = ProfilPemain.nama
			lbl_pesan.text = "Saved!"
			lbl_pesan.add_theme_color_override("font_color", HIJAU)
		else:
			lbl_pesan.text = pesan
			lbl_pesan.add_theme_color_override("font_color", MERAH)
	)

	var info = ProfilPemain.info_level()
	var baris_lv = HBoxContainer.new()
	baris_lv.alignment = BoxContainer.ALIGNMENT_CENTER
	baris_lv.add_theme_constant_override("separation", 10)
	isi.add_child(baris_lv)
	baris_lv.add_child(_label("Level %d" % int(info["level"]), 22, EMAS))
	var batang = _batang_xp(220, 14)
	_isi_batang(batang, info)
	baris_lv.add_child(batang)
	baris_lv.add_child(_label("%d/%d XP to Lv %d" % [int(info["xp_dalam"]), int(info["xp_butuh"]), int(info["level"]) + 1], 16, ABU))

	isi.add_child(_label("CROWNS %d" % ProfilPemain.crowns, 24, EMAS))
	isi.add_child(_label("Crowns will unlock items soon.", 16, ABU))

	var kisi = GridContainer.new()
	kisi.columns = 4
	kisi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	kisi.add_theme_constant_override("h_separation", 18)
	kisi.add_theme_constant_override("v_separation", 4)
	isi.add_child(kisi)
	var s = ProfilPemain.statistik
	var daftar = [["Matches", "match"], ["Wins", "menang"], ["Duels won", "duel_menang"], ["Traps set", "jebakan_pasang"],
		["Tiles bought", "petak_beli"], ["Gems", "permata"], ["Awards", "penghargaan"]]
	for d in daftar:
		var l_nama = _label(str(d[0]), 18, ABU)
		l_nama.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		kisi.add_child(l_nama)
		var l_isi = _label(str(int(s.get(d[1], 0))), 18)
		l_isi.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		kisi.add_child(l_isi)

	var btn_tutup = _tombol("CLOSE", Color(0.6, 0.2, 0.2), Vector2(200, 52), 20)
	btn_tutup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_tutup.pressed.connect(kanvas.queue_free)
	isi.add_child(btn_tutup)

# ------------------------------------------------------------
# PANEL MISI HARIAN (+ hadiah login)
# ------------------------------------------------------------
static func buka_panel_misi(menu: Node) -> void:
	ProfilPemain.segarkan_hari()
	var kanvas = _layar_gelap(menu, 11)
	kanvas.name = "PanelMisi"
	var isi = _kartu_tengah(kanvas, false)
	isi.add_child(_label("DAILY MISSIONS", 32, EMAS))
	isi.add_child(_label("New missions every day at midnight.", 16, ABU))

	for i in range(ProfilPemain.misi.size()):
		var m: Dictionary = ProfilPemain.misi[i]
		var hd = ProfilPemain.hadiah_misi(m)
		var baris = HBoxContainer.new()
		baris.add_theme_constant_override("separation", 14)
		isi.add_child(baris)
		var kolom = VBoxContainer.new()
		kolom.custom_minimum_size = Vector2(420, 0)
		kolom.add_theme_constant_override("separation", 0)
		baris.add_child(kolom)
		var l_teks = _label(ProfilPemain.teks_misi(m), 20)
		l_teks.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		kolom.add_child(l_teks)
		var l_hadiah = _label("+%d CROWNS  +%d XP" % [int(hd["crowns"]), int(hd["xp"])], 16, EMAS)
		l_hadiah.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		kolom.add_child(l_hadiah)
		var l_progres = _label("%d/%d" % [int(m.get("progres", 0)), ProfilPemain.target_misi(m)], 20)
		l_progres.custom_minimum_size = Vector2(60, 0)
		l_progres.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		baris.add_child(l_progres)
		if bool(m.get("selesai", false)):
			var l_done = _label("DONE", 20, HIJAU)
			l_done.custom_minimum_size = Vector2(130, 0)
			l_done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			baris.add_child(l_done)
		elif ProfilPemain.boleh_ganti_misi(i):
			var btn_ganti = _tombol("CHANGE", Color(0.4, 0.4, 0.5), Vector2(130, 44), 18)
			btn_ganti.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var indeks = i
			btn_ganti.pressed.connect(func():
				if ProfilPemain.ganti_misi(indeks):
					kanvas.queue_free()
					buka_panel_misi(menu)
			)
			baris.add_child(btn_ganti)
		else:
			var kosong = Control.new()
			kosong.custom_minimum_size = Vector2(130, 0)
			baris.add_child(kosong)
	if ProfilPemain.ganti_misi_dipakai:
		isi.add_child(_label("1 change per day", 16, ABU))

	isi.add_child(_label("DAILY LOGIN", 22, EMAS))
	isi.add_child(_baris_hari_login())
	if ProfilPemain.login_bisa_diklaim():
		var jumlah = int(ProfilPemain.HADIAH_LOGIN[ProfilPemain.hari_login - 1])
		var btn_klaim = _tombol("CLAIM +%d CROWNS" % jumlah, Color(0.15, 0.55, 0.25), Vector2(300, 52), 20)
		btn_klaim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn_klaim.pressed.connect(func():
			ProfilPemain.klaim_login()
			kanvas.queue_free()
			buka_panel_misi(menu)
		)
		isi.add_child(btn_klaim)

	var btn_tutup = _tombol("CLOSE", Color(0.6, 0.2, 0.2), Vector2(200, 52), 20)
	btn_tutup.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_tutup.pressed.connect(kanvas.queue_free)
	isi.add_child(btn_tutup)

static func _baris_hari_login() -> HBoxContainer:
	# 7 kotak: hari yang sudah diklaim (sebelum hari_login di putaran ini) redup + CLAIMED,
	# hari yang bisa diklaim sekarang bingkai emas.
	var baris = HBoxContainer.new()
	baris.alignment = BoxContainer.ALIGNMENT_CENTER
	baris.add_theme_constant_override("separation", 6)
	var bisa = ProfilPemain.login_bisa_diklaim()
	for h in range(1, 8):
		var kotak = PanelContainer.new()
		var sudah = h < ProfilPemain.hari_login
		var hari_ini = bisa and h == ProfilPemain.hari_login
		var g = _gaya_kartu(EMAS if hari_ini else Color(0.3, 0.3, 0.4))
		g.content_margin_left = 8
		g.content_margin_right = 8
		g.content_margin_top = 4
		g.content_margin_bottom = 4
		if sudah:
			g.bg_color = Color(0.1, 0.25, 0.12, 0.96)
		kotak.add_theme_stylebox_override("panel", g)
		kotak.custom_minimum_size = Vector2(78, 0)
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		kotak.add_child(v)
		v.add_child(_label("Day %d" % h, 14, ABU))
		v.add_child(_label("+%d" % int(ProfilPemain.HADIAH_LOGIN[h - 1]), 18, EMAS))
		if sudah:
			v.add_child(_label("CLAIMED", 11, HIJAU))
		baris.add_child(kotak)
	return baris

# ------------------------------------------------------------
# POPUP HADIAH LOGIN (otomatis di menu, sekali sehari)
# ------------------------------------------------------------
static func tampilkan_popup_login(menu: Node) -> void:
	if not ProfilPemain.login_bisa_diklaim():
		return
	var kanvas = _layar_gelap(menu, 12)
	var isi = _kartu_tengah(kanvas, false)
	isi.add_child(_label("DAILY REWARD", 36, EMAS))
	isi.add_child(_label("Day %d" % ProfilPemain.hari_login, 22))
	isi.add_child(_baris_hari_login())
	var jumlah = int(ProfilPemain.HADIAH_LOGIN[ProfilPemain.hari_login - 1])
	var btn_klaim = _tombol("CLAIM +%d CROWNS" % jumlah, Color(0.15, 0.55, 0.25), Vector2(340, 64), 24)
	btn_klaim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	isi.add_child(btn_klaim)
	var btn_nanti = _tombol("LATER", Color(0.4, 0.4, 0.4), Vector2(160, 44), 18)
	btn_nanti.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_nanti.pressed.connect(kanvas.queue_free)
	isi.add_child(btn_nanti)
	var lbl_hasil = _label("", 26, HIJAU)
	lbl_hasil.hide()
	isi.add_child(lbl_hasil)
	btn_klaim.pressed.connect(func():
		btn_klaim.disabled = true
		btn_nanti.disabled = true
		var h = ProfilPemain.klaim_login()
		if h.is_empty():
			kanvas.queue_free()
			return
		var teks = "+%d CROWNS!" % int(h["crowns"])
		if int(h.get("xp", 0)) > 0:
			teks += "  +%d XP" % int(h["xp"])
		if int(h["level_baru"]) > int(h["level_lama"]):
			teks += "  LEVEL UP!"
		lbl_hasil.text = teks
		lbl_hasil.show()
		kanvas.get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(kanvas):
				kanvas.queue_free()
		)
	)
