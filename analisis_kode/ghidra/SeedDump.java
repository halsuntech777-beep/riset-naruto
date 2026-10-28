import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.mem.*;
import java.io.*;
import java.util.*;

// Prascript untuk dump RAM mentah (basis 0x80000000): tanam fungsi pada target jal yang selaras, di rentang 0x80010000..0x80200000,
// bila kata pertama target adalah prolog (addiu sp,sp,-N) atau target dipanggil >=2 kali. Tulis jumlah ke berkas arg0.
public class SeedDump extends GhidraScript {
  @Override public void run() throws Exception {
    Memory m = currentProgram.getMemory();
    MemoryBlock blk = m.getBlocks()[0];
    long base = blk.getStart().getOffset();
    byte[] b = new byte[(int) blk.getSize()];
    m.getBytes(blk.getStart(), b);
    AddressSpace sp = currentProgram.getAddressFactory().getDefaultAddressSpace();
    long lo = 0x80010000L, hi = 0x80200000L;
    HashMap<Long, Integer> cnt = new HashMap<>();
    long jalAll = 0;
    for (int i = 0; i + 4 <= b.length; i += 4) {
      long pc = base + i;
      if (pc < lo || pc >= hi) continue;
      int w = (b[i] & 0xff) | ((b[i+1] & 0xff) << 8) | ((b[i+2] & 0xff) << 16) | ((b[i+3] & 0xff) << 24);
      if ((w >>> 26) == 3) {
        jalAll++;
        long t = (base & 0xF0000000L) | ((long) (w & 0x3FFFFFF) << 2);
        if (t >= lo && t < hi) cnt.merge(t, 1, Integer::sum);
      }
    }
    TreeSet<Long> tg = new TreeSet<>();
    for (Map.Entry<Long, Integer> e : cnt.entrySet()) {
      int i = (int) (e.getKey() - base);
      int w = (b[i] & 0xff) | ((b[i+1] & 0xff) << 8) | ((b[i+2] & 0xff) << 16) | ((b[i+3] & 0xff) << 24);
      boolean prolog = (w >>> 16) == 0x27BD && (w & 0x8000) != 0;
      if (prolog || e.getValue() >= 2) tg.add(e.getKey());
    }
    tg.add(0x80011448L);
    int ok = 0;
    for (long t : tg) {
      Address a = sp.getAddress(t);
      try { disassemble(a); if (getFunctionAt(a) == null) createFunction(a, null); ok++; } catch (Exception e) { }
    }
    try (PrintWriter w = new PrintWriter(getScriptArgs()[0])) {
      w.println("jal_total=" + jalAll);
      w.println("target_unik_dalam_rentang=" + cnt.size());
      w.println("target_ditanam=" + tg.size() + " berhasil=" + ok);
    }
  }
}
