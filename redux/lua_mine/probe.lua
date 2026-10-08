-- probe: input terjadwal + polling uang (2 pemain) + dump RAM + screenshot + poke memori
local ffi = require 'ffi'
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
local mem = PCSX.getMemPtr()
local function u32(a) return ffi.cast('uint32_t*', mem + (a % 0x200000))[0] end
local frame, last = 0, {}
local polls = { {0x1EFBBC, 'S1'}, {0x1EFC4C, 'S2'} }
listener = PCSX.Events.createEventListener('GPU::Vsync', function()
  frame = frame + 1
  for _, pk in ipairs(pokes) do
    if frame == pk[1] then
      local off = pk[2] % 0x200000
      if pk[3] == 2 then ffi.cast('uint16_t*', mem + off)[0] = pk[4] else ffi.cast('uint32_t*', mem + off)[0] = pk[4] end
      print(string.format('POKE f=%d addr=0x%X val=%d', frame, pk[2], pk[4]))
    end
  end
  for _, i in ipairs(inputs) do
    if frame == i[1] then pad.setOverride(i[3]) end
    if frame == i[2] then pad.clearOverride(i[3]) end
  end
  for _, p in ipairs(polls) do
    local v = u32(p[1])
    if last[p[2]] ~= v and frame > 4000 then print(string.format('CHG f=%d %s: %s -> %d', frame, p[2], tostring(last[p[2]]), v)) end
    last[p[2]] = v
  end
  if dumpset[frame] then PCSX.nextTick(function()
    local fh = io.open(string.format('%s/r_%05d.bin', OUT, frame), 'wb'); fh:write(ffi.string(PCSX.getMemPtr(), 0x200000)); fh:close(); print('DUMP ' .. frame) end) end
  if shotset[frame] then PCSX.nextTick(function()
    local ss = PCSX.GPU.takeScreenShot(); local f = Support.File.open(string.format('%s/f%05d.raw', OUT, frame), 'TRUNCATE')
    f:writeMoveSlice(ss.data); f:close(); print('SHOT ' .. frame) end) end
  if frame >= MAXF then PCSX.nextTick(function() PCSX.quit(0) end) end
end)
print('probe siap; input=' .. #inputs .. ' MAXF=' .. MAXF)
