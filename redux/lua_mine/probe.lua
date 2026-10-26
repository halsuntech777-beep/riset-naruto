-- probe: input terjadwal + polling uang (2 pemain) + dump RAM + screenshot + poke memori
local ffi = require 'ffi'
pcall(function() io.stdout:setvbuf('line') end)  -- agar baris tidak hilang bila emulator crash
local B = PCSX.CONSTS.PAD.BUTTON
local pad = PCSX.SIO0.slots[1].pads[1]
local MAXF = tonumber(os.getenv('MAXF') or '1000')
local OUT = os.getenv('OUTDIR') or '/tmp/out'
local inputs = {}
for line in io.lines(os.getenv('INPUTS')) do
  local s, b, d = line:match('^(%d+)%s+(%u[%u%d]*)%s+(%d+)')
  if s and B[b] then table.insert(inputs, {tonumber(s), tonumber(s) + tonumber(d), B[b]}) end
end
local INEV = {}  -- frame -> daftar {1=set|0=clear, tombol}, urutan = urutan input (identik dengan loop lama)
for _, i in ipairs(inputs) do
  INEV[i[1]] = INEV[i[1]] or {}; table.insert(INEV[i[1]], {1, i[3]})
  INEV[i[2]] = INEV[i[2]] or {}; table.insert(INEV[i[2]], {0, i[3]})
end
local dumpset, shotset, pokes = {}, {}, {}
for f in (os.getenv('DUMPS') or ''):gmatch('%d+') do dumpset[tonumber(f)] = true end
for f in (os.getenv('SHOTS') or ''):gmatch('%d+') do shotset[tonumber(f)] = true end
for item in (os.getenv('POKES') or ''):gmatch('[^,]+') do
  local f, a, w, v = item:match('^(%d+)@(%x+)@(%d)@(%d+)$')
  if f then table.insert(pokes, {tonumber(f), tonumber(a, 16), tonumber(w), tonumber(v)}) end
end
-- ORPOKES="frame[-frame2]@alamathex@lebar@mask,..." : OR-kan mask ke memori pada frame itu (atau tiap frame dalam rentang). Kosong = tak berpengaruh.
local bit = require 'bit'
local orpokes = {}
for item in (os.getenv('ORPOKES') or ''):gmatch('[^,]+') do
  local f1, f2, a, w, v = item:match('^(%d+)%-?(%d*)@(%x+)@(%d)@(%S+)$')
  if f1 and tonumber(v) then table.insert(orpokes, {tonumber(f1), tonumber(f2) or tonumber(f1), tonumber(a, 16), tonumber(w), tonumber(v)}) end
