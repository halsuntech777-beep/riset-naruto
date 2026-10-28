import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import java.io.*;
import java.util.*;

// Pascript: angka agregat per zona (exe 0x80010000-0x8006D800, atas 0x8006D800-0x80200000) dan cek fungsi exe yang dikenal. Tanpa listing/dekompilasi.
public class OverlayStat extends GhidraScript {
  @Override public void run() throws Exception {
    FunctionManager fm = currentProgram.getFunctionManager();
    AddressSpace sp = currentProgram.getAddressFactory().getDefaultAddressSpace();
    long split = 0x8006D800L;
    int nExe = 0, nUp = 0, bigUp = 0, bigExe = 0; long covExe = 0, covUp = 0;
    for (Function f : fm.getFunctions(true)) {
      long a = f.getEntryPoint().getOffset(), s = f.getBody().getNumAddresses();
      if (a < split) { nExe++; covExe += s; if (s >= 1000) bigExe++; }
      else { nUp++; covUp += s; if (s >= 1000) bigUp++; }
    }
    long[] known = {0x80011448L, 0x80035D78L, 0x800172ECL};
    try (PrintWriter w = new PrintWriter(getScriptArgs()[0])) {
      w.println("GHIDRA dump: " + currentProgram.getLanguageID() + " basis=" + currentProgram.getMemory().getBlocks()[0].getStart() + " blok=" + currentProgram.getMemory().getBlocks()[0].getSize());
      try { for (String l : java.nio.file.Files.readAllLines(java.nio.file.Paths.get("/dev/null"))) { } } catch (Exception e) { }
      w.println("fungsi_total=" + fm.getFunctionCount() + " instruksi=" + currentProgram.getListing().getNumInstructions());
      w.println("zona_exe: fungsi=" + nExe + " cakupan_byte=" + covExe + " >=1000B=" + bigExe);
      w.println("zona_atas(>=0x8006D800): fungsi=" + nUp + " cakupan_byte=" + covUp + " >=1000B=" + bigUp);
      for (long k : known) {
        Function f = fm.getFunctionAt(sp.getAddress(k));
        w.println("fungsi_exe_dikenal 0x" + Long.toHexString(k) + ": " + (f == null ? "TIDAK ADA" : "ada ukuran=" + f.getBody().getNumAddresses()));
      }
    }
  }
}
