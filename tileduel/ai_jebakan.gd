class_name AiJebakan
extends RefCounted
## Fase 4 (A5): otak jebakan AI -- dipisah dari ai_musuh.gd, sama seperti
## AiMusuh dulu dipisah dari pemain.gd (Fase 2, pemecahan file). Static,
## semua fungsi menerima main_node & slot supaya AI bisa bermain di slot mana
## pun (sama seperti AiMusuh -- lihat komentar di sana).
##
## Dua tanggung jawab (rencana bagian 6):
## - pilih_role_ai: dipanggil SEKALI di awal pertandingan SOLO (pemain_role.gd
##   _siapkan_role_solo) untuk memberi tiap slot AI role-nya.
## - pertimbangkan: dipanggil di akhir tiap giliran AI (ai_musuh.gd
##   logika_ai_musuh_setelah_jalan) untuk memutuskan pasang jebakan atau tidak,
##   lewat _pasang_jebakan(slot, elemen) -- fungsi inti yang sama dengan
##   handler tombol manusia (temuan 8), BUKAN handler tombol itu sendiri.

# Distribusi standar DUA dadu (2d6): jumlah cara mendapat tiap total 2-12 dari
# 36 kombinasi. Dipakai _peluang_lewat saat mode_rolet_double aktif (Quick
# Match / Peta Pantai) -- rencana bagian 6: "dadu 2-12 / Quick: hitung dari
# dua dadu". Sengaja BEDA dari distribusi rata mesin_acak.randi_range(2,12)
# yang sungguhan dipakai lempar_dadu() -- ini cuma kiraan AI, tidak perlu
# sama persis dengan RNG sungguhan.
const HITUNG_2D6 := {2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6, 8: 5, 9: 4, 10: 3, 11: 2, 12: 1}

# Nilai minimal supaya AI mau memasang jebakan (bagian 6 langkah 4). Angka
# awal -- disetel Opus di uji keseimbangan (K11 / U3, target: AI memasang
# 2-6 jebakan per Quick 2 pemain).
const AMBANG_NILAI := 50.0 # U3: 80 -> 50 (80 = 1,3 jebakan/AI/Quick 2P, di bawah target)
# Peluang AI benar-benar memasang walau nilainya cukup (1-100, mesin_acak) --
# supaya AI tidak SELALU memasang begitu nilainya lewat ambang.
const AMBANG_PELUANG := 80 # U3: 70 -> 80
# D4 (B-d/K17a, 26-09): NILAI_PETIR_LUMPUH (150, flat) DIHAPUS -- diganti 2
# angka level-sensitif: dasar BERHENTI selalu kena (petir tetap menghentikan
# gerakan korban meski Grounded tinggi) + tambahan PER GILIRAN sisa lumpuh
# (GROUNDED_LV: Lv0 sisa=2 giliran -> 75+75x1=150 SAMA seperti dulu; Lv1/2/3
# sisa=1 giliran -> 75+75x0=75, separuh, sesuai T4/K13).
const NILAI_PETIR_BERHENTI := 75.0
const NILAI_PETIR_LEWAT_GILIRAN := 75.0
# Nilai korban air per giliran melayang di gelembung (tidak beraksi, tidak dapat gaji).
const NILAI_GELEMBUNG_PER_GILIRAN := 75.0
# Nilai jebakan tanah = denda petak x ini (bagian 6 langkah 3).
const FAKTOR_NILAI_TANAH := 0.5
# K18(a): Sacred Ground AI -- prioritas #1 hanya kalau menara petak >= level
# ini (cegah T5, Sacred terbuang di petak Lv0 murah).
const AMBANG_MENARA_SACRED := 1

static func pilih_role_ai(main_node: Node, slot: int) -> String:
	# Solo (pemain_role.gd _siapkan_role_solo): acak dengan mesin_acak,
	# utamakan role yang BELUM dipakai slot lain (role boleh kembar kalau
	# semua sudah kepakai). Rig keseimbangan (U3) TIDAK memakai fungsi ini --
	# role diberikan langsung lewat argumen rig, supaya tidak bergantung pada
	# mesin_acak yang baru diberi benih sesudah START (rencana bagian 9 U3).
	var dipakai := {}
	for s in range(main_node.jumlah_pemain()):
		if s == slot:
			continue
		var r = main_node.daftar_pemain[s].role
		if r != "":
			dipakai[r] = true
	var belum_dipakai: Array = DataRole.ROLE.filter(func(r): return not dipakai.has(r))
	var kumpulan: Array = belum_dipakai if belum_dipakai.size() > 0 else DataRole.ROLE
	return kumpulan[main_node.mesin_acak.randi_range(0, kumpulan.size() - 1)]

