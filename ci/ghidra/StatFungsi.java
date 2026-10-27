import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import java.io.*;
import java.nio.file.*;
import java.util.*;
// Pascript: cetak angka agregat (tanpa daftar fungsi, tanpa listing) ke berkas arg0; arg1 = berkas seed dari SeedJal.
public class StatFungsi extends GhidraScript {
  @Override public void run() throws Exception {
    String[] a = getScriptArgs();
    FunctionManager fm = currentProgram.getFunctionManager();
    ArrayList<Long> sz = new ArrayList<>();
    long cov = 0;
    for (Function f : fm.getFunctions(true)) { long s = f.getBody().getNumAddresses(); sz.add(s); cov += s; }
    Collections.sort(sz);
    int n = sz.size();
    long blkSize = currentProgram.getMemory().getBlocks()[0].getSize();
    Listing L = currentProgram.getListing();
    int big = 0, tiny = 0; for (long s : sz) { if (s >= 1000) big++; if (s <= 8) tiny++; }
    boolean entry = getFunctionAt(currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(0x80011448L)) != null;
    try (PrintWriter w = new PrintWriter(a[0])) {
      w.println("LANGKAH3: Ghidra " + currentProgram.getLanguageID() + " basis=" + currentProgram.getMemory().getBlocks()[0].getStart() + " blok=" + blkSize + " byte");
      for (String l : Files.readAllLines(Paths.get(a[1]))) w.println("  seed: " + l);
      w.println("  fungsi_total=" + n + " entry_0x80011448_fungsi=" + entry);
      w.println("  cakupan_fungsi_byte=" + cov + " (" + (100 * cov / blkSize) + "% blok)");
      w.println("  instruksi=" + L.getNumInstructions());
      if (n > 0) w.println("  ukuran_fungsi min=" + sz.get(0) + " median=" + sz.get(n/2) + " p90=" + sz.get(n*9/10) + " maks=" + sz.get(n-1) + " >=1000B:" + big + " <=8B:" + tiny);
    }
  }
}
