#!/bin/bash
# Analisis KODE game dari dump RAM (replay deterministik). Dipanggil .github/workflows/analisis-kode.yml.
# Berkas game, emulator, dump RAM HANYA di $W (folder sementara runner). Yang dikomit: angka/alamat (txt) di analisis_kode/hasil/.
# TAHAP: E = unduh aset + replay (baseline vs dengan-dump, dua kali) + uji identik; P = analisis dump (python); G = impor Ghidra.
set -euo pipefail
R="$PWD"; W="${RUNNER_TEMP:-/tmp}/ak"; mkdir -p "$W"
TAHAP="${TAHAP:-E,P}"; LABEL="${LABEL:-ak}"
[[ "$TAHAP" =~ ^[EPG](,[EPG])*$ ]] || { echo "TAHAP tidak valid"; exit 1; }
[[ "$LABEL" =~ ^[A-Za-z0-9_-]{1,30}$ ]] || { echo "LABEL tidak valid"; exit 1; }
ID="${GITHUB_RUN_ID:-lokal}-${GITHUB_RUN_ATTEMPT:-1}"; D="$R/analisis_kode/hasil/${LABEL}_$ID"; mkdir -p "$D"
LOG="$D/ringkas.txt"; : > "$LOG"
say(){ echo "$*" | tee -a "$LOG"; }
komit(){
  rc=$?; set +e
  bad=$(find "$D" -type f \( -size +300k -o -not -name '*.txt' \)); [ -z "$bad" ] || { echo "berkas terlarang dihapus"; rm -f $bad; }
  git config user.name claude-runner; git config user.email actions@users.noreply.github.com
  git add "$D"; git commit -q -m "analisis kode $ID ($LABEL, tahap $TAHAP, rc=$rc)"
  for i in 1 2 3 4 5 6 7 8 9 10; do git pull --rebase -q origin "$GITHUB_REF_NAME" && git push -q origin "HEAD:$GITHUB_REF_NAME" && { echo "push ok"; break; }; sleep $((RANDOM % 9 + 3)); done
}
trap komit EXIT
gagal(){ say "BERHENTI: $*"; exit 1; }
has(){ [[ ",$TAHAP," == *",$1,"* ]]; }
{ has P || has G; } && ! has E && gagal "tahap P/G butuh E di job yang sama (dump hanya ada di runner)"
has E || gagal "tahap E wajib"

# ---------- unduh aset privat + bangun emulator (salinan pola ci/run_remote.sh, tanpa mengubahnya) ----------
[ -n "${PRIVATE_REPO:-}" ] && [ -n "${PRIVATE_TOKEN:-}" ] || gagal "secret aset kosong"
mkdir -p "$W/dl"
GH_TOKEN="$PRIVATE_TOKEN" gh release download aset -R "$PRIVATE_REPO" -D "$W/dl" -p '*' >/dev/null 2>&1 || gagal "unduh aset gagal"
GAME=$(ls "$W/dl" | grep -iE '\.bin$' | head -1); RED=$(ls "$W/dl" | grep -iE '\.(appimage|zip)$' | head -1)
[ -n "$GAME" ] && [ -n "$RED" ] || gagal "butuh .bin dan .AppImage/.zip di release aset"
mv "$W/dl/$GAME" "$W/dl/game.bin"; mv "$W/dl/$RED" "$W/dl/redux.$(echo "${RED##*.}" | tr 'A-Z' 'a-z')"
cd "$W"
A=$(ls dl/redux.* | head -1)
case "$A" in *.zip) unzip -q -o "$A" -d rz; A=$(find rz -iname '*.AppImage' | head -1);; esac
[ -f "$A" ] || gagal "AppImage tidak ditemukan"
cp "$A" redux.AppImage; chmod +x redux.AppImage; ./redux.AppImage --appimage-extract >/dev/null
python3 "$R/redux/patch_verneed.py" squashfs-root >/dev/null
gcc -shared -fPIC -O2 -o shim243.so "$R/redux/shim243.c" -lm || cp "$R/redux/shim243.so" shim243.so
BIN=$(sed -n 's/^FILE "\(.*\)" BINARY.*/\1/p' "$R/redux/game/naruto.cue" | head -1)
mkdir -p game; cp "$R/redux/game/naruto.cue" game/; mv dl/game.bin "game/$BIN"
say "aset dan emulator siap (game $(stat -c %s "game/$BIN") byte)"
cd "$R"

