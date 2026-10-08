extends Node3D
class_name UIPetak

var teks_denda: Label3D
var teks_nyawa: Label3D
var node_lantai: Node3D
var mat_petak: StandardMaterial3D
var tween_sekarat: Tween 

# --- Variabel Tambahan ---
var tingkat_grafis_saat_ini = "sedang"
var pemilik_terakhir: int = -1 
var ukuran_x: float = 2.0
var ukuran_z: float = 2.0
var skala_teks_dasar: float = 0.007
const ANGKA_ROMAWI = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
var is_start: bool = false 
var volume_sfx_db: float = -22.0 

# --- MEMORI GLOBAL UNTUK BATCHING LANTAI (KHUSUS LOW) ---
static var mat_netral: StandardMaterial3D
static var mat_pemain: StandardMaterial3D
static var mat_musuh: StandardMaterial3D
static var mat_siap: bool = false
# Warna pemilik petak per slot: 0 biru, 1 merah, 2 hijau, 3 kuning.
const WARNA_PEMILIK = [Color(0.2, 0.5, 1.0), Color(1.0, 0.2, 0.2), Color(0.15, 0.8, 0.3), Color(1.0, 0.8, 0.1)]
const NAMA_AKTOR_PETAK = ["pemain", "musuh", "pemain3", "pemain4"]
static var mat_slot: Array = []

static func warna_slot(slot: int) -> Color:
	return WARNA_PEMILIK[clampi(slot, 0, WARNA_PEMILIK.size() - 1)]

static func slot_dari_aktor(aktor: String) -> int:
	var i = NAMA_AKTOR_PETAK.find(aktor)
	return i if i >= 0 else 0

static func material_slot(slot: int) -> StandardMaterial3D:
	# Material lantai bersama (khusus setelan Low/Very Low yang tidak memakai
	# material per petak). Slot 0 & 1 memakai material lama supaya tidak ada
	# perubahan apa pun di permainan 2 pemain.
	var s = clampi(slot, 0, WARNA_PEMILIK.size() - 1)
	if s == 0 and mat_pemain != null: return mat_pemain
	if s == 1 and mat_musuh != null: return mat_musuh
	while mat_slot.size() <= s: mat_slot.append(null)
	if mat_slot[s] == null:
		var m = StandardMaterial3D.new()
		m.albedo_color = warna_slot(s)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat_slot[s] = m
	return mat_slot[s]

func _ready():
	rotation_degrees.x = -90 
	position.y = 0.15 
	
	# BACA MEMORI GRAFIS UNTUK PETAK INI
	var config = ConfigFile.new()
	if config.load("user://seting_grafis.cfg") == OK:
		tingkat_grafis_saat_ini = config.get_value("Pengaturan", "kualitas_grafik", "sedang")
	
	if not mat_siap:
		mat_netral = StandardMaterial3D.new()
		mat_netral.albedo_color = Color(0.6, 0.6, 0.6)
		mat_netral.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat_pemain = StandardMaterial3D.new()
		mat_pemain.albedo_color = Color(0.2, 0.5, 1.0)
		mat_pemain.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat_musuh = StandardMaterial3D.new()
		mat_musuh.albedo_color = Color(1.0, 0.2, 0.2)
		mat_musuh.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat_siap = true
		
	teks_denda = Label3D.new()
	teks_nyawa = Label3D.new()
	add_child(teks_denda)
	add_child(teks_nyawa)
	
	_setup_label_dasar(teks_denda)
	_setup_label_dasar(teks_nyawa)
	
	var parent_petak = get_parent()
	if parent_petak and parent_petak.get_child_count() > 0:
		node_lantai = parent_petak.get_child(0)
		if "size" in node_lantai: 
			ukuran_x = node_lantai.size.x
			ukuran_z = node_lantai.size.z
		elif node_lantai is MeshInstance3D and node_lantai.mesh:
			var aabb = node_lantai.mesh.get_aabb()
			ukuran_x = aabb.size.x
			ukuran_z = aabb.size.z

		# Di dalam _ready()
		if not tingkat_grafis_saat_ini in ["rendah", "sangat_rendah"]:
			mat_petak = StandardMaterial3D.new()
			mat_petak.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL 
			_terapkan_material_ke_lantai()
			
	teks_denda.position = Vector3(0, ukuran_z * 0.20, 0) 
	teks_nyawa.position = Vector3(0, -ukuran_z * 0.20, 0)
	var faktor_skala = min(ukuran_x, ukuran_z) / 2.0
	skala_teks_dasar = faktor_skala * 0.007 
	teks_denda.pixel_size = skala_teks_dasar
	teks_nyawa.pixel_size = skala_teks_dasar

func _setup_label_dasar(lbl: Label3D):
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.font_size = 140 
	lbl.outline_size = 35
	lbl.text = ""
	
	# MATIKAN TRANSPARANSI
	if tingkat_grafis_saat_ini in ["rendah", "sangat_rendah"]:
		lbl.alpha_cut = Label3D.ALPHA_CUT_DISCARD

func _terapkan_material_ke_lantai():
	if node_lantai and mat_petak and not tingkat_grafis_saat_ini in ["rendah", "sangat_rendah"]:
		node_lantai.set("material", mat_petak)
		node_lantai.set("material_override", mat_petak)

