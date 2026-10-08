extends Node3D
class_name JebakanDasar

var pemilik: int = -1
var elemen: String = ""
var aktif: bool = true

func _ready():
	add_to_group("grup_jebakan")
