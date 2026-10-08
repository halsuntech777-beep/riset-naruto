extends Node3D

var pemilik: int = -1
var aktif = true

# C7 (B-c, 26-09, perbaikan bug T1): jumlah PINDAH+AKTIF-LAGI TAMBAHAN yang
# masih tersisa sesudah kena (bukan dihapus) -- diisi 1 di pemain_papan.gd
# ::_pasang_jebakan kalau pemasang punya Ultimate Tornado (pola SAMA Phoenix
# sisa_aktif_ulang, jebakan_api.gd). Sebelum ini, jebakan Tornado pindah &
# aktif lagi TANPA BATAS (rencana B4: "sekali lagi") -- lihat pemain.gd blok
# angin (bergerak_maju).
var sisa_pindah: int = 0

# C4 (B-c, 26-09): SATU sumber info runtime dibawa siaran state penuh
# (_kumpulkan_data_jebakan/_terapkan_data_jebakan, pemain_papan.gd) DAN
# rpc_jebakan_dipasang saat pemasangan pertama.
func ambil_info() -> Dictionary:
	return {"sisa_pindah": sisa_pindah}

func terapkan_info(d: Dictionary) -> void:
	sisa_pindah = int(d.get("sisa_pindah", sisa_pindah))

func _ready():
	# 1. BENTUK VISUAL TORNADO KERTAS
	var mesh_inst = MeshInstance3D.new()
	var kerucut = CylinderMesh.new()
	kerucut.top_radius = 1.2
	kerucut.bottom_radius = 0.1
	kerucut.height = 3.0
	mesh_inst.mesh = kerucut
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.7, 0.9, 0.9, 0.4) 
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.8, 0.8)
	mesh_inst.material_override = mat
	
	mesh_inst.position.y = 1.5 
	add_child(mesh_inst)
	
	# 2. SINTESIS AUDIO ANGIN (WHITE NOISE)
	var pemutar = AudioStreamPlayer3D.new()
	pemutar.name = "SuaraAngin"
	var stream_angin = AudioStreamWAV.new()
	stream_angin.format = AudioStreamWAV.FORMAT_8_BITS
	stream_angin.mix_rate = 11025 
	
	var durasi = 1.2 
	var jumlah_sampel = int(stream_angin.mix_rate * durasi)
	var data_suara = PackedByteArray()
	data_suara.resize(jumlah_sampel)
	
	for i in range(jumlah_sampel):
		var noise = randi() % 256 - 128
		var envelope = sin(PI * float(i) / float(jumlah_sampel)) 
		data_suara[i] = int(noise * envelope) + 128 
		
	stream_angin.data = data_suara
	pemutar.stream = stream_angin
	pemutar.unit_size = 15.0
	pemutar.max_distance = 40.0
	add_child(pemutar)

func _process(delta):
	rotation_degrees.y += 400 * delta

