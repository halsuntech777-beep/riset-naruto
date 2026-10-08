@abstract
extends "res://pemain_kartu.gd"
# ========================================================================
# PEMAIN_DUEL.GD
# DUEL: pilih elemen, naskah & replay duel, lempar koin penentu seri, hasil duel, jebakan tanah saat duel
# pemain.gd dipecah BERTINGKAT (Fase 3): tiap file meneruskan (extends) file
# sebelumnya, jadi semuanya tetap SATU node Pemain -- variabel & fungsi dari file
# lain dipakai langsung seperti dulu. Urutan: pemain_dasar.gd -> pemain_tampilan.gd -> pemain_papan.gd -> pemain_kartu.gd -> pemain_duel.gd -> pemain_jaringan.gd -> pemain.gd
# @abstract = file ini bagian dari pemain.gd, tidak dipasang sendiri ke node.
# ========================================================================

# Penampung pilihan elemen dari device lain, per slot peserta duel. WAJIB
# ditampung, bukan cuma mengandalkan sinyal: kalau client memilih lebih dulu
# daripada host, sinyalnya terpancar saat host belum menunggu — lalu hilang, dan
# duel membeku selamanya.
var _pilihan_elemen_jaringan: Dictionary = {} # slot -> elemen
signal elemen_jaringan_diterima(slot)
# Duel yang sedang berjalan (HOST): siapa penyerang & pembelanya.
var _duel_slot_penyerang: int = -1
var _duel_slot_pembela: int = -1
# Lempar koin penentu seri (HOST): hasil koin baru diundi setelah SEMUA peserta
# manusia memilih. Urutan datangnya bebas, tergantung siapa yang jadi pembela.
var _koin_seri_pilihan: Dictionary = {} # slot -> "kepala"/"ekor"
var _koin_seri_wajib: Array = []        # slot manusia yang pilihannya ditunggu
var _duel_mengumpulkan: bool = false    # host sedang menunggu pilihan elemen peserta
# HOST: penjaga timer "berpikir" AI (_ai_kunci_elemen_tertunda) supaya timer dari
# duel SEBELUMNYA tidak nyasar mengunci elemen duel BERIKUTNYA.
var _nomor_duel: int = 0
# CLIENT: naik setiap kali device ini mengambil alih permainan karena host keluar.
# Coroutine lama yang masih menunggu klik untuk dikirim ke host jadi tahu diri.
var _generasi_jaringan: int = 0

# ========================================================
# DUEL (2-4 PEMAIN)
# Penyerang = pemain yang mendarat, pembela = pemilik petak. Layar duel
# (ui_elemen) punya dua sisi: "pemain" (YOU) dan "musuh". Di device peserta,
# sisi "pemain" = pemain device itu sendiri; di device penonton (3-4 pemain),
# sisi "pemain" = penyerang.
# - Solo manusia vs AI: alur asli ui_elemen (AI memilih sendiri di dalamnya).
# - Selainnya (multiplayer, atau AI vs AI): semua keputusan dikumpulkan dulu
#   jadi satu NASKAH -- elemen & angka rolet kedua peserta (plus lempar koin
#   kalau pesertanya AI) -- lalu diputar identik di semua layar. Naskah ditulis
#   dalam SLOT (slot_a = penyerang, slot_d = pembela); tiap device tinggal
#   menerjemahkannya ke sudut pandangnya sendiri (_naskah_lokal).
# Kedua pemain manusia tetap memilih elemennya sendiri-sendiri: host
# mengumpulkan pilihan NYATA dulu -- klik lokal dan/atau RPC dari client.
# ========================================================

