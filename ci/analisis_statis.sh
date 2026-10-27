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
if has 1 || has 2 || has 3 || has 4; then
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
if has 3 || has 4; then
  EXE=$(find "$W/disc" -iname "SLPS_035.53" | head -1); [ -n "$EXE" ] || gagal "exe tak ketemu"
  tail -c +2049 "$EXE" > "$W/exe.bin"
  mkdir -p "$W/gh"
  GH_TOKEN="${GITHUB_TOKEN:-}" gh release download -R NationalSecurityAgency/ghidra -D "$W/gh" -p "ghidra_*_PUBLIC_*.zip" >/dev/null 2>&1 || gagal "unduh ghidra gagal"
  (cd "$W/gh" && unzip -q -o ./ghidra_*.zip); GD=$(find "$W/gh" -maxdepth 1 -type d -name "ghidra_*" | head -1)
  chmod +x "$GD"/support/* "$GD"/*.sh 2>/dev/null || true
  J="${JAVA_HOME_21_X64:-}"; if [ -z "$J" ] || [ ! -x "$J/bin/javac" ]; then sudo apt-get install -y -qq openjdk-21-jdk-headless >/dev/null 2>&1; J=/usr/lib/jvm/java-21-openjdk-amd64; fi
  export JAVA_HOME="$J" PATH="$J/bin:$PATH"
  echo "ghidra: $(basename "$GD"); $(java -version 2>&1 | head -1 | cut -c1-60)" | tee -a "$D/ringkas.txt"
  O3="$D/ghidra_stat.txt"; O4="$D/rng.txt"; OK=0
  for BA in 0x80010000 80010000; do
    rm -rf "$W/gproj"; mkdir -p "$W/gproj"; rm -f "$O3" "$O4"
    PS=()
    if has 3; then PS+=(-postScript StatFungsi.java "$O3" "$W/seed.txt"); fi
    if has 4; then PS+=(-postScript FindRng.java "$O4"); fi
    "$GD/support/analyzeHeadless" "$W/gproj" naruto -import "$W/exe.bin" -processor "MIPS:LE:32:default" -loader BinaryLoader -loader-baseAddr "$BA" -scriptPath "$R/ci/ghidra" -preScript SeedJal.java "$W/seed.txt" "${PS[@]}" > "$W/gh.log" 2>&1 || true
    OK=1
    if has 3 && [ ! -s "$O3" ]; then OK=0; fi
    if has 4 && [ ! -s "$O4" ]; then OK=0; fi
    [ $OK = 1 ] && break
  done
  [ $OK = 1 ] || { grep -aE "ERROR|Exception|rror" "$W/gh.log" | head -8 | cut -c1-170 | tr -cd "\11\12\40-\176"; gagal "ghidra tak menghasilkan keluaran"; }
  if has 3; then cat "$O3" | tee -a "$D/ringkas.txt"; fi
  if has 4; then cat "$O4" | tee -a "$D/ringkas.txt"; fi
fi
for l in 5 6 7 8 9 10; do has $l && echo "langkah $l belum diimplementasikan di skrip ini" | tee -a "$D/ringkas.txt"; done
bad=$(find "$D" -type f \( -size +300k -o -not -name "*.txt" \)) || true; [ -z "$bad" ] || gagal "berkas terlarang: $bad"
git config user.name claude-runner; git config user.email actions@users.noreply.github.com
git add "$D"; git commit -q -m "hasil analisis statis $ID (langkah $LANGKAH)"
for i in 1 2 3 4 5 6 7 8 9 10; do git pull --rebase -q origin "$GITHUB_REF_NAME" && git push -q origin "HEAD:$GITHUB_REF_NAME" && { echo "push ok"; break; }; sleep $((RANDOM % 9 + 3)); done
