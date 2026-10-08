extends Node
## MIGRASI HOST -- dipakai pemain.gd saat host putus di tengah permainan 3-4 pemain.
## File ini cuma mengurus JARINGAN-nya: mencari host baru lewat siaran UDP,
## mengumumkan diri sebagai host baru, menyelesaikan rebutan kalau dua device
## sama-sama jadi host, dan membuat peer ENet (server / client). Semua keputusan
## permainan (slot mana yang kembali, kapan lanjut) tetap di pemain.gd.
##
## Pesan UDP (port 7778 seperti lobby, tapi awalannya beda supaya lobby tidak salah tangkap):
##   TILEDUEL_MIGRASI_HOST|id_sesi|slot|umur_host|host_lama|port_game|anggota
##       dikirim host tiap 0.5 dtk, juga sebagai balasan langsung untuk CARI.
##       umur_host = detik sejak host ini menekan tombolnya, diukur di HP-nya
##       sendiri (tidak butuh jam yang sama di semua HP). host_lama = 1 kalau ini
##       host sebelum putus (P1 yang kembali). anggota = "" selama belum START NOW;
##       sesudahnya daftar slot manusia di permainan yang dilanjutkan, mis. "1,2".
##   TILEDUEL_MIGRASI_CARI|id_sesi|slot|port_balas   dikirim pencari tiap 0.4 dtk.
## Pesan dengan id_sesi lain diabaikan (permainan lain di jaringan yang sama).

signal host_ditemukan(ip: String, port: int, slot_host: int, anggota: Array)
signal harus_mengalah(slot_pemenang: int, anggota: Array)

const PESAN_HOST = "TILEDUEL_MIGRASI_HOST"
const PESAN_CARI = "TILEDUEL_MIGRASI_CARI"
const MAKS_CLIENT = 3

# Nilai bawaan = nilai sungguhan di HP. HANYA robot uji yang mengubahnya: di rig
# satu mesin beberapa proses tidak bisa memakai port yang sama.
var port_dengar: int = 7778
var port_tujuan: Array = [7778]
var alamat_tambahan: Array = []
var port_game: int = 7777

var mode: String = "" # "" | "cari" | "host"
var id_sesi: int = 0
var slot_saya: int = -1
var host_lama: bool = false
var anggota_mulai: Array = [] # kosong = belum START NOW
var umur_host: float = 0.0
var _udp: PacketPeerUDP = null
var _jeda_kirim: float = 0.0
var _jam: float = 0.0
var _konflik_sejak: Dictionary = {} # slot host lain -> _jam saat rebutan mulai terdengar

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _exit_tree() -> void:
	berhenti()

# ---------------------------------------------------------------- dipanggil pemain.gd
func mulai_cari(sesi: int, slot: int) -> void:
	berhenti()
	id_sesi = sesi
	slot_saya = slot
	mode = "cari"
	_buka_udp()
	_kirim_siaran(_pesan_cari())

func jadi_host(sesi: int, slot: int, adalah_host_lama: bool) -> bool:
	# Buat server ENet baru lalu mulai mengumumkan diri. false = port game tidak
	# bisa dipakai (jarang; mis. server lama belum benar-benar tertutup).
	berhenti()
	tutup_peer()
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(port_game, MAKS_CLIENT) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	id_sesi = sesi
	slot_saya = slot
	host_lama = adalah_host_lama
	anggota_mulai = []
	umur_host = 0.0
	mode = "host"
	_buka_udp()
	_kirim_siaran(_pesan_host())
	return true

func tandai_mulai(anggota: Array) -> void:
	# START NOW: host tetap mengumumkan diri, supaya device yang terlambat tahu
	# permainannya sudah dilanjutkan tanpa dia (bukan menunggu selamanya).
	anggota_mulai = anggota.duplicate()

func sambung_ke(ip: String, port: int) -> bool:
	tutup_peer()
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, port) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	return true

func tutup_peer() -> void:
	# Diganti peer OFFLINE (bukan null): logika permainan yang masih berjalan boleh
	# tetap memanggil rpc() tanpa error -- pesannya saja yang tidak terkirim.
	var peer = multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func berhenti() -> void:
	mode = ""
	_konflik_sejak.clear()
	if _udp:
		_udp.close()
		_udp = null

# ---------------------------------------------------------------- siaran & terima
func _process(delta: float) -> void:
	if mode == "":
		return
	_jam += delta
	if mode == "host":
		umur_host += delta
	# Diulang berkala: UDP tidak dijamin sampai (pola sama dengan lobby).
	_jeda_kirim += delta
	if _jeda_kirim >= (0.5 if mode == "host" else 0.4):
		_jeda_kirim = 0.0
		_kirim_siaran(_pesan_host() if mode == "host" else _pesan_cari())
	while _udp and _udp.get_available_packet_count() > 0:
		var data = _udp.get_packet().get_string_from_utf8()
		var ip = _udp.get_packet_ip()
		_proses_pesan(data, ip)

func _proses_pesan(data: String, ip: String) -> void:
	var b = data.split("|")
	if b.size() < 3 or int(b[1]) != id_sesi:
		return
	var slot_lain = int(b[2])
	if slot_lain == slot_saya:
		return # siaran kita sendiri yang memantul balik
	if b[0] == PESAN_HOST and b.size() >= 7:
		var anggota = _baca_anggota(b[6])
		if mode == "cari":
			host_ditemukan.emit(ip, int(b[5]), slot_lain, anggota)
		elif mode == "host":
			_periksa_rebutan(ip, slot_lain, float(b[3]), b[4] == "1", anggota)
	elif b[0] == PESAN_CARI and mode == "host" and b.size() >= 4:
		# Balas langsung ke pencarinya -- siaran dari HP Android sering salah jalur,
		# jadi koneksi tetap terjalin selama SALAH SATU arah berhasil.
		_udp.set_dest_address(ip, int(b[3]))
		_udp.put_packet(_pesan_host().to_utf8_buffer())

