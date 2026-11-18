const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const configPath = path.join(__dirname, 'config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const pool = mysql.createPool({
    host: config.dbHost || 'localhost',
    port: Number(config.dbPort) || 3316,
    user: config.dbUser || 'uniopos_app',
    password: config.dbPassword || '',
    database: config.dbName || 'uniopos',
    waitForConnections: true,
    connectionLimit: 10
});

const UNICENTA_JAR = config.unicentaJarPath || 'C:\\Program Files\\unicenta-opos\\app\\unicentaopos.jar';
const HELPER_DIR = path.join(__dirname, 'java-helper');
const PLANTILLA_PATH = path.join(HELPER_DIR, 'plantilla.b64');
const CLASSPATH = `${UNICENTA_JAR};${HELPER_DIR}`;

const localJava = path.resolve(__dirname, config.javaPath || 'bin\\jre\\bin\\java.exe');
const JAVA_BIN = fs.existsSync(localJava) ? localJava : 'java';

let colaComandas = [];
let comandaSeq = 1;

function runJavaBridge(args) {
    return execFileSync(JAVA_BIN, ['-cp', CLASSPATH, 'TicketBridge', ...args], {
        encoding: 'utf8', maxBuffer: 1024 * 1024 * 5
    }).trim().split(/\r?\n/).pop().trim();
}

app.get('/api/mesas', async (req, res) => {
    try {
        const [floors] = await pool.query('SELECT ID, NAME FROM floors ORDER BY NAME');
        const [places] = await pool.query(`SELECT p.ID, p.NAME, p.FLOOR, p.X, p.Y, CASE WHEN st.ID IS NOT NULL THEN 1 ELSE 0 END AS ocupada FROM places p LEFT JOIN sharedtickets st ON p.ID = st.ID ORDER BY p.NAME`);
        places.sort((a, b) => a.NAME.localeCompare(b.NAME, 'es', { numeric: true }));
        res.json({ ok: true, floors, places });
    } catch (err) { res.status(500).json({ ok: false, error: err.message }); }
});

app.get('/api/menu', async (req, res) => {
    try {
        const [categories] = await pool.query('SELECT ID, NAME FROM categories ORDER BY NAME');
        const [products] = await pool.query(`
            SELECT p.ID, p.REFERENCE, p.CODE, p.NAME, p.PRICESELL, p.CATEGORY, c.NAME AS CAT_NAME,
                   COALESCE(t.ID, '000') AS TAX_ID, COALESCE(t.NAME, 'Exento') AS TAX_NAME,
                   COALESCE(t.CATEGORY, '000') AS TAX_CAT, COALESCE(t.RATE, 0) AS TAX_RATE,
                   COALESCE(t.RATEORDER, 1) AS TAX_ORDER
            FROM products p INNER JOIN products_cat pc ON p.ID = pc.PRODUCT
            LEFT JOIN categories c ON p.CATEGORY = c.ID LEFT JOIN taxes t ON p.TAXCAT = t.CATEGORY
            WHERE COALESCE(p.ISCOM, 0) = 0
            GROUP BY p.ID ORDER BY p.NAME`);

        const [auxRows] = await pool.query(`
            SELECT pc.PRODUCT AS PARENT_ID, p.ID, p.REFERENCE, p.CODE, p.NAME, p.PRICESELL, p.CATEGORY,
                   COALESCE(t.ID, '000') AS TAX_ID, COALESCE(t.NAME, 'Exento') AS TAX_NAME,
                   COALESCE(t.CATEGORY, '000') AS TAX_CAT, COALESCE(t.RATE, 0) AS TAX_RATE,
                   COALESCE(t.RATEORDER, 1) AS TAX_ORDER
            FROM products_com pc
            INNER JOIN products p ON pc.PRODUCT2 = p.ID
            LEFT JOIN taxes t ON p.TAXCAT = t.CATEGORY
            GROUP BY pc.PRODUCT, p.ID
            ORDER BY p.NAME`);

        const auxiliaries = {};
        for (const row of auxRows) {
            if (!auxiliaries[row.PARENT_ID]) auxiliaries[row.PARENT_ID] = [];
            auxiliaries[row.PARENT_ID].push(row);
        }

        res.json({ ok: true, categories, products, auxiliaries });
    } catch (err) { res.status(500).json({ ok: false, error: err.message }); }
});
app.get('/api/mesa/:id', async (req, res) => {
    try {
        const [rows] = await pool.query('SELECT content FROM sharedtickets WHERE ID = ?', [req.params.id]);
        const raw = rows.length > 0 ? (rows.content || rows.CONTENT) : null;
        if (!raw) return res.json({ ok: true, lines: [], total: 0 });
        const lines = JSON.parse(runJavaBridge(['READ', Buffer.from(raw).toString('base64')]));
        res.json({ ok: true, lines, total: lines.reduce((acc, item) => acc + item.total, 0) });
    } catch (err) { res.status(500).json({ ok: false, error: err.message }); }
});

app.get('/api/comandas', (req, res) => res.json({ ok: true, comandas: colaComandas }));
app.delete('/api/comandas/:id', (req, res) => { colaComandas = colaComandas.filter(c => c.id !== parseInt(req.params.id)); res.json({ ok: true }); });

