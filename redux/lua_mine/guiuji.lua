-- Uji mode GUI (tanpa -cli) + Mesa llvmpipe TANPA game (BIOS bawaan). Hanya angka/tipe yang dicetak (prefiks "API ").
io.stdout:setvbuf('line')
local ffi = require 'ffi'
local bit = require 'bit'
local OUT = os.getenv('OUTDIR') or '/tmp'
local function say(m) print('API ' .. m); pcall(function() io.stderr:write('API ' .. m .. '\n'); io.stderr:flush() end) end
local frame = 0
local function shot(tag)
  PCSX.nextTick(function()
    local ok, err = pcall(function()
      local ss = PCSX.GPU.takeScreenShot()
      local meta = {}
      for _, k in ipairs({ 'width', 'height', 'bpp' }) do local v; pcall(function() v = ss[k] end); meta[#meta + 1] = k .. '=' .. tostring(v) end
      local path = string.format('%s/g_%s.raw', OUT, tag)
      local f = Support.File.open(path, 'TRUNCATE'); f:writeMoveSlice(ss.data); f:close()
      local fh = io.open(path, 'rb'); local s = fh:read('*a'); fh:close(); os.remove(path)
      local p = ffi.cast('const uint8_t*', s)
      local nz, h = 0, 0
      for i = 0, #s - 1 do if p[i] ~= 0 then nz = nz + 1 end; h = bit.tobit(bit.rol(bit.bxor(h, p[i]), 5) + 40503) end
      say(string.format('shot %s bytes=%d nonzero=%d hash=%d %s', tag, #s, nz, h % 4294967296, table.concat(meta, ' ')))
    end)
    if not ok then say('shot ' .. tag .. ' galat=' .. tostring(err):gsub('[^%w%s_%.:]', ''):sub(1, 90)) end
  end)
end
local listener
listener = PCSX.Events.createEventListener('GPU::Vsync', function()
  frame = frame + 1
  if frame == 1 then say('mulai gui-mode') end
  if frame == 60 or frame == 120 or frame == 180 then shot('f' .. frame) end
  if frame == 200 then
    local ok, s = pcall(function() return PCSX.createSaveState() end)
    say('createSaveState ok=' .. tostring(ok) .. ' tipe=' .. type(s))
    if ok then
      say('muat mulai')
      local ok2, e2 = pcall(function() PCSX.loadSaveState(s) end)
      say('muat selesai ok=' .. tostring(ok2))
    end
  end
  if frame == 230 then shot('f230_sesudah_muat') end
  if frame >= 260 then say('selesai'); PCSX.nextTick(function() PCSX.quit(0) end) end
end)
