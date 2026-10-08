extends Node3D
class_name PetakKartu

signal interaksi_selesai(efek_terpilih)
signal kartu_dibuang_selesai
signal kartu_digunakan_selesai(data_kartu)
signal pedang_terpilih(data_kartu) # <--- TAMBAHKAN SINYAL INI
# --- Bagian B2: MULTIPLAYER (yang lewat petak memilih, lawannya menonton) ---
# Naik ke pemain.gd: pemain di device INI baru memilih kartu ke-indeks, supaya
# pilihannya diteruskan ke device lawan.
signal kartu_gacha_diklik(indeks)
signal kartu_buang_diklik(indeks)
# Kartu pedang: dipancarkan SAAT penyerang di device ini mengklik (indeks
# pedang, atau -1 = NO, SAVE IT) -- sebelum jeda pengumuman 1.5 dtk -- supaya
# pemain.gd bisa langsung mengabari device lawan dan pengumumannya bersamaan.
signal pedang_diklik(indeks)

var poros_animasi: Node3D
var pivot_kiri: Node3D
var pivot_tengah: Node3D
var pivot_kanan: Node3D

var kanvas_ui: CanvasLayer

# Flag penanda untuk integrasi dengan pemain.gd
var is_petak_kartu: bool = true
var node_sistem_kartu: PetakKartu

# Keadaan UI yang sedang tampil, supaya pilihan dari jaringan bisa "menekan"
# kartu yang sama. Pilihan yang tiba sebelum UI selesai dibangun (misalnya layar
# ini masih memutar animasi kartu) ditampung dulu di *_tertunda.
var _gacha_tombol: Array = []
var _gacha_efek: Array = []
var _gacha_judul: Label
var _gacha_rasio: float = 1.0
var _kartu_sudah_dibuka: bool = false
var _indeks_tertunda: int = -1
var _buang_tombol: Array = []
var _buang_sudah_dipilih: bool = false
var _indeks_buang_tertunda: int = -1

# Sama seperti _gacha_tombol/_buang_tombol di atas, tapi untuk UI tawaran
# kartu pedang (lihat munculkan_ui_pedang_penyerang).
var _pedang_tombol: Array = []
var _pedang_tombol_batal: Button
var _pedang_sudah_dipilih: bool = false
var _ada_pedang_tertunda: bool = false
var _indeks_pedang_tertunda: int = -1

# ========================================================
# SAKLAR PENGUJIAN: kalau true, 3 kartu yang ditawarkan petak kartu SELALU
# ketiga-tiganya kartu pedang (pedang_1, pedang_2, pedang_3) -- supaya alur
# duel kartu pedang gampang diuji tanpa menunggu RNG mengacak kartu pedang
# secara kebetulan. WAJIB false sebelum rilis.
# ========================================================
const UJI_SELALU_PEDANG := false

# Gudang data efek kartu (Diperbarui dengan sistem instan & simpan)
var database_efek = [
	# --- KARTU INSTAN ---
	{"id": "koin_500", "tipe_eksekusi": "instan", "tipe": "koin", "nilai": 500, "teks": "GET\n+500 KOIN"},
	{"id": "koin_1000", "tipe_eksekusi": "instan", "tipe": "koin", "nilai": 1000, "teks": "JACKPOT!\n+1000 KOIN"},
	{"id": "koin_min", "tipe_eksekusi": "instan", "tipe": "koin", "nilai": -300, "teks": "UnLucky!\n-300 KOIN"},
	{"id": "bintang_2", "tipe_eksekusi": "instan", "tipe": "bintang", "nilai": 2, "teks": "BLESSING!\n+2 BINTANG"},
	{"id": "bintang_min", "tipe_eksekusi": "instan", "tipe": "bintang", "nilai": -1, "teks": "CURSE\n-1 BINTANG"},
	# --- KARTU NORMAL (SIMPAN) ---
	{"id": "dadu_rendah", "tipe_eksekusi": "simpan", "teks": "LOW ROLL\n(1-3)\n3 Turns"},
	{"id": "dadu_tinggi", "tipe_eksekusi": "simpan", "teks": "HIGH ROLL\n(10-12)\n3 Turns"},
	{"id": "pelindung", "tipe_eksekusi": "simpan", "teks": "SHIELD\n(Keep)"},
	# --- KARTU PEDANG (PENGGANTI CURI KOIN) ---
	{"id": "pedang_1", "tipe_eksekusi": "simpan", "teks": "SWORD LV 1\n+1 ATK\n(Attacker)"},
	{"id": "pedang_2", "tipe_eksekusi": "simpan", "teks": "SWORD LV 2\n+2 ATK\n(Attacker)"},
	{"id": "pedang_3", "tipe_eksekusi": "simpan", "teks": "SWORD LV 3\n+3 ATK\n(Attacker)"}
]

