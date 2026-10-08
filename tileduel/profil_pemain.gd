extends Node
# ============================================================
# PROFIL PEMAIN (Fase 2) -- autoload "ProfilPemain".
# Profil di HP ini: nama, XP (-> Level Pemain), Crowns, statistik seumur main,
# misi harian, dan hadiah login 7 hari. Semua angka aturan ada di KONSTANTA.
# Data lokal: pemain yang sangat niat masih bisa mengubah berkas / jam HP (diterima).
# PENTING:
# - Autoload -> JANGAN pakai "static func" untuk fungsi yang dipanggil lewat
#   ProfilPemain.xxx() (peringatan STATIC_CALLED_ON_INSTANCE).
# - Pengacak SENDIRI (_rng). randi()/randf()/pick_random()/shuffle() memakai pengacak
#   GLOBAL yang juga dipakai permainan -- jejak uji harus tetap sama persis.
# ============================================================

signal profil_berubah

const BERKAS := "user://profil.cfg"
const BERKAS_SEMENTARA := "user://profil.cfg.tmp"
const BERKAS_CADANGAN := "user://profil.cfg.bak"
const VERSI := 2 # Fase 4: + role_terakhir, jebakan_role (A), xp_role/build_solo/arena (B, belum dipakai)

# --- XP & Crowns per pertandingan ---
const XP_PER_GILIRAN := 5
const CROWNS_PER_GILIRAN := 2
const PENGALI_QUICK := 1.0
const PENGALI_CLASSIC := 1.6
const BONUS_MENANG := 1.5
const XP_PENGHARGAAN := 15
const CROWNS_PENGHARGAAN := 10
# --- Level: Lv L -> L+1 butuh 100 + 25 x (L-1) XP. Tanpa batas. ---
const XP_LEVEL_AWAL := 100
const XP_TAMBAH_PER_LEVEL := 25
const CROWNS_NAIK_LEVEL := 10 # x level baru (naik ke Lv 3 = +30 Crowns)
# --- Login 7 hari: hari yang terlewat TIDAK mengulang ke Hari 1 ---
const HADIAH_LOGIN := [20, 30, 40, 50, 60, 80, 150]
const XP_LOGIN_HARI_7 := 50
# --- Penghargaan akhir (dihitung host/solo lewat hitung_penghargaan) ---
const NAMA_PENGHARGAAN := {
	"duel_king": "DUEL KING",
	"trap_master": "TRAP MASTER",
	"landlord": "LANDLORD",
	"lucky_roller": "LUCKY ROLLER",
}
const MIN_LEMPARAN_LUCKY := 3
# --- Misi harian: 1 mudah + 1 sedang + 1 sulit per hari; semua bisa selesai di solo ---
# "stat" = kunci statistik pertandingan (pemain.gd statistik_slot), atau khusus:
# "_match" tiap pertandingan tuntas, "_menang", "_penghargaan", "_elemen".
const MISI := {
	"main_match": {"tingkat": 0, "teks": "Finish 2 matches", "target": 2, "stat": "_match"},
	"pasang_jebakan": {"tingkat": 0, "teks": "Set 3 traps", "target": 3, "stat": "jebakan_pasang"},
	"beli_petak": {"tingkat": 0, "teks": "Buy 5 tiles", "target": 5, "stat": "petak_beli"},
	"lewat_start": {"tingkat": 0, "teks": "Pass START 3 times", "target": 3, "stat": "lewat_start"},
	"menang_match": {"tingkat": 1, "teks": "Win 1 match", "target": 1, "stat": "_menang"},
	"menang_duel": {"tingkat": 1, "teks": "Win 2 duels", "target": 2, "stat": "duel_menang"},
	"permata": {"tingkat": 1, "teks": "Collect 2 gems", "target": 2, "stat": "permata"},
	"pakai_kartu": {"tingkat": 1, "teks": "Use 2 cards", "target": 2, "stat": "kartu_pakai"},
	"penghargaan": {"tingkat": 1, "teks": "Earn 1 award", "target": 1, "stat": "_penghargaan"},
	"duel_elemen": {"tingkat": 2, "teks": "Win a duel with %s", "target": 1, "stat": "_elemen"},
	"kena_jebakan": {"tingkat": 2, "teks": "Catch rivals with your traps 2 times", "target": 2, "stat": "jebakan_kena"},
	"menara_lv2": {"tingkat": 2, "teks": "Build a Lv 2 tower", "target": 1, "stat": "menara_lv2"},
}
const HADIAH_MISI := [{"crowns": 20, "xp": 15}, {"crowns": 30, "xp": 25}, {"crowns": 45, "xp": 35}]
const NAMA_ELEMEN := {"api": "FIRE", "air": "WATER", "tanah": "EARTH", "petir": "LIGHTNING", "angin": "WIND"}
# Statistik pertandingan yang dijumlahkan ke statistik seumur main.
const STAT_SEUMUR := ["giliran", "duel_menang", "jebakan_pasang", "jebakan_kena", "petak_beli", "menara_lv2", "permata", "kartu_pakai", "lewat_start"]
# Filter nama sederhana (boleh ditambah). KATA_KASAR dicari di BAGIAN mana saja nama (setelah
# spasi dibuang dan angka mirip huruf diganti: 0->o 1->i 3->e 4->a 5->s 7->t @->a $->s);
# KATA_KASAR_UTUH hanya kalau SAMA dengan satu kata utuh (supaya "Asuka", "Taiga",
# "Hancock", "Scrape" tetap boleh).
const KATA_KASAR := ["fuck", "shit", "bitch", "cunt", "pussy", "asshole", "bastard", "whore", "slut",
	"nigger", "nigga", "faggot", "retard", "hitler", "penis", "vagina",
	"anjing", "anjeng", "bangsat", "kontol", "memek", "ngentot", "ngewe", "jancok", "jancuk",
	"goblok", "goblog", "tolol", "kampret", "pepek", "peler", "titit", "pantek", "bajingan",
	"keparat", "lonte", "pelacur", "bokep", "colmek", "jembut", "kimak", "sundal"]
