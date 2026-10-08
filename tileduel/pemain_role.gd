@abstract
extends "res://pemain_tampilan.gd"
# ========================================================================
# PEMAIN_ROLE.GD (Fase 4 Langkah A)
# ATURAN ROLE DI DALAM PERTANDINGAN: menyiapkan role tiap slot, jebakan yang
# dibawa, hitungan ketahanan/node, syarat pasang jebakan, jarak antar petak,
# kemas/terapkan state role untuk jaringan.
#
# Disisipkan DI ANTARA pemain_tampilan.gd dan pemain_papan.gd (rantai Fase 3):
# pemain_dasar -> pemain_tampilan -> pemain_role -> pemain_papan -> pemain_kartu
# -> pemain_duel -> pemain_jaringan -> pemain.gd
#
# ATURAN RANTAI (Fase 3, tetap berlaku): fungsi di file ini TIDAK BOLEH
# memanggil apa pun yang dideklarasikan di file DI ATASNYA (pemain_papan.gd
# dst) -- hanya @abstract func di pemain_dasar.gd, atau class_name/autoload
# global (DataRole, DataPemain, StatusJaringan, ProfilPemain, AiJebakan),
# boleh dipakai di sini. Teks/siaran kerugian TETAP tugas pemanggil di file
# yang lebih atas -- fungsi di sini hanya menghitung & mencatat statistik.
# @abstract = bagian dari pemain.gd, tidak dipasang sendiri ke node.
# ========================================================================

# Diisi pemain_duel.gd's _mulai_duel() SAAT duel mulai -- SEBELUM buff HP
# sementara jebakan tanah dibersihkan -- supaya keputusan SESUDAH duel (Rock
# Breaker) masih tahu apakah petak yang diperebutkan punya jebakan tanah.
# {"ada": bool, "pemilik": int, "posisi": int}. Dikosongkan lagi setelah hasil
# duel dipakai (lihat pemain_duel.gd _hasil_duel_petak).
var _tanah_saat_duel: Dictionary = {}

# Navigasi papan untuk _jarak_maju / _petak_mundur -- dibangun SEKALI, lazy,
# karena rute_papan baru terisi setelah peta selesai dibangun (bukan saat
# _ready node ini).
var _indeks_petak: Dictionary = {}   # Node3D (petak) -> indeks di rute_papan
var _peta_pendahulu: Dictionary = {} # indeks -> indeks pendahulu (indeks terkecil kalau >1)
var _navigasi_siap: bool = false

# ========================================================
# A2: MENYIAPKAN ROLE SEMUA SLOT
# ========================================================
func _siapkan_role_semua() -> void:
	# Dipanggil _siapkan_peta_dan_mulai (pemain.gd) SETELAH daftar_pemain
	# tersusun penuh (solo & multiplayer) dan mesin_acak sudah siap.
	# Host & client sama-sama menyalin dari StatusJaringan.role_slot (dikirim
	# host lewat rpc_mulai_dari_lobby, sudah lengkap & sah dari _bangun_role_slot,
	# jadi tidak ada undian cadangan yang bisa beda antar-HP). Sesudahnya siaran
	# state (_kemas_role/_terapkan_role) yang menjaga semua HP tetap sama.
	if StatusJaringan.peran_multiplayer == "host" or StatusJaringan.peran_multiplayer == "client":
		_siapkan_role_multiplayer()
	else:
		_siapkan_role_solo()

func _siapkan_role_solo() -> void:
	# D2 (B-d/P5): dipecah 2 putaran -- putaran 1 (role+build SEMUA slot, urutan
	# undian pilih_role_ai PERSIS sama seperti sebelumnya, s=1..N-1 berurutan)
	# lalu putaran 2 (jebakan_dibawa AI, sekarang bisa baca build_lawan
	# SUNGGUHAN semua lawan karena sudah lengkap di putaran 1 -- pilih_role_ai
	# sendiri TIDAK menyentuh RNG di putaran 2, jadi urutan undian tidak berubah).
	var level_pemain = ProfilPemain.level_sekarang()
	var jumlah_jenis = DataRole.slot_jebakan_solo(level_pemain)
	var role0 = ProfilPemain.role_terakhir
	if role0 == "" or not DataRole.ROLE.has(role0):
		role0 = DataRole.ROLE[mesin_acak.randi_range(0, DataRole.ROLE.size() - 1)]
	daftar_pemain[0].role = role0
	daftar_pemain[0].jebakan_dibawa = _jebakan_sah(role0, ProfilPemain.jebakan_role.get(role0, []), jumlah_jenis)
	daftar_pemain[0].build = _build_lv1(role0)
	for s in range(1, jumlah_pemain()):
		var role_ai = AiJebakan.pilih_role_ai(self, s)
		daftar_pemain[s].role = role_ai
		daftar_pemain[s].build = _build_lv1(role_ai)
	for s in range(1, jumlah_pemain()):
		var role_lawan: Array = []
		var build_lawan: Array = []
		for t in range(jumlah_pemain()):
			if t != s:
				role_lawan.append(daftar_pemain[t].role)
				build_lawan.append(daftar_pemain[t].build)
		daftar_pemain[s].jebakan_dibawa = DataRole.jebakan_bawaan_ai(daftar_pemain[s].role, role_lawan, jumlah_jenis, build_lawan)

