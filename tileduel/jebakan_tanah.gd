extends Node3D

var aktif: bool = true
var pemilik: int = -1
var penanda_visual: MeshInstance3D

# Fase 4 (B-b bagian 4, temuan 9 + hard_rock): jebakan tanah sekarang bisa
# bertahan lebih dari satu duel. sisa_duel diisi pemain_papan.gd::_pasang_jebakan
# saat dipasang, dari _angka_jebakan(pemilik,"tanah")["sisa_duel"] (Lv0 = 1,
# sama persis perilaku lama -- hilang setelah 1 duel). Keputusan bertahan/
# hancur SESUNGGUHNYA dibuat pemain_duel.gd::_selesaikan_tanah_setelah_duel
# (dipanggil SESUDAH pemilik_petak pasti mutakhir, bukan di sini -- temuan 9).
# sacred diisi TRUE kalau jebakan ini dipasang Ultimate Sacred Ground (belum
# disambung -- lihat bagian 5/fortress+sacred_ground): tidak ikut mengurangi
# sisa_duel, hanya hilang kalau petak berganti pemilik.
var sisa_duel: int = 1
var sacred: bool = false
var _sudah_duel_pertama: bool = false
var _hp_terakhir_ditambahkan: int = 0

# B-b bagian 4b (fortress): jumlah serangan jarak jauh yang MASIH bisa ditahan
# jebakan ini (Lv0/tidak dibeli = 0, tidak menahan apa pun -- perilaku lama).
# Diisi pemain_papan.gd::_pasang_jebakan dari _angka_jebakan(pemilik,"tanah")
# ["tahan_serangan"], dikurangi tiap kali pemain_role.gd::_benteng_menahan
# berhasil menahan satu serangan.
var sisa_tahan_serangan: int = 0

# C4 (B-c, 26-09): SATU sumber info runtime dibawa siaran state penuh
# (_kumpulkan_data_jebakan/_terapkan_data_jebakan, pemain_papan.gd) DAN
# rpc_jebakan_dipasang saat pemasangan pertama.
func ambil_info() -> Dictionary:
	return {"aktif": aktif, "sisa_duel": sisa_duel, "sacred": sacred,
		"sisa_tahan_serangan": sisa_tahan_serangan, "sudah_duel_pertama": _sudah_duel_pertama}

func terapkan_info(d: Dictionary) -> void:
	sisa_duel = int(d.get("sisa_duel", sisa_duel))
	sacred = bool(d.get("sacred", sacred))
	sisa_tahan_serangan = int(d.get("sisa_tahan_serangan", sisa_tahan_serangan))
	_sudah_duel_pertama = bool(d.get("sudah_duel_pertama", _sudah_duel_pertama))
	# C4: jebakan tanah yang SEHARUSNYA aktif (tampak) tapi salinan di layar ini
	# sedang tidak aktif (mis. RPC tampilan sebelumnya terlewat) -- munculkan lagi
	# lewat jalur yang sama seperti saat benar2 bertahan lewat duel. Arah
	# sebaliknya (aktif -> tidak) SENGAJA tidak disentuh di sini -- itu tetap
	# tugas RPC tampilan spesifik (rpc_jebakan_tanah_aktif dkk), bukan siaran
	# state umum ini.
	if bool(d.get("aktif", aktif)) and not aktif:
		aktifkan_kembali()

func _ready():
	# Membuat gundukan tanah kecil sebagai penanda jebakan sedang bersiap
	penanda_visual = MeshInstance3D.new()
	var mesh_batu = SphereMesh.new()
	mesh_batu.radius = 0.4
	mesh_batu.height = 0.2 
	penanda_visual.mesh = mesh_batu
	
	var mat_batu = StandardMaterial3D.new()
	mat_batu.albedo_color = Color(0.5, 0.3, 0.15) 
	mat_batu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	penanda_visual.material_override = mat_batu
	
	add_child(penanda_visual)
	penanda_visual.position.y = 0.1 

