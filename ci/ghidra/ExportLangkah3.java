import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.mem.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;

// Pascript langkah 3 (lengkap). Args: arg0 = folder mentah (sementara, akan dienkripsi), arg1 = berkas ringkasan angka, arg2 = daftar string dari cari_string.py.
// Mentah (fungsi.txt, string_xref.txt, gagal_disasm.txt) TIDAK dikomit polos; hanya ringkasan angka (arg1).
public class ExportLangkah3 extends GhidraScript {
  byte[] blob;
  long base;

  int wordAt(int off) {
    return (blob[off] & 0xff) | ((blob[off + 1] & 0xff) << 8) | ((blob[off + 2] & 0xff) << 16) | ((blob[off + 3] & 0xff) << 24);
  }

  @Override
  public void run() throws Exception {
    String[] a = getScriptArgs();
    StringBuilder sum = new StringBuilder();
    try {
      jalan(a[0], a[2], sum);
    } catch (Throwable t) {
      sum.append("GALAT ").append(t.getClass().getName()).append(": ")
         .append(String.valueOf(t.getMessage()).replaceAll("[^\\x20-\\x7e]", "?")).append("\n");
      StackTraceElement[] st = t.getStackTrace();
      for (int i = 0; i < Math.min(st.length, 6); i++)
        sum.append("  di ").append(st[i].getClassName()).append(".").append(st[i].getMethodName()).append(":").append(st[i].getLineNumber()).append("\n");
    }
    try (PrintWriter w = new PrintWriter(a[1], "UTF-8")) {
      w.print(sum);
    }
  }

