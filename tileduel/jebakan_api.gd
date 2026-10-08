extends Node3D

var pemilik: int = -1
var aktif = true
var mode_residu = false
# B-b (B4, Ultimate Phoenix): jumlah korban TAMBAHAN yang masih membuat jebakan
# ini aktif lagi (bukan dihapus) sesudah kena -- diisi _pasang_jebakan (1 kalau
# pemasang punya Ultimate api, dikurangi tiap kena; lihat pemain.gd trigger api).
var sisa_aktif_ulang: int = 0

# C4 (B-c, 26-09): SATU sumber info runtime dibawa siaran state penuh
# (_kumpulkan_data_jebakan/_terapkan_data_jebakan, pemain_papan.gd) DAN
# rpc_jebakan_dipasang saat pemasangan pertama.
func ambil_info() -> Dictionary:
	return {"aktif_ulang": sisa_aktif_ulang}

func terapkan_info(d: Dictionary) -> void:
	sisa_aktif_ulang = int(d.get("aktif_ulang", sisa_aktif_ulang))

# =======================================================
# 1. VARIABEL NODE & MATERIAL (PRE-LOAD ANTILAG)
# =======================================================
var mat_asap_cache: StandardMaterial3D

var node_nuklir: Node3D
var gelombang: MeshInstance3D
var dasar: MeshInstance3D
var batang: MeshInstance3D
var kepala: MeshInstance3D
var kilat: OmniLight3D

var mat_ledakan: StandardMaterial3D 
var mat_gelombang: StandardMaterial3D
var stream_nuklir: AudioStreamWAV

var grafis_ringan: bool = false
var bola_ringan: MeshInstance3D = null
var mat_bola_ringan: StandardMaterial3D = null

