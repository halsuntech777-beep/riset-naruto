extends JebakanDasar
class_name JebakanAir

# Jeda (detik) antara karakter berdiri di atas genangan dan geiser meledak.
# Dipakai host (bergerak_maju) maupun client (rpc_jebakan_air_aktif) supaya sama.
const JEDA_SEBELUM_AKTIF := 0.5

var node_visual: CSGCylinder3D

# C4 (B-c, 26-09): air tidak punya field runtime tambahan -- fungsi ini ada
# supaya pemain_papan.gd bisa memanggil ambil_info()/terapkan_info() SAMA
# untuk kelima jenis jebakan tanpa perlu tahu jenisnya (SATU sumber).
func ambil_info() -> Dictionary:
	return {}

func terapkan_info(_d: Dictionary) -> void:
	pass

func _ready():
	elemen = "Air"
	
	# Bentuk Fisik Jebakan di Lantai (Pusaran Air / Genangan Biru)
	node_visual = CSGCylinder3D.new()
	node_visual.radius = 0.8
	node_visual.height = 0.05
	node_visual.position.y = 0.025 # Sedikit di atas tanah agar tidak z-fighting
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.6, 1.0, 0.6) # Biru air transparan
	node_visual.material = mat
	add_child(node_visual)
	
	# Efek Pusaran Berputar
	var tw = create_tween().set_loops()
	tw.tween_property(node_visual, "rotation_degrees:y", 360.0, 2.0).as_relative()

