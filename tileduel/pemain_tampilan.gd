@abstract
extends "res://pemain_dasar.gd"
# ========================================================================
# PEMAIN_TAMPILAN.GD
# TAMPILAN: HUD uang/bintang, label petak & ronde, menara, warna & posisi karakter, pemanasan shader
# pemain.gd dipecah BERTINGKAT (Fase 3): tiap file meneruskan (extends) file
# sebelumnya, jadi semuanya tetap SATU node Pemain -- variabel & fungsi dari file
# lain dipakai langsung seperti dulu. Urutan: pemain_dasar.gd -> pemain_tampilan.gd -> pemain_papan.gd -> pemain_kartu.gd -> pemain_duel.gd -> pemain_jaringan.gd -> pemain.gd
# @abstract = file ini bagian dari pemain.gd, tidak dipasang sendiri ke node.
# ========================================================================

# Material dari _pemanasan_shader yang sengaja dibiarkan hidup sepanjang
# permainan, supaya shader-nya tidak dibuang lalu disusun ulang (lihat di sana).
var _penjaga_shader: Array = []

var _ronde_spanduk: int = -1         # ronde yang spanduk FINAL ROUND-nya sudah tampil

func _pemanasan_shader() -> void:
	# Lag 4-5 detik saat efek PERTAMA kali muncul bukan dari kode GDScript —
	# kita sudah mengukurnya, hanya ~50 ms. Sisanya adalah GPU menyusun (compile)
	# shader saat sebuah material digambar untuk pertama kalinya. Di GPU lemah
	# itu bisa makan beberapa detik; sesudahnya tersimpan, makanya kali kedua mulus.
	#
	# Caranya: gambar material yang PERSIS SAMA sekali di awal, dalam ukuran
	# sangat kecil di depan kamera. Percobaan sebelumnya gagal karena memakai
	# material tebakan — shader disusun per KOMBINASI FITUR, jadi kalau satu
	# properti saja berbeda (mis. billboard), yang tersusun shader yang salah.
	await get_tree().process_frame

	var wadah = Node3D.new()
	add_child(wadah)
	if kamera:
		# Ukuran normal, jarak dekat — supaya objeknya PASTI menutupi piksel dan
		# benar-benar digambar. Versi sebelumnya diperkecil 1/100 sampai lebih kecil
		# dari satu piksel, dan kemungkinan besar dilewati tanpa pernah digambar,
		# sehingga shader-nya tidak pernah tersusun.
		wadah.global_position = kamera.global_position - kamera.global_transform.basis.z * 1.2
		wadah.look_at(kamera.global_position, Vector3.UP)

	# Efek beli petak: CSGBox3D + unshaded + alpha (tanpa billboard)
	var kotak_beli = CSGBox3D.new()
	kotak_beli.size = Vector3(0.5, 0.05, 0.5)
	var mat_beli = StandardMaterial3D.new()
	mat_beli.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_beli.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_beli.albedo_color = Color(0.2, 0.5, 1.0, 0.02)
	kotak_beli.material = mat_beli
	wadah.add_child(kotak_beli)

	# --- 2. Jebakan api: instance aslinya, bukan tiruan (lihat fungsinya di bawah) ---
	_pemanasan_jebakan_api(wadah)

	# --- 3-5. Petak permata: instance aslinya, bukan tiruan (lihat fungsinya di bawah) ---
	_pemanasan_permata(wadah)

	# --- 6. Label3D angka kerugian: HARUS sama persis dengan aslinya.
	# outline_size dan billboard masing-masing menghasilkan varian shader
	# berbeda — versi sebelumnya memakai font kecil tanpa outline, jadi yang
	# tersusun shader yang salah dan lag-nya tetap muncul.
	var lbl = Label3D.new()
	lbl.text = "-0"
	lbl.font_size = 250
	lbl.outline_size = 50
	lbl.modulate = Color(0.7, 0.0, 0.0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	wadah.add_child(lbl)

	# --- 7. Cahaya dinamis OmniLight3D -- dipakai ledakan penuh jebakan api dan
	# koin 3D penentu seri (keduanya hanya di setelan selain Very Low).
	# Jangkauannya WAJIB luas: lampu seperti ini butuh versi shader tambahan untuk
	# SETIAP material yang disinarinya, termasuk petak-petak papan di sekitarnya.
	# Sudah diukur: dengan jangkauan mungil (0.1) jeda koin pertama cuma turun
	# ~25%; dengan jangkauan luas jedanya hilang total. Energinya tetap nyaris
	# nol, jadi tidak terlihat.
	if AudioGrafis.baca_tingkat() != "sangat_rendah":
		var lampu = OmniLight3D.new()
		lampu.light_energy = 0.01
		lampu.omni_range = 60.0
		wadah.add_child(lampu)

		# --- 8. Koin 3D penentu seri: salinan PERSIS material & teksnya (lihat
		# _eksekusi_flip_koin di ui_elemen.gd), termasuk huruf ukuran 200 bergaris
		# tepi 40 yang juga mahal disiapkan pertama kali. Very Low memakai koin 2D.
		var koin = CSGCylinder3D.new()
		koin.radius = 0.2
		koin.height = 0.05
		koin.sides = 64
		var mat_koin = StandardMaterial3D.new()
		mat_koin.albedo_color = Color(1.0, 0.85, 0.2)
		mat_koin.metallic = 1.0
		mat_koin.roughness = 0.25
		koin.material = mat_koin
		wadah.add_child(koin)

		var teks_koin = Label3D.new()
		teks_koin.text = "HEADS TAILS"
		teks_koin.font_size = 200
		teks_koin.outline_size = 40
		teks_koin.modulate = Color(0.65, 0.45, 0.0)
		teks_koin.outline_modulate = Color(1.0, 0.95, 0.5)
		teks_koin.shaded = true
		teks_koin.pixel_size = 0.0005 # dikecilkan saja; ukuran tampil tidak memengaruhi shader
		wadah.add_child(teks_koin)

	# Beri beberapa frame agar semuanya sempat digambar sekali
	# Wadah HARUS mengikuti kamera tiap frame. Kamera menu utama melayang ke
	# posisi orbitnya tepat setelah _ready(), jadi kalau posisinya cuma ditetapkan
	# sekali di awal, wadah ini langsung ditinggal keluar dari pandangan — dan
	# objek yang tidak tergambar tidak akan pernah menyusun shader-nya.
	#
	# DUA TAHAP: 5 frame pertama semua lampu di wadah dimatikan, 5 frame sisanya
	# dinyalakan. Shader disusun terpisah untuk objek yang DISINARI lampu omni dan
	# yang TIDAK -- kebanyakan efek (pilar Start, permata, teks) muncul tanpa lampu
	# di dekatnya. Dulu lampunya menyala terus, jadi di setelan di atas Very Low
	# versi "tanpa lampu" baru disusun saat efeknya pertama kali muncul.
	var lampu_wadah = wadah.find_children("*", "Light3D", true, false)
	for l in lampu_wadah: l.visible = false
	for _i in range(10):
		if _i == 5:
			for l in lampu_wadah:
				if is_instance_valid(l): l.visible = true
		await get_tree().process_frame
		if is_instance_valid(wadah) and kamera:
			wadah.global_position = kamera.global_position - kamera.global_transform.basis.z * 1.2
			wadah.look_at(kamera.global_position, Vector3.UP)

	# Material-material di atas DISIMPAN, bukan ikut dibuang. Godot membuang shader
	# StandardMaterial3D begitu tidak ada lagi material hidup yang memakainya --
	# lalu menyusunnya ULANG saat efek berikutnya muncul. Terukur di rig uji: pilar
	# efek Start ~150 ms di SETIAP putaran kalau material pemanasannya ikut dibuang,
	# ~30 ms kalau disimpan. Tanpa ini, pemanasan sebagian besar efek jadi sia-sia.
	for n in wadah.find_children("*", "", true, false):
		if n is GeometryInstance3D and n.material_override != null:
			_penjaga_shader.append(n.material_override)
		if n is CSGPrimitive3D and n.material != null:
			_penjaga_shader.append(n.material)

	wadah.queue_free()

static func _pemanasan_permata(wadah: Node3D) -> void:
	# Petak permata ASLI di dalam wadah pemanasan -- _ready()-nya membaca setelan
	# grafis yang sama, jadi otomatis ikut versi ringan (Very Low) atau penuh, dan
	# sekalian menyintesis suara "ting" sekarang.
	var pp = preload("res://petak_permata.gd").new()
	pp.name = "PemanasanPermata"
	wadah.add_child(pp)

	# a. Stiker permata di petak (shader custom). Stiker aslinya rebah di lantai
	#    (terlihat dari samping di sini), jadi dipasang ke kotak yang menghadap kamera.
	var mesh_permata = MeshInstance3D.new()
	mesh_permata.mesh = BoxMesh.new()
	mesh_permata.material_override = pp._buat_material_permata()
	wadah.add_child(mesh_permata)

	# b. Kilauan bintang (shader custom, sekarang satu untuk semua kilauan)
	var mesh_kilau = MeshInstance3D.new()
	mesh_kilau.mesh = QuadMesh.new()
	var mat_kilau = ShaderMaterial.new()
	mat_kilau.shader = pp._dapatkan_shader_kilauan()
	mesh_kilau.material_override = mat_kilau
	wadah.add_child(mesh_kilau)

	# c. Efek saat permata DIAMBIL: bentuk & material yang PERSIS dipakai
	#    mainkan_efek_koleksi. Dulu di sini dipakai salinan material kaca tanpa
	#    refraction & emission -- varian shader yang salah, jadi material aslinya
	#    tetap disusun saat permata pertama diambil (terukur ~575 ms di rig uji).
	pp.buat_contoh_efek(wadah)

static func _pemanasan_jebakan_api(wadah: Node3D) -> void:
	# Semua yang digambar saat jebakan api PERTAMA kali kena, digambar sekali di
	# sini dulu (di dalam wadah pemanasan -- ikut terhapus bersamanya).
	# Jebakan aslinya dibaca dari setelan grafis yang sama, jadi otomatis ikut
	# versi ringan di Very Low dan versi penuh di setelan lain.
	var api = preload("res://jebakan_api.gd").new()
	api.name = "PemanasanApi"
	wadah.add_child(api) # kotak api berputar (dipakai ulang juga oleh ledakan ringan)

	# a. Asap terbakar di tubuh korban (tempel_efek_terbakar) -- SEMUA setelan.
	#    Di Very Low inilah yang tampil pertama kali saat kena: ledakan ringan cuma
	#    memakai ulang kotak api di atas, sedangkan asapnya CPUParticles3D -- digambar
	#    lewat MultiMesh, varian shader tersendiri. "pemanas_asap" di _ready()
	#    jebakan_api.gd tidak pernah benar-benar tergambar (partikelnya tanpa mesh
	#    dan diletakkan 100 unit di bawah papan).
	var korban_dummy = Node3D.new()
	korban_dummy.position.y = -1.0 # asap dipasang 1.0 di atas korban -> tepat di tengah wadah
	wadah.add_child(korban_dummy)
	api.tempel_efek_terbakar(korban_dummy)
	var efek_asap = korban_dummy.get_node_or_null("EfekTerbakar")
	if efek_asap:
		for anak in efek_asap.get_children():
			if anak is CPUParticles3D:
				# Setelan CPU saja (tidak mengubah shader): semua partikel langsung
				# muncul & diam di depan kamera selama frame-frame pemanasan.
				anak.explosiveness = 1.0
				anak.initial_velocity_min = 0.0
				anak.initial_velocity_max = 0.0
				anak.restart()

	# b. Ledakan PENUH (node_nuklir) -- hanya ada di setelan SELAIN Very Low. Node
	#    ini sengaja disembunyikan sampai ledakan sungguhan, jadi shader mat_ledakan
	#    & mat_gelombang (4 mesh beda bentuk) tidak pernah tersusun sebelumnya.
	#    Diperkecil (ukuran tidak memengaruhi shader, asal tetap beberapa piksel) dan
	#    lampu kilatnya diredupkan supaya tidak menyilaukan layar saat loading.
	if is_instance_valid(api.node_nuklir):
		api.node_nuklir.scale = Vector3(0.2, 0.2, 0.2)
		if is_instance_valid(api.kilat):
			api.kilat.light_energy = 0.01
		api.node_nuklir.show()

func _jalankan_auto_detect_pertama() -> void:
	# Mulai dari "sedang" sebagai titik ukur yang netral.
	AudioGrafis.simpan_tingkat("sedang")
	AudioGrafis.muat_seting_grafis(self)

	var fps = await AudioGrafis.ukur_fps(self, 5.0)
	var tingkat = AudioGrafis.tentukan_tingkat(fps, "sedang")
	AudioGrafis.simpan_tingkat(tingkat)

	# Terapkan yang bisa langsung berlaku (skala resolusi, MSAA, bayangan).
	# Inilah bagian yang paling besar pengaruhnya ke FPS, jadi pemain sudah
	# merasakan sebagian besar manfaatnya sejak sesi pertama.
	AudioGrafis.muat_seting_grafis(self)

func _munculkan_teks_paralysis(target_model: Node3D) -> void:
	# Teks melayang oranye "PARALYSIS" dari tubuh korban yang bergetar -- pola
	# yang sama dengan _munculkan_teks_kerugian, cuma warna & tulisannya beda.
	var teks_p = Label3D.new()
	teks_p.text = "PARALYSIS"
	teks_p.font_size = 200
	teks_p.outline_size = 45
	teks_p.modulate = Color(1.0, 0.55, 0.0) # Oranye
	teks_p.outline_modulate = Color(0.3, 0.1, 0.0)
	teks_p.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	get_tree().current_scene.add_child(teks_p)
	teks_p.global_position = target_model.global_position + Vector3(0, 1.5, 0)

	var tw = create_tween().set_parallel(true)
	tw.tween_property(teks_p, "global_position:y", target_model.global_position.y + 4.5, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(teks_p, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	await tw.finished
	if is_instance_valid(teks_p):
		teks_p.queue_free()

func _bangun_fisik_menara(posisi_index, _cat_warna, level):
	var petak_target = rute_papan[posisi_index]
	var balok_lantai = petak_target.get_child(0)
	
	# Deteksi otomatis ukuran petak untuk mencetak bingkai emboss yang pas
	var p_x = 2.0
	var l_z = 2.0
	if "size" in balok_lantai:
		p_x = balok_lantai.size.x
		l_z = balok_lantai.size.z
	elif balok_lantai is MeshInstance3D and balok_lantai.mesh:
		var aabb = balok_lantai.mesh.get_aabb()
		p_x = aabb.size.x
		l_z = aabb.size.z
		
	var tebal = 0.15
	var tinggi = 0.05 if level == 1 else 0.12
	
	# Membuat kontainer utama untuk Emboss
	var frame_emboss = Node3D.new()
	frame_emboss.name = "EmbossMenara"
	frame_emboss.position.y = 0.1 # Sedikit menonjol di atas permukaan lantai
	
	var mat_emboss = StandardMaterial3D.new()
	if level == 1:
		mat_emboss.albedo_color = Color.BLACK
		mat_emboss.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif level == 2:
		# =======================================================
		# PERUBAHAN: WARNA EMAS (SAMA PERSIS DENGAN KOIN FLIP)
		# =======================================================
		mat_emboss.albedo_color = Color(1.0, 0.85, 0.1) # Warna Emas Koin
		mat_emboss.metallic = 1.0 # Pantulan logam maksimal seperti koin
		mat_emboss.roughness = 0.25
		
		# --- EFEK KILAP BERJALAN (SWEEP SHINE) ---
		# 1. Membuat Gradient Hitam -> Putih -> Hitam
		var grad = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.45, 0.5, 0.55, 1.0])
		grad.colors = PackedColorArray([Color.BLACK, Color.BLACK, Color.WHITE, Color.BLACK, Color.BLACK])
		
		# 2. Mengubah Gradient menjadi Tekstur 1D
		var tex = GradientTexture1D.new()
		tex.gradient = grad
		
		# 3. Menerapkan ke fitur Emission (Menyala)
		mat_emboss.emission_enabled = true
		mat_emboss.emission = Color(1.0, 0.85, 0.1) # Kilauan kini berwarna emas murni (bukan putih)
		mat_emboss.emission_energy_multiplier = 2.0 # Diturunkan dari 5.0 agar emasnya tidak pudar/memutih
		mat_emboss.emission_texture = tex
		
		# Triplanar penting agar tekstur membalut seluruh 4 sisi bingkai dengan mulus
		mat_emboss.uv1_triplanar = true
	
	# Membuat 4 sisi bingkai menggunakan MeshInstance3D (Jauh lebih ringan)
	var sisi_atas = MeshInstance3D.new()
	var mesh_atas = BoxMesh.new()
	mesh_atas.size = Vector3(p_x, tinggi, tebal)
	sisi_atas.mesh = mesh_atas
	sisi_atas.position = Vector3(0, 0, -l_z/2.0 + tebal/2.0)
	sisi_atas.material_override = mat_emboss
	frame_emboss.add_child(sisi_atas)
	
	var sisi_bawah = MeshInstance3D.new()
	var mesh_bawah = BoxMesh.new()
	mesh_bawah.size = Vector3(p_x, tinggi, tebal)
	sisi_bawah.mesh = mesh_bawah
	sisi_bawah.position = Vector3(0, 0, l_z/2.0 - tebal/2.0)
	sisi_bawah.material_override = mat_emboss
	frame_emboss.add_child(sisi_bawah)
	
	var sisi_kiri = MeshInstance3D.new()
	var mesh_kiri = BoxMesh.new()
	mesh_kiri.size = Vector3(tebal, tinggi, l_z - tebal*2.0)
	sisi_kiri.mesh = mesh_kiri
	sisi_kiri.position = Vector3(-p_x/2.0 + tebal/2.0, 0, 0)
	sisi_kiri.material_override = mat_emboss
	frame_emboss.add_child(sisi_kiri)
	
	var sisi_kanan = MeshInstance3D.new()
	var mesh_kanan = BoxMesh.new()
	mesh_kanan.size = Vector3(tebal, tinggi, l_z - tebal*2.0)
	sisi_kanan.mesh = mesh_kanan
	sisi_kanan.position = Vector3(p_x/2.0 - tebal/2.0, 0, 0)
	sisi_kanan.material_override = mat_emboss
	frame_emboss.add_child(sisi_kanan)
	
	# Hapus emboss level lama jika sedang upgrade
	# PERBAIKAN: Gunakan begins_with di sini juga agar aman dari duplikasi nama
	for anak in petak_target.get_children():
		if anak.name.begins_with("Emboss"):
			anak.queue_free()
			
	petak_target.add_child(frame_emboss)
	
	# =======================================================
	# PENGGERAK ANIMASI KILAP (Khusus Level 2)
	# =======================================================
	if level == 2:
		var tw = frame_emboss.create_tween().set_loops()
		# 1. Paksa posisi kilap ke titik paling kiri luar (-0.5) tanpa jeda waktu (0.0 dtk)
		tw.tween_property(mat_emboss, "uv1_offset", Vector3(-0.5, 0.0, -0.5), 0.05)
		# 2. Luncurkan kilap ke titik paling kanan luar (1.5) selama 0.7 detik
		tw.tween_property(mat_emboss, "uv1_offset", Vector3(1.5, 0.0, 1.5), 0.7)
		# 3. Diam/jeda selama 1.0 detik penuh sebelum efek kembali berulang dari awal
		tw.tween_interval(1.0)

func update_semua_label_petak():
	for i in range(rute_papan.size()):
		if status_kepemilikan_petak[i] and i != 0:
			var denda = 100
			if level_menara_petak[i] == 1: denda = 300
			elif level_menara_petak[i] == 2: denda = 600
			
			var siapa_pemilik = pemilik_petak[i]
			var jumlah_nyawa = nyawa_petak[i]

			# B-b bagian 4b (fortress): tandai petak yang jebakan tanahnya sendiri
			# masih punya jatah menahan serangan jarak jauh. Dibaca langsung dari
			# node (bukan lewat fungsi pemain_role.gd -- file ini LEBIH AWAL di
			# rantai extends, tidak boleh memanggil fungsi file belakangnya).
			var jebakan_tanah_i = rute_papan[i].get_node_or_null("JebakanTanah")
			var dilindungi = jebakan_tanah_i != null and jebakan_tanah_i.aktif \
					and jebakan_tanah_i.pemilik == siapa_pemilik and jebakan_tanah_i.sisa_tahan_serangan > 0

			# Mengirim data ke ui_petak.gd untuk diproses dan dirender
			label_petak_3d[i].perbarui_tampilan(siapa_pemilik, jumlah_nyawa, denda, dilindungi)
		else:
			# Bersihkan teks jika petak netral
			label_petak_3d[i].perbarui_tampilan(-1, 0, 0)

func _atur_posisi_label_ronde() -> void:
	# Tepat di bawah TeksDadu dan sejajar tengahnya. TeksDadu tidak selalu di tengah
	# layar (di layar lebar seperti 1600x720 ia bergeser ke kiri), jadi label ini
	# mengikuti TeksDadu, bukan tengah layar.
	if label_ronde == null or not label_ronde.visible or teks_dadu == null:
		return
	var x = teks_dadu.position.x + teks_dadu.size.x * 0.5 - label_ronde.size.x * 0.5
	var y = teks_dadu.position.y + teks_dadu.size.y + 6.0
	if not label_ronde.position.is_equal_approx(Vector2(x, y)):
		label_ronde.position = Vector2(x, y)

func _perbarui_label_ronde() -> void:
	if label_ronde == null or batas_ronde <= 0:
		return
	var r = mini(ronde_sekarang, batas_ronde)
	if r >= batas_ronde:
		label_ronde.text = "[center][color=#ff6644]FINAL ROUND %d/%d[/color][/center]" % [r, batas_ronde]
		if _ronde_spanduk != r:
			_ronde_spanduk = r
			UiDinamis.tampilkan_spanduk(self, "FINAL ROUND!", Color(1.0, 0.45, 0.3))
	else:
		label_ronde.text = "[center]ROUND %d/%d[/center]" % [r, batas_ronde]

# ========================================================
# GANTI 4 FUNGSI DI BAGIAN PALING BAWAH DENGAN BLOK INI
# ========================================================
func update_ui_status():
	# ========================================================
	# TAMBAHAN: DETEKSI UANG KRITIS UNTUK MENGUBAH TEMPO BGM
	# ========================================================
	var ambang_kritis = 600
	var status_kritis_baru = false
	for d in daftar_pemain:
		if d.uang < ambang_kritis: status_kritis_baru = true
	
	if status_kritis_baru != mode_kritis and pemutar_bgm != null:
		mode_kritis = status_kritis_baru
		var tw_pitch = create_tween()
		if mode_kritis:
			# Naikkan tempo 15% jika ada yang hampir bangkrut
			tw_pitch.tween_property(pemutar_bgm, "pitch_scale", 1.15, 2.0).set_trans(Tween.TRANS_SINE)
		else:
			# Kembalikan ke tempo normal jika sudah menabung
			tw_pitch.tween_property(pemutar_bgm, "pitch_scale", 1.0, 2.0).set_trans(Tween.TRANS_SINE)
	# ========================================================

	# Memaksa render ulang agar teks bintang tetap update meski uang tidak berubah
	var semua_sama = true
	for s in range(jumlah_pemain()):
		if daftar_pemain[s].uang != uang_tampil_slot[s]: semua_sama = false
	if semua_sama:
		for s in range(jumlah_pemain()):
			warna_hex_slot[s] = "#ffffff"
		for s in range(jumlah_pemain()):
			_render_uang_tampil(uang_tampil_slot[s], _aktor_dari_slot(s))
		return

	# Animasi uang berjalan, per slot yang angkanya berubah
	for s in range(jumlah_pemain()):
		if daftar_pemain[s].uang == uang_tampil_slot[s]:
			continue
		var tw_lama = tween_uang_slot[s]
		if tw_lama and tw_lama.is_valid(): tw_lama.kill()
		var tw_uang = create_tween()
		tween_uang_slot[s] = tw_uang
		warna_hex_slot[s] = "#44ff44" if daftar_pemain[s].uang > uang_tampil_slot[s] else "#ff4444"
		tw_uang.tween_method(_render_uang_tampil.bind(_aktor_dari_slot(s)), uang_tampil_slot[s], daftar_pemain[s].uang, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var slot_ini = s
		tw_uang.tween_callback(func(): 
			warna_hex_slot[slot_ini] = "#ffffff"
			_render_uang_tampil(daftar_pemain[slot_ini].uang, _aktor_dari_slot(slot_ini))
		)

func _render_uang_tampil(nilai: int, target: String):
	# target = SLOT yang dirender (nama aktornya: "pemain" = slot 0, "musuh" = slot 1, ...).
	# PANEL KIRI ("Your ...") selalu milik pemain DI DEVICE INI (slot_lokal),
	# PANEL KANAN milik lawan. Dulu slot 0 selalu dianggap "Your" -- benar di
	# host & solo, tapi di layar client (slot 1) tertukar.
	var slot = _slot_dari_aktor(target)
	uang_tampil_slot[slot] = nilai
	if jumlah_pemain() > 2:
		_render_hud_banyak_pemain()
		return
	var milik_sendiri = (slot == slot_lokal)
	var awalan = "Your" if milik_sendiri else "Enemy"
	var warna_hex = warna_hex_slot[slot]

	# Fase 4 (A6): nama role berwarna di atas Coins, supaya ketahanan lawan
	# terlihat. DataRole statis + daftar_pemain[s].role langsung -- file ini
	# ada DI BAWAH pemain_role.gd di rantai, jadi tidak lewat fungsi role.
	var baris_role = ""
	var role_slot = daftar_pemain[slot].role
	if role_slot != "":
		baris_role = "[font_size=16][color=#" + DataRole.warna_role(role_slot).to_html(false) + "]" + DataRole.nama_role(role_slot) + "[/color][/font_size]\n"

	var baris_u = awalan + " Coins: [color=" + warna_hex + "]" + str(nilai) + "[/color]"
	var baris_b = awalan + " Stars: ⭐ x " + str(daftar_pemain[slot].bintang)

	# Format daftar permata (Contoh: "Merah, Biru")
	var str_permata = ""
	for p in koleksi_permata_slot[slot]: str_permata += p + " "
	var baris_p = "Gems: " + (str_permata if str_permata != "" else "0")

	var isi = "[center]" + baris_role + baris_u + "\n" + baris_b + "\n[font_size=18][color=#00ffff]" + baris_p + "[/color][/font_size][/center]"
	if milik_sendiri: teks_uang.text = isi
	else: teks_bintang.text = isi

func _render_hud_banyak_pemain() -> void:
	# 3-4 pemain. KIRI: panel besar milik pemain di device ini (isi sama dengan
	# versi 2 pemain + penanda warna). KANAN: daftar ringkas semua lawan, satu
	# baris per pemain; » menandai yang sedang mendapat giliran.
	var s = slot_lokal
	var str_permata = ""
	for p in koleksi_permata_slot[s]: str_permata += p + " "
	# Fase 4 (A6): role berwarna di samping "YOU (Pn)" & di tiap baris lawan.
	var baris_role_s = ""
	if daftar_pemain[s].role != "":
		baris_role_s = "  [color=#" + DataRole.warna_role(daftar_pemain[s].role).to_html(false) + "]" + DataRole.nama_role(daftar_pemain[s].role) + "[/color]"
	teks_uang.text = "[center][font_size=18][color=#" + _warna_slot(s).to_html(false) + "]YOU (P" + str(s + 1) + ")[/color][/font_size]" + baris_role_s + "\n" \
		+ "Your Coins: [color=" + warna_hex_slot[s] + "]" + str(uang_tampil_slot[s]) + "[/color]\n" \
		+ "Your Stars: ⭐ x " + str(daftar_pemain[s].bintang) + "\n" \
		+ "[font_size=18][color=#00ffff]Gems: " + (str_permata if str_permata != "" else "0") + "[/color][/font_size][/center]"
	var slot_giliran = _slot_dari_aktor(giliran_sekarang)
	var baris = []
	for o in range(jumlah_pemain()):
		if o == s:
			continue
		var penanda = "» " if o == slot_giliran else "   "
		var baris_role_o = ""
		if daftar_pemain[o].role != "":
			baris_role_o = "  [color=#" + DataRole.warna_role(daftar_pemain[o].role).to_html(false) + "]" + DataRole.nama_role(daftar_pemain[o].role) + "[/color]"
		baris.append(penanda + "[color=#" + _warna_slot(o).to_html(false) + "][b]P" + str(o + 1) + "[/b][/color]" + baris_role_o + "  " \
			+ "Coins: [color=" + warna_hex_slot[o] + "]" + str(uang_tampil_slot[o]) + "[/color]  " \
			+ "⭐ " + str(daftar_pemain[o].bintang) + "  " \
			+ "[color=#00ffff]Gems: " + str(koleksi_permata_slot[o].size()) + "[/color]")
	teks_bintang.text = "[font_size=19]" + "\n".join(baris) + "[/font_size]"

# ========================================================
# FUNGSI BARU: BERBAGI RUANG JIKA BERADA DI PETAK YANG SAMA
# ========================================================
# Geseran karakter yang berbagi satu petak (urut slot). Dua karakter = serong
# kiri atas & kanan bawah seperti dulu; karakter ke-3/4 mengisi sudut lainnya.
const OFFSET_BERBAGI_PETAK = [Vector3(1.3, 0.0, 1.3), Vector3(-1.3, 0.0, -1.3), Vector3(1.3, 0.0, -1.3), Vector3(-1.3, 0.0, 1.3)]

func atur_posisi_berbagi_petak():
	var tween: Tween = null
	var durasi = 0.3
	
	# Kelompokkan slot per petak tempat mereka berpijak
	var isi_petak = {}
	for s in range(jumlah_pemain()):
		var pos = daftar_pemain[s].posisi_saat_ini
		if not isi_petak.has(pos):
			isi_petak[pos] = []
		isi_petak[pos].append(s)
	
	for s in range(jumlah_pemain()):
		var node = _node_karakter(s)
		if not is_instance_valid(node) or not node.is_inside_tree():
			continue
		var pos = daftar_pemain[s].posisi_saat_ini
		# Ambil koordinat pusat petak; kunci posisi Y agar karakter tidak melayang
		# atau amblas ke lantai
		var tujuan = rute_papan[pos].global_position
		tujuan.y = node.global_position.y
		var kelompok = isi_petak[pos]
		if kelompok.size() > 1:
			# Di petak yang sama: tiap karakter bergeser ke sudutnya sendiri
			tujuan += OFFSET_BERBAGI_PETAK[kelompok.find(s)]
		# Di petak yang berbeda: berdiri tegak persis di tengah petak
		if tween == null:
			tween = create_tween().set_parallel(true)
		tween.tween_property(node, "global_position", tujuan, durasi).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ========================================================
# MESIN PENGGERAK AUDIO & RETENTION ENGINEERING
# ========================================================
func atur_visibilitas_fps(nyala: bool):
	AudioGrafis.atur_visibilitas_fps(self, nyala)

func _munculkan_teks_kerugian(target_model: Node3D, jumlah: int):
	var teks_rugi = Label3D.new()
	teks_rugi.text = "-" + str(jumlah)
	teks_rugi.font_size = 250
	teks_rugi.outline_size = 50
	teks_rugi.modulate = Color(0.7, 0.0, 0.0) # Warna Merah Gelap
	teks_rugi.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	
	get_tree().current_scene.add_child(teks_rugi)
	# Posisikan teks tepat di atas kepala model karakter
	teks_rugi.global_position = target_model.global_position + Vector3(0, 1.5, 0)
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(teks_rugi, "global_position:y", target_model.global_position.y + 4.5, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(teks_rugi, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await tw.finished
	if is_instance_valid(teks_rugi):
		teks_rugi.queue_free()
