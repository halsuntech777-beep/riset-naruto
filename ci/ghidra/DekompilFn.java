import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import java.io.*;

// Langkah 5: dekompilasi fungsi pada alamat arg2 (hex dipisah koma). arg0 = keluaran teks (HANYA di runner, lalu dienkripsi), arg1 = daftar "alamat ukuran".
public class DekompilFn extends GhidraScript {
  @Override public void run() throws Exception {
    String[] a = getScriptArgs();
    DecompInterface di = new DecompInterface();
    di.openProgram(currentProgram);
    AddressSpace sp = currentProgram.getAddressFactory().getDefaultAddressSpace();
    int n = 0, okc = 0;
    try (PrintWriter w = new PrintWriter(a[0]); PrintWriter fl = new PrintWriter(a[1])) {
      for (String t : a[2].split(",")) {
        long v = Long.parseLong(t.trim().replace("0x", ""), 16);
        if (v < 0x80000000L) v |= 0x80000000L;
        Address ad = sp.getAddress(v);
        Function f = getFunctionContaining(ad);
        if (f == null) { disassemble(ad); f = createFunction(ad, null); }
        if (f == null) { w.println("// tidak ada fungsi di " + t); continue; }
        n++;
        fl.println(String.format("%X %d", f.getEntryPoint().getOffset(), f.getBody().getNumAddresses()));
        w.println("// ===== fungsi " + f.getEntryPoint() + " ukuran " + f.getBody().getNumAddresses() + " =====");
        DecompileResults r = di.decompileFunction(f, 60, monitor);
        if (r != null && r.decompileCompleted()) { w.println(r.getDecompiledFunction().getC()); okc++; }
        else w.println("// dekompilasi gagal");
        for (Instruction i : currentProgram.getListing().getInstructions(f.getBody(), true))
          w.println(String.format("//  %X: %s", i.getAddress().getOffset(), i.toString()));
      }
    }
    println("DEKOMPIL n=" + n + " ok=" + okc);
  }
}