func perbarui_tampilan(pemilik: int, jumlah_nyawa: int, harga_denda: int, dilindungi_fortress: bool = false):
	if is_start: return 
	
	# Mencegah teks harga/nyawa muncul di petak permata
	if get_parent().is_petak_permata: return 
	
	if not tingkat_grafis_saat_ini in ["rendah", "sangat_rendah"]:
		_terapkan_material_ke_lantai() 
	
	if tween_sekarat and tween_sekarat.is_valid():
		tween_sekarat.kill()
		if tingkat_grafis_saat_ini in ["rendah", "sangat_rendah"]:
			teks_nyawa.modulate = Color.WHITE
		
	if pemilik_terakhir == -1 and pemilik != -1:
		_mainkan_efek_beli(pemilik)
		
	pemilik_terakhir = pemilik
	
	if pemilik == -1:
		teks_denda.text = ""
		teks_nyawa.text = ""
		if tingkat_grafis_saat_ini in ["rendah", "sangat_rendah"]:
			if node_lantai: node_lantai.set("material_override", mat_netral)
		else:
			if mat_petak: mat_petak.albedo_color = Color(0.6, 0.6, 0.6) 
		return

	# B-b bagian 4b: tandai petak yang punya Fortress aktif -- supaya tombol
	# Attack manusia tidak "tertipu" mengira serangannya akan mengurangi HP.
	teks_denda.text = (str(harga_denda) + "\n(Protected)") if dilindungi_fortress else str(harga_denda)
	var batas_nyawa = clampi(jumlah_nyawa, 0, 10)
	teks_nyawa.text = ANGKA_ROMAWI[batas_nyawa]
	var warna_dasar = Color(0.6, 0.6, 0.6)

	if pemilik >= 0:
		warna_dasar = warna_slot(pemilik)
		teks_denda.modulate = Color.WHITE 
		teks_nyawa.modulate = Color.WHITE
		teks_denda.outline_modulate = Color.BLACK
		teks_nyawa.outline_modulate = Color.BLACK
		if tingkat_grafis_saat_ini in ["rendah", "sangat_rendah"] and node_lantai:
			node_lantai.set("material_override", material_slot(pemilik))

	if tingkat_grafis_saat_ini != "rendah" and mat_petak: 
		mat_petak.albedo_color = warna_dasar 

	if jumlah_nyawa == 1:
		tween_sekarat = create_tween().set_loops()
		if tingkat_grafis_saat_ini in ["rendah", "sangat_rendah"]:
			# Pada LOW, kedipkan teks nyawanya saja agar tidak bentrok material global
			tween_sekarat.tween_property(teks_nyawa, "modulate", Color(1.0, 0.2, 0.2), 0.6).set_trans(Tween.TRANS_SINE)
			tween_sekarat.tween_property(teks_nyawa, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
		else:
			# Pada HIGH/MEDIUM, kedipkan lantai seperti biasa
			tween_sekarat.tween_property(mat_petak, "albedo_color", Color(0.6, 0.6, 0.6), 1.2).set_trans(Tween.TRANS_SINE)
			tween_sekarat.tween_property(mat_petak, "albedo_color", warna_dasar, 1.2).set_trans(Tween.TRANS_SINE)

# ========================================================
# ANIMASI SAAT PETAK NETRAL DIBELI
# ========================================================
func _mainkan_efek_beli(aktor: int):

	var suara_beli = AudioStreamPlayer.new()
	suara_beli.bus = "BusSFX" 
	suara_beli.volume_db = volume_sfx_db # <--- TAMBAHKAN BARIS INI
	suara_beli.stream = _buat_suara_sintetis("beli")
	add_child(suara_beli)
	suara_beli.play()
	
	var gelombang = CSGBox3D.new()
	gelombang.size = Vector3(ukuran_x, 0.05, ukuran_z)
	gelombang.position.y = -0.05
	var mat_gelombang = StandardMaterial3D.new()
	mat_gelombang.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Unshaded di sini aman, hanya untuk efek visual
	mat_gelombang.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_gelombang.albedo_color = warna_slot(aktor)
	gelombang.material = mat_gelombang
	
	add_child(gelombang)
	
	var tw_gelombang = gelombang.create_tween().set_parallel(true)
	tw_gelombang.tween_property(gelombang, "size", Vector3(ukuran_x * 1.8, 0.05, ukuran_z * 1.8), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_gelombang.tween_property(mat_gelombang, "albedo_color:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD)
	
	teks_denda.pixel_size = 0.0
	teks_nyawa.pixel_size = 0.0
	var tw_teks = create_tween().set_parallel(true)
	tw_teks.tween_property(teks_denda, "pixel_size", skala_teks_dasar, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw_teks.tween_property(teks_nyawa, "pixel_size", skala_teks_dasar, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	await tw_gelombang.finished
	gelombang.queue_free()
	suara_beli.queue_free()


# ========================================================
# EFEK ANIMASI SERANGAN JARAK JAUH & PARTIKEL
# ========================================================
# --- MEMORI GLOBAL EFEK SERANGAN RINGAN (Very Low) ---
# Satu mesh & satu material dipakai ulang oleh SEMUA bola energi di seluruh sesi.
static var cache_mesh_bola_ringan: SphereMesh
static var cache_mesh_ledak_ringan: SphereMesh
static var cache_mat_energi_ringan: Dictionary = {}

static func _mesh_bola_ringan() -> SphereMesh:
	if cache_mesh_bola_ringan == null:
		cache_mesh_bola_ringan = SphereMesh.new()
		cache_mesh_bola_ringan.radius = 0.5
		cache_mesh_bola_ringan.height = 1.0
		cache_mesh_bola_ringan.radial_segments = 6
		cache_mesh_bola_ringan.rings = 3
	return cache_mesh_bola_ringan

static func _mesh_ledak_ringan() -> SphereMesh:
	# Ledakannya cuma SATU bola dan ukurannya besar di layar, jadi segmennya
	# sedikit lebih halus daripada bola energi yang jumlahnya banyak.
	if cache_mesh_ledak_ringan == null:
		cache_mesh_ledak_ringan = SphereMesh.new()
		cache_mesh_ledak_ringan.radius = 0.5
		cache_mesh_ledak_ringan.height = 1.0
		cache_mesh_ledak_ringan.radial_segments = 12
		cache_mesh_ledak_ringan.rings = 6
	return cache_mesh_ledak_ringan

static func _mat_energi_ringan(warna: Color) -> StandardMaterial3D:
	var kunci = warna.to_html(false)
	if not cache_mat_energi_ringan.has(kunci):
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = warna
		cache_mat_energi_ringan[kunci] = m
	return cache_mat_energi_ringan[kunci]

func _efek_serangan_ringan(pos_awal: Vector3, aktor: String, main_node: Node):
	# Versi hemat khusus Very Low. Alur, durasi, dan suaranya sama persis dengan
	# versi penuh — yang diganti cuma cara menggambar bolanya:
	#   - CSGSphere3D  -> MeshInstance3D + SphereMesh 6x3 yang dipakai bersama.
	#   - tween "radius" -> tween "scale".
	# Mengubah radius CSG memaksa Godot MENYUSUN ULANG mesh-nya tiap frame untuk
	# tiap bola (24 bola sekaligus di versi penuh) — itu sumber lag serangan
	# pertama di HP. Skala hanya mengubah matriks, gratis di GPU.
	main_node.geser_kamera = Vector3.ZERO
	var warna_energi = warna_slot(slot_dari_aktor(aktor))
	var mesh_bola = _mesh_bola_ringan()
	var mat_energi = _mat_energi_ringan(warna_energi)

	var suara_kumpul = AudioStreamPlayer.new()
	suara_kumpul.bus = "BusSFX"
	suara_kumpul.volume_db = volume_sfx_db
	suara_kumpul.stream = _buat_suara_sintetis("kumpul")

	var suara_luncur = AudioStreamPlayer.new()
	suara_luncur.bus = "BusSFX"
	suara_luncur.volume_db = volume_sfx_db
	suara_luncur.stream = _buat_suara_sintetis("luncur")

	var suara_ledak = AudioStreamPlayer.new()
	suara_ledak.bus = "BusSFX"
	suara_ledak.volume_db = volume_sfx_db
	suara_ledak.stream = _buat_suara_sintetis("ledak")

	add_child(suara_kumpul)
	add_child(suara_luncur)
	add_child(suara_ledak)

	var titik_kumpul = pos_awal + Vector3(0, 3.0, 0)
	main_node.target_kamera = main_node._model_aktor(aktor)
	suara_kumpul.play()

	var durasi_kumpul = 1.2
	var partikel_list = []
	var tw_kumpul = create_tween().set_parallel(true)

	var jumlah_partikel = 8 # versi penuh: 24
	for i in range(jumlah_partikel):
		var partikel = MeshInstance3D.new()
		partikel.mesh = mesh_bola
		partikel.material_override = mat_energi
		partikel.scale = Vector3.ONE * randf_range(0.1, 0.24) # setara radius 0.05-0.12
		get_tree().current_scene.add_child(partikel)
		partikel_list.append(partikel)

		var sudut = (PI * 2.0 / jumlah_partikel) * i
		var jarak_sebar = randf_range(1.5, 2.8)
		var tinggi_acak = randf_range(-1.0, 1.2)
		partikel.global_position = titik_kumpul + Vector3(cos(sudut) * jarak_sebar, tinggi_acak, sin(sudut) * jarak_sebar)

		tw_kumpul.tween_property(partikel, "global_position", titik_kumpul, durasi_kumpul).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw_kumpul.tween_property(partikel, "scale", Vector3.ONE * 0.02, durasi_kumpul)

	var proyektil = MeshInstance3D.new()
	proyektil.mesh = mesh_bola
	proyektil.material_override = mat_energi
	proyektil.scale = Vector3.ONE * 0.02
	get_tree().current_scene.add_child(proyektil)
	proyektil.global_position = titik_kumpul

	tw_kumpul.tween_property(proyektil, "scale", Vector3.ONE, durasi_kumpul).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw_kumpul.finished
	for p in partikel_list:
		p.queue_free()

	main_node.target_kamera = proyektil
	suara_luncur.play()

	var jarak = titik_kumpul.distance_to(global_position)
	var waktu_terbang = max(0.4, jarak * 0.035)

	var tw_terbang = proyektil.create_tween().set_parallel(true)
	tw_terbang.tween_property(proyektil, "global_position:x", global_position.x, waktu_terbang)
	tw_terbang.tween_property(proyektil, "global_position:z", global_position.z, waktu_terbang)

	var tw_y = proyektil.create_tween()
	var titik_puncak = max(titik_kumpul.y, global_position.y) + 3.0
	tw_y.tween_property(proyektil, "global_position:y", titik_puncak, waktu_terbang / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_y.tween_property(proyektil, "global_position:y", global_position.y, waktu_terbang / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tw_terbang.finished
	proyektil.queue_free()

	main_node.target_kamera = self
	suara_ledak.play()

	var ledakan = MeshInstance3D.new()
	ledakan.mesh = _mesh_ledak_ringan()
	# Alpha-nya dianimasikan, jadi material ledakan tetap dibuat per serangan.
	var mat_l = StandardMaterial3D.new()
	mat_l.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_l.albedo_color = Color(1.0, 0.4, 0.0)
	mat_l.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ledakan.material_override = mat_l

	get_tree().current_scene.add_child(ledakan)
	ledakan.global_position = global_position

	var tw_ledak = ledakan.create_tween().set_parallel(true)
	tw_ledak.tween_property(ledakan, "scale", Vector3.ONE * 5.6, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) # setara radius 2.8
	tw_ledak.tween_property(mat_l, "albedo_color:a", 0.0, 0.4)

	await tw_ledak.finished
	ledakan.queue_free()

	suara_kumpul.queue_free()
	suara_luncur.queue_free()
	suara_ledak.queue_free()

func mainkan_efek_serangan(pos_awal: Vector3, aktor: String, main_node: Node):
	if tingkat_grafis_saat_ini == "sangat_rendah":
		await _efek_serangan_ringan(pos_awal, aktor, main_node)
		return
	main_node.geser_kamera = Vector3.ZERO
	var warna_energi = warna_slot(slot_dari_aktor(aktor))
	
	var suara_kumpul = AudioStreamPlayer.new()
	suara_kumpul.bus = "BusSFX" 
	suara_kumpul.volume_db = volume_sfx_db # <--- TAMBAHKAN BARIS INI
	suara_kumpul.stream = _buat_suara_sintetis("kumpul")
	
	var suara_luncur = AudioStreamPlayer.new()
	suara_luncur.bus = "BusSFX" 
	suara_luncur.volume_db = volume_sfx_db # <--- TAMBAHKAN BARIS INI
	suara_luncur.stream = _buat_suara_sintetis("luncur")
	
	var suara_ledak = AudioStreamPlayer.new()
	suara_ledak.bus = "BusSFX" 
	suara_ledak.volume_db = volume_sfx_db # <--- TAMBAHKAN BARIS INI
	suara_ledak.stream = _buat_suara_sintetis("ledak")
	
	add_child(suara_kumpul)
	add_child(suara_luncur)
	add_child(suara_ledak)
	
	var titik_kumpul = pos_awal + Vector3(0, 3.0, 0) 
	main_node.target_kamera = main_node._model_aktor(aktor)
		
	suara_kumpul.play()
	
	var durasi_kumpul = 1.2 
	var partikel_list = []
	var tw_kumpul = create_tween().set_parallel(true)
	
	var jumlah_partikel = 24 
	for i in range(jumlah_partikel):
		var partikel = CSGSphere3D.new()
		partikel.radius = randf_range(0.05, 0.12) 
		var mat_partikel = StandardMaterial3D.new()
		mat_partikel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_partikel.albedo_color = warna_energi
		partikel.material = mat_partikel
		get_tree().current_scene.add_child(partikel)
		partikel_list.append(partikel)
		
		var sudut = (PI * 2.0 / jumlah_partikel) * i
		var jarak_sebar = randf_range(1.5, 2.8)
		var tinggi_acak = randf_range(-1.0, 1.2)
		var pos_sebar = titik_kumpul + Vector3(cos(sudut) * jarak_sebar, tinggi_acak, sin(sudut) * jarak_sebar)
		partikel.global_position = pos_sebar
		
		tw_kumpul.tween_property(partikel, "global_position", titik_kumpul, durasi_kumpul).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw_kumpul.tween_property(partikel, "radius", 0.01, durasi_kumpul)
		
	var proyektil = CSGSphere3D.new()
	proyektil.radius = 0.01
	var mat_p = StandardMaterial3D.new()
	mat_p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_p.albedo_color = warna_energi
	proyektil.material = mat_p
	get_tree().current_scene.add_child(proyektil)
	proyektil.global_position = titik_kumpul
	
	tw_kumpul.tween_property(proyektil, "radius", 0.5, durasi_kumpul).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tw_kumpul.finished
	for p in partikel_list:
		p.queue_free()
	
	main_node.target_kamera = proyektil
	suara_luncur.play()
	
	var jarak = titik_kumpul.distance_to(global_position)
	var waktu_terbang = max(0.4, jarak * 0.035)
	
	var tw_terbang = proyektil.create_tween().set_parallel(true)
	tw_terbang.tween_property(proyektil, "global_position:x", global_position.x, waktu_terbang)
	tw_terbang.tween_property(proyektil, "global_position:z", global_position.z, waktu_terbang)
	
	var tw_y = proyektil.create_tween()
	var titik_puncak = max(titik_kumpul.y, global_position.y) + 3.0
	tw_y.tween_property(proyektil, "global_position:y", titik_puncak, waktu_terbang / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_y.tween_property(proyektil, "global_position:y", global_position.y, waktu_terbang / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tw_terbang.finished
	proyektil.queue_free()
	
	main_node.target_kamera = self
	suara_ledak.play()
	
	var ledakan = CSGSphere3D.new()
	var mat_l = StandardMaterial3D.new()
	mat_l.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_l.albedo_color = Color(1.0, 0.4, 0.0) 
	mat_l.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ledakan.material = mat_l
	
	get_tree().current_scene.add_child(ledakan)
	ledakan.global_position = global_position
	
	var tw_ledak = ledakan.create_tween().set_parallel(true)
	tw_ledak.tween_property(ledakan, "radius", 2.8, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_ledak.tween_property(mat_l, "albedo_color:a", 0.0, 0.4)
	
	await tw_ledak.finished
	ledakan.queue_free()
	
	suara_kumpul.queue_free()
	suara_luncur.queue_free()
	suara_ledak.queue_free()

# ========================================================
# GENERATOR AUDIO SINTETIS
# ========================================================
# Suara disintesis sampel-per-sampel — mahal untuk CPU HP. "static" membuat
# hasilnya dibagi ke SEMUA petak dalam satu sesi, jadi dihitung sekali saja.
static var cache_suara: Dictionary = {}

func _buat_suara_sintetis(tipe: String) -> AudioStreamWAV:
	if cache_suara.has(tipe):
		return cache_suara[tipe]

	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	var sample_rate = 22050
	stream.mix_rate = sample_rate
	
	var durasi = 1.0
	if tipe == "luncur" or tipe == "ledak" or tipe == "denda" or tipe == "jual" or tipe == "bangun1":
		durasi = 0.5
	elif tipe == "beli":
		durasi = 0.4
	elif tipe == "rebut" or tipe == "bangun2" or tipe == "gajian": # <--- TAMBAHKAN gajian di sini
		durasi = 0.8
		
	var panjang_data = int(sample_rate * durasi)
	var data_byte = PackedByteArray()
	data_byte.resize(panjang_data)
	
	var fase = 0.0
	for i in range(panjang_data):
		var waktu_t = float(i) / float(panjang_data)
		var nilai_gelombang = 0.0
		
		if tipe == "kumpul":
			var frekuensi = lerp(100.0, 800.0, waktu_t * waktu_t)
			fase += frekuensi * (PI * 2.0) / sample_rate
			nilai_gelombang = sin(fase) * 0.4
			
		elif tipe == "luncur":
			var frekuensi = lerp(1200.0, 100.0, waktu_t * waktu_t * waktu_t)
			fase += frekuensi * (PI * 2.0) / sample_rate
			nilai_gelombang = sin(fase) * (1.0 - waktu_t) 
			
		elif tipe == "ledak":
			nilai_gelombang = randf_range(-1.0, 1.0) * (1.0 - (waktu_t * waktu_t))
			
		elif tipe == "beli":
			var frekuensi = lerp(400.0, 1500.0, waktu_t)
			fase += frekuensi * (PI * 2.0) / sample_rate
			var envelope = 1.0 - waktu_t
			nilai_gelombang = sin(fase) * envelope * 0.5
			
		elif tipe == "denda":
			var frekuensi = lerp(500.0, 100.0, waktu_t * waktu_t)
			fase += frekuensi * (PI * 2.0) / sample_rate
			var envelope = 1.0 - waktu_t
			var distorsi = randf_range(-0.3, 0.3)
			nilai_gelombang = (sin(fase) + distorsi) * envelope * 0.5
			
		elif tipe == "rebut": 
			var langkah = int(waktu_t * 3.0) 
			var frekuensi = 400.0
			if langkah == 1: frekuensi = 500.0
			elif langkah == 2: frekuensi = 600.0
			
			fase += frekuensi * (PI * 2.0) / sample_rate
			var envelope = 1.0 - (waktu_t * 0.5) 
			nilai_gelombang = sin(fase) * envelope * 0.5
			
		elif tipe == "jual":
			var frekuensi = lerp(300.0, 50.0, waktu_t)
			fase += frekuensi * (PI * 2.0) / sample_rate
			var noise = randf_range(-1.0, 1.0)
			var envelope = 1.0 - (waktu_t * waktu_t)
			nilai_gelombang = ((noise * 0.7) + (sin(fase) * 0.3)) * envelope
						
		if tipe == "bangun1":
			var frekuensi = 150.0
			fase += frekuensi * (PI * 2.0) / sample_rate
			var noise = randf_range(-1.0, 1.0)
			var ketukan = abs(sin(waktu_t * PI * 6.0)) 
			var envelope = (1.0 - waktu_t) * ketukan
			nilai_gelombang = ((noise * 0.5) + (sin(fase) * 0.5)) * envelope
			
		elif tipe == "bangun2":
			var frekuensi = lerp(600.0, 1800.0, waktu_t)
			fase += frekuensi * (PI * 2.0) / sample_rate
			var shimmer = sin(waktu_t * PI * 40.0) * 0.3 
			var envelope = 1.0 - (waktu_t * waktu_t)
			nilai_gelombang = (sin(fase) + shimmer) * envelope * 0.6
			
		elif tipe == "gajian":
			# Nada melompat-lompat berirama ceria (Arpeggio)
			var langkah = int(waktu_t * 6.0) 
			var frekuensi = 400.0
			if langkah % 3 == 1: frekuensi = 520.0
			elif langkah % 3 == 2: frekuensi = 650.0
			
			fase += frekuensi * (PI * 2.0) / sample_rate
			var envelope = 1.0 - (waktu_t * 0.3)
			nilai_gelombang = sin(fase) * envelope * 0.5

		var konversi_byte = int((nilai_gelombang + 1.0) * 127.5)
		data_byte[i] = clamp(konversi_byte, 0, 255)
		
	stream.data = data_byte
	cache_suara[tipe] = stream
	return stream

# ========================================================
# ANIMASI SAAT TERKENA DENDA (TEKS MELAYANG & GETARAN)
# ========================================================
func mainkan_efek_denda(jumlah: int):
	var suara_denda = AudioStreamPlayer.new()
	suara_denda.bus = "BusSFX" 
	suara_denda.volume_db = volume_sfx_db # <--- TAMBAHKAN BARIS INI
	suara_denda.stream = _buat_suara_sintetis("denda")
	add_child(suara_denda)
	suara_denda.play()
	
	var teks_melayang = Label3D.new()
	teks_melayang.text = "-" + str(jumlah)
	teks_melayang.font_size = 200
	teks_melayang.outline_size = 40
	teks_melayang.modulate = Color(1.0, 0.2, 0.2)
	teks_melayang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	get_tree().current_scene.add_child(teks_melayang)
	teks_melayang.global_position = global_position + Vector3(0, 1.0, 0)
	
	var tw_teks = teks_melayang.create_tween().set_parallel(true)
	tw_teks.tween_property(teks_melayang, "global_position:y", global_position.y + 3.5, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_teks.tween_property(teks_melayang, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	if node_lantai:
		var pos_asli = node_lantai.position
		var tw_getar = node_lantai.create_tween()
		for i in range(4):
			tw_getar.tween_property(node_lantai, "position", pos_asli + Vector3(0.15, 0, 0), 0.04)
			tw_getar.tween_property(node_lantai, "position", pos_asli + Vector3(-0.15, 0, 0), 0.04)
		tw_getar.tween_property(node_lantai, "position", pos_asli, 0.04)
		
	await tw_teks.finished
	teks_melayang.queue_free()
	suara_denda.queue_free()

# ========================================================
# ANIMASI SAAT PETAK DIREBUT (KEMENANGAN PERTARUNGAN)
# ========================================================
func mainkan_efek_rebut(aktor_pemenang: String):
	var suara_rebut = AudioStreamPlayer.new()
	suara_rebut.bus = "BusSFX" 
	suara_rebut.volume_db = volume_sfx_db # <--- TAMBAHKAN BARIS INI
	suara_rebut.stream = _buat_suara_sintetis("rebut")
	add_child(suara_rebut)
	suara_rebut.play()
	
	var warna_menang = warna_slot(slot_dari_aktor(aktor_pemenang))
	
	var pilar = CSGCylinder3D.new()
	pilar.radius = 0.8
	pilar.height = 12.0
	var mat_pilar = StandardMaterial3D.new()
	mat_pilar.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_pilar.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_pilar.albedo_color = warna_menang
	mat_pilar.albedo_color.a = 0.6
	pilar.material = mat_pilar
	
	get_tree().current_scene.add_child(pilar)
	pilar.global_position = global_position + Vector3(0, 6.0, 0)
	
	var cincin = CSGTorus3D.new()
	cincin.inner_radius = 0.1
	cincin.outer_radius = 0.3
	var mat_cincin = StandardMaterial3D.new()
	mat_cincin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_cincin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cincin.albedo_color = warna_menang
	cincin.material = mat_cincin
	
	get_tree().current_scene.add_child(cincin)
	cincin.global_position = global_position + Vector3(0, 0.2, 0)
	
	var tw_efek = create_tween().set_parallel(true)
	tw_efek.tween_property(mat_pilar, "albedo_color:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tw_efek.tween_property(cincin, "inner_radius", 3.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_efek.tween_property(cincin, "outer_radius", 3.2, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_efek.tween_property(mat_cincin, "albedo_color:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if node_lantai:
		var pos_asli = node_lantai.position
		var tw_lompat = node_lantai.create_tween()
		tw_lompat.tween_property(node_lantai, "position:y", pos_asli.y + 0.6, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_lompat.tween_property(node_lantai, "position:y", pos_asli.y, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
	teks_denda.pixel_size = 0.0
	teks_nyawa.pixel_size = 0.0
	tw_efek.tween_property(teks_denda, "pixel_size", skala_teks_dasar, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw_efek.tween_property(teks_nyawa, "pixel_size", skala_teks_dasar, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	await tw_efek.finished
	pilar.queue_free()
	cincin.queue_free()
	suara_rebut.queue_free()

# ========================================================
# ANIMASI SAAT PETAK DIJUAL KARENA BANGKRUT
# ========================================================
func mainkan_efek_jual(harga_jual: int):
	var suara_jual = AudioStreamPlayer.new()
	suara_jual.bus = "BusSFX" 
	suara_jual.volume_db = volume_sfx_db # <--- TAMBAHKAN BARIS INI
	suara_jual.stream = _buat_suara_sintetis("jual")
	add_child(suara_jual)
	suara_jual.play()
	
	var tw_utama = create_tween().set_parallel(true)
	var list_asap = []
	
	for i in range(5):
		var asap = CSGSphere3D.new()
		asap.radius = randf_range(0.3, 0.6)
		var mat_asap = StandardMaterial3D.new()
		mat_asap.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_asap.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_asap.albedo_color = Color(0.7, 0.7, 0.7, 1.0)
		asap.material = mat_asap
		
		get_tree().current_scene.add_child(asap)
		list_asap.append(asap)
		
		asap.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.2, randf_range(-0.5, 0.5))
		
		tw_utama.tween_property(asap, "global_position:y", global_position.y + randf_range(2.0, 3.5), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_utama.tween_property(asap, "global_position:x", asap.global_position.x + randf_range(-1.0, 1.0), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_utama.tween_property(asap, "global_position:z", asap.global_position.z + randf_range(-1.0, 1.0), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_utama.tween_property(asap, "radius", asap.radius * 1.5, 1.0)
		tw_utama.tween_property(mat_asap, "albedo_color:a", 0.0, 1.0)
	
	if node_lantai:
		var pos_asli = node_lantai.position
		var tw_amblas = node_lantai.create_tween()
		tw_amblas.tween_property(node_lantai, "position:y", pos_asli.y - 0.4, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_amblas.tween_property(node_lantai, "position:y", pos_asli.y, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
	var teks_uang_cair = Label3D.new()
	teks_uang_cair.text = "+" + str(harga_jual)
	teks_uang_cair.font_size = 250
	teks_uang_cair.outline_size = 50
	teks_uang_cair.modulate = Color(1.0, 0.84, 0.0) 
	teks_uang_cair.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	get_tree().current_scene.add_child(teks_uang_cair)
	teks_uang_cair.global_position = global_position + Vector3(0, 1.0, 0)
	
	tw_utama.tween_property(teks_uang_cair, "global_position:y", global_position.y + 4.5, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_utama.tween_property(teks_uang_cair, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await tw_utama.finished
	
	for asap in list_asap:
		asap.queue_free()
	teks_uang_cair.queue_free()
	suara_jual.queue_free()

# ========================================================
# ANIMASI SAAT MEMBANGUN/UPGRADE MENARA
# ========================================================
func mainkan_efek_bangun(level: int):
	var tw_bangun = create_tween().set_parallel(true)
	
	if level == 1:
		var suara_bangun1 = AudioStreamPlayer.new()
		suara_bangun1.bus = "BusSFX" 
		suara_bangun1.volume_db = volume_sfx_db # <--- TAMBAHKAN BARIS INI
		suara_bangun1.stream = _buat_suara_sintetis("bangun1")
		add_child(suara_bangun1)
		suara_bangun1.play()
		
		if node_lantai:
			var pos_asli = node_lantai.position
			var tw_tekan = node_lantai.create_tween()
			tw_tekan.tween_property(node_lantai, "position:y", pos_asli.y - 0.2, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_tekan.tween_property(node_lantai, "position:y", pos_asli.y, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			
		var list_debu = []
		var jumlah_debu = 24 
		
		for i in range(jumlah_debu):
			var debu = CSGSphere3D.new()
			debu.radius = randf_range(0.15, 0.35) 
			var mat_debu = StandardMaterial3D.new()
			mat_debu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat_debu.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			
			var kecerahan = randf_range(0.65, 0.9)
			mat_debu.albedo_color = Color(kecerahan, kecerahan * 0.95, kecerahan * 0.85) 
			debu.material = mat_debu
			
			get_tree().current_scene.add_child(debu)
			list_debu.append(debu)
			
			var sudut = (PI * 2.0 / jumlah_debu) * i + randf_range(-0.2, 0.2)
			var jarak_awal = randf_range(0.4, 1.2)
			var pos_awal_debu = global_position + Vector3(cos(sudut) * jarak_awal, 0.0, sin(sudut) * jarak_awal)
			debu.global_position = pos_awal_debu
			
			var tinggi_puncak = global_position.y + randf_range(1.0, 2.5)
			var jarak_lempar = randf_range(1.5, 2.8)
			
			tw_bangun.tween_property(debu, "global_position:y", tinggi_puncak, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_bangun.tween_property(debu, "global_position:x", pos_awal_debu.x + (cos(sudut) * jarak_lempar), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw_bangun.tween_property(debu, "global_position:z", pos_awal_debu.z + (sin(sudut) * jarak_lempar), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
			tw_bangun.tween_property(mat_debu, "albedo_color:a", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			
		await tw_bangun.finished
		for d in list_debu: d.queue_free()
		suara_bangun1.queue_free()
		
	elif level == 2:
		var suara_bangun2 = AudioStreamPlayer.new()
		suara_bangun2.bus = "BusSFX" 
		suara_bangun2.volume_db = volume_sfx_db # <--- TAMBAHKAN BARIS INI
		suara_bangun2.stream = _buat_suara_sintetis("bangun2")
		add_child(suara_bangun2)
		suara_bangun2.play()
		
		var pilar = CSGCylinder3D.new()
		pilar.radius = 0.5
		pilar.height = 8.0
		var mat_pilar = StandardMaterial3D.new()
		mat_pilar.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_pilar.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_pilar.albedo_color = Color(1.0, 0.9, 0.2, 0.8) 
		pilar.material = mat_pilar
		get_tree().current_scene.add_child(pilar)
		pilar.global_position = global_position + Vector3(0, 4.0, 0)
		
		var cincin = CSGTorus3D.new()
		cincin.inner_radius = 1.2
		cincin.outer_radius = 1.4
		var mat_cincin = StandardMaterial3D.new()
		mat_cincin.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_cincin.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat_cincin.albedo_color = Color(1.0, 0.8, 0.0)
		cincin.material = mat_cincin
		get_tree().current_scene.add_child(cincin)
		cincin.global_position = global_position
		
		tw_bangun.tween_property(mat_pilar, "albedo_color:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_bangun.tween_property(cincin, "global_position:y", global_position.y + 3.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_bangun.tween_property(cincin, "inner_radius", 2.0, 0.8)
		tw_bangun.tween_property(cincin, "outer_radius", 2.2, 0.8)
		tw_bangun.tween_property(mat_cincin, "albedo_color:a", 0.0, 0.8)
		
		var rotasi_awal = teks_denda.rotation_degrees.y
		tw_bangun.tween_property(teks_denda, "rotation_degrees:y", rotasi_awal + 360.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw_bangun.tween_property(teks_nyawa, "rotation_degrees:y", rotasi_awal + 360.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		
		await tw_bangun.finished
		
		teks_denda.rotation_degrees.y = rotasi_awal
		teks_nyawa.rotation_degrees.y = rotasi_awal
		
		pilar.queue_free()
		cincin.queue_free()
		suara_bangun2.queue_free()

# ========================================================
# PENGATURAN VISUAL PETAK START (STAR COIN 3D)
# ========================================================
func jadikan_petak_start():
	is_start = true
	teks_denda.hide()
	teks_nyawa.hide()
	
	var grup_koin = Node3D.new()
	grup_koin.name = "SimbolStart"
	grup_koin.position.y = 0.05 
	
	var skala = min(ukuran_x, ukuran_z) / 2.0 
	
	# 1. MEMBUAT ALAS KOIN
	var alas_koin = MeshInstance3D.new()
	var mesh_alas = CylinderMesh.new()
	mesh_alas.top_radius = 0.85 * skala
	mesh_alas.bottom_radius = 0.85 * skala
	mesh_alas.height = 0.02
	mesh_alas.radial_segments = 32
	alas_koin.mesh = mesh_alas
	
	var mat_alas = StandardMaterial3D.new()
	mat_alas.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_alas.albedo_color = Color(0.7, 0.5, 0.05) 
	alas_koin.material_override = mat_alas
	grup_koin.add_child(alas_koin)
	
	# 2. MEMBUAT BINTANG 8 SUDUT (UKURAN DIPERKECIL)
	var bintang = CSGPolygon3D.new()
	var titik_bintang = PackedVector2Array()
	
	for i in range(16):
		var sudut = i * (TAU / 16.0)
		var jarak = 0.12 * skala # Titik Lembah (Paling kecil)
		
		if i % 2 == 0:
			if i % 4 == 0:
				jarak = 0.45 * skala # Pucuk Utama (Dikecilkan)
			else:
				jarak = 0.30 * skala # Pucuk Sekunder (Dikecilkan)
				
		titik_bintang.append(Vector2(cos(sudut) * jarak, sin(sudut) * jarak))
		
	bintang.polygon = titik_bintang
	bintang.mode = CSGPolygon3D.MODE_DEPTH
	bintang.depth = 0.03
	bintang.rotation_degrees.x = 90 
	bintang.position.y = 0.015 
	
	var mat_bintang = StandardMaterial3D.new()
	mat_bintang.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_bintang.albedo_color = Color(1.0, 0.9, 0.1) 
	bintang.material_override = mat_bintang
	grup_koin.add_child(bintang)
	
	# 3. MEMBUAT TEKS MELENGKUNG RAPI DENGAN SISTEM PIVOT
	var radius_teks = 0.65 * skala
	var ukuran_pixel_font = 0.005 * skala
	var spasi_derajat = 22.0 # Jarak antar huruf, sangat presisi
	
	# --- Teks Atas: TILE ---
	var kata_atas = "TILE"
	var total_sudut_atas = (kata_atas.length() - 1) * spasi_derajat
	
	for i in range(kata_atas.length()):
		var pivot = Node3D.new()
		pivot.position.y = 0.04
		grup_koin.add_child(pivot)
		
		var lbl = Label3D.new()
		lbl.text = kata_atas[i]
		lbl.font_size = 40 # Huruf diperkecil lagi
		lbl.pixel_size = ukuran_pixel_font
		lbl.outline_size = 12
		lbl.modulate = Color.WHITE
		lbl.outline_modulate = Color.BLACK
		lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		
		lbl.rotation_degrees = Vector3(-90, 0, 0) # Ditidurkan rata
		lbl.position.z = -radius_teks # Posisikan di utara (atas)
		
		pivot.add_child(lbl)
		# TILE: Kiri ke Kanan
		pivot.rotation_degrees.y = (total_sudut_atas / 2.0) - (i * spasi_derajat)
		
	# --- Teks Bawah: DUEL ---
	var kata_bawah = "DUEL"
	var total_sudut_bawah = (kata_bawah.length() - 1) * spasi_derajat
	
	for i in range(kata_bawah.length()):
		var pivot = Node3D.new()
		pivot.position.y = 0.04
		grup_koin.add_child(pivot)
		
		var lbl = Label3D.new()
		lbl.text = kata_bawah[i]
		lbl.font_size = 40 # Huruf diperkecil lagi
		lbl.pixel_size = ukuran_pixel_font
		lbl.outline_size = 12
		lbl.modulate = Color.WHITE
		lbl.outline_modulate = Color.BLACK
		lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		
		lbl.rotation_degrees = Vector3(-90, 0, 0) # Ditidurkan rata
		lbl.position.z = radius_teks # Posisikan di selatan (bawah)
		
		pivot.add_child(lbl)
		# DUEL: Kiri ke Kanan
		pivot.rotation_degrees.y = -(total_sudut_bawah / 2.0) + (i * spasi_derajat)
		
	if get_parent():
		get_parent().call_deferred("add_child", grup_koin)
	else:
		call_deferred("add_child", grup_koin)
	
	# 4. EFEK ANIMASI
	var tw_warna = create_tween().set_loops()
	tw_warna.tween_property(mat_bintang, "albedo_color", Color(1.0, 1.0, 0.7), 1.0).set_trans(Tween.TRANS_SINE)
	tw_warna.tween_property(mat_bintang, "albedo_color", Color(1.0, 0.9, 0.1), 1.0).set_trans(Tween.TRANS_SINE)

	var tw_putar = create_tween().set_loops()
	tw_putar.tween_property(grup_koin, "rotation_degrees:y", 360.0, 6.0).as_relative()

	# Suara gajian disintesis sekarang (saat peta dimuat), bukan saat gaji
	# pertama kali diterima. Hasilnya statis (cache_suara), jadi cukup sekali.
	_buat_suara_sintetis("gajian")

# ========================================================
# ANIMASI SAAT KARAKTER MELEWATI/BERHENTI DI START
# ========================================================
func mainkan_efek_lewat_start(jumlah_gaji: int):
	var suara_gajian = AudioStreamPlayer.new()
	suara_gajian.bus = "BusSFX" 
	suara_gajian.volume_db = volume_sfx_db # <--- TAMBAHKAN BARIS INI
	suara_gajian.stream = _buat_suara_sintetis("gajian")
	add_child(suara_gajian)
	suara_gajian.play()
	
	# Efek Pilar Cahaya Emas dari lantai
	var pilar = CSGCylinder3D.new()
	pilar.radius = 0.9
	pilar.height = 10.0
	var mat_pilar = StandardMaterial3D.new()
	mat_pilar.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_pilar.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_pilar.albedo_color = Color(1.0, 0.9, 0.2, 0.8)
	pilar.material = mat_pilar
	
	get_tree().current_scene.add_child(pilar)
	pilar.global_position = global_position + Vector3(0, 5.0, 0)
	
	# Efek Teks Gaji Melayang (+500 KOIN)
	var teks_gaji = Label3D.new()
	teks_gaji.text = "+" + str(jumlah_gaji) + " KOIN"
	teks_gaji.font_size = 250
	teks_gaji.outline_size = 50
	teks_gaji.modulate = Color(1.0, 0.84, 0.0) 
	teks_gaji.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	get_tree().current_scene.add_child(teks_gaji)
	teks_gaji.global_position = global_position + Vector3(0, 1.5, 0)
	
	var tw_efek = create_tween().set_parallel(true)
	tw_efek.tween_property(teks_gaji, "global_position:y", global_position.y + 4.5, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_efek.tween_property(teks_gaji, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	tw_efek.tween_property(mat_pilar, "albedo_color:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tw_efek.finished
	pilar.queue_free()
	teks_gaji.queue_free()
	suara_gajian.queue_free()

# ========================================================
# PENGATURAN VISUAL PETAK CABANG (PANAH ARAH 3D)
# ========================================================
func jadikan_petak_cabang(daftar_arah: Array):
	var grup_panah = Node3D.new()
	grup_panah.name = "IndikatorCabang"
	grup_panah.position.y = 0.03 
	
	var skala = min(ukuran_x, ukuran_z) / 2.0 
	
	# Material Panah Biru
	var mat_panah = StandardMaterial3D.new()
	mat_panah.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_panah.albedo_color = Color(0.2, 0.65, 1.0) 
	
	# Material Garis Luar (Outline Hitam)
	var mat_outline = StandardMaterial3D.new()
	mat_outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_outline.albedo_color = Color.BLACK
	
	for arah_string in daftar_arah:
		var arah_teks = str(arah_string).to_lower()
		var rotasi_y = 0.0
		
		# Koreksi rotasi absolut 180 derajat
		if "⬆️" in arah_teks or "atas" in arah_teks:
			rotasi_y = 180.0
		elif "⬇️" in arah_teks or "bawah" in arah_teks:
			rotasi_y = 0.0
		elif "➡️" in arah_teks or "kanan" in arah_teks:
			rotasi_y = 90.0
		elif "⬅️" in arah_teks or "kiri" in arah_teks:
			rotasi_y = -90.0
		else:
			continue 
			
		# Poros utama untuk menentukan arah hadap panah
		var pivot = Node3D.new()
		pivot.rotation_degrees.y = rotasi_y
		grup_panah.add_child(pivot)
		
		# Wadah animasi untuk menggeser objek secara lokal
		var wadah_animasi = Node3D.new()
		pivot.add_child(wadah_animasi)
		
		# --- 1. MATA PANAH UTAMA (BIRU) ---
		var panah_utama = CSGPolygon3D.new()
		var titik_panah = PackedVector2Array([
			Vector2(-0.15, 0.3),  
			Vector2(-0.15, 0.6),  
			Vector2(-0.35, 0.6),  
			Vector2(0.0, 0.95),   
			Vector2(0.35, 0.6),   
			Vector2(0.15, 0.6),   
			Vector2(0.15, 0.3)    
		])
		
		for v in range(titik_panah.size()):
			titik_panah[v] *= skala
			
		panah_utama.polygon = titik_panah
		panah_utama.mode = CSGPolygon3D.MODE_DEPTH
		panah_utama.depth = 0.015
		panah_utama.rotation_degrees.x = 90
		panah_utama.position.y = 0.005 # Diberi jarak agar berada di atas outline
		panah_utama.material_override = mat_panah
		wadah_animasi.add_child(panah_utama)
		
		# --- 2. OUTLINE PANAH (HITAM) ---
		var panah_outline = CSGPolygon3D.new()
		# Titik ditarik lebih lebar dari panah utama
		var titik_outline = PackedVector2Array([
			Vector2(-0.20, 0.25),  
			Vector2(-0.20, 0.55),  
			Vector2(-0.43, 0.55),  
			Vector2(0.0, 1.05),   
			Vector2(0.43, 0.55),   
			Vector2(0.20, 0.55),   
			Vector2(0.20, 0.25)    
		])
		
		for v in range(titik_outline.size()):
			titik_outline[v] *= skala
			
		panah_outline.polygon = titik_outline
		panah_outline.mode = CSGPolygon3D.MODE_DEPTH
		panah_outline.depth = 0.015
		panah_outline.rotation_degrees.x = 90
		panah_outline.position.y = 0.0 # Posisi dasar (menempel tanah)
		panah_outline.material_override = mat_outline
		wadah_animasi.add_child(panah_outline)
		
		# --- 3. ANIMASI MAJU MUNDUR BOLAK-BALIK ---
		var jarak_gerak = 0.15 * skala
		# bind_node mencegah eror memory leak
		var tw_maju_mundur = create_tween().bind_node(wadah_animasi).set_loops()
		# Maju ke ujung (-Z)
		tw_maju_mundur.tween_property(wadah_animasi, "position:z", -jarak_gerak, 0.5).as_relative().set_trans(Tween.TRANS_SINE)
		# Mundur kembali ke pusat (+Z)
		tw_maju_mundur.tween_property(wadah_animasi, "position:z", jarak_gerak, 0.5).as_relative().set_trans(Tween.TRANS_SINE)
		
	if get_parent():
		get_parent().call_deferred("add_child", grup_panah)
	else:
		call_deferred("add_child", grup_panah)
