#!/usr/bin/env python3
"""Di runner: enkripsi berkas mentah (dekompilasi/daftar/string) dengan kunci PUBLIK; hanya hasil terenkripsi yang dikomit.
Format potongan: "ENC2\\n<base64 RSA-OAEP(kunci+iv)>\\n<base64 AES-256-CBC(zlib(potongan))>\\n"; potongan 150000 byte data terkompresi.
Pakai: enkripsi_berkas.py PUB.pem OUTDIR MANIFEST RUNID berkas1 berkas2 ...
MANIFEST (aman, dikomit ke out/): nama, ukuran polos, jumlah baris, sha256 polos, nama potongan terenkripsi."""
import base64
import hashlib
import os
import subprocess
import sys
import zlib

pub, outdir, manifest, rid = sys.argv[1:5]
files = sys.argv[5:]
CH = 150000
os.makedirs(outdir, exist_ok=True)


def enc(data):
    key, iv = os.urandom(32), os.urandom(16)
    ct = subprocess.run(["openssl", "enc", "-aes-256-cbc", "-K", key.hex(), "-iv", iv.hex()], input=data, capture_output=True, check=True).stdout
    wk = subprocess.run(["openssl", "pkeyutl", "-encrypt", "-pubin", "-inkey", pub, "-pkeyopt", "rsa_padding_mode:oaep"],
                        input=key + iv, capture_output=True, check=True).stdout
    return b"ENC2\n" + base64.b64encode(wk) + b"\n" + base64.b64encode(ct) + b"\n"


lines = ["MANIFEST berkas terenkripsi - run %s (kunci privat TIDAK ada di repo; dekripsi hanya di sandbox pemilik kunci)" % rid,
         "format: nama_polos ukuran_polos baris sha256_polos -> potongan:ukuran_enc"]
for f in files:
    data = open(f, "rb").read()
    comp = zlib.compress(data, 9)
    parts = []
    base = os.path.basename(f)
    base = base[:-4] if base.endswith(".txt") else base
    for k in range(0, max(len(comp), 1), CH):
        blob = enc(comp[k:k + CH])
        nm = "%s.p%02d.enc.txt" % (base, k // CH + 1)
        open(os.path.join(outdir, nm), "wb").write(blob)
        parts.append("%s:%d" % (nm, len(blob)))
    lines.append("%s %d %d %s -> %s" % (os.path.basename(f), len(data), data.count(b"\n"), hashlib.sha256(data).hexdigest(), " ".join(parts)))
open(manifest, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("\n".join(l[:200] for l in lines))