func _periksa_rebutan(ip_lain: String, slot_lain: int, umur_lain: float, lama_lain: bool, anggota_lain: Array) -> void:
	# Dua device sama-sama jadi host untuk permainan yang sama. Aturannya harus
	# memberi hasil yang SAMA di kedua device, supaya tepat satu yang mengalah.
	var kalah = false
	if not anggota_mulai.is_empty():
		_kabari_langsung(ip_lain) # sudah START NOW: permainan di sini jalan, tidak bisa mundur
		return
	if not anggota_lain.is_empty():
		kalah = true # host lain sudah melanjutkan permainan
	else:
		if not _konflik_sejak.has(slot_lain):
			_konflik_sejak[slot_lain] = _jam
		var selisih = umur_lain - umur_host
		if absf(selisih) >= 0.5 and _jam - _konflik_sejak[slot_lain] < 2.0:
			kalah = selisih > 0.0 # yang menekan belakangan (lebih muda) mengalah
		else:
			# Hampir bersamaan -- atau rebutan sudah 2 dtk tidak selesai karena kedua
			# HP berbeda pendapat soal umur (selisihnya pas di sekitar 0.5 dtk):
			# host lama menang; selain itu aturan lobby -- IP lebih besar mengalah,
			# IP sama (rig uji satu mesin) -> slot lebih besar mengalah.
			kalah = _kalah_saat_seri(ip_lain, slot_lain, lama_lain)
	if kalah:
		harus_mengalah.emit(slot_lain, anggota_lain)
	else:
		# Siaran bisa saja cuma sampai satu arah (Android): kirim langsung ke host
		# yang kalah supaya ia pasti mendengar kita dan mengalah.
		_kabari_langsung(ip_lain)

func _kabari_langsung(ip: String) -> void:
	if _udp == null:
		return
	var buf = _pesan_host().to_utf8_buffer()
	for port in port_tujuan:
		_udp.set_dest_address(ip, port)
		_udp.put_packet(buf)

func _kalah_saat_seri(ip_lain: String, slot_lain: int, lama_lain: bool) -> bool:
	if host_lama != lama_lain:
		return lama_lain
	var ip_ku = ip_ku_yang_sejaringan(ip_lain)
	if ip_ku != "" and ip_ku != ip_lain:
		return ip_ke_angka(ip_ku) > ip_ke_angka(ip_lain)
	return slot_saya > slot_lain

func _pesan_host() -> String:
	var bagian = PackedStringArray()
	for s in anggota_mulai:
		bagian.append(str(s))
	return "%s|%d|%d|%.2f|%d|%d|%s" % [PESAN_HOST, id_sesi, slot_saya, umur_host, 1 if host_lama else 0, port_game, ",".join(bagian)]

func _pesan_cari() -> String:
	return "%s|%d|%d|%d" % [PESAN_CARI, id_sesi, slot_saya, port_dengar]

func _baca_anggota(teks: String) -> Array:
	var hasil = []
	for bagian in teks.split(",", false):
		hasil.append(int(bagian))
	return hasil

# ---------------------------------------------------------------- UDP & IP (tiru persis lobby)
func _buka_udp() -> void:
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	if _udp.bind(port_dengar) != OK:
		push_warning("Migrasi host: port %d tidak bisa dipakai." % port_dengar)
	_jeda_kirim = 0.0

func _kirim_siaran(pesan: String) -> void:
	if _udp == null:
		return
	var buf = pesan.to_utf8_buffer()
	for alamat in _alamat_siaran():
		for port in port_tujuan:
			_udp.set_dest_address(alamat, port)
			_udp.put_packet(buf)

func _alamat_siaran() -> Array:
	# Selain 255.255.255.255, alamat broadcast khusus tiap jaringan aktif (mis.
	# 192.168.43.255 untuk hotspot HP) -- di Android siaran umum sering dikirim
	# lewat data seluler, bukan lewat hotspot-nya sendiri.
	var daftar = ["255.255.255.255"]
	for ip in alamat_lokal_sendiri():
		var bagian = ip.split(".")
		var alamat = "%s.%s.%s.255" % [bagian[0], bagian[1], bagian[2]]
		if not daftar.has(alamat):
			daftar.append(alamat)
	for alamat in alamat_tambahan:
		if not daftar.has(alamat):
			daftar.append(alamat)
	return daftar

static func alamat_lokal_sendiri() -> Array:
	var hasil = []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and not ip.begins_with("127."):
			hasil.append(ip)
	return hasil

static func ip_ke_angka(ip: String) -> int:
	var bagian = ip.split(".")
	if bagian.size() != 4:
		return 0
	return int(bagian[0]) * 16777216 + int(bagian[1]) * 65536 + int(bagian[2]) * 256 + int(bagian[3])

static func ip_ku_yang_sejaringan(ip_lawan: String) -> String:
	# Alamat milik kita sendiri yang 3 angka depannya sama dengan alamat lawan.
	var awalan = ip_lawan.rsplit(".", true, 1)[0]
	for ip in alamat_lokal_sendiri():
		if ip.begins_with(awalan + "."):
			return ip
	return ""
