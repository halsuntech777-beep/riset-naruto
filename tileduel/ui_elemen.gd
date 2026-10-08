extends ColorRect

signal elemen_diklik(nama_elemen)
# (Sinyal "pilihan_jaringan_diterima" yang tadinya ada di sini dihapus -- tidak
# pernah dipakai; pilihan elemen dari client di multiplayer ternyata ditangani
# lewat _pilihan_elemen_jaringan di pemain.gd, bukan lewat sinyal ini.)
signal koin_dipilih(pilihan)
# Dipancarkan di akhir jalankan_duel -- penanda duel benar-benar tuntas.
# Dipakai jebakan tanah untuk menarik kembali buff +1 HP petak.
signal duel_selesai

# --- LEMPAR KOIN PENENTU SERI (MULTIPLAYER) ---
# Naik ke pemain.gd: "pemain di device INI sudah memilih sisi koin, kirimkan".
signal koin_lokal_dikunci(pilihan)
# Dipancarkan tiap kali pemain.gd menitipkan data koin baru dari jaringan.
signal data_koin_jaringan_tiba
# Titipan data koin dari jaringan. WAJIB ditampung, bukan cuma sinyal: kiriman
# lawan bisa tiba saat layar ini belum sampai di tahap menunggu (misalnya masih
# memutar animasi rolet), dan sinyal yang terpancar saat tidak ada yang
# menunggu akan hilang -- duel membeku selamanya.
var koin_pilihan_lawan: String = ""
var koin_hasil_jaringan: String = ""
# Diisi pemain.gd dari saklar UJI_SERI. Hanya dipakai jalur solo -- di
# multiplayer, host sudah memasukkan angka serinya ke dalam naskah.
var paksa_seri: bool = false

# --- KOIN 2D RINGAN (khusus setelan grafis Very Low) ---
# Digambar langsung di _draw(): tanpa node 3D, material logam, lampu, atau
# Label3D -- jadi GPU tidak perlu mengompilasi shader baru saat koin pertama
# kali muncul (penyebab jeda beberapa detik di HP).
var koin_ringan_tampil = false
var koin_ringan_sudut = 0.0 # derajat; 0 = HEADS menghadap layar, 180 = TAILS
var koin_ringan_skala = 0.0

# --- SUDUT PANDANG LAYAR DUEL (2-4 pemain) ---
# Sisi "pemain" (bawah) & "musuh" (atas) layar ini bisa milik siapa saja. Di
# device peserta duel, sisi "pemain" = pemain device itu ("YOU"); di device
# penonton (3-4 pemain) sisi "pemain" = penyerang dan mode_tonton = true
# (tidak ada yang bisa diklik di sini). Nilai bawaan = permainan 2 pemain,
# yaitu persis seperti sebelumnya.
var nama_sisi_p: String = "YOU"
var nama_sisi_m: String = "ENEMY"
var mode_tonton: bool = false

var memori_serang_pemain = {"api": 0, "air": 0, "angin": 0, "tanah": 0, "petir": 0}
var memori_bertahan_pemain = {"api": 0, "air": 0, "angin": 0, "tanah": 0, "petir": 0}
var lubang_koin_progress = 0.0
var elemen_pilihan_musuh = ""
var elemen_pilihan_pemain = ""
var teks_judul: Label
var teks_bantuan: Label 

var elemen_fokus = ""
var waktu_animasi = 0.0
var rng = RandomNumberGenerator.new() 
var rng_visual = RandomNumberGenerator.new() # <--- TAMBAHKAN MESIN KHUSUS VISUAL

# --- VARIABEL AUDIO EXTERNAL & ROLET ---
var pemutar_suara: AudioStreamPlayer
var pemutar_suara_rolet: AudioStreamPlayer
var efek_filter_rolet: AudioEffectLowPassFilter

var stream_elemen = {
	"api": preload("res://suara/api.wav"),
	"air": preload("res://suara/air.wav"),
	"angin": preload("res://suara/angin.wav"),
	"tanah": preload("res://suara/tanah.wav"),
	"petir": preload("res://suara/petir.wav")
}

const DATA_ELEMEN = {
	"api": {"nama": "FIRE", "warna": Color(0.9, 0.2, 0.2), "menang_lawan": ["angin", "tanah"]},
	"air": {"nama": "WATER", "warna": Color(0.2, 0.5, 0.9), "menang_lawan": ["api", "tanah"]},
	"tanah": {"nama": "EARTH", "warna": Color(0.6, 0.4, 0.2), "menang_lawan": ["angin", "petir"]},
	"petir": {"nama": "LIGHTNING", "warna": Color(0.9, 0.8, 0.1), "menang_lawan": ["air", "api"]},
	"angin": {"nama": "WIND", "warna": Color(0.5, 0.9, 0.7), "menang_lawan": ["air", "petir"]}
}

var urutan_pentagon = ["api", "air", "tanah", "petir", "angin"]
var radius_pentagon = 160.0 
var radius_lingkaran = 45.0

# Variabel Posisi
var tengah_musuh: Vector2
var tengah_pemain: Vector2
var posisi_titik_pemain = {}
var posisi_titik_musuh = {}
var tombol_elemen = {}

# Variabel Animasi Elemen
var fase_duel = "MENUNGGU_MUSUH" 
var musuh_siap = false
var pemain_siap = false
var alpha_bg = 1.0

var anim_pos_p: Vector2
var anim_scale_p = 1.0
var anim_alpha_p = 1.0
var anim_coret_p = 0.0

var anim_pos_m: Vector2
var anim_scale_m = 1.0
var anim_alpha_m = 1.0
var anim_coret_m = 0.0

# --- VARIABEL ROLET VISUAL ---
var posisi_rolet_p: Vector2
var posisi_rolet_m: Vector2
var alpha_rolet_p = 0.0
var alpha_rolet_m = 0.0
var rotasi_rolet_p = 0.0
var rotasi_rolet_m = 0.0
var putar_diklik = false

var angka_penyerang = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
var angka_pembela = [1, 2, 3, 4, 5, 6]
var angka_p: Array
var angka_m: Array

var warna_penyerang = Color(0.8, 0.15, 0.15) 
var warna_pembela = Color(0.15, 0.4, 0.8)    
var warna_p: Color
var warna_m: Color

var tombol_putar: Button
var tombol_kepala: Button
var tombol_ekor: Button
# --- VARIABEL PANEL & PENGUMUMAN ---
var panel_p: Panel
var teks_p: RichTextLabel
var panel_m: Panel
var teks_m: RichTextLabel
var panel_tengah: Panel
var teks_tengah: RichTextLabel

# --- VARIABEL EFEK CUACA ---
var sfx_cuaca: AudioStreamPlayer
var cuaca_aktif = ""
var partikel_kembang_api = []
var partikel_hujan = []
var kilat_petir_alpha = 0.0

var _last_slice_p = -1
var _last_slice_m = -1
var waktu_tunggu_putar = 0.0
var warna_bg_asli: Color 

func _ready():
	rng.randomize() # <--- TAMBAHKAN BARIS INI
	warna_bg_asli = self.color 
	_setup_ui_dasar()
	_kalkulasi_posisi_pentagon()
	_setup_audio_mekanik()

func _setup_audio_mekanik():
	pemutar_suara = AudioStreamPlayer.new()
	add_child(pemutar_suara)
	
	var nama_bus = "UIBus"
	var index_bus = AudioServer.get_bus_index(nama_bus)
	if index_bus == -1:
		AudioServer.add_bus()
		index_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index_bus, nama_bus)
		efek_filter_rolet = AudioEffectLowPassFilter.new()
		efek_filter_rolet.cutoff_hz = 1800.0 
		AudioServer.add_bus_effect(index_bus, efek_filter_rolet)

	pemutar_suara_rolet = AudioStreamPlayer.new()
	pemutar_suara_rolet.bus = nama_bus
	add_child(pemutar_suara_rolet)
	
	var suara_ketukan = AudioStreamWAV.new()
	suara_ketukan.format = AudioStreamWAV.FORMAT_16_BITS
	suara_ketukan.mix_rate = 44100
	var data_suara = PackedByteArray()
	var sampel_total = int(44100 * 0.035)
	
	for i in range(sampel_total):
		var t = float(i) / 44100.0
		var progress = float(i) / sampel_total
		var envelope = exp(-progress * 6.0) * (1.0 - progress)
		# Ubah randf_range menjadi rng.randf_range
		var gelombang = sin(2.0 * PI * 320.0 * t) * 0.6 + sin(2.0 * PI * 800.0 * t) * 0.3 + rng.randf_range(-1.0, 1.0) * 0.15
		var nilai_pcm = int(clamp(gelombang * envelope, -1.0, 1.0) * 32767.0)
		data_suara.append(nilai_pcm & 0xFF)
		data_suara.append((nilai_pcm >> 8) & 0xFF)
		
	suara_ketukan.data = data_suara
	pemutar_suara_rolet.stream = suara_ketukan
	pemutar_suara_rolet.volume_db = -3.0
	sfx_cuaca = AudioStreamPlayer.new()
	add_child(sfx_cuaca)

