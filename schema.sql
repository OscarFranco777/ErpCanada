-- ============================================================================
-- ERP CANADÁ - Esquema SQLite Completo
-- Pintura · Fontanería · Drywall
-- ============================================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- ============================================================================
-- 1. CONFIGURACIÓN DE LA EMPRESA
-- ============================================================================
CREATE TABLE company (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    NOT NULL,
    logo_path   TEXT,               -- ruta al archivo del logo
    address     TEXT,
    city        TEXT,
    province    TEXT,               -- código de provincia (ON, QC, BC, AB...)
    postal_code TEXT,
    phone       TEXT,
    email       TEXT,
    tax_number  TEXT,               -- GST/HST Number (ej: 123456789RT0001)
    created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- ============================================================================
-- 2. PROVINCIAS CANADIENSES + Tasas de Impuesto
-- ============================================================================
-- Canadá: cada provincia puede tener GST federal + PST provincial.
-- HST = GST + PST combinados (Atlantic provinces).
-- QST = Quebec reemplaza PST con su propio sistema.
CREATE TABLE provinces (
    code        TEXT PRIMARY KEY,          -- ON, QC, BC, AB, SK, MB, NB, NS, PE, NL, NT, YT, NU
    name        TEXT NOT NULL,
    gst_rate    REAL NOT NULL DEFAULT 0.05,   -- GST federal (5% en todo Canadá)
    pst_rate    REAL NOT NULL DEFAULT 0.0,    -- PST provincial (varía)
    hst_rate    REAL NOT NULL DEFAULT 0.0,    -- HST (0 si la provincia no usa HST)
    qst_rate    REAL NOT NULL DEFAULT 0.0,    -- QST solo Quebec
    -- total_tax_rate = gst_rate + pst_rate + hst_rate + qst_rate
    -- NOTA: donde hay HST, gst_rate y pst_rate deben ser 0 (ya vienen incluidos en hst)
    is_active   INTEGER NOT NULL DEFAULT 1
);

-- Datos iniciales de las 13 provincias/territorios
INSERT INTO provinces (code, name, gst_rate, pst_rate, hst_rate, qst_rate) VALUES
    ('AB', 'Alberta',              0.05, 0.00, 0.00, 0.00),
    ('BC', 'British Columbia',     0.05, 0.07, 0.00, 0.00),
    ('MB', 'Manitoba',             0.05, 0.07, 0.00, 0.00),
    ('NB', 'New Brunswick',        0.00, 0.00, 0.15, 0.00),
    ('NL', 'Newfoundland & Labrador', 0.00, 0.00, 0.15, 0.00),
    ('NS', 'Nova Scotia',          0.00, 0.00, 0.15, 0.00),
    ('NT', 'Northwest Territories', 0.05, 0.00, 0.00, 0.00),
    ('NU', 'Nunavut',              0.05, 0.00, 0.00, 0.00),
    ('ON', 'Ontario',              0.05, 0.00, 0.13, 0.00),
    ('PE', 'Prince Edward Island', 0.00, 0.00, 0.15, 0.00),
    ('QC', 'Quebec',               0.05, 0.00, 0.00, 0.09975),
    ('SK', 'Saskatchewan',         0.05, 0.06, 0.00, 0.00),
    ('YT', 'Yukon',                0.05, 0.00, 0.00, 0.00);

-- ============================================================================
-- 3. CLIENTES (CRM)
-- ============================================================================
CREATE TABLE customers (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    company_name    TEXT,               -- empresa (null si persona física)
    first_name      TEXT    NOT NULL,
    last_name       TEXT    NOT NULL,
    email           TEXT,
    phone           TEXT,
    -- Dirección canadiense
    address_line1   TEXT,
    address_line2   TEXT,
    city            TEXT,
    province_code   TEXT,               -- FK → provinces.code
    postal_code     TEXT,               -- formato canadiense: A1A 1A1
    -- Cuentas por cobrar
    credit_limit    REAL    DEFAULT 0,
    balance         REAL    NOT NULL DEFAULT 0,  -- saldo pendiente (se actualiza con triggers)
    notes           TEXT,
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (province_code) REFERENCES provinces(code)
);

CREATE INDEX idx_customers_postal ON customers(postal_code);
CREATE INDEX idx_customers_name ON customers(last_name, first_name);

-- ============================================================================
-- 4. PROVEEDORES
-- ============================================================================
CREATE TABLE suppliers (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    company_name    TEXT    NOT NULL,
    contact_name    TEXT,
    email           TEXT,
    phone           TEXT,
    address         TEXT,
    city            TEXT,
    province_code   TEXT,
    postal_code     TEXT,
    tax_number      TEXT,               -- BN (Business Number) canadiense
    category        TEXT,               -- 'materials', 'tools', 'services', 'fuel', etc.
    notes           TEXT,
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (province_code) REFERENCES provinces(code)
);

-- ============================================================================
-- 5. CATÁLOGO DE SERVICIOS (Mano de obra - no se agota)
-- ============================================================================
CREATE TABLE services (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    code            TEXT    UNIQUE,      -- código interno (PINT-001, DRY-001, FONT-001)
    name            TEXT    NOT NULL,    -- "Pintura interior", "Reparación de tubería"
    description     TEXT,
    category        TEXT    NOT NULL,    -- 'painting', 'plumbing', 'drywall'
    unit_price      REAL    NOT NULL DEFAULT 0,   -- precio por hora o por job
    unit_type       TEXT    NOT NULL DEFAULT 'hour', -- 'hour', 'sqft', 'job', 'linear_ft'
    gst_taxable     INTEGER NOT NULL DEFAULT 1,   -- ¿cobra GST?
    hst_taxable     INTEGER NOT NULL DEFAULT 1,
    pst_taxable     INTEGER NOT NULL DEFAULT 1,
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- ============================================================================
-- 6. INVENTARIO DE PRODUCTOS (Materiales que se agotan)
-- ============================================================================
CREATE TABLE products (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    sku             TEXT    UNIQUE,       -- código de barras o SKU interno
    name            TEXT    NOT NULL,     -- "Galón de pintura latex", "Tubo PVC 3/4"
    description     TEXT,
    category        TEXT,                 -- 'paint', 'plumbing_parts', 'drywall_material', 'tools', 'other'
    unit_of_measure TEXT    NOT NULL DEFAULT 'unit', -- 'unit', 'gallon', 'ft', 'box', 'kg', 'lb'
    cost_price      REAL    NOT NULL DEFAULT 0,     -- costo de compra
    sell_price      REAL    NOT NULL DEFAULT 0,     -- precio de venta (si se vende material al cliente)
    current_stock   REAL    NOT NULL DEFAULT 0,     -- stock actual
    min_stock       REAL    DEFAULT 0,              -- stock mínimo (alerta)
    gst_taxable     INTEGER NOT NULL DEFAULT 1,
    hst_taxable     INTEGER NOT NULL DEFAULT 1,
    pst_taxable     INTEGER NOT NULL DEFAULT 1,
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_sku ON products(sku);

-- ============================================================================
-- 7. MOVIMIENTOS DE INVENTARIO (historial completo de entradas/salidas)
-- ============================================================================
CREATE TABLE inventory_movements (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id      INTEGER NOT NULL,
    movement_type   TEXT    NOT NULL,    -- 'purchase', 'sale', 'adjustment', 'return', 'waste'
    quantity        REAL    NOT NULL,    -- positivo = entrada, negativo = salida
    unit_cost       REAL,               -- costo unitario al momento del movimiento
    reference_type  TEXT,               -- 'purchase', 'invoice', 'quote', 'manual'
    reference_id    INTEGER,            -- ID del registro referenciado
    notes           TEXT,
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE INDEX idx_inv_movements_product ON inventory_movements(product_id);
CREATE INDEX idx_inv_movements_date ON inventory_movements(created_at);

-- ============================================================================
-- 8. ACTIVOS FIJOS
-- ============================================================================
CREATE TABLE fixed_assets (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    asset_code      TEXT    UNIQUE,      -- código interno del activo
    name            TEXT    NOT NULL,     -- "Andamio torsionado 6ft", "Ford F-150 2022"
    description     TEXT,
    category        TEXT    NOT NULL,     -- 'vehicle', 'equipment', 'tool', 'scaffold', 'safety'
    purchase_date   TEXT,
    purchase_price  REAL,
    current_value   REAL,                 -- valor depreciado actual
    salvage_value   REAL DEFAULT 0,       -- valor de rescate
    useful_life_years INTEGER,            -- vida útil en años
    serial_number   TEXT,
    assigned_to     TEXT,                 -- nombre del empleado o "warehouse"
    status          TEXT    NOT NULL DEFAULT 'active', -- 'active', 'maintenance', 'retired', 'sold'
    notes           TEXT,
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- ============================================================================
-- 9. GASTOS / COMPRAS
-- ============================================================================
CREATE TABLE expenses (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    supplier_id     INTEGER,
    expense_date    TEXT    NOT NULL,
    description     TEXT    NOT NULL,
    category        TEXT    NOT NULL,     -- 'materials', 'fuel', 'tools', 'rent', 'utilities', 'insurance', 'other'
    subtotal        REAL    NOT NULL DEFAULT 0,
    gst_amount      REAL    NOT NULL DEFAULT 0,
    pst_amount      REAL    NOT NULL DEFAULT 0,
    hst_amount      REAL    NOT NULL DEFAULT 0,
    qst_amount      REAL    NOT NULL DEFAULT 0,
    total           REAL    NOT NULL DEFAULT 0,  -- subtotal + todos los impuestos
    tax_deductible  INTEGER NOT NULL DEFAULT 1,  -- ¿deducible de impuestos?
    payment_method  TEXT,                 -- 'cash', 'card', 'transfer', 'cheque'
    receipt_path    TEXT,                 -- ruta a foto/factura escaneada
    notes           TEXT,
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
);

CREATE INDEX idx_expenses_date ON expenses(expense_date);
CREATE INDEX idx_expenses_category ON expenses(category);

-- ============================================================================
-- 10. COTIZACIONES (Quotes)
-- ============================================================================
CREATE TABLE quotes (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    quote_number    TEXT    UNIQUE,       -- QT-0001, QT-0002...
    customer_id     INTEGER NOT NULL,
    quote_date      TEXT    NOT NULL,
    expiry_date     TEXT,                 -- fecha de expiración de la cotización
    status          TEXT    NOT NULL DEFAULT 'draft', -- 'draft', 'sent', 'accepted', 'rejected', 'converted'
    -- Dirección de trabajo (puede ser diferente a la del cliente)
    job_address     TEXT,
    job_city        TEXT,
    job_province    TEXT,
    job_postal_code TEXT,
    -- Desglose
    subtotal        REAL    NOT NULL DEFAULT 0,
    gst_amount      REAL    NOT NULL DEFAULT 0,
    pst_amount      REAL    NOT NULL DEFAULT 0,
    hst_amount      REAL    NOT NULL DEFAULT 0,
    qst_amount      REAL    NOT NULL DEFAULT 0,
    tax_total       REAL    NOT NULL DEFAULT 0,
    total           REAL    NOT NULL DEFAULT 0,
    notes           TEXT,                 -- términos, condiciones
    converted_invoice_id INTEGER,         -- factura生成 si se convirtió
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (converted_invoice_id) REFERENCES invoices(id)
);

CREATE INDEX idx_quotes_customer ON quotes(customer_id);
CREATE INDEX idx_quotes_date ON quotes(quote_date);
CREATE INDEX idx_quotes_status ON quotes(status);

-- ============================================================================
-- 11. LÍNEAS DE COTIZACIÓN
-- ============================================================================
CREATE TABLE quote_items (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    quote_id        INTEGER NOT NULL,
    item_type       TEXT    NOT NULL,     -- 'service' o 'product'
    service_id      INTEGER,             -- FK → services.id (si es servicio)
    product_id      INTEGER,             -- FK → products.id (si es producto)
    description     TEXT    NOT NULL,     -- descripción libre
    quantity        REAL    NOT NULL DEFAULT 1,
    unit_price      REAL    NOT NULL DEFAULT 0,
    discount_pct    REAL    DEFAULT 0,    -- descuento en porcentaje
    line_total      REAL    NOT NULL DEFAULT 0,  -- quantity * unit_price * (1 - discount/100)
    sort_order      INTEGER DEFAULT 0,
    FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE INDEX idx_quote_items_quote ON quote_items(quote_id);

-- ============================================================================
-- 12. FACTURAS (Invoices)
-- ============================================================================
CREATE TABLE invoices (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_number  TEXT    UNIQUE,       -- INV-0001, INV-0002...
    customer_id     INTEGER NOT NULL,
    quote_id        INTEGER,              -- si vino de una cotización
    invoice_date    TEXT    NOT NULL,
    due_date        TEXT,
    status          TEXT    NOT NULL DEFAULT 'draft', -- 'draft', 'sent', 'paid', 'partial', 'overdue', 'cancelled'
    -- Tipo de factura
    is_credit_note  INTEGER NOT NULL DEFAULT 0,  -- 1 = nota de crédito
    credit_note_for INTEGER,             -- ID de factura original si es NC
    -- Dirección de trabajo
    job_address     TEXT,
    job_city        TEXT,
    job_province    TEXT,
    job_postal_code TEXT,
    -- Desglose
    subtotal        REAL    NOT NULL DEFAULT 0,
    gst_amount      REAL    NOT NULL DEFAULT 0,
    pst_amount      REAL    NOT NULL DEFAULT 0,
    hst_amount      REAL    NOT NULL DEFAULT 0,
    qst_amount      REAL    NOT NULL DEFAULT 0,
    tax_total       REAL    NOT NULL DEFAULT 0,
    total           REAL    NOT NULL DEFAULT 0,
    amount_paid     REAL    NOT NULL DEFAULT 0,
    balance_due     REAL    NOT NULL DEFAULT 0,  -- total - amount_paid
    notes           TEXT,
    pdf_path        TEXT,                 -- ruta al PDF generado
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (customer_id) REFERENCES customers(id),
    FOREIGN KEY (quote_id) REFERENCES quotes(id),
    FOREIGN KEY (credit_note_for) REFERENCES invoices(id)
);

CREATE INDEX idx_invoices_customer ON invoices(customer_id);
CREATE INDEX idx_invoices_date ON invoices(invoice_date);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_number ON invoices(invoice_number);

-- ============================================================================
-- 13. LÍNEAS DE FACTURA
-- ============================================================================
CREATE TABLE invoice_items (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id      INTEGER NOT NULL,
    item_type       TEXT    NOT NULL,     -- 'service' o 'product'
    service_id      INTEGER,
    product_id      INTEGER,
    description     TEXT    NOT NULL,
    quantity        REAL    NOT NULL DEFAULT 1,
    unit_price      REAL    NOT NULL DEFAULT 0,
    discount_pct    REAL    DEFAULT 0,
    line_total      REAL    NOT NULL DEFAULT 0,
    sort_order      INTEGER DEFAULT 0,
    FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);

-- ============================================================================
-- 14. PAGOS RECIBIDOS
-- ============================================================================
CREATE TABLE payments (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_id      INTEGER NOT NULL,
    customer_id     INTEGER NOT NULL,
    payment_date    TEXT    NOT NULL,
    amount          REAL    NOT NULL,
    payment_method  TEXT    NOT NULL,     -- 'cash', 'card', 'transfer', 'cheque', 'e-transfer'
    reference_number TEXT,                -- número de cheque, transferencia, etc.
    notes           TEXT,
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (invoice_id) REFERENCES invoices(id),
    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

CREATE INDEX idx_payments_invoice ON payments(invoice_id);
CREATE INDEX idx_payments_customer ON payments(customer_id);
CREATE INDEX idx_payments_date ON payments(payment_date);

-- ============================================================================
-- 15. SECUENCIAS DE NUMERACIÓN
-- ============================================================================
-- Para generar números correlativos: QT-0001, INV-0001, etc.
CREATE TABLE sequences (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT    UNIQUE NOT NULL,  -- 'quote', 'invoice', 'credit_note'
    prefix      TEXT    NOT NULL,         -- 'QT', 'INV', 'NC'
    next_number INTEGER NOT NULL DEFAULT 1,
    padding     INTEGER NOT NULL DEFAULT 4  -- ceros a la izquierda
);

INSERT INTO sequences (name, prefix, next_number, padding) VALUES
    ('quote',        'QT',  1, 4),
    ('invoice',      'INV', 1, 4),
    ('credit_note',  'NC',  1, 4),
    ('expense',      'EXP', 1, 4);

-- ============================================================================
-- 16. CONFIGURACIÓN DE IMPUESTOS POR SERVICIO/PRODUCTO
-- ============================================================================
-- Tabla puente: qué impuestos aplica cada servicio/producto en cada provincia
-- (útil si querés granularidad a nivel provincial, pero por ahora usamos
-- las banderas gst_taxable/pst_taxable/hst_taxable en services y products)

-- ============================================================================
-- VISTAS ÚTILES
-- ============================================================================

-- Vista: Facturas con saldo pendiente
CREATE VIEW v_open_invoices AS
SELECT
    i.id,
    i.invoice_number,
    i.invoice_date,
    i.due_date,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.company_name,
    i.total,
    i.amount_paid,
    i.balance_due,
    i.status,
    CASE
        WHEN i.is_credit_note = 1 THEN 'Credit Note'
        WHEN julianday('now') - julianday(i.due_date) > 0 THEN 'Overdue'
        ELSE 'Current'
    END AS aging_status,
    CAST(julianday('now') - julianday(i.due_date) AS INTEGER) AS days_overdue
FROM invoices i
JOIN customers c ON i.customer_id = c.id
WHERE i.balance_due > 0
  AND i.status != 'cancelled'
  AND i.is_credit_note = 0
ORDER BY i.due_date;

-- Vista: Resumen de impuestos cobrados por provincia
CREATE VIEW v_tax_summary AS
SELECT
    i.job_province AS province_code,
    p.name AS province_name,
    SUM(i.gst_amount) AS total_gst,
    SUM(i.pst_amount) AS total_pst,
    SUM(i.hst_amount) AS total_hst,
    SUM(i.qst_amount) AS total_qst,
    SUM(i.tax_total) AS total_taxes,
    COUNT(*) AS invoice_count
FROM invoices i
LEFT JOIN provinces p ON i.job_province = p.code
WHERE i.status != 'cancelled'
  AND i.is_credit_note = 0
GROUP BY i.job_province;

-- Vista: Valor total del inventario
CREATE VIEW v_inventory_value AS
SELECT
    id,
    sku,
    name,
    category,
    current_stock,
    cost_price,
    (current_stock * cost_price) AS total_value
FROM products
WHERE is_active = 1
ORDER BY total_value DESC;

-- Vista: Estado de cuenta del cliente
CREATE VIEW v_customer_balance AS
SELECT
    c.id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.company_name,
    c.balance,
    COUNT(DISTINCT i.id) FILTER (WHERE i.status != 'cancelled' AND i.is_credit_note = 0) AS total_invoices,
    COUNT(DISTINCT i.id) FILTER (WHERE i.status = 'paid' AND i.is_credit_note = 0) AS paid_invoices,
    COUNT(DISTINCT i.id) FILTER (WHERE i.balance_due > 0 AND i.status != 'cancelled' AND i.is_credit_note = 0) AS open_invoices,
    MIN(i.due_date) FILTER (WHERE i.balance_due > 0 AND i.status != 'cancelled') AS next_due_date
FROM customers c
LEFT JOIN invoices i ON i.customer_id = c.id
WHERE c.is_active = 1
GROUP BY c.id;

-- Vista: Depreciación de activos fijos
CREATE VIEW v_asset_depreciation AS
SELECT
    id,
    asset_code,
    name,
    category,
    purchase_date,
    purchase_price,
    current_value,
    useful_life_years,
    CASE
        WHEN useful_life_years > 0 AND purchase_price > 0 THEN
            ROUND((purchase_price - COALESCE(salvage_value, 0)) / useful_life_years, 2)
        ELSE 0
    END AS annual_depreciation,
    CASE
        WHEN useful_life_years > 0 THEN
            ROUND(((purchase_price - COALESCE(current_value, purchase_price)) /
                   (purchase_price - COALESCE(salvage_value, 0))) * 100, 1)
        ELSE 0
    END AS depreciation_pct
FROM fixed_assets
WHERE status = 'active';

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Trigger: Actualizar saldo del cliente al insertar un pago
CREATE TRIGGER trg_payment_insert
AFTER INSERT ON payments
BEGIN
    UPDATE customers
    SET balance = balance - NEW.amount,
        updated_at = datetime('now')
    WHERE id = NEW.customer_id;

    UPDATE invoices
    SET amount_paid = amount_paid + NEW.amount,
        balance_due = total - (amount_paid + NEW.amount),
        status = CASE
            WHEN (total - (amount_paid + NEW.amount)) <= 0 THEN 'paid'
            WHEN (amount_paid + NEW.amount) > 0 THEN 'partial'
            ELSE status
        END,
        updated_at = datetime('now')
    WHERE id = NEW.invoice_id;
END;

-- Trigger: Generar próximo número de factura
CREATE TRIGGER trg_invoice_number
AFTER INSERT ON invoices
WHEN NEW.invoice_number IS NULL
BEGIN
    UPDATE invoices
    SET invoice_number = (
        SELECT prefix || '-' || printf('%0' || padding || 'd', next_number)
        FROM sequences WHERE name = 'invoice'
    )
    WHERE id = NEW.id;

    UPDATE sequences
    SET next_number = next_number + 1
    WHERE name = 'invoice';
END;

-- Trigger: Generar próximo número de cotización
CREATE TRIGGER trg_quote_number
AFTER INSERT ON quotes
WHEN NEW.quote_number IS NULL
BEGIN
    UPDATE quotes
    SET quote_number = (
        SELECT prefix || '-' || printf('%0' || padding || 'd', next_number)
        FROM sequences WHERE name = 'quote'
    )
    WHERE id = NEW.id;

    UPDATE sequences
    SET next_number = next_number + 1
    WHERE name = 'quote';
END;

-- Trigger: Salida automática de inventario al facturar un producto
CREATE TRIGGER trg_invoice_product_sale
AFTER INSERT ON invoice_items
WHEN NEW.item_type = 'product' AND NEW.product_id IS NOT NULL
BEGIN
    -- Registrar movimiento de salida
    INSERT INTO inventory_movements (product_id, movement_type, quantity, reference_type, reference_id, created_at)
    VALUES (NEW.product_id, 'sale', -NEW.quantity, 'invoice', NEW.invoice_id, datetime('now'));

    -- Actualizar stock
    UPDATE products
    SET current_stock = current_stock - NEW.quantity,
        updated_at = datetime('now')
    WHERE id = NEW.product_id;
END;

-- Trigger: Salida de inventario al convertir cotización en factura
-- (Se maneja en lógica de aplicación, no en trigger, porque quote_items
--  se copian a invoice_items y el trigger anterior se encarga)

-- ============================================================================
-- DATOS DE EJEMPLO (para testing)
-- ============================================================================

-- Empresa por defecto
INSERT INTO company (name, address, city, province, postal_code, phone, email, tax_number)
VALUES ('Your Painting & Drywall Ltd.', '123 Main Street', 'Toronto', 'ON', 'M5V 2T6',
        '(416) 555-0123', 'info@yourcompany.ca', '123456789RT0001');

-- Algunos servicios de ejemplo
INSERT INTO services (code, name, category, unit_price, unit_type) VALUES
    ('PINT-001', 'Interior Painting (per sqft)',     'painting',   2.50, 'sqft'),
    ('PINT-002', 'Exterior Painting (per sqft)',     'painting',   3.00, 'sqft'),
    ('PINT-003', 'Ceiling Painting (per sqft)',      'painting',   2.00, 'sqft'),
    ('DRY-001',  'Drywall Installation (per sqft)',  'drywall',    3.50, 'sqft'),
    ('DRY-002',  'Drywall Repair (per sqft)',        'drywall',    4.00, 'sqft'),
    ('DRY-003',  'Taping & Mudding (per sqft)',      'drywall',    1.50, 'sqft'),
    ('DRY-004',  'Texture Application (per sqft)',   'drywall',    2.00, 'sqft'),
    ('FONT-001', 'Pipe Repair (per hour)',           'plumbing',  95.00, 'hour'),
    ('FONT-002', 'Fixture Installation (per hour)',  'plumbing',  85.00, 'hour'),
    ('FONT-003', 'Drain Cleaning (per hour)',        'plumbing',  90.00, 'hour'),
    ('FONT-004', 'Water Heater Install (per job)',   'plumbing', 350.00, 'job'),
    ('GEN-001',  'Site Preparation (per hour)',      'general',   65.00, 'hour'),
    ('GEN-002',  'Cleanup (per hour)',               'general',   55.00, 'hour');

-- Algunos productos de ejemplo
INSERT INTO products (sku, name, category, unit_of_measure, cost_price, sell_price, current_stock) VALUES
    ('PNT-WHT-1G', 'Interior Latex Paint - White (1 gal)',    'paint',             'gallon', 35.00, 55.00, 20),
    ('PNT-PRM-1G', 'Primer - White (1 gal)',                  'paint',             'gallon', 25.00, 40.00, 10),
    ('DRY-4x8-1/2', 'Drywall Sheet 4x8 1/2"',                'drywall_material',  'unit',   14.00, 22.00, 50),
    ('DRY-4x8-5/8', 'Drywall Sheet 4x8 5/8" (fire rated)',   'drywall_material',  'unit',   18.00, 28.00, 30),
    ('DRY-TAPE',    'Paper Drywall Tape (75ft roll)',         'drywall_material',  'unit',    4.00,  7.00, 40),
    ('DRY-MUD-5KG', 'Pre-mixed Joint Compound (5kg)',         'drywall_material',  'unit',    8.00, 14.00, 25),
    ('FONT-PVC-3/4', 'PVC Pipe 3/4" (10ft)',                 'plumbing_parts',    'unit',    5.00,  9.00, 30),
    ('FONT-ELBOW-3/4', 'PVC Elbow 3/4"',                     'plumbing_parts',    'unit',    1.50,  3.00, 50),
    ('FONT-VALVE',  'Shut-off Valve 3/4"',                    'plumbing_parts',    'unit',   12.00, 20.00, 15),
    ('GEN-TAPE-M',  'Masking Tape 2" (6-pack)',               'other',             'unit',    8.00, 15.00, 10);

-- ============================================================================
-- FIN DEL ESQUEMA
-- ============================================================================
