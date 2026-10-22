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
for line in io.lines(os.getenv('INPUTS')) do
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
  for _, i in ipairs(inputs) do
    if frame == i[1] then pad.setOverride(i[3]) end
    if frame == i[2] then pad.clearOverride(i[3]) end
  end
  for _, p in ipairs(polls) do
    local v = u32(p[1])
    if last[p[2]] ~= v and frame > 4000 then print(string.format('CHG%s f=%d %s: %s -> %d', pass >= 2 and tostring(pass) or '', frame, p[2], tostring(last[p[2]]), v)) end
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
