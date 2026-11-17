import java.io.*;
import java.nio.file.*;
import java.util.*;
import com.unicenta.pos.ticket.*;

public class TicketBridge {
    public static void main(String... rawArgs) throws Exception {
        List<String> args = Arrays.asList(rawArgs);
        String mode = args.get(0);
        String inputBase64 = args.size() > 1 ? args.get(1) : "";

        if ("READ".equals(mode)) {
            if (inputBase64.isEmpty() || "EMPTY".equals(inputBase64)) { System.out.println("[]"); return; }
            byte[] data = Base64.getDecoder().decode(inputBase64);
            ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(data));
            TicketInfo ticket = (TicketInfo) ois.readObject();
            ois.close();
            StringBuilder sb = new StringBuilder("[");
            List<TicketLineInfo> lines = ticket.getLines();
            for (int i = 0; i < lines.size(); i++) {
                TicketLineInfo l = lines.get(i);
                if (i > 0) sb.append(",");
                String name = l.getProductName() != null ? l.getProductName().replace("\"", "\\\"") : "";
                String notes = l.getProperty("notes") != null ? l.getProperty("notes").replace("\"", "\\\"") : "";
                sb.append(String.format(Locale.US, "{\"name\":\"%s\",\"qty\":%.2f,\"price\":%.2f,\"total\":%.2f,\"notes\":\"%s\"}", name, l.getMultiply(), l.getPrice(), l.getValue(), notes));
            }
            sb.append("]");
            System.out.println(sb.toString());
        } else if ("WRITE".equals(mode)) {
            TicketInfo ticket;
            String tplPath = args.size() > 3 && !args.get(3).isEmpty() ? args.get(3) : "plantilla.b64";
            if (inputBase64.isEmpty() || "EMPTY".equals(inputBase64)) {
                String tplB64 = new String(Files.readAllBytes(Paths.get(tplPath)), "UTF-8").trim();
                ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(Base64.getDecoder().decode(tplB64)));
                ticket = (TicketInfo) ois.readObject();
                ois.close();
                ticket.getLines().clear();
            } else {
                ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(Base64.getDecoder().decode(inputBase64)));
                ticket = (TicketInfo) ois.readObject();
                ois.close();
            }
            for (String item : args.get(2).split(";;")) {
                if (item.trim().isEmpty()) continue;
                String[] p = item.split("\\|", -1);
                TaxInfo tax = new TaxInfo(p, p, p, null, null, Double.parseDouble(p), false, p.length > 8 && !p.isEmpty() ? Integer.parseInt(p) : 1);
                Properties props = new Properties();
                props.setProperty("product.name", p);
                props.setProperty("product.reference", p.length > 10 && !p.isEmpty() ? p : p);
                props.setProperty("product.code", p.length > 11 && !p.isEmpty() ? p : p);
                props.setProperty("product.categoryid", p.length > 12 && !p.isEmpty() ? p : "000");
                props.setProperty("product.taxcategoryid", p);
                props.setProperty("product.warranty", "false");
                props.setProperty("product.verpatrib", "false");
                boolean isCom = p.length > 13 && "1".equals(p);
                props.setProperty("product.com", isCom ? "true" : "false");
                props.setProperty("product.service", "false");
                props.setProperty("product.vprice", "false");
                props.setProperty("product.constant", "false");
                props.setProperty("product.texttip", "");
                props.setProperty("product.memodate", "1900-01-01 00:00:01");
                boolean isBar = p.toLowerCase().matches(".*(bebida|cerveza|jugo|gaseosa|coca|agua|licor|coctel|batido).*");
                props.setProperty("product.printer", isBar ? "3" : "2");
                props.setProperty("ticket.updated", "true");
                props.setProperty("sendstatus", "No");
                if (p.length > 9 && !p.isEmpty()) { props.setProperty("notes", p); props.setProperty("product.attsetdesc", p); }
                ticket.addLine(new TicketLineInfo(p, Double.parseDouble(p), Double.parseDouble(p), tax, props));
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