# ---------- tahap E: replay netral + dump ----------
POKES="9000@70EB8@4@5000,13000@70EB8@4@5000"; ORPOKES="14000-36000@70EBC@4@0x3000"   # jalur baku r13 (STATUS_RINGKAS)
mkjad(){ { echo "# SPUSPEED 4"; echo "# NODEBUG"; grep -v -E '^# *(SPUSPEED|NODEBUG|SVS|SHOT|BOT)' "$R/$1"; } > "$2"; }
mkjad inputs/r13_a.txt "$W/jad_A.txt"; mkjad inputs/s4_F.txt "$W/jad_B.txt"
FA="24500 26659 26900 27500 28700"; MXA=28800   # A=r13_a: dialog papan, sebelum CIRCLE penghenti, setelah berhenti, prompt serang, menu duel
FB="26699 27000 27200"; MXB=27300               # B=s4_F : sebelum CIRCLE penghenti, prompt beli 260, setelah beli
for n in A_base A_d1 A_d2 B_base B_d1 B_d2; do :; done
for n in 1 2 3; do cp -a "$W/squashfs-root" "$W/sq_$n"; done
run1(){ # slot nama jadwal maxf dumps
  local s="$1" n="$2" j="$3" mx="$4" dm="$5"; local o="$W/o_$n"; rm -rf "$o"; mkdir -p "$o" "$W/xdg_$n"; chmod 700 "$W/xdg_$n"
  ( cd "$W/sq_$s" && env INPUTS="$j" MAXF="$mx" OUTDIR="$o" DUMPS="$dm" POKES="$POKES" ORPOKES="$ORPOKES" XDG_RUNTIME_DIR="$W/xdg_$n" SDL_AUDIODRIVER=dummy \
    LD_PRELOAD="$W/shim243.so" LD_LIBRARY_PATH="$PWD/usr/lib" xvfb-run -a -s "-screen 0 1280x720x24" timeout -k 20 900 \
    usr/bin/pcsx-redux -cli -noupdate -interpreter -softgpu -fastboot -loadiso "$W/game/naruto.cue" -run -dofile "$R/analisis_kode/probe_dump.lua" > "$o/emu.log" 2>&1; echo $? > "$o/rc" ) || true
}
t0=$(date +%s)
run1 1 A_base "$W/jad_A.txt" $MXA "" & sleep 4; run1 2 A_d1 "$W/jad_A.txt" $MXA "$FA" & sleep 4; run1 3 A_d2 "$W/jad_A.txt" $MXA "$FA" & wait
t1=$(date +%s)
run1 1 B_base "$W/jad_B.txt" $MXB "" & sleep 4; run1 2 B_d1 "$W/jad_B.txt" $MXB "$FB" & sleep 4; run1 3 B_d2 "$W/jad_B.txt" $MXB "$FB" & wait
t2=$(date +%s)
say "waktu replay: lot A $((t1-t0)) dtk, lot B $((t2-t1)) dtk (3 emulator paralel)"
chgsig(){ grep -aE '^(POKE|ORPOKE|CHG)' "$W/o_$1/emu.log" | md5sum | cut -c1-12; }
nchg(){ grep -ac '^CHG' "$W/o_$1/emu.log" || true; }
ndump(){ grep -ac '^DUMP' "$W/o_$1/emu.log" || true; }
for S in A B; do
  b=$(chgsig ${S}_base); x=$(chgsig ${S}_d1); y=$(chgsig ${S}_d2)
  say "UJI NETRAL $S: rc=$(cat $W/o_${S}_base/rc),$(cat $W/o_${S}_d1/rc),$(cat $W/o_${S}_d2/rc) CHG=$(nchg ${S}_base),$(nchg ${S}_d1),$(nchg ${S}_d2) DUMP=$(ndump ${S}_d1),$(ndump ${S}_d2) md5(POKE/ORPOKE/CHG) base=$b d1=$x d2=$y => d1=base:$([ "$b" = "$x" ] && echo YA || echo TIDAK) d2=base:$([ "$b" = "$y" ] && echo YA || echo TIDAK)"
done
for pair in "A:$FA" "B:$FB"; do
  S="${pair%%:*}"; FL="${pair#*:}"
  for f in $FL; do
    p1="$W/o_${S}_d1/r_$f.bin"; p2="$W/o_${S}_d2/r_$f.bin"
    if [ -f "$p1" ] && [ -f "$p2" ]; then
      if cmp -s "$p1" "$p2"; then say "DUMP $S@$f: ada, identik byte-demi-byte antar-run ($(sha256sum < "$p1" | cut -c1-12))"
      else say "DUMP $S@$f: BEDA antar-run; jumlah byte beda=$(cmp -l "$p1" "$p2" | wc -l); offset beda pertama: $(cmp -l "$p1" "$p2" | head -8 | awk '{printf "0x%X ", $1-1}')"; fi
    else say "DUMP $S@$f: TIDAK ADA (d1=$([ -f "$p1" ] && echo ada || echo tidak) d2=$([ -f "$p2" ] && echo ada || echo tidak))"; fi
  done