func _mulai_duel(slot_a: int) -> void:
	# Dipanggil setelah penyerang memutuskan bertarung (tombol Fight / keputusan AI).
	var posisi = daftar_pemain[slot_a].posisi_saat_ini
	var slot_d = pemilik_petak[posisi]
	fase_giliran = "duel_berlangsung"
	menu_aksi.hide()
	teks_uang.hide()
	teks_bintang.hide()
	teks_dadu.hide()

	# --- CEK JEBAKAN TANAH SEBELUM DUEL DIMULAI ---
	var cek_tanah = rute_papan[posisi].get_node_or_null("JebakanTanah")
	# Fase 4 (A2/A4, temuan 9): dicatat DI SINI, bukan dibaca lagi nanti -- node
	# jebakan tanah ini BISA BERTAHAN lebih dari satu duel sekarang (hard_rock/
	# Sacred Ground, bagian 4/5) -- _pengali_kalah_duel (Rock Breaker) tetap
	# harus tahu jebakan ini ADA saat duel INI dimulai, apapun nasibnya nanti.
	_tanah_saat_duel = {
		"ada": cek_tanah != null and cek_tanah.aktif,
		"pemilik": cek_tanah.pemilik if cek_tanah != null else -1,
		"posisi": posisi,
	}
	if cek_tanah and cek_tanah.aktif:
		# Fase 2: jebakan tanah bisa terpasang di petak lawan -- penyerangnya sendiri tidak dihitung.
		# B-b bagian 4 (14.2/B4): Guard (rock_breaker Lv3) diperiksa PERTAMA -- kalau
		# aktif, jebakan hilang & penyerang tidak dapat/kena efek tanah APA PUN.
		if cek_tanah.pemilik != slot_a and _guard_boleh(slot_a, "tanah"):
			_pakai_guard(slot_a, "tanah")
			_tanah_saat_duel = {"ada": false, "pemilik": -1, "posisi": posisi}
			teks_dadu.show()
			teks_dadu.text = "GUARD! Earth Trap blocked!"
			# C5 (B-c, 26-09, perbaikan T2): dulu rpc_mainkan_efek_jebakan -- match
			# di fungsi itu tidak punya kasus "JebakanTanah" jadi client tidak
			# pernah melihat teksnya. Sekarang lewat rpc_efek_role "guard" (satu
			# jalur baru dengan 4 cabang Guard lain, pemain.gd).
			if StatusJaringan.peran_multiplayer == "host":
				rpc("rpc_efek_role", "guard", {"elemen": "tanah", "petak": posisi, "aktor": _aktor_dari_slot(slot_a)})
			await get_tree().create_timer(1.0).timeout
			teks_dadu.hide()
			if is_instance_valid(cek_tanah):
				cek_tanah.queue_free()
		else:
			if cek_tanah.pemilik != slot_a:
				_tambah_stat(cek_tanah.pemilik, "jebakan_kena")
				if daftar_pemain[cek_tanah.pemilik].role == "tanah": # Fase 4 (4c): XP Role "kena"
					_tambah_stat(cek_tanah.pemilik, "jebakan_role_kena")
			teks_dadu.show()
			# K14 (B-b bagian 4): Rock Breaker Lv1+ milik PENYERANG (yang kena efek
			# tanah) -- 50% peluang (diundi host/solo; _mulai_duel tidak pernah
			# berjalan di client murni, lihat _teruskan_aksi_ke_host) meniadakan
			# bonus HP tanah SEPENUHNYA untuk duel ini saja (sisa_duel tetap berkurang
			# seperti biasa -- diputuskan _selesaikan_tanah_setelah_duel).
			var lv_rock_breaker = _lv_node(slot_a, "rock_breaker")
			var rock_breaker_gagal = false
			if lv_rock_breaker >= 1 and StatusJaringan.peran_multiplayer != "client":
				var peluang_gagal = float(DataRole.ROCK_BREAKER_LV[clampi(lv_rock_breaker, 1, 3)]["peluang_gagal_hp"])
				rock_breaker_gagal = mesin_acak.randf() < peluang_gagal
			# C5 (B-c, 26-09): _siarkan_jebakan_tanah_aktif DIPINDAH ke SINI --
			# SESUDAH undian Rock Breaker (dulu SEBELUM -> client SELALU melihat
			# "+1 HP" walau Rock Breaker meniadakannya di host). bonus_hp dihitung
			# SEKALI (hitung_bonus_hp, tanpa efek samping) & angka yang SAMA
			# dipakai RPC ini maupun aktifkan_pelindung_sementara di bawah (host
			# & client jadi selalu identik).
			var bonus_hp_tanah = 0 if rock_breaker_gagal else cek_tanah.hitung_bonus_hp(self)
			_siarkan_jebakan_tanah_aktif(posisi, bonus_hp_tanah)
			if rock_breaker_gagal:
				_tambah_stat(slot_a, "tahan_kurangi") # K14: benar2 meniadakan bonus HP kali ini
				teks_dadu.text = "ROCK BREAKER! Earth Trap bonus negated!"
				await get_tree().create_timer(1.5).timeout
			else:
				teks_dadu.text = "EARTH TRAP ACTIVATED!"
				await cek_tanah.aktifkan_pelindung_sementara(self, posisi, ui_elemen, bonus_hp_tanah)
			teks_dadu.hide()

	# =======================================================
	# KARTU PEDANG PENYERANG (manusia: tawaran di device-nya; AI: otomatis)
	# =======================================================
	var poin_bonus_pedang = 0
	if _is_ai(slot_a):
		# Tawaran pedang AI terlihat di HOST dan semua CLIENT, sama persis dengan
		# milik penyerang manusia -- termasuk kesempatan AI menekan NO, SAVE IT.
		poin_bonus_pedang = await _pilih_pedang_ai_terlihat(slot_a)
	else:
		var ada_pedang = false
		for k in daftar_pemain[slot_a].inventaris_kartu:
			if k["id"].begins_with("pedang"): ada_pedang = true
		if ada_pedang:
			# Tawaran pedang muncul di device PENYERANG (lihat _pilih_pedang_penyerang).
			# Pilihannya (pakai / NO, SAVE IT) diumumkan 1.5 dtk di dalam UI pedang
			# itu sendiri, di semua layar -- jadi tidak perlu teks pengumuman lagi di sini.
			var pedang_dipilih = await _pilih_pedang_penyerang(slot_a)
			if pedang_dipilih != null:
				var indeks = daftar_pemain[slot_a].inventaris_kartu.find(pedang_dipilih)
				if indeks != -1: daftar_pemain[slot_a].inventaris_kartu.remove_at(indeks)
				poin_bonus_pedang = int(pedang_dipilih["id"].right(1))
	if poin_bonus_pedang > 0:
		_tambah_stat(slot_a, "kartu_pakai")

	AudioGrafis.mulai_musik_duel(self)
	var hasil_duel = await _jalankan_duel(slot_a, slot_d, nyawa_petak[posisi], poin_bonus_pedang)
	AudioGrafis.kembali_ke_musik_normal(self)
	eksekusi_dadu_pertarungan(hasil_duel, slot_a, slot_d)

func _sisi_p_duel(slot_a: int, slot_d: int) -> int:
	# Slot yang tampil di sisi "pemain" (YOU) layar duel device ini.
	if slot_d == slot_lokal:
		return slot_d
	return slot_a # peserta penyerang, atau penonton