static func _peluang_lewat(main_node: Node, lawan: int, jarak: int) -> float:
	# Peluang lemparan dadu SLOT LAWAN >= jarak (bagian 6 langkah 2). Jebakan
	# air & petir menghentikan korban di tengah jalan juga, jadi rumus yang
	# SAMA dipakai untuk keempat jenis (api/air/angin/petir) -- "cukup lewat".
	if jarak <= 0:
		return 1.0
	var tipe: String = main_node.tipe_dadu_slot[lawan]
	if tipe == "rendah":
		# LOW ROLL: undian rata 1-3.
		if jarak > 3:
			return 0.0
		return float(4 - jarak) / 3.0
	if tipe == "tinggi":
		# HIGH ROLL: undian rata 10-12.
		if jarak > 12:
			return 0.0
		if jarak <= 10:
			return 1.0
		return float(13 - jarak) / 3.0
	if main_node.mode_rolet_double:
		# Dadu 2-12 (Quick Match / Peta Pantai): dihitung dari DUA dadu.
		if jarak > 12:
			return 0.0
		if jarak <= 2:
			return 1.0
		var total := 0
		for s in range(jarak, 13):
			total += HITUNG_2D6[s]
		return float(total) / 36.0
	# Dadu biasa 1-6.
	if jarak > 6:
		return 0.0
	if jarak <= 1:
		return 1.0
	return float(7 - jarak) / 6.0

static func _denda_petak(main_node: Node, posisi: int) -> int:
	# Denda dasar petak ini menurut level menaranya -- pola yang sama dipakai
	# di beberapa tempat lain (pemain.gd, pemain_tampilan.gd, ai_musuh.gd).
	if posisi < 0 or posisi >= main_node.level_menara_petak.size():
		return 100
	if main_node.level_menara_petak[posisi] == 1:
		return 300
	if main_node.level_menara_petak[posisi] == 2:
		return 600
	return 100

static func _nilai_korban(main_node: Node, slot: int, lawan: int, elemen: String, posisi: int) -> float:
	# D4 (B-d/K17a, 26-09): nilai SATU korban untuk api/angin/air/petir lewat
	# MEKANIK ASLI yang sama dengan efeknya -- bukan potongan flat lama. Guard
	# (node ketahanan Lv3 korban) belum terpakai -> korban KEBAL TOTAL (jebakan
	# akan dibatalkan Guard), SAMA untuk semua elemen -- dicek PALING AWAL.
	if main_node._guard_boleh(lawan, elemen):
		return 0.0
	match elemen:
		"api":
			var nilai = float(DataRole.DASAR["bakar_per_giliran"] * DataRole.DASAR["bakar_giliran"])
			return nilai * (1.0 - DataRole.potongan_tahan(main_node._tahan(lawan, "api")))
		"angin":
			var nilai = DataRole.DASAR["rampas_angin"] * main_node.daftar_pemain[lawan].uang
			return nilai * (1.0 - DataRole.potongan_tahan(main_node._tahan(lawan, "angin")))
		"air":
			# Steady Feet sudah masuk lewat _durasi_gelembung (angka TETAP 1
			# giliran di Lv1+, bukan potongan persen) -- tidak ada potongan lain.
			return NILAI_GELEMBUNG_PER_GILIRAN * main_node._durasi_gelembung(lawan)
		"petir":
			var info = main_node._paralisis_untuk(lawan)
			var sisa = int(info["sisa"])
			var nilai = NILAI_PETIR_BERHENTI + NILAI_PETIR_LEWAT_GILIRAN * float(sisa - 1)
			if main_node.pemilik_petak[posisi] == slot:
				# Tambahan denda petak HANYA kalau jebakan di petak SENDIRI --
				# dipotong separuh kalau Grounded korban Lv2+ (boleh Fight walau
				# lumpuh, K13 -- jebakan tidak lagi mencegah serangan balik penuh).
				var faktor_denda = 0.5 if bool(info["boleh_fight"]) else 1.0
				nilai += float(_denda_petak(main_node, posisi)) * faktor_denda
			return nilai
	return 0.0

