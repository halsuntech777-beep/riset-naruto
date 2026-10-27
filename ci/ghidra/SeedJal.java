import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.mem.*;
import java.io.*;
import java.util.*;
// Prascript: tanam entry + semua target jal (aligned, dalam rentang) sebagai fungsi sebelum analisis. Tulis jumlah ke berkas arg0.
public class SeedJal extends GhidraScript {
  @Override public void run() throws Exception {
    Memory m = currentProgram.getMemory();
    MemoryBlock blk = m.getBlocks()[0];
    long base = blk.getStart().getOffset(), len = blk.getSize();
    byte[] b = new byte[(int) len];
    m.getBytes(blk.getStart(), b);
    AddressSpace sp = currentProgram.getAddressFactory().getDefaultAddressSpace();
    TreeSet<Long> tg = new TreeSet<>();
    long jalAll = 0;
    for (int i = 0; i + 4 <= b.length; i += 4) {
      int w = (b[i] & 0xff) | ((b[i+1] & 0xff) << 8) | ((b[i+2] & 0xff) << 16) | ((b[i+3] & 0xff) << 24);
      if ((w >>> 26) == 3) {
        jalAll++;
        long t = (base & 0xF0000000L) | ((long)(w & 0x3FFFFFF) << 2);
        if (t >= base && t < base + len) tg.add(t);
      }
    }
    tg.add(0x80011448L);
    int ok = 0;
    for (long t : tg) {
      Address a = sp.getAddress(t);
      try { disassemble(a); if (getFunctionAt(a) == null) createFunction(a, null); ok++; } catch (Exception e) { }
    }
    try (PrintWriter w = new PrintWriter(getScriptArgs()[0])) { w.println("jal_total=" + jalAll); w.println("jal_target_unik_dalam_rentang=" + tg.size()); w.println("benih_berhasil=" + ok); }
  }
}