func _atur_nama_duel(slot_a: int, slot_d: int) -> void:
	# 2 pemain: "YOU" vs "ENEMY" seperti dulu. 3-4 pemain: "YOU" vs "P3", atau
	# untuk penonton "P2" vs "P3" (mode tonton: tanpa klik sama sekali).
	var sisi_p = _sisi_p_duel(slot_a, slot_d)
	var sisi_m = slot_d if sisi_p == slot_a else slot_a
	var tonton = (sisi_p != slot_lokal) or _is_ai(sisi_p)
	var nama_p = "YOU" if not tonton else "P%d" % (sisi_p + 1)
	var nama_m = "ENEMY" if jumlah_pemain() <= 2 else "P%d" % (sisi_m + 1)
	if tonton and jumlah_pemain() <= 2:
		nama_p = "P%d" % (sisi_p + 1)
		nama_m = "P%d" % (sisi_m + 1)
	ui_elemen.atur_sudut_pandang(nama_p, nama_m, tonton)

func _jalankan_duel(slot_a: int, slot_d: int, nyawa_kandang: int, bonus_pedang: int) -> Dictionary:
	# Menjalankan duel di device ini (solo / host). Hasilnya dalam SLOT:
	# {"slot_pemenang": s, "poin_sisa": n} -- poin_sisa = selisih skor (999 kalau
	# pemenangnya ditentukan lempar koin), dipakai untuk HP petak pembela.
	_atur_nama_duel(slot_a, slot_d)
	var sisi_p = _sisi_p_duel(slot_a, slot_d)
	var hasil_ui: Dictionary
	var manusia_lokal_ikut = (sisi_p == slot_lokal) and not _is_ai(slot_lokal)
	if StatusJaringan.peran_multiplayer == "" and manusia_lokal_ikut:
		# Solo manusia vs AI: alur asli (AI memilih elemen di dalam jalankan_duel).
		var siapa = "pemain" if slot_a == slot_lokal else "musuh"
		hasil_ui = await ui_elemen.jalankan_duel(siapa, nyawa_kandang, kamera, teks_dadu, bonus_pedang)
	else:
		var naskah: Dictionary
		if StatusJaringan.peran_multiplayer == "host":
			naskah = await _kumpulkan_naskah_duel(slot_a, slot_d, nyawa_kandang, bonus_pedang)
			rpc("rpc_mulai_replay_duel", nyawa_kandang, naskah)
		else:
			naskah = _naskah_duel_ai(slot_a, slot_d, nyawa_kandang, bonus_pedang)
			await _tonton_ai_pilih_elemen(slot_a, slot_d)
		var siapa_lokal = "pemain" if sisi_p == slot_a else "musuh"
		hasil_ui = await ui_elemen.jalankan_duel(siapa_lokal, nyawa_kandang, kamera, teks_dadu, bonus_pedang, _naskah_lokal(naskah, sisi_p))
	var sisi_m = slot_d if sisi_p == slot_a else slot_a
	var selisih = abs(hasil_ui["skor_akhir_pemain"] - hasil_ui["skor_akhir_musuh"])
	# Fase 2: elemen yang dipakai tiap sisi (ui_elemen menyimpannya sampai duel berikutnya).
	var elemen_sisi = {sisi_p: ui_elemen.elemen_pilihan_pemain, sisi_m: ui_elemen.elemen_pilihan_musuh}
	var slot_menang = sisi_p if hasil_ui["pemenang_final"] == "pemain" else sisi_m
	return {
		"slot_pemenang": slot_menang,
		"poin_sisa": selisih if selisih > 0 else 999,
		"elemen_pemenang": str(elemen_sisi.get(slot_menang, "")),
	}

func _naskah_lokal(naskah: Dictionary, sisi_p: int) -> Dictionary:
	# Terjemahkan naskah (dalam slot) ke sisi layar duel device ini.
	var p_adalah_a = (sisi_p == naskah["slot_a"])
	var lokal = {
		"elemen_pemain": naskah["elemen_a"] if p_adalah_a else naskah["elemen_d"],
		"elemen_musuh": naskah["elemen_d"] if p_adalah_a else naskah["elemen_a"],
		"angka_p": naskah["angka_a"] if p_adalah_a else naskah["angka_d"],
		"angka_m": naskah["angka_d"] if p_adalah_a else naskah["angka_a"],
		"bonus_pedang": naskah.get("bonus_pedang", 0),
	}
	# Lempar koin penentu seri: pilihan pembela AI & hasil koin (kalau kedua
	# peserta AI) sudah ditentukan di naskah -- tidak ada yang perlu diklik.
	if naskah.has("koin_pembela"): lokal["koin_pembela"] = naskah["koin_pembela"]
	if naskah.has("koin_hasil"): lokal["koin_hasil"] = naskah["koin_hasil"]
	return lokal

func _tonton_ai_pilih_elemen(slot_a: int, slot_d: int) -> void:
	# SOLO, kedua peserta AI (pemain manusia menonton): elemennya sudah diputuskan
	# di naskah, tapi segel LOCKED dimunculkan BERGANTIAN -- penyerang "berpikir"
	# 1.5 dtk lalu mengunci, jeda 1 dtk, baru pembela mengunci -- sama seperti
	# duel AI vs AI di multiplayer (_kumpulkan_naskah_duel). Tanpa ini kedua segel
	# langsung muncul bersamaan di "BOTH LOCKED!" dan terlihat kurang alami.
	_duel_slot_penyerang = slot_a
	_duel_slot_pembela = slot_d
	ui_elemen.siapkan_tonton_pilih_elemen(ui_elemen._kata_serang(ui_elemen.nama_sisi_p) + " CHOOSING ELEMENTS...")
	await get_tree().create_timer(1.5).timeout
	_tampilkan_segel_terkunci(slot_a)
	await get_tree().create_timer(1.0).timeout
	_tampilkan_segel_terkunci(slot_d)

