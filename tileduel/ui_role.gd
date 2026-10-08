class_name UiRole
# ============================================================
# UI ROLE (Fase 4 Langkah A6): layar "CHOOSE YOUR ROLE" -- dipakai SOLO
# (main_menu.gd, sesudah SELECT STAGE) dan LOBBY multiplayer (layar_local_play.gd,
# tombol "MY ROLE"). Semua fungsi static, dipanggil lewat nama kelas
# (UiRole.xxx) -- pola sama dengan UiProfil (dan memakai pembantu-pembantu
# UiProfil/UiDinamis yang sudah ada, bukan menulis ulang gaya tombol/kartu).
# Data angka/nama/warna dari DataRole (class_name statis, aman dipanggil di
# mana pun). Teks untuk pemain = bahasa Inggris sederhana.
# ============================================================

const EMAS := Color(1.0, 0.85, 0.2)
const ABU := Color(0.75, 0.75, 0.8)

# konteks (Dictionary, semua opsional kecuali disebutkan "wajib" di bawah):
#   "role": String            -- role terpilih awal ("" = belum pernah pilih)
#   "jebakan": Array           -- jenis tambahan terakhir (role selalu ditambahkan sendiri)
#   "jumlah_jenis": int        -- WAJIB secara praktik: total jenis jebakan yang boleh dibawa
#                                  (solo: DataRole.slot_jebakan_solo(level); lobby: DataRole.SLOT_JEBAKAN_MP)
#   "teks_tombol": String      -- teks tombol konfirmasi ("START" solo / "OK" lobby)
#   "petunjuk_level": bool     -- true (default): tampilkan "Level N: bring M traps" (solo saja)
#   "boleh_batal": bool        -- true: tampilkan tombol BACK
#   "batal": Callable          -- dipanggil kalau BACK ditekan (tanpa argumen)
#   "lapisan": int             -- layer CanvasLayer (default 11)
# selesai: Callable(role: String, jebakan: Array) -- dipanggil sekali saat tombol
# konfirmasi ditekan; layar ROLE sudah membuang dirinya sendiri saat ini dipanggil.
static func buka_pilih_role(induk: Node, konteks: Dictionary, selesai: Callable) -> CanvasLayer:
	var jumlah_jenis: int = int(konteks.get("jumlah_jenis", DataRole.SLOT_JEBAKAN_MP))
	var role0: String = str(konteks.get("role", ""))
	if role0 != "" and not DataRole.ROLE.has(role0):
		role0 = ""
	var jebakan0: Array = (konteks.get("jebakan", []) as Array).duplicate()
	if role0 != "" and not jebakan0.has(role0):
		jebakan0.insert(0, role0)
	# State DIBAGI lewat SATU Dictionary yang ISINYA diubah (state["role"] = ...),
	# bukan lewat menimpa variabel lokal biasa -- lambda GDScript menangkap
	# variabel lokal primitif lewat NILAI saat closure dibuat, jadi hanya
	# Dictionary/Array/Node (tipe referensi) yang aman dibagi antar closure
	# tombol di bawah.
	var state := {"role": role0, "jebakan": jebakan0}
	var teks_tombol: String = str(konteks.get("teks_tombol", "START"))
	var petunjuk_level: bool = bool(konteks.get("petunjuk_level", true))

	var kanvas = UiProfil._layar_gelap(induk, int(konteks.get("lapisan", 11)))
	var isi = UiProfil._kartu_tengah(kanvas, true)
	isi.custom_minimum_size = Vector2(560, 0)

	isi.add_child(UiProfil._label("CHOOSE YOUR ROLE", 30, EMAS))

	var baris_role = GridContainer.new()
	baris_role.columns = 5
	baris_role.add_theme_constant_override("h_separation", 10)
	baris_role.add_theme_constant_override("v_separation", 10)
	baris_role.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	isi.add_child(baris_role)

	var lbl_ket = UiProfil._label("", 17)
	lbl_ket.custom_minimum_size = Vector2(500, 0)
	lbl_ket.autowrap_mode = TextServer.AUTOWRAP_WORD
	isi.add_child(lbl_ket)

	var lbl_bawa = UiProfil._label("", 18, ABU)
	isi.add_child(lbl_bawa)

	var baris_jebakan = GridContainer.new()
	baris_jebakan.columns = 4
	baris_jebakan.add_theme_constant_override("h_separation", 8)
	baris_jebakan.add_theme_constant_override("v_separation", 8)
	baris_jebakan.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	isi.add_child(baris_jebakan)

	var lbl_petunjuk = UiProfil._label("", 14, ABU)
	isi.add_child(lbl_petunjuk)

	# Placeholder dibuat SEKARANG (bukan lewat UiProfil._tombol nanti) supaya
	# closure "segarkan" di bawah menangkap OBJEK tombolnya, bukan null --
	# properti tombol ini (.disabled dst) yang diubah belakangan, bukan
	# variabelnya sendiri ditimpa (lihat catatan "state" di atas).
	var tombol_role: Dictionary = {}
	var tombol_jebakan: Dictionary = {}
	var btn_mulai := Button.new()

	var segarkan := func():
		var r_sel: String = state["role"]
		var j_sel: Array = state["jebakan"]
		for r in DataRole.ROLE:
			var b: Button = tombol_role[r]
			var terpilih = (r == r_sel)
			UiDinamis._gaya_tombol(b, DataRole.warna_role(r) if terpilih else DataRole.warna_role(r).darkened(0.55))
			b.add_theme_color_override("font_color", Color(1, 1, 1, 1.0 if terpilih else 0.65))
		if r_sel == "":
			lbl_ket.text = "Pick a role to see its trap and resistances."
			lbl_bawa.text = ""
		else:
			lbl_ket.text = "%s - Your trap: %s Trap. Tough against: %s." % [
				DataRole.nama_role(r_sel), DataRole.nama_role(r_sel).capitalize(), DataRole.teks_tahan_role(r_sel)]
			lbl_bawa.text = "TRAPS YOU BRING %d/%d" % [j_sel.size(), jumlah_jenis]
		for e in tombol_jebakan.keys():
			var bj: Button = tombol_jebakan[e]
			var dibawa = j_sel.has(e)
			var terkunci = (e == r_sel)
			bj.disabled = terkunci or r_sel == "" or (not dibawa and j_sel.size() >= jumlah_jenis)
			UiDinamis._gaya_tombol(bj, DataRole.warna_role(e) if dibawa else Color(0.3, 0.3, 0.35))
			bj.text = DataRole.nama_role(e) + (" (Role)" if terkunci else (" ✓" if dibawa else ""))
		btn_mulai.disabled = r_sel == ""
		if petunjuk_level:
			_isi_petunjuk_slot(lbl_petunjuk, j_sel.size())

	for r in DataRole.ROLE:
		var b = UiProfil._tombol(DataRole.nama_role(r), DataRole.warna_role(r), Vector2(96, 64), 16)
		tombol_role[r] = b
		baris_role.add_child(b)
		b.pressed.connect(func():
			# Ganti role: jebakan role lama yang bukan role baru tetap dipakai
			# kalau masih muat (UX lebih enak daripada mengosongkan semuanya).
			var j: Array = (state["jebakan"] as Array).filter(func(x): return x != r)
			j.insert(0, r)
			while j.size() > jumlah_jenis:
				j.pop_back()
			state["role"] = r
			state["jebakan"] = j
			segarkan.call()
		)

	for e in DataRole.ROLE:
		var bj = UiProfil._tombol(DataRole.nama_role(e), Color(0.3, 0.3, 0.35), Vector2(112, 48), 15)
		tombol_jebakan[e] = bj
		baris_jebakan.add_child(bj)
		bj.pressed.connect(func():
			if e == str(state["role"]):
				return
			var j: Array = (state["jebakan"] as Array).duplicate()
			if j.has(e):
				j.erase(e)
			elif j.size() < jumlah_jenis:
				j.append(e)
			state["jebakan"] = j
			segarkan.call()
		)

	var baris_tombol = HBoxContainer.new()
	baris_tombol.alignment = BoxContainer.ALIGNMENT_CENTER
	baris_tombol.add_theme_constant_override("separation", 16)
	isi.add_child(baris_tombol)

	if bool(konteks.get("boleh_batal", false)):
		var btn_batal = UiProfil._tombol("BACK", Color(0.5, 0.2, 0.2), Vector2(150, 56), 20)
		baris_tombol.add_child(btn_batal)
		btn_batal.pressed.connect(func():
			kanvas.queue_free()
			var batal: Callable = konteks.get("batal", Callable())
			if batal.is_valid():
				batal.call()
		)

	btn_mulai.text = teks_tombol
	btn_mulai.custom_minimum_size = Vector2(220, 60)
	btn_mulai.add_theme_font_size_override("font_size", 22)
	UiDinamis._gaya_tombol(btn_mulai, Color(0.15, 0.55, 0.25))
	baris_tombol.add_child(btn_mulai)
	btn_mulai.pressed.connect(func():
		if str(state["role"]) == "":
			return
		btn_mulai.disabled = true
		var role_akhir: String = state["role"]
		var jebakan_akhir: Array = (state["jebakan"] as Array).duplicate()
		kanvas.queue_free()
		selesai.call(role_akhir, jebakan_akhir)
	)

	segarkan.call()
	return kanvas

static func _isi_petunjuk_slot(lbl: Label, jumlah_sekarang: int) -> void:
	# "Level N: bring M traps" -- tingkat SLOT_JEBAKAN_SOLO berikutnya di atas
	# jumlah sekarang (list-nya terurut dari syarat level TERTINGGI ke
	# terendah, jadi hasil akhir loop ini otomatis yang PALING DEKAT). Kosong
	# kalau sudah maksimal (5 jenis) -- multiplayer (petunjuk_level=false)
	# tidak pernah memanggil fungsi ini sama sekali.
	var berikut := ""
	for pasangan in DataRole.SLOT_JEBAKAN_SOLO:
		if int(pasangan[1]) > jumlah_sekarang:
			berikut = "Level %d: bring %d traps" % [int(pasangan[0]), int(pasangan[1])]
	lbl.text = berikut