done
head -c 600 "$W/o_A_base/emu.log" | tr -cd '\11\12\40-\176' | head -3 | cut -c1-160 | sed 's/^/  emu_awal: /' | tee -a "$LOG" >/dev/null

# ---------- tahap P: analisis dump ----------
if has P || has G; then
  export GH_TOKEN="${GITHUB_TOKEN:-}"
  mkdir -p "$W/mk"; MP=$(sed -n 's/^mkpsxiso=//p' "$R/ci/versi_pin.txt" | head -1 || true)
  gh release download ${MP:+"$MP"} -R Lameguy64/mkpsxiso -D "$W/mk" -p "*Linux*.zip" >/dev/null 2>&1 || gagal "unduh mkpsxiso gagal"
  (cd "$W/mk" && unzip -q -o ./*.zip); DX=$(find "$W/mk" -type f -name dumpsxiso | head -1); chmod +x "$DX"
  "$DX" -x "$W/disc" -s "$W/disc.xml" "$W/game/naruto.cue" > "$W/dump.log" 2>&1 || gagal "dumpsxiso gagal"
  EXE=$(find "$W/disc" -iname "SLPS_035.53" | head -1); [ -n "$EXE" ] || gagal "exe tak ketemu"
  tail -c +2049 "$EXE" > "$W/exe.bin"
  ARGS=(); for f in $FA; do [ -f "$W/o_A_d1/r_$f.bin" ] && ARGS+=("A$f=$W/o_A_d1/r_$f.bin"); done
  for f in $FB; do [ -f "$W/o_B_d1/r_$f.bin" ] && ARGS+=("B$f=$W/o_B_d1/r_$f.bin"); done
  python3 "$R/analisis_kode/an_dump.py" "$W/exe.bin" "$W/disc" --xref=B27000,A28700 "${ARGS[@]}" > "$D/analisis.txt" 2>&1 || say "an_dump.py gagal (lihat analisis.txt)"
  say "analisis.txt: $(wc -l < "$D/analisis.txt") baris"
  head -c 9000 "$D/analisis.txt" | tr -cd '\11\12\40-\176' | tee -a "$LOG" >/dev/null
fi

# ---------- tahap G: impor dump ke Ghidra (headless) ----------
if has G; then
  mkdir -p "$W/gh"; GP=$(sed -n 's/^ghidra=//p' "$R/ci/versi_pin.txt" | head -1 || true)
  gh release download ${GP:+"$GP"} -R NationalSecurityAgency/ghidra -D "$W/gh" -p "ghidra_*_PUBLIC_*.zip" >/dev/null 2>&1 || gagal "unduh ghidra gagal"
  (cd "$W/gh" && unzip -q -o ./ghidra_*.zip); GD=$(find "$W/gh" -maxdepth 1 -type d -name "ghidra_*" | head -1); chmod +x "$GD"/support/* 2>/dev/null || true
  J="${JAVA_HOME_21_X64:-}"; if [ -z "$J" ] || [ ! -x "$J/bin/javac" ]; then sudo apt-get install -y -qq openjdk-21-jdk-headless >/dev/null 2>&1; J=/usr/lib/jvm/java-21-openjdk-amd64; fi
  export JAVA_HOME="$J" PATH="$J/bin:$PATH"
  say "ghidra: $(basename "$GD"); $(java -version 2>&1 | head -1 | cut -c1-60)"
  for LB in ${GLIST:-B27000}; do
    DF="${LB:0:1}"; FR="${LB:1}"; DUMP="$W/o_${DF}_d1/r_$FR.bin"; [ -f "$DUMP" ] || { say "ghidra $LB: dump tak ada"; continue; }
    rm -rf "$W/gproj_$LB"; mkdir -p "$W/gproj_$LB"
    timeout 780 "$GD/support/analyzeHeadless" "$W/gproj_$LB" naruto -import "$DUMP" -processor "MIPS:LE:32:default" -loader BinaryLoader -loader-baseAddr 0x80000000 \
      -analysisTimeoutPerFile 600 -scriptPath "$R/analisis_kode/ghidra" -preScript SeedDump.java "$W/seed_$LB.txt" -postScript OverlayStat.java "$D/ghidra_$LB.txt" > "$W/gh_$LB.log" 2>&1 || true
    if [ -s "$D/ghidra_$LB.txt" ]; then say "ghidra $LB: ok"; cat "$D/ghidra_$LB.txt" | head -c 3500 | tee -a "$LOG" >/dev/null
    else say "ghidra $LB: tanpa keluaran"; grep -aE "ERROR|Exception|rror" "$W/gh_$LB.log" | head -8 | cut -c1-170 | tr -cd '\11\12\40-\176' | tee -a "$LOG" >/dev/null; fi
  done
fi
say "selesai tahap $TAHAP"