func _setup_ui_dasar():
	teks_judul = Label.new()
	teks_judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	teks_judul.add_theme_font_size_override("font_size", 40)
	teks_judul.add_theme_color_override("font_outline_color", Color.BLACK)
	teks_judul.add_theme_constant_override("outline_size", 10)
	teks_judul.set_anchors_preset(Control.PRESET_TOP_WIDE)
	teks_judul.position.y = 50
	add_child(teks_judul)
	
	teks_bantuan = Label.new()
	teks_bantuan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	teks_bantuan.add_theme_font_size_override("font_size", 26)
	teks_bantuan.add_theme_color_override("font_outline_color", Color.BLACK)
	teks_bantuan.add_theme_constant_override("outline_size", 6)
	teks_bantuan.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	teks_bantuan.position.y = -80
	teks_bantuan.modulate = Color(1.0, 1.0, 0.5) 
	add_child(teks_bantuan)

	var style_panel = StyleBoxFlat.new()
	style_panel.bg_color = Color(0.05, 0.05, 0.08, 0.85)
	
	# Ganti dengan 4 baris ini
	style_panel.border_width_left = 3
	style_panel.border_width_top = 3
	style_panel.border_width_right = 3
	style_panel.border_width_bottom = 3
	
	style_panel.border_color = Color(0.8, 0.6, 0.1)
	style_panel.corner_radius_top_left = 15
	style_panel.corner_radius_top_right = 15
	style_panel.corner_radius_bottom_right = 15
	style_panel.corner_radius_bottom_left = 15
	
	panel_p = Panel.new()
	panel_p.add_theme_stylebox_override("panel", style_panel)
	panel_p.hide()
	add_child(panel_p)
	
	teks_p = RichTextLabel.new()
	teks_p.bbcode_enabled = true
	teks_p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 15)
	panel_p.add_child(teks_p)
	
	panel_m = Panel.new()
	panel_m.add_theme_stylebox_override("panel", style_panel)
	panel_m.hide()
	add_child(panel_m)
	
	teks_m = RichTextLabel.new()
	teks_m.bbcode_enabled = true
	teks_m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 15)
	panel_m.add_child(teks_m)

	panel_tengah = Panel.new()
	panel_tengah.add_theme_stylebox_override("panel", style_panel.duplicate())
	panel_tengah.get_theme_stylebox("panel").bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_tengah.hide()
	add_child(panel_tengah)
	
	teks_tengah = RichTextLabel.new()
	teks_tengah.bbcode_enabled = true
	teks_tengah.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 20)
	panel_tengah.add_child(teks_tengah)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.6, 0.9)
	style_normal.border_width_bottom = 8 
	style_normal.border_width_right = 5
	style_normal.border_color = Color(0.1, 0.3, 0.5) 
	style_normal.corner_radius_top_left = 15
	style_normal.corner_radius_top_right = 15
	style_normal.corner_radius_bottom_right = 15
	style_normal.corner_radius_bottom_left = 15
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.3, 0.7, 1.0) 
	
	var style_pressed = style_normal.duplicate()
	style_pressed.border_width_bottom = 2 
	style_pressed.border_width_top = 6  
	style_pressed.bg_color = Color(0.1, 0.4, 0.7)

	# Tombol koin yang sisinya sudah diambil lawan (lempar koin multiplayer):
	# abu-abu redup. Godot memakai gaya ini otomatis selama tombol disabled.
	var style_terkunci = style_normal.duplicate()
	style_terkunci.bg_color = Color(0.28, 0.28, 0.3)
	style_terkunci.border_color = Color(0.18, 0.18, 0.2)

	tombol_putar = Button.new()
	tombol_putar.text = "SPIN WHEEL!"
	tombol_putar.add_theme_font_size_override("font_size", 26)
	tombol_putar.add_theme_color_override("font_color", Color.WHITE)
	tombol_putar.add_theme_constant_override("outline_size", 6)
	tombol_putar.size = Vector2(220, 60)
	tombol_putar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tombol_putar.pressed.connect(_on_tombol_putar_ditekan)
	tombol_putar.add_theme_stylebox_override("normal", style_normal)
	tombol_putar.add_theme_stylebox_override("hover", style_hover)
	tombol_putar.add_theme_stylebox_override("pressed", style_pressed)
	tombol_putar.clip_contents = true 
	
	var efek_kilap = ColorRect.new()
	efek_kilap.color = Color(1.0, 1.0, 1.0, 0.45) 
	efek_kilap.size = Vector2(30, 150)
	efek_kilap.rotation_degrees = 25 
	efek_kilap.position = Vector2(-80, -30) 
	efek_kilap.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	tombol_putar.add_child(efek_kilap)
	
	var tween_kilap = tombol_putar.create_tween().bind_node(tombol_putar).set_loops() # <--- PERBAIKAN DI SINI
	tween_kilap.tween_property(efek_kilap, "position:x", 250.0, 0.5) 
	tween_kilap.tween_interval(1.0) 
	tween_kilap.tween_property(efek_kilap, "position:x", -80.0, 0.05)
	tombol_putar.hide()
	add_child(tombol_putar)
	
	tombol_kepala = Button.new()
	tombol_kepala.text = "🪙 HEADS"
	tombol_kepala.add_theme_font_size_override("font_size", 28)
	tombol_kepala.add_theme_color_override("font_color", Color.WHITE)
	tombol_kepala.add_theme_constant_override("outline_size", 6)
	tombol_kepala.size = Vector2(230, 70)
	tombol_kepala.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tombol_kepala.pressed.connect(func(): koin_dipilih.emit("kepala"))
	tombol_kepala.add_theme_stylebox_override("normal", style_normal)
	tombol_kepala.add_theme_stylebox_override("hover", style_hover)
	tombol_kepala.add_theme_stylebox_override("pressed", style_pressed)
	tombol_kepala.add_theme_stylebox_override("disabled", style_terkunci)
	tombol_kepala.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	tombol_kepala.hide()
	add_child(tombol_kepala)

	tombol_ekor = Button.new()
	tombol_ekor.text = "🪙 TAILS"
	tombol_ekor.add_theme_font_size_override("font_size", 28)
	tombol_ekor.add_theme_color_override("font_color", Color.WHITE)
	tombol_ekor.add_theme_constant_override("outline_size", 6)
	tombol_ekor.size = Vector2(230, 70)
	tombol_ekor.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tombol_ekor.pressed.connect(func(): koin_dipilih.emit("ekor"))
	tombol_ekor.add_theme_stylebox_override("normal", style_normal)
	tombol_ekor.add_theme_stylebox_override("hover", style_hover)
	tombol_ekor.add_theme_stylebox_override("pressed", style_pressed)
	tombol_ekor.add_theme_stylebox_override("disabled", style_terkunci)
	tombol_ekor.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	tombol_ekor.hide()
	add_child(tombol_ekor)

func _kalkulasi_posisi_pentagon():
	tengah_musuh = Vector2(size.x * 0.25, size.y * 0.55)
	tengah_pemain = Vector2(size.x * 0.75, size.y * 0.55)
	
	posisi_rolet_m = tengah_musuh + Vector2(0, -40)
	posisi_rolet_p = tengah_pemain + Vector2(0, -40)
	
	panel_m.size = Vector2(280, 160)
	panel_m.position = posisi_rolet_m + Vector2(-140, 150)
	
	panel_p.size = Vector2(280, 160)
	panel_p.position = posisi_rolet_p + Vector2(-140, 150)
	
	panel_tengah.size = Vector2(400, 420)
	panel_tengah.position = (size / 2.0) - (panel_tengah.size / 2.0)
	
	tombol_putar.position = tengah_pemain + Vector2(-110, 147)

	var sudut_mulai = -PI / 2.0 
	for i in range(5):
		var nama = urutan_pentagon[i]
		var sudut = sudut_mulai + (i * 2.0 * PI / 5.0)
		posisi_titik_musuh[nama] = tengah_musuh + Vector2(cos(sudut), sin(sudut)) * radius_pentagon
		posisi_titik_pemain[nama] = tengah_pemain + Vector2(cos(sudut), sin(sudut)) * radius_pentagon
		
		var btn = Button.new()
		btn.size = Vector2(radius_lingkaran * 2.2, radius_lingkaran * 2.2)
		btn.position = posisi_titik_pemain[nama] - Vector2(radius_lingkaran * 1.1, radius_lingkaran * 1.1)
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(_on_tombol_ditekan.bind(nama))
		add_child(btn)
		tombol_elemen[nama] = btn

func _process(delta):
	if visible:
		waktu_animasi += delta
		
		if cuaca_aktif == "kembang_api":
			if rng_visual.randf() < 0.05: _buat_kembang_api()
			for p in partikel_kembang_api:
				p.pos += p.vel * delta
				p.vel.y += 120.0 * delta 
				p.life -= delta
			partikel_kembang_api = partikel_kembang_api.filter(func(p): return p.life > 0.0)
			
		elif cuaca_aktif == "hujan":
			if rng_visual.randf() < 0.4: _buat_rintik_hujan()
			for p in partikel_hujan:
				p.pos += p.vel * delta
				p.life -= delta
			partikel_hujan = partikel_hujan.filter(func(p): return p.life > 0.0)
			
			if rng_visual.randf() < 0.01: kilat_petir_alpha = 0.6
			kilat_petir_alpha = lerp(kilat_petir_alpha, 0.0, delta * 8.0)
			
		# --- PERBAIKAN OVERDRAW MULA ---
		# Hanya minta GPU merender ulang saat ada elemen yang bergerak secara visual
		var sedang_animasi = false
		if cuaca_aktif != "": sedang_animasi = true
		if elemen_fokus != "": sedang_animasi = true
		if alpha_rolet_p > 0.0 or alpha_rolet_m > 0.0: sedang_animasi = true
		if fase_duel not in ["MENUNGGU_MUSUH", "PILIH_PEMAIN"]: sedang_animasi = true
		if lubang_koin_progress > 0.0 and lubang_koin_progress < 1.0: sedang_animasi = true
		if koin_ringan_tampil: sedang_animasi = true

		if sedang_animasi:
			queue_redraw()
		# --- PERBAIKAN OVERDRAW AKHIR ---
		
		if alpha_rolet_p > 0 and angka_p.size() > 0:
			var rad_per_slice = TAU / float(angka_p.size())
			var rot_offset = rotasi_rolet_p
			if rot_offset < 0: rot_offset += TAU * 10
			var current_slice = int(floor(rot_offset / rad_per_slice))
			if current_slice != _last_slice_p:
				pemutar_suara_rolet.pitch_scale = rng.randf_range(0.92, 1.08) # <--- UBAH DI SINI
				pemutar_suara_rolet.play()
				_last_slice_p = current_slice

		if alpha_rolet_m > 0 and angka_m.size() > 0:
			var rad_per_slice_m = TAU / float(angka_m.size())
			var rot_offset_m = rotasi_rolet_m
			if rot_offset_m < 0: rot_offset_m += TAU * 10
			var current_slice_m = int(floor(rot_offset_m / rad_per_slice_m))
			if current_slice_m != _last_slice_m:
				pemutar_suara_rolet.pitch_scale = rng.randf_range(0.92, 1.08) # <--- UBAH DI SINI
				pemutar_suara_rolet.play()
				_last_slice_m = current_slice_m

