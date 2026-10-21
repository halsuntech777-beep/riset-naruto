-- Diagnostik TANPA game (BIOS bawaan saja): (1) pohon PCSX.settings + kecepatan (APIV=cfg), (2) serialisasi state ke berkas (APIV=ser, APIS=file|zr|buf).
-- Hanya nama/tipe/angka yang dicetak (prefiks "API "). State sementara hanya di temp runner dan dihapus.
local ffi = require 'ffi'
local bit = require 'bit'
pcall(function() io.stdout:setvbuf('line') end)
local V = os.getenv('APIV') or 'cfg'
local S = os.getenv('APIS') or 'file'
local PATH = os.getenv('APIPATH') or '/tmp/ss_uji.bin'
local function say(m) print('API ' .. m); pcall(function() io.stderr:write('API ' .. m .. '\n'); io.stderr:flush() end) end
local function et(e) return tostring(e):gsub('[^%w%s_%.:]', ''):sub(1, 100) end
local now = function() return os.clock() end
pcall(function()
  ffi.cdef[[ typedef struct { long tv_sec; long tv_usec; } tvx_t; int gettimeofday(tvx_t*, void*); ]]
  now = function() local t = ffi.new('tvx_t'); ffi.C.gettimeofday(t, nil); return tonumber(t.tv_sec) + tonumber(t.tv_usec) / 1e6 end
end)
local mem = PCSX.getMemPtr()
local function hram()
  local p = ffi.cast('uint32_t*', mem); local h = 0
  for i = 0, 0x80000 - 1 do h = bit.tobit(bit.rol(bit.bxor(h, p[i]), 5) + 40503) end
  return h % 4294967296
end
local seen = {}
local function dump(t, path, depth)
  if depth > 4 or seen[t] then return end
  seen[t] = true
  local names = {}
  pcall(function() for k, v in pairs(t) do names[#names + 1] = { tostring(k), v } end end)
  local mt = getmetatable(t)
  if type(mt) == 'table' and type(mt.__index) == 'table' then
    pcall(function() for k, v in pairs(mt.__index) do names[#names + 1] = { 'mt:' .. tostring(k), v } end end)
  end
  table.sort(names, function(a, b) return a[1] < b[1] end)
  local parts = {}
  for _, kv in ipairs(names) do
    local k, v = kv[1], kv[2]
    local tv = type(v)
    if tv == 'table' then dump(v, path .. '.' .. k, depth + 1); parts[#parts + 1] = k .. ':table'
    elseif tv == 'number' or tv == 'boolean' then parts[#parts + 1] = k .. '=' .. tostring(v)
    else parts[#parts + 1] = k .. ':' .. tv end
  end
  local line = table.concat(parts, ' ')
  while #line > 380 do say(path .. ' ' .. line:sub(1, 380)); line = line:sub(381) end
  say(path .. ' ' .. line)
end
local frame, t0, t1, savedh, saved, flipped = 0, nil, nil, nil, nil, {}
local listener
listener = PCSX.Events.createEventListener('GPU::Vsync', function()
  frame = frame + 1
  if V == 'cfg' then
    if frame == 20 then
      say('varian=cfg')
      for _, n in ipairs({ 'settings', 'GUI', 'Misc', 'SPU', 'GPU', 'Events' }) do
        local o = PCSX[n]; say('== PCSX.' .. n .. ' tipe=' .. type(o))
        if type(o) == 'table' then dump(o, 'PCSX.' .. n, 1) end
      end
    elseif frame == 60 then t0 = now()
    elseif frame == 360 then
      t1 = now(); say(string.format('fps_awal=%.1f (300 frame dalam %.2f dtk)', 300 / (t1 - t0), t1 - t0))
      local function walk(t, path, d)
        if d > 4 then return end
        pcall(function()
          for k, v in pairs(t) do
            local ks = tostring(k)
            if type(v) == 'table' then walk(v, path .. '.' .. ks, d + 1)
            elseif type(v) == 'boolean' and v and ks:lower():match('limit') then
              local ok = pcall(function() t[k] = false end)
              flipped[#flipped + 1] = path .. '.' .. ks; say('set false ' .. path .. '.' .. ks .. ' ok=' .. tostring(ok))
            end
          end
        end)
      end
      pcall(walk, PCSX.settings, 'settings', 1)
      say('nama_diubah=' .. #flipped)
    elseif frame == 361 then t0 = now()
    elseif frame == 661 then
      t1 = now(); say(string.format('fps_sesudah=%.1f (300 frame dalam %.2f dtk)', 300 / (t1 - t0), t1 - t0))
      say('selesai'); PCSX.nextTick(function() PCSX.quit(0) end)
    end
    return
  end
  -- V == 'ser'
  if frame == 30 then
    say('varian=ser sub=' .. S)
    local ok, st = pcall(function() return PCSX.createSaveState() end)
    say('createSaveState ok=' .. tostring(ok) .. ' tipe=' .. type(st))
    if not ok then return end
    local okn, n = pcall(function() return #st end); say('len ok=' .. tostring(okn) .. ' n=' .. tostring(n))
    local oks, s = pcall(function() return tostring(st) end)
    say('tostring ok=' .. tostring(oks) .. ' panjang=' .. tostring(oks and #s or -1))
    if oks and #s >= 8 then say('byte_awal=' .. table.concat({ s:byte(1, 8) }, ',')) end
    savedh = hram(); say('ram_simpan=' .. savedh)
    if not oks then return end
    local f = io.open(PATH, 'wb'); f:write(s); f:close()
    local g = io.open(PATH, 'rb'); local sz = g:seek('end'); g:close(); say('berkas_ukuran=' .. tostring(sz))
    saved = s
  elseif frame == 60 and saved then
    local h0 = hram(); say('ram_sebelum_muat=' .. h0 .. ' beda_dari_simpan=' .. tostring(h0 ~= savedh))
    local okl, e
    if S == 'file' then
      local okf, fl = pcall(function() return Support.File.open(PATH) end); say('open READ ok=' .. tostring(okf))
      say('muat(berkas) mulai'); okl, e = pcall(function() PCSX.loadSaveState(fl) end)
    elseif S == 'zr' then
      local okf, fl = pcall(function() return Support.File.zReader(Support.File.open(PATH)) end); say('zReader ok=' .. tostring(okf) .. ' ' .. (okf and '' or et(fl)))
      say('muat(zReader) mulai'); okl, e = pcall(function() PCSX.loadSaveState(fl) end)
    elseif S == 'buf' then
      local okb, b = pcall(function() return Support.NewLuaBuffer(#saved) end); say('NewLuaBuffer ok=' .. tostring(okb) .. ' tipe=' .. type(b))
      local okfill = pcall(function() for i = 1, #saved do b[i - 1] = saved:byte(i) end end); say('isi_buffer ok=' .. tostring(okfill))
      say('muat(buffer) mulai'); okl, e = pcall(function() PCSX.loadSaveState(b) end)
    end
    say('muat selesai ok=' .. tostring(okl) .. ' ' .. et(e))
    local h1 = hram(); say('ram_sesudah_muat=' .. h1 .. ' sama_dengan_simpan=' .. tostring(h1 == savedh))
  elseif frame >= 100 then
    say('selesai'); PCSX.nextTick(function() PCSX.quit(0) end)
  end
end)