func _siapkan_role_multiplayer() -> void:
	# HOST: StatusJaringan.role_slot sudah divalidasi layar lobby (A6) --
	# indeksnya sejajar dengan StatusJaringan.jenis_slot / daftar_pemain.
	var jumlah_jenis = DataRole.SLOT_JEBAKAN_MP
	for s in range(jumlah_pemain()):
		var data_slot = {}
		if s < StatusJaringan.role_slot.size() and StatusJaringan.role_slot[s] is Dictionary:
			data_slot = StatusJaringan.role_slot[s]
		var role_s = str(data_slot.get("role", ""))
		if role_s == "" or not DataRole.ROLE.has(role_s):
			role_s = DataRole.ROLE[mesin_acak.randi_range(0, DataRole.ROLE.size() - 1)]
		daftar_pemain[s].role = role_s
		var jebakan_s: Array = data_slot.get("jebakan", [])
		daftar_pemain[s].jebakan_dibawa = _jebakan_sah(role_s, jebakan_s, jumlah_jenis)
		# C2 (B-c, 26-09): build Arena (bukan _build_lv1 lagi) -- host & client
		# menghitung dari StatusJaringan.role_slot yang SAMA (dikirim host lewat
		# rpc_mulai_dari_lobby, sudah divalidasi _bangun_role_slot) -> hasil sama.
		daftar_pemain[s].build = DataRole.build_arena(role_s, {"node": data_slot.get("build", {})})

func _build_lv1(role: String) -> Dictionary:
	# Langkah A: kedua node ketahanan role ini selalu Lv1, gratis (tidak ada
	# SP/level Role sampai Langkah B).
	var b = {}
	for id_node in DataRole.TAHAN_ROLE.get(role, []):
		b[id_node] = 1
	return b

func _jebakan_sah(role: String, dibawa: Array, jumlah_jenis: int) -> Array:
	# role selalu ikut & terkunci; sisanya dari "dibawa" kalau sah (jenis
	# dikenal, tidak dobel); dilengkapi bawaan otomatis kalau kurang/tidak sah.
	var hasil: Array = [role]
	for e in dibawa:
		if typeof(e) == TYPE_STRING and DataRole.ROLE.has(e) and not hasil.has(e) and hasil.size() < jumlah_jenis:
			hasil.append(e)
	if hasil.size() < jumlah_jenis:
		for e in DataRole.jebakan_bawaan_ai(role, [], jumlah_jenis):
			if not hasil.has(e) and hasil.size() < jumlah_jenis:
				hasil.append(e)
	return hasil

# ========================================================
# A2: JEBAKAN & KETAHANAN
# ========================================================
func _jebakan_boleh(slot: int, elemen: String) -> bool:
	if slot < 0 or slot >= jumlah_pemain():
		return false
	var dibawa: Array = daftar_pemain[slot].jebakan_dibawa
	if dibawa.is_empty():
		return true # role belum disiapkan (mis. rig lama) -- perilaku sebelum Fase 4: semua boleh
	return dibawa.has(elemen)

func _lv_node(slot: int, id_node: String) -> int:
	if slot < 0 or slot >= jumlah_pemain():
		return 0
	return int(daftar_pemain[slot].build.get(id_node, 0))

func _punya_ultimate(slot: int, role: String) -> bool:
	# Ultimate (Guard nol level, khusus): true/false di build["ULT_<role>"]
	# (lihat DataRole.build_sah/biaya_build, B-a) -- HANYA berlaku kalau slot
	# itu memang role tsb (Ultimate role lain tidak pernah tersimpan di sana).
	if slot < 0 or slot >= jumlah_pemain() or daftar_pemain[slot].role != role:
		return false
	return bool(daftar_pemain[slot].build.get("ULT_" + role, false))