func _naskah_duel_ai(slot_a: int, slot_d: int, nyawa_kandang: int, bonus_pedang: int) -> Dictionary:
	# SOLO, kedua peserta AI (3-4 pemain): semua keputusan diambil di sini, lalu
	# pemain manusia menonton duelnya.
	var naskah = {
		"slot_a": slot_a, "slot_d": slot_d,
		"elemen_a": ui_elemen._pilih_elemen_adaptif("menyerang"),
		"elemen_d": ui_elemen._pilih_elemen_adaptif("bertahan"),
		"angka_a": ui_elemen.angka_penyerang[mesin_acak.randi_range(0, ui_elemen.angka_penyerang.size() - 1)],
		"angka_d": ui_elemen.angka_pembela[mesin_acak.randi_range(0, ui_elemen.angka_pembela.size() - 1)],
		"bonus_pedang": bonus_pedang,
	}
	_lengkapi_koin_naskah(naskah, nyawa_kandang)
	return naskah

func _lengkapi_koin_naskah(naskah: Dictionary, nyawa_kandang: int) -> void:
	# Skor akhir sudah bisa dihitung dari naskah. Kalau SERI: pilihan sisi koin
	# pembela AI diundi di sini, dan kalau kedua peserta AI hasil koinnya juga.
	# Peserta manusia yang pilihannya ditunggu host dicatat di _koin_seri_wajib.
	var skor = ui_elemen.skor_duel(naskah["elemen_a"], naskah["elemen_d"], naskah["angka_a"], naskah["angka_d"], nyawa_kandang, naskah.get("bonus_pedang", 0))
	if skor[0] != skor[1]:
		return
	var slot_a = naskah["slot_a"]
	var slot_d = naskah["slot_d"]
	if _is_ai(slot_d):
		naskah["koin_pembela"] = "kepala" if mesin_acak.randi_range(0, 1) == 0 else "ekor"
	if _is_ai(slot_a) and _is_ai(slot_d):
		naskah["koin_hasil"] = "kepala" if mesin_acak.randi_range(0, 1) == 0 else "ekor"
	for s in [slot_a, slot_d]:
		if not _is_ai(s) and not _koin_seri_wajib.has(s):
			_koin_seri_wajib.append(s)

func _ai_kunci_elemen_tertunda(slot: int, jeda: float, nomor: int) -> void:
	# HOST: AI "berpikir" sebentar sebelum mengunci elemen duel (lihat
	# _kumpulkan_naskah_duel). "nomor" menjaga supaya timer dari duel SEBELUMNYA
	# (mis. AI vs AI yang jeda pembelanya lebih panjang) tidak nyasar mengunci
	# elemen duel BERIKUTNYA kalau duel ini keburu selesai lebih dulu.
	await get_tree().create_timer(jeda).timeout
	if nomor != _nomor_duel or not _duel_mengumpulkan:
		return
	_kunci_elemen_peserta(slot, ui_elemen._pilih_elemen_adaptif("menyerang" if slot == _duel_slot_penyerang else "bertahan"))

