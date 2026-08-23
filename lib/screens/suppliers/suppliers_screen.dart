import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../providers/erp_provider.dart';
import 'supplier_form_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  String _search = '';
  List<Map<String, dynamic>> _suppliers = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final suppliers = await provider.getSuppliers(search: _search);
    setState(() { _suppliers = suppliers; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Proveedores', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            SizedBox(
              width: 300,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar proveedor...', prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                onChanged: (v) { setState(() => _search = v); _loadData(); },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () async {
                await showDialog(context: context, builder: (_) => const SupplierFormScreen());
                _loadData();
              },
              icon: const Icon(Icons.add), label: const Text('Nuevo Proveedor'),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _suppliers.isEmpty
                    ? const Center(child: Text('No hay proveedores registrados'))
                    : DataTable2(
                        columns: const [
                          DataColumn2(label: Text('Código'), size: ColumnSize.S),
                          DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
                          DataColumn2(label: Text('Empresa'), size: ColumnSize.M),
                          DataColumn2(label: Text('Email'), size: ColumnSize.M),
                          DataColumn2(label: Text('Teléfono'), size: ColumnSize.S),
                          DataColumn2(label: Text('Ciudad'), size: ColumnSize.S),
                          DataColumn2(label: Text(''), size: ColumnSize.S),
                        ],
                        rows: _suppliers.map((s) => DataRow2(cells: [
                          DataCell(Text(s['supplier_code'] ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                          DataCell(Text('${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim())),
                          DataCell(Text(s['company_name'] ?? '-')),
                          DataCell(Text(s['email'] ?? '-')),
                          DataCell(Text(s['phone'] ?? '-')),
                          DataCell(Text(s['city'] ?? '-')),
                          DataCell(IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () async {
                              await showDialog(context: context, builder: (_) => SupplierFormScreen(supplier: s));
                              _loadData();
                            },
                          )),
                        ])).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}