const KATA_KASAR_UTUH := ["ass", "sex", "fck", "fuk", "sht", "dick", "cock", "nazi", "rape", "porn",
	"boob", "tits", "cok", "asu", "tai", "anj", "bgst", "kntl", "mmk", "babi", "coli", "itil",
	"puki", "perek", "sange", "ngentd"]

var id := ""                   # 16 hex acak (untuk Fase 6: kartu profil / Respect)
var nama := ""
var xp_total := 0
var crowns := 0
var statistik := {}            # statistik seumur main
var misi: Array = []           # 3 x {"id", "progres", "selesai", "elemen"}
var tanggal_misi := ""
var ganti_misi_dipakai := false  # CHANGE gratis 1x per hari
var hari_login := 1            # hadiah login berikutnya: Hari 1..7
var tanggal_login := ""        # tanggal klaim login terakhir ("" = belum pernah)
var _double_terpakai := false  # DOUBLE untuk pertandingan terakhir sudah dipakai
var _tanggal_uji := ""         # HANYA uji: memaksa tanggal "YYYY-MM-DD"
var _rng := RandomNumberGenerator.new()

# --- Fase 4 Langkah A: role elemen ---
var role_terakhir := ""        # "" = belum pernah pilih role -> layar ROLE minta memilih
var jebakan_role := {}         # role -> Array jenis jebakan tambahan yang terakhir dipilih untuk role itu
# --- Fase 4 Langkah B: belum dipakai kode mana pun, disiapkan supaya berkas VERSI 2
# tidak perlu diubah lagi saat pohon skill ditulis. ---
var xp_role := {}              # role -> XP Role
var build_solo := {}           # role -> {node_id: level}
var arena := {}                # role -> {"preset": "balanced"|"attack"|"defense"|"custom", "node": {...}}

