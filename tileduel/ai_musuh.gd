class_name AiMusuh
extends RefCounted
## Dipindah dari pemain.gd (Fase 2 - pemecahan file, file terakhir).
## Ini logika inti keputusan AI: beli tanah, bangun menara, duel, serang jarak jauh, pakai kartu.
## ai_probabilitas_beli_tanah TETAP jadi variabel milik pemain.gd (bukan di sini),
## karena nilainya di-set di satu fungsi lalu dibaca di fungsi lain, harus tetap satu sumber.
##
## Semua fungsi menerima "slot" (0-3). Dulu AI dipatok ke slot 1 saja; sekarang AI
## bisa bermain di slot mana pun -- untuk mode 1 vs 2/3 AI, dan untuk mengambil
## alih pemain yang keluar dari permainan (slot & warnanya tetap seperti semula).

static func _boleh_bangun_menara(main_node: Node, slot: int = 1) -> bool:
	# Syarat menara sekarang: AI harus BERHENTI lagi di petaknya sendiri (bukan
	# menunggu putaran papan). Aturannya sama persis dengan pemain manusia.
	var posisi = main_node.daftar_pemain[slot].posisi_saat_ini
	if posisi >= main_node.berhenti_di_petak_sendiri.size():
		return false
	return main_node.berhenti_di_petak_sendiri[posisi] >= 1

static func _lawan_terkuat(main_node: Node, slot: int) -> int:
	# Lawan dengan uang terbanyak (2 pemain: selalu lawan satu-satunya).
	var terpilih = -1
	for s in range(main_node.jumlah_pemain()):
		if s == slot:
			continue
		if terpilih < 0 or main_node.daftar_pemain[s].uang > main_node.daftar_pemain[terpilih].uang:
			terpilih = s
	return maxi(terpilih, 0)

static func pilih_pedang_ai(main_node: Node, slot: int):
	# KEPUTUSAN SAJA (tanpa efek/UI): kartu pedang terbaik yang dipunyai AI, atau
	# null kalau AI tidak punya pedang sama sekali ATAU memutuskan menyimpannya.
	# Tawaran & pemakaian sebenarnya (termasuk kesempatan AI menekan tombol
	# NO, SAVE IT -- sama seperti penyerang manusia) diurus pemain.gd lewat
	# _pilih_pedang_ai_terlihat(), supaya terlihat di HOST dan semua CLIENT.
	var kartu_pedang_terbaik = null
	var nilai_terbaik = 0
	for k in main_node.daftar_pemain[slot].inventaris_kartu:
		if k["id"].begins_with("pedang"):
			var nilai_pedang = int(k["id"].right(1))
			if nilai_pedang > nilai_terbaik:
				nilai_terbaik = nilai_pedang
				kartu_pedang_terbaik = k
	if kartu_pedang_terbaik == null:
		return null
	# AI tidak selalu memakai pedangnya -- 75% dipakai, 25% menekan NO, SAVE IT
	# sendiri (kartu disimpan untuk duel berikutnya).
	if main_node.mesin_acak.randi_range(1, 100) <= 75:
		return kartu_pedang_terbaik
	return null