# C5 (B-c, 26-09): dipisah dari aktifkan_pelindung_sementara (tanpa efek
# samping, TIDAK mengubah _sudah_duel_pertama) supaya host bisa menghitung
# SEKALI, memakai angka yang sama untuk dirinya sendiri (di bawah) & RPC
# rpc_jebakan_tanah_aktif (pemain_papan.gd) -- dulu dihitung ulang diam-diam
# di client lewat parameter bawaan (selalu "+1", salah untuk hard_rock Lv3
# & tidak tahu Rock Breaker meniadakannya di host).
func hitung_bonus_hp(main_node: Node) -> int:
	# hard_rock Lv3: duel PERTAMA melawan jebakan ini dapat tambahan HP (di atas
	# +1 dasar Langkah A) -- duel berikutnya (kalau bertahan lewat sisa_duel)
	# hanya dapat +1 seperti biasa. Lv0/1/2 (hp_tambahan_awal = 0) = perilaku
	# lama, selalu +1.
	var bonus_hp = int(DataRole.DASAR["tanah_hp_duel"])
	if not _sudah_duel_pertama and pemilik >= 0:
		bonus_hp += int(main_node._angka_jebakan(pemilik, "tanah").get("hp_tambahan_awal", 0))
	return bonus_hp

# Fungsi ini dipanggil dari pemain.gd sesaat sebelum duel dimulai. bonus_hp
# (C5, 26-09): dihitung SEKALI oleh pemanggil (host: hitung_bonus_hp di atas;
# client: dari RPC rpc_jebakan_tanah_aktif) -- fungsi ini tidak lagi menghitung
# sendiri, supaya host & client selalu memakai angka yang identik.
func aktifkan_pelindung_sementara(main_node: Node, index_petak: int, ui_node: Node, bonus_hp: int):
	aktif = false
	_hp_terakhir_ditambahkan = bonus_hp
	_sudah_duel_pertama = true

	# Sembunyikan penanda kecil karena batu raksasa akan muncul
	if is_instance_valid(penanda_visual):
		penanda_visual.hide()
	
	# 1. Mainkan Suara
	var sfx_tanah = AudioStreamPlayer.new()
	sfx_tanah.bus = "BusSFX"
	sfx_tanah.volume_db = -10.0
	sfx_tanah.stream = _buat_suara_batu()
	add_child(sfx_tanah)
	sfx_tanah.play()
	
	# 2. Render Efek Visual Batu Raksasa
	var batu = MeshInstance3D.new()
	var mesh_batu = SphereMesh.new()
	mesh_batu.radius = 1.8
	mesh_batu.height = 3.6 
	batu.mesh = mesh_batu
	
	var mat_batu = StandardMaterial3D.new()
	mat_batu.albedo_color = Color(0.6, 0.4, 0.2) 
	mat_batu.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	batu.material_override = mat_batu
	
	get_tree().current_scene.add_child(batu)
	batu.global_position = self.global_position
	batu.scale = Vector3(1.0, 0.1, 1.0) 
	
	var tw = create_tween()
	tw.tween_property(batu, "scale", Vector3(1.0, 1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(batu, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Tunggu sampai batu benar-benar hancur
	await tw.finished
	
	if is_instance_valid(batu):
		batu.queue_free()
	if is_instance_valid(sfx_tanah):
		sfx_tanah.queue_free()

	# ========================================================
	# 3. RENDER TEKS MELAYANG "+1 TILE HP"
	# ========================================================
	var teks_buff = Label3D.new()
	teks_buff.text = "+%d Tile HP" % bonus_hp
	teks_buff.font_size = 220
	teks_buff.outline_size = 45
	teks_buff.modulate = Color(1.0, 0.85, 0.2) # Warna Emas
	teks_buff.outline_modulate = Color(0.3, 0.2, 0.0) # Outline Cokelat Gelap
	teks_buff.billboard = BaseMaterial3D.BILLBOARD_ENABLED # Agar selalu menghadap kamera
	
	get_tree().current_scene.add_child(teks_buff)
	# Posisikan teks tepat di atas petak
	teks_buff.global_position = self.global_position + Vector3(0, 1.0, 0)
	
	# Animasi Teks: Melayang naik sambil menghilang perlahan (seperti uap)
	var tw_teks = create_tween().set_parallel(true)
	tw_teks.tween_property(teks_buff, "global_position:y", self.global_position.y + 4.5, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_teks.tween_property(teks_buff, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw_teks.tween_property(teks_buff, "outline_modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# Duel hanya akan dimulai SETELAH teks ini selesai menguap
	await tw_teks.finished
	
	if is_instance_valid(teks_buff):
		teks_buff.queue_free()
	# ========================================================

	# 4. Berikan Buff HP Sementara ke Label Petak (Secara Nyata) -- bonus_hp
	# dihitung di atas (dasar +1, atau +3 kalau hard_rock Lv3 & ini duel pertama).
	main_node.nyawa_petak[index_petak] += bonus_hp
	main_node.update_semua_label_petak()
	
	self.hide() 
	
	# 5. Jalankan pengamatan duel di latar belakang
	_pantau_duel_berlangsung(main_node, index_petak, ui_node)

func _pantau_duel_berlangsung(main_node: Node, index_petak: int, ui_node: Node):
	# Tunggu sampai duel BENAR-BENAR selesai. Versi lama hanya menunggu layar duel
	# tertutup KALAU layarnya sedang terlihat -- padahal jebakan ini aktif SEBELUM
	# layar duel dibuka, jadi penantiannya selalu dilewati dan buff +1 langsung
	# ditarik lagi sebelum duel sempat membaca HP petak (+1 tidak pernah terhitung).
	# Sinyal duel_selesai dipancarkan ui_elemen di akhir jalankan_duel: di solo,
	# di host, maupun saat client memutar ulang duel.
	await ui_node.duel_selesai

	# UI Duel tertutup. Cek apakah petak ini masih milik pemilik jebakan awal
	if main_node.pemilik_petak[index_petak] == pemilik:
		# Tarik kembali buff HP sementara yang baru saja diberikan (jumlahnya
		# sama persis dengan yang diberikan barusan -- bisa +1 atau +3).
		main_node.nyawa_petak[index_petak] -= _hp_terakhir_ditambahkan

		# Jaring Pengaman Mutlak
		if main_node.nyawa_petak[index_petak] < 1:
			main_node.nyawa_petak[index_petak] = 1

		main_node.update_semua_label_petak()

	# Fase 4 (B-b bagian 4, temuan 9): keputusan jebakan ini BERTAHAN atau HANCUR
	# TIDAK LAGI dibuat di sini -- pemilik_petak di atas bisa saja masih basi
	# (sinyal duel_selesai terpancar SEBELUM _hasil_duel_petak menentukan pemilik
	# akhir). Keputusan sesungguhnya dibuat pemain_duel.gd::_selesaikan_tanah_setelah_duel,
	# dipanggil dari _hasil_duel_petak SETELAH data sungguh mutakhir (host/solo).
	# Fungsi ini di sini HANYA menarik buff HP sementara di atas.

func aktifkan_kembali() -> void:
	# Dipanggil _selesaikan_tanah_setelah_duel saat jebakan ini masih bertahan
	# (sisa_duel > 0, atau Sacred Ground) -- tampil lagi & siap dipicu duel
	# berikutnya. _sudah_duel_pertama SENGAJA tidak direset (bonus hard_rock
	# Lv3 hanya untuk duel pertama sepanjang umur jebakan ini).
	aktif = true
	show()
	if is_instance_valid(penanda_visual):
		penanda_visual.show()

func _buat_suara_batu() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	
	var panjang_data = int(22050 * 0.4)
	var data_byte = PackedByteArray()
	data_byte.resize(panjang_data)
	
	var fase = 0.0
	for i in range(panjang_data):
		var waktu_t = float(i) / float(panjang_data)
		var frekuensi = lerp(200.0, 50.0, waktu_t)
		fase += frekuensi * (PI * 2.0) / 22050
		var noise = randf_range(-1.0, 1.0)
		var envelope = 1.0 - (waktu_t * waktu_t)
		var nilai_gelombang = ((noise * 0.5) + (sin(fase) * 0.5)) * envelope
		var konversi_byte = int((nilai_gelombang + 1.0) * 127.5)
		data_byte[i] = clamp(konversi_byte, 0, 255)
		
	stream.data = data_byte
	return stream
