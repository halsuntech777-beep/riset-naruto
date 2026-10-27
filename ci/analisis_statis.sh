#!/bin/bash
# Analisis statis ROM di runner (dipanggil ci/analisis-statis.yml). Berkas game HANYA di $W (sementara). Yang dikomit: angka/metadata di hasil_analisis/.
set -euo pipefail
R="$PWD"; W="${RUNNER_TEMP:-/tmp}/an"; mkdir -p "$W"
LANGKAH="${LANGKAH:-1,2}"; ALAMAT="${ALAMAT:-}"
[[ "$LANGKAH" =~ ^[0-9]{1,2}(,[0-9]{1,2})*$ ]] || { echo "LANGKAH tidak valid"; exit 1; }
[[ -z "$ALAMAT" || "$ALAMAT" =~ ^(0x)?[0-9A-Fa-f]{1,8}(,(0x)?[0-9A-Fa-f]{1,8})*$ ]] || { echo "ALAMAT tidak valid"; exit 1; }
ID="${GITHUB_RUN_ID:-lokal}-${GITHUB_RUN_ATTEMPT:-1}"; D="$R/hasil_analisis/l${LANGKAH//,/_}_$ID"; mkdir -p "$D"
gagal(){ echo "BERHENTI: $*" | tee -a "$D/ringkas.txt"; exit 1; }
has(){ [[ ",$LANGKAH," == *",$1,"* ]]; }
unduh_game(){
  [ -n "${PRIVATE_REPO:-}" ] && [ -n "${PRIVATE_TOKEN:-}" ] || gagal "secret aset kosong"
  mkdir -p "$W/dl"
  GH_TOKEN="$PRIVATE_TOKEN" gh release download aset -R "$PRIVATE_REPO" -D "$W/dl" -p "*.bin" -p "*.BIN" >/dev/null 2>&1 || gagal "unduh game.bin gagal"
  G=$(ls "$W/dl" | grep -iE "\.bin$" | head -1); [ -n "$G" ] || gagal "tidak ada .bin"
  BIN=$(sed -n "s/^FILE \"\(.*\)\" BINARY.*/\1/p" "$R/redux/game/naruto.cue" | head -1)
  mkdir -p "$W/game"; cp "$R/redux/game/naruto.cue" "$W/game/"; mv "$W/dl/$G" "$W/game/$BIN"
  echo "game.bin ok, $(stat -c %s "$W/game/$BIN") byte" | tee -a "$D/ringkas.txt"
}
pasang_mkpsxiso(){
  mkdir -p "$W/mk"
  GH_TOKEN="${GITHUB_TOKEN:-}" gh release download -R Lameguy64/mkpsxiso -D "$W/mk" -p "*Linux*.zip" >/dev/null 2>&1 || gagal "unduh mkpsxiso gagal"
  (cd "$W/mk" && unzip -q -o ./*.zip); DX=$(find "$W/mk" -type f -name dumpsxiso | head -1); [ -n "$DX" ] || gagal "dumpsxiso tak ketemu"; chmod +x "$DX"
  echo "dumpsxiso: $("$DX" --version 2>&1 | head -1 | tr -cd "\11\12\40-\176" | cut -c1-80)" | tee -a "$D/ringkas.txt"
}
if has 1 || has 2; then
  unduh_game; pasang_mkpsxiso
  CUE=$(ls "$W"/game/*.cue | head -1)
  "$DX" -x "$W/disc" -s "$W/disc.xml" "$CUE" > "$W/dump.log" 2>&1 || { tail -n 5 "$W/dump.log" | tr -cd "\11\12\40-\176" | cut -c1-160; gagal "dumpsxiso gagal"; }
  python3 - "$W/disc" <<"PY" | tee -a "$D/ringkas.txt"
import os,sys,re,struct
root=sys.argv[1]; files=[]
for dp,_,fn in os.walk(root):
    for f in fn:
        p=os.path.join(dp,f); files.append((os.path.relpath(p,root),os.path.getsize(p),p))
files.sort(key=lambda x:-x[1])
print("LANGKAH1: berkas=%d total=%d byte"%(len(files),sum(x[1] for x in files)))
def magic(p):
    with open(p,"rb") as h: return h.read(8)==b"PS-X EXE"
for n,s,p in files[:25]:
    print("  %-28s %9d  PSXEXE=%s"%(n[:28],s,magic(p)))
cnf=[x for x in files if x[0].upper().endswith("SYSTEM.CNF")]
boot=None
if cnf:
    t=open(cnf[0][2],"rb").read().decode("ascii","replace")
    for l in t.splitlines():
        l=l.strip()
        if l[:4].upper() in("BOOT","TCB ","EVEN","STAC"): print("  CNF:",re.sub(r"[^\x20-\x7e]","?",l)[:60])
        m=re.match(r"BOOT\s*=\s*cdrom:\\?([^;\s]+)",l,re.I)
        if m: boot=m.group(1).split("\\")[-1]
print("LANGKAH2: exe utama=%s"%boot)
for n,s,p in files:
    if boot and os.path.basename(n).upper()==boot.upper() or magic(p):
        h=open(p,"rb").read(0x40)
        if h[:8]!=b"PS-X EXE": print("  %s: bukan PS-X EXE"%n); continue
        pc,gp,dest,ts=struct.unpack("<IIII",h[0x10:0x20]); sp=struct.unpack("<I",h[0x30:0x34])[0]
        print("  %s: muat=0x%08X entry=0x%08X gp=0x%08X ukuran_teks=%d (0x%X) sp=0x%08X ukuran_berkas=%d header+teks_cocok=%s akhir=0x%08X"%(n,dest,pc,gp,ts,ts,sp,s,s==0x800+ts,dest+ts))
PY
fi
for l in 3 4 5 6 7 8 9 10; do has $l && echo "langkah $l belum diimplementasikan di skrip ini" | tee -a "$D/ringkas.txt"; done
bad=$(find "$D" -type f \( -size +300k -o -not -name "*.txt" \)) || true; [ -z "$bad" ] || gagal "berkas terlarang: $bad"
git config user.name claude-runner; git config user.email actions@users.noreply.github.com
git add "$D"; git commit -q -m "hasil analisis statis $ID (langkah $LANGKAH)"
for i in 1 2 3 4 5 6 7 8 9 10; do git pull --rebase -q origin "$GITHUB_REF_NAME" && git push -q origin "HEAD:$GITHUB_REF_NAME" && { echo "push ok"; break; }; sleep $((RANDOM % 9 + 3)); done