func _tahan(slot: int, elemen: String) -> int:
	# Level node ketahanan yang menahan JEBAKAN elemen ini untuk slot itu (0 = tidak punya).
	var id_node = DataRole.node_tahan_untuk_elemen(elemen)
	if id_node == "":
		return 0
	return _lv_node(slot, id_node)

func _kurangi_tahan(slot_korban: int, elemen: String, jumlah: int) -> int:
	# Angka SESUDAH potongan ketahanan (>= 0, dibulatkan). Menambah stat
	# tahan_kurangi kalau memang berkurang. TIDAK menampilkan teks/siaran --
	# itu tetap tugas pemanggil (aturan rantai di atas).
	var lv = _tahan(slot_korban, elemen)
	if lv <= 0:
		return jumlah
	var potongan = DataRole.potongan_tahan(lv)
	var hasil = maxi(0, int(round(jumlah * (1.0 - potongan))))
	if hasil < jumlah:
		_tambah_stat(slot_korban, "tahan_kurangi")
	return hasil

func _durasi_gelembung(slot_korban: int) -> int:
	# steady_feet Lv1 = angka TETAP 1 giliran (bukan potongan persen) --
	# lihat tabel node di data_role.gd.
	if _lv_node(slot_korban, "steady_feet") > 0:
		return 1
	return DataRole.DASAR["gelembung"]

# ========================================================
# B-b (14.2/B4): GUARD -- node ketahanan Lv3, sekali per pertandingan per
# ELEMEN: jebakan pertama elemen itu yang mengenai pemain tidak berefek sama
# sekali (jebakannya tetap hilang/dipakai). Dicek PERTAMA di setiap titik
# picu jebakan (pemanggil yang menghapus node jebakan & menampilkan teks
# "GUARD! <node> blocked the <trap>!" -- aturan rantai: di sini cuma syarat +
# pencatatan).
# ========================================================
func _guard_boleh(slot_korban: int, elemen: String) -> bool:
	if slot_korban < 0 or slot_korban >= jumlah_pemain():
		return false
	if _tahan(slot_korban, elemen) < 3:
		return false
	return not bool(daftar_pemain[slot_korban].guard_terpakai.get(elemen, false))

func _pakai_guard(slot_korban: int, elemen: String) -> void:
	daftar_pemain[slot_korban].guard_terpakai[elemen] = true
	_tambah_stat(slot_korban, "tahan_kurangi") # Guard = ketahanan mengurangi jebakan sampai nol (14.5)

# ========================================================
# B-b (K13): GROUNDED -- giliran lumpuh & boleh-Fight-saat-lumpuh dari level
# node milik KORBAN (bukan pemasang jebakan petir). Lv0 (bukan role
# tanah/angin) = perilaku dasar Langkah A (2 giliran, TIDAK boleh Fight).
# ========================================================
func _paralisis_untuk(slot_korban: int) -> Dictionary:
	var lv = _lv_node(slot_korban, "grounded")
	if lv <= 0:
		return {"sisa": DataRole.DASAR["paralisis"], "boleh_fight": false}
	var info: Dictionary = DataRole.GROUNDED_LV[clampi(lv, 1, 3)]
	return {"sisa": int(info["sisa_paralisis"]), "boleh_fight": bool(info["boleh_fight_lumpuh"])}

func _boleh_fight_saat_lumpuh(slot: int) -> bool:
	return bool(_paralisis_untuk(slot)["boleh_fight"])