func _kumpulkan_naskah_duel(slot_a: int, slot_d: int, nyawa_kandang: int, bonus_pedang: int) -> Dictionary:
	# HOST ONLY.
	_duel_mengumpulkan = true
	_pilihan_elemen_jaringan.clear() # bersihkan sisa duel sebelumnya
	_koin_seri_pilihan.clear()
	_koin_seri_wajib.clear()
	_duel_slot_penyerang = slot_a
	_duel_slot_pembela = slot_d
	_nomor_duel += 1
	var nomor_ini = _nomor_duel

	# Permintaan ke client dikirim DULU, sebelum host menunggu kliknya sendiri --
	# kalau ditaruh setelah await, baris ini tidak akan pernah tercapai selama
	# host belum memilih, dan client tak pernah melihat pilihan elemennya.
	for s in [slot_a, slot_d]:
		var id_peserta = _peer_slot(s)
		if id_peserta > 0:
			rpc_id(id_peserta, "rpc_minta_pilihan_elemen_duel", slot_a, slot_d)
	# Device lain yang bukan peserta cuma menonton: kabari duelnya sudah mulai --
	# layar duel mode tonton dibuka SEJAK AWAL fase pilih elemen (bukan cuma teks).
	var peserta_jaringan = [_peer_slot(slot_a), _peer_slot(slot_d)]
	_rpc_ke_klien_kecuali(peserta_jaringan, "rpc_duel_dimulai", [slot_a, slot_d])
	if slot_a != slot_lokal and slot_d != slot_lokal:
		rpc_duel_dimulai(slot_a, slot_d)

	# Host yang IKUT jadi peserta harus sudah membuka layar pilih elemennya
	# sendiri SEBELUM AI lawannya mulai "berpikir" -- supaya jeda berpikirnya
	# terlihat sungguhan, bukan segel yang sudah terkunci duluan (bug lama).
	var host_ikut = (slot_a == slot_lokal or slot_d == slot_lokal) and not _is_ai(slot_lokal)
	if host_ikut:
		_siapkan_pilihan_elemen_lokal()

	# Peserta AI "berpikir" dulu sebelum mengunci elemen -- 2.0 dtk kalau lawannya
	# manusia, atau (kalau KEDUA peserta AI) penyerang 1.5 dtk & pembela 2.5 dtk
	# supaya segelnya muncul bergantian, bukan bersamaan. Jeda TETAP (bukan acak)
	# supaya urutan mesin_acak tidak bergeser dibanding sebelumnya.
	var kedua_ai = _is_ai(slot_a) and _is_ai(slot_d)
	for s in [slot_a, slot_d]:
		if not _is_ai(s):
			continue
		var jeda = 2.0
		if kedua_ai:
			jeda = 1.5 if s == slot_a else 2.5
		_ai_kunci_elemen_tertunda(s, jeda, nomor_ini) # TANPA await

	if host_ikut:
		var pilihan = await _tunggu_klik_elemen_lokal()
		if pilihan != "":
			_kunci_elemen_peserta(slot_lokal, pilihan)

	# Tunggu semua peserta terkunci (client lewat rpc_kirim_pilihan_elemen_duel,
	# AI lewat _ai_kunci_elemen_tertunda di atas) -- mungkin sudah tertampung duluan.
	for s in [slot_a, slot_d]:
		while not _pilihan_elemen_jaringan.has(s):
			await elemen_jaringan_diterima
	var elemen = {slot_a: _pilihan_elemen_jaringan[slot_a], slot_d: _pilihan_elemen_jaringan[slot_d]}
	_duel_mengumpulkan = false
	ui_elemen.hide()

	# Pool angka_penyerang/angka_pembela tetap (bukan diacak), jadi tinggal
	# pakai mesin_acak milik host untuk memilih satu nilai. Slot bernomor kecil
	# diundi lebih dulu (urutan lama 1v1: slot 0 lalu slot 1).
	var pool = {slot_a: ui_elemen.angka_penyerang, slot_d: ui_elemen.angka_pembela}
	var angka = {}
	for s in [mini(slot_a, slot_d), maxi(slot_a, slot_d)]:
		angka[s] = pool[s][mesin_acak.randi_range(0, pool[s].size() - 1)]

	# Saklar uji UJI_SERI: ganti kedua angka dengan pasangan yang membuat skor
	# akhir sama, supaya lempar koin penentu seri pasti muncul.
	if UJI_SERI:
		var angka_seri = ui_elemen.cari_angka_seri("pemain", elemen[slot_a], elemen[slot_d], nyawa_kandang, bonus_pedang)
		if not angka_seri.is_empty():
			angka[slot_a] = angka_seri[0]
			angka[slot_d] = angka_seri[1]

	var naskah = {
		"slot_a": slot_a, "slot_d": slot_d,
		"elemen_a": elemen[slot_a], "elemen_d": elemen[slot_d],
		"angka_a": angka[slot_a], "angka_d": angka[slot_d],
		# Bonus kartu pedang penyerang ikut dikirim: semua device WAJIB menghitung
		# skor dengan angka yang sama persis. Tanpa ini, host bisa melihat SERI
		# sementara client tidak -- host lalu menunggu pilihan koin yang tidak
		# akan pernah datang, dan duel membeku.
		"bonus_pedang": bonus_pedang,
	}
	_lengkapi_koin_naskah(naskah, nyawa_kandang)
	return naskah

func _kunci_elemen_peserta(slot: int, elemen: String) -> void:
	# HOST: peserta "slot" baru mengunci elemen "elemen". Dicatat SEKALI (dipanggil
	# dari beberapa jalur -- klik lokal, RPC client, AI, atau device yang putus --
	# jadi dijaga supaya tidak tercatat dua kali), lalu segel LOCKED disiarkan ke
	# SEMUA device (bukan hanya ke lawannya) -- termasuk penonton yang sejak awal
	# fase pilih elemen sudah membuka layar duel mode tonton.
	if _pilihan_elemen_jaringan.has(slot):
		return
	_pilihan_elemen_jaringan[slot] = elemen
	_siarkan_segel_terkunci(slot)
	elemen_jaringan_diterima.emit(slot)

func _siarkan_segel_terkunci(slot: int) -> void:
	# HOST.
	_tampilkan_segel_terkunci(slot)
	if StatusJaringan.peran_multiplayer == "host":
		rpc("rpc_segel_terkunci", slot)

@rpc("authority", "call_remote", "reliable")
func rpc_segel_terkunci(slot: int) -> void:
	_tampilkan_segel_terkunci(slot)

func _tampilkan_segel_terkunci(slot: int) -> void:
	# SEMUA device: gambar segel LOCKED milik "slot" di sisi yang benar pada
	# layar duel ini, dan -- kalau device ini sedang menonton (belum ikut
	# memilih) -- perbarui judulnya juga.
	if _duel_slot_penyerang < 0 or _duel_slot_pembela < 0:
		return
	var sisi_p = _sisi_p_duel(_duel_slot_penyerang, _duel_slot_pembela)
	var nama = ui_elemen.nama_sisi_p if slot == sisi_p else ui_elemen.nama_sisi_m
	if slot == sisi_p:
		ui_elemen.pemain_siap = true
	else:
		ui_elemen.musuh_siap = true
	ui_elemen.queue_redraw()
	if ui_elemen.mode_tonton:
		ui_elemen.teks_judul.text = nama + " LOCKED IN!"
	elif slot != sisi_p and ui_elemen.fase_duel == "PILIH_PEMAIN" and not ui_elemen.pemain_siap:
		ui_elemen.teks_judul.text = nama + " CHOSE! YOUR TURN!"