func _ready() -> void:
	_rng.randomize()
	muat()
	segarkan_hari()

# ============================================================
# SIMPAN / MUAT
# Ditulis ke berkas sementara dulu, lalu diganti nama. Berkas lama jadi cadangan.
# HP mati di tengah menyimpan -> muat() memakai berkas yang masih utuh.
# ============================================================
func muat() -> void:
	var c = _baca_berkas(BERKAS)
	if c == null:
		c = _baca_berkas(BERKAS_SEMENTARA)
	if c == null:
		c = _baca_berkas(BERKAS_CADANGAN)
	if c == null:
		_profil_baru()
		return
	id = str(c.get_value("profil", "id", ""))
	nama = str(c.get_value("profil", "nama", ""))
	xp_total = maxi(0, int(c.get_value("profil", "xp", 0)))
	crowns = maxi(0, int(c.get_value("profil", "crowns", 0)))
	var s = c.get_value("statistik", "isi", {})
	statistik = s if s is Dictionary else {}
	var m = c.get_value("misi", "daftar", [])
	misi = m if m is Array else []
	tanggal_misi = str(c.get_value("misi", "tanggal", ""))
	ganti_misi_dipakai = bool(c.get_value("misi", "ganti_dipakai", false))
	hari_login = clampi(int(c.get_value("login", "hari", 1)), 1, 7)
	tanggal_login = str(c.get_value("login", "tanggal", ""))
	if cek_nama(nama) != "":
		nama = _nama_bawaan()
	# Fase 4 -- berkas VERSI 1 tidak punya bagian "role" sama sekali: get_value
	# jatuh ke nilai bawaan di bawah, jadi tidak ada data lama yang hilang.
	role_terakhir = str(c.get_value("role", "terakhir", ""))
	var jr = c.get_value("role", "jebakan", {})
	jebakan_role = jr if jr is Dictionary else {}
	var xr = c.get_value("role", "xp", {})
	xp_role = xr if xr is Dictionary else {}
	var bs = c.get_value("role", "build_solo", {})
	build_solo = bs if bs is Dictionary else {}
	var ar = c.get_value("role", "arena", {})
	arena = ar if ar is Dictionary else {}

func _baca_berkas(jalur: String):
	# ConfigFile yang sah (terbaca & punya id), atau null.
	if not FileAccess.file_exists(jalur):
		return null
	var c = ConfigFile.new()
	if c.load(jalur) != OK or str(c.get_value("profil", "id", "")) == "":
		return null
	return c

func simpan() -> void:
	var c = ConfigFile.new()
	c.set_value("profil", "versi", VERSI)
	c.set_value("profil", "id", id)
	c.set_value("profil", "nama", nama)
	c.set_value("profil", "xp", xp_total)
	c.set_value("profil", "crowns", crowns)
	c.set_value("statistik", "isi", statistik)
	c.set_value("misi", "daftar", misi)
	c.set_value("misi", "tanggal", tanggal_misi)
	c.set_value("misi", "ganti_dipakai", ganti_misi_dipakai)
	c.set_value("login", "hari", hari_login)
	c.set_value("login", "tanggal", tanggal_login)
	c.set_value("role", "terakhir", role_terakhir)
	c.set_value("role", "jebakan", jebakan_role)
	c.set_value("role", "xp", xp_role)
	c.set_value("role", "build_solo", build_solo)
	c.set_value("role", "arena", arena)
	var err = c.save(BERKAS_SEMENTARA)
	if err != OK:
		push_warning("Profil gagal disimpan (kode %d)." % err)
		return
	if FileAccess.file_exists(BERKAS):
		if FileAccess.file_exists(BERKAS_CADANGAN):
			DirAccess.remove_absolute(BERKAS_CADANGAN)
		DirAccess.rename_absolute(BERKAS, BERKAS_CADANGAN)
	err = DirAccess.rename_absolute(BERKAS_SEMENTARA, BERKAS)
	if err != OK:
		push_warning("Profil gagal disimpan (ganti nama, kode %d)." % err)
	profil_berubah.emit()