# =======================================================
# MODIFIKASI: MENAMBAHKAN PARAMETER TARGET_MODEL & ANIMASI
# =======================================================
func mainkan_efek_perampas(target_model: Node3D):
	aktif = false
	var pemutar = get_node_or_null("SuaraAngin")
	if pemutar: pemutar.play()
	
	var tw_jebakan = create_tween()
	tw_jebakan.tween_property(self, "scale", Vector3(1.5, 1.5, 1.5), 0.2)
	tw_jebakan.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# --- 1. ANIMASI KARAKTER BERPUTAR DAN MELAYANG ---
	var pos_y_asli = target_model.position.y
	var tw_karakter = target_model.create_tween().set_parallel(true)
	
	# Karakter melayang naik (0.3 detik pertama)
	tw_karakter.tween_property(target_model, "position:y", pos_y_asli + 2.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Karakter berputar 360 derajat di tempat (0.6 detik)
	tw_karakter.tween_property(target_model, "rotation_degrees:y", target_model.rotation_degrees.y + 360.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Karakter jatuh kembali mendarat (0.3 detik terakhir) setelah melayang naik selesai
	tw_karakter.chain().tween_property(target_model, "position:y", pos_y_asli, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# --- 2. ANIMASI KEPINGAN KOIN KELUAR DARI TUBUH ---
	var scene_utama = target_model.get_tree().current_scene
	for i in range(6): # Memunculkan 6 keping koin berhamburan secara kosmetik
		var koin = MeshInstance3D.new()
		var silinder = CylinderMesh.new()
		silinder.height = 0.05
		silinder.top_radius = 0.25
		silinder.bottom_radius = 0.25
		koin.mesh = silinder
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.1)
		mat.metallic = 1.0
		mat.roughness = 0.3
		koin.material_override = mat
		
		scene_utama.add_child(koin)
		koin.global_position = target_model.global_position + Vector3(0, 1.5, 0)
		
		var sudut_acak = randf() * PI * 2.0
		var jarak_lempar = randf_range(1.5, 3.5)
		var target_x = koin.global_position.x + cos(sudut_acak) * jarak_lempar
		var target_z = koin.global_position.z + sin(sudut_acak) * jarak_lempar
		
		var tw_koin = scene_utama.create_tween().set_parallel(true)
		tw_koin.tween_property(koin, "global_position:x", target_x, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_koin.tween_property(koin, "global_position:z", target_z, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		# Koin berputar liar di udara
		tw_koin.tween_property(koin, "rotation_degrees", Vector3(randf_range(360, 720), randf_range(360, 720), 0), 0.5)
		
		# Koin terlempar ke atas lalu jatuh
		var tw_koin_y = scene_utama.create_tween()
		tw_koin_y.tween_property(koin, "global_position:y", koin.global_position.y + 2.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_koin_y.tween_property(koin, "global_position:y", 0.1, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		# Koin mengecil lalu hilang
		tw_koin_y.chain().tween_property(koin, "scale", Vector3.ZERO, 0.2)
		tw_koin_y.chain().tween_callback(koin.queue_free)
	
	await tw_jebakan.finished
	queue_free()

func eksekusi_sebar_acak(rute_papan: Array, total_koin: int, mesin_acak: RandomNumberGenerator) -> Array:
	# Mengembalikan daftar [index_petak, koin_yang_ditambahkan] -- dipakai host
	# untuk mengabari client petak mana saja yang kejatuhan koin (lihat
	# pemain.gd _siarkan_koin_tercecer). Pengacakannya sendiri tidak berubah.
	var jumlah_sasaran = mesin_acak.randi_range(2, 4)
	
	var petak_kosong = []
	var petak_berisi = []
	
	for i in range(1, rute_papan.size()):
		var petak = rute_papan[i]
		if petak.has_node("KoinTercecer"):
			petak_berisi.append(petak) 
		else:
			petak_kosong.append(petak) 
			
	var daftar_petak_terpilih = []
	
	for i in range(jumlah_sasaran):
		if petak_kosong.size() > 0:
			var index_acak = mesin_acak.randi_range(0, petak_kosong.size() - 1)
			daftar_petak_terpilih.append(petak_kosong[index_acak])
			petak_kosong.remove_at(index_acak) 
		elif petak_berisi.size() > 0:
			var index_acak = mesin_acak.randi_range(0, petak_berisi.size() - 1)
			daftar_petak_terpilih.append(petak_berisi[index_acak])
			petak_berisi.remove_at(index_acak) 
			
	if daftar_petak_terpilih.size() == 0: return []

	var koin_per_petak = int(float(total_koin) / float(daftar_petak_terpilih.size()))
	var hasil = []

	for petak in daftar_petak_terpilih:
		var koin_lama = petak.get_node_or_null("KoinTercecer")
		if koin_lama:
			koin_lama.tambah_koin(koin_per_petak)
		else:
			var script_koin = preload("res://koin_tercecer.gd")
			var koin_baru = script_koin.new()
			koin_baru.name = "KoinTercecer"
			koin_baru.isi_koin = koin_per_petak
			petak.add_child(koin_baru)
		hasil.append([rute_papan.find(petak), koin_per_petak])
	return hasil