end
local mem = PCSX.getMemPtr()
local function u32(a) return ffi.cast('uint32_t*', mem + (a % 0x200000))[0] end
local frame, last = 0, {}
local polls = {}
for i, a in ipairs({ 0x1EFBBC, 0x1EFC4C, 0x1EFCDC, 0x1EFD6C }) do polls[#polls+1] = { a, 'A' .. i } end
for i, a in ipairs({ 0x70EB8, 0x70F6C, 0x71020, 0x710D4 }) do polls[#polls+1] = { a, 'B' .. i } end
-- posisi (struct +112/+116): P1 0x70F28/0x70F2C, P2 0x70FDC/0x70FE0 (angka saja)
for i, a in ipairs({ 0x70F28, 0x70F2C, 0x70FDC, 0x70FE0 }) do polls[#polls+1] = { a, 'P' .. i } end
-- HASH (hanya angka keluar): tiap HSTEP frame sejak HFROM cetak "HSH f= ram=" (hash RAM penuh) dan "HSF f= fb= n=" (hash framebuffer).
-- Berkas screenshot sementara ditulis di OUTDIR (runner), dibaca, di-hash, lalu dihapus; tidak pernah keluar dari runner.
local HFROM = tonumber(os.getenv('HFROM') or '19000')
local HSTEP = tonumber(os.getenv('HSTEP') or '20')
local function hram()
  local p = ffi.cast('uint32_t*', mem)
  local h = 0
  for i = 0, 0x80000 - 1 do h = bit.tobit(bit.rol(bit.bxor(h, p[i]), 5) + 40503) end
  return h % 4294967296
end
local function hfb(fr)
  PCSX.nextTick(function()
    local ok, err = pcall(function()
      local path = string.format('%s/h%05d.raw', OUT, fr)
      local ss = PCSX.GPU.takeScreenShot()
      local f = Support.File.open(path, 'TRUNCATE'); f:writeMoveSlice(ss.data); f:close()
      local fh = io.open(path, 'rb'); local s = fh:read('*a'); fh:close(); os.remove(path)
      local p = ffi.cast('const uint8_t*', s)
      local h = 0
      for i = 0, #s - 1 do h = bit.tobit(bit.rol(bit.bxor(h, p[i]), 5) + 40503) end
      print(string.format('HSF f=%d fb=%d n=%d', fr, h % 4294967296, #s))
    end)
    if not ok then print('HSF f=' .. fr .. ' err=' .. tostring(err):gsub('[^%w%s_%.:]', ''):sub(1, 80)) end
  end)
end

-- SAVE-STATE (uji satu run; state HANYA di memori Lua, tidak ditulis ke disk; yang dicetak hanya angka/nama API)
-- SAVEF=frame simpan, LOADF=frame muat (kembali ke SAVEF), MODUS: "nt" (default, lewat nextTick) atau "vs" (langsung di handler Vsync)
local SAVEF = tonumber(os.getenv('SAVEF') or '')
local LOADF = tonumber(os.getenv('LOADF') or '')
local MODUS = os.getenv('MODUS') or 'nt'
if MODUS == '' then MODUS = 'nt' end
local pass, saved, savedlast, fsave = 1, nil, nil, nil
local function say(msg) print(msg); pcall(function() io.stderr:write('SVE ' .. msg .. '\n'); io.stderr:flush() end) end
local function p1words()
  local t = {}
  for i = 0, 31 do t[#t+1] = string.format('%x', u32(0x70EB8 + 4 * i)) end
  return table.concat(t, ',')
end
local function copy(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end
do
  local names = {}
  pcall(function() for k, v in pairs(PCSX) do local n = tostring(k):gsub('[^%w_]', ''); local l = n:lower()
    if l:find('state') or l:find('save') or l:find('load') then names[#names+1] = n .. ':' .. type(v) end end end)
  do local all = {} pcall(function() for k, v in pairs(PCSX) do all[#all+1] = tostring(k):gsub('[^%w_]', '') end end) table.sort(all) print('SVS apiall ' .. table.concat(all, ' ')) end
  print('SVS api ' .. table.concat(names, ' ') .. ' createSaveState=' .. type(PCSX.createSaveState) .. ' loadSaveState=' .. type(PCSX.loadSaveState))
end
local function doSave()
  local ok, st = pcall(function() return PCSX.createSaveState() end)
  saved = ok and st or nil; savedlast = copy(last); fsave = frame
  local sz = '?'; pcall(function() sz = tostring(#st) end)
  if sz == '?' then pcall(function() sz = tostring(st:size()) end) end
  local okh, h = pcall(hram)
  print(string.format('SVS simpan ok=%s tipe=%s ukuran=%s f=%d ram=%d', tostring(ok), type(st), sz, frame, okh and h or -1))
  if not ok then print('SVS galat_simpan ' .. tostring(st):gsub('[^%w%s_%.:]', ''):sub(1, 100)) end
end
local HPSET = {[24000]=true,[24020]=true,[24100]=true,[24500]=true,[25000]=true,[26000]=true,[26300]=true}
function hpages()
  local p = ffi.cast('uint32_t*', mem)
  local t = {}
  for pg = 0, 511 do
    local h = 0
    for i = pg * 1024, pg * 1024 + 1023 do h = bit.tobit(bit.rol(bit.bxor(h, p[i]), 5) + 40503) end
    t[#t+1] = string.format('%x', h % 4294967296)
  end
  print(string.format('SVS hsp p=%d f=%d %s', pass, frame, table.concat(t, ',')))
end
local function errtxt(e) return tostring(e):gsub('[^%w%s_%.:]', ''):sub(1, 80) end
local function doLoad()
  if not saved then print('SVS muat dilewati: tidak ada state'); return end
  local pc = (MODUS == 'pc' or MODUS == 'pd')
  local np = (MODUS == 'pd') and (pass + 1) or 2
  -- pc = pause + lepas semua override pad sebelum muat, pasang ulang sesudah muat
  say('SVS muat mulai f=' .. frame .. ' modus=' .. MODUS .. ' pause=' .. type(PCSX.pauseEmulator) .. ' resume=' .. type(PCSX.resumeEmulator))
  if MODUS == 'ps' then pcall(function() PCSX.pauseEmulator() end) end
  if pc then
    local okp, ep = pcall(function() PCSX.pauseEmulator() end)
    say('SVS pc pause ok=' .. tostring(okp) .. ' err=' .. (okp and '-' or errtxt(ep)))
    local seen, n, nok = {}, 0, 0
    for _, i in ipairs(inputs) do
      if not seen[i[3]] then
        seen[i[3]] = true; n = n + 1
        local okc = pcall(function() pad.clearOverride(i[3]) end)
        if okc then nok = nok + 1 end
      end
    end
    say('SVS pc clearOverride tombol=' .. n .. ' ok=' .. nok)
  end
  local ok, err = pcall(function() PCSX.loadSaveState(saved) end)
  say('SVS muat kembali ok=' .. tostring(ok))
  if pc and ok then
    frame = fsave; last = copy(savedlast); pass = np
    local n = 0
    for _, i in ipairs(inputs) do if i[1] <= frame and frame < i[2] then pad.setOverride(i[3]); n = n + 1 end end
    say('SVS pc override_pasang_ulang f=' .. frame .. ' aktif=' .. n)
    local okr, er = pcall(function() PCSX.resumeEmulator() end)
    say('SVS pc resume ok=' .. tostring(okr) .. ' err=' .. (okr and '-' or errtxt(er)))
  end
  if MODUS == 'ps' then pcall(function() PCSX.resumeEmulator() end) end
  print(string.format('SVS muat selesai ok=%s', tostring(ok)))
  if not ok then print('SVS galat_muat ' .. tostring(err):gsub('[^%w%s_%.:]', ''):sub(1, 100)); return end
  frame = fsave; last = copy(savedlast); pass = np
  for _, i in ipairs(inputs) do pad.clearOverride(i[3]) end
  for _, i in ipairs(inputs) do if i[1] <= frame and frame < i[2] then pad.setOverride(i[3]) end end
  local okh, h = pcall(hram)
  print(string.format('SVS sesudah_muat f=%d ram=%d p=%d', frame, okh and h or -1, pass))
  if MODUS == 'pd' then hpages() end
end

-- MODUS=svs (baru): cetak hash layar + hash VRAM (ANGKA SAJA) tiap SVSN frame sejak SVSFROM dan sesudah tiap tombol di jadwal (lepas+2, lepas+30).
-- Baris: "SVS scr f= sw= sn= sd= g=16angka vh= vn= vd=" (sw/vh=hash 32-bit, sn/vn=jumlah byte tidak nol, sd/vd=jumlah kata 32-bit beda vs sampel sebelumnya, g=beda per sel grid 4x4 layar).
-- Piksel/gambar tidak pernah dicetak atau ditulis; hanya statistik.
local SVSON = (MODUS == 'svs')
local SVSFROM, SVSN = tonumber(os.getenv('SVSFROM') or '23000'), tonumber(os.getenv('SVSN') or '20')
-- header opsional di berkas jadwal: "# SVS from=24500 step=20" (input workflow sudah 10 = batas GitHub, jadi parameter lewat jadwal)
if SVSON then for line in io.lines(os.getenv('INPUTS')) do local hf, hs = line:match('^#%s*SVS%s+from=(%d+)%s+step=(%d+)'); if hf then SVSFROM, SVSN = tonumber(hf), tonumber(hs) end end end
local svsset = {}
if SVSON then
  for _, i in ipairs(inputs) do
    for _, d in ipairs({2, 30}) do if i[2] + d >= SVSFROM then svsset[i[2] + d] = true end end
  end
end
local prevS, prevV = nil, nil
local function svsample(fr)
  local ok, err = pcall(function()
    local ss = PCSX.GPU.takeScreenShot()
    local s = tostring(ss.data)
    local v = tostring(PCSX.GPU.getVRAM())
    local function scan(str, prev, grid)
      local n = math.floor(#str / 4)
      local p = ffi.cast('const uint32_t*', str)
      local h, nz, dw = 0, 0, 0
      local g = {}
      for k = 1, 16 do g[k] = 0 end
      local same = prev and prev.n == n
      for i = 0, n - 1 do
        local w = p[i]
        if w ~= 0 then nz = nz + 1 end
        h = bit.tobit(bit.rol(bit.bxor(h, w), 5) + 40503)
        if same and prev.buf[i] ~= w then
          dw = dw + 1
          if grid then
            local r = math.min(3, math.floor(math.floor(i / 320) / 120))
            local c = math.min(3, math.floor((i % 320) / 80))
            g[r * 4 + c + 1] = g[r * 4 + c + 1] + 1
          end
        end
      end
      local nb = ffi.new('uint32_t[?]', n)
      ffi.copy(nb, p, n * 4)
      return h % 4294967296, nz, (same and dw or -1), g, { n = n, buf = nb }
    end
    local sh, snz, sd, g, ns = scan(s, prevS, true)
    local vh, vnz, vd, _, nv = scan(v, prevV, false)
    prevS, prevV = ns, nv
    print(string.format('SVS scr f=%d sw=%d sn=%d sd=%d g=%s vh=%d vn=%d vd=%d', fr, sh, snz, sd, table.concat(g, ','), vh, vnz, vd))
  end)
  if not ok then print('SVS scr f=' .. fr .. ' galat=' .. tostring(err):gsub('[^%w%s_%.:]', ''):sub(1, 80)) end
end
-- MODUS=svs: tangkapan layar mentah HANYA ke folder sementara runner (OUTDIR), pada frame di header jadwal "# SHOT f1 f2 ...".
-- Runner lalu mengenkripsi (kunci publik) dan menghapus mentahnya; log hanya mencetak angka (w,h,bpp,len).
local shotf = {}
if SVSON then for line in io.lines(os.getenv('INPUTS')) do local l = line:match('^#%s*SHOT%s+([%d%s]+)$'); if l then for f in l:gmatch('%d+') do shotf[tonumber(f)] = true end end end end
local function svshot(fr)
  local ok, err = pcall(function()
    local ss = PCSX.GPU.takeScreenShot()
    local str = tostring(ss.data)
    local w, h = tonumber(tostring(ss.width)), tonumber(tostring(ss.height))
    local bpp = -1; pcall(function() bpp = tonumber(tostring(ss.bpp)) or -1 end)
    local fh = io.open(string.format('%s/s%05d.raw', OUT, fr), 'wb'); fh:write(str); fh:close()
    local fm = io.open(string.format('%s/s%05d.meta', OUT, fr), 'w'); fm:write(string.format('%d %d %d %d', w, h, bpp, #str)); fm:close()
    print(string.format('SVS shot f=%d w=%d h=%d bpp=%d len=%d', fr, w, h, bpp, #str))
  end)
  if not ok then print('SVS shot f=' .. fr .. ' galat=' .. tostring(err):gsub('[^%w%s_%.:]', ''):sub(1, 80)) end
end
local STATEOUT, STATEIN, LSITE = os.getenv('STATEOUT'), os.getenv('STATEIN'), os.getenv('LSITE') or 'top'
if STATEOUT == '' then STATEOUT = nil end
if STATEIN == '' then STATEIN = nil end
local wall = function() return os.clock() end
pcall(function()
  ffi.cdef[[ typedef struct { long tv_sec; long tv_usec; } tvx_t; int gettimeofday(tvx_t*, void*); ]]
  wall = function() local t = ffi.new('tvx_t'); ffi.C.gettimeofday(t, nil); return tonumber(t.tv_sec) + tonumber(t.tv_usec) / 1e6 end
end)
local WALL0 = wall()
-- header opsional di jadwal: "# SPUSPEED n" (mengatur PCSX.settings.spu.Speed; hanya angka)
local hblkset = {}
local hfrset = {}
local REFOUT, REFIN = os.getenv('REFOUT') or '', os.getenv('REFIN') or ''
local WDFMAX = tonumber(os.getenv('WDFMAX') or '16')
-- WDIFF: bandingkan RAM sekarang dengan snapshot referensi (berkas HANYA di runner, tidak pernah di-commit); cetak jumlah kata beda per blok 64 KB + beberapa kata beda sebagai ANGKA
local function wdiff(fr)
  local fh = io.open(string.format('%s_%d.bin', REFIN, fr), 'rb')
  if not fh then print(string.format('WDN f=%d sem_ref', fr)); return end
  local s = fh:read(0x200000); fh:close()
  if not s or #s ~= 0x200000 then print(string.format('WDN f=%d ref_rusak', fr)); return end
  local rp = ffi.new('uint32_t[?]', 0x80000)
  ffi.copy(rp, s, 0x200000)
  local cp = ffi.cast('uint32_t*', mem)
  local cnt, shown, lines, total = {}, {}, {}, 0
  for i = 0, 0x7FFFF do
    local a, b = rp[i], cp[i]
    if a ~= b then
      local blk = math.floor(i / 16384)
      cnt[blk] = (cnt[blk] or 0) + 1; total = total + 1
      shown[blk] = (shown[blk] or 0) + 1
      if shown[blk] <= WDFMAX then lines[#lines + 1] = string.format('WDF f=%d a=0x%06X ref=%d cur=%d', fr, i * 4, a, b) end
    end
  end
  local parts = {}
  for blk = 0, 31 do if cnt[blk] then parts[#parts + 1] = blk .. ':' .. cnt[blk] end end
  print(string.format('WDN f=%d total=%d blok=%s', fr, total, table.concat(parts, ',')))
  for _, l in ipairs(lines) do print(l) end
end
-- SCAN_BEGIN
-- SCAN (hanya angka keluar): "# SCAN f v1 v2 ..." cetak ALAMAT (offset RAM, hex tanpa 0x) kata 32-bit sejajar yang bernilai v pada frame f;
-- "# SCANH f v1 ..." sama untuk halfword 16-bit sejajar, "# SCANB f v1 ..." untuk byte; "# SCANP w f1 v1 f2 v2 ..." rantai (w=1|2|4, frame menaik): alamat harus bernilai v_k pada frame f_k untuk SEMUA k;
-- "# SCANMAX n" batas alamat tercetak per baris (baku 300, maks 5000; n= tetap jumlah penuh). Nilai desimal tak negatif. Isi RAM lain tidak pernah dicetak.
local SCAN = { jobs = {}, max = 300, chains = 0 }
local function scanfind(w, v)
  local res, n = {}, 0
  if w == 4 then
    local p = ffi.cast('uint32_t*', mem)
    for i = 0, 0x7FFFF do if p[i] == v then n = n + 1; res[n] = i * 4 end end
  elseif w == 1 then
    local p = ffi.cast('uint8_t*', mem)
    for i = 0, 0x1FFFFF do if p[i] == v then n = n + 1; res[n] = i end end
  else
    local p = ffi.cast('uint16_t*', mem)
    for i = 0, 0xFFFFF do if p[i] == v then n = n + 1; res[n] = i * 2 end end
  end
  return res
end
local function scanfilter(w, cand, v)
  local res, n = {}, 0
  local p = (w == 4) and ffi.cast('uint32_t*', mem) or ((w == 1) and ffi.cast('uint8_t*', mem) or ffi.cast('uint16_t*', mem))
  local sh = (w == 4) and 2 or ((w == 1) and 0 or 1)
  for _, a in ipairs(cand) do
    if p[bit.rshift(a, sh)] == v then n = n + 1; res[n] = a end
  end
  return res
end
local function scanfmt(list)
  local t = {}
  for i = 1, math.min(#list, SCAN.max) do t[i] = string.format('%X', list[i]) end
  return table.concat(t, ',')
end
local function scanrun(job, fr)
  if job.kind == 'scan' then
    for _, v in ipairs(job.vals) do
      local r = scanfind(job.w, v)
      print(string.format('SCN f=%d w=%d v=%d n=%d a=%s', fr, job.w, v, #r, scanfmt(r)))
    end
  else
    local ch = job.ch
    if job.k == 1 then ch.cand = scanfind(ch.w, job.v) else ch.cand = scanfilter(ch.w, ch.cand or {}, job.v) end
    print(string.format('SCP c=%d k=%d/%d f=%d w=%d v=%d n=%d', ch.id, job.k, ch.n, fr, ch.w, job.v, #ch.cand))
    if job.k == ch.n then print(string.format('SCP c=%d fin n=%d a=%s', ch.id, #ch.cand, scanfmt(ch.cand))) end
  end
end
function SCAN.runall(list, fr)
  for _, job in ipairs(list) do
    local ok, e = pcall(scanrun, job, fr)
    if not ok then print('SCN f=' .. fr .. ' galat=' .. tostring(e):gsub('[^%w%s_%.:]', ''):sub(1, 60)) end
  end
end
local function scanadd(f, job)
  SCAN.jobs[f] = SCAN.jobs[f] or {}
  table.insert(SCAN.jobs[f], job)
end
function SCAN.parse(line)
  local sm = line:match('^#%s*SCANMAX%s+(%d+)')
  if sm then SCAN.max = math.max(1, math.min(tonumber(sm), 5000)); return end
  local kh, rest = line:match('^#%s*SCAN([HB]?)%s+([%d%s]+)$')
  if rest then
    local nums = {}
    for n in rest:gmatch('%d+') do nums[#nums + 1] = tonumber(n) end
    local w = (kh == 'H') and 2 or ((kh == 'B') and 1 or 4)
    local lim = (w == 1) and 255 or ((w == 2) and 65535 or 4294967295)
    local good = (#nums >= 2)
    for k = 2, #nums do if nums[k] > lim then good = false end end
    if good then scanadd(table.remove(nums, 1), { kind = 'scan', w = w, vals = nums }) else print('SCN galat scan_tak_sah') end
    return
  end
  local pw, prest = line:match('^#%s*SCANP%s+(%d)%s+([%d%s]+)$')
  if prest then
    local nums = {}
    for n in prest:gmatch('%d+') do nums[#nums + 1] = tonumber(n) end
    local w = tonumber(pw)
    local lim = (w == 1) and 255 or ((w == 2) and 65535 or 4294967295)
    local good = ((w == 1 or w == 2 or w == 4) and #nums >= 2 and #nums % 2 == 0)
    if good then
      for k = 1, #nums / 2 do
        if k > 1 and nums[2 * k - 1] <= nums[2 * k - 3] then good = false end
        if nums[2 * k] > lim then good = false end
      end
    end
    if good then
      SCAN.chains = SCAN.chains + 1
      local ch = { id = SCAN.chains, w = w, n = #nums / 2 }
      for k = 1, ch.n do scanadd(nums[2 * k - 1], { kind = 'chain', ch = ch, k = k, v = nums[2 * k] }) end
    else print('SCN galat rantai_tak_sah') end
  end
end
-- SCAN_END
-- BOT_BEGIN
-- DISC (Sesi x6): pencari penanda RAM tanpa tebak alamat. "# DISC nama f1 f2 ..." = kelas frame berlabel; "# DISCQ q A B [cap] [maxv]": pada frame terakhir kedua kelas
-- cetak alamat BYTE yang konstan di semua frame kelas A (nilai vA), konstan di kelas B (nilai vB), dan vA ~= vB. Keluaran HANYA angka dan terbatas:
-- "SCNDSC q 0xADDR vA vB" (maks cap, baku 150, hanya bila vA dan vB <= maxv, baku 255), "SCNDSC# q total= tampil= reg64k=..." (jumlah kandidat per blok 64 KB). Awalan SCN agar lolos saringan chg.log.
local DISC = { cls = {}, snapf = {}, snaps = {}, qs = {} }
function DISC.parse(line)
  local nm, fl = line:match('^#%s*DISC%s+(%w+)%s+([%d%s]+)$')
  if nm then
    local t = {}
    for fr in fl:gmatch('%d+') do local f = tonumber(fr); t[#t + 1] = f; DISC.snapf[f] = true end
    DISC.cls[nm] = t
    return
  end
  local q, a, b, cap, mv = line:match('^#%s*DISCQ%s+(%w+)%s+(%w+)%s+(%w+)%s*(%d*)%s*(%d*)')
  if q then DISC.qs[#DISC.qs + 1] = { q = q, a = a, b = b, cap = tonumber(cap) or 150, maxv = tonumber(mv) or 255 } end
end
function DISC.run(Q, A, B)
  local pa, pb = {}, {}
  for i, f in ipairs(A) do pa[i] = DISC.snaps[f] end
  for i, f in ipairs(B) do pb[i] = DISC.snaps[f] end
  local na, nb = #pa, #pb
  local reg = {}
  for r = 0, 31 do reg[r] = 0 end
  local total, shown, out = 0, 0, {}
  for a = 0, 0x1FFFFF do
    local va = pa[1][a]
    local ok = true
    for k = 2, na do if pa[k][a] ~= va then ok = false; break end end
    if ok then
      local vb = pb[1][a]
      if vb ~= va then
        for k = 2, nb do if pb[k][a] ~= vb then ok = false; break end end
        if ok then
          total = total + 1
          local r = math.floor(a / 65536); reg[r] = reg[r] + 1
          if shown < Q.cap and va <= Q.maxv and vb <= Q.maxv then shown = shown + 1; out[#out + 1] = string.format('SCNDSC %s 0x%X %d %d', Q.q, a, va, vb) end
        end
      end
    end
  end
  for _, l in ipairs(out) do print(l) end
  local rs = {}
  for r = 0, 31 do rs[#rs + 1] = tostring(reg[r]) end
  print(string.format('SCNDSC# %s total=%d tampil=%d na=%d nb=%d reg64k=%s', Q.q, total, shown, na, nb, table.concat(rs, ',')))
end
function DISC.tick(frame)
  if not DISC.snapf[frame] then return end
  local buf = ffi.new('uint8_t[?]', 0x200000)
  ffi.copy(buf, mem, 0x200000)
  DISC.snaps[frame] = buf
  for _, Q in ipairs(DISC.qs) do
    if not Q.done then
      local A, B = DISC.cls[Q.a], DISC.cls[Q.b]
      if A and B then
        local ready = true
        for _, f in ipairs(A) do if not DISC.snaps[f] then ready = false end end
        for _, f in ipairs(B) do if not DISC.snaps[f] then ready = false end end
        if ready then Q.done = true; local ok, e = pcall(DISC.run, Q, A, B); if not ok then print('SCNDSC# galat ' .. tostring(e):gsub('[^%w%s_%.:]', ''):sub(1, 80)) end end
      end
    end
  end
end
-- DISC_END
-- BOT v0 (aturan tetap). "# BOT from=F": sebelum frame F jadwal/replay yang jalan, sesudah F bot memutuskan. Masukan: hash layar (tiap K frame) + RAM chakra/posisi.
-- Aturan: tekan CIRCLE bila layar statis >= stable sampel dan >= gap frame sejak tekan terakhir, atau tiap max frame; tanpa kemajuan > stuck frame -> makro cadangan bergilir;
-- tanpa kemajuan > dead frame -> MACET dan berhenti. Kemajuan = hash layar baru atau perubahan RAM pantau. "# BOTCFG K=10 stable=3 gap=30 max=100 stuck=3000 dead=30000 maxlog=11000", "# BOTSCENE <hash> <TOMBOL>".
-- Keluaran angka: "BOT <frame> <TOMBOL> <lama>" (format jadwal; dipakai ci/bot_lanjut.py), "BOT# N f= h=" adegan baru, "BOT# S ..." status, "BOT# END f= why=".
local BOT = { on = false, nh = 0, nref = 0, from = 0, q = {}, seen = {}, nseen = 0, scene = {}, nlog = 0, h = nil, ph = nil, stable = 0, lastp = -100000, lastprog = 0, esc = 0, pend = false, done = false, ram = {},
  cfg = { K = 10, stable = 3, gap = 30, max = 100, stuck = 1800, dead = 30000, maxlog = 11000, shots = 3, hashrate = 9999, lowchakra = 0, refuse = 1, ext = 0 },
  watch = { 0x70EB8, 0x70F6C, 0x71020, 0x710D4, 0x70F28, 0x70FDC },
  macros = { { { 0, 'CROSS', 4 } }, { { 0, 'TRIANGLE', 4 } }, { { 0, 'SQUARE', 4 } }, { { 0, 'START', 4 } },
    { { 0, 'DOWN', 4 }, { 20, 'CIRCLE', 4 } }, { { 0, 'UP', 4 }, { 20, 'CIRCLE', 4 } }, { { 0, 'RIGHT', 4 }, { 20, 'CIRCLE', 4 } }, { { 0, 'LEFT', 4 }, { 20, 'CIRCLE', 4 } } } }
-- eskalasi saat macet (arah dulu: persimpangan papan memakai kiri/kanan; CIRCLE = peta)
BOT.macros = { { { 0, 'RIGHT', 4 } }, { { 0, 'LEFT', 4 } }, { { 0, 'CROSS', 4 } }, { { 0, 'RIGHT', 4 }, { 20, 'CROSS', 4 } }, { { 0, 'LEFT', 4 }, { 20, 'CROSS', 4 } },
  { { 0, 'TRIANGLE', 4 } }, { { 0, 'SQUARE', 4 } }, { { 0, 'START', 4 } }, { { 0, 'DOWN', 4 }, { 20, 'CIRCLE', 4 } }, { { 0, 'UP', 4 }, { 20, 'CIRCLE', 4 } } }
-- ext=1: eskalasi dengan kombinasi arah/bahu lalu CIRCLE (layar pilih bola kristal: ジャンプする水晶玉をえらんでください)
BOT.macros2 = { { { 0, 'RIGHT', 4 }, { 20, 'CIRCLE', 4 } }, { { 0, 'LEFT', 4 }, { 20, 'CIRCLE', 4 } }, { { 0, 'DOWN', 4 }, { 20, 'CIRCLE', 4 } }, { { 0, 'UP', 4 }, { 20, 'CIRCLE', 4 } },
  { { 0, 'R1', 4 }, { 20, 'CIRCLE', 4 } }, { { 0, 'L1', 4 }, { 20, 'CIRCLE', 4 } }, { { 0, 'R2', 4 }, { 20, 'CIRCLE', 4 } }, { { 0, 'L2', 4 }, { 20, 'CIRCLE', 4 } },
  { { 0, 'CROSS', 4 } }, { { 0, 'TRIANGLE', 4 } }, { { 0, 'SQUARE', 4 } }, { { 0, 'START', 4 } }, { { 0, 'SELECT', 4 } } }
-- ext=2: macros2 + keluar dari layar peta/info petak (✕もどる): CROSS, arah, CIRCLE (didahulukan)
BOT.macros3 = { { { 0, 'CROSS', 4 }, { 30, 'UP', 4 }, { 60, 'CIRCLE', 4 } }, { { 0, 'CROSS', 4 }, { 30, 'DOWN', 4 }, { 60, 'CIRCLE', 4 } }, { { 0, 'CROSS', 4 }, { 30, 'CROSS', 4 }, { 60, 'CIRCLE', 4 } },
  { { 0, 'CROSS', 4 }, { 30, 'LEFT', 4 }, { 60, 'CIRCLE', 4 } }, { { 0, 'CROSS', 4 }, { 30, 'RIGHT', 4 }, { 60, 'CIRCLE', 4 } } }
for _, m in ipairs(BOT.macros2) do table.insert(BOT.macros3, m) end
function BOT.parse(line)
  local f = line:match('^#%s*BOT%s+from=(%d+)')
  if f then BOT.on = true; BOT.from = tonumber(f); return end
  local cfg = line:match('^#%s*BOTCFG%s+(.+)$')
  if cfg then for k, v in cfg:gmatch('(%a+)=(%d+)') do if BOT.cfg[k] then BOT.cfg[k] = tonumber(v) end end return end
  local h, b = line:match('^#%s*BOTSCENE%s+(%d+)%s+(%u+)')
  if h and B[b] then BOT.scene[tonumber(h)] = b end
end
-- INSTRUMEN v3 (hanya hitung/cetak; tidak mengubah keputusan): pengenal prompt Ya/Tidak lewat piksel tetap (data/sig_piksel_prompt.json; layar 320x240, PS1 555: R bit0-4, G bit5-9, B bit10-14). m = jumlah titik yang cocok (toleransi 8); t2 = piksel terang di baris teks ke-2 (x30-149, y188-205): >100 = prompt beli (必要チャクラ), ~0 = prompt serang.
BOT.SIG = { {241,164,255,238,139}, {252,164,49,24,0}, {241,168,255,238,139}, {263,171,172,57,41}, {268,170,164,49,32}, {280,170,164,49,32}, {241,182,230,197,57}, {252,182,172,57,32}, {266,182,0,8,74}, {280,182,0,8,74}, {241,196,230,180,41}, {255,196,0,8,74}, {266,196,0,8,74}, {280,196,0,8,74}, {232,210,180,106,0}, {238,210,189,139,8}, {252,210,189,139,8}, {266,210,189,139,8}, {280,210,189,139,8}, {294,210,197,148,8} }
BOT.sm, BOT.st2, BOT.sigf, BOT.yon, BOT.ny, BOT.t2max = 0, 0, 0, 0, 0, 0
BOT.sbx, BOT.sxr, BOT.bxmax, BOT.xrmax, BOT.lc = 0, 0, 0, 0, {}  -- INSTRUMEN v4 (hanya cetak): bx = kecocokan kotak-serang, xr = ujung kanan teks baris-1, mv = pemain yang terakhir bergerak (1=P1, 3=0x70FDC)
BOT.SIGB = { {20,106,172,123,32}, {20,114,74,49,16}, {20,122,74,49,16}, {20,130,74,49,16}, {20,138,74,49,16}, {20,146,98,65,16}, {20,154,74,49,16}, {28,106,131,0,0}, {28,114,98,123,82}, {28,122,90,115,74}, {28,130,222,222,222}, {28,138,82,106,74}, {28,146,222,222,222}, {28,154,90,115,74}, {36,106,115,74,16}, {36,114,82,106,65}, {36,122,90,115,74}, {36,130,82,106,65}, {36,138,82,106,74}, {36,146,82,106,74}, {36,154,82,98,65}, {44,106,115,74,16}, {44,114,82,106,74}, {44,122,82,106,65}, {44,130,222,222,222}, {44,138,82,115,74}, {44,146,222,222,222}, {44,154,82,106,65}, {52,106,131,82,16}, {52,114,222,222,222}, {52,122,82,106,65}, {52,130,0,0,8}, {52,138,82,106,65}, {52,146,0,0,8}, {52,154,82,106,65}, {60,106,115,74,16}, {60,114,82,98,65}, {60,122,82,106,65}, {60,130,222,222,222}, {60,138,90,115,74}, {60,146,0,0,8}, {60,154,82,106,74}, {68,106,115,74,16}, {68,114,90,115,74}, {68,122,90,115,74}, {68,130,222,222,222}, {68,138,82,106,65}, {68,146,90,115,74}, {68,154,82,106,74}, {76,106,115,74,16}, {76,114,82,115,74}, {76,122,98,123,82}, {76,130,74,98,57}, {76,138,82,106,65}, {76,146,90,115,74}, {76,154,82,106,65}, {84,106,115,74,16}, {84,114,82,98,65}, {84,122,82,106,65}, {84,130,82,106,65}, {84,138,106,131,90}, {84,146,65,90,57}, {84,154,82,106,65}, {92,106,115,74,16}, {92,114,98,123,82}, {92,122,90,115,74}, {92,130,82,106,65}, {92,138,82,106,74}, {92,146,82,106,74}, {92,154,90,115,74}, {100,106,115,74,16}, {100,114,82,106,65}, {100,122,90,115,74}, {100,130,82,106,65}, {100,138,82,106,74}, {100,146,0,49,156}, {100,154,82,98,65}, {108,106,131,82,16}, {108,114,82,106,74}, {108,122,82,106,65}, {108,130,255,255,255}, {108,138,82,115,74}, {108,146,49,172,222}, {108,154,82,106,65}, {116,106,98,65,16}, {116,114,24,115,189}, {116,122,82,106,65}, {116,130,0,0,8}, {116,138,82,106,65}, {116,146,0,49,156}, {116,154,82,106,65} }
function BOT.sig(str)
  if #str ~= 153600 then BOT.sm = -1; BOT.st2 = 0; BOT.sigf = 1; BOT.sbx = 0; BOT.sxr = 0; return end
  local px = ffi.cast('const uint16_t*', str)
  local band, rsh = bit.band, bit.rshift
  local m = 0
  for i = 1, #BOT.SIG do
    local s = BOT.SIG[i]
    local p = px[s[2] * 320 + s[1]]
    local r = math.floor(band(p, 31) * 255 / 31)
    local g = math.floor(band(rsh(p, 5), 31) * 255 / 31)
    local b = math.floor(band(rsh(p, 10), 31) * 255 / 31)
    if math.abs(r - s[3]) <= 8 and math.abs(g - s[4]) <= 8 and math.abs(b - s[5]) <= 8 then m = m + 1 end
  end
  local t = 0
  for y = 188, 205 do for x = 30, 149 do
    local p = px[y * 320 + x]
    local r = math.floor(band(p, 31) * 255 / 31)
    local g = math.floor(band(rsh(p, 5), 31) * 255 / 31)
    local b = math.floor(band(rsh(p, 10), 31) * 255 / 31)
    if r + g + b > 600 then t = t + 1 end
  end end
  BOT.sm, BOT.st2, BOT.sigf = m, t, 1
  local bx, xr = 0, 0  -- v4: dihitung SETELAH hasil v3 diisi (kegagalan di sini tak mengubah v3)
  for i = 1, #BOT.SIGB do
    local q = BOT.SIGB[i]
    local p = px[q[2] * 320 + q[1]]
    local r = math.floor(band(p, 31) * 255 / 31)
    local g = math.floor(band(rsh(p, 5), 31) * 255 / 31)
    local b = math.floor(band(rsh(p, 10), 31) * 255 / 31)
    if math.abs(r - q[3]) <= 24 and math.abs(g - q[4]) <= 24 and math.abs(b - q[5]) <= 24 then bx = bx + 1 end
  end
  for y = 172, 182 do for x = 30, 239 do
    local p = px[y * 320 + x]
    local r = math.floor(band(p, 31) * 255 / 31)
    local g = math.floor(band(rsh(p, 5), 31) * 255 / 31)
    local b = math.floor(band(rsh(p, 10), 31) * 255 / 31)
    if r + g + b > 600 and x > xr then xr = x end
  end end
  BOT.sbx, BOT.sxr = bx, xr
end
function BOT.shot()
  local ss = PCSX.GPU.takeScreenShot()
  local str = tostring(ss.data)
  pcall(BOT.sig, str)  -- INSTRUMEN v3 (efek samping hanya mengisi BOT.sm/st2)
  local p = ffi.cast('const uint32_t*', str)
  local h = 0
  for i = 0, math.floor(#str / 4) - 1 do h = bit.tobit(bit.rol(bit.bxor(h, p[i]), 5) + 40503) end
  return h % 4294967296
end
function BOT.newhash(h, f0)
  if h == BOT.ph then BOT.stable = BOT.stable + 1 else BOT.stable = 0 end
  BOT.ph = h; BOT.h = h
  if not BOT.seen[h] then
    BOT.seen[h] = true; BOT.nseen = BOT.nseen + 1; BOT.nh = BOT.nh + 1
    if BOT.nseen <= 300 then print(string.format('BOT# N f=%d h=%d', f0, h)) end
  end
end
function BOT.queue(fr, macro)
  for _, m in ipairs(macro) do
    local b = B[m[2]]
    if b then table.insert(BOT.q, { s = fr + 1 + m[1], n = m[2], b = b, d = m[3], on = false }) end
  end
end
BOT.nshot = 0
BOT.np = 0; BOT.lastpk = -1; BOT.pflag = 0; BOT.pcur = 0; BOT.ep = 0; BOT.epcur = 0; BOT.nfall = 0  -- penanda RAM (Sesi x6): prompt Ya/Tidak papan terbuka bila byte 0x139F46 == 5; kursor byte 0x1CECF0 (0 = はい, 1 = いいえ)
function BOT.snap(fr)
  if BOT.nshot >= BOT.cfg.shots then return end
  BOT.nshot = BOT.nshot + 1
  PCSX.nextTick(function() svshot(fr) end)
end
function BOT.finish(fr, why)
  if BOT.done then return end
  BOT.done = true
  print(string.format('BOT# END f=%d why=%s', fr, why))
  if why == 'MACET' then BOT.snap(fr) end
  if why ~= 'MAXF' then PCSX.nextTick(function() PCSX.quit(0) end) end
end
-- INSTRUMEN Sesi x10 (HANYA cetak angka; tidak mengubah keputusan/penekanan bot; dipanggil lewat pcall). Rekaman tampilan petak RAM (catatan_riset 11.1): pasangan harga,sewa u16 di 0x13BA6E + 0x124*i; level di -4 (256 = level 1); pemilik di +44 (242 kosong, 245 P1, 246 P2). Hanya dibaca.
-- Keluaran: "BOT# I0 f= hs=harga/sewa x22" (validasi pemetaan), "BOT# Q f= pos=P1..P4 c=B1..B4(bertanda) cur= own=22 huruf lev=22 digit" saat flag 0x139F46 masuk 5, "BOT# R f= c=..." saat keluar dari 5.
BOT.tb = 0x13BA6E; BOT.nq = 0; BOT.prevpf = 0; BOT.t0 = false; BOT.nh5 = 0; BOT.lh5 = nil  -- v2: hash layar stabil per jendela flag=5
function BOT.u16(a) return ffi.cast('uint16_t*', mem + (a % 0x200000))[0] end
function BOT.sg32(v) if v >= 2147483648 then return v - 4294967296 end return v end
function BOT.tiles()
  local o, l = {}, {}
  for i = 0, 21 do
    local a = BOT.tb + 0x124 * i
    local ow, lv = BOT.u16(a + 44), BOT.u16(a - 4)
    if ow == 242 then o[#o + 1] = '.' elseif ow >= 245 and ow <= 248 then o[#o + 1] = tostring(ow - 244) else o[#o + 1] = '?' end
    if lv % 256 == 0 and lv <= 2304 then l[#l + 1] = tostring(math.floor(lv / 256)) else l[#l + 1] = '?' end
  end
  return table.concat(o), table.concat(l)
end
function BOT.inst(fr)
  local pf = BOT.pflag
  if not BOT.t0 then
    BOT.t0 = true
    local pr = {}
    for i = 0, 21 do local a = BOT.tb + 0x124 * i; pr[#pr + 1] = BOT.u16(a) .. '/' .. BOT.u16(a + 2) end
    print(string.format('BOT# I0 f=%d hs=%s', fr, table.concat(pr, ',')))
  end
  if pf == 5 and BOT.prevpf ~= 5 and BOT.nq < 500 then
    BOT.nq = BOT.nq + 1
    local o, l = BOT.tiles()
    print(string.format('BOT# Q f=%d pos=%d,%d,%d,%d c=%d,%d,%d,%d cur=%d own=%s lev=%s', fr, u32(0x70F28), u32(0x70F2C), u32(0x70FDC), u32(0x70FE0), BOT.sg32(u32(0x70EB8)), BOT.sg32(u32(0x70F6C)), BOT.sg32(u32(0x71020)), BOT.sg32(u32(0x710D4)), BOT.pcur, o, l))
  elseif pf ~= 5 and BOT.prevpf == 5 and BOT.nq <= 500 then
    print(string.format('BOT# R f=%d c=%d,%d,%d,%d', fr, BOT.sg32(u32(0x70EB8)), BOT.sg32(u32(0x70F6C)), BOT.sg32(u32(0x71020)), BOT.sg32(u32(0x710D4))))
  end
  -- INSTRUMEN v2 (hanya cetak): hash layar yang stabil (>= stable sampel) selama flag=5, sekali per hash per jendela -> mengenali layar prompt beli/serang/level-up vs menu/pesan.
  if pf == 5 and BOT.stable >= BOT.cfg.stable and BOT.h and BOT.h ~= BOT.lh5 and BOT.nh5 < 800 then
    BOT.lh5 = BOT.h; BOT.nh5 = BOT.nh5 + 1
    print(string.format('BOT# H f=%d h=%d p1=%d cur=%d', fr, BOT.h, u32(0x70F28) % 65536, BOT.pcur))
  end
  if pf ~= 5 then BOT.lh5 = nil end
  if BOT.sigf == 1 then
    BOT.sigf = 0
    local on = (BOT.sm >= 16) and 1 or 0
    if on == 1 and BOT.st2 > BOT.t2max then BOT.t2max = BOT.st2 end
    if on == 1 then if BOT.sbx > BOT.bxmax then BOT.bxmax = BOT.sbx end; if BOT.sxr > BOT.xrmax then BOT.xrmax = BOT.sxr end end
    if on ~= BOT.yon and BOT.ny < 700 then
      BOT.ny = BOT.ny + 1
      if on == 1 then
        BOT.t2max = BOT.st2; BOT.bxmax = BOT.sbx; BOT.xrmax = BOT.sxr
        local o = BOT.tiles()
        local mv = ((BOT.lc[5] or 0) >= (BOT.lc[6] or 0)) and 1 or 3
        local pm = (BOT.ram[mv == 1 and 5 or 6] or 0) % 65536
        print(string.format('BOT# Y f=%d on=1 m=%d t2=%d pf=%d cur=%d pos=%d c=%d,%d own=%s bx=%d xr=%d mv=%d pm=%d', fr, BOT.sm, BOT.st2, pf, BOT.pcur, u32(0x70F28) % 65536, BOT.sg32(u32(0x70EB8)), BOT.sg32(u32(0x70F6C)), o, BOT.sbx, BOT.sxr, mv, pm))
      else
        print(string.format('BOT# Y f=%d on=0 m=%d t2max=%d pf=%d cur=%d c=%d,%d bxmax=%d xrmax=%d', fr, BOT.sm, BOT.t2max, pf, BOT.pcur, BOT.sg32(u32(0x70EB8)), BOT.sg32(u32(0x70F6C)), BOT.bxmax, BOT.xrmax))
      end
    end
    BOT.yon = on
  end
  BOT.prevpf = pf
end
function BOT.tick(fr)
  if BOT.done then return end
  local c = BOT.cfg
  for i = #BOT.q, 1, -1 do
    local e = BOT.q[i]
    if not e.on and fr >= e.s then
      pad.setOverride(e.b); e.on = true; BOT.nlog = BOT.nlog + 1
      print(string.format('BOT %d %s %d', fr, e.n, e.d))
    end
    if e.on and fr >= e.s + e.d then pad.clearOverride(e.b); table.remove(BOT.q, i) end
  end
  for i, a in ipairs(BOT.watch) do
    local v = u32(a)
    if BOT.ram[i] ~= v then BOT.ram[i] = v; BOT.lastprog = fr; BOT.lc[i] = fr end
  end
  do local pb = ffi.cast('uint8_t*', mem); BOT.pflag = pb[0x139F46]; BOT.pcur = pb[0x1CECF0]; if BOT.pflag ~= 5 then BOT.ep = 0 end end
  local pk = BOT.pflag * 256 + BOT.pcur
  if pk ~= BOT.lastpk then BOT.lastpk = pk; BOT.np = BOT.np + 1; if BOT.np <= 600 then print(string.format('BOT# P f=%d pf=%d cur=%d b1=%d', fr, BOT.pflag, BOT.pcur, BOT.ram[1] or 0)) end end
  pcall(BOT.inst, fr)  -- INSTRUMEN Sesi x10 (hanya cetak)
  if fr % 500 == 0 then if BOT.nh >= c.hashrate then BOT.lastprog = fr end; BOT.nh = 0 end  -- kemajuan = RAM pantau berubah ATAU >= hashrate hash layar baru per 500 frame
  if fr >= MAXF then BOT.finish(fr, 'MAXF'); return end
  if BOT.nlog >= c.maxlog then BOT.finish(fr, 'LOG_PENUH'); return end
  if fr - BOT.lastprog > c.dead then BOT.finish(fr, 'MACET'); return end
  if fr % 2000 == 0 then
    local r = BOT.ram
    print(string.format('BOT# S f=%d c=%d,%d,%d,%d p=%d,%d seen=%d esc=%d ref=%d fb=%d', fr, r[1] or 0, r[2] or 0, r[3] or 0, r[4] or 0, r[5] or 0, r[6] or 0, BOT.nseen, BOT.esc, BOT.nref, BOT.nfall))
  end
  if fr % c.K == 0 and not BOT.pend then
    BOT.pend = true
    PCSX.nextTick(function()
      local ok, h = pcall(BOT.shot)
      BOT.pend = false
      if ok then BOT.newhash(h, fr) end
    end)
  end
  if #BOT.q == 0 then
    local since = fr - BOT.lastp
    if (BOT.stable >= c.stable and since >= c.gap) or since >= c.max then
      local macro
      local btn = BOT.h and BOT.scene[BOT.h]
      if fr - BOT.lastprog > c.stuck then if BOT.esc == 0 then BOT.snap(fr) end; local ms = (c.ext > 1) and BOT.macros3 or ((c.ext > 0) and BOT.macros2 or BOT.macros); macro = ms[(BOT.esc % #ms) + 1]; BOT.esc = BOT.esc + 1
      elseif btn and BOT.stable >= 1 then macro = { { 0, btn, 4 } }
      elseif BOT.pflag == 5 and c.lowchakra > 0 and (BOT.ram[1] or 0) < c.lowchakra then  -- chakra B1 rendah DAN jendela menunggu masukan (RAM flag=5)
        -- satu episode flag=5: giliran 1 = DOWN, giliran berikut = CIRCLE. Kursor RAM hanya dicatat (layar pilih kartu tidak menggerakkannya; nilainya tetap 1 setelah prompt ditutup).
        if BOT.ep == 0 then macro = { { 0, 'DOWN', 4 } }; BOT.ep = 1; BOT.epcur = BOT.pcur
        else macro = { { 0, 'CIRCLE', 4 } }; if BOT.ep == 1 then BOT.ep = 2; if BOT.pcur ~= BOT.epcur then BOT.nref = BOT.nref + 1 else BOT.nfall = BOT.nfall + 1 end end end
      else macro = { { 0, 'CIRCLE', 4 } } end
      BOT.queue(fr, macro); BOT.lastp = fr
    end
  end
end
-- BOT_END
for line in io.lines(os.getenv('INPUTS')) do
  local hbl = line:match('^#%s*HBLK%s+([%d%s]+)')
  local hfr = line:match('^#%s*HFR%s+([%d%s]+)')
  if hfr then for fr in hfr:gmatch('%d+') do hfrset[tonumber(fr)] = true end end
  if hbl then for fr in hbl:gmatch('%d+') do hblkset[tonumber(fr)] = true end end
  SCAN.parse(line)
  BOT.parse(line)
  DISC.parse(line)
  local sp = line:match('^#%s*SPUSPEED%s+(%d+)')
  if sp then local ok = pcall(function() PCSX.settings.spu.Speed = tonumber(sp) end); print('SVS spu.Speed=' .. sp .. ' ok=' .. tostring(ok)) end
end
local function xsave()
  local okc, st = pcall(function() return PCSX.createSaveState() end)
  local oks, str = pcall(function() return tostring(st) end)
  local okh, h = pcall(hram)
  if not (okc and oks) then say('XS simpan GAGAL'); return end
  local f = io.open(STATEOUT, 'wb'); f:write(str); f:close()
  say(string.format('XS simpan f=%d ram=%d bytes=%d', frame, okh and h or -1, #str))
  PCSX.nextTick(function() PCSX.quit(0) end)
end
local listener
local XSPOST = nil
local function onVsync()
  frame = frame + 1
  if XSPOST and XSPOST < 3 then
    XSPOST = XSPOST + 1
    local okc, c = pcall(function() return PCSX.getCPUCycles() end)
    say(string.format('XS vsync n=%d f=%d cyc=%s', XSPOST, frame, okc and tostring(c) or 'na'))
  end
  for _, pk in ipairs(pokes) do
    if frame == pk[1] then
      local off = pk[2] % 0x200000
      if pk[3] == 2 then ffi.cast('uint16_t*', mem + off)[0] = pk[4] else ffi.cast('uint32_t*', mem + off)[0] = pk[4] end
      print(string.format('POKE f=%d addr=0x%X val=%d', frame, pk[2], pk[4]))
    end
  end
  for _, op in ipairs(orpokes) do
    if frame >= op[1] and frame <= op[2] then
      local off = op[3] % 0x200000
      local ptr = (op[4] == 2) and ffi.cast('uint16_t*', mem + off) or ffi.cast('uint32_t*', mem + off)
      local old = ptr[0]
      local new = bit.bor(old, op[5])
      if op[4] == 2 then new = new % 65536 else new = new % 4294967296 end
      if new ~= old then ptr[0] = new; if frame == op[1] then print(string.format('ORPOKE f=%d addr=0x%X old=%d new=%d', frame, op[3], old, new)) end end
    end
  end
  local iev = INEV[frame]
  if iev then for _, e in ipairs(iev) do
    if e[1] == 1 then if not (BOT.on and frame > BOT.from) then pad.setOverride(e[2]) end else pad.clearOverride(e[2]) end
  end end
  for _, p in ipairs(polls) do
    local v = u32(p[1])
    if last[p[2]] ~= v and frame > 4000 and not (BOT.on and frame > BOT.from and p[2]:sub(1, 1) == 'A') then print(string.format('CHG%s f=%d %s: %s -> %d', pass >= 2 and tostring(pass) or '', frame, p[2], tostring(last[p[2]]), v)) end
    last[p[2]] = v
  end
  if SAVEF and LOADF and frame >= SAVEF and frame <= LOADF and (frame % 500 == 0) then
    local ok, h = pcall(hram)
    print(string.format('SVS p=%d f=%d ram=%d p1=%s', pass, frame, ok and h or -1, p1words()))
  end
  if MODUS == 'pd' and SAVEF and frame >= SAVEF and HPSET[frame] then pcall(hpages) end
  if SAVEF and MODUS ~= 'xs' and MODUS ~= 'xb' and MODUS ~= 'xv' and pass == 1 and not saved and frame == SAVEF then
    if MODUS == 'vs' then doSave() else PCSX.nextTick(doSave) end
  end
  if LOADF and (pass == 1 or (MODUS == 'pd' and pass == 2)) and saved and frame == LOADF then
    if MODUS == 'vs' then doLoad() else PCSX.nextTick(doLoad) end
  end
  if SVSON and frame >= SVSFROM and (((frame - SVSFROM) % SVSN == 0) or svsset[frame]) then
    local fr = frame; PCSX.nextTick(function() svsample(fr) end)
  end
  if SVSON and shotf[frame] then local fr = frame; PCSX.nextTick(function() svshot(fr) end) end
  if not SVSON and frame >= HFROM and (frame - HFROM) % HSTEP == 0 then
    local ok, h = pcall(hram)
    print(string.format('HSH f=%d ram=%d', frame, ok and h or -1))
    hfb(frame)
  end
  DISC.tick(frame)
  if hblkset[frame] then
    local p = ffi.cast('uint32_t*', mem)
    local out = {}
    for b = 0, 31 do
      local h = 0
      for i = b * 16384, b * 16384 + 16383 do h = bit.tobit(bit.rol(bit.bxor(h, p[i]), 5) + 40503) end
      out[#out + 1] = tostring(h % 4294967296)
    end
    print(string.format('HSB f=%d %s', frame, table.concat(out, ' ')))
  end
  if hfrset[frame] then
    local fr = frame
    if REFOUT ~= '' then pcall(function()
      local fh = io.open(string.format('%s_%d.bin', REFOUT, fr), 'wb'); fh:write(ffi.string(mem, 0x200000)); fh:close()
      print(string.format('WDREF f=%d ok', fr))
    end) end
    if REFIN ~= '' then
      local okd, ed = pcall(wdiff, fr)
      if not okd then print('WDN f=' .. fr .. ' galat=' .. tostring(ed):gsub('[^%w%s_%.:]', ''):sub(1, 60)) end
    end
  end
  if SCAN.jobs[frame] then SCAN.runall(SCAN.jobs[frame], frame) end
  if BOT.on and frame > BOT.from then BOT.tick(frame) end
  if dumpset[frame] then PCSX.nextTick(function()
    local fh = io.open(string.format('%s/r_%05d.bin', OUT, frame), 'wb'); fh:write(ffi.string(PCSX.getMemPtr(), 0x200000)); fh:close(); print('DUMP ' .. frame) end) end
  if shotset[frame] then PCSX.nextTick(function()
    local ss = PCSX.GPU.takeScreenShot(); local f = Support.File.open(string.format('%s/f%05d.raw', OUT, frame), 'TRUNCATE')
    f:writeMoveSlice(ss.data); f:close(); print('SHOT ' .. frame) end) end
  if frame >= MAXF then PCSX.nextTick(function() PCSX.quit(0) end) end
  if frame % 1000 == 0 then print(string.format('TIME f=%d t=%.1f', frame, wall() - WALL0)) end
  if (MODUS == 'xs' or MODUS == 'xb' or MODUS == 'xv') and STATEOUT and frame == SAVEF then PCSX.nextTick(xsave) end
end
function install() listener = PCSX.Events.createEventListener('GPU::Vsync', onVsync) end
print('probe siap; input=' .. #inputs .. ' MAXF=' .. MAXF)
-- MODUS=xs: proses penulis (STATEOUT) menyimpan state mentah ke berkas SEMENTARA di runner pada SAVEF lalu keluar; proses pembaca (STATEIN, LSITE=top|nt|vs1)
-- memuat berkas itu di proses BARU dan melanjutkan dari SAVEF. Berkas state tidak pernah keluar dari runner (dihapus oleh run_remote.sh).
if (MODUS == 'xs' or MODUS == 'xb' or MODUS == 'xv') and STATEIN then
  local function xload(tag)
    say('XS muat mulai site=' .. LSITE .. ' tag=' .. tag)
    local okf, fl = pcall(function() return Support.File.open(STATEIN) end)
    local ok, e = pcall(function() PCSX.loadSaveState(fl) end)
    say('XS muat selesai ok=' .. tostring(ok) .. ' ' .. tostring(e):gsub('[^%w%s_%.:]', ''):sub(1, 80))
    if not ok then return end
    frame = SAVEF; last = {}; pass = 2
    local n = 0
    for _, i in ipairs(inputs) do if i[1] <= frame and frame < i[2] then pad.setOverride(i[3]); n = n + 1 end end
    local okh, h = pcall(hram)
    say(string.format('XS sesudah_muat f=%d ram=%d override_aktif=%d', frame, okh and h or -1, n))
    local function cyc() local okc, c = pcall(function() return PCSX.getCPUCycles() end); return okc and tostring(c) or 'na' end
    local vals = {}
    for _, pl in ipairs(polls) do vals[#vals+1] = pl[2] .. '=' .. tostring(u32(pl[1])) end
    say('XS nilai ' .. table.concat(vals, ' ') .. ' cyc=' .. cyc())
    XSPOST = 0
    XSEV = XSEV or {}
    for _, evn in ipairs({'ExecutionFlow::Pause', 'ExecutionFlow::Run', 'ExecutionFlow::Reset'}) do
      pcall(function() XSEV[#XSEV + 1] = PCSX.Events.createEventListener(evn, function() say('XS ev ' .. evn .. ' cyc=' .. cyc()) end) end)
    end
    install()
    PCSX.nextTick(function()
      say('XS tick1 cyc=' .. cyc())
      local okr, er = pcall(function() PCSX.resumeEmulator() end)
      say('XS resume ok=' .. tostring(okr) .. ' ' .. tostring(er):gsub('[^%w%s_%.:]', ''):sub(1, 60))
      PCSX.nextTick(function() say('XS tick2 cyc=' .. cyc()) end)
    end)
  end
  if LSITE == 'top' then xload('top')
  elseif LSITE == 'nt' then PCSX.nextTick(function() xload('nt') end)
  else
    local one; one = PCSX.Events.createEventListener('GPU::Vsync', function() one = nil; PCSX.nextTick(function() xload('vs1') end) end)
  end
else
  install()
end
