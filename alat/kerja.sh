#!/usr/bin/env bash
# Alat HEMAT PANGGILAN (satu panggilan = banyak langkah). Token lewat env T, disisipkan inline per perintah; TIDAK pernah ditulis ke disk.
# Pakai: T=<token> bash alat/kerja.sh <sub> ...
#   tarik                          git pull --rebase
#   dorong "pesan"                 add -A + commit + pull --rebase + push
#   jalan LABEL JADWAL MAXF [MODUS] [DUMPS] [ADDRS]  dispatch jalur baku r13 (pokes/orpokes baku) -> cetak "LABEL run_id"
#   tunggu DETIK ID...             polling tiap 10 dtk sampai SEMUA ID selesai atau batas DETIK (uji: <= 280 aman)
#   lihat LABEL                    tarik + ringkasan angka hasil/<LABEL>_* terbaru (alat/ringkas.py)
#   env PK= OPK= (di-set kosong) pada jalan = TANPA poke RAM; tidak di-set = poke baku (9000/13000 B1=5000; orpoke 0x3000)
set -u
R=halsuntech777-beep/riset-naruto
[ -n "${T:-}" ] || { echo "env T (token) kosong"; exit 2; }
cd "$(dirname "$0")/.."
H="http.extraheader=Authorization: Basic $(printf 'x-access-token:%s' "$T" | base64 -w0)"
api(){ curl -s -H "Authorization: Bearer $T" -H "Accept: application/vnd.github+json" "$@"; }
ids(){ api "https://api.github.com/repos/$R/actions/runs?event=workflow_dispatch&per_page=15" | python3 -c "import sys,json; print(' '.join(str(r['id']) for r in json.load(sys.stdin)['workflow_runs']))"; }
case "${1:-}" in
tarik) git -c "$H" pull --rebase -q origin main 2>&1 | tail -2;;
dorong) git config user.name claude; git config user.email claude@users.noreply.github.com; git rebase --abort 2>/dev/null; git add -A; git -c user.name=claude -c user.email=claude@users.noreply.github.com commit -q -m "${2:-Sesi: pembaruan}" 2>&1 | tail -1
  git -c "$H" pull --rebase -q origin main 2>&1 | tail -2; git -c "$H" push -q origin main 2>&1 | tail -2; git log --oneline | head -1;;
jalan) L=$2; J=$3; M=$4; MO=${5:-}; DU=${6:-}; AD=${7:-}; before=" $(ids) "
  c=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "Authorization: Bearer $T" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$R/actions/workflows/emulator-run.yml/dispatches" \
    -d "{\"ref\":\"main\",\"inputs\":{\"jadwal\":\"$J\",\"maxf\":\"$M\",\"pokes\":\"${PK-9000@70EB8@4@5000,13000@70EB8@4@5000}\",\"orpokes\":\"${OPK-14000-36000@70EBC@4@0x3000}\",\"modus\":\"$MO\",\"dumps\":\"$DU\",\"addrs\":\"$AD\",\"label\":\"$L\"}}")
  [ "$c" = 204 ] || { echo "dispatch gagal http=$c"; exit 1; }
  for i in 1 2 3 4 5 6 7 8; do sleep 4; for id in $(ids); do case "$before" in *" $id "*) ;; *) echo "$L $id"; exit 0;; esac; done; done; echo "$L id-tidak-ketemu";;
tunggu) D=$2; shift 2; t0=$(date +%s)
  while :; do all=1; out=""; for id in "$@"; do s=$(api "https://api.github.com/repos/$R/actions/runs/$id" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r['status'],r['conclusion'])"); out="$out $id:$s"; case "$s" in completed*) ;; *) all=0;; esac; done
    [ $all = 1 ] && { echo "SELESAI$out"; exit 0; }; [ $(( $(date +%s) - t0 )) -ge "$D" ] && { echo "BELUM (${D}s)$out"; exit 0; }; sleep 10; done;;
lihat) git -c "$H" pull --rebase -q origin main 2>&1 | tail -2; d=$(ls -d hasil/${2}_[0-9]* 2>/dev/null | sort -V | tail -1); echo "DIR=$d"; python3 alat/ringkas.py "$d";;
*) sed -n '2,10p' "$0";;
esac