func _ready():
	# Mode ringan khusus setelan grafis "Very Low". Versi lama TIDAK diubah —
	# perangkat kelas menengah ke atas tetap mendapat efek penuh seperti biasa.
	var config = ConfigFile.new()
	if config.load("user://seting_grafis.cfg") == OK:
		grafis_ringan = (config.get_value("Pengaturan", "kualitas_grafik", "sedang") == "sangat_rendah")

	mat_asap_cache = StandardMaterial3D.new()
	mat_asap_cache.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_asap_cache.albedo_color = Color(0.15, 0.15, 0.15, 0.6)


	if mode_residu:
		return 
		
	# =======================================================
	# A. VISUAL KOTAK BERPUTAR (SAAT DITANAM DI LANTAI)
	# =======================================================
	var mesh_inst = MeshInstance3D.new()
	var kotak = BoxMesh.new()
	kotak.size = Vector3(0.8, 0.8, 0.8)
	mesh_inst.mesh = kotak
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.0, 0.8) 
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.0)
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	mesh_inst.position.y = 0.5
	add_child(mesh_inst)
	
	var tw_putar = create_tween().set_loops()
	tw_putar.tween_property(mesh_inst, "rotation_degrees", Vector3(0, 360, 0), 2.0)
	
	# AUDIO DERAK API
	var pemutar = AudioStreamPlayer3D.new()
	pemutar.name = "SuaraApi"
	# 11.025 sampel dihitung sampel-per-sampel — inilah yang memakan ~33 ms SETIAP
	# jebakan dipasang. Disimpan statis supaya cuma dihitung sekali per sesi.
	var stream_api: AudioStreamWAV
	if cache_stream_derak != null:
		stream_api = cache_stream_derak
	else:
		stream_api = AudioStreamWAV.new()
		stream_api.format = AudioStreamWAV.FORMAT_8_BITS
		stream_api.mix_rate = 11025
		var durasi = 1.0
		var jumlah_sampel = int(stream_api.mix_rate * durasi)
		var data_suara = PackedByteArray()
		data_suara.resize(jumlah_sampel)
		for i in range(jumlah_sampel):
			var noise = (randi() % 100 - 50) 
			if randi() % 10 == 0: noise = randi() % 256 - 128
			var envelope = 1.0 - (float(i) / float(jumlah_sampel)) 
			data_suara[i] = int(noise * envelope) + 128
		stream_api.data = data_suara
		cache_stream_derak = stream_api
	pemutar.stream = stream_api
	pemutar.unit_size = 15.0
	pemutar.max_distance = 40.0
	add_child(pemutar)

	var pemanas_asap = CPUParticles3D.new()
	pemanas_asap.material_override = mat_asap_cache
	pemanas_asap.emitting = true
	pemanas_asap.one_shot = true
	pemanas_asap.position = Vector3(0, -100, 0) 
	add_child(pemanas_asap)

	# =======================================================
	# B. PRA-RAKITAN LEDAKAN NUKLIR (UKURAN MEDIUM)
	# =======================================================
	if grafis_ringan:
		# Inilah bagian terberatnya, dan ia berjalan SAAT JEBAKAN DIBUAT — bukan
		# saat meledak. Sintesis suara 22.050 sampel + 5 mesh + cahaya dinamis
		# terlalu mahal untuk HP kelas bawah. Di mode ringan semuanya dilewati.
		# Sebagai gantinya bola ledakan sederhana disiapkan DI SINI, bukan nanti
		# saat meledak: Godot baru menyusun shader saat material pertama tampil di
		# layar, dan penyusunan itulah yang bikin tersendat sekali di awal. Dengan
		# menampilkannya sekarang dalam ukuran nyaris tak terlihat, shader-nya sudah
		# siap sebelum dibutuhkan — jadi ledakan pertama pun langsung mulus.
		_siapkan_bola_ringan()
		return

	_siapkan_data_suara_nuklir()
	
	node_nuklir = Node3D.new()
	node_nuklir.hide() 
	add_child(node_nuklir)
	
	mat_ledakan = StandardMaterial3D.new()
	mat_ledakan.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ledakan.emission_enabled = true
	
	mat_gelombang = StandardMaterial3D.new()
	mat_gelombang.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_gelombang.emission_enabled = true
	
	# 1. DASAR AWAN (Base Cloud)
	dasar = MeshInstance3D.new()
	var mesh_dasar = SphereMesh.new()
	mesh_dasar.radius = 1.0
	mesh_dasar.height = 0.6
	dasar.mesh = mesh_dasar
	dasar.material_override = mat_ledakan
	dasar.position.y = 0.2
	node_nuklir.add_child(dasar)
	
	# 2. BATANG JAMUR (Pillar)
	batang = MeshInstance3D.new()
	var mesh_batang = CylinderMesh.new()
	mesh_batang.top_radius = 0.4
	mesh_batang.bottom_radius = 0.6
	mesh_batang.height = 2.4
	batang.mesh = mesh_batang
	batang.material_override = mat_ledakan
	batang.position.y = 1.4
	node_nuklir.add_child(batang)
	
	# 3. KEPALA JAMUR (Mushroom Head)
	kepala = MeshInstance3D.new()
	var mesh_kepala = SphereMesh.new()
	mesh_kepala.radius = 1.3
	mesh_kepala.height = 1.8
	kepala.mesh = mesh_kepala
	kepala.material_override = mat_ledakan
	kepala.position.y = 3.2
	node_nuklir.add_child(kepala)
	
	# 4. GELOMBANG KEJUT (Shockwave)
	gelombang = MeshInstance3D.new()
	var mesh_gelombang = TorusMesh.new()
	mesh_gelombang.inner_radius = 0.3
	mesh_gelombang.outer_radius = 0.4
	gelombang.mesh = mesh_gelombang
	gelombang.material_override = mat_gelombang
	gelombang.position.y = 0.1
	node_nuklir.add_child(gelombang)
	
	# 5. KILATAN CAHAYA
	kilat = OmniLight3D.new()
	kilat.omni_range = 15.0
	kilat.position.y = 1.5
	node_nuklir.add_child(kilat)


