import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../providers/erp_provider.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _category = 'all';
  String _search = '';
  List<Map<String, dynamic>> _services = [];
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
    final cats = await provider.getServiceCategories();
    final cat = _category == 'all' ? null : _category;
    final search = _search.isEmpty ? null : _search;
    final services = await provider.getServices(category: cat, search: search);
    if (mounted) setState(() { _categories = cats; _services = services; _loading = false; });
  }

  // ─── Category Management ───
  void _showCategoryManager() {
    showDialog(
      context: context,
      builder: (ctx) => _ServiceCategoryManagerDialog(
        categories: _categories,
        onRefresh: () { _loadData(); },
      ),
    );
  }

  // ─── Service Form ───
  void _showServiceForm({Map<String, dynamic>? service}) {
    final isEdit = service != null;
    final nameCtrl = TextEditingController(text: service?['name'] ?? '');
    final descCtrl = TextEditingController(text: service?['description'] ?? '');
    final priceCtrl = TextEditingController(text: service?['unit_price']?.toString() ?? '0');
    final codeCtrl = TextEditingController(text: service?['code'] ?? '');
    String category = service?['category'] ?? (_categories.isNotEmpty ? _categories.first['name'] as String : 'General');
    String unit = service?['unit_type'] ?? 'hour';

    if (!_categories.any((c) => c['name'] == category)) {
      category = _categories.isNotEmpty ? _categories.first['name'] as String : 'General';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Editar Servicio' : 'Nuevo Servicio'),
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
                  TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder(), hintText: 'Auto-generado si vacío')),
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
                      DropdownMenuItem(value: 'hour', child: Text('Hora')),
                      DropdownMenuItem(value: 'sqft', child: Text('Pie²')),
                      DropdownMenuItem(value: 'job', child: Text('Trabajo')),
                      DropdownMenuItem(value: 'unit', child: Text('Unidad')),
                      DropdownMenuItem(value: 'day', child: Text('Día')),
                    ],
                    onChanged: (v) { if (v != null) setDialogState(() => unit = v); },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio (C\$)', border: OutlineInputBorder())),
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
                  'code': codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'category': category,
                  'unit_type': unit,
                  'unit_price': double.tryParse(priceCtrl.text) ?? 0,
                };
                final provider = context.read<ERPProvider>();
                if (isEdit) {
                  await provider.updateService(service!['id'], data);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicio actualizado')));
                } else {
                  await provider.insertService(data);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicio creado')));
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

  void _confirmDelete(Map<String, dynamic> service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Servicio'),
        content: Text('¿Estás seguro de eliminar "${service['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<ERPProvider>().deleteService(service['id']);
              if (mounted) { Navigator.pop(ctx); _loadData(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicio eliminado'))); }
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
            Text('Servicios', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            // Search bar
            SizedBox(
              width: 260,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o código...',
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
              onPressed: () => _showServiceForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Servicio'),
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
                : _services.isEmpty ? const Center(child: Text('No hay servicios'))
                : DataTable2(
                    columns: const [
                      DataColumn2(label: Text('Código'), size: ColumnSize.S),
                      DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
                      DataColumn2(label: Text('Categoría'), size: ColumnSize.S),
                      DataColumn2(label: Text('Precio'), size: ColumnSize.S),
                      DataColumn2(label: Text('Unidad'), size: ColumnSize.S),
                      DataColumn2(label: Text(''), size: ColumnSize.M),
                    ],
                    rows: _services.map((s) => DataRow2(cells: [
                      DataCell(Text(s['code'] ?? '')),
                      DataCell(Text(s['name'])),
                      DataCell(Text(s['category'] ?? '')),
                      DataCell(Text('C\$${(s['unit_price'] as num).toStringAsFixed(2)}')),
                      DataCell(Text(s['unit_type'])),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showServiceForm(service: s), tooltip: 'Editar'),
                          IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _confirmDelete(s), tooltip: 'Eliminar'),
                        ],
                      )),
                    ])).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Service Category Manager Dialog ───
class _ServiceCategoryManagerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final VoidCallback onRefresh;
  const _ServiceCategoryManagerDialog({required this.categories, required this.onRefresh});

  @override
  State<_ServiceCategoryManagerDialog> createState() => _ServiceCategoryManagerDialogState();
}

class _ServiceCategoryManagerDialogState extends State<_ServiceCategoryManagerDialog> {
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
      title: const Text('Categorías de Servicios'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
      final id = await provider.insertServiceCategory(name);
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esa categoría ya existe')));
        return;
      }
      _newCatCtrl.clear();
      final cats = await provider.getServiceCategories();
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
    final ok = await provider.deleteServiceCategory(cat['id'] as int);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se puede eliminar "${cat['name']}" — tiene servicios asociados')),
      );
      return;
    }
    final cats = await provider.getServiceCategories();
    setState(() => _localCategories
      ..clear()
      ..addAll(cats));
    widget.onRefresh();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Categoría "${cat['name']}" eliminada')));
  }
}
