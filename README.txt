Skrip riset Naruto Jintori Gassen (PS1) di PCSX-Redux. Hanya skrip dan jadwal input; tidak ada game, emulator, atau aset.

Cara pakai (ringkas):
1. Unggah ulang AppImage PCSX-Redux dan game (.bin + .cue). Ekstrak AppImage: ./PCSX-Redux-*.AppImage --appimage-extract
2. AppImage butuh glibc lebih baru dari sandbox: pakai patch_verneed.py (tambal versi simbol) + shim243.c/.so (LD_PRELOAD). Bila perlu, buat ulang.
3. run_headless.sh <skrip.lua> [batas_detik] menjalankan emulator tanpa layar. Sesuaikan path .cue.
4. lua_mine/probe.lua: input terjadwal (INPUTS=file), dump RAM (DUMPS="frame ..."), screenshot (SHOTS), poke memori (POKES="frame@alamathex@lebar@nilai"), keluaran lewat OUTDIR/MAXF.
5. inputs_base.txt = jalur Party Mode (4 pemain) sampai frame 7680. inputs_cp/cq/cr = lanjutan ke petak kartu (RIGHT 7520, CIRCLE 7580, dst).
6. tools/sheet.py membuat montase dari screenshot mentah (.raw 320x240).
Format baris input: <frame_mulai> <TOMBOL> <lama_frame>.

SCAN (Sesi x4, header jadwal; hanya angka keluar): "# SCAN f v1 v2 ..." (kata 32-bit), "# SCANH" (16-bit), "# SCANB" (byte): cetak alamat RAM bernilai v pada frame f; "# SCANP w f1 v1 f2 v2 ..." rantai (alamat harus bernilai v_k pada frame f_k untuk semua k); "# SCANMAX n" batas alamat tercetak. Contoh: inputs/sc2.txt.