func _profil_baru() -> void:
	id = "%08x%08x" % [_rng.randi(), _rng.randi()]
	nama = _nama_bawaan()
	xp_total = 0
	crowns = 0
	statistik = {}
	misi = []
	tanggal_misi = ""
	ganti_misi_dipakai = false
	hari_login = 1
	tanggal_login = ""
	role_terakhir = ""
	jebakan_role = {}
	xp_role = {}
	build_solo = {}
	arena = {}
	simpan()

func _nama_bawaan() -> String:
	return "Player%d" % _rng.randi_range(1000, 9999)

# ============================================================
# LEVEL
# ============================================================
func xp_untuk_naik(lv: int) -> int:
	# XP untuk naik dari level lv ke lv+1.
	return XP_LEVEL_AWAL + XP_TAMBAH_PER_LEVEL * (lv - 1)

func info_level(xp: int = -1) -> Dictionary:
	# {"level", "xp_dalam", "xp_butuh"} dari XP total (-1 = XP profil sekarang).
	var sisa = xp_total if xp < 0 else xp
	var lv = 1
	while sisa >= xp_untuk_naik(lv):
		sisa -= xp_untuk_naik(lv)
		lv += 1
	return {"level": lv, "xp_dalam": sisa, "xp_butuh": xp_untuk_naik(lv)}

func level_sekarang() -> int:
	return int(info_level()["level"])

func _tambah_xp(n: int) -> Dictionary:
	# XP bertambah; tiap level baru memberi Crowns (10 x level baru).
	var lama = level_sekarang()
	xp_total += maxi(0, n)
	var baru = level_sekarang()
	var bonus = 0
	for lv in range(lama + 1, baru + 1):
		bonus += CROWNS_NAIK_LEVEL * lv
	crowns += bonus
	return {"level_lama": lama, "level_baru": baru, "crowns_level": bonus}

# ============================================================
# STATISTIK PERTANDINGAN & PENGHARGAAN (dipakai pemain.gd)
# ============================================================
func statistik_kosong() -> Dictionary:
	return {"giliran": 0, "dadu_total": 0, "dadu_kali": 0, "duel_menang": 0, "duel_kalah": 0,
		"menang_elemen": {"api": 0, "air": 0, "tanah": 0, "petir": 0, "angin": 0}, "petak_rebut": 0,
		"jebakan_pasang": 0, "jebakan_kena": 0, "koin_jebakan": 0, "petak_beli": 0, "menara_bangun": 0,
		"menara_lv2": 0, "permata": 0, "lewat_start": 0, "kartu_pakai": 0}

func _nilai_stat(baris: Dictionary, kunci: String) -> int:
	var st = baris.get("stat", {})
	if not (st is Dictionary):
		return 0
	return int(st.get(kunci, 0))

func _rata_dadu(baris: Dictionary) -> float:
	var kali = _nilai_stat(baris, "dadu_kali")
	if kali < MIN_LEMPARAN_LUCKY:
		return -1.0
	return snappedf(float(_nilai_stat(baris, "dadu_total")) / float(kali), 0.01)

