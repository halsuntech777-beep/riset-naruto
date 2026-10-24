#!/usr/bin/env python3
"""Di runner: ubah s<frame>.raw (+ .meta) menjadi PNG DI MEMORI, enkripsi hibrida (AES-256-CBC + RSA-OAEP kunci publik), tulis shot_<frame>.enc.txt.
PNG/raw mentah tidak pernah ditulis ke luar folder sementara OUT. Pemakaian: enkripsi_shot.py OUT D PUB.pem"""
import sys, os, glob, zlib, struct, base64, subprocess, tempfile
out, d, pub = sys.argv[1:4]
def png(w, h, rows):
    def ch(t, b): c = struct.pack(">I", len(b)) + t + b; return c + struct.pack(">I", zlib.crc32(t + b) & 0xffffffff)
    raw = b"".join(b"\x00" + r for r in rows)
    return b"\x89PNG\r\n\x1a\n" + ch(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + ch(b"IDAT", zlib.compress(raw, 9)) + ch(b"IEND", b"")
def rows_of(w, h, bpp, s, k):
    rows = []
    for y in range(0, h, k):
        r = bytearray()
        for x in range(0, w, k):
            if bpp == 24 or len(s) == w * h * 3:
                i = (y * w + x) * 3; r += s[i:i+3]
            else:
                i = (y * w + x) * 2; p = s[i] | (s[i+1] << 8)   # PS1 555: R bit0-4, G bit5-9, B bit10-14
                r += bytes(((p & 31) * 255 // 31, ((p >> 5) & 31) * 255 // 31, ((p >> 10) & 31) * 255 // 31))
        rows.append(bytes(r))
    return rows
def enc(data):
    key, iv = os.urandom(32), os.urandom(16)
    ct = subprocess.run(["openssl", "enc", "-aes-256-cbc", "-K", key.hex(), "-iv", iv.hex()], input=data, capture_output=True, check=True).stdout
    wk = subprocess.run(["openssl", "pkeyutl", "-encrypt", "-pubin", "-inkey", pub, "-pkeyopt", "rsa_padding_mode:oaep"], input=key + iv, capture_output=True, check=True).stdout
    return b"ENC1\n" + base64.b64encode(wk) + b"\n" + base64.b64encode(ct) + b"\n"
n = 0
for rawf in sorted(glob.glob(out + "/s*.raw"), key=lambda p: int(os.path.basename(p)[1:-4]))[:8]:
    fr = int(os.path.basename(rawf)[1:-4])   # nama s%05d.raw bisa 6 digit (frame>=100000)
    w, h, bpp, ln = map(int, open(rawf[:-4] + ".meta").read().split())
    s = open(rawf, "rb").read()
    for k in (1, 2, 4):
        wk_, hk_ = (w + k - 1) // k, (h + k - 1) // k
        blob = enc(png(wk_, hk_, rows_of(w, h, bpp, s, k)))
        if len(blob) <= 270000: break
    nm = fr if fr < 100000 else fr // 10   # penjaga run_remote.sh hanya menerima shot_ + 5 digit; frame asli ada di baris SHOT_ENC (f=)
    while os.path.exists(f"{d}/shot_{nm:05d}.enc.txt"): nm += 1   # hindari tabrakan nama
    open(f"{d}/shot_{nm:05d}.enc.txt", "wb").write(blob); n += 1
    print(f"SHOT_ENC f={fr} arq=shot_{nm:05d} w={w} h={h} bpp={bpp} len={ln} skala=1/{k} tx_bytes={len(blob)}")