func mainkan_efek_geiser(posisi_target: Vector3):
	aktif = false
	node_visual.hide()
	
	# 1. Suara Ledakan Air
	var suara = AudioStreamPlayer.new()
	suara.bus = "BusSFX"
	suara.volume_db = -10.0
	suara.stream = _buat_suara_geiser()
	get_tree().current_scene.add_child(suara)
	suara.play()
	
	# 2. Visual Geiser (Pilar Air)
	var pilar = CSGCylinder3D.new()
	pilar.radius = 0.6
	pilar.height = 0.1
	var mat_pilar = StandardMaterial3D.new()
	mat_pilar.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_pilar.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_pilar.albedo_color = Color(0.2, 0.8, 1.0, 0.8)
	pilar.material = mat_pilar
	get_tree().current_scene.add_child(pilar)
	pilar.global_position = posisi_target + Vector3(0, 0.05, 0)
	
	# Animasi Melesat ke Atas
	var tw = create_tween().set_parallel(true)
	tw.tween_property(pilar, "height", 8.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pilar, "global_position:y", posisi_target.y + 4.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tw.tween_property(mat_pilar, "albedo_color:a", 0.0, 0.5).set_delay(0.2)
	tw.tween_property(pilar, "radius", 1.5, 0.5).set_delay(0.2)
	
	await tw.finished
	pilar.queue_free()
	suara.queue_free()
	# queue_free() telah dihapus dari sini agar jebakan tidak hancur duluan

func tempel_efek_gelembung(model_karakter: Node3D):
	# Suara Gelembung Muncul
	var suara = AudioStreamPlayer.new()
	suara.bus = "BusSFX"
	suara.volume_db = -10.0
	suara.stream = _buat_suara_gelembung()
	model_karakter.add_child(suara)
	suara.play()
	
	var gelembung = CSGSphere3D.new()
	gelembung.name = "EfekGelembung"
	gelembung.radius = 1.3
	gelembung.radial_segments = 16
	gelembung.rings = 16
	
	var mat_g = StandardMaterial3D.new()
	mat_g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_g.albedo_color = Color(0.4, 0.8, 1.0, 0.4)
	gelembung.material = mat_g
	
	gelembung.position.y = 1.0
	model_karakter.add_child(gelembung)
	
	# Animasi Mengambang (Pulsing)
	var tw = gelembung.create_tween().set_loops()
	tw.tween_property(gelembung, "scale", Vector3(1.05, 1.05, 1.05), 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(gelembung, "scale", Vector3(1.0, 1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)

func pilih_petak_jatuh(node_utama: Node3D, slot_korban: int = -1, idx_jebakan: int = -1, slot_pemasang: int = -1) -> int:
	# Pilih indeks petak jatuh. Dipisah dari eksekusi_lemparan_acak supaya di
	# multiplayer host bisa mengundinya DULUAN, lalu mengirim angka yang sama ke
	# client sebelum animasinya diputar.
	# B-b (B4): rapid_current/steady_feet menyempitkan kandidat lewat
	# node_utama._kandidat_petak_jatuh (Lv0 = semua petak, perilaku Langkah A
	# ACAK MURNI tetap sama) -- 3 parameter opsional dijaga default -1 supaya
	# tetap aman kalau suatu saat dipanggil tanpa konteks korban/pemasang.
	var total_petak = node_utama.rute_papan.size()
	if slot_korban < 0 or idx_jebakan < 0 or slot_pemasang < 0:
		return node_utama.mesin_acak.randi_range(0, total_petak - 1)
	var kandidat: Array = node_utama._kandidat_petak_jatuh(slot_korban, idx_jebakan, slot_pemasang)
	if kandidat.is_empty():
		return node_utama.mesin_acak.randi_range(0, total_petak - 1)
	return kandidat[node_utama.mesin_acak.randi_range(0, kandidat.size() - 1)]

func eksekusi_lemparan_acak(target_node: Node3D, model_karakter: Node3D, aktor: String, node_utama: Node3D, indeks_jatuh: int = -1) -> int:
	# indeks_jatuh: petak jatuh yang sudah diundi (multiplayer: dari host, supaya
	# lemparan di kedua layar identik). -1 = undi sendiri di sini seperti dulu.
	aktif = false
	node_visual.hide()

	# 1. Panggil efek visual pilar air (berjalan paralel di latar belakang)
	mainkan_efek_geiser(target_node.global_position)

	# 2-3. Tentukan petak jatuh (lihat pilih_petak_jatuh)
	if indeks_jatuh < 0:
		indeks_jatuh = pilih_petak_jatuh(node_utama)
	var node_jatuh = node_utama.rute_papan[indeks_jatuh]
	
	# 4. Kurva animasi melayang parabola jarak jauh
	var tw_lempar = create_tween().set_parallel(true)
	tw_lempar.tween_property(target_node, "global_position:x", node_jatuh.global_position.x, 1.5)
	tw_lempar.tween_property(target_node, "global_position:z", node_jatuh.global_position.z, 1.5)
	
	# Puncak lompatan ditinggikan (8.0) agar terlihat dramatis jika terlempar jauh
	var puncak_y = target_node.global_position.y + 8.0
	var tw_y = create_tween()
	tw_y.tween_property(target_node, "global_position:y", puncak_y, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_y.tween_property(target_node, "global_position:y", node_jatuh.global_position.y, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tw_lempar.finished
	
	# 5. Berikan status Gelembung setelah mendarat
	# Slot korban dicari dari nama aktornya (2-4 pemain).
	var slot_korban = node_utama._slot_dari_aktor(aktor)
	# Fase 4 (A4): steady_feet Lv1 memendekkan gelembung jadi 1 giliran.
	var durasi_gelembung = node_utama._durasi_gelembung(slot_korban)
	node_utama.daftar_pemain[slot_korban].sisa_gelembung = durasi_gelembung
	# Bagian 5 (#121): steady_feet Lv1+ SELALU memendekkan dari DASAR 2 -> 1 giliran
	# -- benar2 mengubah hasil, dicatat DI SINI (titik penerapan sungguhan, cuma
	# sekali per jebakan kena), BUKAN di _durasi_gelembung (dipanggil lagi cuma
	# untuk estimasi AI di ai_jebakan.gd, 14.5).
	if node_utama._lv_node(slot_korban, "steady_feet") > 0:
		node_utama._tambah_stat(slot_korban, "tahan_kurangi")

	tempel_efek_gelembung(model_karakter)

	node_utama.teks_dadu.text = "Landed randomly! Trapped in a Bubble for %d turn%s!" % [durasi_gelembung, "" if durasi_gelembung == 1 else "s"]
	await get_tree().create_timer(1.5).timeout
	
	# 6. Kembalikan posisi baru agar sistem di pemain.gd tahu karakter ada di mana sekarang
	return indeks_jatuh

func _buat_suara_geiser() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	var sr = 22050
	stream.mix_rate = sr
	var length = int(sr * 0.8)
	var data = PackedByteArray(); data.resize(length)
	
	for i in range(length):
		var t = float(i) / float(length)
		var noise = randf_range(-1.0, 1.0)
		var freq = lerp(200.0, 800.0, t)
		var phase = sin(t * freq * PI * 2.0)
		var env = exp(-t * 5.0)
		var val = ((noise * 0.6) + (phase * 0.4)) * env
		data[i] = clamp(int((val + 1.0) * 127.5), 0, 255)
	stream.data = data
	return stream

func _buat_suara_gelembung() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var length = int(22050 * 0.4)
	var data = PackedByteArray(); data.resize(length)
	
	for i in range(length):
		var t = float(i) / float(length)
		var freq = lerp(400.0, 900.0, t)
		var phase = sin(t * freq * PI * 2.0)
		var env = 1.0 - t
		var val = phase * env * 0.6
		data[i] = clamp(int((val + 1.0) * 127.5), 0, 255)
	stream.data = data
	return stream