func hitung_penghargaan(papan: Array) -> Dictionary:
	# papan = baris papan skor ({"slot", "petak", "stat": {...}, ...}) semua slot.
	# Hasil: slot -> Array id penghargaan. Seri = semua yang seri mendapatkannya.
	var hasil = {}
	for baris in papan:
		hasil[int(baris["slot"])] = []
	# DUEL KING: menang duel terbanyak (minimal 1).
	_beri_tertinggi(hasil, papan, "duel_king", func(b): return [float(_nilai_stat(b, "duel_menang"))], 1.0)
	# TRAP MASTER: lawan terbanyak yang kena jebakannya; seri -> koin lawan yang hilang.
	_beri_tertinggi(hasil, papan, "trap_master", func(b): return [float(_nilai_stat(b, "jebakan_kena")), float(_nilai_stat(b, "koin_jebakan"))], 1.0)
	# LANDLORD: petak terbanyak di akhir (minimal 1).
	_beri_tertinggi(hasil, papan, "landlord", func(b): return [float(int(b.get("petak", 0)))], 1.0)
	# LUCKY ROLLER: rata-rata dadu tertinggi (minimal 3 lemparan).
	_beri_tertinggi(hasil, papan, "lucky_roller", func(b): return [_rata_dadu(b)], 0.0)
	return hasil

func _beri_tertinggi(hasil: Dictionary, papan: Array, id_penghargaan: String, nilai: Callable, minimal: float) -> void:
	# nilai(baris) -> [utama, penentu...]; dibandingkan berurutan. Utama < minimal = tidak ikut.
	var terbaik = []
	var calon = []
	for baris in papan:
		var v: Array = nilai.call(baris)
		if float(v[0]) < minimal:
			continue
		var banding = _banding(v, terbaik)
		if terbaik.is_empty() or banding > 0:
			terbaik = v
			calon = [int(baris["slot"])]
		elif banding == 0:
			calon.append(int(baris["slot"]))
	for s in calon:
		hasil[s].append(id_penghargaan)

func _banding(a: Array, b: Array) -> int:
	# 1 kalau a > b, -1 kalau a < b, 0 kalau sama (b kosong = a lebih besar).
	if b.is_empty():
		return 1
	for i in range(mini(a.size(), b.size())):
		if float(a[i]) > float(b[i]):
			return 1
		if float(a[i]) < float(b[i]):
			return -1
	return 0

