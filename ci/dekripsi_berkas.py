#!/usr/bin/env python3
"""Di sandbox pemilik kunci SAJA: gabungkan potongan ENC2 (urut) menjadi satu berkas polos.
Pakai: dekripsi_berkas.py PRIV.pem KELUARAN potongan1.enc.txt potongan2.enc.txt ..."""
import base64
import subprocess
import sys
import zlib

priv, outp = sys.argv[1:3]
buf = b""
for f in sys.argv[3:]:
    L = open(f, "rb").read().split(b"\n")
    assert L[0] == b"ENC2", "format bukan ENC2: " + f
    kv = subprocess.run(["openssl", "pkeyutl", "-decrypt", "-inkey", priv, "-pkeyopt", "rsa_padding_mode:oaep"],
                        input=base64.b64decode(L[1]), capture_output=True, check=True).stdout
    buf += subprocess.run(["openssl", "enc", "-d", "-aes-256-cbc", "-K", kv[:32].hex(), "-iv", kv[32:].hex()],
                          input=base64.b64decode(L[2]), capture_output=True, check=True).stdout
open(outp, "wb").write(zlib.decompress(buf))
print("ok", outp)
