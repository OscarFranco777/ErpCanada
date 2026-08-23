import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static AppDatabase? _instance;
  late final Database _db;
  
  AppDatabase._();
  
  static Future<AppDatabase> getInstance() async {
    if (_instance == null) {
      _instance = AppDatabase._();
      await _instance!._init();
    }
    return _instance!;
  }
  
  Database get db => _db;
  
  Future<void> _init() async {
    // Initialize sqflite for desktop
    sqfliteFfiInit();
    
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'erp_canada.db');
    
    _db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, version) async {
          await _createTables(db);
          await _seedData(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute("ALTER TABLE customers ADD COLUMN customer_code TEXT UNIQUE");
            await db.execute("ALTER TABLE customers ADD COLUMN id_type TEXT");
            await db.execute("ALTER TABLE customers ADD COLUMN id_number TEXT");
            await db.execute("INSERT OR IGNORE INTO sequences (name, prefix, next_number, padding) VALUES ('customer', 'CLI', 1, 4)");
          }
          if (oldVersion < 3) {
            await db.execute("ALTER TABLE suppliers ADD COLUMN supplier_code TEXT");
            await db.execute("ALTER TABLE suppliers ADD COLUMN id_type TEXT");
            await db.execute("ALTER TABLE suppliers ADD COLUMN id_number TEXT");
            await db.execute("ALTER TABLE suppliers ADD COLUMN country TEXT DEFAULT 'CA'");
            await db.execute("ALTER TABLE suppliers ADD COLUMN apt_suite TEXT");
            await db.execute("INSERT OR IGNORE INTO sequences (name, prefix, next_number, padding) VALUES ('supplier', 'SUPP', 1, 4)");
          }
          if (oldVersion < 4) {
            await db.execute("ALTER TABLE customers ADD COLUMN apt_suite TEXT");
            await db.execute("ALTER TABLE customers ADD COLUMN country TEXT DEFAULT 'CA'");
          }
          if (oldVersion < 5) {
            await db.execute('''
              CREATE TABLE product_categories (
                id   INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT    NOT NULL UNIQUE,
                sort_order INTEGER DEFAULT 0
              );
            ''');
            // Migrate old English category names to Spanish
            await db.execute("UPDATE products SET category = 'Pintura' WHERE category = 'paint'");
            await db.execute("UPDATE products SET category = 'Drywall' WHERE category = 'drywall_material'");
            await db.execute("UPDATE products SET category = 'Fontanería' WHERE category = 'plumbing_parts'");
            await db.execute("UPDATE products SET category = 'Otros' WHERE category = 'other'");
            await db.execute("INSERT INTO product_categories (name, sort_order) VALUES ('Pintura', 1)");
            await db.execute("INSERT INTO product_categories (name, sort_order) VALUES ('Drywall', 2)");
            await db.execute("INSERT INTO product_categories (name, sort_order) VALUES ('Fontanería', 3)");
            await db.execute("INSERT INTO product_categories (name, sort_order) VALUES ('Otros', 4)");
          }
          if (oldVersion < 6) {
            await db.execute('''
              CREATE TABLE service_categories (
                id   INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT    NOT NULL UNIQUE,
                sort_order INTEGER DEFAULT 0
              );
            ''');
            // Migrate old English category names to Spanish
            await db.execute("UPDATE services SET category = 'Pintura' WHERE category = 'painting'");
            await db.execute("UPDATE services SET category = 'Drywall' WHERE category = 'drywall'");
            await db.execute("UPDATE services SET category = 'Fontanería' WHERE category = 'plumbing'");
            await db.execute("UPDATE services SET category = 'General' WHERE category = 'general'");
            await db.execute("INSERT INTO service_categories (name, sort_order) VALUES ('Pintura', 1)");
            await db.execute("INSERT INTO service_categories (name, sort_order) VALUES ('Drywall', 2)");
            await db.execute("INSERT INTO service_categories (name, sort_order) VALUES ('Fontanería', 3)");
            await db.execute("INSERT INTO service_categories (name, sort_order) VALUES ('General', 4)");
          }
          if (oldVersion < 7) {
            await db.execute("ALTER TABLE company ADD COLUMN address_line2 TEXT");
            await db.execute("ALTER TABLE company ADD COLUMN apt_suite TEXT");
            await db.execute("ALTER TABLE company ADD COLUMN province_code TEXT");
          }
        },
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
      ),
    );
  }
  
  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE company (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    NOT NULL,
        logo_path     TEXT,
        address       TEXT,
        address_line2 TEXT,
        apt_suite     TEXT,
        city          TEXT,
        province      TEXT,
        province_code TEXT,
        postal_code   TEXT,
        phone         TEXT,
        email         TEXT,
        tax_number    TEXT,
        created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at    TEXT    NOT NULL DEFAULT (datetime('now'))
      );
    ''');

    await db.execute('''
      CREATE TABLE provinces (
        code        TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        gst_rate    REAL NOT NULL DEFAULT 0.05,
        pst_rate    REAL NOT NULL DEFAULT 0.0,
        hst_rate    REAL NOT NULL DEFAULT 0.0,
        qst_rate    REAL NOT NULL DEFAULT 0.0,
        is_active   INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_code   TEXT    UNIQUE,
        id_type         TEXT,
        id_number       TEXT,
        company_name    TEXT,
        first_name      TEXT    NOT NULL,
        last_name       TEXT    NOT NULL,
        email           TEXT,
        phone           TEXT,
        address_line1   TEXT,
        address_line2   TEXT,
        apt_suite       TEXT,
        city            TEXT,
        province_code   TEXT,
        postal_code     TEXT,
        country         TEXT    DEFAULT 'CA',
        credit_limit    REAL    DEFAULT 0,
        balance         REAL    NOT NULL DEFAULT 0,
        notes           TEXT,
        is_active       INTEGER NOT NULL DEFAULT 1,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (province_code) REFERENCES provinces(code)
      );
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_code   TEXT    UNIQUE,
        company_name    TEXT    NOT NULL,
        first_name      TEXT,
        last_name       TEXT,
        id_type         TEXT,
        id_number       TEXT,
        email           TEXT,
        phone           TEXT,
        address_line1   TEXT,
        address_line2   TEXT,
        apt_suite       TEXT,
        city            TEXT,
        province_code   TEXT,
        postal_code     TEXT,
        country         TEXT    DEFAULT 'CA',
        tax_number      TEXT,
        category        TEXT,
        notes           TEXT,
        is_active       INTEGER NOT NULL DEFAULT 1,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (province_code) REFERENCES provinces(code)
      );
    ''');

    await db.execute('''
      CREATE TABLE services (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        code            TEXT    UNIQUE,
        name            TEXT    NOT NULL,
        description     TEXT,
        category        TEXT    NOT NULL,
        unit_price      REAL    NOT NULL DEFAULT 0,
        unit_type       TEXT    NOT NULL DEFAULT 'hour',
        gst_taxable     INTEGER NOT NULL DEFAULT 1,
        hst_taxable     INTEGER NOT NULL DEFAULT 1,
        pst_taxable     INTEGER NOT NULL DEFAULT 1,
        is_active       INTEGER NOT NULL DEFAULT 1,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      );
    ''');

    await db.execute('''
      CREATE TABLE products (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        sku             TEXT    UNIQUE,
        name            TEXT    NOT NULL,
        description     TEXT,
        category        TEXT,
        unit_of_measure TEXT    NOT NULL DEFAULT 'unit',
        cost_price      REAL    NOT NULL DEFAULT 0,
        sell_price      REAL    NOT NULL DEFAULT 0,
        current_stock   REAL    NOT NULL DEFAULT 0,
        min_stock       REAL    DEFAULT 0,
        gst_taxable     INTEGER NOT NULL DEFAULT 1,
        hst_taxable     INTEGER NOT NULL DEFAULT 1,
        pst_taxable     INTEGER NOT NULL DEFAULT 1,
        is_active       INTEGER NOT NULL DEFAULT 1,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      );
    ''');

    await db.execute('''
      CREATE TABLE inventory_movements (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id      INTEGER NOT NULL,
        movement_type   TEXT    NOT NULL,
        quantity        REAL    NOT NULL,
        unit_cost       REAL,
        reference_type  TEXT,
        reference_id    INTEGER,
        notes           TEXT,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (product_id) REFERENCES products(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE fixed_assets (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_code      TEXT    UNIQUE,
        name            TEXT    NOT NULL,
        description     TEXT,
        category        TEXT    NOT NULL,
        purchase_date   TEXT,
        purchase_price  REAL,
        current_value   REAL,
        salvage_value   REAL DEFAULT 0,
        useful_life_years INTEGER,
        serial_number   TEXT,
        assigned_to     TEXT,
        status          TEXT    NOT NULL DEFAULT 'active',
        notes           TEXT,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
      );
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id     INTEGER,
        expense_date    TEXT    NOT NULL,
        description     TEXT    NOT NULL,
        category        TEXT    NOT NULL,
        subtotal        REAL    NOT NULL DEFAULT 0,
        gst_amount      REAL    NOT NULL DEFAULT 0,
        pst_amount      REAL    NOT NULL DEFAULT 0,
        hst_amount      REAL    NOT NULL DEFAULT 0,
        qst_amount      REAL    NOT NULL DEFAULT 0,
        total           REAL    NOT NULL DEFAULT 0,
        tax_deductible  INTEGER NOT NULL DEFAULT 1,
        payment_method  TEXT,
        receipt_path    TEXT,
        notes           TEXT,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE quotes (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_number    TEXT    UNIQUE,
        customer_id     INTEGER NOT NULL,
        quote_date      TEXT    NOT NULL,
        expiry_date     TEXT,
        status          TEXT    NOT NULL DEFAULT 'draft',
        job_address     TEXT,
        job_city        TEXT,
        job_province    TEXT,
        job_postal_code TEXT,
        subtotal        REAL    NOT NULL DEFAULT 0,
        gst_amount      REAL    NOT NULL DEFAULT 0,
        pst_amount      REAL    NOT NULL DEFAULT 0,
        hst_amount      REAL    NOT NULL DEFAULT 0,
        qst_amount      REAL    NOT NULL DEFAULT 0,
        tax_total       REAL    NOT NULL DEFAULT 0,
        total           REAL    NOT NULL DEFAULT 0,
        notes           TEXT,
        converted_invoice_id INTEGER,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        FOREIGN KEY (converted_invoice_id) REFERENCES invoices(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE quote_items (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        quote_id        INTEGER NOT NULL,
        item_type       TEXT    NOT NULL,
        service_id      INTEGER,
        product_id      INTEGER,
        description     TEXT    NOT NULL,
        quantity        REAL    NOT NULL DEFAULT 1,
        unit_price      REAL    NOT NULL DEFAULT 0,
        discount_pct    REAL    DEFAULT 0,
        line_total      REAL    NOT NULL DEFAULT 0,
        sort_order      INTEGER DEFAULT 0,
        FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE CASCADE,
        FOREIGN KEY (service_id) REFERENCES services(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number  TEXT    UNIQUE,
        customer_id     INTEGER NOT NULL,
        quote_id        INTEGER,
        invoice_date    TEXT    NOT NULL,
        due_date        TEXT,
        status          TEXT    NOT NULL DEFAULT 'draft',
        is_credit_note  INTEGER NOT NULL DEFAULT 0,
        credit_note_for INTEGER,
        job_address     TEXT,
        job_city        TEXT,
        job_province    TEXT,
        job_postal_code TEXT,
        subtotal        REAL    NOT NULL DEFAULT 0,
        gst_amount      REAL    NOT NULL DEFAULT 0,
        pst_amount      REAL    NOT NULL DEFAULT 0,
        hst_amount      REAL    NOT NULL DEFAULT 0,
        qst_amount      REAL    NOT NULL DEFAULT 0,
        tax_total       REAL    NOT NULL DEFAULT 0,
        total           REAL    NOT NULL DEFAULT 0,
        amount_paid     REAL    NOT NULL DEFAULT 0,
        balance_due     REAL    NOT NULL DEFAULT 0,
        notes           TEXT,
        pdf_path        TEXT,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        FOREIGN KEY (quote_id) REFERENCES quotes(id),
        FOREIGN KEY (credit_note_for) REFERENCES invoices(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id      INTEGER NOT NULL,
        item_type       TEXT    NOT NULL,
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
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id      INTEGER NOT NULL,
        customer_id     INTEGER NOT NULL,
        payment_date    TEXT    NOT NULL,
        amount          REAL    NOT NULL,
        payment_method  TEXT    NOT NULL,
        reference_number TEXT,
        notes           TEXT,
        created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (invoice_id) REFERENCES invoices(id),
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE sequences (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    UNIQUE NOT NULL,
        prefix      TEXT    NOT NULL,
        next_number INTEGER NOT NULL DEFAULT 1,
        padding     INTEGER NOT NULL DEFAULT 4
      );
    ''');

    // Categorías de productos por defecto
    await db.execute('''
      CREATE TABLE product_categories (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT    NOT NULL UNIQUE,
        sort_order INTEGER DEFAULT 0
      );
    ''');
    await db.execute("INSERT INTO product_categories (name, sort_order) VALUES ('Pintura', 1)");
    await db.execute("INSERT INTO product_categories (name, sort_order) VALUES ('Drywall', 2)");
    await db.execute("INSERT INTO product_categories (name, sort_order) VALUES ('Fontanería', 3)");
    await db.execute("INSERT INTO product_categories (name, sort_order) VALUES ('Otros', 4)");

    await db.execute('''
      CREATE TABLE service_categories (
        id   INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT    NOT NULL UNIQUE,
        sort_order INTEGER DEFAULT 0
      );
    ''');
    await db.execute("INSERT INTO service_categories (name, sort_order) VALUES ('Pintura', 1)");
    await db.execute("INSERT INTO service_categories (name, sort_order) VALUES ('Drywall', 2)");
    await db.execute("INSERT INTO service_categories (name, sort_order) VALUES ('Fontanería', 3)");
    await db.execute("INSERT INTO service_categories (name, sort_order) VALUES ('General', 4)");
    // Migrate seed service categories from English to Spanish
    await db.execute("UPDATE services SET category = 'Pintura' WHERE category = 'painting'");
    await db.execute("UPDATE services SET category = 'Drywall' WHERE category = 'drywall'");
    await db.execute("UPDATE services SET category = 'Fontanería' WHERE category = 'plumbing'");
    await db.execute("UPDATE services SET category = 'General' WHERE category = 'general'");

    // Índices
    await db.execute('CREATE INDEX idx_customers_code ON customers(customer_code);');
    await db.execute('CREATE INDEX idx_customers_postal ON customers(postal_code);');
    await db.execute('CREATE INDEX idx_customers_name ON customers(last_name, first_name);');
    await db.execute('CREATE INDEX idx_products_category ON products(category);');
    await db.execute('CREATE INDEX idx_products_sku ON products(sku);');
    await db.execute('CREATE INDEX idx_inv_movements_product ON inventory_movements(product_id);');
    await db.execute('CREATE INDEX idx_inv_movements_date ON inventory_movements(created_at);');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses(expense_date);');
    await db.execute('CREATE INDEX idx_expenses_category ON expenses(category);');
    await db.execute('CREATE INDEX idx_quotes_customer ON quotes(customer_id);');
    await db.execute('CREATE INDEX idx_quotes_date ON quotes(quote_date);');
    await db.execute('CREATE INDEX idx_quotes_status ON quotes(status);');
    await db.execute('CREATE INDEX idx_quote_items_quote ON quote_items(quote_id);');
    await db.execute('CREATE INDEX idx_invoices_customer ON invoices(customer_id);');
    await db.execute('CREATE INDEX idx_invoices_date ON invoices(invoice_date);');
    await db.execute('CREATE INDEX idx_invoices_status ON invoices(status);');
    await db.execute('CREATE INDEX idx_invoices_number ON invoices(invoice_number);');
    await db.execute('CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);');
    await db.execute('CREATE INDEX idx_payments_invoice ON payments(invoice_id);');
    await db.execute('CREATE INDEX idx_payments_customer ON payments(customer_id);');
    await db.execute('CREATE INDEX idx_payments_date ON payments(payment_date);');
  }
  
  Future<void> _seedData(Database db) async {
    // Provincias canadienses
    await db.insert('provinces', {'code': 'AB', 'name': 'Alberta', 'gst_rate': 0.05, 'pst_rate': 0.00, 'hst_rate': 0.00, 'qst_rate': 0.00});
    await db.insert('provinces', {'code': 'BC', 'name': 'British Columbia', 'gst_rate': 0.05, 'pst_rate': 0.07, 'hst_rate': 0.00, 'qst_rate': 0.00});
    await db.insert('provinces', {'code': 'MB', 'name': 'Manitoba', 'gst_rate': 0.05, 'pst_rate': 0.07, 'hst_rate': 0.00, 'qst_rate': 0.00});
    await db.insert('provinces', {'code': 'NB', 'name': 'New Brunswick', 'gst_rate': 0.00, 'pst_rate': 0.00, 'hst_rate': 0.15, 'qst_rate': 0.00});
    await db.insert('provinces', {'code': 'NL', 'name': 'Newfoundland & Labrador', 'gst_rate': 0.00, 'pst_rate': 0.00, 'hst_rate': 0.15, 'qst_rate': 0.00});
    await db.insert('provinces', {'code': 'NS', 'name': 'Nova Scotia', 'gst_rate': 0.00, 'pst_rate': 0.00, 'hst_rate': 0.15, 'qst_rate': 0.00});
    await db.insert('provinces', {'code': 'NT', 'name': 'Northwest Territories', 'gst_rate': 0.05, 'pst_rate': 0.00, 'hst_rate': 0.00, 'qst_rate': 0.00});
    await db.insert('provinces', {'code': 'NU', 'name': 'Nunavut', 'gst_rate': 0.05, 'pst_rate': 0.00, 'hst_rate': 0.00, 'qst_rate': 0.00});
    await db.insert('provinces', {'code': 'ON', 'name': 'Ontario', 'gst_rate': 0.05, 'pst_rate': 0.00, 'hst_rate': 0.13, 'qst_rate': 0.00});
    await db.insert('provinces', {'code': 'PE', 'name': 'Prince Edward Island', 'gst_rate': 0.00, 'pst_rate': 0.00, 'hst_rate': 0.15, 'qst_rate': 0.00});
    await db.insert('provinces', {'code': 'QC', 'name': 'Quebec', 'gst_rate': 0.05, 'pst_rate': 0.00, 'hst_rate': 0.00, 'qst_rate': 0.09975});
    await db.insert('provinces', {'code': 'SK', 'name': 'Saskatchewan', 'gst_rate': 0.05, 'pst_rate': 0.06, 'hst_rate': 0.00, 'qst_rate': 0.00});
    await db.insert('provinces', {'code': 'YT', 'name': 'Yukon', 'gst_rate': 0.05, 'pst_rate': 0.00, 'hst_rate': 0.00, 'qst_rate': 0.00});

    // Secuencias
    await db.insert('sequences', {'name': 'quote', 'prefix': 'QT', 'next_number': 1, 'padding': 4});
    await db.insert('sequences', {'name': 'invoice', 'prefix': 'INV', 'next_number': 1, 'padding': 4});
    await db.insert('sequences', {'name': 'credit_note', 'prefix': 'NC', 'next_number': 1, 'padding': 4});
    await db.insert('sequences', {'name': 'customer', 'prefix': 'CLI', 'next_number': 1, 'padding': 4});
    await db.insert('sequences', {'name': 'supplier', 'prefix': 'SUPP', 'next_number': 1, 'padding': 4});
    await db.insert('sequences', {'name': 'expense', 'prefix': 'EXP', 'next_number': 1, 'padding': 4});

    // Empresa por defecto
    await db.insert('company', {
      'name': 'Your Painting & Drywall Ltd.', 'address': '123 Main Street',
      'city': 'Toronto', 'province': 'ON', 'postal_code': 'M5V 2T6',
      'phone': '(416) 555-0123', 'email': 'info@yourcompany.ca', 'tax_number': '123456789RT0001',
    });

    // Servicios de ejemplo
    await db.insert('services', {'code': 'PINT-001', 'name': 'Interior Painting (per sqft)', 'category': 'Pintura', 'unit_price': 2.50, 'unit_type': 'sqft'});
    await db.insert('services', {'code': 'PINT-002', 'name': 'Exterior Painting (per sqft)', 'category': 'Pintura', 'unit_price': 3.00, 'unit_type': 'sqft'});
    await db.insert('services', {'code': 'PINT-003', 'name': 'Ceiling Painting (per sqft)', 'category': 'Pintura', 'unit_price': 2.00, 'unit_type': 'sqft'});
    await db.insert('services', {'code': 'DRY-001', 'name': 'Drywall Installation (per sqft)', 'category': 'Drywall', 'unit_price': 3.50, 'unit_type': 'sqft'});
    await db.insert('services', {'code': 'DRY-002', 'name': 'Drywall Repair (per sqft)', 'category': 'Drywall', 'unit_price': 4.00, 'unit_type': 'sqft'});
    await db.insert('services', {'code': 'DRY-003', 'name': 'Taping & Mudding (per sqft)', 'category': 'Drywall', 'unit_price': 1.50, 'unit_type': 'sqft'});
    await db.insert('services', {'code': 'DRY-004', 'name': 'Texture Application (per sqft)', 'category': 'Drywall', 'unit_price': 2.00, 'unit_type': 'sqft'});
    await db.insert('services', {'code': 'FONT-001', 'name': 'Pipe Repair (per hour)', 'category': 'Fontanería', 'unit_price': 95.00, 'unit_type': 'hour'});
    await db.insert('services', {'code': 'FONT-002', 'name': 'Fixture Installation (per hour)', 'category': 'Fontanería', 'unit_price': 85.00, 'unit_type': 'hour'});
    await db.insert('services', {'code': 'FONT-003', 'name': 'Drain Cleaning (per hour)', 'category': 'Fontanería', 'unit_price': 90.00, 'unit_type': 'hour'});
    await db.insert('services', {'code': 'FONT-004', 'name': 'Water Heater Install (per job)', 'category': 'Fontanería', 'unit_price': 350.00, 'unit_type': 'job'});
    await db.insert('services', {'code': 'GEN-001', 'name': 'Site Preparation (per hour)', 'category': 'General', 'unit_price': 65.00, 'unit_type': 'hour'});
    await db.insert('services', {'code': 'GEN-002', 'name': 'Cleanup (per hour)', 'category': 'General', 'unit_price': 55.00, 'unit_type': 'hour'});

    // Productos de ejemplo
    await db.insert('products', {'sku': 'PNT-WHT-1G', 'name': 'Interior Latex Paint - White (1 gal)', 'category': 'Pintura', 'unit_of_measure': 'gallon', 'cost_price': 35.00, 'sell_price': 55.00, 'current_stock': 20});
    await db.insert('products', {'sku': 'PNT-PRM-1G', 'name': 'Primer - White (1 gal)', 'category': 'Pintura', 'unit_of_measure': 'gallon', 'cost_price': 25.00, 'sell_price': 40.00, 'current_stock': 10});
    await db.insert('products', {'sku': 'DRY-4x8-1/2', 'name': 'Drywall Sheet 4x8 1/2"', 'category': 'Drywall', 'unit_of_measure': 'unit', 'cost_price': 14.00, 'sell_price': 22.00, 'current_stock': 50});
    await db.insert('products', {'sku': 'DRY-4x8-5/8', 'name': 'Drywall Sheet 4x8 5/8" (fire rated)', 'category': 'Drywall', 'unit_of_measure': 'unit', 'cost_price': 18.00, 'sell_price': 28.00, 'current_stock': 30});
    await db.insert('products', {'sku': 'DRY-TAPE', 'name': 'Paper Drywall Tape (75ft roll)', 'category': 'Drywall', 'unit_of_measure': 'unit', 'cost_price': 4.00, 'sell_price': 7.00, 'current_stock': 40});
    await db.insert('products', {'sku': 'DRY-MUD-5KG', 'name': 'Pre-mixed Joint Compound (5kg)', 'category': 'Drywall', 'unit_of_measure': 'unit', 'cost_price': 8.00, 'sell_price': 14.00, 'current_stock': 25});
    await db.insert('products', {'sku': 'FONT-PVC-3/4', 'name': 'PVC Pipe 3/4" (10ft)', 'category': 'Fontanería', 'unit_of_measure': 'unit', 'cost_price': 5.00, 'sell_price': 9.00, 'current_stock': 30});
    await db.insert('products', {'sku': 'FONT-ELBOW-3/4', 'name': 'PVC Elbow 3/4"', 'category': 'Fontanería', 'unit_of_measure': 'unit', 'cost_price': 1.50, 'sell_price': 3.00, 'current_stock': 50});
    await db.insert('products', {'sku': 'FONT-VALVE', 'name': 'Shut-off Valve 3/4"', 'category': 'Fontanería', 'unit_of_measure': 'unit', 'cost_price': 12.00, 'sell_price': 20.00, 'current_stock': 15});
    await db.insert('products', {'sku': 'GEN-TAPE-M', 'name': 'Masking Tape 2" (6-pack)', 'category': 'Otros', 'unit_of_measure': 'unit', 'cost_price': 8.00, 'sell_price': 15.00, 'current_stock': 10});
  }
  
  // Generar número correlativo
  Future<String> nextNumber(String sequenceName) async {
    final rows = await _db.query('sequences', where: 'name = ?', whereArgs: [sequenceName]);
    if (rows.isEmpty) throw Exception('Sequence "$sequenceName" not found');
    
    final prefix = rows.first['prefix'] as String;
    final num = rows.first['next_number'] as int;
    final padding = rows.first['padding'] as int;
    
    final numberStr = num.toString().padLeft(padding, '0');
    final result = '$prefix-$numberStr';
    
    await _db.update(
      'sequences',
      {'next_number': num + 1},
      where: 'name = ?',
      whereArgs: [sequenceName],
    );
    
    return result;
  }
  
  Future<void> close() async {
    await _db.close();
  }
}