# =======================================================
# 2. LOGIKA LEDAKAN NUKLIR JAMUR (SAAT DIINJAK)
# =======================================================
func mainkan_efek_bakar():
	aktif = false

	if grafis_ringan:
		await _mainkan_efek_bakar_ringan()
		return

	var kotak = get_child(0)
	if kotak is MeshInstance3D: 
		kotak.hide()

	node_nuklir.show()
	_mainkan_suara_ledakan_nuklir()

	mat_ledakan.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat_ledakan.emission = Color(1.0, 0.8, 0.2)
	mat_ledakan.emission_energy_multiplier = 3.0 # Dinaikkan mengimbangi ukuran medium
	
	mat_gelombang.albedo_color = Color(1.0, 0.8, 0.2, 0.8)
	mat_gelombang.emission = Color(1.0, 0.5, 0.0)
	mat_gelombang.emission_energy_multiplier = 1.8
	
	kilat.light_color = Color(1.0, 0.8, 0.4)
	kilat.light_energy = 12.0 # Dinaikkan sedikit dari sebelumnya

	gelombang.scale = Vector3.ZERO
	dasar.scale = Vector3(0.1, 0.0, 0.1)
	batang.scale = Vector3(0.1, 0.0, 0.1)
	kepala.scale = Vector3.ZERO

	# Skala akhir (Vector3) diperbesar menjadi ukuran medium
	var tw = create_tween().set_parallel(true)
	tw.tween_property(gelombang, "scale", Vector3(10.0, 0.2, 10.0), 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(dasar, "scale", Vector3(2.0, 1.0, 2.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(batang, "scale", Vector3(1.6, 1.3, 1.6), 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	var tw_kepala = create_tween()
	tw_kepala.tween_interval(0.15) 
	tw_kepala.tween_property(kepala, "scale", Vector3(2.5, 2.0, 2.5), 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	var tw_warna = create_tween().set_parallel(true)
	var warna_asap = Color(0.1, 0.1, 0.1, 0.95)

	tw_warna.tween_property(mat_gelombang, "albedo_color:a", 0.0, 0.8)
	tw_warna.tween_property(mat_gelombang, "emission_energy_multiplier", 0.0, 0.5)

	tw_warna.tween_property(mat_ledakan, "albedo_color", warna_asap, 1.5)
	tw_warna.tween_property(mat_ledakan, "emission", Color(0.6, 0.1, 0.0), 1.0) 
	tw_warna.chain().tween_property(mat_ledakan, "emission_energy_multiplier", 0.0, 1.0) 

	tw.tween_property(kilat, "light_energy", 0.0, 1.5)

	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		queue_free()

func _siapkan_bola_ringan():
	# Dibuat saat jebakan dipasang, dalam ukuran nyaris nol supaya tidak terlihat
	# pemain tapi tetap dirender satu kali — itu yang memicu shader tersusun lebih awal.
	mat_bola_ringan = StandardMaterial3D.new()
	mat_bola_ringan.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_bola_ringan.albedo_color = Color(1.0, 0.6, 0.1, 0.9)
	mat_bola_ringan.emission_enabled = true
	mat_bola_ringan.emission = Color(1.0, 0.4, 0.0)
	mat_bola_ringan.emission_energy_multiplier = 2.0

	bola_ringan = MeshInstance3D.new()
	var mesh_bola = SphereMesh.new()
	mesh_bola.radius = 1.0
	mesh_bola.height = 2.0
	mesh_bola.radial_segments = 8   # default 64 — dipangkas jauh
	mesh_bola.rings = 4             # default 32
	bola_ringan.mesh = mesh_bola
	bola_ringan.material_override = mat_bola_ringan
	bola_ringan.position.y = 1.0
	bola_ringan.scale = Vector3(0.001, 0.001, 0.001)
	add_child(bola_ringan)

func _mainkan_efek_bakar_ringan():
	# Versi hemat. Kuncinya: TIDAK membuat mesh/material baru sama sekali —
	# kotak api yang sudah berputar di petak sejak jebakan dipasang dipakai ulang,
	# tinggal dibesarkan lalu dipudarkan. Membuat material baru saat meledak
	# memaksa shader dikompilasi saat itu juga, dan itulah yang bikin tersendat
	# di injakan pertama (injakan kedua terasa lancar karena sudah ter-cache).
	var kotak = get_child(0)
	if not (kotak is MeshInstance3D):
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(self): queue_free()
		return

	var mat_kotak = kotak.material_override
	kotak.show()

	var tw = create_tween().set_parallel(true)
	tw.tween_property(kotak, "scale", Vector3(4.0, 4.0, 4.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if mat_kotak:
		tw.tween_property(mat_kotak, "albedo_color:a", 0.0, 0.7)
		tw.tween_property(mat_kotak, "emission_energy_multiplier", 0.0, 0.7)

	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self):
		queue_free()

# Dibagi ke semua jebakan api dalam satu sesi — 22.050 sampel cuma dihitung sekali.
static var cache_stream_nuklir: AudioStreamWAV = null
static var cache_stream_derak: AudioStreamWAV = null

func _siapkan_data_suara_nuklir():
	if cache_stream_nuklir != null:
		stream_nuklir = cache_stream_nuklir
		return

	stream_nuklir = AudioStreamWAV.new()
	stream_nuklir.format = AudioStreamWAV.FORMAT_8_BITS
	stream_nuklir.mix_rate = 11025
	var durasi = 2.0
	var jumlah_sampel = int(stream_nuklir.mix_rate * durasi)
	var data_suara = PackedByteArray()
	data_suara.resize(jumlah_sampel)

	for i in range(jumlah_sampel):
		var waktu = float(i) / stream_nuklir.mix_rate
		var noise = randf_range(-1.0, 1.0)
		if noise > 0.6: noise = 1.0
		elif noise < -0.6: noise = -1.0
		var envelope = exp(-1.5 * waktu) 
		data_suara[i] = int(noise * envelope * 127) + 128

	stream_nuklir.data = data_suara
	cache_stream_nuklir = stream_nuklir

func _mainkan_suara_ledakan_nuklir():
	var pemutar = AudioStreamPlayer3D.new()
	pemutar.stream = stream_nuklir
	pemutar.unit_size = 30.0
	pemutar.max_distance = 100.0
	add_child(pemutar)
	pemutar.play()


# =======================================================
# 3. LOGIKA EFEK ASAP MENEMPEL PADA TUBUH
# =======================================================
func tempel_efek_terbakar(target_model: Node3D):
	if target_model.has_node("EfekTerbakar"):
		return
		
	var wadah_efek = Node3D.new()
	wadah_efek.name = "EfekTerbakar"
	var kurva_skala = Curve.new()
	kurva_skala.add_point(Vector2(0.0, 1.0))
	kurva_skala.add_point(Vector2(1.0, 0.0))
	
	var asap = CPUParticles3D.new()
	# Partikel bola transparan yang saling tumpang-tindih adalah beban terbesar
	# di GPU HP kelas bawah. Di mode ringan jumlah & kerumitannya dipangkas.
	asap.amount = 6 if grafis_ringan else 20
	asap.lifetime = 1.0
	asap.mesh = SphereMesh.new()
	asap.mesh.radius = 0.25 if grafis_ringan else 0.35
	asap.mesh.height = 0.5 if grafis_ringan else 0.6
	if grafis_ringan:
		asap.mesh.radial_segments = 6
		asap.mesh.rings = 3
	asap.material_override = mat_asap_cache 
	
	asap.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	asap.emission_sphere_radius = 0.7
	asap.direction = Vector3(0, 1, 0)
	asap.spread = 20.0
	asap.initial_velocity_min = 2.0
	asap.initial_velocity_max = 4.0
	asap.gravity = Vector3(0, 0, 0)
	asap.local_coords = false
	asap.scale_amount_curve = kurva_skala
	
	wadah_efek.add_child(asap)
	wadah_efek.position.y = 1.0 
	target_model.add_child(wadah_efek)

func proses_penderitaan_giliran(model_target: Node3D, kamera: Camera3D, node_game: Node, jumlah_rugi: int):
	if not is_instance_valid(model_target) or not is_instance_valid(kamera): return
	
	node_game.target_kamera = model_target
	var pos_ideal = model_target.global_position + (kamera.global_transform.basis.z * 30.0)
	if kamera.global_position.distance_to(pos_ideal) > 5.0:
		var tw_cam = create_tween()
		tw_cam.tween_property(kamera, "global_position", pos_ideal, 0.5).set_trans(Tween.TRANS_SINE)
		await tw_cam.finished
		
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(model_target): return

	tempel_efek_terbakar(model_target)
	var wadah = model_target.get_node_or_null("EfekTerbakar")
	if wadah:
		for anak in wadah.get_children():
			if anak is CPUParticles3D:
				anak.restart() 

	_mainkan_suara_terbakar_singkat(model_target)
	
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(node_game): return
	# Lewat _siarkan_teks_kerugian, bukan _munculkan_teks_kerugian langsung —
	# supaya angka melayangnya ikut tampil di layar client, bukan cuma di host.
	var slot_korban = node_game._slot_dari_model(model_target)
	node_game._siarkan_teks_kerugian(slot_korban, jumlah_rugi)
	
	await get_tree().create_timer(1.2).timeout

func _mainkan_suara_terbakar_singkat(target: Node3D):
	var pemutar = AudioStreamPlayer3D.new()
	var stream_api = AudioStreamWAV.new()
	stream_api.format = AudioStreamWAV.FORMAT_8_BITS
	stream_api.mix_rate = 11025
	var durasi = 0.5
	var jumlah_sampel = int(stream_api.mix_rate * durasi)
	var data_suara = PackedByteArray()
	data_suara.resize(jumlah_sampel)
	for i in range(jumlah_sampel):
		var noise = (randi() % 100 - 50) 
		if randi() % 5 == 0: noise = randi() % 256 - 128
		var envelope = 1.0 - (float(i) / float(jumlah_sampel)) 
		data_suara[i] = int(noise * envelope) + 128
	stream_api.data = data_suara
	pemutar.stream = stream_api
	target.add_child(pemutar)
	pemutar.play()
	get_tree().create_timer(durasi + 0.1).timeout.connect(pemutar.queue_free)