func _siapkan_pilihan_elemen_lokal() -> void:
	# Menyiapkan UI elemen & mengaktifkan tombolnya (sinkron). Dipisah dari
	# _tunggu_klik_elemen_lokal() supaya bisa dipanggil SEBELUM menunggu -- host
	# yang jadi peserta duel harus sudah membuka layar pilih elemennya sendiri
	# sebelum timer "berpikir" AI lawannya berjalan (lihat _kumpulkan_naskah_duel).
	ui_elemen.siapkan_pilih_elemen("CHOOSE YOUR ELEMENT!")
	for btn in ui_elemen.tombol_elemen.values(): btn.disabled = false

func _tunggu_klik_elemen_lokal() -> String:
	# Menunggu pemain di device INI memilih elemennya. UI-nya WAJIB sudah
	# disiapkan lebih dulu lewat _siapkan_pilihan_elemen_lokal() -- fase_duel
	# WAJIB "PILIH_PEMAIN": tombol elemen punya penjaga
	# "if fase_duel != PILIH_PEMAIN: return", jadi tanpa ini semua klik
	# diabaikan diam-diam dan duel menggantung selamanya.
	var generasi = _generasi_jaringan
	var pilihan = await ui_elemen.elemen_diklik
	if generasi != _generasi_jaringan:
		return "" # host sudah keluar di tengah jalan -- layar ini sudah ditutup
	for btn in ui_elemen.tombol_elemen.values(): btn.disabled = true

	# Munculkan segel "LOCKED" di sisi sendiri — di alur asli ini dilakukan baris
	# "pemain_siap = true" di dalam jalankan_duel, yang tidak dilewati di jalur
	# multiplayer karena pemilihan terjadi sebelum fungsi itu dipanggil.
	ui_elemen.pemain_siap = true
	ui_elemen.elemen_pilihan_pemain = pilihan
	ui_elemen.elemen_fokus = ""
	ui_elemen.queue_redraw()

	ui_elemen.teks_judul.text = "WAITING FOR OPPONENT..."
	ui_elemen.teks_judul.modulate = Color.WHITE
	return pilihan

func _tunggu_pilihan_elemen_lokal() -> String:
	# Pembungkus: dipakai rpc_minta_pilihan_elemen_duel (CLIENT peserta), yang
	# layar duelnya baru dibuka saat itu juga -- beda dengan host peserta yang
	# harus membuka layarnya lebih dulu lewat _siapkan_pilihan_elemen_lokal()
	# sebelum menunggu (lihat _kumpulkan_naskah_duel).
	_siapkan_pilihan_elemen_lokal()
	return await _tunggu_klik_elemen_lokal()

@rpc("authority", "call_remote", "reliable")
func rpc_duel_dimulai(slot_a: int, slot_d: int) -> void:
	# Diterima di device PENONTON (bukan peserta duel; host memanggilnya juga
	# secara lokal kalau HOST sendiri yang menonton) -- duel sudah mulai, peserta
	# sedang memilih elemen. Sejak baris ini layar duel mode tonton langsung
	# dibuka (dulu cuma teks placeholder sampai "BOTH LOCKED!"), jadi segel
	# LOCKED tiap peserta (lewat rpc_segel_terkunci) langsung terlihat satu per satu.
	_duel_slot_penyerang = slot_a
	_duel_slot_pembela = slot_d
	menu_aksi.hide()
	teks_uang.hide()
	teks_bintang.hide()
	teks_dadu.hide()
	if not (pemutar_bgm_duel and pemutar_bgm_duel.playing):
		AudioGrafis.mulai_musik_duel(self)
	_atur_nama_duel(slot_a, slot_d)
	ui_elemen.siapkan_tonton_pilih_elemen(ui_elemen._kata_serang(ui_elemen.nama_sisi_p) + " CHOOSING ELEMENTS...")

@rpc("authority", "call_remote", "reliable")
func rpc_minta_pilihan_elemen_duel(slot_a: int = 1, slot_d: int = 0) -> void:
	# Diterima di CLIENT peserta duel. Host minta kita menunjukkan pilihan elemen
	# sendiri. Sembunyikan HUD dan mainkan musik duel supaya suasananya sama
	# dengan host — di host hal ini terjadi di dalam _mulai_duel, yang tidak
	# pernah berjalan di sisi client.
	_duel_slot_penyerang = slot_a
	_duel_slot_pembela = slot_d
	menu_aksi.hide()
	teks_uang.hide()
	teks_bintang.hide()
	teks_dadu.hide()
	AudioGrafis.mulai_musik_duel(self)
	_atur_nama_duel(slot_a, slot_d)

	var pilihan = await _tunggu_pilihan_elemen_lokal()
	if pilihan == "" or StatusJaringan.peran_multiplayer != "client":
		return
	rpc_id(1, "rpc_kirim_pilihan_elemen_duel", pilihan)

@rpc("any_peer", "call_remote", "reliable")
func rpc_kirim_pilihan_elemen_duel(elemen: String) -> void:
	# Diterima di HOST -- ini yang membangunkan await di _kumpulkan_naskah_duel.
	if not multiplayer.is_server():
		return
	var slot = _slot_dari_peer(multiplayer.get_remote_sender_id())
	if slot != _duel_slot_penyerang and slot != _duel_slot_pembela:
		return
	if not ui_elemen.DATA_ELEMEN.has(elemen) or _pilihan_elemen_jaringan.has(slot):
		return
	_kunci_elemen_peserta(slot, elemen)

