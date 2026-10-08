extends Node

# Diset oleh layar_local_play.gd TEPAT SEBELUM change_scene_to_file, dibaca oleh
# pemain.gd._ready() di panggung_utama.tscn. Default HARUS selalu "" (bukan
# multiplayer) — inilah yang menjamin jalur solo (lewat main menu, tidak pernah
# menyentuh LocalPlay.tscn) tidak pernah terpengaruh, karena flag ini cuma pernah
# ditulis dari satu tempat: connect handler di layar_local_play.gd.
#
# Sengaja tidak pakai query ke state multiplayer.* (has_multiplayer_peer()/is_server())
# untuk deteksi ini — terbukti tidak bisa dipercaya, bisa balik true walau tidak ada
# peer sungguhan yang pernah di-attach.
var peran_multiplayer: String = "" # "", "host", atau "client"

# --- Susunan permainan yang dipilih host di lobby (LocalPlay) ---
# peta_multiplayer : "alam" / "pantai"
# jenis_slot       : per slot -> "manusia" / "ai" (kosong = 1v1 jalur lama)
# peer_slot        : peer_id ENet -> nomor slot (host selalu id 1)
var peta_multiplayer: String = "alam"
var jenis_slot: Array = []
var peer_slot: Dictionary = {}
# Fase 4: data role tiap slot dari lobby -- [{"role": String, "jebakan": Array}, ...]
# indeks sejajar dengan jenis_slot. Dikosongkan reset_susunan() seperti field lain.
var role_slot: Array = []
# Nomor acak permainan ini (dibuat host saat START di lobby). Dipakai migrasi host
# supaya device tidak menyambung ke permainan LAIN di jaringan yang sama.
var id_sesi: int = 0

# --- QUICK MATCH (Fase 1) ---
# Jumlah ronde menurut jumlah pemain.
const BATAS_RONDE_QUICK = {2: 8, 3: 6, 4: 5}
const BERKAS_PILIHAN := "user://pilihan_main.cfg"
var mode_quick: bool = false # dipilih host di lobby (multiplayer)
# Engine.time_scale sebelum Quick Match mempercepatnya (-1 = tidak sedang diubah).
# TIDAK di-reset reset_susunan(): pemain.gd yang mengembalikannya.
var skala_waktu_dasar: float = -1.0

func baca_pilihan_quick() -> bool:
	# Pilihan QUICK MATCH / CLASSIC terakhir (menu solo & lobby memakai berkas yang sama).
	var c = ConfigFile.new()
	if c.load(BERKAS_PILIHAN) != OK:
		return true # bawaan: Quick
	return bool(c.get_value("main", "quick", true))

func simpan_pilihan_quick(nilai: bool) -> void:
	var c = ConfigFile.new()
	c.load(BERKAS_PILIHAN)
	c.set_value("main", "quick", nilai)
	c.save(BERKAS_PILIHAN)

func reset_susunan() -> void:
	peta_multiplayer = "alam"
	jenis_slot = []
	peer_slot = {}
	role_slot = []
	id_sesi = 0
	mode_quick = false

func keluar_dari_sesi() -> void:
	peran_multiplayer = ""
	reset_susunan()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