# ========================================================
# B-b (14.2): SATU sumber angka jebakan milik SLOT_PEMASANG -- level 0 (node
# belum dibeli) = angka DASAR Langkah A, sama persis sampai build sungguhan
# tersambung (B-c jaringan/lobby, B-d AI, B-e layar pohon). Dipakai efek host
# (B4) DAN otak AI (B-d) supaya keduanya selalu sinkron dengan satu angka.
# ========================================================
func _angka_jebakan(slot_pemasang: int, elemen: String) -> Dictionary:
	match elemen:
		"api":
			var lv_bakar = _lv_node(slot_pemasang, "hot_flames")
			var lv_pajak = _lv_node(slot_pemasang, "fire_tax")
			var lv_lama = _lv_node(slot_pemasang, "long_burn")
			return {
				"bakar_per_giliran": int(DataRole.NODE_LV["hot_flames"][lv_bakar]) if lv_bakar > 0 else int(DataRole.DASAR["bakar_per_giliran"]),
				"fire_tax": float(DataRole.NODE_LV["fire_tax"][lv_pajak]) if lv_pajak > 0 else 0.0,
				"bakar_giliran": int(DataRole.NODE_LV["long_burn"][lv_lama]) if lv_lama > 0 else int(DataRole.DASAR["bakar_giliran"]),
				"larang_jebakan": lv_lama >= 2,
				"phoenix": _punya_ultimate(slot_pemasang, "api"),
			}
		"air":
			var lv_arus = _lv_node(slot_pemasang, "rapid_current")
			var lv_tide = _lv_node(slot_pemasang, "high_tide")
			var lv_beku = _lv_node(slot_pemasang, "frozen_bubble")
			return {
				"mundur_minimal": int(DataRole.NODE_LV["rapid_current"][lv_arus]) if lv_arus > 0 else 0,
				"peluang_tide": float(DataRole.NODE_LV["high_tide"][lv_tide]) if lv_tide > 0 else 0.0,
				"tide_koin": lv_tide >= 3,
				"kunci_kartu": int(DataRole.NODE_LV["frozen_bubble"][lv_beku]) if lv_beku > 0 else 0,
				"low_roll_beku": lv_beku >= 3,
				"tsunami": _punya_ultimate(slot_pemasang, "air"),
			}
		"tanah":
			var lv_batu = _lv_node(slot_pemasang, "hard_rock")
			var lv_duri = _lv_node(slot_pemasang, "stone_thorns")
			var lv_benteng = _lv_node(slot_pemasang, "fortress")
			return {
				"sisa_duel": int(DataRole.NODE_LV["hard_rock"][lv_batu]) if lv_batu > 0 else 1,
				"hp_tambahan_awal": 2 if lv_batu >= 3 else 0,
				"pengali_kalah": float(DataRole.NODE_LV["stone_thorns"][lv_duri]) if lv_duri > 0 else float(DataRole.DASAR["pengali_kalah_duel"]),
				"tahan_serangan": int(DataRole.NODE_LV["fortress"][lv_benteng]) if lv_benteng > 0 else 0,
				"sacred_ground": _punya_ultimate(slot_pemasang, "tanah"),
			}
		"petir":
			var lv_setrum = _lv_node(slot_pemasang, "shock")
			var lv_rantai = _lv_node(slot_pemasang, "chain_lightning")
			var lv_magnet = _lv_node(slot_pemasang, "card_magnet")
			return {
				"koin_hilang": int(DataRole.NODE_LV["shock"][lv_setrum]) if lv_setrum > 0 else 0,
				"jarak_rantai": int(DataRole.NODE_LV["chain_lightning"][lv_rantai]) if lv_rantai > 0 else -1,
				"peluang_magnet": float(DataRole.NODE_LV["card_magnet"][lv_magnet]) if lv_magnet > 0 else 0.0,
				"stealth_charge": _punya_ultimate(slot_pemasang, "petir"),
			}
		"angin":
			var lv_rampas = _lv_node(slot_pemasang, "strong_wind")
			var lv_homing = _lv_node(slot_pemasang, "homing_wind")
			var lv_puting = _lv_node(slot_pemasang, "whirlwind")
			return {
				"persen_rampas": float(DataRole.NODE_LV["strong_wind"][lv_rampas]) if lv_rampas > 0 else float(DataRole.DASAR["rampas_angin"]),
				"bagian_homing": float(DataRole.NODE_LV["homing_wind"][lv_homing]) if lv_homing > 0 else 0.0,
				"langkah_hilang": int(DataRole.NODE_LV["whirlwind"][lv_puting]) if lv_puting > 0 else 0,
				"tornado": _punya_ultimate(slot_pemasang, "angin"),
			}
	return {}

var _jarak_start_cache: Dictionary = {}   # indeks petak -> jarak (BFS) dari START (indeks 0)
var _jarak_start_siap: bool = false

