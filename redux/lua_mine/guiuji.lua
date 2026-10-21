-- Uji tanpa game: baca piksel screenshot dan VRAM sebagai ANGKA (byte, nonzero, hash), muat state di BIOS. Hanya nama/tipe/angka.
io.stdout:setvbuf('line')
local ffi = require 'ffi'
local bit = require 'bit'
ffi.cdef [[ typedef long time_t; typedef struct { time_t tv_sec; long tv_nsec; } ts_t; int clock_gettime(int, ts_t*); ]]
local function now() local t = ffi.new('ts_t'); ffi.C.clock_gettime(1, t); return tonumber(t.tv_sec) + tonumber(t.tv_nsec) / 1e9 end
local t0 = now()
local function clean(x, n) return (tostring(x):gsub('[^%w%s_%.:,=<>%(%)%[%]/%-]', '')):sub(1, n or 90) end
local function say(m) print('API ' .. m); pcall(function() io.stderr:write('API ' .. m .. '\n'); io.stderr:flush() end) end
-- ambil byte dari Slice: coba tostring, lalu buffer
local function bytes_of(obj)
  local ok, s = pcall(function() return tostring(obj) end)
  if ok and type(s) == 'string' and #s >= 4096 then return s, 'tostring' end
  local ok2, r = pcall(function()
    local b = Support.File.buffer(); b:writeMoveSlice(obj)
    local n = b:size(); local x = b:readAt(n, 0)
    return tostring(x)
  end)
  if ok2 and type(r) == 'string' and #r >= 4096 then return r, 'buffer.readAt' end
  return nil, 'gagal tostring_len=' .. (ok and #tostring(s) or -1) .. ' buf=' .. clean(r, 50)
end
local function stats(tag, obj)
  local s, how = bytes_of(obj)
  if not s then say('V ' .. tag .. ' tanpa_byte ' .. how); return end
  local p = ffi.cast('const uint8_t*', s)
  local nz, h = 0, 0
  for i = 0, #s - 1 do if p[i] ~= 0 then nz = nz + 1 end; h = bit.tobit(bit.rol(bit.bxor(h, p[i]), 5) + 40503) end
  say(string.format('V %s via=%s bytes=%d nonzero=%d hash=%d', tag, how, #s, nz, h % 4294967296))
end
local frame = 0
listener = PCSX.Events.createEventListener('GPU::Vsync', function()
  frame = frame + 1
  if frame % 40 == 0 and frame <= 300 then say(string.format('T f=%05d t=%.2f', frame, now() - t0)) end
  if frame == 40 or frame == 120 or frame == 200 then
    PCSX.nextTick(function()
      local f = frame
      local ok, ss = pcall(function() return PCSX.GPU.takeScreenShot() end)
      if ok then say(string.format('V ss f=%d w=%s h=%s', f, tostring(ss.width), tostring(ss.height))); stats('ss_f' .. f, ss.data) else say('V ss galat') end
      local ok2, v = pcall(function() return PCSX.GPU.getVRAM() end)
      say('V getVRAM f=' .. f .. ' ok=' .. tostring(ok2) .. ' tipe=' .. type(v))
      if ok2 then stats('vram_f' .. f, v) end
    end)
  end
  if frame == 240 then
    local ok, s = pcall(function() return PCSX.createSaveState() end)
    say('C createSaveState ok=' .. tostring(ok))
    if ok then
      say('C muat mulai'); local ok2 = pcall(function() PCSX.loadSaveState(s) end); say('C muat selesai ok=' .. tostring(ok2))
    end
  end
  if frame >= 300 then say('X selesai t=' .. string.format('%.2f', now() - t0)); PCSX.nextTick(function() PCSX.quit(0) end) end
end)