static func logika_ai_fase_awal(main_node: Node, slot: int = 1) -> void:
	main_node.target_kamera = main_node._model(slot)
	main_node._umumkan("ai_berpikir", slot)
	await main_node.get_tree().create_timer(1.5).timeout

	var jumlah_petak_lawan = 0
	var denda_maksimal_lawan = 0
	var target_prioritas = -1
	var target_biasa = []
	var jumlah_petak_sendiri = 0
	var denda_maksimal_sendiri = 0
	var petak_per_lawan = {}

	for i in range(main_node.rute_papan.size()):
		var pemilik = main_node.pemilik_petak[i]
		if pemilik >= 0 and pemilik != slot:
			petak_per_lawan[pemilik] = int(petak_per_lawan.get(pemilik, 0)) + 1
			var denda = 100
			if main_node.level_menara_petak[i] == 1: denda = 300
			elif main_node.level_menara_petak[i] == 2: denda = 600
			# D5 (B-d/P3, 26-09): Fortress aktif -- jangan dibidik serangan jarak
			# jauh (T8, syarat identik label "Protected") -- TETAP dihitung utuh
			# di petak_per_lawan/denda_maksimal_lawan di bawah (strategi beli
			# tanah, di luar cakupan P3, tidak diubah).
			if not main_node._benteng_aktif(i):
				target_biasa.append(i)
				if main_node.level_menara_petak[i] == 2:
					target_prioritas = i

			# Fase 4 (A4): perkiraan risiko memakai rock_breaker milik AI sendiri
			# (kalau AI kalah duel di petak ini) + jebakan tanah petak ini kalau ada.
			# D5 (B-d/P4): +argumen ke-3 stone_thorns SUNGGUHAN milik petak ini
			# (_stone_thorns_p_di -- tanpa stone_thorns hasilnya identik sekarang,
			# dasar 1,2 = bawaan parameter itu juga).
			var ada_tanah_lawan = main_node.rute_papan[i].has_node("JebakanTanah")
			var risiko = int(denda * DataRole.pengali_kalah_duel(main_node._lv_node(slot, "rock_breaker"), ada_tanah_lawan, main_node._stone_thorns_p_di(i)))
			if risiko > denda_maksimal_lawan: denda_maksimal_lawan = risiko

		elif pemilik == slot:
			jumlah_petak_sendiri += 1
			var denda = 100
			if main_node.level_menara_petak[i] == 1: denda = 300
			elif main_node.level_menara_petak[i] == 2: denda = 600
			# Fase 4 (A4): rock_breaker penantang tidak diketahui di sini -- pakai
			# kasus terburuk (tanpa rock_breaker) supaya "potensi" tetap perkiraan
			# maksimum, hanya jebakan tanah milik AI di petak ini yang dihitung.
			# D5 (B-d/P4): +argumen ke-3 stone_thorns SUNGGUHAN milik petak ini.
			var ada_tanah_sendiri = main_node.rute_papan[i].has_node("JebakanTanah")
			var potensi = int(denda * DataRole.pengali_kalah_duel(0, ada_tanah_sendiri, main_node._stone_thorns_p_di(i)))
			if potensi > denda_maksimal_sendiri: denda_maksimal_sendiri = potensi

	# Lawan yang dipakai sebagai patokan = yang petaknya paling banyak.
	for s in petak_per_lawan:
		if int(petak_per_lawan[s]) > jumlah_petak_lawan: jumlah_petak_lawan = int(petak_per_lawan[s])

	var sisa_uang_simulasi = main_node.daftar_pemain[slot].uang - main_node.harga_tanah
	if sisa_uang_simulasi >= denda_maksimal_lawan: main_node.ai_probabilitas_beli_tanah = 100
	else:
		if jumlah_petak_sendiri >= jumlah_petak_lawan or denda_maksimal_sendiri >= denda_maksimal_lawan:
			main_node.ai_probabilitas_beli_tanah = 50
		else: main_node.ai_probabilitas_beli_tanah = 0

	if main_node.daftar_pemain[slot].bintang >= 5 and not main_node.sudah_serang_giliran_ini:
		if main_node.kemarahan_slot[slot] > 0 or target_prioritas != -1:
			var target_tembak = -1
			if target_prioritas != -1: target_tembak = target_prioritas
			elif target_biasa.size() > 0:
				# Kalau sedang dendam, petak milik penyerangnya yang dibidik duluan.
				var daftar_dendam = []
				var pendendam = main_node.sasaran_dendam_slot[slot]
				if main_node.kemarahan_slot[slot] > 0 and pendendam >= 0:
					for i in target_biasa:
						if main_node.pemilik_petak[i] == pendendam: daftar_dendam.append(i)
				var kumpulan = daftar_dendam if daftar_dendam.size() > 0 else target_biasa
				target_tembak = kumpulan[main_node.mesin_acak.randi_range(0, kumpulan.size() - 1)]

			if target_tembak != -1:
				var korban = main_node.pemilik_petak[target_tembak]
				main_node.daftar_pemain[slot].bintang -= 5
				main_node.sudah_serang_giliran_ini = true
				if main_node.kemarahan_slot[slot] > 0: main_node.kemarahan_slot[slot] -= 1

				main_node._umumkan("ai_serang", slot)
				# Multiplayer: animasi serangan yang sama diputar juga di device lain.
				if StatusJaringan.peran_multiplayer == "host":
					main_node.rpc("rpc_efek_serangan", target_tembak, slot, main_node.daftar_pemain[slot].bintang, korban)
				await main_node.label_petak_3d[target_tembak].mainkan_efek_serangan(main_node._model(slot).global_position, main_node._aktor_dari_slot(slot), main_node)

				await main_node.get_tree().create_timer(0.8).timeout
				main_node.target_kamera = main_node._model(slot)

				# B-b bagian 4b: Fortress bisa menahan serangan jarak jauh AI juga,
				# sama seperti serangan manusia (eksekusi_serangan, pemain_papan.gd).
				if main_node._benteng_menahan(target_tembak):
					if StatusJaringan.peran_multiplayer == "host":
						main_node.rpc("rpc_hasil_serangan", target_tembak, slot, false, main_node.nyawa_petak[target_tembak], korban, true)
					main_node.teks_dadu.text = "FORTRESS! The attack was blocked."
				else:
					main_node.nyawa_petak[target_tembak] -= 1
					var hancur = main_node.nyawa_petak[target_tembak] <= 0

					if hancur:
						main_node.reset_petak_ke_netral(target_tembak)
					if StatusJaringan.peran_multiplayer == "host":
						main_node.rpc("rpc_hasil_serangan", target_tembak, slot, hancur, main_node.nyawa_petak[target_tembak], korban)
					main_node.teks_dadu.text = main_node._teks_hasil_serangan(slot, korban, hancur, main_node.nyawa_petak[target_tembak])

				main_node.update_semua_label_petak()
				main_node.update_ui_status()
				main_node._siarkan_state_ai(slot)
				await main_node.get_tree().create_timer(3.0).timeout

	# Fase 4 (U3): manusia boleh Set Trap di AWAL giliran (petak tempat berdiri,
	# sebelum lempar dadu) -- AI disamakan. Tanpa ini AI hampir tidak pernah
	# memasang jebakan: di akhir giliran ia hampir selalu membeli/membangun.
	await AiJebakan.pertimbangkan(main_node, slot)

	# --- LOGIKA AI MENGGUNAKAN KARTU (Sebelum lempar dadu) ---
	# Kartu PEDANG dikecualikan dari sini: itu cuma boleh dipakai saat AI
	# MENYERANG (lihat _pilih_pedang_ai_terlihat, dipanggil dari _mulai_duel) --
	# tanpa penyaringan ini kartunya hilang sia-sia tanpa efek apapun ("is using
	# a card!" lalu diam saja).
	# Fase 4 (A5 / K7): pemain manusia yang melayang di gelembung sudah tidak
	# bisa memakai kartu (tombol Use Card disembunyikan) -- AI disamakan.
	var bisa_dipakai = []
	if main_node.daftar_pemain[slot].sisa_gelembung == 0 and main_node.daftar_pemain[slot].kunci_kartu == 0: # B-b (B4/K7): frozen_bubble
		for k in main_node.daftar_pemain[slot].inventaris_kartu:
			if not k["id"].begins_with("pedang"): bisa_dipakai.append(k)
	if bisa_dipakai.size() > 0:
		if main_node.mesin_acak.randi_range(1, 100) <= 40:
			var kartu_dipilih = bisa_dipakai[randi() % bisa_dipakai.size()]
			var indeks_asal = main_node.daftar_pemain[slot].inventaris_kartu.find(kartu_dipilih)
			main_node.daftar_pemain[slot].inventaris_kartu.remove_at(indeks_asal)

			# AI CERDAS: Pilih target spesifik berdasarkan tipe kartu
			var target_ai = ""
			if kartu_dipilih["id"] == "dadu_rendah":
				target_ai = main_node._aktor_dari_slot(_lawan_terkuat(main_node, slot)) # Sabotase lawan terkuat
			elif kartu_dipilih["id"] == "dadu_tinggi":
				target_ai = main_node._aktor_dari_slot(slot) # Buff diri sendiri

			# Animasi kartu (judul "... USED A CARD!" dst, terlihat di semua device)
			# sudah mengumumkan pemakaiannya -- lihat _putar_animasi_pakai_kartu di
			# dalam _eksekusi_kartu_simpan.
			await main_node._eksekusi_kartu_simpan(kartu_dipilih, main_node._aktor_dari_slot(slot), target_ai, indeks_asal)

	main_node.fase_giliran = "akhir"
	main_node._umumkan("ai_lempar_dadu", slot)
	await main_node.get_tree().create_timer(1.0).timeout
	main_node.lempar_dadu(main_node._aktor_dari_slot(slot))

