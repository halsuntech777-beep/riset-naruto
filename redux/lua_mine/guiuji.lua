-- Uji tanpa game: (1) kecepatan frame, (2) nama/tipe API GPU, (3) bentuk data screenshot, (4) skema state (mencari VRAM). Hanya nama/tipe/angka.
io.stdout:setvbuf('line')
local ffi = require 'ffi'
ffi.cdef [[ typedef long time_t; typedef struct { time_t tv_sec; long tv_nsec; } ts_t; int clock_gettime(int, ts_t*); ]]
local function now() local t = ffi.new('ts_t'); ffi.C.clock_gettime(1, t); return tonumber(t.tv_sec) + tonumber(t.tv_nsec) / 1e9 end
local t0 = now()
local function clean(x, n) return (tostring(x):gsub('[^%w%s_%.:,=<>%(%)%[%]/%-]', '')):sub(1, n or 90) end
local function say(m) print('API ' .. m); pcall(function() io.stderr:write('API ' .. m .. '\n'); io.stderr:flush() end) end
local function keys(name, t)
  local ks = {}
  pcall(function() for k, v in pairs(t) do ks[#ks + 1] = tostring(k) .. ':' .. type(v) end end)
  table.sort(ks); say('K ' .. name .. ' (' .. #ks .. ')=' .. clean(table.concat(ks, ','), 600))
end
local function try(label, fn)
  local ok, r = pcall(fn)
  say('R ' .. label .. ' ok=' .. tostring(ok) .. ' -> ' .. clean(r, 80))
end
local frame = 0
listener = PCSX.Events.createEventListener('GPU::Vsync', function()
  frame = frame + 1
  if frame % 20 == 0 and frame <= 300 then say(string.format('T f=%05d t=%.2f', frame, now() - t0)) end
  if frame == 30 then
    keys('PCSX.GPU', PCSX.GPU); keys('PCSX.GUI', PCSX.GUI); keys('PCSX.Misc', PCSX.Misc)
  end
  if frame == 40 then
    PCSX.nextTick(function()
      local ok, ss = pcall(function() return PCSX.GPU.takeScreenShot() end)
      say('S takeScreenShot ok=' .. tostring(ok) .. ' tipe=' .. type(ss))
      if not ok then return end
      keys('ss', ss)
      local d = ss.data
      say('S data tipe=' .. type(d) .. ' tostring=' .. clean(d, 60))
      try('S #data', function() return #d end)
      try('S data:size()', function() return d:size() end)
      try('S buffer+writeMoveSlice', function() local b = Support.File.buffer(); b:writeMoveSlice(d); return b:size() end)
      try('S meta.__index keys', function()
        local mt = getmetatable(d); local ks = {}
        for k in pairs(mt.__index or {}) do ks[#ks + 1] = tostring(k) end
        table.sort(ks); return table.concat(ks, ',')
      end)
    end)
  end
  if frame == 60 then
    local ok, sch = pcall(function() return PCSX.getSaveStateProtoSchema() end)
    say('P schema ok=' .. tostring(ok) .. ' tipe=' .. type(sch) .. ' len=' .. (ok and #tostring(sch) or -1))
    if ok then
      local n = 0
      for line in tostring(sch):gmatch('[^\n]+') do
        local l = line:lower()
        if (l:find('vram') or l:find('gpu') or l:find('framebuffer') or l:find('display')) and n < 14 then
          n = n + 1; say(string.format('P %02d %s', n, clean(line:gsub('^%s+', ''), 100)))
        end
      end
    end
  end
  if frame == 100 then
    say('C sebelum createSaveState f=100')
    local ok, s = pcall(function() return PCSX.createSaveState() end)
    say('C createSaveState ok=' .. tostring(ok) .. ' tipe=' .. type(s))
    if ok then try('C #state', function() return #s end); try('C state:size()', function() return s:size() end) end
  end
  if frame >= 140 then say('X selesai t=' .. string.format('%.2f', now() - t0)); PCSX.nextTick(function() PCSX.quit(0) end) end
end)
