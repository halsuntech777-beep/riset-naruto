#!/usr/bin/env bash
# Dispatch workflow analisis-statis + tunggu + tarik hasil + ringkasan, SATU panggilan.
# Token lewat env T (inline per perintah; tidak pernah ditulis ke disk).
# Pakai: T=<token> bash alat/analisis.sh LANGKAH [DETIK=270] [ALAMAT]
#   contoh: T=<token> bash alat/analisis.sh 2 270
set -u
R=halsuntech777-beep/riset-naruto; WF=analisis-statis.yml
[ -n "${T:-}" ] || { echo "env T (token) kosong"; exit 2; }
L=${1:?langkah}; D=${2:-270}; AD=${3:-}
cd "$(dirname "$0")/.."
H="http.extraheader=Authorization: Basic $(printf 'x-access-token:%s' "$T" | base64 -w0)"
api(){ curl -s -H "Authorization: Bearer $T" -H "Accept: application/vnd.github+json" "$@"; }
ids(){ api "https://api.github.com/repos/$R/actions/workflows/$WF/runs?per_page=10" | python3 -c "import sys,json; print(' '.join(str(r['id']) for r in json.load(sys.stdin)['workflow_runs']))"; }
before=" $(ids) "
c=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $T" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$R/actions/workflows/$WF/dispatches" -d "{\"ref\":\"main\",\"inputs\":{\"langkah\":\"$L\",\"alamat\":\"$AD\"}}")
[ "$c" = 204 ] || { echo "dispatch gagal http=$c"; exit 1; }
ID=""
for i in 1 2 3 4 5 6 7 8; do sleep 4; for id in $(ids); do case "$before" in *" $id "*) ;; *) ID=$id; break 2;; esac; done; done
[ -n "$ID" ] || { echo "id-tidak-ketemu"; exit 1; }
echo "run $ID dimulai $(date -u +%H:%M:%S) UTC"
t0=$(date +%s); S=""
while :; do
  S=$(api "https://api.github.com/repos/$R/actions/runs/$ID" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['status'],r['conclusion'])")
  case "$S" in completed*) break;; esac
  [ $(( $(date +%s) - t0 )) -ge "$D" ] && break
  sleep 8
done
echo "status: $S ($(( $(date +%s) - t0 )) dtk)"
case "$S" in
completed*)
  case "$S" in *success*) ;; *) api "https://api.github.com/repos/$R/actions/runs/$ID/jobs" | python3 -c "import sys,json; [print('GAGAL langkah:',s['name']) for j in json.load(sys.stdin)['jobs'] for s in j['steps'] if s['conclusion']=='failure']";; esac
  git -c "$H" pull --rebase -q origin main 2>&1 | tail -2
  d=$(ls -d hasil_analisis/l${L//,/_}_${ID}-* 2>/dev/null | tail -1); echo "DIR=$d"
  [ -n "$d" ] && cut -c1-220 "$d/ringkas.txt" | head -80;;
*) echo "BELUM selesai; sekarang $(date -u +%H:%M) UTC = $(TZ=Asia/Jakarta date +%H:%M) WIB";;
esac
