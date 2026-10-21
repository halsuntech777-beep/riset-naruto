#!/usr/bin/env python3
"""Di sandbox Claude saja: dekripsi shot_*.enc.txt menjadi PNG lokal (kunci privat tidak ada di repo). Pemakaian: dekripsi_shot.py PRIV.pem file.enc.txt out.png"""
import sys, base64, subprocess
priv, f, outp = sys.argv[1:4]
L = open(f, "rb").read().split(b"\n"); assert L[0] == b"ENC1"
kv = subprocess.run(["openssl", "pkeyutl", "-decrypt", "-inkey", priv, "-pkeyopt", "rsa_padding_mode:oaep"], input=base64.b64decode(L[1]), capture_output=True, check=True).stdout
open(outp, "wb").write(subprocess.run(["openssl", "enc", "-d", "-aes-256-cbc", "-K", kv[:32].hex(), "-iv", kv[32:].hex()], input=base64.b64decode(L[2]), capture_output=True, check=True).stdout)