func _on_tombol_ditekan(nama_elemen):
	if fase_duel != "PILIH_PEMAIN": return 
	if elemen_fokus == nama_elemen:
		pemutar_suara.stream = stream_elemen[nama_elemen]
		pemutar_suara.pitch_scale = 1.1 
		pemutar_suara.play()
		elemen_fokus = ""
		teks_bantuan.text = ""
		queue_redraw() # <--- TAMBAHKAN INI UNTUK MENGHAPUS EFEK 3D
		elemen_diklik.emit(nama_elemen)
	else:
		pemutar_suara.stream = stream_elemen[nama_elemen]
		pemutar_suara.pitch_scale = 1.0 
		pemutar_suara.play()
		elemen_fokus = nama_elemen
		teks_bantuan.text = "TAP " + DATA_ELEMEN[nama_elemen]["nama"] + " AGAIN TO CONFIRM!"
		queue_redraw() # <--- TAMBAHKAN INI UNTUK MENGGAMBAR EFEK 3D

func _on_tombol_putar_ditekan():
	putar_diklik = true

func _draw():
	if posisi_titik_pemain.is_empty(): return
	var font = ThemeDB.fallback_font
	
	if alpha_bg > 0.0:
		for i in range(5):
			var p1_m = posisi_titik_musuh[urutan_pentagon[i]]
			var p2_m = posisi_titik_musuh[urutan_pentagon[(i+1)%5]]
			var p1_p = posisi_titik_pemain[urutan_pentagon[i]]
			var p2_p = posisi_titik_pemain[urutan_pentagon[(i+1)%5]]
			draw_line(p1_m, p2_m, Color(1, 1, 1, 0.05 * alpha_bg), 2.0)
			draw_line(p1_p, p2_p, Color(1, 1, 1, 0.05 * alpha_bg), 2.0)
			
		draw_string(font, tengah_musuh + Vector2(-40, -radius_pentagon - 60), nama_sisi_m, HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color(1.0, 0.3, 0.3, alpha_bg))
		draw_string(font, tengah_pemain + Vector2(-40, -radius_pentagon - 60), nama_sisi_p, HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color(0.3, 1.0, 1.0, alpha_bg))

		for nama in urutan_pentagon:
			if fase_duel in ["FADE_OUT", "ANIMASI_CORET", "ANIMASI_HILANG", "ANIMASI_MENANG", "ROLET", "RANGKUMAN"]:
				if nama != elemen_pilihan_musuh: _gambar_lingkaran_elemen(posisi_titik_musuh[nama], nama, 1.0, alpha_bg)
				if nama != elemen_pilihan_pemain: _gambar_lingkaran_elemen(posisi_titik_pemain[nama], nama, 1.0, alpha_bg)
			else:
				_gambar_lingkaran_elemen(posisi_titik_musuh[nama], nama, 1.0, alpha_bg)
				var ukuran_p = 1.15 if nama == elemen_fokus else 1.0
				_gambar_lingkaran_elemen(posisi_titik_pemain[nama], nama, ukuran_p, alpha_bg)

	if elemen_fokus != "" and fase_duel == "PILIH_PEMAIN":
		for target in DATA_ELEMEN[elemen_fokus]["menang_lawan"]:
			_gambar_panah_kelemahan(posisi_titik_pemain[elemen_fokus], posisi_titik_pemain[target], Color(0, 1, 0, alpha_bg))
		_render_efek_faux3d(elemen_fokus, posisi_titik_pemain[elemen_fokus], 1.0, 1.0)
		
	if musuh_siap and alpha_bg > 0.0: _gambar_segel(tengah_musuh, alpha_bg)
	if pemain_siap and alpha_bg > 0.0: _gambar_segel(tengah_pemain, alpha_bg)

	if fase_duel in ["FADE_OUT", "ANIMASI_CORET", "ANIMASI_HILANG", "ANIMASI_MENANG", "ROLET", "RANGKUMAN"]:
		_render_efek_faux3d(elemen_pilihan_musuh, anim_pos_m, anim_scale_m, anim_alpha_m)
		_gambar_lingkaran_elemen(anim_pos_m, elemen_pilihan_musuh, anim_scale_m, anim_alpha_m)
		_gambar_coret_kalah(anim_pos_m, anim_scale_m, anim_coret_m, anim_alpha_m)
		
		_render_efek_faux3d(elemen_pilihan_pemain, anim_pos_p, anim_scale_p, anim_alpha_p)
		_gambar_lingkaran_elemen(anim_pos_p, elemen_pilihan_pemain, anim_scale_p, anim_alpha_p)
		_gambar_coret_kalah(anim_pos_p, anim_scale_p, anim_coret_p, anim_alpha_p)

	if alpha_rolet_m > 0.0:
		_gambar_rolet_mekanik(posisi_rolet_m, rotasi_rolet_m, angka_m, warna_m, alpha_rolet_m)
	if alpha_rolet_p > 0.0:
		_gambar_rolet_mekanik(posisi_rolet_p, rotasi_rolet_p, angka_p, warna_p, alpha_rolet_p)

	if cuaca_aktif == "kembang_api":
		for p in partikel_kembang_api:
			draw_circle(p.pos, p.size * (p.life/1.5), p.color)
	elif cuaca_aktif == "hujan":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		for p in partikel_hujan:
			draw_line(p.pos, p.pos + p.vel * 0.05, Color(0.7, 0.8, 1.0, p.life), 2.0)
		if kilat_petir_alpha > 0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, kilat_petir_alpha))

	# ========================================================
	# PERBAIKAN POSISI: MENGGAMBAR MASKING LUBANG KOIN DI SINI
	# (Masih di dalam blok fungsi _draw)
	# ========================================================
	if lubang_koin_progress > 0.0:
		var radius_maksimal = 290.0 # Jari-jari lubang, pas untuk besarnya koin
		var radius_sekarang = radius_maksimal * lubang_koin_progress
		var pusat = size / 2.0
		
		# Trik Jenius: Kita menggambar lingkaran bergaris tepi SANGAT TEBAL hingga keluar layar.
		# Bagian dalam (jari-jarinya) akan kosong tembus pandang menampakkan koin 3D.
		var tebal_layar = max(size.x, size.y) * 1.5 
		var warna_kaca_gelap = Color(0, 0, 0, 0.70)
		
		# Posisi gambar garis ditepikan setengah ketebalan agar tepat berada di luar radius lubang
		draw_arc(pusat, radius_sekarang + (tebal_layar / 2.0), 0, TAU, 128, warna_kaca_gelap, tebal_layar, true)

	# Koin 2D versi Very Low, digambar di atas lapisan gelap berlubang.
	if koin_ringan_tampil and koin_ringan_skala > 0.0:
		_gambar_koin_ringan(size / 2.0)

func _gambar_rolet_mekanik(pusat, rotasi, daftar_angka, warna_utama, alpha):
	if daftar_angka.size() == 0: return
	
	var radius = 135.0 
	var jumlah_potongan = daftar_angka.size()
	var sudut_per_potongan = TAU / float(jumlah_potongan)
	var font = ThemeDB.fallback_font

	draw_circle(pusat + Vector2(10, 10), radius + 5, Color(0, 0, 0, 0.4 * alpha))
	draw_circle(pusat, radius + 10, Color(0.85, 0.65, 0.15, alpha)) 
	draw_circle(pusat, radius + 5, Color(0.1, 0.1, 0.1, alpha)) 

	for i in range(jumlah_potongan):
		var sudut_tengah_asli = i * sudut_per_potongan
		var sudut_awal = sudut_tengah_asli - (sudut_per_potongan / 2.0)
		var sudut_akhir = sudut_tengah_asli + (sudut_per_potongan / 2.0)
		
		var c_warna = warna_utama if i % 2 == 0 else Color(0.15, 0.15, 0.15)
		c_warna.a = alpha
		
		draw_set_transform(pusat, rotasi, Vector2.ONE)
		_gambar_potongan_kue(Vector2.ZERO, radius, sudut_awal, sudut_akhir, c_warna)
		
		var titik_luar = Vector2(cos(sudut_awal), sin(sudut_awal)) * radius
		draw_line(Vector2.ZERO, titik_luar, Color(1, 1, 1, alpha), 3.0)

	for i in range(jumlah_potongan):
		var angka = daftar_angka[i]
		var sudut_tengah_asli = i * sudut_per_potongan
		var jarak_teks = radius * 0.65
		var sudut_global = rotasi + sudut_tengah_asli
		var pos_teks_pusat = pusat + Vector2(cos(sudut_global), sin(sudut_global)) * jarak_teks
		
		draw_set_transform(pos_teks_pusat, sudut_global, Vector2.ONE)
		draw_string(font, Vector2(-12, 12), str(angka), HORIZONTAL_ALIGNMENT_CENTER, -1, 35, Color(1, 1, 1, alpha))
		
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	draw_circle(pusat + Vector2(2, 3), 15.0, Color(0, 0, 0, 0.4 * alpha)) 
	draw_circle(pusat, 15.0, Color(0.85, 0.65, 0.15, alpha)) 
	draw_circle(pusat, 7.0, Color(0.2, 0.2, 0.2, alpha)) 

	var titik_jarum = PackedVector2Array([
		pusat + Vector2(radius - 5, 0),      
		pusat + Vector2(radius + 20, -15),   
		pusat + Vector2(radius + 20, 15)     
	])
	var warna_jarum = Color.YELLOW
	warna_jarum.a = alpha
	draw_polygon(titik_jarum, PackedColorArray([warna_jarum]))
	
	var tepi_jarum = titik_jarum
	tepi_jarum.append(titik_jarum[0])
	var warna_tepi = Color(0.6, 0.5, 0)
	warna_tepi.a = alpha
	draw_polyline(tepi_jarum, warna_tepi, 3.0)

func _gambar_potongan_kue(pusat, rad, s_awal, s_akhir, w):
	var titik = PackedVector2Array()
	titik.append(pusat)
	var langkah = 20
	for i in range(langkah + 1):
		var s = lerp(s_awal, s_akhir, float(i) / langkah)
		titik.append(pusat + Vector2(cos(s), sin(s)) * rad)
	draw_polygon(titik, PackedColorArray([w]))

func _gambar_segel(pusat, alpha):
	draw_circle(pusat, radius_pentagon + 40, Color(0.05, 0.05, 0.08, 0.98 * alpha))
	draw_arc(pusat, radius_pentagon + 40, 0, TAU, 64, Color(1, 0, 0, alpha), 6.0)
	draw_string(ThemeDB.fallback_font, pusat + Vector2(-90, 20), "LOCKED", HORIZONTAL_ALIGNMENT_CENTER, -1, 40, Color(1, 0.2, 0.2, alpha))