static func _faktor_fight_tanah(main_node: Node, slot_penyerang: int, posisi: int) -> float:
	# K19(a) (B-d/D5, 26-09): faktor kontinu (0-1) TANPA ambang batal --
	# menggantikan gerbang biner lama ("ada/tidak ada jebakan tanah lawan" ->
	# peluang dibagi dua rata, tidak peduli levelnya). Rumus:
	# faktor = clamp(0,5^hp_harapan x (1,2/pengali_kalah), 0, 1). TANPA ambang
	# karena: dengan ambang, petak Sacred+hard_rock jadi KEBAL SELAMANYA dari
	# AI -- bertentangan dengan bagian 1 ("petak tetap bisa direbut lewat duel").
	if posisi < 0 or posisi >= main_node.rute_papan.size():
		return 1.0
	var jebakan = main_node.rute_papan[posisi].get_node_or_null("JebakanTanah")
	if jebakan == null or not jebakan.aktif or jebakan.pemilik == slot_penyerang:
		return 1.0
	# AI (penyerang) sendiri Guard rock_breaker belum terpakai -> kebal total,
	# tidak ada alasan segan (faktor 1).
	if main_node._guard_boleh(slot_penyerang, "tanah"):
		return 1.0
	var lv_rb_penyerang = main_node._tahan(slot_penyerang, "tanah")
	# hp_harapan: bonus HP SUNGGUHAN jebakan ini (hitung_bonus_hp, jebakan_tanah.gd
	# -- P1: baca fungsi murni ini, JANGAN _angka_jebakan langsung dari sini),
	# dipotong peluang gagal 50% (ROCK_BREAKER_LV, SEMUA level) kalau penyerang
	# punya Rock Breaker.
	var hp_harapan = float(jebakan.hitung_bonus_hp(main_node))
	if lv_rb_penyerang >= 1:
		hp_harapan *= 1.0 - float(DataRole.ROCK_BREAKER_LV[clampi(lv_rb_penyerang, 1, 3)]["peluang_gagal_hp"])
	# pengali_kalah: stone_thorns SUNGGUHAN pemilik petak (_stone_thorns_p_di,
	# pemain_role.gd -- P1: sudah murni), dipotong Rock Breaker Lv2/3 penyerang
	# lewat DataRole.pengali_kalah_duel yang SUNGGUHAN dipakai saat duel.
	var pengali_kalah = DataRole.pengali_kalah_duel(lv_rb_penyerang, true, main_node._stone_thorns_p_di(posisi))
	return clampf(pow(0.5, hp_harapan) * (float(DataRole.DASAR["pengali_kalah_duel"]) / pengali_kalah), 0.0, 1.0)

