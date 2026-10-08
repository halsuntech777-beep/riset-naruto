extends Node3D

var pemilik: int = -1
var aktif = true
var mesh_inst: MeshInstance3D
var mode_residu = false # Penanda agar pilar jebakan tidak muncul saat dipanggil ulang

# C6 (B-c, 26-09, Ultimate stealth_charge): true kalau pemasangnya punya
# Ultimate Petir (diisi SEMUA jebakan petirnya, bukan cuma satu -- sesuai B4)
# -- disembunyikan dari siapa pun selain pemiliknya (pemain_papan.gd::
# _terapkan_siluman), termasuk di solo terhadap AI musuh.
var siluman: bool = false

# C4 (B-c, 26-09): SATU sumber info runtime dibawa siaran state penuh
# (_kumpulkan_data_jebakan/_terapkan_data_jebakan, pemain_papan.gd) DAN
# rpc_jebakan_dipasang saat pemasangan pertama.
func ambil_info() -> Dictionary:
	return {"siluman": siluman}

func terapkan_info(d: Dictionary) -> void:
	siluman = bool(d.get("siluman", siluman))

func _ready():
	# SINTESIS AUDIO SETRUM LISTRIK (Dibutuhkan oleh jebakan asli maupun efek sisa)
	var pemutar = AudioStreamPlayer3D.new()
	pemutar.name = "SuaraListrik"
	var stream_listrik = AudioStreamWAV.new()
	stream_listrik.format = AudioStreamWAV.FORMAT_8_BITS
	stream_listrik.mix_rate = 22050
	
	var durasi = 0.35
	var jumlah_sampel = int(stream_listrik.mix_rate * durasi)
	var data_suara = PackedByteArray()
	data_suara.resize(jumlah_sampel)
	
	for i in range(jumlah_sampel):
		var noise = randi() % 256 - 128
		var envelope = 1.0 - (float(i) / float(jumlah_sampel))
		data_suara[i] = int(noise * envelope) + 128
		
	stream_listrik.data = data_suara
	pemutar.stream = stream_listrik
	pemutar.unit_size = 15.0
	pemutar.max_distance = 40.0
	add_child(pemutar)

	# Jika script ini dipanggil hanya untuk memutar efek sisa paralisis, hentikan _ready di sini
	if mode_residu: return 

	# 1. BENTUK VISUAL KILAT/PETIR (Hanya dieksekusi jika ini jebakan asli)
	mesh_inst = MeshInstance3D.new()
	var silinder = CylinderMesh.new()
	silinder.top_radius = 0.08
	silinder.bottom_radius = 0.08
	silinder.height = 3.5
	mesh_inst.mesh = silinder
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.9) # Biru Cyan
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	mat.emission_energy_multiplier = 4.0
	mesh_inst.material_override = mat
	
	mesh_inst.position.y = 1.7
	add_child(mesh_inst)
	
	var tw_kedip = create_tween().set_loops()
	tw_kedip.tween_property(mesh_inst, "scale:x", 2.5, 0.05)
	tw_kedip.tween_property(mesh_inst, "scale:x", 0.3, 0.05)
	tw_kedip.tween_property(mesh_inst, "scale:z", 2.5, 0.05)
	tw_kedip.tween_property(mesh_inst, "scale:z", 0.3, 0.05)