# ============================================================
# HADIAH AKHIR PERTANDINGAN
# d = {"menang", "quick", "multiplayer", "stat", "penghargaan", "role"} untuk pemain
# di HP ini (pemain.gd _data_akhir_profil). Dipanggil SEKALI per pertandingan tuntas.
# ============================================================
func catat_akhir_match(d: Dictionary) -> Dictionary:
	segarkan_hari()
	_double_terpakai = false
	var st: Dictionary = d.get("stat", {})
	var menang: bool = bool(d.get("menang", false))
	var quick: bool = bool(d.get("quick", false))
	var peng: Array = d.get("penghargaan", [])
	var giliran = int(st.get("giliran", 0))
	var pengali = (PENGALI_QUICK if quick else PENGALI_CLASSIC) * (BONUS_MENANG if menang else 1.0)
	var xp_match = roundi(XP_PER_GILIRAN * giliran * pengali)
	var cr_match = roundi(CROWNS_PER_GILIRAN * giliran * pengali)
	var xp_peng = XP_PENGHARGAAN * peng.size()
	var cr_peng = CROWNS_PENGHARGAAN * peng.size()
	# Statistik seumur main.
	for k in STAT_SEUMUR:
		statistik[k] = int(statistik.get(k, 0)) + int(st.get(k, 0))
	_tambah_statistik("match")
	if menang:
		_tambah_statistik("menang")
	_tambah_statistik("match_quick" if quick else "match_classic")
	_tambah_statistik("penghargaan", peng.size())
	# Misi: hadiahnya langsung masuk saat selesai.
	var selesai = _majukan_misi(st, menang, peng.size())
	var xp_misi = 0
	var cr_misi = 0
	for ms in selesai:
		xp_misi += int(ms["xp"])
		cr_misi += int(ms["crowns"])
	# Fase 4 (4c/B1): XP Role -- HANYA kalau pemain sudah pilih role match ini
	# (d["role"], lihat pemain.gd _data_akhir_profil). Pengali sama dengan XP
	# profil TAPI TANPA BONUS_MENANG (menang sudah dihitung sendiri lewat
	# XP_ROLE["menang"], supaya tidak dobel). Dibaca kartu hadiah (ui_profil.gd
	# buat_kartu_hadiah/_tulis_baris_role, B1).
	var role: String = str(d.get("role", ""))
	var xp_role_match = 0
	var role_lv_awal = 0
	var role_lv_akhir = 0
	if role != "" and DataRole.ROLE.has(role):
		var pengali_role = PENGALI_QUICK if quick else PENGALI_CLASSIC
		var me: Dictionary = st.get("menang_elemen", {})
		var xp_role_dasar = int(DataRole.XP_ROLE["selesai"]) \
			+ int(st.get("jebakan_role_pasang", 0)) * int(DataRole.XP_ROLE["pasang"]) \
			+ int(st.get("jebakan_role_kena", 0)) * int(DataRole.XP_ROLE["kena"]) \
			+ int(st.get("tahan_kurangi", 0)) * int(DataRole.XP_ROLE["tahan"]) \
			+ int(me.get(role, 0)) * int(DataRole.XP_ROLE["duel_elemen"]) \
			+ (int(DataRole.XP_ROLE["menang"]) if menang else 0)
		xp_role_match = roundi(xp_role_dasar * pengali_role)
		role_lv_awal = int(DataRole.info_level_role(int(xp_role.get(role, 0)))["level"])
		xp_role[role] = int(xp_role.get(role, 0)) + xp_role_match
		role_lv_akhir = int(DataRole.info_level_role(int(xp_role[role]))["level"])
	var xp_awal = xp_total
	crowns += cr_match + cr_peng + cr_misi
	var naik = _tambah_xp(xp_match + xp_peng + xp_misi)
	simpan()
	return {
		"xp_match": xp_match, "crowns_match": cr_match,
		"xp_penghargaan": xp_peng, "crowns_penghargaan": cr_peng, "penghargaan": peng.duplicate(),
		"misi_selesai": selesai, "xp_misi": xp_misi, "crowns_misi": cr_misi,
		"level_awal": naik["level_lama"], "level_akhir": naik["level_baru"], "crowns_naik_level": naik["crowns_level"],
		"xp_total_awal": xp_awal, "xp_total": xp_total,
		"bisa_double": (xp_match + xp_peng) > 0, "sudah_double": false,
		"role": role, "xp_role_match": xp_role_match,
		"role_level_awal": role_lv_awal, "role_level_akhir": role_lv_akhir,
	}

func tambah_double(r: Dictionary) -> bool:
	# Iklan DOUBLE REWARDS: XP & Crowns pertandingan + penghargaan + XP Role (K10)
	# diberikan sekali lagi. Hadiah misi & login TIDAK digandakan; naik level
	# (profil & Role) karena tambahan XP tetap berhadiah.
	# Mengubah r DI TEMPAT (dipakai kartu hadiah di layar akhir).
	if r.is_empty() or bool(r.get("sudah_double", false)) or _double_terpakai:
		return false
	_double_terpakai = true
	var xp_tambah = int(r["xp_match"]) + int(r["xp_penghargaan"])
	var cr_tambah = int(r["crowns_match"]) + int(r["crowns_penghargaan"])
	crowns += cr_tambah
	var naik = _tambah_xp(xp_tambah)
	var role_double: String = str(r.get("role", ""))
	var xp_role_asal = int(r.get("xp_role_match", 0))
	if role_double != "" and xp_role_asal > 0 and DataRole.ROLE.has(role_double):
		xp_role[role_double] = int(xp_role.get(role_double, 0)) + xp_role_asal
		r["xp_role_double"] = xp_role_asal
		r["role_level_akhir"] = int(DataRole.info_level_role(int(xp_role[role_double]))["level"])
	_tambah_statistik("double")
	r["sudah_double"] = true
	r["xp_double"] = xp_tambah
	r["crowns_double"] = cr_tambah
	r["level_akhir"] = naik["level_baru"]
	r["crowns_naik_level"] = int(r.get("crowns_naik_level", 0)) + int(naik["crowns_level"])
	r["xp_total"] = xp_total
	simpan()
	return true