static func logika_ai_musuh_setelah_jalan(main_node: Node, slot: int = 1) -> void:
	if main_node.daftar_pemain[slot].sisa_gelembung > 0:
		main_node._umumkan("ai_gelembung", slot)
		await main_node.get_tree().create_timer(1.5).timeout
		main_node.ganti_giliran()
		return
	var posisi = main_node.daftar_pemain[slot].posisi_saat_ini
	var sudah_dibeli = main_node.status_kepemilikan_petak[posisi]
	var siapa_punya = main_node.pemilik_petak[posisi]
	var level_menara = main_node.level_menara_petak[posisi]
	# Fase 4 (A5): true kalau AI membeli/membangun giliran ini -- dipakai untuk
	# menahan AiJebakan.pertimbangkan di bawah (aturan sama seperti manusia:
	# Buy/Build langsung mengakhiri giliran, tidak sekalian pasang jebakan).
	var beli_atau_bangun := false

	await main_node.get_tree().create_timer(1.0).timeout
	# BLOK PROTEKSI PETAK CABANG UNTUK AI
	var petak_kini = main_node.rute_papan[posisi]
	if petak_kini.referensi_node_selanjutnya.size() > 1:
		main_node._umumkan("ai_cabang", slot)
		await main_node.get_tree().create_timer(1.5).timeout
		main_node.ganti_giliran()
		return

	# BLOK PROTEKSI PETAK PERMATA UNTUK AI
	if petak_kini.is_petak_permata:
		main_node._umumkan("ai_permata", slot)
		await main_node.get_tree().create_timer(1.5).timeout
		main_node.ganti_giliran()
		return

	# =======================================================
	# TAMBAHAN BARU: PROTEKSI PETAK KARTU UNTUK AI
	# =======================================================
	if petak_kini.is_petak_kartu:
		main_node._umumkan("ai_kartu", slot)
		await main_node.get_tree().create_timer(1.5).timeout
		main_node.ganti_giliran()
		return
	if posisi == 0:
		main_node._umumkan("ai_start", slot)
		await main_node.get_tree().create_timer(2.0).timeout
		main_node.ganti_giliran()
		return

	if sudah_dibeli and siapa_punya >= 0 and siapa_punya != slot:
		main_node._umumkan("ai_mendarat", slot, 0, siapa_punya)
		await main_node.get_tree().create_timer(1.5).timeout
		var akan_bertarung = false

		# AI TIDAK BOLEH BERTARUNG JIKA PARALISIS -- kecuali Grounded Lv2/3 (K13,
		# B-b: Lv1 sekarang HANYA giliran berikut tidak terlewat, TIDAK membuka Fight).
		var boleh_lawan_saat_paralisis = main_node.daftar_pemain[slot].sisa_paralisis == 0 or main_node._boleh_fight_saat_lumpuh(slot)
		if main_node.daftar_pemain[slot].uang >= 0 and boleh_lawan_saat_paralisis:
			# K19(a) (B-d/D5, 26-09): peluang Fight DASAR per level menara
			# (100/55/50, U3) dikali faktor KONTINU _faktor_fight_tanah (0-1,
			# TANPA ambang batal -- lihat komentar di fungsi itu) --
			# menggantikan gerbang biner lama (ada/tidak ada jebakan tanah ->
			# dibagi dua rata, tidak peduli levelnya, T7).
			var peluang_dasar = 100 if level_menara == 2 else (55 if level_menara == 1 else 50)
			var faktor_tanah = _faktor_fight_tanah(main_node, slot, posisi)
			if main_node.mesin_acak.randi_range(1, 100) <= roundi(float(peluang_dasar) * faktor_tanah):
				akan_bertarung = true

		if akan_bertarung:
			# Jebakan tanah, kartu pedang, duel, lalu hasilnya (lihat _mulai_duel).
			main_node._mulai_duel(slot)
			return
		else:
			main_node._bayar_denda(slot, siapa_punya, 1.0)
			return

	elif not sudah_dibeli and main_node.daftar_pemain[slot].uang >= main_node.harga_tanah and main_node.daftar_pemain[slot].sisa_paralisis == 0:
		var keputusan = main_node.mesin_acak.randi_range(1, 100)
		if keputusan <= main_node.ai_probabilitas_beli_tanah:
			main_node.daftar_pemain[slot].uang -= main_node.harga_tanah
			main_node.status_kepemilikan_petak[posisi] = true
			main_node.pemilik_petak[posisi] = slot
			main_node.nyawa_petak[posisi] = 3
			main_node._atur_berhenti_petak(posisi, 0)
			main_node._umumkan("ai_beli", slot)
			beli_atau_bangun = true
		else: main_node._umumkan("ai_hemat", slot)

	elif sudah_dibeli and siapa_punya == slot and level_menara == 0 and main_node.daftar_pemain[slot].uang >= main_node.harga_menara_lv1 and _boleh_bangun_menara(main_node, slot) and main_node.daftar_pemain[slot].sisa_paralisis == 0:
		main_node.daftar_pemain[slot].uang -= main_node.harga_menara_lv1
		main_node.level_menara_petak[posisi] = 1
		main_node.nyawa_petak[posisi] += 1
		beli_atau_bangun = true

		main_node._umumkan("ai_bangun", slot)
		await main_node.label_petak_3d[posisi].mainkan_efek_bangun(1)
		main_node._bangun_fisik_menara(posisi, main_node._material_slot(slot), 1)
		main_node._atur_berhenti_petak(posisi, 0)

	elif sudah_dibeli and siapa_punya == slot and level_menara == 1 and main_node.daftar_pemain[slot].uang >= main_node.harga_menara_lv2 and _boleh_bangun_menara(main_node, slot) and main_node.daftar_pemain[slot].sisa_paralisis == 0:
		main_node.daftar_pemain[slot].uang -= main_node.harga_menara_lv2
		main_node.level_menara_petak[posisi] = 2
		main_node.nyawa_petak[posisi] += 1
		beli_atau_bangun = true

		main_node._umumkan("ai_upgrade", slot)
		await main_node.label_petak_3d[posisi].mainkan_efek_bangun(2)
		main_node._bangun_fisik_menara(posisi, main_node._material_slot(slot), 2)
		main_node._atur_berhenti_petak(posisi, 0)
	else:
		if main_node.daftar_pemain[slot].sisa_paralisis > 0:
			main_node._umumkan("ai_lumpuh_akhir", slot)
		else:
			main_node._umumkan("ai_selesai", slot)

	# Fase 4 (A5): AI mempertimbangkan memasang jebakan HANYA kalau ia
	# TIDAK baru membeli/membangun di petak ini giliran ini (lihat komentar
	# beli_atau_bangun di atas).
	if not beli_atau_bangun:
		await AiJebakan.pertimbangkan(main_node, slot)

	main_node.update_semua_label_petak()
	main_node.update_ui_status()
	# Multiplayer: papan di device lain ikut diperbarui (petak dibeli/menara baru).
	main_node._siarkan_state_ai(slot)
	await main_node.get_tree().create_timer(1.5).timeout
	if main_node.cek_game_over(): return
	main_node.ganti_giliran()