func _pastikan_jarak_start_siap() -> void:
	if _jarak_start_siap or rute_papan.is_empty():
		return
	_pastikan_navigasi_siap()
	_jarak_start_cache.clear()
	_jarak_start_cache[0] = 0
	var lapis: Array = [0]
	var jarak = 0
	while not lapis.is_empty():
		jarak += 1
		var lapis_berikut: Array = []
		for idx in lapis:
			for n in rute_papan[idx].referensi_node_selanjutnya:
				var idx_n = _indeks_petak.get(n, -1)
				if idx_n == -1 or _jarak_start_cache.has(idx_n):
					continue
				_jarak_start_cache[idx_n] = jarak
				lapis_berikut.append(idx_n)
		lapis = lapis_berikut
	_jarak_start_siap = true

func _jarak_dari_start(idx: int) -> int:
	_pastikan_jarak_start_siap()
	return int(_jarak_start_cache.get(idx, 0))

func _terjauh_dari_start(indeks: Array) -> int:
	var terbaik = indeks[0]
	var terbaik_jarak = _jarak_dari_start(terbaik)
	for i in indeks:
		var j = _jarak_dari_start(i)
		if j > terbaik_jarak:
			terbaik_jarak = j
			terbaik = i
	return terbaik

# ========================================================
# B-b (B4): kandidat petak jatuh jebakan air -- rapid_current (level PEMASANG)
# menaikkan jarak-dari-START minimal petak jatuh (Lv0 = 0, SEMUA petak tetap
# kandidat, perilaku Langkah A acak murni); steady_feet Lv2 (KORBAN) lalu
# MENYEMPITKAN ke <= 6 petak dari posisi jebakan (ketahanan menang kalau
# bertentangan); kosong -> petak sah terjauh. Dipanggil jebakan_air.gd
# (bukan bagian rantai, jadi aturan panggil-ke-atas tidak berlaku di sana).
# ========================================================
func _kandidat_petak_jatuh(slot_korban: int, idx_jebakan: int, slot_pemasang: int) -> Array:
	_pastikan_jarak_start_siap()
	var total = rute_papan.size()
	if total <= 0:
		return [0]
	var n_min = int(_angka_jebakan(slot_pemasang, "air").get("mundur_minimal", 0))
	var semua: Array = range(total)
	# Lv0 (belum beli rapid_current, SELALU begini untuk sekarang) -- TIDAK
	# menyempitkan sama sekali, supaya kandidatnya persis "semua petak" seperti
	# pilih_petak_jatuh Langkah A yang lama (bukan cuma "n_min=0" dipakai di
	# rumus jarak, yang tetap membuang petak LEBIH DEKAT ke START daripada
	# korban -- itu bukan perilaku lama).
	var kandidat: Array = semua
	if n_min > 0:
		var jarak_korban = _jarak_dari_start(idx_jebakan)
		var sempit_awal: Array = []
		for i in semua:
			if _jarak_dari_start(i) >= jarak_korban + n_min:
				sempit_awal.append(i)
		kandidat = sempit_awal if not sempit_awal.is_empty() else [_terjauh_dari_start(semua)]
	if _lv_node(slot_korban, "steady_feet") >= 2:
		var sempit: Array = []
		for i in kandidat:
			var jm = _jarak_maju(idx_jebakan, i, total)
			if jm >= 0 and jm <= 6:
				sempit.append(i)
		if not sempit.is_empty():
			return sempit
		return [_terjauh_dari_start(kandidat)]
	return kandidat

func _stone_thorns_p_di(posisi: int) -> float:
	# Pengali dasar Stone Thorns (K2: hanya kalau petak ini punya jebakan tanah
	# MILIK PEMAIN ROLE TANAH dengan node itu) -- dipakai teks "Fight (Risk:
	# ...)" SEBELUM duel (posisi tile langsung, pemain.gd) dan _pengali_kalah_duel
	# SAAT duel dimulai (lewat _tanah_saat_duel, di bawah).
	if posisi < 0 or posisi >= rute_papan.size():
		return DataRole.DASAR["pengali_kalah_duel"]
	var jebakan = rute_papan[posisi].get_node_or_null("JebakanTanah")
	if jebakan == null or not jebakan.aktif or jebakan.pemilik < 0 or daftar_pemain[jebakan.pemilik].role != "tanah":
		return DataRole.DASAR["pengali_kalah_duel"]
	var lv_duri = _lv_node(jebakan.pemilik, "stone_thorns")
	if lv_duri <= 0:
		return DataRole.DASAR["pengali_kalah_duel"]
	return DataRole.NODE_LV["stone_thorns"][lv_duri]

