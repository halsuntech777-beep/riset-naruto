#!/bin/bash
# Dijalankan di runner GitHub Actions oleh ci/emulator-run.yml. Sub-perintah: unduh | bangun | jalankan | hasil
# Berkas game/emulator HANYA di $W (folder sementara runner). Yang masuk repositori: angka (log/CSV) di hasil/.
set -euo pipefail
cmd="${1:?sub-perintah}"
R="$PWD"; W="${RUNNER_TEMP:-/tmp}/naruto"; mkdir -p "$W"
LABEL="${LABEL:-uji}"; [[ "$LABEL" =~ ^[A-Za-z0-9_-]{1,30}$ ]] || { echo "LABEL tidak valid"; exit 1; }
ID="${GITHUB_RUN_ID:-lokal}-${GITHUB_RUN_ATTEMPT:-1}"; D="$R/hasil/${LABEL}_$ID"
gagal(){ echo "BERHENTI: $*"; exit 1; }

# Diagnostik galat ikut di-commit (disaring), kecuali 'unduh' (bisa memuat nama repositori privat).
if [[ "$cmd" == bangun || "$cmd" == jalankan ]]; then
  exec > >(tee "$W/log_$cmd.txt") 2>&1
  trap 'rc=$?; if [ $rc -ne 0 ]; then mkdir -p "$D"; { echo "perintah=$cmd rc=$rc"; tail -n 40 "$W/log_$cmd.txt" | tr -cd "\11\12\40-\176" | cut -c1-200; } > "$D/galat_$cmd.txt"; fi' EXIT
fi