func _ready():
	node_sistem_kartu = self
	
	# ---> TAMBAHKAN PROTEKSI INI <---
	if not is_petak_kartu:
		return # Hentikan eksekusi pembuatan objek 3D jika hanya meminjam UI
	
	# =======================================================
	# 1. POROS UTAMA STIKER (Merapat mendatar di lantai)
	# =======================================================
	poros_animasi = Node3D.new()
	poros_animasi.position.y = 0.05
	add_child(poros_animasi)
	
	# =======================================================
	# 2. MEMBUAT 3 KARTU DECAL DENGAN UKURAN DIPERBESAR
	# =======================================================
	var mat_kartu = _buat_material_kartu()
	var quad = QuadMesh.new()
	quad.size = Vector2(3.2, 4.48) # Ukuran diperbesar secara signifikan
	
	# --- KARTU BAWAH (KIRI) ---
	pivot_kiri = Node3D.new()
	pivot_kiri.position.z = 1.4
	poros_animasi.add_child(pivot_kiri)
	
	var kartu_kiri = MeshInstance3D.new()
	kartu_kiri.mesh = quad
	kartu_kiri.material_override = mat_kartu
	kartu_kiri.rotation_degrees.x = -90
	kartu_kiri.position = Vector3(0, 0.01, -1.4)
	pivot_kiri.add_child(kartu_kiri)
	
	# --- KARTU TENGAH ---
	pivot_tengah = Node3D.new()
	pivot_tengah.position.z = 1.4
	poros_animasi.add_child(pivot_tengah)
	
	var kartu_tengah = MeshInstance3D.new()
	kartu_tengah.mesh = quad
	kartu_tengah.material_override = mat_kartu
	kartu_tengah.rotation_degrees.x = -90
	kartu_tengah.position = Vector3(0, 0.02, -1.4)
	pivot_tengah.add_child(kartu_tengah)
	
	# --- KARTU ATAS (KANAN) ---
	pivot_kanan = Node3D.new()
	pivot_kanan.position.z = 1.4
	poros_animasi.add_child(pivot_kanan)
	
	var kartu_kanan = MeshInstance3D.new()
	kartu_kanan.mesh = quad
	kartu_kanan.material_override = mat_kartu
	kartu_kanan.rotation_degrees.x = -90
	kartu_kanan.position = Vector3(0, 0.03, -1.4)
	pivot_kanan.add_child(kartu_kanan)

	# =======================================================
	# 3. ANIMASI MENGIPAS (FANNING)
	# =======================================================
	var tw_mekar = create_tween().bind_node(self).set_loops() # <--- PERBAIKAN DI SINI
	tw_mekar.tween_property(pivot_kiri, "rotation_degrees:y", 25.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_mekar.parallel().tween_property(pivot_tengah, "rotation_degrees:y", 0.0, 0.6)
	tw_mekar.parallel().tween_property(pivot_kanan, "rotation_degrees:y", -25.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_mekar.tween_interval(1.5)
	
	tw_mekar.tween_property(pivot_kiri, "rotation_degrees:y", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw_mekar.parallel().tween_property(pivot_kanan, "rotation_degrees:y", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw_mekar.tween_interval(1.0)

	var tw_layang = create_tween().bind_node(self).set_loops() # <--- PERBAIKAN DI SINI
	tw_layang.tween_property(poros_animasi, "position:y", 0.15, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_layang.tween_property(poros_animasi, "position:y", 0.05, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# =======================================================
# 4. FUNGSI SHADER: PUNGGUNG KARTU TERTUTUP (TANDA TANYA)
# =======================================================
func _buat_material_kartu() -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	var kode_shader = """
	shader_type spatial;
	render_mode unshaded, blend_mix, depth_draw_opaque;

	bool is_question_mark(vec2 p) {
		p.y = -p.y;
		p.y -= 0.05; 
		
		bool atas_horizontal = abs(p.y - 0.15) < 0.03 && abs(p.x) < 0.08;
		bool kanan_vertikal = abs(p.x - 0.08) < 0.03 && p.y > 0.02 && p.y < 0.18;
		bool tengah_horizontal = abs(p.y - 0.02) < 0.03 && abs(p.x - 0.04) < 0.07;
		bool leher_vertikal = abs(p.x) < 0.03 && p.y > -0.1 && p.y < 0.05;
		bool titik_bawah = length(p - vec2(0.0, -0.18)) < 0.035;

		return atas_horizontal || kanan_vertikal || tengah_horizontal || leher_vertikal || titik_bawah;
	}

	void fragment() {
		vec2 uv = UV - vec2(0.5);
		vec2 size = vec2(0.35, 0.5); 
		float radius = 0.04;
		vec2 d = abs(uv) - size + vec2(radius);
		float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
		
		if (dist > 0.0) discard;
		
		vec3 color = vec3(1.0);
		
		if (dist < -0.015) { 
			color = vec3(0.05, 0.1, 0.3);
			
			if (is_question_mark(uv)) {
				color = vec3(1.0, 0.8, 0.1);
			} else {
				float pat = sin(uv.x * 120.0) * sin(uv.y * 120.0);
				if (pat > 0.0) color = vec3(0.1, 0.15, 0.4);
			}
		}
		ALBEDO = color;
	}
	"""
	var shader = Shader.new()
	shader.code = kode_shader
	mat.shader = shader
	return mat

# =======================================================
# 5. EFEK ANIMASI 3D DAN SUARA SAAT PETAK DIINJAK/DILEWATI
# =======================================================
func mainkan_efek_kartu():
	# 1. SFX: Suara Sintetis Arpeggio Gacha
	var pemutar_suara = AudioStreamPlayer.new()
	pemutar_suara.bus = "BusSFX"
	
	# PERBAIKAN: Turunkan volume dari 2.0 menjadi -8.0
	pemutar_suara.volume_db = -22.0 
	
	pemutar_suara.stream = _buat_suara_gacha()
	add_child(pemutar_suara)
	pemutar_suara.play()
	
	# 2. VFX: Pop-Up Kartu 3D Meluncur ke Udara
	var efek_kartu_3d = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2.5, 3.5)
	efek_kartu_3d.mesh = quad
	efek_kartu_3d.material_override = _buat_material_kartu()
	
	get_tree().current_scene.add_child(efek_kartu_3d)
	efek_kartu_3d.global_position = self.global_position + Vector3(0, 0.2, 0)
	efek_kartu_3d.scale = Vector3(0.01, 0.01, 0.01)
	
	var tw = create_tween().set_parallel(true)
	var pos_puncak = self.global_position + Vector3(0, 4.0, 0)
	
	tw.tween_property(efek_kartu_3d, "global_position", pos_puncak, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(efek_kartu_3d, "scale", Vector3(1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(efek_kartu_3d, "rotation_degrees:y", 360.0, 0.5)
	
	# Partikel Ledakan Bintang
	var list_partikel = []
	var mesh_p = SphereMesh.new()
	mesh_p.radius = 0.15
	mesh_p.height = 0.3
	var mat_p = StandardMaterial3D.new()
	mat_p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_p.albedo_color = Color(1.0, 0.8, 0.2)
	
	for i in range(8):
		var p = MeshInstance3D.new()
		p.mesh = mesh_p
		p.material_override = mat_p
		get_tree().current_scene.add_child(p)
		list_partikel.append(p)
		p.global_position = self.global_position + Vector3(0, 1.0, 0)
		
		var sudut = randf_range(0, PI * 2.0)
		var target_pos = p.global_position + Vector3(cos(sudut) * 2.0, randf_range(1.0, 3.0), sin(sudut) * 2.0)
		
		var tw_p = create_tween().set_parallel(true)
		tw_p.tween_property(p, "global_position", target_pos, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_p.tween_property(p, "scale", Vector3(0.01, 0.01, 0.01), 0.6)

	await get_tree().create_timer(0.5).timeout
	
	var tw_hilang = create_tween().set_parallel(true)
	tw_hilang.tween_property(efek_kartu_3d, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	tw_hilang.tween_property(efek_kartu_3d, "global_position", self.global_position + Vector3(0, 1.0, 0), 0.3)
	
	await tw_hilang.finished
	
	if is_instance_valid(efek_kartu_3d): efek_kartu_3d.queue_free()
	if is_instance_valid(pemutar_suara): pemutar_suara.queue_free()
	for p in list_partikel:
		if is_instance_valid(p): p.queue_free()

func _buat_suara_gacha() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	var sample_rate = 22050
	stream.mix_rate = sample_rate
	
	var durasi = 0.35 # Sangat singkat, pas untuk efek shuffle/buka kartu
	var panjang_data = int(sample_rate * durasi)
	var data_byte = PackedByteArray()
	data_byte.resize(panjang_data)
	
	var saringan_noise = 0.0
	for i in range(panjang_data):
		var waktu_t = float(i) / float(panjang_data)
		
		# 1. Menghasilkan Noise (Suara desisan kasar)
		var noise = randf_range(-1.0, 1.0)
		
		# 2. Low-Pass Filter Sederhana
		# Menyaring noise agar suaranya "tumpul" dan tebal seperti kertas karton
		saringan_noise = (saringan_noise * 0.6) + (noise * 0.4)
		
		# 3. Mensimulasikan 6 lembar kartu yang digeser beruntun
		var jumlah_lembar = 6.0
		var progres_lembar = fmod(waktu_t * jumlah_lembar, 1.0)
		
		# 4. Envelope Kertas (Attack instan, Decay sangat tajam)
		var envelope = exp(-progres_lembar * 12.0)
		
		# Fade out global agar di akhir animasi suara tidak terpotong tiba-tiba
		var fade_out = 1.0 - (waktu_t * waktu_t)
		
		# Amplitude diatur ke 0.7 karena karakter noise secara alami terdengar lebih pelan dari gelombang sinus
		var nilai_gelombang = saringan_noise * envelope * fade_out * 0.7
		
		var konversi_byte = int((nilai_gelombang + 1.0) * 127.5)
		data_byte[i] = clamp(konversi_byte, 0, 255)
		
	stream.data = data_byte
	return stream

# =======================================================
# BLOK FUNGSI UI & GACHA
# =======================================================
func ambil_tiga_kartu() -> Array:
	# Multiplayer: HOST yang mengacak 3 kartu lalu mengirimkannya ke client,
	# supaya kedua layar menampilkan 3 kartu yang SAMA.
	if UJI_SELALU_PEDANG:
		return _ambil_tiga_kartu_uji_pedang()
	database_efek.shuffle()
	return [database_efek[0], database_efek[1], database_efek[2]]

func _ambil_tiga_kartu_uji_pedang() -> Array:
	# Khusus UJI_SELALU_PEDANG: 3 kartu yang ditawarkan SELALU ketiga-tiganya
	# kartu pedang (pedang_1, pedang_2, pedang_3), urutannya diacak saja.
	var daftar_pedang = []
	for k in database_efek:
		if k["id"].begins_with("pedang"): daftar_pedang.append(k)
	daftar_pedang.shuffle()
	return daftar_pedang

func siapkan_sesi_gacha() -> void:
	# Buang titipan pilihan kartu dari sesi sebelumnya.
	_indeks_tertunda = -1

func siapkan_sesi_buang() -> void:
	# Sengaja TERPISAH dari siapkan_sesi_gacha: kalau layar ini sempat macet saat
	# animasi kartu, pilihan kartu lawan dan perintah "buang kartu" bisa tiba
	# berdekatan sebelum 3 kartunya tampil -- titipan pilihan kartu itu tidak
	# boleh ikut terhapus, atau layar kartu di sini tertahan selamanya.
	_indeks_buang_tertunda = -1

func mulai_gacha_kartu(aktor: String, pilihan_host: Array = [], mode: String = "", nama_aktor: String = ""):
	# mode: "" = solo (perilaku asli, termasuk AI), "lokal" = pemain di device ini
	# yang memilih, "ai" = AI (di host) memilih sendiri lalu pilihannya diteruskan
	# ke device lain, "tonton" = hanya menonton pilihan dari jaringan.
	# nama_aktor kosong = permainan 2 pemain (teks lama "ENEMY ...").
	_bangun_ui_layar_kartu(aktor, pilihan_host, mode, nama_aktor)
	var hasil = await self.interaksi_selesai
	return hasil

func buka_kartu_jaringan(indeks: int) -> void:
	# Dipanggil pemain.gd saat pilihan kartu dari device lawan tiba.
	if indeks < 0 or indeks > 2:
		return
	if _gacha_tombol.is_empty():
		_indeks_tertunda = indeks # UI belum jadi -- dibuka begitu selesai dibangun
		return
	_eksekusi_balik_kartu(_gacha_tombol[indeks], _gacha_efek[indeks], _gacha_tombol, _gacha_judul, _gacha_rasio)

func buang_kartu_jaringan(indeks: int) -> void:
	# Dipanggil pemain.gd saat pilihan kartu yang dibuang dari device lawan tiba.
	if _buang_tombol.is_empty():
		_indeks_buang_tertunda = indeks
		return
	if indeks < 0 or indeks >= _buang_tombol.size():
		return
	_buang_tombol[indeks].emit_signal("pressed")

func pedang_jaringan(indeks: int) -> void:
	# Dipanggil pemain.gd saat pilihan kartu pedang dari device lawan tiba
	# (UI ini dibuka dalam mode "tonton"). indeks == -1 berarti pedang tidak
	# dipakai/disimpan (tombol "NO, SAVE IT" yang ditekan penyerang).
	if _pedang_tombol.is_empty() and not is_instance_valid(_pedang_tombol_batal):
		# UI belum jadi -- ditampung dulu, dibuka begitu tombol-tombolnya siap.
		_ada_pedang_tertunda = true
		_indeks_pedang_tertunda = indeks
		return
	if indeks < 0 or indeks >= _pedang_tombol.size():
		if is_instance_valid(_pedang_tombol_batal):
			_pedang_tombol_batal.emit_signal("pressed")
		return
	_pedang_tombol[indeks].emit_signal("pressed")

func _bangun_ui_layar_kartu(aktor: String, pilihan_host: Array = [], mode: String = "", nama_aktor: String = ""):
	kanvas_ui = CanvasLayer.new()
	kanvas_ui.layer = 10 
	kanvas_ui.process_mode = Node.PROCESS_MODE_ALWAYS 
	add_child(kanvas_ui)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	kanvas_ui.add_child(overlay)
	
	var resolusi_layar = get_viewport().get_visible_rect().size
	var rasio_x = min(1.0, resolusi_layar.x / 650.0) 
	var rasio_y = min(1.0, resolusi_layar.y / 400.0) 
	var rasio_akhir = min(rasio_x, rasio_y) 
	
	var lebar_kartu = int(180 * rasio_akhir)
	var tinggi_kartu = int(250 * rasio_akhir)
	var spasi_kartu = int(30 * rasio_akhir)
	var font_judul = int(45 * rasio_akhir)
	var font_tanya = int(80 * rasio_akhir)
	
	var judul = Label.new()
	var nama_lawan = nama_aktor if nama_aktor != "" else "ENEMY"
	judul.text = ("YOUR TURN" if aktor == "pemain" else nama_lawan + " TURN") + "\nCHOOSE A CARD!"
	if mode == "tonton":
		judul.text = nama_lawan + " TURN\n" + nama_lawan + " IS CHOOSING A CARD..."
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judul.add_theme_font_size_override("font_size", font_judul)
	judul.add_theme_color_override("font_outline_color", Color.BLACK)
	judul.add_theme_constant_override("outline_size", int(10 * rasio_akhir))
	judul.set_anchors_preset(Control.PRESET_CENTER_TOP)
	judul.grow_horizontal = Control.GROW_DIRECTION_BOTH
	judul.position.y = int(50 * rasio_akhir)
	overlay.add_child(judul)
	
	var penengah_layar = CenterContainer.new()
	penengah_layar.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(penengah_layar)
	
	var wadah_kartu = HBoxContainer.new()
	wadah_kartu.alignment = BoxContainer.ALIGNMENT_CENTER
	wadah_kartu.add_theme_constant_override("separation", spasi_kartu)
	penengah_layar.add_child(wadah_kartu)
	
	var gaya_punggung = StyleBoxFlat.new()
	gaya_punggung.bg_color = Color(0.1, 0.1, 0.3)
	gaya_punggung.border_width_bottom = int(8 * rasio_akhir)
	gaya_punggung.border_color = Color(0.4, 0.7, 1.0)
	gaya_punggung.corner_radius_top_left = int(15 * rasio_akhir)
	gaya_punggung.corner_radius_top_right = int(15 * rasio_akhir)
	gaya_punggung.corner_radius_bottom_right = int(15 * rasio_akhir)
	gaya_punggung.corner_radius_bottom_left = int(15 * rasio_akhir)
	
	# Multiplayer: 3 kartunya sudah ditentukan host. Solo: acak sendiri seperti biasa.
	var efek_terpilih = pilihan_host
	if efek_terpilih.is_empty():
		if UJI_SELALU_PEDANG:
			efek_terpilih = _ambil_tiga_kartu_uji_pedang()
		else:
			database_efek.shuffle()
			efek_terpilih = [database_efek[0], database_efek[1], database_efek[2]]
	var daftar_tombol = []
	
	for i in range(3):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(lebar_kartu, tinggi_kartu)
		btn.add_theme_stylebox_override("normal", gaya_punggung)
		btn.add_theme_stylebox_override("hover", gaya_punggung)
		btn.add_theme_stylebox_override("disabled", gaya_punggung)
		
		# Wadah vertikal untuk menyusun teks "Tile Duel" dan "?"
		var vbox_konten = VBoxContainer.new()
		vbox_konten.name = "VBoxKonten"
		vbox_konten.set_anchors_preset(Control.PRESET_FULL_RECT)
		vbox_konten.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox_konten.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox_konten)
		
		# 1. Teks Atas
		var lbl_atas = Label.new()
		lbl_atas.text = "Tile Duel"
		lbl_atas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_atas.add_theme_font_size_override("font_size", int(18 * rasio_akhir))
		lbl_atas.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Warna Emas
		lbl_atas.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl_atas.add_theme_constant_override("outline_size", int(4 * rasio_akhir))
		lbl_atas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox_konten.add_child(lbl_atas)
		
		# 2. Tanda Tanya Tengah
		var lbl_tanya = Label.new()
		lbl_tanya.text = "?"
		lbl_tanya.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_tanya.add_theme_font_size_override("font_size", font_tanya)
		lbl_tanya.add_theme_color_override("font_color", Color.WHITE)
		lbl_tanya.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl_tanya.add_theme_constant_override("outline_size", int(8 * rasio_akhir))
		lbl_tanya.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox_konten.add_child(lbl_tanya)
		
		# 3. Teks Bawah
		var lbl_bawah = Label.new()
		lbl_bawah.text = "Tile Duel"
		lbl_bawah.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_bawah.add_theme_font_size_override("font_size", int(18 * rasio_akhir))
		lbl_bawah.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Warna Emas
		lbl_bawah.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl_bawah.add_theme_constant_override("outline_size", int(4 * rasio_akhir))
		lbl_bawah.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox_konten.add_child(lbl_bawah)
		
		btn.pressed.connect(func():
			if mode == "lokal": kartu_gacha_diklik.emit(i)
			_eksekusi_balik_kartu(btn, efek_terpilih[i], daftar_tombol, judul, rasio_akhir)
		)
		wadah_kartu.add_child(btn)
		daftar_tombol.append(btn)

	_gacha_tombol = daftar_tombol
	_gacha_efek = efek_terpilih
	_gacha_judul = judul
	_gacha_rasio = rasio_akhir
	_kartu_sudah_dibuka = false

	if (aktor == "musuh" and mode == "") or mode == "ai":
		for b in daftar_tombol: b.disabled = true
		await get_tree().create_timer(1.5, true).timeout
		var index_acak = randi() % 3
		# Multiplayer: pilihan AI diteruskan ke device lain persis seperti klik pemain.
		if mode == "ai": kartu_gacha_diklik.emit(index_acak)
		_eksekusi_balik_kartu(daftar_tombol[index_acak], efek_terpilih[index_acak], daftar_tombol, judul, rasio_akhir)
	elif mode == "tonton":
		# Hanya menonton: kartu tidak bisa diklik, menunggu pilihan lawan.
		for b in daftar_tombol: b.disabled = true
		if _indeks_tertunda >= 0:
			var indeks = _indeks_tertunda
			_indeks_tertunda = -1
			buka_kartu_jaringan(indeks)

func _eksekusi_balik_kartu(tombol_ditekan: Button, data_efek: Dictionary, semua_tombol: Array, label_judul: Label, rasio: float):
	if _kartu_sudah_dibuka: return # cegah terbuka dua kali
	_kartu_sudah_dibuka = true
	# Simpan kanvas milik UI INI. Di multiplayer, UI buang kartu bisa sudah muncul
	# sesaat sebelum UI ini tertutup -- kalau memakai kanvas_ui langsung, yang
	# tertutup nanti malah kanvas UI buang kartu.
	var kanvas_ini = kanvas_ui
	for b in semua_tombol: b.disabled = true
	label_judul.text = "CARD REVEALED!"

	var tw = create_tween().bind_node(kanvas_ini)
	tw.tween_property(tombol_ditekan, "scale:x", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		# Hapus VBoxKonten agar teks punggung kartu hilang saat terbuka
		var vbox = tombol_ditekan.get_node_or_null("VBoxKonten")
		if vbox:
			vbox.queue_free()
			
		var gaya_depan = StyleBoxFlat.new()
		
		# ==========================================
		# PERBAIKAN PROTEKSI KUNCI DICTIONARY
		# Gunakan .get() dengan default value 1 agar
		# kartu "simpan" terdeteksi sebagai kartu positif (emas)
		# ==========================================
		var nilai_kartu = data_efek.get("nilai", 1)
		gaya_depan.bg_color = Color(0.9, 0.8, 0.2) if nilai_kartu > 0 else Color(0.8, 0.2, 0.2)
		
		gaya_depan.corner_radius_top_left = int(15 * rasio)
		gaya_depan.corner_radius_top_right = int(15 * rasio)
		gaya_depan.corner_radius_bottom_right = int(15 * rasio)
		gaya_depan.corner_radius_bottom_left = int(15 * rasio)
		tombol_ditekan.add_theme_stylebox_override("disabled", gaya_depan)
		
		tombol_ditekan.add_theme_font_size_override("font_size", int(25 * rasio))
		tombol_ditekan.add_theme_color_override("font_disabled_color", Color.BLACK)
		tombol_ditekan.text = data_efek["teks"]
	)
	tw.tween_property(tombol_ditekan, "scale:x", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	
	await tw.finished
	await get_tree().create_timer(2.5, true).timeout

	kanvas_ini.queue_free()
	_gacha_tombol = []
	emit_signal("interaksi_selesai", data_efek)

# =======================================================
# FUNGSI UI BARU: MEMBUANG KARTU (DISCARD) KARENA PENUH
# =======================================================
func munculkan_ui_buang_kartu(aktor: String, referensi_inventaris: Array, mode: String = "", nama_aktor: String = ""):
	# mode: sama seperti mulai_gacha_kartu ("" solo, "lokal", "ai", "tonton").
	_buang_sudah_dipilih = false
	kanvas_ui = CanvasLayer.new()
	kanvas_ui.layer = 15 # Layer lebih tinggi dari UI Gacha
	kanvas_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(kanvas_ui)
	var kanvas_ini = kanvas_ui # lihat catatan di _eksekusi_balik_kartu

	var overlay = ColorRect.new()
	overlay.color = Color(0.2, 0.0, 0.0, 0.9) # Warna merah gelap menandakan peringatan
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	kanvas_ui.add_child(overlay)
	
	var resolusi = get_viewport().get_visible_rect().size
	var rasio = min(min(1.0, resolusi.x / 650.0), min(1.0, resolusi.y / 400.0))
	
	var judul = Label.new()
	var nama_lawan = nama_aktor if nama_aktor != "" else "ENEMY"
	judul.text = ("INVENTORY FULL!" if aktor == "pemain" else nama_lawan + " INVENTORY FULL!") + "\nCHOOSE 1 CARD TO DISCARD"
	if mode == "tonton":
		judul.text = nama_lawan + " INVENTORY FULL!\n" + nama_lawan + " IS DISCARDING 1 CARD..."
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judul.add_theme_font_size_override("font_size", int(35 * rasio))
	judul.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	judul.set_anchors_preset(Control.PRESET_CENTER_TOP)
	judul.position.y = int(30 * rasio)
	judul.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.add_child(judul)
	
	var wadah = HBoxContainer.new()
	wadah.alignment = BoxContainer.ALIGNMENT_CENTER
	wadah.add_theme_constant_override("separation", int(20 * rasio))
	wadah.set_anchors_preset(Control.PRESET_CENTER)
	wadah.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wadah.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(wadah)
	
	var gaya_btn = StyleBoxFlat.new()
	gaya_btn.bg_color = Color(0.1, 0.1, 0.3)
	gaya_btn.corner_radius_top_left = 10; gaya_btn.corner_radius_bottom_right = 10
	gaya_btn.corner_radius_top_right = 10; gaya_btn.corner_radius_bottom_left = 10
	
	var daftar_tombol = []
	
	# Membangun 4 tombol berdasarkan array inventaris (yang kini berisi 4 item)
	for i in range(referensi_inventaris.size()):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(int(140 * rasio), int(200 * rasio))
		btn.add_theme_stylebox_override("normal", gaya_btn)
		btn.add_theme_stylebox_override("hover", gaya_btn)
		btn.add_theme_stylebox_override("disabled", gaya_btn)
		btn.add_theme_font_size_override("font_size", int(18 * rasio))
		btn.text = referensi_inventaris[i]["teks"]
		
		btn.pressed.connect(func():
			if _buang_sudah_dipilih: return # cegah terbuang dua kali
			_buang_sudah_dipilih = true
			if mode == "lokal": kartu_buang_diklik.emit(i)
			for b in daftar_tombol: b.disabled = true
			judul.text = "CARD DISCARDED!"

			var tw = create_tween()
			tw.tween_property(btn, "scale", Vector2.ZERO, 0.3)
			await tw.finished

			referensi_inventaris.remove_at(i) # Hapus elemen dari array asli pemain/musuh
			await get_tree().create_timer(0.5).timeout
			kanvas_ini.queue_free()
			_buang_tombol = []
			emit_signal("kartu_dibuang_selesai")
		)
		
		# Jika tombol ke-4 (kartu baru), beri warna beda agar mencolok
		if i == 3:
			var gaya_baru = gaya_btn.duplicate()
			gaya_baru.border_width_bottom = 5; gaya_baru.border_color = Color.YELLOW
			btn.add_theme_stylebox_override("normal", gaya_baru)
			
		wadah.add_child(btn)
		daftar_tombol.append(btn)

	_buang_tombol = daftar_tombol

	if (aktor == "musuh" and mode == "") or mode == "ai":
		for b in daftar_tombol: b.disabled = true
		await get_tree().create_timer(2.0, true).timeout # Jeda baca untuk pemain
		var index_buang = randi() % 4 # AI acak membuang
		if mode == "ai": kartu_buang_diklik.emit(index_buang)
		daftar_tombol[index_buang].emit_signal("pressed")
	elif mode == "tonton":
		# Hanya menonton: menunggu pilihan lawan dari jaringan.
		for b in daftar_tombol: b.disabled = true
		if _indeks_buang_tertunda >= 0:
			var indeks = _indeks_buang_tertunda
			_indeks_buang_tertunda = -1
			buang_kartu_jaringan(indeks)

	await self.kartu_dibuang_selesai

# =======================================================
# FUNGSI UI BARU: MEMILIH KARTU UNTUK DIGUNAKAN SEBELUM DADU
# =======================================================
func munculkan_ui_gunakan_kartu(referensi_inventaris: Array):
	kanvas_ui = CanvasLayer.new()
	kanvas_ui.layer = 15
	kanvas_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(kanvas_ui) 
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85) 
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	kanvas_ui.add_child(overlay)
	
	var judul = Label.new()
	judul.text = "YOUR CARDS\nChoose one to use!"
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judul.add_theme_font_size_override("font_size", 35)
	judul.set_anchors_preset(Control.PRESET_CENTER_TOP)
	judul.position.y = 50
	judul.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.add_child(judul)
	
	var wadah = HBoxContainer.new()
	wadah.alignment = BoxContainer.ALIGNMENT_CENTER
	wadah.add_theme_constant_override("separation", 30)
	wadah.set_anchors_preset(Control.PRESET_CENTER)
	wadah.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wadah.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(wadah)
	
	var gaya_btn = StyleBoxFlat.new()
	gaya_btn.bg_color = Color(0.1, 0.4, 0.8)
	gaya_btn.corner_radius_top_left = 10; gaya_btn.corner_radius_bottom_right = 10
	gaya_btn.corner_radius_top_right = 10; gaya_btn.corner_radius_bottom_left = 10
	
	var daftar_tombol = []
	
	for i in range(referensi_inventaris.size()):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(160, 220)
		btn.add_theme_font_size_override("font_size", 20)
		btn.text = referensi_inventaris[i]["teks"]
		var data_kartu = referensi_inventaris[i]
		
		# ========================================================
		# LOGIKA PEMISAHAN VISUAL KARTU PEDANG
		# ========================================================
		if data_kartu["id"].begins_with("pedang"):
			var gaya_pedang = gaya_btn.duplicate()
			gaya_pedang.bg_color = Color(0.2, 0.2, 0.2, 0.8) # Warna redup abu-abu transparan
			gaya_pedang.border_color = Color(0.5, 0.1, 0.1)
			gaya_pedang.border_width_bottom = 5
			
			btn.add_theme_stylebox_override("normal", gaya_pedang)
			btn.add_theme_stylebox_override("hover", gaya_pedang)
			btn.add_theme_stylebox_override("pressed", gaya_pedang)
			btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6)) # Teks meredup
		else:
			btn.add_theme_stylebox_override("normal", gaya_btn)
		
		btn.pressed.connect(func():
			if data_kartu["id"].begins_with("pedang"):
				# Tampilkan peringatan, UI tidak ditutup, dan kartu tidak digunakan
				judul.text = "Swords can only be used when attacking!"
				judul.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3)) # Peringatan merah
			else:
				# Eksekusi kartu normal
				for b in daftar_tombol: b.disabled = true
				kanvas_ui.queue_free()
				emit_signal("kartu_digunakan_selesai", data_kartu)
		)
		wadah.add_child(btn)
		daftar_tombol.append(btn)
		
	var btn_batal = Button.new()
	btn_batal.text = "CANCEL"
	btn_batal.custom_minimum_size = Vector2(200, 60)
	btn_batal.add_theme_font_size_override("font_size", 25)
	btn_batal.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_batal.position.y = -200
	btn_batal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_batal.pressed.connect(func():
		kanvas_ui.queue_free()
		emit_signal("kartu_digunakan_selesai", null)
	)
	overlay.add_child(btn_batal)
	
	var hasil = await self.kartu_digunakan_selesai
	return hasil

# =======================================================
# FUNGSI UI KHUSUS: MENAWARKAN KARTU PEDANG SAAT MENYERANG
# =======================================================
func munculkan_ui_pedang_penyerang(referensi_inventaris: Array, mode: String = "", nama_aktor: String = ""):
	# mode: "" = interaktif (device penyerang atau solo yang memilih sendiri),
	# "tonton" = device lawan (pembela) hanya menonton tawaran yang SAMA --
	# tombol nonaktif, ditutup lewat pedang_jaringan() saat pilihan tiba.
	# Di kedua mode, pilihan diumumkan 1.5 dtk dulu sebelum layar ditutup
	# (lihat _umumkan_pilihan_pedang).
	var daftar_pedang = []
	for k in referensi_inventaris:
		if k["id"].begins_with("pedang"): daftar_pedang.append(k)

	if daftar_pedang.size() == 0:
		return null

	_pedang_sudah_dipilih = false
	_pedang_tombol = []
	_pedang_tombol_batal = null

	kanvas_ui = CanvasLayer.new()
	kanvas_ui.layer = 15
	kanvas_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(kanvas_ui)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	kanvas_ui.add_child(overlay)

	var judul = Label.new()
	var nama_penyerang = nama_aktor if nama_aktor != "" else "Enemy"
	judul.text = "ATTACK PHASE!\nUse a Sword Card to boost your power?"
	if mode == "tonton":
		judul.text = "ATTACK PHASE!\n" + nama_penyerang + " is choosing a Sword Card..."
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judul.add_theme_font_size_override("font_size", 35)
	judul.set_anchors_preset(Control.PRESET_CENTER_TOP)
	judul.position.y = 50
	judul.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.add_child(judul)
	
	var wadah = HBoxContainer.new()
	wadah.alignment = BoxContainer.ALIGNMENT_CENTER
	wadah.add_theme_constant_override("separation", 30)
	wadah.set_anchors_preset(Control.PRESET_CENTER)
	wadah.grow_horizontal = Control.GROW_DIRECTION_BOTH
	wadah.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(wadah)
	
	var gaya_btn = StyleBoxFlat.new()
	gaya_btn.bg_color = Color(0.3, 0.1, 0.1)
	gaya_btn.border_width_bottom = 5
	gaya_btn.border_color = Color(0.8, 0.2, 0.2)
	gaya_btn.corner_radius_top_left = 10; gaya_btn.corner_radius_bottom_right = 10
	gaya_btn.corner_radius_top_right = 10; gaya_btn.corner_radius_bottom_left = 10
	
	var daftar_tombol = []
	
	for i in range(daftar_pedang.size()):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(160, 220)
		btn.add_theme_stylebox_override("normal", gaya_btn)
		
		# Mengurai level pedang dari id (pedang_1, pedang_2, pedang_3)
		var jumlah_pedang = int(daftar_pedang[i]["id"].right(1))
		
		var wadah_visual = HBoxContainer.new()
		wadah_visual.alignment = BoxContainer.ALIGNMENT_CENTER
		wadah_visual.set_anchors_preset(Control.PRESET_FULL_RECT)
		wadah_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(wadah_visual)
		
		# =================================================
		# MENGGAMBAR PEDANG REALISTIS MENGGUNAKAN NODE UI SAJA
		# =================================================
		for p in range(jumlah_pedang):
			var anchor_pedang = Control.new()
			
			# PERBAIKAN 1: Tinggi disesuaikan menjadi 120 karena batas elemen terbawah ada di Y=118
			anchor_pedang.custom_minimum_size = Vector2(40, 120)
			
			# PERBAIKAN 2: Mengunci posisi agar otomatis berada persis di tengah wadah secara Y dan X
			anchor_pedang.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			anchor_pedang.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			
			# PERBAIKAN 3: Baris pivot_offset dan rotation_degrees dihapus untuk mencegah kerusakan layout
			anchor_pedang.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			# 1. Gagang (Grip)
			var gagang = ColorRect.new()
			gagang.color = Color(0.3, 0.15, 0.15) # Cokelat tua
			gagang.size = Vector2(10, 30)
			gagang.position = Vector2(15, 75)
			
			# 2. Pommel (Bulatan gagang bawah) menggunakan Panel + StyleBoxFlat
			var gaya_bulat = StyleBoxFlat.new()
			gaya_bulat.bg_color = Color(0.8, 0.1, 0.3) # Merah Delima (Permata)
			gaya_bulat.corner_radius_top_left = 10
			gaya_bulat.corner_radius_top_right = 10
			gaya_bulat.corner_radius_bottom_right = 10
			gaya_bulat.corner_radius_bottom_left = 10
			
			var pommel = Panel.new()
			pommel.add_theme_stylebox_override("panel", gaya_bulat)
			pommel.size = Vector2(18, 18)
			pommel.position = Vector2(11, 100)
			
			# 3. Bilah Utama (Blade dasar)
			var bilah = ColorRect.new()
			bilah.color = Color(0.65, 0.65, 0.7) # Perak medium
			bilah.size = Vector2(18, 65)
			bilah.position = Vector2(11, 10)
			
			# 4. Sisi terang bilah (Highlight untuk ketajaman)
			var bilah_terang = ColorRect.new()
			bilah_terang.color = Color(0.85, 0.85, 0.9) # Perak terang
			bilah_terang.size = Vector2(9, 65)
			bilah_terang.position = Vector2(11, 10)
			
			# 5. Ujung Pedang (Segitiga dibentuk dari 2 kotak yang diputar silang)
			var ujung_kiri = ColorRect.new()
			ujung_kiri.color = Color(0.85, 0.85, 0.9)
			ujung_kiri.size = Vector2(13, 13)
			ujung_kiri.position = Vector2(11, 3)
			ujung_kiri.rotation_degrees = -45
			
			var ujung_kanan = ColorRect.new()
			ujung_kanan.color = Color(0.65, 0.65, 0.7)
			ujung_kanan.size = Vector2(13, 13)
			ujung_kanan.position = Vector2(29, 3)
			ujung_kanan.rotation_degrees = 135
			
			# 6. Pelindung (Crossguard)
			var pelindung = ColorRect.new()
			pelindung.color = Color(0.4, 0.4, 0.45) # Besi gelap
			pelindung.size = Vector2(40, 10)
			pelindung.position = Vector2(0, 75)
			
			# 7. Sayap Pelindung Atas (Menyudut tajam)
			var sayap_kiri = ColorRect.new()
			sayap_kiri.color = Color(0.4, 0.4, 0.45)
			sayap_kiri.size = Vector2(10, 10)
			sayap_kiri.position = Vector2(-2, 70)
			sayap_kiri.rotation_degrees = -30
			
			var sayap_kanan = ColorRect.new()
			sayap_kanan.color = Color(0.4, 0.4, 0.45)
			sayap_kanan.size = Vector2(10, 10)
			sayap_kanan.position = Vector2(35, 65)
			sayap_kanan.rotation_degrees = 30
			
			# 8. Permata Tengah
			var permata = Panel.new()
			permata.add_theme_stylebox_override("panel", gaya_bulat)
			permata.size = Vector2(10, 10)
			permata.position = Vector2(15, 75)
			
			# Merakit urutan lapisan (z-index UI)
			anchor_pedang.add_child(gagang)
			anchor_pedang.add_child(bilah)
			anchor_pedang.add_child(bilah_terang)
			anchor_pedang.add_child(ujung_kiri)
			anchor_pedang.add_child(ujung_kanan)
			anchor_pedang.add_child(pelindung)
			anchor_pedang.add_child(sayap_kiri)
			anchor_pedang.add_child(sayap_kanan)
			anchor_pedang.add_child(pommel)
			anchor_pedang.add_child(permata)
			
			wadah_visual.add_child(anchor_pedang)
		
		var teks_info = Label.new()
		teks_info.text = "+ " + str(jumlah_pedang) + " ATK"
		teks_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		teks_info.add_theme_font_size_override("font_size", 24)
		teks_info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		teks_info.position.y = -35
		btn.add_child(teks_info)
		
		btn.pressed.connect(func():
			if _pedang_sudah_dipilih: return # cegah terpilih dua kali
			_pedang_sudah_dipilih = true
			if mode != "tonton": pedang_diklik.emit(i)
			_umumkan_pilihan_pedang(i, daftar_pedang[i], judul, mode, nama_penyerang)
		)
		wadah.add_child(btn)
		daftar_tombol.append(btn)

	_pedang_tombol = daftar_tombol

	var btn_batal = Button.new()
	btn_batal.text = "NO, SAVE IT"
	btn_batal.custom_minimum_size = Vector2(250, 60)
	btn_batal.add_theme_font_size_override("font_size", 25)
	btn_batal.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)

	# PERBAIKAN: Posisi dinaikkan drastis untuk menghindari zona banner ads bagian bawah
	btn_batal.position.y = -200

	btn_batal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	btn_batal.pressed.connect(func():
		if _pedang_sudah_dipilih: return # cegah terpilih dua kali
		_pedang_sudah_dipilih = true
		if mode != "tonton": pedang_diklik.emit(-1)
		_umumkan_pilihan_pedang(-1, null, judul, mode, nama_penyerang)
	)
	overlay.add_child(btn_batal)
	_pedang_tombol_batal = btn_batal

	if mode == "tonton":
		# Hanya menonton: tombol tidak bisa diklik, menunggu pilihan lawan
		# dari jaringan (dikirim lewat pedang_jaringan()).
		for b in daftar_tombol: b.disabled = true
		btn_batal.disabled = true
		if _ada_pedang_tertunda:
			# PENTING: titipan ini tidak boleh dieksekusi sebelum baris
			# "await self.pedang_terpilih" di bawah sempat menyimak. Sekarang
			# memang ada jeda pengumuman 1.5 dtk sebelum sinyal itu terpancar,
			# tapi penundaan 1 frame lewat call_deferred tetap dipertahankan
			# sebagai pengaman -- kalau jedanya kelak diubah/dihapus, layar ini
			# tidak akan terkunci selamanya.
			var indeks = _indeks_pedang_tertunda
			_ada_pedang_tertunda = false
			_indeks_pedang_tertunda = -1
			call_deferred("pedang_jaringan", indeks)

	var hasil = await self.pedang_terpilih
	return hasil

func _umumkan_pilihan_pedang(indeks: int, data_terpilih, judul: Label, mode: String, nama_aktor: String = "Enemy") -> void:
	# Pilihan penyerang diumumkan 1.5 dtk di layar ini sebelum ditutup -- di
	# device penyerang maupun pembela (mode "tonton"), supaya keduanya sempat
	# melihat keputusan yang sama: kartu yang dipakai disorot emas & sisanya
	# diredupkan, atau semua kartu diredupkan kalau penyerang memilih menyimpan.
	var kanvas_ini = kanvas_ui
	for b in _pedang_tombol: b.disabled = true
	if is_instance_valid(_pedang_tombol_batal):
		_pedang_tombol_batal.disabled = true

	for i in range(_pedang_tombol.size()):
		if i != indeks:
			_pedang_tombol[i].modulate = Color(1, 1, 1, 0.3)

	judul.modulate = Color(1.0, 0.85, 0.2) # emas = pengumuman
	if data_terpilih != null:
		var poin = int(data_terpilih["id"].right(1))
		if mode == "tonton":
			judul.text = nama_aktor.to_upper() + " USES SWORD CARD!\n+" + str(poin) + " ATK"
		else:
			judul.text = "SWORD CARD USED!\n+" + str(poin) + " ATK"

		var btn = _pedang_tombol[indeks]
		var gaya_sorot = StyleBoxFlat.new()
		gaya_sorot.bg_color = Color(0.5, 0.15, 0.1)
		gaya_sorot.set_border_width_all(6)
		gaya_sorot.border_color = Color(1.0, 0.85, 0.2)
		gaya_sorot.set_corner_radius_all(10)
		btn.add_theme_stylebox_override("normal", gaya_sorot)
		btn.add_theme_stylebox_override("disabled", gaya_sorot)
		if is_instance_valid(_pedang_tombol_batal):
			_pedang_tombol_batal.hide()

		# Sedikit "denyut" pada kartu terpilih (tween ringan, aman untuk Very Low)
		btn.pivot_offset = btn.size / 2.0
		var tw = create_tween().bind_node(kanvas_ini)
		tw.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15)
	else:
		if mode == "tonton":
			judul.text = nama_aktor.to_upper() + " SAVED THE SWORD CARD!\nNo bonus this time"
		else:
			judul.text = "SWORD CARD SAVED!\nNo bonus this time"
		if is_instance_valid(_pedang_tombol_batal):
			# Tombol yang dipilih ikut disorot emas seperti kartu terpilih (tanpa
			# ini, gaya "nonaktif" bawaan membuatnya redup & sulit dibaca).
			var gaya_batal = StyleBoxFlat.new()
			gaya_batal.bg_color = Color(0.25, 0.2, 0.05)
			gaya_batal.set_border_width_all(4)
			gaya_batal.border_color = Color(1.0, 0.85, 0.2)
			gaya_batal.set_corner_radius_all(8)
			_pedang_tombol_batal.add_theme_stylebox_override("disabled", gaya_batal)
			_pedang_tombol_batal.add_theme_color_override("font_disabled_color", Color(1.0, 0.85, 0.2))

	await get_tree().create_timer(1.5, true).timeout
	if is_instance_valid(kanvas_ini):
		kanvas_ini.queue_free()
	_pedang_tombol = []
	_pedang_tombol_batal = null
	emit_signal("pedang_terpilih", data_terpilih)


# =======================================================
# ANIMASI PEMAKAIAN KARTU TERSIMPAN (SEMUA DEVICE)
# Dipakai pemain.gd (_putar_animasi_pakai_kartu) tiap kali kartu simpanan
# (LOW/HIGH ROLL, SHIELD) dipakai -- host, client, maupun AI. Mekanismenya
# mirip kartu pedang:
#   1. semua kartu simpanan karakter itu ditampilkan (kartu pedang diredupkan
#      -- hanya untuk duel)
#   2. kartu terpilih jadi emas, sisanya menghilang (animasi mengecil yang sama
#      dengan buang kartu) dan kartu terpilih bergeser ke tengah; tahan 2 dtk,
#      lalu keterangan target muncul; tahan 1 dtk      -> tampilkan_kartu_pakai()
#   3. latar gelap memudar supaya papan terlihat       -> lepas_latar_kartu_pakai()
#      (pemain.gd mengarahkan kamera ke target di sela-sela ini)
#   4. kartu mengecil masuk ke tubuh target            -> masukkan_kartu_pakai()
# Hanya Control + tween -- aman untuk device Very Low. Tidak menunggu klik.
# =======================================================
var _pakai_overlay: ColorRect
var _pakai_judul: Label
var _pakai_target: Label
var _pakai_kartu: Button

func _teks_kartu_dari_id(id_kartu: String) -> String:
	for k in database_efek:
		if k["id"] == id_kartu:
			return k["teks"]
	return id_kartu

func tampilkan_kartu_pakai(daftar_id: Array, indeks: int, judul_awal: String, judul_pakai: String,
		teks_target: String, warna_judul: Color, warna_target: Color) -> void:
	indeks = clampi(indeks, 0, maxi(0, daftar_id.size() - 1))
	kanvas_ui = CanvasLayer.new()
	kanvas_ui.layer = 15
	kanvas_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(kanvas_ui)
	var kanvas_ini = kanvas_ui

	var resolusi = get_viewport().get_visible_rect().size
	var rasio = min(min(1.0, resolusi.x / 650.0), min(1.0, resolusi.y / 400.0))

	_pakai_overlay = ColorRect.new()
	_pakai_overlay.color = Color(0, 0, 0, 0.0)
	_pakai_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pakai_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kanvas_ui.add_child(_pakai_overlay)

	_pakai_judul = Label.new()
	_pakai_judul.text = judul_awal
	_pakai_judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pakai_judul.add_theme_font_size_override("font_size", int(40 * rasio))
	_pakai_judul.add_theme_color_override("font_color", warna_judul)
	_pakai_judul.add_theme_color_override("font_outline_color", Color.BLACK)
	_pakai_judul.add_theme_constant_override("outline_size", int(8 * rasio))
	_pakai_judul.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pakai_judul.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pakai_judul.position.y = int(50 * rasio)
	_pakai_judul.modulate.a = 0.0
	kanvas_ui.add_child(_pakai_judul)

	# Kartu diletakkan manual (bukan HBoxContainer) supaya kartu terpilih bisa
	# digeser mulus ke tengah setelah kartu lainnya menghilang.
	var lebar = int(140 * rasio)
	var tinggi = int(200 * rasio)
	var spasi = int(20 * rasio)
	var jumlah = daftar_id.size()
	var total_lebar = jumlah * lebar + maxi(0, jumlah - 1) * spasi
	var pusat = resolusi / 2.0
	var x_awal = pusat.x - total_lebar / 2.0
	var y_kartu = pusat.y - tinggi / 2.0

	var gaya_biasa = StyleBoxFlat.new()
	gaya_biasa.bg_color = Color(0.1, 0.4, 0.8)
	gaya_biasa.set_corner_radius_all(10)
	var gaya_pedang = StyleBoxFlat.new()
	gaya_pedang.bg_color = Color(0.2, 0.2, 0.2, 0.8) # redup: kartu pedang hanya untuk duel
	gaya_pedang.border_color = Color(0.5, 0.1, 0.1)
	gaya_pedang.border_width_bottom = 5
	gaya_pedang.set_corner_radius_all(10)

	var semua_kartu = []
	for i in range(jumlah):
		var id_k = str(daftar_id[i])
		var btn = Button.new()
		btn.disabled = true
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.text = _teks_kartu_dari_id(id_k)
		btn.size = Vector2(lebar, tinggi)
		btn.position = Vector2(x_awal + i * (lebar + spasi), y_kartu)
		btn.pivot_offset = Vector2(lebar, tinggi) / 2.0
		btn.add_theme_font_size_override("font_size", int(18 * rasio))
		var gaya = gaya_pedang if id_k.begins_with("pedang") else gaya_biasa
		btn.add_theme_stylebox_override("normal", gaya)
		btn.add_theme_stylebox_override("disabled", gaya)
		btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6) if id_k.begins_with("pedang") else Color.WHITE)
		btn.scale = Vector2.ZERO
		kanvas_ui.add_child(btn)
		semua_kartu.append(btn)
	_pakai_kartu = semua_kartu[indeks] if jumlah > 0 else null

	_pakai_target = Label.new()
	_pakai_target.text = teks_target
	_pakai_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pakai_target.add_theme_font_size_override("font_size", int(28 * rasio))
	_pakai_target.add_theme_color_override("font_color", warna_target)
	_pakai_target.add_theme_color_override("font_outline_color", Color.BLACK)
	_pakai_target.add_theme_constant_override("outline_size", int(6 * rasio))
	_pakai_target.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pakai_target.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pakai_target.position.y = y_kartu + tinggi + int(25 * rasio)
	_pakai_target.modulate.a = 0.0
	kanvas_ui.add_child(_pakai_target)

	# 1. Latar & judul muncul, semua kartu simpanan muncul.
	var tw = create_tween().bind_node(kanvas_ini)
	tw.tween_property(_pakai_overlay, "color:a", 0.8, 0.2)
	tw.parallel().tween_property(_pakai_judul, "modulate:a", 1.0, 0.2)
	for b in semua_kartu:
		tw.parallel().tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	await get_tree().create_timer(0.8, true).timeout # sempat melihat semua kartunya
	if _pakai_kartu == null or not is_instance_valid(kanvas_ini):
		return

	# 2. Kartu terpilih jadi emas; sisanya menghilang (mengecil seperti buang kartu).
	var gaya_emas = StyleBoxFlat.new()
	gaya_emas.bg_color = Color(0.9, 0.8, 0.2)
	gaya_emas.set_border_width_all(4)
	gaya_emas.border_color = Color(1.0, 0.95, 0.6)
	gaya_emas.set_corner_radius_all(10)
	_pakai_kartu.add_theme_stylebox_override("disabled", gaya_emas)
	_pakai_kartu.add_theme_color_override("font_disabled_color", Color.BLACK)
	_pakai_judul.text = judul_pakai
	var tw_pilih = create_tween().bind_node(kanvas_ini)
	tw_pilih.tween_property(_pakai_kartu, "scale", Vector2(1.12, 1.12), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for b in semua_kartu:
		if b != _pakai_kartu:
			tw_pilih.parallel().tween_property(b, "scale", Vector2.ZERO, 0.3)
	tw_pilih.tween_property(_pakai_kartu, "position", Vector2(pusat.x - lebar / 2.0, y_kartu), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_pilih.parallel().tween_property(_pakai_kartu, "scale", Vector2(1.2, 1.2), 0.35)
	await tw_pilih.finished
	for b in semua_kartu:
		if b != _pakai_kartu and is_instance_valid(b):
			b.queue_free()

	# Tahan 2 dtk (hanya kartu terpilih), lalu keterangan target, tahan 1 dtk.
	await get_tree().create_timer(2.0, true).timeout
	if not is_instance_valid(kanvas_ini):
		return
	var tw_target = create_tween().bind_node(kanvas_ini)
	tw_target.tween_property(_pakai_target, "modulate:a", 1.0, 0.25)
	await tw_target.finished
	await get_tree().create_timer(1.0, true).timeout

func lepas_latar_kartu_pakai() -> void:
	# 3. Latar gelap, judul & keterangan memudar supaya papan (dan target yang
	# sedang disorot kamera) terlihat -- kartu emasnya tetap melayang.
	if not is_instance_valid(kanvas_ui):
		return
	var tw = create_tween().bind_node(kanvas_ui)
	tw.tween_property(_pakai_overlay, "color:a", 0.0, 0.4)
	tw.parallel().tween_property(_pakai_judul, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(_pakai_target, "modulate:a", 0.0, 0.4)
	await tw.finished

func masukkan_kartu_pakai(posisi_layar: Vector2) -> void:
	# 4. Kartu mengecil & terbang masuk ke tubuh target (posisi layarnya dihitung
	# pemain.gd dari kamera) -- tanda efeknya sudah dimulai.
	if not is_instance_valid(kanvas_ui) or not is_instance_valid(_pakai_kartu):
		return
	var tujuan = posisi_layar - _pakai_kartu.size / 2.0
	var tw = create_tween().bind_node(kanvas_ui)
	tw.tween_property(_pakai_kartu, "position", tujuan, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_pakai_kartu, "scale", Vector2(0.05, 0.05), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_pakai_kartu, "modulate:a", 0.0, 0.1)
	await tw.finished

func tutup_kartu_pakai() -> void:
	if is_instance_valid(kanvas_ui):
		kanvas_ui.queue_free()