@rpc("authority", "call_remote", "reliable")
func rpc_mulai_replay_duel(nyawa_kandang: int, naskah: Dictionary) -> void:
	# Diterima di CLIENT (peserta maupun penonton). Jalankan animasi yang identik
	# dengan host lewat naskah yang sudah lengkap -- tidak menunggu klik atau
	# mengacak apapun sendiri. Hasilnya MURNI TAMPILAN: angka uang/HP yang
	# sebenarnya tetap datang lewat siaran state seperti biasa.
	# Naskah ditulis dalam slot; _naskah_lokal menerjemahkannya ke sudut pandang
	# layar INI -- segilima yang tersorot, teks menang/kalah, sampai kembang api vs
	# hujan otomatis benar tanpa mengubah kode penggambaran duel.
	var slot_a = int(naskah["slot_a"])
	var slot_d = int(naskah["slot_d"])
	var sisi_p = _sisi_p_duel(slot_a, slot_d)
	_atur_nama_duel(slot_a, slot_d)
	menu_aksi.hide()
	teks_uang.hide()
	teks_bintang.hide()
	teks_dadu.hide()

	# Musik duel di client peserta sudah dimulai saat diminta memilih elemen
	# (rpc_minta_pilihan_elemen_duel). Memanggilnya lagi di sini akan mengulang
	# lagu dari awal tepat sebelum "UNLOCKING" -- jadi hanya mulai kalau belum jalan.
	if not (pemutar_bgm_duel and pemutar_bgm_duel.playing):
		AudioGrafis.mulai_musik_duel(self)
	_replay_duel_berjalan = true
	var siapa_lokal = "pemain" if sisi_p == slot_a else "musuh"
	await ui_elemen.jalankan_duel(siapa_lokal, nyawa_kandang, kamera, teks_dadu, naskah.get("bonus_pedang", 0), _naskah_lokal(naskah, sisi_p))
	AudioGrafis.kembali_ke_musik_normal(self)
	teks_uang.show()
	teks_bintang.show()
	teks_dadu.show()
	_replay_duel_berjalan = false
	replay_duel_selesai.emit()

# ========================================================
# LEMPAR KOIN PENENTU SERI (MULTIPLAYER)
# Tampilan & urutan klik (pembela duluan, penyerang dapat sisanya) diurus
# ui_elemen._pilih_koin_jaringan(). Bagian ini cuma mengantar pilihan antar
# device dan -- khusus host -- mengundi hasil koin setelah SEMUA peserta manusia
# memilih, lalu mengirim hasil yang sama ke semua layar. Peserta AI tidak perlu
# ditunggu: pilihannya sudah ada di naskah.
# ========================================================

func _saat_koin_seri_lokal_dipilih(pilihan: String) -> void:
	# Tersambung ke sinyal ui_elemen.koin_lokal_dikunci (hanya di multiplayer).
	# BUKAN "client" (bukan cuma "host"): device yang tadinya host tapi lawan
	# satu-satunya sudah keluar di tengah duel ini jadi peran_multiplayer="" --
	# tetap satu-satunya otoritas lokal, jadi pilihannya WAJIB diproses di sini
	# juga (dulu diam saja -> _koin_seri_wajib tidak pernah lunas -> MACET).
	if StatusJaringan.peran_multiplayer == "client":
		rpc_id(1, "rpc_kirim_pilihan_koin_seri", pilihan)
	else:
		_terima_pilihan_koin(slot_lokal, pilihan)

@rpc("any_peer", "call_remote", "reliable")
func rpc_kirim_pilihan_koin_seri(pilihan: String) -> void:
	# Diterima di HOST: client peserta duel sudah memilih sisi koinnya.
	if not multiplayer.is_server():
		return
	var slot = _slot_dari_peer(multiplayer.get_remote_sender_id())
	if slot != _duel_slot_penyerang and slot != _duel_slot_pembela:
		return
	if pilihan != "kepala" and pilihan != "ekor":
		return
	_terima_pilihan_koin(slot, pilihan)

func _terima_pilihan_koin(slot: int, pilihan: String) -> void:
	# HOST. Pilihan PEMBELA menentukan tombol mana yang diabu-abukan di layar
	# penyerang, dan yang ditampilkan di layar penonton -- jadi diteruskan ke
	# semua device selain milik pembela itu sendiri.
	if _koin_seri_pilihan.has(slot):
		return
	_koin_seri_pilihan[slot] = pilihan
	if slot == _duel_slot_pembela:
		_rpc_ke_klien_kecuali([_peer_slot(slot)], "rpc_pilihan_koin_seri_lawan", [pilihan])
		if slot != slot_lokal:
			ui_elemen.terima_pilihan_koin_lawan(pilihan)
	_undi_koin_seri_jika_lengkap()

@rpc("authority", "call_remote", "reliable")
func rpc_pilihan_koin_seri_lawan(pilihan: String) -> void:
	# Diterima di CLIENT: sisi koin yang dipilih pembela.
	ui_elemen.terima_pilihan_koin_lawan(pilihan)

func _undi_koin_seri_jika_lengkap() -> void:
	# HOST ONLY.
	if _koin_seri_wajib.is_empty():
		return
	for s in _koin_seri_wajib:
		if not _koin_seri_pilihan.has(s):
			return
	_koin_seri_wajib.clear()
	_koin_seri_pilihan.clear()
	var hasil = "kepala" if mesin_acak.randi_range(0, 1) == 0 else "ekor"
	rpc("rpc_hasil_koin_seri", hasil)
	ui_elemen.terima_hasil_koin(hasil)

@rpc("authority", "call_remote", "reliable")
func rpc_hasil_koin_seri(hasil: String) -> void:
	# Diterima di CLIENT: hasil undian host, supaya koin di semua layar jatuh
	# di sisi yang sama.
	ui_elemen.terima_hasil_koin(hasil)

