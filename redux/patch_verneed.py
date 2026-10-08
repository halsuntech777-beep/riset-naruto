import struct, sys, glob, os
def elf_hash(n):
    h = 0
    for c in n.encode():
        h = ((h << 4) + c) & 0xffffffff
        g = h & 0xf0000000
        if g: h ^= g >> 24
        h &= ~g & 0xffffffff
    return h
def patch(path):
    d = bytearray(open(path, 'rb').read())
    if d[:4] != b'\x7fELF' or d[4] != 2: return 0
    shoff, = struct.unpack_from('<Q', d, 0x28); shentsize, shnum = struct.unpack_from('<HH', d, 0x3A)
    secs = [struct.unpack_from('<IIQQQQIIQQ', d, shoff + i*shentsize) for i in range(shnum)]
    vr = [s for s in secs if s[1] == 0x6ffffffe]
    if not vr: return 0
    s = vr[0]; off0, size, link = s[4], s[5], s[6]; stroff = secs[link][4]
    def sname(o): 
        e = d.index(b'\0', stroff + o); return d[stroff+o:e].decode()
    n = 0; off = off0
    while True:
        vn_ver, vn_cnt, vn_file, vn_aux, vn_next = struct.unpack_from('<HHIII', d, off)
        auxs = []; a = off + vn_aux
        for _ in range(vn_cnt):
            h, fl, oth, nm, nx = struct.unpack_from('<IHHII', d, a); auxs.append((a, sname(nm), nm)); a += nx
        good = [x for x in auxs if x[1] not in ('GLIBC_2.43', 'GLIBC_2.42')]
        for (a, name, nm) in auxs:
            if name in ('GLIBC_2.43', 'GLIBC_2.42') and good:
                gname, gnm = good[0][1], good[0][2]
                struct.pack_into('<I', d, a, elf_hash(gname)); struct.pack_into('<I', d, a + 8, gnm); n += 1
        if vn_next == 0: break
        off += vn_next
    if n: open(path, 'wb').write(d)
    return n
tot = 0
for f in glob.glob(sys.argv[1] + '/**/*', recursive=True):
    if os.path.isfile(f) and not os.path.islink(f):
        try: c = patch(f)
        except Exception as e: c = 0
        if c: print("patched", f, c); tot += c
print("total entri dipatch:", tot)
