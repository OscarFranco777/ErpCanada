import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database.dart';

class ERPProvider extends ChangeNotifier {
  late AppDatabase _db;
  bool _initialized = false;
  
  bool get initialized => _initialized;
  AppDatabase get db => _db;
  Database get database => _db.db;
  
  Future<void> init() async {
    _db = await AppDatabase.getInstance();
    _initialized = true;
    notifyListeners();
  }
  
  // ═══════════════════════════════════════════════════════════
  // COMPANY
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> getCompany() async {
    final rows = await _db.db.query('company', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }
  
  Future<void> updateCompany(Map<String, dynamic> data) async {
    await _db.db.update('company', {
      'name': data['name'], 'logo_path': data['logo_path'],
      'address': data['address'], 'address_line2': data['address_line2'],
      'apt_suite': data['apt_suite'],
      'city': data['city'],
      'province': data['province'], 'province_code': data['province_code'],
      'postal_code': data['postal_code'],
      'phone': data['phone'], 'email': data['email'],
      'tax_number': data['tax_number'],
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [data['id']]);
    notifyListeners();
  }
  
  // ═══════════════════════════════════════════════════════════
  // PROVINCES
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getProvinces() async {
    return await _db.db.query('provinces', orderBy: 'name');
  }
  
  Future<Map<String, dynamic>?> getProvince(String code) async {
    final rows = await _db.db.query('provinces', where: 'code = ?', whereArgs: [code]);
    return rows.isNotEmpty ? rows.first : null;
  }
  
  Future<double> getTaxRate(String provinceCode) async {
    final p = await getProvince(provinceCode);
    if (p == null) return 0;
    return (p['gst_rate'] ?? 0) + (p['pst_rate'] ?? 0) + (p['hst_rate'] ?? 0) + (p['qst_rate'] ?? 0);
  }

  Future<void> updateProvinceTaxRates(String code, {
    required double gstRate,
    required double pstRate,
    required double hstRate,
    required double qstRate,
  }) async {
    await _db.db.update('provinces', {
      'gst_rate': gstRate,
      'pst_rate': pstRate,
      'hst_rate': hstRate,
      'qst_rate': qstRate,
    }, where: 'code = ?', whereArgs: [code]);
    notifyListeners();
  }

  Future<void> toggleProvinceActive(String code, bool isActive) async {
    await _db.db.update('provinces', {
      'is_active': isActive ? 1 : 0,
    }, where: 'code = ?', whereArgs: [code]);
    notifyListeners();
  }
  
  // ═══════════════════════════════════════════════════════════
  // CUSTOMERS
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getCustomers({String? search}) async {
    if (search != null && search.isNotEmpty) {
      return await _db.db.rawQuery('''
        SELECT c.*, p.name as province_name FROM customers c
        LEFT JOIN provinces p ON c.province_code = p.code
        WHERE c.is_active = 1 AND (
          c.first_name LIKE ? OR c.last_name LIKE ? OR c.company_name LIKE ?
        )
        ORDER BY c.last_name, c.first_name
      ''', ['%$search%', '%$search%', '%$search%']);
    }
    return await _db.db.rawQuery('''
      SELECT c.*, p.name as province_name FROM customers c
      LEFT JOIN provinces p ON c.province_code = p.code
      WHERE c.is_active = 1
      ORDER BY c.last_name, c.first_name
    ''');
  }
  
  Future<Map<String, dynamic>?> getCustomer(int id) async {
    final rows = await _db.db.rawQuery('''
      SELECT c.*, p.name as province_name FROM customers c
      LEFT JOIN provinces p ON c.province_code = p.code
      WHERE c.id = ?
    ''', [id]);
    return rows.isNotEmpty ? rows.first : null;
  }
  
  Future<int> insertCustomer(Map<String, dynamic> data) async {
    final code = await _db.nextNumber('customer');
    final id = await _db.db.insert('customers', {
      'customer_code': code,
      'company_name': data['company_name'],
      'first_name': data['first_name'],
      'last_name': data['last_name'],
      'id_type': data['id_type'],
      'id_number': data['id_number'],
      'email': data['email'],
      'phone': data['phone'],
      'address_line1': data['address_line1'],
      'address_line2': data['address_line2'],
      'apt_suite': data['apt_suite'],
      'city': data['city'],
      'province_code': data['province_code'],
      'postal_code': data['postal_code'],
      'country': data['country'] ?? 'CA',
      'credit_limit': data['credit_limit'] ?? 0,
      'notes': data['notes'],
    });
    notifyListeners();
    return id;
  }
  
  Future<void> updateCustomer(int id, Map<String, dynamic> data) async {
    await _db.db.update('customers', {
      'company_name': data['company_name'],
      'first_name': data['first_name'],
      'last_name': data['last_name'],
      'id_type': data['id_type'],
      'id_number': data['id_number'],
      'email': data['email'],
      'phone': data['phone'],
      'address_line1': data['address_line1'],
      'address_line2': data['address_line2'],
      'apt_suite': data['apt_suite'],
      'city': data['city'],
      'province_code': data['province_code'],
      'postal_code': data['postal_code'],
      'country': data['country'] ?? 'CA',
      'credit_limit': data['credit_limit'],
      'notes': data['notes'],
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }
  
  Future<bool> deleteCustomer(int id) async {
    // Verificar si tiene cotizaciones, facturas o pagos vinculados
    final quotes = await _db.db.rawQuery(
      'SELECT COUNT(*) as cnt FROM quotes WHERE customer_id = ?', [id]);
    if ((quotes.first['cnt'] as int) > 0) return false;
    final invoices = await _db.db.rawQuery(
      'SELECT COUNT(*) as cnt FROM invoices WHERE customer_id = ?', [id]);
    if ((invoices.first['cnt'] as int) > 0) return false;
    final payments = await _db.db.rawQuery(
      'SELECT COUNT(*) as cnt FROM payments WHERE customer_id = ?', [id]);
    if ((payments.first['cnt'] as int) > 0) return false;
    await _db.db.update('customers', {
      'is_active': 0, 'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return true;
  }
  
  // ═══════════════════════════════════════════════════════════
  // SUPPLIERS
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getSuppliers({String? search}) async {
    if (search != null && search.isNotEmpty) {
      return await _db.db.rawQuery('''
        SELECT s.*, p.name as province_name FROM suppliers s
        LEFT JOIN provinces p ON s.province_code = p.code
        WHERE s.is_active = 1 AND (s.company_name LIKE ? OR s.first_name LIKE ? OR s.last_name LIKE ? OR s.supplier_code LIKE ?)
        ORDER BY s.last_name, s.first_name
      ''', ['%$search%', '%$search%', '%$search%', '%$search%']);
    }
    return await _db.db.rawQuery('''
      SELECT s.*, p.name as province_name FROM suppliers s
      LEFT JOIN provinces p ON s.province_code = p.code
      WHERE s.is_active = 1 ORDER BY s.last_name, s.first_name
    ''');
  }

  Future<Map<String, dynamic>?> getSupplier(int id) async {
    final rows = await _db.db.rawQuery('''
      SELECT s.*, p.name as province_name FROM suppliers s
      LEFT JOIN provinces p ON s.province_code = p.code
      WHERE s.id = ?
    ''', [id]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> insertSupplier(Map<String, dynamic> data) async {
    final code = await _db.nextNumber('supplier');
    final id = await _db.db.insert('suppliers', {
      'supplier_code': code,
      'company_name': data['company_name'],
      'first_name': data['first_name'],
      'last_name': data['last_name'],
      'id_type': data['id_type'],
      'id_number': data['id_number'],
      'email': data['email'],
      'phone': data['phone'],
      'address_line1': data['address_line1'],
      'address_line2': data['address_line2'],
      'apt_suite': data['apt_suite'],
      'city': data['city'],
      'province_code': data['province_code'],
      'postal_code': data['postal_code'],
      'country': data['country'] ?? 'CA',
      'tax_number': data['tax_number'],
      'category': data['category'],
      'notes': data['notes'],
    });
    notifyListeners();
    return id;
  }

  Future<void> updateSupplier(int id, Map<String, dynamic> data) async {
    await _db.db.update('suppliers', {
      'company_name': data['company_name'],
      'first_name': data['first_name'],
      'last_name': data['last_name'],
      'id_type': data['id_type'],
      'id_number': data['id_number'],
      'email': data['email'],
      'phone': data['phone'],
      'address_line1': data['address_line1'],
      'address_line2': data['address_line2'],
      'apt_suite': data['apt_suite'],
      'city': data['city'],
      'province_code': data['province_code'],
      'postal_code': data['postal_code'],
      'country': data['country'] ?? 'CA',
      'tax_number': data['tax_number'],
      'category': data['category'],
      'notes': data['notes'],
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<bool> deleteSupplier(int id) async {
    // Verificar si tiene gastos vinculados
    final expenses = await _db.db.rawQuery(
      'SELECT COUNT(*) as cnt FROM expenses WHERE supplier_id = ?', [id]);
    if ((expenses.first['cnt'] as int) > 0) return false;
    await _db.db.update('suppliers', {
      'is_active': 0, 'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return true;
  }
  
  // ═══════════════════════════════════════════════════════════
  // SERVICES
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getServices({String? category, String? search}) async {
    var where = 'is_active = 1';
    List<dynamic> args = [];
    if (category != null && category.isNotEmpty) { where += ' AND category = ?'; args.add(category); }
    if (search != null && search.isNotEmpty) { where += ' AND (name LIKE ? OR code LIKE ?)'; args.addAll(['%$search%', '%$search%']); }
    return await _db.db.query('services', where: where, orderBy: 'category, name', whereArgs: args);
  }
  
  Future<int> insertService(Map<String, dynamic> data) async {
    final id = await _db.db.insert('services', {
      'code': data['code'], 'name': data['name'], 'description': data['description'],
      'category': data['category'], 'unit_price': data['unit_price'], 'unit_type': data['unit_type'],
    });
    notifyListeners();
    return id;
  }

  Future<void> updateService(int id, Map<String, dynamic> data) async {
    await _db.db.update('services', {
      'code': data['code'], 'name': data['name'], 'description': data['description'],
      'category': data['category'], 'unit_price': data['unit_price'], 'unit_type': data['unit_type'],
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> deleteService(int id) async {
    await _db.db.update('services', {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // SERVICE CATEGORIES
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getServiceCategories() async {
    return await _db.db.query('service_categories', orderBy: 'sort_order, name');
  }

  Future<int?> insertServiceCategory(String name) async {
    // Check if category already exists
    final existing = await _db.db.query('service_categories', where: 'name = ?', whereArgs: [name.trim()]);
    if (existing.isNotEmpty) return null; // duplicate
    final maxRow = await _db.db.rawQuery('SELECT MAX(sort_order) as mx FROM service_categories');
    final nextOrder = ((maxRow.first['mx'] as int?) ?? 0) + 1;
    final id = await _db.db.insert('service_categories', {'name': name.trim(), 'sort_order': nextOrder});
    notifyListeners();
    return id;
  }

  Future<bool> deleteServiceCategory(int id) async {
    final cat = await _db.db.query('service_categories', where: 'id = ?', whereArgs: [id]);
    if (cat.isEmpty) return false;
    final catName = cat.first['name'] as String;
    final services = await _db.db.rawQuery(
      "SELECT COUNT(*) as cnt FROM services WHERE category = ? AND is_active = 1", [catName]);
    if ((services.first['cnt'] as int) > 0) return false;
    await _db.db.delete('service_categories', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return true;
  }
  
  // ═══════════════════════════════════════════════════════════
  // PRODUCT CATEGORIES
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getProductCategories() async {
    return await _db.db.query('product_categories', orderBy: 'sort_order, name');
  }

  Future<int?> insertProductCategory(String name) async {
    // Check if category already exists
    final existing = await _db.db.query('product_categories', where: 'name = ?', whereArgs: [name.trim()]);
    if (existing.isNotEmpty) return null; // duplicate
    final maxRow = await _db.db.rawQuery('SELECT MAX(sort_order) as mx FROM product_categories');
    final nextOrder = ((maxRow.first['mx'] as int?) ?? 0) + 1;
    final id = await _db.db.insert('product_categories', {'name': name.trim(), 'sort_order': nextOrder});
    notifyListeners();
    return id;
  }

  Future<bool> deleteProductCategory(int id) async {
    // Check if any product uses this category
    final cat = await _db.db.query('product_categories', where: 'id = ?', whereArgs: [id]);
    if (cat.isEmpty) return false;
    final catName = cat.first['name'] as String;
    final products = await _db.db.rawQuery(
      'SELECT COUNT(*) as cnt FROM products WHERE category = ?', [catName]);
    if ((products.first['cnt'] as int) > 0) return false;
    await _db.db.delete('product_categories', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  // PRODUCTS
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getProducts({String? category, String? search}) async {
    var where = 'is_active = 1';
    List<dynamic> args = [];
    if (category != null && category.isNotEmpty) { where += ' AND category = ?'; args.add(category); }
    if (search != null && search.isNotEmpty) { where += ' AND (name LIKE ? OR sku LIKE ?)'; args.addAll(['%$search%', '%$search%']); }
    return await _db.db.query('products', where: where, orderBy: 'category, name', whereArgs: args);
  }
  
  Future<int> insertProduct(Map<String, dynamic> data) async {
    final id = await _db.db.insert('products', {
      'sku': data['sku'], 'name': data['name'], 'description': data['description'],
      'category': data['category'], 'unit_of_measure': data['unit_of_measure'],
      'cost_price': data['cost_price'], 'sell_price': data['sell_price'],
      'current_stock': data['current_stock'] ?? 0, 'min_stock': data['min_stock'] ?? 0,
    });
    notifyListeners();
    return id;
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    await _db.db.update('products', {
      'sku': data['sku'], 'name': data['name'], 'description': data['description'],
      'category': data['category'], 'unit_of_measure': data['unit_of_measure'],
      'cost_price': data['cost_price'], 'sell_price': data['sell_price'],
      'current_stock': data['current_stock'] ?? 0, 'min_stock': data['min_stock'] ?? 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<void> deleteProduct(int id) async {
    await _db.db.update('products', {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }
  
  // ═══════════════════════════════════════════════════════════
  // FIXED ASSETS
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getAssets({String? status}) async {
    var where = status != null ? 'status = ?' : null;
    var args = status != null ? [status] : null;
    return await _db.db.query('fixed_assets', where: where, whereArgs: args, orderBy: 'category, name');
  }
  
  // ═══════════════════════════════════════════════════════════
  // EXPENSES
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getExpenses({String? fromDate, String? toDate, String? category}) async {
    var where = '1=1';
    List<dynamic> args = [];
    if (fromDate != null) { where += ' AND e.expense_date >= ?'; args.add(fromDate); }
    if (toDate != null) { where += ' AND e.expense_date <= ?'; args.add(toDate); }
    if (category != null && category.isNotEmpty) { where += ' AND e.category = ?'; args.add(category); }
    return await _db.db.rawQuery('''
      SELECT e.*, s.company_name as supplier_name FROM expenses e
      LEFT JOIN suppliers s ON e.supplier_id = s.id
      WHERE $where ORDER BY e.expense_date DESC
    ''', args);
  }
  
  // ═══════════════════════════════════════════════════════════
  // QUOTES
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getQuotes({String? status}) async {
    var where = status != null ? 'q.status = ?' : null;
    var args = status != null ? [status] : null;
    return await _db.db.rawQuery('''
      SELECT q.*, c.first_name || ' ' || c.last_name AS customer_name, c.company_name
      FROM quotes q JOIN customers c ON q.customer_id = c.id
      ${where != null ? 'WHERE $where' : ''} ORDER BY q.quote_date DESC
    ''', args);
  }
  
  Future<Map<String, dynamic>?> getQuote(int id) async {
    final rows = await _db.db.rawQuery('''
      SELECT q.*, c.first_name || ' ' || c.last_name AS customer_name,
             c.company_name, c.email as customer_email, c.phone as customer_phone
      FROM quotes q JOIN customers c ON q.customer_id = c.id WHERE q.id = ?
    ''', [id]);
    return rows.isNotEmpty ? rows.first : null;
  }
  
  Future<List<Map<String, dynamic>>> getQuoteItems(int quoteId) async {
    return await _db.db.rawQuery('''
      SELECT qi.*, 
        CASE WHEN qi.item_type = 'service' THEN s.name ELSE p.name END as item_name,
        CASE WHEN qi.item_type = 'service' THEN s.code ELSE p.sku END as item_code
      FROM quote_items qi
      LEFT JOIN services s ON qi.service_id = s.id
      LEFT JOIN products p ON qi.product_id = p.id
      WHERE qi.quote_id = ? ORDER BY qi.sort_order
    ''', [quoteId]);
  }
  
  Future<int> insertQuote(Map<String, dynamic> data, List<Map<String, dynamic>> items) async {
    final quoteNum = await _db.nextNumber('quote');
    
    final quoteId = await _db.db.insert('quotes', {
      'quote_number': quoteNum, 'customer_id': data['customer_id'],
      'quote_date': data['quote_date'], 'expiry_date': data['expiry_date'],
      'status': data['status'] ?? 'draft',
      'job_address': data['job_address'], 'job_city': data['job_city'],
      'job_province': data['job_province'], 'job_postal_code': data['job_postal_code'],
      'subtotal': data['subtotal'], 'gst_amount': data['gst_amount'] ?? 0,
      'pst_amount': data['pst_amount'] ?? 0, 'hst_amount': data['hst_amount'] ?? 0,
      'qst_amount': data['qst_amount'] ?? 0, 'tax_total': data['tax_total'] ?? 0,
      'total': data['total'], 'notes': data['notes'],
    });
    
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await _db.db.insert('quote_items', {
        'quote_id': quoteId, 'item_type': item['item_type'],
        'service_id': item['service_id'], 'product_id': item['product_id'],
        'description': item['description'], 'quantity': item['quantity'],
        'unit_price': item['unit_price'], 'discount_pct': item['discount_pct'] ?? 0,
        'line_total': item['line_total'], 'sort_order': i,
      });
    }
    
    notifyListeners();
    return quoteId;
  }
  
  Future<void> updateQuote(int id, Map<String, dynamic> data, List<Map<String, dynamic>> items) async {
    await _db.db.update('quotes', {
      'customer_id': data['customer_id'],
      'quote_date': data['quote_date'],
      'expiry_date': data['expiry_date'],
      'status': data['status'] ?? 'draft',
      'job_address': data['job_address'], 'job_city': data['job_city'],
      'job_province': data['job_province'], 'job_postal_code': data['job_postal_code'],
      'subtotal': data['subtotal'], 'gst_amount': data['gst_amount'] ?? 0,
      'pst_amount': data['pst_amount'] ?? 0, 'hst_amount': data['hst_amount'] ?? 0,
      'qst_amount': data['qst_amount'] ?? 0, 'tax_total': data['tax_total'] ?? 0,
      'total': data['total'], 'notes': data['notes'],
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
    // Delete old items and re-insert
    await _db.db.delete('quote_items', where: 'quote_id = ?', whereArgs: [id]);
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await _db.db.insert('quote_items', {
        'quote_id': id, 'item_type': item['item_type'],
        'service_id': item['service_id'], 'product_id': item['product_id'],
        'description': item['description'], 'quantity': item['quantity'],
        'unit_price': item['unit_price'], 'discount_pct': item['discount_pct'] ?? 0,
        'line_total': item['line_total'], 'sort_order': i,
      });
    }
    notifyListeners();
  }

  Future<bool> deleteQuote(int id) async {
    // Check if converted to invoice
    final q = await _db.db.query('quotes', where: 'id = ?', whereArgs: [id]);
    if (q.isNotEmpty && q.first['converted_invoice_id'] != null) return false;
    await _db.db.delete('quote_items', where: 'quote_id = ?', whereArgs: [id]);
    await _db.db.delete('quotes', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
    return true;
  }

  Future<List<Map<String, dynamic>>> getCustomersList() async {
    return await _db.db.rawQuery(
      "SELECT id, first_name, last_name, company_name, email, phone, address_line1, city, province_code, postal_code FROM customers WHERE is_active = 1 ORDER BY last_name, first_name"
    );
  }

  Future<List<Map<String, dynamic>>> getServicesList() async {
    return await _db.db.rawQuery(
      "SELECT id, code, name, unit_price, unit_type FROM services WHERE is_active = 1 ORDER BY category, name"
    );
  }

  Future<List<Map<String, dynamic>>> getProductsList() async {
    return await _db.db.rawQuery(
      "SELECT id, sku, name, sell_price, current_stock FROM products WHERE is_active = 1 ORDER BY category, name"
    );
  }

  // ═══════════════════════════════════════════════════════════
  // INVOICES
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getInvoices({String? status, bool? creditNotes}) async {
    var where = '1=1';
    List<dynamic> args = [];
    if (status != null) { where += ' AND i.status = ?'; args.add(status); }
    if (creditNotes != null) { where += ' AND i.is_credit_note = ?'; args.add(creditNotes ? 1 : 0); }
    return await _db.db.rawQuery('''
      SELECT i.*, c.first_name || ' ' || c.last_name AS customer_name, c.company_name
      FROM invoices i JOIN customers c ON i.customer_id = c.id
      WHERE $where ORDER BY i.invoice_date DESC
    ''', args);
  }
  
  Future<Map<String, dynamic>?> getInvoice(int id) async {
    final rows = await _db.db.rawQuery('''
      SELECT i.*, c.first_name || ' ' || c.last_name AS customer_name,
             c.company_name, c.email as customer_email, c.phone as customer_phone,
             c.address_line1 as customer_address, c.city as customer_city,
             c.province_code as customer_province, c.postal_code as customer_postal
      FROM invoices i JOIN customers c ON i.customer_id = c.id WHERE i.id = ?
    ''', [id]);
    return rows.isNotEmpty ? rows.first : null;
  }
  
  Future<List<Map<String, dynamic>>> getInvoiceItems(int invoiceId) async {
    return await _db.db.rawQuery('''
      SELECT ii.*,
        CASE WHEN ii.item_type = 'service' THEN s.name ELSE p.name END as item_name,
        CASE WHEN ii.item_type = 'service' THEN s.code ELSE p.sku END as item_code
      FROM invoice_items ii
      LEFT JOIN services s ON ii.service_id = s.id
      LEFT JOIN products p ON ii.product_id = p.id
      WHERE ii.invoice_id = ? ORDER BY ii.sort_order
    ''', [invoiceId]);
  }
  
  Future<int> insertInvoice(Map<String, dynamic> data, List<Map<String, dynamic>> items) async {
    final invoiceNum = await _db.nextNumber('invoice');
    
    final invoiceId = await _db.db.insert('invoices', {
      'invoice_number': invoiceNum, 'customer_id': data['customer_id'],
      'quote_id': data['quote_id'], 'invoice_date': data['invoice_date'],
      'due_date': data['due_date'], 'status': data['status'] ?? 'draft',
      'is_credit_note': data['is_credit_note'] ?? 0, 'credit_note_for': data['credit_note_for'],
      'job_address': data['job_address'], 'job_city': data['job_city'],
      'job_province': data['job_province'], 'job_postal_code': data['job_postal_code'],
      'subtotal': data['subtotal'], 'gst_amount': data['gst_amount'] ?? 0,
      'pst_amount': data['pst_amount'] ?? 0, 'hst_amount': data['hst_amount'] ?? 0,
      'qst_amount': data['qst_amount'] ?? 0, 'tax_total': data['tax_total'] ?? 0,
      'total': data['total'], 'amount_paid': 0, 'balance_due': data['total'],
      'notes': data['notes'],
    });
    
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await _db.db.insert('invoice_items', {
        'invoice_id': invoiceId, 'item_type': item['item_type'],
        'service_id': item['service_id'], 'product_id': item['product_id'],
        'description': item['description'], 'quantity': item['quantity'],
        'unit_price': item['unit_price'], 'discount_pct': item['discount_pct'] ?? 0,
        'line_total': item['line_total'], 'sort_order': i,
      });
      
      // Descuento de inventario
      if (item['item_type'] == 'product' && item['product_id'] != null) {
        await _db.db.insert('inventory_movements', {
          'product_id': item['product_id'], 'movement_type': 'sale',
          'quantity': -(item['quantity'] as num).toDouble(),
          'reference_type': 'invoice', 'reference_id': invoiceId,
        });
        await _db.db.rawUpdate(
          'UPDATE products SET current_stock = current_stock - ?, updated_at = datetime(\'now\') WHERE id = ?',
          [(item['quantity'] as num).toDouble(), item['product_id']],
        );
      }
    }
    
    notifyListeners();
    return invoiceId;
  }
  
  // Convertir cotización a factura
  Future<int?> convertQuoteToInvoice(int quoteId) async {
    final quote = await getQuote(quoteId);
    if (quote == null) return null;
    
    final items = (await getQuoteItems(quoteId)).map((item) => {
      'item_type': item['item_type'], 'service_id': item['service_id'],
      'product_id': item['product_id'], 'description': item['description'],
      'quantity': item['quantity'], 'unit_price': item['unit_price'],
      'discount_pct': item['discount_pct'], 'line_total': item['line_total'],
    }).toList();
    
    final invoiceId = await insertInvoice({
      'customer_id': quote['customer_id'], 'quote_id': quoteId,
      'invoice_date': DateTime.now().toIso8601String().substring(0, 10),
      'due_date': DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10),
      'status': 'sent',
      'job_address': quote['job_address'], 'job_city': quote['job_city'],
      'job_province': quote['job_province'], 'job_postal_code': quote['job_postal_code'],
      'subtotal': quote['subtotal'], 'gst_amount': quote['gst_amount'],
      'pst_amount': quote['pst_amount'], 'hst_amount': quote['hst_amount'],
      'qst_amount': quote['qst_amount'], 'tax_total': quote['tax_total'], 'total': quote['total'],
    }, items);
    
    await _db.db.update('quotes', {
      'status': 'converted', 'converted_invoice_id': invoiceId,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [quoteId]);
    
    return invoiceId;
  }
  
  // ═══════════════════════════════════════════════════════════
  // PAYMENTS
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getPayments({int? invoiceId, int? customerId}) async {
    var where = '1=1';
    List<dynamic> args = [];
    if (invoiceId != null) { where += ' AND p.invoice_id = ?'; args.add(invoiceId); }
    if (customerId != null) { where += ' AND p.customer_id = ?'; args.add(customerId); }
    return await _db.db.rawQuery('''
      SELECT p.*, i.invoice_number FROM payments p
      JOIN invoices i ON p.invoice_id = i.id
      WHERE $where ORDER BY p.payment_date DESC
    ''', args);
  }
  
  Future<void> insertPayment(Map<String, dynamic> data) async {
    await _db.db.insert('payments', {
      'invoice_id': data['invoice_id'], 'customer_id': data['customer_id'],
      'payment_date': data['payment_date'], 'amount': data['amount'],
      'payment_method': data['payment_method'], 'reference_number': data['reference_number'],
      'notes': data['notes'],
    });
    // El trigger en SQLite se encarga de actualizar saldo, pero sqflite
    // no ejecuta triggers de la misma forma. Lo hacemos manualmente:
    await _db.db.rawUpdate(
      'UPDATE customers SET balance = balance - ?, updated_at = datetime(\'now\') WHERE id = ?',
      [data['amount'], data['customer_id']],
    );
    await _db.db.rawUpdate('''
      UPDATE invoices SET
        amount_paid = amount_paid + ?,
        balance_due = total - (amount_paid + ?),
        status = CASE WHEN (total - (amount_paid + ?)) <= 0 THEN 'paid'
                      WHEN (amount_paid + ?) > 0 THEN 'partial'
                      ELSE status END,
        updated_at = datetime('now')
      WHERE id = ?
    ''', [data['amount'], data['amount'], data['amount'], data['amount'], data['invoice_id']]);
    notifyListeners();
  }
  
  // ═══════════════════════════════════════════════════════════
  // REPORTS
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getOpenInvoices() async {
    return await _db.db.rawQuery('''
      SELECT i.*, c.first_name || ' ' || c.last_name AS customer_name,
             c.company_name,
             CAST(julianday('now') - julianday(i.due_date) AS INTEGER) AS days_overdue
      FROM invoices i JOIN customers c ON i.customer_id = c.id
      WHERE i.balance_due > 0 AND i.status != 'cancelled' AND i.is_credit_note = 0
      ORDER BY i.due_date
    ''');
  }
  
  Future<List<Map<String, dynamic>>> getTaxSummary() async {
    return await _db.db.rawQuery('''
      SELECT i.job_province AS province_code, p.name AS province_name,
             SUM(i.gst_amount) AS total_gst, SUM(i.pst_amount) AS total_pst,
             SUM(i.hst_amount) AS total_hst, SUM(i.qst_amount) AS total_qst,
             SUM(i.tax_total) AS total_taxes, COUNT(*) AS invoice_count
      FROM invoices i LEFT JOIN provinces p ON i.job_province = p.code
      WHERE i.status != 'cancelled' AND i.is_credit_note = 0
      GROUP BY i.job_province
    ''');
  }
  
  Future<double> getInventoryValue() async {
    final rows = await _db.db.rawQuery('SELECT SUM(current_stock * cost_price) as total FROM products WHERE is_active = 1');
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }
  
  Future<Map<String, dynamic>> getDashboardStats() async {
    final totalReceivable = await _db.db.rawQuery(
      "SELECT SUM(balance_due) as total FROM invoices WHERE balance_due > 0 AND status != 'cancelled' AND is_credit_note = 0"
    );
    final totalInventory = await getInventoryValue();
    final openQuotes = await _db.db.rawQuery(
      "SELECT COUNT(*) as count FROM quotes WHERE status IN ('draft', 'sent')"
    );
    final overdueInvoices = await _db.db.rawQuery(
      "SELECT COUNT(*) as count FROM invoices WHERE balance_due > 0 AND status != 'cancelled' AND is_credit_note = 0 AND due_date < date('now')"
    );
    final totalCustomers = await _db.db.rawQuery('SELECT COUNT(*) as count FROM customers WHERE is_active = 1');
    final totalAssets = await _db.db.rawQuery('SELECT SUM(current_value) as total FROM fixed_assets WHERE status = \'active\'');
    
    return {
      'total_receivable': (totalReceivable.first['total'] as num?)?.toDouble() ?? 0,
      'total_inventory': totalInventory,
      'open_quotes': openQuotes.first['count'],
      'overdue_invoices': overdueInvoices.first['count'],
      'total_customers': totalCustomers.first['count'],
      'total_assets': (totalAssets.first['total'] as num?)?.toDouble() ?? 0,
    };
  }
}