static func _nilai_tanah(main_node: Node, slot: int, posisi: int) -> float:
	# D4 (B-d/K17a): nilai jebakan tanah dirata-rata per lawan (bukan sekali
	# flat seperti dulu) -- base SAMA (denda petak x FAKTOR_NILAI_TANAH),
	# didiskon per lawan pakai 2 mekanik asli Rock Breaker korban:
	# 1) bonus HP (hitung_bonus_hp, jebakan_tanah.gd) punya peluang GAGAL 50%
	#    kalau Rock Breaker korban >=1 (ROCK_BREAKER_LV, SEMUA level) -> nilai
	#    harapan x0,5 (K17a "bonus HP x(1-0,5)").
	# 2) pengali kalah duel (stone_thorns AI sendiri) dipotong Rock Breaker
	#    Lv2/3 korban lewat DataRole.pengali_kalah_duel yang SUNGGUHAN dipakai
	#    duel -- dirasiokan ke pengali PENUH AI (rasio 1,0 kalau korban RB<2).
	# Guard Rock Breaker korban belum terpakai -> kebal total dari korban itu.
	# CATATAN implementasi (Sonnet, di luar rumus harfiah 14.16 -- tinjau lagi
	# B-f/U9): dirata-rata (BUKAN dijumlah) antar lawan supaya nilai satu
	# petak tidak melonjak hanya karena jumlah pemain lebih banyak -- beda dari
	# api/angin/petir/air yang memang menjumlah peluang independen tiap lawan
	# lewat lintasan papan (tanah tidak punya "peluang lewat", cuma siapa yang
	# BISA menyerang petak ini kelak).
	var base = float(_denda_petak(main_node, posisi)) * FAKTOR_NILAI_TANAH
	var lv_duri_ai = main_node._lv_node(slot, "stone_thorns")
	var stone_thorns_ai: float = float(DataRole.NODE_LV["stone_thorns"][lv_duri_ai]) if lv_duri_ai > 0 else float(DataRole.DASAR["pengali_kalah_duel"])
	var total := 0.0
	var jumlah_lawan := 0
	for lawan in range(main_node.jumlah_pemain()):
		if lawan == slot:
			continue
		jumlah_lawan += 1
		if main_node._guard_boleh(lawan, "tanah"):
			continue
		var lv_rb = main_node._tahan(lawan, "tanah")
		var faktor_hp = 0.5 if lv_rb >= 1 else 1.0
		var pengali = DataRole.pengali_kalah_duel(lv_rb, true, stone_thorns_ai)
		var faktor_pengali = pengali / stone_thorns_ai
		total += base * faktor_hp * faktor_pengali
	if jumlah_lawan <= 0:
		return base
	return total / float(jumlah_lawan)

static func _sacred_layak(main_node: Node, slot: int) -> bool:
	# K18(a): Sacred Ground -- prioritas #1, TANPA gerbang bintang & TANPA
	# undian mesin_acak, HANYA kalau syarat pasang tanah biasa terpenuhi DAN
	# menara petak ini >= AMBANG_MENARA_SACRED (cegah T5, Sacred terbuang di
	# petak Lv0 murah -- lebih baik ditahan sampai petak bermenara).
	if not main_node._sacred_tersedia(slot):
		return false
	if not main_node._jebakan_boleh(slot, "tanah"):
		return false
	if not main_node._boleh_tanah_di(slot):
		return false
	if not main_node._boleh_pasang_jebakan_di(slot, true):
		return false
	var posisi = main_node.daftar_pemain[slot].posisi_saat_ini
	if posisi < 0 or posisi >= main_node.level_menara_petak.size():
		return false
	return main_node.level_menara_petak[posisi] >= AMBANG_MENARA_SACRED

static func _pilih_elemen_biasa(main_node: Node, slot: int) -> String:
	# Isi lama pertimbangkan (blok 107-179 sebelum B-d) dipindah ke sini, nilai
	# per elemen diganti _nilai_korban/_nilai_tanah (K17a) -- gerbang bintang
	# TETAP di pertimbangkan (dicek SEBELUM memanggil fungsi ini). K18(a):
	# selama Sacred masih tersedia, tanah TIDAK dipilih lewat jalur ini sama
	# sekali (cegah T5) -- _sacred_layak yang menanganinya kalau memang layak.
	var data = main_node.daftar_pemain[slot]
	var posisi = data.posisi_saat_ini
	var elemen_terbaik := ""
	var nilai_terbaik := 0.0
	var sacred_tersedia: bool = main_node._sacred_tersedia(slot) # D4: tipe eksplisit -- ":=" polos lewat referensi Node generik kena "cannot infer type"
	for elemen in data.jebakan_dibawa:
		if not main_node._jebakan_boleh(slot, elemen):
			continue
		var nilai := 0.0
		if elemen == "tanah":
			if sacred_tersedia:
				continue
			# Langkah 3: tanah hanya petak sendiri, TIDAK perlu lawan "lewat".
			if not main_node._boleh_tanah_di(slot):
				continue
			nilai = _nilai_tanah(main_node, slot, posisi)
		else:
			for lawan in range(main_node.jumlah_pemain()):
				if lawan == slot:
					continue
				if main_node.daftar_pemain[lawan].sisa_gelembung >= 2:
					continue # masih melayang di giliran berikutnya juga
				var posisi_lawan = main_node.daftar_pemain[lawan].posisi_saat_ini
				var jarak = main_node._jarak_maju(posisi_lawan, posisi, 12)
				if jarak < 0:
					continue
				var peluang = _peluang_lewat(main_node, lawan, jarak)
				if peluang <= 0.0:
					continue
				nilai += _nilai_korban(main_node, slot, lawan, elemen, posisi) * peluang
		if elemen == data.role:
			nilai *= 1.2 # Langkah 3: jenis = role bernilai lebih.
		if nilai > nilai_terbaik:
			nilai_terbaik = nilai
			elemen_terbaik = elemen
	if elemen_terbaik == "" or nilai_terbaik < AMBANG_NILAI:
		return ""
	if main_node.mesin_acak.randi_range(1, 100) > AMBANG_PELUANG:
		return ""
	return elemen_terbaik