func _gambar_lingkaran_elemen(pos, nama, skala, alpha):
	if skala <= 0.01 or alpha <= 0.0: 
		return 
		
	var warna_dasar = DATA_ELEMEN[nama]["warna"]
	warna_dasar.a = alpha
	draw_circle(pos, radius_lingkaran * skala, warna_dasar)
	
	var ukuran_font = max(1, int(17 * skala))
	var lebar_teks = radius_lingkaran * 2.0 * skala
	var pos_teks = pos + Vector2(-radius_lingkaran * skala, 6 * skala)
	
	draw_string(ThemeDB.fallback_font, pos_teks, DATA_ELEMEN[nama]["nama"], HORIZONTAL_ALIGNMENT_CENTER, lebar_teks, ukuran_font, Color(1, 1, 1, alpha))

func _gambar_coret_kalah(pos, skala, progress, alpha):
	if progress <= 0.0 or alpha <= 0.0: return
	var jarak = radius_lingkaran * 1.3 * skala * progress
	var warna_coret = Color(1.0, 0.0, 0.0, alpha) 
	var tebal = 12.0 * skala
	draw_line(pos - Vector2(jarak, jarak), pos + Vector2(jarak, jarak), warna_coret, tebal)
	draw_line(pos - Vector2(-jarak, jarak), pos + Vector2(-jarak, jarak), warna_coret, tebal)

func _gambar_panah_kelemahan(awal, akhir, warna):
	var arah = (akhir - awal).normalized()
	var mulai_garis = awal + arah * (radius_lingkaran * 1.5)
	var akhir_garis = akhir - arah * (radius_lingkaran * 1.2)
	draw_line(mulai_garis, akhir_garis, warna, 5.0)
	var ukuran = 22.0
	var p1 = akhir_garis - arah * ukuran + Vector2(-arah.y, arah.x) * (ukuran * 0.6)
	var p2 = akhir_garis - arah * ukuran + Vector2(arah.y, -arah.x) * (ukuran * 0.6)
	draw_polygon(PackedVector2Array([akhir_garis, p1, p2]), PackedColorArray([warna]))

func _render_efek_faux3d(nama, pusat, skala, alpha):
	if alpha <= 0.0: return
	match nama:
		"api": _efek_animasi_api(pusat, skala, alpha)
		"air": _efek_animasi_air(pusat, skala, alpha)
		"angin": _efek_animasi_angin(pusat, skala, alpha)
		"tanah": _efek_animasi_tanah(pusat, skala, alpha)
		"petir": _efek_animasi_petir(pusat, skala, alpha)

func _efek_animasi_api(pusat, skala, alpha):
	for i in range(12):
		var t = waktu_animasi * 3.5 + (i * 0.4)
		var z_kedalaman = sin(t * 2.0)
		var geser_y = -fmod(t * 40.0, 100.0) * skala
		var geser_x = sin(t * 3.0 + i) * (15.0 + z_kedalaman * 5.0) * skala
		var persentase_hidup = 1.0 - (abs(geser_y) / (100.0 * skala))
		var ukuran = (25.0 + z_kedalaman * 10.0) * persentase_hidup * skala
		var posisi_partikel = pusat + Vector2(geser_x, geser_y - (20 * skala))
		draw_circle(posisi_partikel, ukuran * 1.6, Color(1.0, 0.2, 0.0, persentase_hidup * 0.3 * alpha))
		draw_circle(posisi_partikel, ukuran, Color(1.0, 0.4 + (persentase_hidup * 0.5), 0.0, persentase_hidup * 0.9 * alpha))

func _efek_animasi_air(pusat, skala, alpha):
	draw_set_transform(pusat, 0, Vector2(1.0, 0.45)) 
	for i in range(3):
		var t = fmod(waktu_animasi * 1.2 + (i * 0.33), 1.0) 
		var r = (radius_lingkaran + (t * 150.0)) * skala 
		draw_arc(Vector2(0, 20.0 * skala), r, 0, TAU, 40, Color(0.0, 0.3, 0.6, (1.0 - t) * 0.7 * alpha), 18.0 * skala)
		draw_arc(Vector2(0, 0), r, 0, TAU, 40, Color(0.4, 0.8, 1.0, (1.0 - t) * alpha), 8.0 * skala)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _efek_animasi_angin(pusat, skala, alpha):
	for i in range(50):
		var tinggi_persen = float(i) / 50.0
		var sudut = waktu_animasi * 18.0 + (tinggi_persen * PI * 6.0) 
		var radius_tornado = (15.0 + (tinggi_persen * radius_lingkaran * 1.8)) * skala
		var z = sin(sudut) 
		var x = cos(sudut) * radius_tornado
		var y = ((tinggi_persen - 0.5) * 160.0) * skala 
		var opasitas = ((z + 1.0) / 2.0 * 0.7 + 0.1) * alpha
		var ketebalan = (2.0 + ((z + 1.0) / 2.0 * 5.0)) * skala
		var warna = Color(0.7, 1.0, 0.9, opasitas * (1.0 - tinggi_persen))
		var sudut_next = waktu_animasi * 18.0 + ((tinggi_persen + 0.02) * PI * 6.0)
		var x_next = cos(sudut_next) * ((15.0 + ((tinggi_persen + 0.02) * radius_lingkaran * 1.8)) * skala)
		var y_next = (((tinggi_persen + 0.02) - 0.5) * 160.0) * skala
		draw_line(pusat + Vector2(x, y), pusat + Vector2(x_next, y_next), warna, ketebalan)

func _efek_animasi_tanah(pusat, skala, alpha):
	var rotasi_global = waktu_animasi * 1.5
	for i in range(5):
		var sudut = rotasi_global + i * (TAU / 5.0)
		var z_kedalaman = sin(sudut + waktu_animasi) 
		var skala_batu = (0.7 + (z_kedalaman * 0.4)) * skala
		var jarak = (radius_lingkaran + 40.0) * skala
		var posisi_batu = pusat + Vector2(cos(sudut), sin(sudut * 0.4)) * jarak 
		posisi_batu.y += sin(waktu_animasi * 4.0 + i) * 15.0 * skala 
		_gambar_kubus_3d(posisi_batu, 18.0 * skala_batu, alpha)
		
func _gambar_kubus_3d(pos, ukuran, alpha):
	if ukuran <= 0.5 or alpha <= 0.0:
		return
		
	var w = ukuran * 0.9
	var h = ukuran
	var p_tengah = pos
	var p_atas = pos + Vector2(0, -h)
	var p_bawah = pos + Vector2(0, h)
	var p_kiri_atas = pos + Vector2(-w, -h/2.0)
	var p_kiri_bawah = pos + Vector2(-w, h/2.0)
	var p_kanan_atas = pos + Vector2(w, -h/2.0)
	var p_kanan_bawah = pos + Vector2(w, h/2.0)
	
	draw_polygon(PackedVector2Array([p_tengah, p_kiri_atas, p_atas, p_kanan_atas]), PackedColorArray([Color(0.75, 0.6, 0.4, alpha)]))
	draw_polygon(PackedVector2Array([p_tengah, p_kiri_atas, p_kiri_bawah, p_bawah]), PackedColorArray([Color(0.4, 0.25, 0.15, alpha)]))
	draw_polygon(PackedVector2Array([p_tengah, p_bawah, p_kanan_bawah, p_kanan_atas]), PackedColorArray([Color(0.55, 0.4, 0.25, alpha)]))
	
func _efek_animasi_petir(pusat, skala, alpha):
	# Gunakan rng_visual agar tidak mencemari sistem rolet dan AI
	rng_visual.seed = int(waktu_animasi * 25.0) 
	for i in range(5):
		var sudut = rng_visual.randf_range(0, TAU)
		var jarak = (radius_lingkaran - 15) * skala
		var p_sekarang = pusat + Vector2(cos(sudut), sin(sudut)) * jarak
		var tebal_awal = 7.0 * skala
		for j in range(3): 
			var arah = sudut + rng_visual.randf_range(-0.9, 0.9)
			var p_next = p_sekarang + Vector2(cos(arah), sin(arah)) * rng_visual.randf_range(25.0, 50.0) * skala
			draw_line(p_sekarang, p_next, Color(0.3, 0.6, 1.0, 0.5 * alpha), tebal_awal + (9.0 * skala))
			draw_line(p_sekarang, p_next, Color(1.0, 1.0, 0.9, 1.0 * alpha), tebal_awal)
			p_sekarang = p_next
			tebal_awal *= 0.55
			
func _buat_kembang_api():
	var warna_api = [Color.RED, Color.CYAN, Color.YELLOW, Color.GREEN, Color.MAGENTA][rng_visual.randi_range(0, 4)]
	var asal = Vector2(rng_visual.randf_range(100, size.x - 100), size.y + 50)
	if rng_visual.randf() < 0.5: asal.x = rng_visual.randf_range(50, 300) 
	else: asal.x = rng_visual.randf_range(size.x - 300, size.x - 50) 
	
	for i in range(25):
		var sudut = rng_visual.randf_range(0, TAU)
		var kecepatan = rng_visual.randf_range(80.0, 350.0)
		partikel_kembang_api.append({
			"pos": asal - Vector2(0, rng_visual.randf_range(200, 500)),
			"vel": Vector2(cos(sudut), sin(sudut)) * kecepatan,
			"color": warna_api,
			"size": rng_visual.randf_range(3.0, 7.0),
			"life": rng_visual.randf_range(1.0, 2.0)
		})

func _buat_rintik_hujan():
	for i in range(5):
		partikel_hujan.append({
			"pos": Vector2(rng_visual.randf_range(0, size.x), -50),
			"vel": Vector2(rng_visual.randf_range(-100, 100), rng_visual.randf_range(1000, 1500)),
			"life": 1.0
		})

func _pilih_elemen_adaptif(peran_ai):
	var elemen_tersedia = ["api", "air", "angin", "tanah", "petir"]
	var elemen_favorit = "api"
	var skor_tertinggi = -1
	var memori = memori_serang_pemain if peran_ai == "bertahan" else memori_bertahan_pemain
	
	for el in memori:
		if memori[el] > skor_tertinggi:
			skor_tertinggi = memori[el]
			elemen_favorit = el
			
	if skor_tertinggi == 0: return elemen_tersedia.pick_random()
	var elemen_penawar = []
	for el in DATA_ELEMEN:
		if elemen_favorit in DATA_ELEMEN[el]["menang_lawan"]:
			elemen_penawar.append(el)
	if randi_range(1, 100) <= 60 and elemen_penawar.size() > 0:
		return elemen_penawar.pick_random()
	else:
		return elemen_tersedia.pick_random()

