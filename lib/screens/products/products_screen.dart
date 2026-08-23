import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../providers/erp_provider.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _category = 'all';
  String _search = '';
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final cats = await provider.getProductCategories();
    final cat = _category == 'all' ? null : _category;
    final search = _search.isEmpty ? null : _search;
    final products = await provider.getProducts(category: cat, search: search);
    if (mounted) setState(() { _categories = cats; _products = products; _loading = false; });
  }

  // ─── Category Management ───
  void _showCategoryManager() {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryManagerDialog(
        categories: _categories,
        onRefresh: () { _loadData(); },
      ),
    );
  }

  String? _catKey(String? label) {
    if (label == null) return null;
    for (final c in _categories) {
      if (c['name'] == label) return c['name'] as String;
    }
    return null;
  }

  // ─── Product Form ───
  void _showProductForm({Map<String, dynamic>? product}) {
    final isEdit = product != null;
    final nameCtrl = TextEditingController(text: product?['name'] ?? '');
    final descCtrl = TextEditingController(text: product?['description'] ?? '');
    final costCtrl = TextEditingController(text: product?['cost_price']?.toString() ?? '0');
    final sellCtrl = TextEditingController(text: product?['sell_price']?.toString() ?? '0');
    final stockCtrl = TextEditingController(text: product?['current_stock']?.toString() ?? '0');
    final minStockCtrl = TextEditingController(text: product?['min_stock']?.toString() ?? '0');
    final skuCtrl = TextEditingController(text: product?['sku'] ?? '');
    String category = product?['category'] ?? (_categories.isNotEmpty ? _categories.first['name'] as String : 'Otros');
    String unit = product?['unit_of_measure'] ?? 'unit';

    // Validate category exists in current list
    if (!_categories.any((c) => c['name'] == category)) {
      category = _categories.isNotEmpty ? _categories.first['name'] as String : 'Otros';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Editar Producto' : 'Nuevo Producto'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU', border: OutlineInputBorder(), hintText: 'Auto-generado si vacío')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                    items: _categories.map((c) => DropdownMenuItem(value: c['name'] as String, child: Text(c['name'] as String))).toList(),
                    onChanged: (v) { if (v != null) setDialogState(() => category = v); },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: unit,
                    decoration: const InputDecoration(labelText: 'Unidad', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'unit', child: Text('Unidad')),
                      DropdownMenuItem(value: 'kg', child: Text('Kilogramo')),
                      DropdownMenuItem(value: 'ltr', child: Text('Litro')),
                      DropdownMenuItem(value: 'mtr', child: Text('Metro')),
                      DropdownMenuItem(value: 'box', child: Text('Caja')),
                      DropdownMenuItem(value: 'gal', child: Text('Galón')),
                    ],
                    onChanged: (v) { if (v != null) setDialogState(() => unit = v); },
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Costo (C\$)', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: sellCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio (C\$)', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock Actual', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: minStockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock Mínimo', border: OutlineInputBorder()))),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
                  return;
                }
                final data = {
                  'sku': skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'category': category,
                  'unit_of_measure': unit,
                  'cost_price': double.tryParse(costCtrl.text) ?? 0,
                  'sell_price': double.tryParse(sellCtrl.text) ?? 0,
                  'current_stock': double.tryParse(stockCtrl.text) ?? 0,
                  'min_stock': double.tryParse(minStockCtrl.text) ?? 0,
                };
                final provider = context.read<ERPProvider>();
                if (isEdit) {
                  await provider.updateProduct(product!['id'], data);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto actualizado')));
                } else {
                  await provider.insertProduct(data);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto creado')));
                }
                if (mounted) { Navigator.pop(ctx); _loadData(); }
              },
              child: Text(isEdit ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Estás seguro de eliminar "${product['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<ERPProvider>().deleteProduct(product['id']);
              if (mounted) { Navigator.pop(ctx); _loadData(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto eliminado'))); }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───
          Row(children: [
            Text('Productos', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            // Search bar
            SizedBox(
              width: 260,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o SKU...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); _loadData(); },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (v) { setState(() => _search = v); _loadData(); },
                onChanged: (v) { setState(() => _search = v); _loadData(); },
              ),
            ),
            const SizedBox(width: 12),
            // Category manager button
            IconButton(
              icon: const Icon(Icons.category, size: 20),
              tooltip: 'Gestionar categorías',
              onPressed: _showCategoryManager,
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _showProductForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Producto'),
            ),
          ]),
          const SizedBox(height: 12),
          // ─── Category filter chips ───
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Todos'),
                selected: _category == 'all',
                onSelected: (v) { setState(() => _category = 'all'); _loadData(); },
              ),
              ..._categories.map((c) => FilterChip(
                label: Text(c['name'] as String),
                selected: _category == (c['name'] as String),
                onSelected: (v) { setState(() => _category = c['name'] as String); _loadData(); },
              )),
            ],
          ),
          const SizedBox(height: 12),
          // ─── Table ───
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty ? const Center(child: Text('No hay productos'))
                : DataTable2(
                    columns: const [
                      DataColumn2(label: Text('SKU'), size: ColumnSize.S),
                      DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
                      DataColumn2(label: Text('Categoría'), size: ColumnSize.S),
                      DataColumn2(label: Text('Costo'), size: ColumnSize.S),
                      DataColumn2(label: Text('Precio'), size: ColumnSize.S),
                      DataColumn2(label: Text('Stock'), size: ColumnSize.S),
                      DataColumn2(label: Text(''), size: ColumnSize.M),
                    ],
                    rows: _products.map((p) {
                      final stock = (p['current_stock'] as num).toDouble();
                      final minStock = (p['min_stock'] as num).toDouble();
                      final lowStock = minStock > 0 && stock <= minStock;
                      return DataRow2(cells: [
                        DataCell(Text(p['sku'] ?? '')),
                        DataCell(Text(p['name'])),
                        DataCell(Text(p['category'] ?? '')),
                        DataCell(Text('C\$${(p['cost_price'] as num).toStringAsFixed(2)}')),
                        DataCell(Text('C\$${(p['sell_price'] as num).toStringAsFixed(2)}')),
                        DataCell(Text('${stock.toInt()}', style: TextStyle(color: lowStock ? Colors.red : null, fontWeight: lowStock ? FontWeight.bold : null))),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showProductForm(product: p), tooltip: 'Editar'),
                            IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDelete(p), tooltip: 'Eliminar'),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Category Manager Dialog ───
class _CategoryManagerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final VoidCallback onRefresh;
  const _CategoryManagerDialog({required this.categories, required this.onRefresh});

  @override
  State<_CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<_CategoryManagerDialog> {
  final _newCatCtrl = TextEditingController();
  late List<Map<String, dynamic>> _localCategories;

  @override
  void initState() {
    super.initState();
    _localCategories = List.from(widget.categories);
  }

  @override
  void dispose() {
    _newCatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Categorías de Productos'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add new category
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _newCatCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Nueva categoría...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addCategory(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.add, size: 20),
                onPressed: _addCategory,
                tooltip: 'Agregar categoría',
              ),
            ]),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // Category list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _localCategories.length,
                itemBuilder: (ctx, i) {
                  final cat = _localCategories[i];
                  return ListTile(
                    dense: true,
                    title: Text(cat['name'] as String),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      tooltip: 'Eliminar',
                      onPressed: () => _deleteCategory(cat),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }

  void _addCategory() async {
    final name = _newCatCtrl.text.trim();
    if (name.isEmpty) return;
    final provider = context.read<ERPProvider>();
    try {
      final id = await provider.insertProductCategory(name);
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esa categoría ya existe')));
        return;
      }
      _newCatCtrl.clear();
      final cats = await provider.getProductCategories();
      setState(() => _localCategories
        ..clear()
        ..addAll(cats));
      widget.onRefresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Categoría "$name" creada')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _deleteCategory(Map<String, dynamic> cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar la categoría "${cat['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final provider = context.read<ERPProvider>();
    final ok = await provider.deleteProductCategory(cat['id'] as int);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede eliminar "${cat['name']}" — tiene productos asociados')),
      );
      return;
    }
    final cats = await provider.getProductCategories();
    setState(() => _localCategories
      ..clear()
      ..addAll(cats));
    widget.onRefresh();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Categoría "${cat['name']}" eliminada')));
  }
}
