import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/erp_provider.dart';

class QuoteFormScreen extends StatefulWidget {
  final Map<String, dynamic>? quote;
  const QuoteFormScreen({super.key, this.quote});

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends State<QuoteFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabCtrl;

  // Customer
  Map<String, dynamic>? _selectedCustomer;

  // Dates
  late TextEditingController _quoteDate;
  late TextEditingController _expiryDate;

  // Job address
  late TextEditingController _jobAddress;
  late TextEditingController _jobCity;
  String? _jobProvince;
  late TextEditingController _jobPostalCode;

  // Notes
  late TextEditingController _notes;

  // Items
  List<_QuoteLine> _items = [];

  // Province list
  List<Map<String, dynamic>> _provinces = [];

  // Tax rates
  double _gstRate = 0, _pstRate = 0, _hstRate = 0, _qstRate = 0;

  // Dropdown lists
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _products = [];

  bool get isEditing => widget.quote != null;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final q = widget.quote;
    _quoteDate = TextEditingController(text: q?['quote_date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    _expiryDate = TextEditingController(text: q?['expiry_date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30))));
    _jobAddress = TextEditingController(text: q?['job_address'] ?? '');
    _jobCity = TextEditingController(text: q?['job_city'] ?? '');
    _jobProvince = q?['job_province'];
    _jobPostalCode = TextEditingController(text: q?['job_postal_code'] ?? '');
    _notes = TextEditingController(text: q?['notes'] ?? '');
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final customers = await provider.getCustomersList();
    final services = await provider.getServicesList();
    final products = await provider.getProductsList();
    final provinces = await provider.getProvinces();

    setState(() {
      _customers = customers;
      _services = services;
      _products = products;
      _provinces = provinces;
    });

    // If editing, load existing items and customer
    if (isEditing) {
      final items = await provider.getQuoteItems(widget.quote!['id']);
      final cust = customers.where((c) => c['id'] == widget.quote!['customer_id']).toList();
      setState(() {
        _selectedCustomer = cust.isNotEmpty ? cust.first : null;
        _items = items.map((i) => _QuoteLine(
          itemType: i['item_type'],
          serviceId: i['service_id'],
          productId: i['product_id'],
          description: i['description'],
          quantity: (i['quantity'] as num).toDouble(),
          unitPrice: (i['unit_price'] as num).toDouble(),
          discountPct: (i['discount_pct'] as num?)?.toDouble() ?? 0,
        )).toList();
      });
    }
  }

  void _updateTaxRates() {
    if (_jobProvince == null) return;
    final p = _provinces.where((pp) => pp['code'] == _jobProvince).toList();
    if (p.isEmpty) return;
    setState(() {
      _gstRate = (p.first['gst_rate'] as num).toDouble();
      _pstRate = (p.first['pst_rate'] as num).toDouble();
      _hstRate = (p.first['hst_rate'] as num).toDouble();
      _qstRate = (p.first['qst_rate'] as num).toDouble();
    });
  }

  double get _subtotal => _items.fold(0, (sum, i) => sum + i.lineTotal);
  double get _gst => _subtotal * _gstRate;
  double get _pst => _subtotal * _pstRate;
  double get _hst => _subtotal * _hstRate;
  double get _qst => _subtotal * _qstRate;
  double get _taxTotal => _gst + _pst + _hst + _qst;
  double get _total => _subtotal + _taxTotal;

  void _addItem() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => _AddItemSheet(
          services: _services,
          products: _products,
          scrollCtrl: ctrl,
          onAdd: (item) {
            setState(() => _items.add(item));
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná un cliente'), backgroundColor: Colors.orange));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregá al menos un ítem'), backgroundColor: Colors.orange));
      return;
    }

    final provider = context.read<ERPProvider>();
    final data = {
      'customer_id': _selectedCustomer!['id'],
      'quote_date': _quoteDate.text.trim(),
      'expiry_date': _expiryDate.text.trim().isEmpty ? null : _expiryDate.text.trim(),
      'status': isEditing ? (widget.quote!['status'] ?? 'draft') : 'draft',
      'job_address': _jobAddress.text.trim().isEmpty ? null : _jobAddress.text.trim(),
      'job_city': _jobCity.text.trim().isEmpty ? null : _jobCity.text.trim(),
      'job_province': _jobProvince,
      'job_postal_code': _jobPostalCode.text.trim().isEmpty ? null : _jobPostalCode.text.trim().toUpperCase(),
      'subtotal': _subtotal,
      'gst_amount': _gst, 'pst_amount': _pst, 'hst_amount': _hst, 'qst_amount': _qst,
      'tax_total': _taxTotal, 'total': _total,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };

    final itemsData = _items.map((i) => {
      'item_type': i.itemType,
      'service_id': i.serviceId,
      'product_id': i.productId,
      'description': i.description,
      'quantity': i.quantity,
      'unit_price': i.unitPrice,
      'discount_pct': i.discountPct,
      'line_total': i.lineTotal,
    }).toList();

    if (isEditing) {
      await provider.updateQuote(widget.quote!['id'], data, itemsData);
    } else {
      await provider.insertQuote(data, itemsData);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _quoteDate.dispose(); _expiryDate.dispose();
    _jobAddress.dispose(); _jobCity.dispose(); _jobPostalCode.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEditing ? 'Editar Cotización' : 'Nueva Cotización',
                  style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabCtrl,
                  tabs: const [
                    Tab(icon: Icon(Icons.info_outline), text: 'Información'),
                    Tab(icon: Icon(Icons.list_alt), text: 'Ítems'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // ═══ TAB INFO ═══
                      ListView(
                        children: [
                          // Customer selector
                          _buildCustomerDropdown(),
                          const SizedBox(height: 12),
                          // Dates
                          Row(children: [
                            Expanded(child: _buildDateField('Fecha Cotización', _quoteDate)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildDateField('Fecha Vencimiento', _expiryDate)),
                          ]),
                          const SizedBox(height: 16),
                          Text('Dirección del Trabajo', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _jobAddress,
                            decoration: InputDecoration(
                              labelText: 'Dirección',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.content_copy, size: 18),
                                tooltip: 'Copiar dirección del cliente',
                                onPressed: _selectedCustomer != null ? () {
                                  setState(() {
                                    _jobAddress.text = _selectedCustomer!['address_line1'] ?? '';
                                    _jobCity.text = _selectedCustomer!['city'] ?? '';
                                    _jobProvince = _selectedCustomer!['province_code'];
                                    _jobPostalCode.text = _selectedCustomer!['postal_code'] ?? '';
                                  });
                                  _updateTaxRates();
                                } : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: TextFormField(controller: _jobCity, decoration: const InputDecoration(labelText: 'Ciudad'))),
                            const SizedBox(width: 8),
                            Expanded(child: DropdownButtonFormField<String>(
                              value: _jobProvince,
                              isDense: true,
                              decoration: const InputDecoration(labelText: 'Provincia'),
                              items: _provinces.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(
                                value: p['code'] as String,
                                child: Tooltip(message: '${p['code']} - ${p['name']}', child: Text(p['code'] as String)),
                              )).toList(),
                              onChanged: (v) { setState(() => _jobProvince = v); _updateTaxRates(); },
                            )),
                            const SizedBox(width: 8),
                            Expanded(child: TextFormField(controller: _jobPostalCode, decoration: const InputDecoration(labelText: 'Código Postal'))),
                          ]),
                          const SizedBox(height: 12),
                          TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notas / Observaciones'), maxLines: 3),
                        ],
                      ),
                      // ═══ TAB ITEMS ═══
                      Column(
                        children: [
                          // Add item buttons
                          Row(children: [
                            TextButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Agregar Ítem'),
                            ),
                            const Spacer(),
                            Text('Subtotal: C\$${_subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 4),
                          // Items table header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Row(children: [
                              Expanded(flex: 3, child: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Expanded(flex: 1, child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text('P. Unit.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                              Expanded(flex: 1, child: Text('Dto%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                              SizedBox(width: 36),
                            ]),
                          ),
                          // Items list
                          Expanded(
                            child: _items.isEmpty
                                ? const Center(child: Text('No hay ítems. Presioná "Agregar Ítem".'))
                                : ListView.builder(
                                    itemCount: _items.length,
                                    itemBuilder: (_, i) {
                                      final item = _items[i];
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                        ),
                                        child: Row(children: [
                                          Expanded(flex: 3, child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.description, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                              Text('${item.itemType == 'service' ? 'Servicio' : 'Producto'}',
                                                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                            ],
                                          )),
                                          Expanded(flex: 1, child: Text('${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)}',
                                            textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                                          Expanded(flex: 2, child: Text('C\$${item.unitPrice.toStringAsFixed(2)}',
                                            textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                                          Expanded(flex: 1, child: Text('${item.discountPct.toStringAsFixed(0)}%',
                                            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: item.discountPct > 0 ? Colors.orange[700] : null))),
                                          Expanded(flex: 2, child: Text('C\$${item.lineTotal.toStringAsFixed(2)}',
                                            textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                                          SizedBox(
                                            width: 36,
                                            child: IconButton(
                                              icon: Icon(Icons.close, size: 16, color: Colors.red[300]),
                                              padding: EdgeInsets.zero,
                                              onPressed: () => setState(() => _items.removeAt(i)),
                                            ),
                                          ),
                                        ]),
                                      );
                                    },
                                  ),
                          ),
                          const Divider(),
                          // Tax summary
                          _buildTaxRow('GST (5%)', _gst),
                          _buildTaxRow('PST (0%)', _pst),
                          _buildTaxRow('HST (0%)', _hst),
                          _buildTaxRow('QST (0%)', _qst),
                          const Divider(),
                          Row(children: [
                            const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            Text('C\$${_total.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18,
                                color: Theme.of(context).colorScheme.primary)),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _save, child: const Text('Guardar')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDropdown() {
    return DropdownButtonFormField<Map<String, dynamic>>(
      value: _selectedCustomer,
      decoration: const InputDecoration(labelText: 'Cliente *', prefixIcon: Icon(Icons.person)),
      items: _customers.map<DropdownMenuItem<Map<String, dynamic>>>((c) {
        final name = '${c['first_name']} ${c['last_name']}';
        return DropdownMenuItem(
          value: c,
          child: Text('${c['company_name'] != null && c['company_name'].toString().isNotEmpty ? c['company_name'] : name}'),
        );
      }).toList(),
      onChanged: (v) {
        setState(() {
          _selectedCustomer = v;
          // Auto-fill job address from customer
          if (v != null && _jobAddress.text.isEmpty) {
            _jobAddress.text = v['address_line1'] ?? '';
            _jobCity.text = v['city'] ?? '';
            _jobProvince = v['province_code'];
            _jobPostalCode.text = v['postal_code'] ?? '';
            _updateTaxRates();
          }
        });
      },
    );
  }

  Widget _buildDateField(String label, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today, size: 18),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(ctrl.text) ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) ctrl.text = DateFormat('yyyy-MM-dd').format(date);
      },
    );
  }

  Widget _buildTaxRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const Spacer(),
        Text('C\$${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Add Item Sheet
// ═══════════════════════════════════════════════════════════

class _AddItemSheet extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> products;
  final ScrollController scrollCtrl;
  final Function(_QuoteLine) onAdd;

  const _AddItemSheet({
    required this.services, required this.products,
    required this.scrollCtrl, required this.onAdd,
  });

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  String _type = 'service';
  Map<String, dynamic>? _selected;
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _priceCtrl.text = '0.00';
  }

  List<Map<String, dynamic>> get _items => _type == 'service' ? widget.services : widget.products;

  void _onItemChanged(Map<String, dynamic>? item) {
    if (item == null) return;
    setState(() {
      _selected = item;
      _descCtrl.text = item['name'] ?? '';
      _priceCtrl.text = _type == 'service'
          ? (item['unit_price'] as num).toStringAsFixed(2)
          : (item['sell_price'] as num).toStringAsFixed(2);
    });
  }

  void _confirm() {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá una descripción'), backgroundColor: Colors.orange));
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    if (qty <= 0 || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cantidad y precio inválidos'), backgroundColor: Colors.orange));
      return;
    }
    widget.onAdd(_QuoteLine(
      itemType: _type,
      serviceId: _type == 'service' && _selected != null ? _selected!['id'] as int? : null,
      productId: _type == 'product' && _selected != null ? _selected!['id'] as int? : null,
      description: _descCtrl.text.trim(),
      quantity: qty,
      unitPrice: price,
      discountPct: double.tryParse(_discountCtrl.text) ?? 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Agregar Ítem', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          // Type toggle
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'service', label: Text('Servicio')),
              ButtonSegment(value: 'product', label: Text('Producto')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() { _type = s.first; _selected = null; }),
          ),
          const SizedBox(height: 12),
          // Item selector
          DropdownButtonFormField<Map<String, dynamic>>(
            value: _selected,
            decoration: InputDecoration(
              labelText: _type == 'service' ? 'Seleccionar Servicio' : 'Seleccionar Producto',
              prefixIcon: Icon(_type == 'service' ? Icons.build : Icons.inventory_2),
            ),
            items: _items.map<DropdownMenuItem<Map<String, dynamic>>>((i) => DropdownMenuItem(
              value: i,
              child: Text('${i['name']} - C\$${(_type == 'service' ? i['unit_price'] : i['sell_price']).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: _onItemChanged,
          ),
          const SizedBox(height: 12),
          // Description
          TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
          const SizedBox(height: 12),
          // Qty, Price, Discount
          Row(children: [
            Expanded(child: TextFormField(
              controller: _qtyCtrl,
              decoration: const InputDecoration(labelText: 'Cantidad'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
            )),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(labelText: 'Precio Unitario', prefixText: 'C\$ '),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
            )),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(
              controller: _discountCtrl,
              decoration: const InputDecoration(labelText: 'Descuento %'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
            )),
          ]),
          const Spacer(),
          // Total preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Text('Subtotal línea:'),
              const Spacer(),
              Text(
                'C\$${_calcLine().toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                  color: Theme.of(context).colorScheme.primary),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              const SizedBox(width: 8),
              FilledButton.icon(onPressed: _confirm, icon: const Icon(Icons.check), label: const Text('Agregar')),
            ],
          ),
        ],
      ),
    );
  }

  double _calcLine() {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final disc = double.tryParse(_discountCtrl.text) ?? 0;
    return qty * price * (1 - disc / 100);
  }
}

// ═══════════════════════════════════════════════════════════
//  Quote line model
// ═══════════════════════════════════════════════════════════

class _QuoteLine {
  final String itemType;
  final int? serviceId;
  final int? productId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double discountPct;

  _QuoteLine({
    required this.itemType,
    this.serviceId,
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.discountPct = 0,
  });

  double get lineTotal => quantity * unitPrice * (1 - discountPct / 100);
}
