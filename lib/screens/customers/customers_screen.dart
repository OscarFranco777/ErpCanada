import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../providers/erp_provider.dart';
import 'customer_form_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _search = '';
  List<Map<String, dynamic>> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final customers = await provider.getCustomers(search: _search);
    setState(() { _customers = customers; _loading = false; });
  }

  Future<void> _deleteCustomer(Map<String, dynamic> customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cliente'),
        content: Text('¿Estás seguro de eliminar a ${customer['first_name']} ${customer['last_name']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;

    final provider = context.read<ERPProvider>();
    final success = await provider.deleteCustomer(customer['id']);
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede eliminar: tiene cotizaciones, facturas o pagos vinculados'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente eliminado'), backgroundColor: Colors.green),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Clientes', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente...', prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  onChanged: (v) { setState(() => _search = v); _loadData(); },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () async {
                  await showDialog(context: context, builder: (_) => const CustomerFormScreen());
                  _loadData();
                },
                icon: const Icon(Icons.add), label: const Text('Nuevo Cliente'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? const Center(child: Text('No hay clientes registrados'))
                    : DataTable2(
                        columns: const [
                          DataColumn2(label: Text('Código'), size: ColumnSize.S),
                          DataColumn2(label: Text('Nombre'), size: ColumnSize.L),
                          DataColumn2(label: Text('Empresa'), size: ColumnSize.M),
                          DataColumn2(label: Text('Email'), size: ColumnSize.M),
                          DataColumn2(label: Text('Teléfono'), size: ColumnSize.S),
                          DataColumn2(label: Text('Provincia'), size: ColumnSize.S),
                          DataColumn2(label: Text(''), size: ColumnSize.S),
                        ],
                        rows: _customers.map((c) => DataRow2(cells: [
                          DataCell(Text(c['customer_code'] ?? '-')),
                          DataCell(Text('${c['first_name']} ${c['last_name']}')),
                          DataCell(Text(c['company_name'] ?? '-')),
                          DataCell(Text(c['email'] ?? '-')),
                          DataCell(Text(c['phone'] ?? '-')),
                          DataCell(Text(c['province_code'] ?? '-')),
                          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () async {
                                await showDialog(context: context, builder: (_) => CustomerFormScreen(customer: c));
                                _loadData();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => _deleteCustomer(c),
                            ),
                          ])),
                        ])).toList(),
                      ),
          ),
        ],
      ),
    );
  }
}