func atur_sudut_pandang(nama_p: String, nama_m: String, tonton: bool) -> void:
	# Dipanggil pemain.gd sebelum tiap duel. 2 pemain: ("YOU", "ENEMY", false)
	# -- semua teks sama persis seperti versi lama.
	nama_sisi_p = nama_p
	nama_sisi_m = nama_m
	mode_tonton = tonton

func _kata_serang(nama: String) -> String:
	return "YOU ATTACK!" if nama == "YOU" else nama + " ATTACKS!"

func _kata_menang(nama: String) -> String:
	return "YOU WIN THE FIGHT!" if nama == "YOU" else nama + " WINS THE FIGHT!"

func _nama_kecil(nama: String) -> String:
	# "ENEMY" -> "Enemy", "YOU" -> "You", "P3" -> "P3"
	if nama == "YOU": return "You"
	if nama == "ENEMY": return "Enemy"
	return nama

func skor_duel(el_a: String, el_d: String, angka_a: int, angka_d: int, nyawa_kandang: int, bonus_pedang: int) -> Array:
	# Skor akhir [penyerang, pembela] dengan rumus yang PERSIS sama dengan
	# perhitungan di jalankan_duel. Dipakai host untuk tahu lebih dulu apakah
	# duelnya akan SERI (perlu lempar koin) sebelum animasinya diputar.
	var bonus_a = 0
	var bonus_d = 0
	if el_a != el_d:
		if el_d in DATA_ELEMEN[el_a]["menang_lawan"]: bonus_a = 3
		else: bonus_d = 3
	return [angka_a + bonus_a + bonus_pedang, angka_d + bonus_d + nyawa_kandang]

func cari_angka_seri(siapa_penyerang: String, el_pemain: String, el_musuh: String, nyawa_kandang: int, bonus_pedang: int) -> Array:
	# KHUSUS saklar uji UJI_SERI. Mengembalikan [angka_rolet_pemain, angka_rolet_musuh]
	# yang membuat skor akhir kedua pihak SAMA, dengan rumus yang persis sama
	# seperti perhitungan skor di jalankan_duel. Kosong [] kalau tidak ada pasangan
	# yang mungkin (misalnya HP petak terlalu tinggi) -- duel lalu berjalan normal.
	var bonus_p = 0
	var bonus_m = 0
	if el_pemain != el_musuh:
		if el_musuh in DATA_ELEMEN[el_pemain]["menang_lawan"]: bonus_p = 3
		else: bonus_m = 3
	var tambahan_p = bonus_p + (nyawa_kandang if siapa_penyerang == "musuh" else 0) + (bonus_pedang if siapa_penyerang == "pemain" else 0)
	var tambahan_m = bonus_m + (nyawa_kandang if siapa_penyerang == "pemain" else 0) + (bonus_pedang if siapa_penyerang == "musuh" else 0)
	var pool_p = angka_penyerang if siapa_penyerang == "pemain" else angka_pembela
	var pool_m = angka_pembela if siapa_penyerang == "pemain" else angka_penyerang
	var pasangan = []
	for a_p in pool_p:
		var a_m = a_p + tambahan_p - tambahan_m
		if a_m in pool_m: pasangan.append([a_p, a_m])
	if pasangan.is_empty(): return []
	return pasangan[rng.randi_range(0, pasangan.size() - 1)]

# ========================================================
# LOGIKA UTAMA PERTARUNGAN (DENGAN PENERIMAAN BONUS PEDANG)
# ========================================================
func siapkan_pilih_elemen(judul_teks: String) -> void:
	# Bagian B2: membersihkan tampilan duel SEBELUM pemain memilih elemen.
	# Tanpa ini, duel kedua dan seterusnya masih menampilkan sisa tampilan duel
	# sebelumnya (kembang api, segel, panel skor) karena pemilihan elemen di
	# multiplayer terjadi di LUAR jalankan_duel -- jadi blok pembersihan yang
	# ada di awal jalankan_duel tidak pernah tersentuh lebih dulu.
	show()
	self.color = warna_bg_asli
	lubang_koin_progress = 0.0
	musuh_siap = false
	pemain_siap = false
	alpha_bg = 1.0
	alpha_rolet_p = 0.0
	alpha_rolet_m = 0.0
	rotasi_rolet_p = 0.0
	rotasi_rolet_m = 0.0
	elemen_pilihan_musuh = ""
	elemen_pilihan_pemain = ""
	elemen_fokus = ""
	cuaca_aktif = ""
	partikel_kembang_api.clear()
	partikel_hujan.clear()
	anim_alpha_p = 1.0
	anim_alpha_m = 1.0
	anim_coret_p = 0.0
	anim_coret_m = 0.0

	teks_bantuan.text = ""
	panel_p.hide()
	panel_m.hide()
	panel_tengah.hide()
	tombol_putar.hide()

	teks_judul.text = judul_teks
	teks_judul.modulate = Color.CYAN
	fase_duel = "PILIH_PEMAIN"
	queue_redraw()

func siapkan_tonton_pilih_elemen(judul_teks: String) -> void:
	# Layar duel mode TONTON (penonton, bukan peserta) dibuka SEJAK AWAL fase
	# pilih elemen -- bukan cuma teks placeholder sampai "BOTH LOCKED!". Segel
	# LOCKED tiap peserta (lihat pemain.gd _tampilkan_segel_terkunci) langsung
	# tergambar di sini satu per satu begitu diterima.
	siapkan_pilih_elemen(judul_teks)
	fase_duel = "MENUNGGU_MUSUH" # klik diabaikan oleh penjaga _on_tombol_ditekan
	for btn in tombol_elemen.values(): btn.disabled = true
	queue_redraw()