func _pengali_kalah_duel(slot_penyerang: int, posisi: int) -> float:
	# Dipakai _hasil_duel_petak (pemain_duel.gd) sesudah duel dimulai. Rock
	# Breaker (K14) hanya berlaku kalau petak yang diperebutkan memang punya
	# jebakan tanah SAAT DUEL DIMULAI (temuan 9, _tanah_saat_duel).
	var lv_rock_breaker = _lv_node(slot_penyerang, "rock_breaker")
	var ada_tanah = bool(_tanah_saat_duel.get("ada", false)) and int(_tanah_saat_duel.get("posisi", -1)) == posisi
	var stone_thorns_p = DataRole.DASAR["pengali_kalah_duel"]
	if ada_tanah:
		var pemilik_tanah = int(_tanah_saat_duel.get("pemilik", -1))
		if pemilik_tanah >= 0 and daftar_pemain[pemilik_tanah].role == "tanah":
			var lv_duri = _lv_node(pemilik_tanah, "stone_thorns")
			if lv_duri > 0:
				stone_thorns_p = DataRole.NODE_LV["stone_thorns"][lv_duri]
	var hasil = DataRole.pengali_kalah_duel(lv_rock_breaker, ada_tanah, stone_thorns_p)
	# Bagian 5 (#121): Rock Breaker Lv2/3 (potongan_kalah_duel > 0, lihat
	# ROCK_BREAKER_LV) benar2 memotong pengali kalah duel dibandingkan
	# stone_thorns_p -- dicatat HANYA kalau memang berubah (14.5; Lv1 = 0,0,
	# tidak pernah masuk sini -- efeknya sendiri sudah dicatat pemain_duel.gd).
	if hasil < stone_thorns_p:
		_tambah_stat(slot_penyerang, "tahan_kurangi")
	return hasil

# ========================================================
# B-b bagian 4b: FORTRESS & SACRED GROUND
# ========================================================
func _sacred_tersedia(slot: int) -> bool:
	# Sacred Ground (Ultimate Tanah): jebakan tanah PERTAMA yang dipasang
	# pemain ini gratis (tidak makan bintang) & tidak habis oleh duel (field
	# "sacred" jebakan_tanah.gd, dibaca _selesaikan_tanah_setelah_duel) --
	# sekali per pertandingan (daftar_pemain[slot].sacred_terpakai).
	if slot < 0 or slot >= jumlah_pemain():
		return false
	return _punya_ultimate(slot, "tanah") and not daftar_pemain[slot].sacred_terpakai

func _benteng_aktif(petak: int) -> bool:
	# D2 (B-d, P3): versi MURNI (tanpa efek samping) dari syarat Fortress --
	# PERSIS sama syaratnya dengan _benteng_menahan di bawah, TAPI tidak
	# mengurangi sisa_tahan_serangan. Dipakai ai_musuh.gd (D5) untuk melihat
	# apakah petak "Protected" (label sama seperti UI) sebelum memutuskan
	# target serangan jarak jauh, TANPA ikut memakai jatah tahan Fortress --
	# jatah itu hanya boleh berkurang lewat serangan SUNGGUHAN (_benteng_menahan).
	if petak < 0 or petak >= rute_papan.size():
		return false
	var jebakan = rute_papan[petak].get_node_or_null("JebakanTanah")
	if jebakan == null or not jebakan.aktif or jebakan.pemilik != pemilik_petak[petak]:
		return false
	return jebakan.sisa_tahan_serangan > 0

func _benteng_menahan(petak: int) -> bool:
	# Fortress (node ketahanan MILIK PEMASANG jebakan tanah, bukan korban --
	# beda dari Guard/node_tahan yang milik korban): jebakan tanah aktif milik
	# PEMILIK PETAK ITU SENDIRI bisa menahan N serangan jarak jauh (Lv1=1,
	# Lv2=2, Lv3=selamanya) sebelum nyawa_petak berkurang sama sekali. Dipanggil
	# pemain_papan.gd::eksekusi_serangan DAN ai_musuh.gd (serangan jarak jauh
	# AI), SEBELUM nyawa_petak -= 1. Setiap serangan yang tertahan mengurangi
	# sisa_tahan_serangan 1 (kecuali Lv3/Sacred = 999, praktis tidak pernah habis).
	# D2 (B-d): syarat dipindah ke _benteng_aktif (murni) -- di sini HANYA
	# tambahan efek samping (kurangi jatah) sesudah syaratnya terpenuhi.
	if not _benteng_aktif(petak):
		return false
	var jebakan = rute_papan[petak].get_node_or_null("JebakanTanah")
	jebakan.sisa_tahan_serangan -= 1
	return true

