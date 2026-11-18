import java.io.*;
import java.nio.file.*;
import java.util.*;
import com.unicenta.pos.ticket.*;
import com.unicenta.pos.util.Hashcypher;

public class TicketBridge {
    public static void main(String... rawArgs) throws Exception {
        List<String> args = Arrays.asList(rawArgs);
        String mode = args.get(0);
        String inputBase64 = args.size() > 1 ? args.get(1) : "";

        if ("AUTH".equals(mode)) {
            String pin = args.size() > 1 ? args.get(1) : "";
            String stored = args.size() > 2 ? args.get(2) : "";
            boolean ok = (stored == null || stored.isEmpty() || "NULL".equalsIgnoreCase(stored)) ? true : Hashcypher.authenticate(pin, stored);
            System.out.println(ok ? "OK" : "FAIL");
            return;
        }
        if ("READ".equals(mode)) {
            if (inputBase64.isEmpty() || "EMPTY".equals(inputBase64)) { System.out.println("[]"); return; }
            ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(Base64.getDecoder().decode(inputBase64)));
            TicketInfo ticket = (TicketInfo) ois.readObject();
            ois.close();
            StringBuilder sb = new StringBuilder("[");
            List<TicketLineInfo> lines = ticket.getLines();
            for (int i = 0; i < lines.size(); i++) {
                TicketLineInfo l = lines.get(i);
                if (i > 0) sb.append(",");
                String name = l.getProductName() != null ? l.getProductName().replace("\"", "\\\"") : "";
                String notes = l.getProperty("notes") != null ? l.getProperty("notes").replace("\"", "\\\"") : "";
                String printer = l.getProperty("product.printer") != null ? l.getProperty("product.printer") : "2";
                String sent = l.getProperty("sendstatus") != null ? l.getProperty("sendstatus") : "No";
                sb.append(String.format(Locale.US, "{\"name\":\"%s\",\"qty\":%.2f,\"price\":%.2f,\"total\":%.2f,\"notes\":\"%s\",\"printer\":\"%s\",\"sendstatus\":\"%s\"}", name, l.getMultiply(), l.getPrice(), l.getValue(), notes, printer, sent));
            }
            sb.append("]");
            System.out.println(sb.toString());
        } else if ("MARK_SENT".equals(mode)) {
            if (inputBase64.isEmpty() || "EMPTY".equals(inputBase64)) { System.out.println("EMPTY::[]"); return; }
            ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(Base64.getDecoder().decode(inputBase64)));
            TicketInfo ticket = (TicketInfo) ois.readObject();
            ois.close();
            StringBuilder sb = new StringBuilder("[");
            boolean first = true;
            for (TicketLineInfo l : ticket.getLines()) {
                if (!"Yes".equalsIgnoreCase(l.getProperty("sendstatus"))) {
                    if (!first) sb.append(",");
                    first = false;
                    String name = l.getProductName() != null ? l.getProductName().replace("\"", "\\\"") : "";
                    String notes = l.getProperty("notes") != null ? l.getProperty("notes").replace("\"", "\\\"") : "";
                    String printer = l.getProperty("product.printer") != null ? l.getProperty("product.printer") : "2";
                    sb.append(String.format(Locale.US, "{\"name\":\"%s\",\"qty\":%.2f,\"notes\":\"%s\",\"printer\":\"%s\"}", name, l.getMultiply(), notes, printer));
                    l.setProperty("sendstatus", "Yes");
                }
            }
            sb.append("]");
            ticket.setTaxes(null);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ObjectOutputStream oos = new ObjectOutputStream(baos);
            oos.writeObject(ticket);
            oos.flush(); oos.close();
            System.out.println(Base64.getEncoder().encodeToString(baos.toByteArray()) + "::" + sb.toString());
        }
        else if ("WRITE".equals(mode)) {
            TicketInfo ticket;
            String tplPath = args.size() > 3 && !args.get(3).isEmpty() ? args.get(3) : "plantilla.b64";
            if (inputBase64.isEmpty() || "EMPTY".equals(inputBase64)) {
                String tplB64 = new String(Files.readAllBytes(Paths.get(tplPath)), "UTF-8").trim();
                ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(Base64.getDecoder().decode(tplB64)));
                ticket = (TicketInfo) ois.readObject();
                ois.close();
                ticket.getLines().clear();
                java.lang.reflect.Field fid = TicketInfo.class.getDeclaredField("m_sId");
                fid.setAccessible(true);
                fid.set(ticket, UUID.randomUUID().toString());
            } else {
                ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(Base64.getDecoder().decode(inputBase64)));
                ticket = (TicketInfo) ois.readObject();
                ois.close();
            }
            for (String item : args.get(2).split(";;")) {
                if (item.trim().isEmpty()) continue;
                String[] p = item.split("\\|", -1);
                TaxInfo tax = new TaxInfo(p[4], p[5], p[6], null, null, Double.parseDouble(p[7]), false, p.length > 8 && !p[8].isEmpty() ? Integer.parseInt(p[8]) : 1);
                Properties props = new Properties();
                props.setProperty("product.name", p[1]);
                props.setProperty("product.reference", p.length > 10 && !p[10].isEmpty() ? p[10] : p[0]);
                props.setProperty("product.code", p.length > 11 && !p[11].isEmpty() ? p[11] : p[0]);
                props.setProperty("product.categoryid", p.length > 12 && !p[12].isEmpty() ? p[12] : "000");
                props.setProperty("product.taxcategoryid", p[6]);
                props.setProperty("product.warranty", "false");
                props.setProperty("product.verpatrib", "false");
                props.setProperty("product.com", (p.length > 13 && "1".equals(p)) ? "true" : "false");
                props.setProperty("product.service", "false");
                props.setProperty("product.vprice", "false");
                props.setProperty("product.constant", "false");
                props.setProperty("product.texttip", "");
                props.setProperty("product.memodate", "1900-01-01 00:00:01");
                String dbPrinter = (p.length > 14 && !p[14].isEmpty()) ? p[14].trim() : "";
                boolean isBar = "3".equals(dbPrinter) || (dbPrinter.isEmpty() && p[1].toLowerCase().matches(".*(bebida|cerveza|jugo|gaseosa|coca|agua|licor|coctel|batido).*"));
                String targetPrinter = ("2".equals(dbPrinter) || "3".equals(dbPrinter)) ? dbPrinter : (isBar ? "3" : "2");
                props.setProperty("product.printer", targetPrinter);
                props.setProperty("ticket.updated", "true");
                props.setProperty("sendstatus", "No");
                if (p.length > 9 && !p[9].isEmpty()) { props.setProperty("notes", p[9]); props.setProperty("product.attsetdesc", p[9]); }
                ticket.addLine(new TicketLineInfo(p[0], Double.parseDouble(p[2]), Double.parseDouble(p[3]), tax, props));
            }
            ticket.setTaxes(null);
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ObjectOutputStream oos = new ObjectOutputStream(baos);
            oos.writeObject(ticket);
            oos.flush(); oos.close();
            System.out.println(ticket.getId() + "::" + Base64.getEncoder().encodeToString(baos.toByteArray()));
        }
    }
}