# =========================================================
# FUNGSI SENTRAL PERTARUNGAN (KINI SANGAT BERSIH & SIMPEL)
# =========================================================
func eksekusi_dadu_pertarungan(hasil_duel: Dictionary, slot_penyerang: int, slot_pembela: int):
	# hasil_duel dari _jalankan_duel: {"slot_pemenang", "poin_sisa"}.
	# ========================================================
	# PERBAIKAN 3: Tampilkan kembali UI setelah duel usai
	# ========================================================
	teks_uang.show()
	teks_bintang.show()
	teks_dadu.show()

	# Fase 2: statistik duel (penghargaan DUEL KING & misi).
	var slot_menang_duel = int(hasil_duel["slot_pemenang"])
	_tambah_stat(slot_menang_duel, "duel_menang")
	_tambah_stat(slot_pembela if slot_menang_duel == slot_penyerang else slot_penyerang, "duel_kalah")
	_tambah_stat_elemen(slot_menang_duel, str(hasil_duel.get("elemen_pemenang", "")))
	if slot_menang_duel == slot_penyerang:
		_tambah_stat(slot_penyerang, "petak_rebut")

	if hasil_duel["slot_pemenang"] == slot_penyerang:
		_hasil_duel_petak(slot_penyerang, slot_pembela, true)
	else:
		_hasil_duel_petak(slot_penyerang, slot_pembela, false, hasil_duel["poin_sisa"])

func _selesaikan_tanah_setelah_duel(posisi: int) -> void:
	# B-b bagian 4 (temuan 9): keputusan SESUNGGUHNYA soal jebakan tanah di petak
	# ini bertahan atau hancur -- dipanggil DI SINI (dari _hasil_duel_petak, bukan
	# _pantau_duel_berlangsung/jebakan_tanah.gd) karena di sinilah pemilik_petak
	# sudah pasti mutakhir untuk duel yang baru saja selesai. Dipanggil dari KEDUA
	# cabang (menang/kalah), SEBELUM _tanah_saat_duel dikosongkan.
	if not bool(_tanah_saat_duel.get("ada", false)) or int(_tanah_saat_duel.get("posisi", -1)) != posisi:
		return
	var pemilik_jebakan = int(_tanah_saat_duel.get("pemilik", -1))
	if pemilik_jebakan < 0:
		return
	var jebakan = rute_papan[posisi].get_node_or_null("JebakanTanah")
	if jebakan == null:
		return
	if pemilik_petak[posisi] != pemilik_jebakan:
		# Petak berganti pemilik (direbut, atau tetap di tangan lain) -- jebakan
		# lama sudah tidak relevan.
		jebakan.queue_free()
		return
	# Masih milik pemasang. Sacred Ground (Ultimate, bagian 5) tidak ikut
	# berkurang hitungannya -- bertahan sampai petak sungguh berganti pemilik.
	if bool(jebakan.sacred):
		jebakan.aktifkan_kembali()
		return
	jebakan.sisa_duel -= 1
	if jebakan.sisa_duel <= 0:
		jebakan.queue_free()
	else:
		jebakan.aktifkan_kembali()

func _hasil_duel_petak(slot_penyerang: int, slot_pembela: int, penyerang_menang: bool, sisa_poin_pembela: int = 999) -> void:
	var posisi = daftar_pemain[slot_penyerang].posisi_saat_ini
	if penyerang_menang:
		teks_dadu.text = _teks_rebut(slot_penyerang, slot_pembela)
		status_kepemilikan_petak[posisi] = true
		pemilik_petak[posisi] = slot_penyerang
		_atur_berhenti_petak(posisi, 0)
		var lvl = level_menara_petak[posisi]
		nyawa_petak[posisi] = 3 if lvl == 0 else (4 if lvl == 1 else 5)
		_selesaikan_tanah_setelah_duel(posisi) # Fase 4 (temuan 9): SEBELUM dikosongkan.
		_tanah_saat_duel = {} # Fase 4 (A2): tidak dibutuhkan lagi setelah hasil ditentukan.

		update_semua_label_petak()
		_siarkan_kondisi_petak(posisi, true, slot_pembela)

		await label_petak_3d[posisi].mainkan_efek_rebut(_aktor_dari_slot(slot_penyerang))
		await get_tree().create_timer(0.8).timeout

		tombol_tutup.disabled = false
		await get_tree().create_timer(3.0).timeout
		ganti_giliran()
	else:
		if sisa_poin_pembela < nyawa_petak[posisi]:
			nyawa_petak[posisi] = max(1, sisa_poin_pembela)
			update_semua_label_petak()
			_siarkan_kondisi_petak(posisi, false, slot_pembela)
		# Fase 4 (A4): Rock Breaker (data_role.gd) memotong tambahan denda kalau
		# penyerang punya node itu DAN petak ini punya jebakan tanah saat duel mulai.
		var pengali = _pengali_kalah_duel(slot_penyerang, posisi)
		_selesaikan_tanah_setelah_duel(posisi) # Fase 4 (temuan 9): SEBELUM dikosongkan.
		_tanah_saat_duel = {}
		_bayar_denda(slot_penyerang, slot_pembela, pengali)

func hasil_akhir_pertarungan_pemain(pemain_menang, sisa_poin_pembela = 999):
	_hasil_duel_petak(0, 1, pemain_menang, sisa_poin_pembela)

func hasil_akhir_pertarungan_musuh(musuh_menang, sisa_poin_pembela = 999):
	_hasil_duel_petak(1, 0, musuh_menang, sisa_poin_pembela)