# ========================================================
# A2/A3: SYARAT PASANG JEBAKAN
# ========================================================
func _boleh_pasang_jebakan_di(slot: int, gratis: bool = false) -> bool:
	# Syarat SAMA PERSIS dengan tombol Set Trap sekarang (periksa_status_petak,
	# pemain.gd): bukan petak START, belum ada jebakan APA PUN di petak itu,
	# tidak di gelembung, tidak lumpuh di fase akhir, bukan petak khusus di
	# fase akhir, BUKAN fase konfrontasi/duel, + bintang >= 1. Satu sumber
	# kebenaran dipakai menu manusia (A3), validasi host, dan AI (A5).
	# gratis=true (bagian 4b, Sacred Ground): lewati syarat bintang >= 1 --
	# dipakai HANYA lewat _pasang_jebakan saat _sacred_tersedia(slot) true.
	if slot < 0 or slot >= jumlah_pemain():
		return false
	if fase_giliran == "konfrontasi" or fase_giliran == "duel_berlangsung":
		return false
	var data = daftar_pemain[slot]
	if not gratis and data.bintang < 1:
		return false
	var posisi = data.posisi_saat_ini
	if posisi < 0 or posisi >= rute_papan.size():
		return false
	if posisi == 0:
		return false
	var petak = rute_papan[posisi]
	if petak.has_node("JebakanAir") or petak.has_node("JebakanApi") or petak.has_node("JebakanAngin") \
			or petak.has_node("JebakanPetir") or petak.has_node("JebakanTanah"):
		return false
	if data.sisa_gelembung > 0:
		return false
	if data.bakar_larang_jebakan and data.sisa_bakar > 0: # B-b (B4): long_burn Lv2/3
		return false
	if fase_giliran == "akhir":
		if data.sisa_paralisis > 0:
			return false
		var is_petak_khusus = petak.referensi_node_selanjutnya.size() > 1 \
			or petak.get("is_petak_permata") or petak.get("is_petak_kartu") or petak.get("is_start_point")
		if is_petak_khusus:
			return false
	return true

func _petak_kosong_untuk_jebakan() -> Array:
	# B-b (B4): daftar SEMUA petak kosong yang sah menampung jebakan APA PUN --
	# dipakai Tornado (Ultimate Angin) memindahkan jebakannya sendiri. Aturan
	# posisi SAMA dengan _boleh_pasang_jebakan_di (bukan petak START, belum
	# ada jebakan APA PUN di petak itu) TANPA syarat milik pemain yang sedang
	# bergiliran -- ini bukan pemasangan lewat menu manusia.
	var hasil: Array = []
	for i in range(1, rute_papan.size()):
		var petak = rute_papan[i]
		if petak.has_node("JebakanAir") or petak.has_node("JebakanApi") or petak.has_node("JebakanAngin") \
				or petak.has_node("JebakanPetir") or petak.has_node("JebakanTanah"):
			continue
		hasil.append(i)
	return hasil

func _boleh_tanah_di(slot: int) -> bool:
	# K3: jebakan tanah hanya boleh dipasang di petak milik SENDIRI.
	if slot < 0 or slot >= jumlah_pemain():
		return false
	var posisi = daftar_pemain[slot].posisi_saat_ini
	if posisi < 0 or posisi >= pemilik_petak.size():
		return false
	return pemilik_petak[posisi] == slot

# ========================================================
# A2: JARAK ANTAR PETAK (dipakai AI di A5; node gerak Langkah B)
# ========================================================
func _pastikan_navigasi_siap() -> void:
	if _navigasi_siap or rute_papan.is_empty():
		return
	_indeks_petak.clear()
	for i in range(rute_papan.size()):
		_indeks_petak[rute_papan[i]] = i
	_peta_pendahulu.clear()
	for i in range(rute_papan.size()):
		for n in rute_papan[i].referensi_node_selanjutnya:
			var idx_n = _indeks_petak.get(n, -1)
			if idx_n == -1:
				continue
			if not _peta_pendahulu.has(idx_n):
				_peta_pendahulu[idx_n] = i
			else:
				# >1 pendahulu (petak persimpangan) -- pilih indeks TERKECIL.
				_peta_pendahulu[idx_n] = mini(int(_peta_pendahulu[idx_n]), i)
	_navigasi_siap = true