func jalankan_duel(siapa_penyerang, nyawa_kandang = 0, kamera_node = null, teks_dadu_node = null, bonus_pedang = 0, naskah: Dictionary = {}):
	# Bagian B2: kalau "naskah" terisi, KEDUA pilihan elemen dan KEDUA angka
	# rolet sudah ditentukan host -- device ini (host sendiri, atau client yang
	# memutar ulang) tinggal memutar animasi yang identik, tanpa menunggu klik
	# atau memanggil AI/RNG apapun. Kosong (default) = perilaku asli, solo vs AI.
	show()
	self.color = warna_bg_asli
	lubang_koin_progress = 0.0 # <--- TAMBAHKAN BARIS INI
	fase_duel = "MENUNGGU_MUSUH"
	musuh_siap = false
	pemain_siap = false
	alpha_bg = 1.0
	alpha_rolet_p = 0.0
	alpha_rolet_m = 0.0
	rotasi_rolet_p = 0.0
	rotasi_rolet_m = 0.0
	elemen_pilihan_musuh = ""
	elemen_pilihan_pemain = ""
	elemen_fokus = ""
	# Lempar koin multiplayer: buang titipan dari duel sebelumnya.
	koin_pilihan_lawan = ""
	koin_hasil_jaringan = ""
	queue_redraw() # <--- TAMBAHKAN INI UNTUK MEMBERSIHKAN LAYAR AWAL

	teks_bantuan.text = ""
	panel_p.hide()
	panel_m.hide()
	panel_tengah.hide()
	tombol_putar.hide()
	
	if siapa_penyerang == "pemain":
		angka_p = angka_penyerang
		warna_p = warna_penyerang
		angka_m = angka_pembela
		warna_m = warna_pembela
	else:
		angka_p = angka_pembela
		warna_p = warna_pembela
		angka_m = angka_penyerang
		warna_m = warna_penyerang
	
	for btn in tombol_elemen.values(): btn.disabled = true
	
	if not naskah.is_empty():
		# --- Bagian B2: kedua pilihan sudah pasti, tidak ada yang perlu ditunggu ---
		elemen_pilihan_musuh = naskah["elemen_musuh"]
		elemen_pilihan_pemain = naskah["elemen_pemain"]

		# Kedua segel LOCKED langsung ditampilkan (jangan sempat menghilang dulu —
		# blok pembersih di atas sudah menyetelnya jadi false), lalu diberi jeda
		# supaya pemain sempat melihat keduanya terkunci sebelum dibuka.
		musuh_siap = true
		pemain_siap = true
		teks_bantuan.text = ""

		if siapa_penyerang == "pemain":
			teks_judul.text = _kata_serang(nama_sisi_p) + " BOTH LOCKED!"
			teks_judul.modulate = Color.CYAN
		else:
			teks_judul.text = _kata_serang(nama_sisi_m) + " BOTH LOCKED!"
			teks_judul.modulate = Color.RED

		queue_redraw()
		await get_tree().create_timer(2.0).timeout
	else:
		# --- Alur asli: solo vs AI ---
		if siapa_penyerang == "pemain":
			teks_judul.text = _kata_serang(nama_sisi_p) + " " + nama_sisi_m + " IS THINKING..."
			teks_judul.modulate = Color.CYAN
			elemen_pilihan_musuh = _pilih_elemen_adaptif("bertahan")
		else:
			teks_judul.text = _kata_serang(nama_sisi_m) + " " + nama_sisi_m + " IS THINKING..."
			teks_judul.modulate = Color.RED
			elemen_pilihan_musuh = _pilih_elemen_adaptif("menyerang")
			
		await get_tree().create_timer(2.0).timeout
		musuh_siap = true
		queue_redraw() # <--- TAMBAHKAN INI UNTUK MEMUNCULKAN SEGEL MERAH MUSUH
		teks_judul.text = nama_sisi_m + " CHOSE! YOUR TURN!"
		fase_duel = "PILIH_PEMAIN"
		
		for btn in tombol_elemen.values(): btn.disabled = false
		elemen_pilihan_pemain = await self.elemen_diklik
		for btn in tombol_elemen.values(): btn.disabled = true
		teks_bantuan.text = ""
		
		pemain_siap = true
		queue_redraw() # <--- TAMBAHKAN INI UNTUK MEMUNCULKAN SEGEL BIRU PEMAIN
	fase_duel = "SEGEL_KEDUANYA"
	
	if siapa_penyerang == "pemain": memori_serang_pemain[elemen_pilihan_pemain] += 1
	else: memori_bertahan_pemain[elemen_pilihan_pemain] += 1
		
	teks_judul.text = "UNLOCKING..."
	teks_judul.modulate = Color.YELLOW
	await get_tree().create_timer(1.2).timeout
	
	anim_pos_p = posisi_titik_pemain[elemen_pilihan_pemain]
	anim_scale_p = 1.0
	anim_alpha_p = 1.0
	anim_coret_p = 0.0
	
	anim_pos_m = posisi_titik_musuh[elemen_pilihan_musuh]
	anim_scale_m = 1.0
	anim_alpha_m = 1.0
	anim_coret_m = 0.0
	
	fase_duel = "FADE_OUT"
	var tween_fade = create_tween()
	tween_fade.tween_property(self, "alpha_bg", 0.0, 1.0)
	pemutar_suara.stream = stream_elemen[elemen_pilihan_musuh]
	pemutar_suara.pitch_scale = 0.9 
	pemutar_suara.play()
	
	await tween_fade.finished
	await get_tree().create_timer(0.5).timeout
	
	var bonus_pemain = 0
	var bonus_musuh = 0
	var pemenang = ""
	
	if elemen_pilihan_pemain == elemen_pilihan_musuh:
		teks_judul.text = "ELEMENT DRAW! (+0)"
		pemenang = "seri"
	elif elemen_pilihan_musuh in DATA_ELEMEN[elemen_pilihan_pemain]["menang_lawan"]:
		teks_judul.text = "ELEMENT WIN! " + _nama_kecil(nama_sisi_p) + " +3"
		bonus_pemain = 3
		pemenang = "pemain"
	else:
		teks_judul.text = "ELEMENT LOSE! " + _nama_kecil(nama_sisi_m) + " +3"
		bonus_musuh = 3
		pemenang = "musuh"
		
	fase_duel = "ANIMASI_CORET"
	var tween_coret = create_tween()
	if pemenang == "pemain": 
		tween_coret.tween_property(self, "anim_coret_m", 1.0, 0.3)
	elif pemenang == "musuh": 
		tween_coret.tween_property(self, "anim_coret_p", 1.0, 0.3)
	else:
		tween_coret.tween_interval(0.3)
		
	await tween_coret.finished
	await get_tree().create_timer(1.0).timeout 
	
	fase_duel = "ANIMASI_HILANG"
	var tween_hilang = create_tween()
	if pemenang == "pemain": 
		tween_hilang.tween_property(self, "anim_alpha_m", 0.0, 0.4)
	elif pemenang == "musuh": 
		tween_hilang.tween_property(self, "anim_alpha_p", 0.0, 0.4)
	else:
		tween_hilang.tween_interval(0.4)
		
	await tween_hilang.finished
	
	fase_duel = "ANIMASI_MENANG"
	var tween_menang = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	var posisi_tengah = size / 2.0
	
	if pemenang == "pemain":
		tween_menang.tween_property(self, "anim_pos_p", posisi_tengah, 0.8)
		tween_menang.tween_property(self, "anim_scale_p", 1.8, 0.8)
	elif pemenang == "musuh":
		tween_menang.tween_property(self, "anim_pos_m", posisi_tengah, 0.8)
		tween_menang.tween_property(self, "anim_scale_m", 1.8, 0.8)
	else:
		tween_menang.tween_property(self, "anim_pos_p", posisi_tengah, 0.6)
		tween_menang.tween_property(self, "anim_pos_m", posisi_tengah, 0.6)
		tween_menang.tween_property(self, "anim_scale_p", 1.4, 0.6)
		tween_menang.tween_property(self, "anim_scale_m", 1.4, 0.6)
		tween_menang.tween_property(self, "anim_scale_p", 0.0, 0.3).set_delay(0.6)
		tween_menang.tween_property(self, "anim_scale_m", 0.0, 0.3).set_delay(0.6)
		tween_menang.tween_property(self, "anim_alpha_p", 0.0, 0.3).set_delay(0.6)
		tween_menang.tween_property(self, "anim_alpha_m", 0.0, 0.3).set_delay(0.6)

	await tween_menang.finished
	await get_tree().create_timer(0.5).timeout

	fase_duel = "ROLET_PEMAIN"
	putar_diklik = false
	alpha_rolet_p = 1.0
	if mode_tonton:
		# Penonton: tidak ada yang bisa diklik, roletnya berputar sendiri.
		teks_judul.text = nama_sisi_p + " WHEEL SPINNING..."
		await get_tree().create_timer(0.8).timeout
	else:
		tombol_putar.show()
		teks_judul.text = "SPIN YOUR WHEEL!"
		
		waktu_tunggu_putar = 0.0
		while waktu_tunggu_putar < 2.0 and not putar_diklik:
			await get_tree().process_frame
			waktu_tunggu_putar += get_process_delta_time()
			
		tombol_putar.hide()
		teks_judul.text = "WHEEL SPINNING..."
	
	# Saklar uji UJI_SERI (jalur solo): pakai pasangan angka yang membuat skor
	# akhir sama persis. Di multiplayer tidak perlu -- host sudah memasukkan
	# angka serinya ke dalam naskah.
	var angka_seri = []
	if paksa_seri and naskah.is_empty():
		angka_seri = cari_angka_seri(siapa_penyerang, elemen_pilihan_pemain, elemen_pilihan_musuh, nyawa_kandang, bonus_pedang)

	# Kalau naskah terisi, angkanya sudah ditentukan host -- jangan diacak lagi.
	var nilai_rolet_final_p = naskah["angka_p"] if not naskah.is_empty() else angka_p[rng.randi_range(0, angka_p.size() - 1)]
	if not angka_seri.is_empty(): nilai_rolet_final_p = angka_seri[0]
	var target_index_p = angka_p.find(nilai_rolet_final_p)
	
	var sudut_per_potongan_p = TAU / float(angka_p.size())
	var target_rad_p = -(target_index_p * sudut_per_potongan_p)
	
	# Ganti randf_range
	var total_rotasi_p = target_rad_p + deg_to_rad(rng.randf_range(-10.0, 10.0)) + (TAU * 5)
	
	var tw_rolet_p = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw_rolet_p.tween_property(self, "rotasi_rolet_p", total_rotasi_p, 3.5)
	await tw_rolet_p.finished
	await get_tree().create_timer(0.5).timeout

	fase_duel = "ROLET_MUSUH"
	alpha_rolet_m = 1.0
	teks_judul.text = nama_sisi_m + " WHEEL SPINNING..."
	teks_judul.modulate = Color.RED
	
	var nilai_rolet_final_m = naskah["angka_m"] if not naskah.is_empty() else angka_m[rng.randi_range(0, angka_m.size() - 1)]
	if not angka_seri.is_empty(): nilai_rolet_final_m = angka_seri[1]
	var target_index_m = angka_m.find(nilai_rolet_final_m)
	
	var sudut_per_potongan_m = TAU / float(angka_m.size())
	var target_rad_m = -(target_index_m * sudut_per_potongan_m)
	
	# Ganti randf_range
	var total_rotasi_m = target_rad_m + deg_to_rad(rng.randf_range(-10.0, 10.0)) + (TAU * 5)
	
	var tw_rolet_m = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw_rolet_m.tween_property(self, "rotasi_rolet_m", total_rotasi_m, 3.5)
	await tw_rolet_m.finished
	await get_tree().create_timer(0.8).timeout

	# CARI BLOK KODE "fase_duel = "RANGKUMAN"" DAN GANTI DARI TITIK INI:
	fase_duel = "RANGKUMAN"
	var tw_fade_rolet = create_tween().set_parallel(true)
	tw_fade_rolet.tween_property(self, "alpha_rolet_p", 0.15, 0.5)
	tw_fade_rolet.tween_property(self, "alpha_rolet_m", 0.15, 0.5)
	
	teks_judul.text = "CALCULATING TOTAL SCORE..."
	teks_judul.modulate = Color.YELLOW
	
	# Penambahan logika bonus_pedang untuk penyerang
	var skor_akhir_p = nilai_rolet_final_p + bonus_pemain + (nyawa_kandang if siapa_penyerang == "musuh" else 0) + (bonus_pedang if siapa_penyerang == "pemain" else 0)
	var skor_akhir_m = nilai_rolet_final_m + bonus_musuh + (nyawa_kandang if siapa_penyerang == "pemain" else 0) + (bonus_pedang if siapa_penyerang == "musuh" else 0)
	
	# Pemasangan teks dinamis agar UI tidak berlubang (tanpa spasi kosong berlebih)
	var teks_panel_p = "[center][b]Wheel Number: " + str(nilai_rolet_final_p) + "[/b]\nElement Bonus: +" + str(bonus_pemain)
	if siapa_penyerang == "musuh" and nyawa_kandang > 0: teks_panel_p += "\nTile HP: +" + str(nyawa_kandang)
	if siapa_penyerang == "pemain" and bonus_pedang > 0: teks_panel_p += "\nCard Bonus: +" + str(bonus_pedang)
	teks_panel_p += "\n\n[color=yellow][b]TOTAL SCORE: " + str(skor_akhir_p) + "[/b][/color][/center]"
	
	var teks_panel_m = "[center][b]Wheel Number: " + str(nilai_rolet_final_m) + "[/b]\nElement Bonus: +" + str(bonus_musuh)
	if siapa_penyerang == "pemain" and nyawa_kandang > 0: teks_panel_m += "\nTile HP: +" + str(nyawa_kandang)
	if siapa_penyerang == "musuh" and bonus_pedang > 0: teks_panel_m += "\nCard Bonus: +" + str(bonus_pedang)
	teks_panel_m += "\n\n[color=yellow][b]TOTAL SCORE: " + str(skor_akhir_m) + "[/b][/color][/center]"
	
	teks_p.text = teks_panel_p
	teks_m.text = teks_panel_m
	
	panel_p.modulate.a = 0
	panel_m.modulate.a = 0
	panel_p.show()
	panel_m.show()
	
	tw_fade_rolet.tween_property(panel_p, "modulate:a", 1.0, 0.5)
	tw_fade_rolet.tween_property(panel_m, "modulate:a", 1.0, 0.5)
	
	await get_tree().create_timer(3.0).timeout
	
	fase_duel = "PENGUMUMAN_TRANSISI"
	var tw_bersih = create_tween().set_parallel(true)
	tw_bersih.tween_property(self, "alpha_rolet_p", 0.0, 0.5)
	tw_bersih.tween_property(self, "alpha_rolet_m", 0.0, 0.5)
	tw_bersih.tween_property(self, "anim_alpha_p", 0.0, 0.5)
	tw_bersih.tween_property(self, "anim_alpha_m", 0.0, 0.5)
	tw_bersih.tween_property(panel_p, "modulate:a", 0.0, 0.5)
	tw_bersih.tween_property(panel_m, "modulate:a", 0.0, 0.5)
	await tw_bersih.finished
	
	panel_p.hide()
	panel_m.hide()
	
	fase_duel = "PENGUMUMAN_FINAL"
	panel_tengah.modulate.a = 0
	panel_tengah.show()
	
	var pemenang_akhir = ""
	var elemen_menang = ""
	
	if skor_akhir_p > skor_akhir_m:
		pemenang_akhir = "pemain"
		elemen_menang = elemen_pilihan_pemain if bonus_pemain > 0 else ""
		teks_judul.text = _kata_menang(nama_sisi_p)
		teks_judul.modulate = Color.CYAN
		cuaca_aktif = "kembang_api"
		if ResourceLoader.exists("res://suara/kembang_api.wav"):
			sfx_cuaca.stream = preload("res://suara/kembang_api.wav")
			sfx_cuaca.play()
			
	elif skor_akhir_m > skor_akhir_p:
		pemenang_akhir = "musuh"
		elemen_menang = elemen_pilihan_musuh if bonus_musuh > 0 else ""
		teks_judul.text = _kata_menang(nama_sisi_m)
		teks_judul.modulate = Color.RED
		# Penonton tidak ikut "kalah": yang menang tetap dirayakan kembang api.
		cuaca_aktif = "kembang_api" if mode_tonton else "hujan"
		if ResourceLoader.exists("res://suara/hujan_petir.wav"):
			sfx_cuaca.stream = preload("res://suara/hujan_petir.wav")
			sfx_cuaca.play()
			
	else:
		teks_judul.text = "SCORE TIED! GET READY FOR TIE-BREAKER..."
		teks_judul.modulate = Color.YELLOW
		panel_tengah.hide()
		cuaca_aktif = ""
		var tw_gelap = create_tween()
		tw_gelap.tween_property(self, "color", Color(0.0, 0.0, 0.0, 0.70), 1.5) 
		await tw_gelap.finished
		await get_tree().create_timer(0.5).timeout
		
		teks_judul.text = "SCORE TIED! COIN FLIP DECIDES!" if mode_tonton else "SCORE TIED! CHOOSE YOUR COIN GUESS!"
		var tw_tegang = create_tween().bind_node(self).set_loops() # <--- PERBAIKAN DI SINI
		tw_tegang.tween_property(teks_judul, "modulate", Color(1.0, 0.3, 0.3), 0.5).set_trans(Tween.TRANS_SINE)
		tw_tegang.tween_property(teks_judul, "modulate", Color(1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
		
		tombol_kepala.position = Vector2(size.x / 2.0 - 250, size.y / 2.0 + 80)
		tombol_ekor.position = Vector2(size.x / 2.0 + 20, size.y / 2.0 + 80)

		var pilihan_pemain = ""
		var hasil_koin_host = "" # kosong = koin diacak sendiri (solo)
		if naskah.is_empty():
			# --- Alur asli: solo vs AI, pemain langsung menebak ---
			_tampilkan_tombol_koin("")
			pilihan_pemain = await self.koin_dipilih
		else:
			# --- Multiplayer: pembela memilih dulu, penyerang dapat sisanya ---
			var data_koin = await _pilih_koin_jaringan(siapa_penyerang, naskah)
			pilihan_pemain = data_koin["pilihan_lokal"]
			hasil_koin_host = data_koin["hasil"]
		tw_tegang.kill()
		teks_judul.modulate = Color.WHITE
		tombol_kepala.hide()
		tombol_ekor.hide()
		
		teks_judul.hide() 
		lubang_koin_progress = 0.001 
		self.color = Color.TRANSPARENT 
		
		var tw_lubang = create_tween()
		tw_lubang.tween_property(self, "lubang_koin_progress", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw_lubang.finished
		
		var pemain_tebak_benar = await _eksekusi_flip_koin(pilihan_pemain, kamera_node, teks_dadu_node, hasil_koin_host)
		teks_judul.show()
		
		if pemain_tebak_benar:
			pemenang_akhir = "pemain"
			teks_judul.text = ("YOU WON THE TIE-BREAKER!" if nama_sisi_p == "YOU" else nama_sisi_p + " WON THE TIE-BREAKER!")
			teks_judul.modulate = Color.CYAN
		else:
			pemenang_akhir = "musuh"
			teks_judul.text = nama_sisi_m + " WON THE TIE-BREAKER!"
			teks_judul.modulate = Color.RED
			
		await get_tree().create_timer(3.0).timeout

	if panel_tengah.visible:
		var warna_teks = "cyan" if pemenang_akhir == "pemain" else "red"
		var akhir_skor = skor_akhir_p if pemenang_akhir == "pemain" else skor_akhir_m
		var akhir_dadu = nilai_rolet_final_p if pemenang_akhir == "pemain" else nilai_rolet_final_m
		var akhir_bonus = bonus_pemain if pemenang_akhir == "pemain" else bonus_musuh
		
		# --- AWAL PENAMBAHAN KODE ---
		var teks_n_p = ""
		if siapa_penyerang == "musuh" and nyawa_kandang > 0: teks_n_p += "Tile HP: +" + str(nyawa_kandang) + "\n"
		if siapa_penyerang == "pemain" and bonus_pedang > 0: teks_n_p += "Card Bonus: +" + str(bonus_pedang) + "\n"
		
		var teks_n_m = ""
		if siapa_penyerang == "pemain" and nyawa_kandang > 0: teks_n_m += "Tile HP: +" + str(nyawa_kandang) + "\n"
		if siapa_penyerang == "musuh" and bonus_pedang > 0: teks_n_m += "Card Bonus: +" + str(bonus_pedang) + "\n"
		# --- AKHIR PENAMBAHAN KODE ---

		var ekstra = teks_n_p if pemenang_akhir == "pemain" else teks_n_m
		
		var ruang_kosong = "\n\n\n\n\n\n\n" if elemen_menang != "" else "\n\n"
		
		var template_bukti = "[center][b]VICTORY PROOF[/b]\n\nWheel Number: %s\nElement Bonus: +%s\n%s%s[color=%s][font_size=40][b]FINAL SCORE: %s[/b][/font_size][/color][/center]"
		teks_tengah.text = template_bukti % [akhir_dadu, akhir_bonus, ekstra, ruang_kosong, warna_teks, akhir_skor]
		
		var tw_tengah = create_tween()
		tw_tengah.tween_property(panel_tengah, "modulate:a", 1.0, 0.5)
		
		if elemen_menang != "":
			var pusat_panel = panel_tengah.position + Vector2(panel_tengah.size.x / 2.0, panel_tengah.size.y / 2.0 + 35)
			if pemenang_akhir == "pemain":
				anim_pos_p = pusat_panel
				anim_scale_p = 1.3
				anim_alpha_p = 1.0
			else:
				anim_pos_m = pusat_panel
				anim_scale_m = 1.3
				anim_alpha_m = 1.0
				
		await get_tree().create_timer(4.5).timeout

	cuaca_aktif = ""
	hide()
	duel_selesai.emit()

	return {
		"skor_akhir_pemain": skor_akhir_p,
		"skor_akhir_musuh": skor_akhir_m,
		"pemenang_final": pemenang_akhir
	}

func _eksekusi_flip_koin(pilihan_pemain, kamera_node, teks_dadu_node, hasil_dari_host: String = ""):
	# ==========================================================
	# PERBAIKAN 4A: Panggil teks_dadu keluar khusus untuk koin
	# ==========================================================
	if teks_dadu_node:
		teks_dadu_node.show()
	
	# Menerjemahkan sistem pilihan
	var terjemahan_pilihan = "HEADS" if pilihan_pemain == "kepala" else "TAILS"
	teks_dadu_node.text = _nama_kecil(nama_sisi_p) + " guessed " + terjemahan_pilihan + ". Flipping coin..."

	# Setelan grafis Very Low: koin 2D super ringan. Versi 3D di bawah dibiarkan
	# utuh untuk setelan Low, Medium, dan High.
	if AudioGrafis.baca_tingkat() == "sangat_rendah":
		var sisi_ringan = ["kepala", "ekor"]
		var hasil_ringan = sisi_ringan[rng.randi_range(0, 1)]
		if hasil_dari_host != "": hasil_ringan = hasil_dari_host
		var benar_ringan = (hasil_ringan == pilihan_pemain)
		await _animasi_koin_ringan(hasil_ringan, benar_ringan, teks_dadu_node)
		if teks_dadu_node:
			teks_dadu_node.hide()
		return benar_ringan

	var koin = CSGCylinder3D.new()
	# KOIN DIPERBESAR AGAR LEBIH TERLIHAT MEWAH
	koin.radius = 2.4  
	koin.height = 0.25  
	koin.sides = 64
	
	# MATERIAL FISIK KOIN DIKEMBALIKAN (Tanpa Emission)
	var mat_emas = StandardMaterial3D.new()
	mat_emas.albedo_color = Color(1.0, 0.85, 0.2) 
	mat_emas.metallic = 1.0 
	mat_emas.roughness = 0.25
	koin.material = mat_emas
	
	var teks_kepala = Label3D.new()
	teks_kepala.text = "HEADS"
	teks_kepala.font_size = 200 # Teks disesuaikan
	teks_kepala.outline_size = 40
	teks_kepala.modulate = Color(0.65, 0.45, 0.0)
	teks_kepala.outline_modulate = Color(1.0, 0.95, 0.5)
	teks_kepala.position.y = 0.13
	teks_kepala.rotation_degrees = Vector3(-90, 0, 0)
	teks_kepala.shaded = true # Shaded diaktifkan agar bereaksi pada lampu
	koin.add_child(teks_kepala)
	
	var teks_ekor = Label3D.new()
	teks_ekor.text = "TAILS"
	teks_ekor.font_size = 200
	teks_ekor.outline_size = 40
	teks_ekor.modulate = Color(0.65, 0.45, 0.0)
	teks_ekor.outline_modulate = Color(1.0, 0.95, 0.5)
	teks_ekor.position.y = -0.13
	teks_ekor.rotation_degrees = Vector3(90, 0, 0)
	teks_ekor.shaded = true
	koin.add_child(teks_ekor)
	
	kamera_node.add_child(koin)
	koin.position = Vector3(0, 0, -5.5) 
	koin.scale = Vector3.ZERO
	
	# ==========================================================
	# LAMPU EKSTERNAL DIKEMBALIKAN (Karena tidak tertutup kaca lagi)
	# ==========================================================
	var lampu_koin = OmniLight3D.new()
	lampu_koin.light_color = Color(1.0, 0.95, 0.8)
	lampu_koin.light_energy = 10.0 # Lampu terang benderang
	lampu_koin.omni_range = 10.0 
	lampu_koin.position = Vector3(0, 1.5, -2.5) # Posisi serong depan atas
	kamera_node.add_child(lampu_koin)
	
	var sisi_koin = ["kepala", "ekor"]
	var hasil_koin = sisi_koin[rng.randi_range(0, 1)]
	# Multiplayer: hasilnya sudah diundi host -- kedua layar WAJIB jatuh sama.
	if hasil_dari_host != "": hasil_koin = hasil_dari_host
	var tebakan_benar = (hasil_koin == pilihan_pemain)
	
	var putaran_cepat = 360 * 12 
	var target_x = 90 + putaran_cepat if hasil_koin == "kepala" else 270 + putaran_cepat
	koin.rotation_degrees = Vector3(90, 0, 0) 
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(koin, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(koin, "rotation_degrees:x", float(target_x), 3.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	await tw.finished
	
	var tw_pop = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pop.tween_property(koin, "scale", Vector3.ONE * 1.15, 0.15)
	tw_pop.tween_property(koin, "scale", Vector3.ONE, 0.15)
	
	# Menerjemahkan hasil output
	var terjemahan_hasil = "HEADS" if hasil_koin == "kepala" else "TAILS"
	teks_dadu_node.text = "RESULT: " + terjemahan_hasil + ("! RIGHT Guess!" if tebakan_benar else "! WRONG Guess!")
	await get_tree().create_timer(2.5).timeout
	
	var tw_hilang = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw_hilang.tween_property(koin, "scale", Vector3.ZERO, 0.3)
	await tw_hilang.finished
	
	koin.queue_free()
	lampu_koin.queue_free() 
	
	# ==========================================================
	# PERBAIKAN 4B: Sembunyikan lagi agar layar bersih di akhir
	# ==========================================================
	if teks_dadu_node:
		teks_dadu_node.hide()

	return tebakan_benar

func _animasi_koin_ringan(hasil_koin: String, tebakan_benar: bool, teks_dadu_node) -> void:
	# Pengganti koin 3D untuk setelan Very Low. Urutan & durasinya SAMA PERSIS
	# dengan versi 3D (muncul 0.5 dtk sambil berputar 3.5 dtk, "pop", hasil tampil
	# 2.5 dtk, lalu mengecil 0.3 dtk) -- supaya di multiplayer kedua layar tetap
	# serempak walau device lawan memakai versi 3D.
	koin_ringan_sudut = 0.0
	koin_ringan_skala = 0.0
	koin_ringan_tampil = true
	var target_sudut = 360.0 * 6 + (0.0 if hasil_koin == "kepala" else 180.0)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "koin_ringan_skala", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "koin_ringan_sudut", target_sudut, 3.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tw.finished

	var tw_pop = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_pop.tween_property(self, "koin_ringan_skala", 1.15, 0.15)
	tw_pop.tween_property(self, "koin_ringan_skala", 1.0, 0.15)

	var terjemahan_hasil = "HEADS" if hasil_koin == "kepala" else "TAILS"
	teks_dadu_node.text = "RESULT: " + terjemahan_hasil + ("! RIGHT Guess!" if tebakan_benar else "! WRONG Guess!")
	await get_tree().create_timer(2.5).timeout

	var tw_hilang = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw_hilang.tween_property(self, "koin_ringan_skala", 0.0, 0.3)
	await tw_hilang.finished
	koin_ringan_tampil = false
	queue_redraw()

func _gambar_koin_ringan(pusat: Vector2) -> void:
	# Koin berputar pada sumbu mendatar: tingginya mengikuti |cos(sudut)| dan sisi
	# yang terlihat berganti tiap setengah putaran. Hanya lingkaran + teks biasa,
	# jenis gambar yang sudah dipakai layar duel ini sejak awal.
	var c = cos(deg_to_rad(koin_ringan_sudut))
	var pipih = max(abs(c), 0.06) # jangan sampai hilang total saat tepat menyamping
	var redup = 0.35 * (1.0 - abs(c)) # makin menyamping makin gelap, kesan terkena cahaya
	var r = 200.0
	draw_set_transform(pusat, 0.0, Vector2(koin_ringan_skala, koin_ringan_skala * pipih))
	draw_circle(Vector2.ZERO, r, Color(0.7, 0.5, 0.05).darkened(redup))
	draw_circle(Vector2.ZERO, r * 0.9, Color(1.0, 0.85, 0.2).darkened(redup))
	draw_arc(Vector2.ZERO, r * 0.78, 0.0, TAU, 48, Color(0.8, 0.6, 0.1).darkened(redup), 5.0)
	var sisi = "HEADS" if c >= 0.0 else "TAILS"
	draw_string(ThemeDB.fallback_font, Vector2(-r, 23.0), sisi, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 64, Color(0.55, 0.38, 0.0).darkened(redup))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ========================================================
# LEMPAR KOIN PENENTU SERI -- VERSI MULTIPLAYER
# Aturan: PEMBELA memilih sisi koin lebih dulu. Penyerang lalu melihat kedua
# tombol, tapi sisi milik pembela sudah abu-abu dan terkunci, jadi penyerang
# tinggal mengambil sisanya. Bagian ini hanya mengurus TAMPILAN; pengiriman
# pilihan dan undian hasil koin diurus pemain.gd (host yang mengundi).
# ========================================================
func _pilih_koin_jaringan(siapa_penyerang: String, naskah: Dictionary = {}) -> Dictionary:
	# "siapa_penyerang" sudah dari kacamata device INI:
	# "musuh" yang menyerang = saya pembela.
	# naskah bisa berisi keputusan yang sudah ditentukan host:
	#   koin_pembela = sisi pilihan pembela AI (tidak ada yang perlu diklik),
	#   koin_hasil   = hasil koin (dipakai saat KEDUA peserta AI).
	var pilihan_lokal = ""
	var pembela_otomatis = str(naskah.get("koin_pembela", ""))
	var hasil_otomatis = str(naskah.get("koin_hasil", ""))
	if siapa_penyerang == "musuh" and not mode_tonton:
		# --- Saya PEMBELA: pilih duluan ---
		teks_judul.text = "YOU DEFEND, SO YOU PICK FIRST!"
		teks_bantuan.text = "The attacker will get the other side."
		_tampilkan_tombol_koin("")
		pilihan_lokal = await self.koin_dipilih
		tombol_kepala.hide()
		tombol_ekor.hide()
		teks_bantuan.text = ""
		teks_judul.text = "YOU PICKED " + _nama_sisi_koin(pilihan_lokal) + "! WAITING FOR " + nama_sisi_m + "..."
		koin_lokal_dikunci.emit(pilihan_lokal)
	else:
		# --- Saya PENYERANG (atau penonton): pembela memilih duluan ---
		teks_judul.text = nama_sisi_m + " DEFENDS, SO " + nama_sisi_m + " PICKS FIRST..."
		teks_bantuan.text = "" if mode_tonton else "You will get the other side."
		var pilihan_lawan = pembela_otomatis
		if pilihan_lawan == "":
			pilihan_lawan = await _tunggu_pilihan_koin_lawan()
		else:
			# Pembelanya AI: pilihannya sudah ada, beri jeda supaya sempat terbaca.
			await get_tree().create_timer(1.5).timeout
		# Sisi penyerang PASTI kebalikan sisi pembela. Dihitung di sini, bukan
		# dibaca dari tombol, supaya semua layar mustahil berbeda pendapat.
		pilihan_lokal = "ekor" if pilihan_lawan == "kepala" else "kepala"
		var siapa_dapat = (nama_sisi_p + " GETS ") if mode_tonton else "YOU GET "
		teks_judul.text = nama_sisi_m + " PICKED " + _nama_sisi_koin(pilihan_lawan) + "! " + siapa_dapat + _nama_sisi_koin(pilihan_lokal) + "!"
		if mode_tonton:
			await get_tree().create_timer(1.2).timeout
		else:
			teks_bantuan.text = "TAP " + _nama_sisi_koin(pilihan_lokal) + " TO FLIP THE COIN!"
			_tampilkan_tombol_koin(pilihan_lawan)
			await self.koin_dipilih # hanya tombol sisa yang bisa diklik
			tombol_kepala.hide()
			tombol_ekor.hide()
			teks_bantuan.text = ""
			koin_lokal_dikunci.emit(pilihan_lokal)

	var hasil = hasil_otomatis
	if hasil == "":
		hasil = await _tunggu_hasil_koin()
	return {"pilihan_lokal": pilihan_lokal, "hasil": hasil}

func _tampilkan_tombol_koin(sisi_terkunci: String) -> void:
	# sisi_terkunci = sisi yang sudah diambil lawan: tampil abu-abu redup dan
	# tidak bisa diklik. Kosong = kedua tombol aktif seperti biasa.
	tombol_kepala.disabled = (sisi_terkunci == "kepala")
	tombol_ekor.disabled = (sisi_terkunci == "ekor")
	tombol_kepala.show()
	tombol_ekor.show()

func terima_pilihan_koin_lawan(pilihan: String) -> void:
	# Dipanggil pemain.gd saat pilihan koin lawan tiba lewat jaringan.
	koin_pilihan_lawan = pilihan
	data_koin_jaringan_tiba.emit()

func terima_hasil_koin(hasil: String) -> void:
	# Dipanggil pemain.gd saat hasil undian koin dari host tersedia.
	koin_hasil_jaringan = hasil
	data_koin_jaringan_tiba.emit()

func _tunggu_pilihan_koin_lawan() -> String:
	# Cek titipan dulu; hanya menunggu sinyal kalau memang belum ada.
	while koin_pilihan_lawan == "":
		await data_koin_jaringan_tiba
	return koin_pilihan_lawan

func _tunggu_hasil_koin() -> String:
	while koin_hasil_jaringan == "":
		await data_koin_jaringan_tiba
	return koin_hasil_jaringan

func _nama_sisi_koin(sisi: String) -> String:
	return "HEADS" if sisi == "kepala" else "TAILS"