func _tambah_statistik(kunci: String, n: int = 1) -> void:
	statistik[kunci] = int(statistik.get(kunci, 0)) + n

# ============================================================
# MISI HARIAN
# ============================================================
func _hari_ini() -> String:
	# Tanggal menurut jam HP (tengah malam jam HP = hari baru).
	return _tanggal_uji if _tanggal_uji != "" else Time.get_date_string_from_system()

func segarkan_hari() -> void:
	# Hari berganti (atau data misi rusak): 3 misi baru, CHANGE gratis lagi.
	var hari = _hari_ini()
	if tanggal_misi == hari and misi.size() == 3 and _misi_sah():
		return
	misi = []
	for tingkat in range(3):
		misi.append(_misi_baru(tingkat, []))
	tanggal_misi = hari
	ganti_misi_dipakai = false
	simpan()

func _misi_sah() -> bool:
	for m in misi:
		if not (m is Dictionary) or not MISI.has(str(m.get("id", ""))):
			return false
	return true

func _misi_baru(tingkat: int, kecuali: Array) -> Dictionary:
	var calon = []
	for k in MISI:
		if int(MISI[k]["tingkat"]) == tingkat and not kecuali.has(k):
			calon.append(k)
	if calon.is_empty():
		for k in MISI:
			if int(MISI[k]["tingkat"]) == tingkat:
				calon.append(k)
	var id_misi = str(calon[_rng.randi_range(0, calon.size() - 1)])
	var el = ""
	if str(MISI[id_misi]["stat"]) == "_elemen":
		var semua = NAMA_ELEMEN.keys()
		el = str(semua[_rng.randi_range(0, semua.size() - 1)])
	return {"id": id_misi, "progres": 0, "selesai": false, "elemen": el}

func _definisi(m: Dictionary) -> Dictionary:
	return MISI.get(str(m.get("id", "")), {})

func target_misi(m: Dictionary) -> int:
	return int(_definisi(m).get("target", 1))

func hadiah_misi(m: Dictionary) -> Dictionary:
	return HADIAH_MISI[clampi(int(_definisi(m).get("tingkat", 0)), 0, 2)]

func teks_misi(m: Dictionary) -> String:
	var def = _definisi(m)
	if def.is_empty():
		return ""
	if str(def["stat"]) == "_elemen":
		return str(def["teks"]) % NAMA_ELEMEN.get(str(m.get("elemen", "api")), "FIRE")
	return str(def["teks"])

func jumlah_misi_selesai() -> int:
	var n = 0
	for m in misi:
		if m is Dictionary and bool(m.get("selesai", false)):
			n += 1
	return n

func _majukan_misi(st: Dictionary, menang: bool, jumlah_penghargaan: int) -> Array:
	# Kemajuan misi dari SATU pertandingan tuntas. Misi yang baru selesai langsung
	# berhadiah. Hasil: [{"teks", "xp", "crowns"}] untuk kartu hadiah.
	var selesai = []
	for m in misi:
		if not (m is Dictionary) or bool(m.get("selesai", false)):
			continue
		var tambah = 0
		var kunci = str(_definisi(m).get("stat", ""))
		match kunci:
			"_match":
				tambah = 1
			"_menang":
				tambah = 1 if menang else 0
			"_penghargaan":
				tambah = jumlah_penghargaan
			"_elemen":
				var me = st.get("menang_elemen", {})
				if me is Dictionary:
					tambah = int(me.get(str(m.get("elemen", "")), 0))
			_:
				tambah = int(st.get(kunci, 0))
		if tambah <= 0:
			continue
		m["progres"] = mini(target_misi(m), int(m.get("progres", 0)) + tambah)
		if int(m["progres"]) >= target_misi(m):
			m["selesai"] = true
			var hd = hadiah_misi(m)
			selesai.append({"teks": teks_misi(m), "xp": int(hd["xp"]), "crowns": int(hd["crowns"])})
	return selesai

