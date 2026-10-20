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
  ADDRS="${ADDRS:-0x1EFBBC:4,0x1EFC4C:4,0x1EFCDC:4,0x1EFD6C:4,0x70EB8:4,0x70EBC:4,0x70F6C:4,0x71020:4,0x710D4:4}"
  OUT="$W/out"; rm -rf "$OUT"; mkdir -p "$OUT" "$W/xdg"; chmod 700 "$W/xdg"; mkdir -p "$D"
  export INPUTS="$R/$JADWAL" MAXF OUTDIR="$OUT" DUMPS="${DUMPS:-}" POKES="${POKES:-}" ORPOKES="${ORPOKES:-}"
  export XDG_RUNTIME_DIR="$W/xdg" SDL_AUDIODRIVER=dummy
  cd "$W/squashfs-root"; t0=$(date +%s); set +e
  xvfb-run -a -s "-screen 0 1280x720x24" timeout "${BATAS_DETIK:-1500}" \
    env LD_PRELOAD="$W/shim243.so" LD_LIBRARY_PATH="$PWD/usr/lib" \
    usr/bin/pcsx-redux -cli -noupdate -interpreter -softgpu -debugger -fastboot -loadiso "$W/game/naruto.cue" -run -dofile "$R/redux/lua_mine/probe.lua" > "$W/emu.log" 2>&1
  rc=$?; set -e; t1=$(date +%s)
  grep -aE '^(probe siap|POKE|ORPOKE|CHG|DUMP|HSH|HSF)' "$W/emu.log" | head -n 5000 > "$D/chg.log" || true
  tail -n 30 "$W/emu.log" | tr -cd '\11\12\40-\176' | cut -c1-200 > "$D/emu_tail.txt"
  if [ -n "${DUMPS:-}" ]; then python3 "$R/ci/ekstrak_dump.py" "$OUT" "$D/dump_angka.csv" "$ADDRS" || true; fi
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
  git config user.name "emulator-runner"; git config user.email "actions@users.noreply.github.com"
  git add "$D"; git commit -q -m "hasil run $ID ($LABEL)"
  for i in 1 2 3 4; do git pull --rebase -q origin "$GITHUB_REF_NAME" && git push -q origin "HEAD:$GITHUB_REF_NAME" && { echo "push ok"; break; }; sleep 5; done
  ;;
*) gagal "sub-perintah tak dikenal" ;;
esac