case "$cmd" in
unduh)
  SRC="${PRIVATE_REPO:-$GITHUB_REPOSITORY}"; export GH_TOKEN="${PRIVATE_TOKEN:-$GITHUB_TOKEN}"; TAG="${ASET_TAG:-aset}"
  mkdir -p "$D"; G="$D/galat_unduh.txt"; : > "$G"
  # Diagnostik hanya berisi kode tetap/status HTTP/nama aset yang dikenal (tanpa nama repo atau token).
  echo "secret PRIVATE_REPO: $([ -n "${PRIVATE_REPO:-}" ] && echo terisi || echo KOSONG-mode-a); PRIVATE_TOKEN: $([ -n "${PRIVATE_TOKEN:-}" ] && echo terisi || echo KOSONG)" >> "$G"
  c=$(curl -s -o "$W/r.json" -w '%{http_code}' -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$SRC" || true)
  pv=$(python3 -c "import json;print(json.load(open('$W/r.json')).get('private'))" 2>/dev/null || echo ?)
  echo "akses repo aset: HTTP $c; private=$pv" >> "$G"
  [ "$c" = "200" ] && [ "$pv" = "True" ] || gagal "sumber aset tidak terbaca atau bukan repositori privat (lihat galat_unduh.txt)."
  c=$(curl -s -o "$W/rel.json" -w '%{http_code}' -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$SRC/releases/tags/$TAG" || true)
  echo "release $TAG: HTTP $c" >> "$G"
  python3 - "$W/rel.json" >> "$G" 2>/dev/null <<'PY' || true
import json,sys,re
d=json.load(open(sys.argv[1]))
for a in d.get("assets",[]):
    n=a["name"]; print("aset:", n if re.fullmatch(r"game\.bin|redux\.[A-Za-z]+",n) else "(ekstensi ." + n.rsplit(".",1)[-1].lower()[:8] + ")", round(a["size"]/1e6,1),"MB", a["state"])
if not d.get("assets"): print("aset: tidak ada")
PY
  mkdir -p "$W/dl"
  gh release download "$TAG" -R "$SRC" -D "$W/dl" -p '*' >/dev/null 2>&1 || gagal "unduh aset gagal."
  # Nama aset bebas: game = berkas .bin; emulator = .AppImage atau .zip; .cue diabaikan (sudah ada di repo).
  GAME=$(ls "$W/dl" | grep -iE '\.bin$' | head -1); RED=$(ls "$W/dl" | grep -iE '\.(appimage|zip)$' | head -1)
  [ -n "$GAME" ] && [ -n "$RED" ] || gagal "butuh satu berkas .bin (game) dan satu .AppImage/.zip (emulator) di release '$TAG'."
  mv "$W/dl/$GAME" "$W/dl/game.bin"; mv "$W/dl/$RED" "$W/dl/redux.$(echo "${RED##*.}" | tr 'A-Z' 'a-z')"
  rm -f "$G"; ls "$W/dl" | sed 's/^game\.bin$/game.bin (ok)/'
  ;;
bangun)
  cd "$W"
  A=$(ls dl/redux.* | head -1)
  case "$A" in *.zip) unzip -q -o "$A" -d rz; A=$(find rz -iname '*.AppImage' | head -1);; esac
  [ -f "$A" ] || gagal "AppImage tidak ditemukan"
  cp "$A" redux.AppImage; chmod +x redux.AppImage
  ./redux.AppImage --appimage-extract >/dev/null
  echo "tambalan glibc: $(python3 "$R/redux/patch_verneed.py" squashfs-root | wc -l) berkas"
  gcc -shared -fPIC -O2 -o shim243.so "$R/redux/shim243.c" -lm || { echo "kompilasi shim gagal, pakai shim bawaan repo"; cp "$R/redux/shim243.so" shim243.so; }
  BIN=$(sed -n 's/^FILE "\(.*\)" BINARY.*/\1/p' "$R/redux/game/naruto.cue" | head -1)
  mkdir -p game; cp "$R/redux/game/naruto.cue" game/; mv dl/game.bin "game/$BIN"
  echo "siap"
  ;;
jalankan)
  JADWAL="${JADWAL:-inputs/inputs_2p.txt}"; MAXF="${MAXF:-7000}"
  P='[0-9]+@[0-9A-Fa-f]+@[24]@[0-9]+'; Q='[0-9]+(-[0-9]+)?@[0-9A-Fa-f]+@[24]@(0x[0-9A-Fa-f]+|[0-9]+)'
  [[ "$JADWAL" =~ ^inputs/[A-Za-z0-9_.-]+\.txt$ && -f "$R/$JADWAL" ]] || gagal "JADWAL tidak valid"
  [[ "$MAXF" =~ ^[0-9]{1,6}$ ]] || gagal "MAXF tidak valid"
  [[ -z "${POKES:-}" || "$POKES" =~ ^$P(,$P)*$ ]] || gagal "POKES tidak valid"
  [[ -z "${ORPOKES:-}" || "$ORPOKES" =~ ^$Q(,$Q)*$ ]] || gagal "ORPOKES tidak valid"
  [[ -z "${DUMPS:-}" || "$DUMPS" =~ ^[0-9]+( [0-9]+){0,19}$ ]] || gagal "DUMPS tidak valid (maks 20 frame, pisah spasi)"
  [[ -z "${SAVEF:-}" || "$SAVEF" =~ ^[0-9]{1,6}$ ]] || gagal "SAVEF tidak valid"
  [[ -z "${LOADF:-}" || "$LOADF" =~ ^[0-9]{1,6}$ ]] || gagal "LOADF tidak valid"
  [[ -z "${MODUS:-}" || "$MODUS" =~ ^[a-z]{1,8}$ ]] || gagal "MODUS tidak valid"
  ADDRS="${ADDRS:-0x1EFBBC:4,0x1EFC4C:4,0x1EFCDC:4,0x1EFD6C:4,0x70EB8:4,0x70EBC:4,0x70F6C:4,0x71020:4,0x710D4:4}"
  OUT="$W/out"; rm -rf "$OUT"; mkdir -p "$OUT" "$W/xdg"; chmod 700 "$W/xdg"; mkdir -p "$D"
  export INPUTS="$R/$JADWAL" MAXF OUTDIR="$OUT" DUMPS="${DUMPS:-}" POKES="${POKES:-}" ORPOKES="${ORPOKES:-}" SAVEF="${SAVEF:-}" LOADF="${LOADF:-}" MODUS="${MODUS:-}"
  export XDG_RUNTIME_DIR="$W/xdg" SDL_AUDIODRIVER=dummy
  cd "$W/squashfs-root"
  if [ "${MODUS:-}" = "apiuji" ]; then  # diagnostik save-state TANPA game: hanya nama/tipe/angka
    : > "$D/api_uji.txt"
    for spec in "a|-debugger"; do
      v=${spec%%|*}; ex=${spec#*|}
      echo "=== varian $v extra=$ex ===" >> "$D/api_uji.txt"
      set +e
      APIV=$v APIPATH="$W/ss_apiuji.bin" xvfb-run -a -s "-screen 0 1280x720x24" timeout -k 5 60 env LD_PRELOAD="$W/shim243.so" LD_LIBRARY_PATH="$PWD/usr/lib" \
        usr/bin/pcsx-redux -cli -noupdate -interpreter -softgpu $ex -run -dofile "$R/redux/lua_mine/apiuji.lua" > "$W/api_$v.log" 2>&1
      rc=$?; set -e
      grep -a '^API ' "$W/api_$v.log" | tr -cd '\11\12\40-\176' | cut -c1-400 | head -n 60 >> "$D/api_uji.txt" || true
      echo "(rc=$rc)" >> "$D/api_uji.txt"
      rm -f "$W/ss_apiuji.bin"
    done
    echo "mode apiuji selesai"; exit 0
  fi
  if [ "${MODUS:-}" = "ssuji" ]; then  # diagnostik TANPA game: pohon settings + kecepatan; serialisasi state ke berkas (3 cara)
    : > "$D/api_uji.txt"
    for spec in "spd8|spd|-|-|Speed=8" "spd16|spd|-|-|Speed=16" "spd64|spd|-|-|Speed=64" "f_sl|ser|file|sl|-" "f_hb|ser|file|hb|-"; do
      IFS='|' read -r v apiv apis apim apik <<< "$spec"; apik=${apik//;/,}; [ "$apik" = "-" ] && apik=""
      echo "=== varian $v ===" >> "$D/api_uji.txt"
      set +e
      APIV=$apiv APIS=$apis APIM=$apim APIK="$apik" APIPATH="$W/ss_uji.bin" xvfb-run -a -s "-screen 0 1280x720x24" timeout -k 5 90 env LD_PRELOAD="$W/shim243.so" LD_LIBRARY_PATH="$PWD/usr/lib" \
        usr/bin/pcsx-redux -cli -noupdate -interpreter -softgpu -debugger -run -dofile "$R/redux/lua_mine/ssuji.lua" > "$W/uji_$v.log" 2>&1
      rc=$?; set -e
      grep -a '^API ' "$W/uji_$v.log" | awk '!s[$0]++' | tr -cd '\11\12\40-\176' | cut -c1-420 | head -n 300 >> "$D/api_uji.txt" || true
      echo "(rc=$rc)" >> "$D/api_uji.txt"
      rm -f "$W/ss_uji.bin"
    done
    echo "mode ssuji selesai"; exit 0
  fi
  if [ "${MODUS:-}" = "guiuji" ]; then  # uji TANPA game: kecepatan, API GPU, bentuk screenshot, skema state; hanya nama/tipe/angka
    : > "$D/api_uji.txt"
    export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe MESA_GL_VERSION_OVERRIDE=4.5 MESA_GLSL_VERSION_OVERRIDE=450
    for n in egl cli; do
      echo "=== varian $n ===" >> "$D/api_uji.txt"
      set +e
      if [ "$n" = "egl" ]; then
        xvfb-run -a -s "-screen 0 1280x720x24 +extension GLX +render -noreset" timeout -k 5 170 env SDL_VIDEO_FORCE_EGL=1 LD_PRELOAD="$W/shim243.so" LD_LIBRARY_PATH="$PWD/usr/lib" \
          usr/bin/pcsx-redux -noupdate -interpreter -softgpu -run -dofile "$R/redux/lua_mine/guiuji.lua" > "$W/gui_$n.log" 2>&1
      else
        xvfb-run -a -s "-screen 0 1280x720x24" timeout -k 5 100 env LD_PRELOAD="$W/shim243.so" LD_LIBRARY_PATH="$PWD/usr/lib" \
          usr/bin/pcsx-redux -cli -noupdate -interpreter -softgpu -debugger -run -dofile "$R/redux/lua_mine/guiuji.lua" > "$W/gui_$n.log" 2>&1
      fi
      rc=$?; set -e
      grep -a '^API ' "$W/gui_$n.log" | sed 's/ *$//' | sort -u | tr -cd '\11\12\40-\176' | cut -c1-700 | head -n 90 >> "$D/api_uji.txt" || true
      echo "(rc=$rc)" >> "$D/api_uji.txt"
    done
    echo "mode guiuji selesai"; exit 0
  fi
  if [ "${MODUS:-}" = "bantuan" ]; then  # hanya teks bantuan emulator (bukan isi game); TIDAK menjalankan game
    : > "$D/bantuan.txt"
    for v in "-cli -noupdate -help" "-cli -noupdate --help" "-cli -noupdate -h"; do
      echo "=== varian: $v ===" >> "$D/bantuan.txt"
      xvfb-run -a -s "-screen 0 1280x720x24" timeout -k 5 30 env LD_PRELOAD="$W/shim243.so" LD_LIBRARY_PATH="$PWD/usr/lib" usr/bin/pcsx-redux $v 2>&1 | tr -cd '\11\12\40-\176' | cut -c1-200 | head -n 200 >> "$D/bantuan.txt" || true
      echo "(rc_pipa=${PIPESTATUS[0]})" >> "$D/bantuan.txt"
    done
    { echo "=== string biner emulator (nama opsi/API; teks emulator saja) ==="; python3 - <<'PYEOF' >> "$D/bantuan.txt" || true
import re
d=open('usr/bin/pcsx-redux','rb').read()
out=set()
for m in re.finditer(rb'[\x21-\x7e]{3,40}', d):
    t=m.group().decode()
    l=t.lower()
    if re.fullmatch(r'-{0,2}[a-z][a-z0-9_-]*', l) and re.search(r'state|sstate|savest|loadst|resume|restore|snapshot|^-?(load|run|cli|dofile|bios|stdout|lua_stdout|testmode|safe|portable|noupdate|fastboot|interpreter|dynarec|softgpu|debugger|no[a-z-]+)$', l):
        out.add(t)
key=lambda t:(not re.search(r'state|snapshot|restore|resume',t.lower()),t)
for t in sorted(out,key=key)[:140]: print(t)
PYEOF
    }
    echo "mode bantuan selesai"; exit 0
  fi
  if [ "${MODUS:-}" = "xs" ] || [ "${MODUS:-}" = "xb" ] || [ "${MODUS:-}" = "xv" ]; then  # state lintas PROSES: penulis simpan state sementara -> pembaca (proses baru) memuat; state tidak keluar dari runner
    EMU_DBG="-debugger"; EMU_CPU="-interpreter"
    grep -q '^# NODEBUG' "$R/$JADWAL" && EMU_DBG=""
    grep -q '^# DYNAREC' "$R/$JADWAL" && EMU_CPU="-dynarec"
    run_emu(){ set +e; xvfb-run -a -s "-screen 0 1280x720x24" timeout -k 20 "$2" env LD_PRELOAD="$W/shim243.so" LD_LIBRARY_PATH="$PWD/usr/lib" \
      usr/bin/pcsx-redux -cli -noupdate $EMU_CPU -softgpu $EMU_DBG -fastboot -loadiso "$W/game/naruto.cue" -run -dofile "$R/redux/lua_mine/probe.lua" > "$1" 2>&1; XRC=$?; set -e; return 0; }
    F='^(probe siap|POKE|ORPOKE|CHG|HSH|SVS|XS|TIME)'
    export STATEOUT="$W/state.bin" STATEIN=""
    t0=$(date +%s); run_emu "$W/emu_w.log" 900; t1=$(date +%s); rcw=$XRC
    grep -aE "$F" "$W/emu_w.log" | head -n 3000 > "$D/chg_w.log" || true
    echo "flags cpu=$EMU_CPU debug=${EMU_DBG:-tidak}"; echo "penulis rc=$rcw detik=$((t1-t0)) state_bytes=$(stat -c %s "$W/state.bin" 2>/dev/null || echo 0)" > "$D/ringkasan.txt"
    export STATEOUT=""
    if [ "$MODUS" = "xv" ]; then  # uji banyak VARIAN state (L = frame SAVEF, E = state awal "# SAVEF2 n"); semua state sementara, dihapus di akhir; hanya angka keluar
      SF2=$(grep -m1 '^# SAVEF2 ' "$R/$JADWAL" | awk '{print $3}' || true); [[ "$SF2" =~ ^[0-9]{1,6}$ ]] || SF2=3000
      SFL="$SAVEF"; PB="python3 $R/ci/pbx.py"; : > "$D/varian.txt"
      VTO=$(grep -m1 '^# VTO ' "$R/$JADWAL" | awk '{print $3}' || true); [[ "$VTO" =~ ^[0-9]{1,3}$ ]] || VTO=40; [ "$VTO" -le 280 ] || VTO=280
      ONLY=$(grep -m1 '^# ONLY ' "$R/$JADWAL" | cut -d' ' -f3- || true); [[ -z "$ONLY" || "$ONLY" =~ ^[A-Za-z0-9_*\ ]{1,200}$ ]] || ONLY=""
      if [ -s "$W/state.bin" ]; then
        mv "$W/state.bin" "$W/stL.bin"
        export STATEOUT="$W/state.bin" STATEIN="" SAVEF="$SF2"
        run_emu "$W/emu_w2.log" 300
        grep -aE "$F" "$W/emu_w2.log" | head -n 20 > "$D/chg_w2.log" || true
        if [ -s "$W/state.bin" ]; then mv "$W/state.bin" "$W/stE.bin"; fi
        export STATEOUT="" SAVEF="$SFL"
        { echo "L frame=$SFL bytes=$(stat -c %s "$W/stL.bin")  E frame=$SF2 bytes=$(stat -c %s "$W/stE.bin" 2>/dev/null || echo 0)"
          for st in L E; do echo "-- nums $st 6.6.1"; $PB nums "$W/st$st.bin" 6.6.1 4 2>&1 | head -n 4; for pth in 6 6.6; do echo "-- $st $pth"; $PB subs "$W/st$st.bin" $pth 2>&1 | head -n 3; $PB shape "$W/st$st.bin" $pth 2>&1 | head -n 4; done; done; } > "$D/struktur.txt" || true
        runvar(){  # $1 nama, $2 frame dasar; $W/var.bin sudah dibuat
          if [ -n "$ONLY" ]; then okv=0; set -f; for pat in $ONLY; do case "$1" in $pat) okv=1;; esac; done; set +f; if [ "$okv" = 0 ]; then rm -f "$W/var.bin"; return 0; fi; fi
          export STATEIN="$W/var.bin" LSITE=top SAVEF="$2" HFROM="$2" HSTEP=20 MAXF=$(( $2 + 100 ))
          t0=$(date +%s); run_emu "$W/emu_v.log" "$VTO"; t1=$(date +%s)
          { echo "== $1 base=$2 ukuran=$(stat -c %s "$W/var.bin") rc=$XRC detik=$((t1-t0)) muat_selesai=$(grep -ac 'XS muat selesai ok=true' "$W/emu_v.log" || true) HSH=$(grep -ac '^HSH' "$W/emu_v.log" || true)"
            grep -aE '^XS (sesudah_muat|nilai|tick|resume|vsync)' "$W/emu_v.log" | head -n 9 | cut -c1-300 || true
            grep -aE '^HSH' "$W/emu_v.log" | head -n 2 || true; } >> "$D/varian.txt"
          rm -f "$W/var.bin"
        }
        if [ -s "$W/stE.bin" ]; then cp "$W/stE.bin" "$W/var.bin"; runvar c0_E_asli "$SF2"; fi
        cp "$W/stL.bin" "$W/var.bin"; runvar c1_L_asli "$SFL"
        $PB drop "$W/stL.bin" "$W/var.bin" 6.6 && runvar d66 "$SFL" || true
        $PB drop "$W/stL.bin" "$W/var.bin" 6 && runvar d6 "$SFL" || true
        if [ -s "$W/stE.bin" ]; then
          $PB swap "$W/stL.bin" "$W/stE.bin" "$W/var.bin" 6 >/dev/null && runvar s6_dariE "$SFL" || true
          $PB swap "$W/stL.bin" "$W/stE.bin" "$W/var.bin" 6.6 >/dev/null && runvar s66_dariE "$SFL" || true
          $PB swap "$W/stE.bin" "$W/stL.bin" "$W/var.bin" 6.6 >/dev/null && runvar e66_dariL "$SF2" || true
          $PB swap "$W/stE.bin" "$W/stL.bin" "$W/var.bin" 6 >/dev/null && runvar e6_dariL "$SF2" || true
        fi
        if [ -s "$W/stE.bin" ]; then
          $PB drop "$W/stE.bin" "$W/var.bin" 6.6 && runvar e_d66 "$SF2" || true
          $PB drop "$W/stE.bin" "$W/var.bin" 6 && runvar e_d6 "$SF2" || true
        fi
        for k in $($PB subs "$W/stL.bin" 6.6.1 | head -n 1 || true); do
          $PB drop "$W/stL.bin" "$W/var.bin" 6.6.1.$k && runvar "d661_$k" "$SFL" || true
        done
        for k in $($PB subs "$W/stL.bin" 6.6 | head -n 1 || true); do
          $PB drop "$W/stL.bin" "$W/var.bin" 6.6.$k && runvar "d66_$k" "$SFL" || true
        done
      fi
      rm -f "$W/state.bin" "$W/stL.bin" "$W/stE.bin" "$W/var.bin"; cat "$D/ringkasan.txt" "$D/varian.txt" | head -n 120; echo "mode xv selesai"; exit 0
    fi
    if [ -s "$W/state.bin" ] && [ "$MODUS" = "xb" ]; then
      python3 "$R/ci/pbsplit.py" struct "$W/state.bin" | head -n 400 > "$D/pb_struct.txt" || true
      PATHS=$(python3 "$R/ci/pbsplit.py" list "$W/state.bin" 150); echo "jalur: $PATHS" >> "$D/ringkasan.txt"
      : > "$D/bisect.txt"
      for p in 0 $PATHS; do
        python3 "$R/ci/pbsplit.py" drop "$W/state.bin" "$W/var.bin" "$p" || { echo "$p gagal_drop" >> "$D/bisect.txt"; continue; }
        export STATEIN="$W/var.bin" LSITE=top HFROM=24000 HSTEP=20 MAXF=24100
        run_emu "$W/emu_v.log" 60
        echo "drop=$p ukuran=$(stat -c %s "$W/var.bin") rc=$XRC muat_selesai=$(grep -ac 'XS muat selesai ok=true' "$W/emu_v.log") sesudah_muat=$(grep -ac '^XS sesudah_muat' "$W/emu_v.log") HSH=$(grep -ac '^HSH' "$W/emu_v.log")" >> "$D/bisect.txt"
        rm -f "$W/var.bin"
      done
    elif [ -s "$W/state.bin" ]; then
      for site in top nt vs1; do
        python3 "$R/ci/pbsplit.py" drop "$W/state.bin" "$W/state_f.bin" 1.2 || cp "$W/state.bin" "$W/state_f.bin"
        export STATEIN="$W/state_f.bin" LSITE=$site HFROM=24000 HSTEP=20
        t0=$(date +%s); run_emu "$W/emu_r_$site.log" 400; t1=$(date +%s)
        grep -aE "$F" "$W/emu_r_$site.log" | head -n 3000 > "$D/chg_r_$site.log" || true
        tail -n 6 "$W/emu_r_$site.log" | tr -cd '\11\12\40-\176' | cut -c1-160 > "$D/ekor_r_$site.txt"
        echo "pembaca site=$site rc=$XRC detik=$((t1-t0)) baris_HSH=$(grep -c '^HSH' "$D/chg_r_$site.log" || true)" >> "$D/ringkasan.txt"
      done
    fi
    rm -f "$W/state.bin" "$W/state_f.bin" "$W/var.bin"; cat "$D/ringkasan.txt"; echo "mode xs selesai"; exit 0
  fi
  # flag cepat lewat header jadwal (baku tidak berubah): "# NODEBUG" = tanpa -debugger; "# SPUSPEED n" dibaca probe.lua
  EMU_DBG0="-debugger"; grep -q '^# NODEBUG' "$R/$JADWAL" && EMU_DBG0=""
  EMU_CPU0="-interpreter"
  t0=$(date +%s); set +e
  xvfb-run -a -s "-screen 0 1280x720x24" timeout -k 20 "${BATAS_DETIK:-$([ -n "${SAVEF:-}" ] && echo 900 || echo 1500)}" \
    env LD_PRELOAD="$W/shim243.so" LD_LIBRARY_PATH="$PWD/usr/lib" \
    usr/bin/pcsx-redux -cli -noupdate ${EMU_CPU0:--interpreter} -softgpu ${EMU_DBG0--debugger} -fastboot -loadiso "$W/game/naruto.cue" -run -dofile "$R/redux/lua_mine/probe.lua" > "$W/emu.log" 2>&1
  rc=$?; set -e; t1=$(date +%s)
  grep -aE '^(probe siap|POKE|ORPOKE|CHG|DUMP|HSH|HSF|SVS|TIME)' "$W/emu.log" | head -n 5000 > "$D/chg.log" || true
  tail -n 30 "$W/emu.log" | tr -cd '\11\12\40-\176' | cut -c1-200 > "$D/emu_tail.txt"
  if [ -n "${DUMPS:-}" ]; then python3 "$R/ci/ekstrak_dump.py" "$OUT" "$D/dump_angka.csv" "$ADDRS" || true; fi
  if ls "$OUT"/s*.raw >/dev/null 2>&1; then python3 "$R/ci/enkripsi_shot.py" "$OUT" "$D" "$R/ci/shot_pub.pem" | tee -a "$D/chg.log" | sed "s/^/  /" || true; fi  # tangkapan layar: HANYA terenkripsi (kunci publik) keluar
  rm -rf "$OUT"/*   # dump/screenshot mentah tidak pernah keluar dari runner
  {
    echo "jadwal=$JADWAL maxf=$MAXF pokes=${POKES:-} orpokes=${ORPOKES:-} dumps=${DUMPS:-}"
    echo "rc_emulator=$rc (0=selesai MAXF, 124=timeout) detik=$((t1-t0)) baris_emu_log=$(wc -l < "$W/emu.log")"
    echo "md5_chg_log=$(md5sum < "$D/chg.log" | cut -c1-32) jumlah_CHG=$(grep -c '^CHG' "$D/chg.log" || true)"
    echo "--- nilai terakhir per alamat pantau ---"
    grep '^CHG' "$D/chg.log" | awk '{l[$3]=$0} END{for(k in l)print l[k]}' | sort
  } > "$D/ringkasan.txt"
  cat "$D/ringkasan.txt"
  exit $rc
  ;;
hasil)
  [ -d "$D" ] || { echo "tidak ada hasil"; exit 0; }
  bad=$(find "$D" -type f \( -size +300k -o -not -regex '.*\.\(txt\|csv\|log\)' \)) || true
  [ -z "$bad" ] || { echo "Berkas terlarang/terlalu besar, TIDAK di-commit:"; echo "$bad"; exit 1; }
  for f in "$D"/shot_*; do [ -e "$f" ] || continue; [[ "$f" =~ /shot_[0-9]{5}\.enc\.txt$ ]] && [ "$(head -c4 "$f")" = "ENC1" ] || { echo "shot tidak terenkripsi/tidak valid, TIDAK di-commit: $f"; exit 1; }; done
  [ "$(ls "$D"/shot_* 2>/dev/null | wc -l)" -le 8 ] || { echo "terlalu banyak shot"; exit 1; }
  git config user.name "emulator-runner"; git config user.email "actions@users.noreply.github.com"
  git add "$D"; git commit -q -m "hasil run $ID ($LABEL)"
  for i in 1 2 3 4 5 6 7 8 9 10; do git pull --rebase -q origin "$GITHUB_REF_NAME" && git push -q origin "HEAD:$GITHUB_REF_NAME" && { echo "push ok"; break; }; sleep $((RANDOM % 9 + 3)); done
  ;;
*) gagal "sub-perintah tak dikenal" ;;
esac
