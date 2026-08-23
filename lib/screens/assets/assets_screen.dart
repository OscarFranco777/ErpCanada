import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../providers/erp_provider.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});
  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  List<Map<String, dynamic>> _assets = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final assets = await provider.getAssets();
    setState(() { _assets = assets; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Activos Fijos', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            FilledButton.icon(onPressed: () {/* TODO */}, icon: const Icon(Icons.add), label: const Text('Nuevo Activo')),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator())
                : _assets.isEmpty ? const Center(child: Text('No hay activos registrados'))
                : DataTable2(
                    columns: const [
                      DataColumn2(label: Text('Código'), size: ColumnSize.S),
                      DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
                      DataColumn2(label: Text('Categoría'), size: ColumnSize.S),
                      DataColumn2(label: Text('Valor Compra'), size: ColumnSize.S),
                      DataColumn2(label: Text('Valor Actual'), size: ColumnSize.S),
                      DataColumn2(label: Text('Asignado a'), size: ColumnSize.M),
                      DataColumn2(label: Text('Estado'), size: ColumnSize.S),
                    ],
                    rows: _assets.map((a) => DataRow2(cells: [
                      DataCell(Text(a['asset_code'] ?? '')),
                      DataCell(Text(a['name'])),
                      DataCell(Text(a['category'])),
                      DataCell(Text('C\$${(a['purchase_price'] as num?)?.toStringAsFixed(2) ?? '-'}')),
                      DataCell(Text('C\$${(a['current_value'] as num?)?.toStringAsFixed(2) ?? '-'}')),
                      DataCell(Text(a['assigned_to'] ?? '-')),
                      DataCell(Chip(
                        label: Text(a['status'], style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        color: WidgetStatePropertyAll(
                          a['status'] == 'active' ? Colors.green.shade50 :
                          a['status'] == 'maintenance' ? Colors.orange.shade50 : Colors.grey.shade200,
                        ),
                      )),
                    ])).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
