import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.lang.Register;
import ghidra.program.model.listing.*;
import ghidra.program.model.scalar.Scalar;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;

// Langkah 4: cari kandidat generator angka acak. Hanya metadata (alamat, ukuran, jumlah pemanggil) ke berkas arg0.
// (a) konstanta pengali LCG umum lewat pasangan lui+ori/addiu; (b) stub BIOS A0:0x2F (rand) / A0:0x30 (srand).
public class FindRng extends GhidraScript {
  static final long[] K = {0x41C64E6DL, 0x000343FDL, 0x6C078965L, 0x5D588B65L, 0x0019660DL, 0x08088405L, 0x3C6EF35FL, 0x00269EC3L};

  Function fnAt(Address a) { return currentProgram.getFunctionManager().getFunctionContaining(a); }

  String callers(Function f) {
    ReferenceManager rm = currentProgram.getReferenceManager();
    int sites = 0;
    TreeSet<Long> cf = new TreeSet<>();
    for (Reference r : rm.getReferencesTo(f.getEntryPoint())) {
      if (!r.getReferenceType().isCall()) continue;
      sites++;
      Function c = fnAt(r.getFromAddress());
      if (c != null) cf.add(c.getEntryPoint().getOffset());
    }
    StringBuilder sb = new StringBuilder();
    int n = 0;
    for (long a : cf) { if (n++ >= 40) break; sb.append(String.format("%X ", a)); }
    return "callsites=" + sites + " funcs_pemanggil=" + cf.size() + " pemanggil=[" + sb.toString().trim() + "]";
  }

  @Override public void run() throws Exception {
    Listing L = currentProgram.getListing();
    FunctionManager fm = currentProgram.getFunctionManager();
    ArrayList<String> out = new ArrayList<>();
    TreeSet<Long> seen = new TreeSet<>();
    int nK = 0, nB = 0;
    for (Function f : fm.getFunctions(true)) {
      ArrayList<Instruction> ins = new ArrayList<>();
      for (Instruction i : L.getInstructions(f.getBody(), true)) ins.add(i);
      Map<String, Long> hi = new HashMap<>();
      Map<String, Integer> hiAt = new HashMap<>();
      for (int idx = 0; idx < ins.size(); idx++) {
        Instruction i = ins.get(idx);
        String m = i.getMnemonicString().toLowerCase();
        try {
          if (m.equals("lui") && i.getNumOperands() >= 2) {
            Register r = i.getRegister(0); Scalar s = i.getScalar(1);
            if (r != null && s != null) { hi.put(r.getName(), s.getValue() & 0xffffL); hiAt.put(r.getName(), idx); }
          } else if ((m.equals("ori") || m.equals("addiu") || m.equals("addi")) && i.getNumOperands() >= 3) {
            Register src = i.getRegister(1); Scalar s = i.getScalar(2);
            if (src != null && s != null && hi.containsKey(src.getName()) && idx - hiAt.get(src.getName()) <= 8) {
              long lo = m.equals("ori") ? (s.getValue() & 0xffffL) : s.getSignedValue();
              long c = ((hi.get(src.getName()) << 16) + lo) & 0xffffffffL;
              for (long k : K) if (c == k && seen.add(i.getAddress().getOffset())) {
                nK++;
                out.add(String.format("LCG const=0x%08X @%X fungsi=%X ukuran=%d %s", c, i.getAddress().getOffset(), f.getEntryPoint().getOffset(), f.getBody().getNumAddresses(), callers(f)));
              }
            }
          }
          // stub BIOS: t1 <- 0x2F/0x30 dekat jr/jalr dan t2 <- 0xA0
          if ((m.equals("li") || m.equals("addiu") || m.equals("ori")) && i.getNumOperands() >= 2) {
            Register d = i.getRegister(0);
            Scalar s = i.getScalar(i.getNumOperands() - 1);
            if (d != null && s != null && d.getName().equals("t1") && (s.getValue() == 0x2F || s.getValue() == 0x30)) {
              boolean jr = false, a0 = false;
              for (int j = Math.max(0, idx - 4); j <= Math.min(ins.size() - 1, idx + 4); j++) {
                Instruction q = ins.get(j); String qm = q.getMnemonicString().toLowerCase();
                if (qm.equals("jr") || qm.equals("jalr")) jr = true;
                if ((qm.equals("li") || qm.equals("addiu") || qm.equals("ori")) && q.getRegister(0) != null && q.getRegister(0).getName().equals("t2")) {
                  Scalar qs = q.getScalar(q.getNumOperands() - 1); if (qs != null && qs.getValue() == 0xA0) a0 = true;
                }
              }
              if (jr && a0) {
                nB++;
                out.add(String.format("BIOS A0:0x%02X (%s) @%X fungsi=%X ukuran=%d %s", s.getValue(), s.getValue() == 0x2F ? "rand" : "srand", i.getAddress().getOffset(), f.getEntryPoint().getOffset(), f.getBody().getNumAddresses(), callers(f)));
              }
            }
          }
        } catch (Exception e) { }
      }
    }
    try (PrintWriter w = new PrintWriter(getScriptArgs()[0])) {
      w.println("LANGKAH4: kandidat_LCG=" + nK + " stub_BIOS_rand_srand=" + nB);
      for (String s : out) w.println("  " + s);
    }
  }
}