func boleh_ganti_misi(i: int) -> bool:
	return not ganti_misi_dipakai and i >= 0 and i < misi.size() and not bool(misi[i].get("selesai", false))

func ganti_misi(i: int) -> bool:
	# Tombol CHANGE: gratis sekali per hari, hanya untuk misi yang belum selesai;
	# diganti misi lain SETINGKAT yang belum ada di daftar.
	if not boleh_ganti_misi(i):
		return false
	var kecuali = []
	for m in misi:
		kecuali.append(str(m.get("id", "")))
	misi[i] = _misi_baru(int(_definisi(misi[i]).get("tingkat", 0)), kecuali)
	ganti_misi_dipakai = true
	simpan()
	return true

# ============================================================
# HADIAH LOGIN 7 HARI
# ============================================================
func login_bisa_diklaim() -> bool:
	return tanggal_login != _hari_ini()

func klaim_login() -> Dictionary:
	# Hasil: {"hari", "crowns", "xp", "level_lama", "level_baru", "crowns_level"} atau {}.
	if not login_bisa_diklaim():
		return {}
	var hari = hari_login
	var jumlah = int(HADIAH_LOGIN[hari - 1])
	var xp_login = XP_LOGIN_HARI_7 if hari == 7 else 0
	crowns += jumlah
	var hasil = _tambah_xp(xp_login)
	hari_login = hari % 7 + 1
	tanggal_login = _hari_ini()
	simpan()
	hasil["hari"] = hari
	hasil["crowns"] = jumlah
	hasil["xp"] = xp_login
	return hasil

# ============================================================
# NAMA
# ============================================================
func ganti_nama(baru: String) -> String:
	# "" = berhasil; selain itu pesan untuk pemain.
	var salah = cek_nama(baru)
	if salah != "":
		return salah
	nama = _rapikan_nama(baru)
	simpan()
	return ""

func _rapikan_nama(teks: String) -> String:
	var b = teks.strip_edges()
	while b.contains("  "):
		b = b.replace("  ", " ")
	return b

func cek_nama(teks: String) -> String:
	var b = _rapikan_nama(teks)
	var pola = RegEx.new()
	pola.compile("^[A-Za-z0-9 ]{3,12}$")
	if pola.search(b) == null:
		return "Use 3-12 letters or numbers."
	if _nama_kasar(b):
		return "Please choose another name."
	return ""

func _nama_kasar(teks: String) -> bool:
	var kecil = teks.to_lower()
	var leet = kecil
	for p in [["0", "o"], ["1", "i"], ["3", "e"], ["4", "a"], ["5", "s"], ["7", "t"], ["@", "a"], ["$", "s"]]:
		leet = leet.replace(p[0], p[1])
	var rapat = leet.replace(" ", "")
	for k in KATA_KASAR:
		if rapat.contains(k):
			return true
	# Kata utuh: dicek dua cara (angka dibuang / angka jadi huruf), per kata dan seluruh nama.
	var daftar = [kecil.replace(" ", ""), rapat]
	for kata in kecil.split(" ", false):
		daftar.append(kata)
	for kata in leet.split(" ", false):
		daftar.append(kata)
	for c in daftar:
		var huruf = ""
		for ch in c:
			if ch >= "a" and ch <= "z":
				huruf += ch
		if KATA_KASAR_UTUH.has(huruf) or KATA_KASAR_UTUH.has(c):
			return true
	return false