app.post('/api/pedido', async (req, res) => {
    const { placeId, placeName, waiterId, waiterName, items } = req.body;
    if (!placeId || !items || items.length === 0) return res.status(400).json({ ok: false, error: 'Faltan datos' });
    try {
        const [rows] = await pool.query('SELECT content FROM sharedtickets WHERE ID = ?', [placeId]);
        const raw = rows.length > 0 ? (rows.content || rows.CONTENT) : null;
        const currentBase64 = raw ? Buffer.from(raw).toString('base64') : 'EMPTY';

        const [allTaxes] = await pool.query('SELECT id, name, category, rate, COALESCE(rateorder, 1) AS rateorder FROM taxes ORDER BY rateorder ASC');
        const defaultTax = allTaxes.find(t => Number(t.rate) === 0) || allTaxes || { id: '000', name: 'Exento', category: '000', rate: 0, rateorder: 1 };
        const [prodRows] = await pool.query('SELECT ID, REFERENCE, CODE, CATEGORY, TAXCAT, COALESCE(ISCOM, 0) AS ISCOM FROM products WHERE ID IN (?)', [items.map(i => i.id)]);
        const prodMap = new Map(prodRows.map(p => [p.ID, p]));

        const serializedLines = items.map(it => {
            const cleanName = (it.name || '').replace(/[\|;]/g, ' ');
            const cleanNotes = (it.notes || '').replace(/[\|;]/g, ' ');
            const dbProd = prodMap.get(it.id) || {};
            const tax = allTaxes.find(t => t.category === dbProd.TAXCAT) || defaultTax;
            const isComFlag = (it.isCom || Number(dbProd.ISCOM) === 1) ? '1' : '0';
            return [it.id, cleanName, it.qty, it.price, tax.id, tax.name, tax.category, tax.rate, tax.rateorder, cleanNotes, dbProd.REFERENCE || it.id, dbProd.CODE || it.id, dbProd.CATEGORY || '000', isComFlag].join('|');
        }).join(';;');

        const [ticketId, newBase64] = runJavaBridge(['WRITE', currentBase64, serializedLines, PLANTILLA_PATH]).split('::');
        const newBuffer = Buffer.from(newBase64, 'base64');
        const now = new Date();
        const timeTag = String(now.getHours()).padStart(2,'0') + ':' + String(now.getMinutes()).padStart(2,'0');
        const formattedTableName = `${placeName || 'Mesa'} - ${waiterName || 'Mesero'} (${timeTag})`;

        if (rows.length > 0) {
            await pool.query("UPDATE sharedtickets SET content = ?, appuser = ?, locked = NULL WHERE id = ?", [newBuffer, String(waiterId || '0'), placeId]);
        } else {
            await pool.query("INSERT INTO sharedtickets (id, name, content, appuser, pickupid, locked) VALUES (?, ?, ?, ?, 0, NULL)", [placeId, formattedTableName, newBuffer, String(waiterId || '0')]);
        }
        await pool.query("UPDATE places SET waiter = ?, ticketid = ?, guests = 0, occupied = COALESCE(occupied, NOW()) WHERE id = ?", [waiterName || 'Administrador', ticketId, placeId]);

        const barKeywords = /bebida|cerveza|jugo|gaseosa|coca|agua|licor|coctel|batido|bar/i;
        const barItems = items.filter(i => barKeywords.test(i.name) || barKeywords.test(i.catName || ''));
        const cocinaItems = items.filter(i => !barKeywords.test(i.name) && !barKeywords.test(i.catName || ''));
        const hora = new Date().toLocaleTimeString();

        if (cocinaItems.length > 0) colaComandas.unshift({ id: comandaSeq++, area: 'COCINA', mesa: formattedTableName, mesero: waiterName || 'Móvil', hora, items: cocinaItems });
        if (barItems.length > 0) colaComandas.unshift({ id: comandaSeq++, area: 'BAR', mesa: formattedTableName, mesero: waiterName || 'Móvil', hora, items: barItems });

        res.json({ ok: true, message: 'Pedido enviado' });
    } catch (err) {
        console.error('Error:', err);
        res.status(500).json({ ok: false, error: err.message });
    }
});

const os = require('os');
app.get('/api/info', (req, res) => {
    const nets = os.networkInterfaces();
    let ip = '127.0.0.1';
    for (const name of Object.keys(nets)) {
        for (const net of nets[name]) {
            if (net.family === 'IPv4' && !net.internal) { ip = net.address; break; }
        }
        if (ip !== '127.0.0.1') break;
    }
    res.json({ ok: true, ip, port: Number(config.port) || 5000, url: `http://${ip}:${Number(config.port) || 5000}` });
});
app.get('/api/meseros', async (req, res) => {
    try {
        const [rows] = await pool.query("SELECT id, name, (apppassword IS NOT NULL AND apppassword <> '') AS hasPin FROM people WHERE visible = 1 ORDER BY name");
        res.json({ ok: true, meseros: rows });
    } catch (e) { res.status(500).json({ ok: false, error: e.message }); }
});
app.post('/api/auth', async (req, res) => {
    try {
        const { waiterId, pin } = req.body;
        const [rows] = await pool.query("SELECT id, name, apppassword FROM people WHERE id = ? AND visible = 1", [waiterId]);
        if (!rows.length) return res.status(404).json({ ok: false, error: 'Mesero no encontrado' });
        const stored = rows[0].apppassword || 'NULL';
        const authRes = runJavaBridge(['AUTH', String(pin || ''), stored]);
        if (authRes === 'OK') return res.json({ ok: true, waiter: { id: rows[0].id, name: rows[0].name } });
        res.status(401).json({ ok: false, error: 'PIN incorrecto' });
    } catch (e) { res.status(500).json({ ok: false, error: e.message }); }
});
const PORT = Number(config.port) || 5000;
app.listen(PORT, '0.0.0.0', () => console.log(`PUENTE WEB v2.0 ACTIVO -> Puerto ${PORT}`));