func _jarak_maju(dari: int, ke: int, maks: int = 12) -> int:
	# BFS maju lewat referensi_node_selanjutnya (bisa bercabang). -1 kalau
	# lebih dari "maks" langkah atau tidak terjangkau dalam batas itu.
	_pastikan_navigasi_siap()
	if dari == ke:
		return 0
	if dari < 0 or dari >= rute_papan.size() or ke < 0 or ke >= rute_papan.size():
		return -1
	var dikunjungi = {dari: true}
	var lapis: Array = [dari]
	var jarak = 0
	while not lapis.is_empty() and jarak < maks:
		jarak += 1
		var lapis_berikut: Array = []
		for idx in lapis:
			for n in rute_papan[idx].referensi_node_selanjutnya:
				var idx_n = _indeks_petak.get(n, -1)
				if idx_n == -1 or dikunjungi.has(idx_n):
					continue
				if idx_n == ke:
					return jarak
				dikunjungi[idx_n] = true
				lapis_berikut.append(idx_n)
		lapis = lapis_berikut
	return -1

func _petak_mundur(dari: int, n: int) -> int:
	# n petak ke BELAKANG lewat peta pendahulu (>1 pendahulu -> indeks terkecil).
	# Berhenti kalau sudah tidak ada pendahulu lagi (mis. dekat Start).
	_pastikan_navigasi_siap()
	var idx = dari
	for i in range(n):
		if not _peta_pendahulu.has(idx):
			return idx
		idx = int(_peta_pendahulu[idx])
	return idx

# ========================================================
# A2/bagian 7: KEMAS & TERAPKAN STATE ROLE (jaringan)
# ========================================================
func _kemas_role() -> Dictionary:
	var hasil = {}
	for s in range(jumlah_pemain()):
		var d = daftar_pemain[s]
		hasil[s] = {
			"role": d.role, "jebakan_dibawa": d.jebakan_dibawa.duplicate(), "build": d.build.duplicate(),
			# C3 (B-c, 26-09): 7 field data_pemain.gd Langkah B yang efeknya SUDAH
			# aktif sejak B-b (Guard, Sacred Ground, fire_tax/long_burn, frozen_bubble)
			# -- WAJIB ikut siaran supaya client (teks/tombol) & host baru (migrasi)/
			# "lanjut sendiri" tetap benar, bukan cuma nilai bawaan _init().
			"guard_terpakai": d.guard_terpakai.duplicate(),
			"sacred_terpakai": d.sacred_terpakai,
			"bakar_per_giliran": d.bakar_per_giliran,
			"bakar_pemilik": d.bakar_pemilik,
			"bakar_larang_jebakan": d.bakar_larang_jebakan,
			"kunci_kartu": d.kunci_kartu,
			"low_roll_bubble": d.low_roll_bubble,
		}
	return hasil

func _terapkan_role(data: Dictionary) -> void:
	for kunci in data:
		var idx = int(kunci)
		if idx < 0 or idx >= jumlah_pemain():
			continue
		var info = data[kunci]
		if not (info is Dictionary):
			continue
		var d = daftar_pemain[idx]
		d.role = str(info.get("role", d.role))
		if info.has("jebakan_dibawa"):
			d.jebakan_dibawa = info["jebakan_dibawa"]
		if info.has("build"):
			d.build = info["build"]
		# C3 (B-c, 26-09): baca dengan .get(..., nilai_lama) -- jaga-jaga kalau
		# field ini belum ada di data yang diterima (aman untuk masa depan).
		# migrasi_host.gd sendiri TIDAK menyentuh field ini sama sekali (cuma
		# urus jaringan, lihat komentar file itu) -- host baru cukup memakai
		# daftar_pemain miliknya sendiri, sudah lengkap dari _terapkan_role
		# terakhir SEBELUM host lama putus.
		if info.has("guard_terpakai"):
			d.guard_terpakai = info["guard_terpakai"]
		d.sacred_terpakai = bool(info.get("sacred_terpakai", d.sacred_terpakai))
		d.bakar_per_giliran = int(info.get("bakar_per_giliran", d.bakar_per_giliran))
		d.bakar_pemilik = int(info.get("bakar_pemilik", d.bakar_pemilik))
		d.bakar_larang_jebakan = bool(info.get("bakar_larang_jebakan", d.bakar_larang_jebakan))
		d.kunci_kartu = int(info.get("kunci_kartu", d.kunci_kartu))
		d.low_roll_bubble = bool(info.get("low_roll_bubble", d.low_roll_bubble))
