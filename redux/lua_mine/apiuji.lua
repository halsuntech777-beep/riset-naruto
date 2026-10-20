-- Diagnostik save-state TANPA game (BIOS bawaan saja). Hanya nama/tipe/angka yang dicetak (prefiks "API ").
io.stdout:setvbuf('line')
local V = os.getenv('APIV') or 'inspect'
local PATH = os.getenv('APIPATH') or '/tmp/ss_apiuji.bin'
local function say(m) print('API ' .. m); pcall(function() io.stderr:write('API ' .. m .. '\n'); io.stderr:flush() end) end
local function keys(t, lim)
  local n = {}
  pcall(function() for k, v in pairs(t) do n[#n + 1] = tostring(k) .. ':' .. type(v) end end)
  table.sort(n)
  local c = #n
  if lim and c > lim then local o = {} for i = 1, lim do o[i] = n[i] end n = o end
  return c .. ' [' .. table.concat(n, ' ') .. ']'
end
local function mtkeys(o)
  local m = getmetatable(o)
  if type(m) ~= 'table' then return 'tanpa-metatable tipe=' .. type(o) end
  local ix = m.__index
  return 'mt=' .. keys(m, 10) .. ' index=' .. (type(ix) == 'table' and keys(ix, 60) or type(ix))
end
local frame = 0
local listener
listener = PCSX.Events.createEventListener('GPU::Vsync', function()
  frame = frame + 1
  if frame == 30 then
    say('varian=' .. V)
    say('Support=' .. type(Support) .. ' ' .. (type(Support) == 'table' and keys(Support, 40) or ''))
    say('Support.File=' .. type(Support and Support.File) .. ' ' .. (Support and type(Support.File) == 'table' and keys(Support.File, 30) or ''))
    local ok, s = pcall(function() return PCSX.createSaveState() end)
    say('createSaveState ok=' .. tostring(ok) .. ' tipe=' .. type(s))
    if not ok then return end
    say('state ' .. mtkeys(s))
    if V == 'a' then
      say('muat(tabel) mulai')
      local ok2, e2 = pcall(function() PCSX.loadSaveState(s) end)
      say('muat(tabel) selesai ok=' .. tostring(ok2) .. ' ' .. tostring(e2):gsub('[^%w%s_%.:]', ''):sub(1, 80))
    elseif V == 'b' then
      local f
      for _, mode in ipairs({ 'TRUNCATE', 'CREATE' }) do
        local okf, ff = pcall(function() return Support.File.open(PATH, mode) end)
        say('open ' .. mode .. ' ok=' .. tostring(okf) .. ' tipe=' .. type(ff))
        if okf and ff then f = ff break end
      end
      if f then
        say('file ' .. mtkeys(f))
        local okw, ew = pcall(function() return f:writeMoveSlice(s) end)
        say('writeMoveSlice ok=' .. tostring(okw) .. ' ' .. tostring(ew):gsub('[^%w%s_%.:]', ''):sub(1, 80))
        pcall(function() f:close() end)
        local okg, g = pcall(function() return Support.File.open(PATH) end)
        say('open READ ok=' .. tostring(okg) .. ' tipe=' .. type(g))
        local oks, sz = pcall(function() return g:size() end)
        say('size ok=' .. tostring(oks) .. ' n=' .. tostring(sz))
        say('muat(berkas) mulai')
        local ok2, e2 = pcall(function() PCSX.loadSaveState(g) end)
        say('muat(berkas) selesai ok=' .. tostring(ok2) .. ' ' .. tostring(e2):gsub('[^%w%s_%.:]', ''):sub(1, 80))
      end
    end
  end
  if frame >= 90 then say('selesai'); PCSX.nextTick(function() PCSX.quit(0) end) end
end)