  void jalan(String rawDir, String strPath, StringBuilder S) throws Exception {
    new File(rawDir).mkdirs();
    Memory mem = currentProgram.getMemory();
    MemoryBlock blk = mem.getBlocks()[0];
    base = blk.getStart().getOffset();
    blob = new byte[(int) blk.getSize()];
    mem.getBytes(blk.getStart(), blob);
    AddressSpace sp = currentProgram.getAddressFactory().getDefaultAddressSpace();
    Listing L = currentProgram.getListing();
    FunctionManager fm = currentProgram.getFunctionManager();
    ReferenceManager rm = currentProgram.getReferenceManager();

    S.append("LANGKAH3-LENGKAP: Ghidra ").append(currentProgram.getLanguageID()).append(" basis=0x").append(Long.toHexString(base))
     .append(" blok=").append(blob.length).append(" byte; instruksi=").append(L.getNumInstructions()).append("\n");

    // ---- (1) kata GTE ----
    String[] gn = {"cop2_perintah", "mfc2/cfc2/mtc2/ctc2", "lwc2/swc2"};
    int[] tot = new int[3], asIns = new int[3], inFn = new int[3];
    HashMap<Long, Integer> gteFn = new HashMap<>();
    for (int off = 0; off + 4 <= blob.length; off += 4) {
      int w = wordAt(off);
      int op = w >>> 26;
      int cat = -1;
      if ((w >>> 25) == 0x25) cat = 0;
      else if (op == 0x12) {
        int r = (w >>> 21) & 31;
        if (r == 0 || r == 2 || r == 4 || r == 6) cat = 1;
      } else if (op == 0x32 || op == 0x3A) cat = 2;
      if (cat < 0) continue;
      Address ad = sp.getAddress(base + off);
      tot[cat]++;
      if (L.getInstructionAt(ad) != null) asIns[cat]++;
      Function f = fm.getFunctionContaining(ad);
      if (f != null) {
        inFn[cat]++;
        gteFn.merge(f.getEntryPoint().getOffset(), 1, Integer::sum);
      }
    }
    for (int c = 0; c < 3; c++)
      S.append("  GTE ").append(gn[c]).append(": kata_total=").append(tot[c]).append(" terdisassemble_sebagai_instruksi=").append(asIns[c]).append(" di_dalam_fungsi=").append(inFn[c]).append("\n");
    S.append("  fungsi_yang_memuat_kata_GTE=").append(gteFn.size()).append("\n");

    // ---- (2) daftar fungsi + konstanta alamat (lui+addiu/ori/load/store) ----
    TreeMap<Long, TreeSet<Long>> consts = new TreeMap<>();
    int nF = 0, nNoCaller = 0;
    try (PrintWriter pw = new PrintWriter(rawDir + "/fungsi.txt", "UTF-8")) {
      pw.println("entry\tukuran\tpanggilan_masuk\tpanggilan_keluar\tkata_gte\tnama");
      for (Function f : fm.getFunctions(true)) {
        long e = f.getEntryPoint().getOffset();
        int cin = 0;
        for (Reference r : rm.getReferencesTo(f.getEntryPoint())) if (r.getReferenceType().isCall()) cin++;
        int cout = 0;
        long[] hiV = new long[32];
        int[] hiI = new int[32];
        Arrays.fill(hiI, -1000);
        int idx = 0;
        for (Instruction ins : L.getInstructions(f.getBody(), true)) {
          if (ins.getFlowType().isCall()) cout++;
          int off = (int) (ins.getAddress().getOffset() - base);
          if (off >= 0 && off + 4 <= blob.length) {
            int w = wordAt(off);
            int op = w >>> 26, rs = (w >>> 21) & 31, rt = (w >>> 16) & 31, imm = w & 0xFFFF;
            if (op == 0x0F) {
              hiV[rt] = ((long) imm) << 16;
              hiI[rt] = idx;
            } else if ((op == 0x09 || op == 0x0D || (op >= 0x20 && op <= 0x2B)) && idx - hiI[rs] > 0 && idx - hiI[rs] <= 8) {
              long lo = (op == 0x0D) ? imm : (short) imm;
              long c = (hiV[rs] + lo) & 0xFFFFFFFFL;
              if (c >= base && c < base + blob.length) consts.computeIfAbsent(c, k -> new TreeSet<>()).add(e);
            }
          }
          idx++;
        }
        if (cin == 0 && e != 0x80011448L) nNoCaller++;
        nF++;
        pw.println(String.format("%08X\t%d\t%d\t%d\t%d\t%s", e, f.getBody().getNumAddresses(), cin, cout, gteFn.getOrDefault(e, 0), f.getName()));
      }
    }
    S.append("  fungsi=").append(nF).append(" tanpa_pemanggil_langsung(selain_entry)=").append(nNoCaller)
     .append(" konstanta_alamat_unik_hasil_pola=").append(consts.size()).append("\n");

    // ---- (3) string + xref ----
    List<String> sl = Files.readAllLines(Paths.get(strPath), StandardCharsets.UTF_8);
    int ns = 0, nsG = 0, nsO = 0, nsAny = 0, nAscii = 0, nSjis = 0, nAsciiAny = 0, nSjisAny = 0;
    StringBuilder flagged = new StringBuilder();
    try (PrintWriter pw = new PrintWriter(rawDir + "/string_xref.txt", "UTF-8")) {
      pw.println("alamat\tenc\tpanjang\ttag\tref_ghidra\tref_pola_tepat\tref_pola_dalam\tfungsi_pengacu\tteks");
      for (String line : sl) {
        String[] p = line.split("\t", 5);
        if (p.length < 5) continue;
        long A = Long.parseLong(p[0], 16);
        int ln = Integer.parseInt(p[2]);
        int g = 0;
        for (Reference r : rm.getReferencesTo(sp.getAddress(A))) g++;
        TreeSet<Long> ex = consts.get(A);
        int exN = ex == null ? 0 : ex.size();
        int inner = 0;
        for (Map.Entry<Long, TreeSet<Long>> en : consts.subMap(A + 1, A + ln).entrySet()) inner += en.getValue().size();
        StringBuilder fs = new StringBuilder();
        if (ex != null) {
          int k = 0;
          for (long fe : ex) { if (k++ >= 30) break; fs.append(String.format("%X ", fe)); }
        }
        ns++;
        boolean any = g > 0 || exN > 0 || inner > 0;
        if (g > 0) nsG++;
        if (exN > 0) nsO++;
        if (any) nsAny++;
        boolean sj = p[1].equals("sjis");
        if (sj) { nSjis++; if (any) nSjisAny++; } else { nAscii++; if (any) nAsciiAny++; }
        if (!p[3].equals("-")) {
          flagged.append(String.format("    string_kunci @0x%s tag=%s ref_ghidra=%d ref_pola_tepat=%d fungsi=[%s]\n", p[0], p[3], g, exN, fs.toString().trim()));
        }
        pw.println(p[0] + "\t" + p[1] + "\t" + p[2] + "\t" + p[3] + "\t" + g + "\t" + exN + "\t" + inner + "\t" + fs.toString().trim() + "\t" + p[4]);
      }
    }
    S.append("  string_dipindai=").append(ns).append(" (ascii=").append(nAscii).append(" dengan_xref=").append(nAsciiAny)
     .append("; sjis=").append(nSjis).append(" dengan_xref=").append(nSjisAny).append(")")
     .append(" xref_ghidra>0=").append(nsG).append(" xref_pola_tepat>0=").append(nsO).append(" salah_satu=").append(nsAny).append("\n");
    int ghStr = 0, ghStrRef = 0;
    for (Data d : L.getDefinedData(true)) {
      String tn = d.getDataType().getName().toLowerCase();
      if (!tn.contains("string")) continue;
      ghStr++;
      boolean has = false;
      for (Reference r : rm.getReferencesTo(d.getAddress())) { has = true; break; }
      if (has) ghStrRef++;
    }
    S.append("  string_terdefinisi_oleh_Ghidra=").append(ghStr).append(" dengan_xref=").append(ghStrRef).append("\n");
    if (flagged.length() > 0) S.append("  string berkata kunci (alamat saja, teks hanya di berkas terenkripsi):\n").append(flagged);

    // ---- (4) wilayah tak tercakup (tak jadi instruksi / data terdefinisi) ----
    int nReg = 0, nRegProl = 0, nRegJr = 0, prolTot = 0;
    long regBytes = 0, regProlBytes = 0, zeroBytes = 0;
    ArrayList<long[]> big = new ArrayList<>();
    try (PrintWriter pw = new PrintWriter(rawDir + "/gagal_disasm.txt", "UTF-8")) {
      pw.println("awal\tukuran\tprolog_addiu_sp_negatif\tjr_ra\tkata_nol");
      int rs0 = -1;
      for (int off = 0; off <= blob.length; off += 4) {
        boolean cov = true;
        if (off + 4 <= blob.length) {
          CodeUnit cu = L.getCodeUnitContaining(sp.getAddress(base + off));
          cov = cu != null && (cu instanceof Instruction || (cu instanceof Data && ((Data) cu).isDefined()));
        }
        if (!cov && rs0 < 0) rs0 = off;
        if (cov && rs0 >= 0) {
          int pr = 0, jr = 0, zr = 0;
          for (int o = rs0; o < off; o += 4) {
            int w = wordAt(o);
            if ((w & 0xFFFF8000) == 0x27BD8000) pr++;
            if (w == 0x03E00008) jr++;
            if (w == 0) zr++;
          }
          long sz = off - rs0;
          nReg++;
          regBytes += sz;
          zeroBytes += 4L * zr;
          prolTot += pr;
          if (pr > 0) { nRegProl++; regProlBytes += sz; }
          if (jr > 0) nRegJr++;
          big.add(new long[]{base + rs0, sz, pr});
          pw.println(String.format("%08X\t%d\t%d\t%d\t%d", base + rs0, sz, pr, jr, zr));
          rs0 = -1;
        }
      }
    }
    S.append("  wilayah_tak_tercakup: jumlah=").append(nReg).append(" total_byte=").append(regBytes).append(" (").append(100 * regBytes / blob.length).append("% blok)")
     .append(" byte_kata_nol=").append(zeroBytes).append("\n");
    S.append("  wilayah_dengan_prolog_fungsi(addiu sp,sp,-N)=").append(nRegProl).append(" (").append(regProlBytes).append(" byte) kata_prolog_total=").append(prolTot)
     .append(" wilayah_dengan_jr_ra=").append(nRegJr).append("  [MUNGKIN: kode yang tak terdisassemble atau tak jadi fungsi]\n");
    big.sort((x, y) -> Long.compare(y[1], x[1]));
    for (int i = 0; i < Math.min(5, big.size()); i++)
      S.append(String.format("    terbesar #%d @0x%08X ukuran=%d prolog=%d\n", i + 1, big.get(i)[0], big.get(i)[1], big.get(i)[2]));
  }
}