static func pertimbangkan(main_node: Node, slot: int) -> void:
	# Dipanggil ai_musuh.gd di akhir giliran AI HANYA kalau AI tidak baru
	# membeli/membangun di petak ini giliran ini (lihat komentar di titik
	# panggilnya, logika_ai_musuh_setelah_jalan).
	if not main_node._boleh_pasang_jebakan_di(slot):
		return
	var data = main_node.daftar_pemain[slot]

	# D4 (B-d/K18a): Sacred Ground didahulukan MUTLAK -- TANPA gerbang
	# bintang/undian di bawah (beda dari elemen biasa).
	var elemen_pasang := ""
	var sacred_pasang := false
	if _sacred_layak(main_node, slot):
		elemen_pasang = "tanah"
		sacred_pasang = true
	else:
		# Langkah 1: sisakan bintang untuk serangan jarak jauh (5 bintang) --
		# pasang hanya kalau bintang >= 6, atau bintang >= 2 DAN tidak ada petak
		# lawan bermenara Lv2 (target prioritas serangan).
		var ada_menara_lv2_lawan := false
		for i in range(main_node.rute_papan.size()):
			if main_node.pemilik_petak[i] != slot and main_node.pemilik_petak[i] >= 0 and main_node.level_menara_petak[i] == 2:
				ada_menara_lv2_lawan = true
				break
		var boleh_pertimbangkan = data.bintang >= 6 or (data.bintang >= 2 and not ada_menara_lv2_lawan)
		if not boleh_pertimbangkan:
			return
		elemen_pasang = _pilih_elemen_biasa(main_node, slot)
		if elemen_pasang == "":
			return

	if not main_node._pasang_jebakan(slot, elemen_pasang):
		return

	# Teks & jeda di layar HOST (client menerima lewat _siarkan_jebakan_dipasang
	# -> rpc_jebakan_dipasang di dalam _pasang_jebakan, dengan teksnya sendiri).
	var nama_node: String = DataRole.NODE_JEBAKAN[elemen_pasang]
	# C6 (B-c, 26-09): stealth_charge -- kalau AI memasang jebakan petir siluman
	# & device ini bukan pemiliknya (SOLO: manusia menonton AI musuh, ATAU host
	# menampilkan giliran AI di multiplayer), teks pemasangan TIDAK ditampilkan
	# sama sekali (sama seperti _on_tombol_trap_petir_pressed, pemain_papan.gd).
	var posisi_ai = main_node.daftar_pemain[slot].posisi_saat_ini
	var jebakan_baru_ai = main_node.rute_papan[posisi_ai].get_node_or_null(nama_node)
	# Perbaikan bug (ditemukan saat baseline B-d, di luar D1-D7): "siluman" HANYA ada
	# di JebakanPetir -- .get("siluman") pada jenis lain mengembalikan null, dan
	# bool(null) di GDScript 4 = SCRIPT ERROR "Nonexistent 'bool' constructor" (jadi
	# error ini terjadi SETIAP AI memasang jebakan SELAIN petir). Gerbang nama_node
	# dulu (pola sama T6/D4: cek jenis SEBELUM baca field khusus jenis itu).
	var siluman_ai = jebakan_baru_ai != null and nama_node == "JebakanPetir" and bool(jebakan_baru_ai.siluman)
	var milik_sendiri_ai = slot == main_node.slot_lokal
	if not (siluman_ai and not milik_sendiri_ai):
		main_node.teks_dadu.show()
		# T6 (B-d, D4): kirim flag sacred_pasang -- dulu teks AI selalu "Earth
		# Trap set!" walau jebakan itu Sacred (client sudah benar lewat info.sacred/C4).
		main_node.teks_dadu.text = main_node._teks_jebakan_dipasang(nama_node, milik_sendiri_ai, slot, sacred_pasang)
	main_node.update_ui_status()
	await main_node.get_tree().create_timer(1.5).timeout