func tempel_efek_paralisis(karakter_model: Node3D, kamera: Node3D):
	aktif = false
	var pemutar = get_node_or_null("SuaraListrik")
	if pemutar: pemutar.play()
	
	var fov_awal = kamera.fov
	var tw_kamera = create_tween()
	tw_kamera.tween_property(kamera, "fov", 40.0, 0.3).set_trans(Tween.TRANS_SINE)
	
	var posisi_awal = karakter_model.position
	var tw_getar = create_tween().set_loops(15)
	tw_getar.tween_property(karakter_model, "position", posisi_awal + Vector3(0.3, 0, 0), 0.04)
	tw_getar.tween_property(karakter_model, "position", posisi_awal - Vector3(0.3, 0, 0), 0.04)
	tw_getar.tween_property(karakter_model, "position", posisi_awal + Vector3(0, 0, 0.3), 0.04)
	tw_getar.tween_property(karakter_model, "position", posisi_awal - Vector3(0, 0, 0.3), 0.04)
	
	var mesh_listrik = MeshInstance3D.new()
	var silinder = CylinderMesh.new()
	silinder.top_radius = 0.7
	silinder.bottom_radius = 0.7
	silinder.height = 2.5
	mesh_listrik.mesh = silinder
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.0)
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_listrik.material_override = mat
	mesh_listrik.position.y = 1.2
	karakter_model.add_child(mesh_listrik)
	
	var tw_kedip_listrik = create_tween().set_loops()
	tw_kedip_listrik.tween_property(mesh_listrik, "scale:x", 1.3, 0.05)
	tw_kedip_listrik.tween_property(mesh_listrik, "scale:x", 0.7, 0.05)
	tw_kedip_listrik.tween_property(mesh_listrik, "scale:z", 1.3, 0.05)
	tw_kedip_listrik.tween_property(mesh_listrik, "scale:z", 0.7, 0.05)
	
	var tw = create_tween()
	tw.tween_property(mesh_inst, "scale", Vector3(5, 5, 5), 0.1)
	tw.tween_property(mesh_inst, "scale", Vector3(0, 0, 0), 0.2)
	
	await get_tree().create_timer(1.2).timeout
	karakter_model.position = posisi_awal 
	
	var tw_kamera_balik = create_tween()
	tw_kamera_balik.tween_property(kamera, "fov", fov_awal, 0.4).set_trans(Tween.TRANS_SINE)
	
	if is_instance_valid(mesh_listrik):
		mesh_listrik.queue_free()

# =========================================================================
# FUNGSI BARU: Dipanggil saat giliran karakter di-skip (mode residu)
# =========================================================================
func mainkan_efek_sisa_paralisis(karakter_model: Node3D, _kamera: Node3D):
	var pemutar = get_node_or_null("SuaraListrik")
	if pemutar: pemutar.play()
	
	var posisi_awal = karakter_model.position
	# Getaran sedikit lebih halus dari efek pertama
	var tw_getar = create_tween().set_loops(20) 
	tw_getar.tween_property(karakter_model, "position", posisi_awal + Vector3(0.15, 0, 0), 0.04)
	tw_getar.tween_property(karakter_model, "position", posisi_awal - Vector3(0.15, 0, 0), 0.04)
	tw_getar.tween_property(karakter_model, "position", posisi_awal + Vector3(0, 0, 0.15), 0.04)
	tw_getar.tween_property(karakter_model, "position", posisi_awal - Vector3(0, 0, 0.15), 0.04)
	
	var mesh_listrik = MeshInstance3D.new()
	var silinder = CylinderMesh.new()
	silinder.top_radius = 0.7
	silinder.bottom_radius = 0.7
	silinder.height = 2.5
	mesh_listrik.mesh = silinder
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 0.0, 0.3) # Dibuat lebih transparan
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 0.0)
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_listrik.material_override = mat
	mesh_listrik.position.y = 1.2
	karakter_model.add_child(mesh_listrik)
	
	var tw_kedip = create_tween().set_loops()
	tw_kedip.tween_property(mesh_listrik, "scale:x", 1.2, 0.05)
	tw_kedip.tween_property(mesh_listrik, "scale:x", 0.8, 0.05)
	tw_kedip.tween_property(mesh_listrik, "scale:z", 1.2, 0.05)
	tw_kedip.tween_property(mesh_listrik, "scale:z", 0.8, 0.05)
	
	# Waktu durasi sisa paralisis menyetrum
	await get_tree().create_timer(1.6).timeout
	
	karakter_model.position = posisi_awal 
	if is_instance_valid(mesh_listrik):
		mesh_listrik.queue_free()
