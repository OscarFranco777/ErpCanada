import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/erp_provider.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final expenses = await provider.getExpenses();
    setState(() { _expenses = expenses; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'en_CA', symbol: 'C\$');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Gastos', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            FilledButton.icon(onPressed: () {/* TODO */}, icon: const Icon(Icons.add), label: const Text('Nuevo Gasto')),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty ? const Center(child: Text('No hay gastos registrados'))
                : ListView.builder(
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final e = _expenses[index];
                      return Card(child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.red.shade50, child: const Icon(Icons.receipt, color: Colors.red)),
                        title: Text(e['description']),
                        subtitle: Text('${e['expense_date']} • ${e['supplier_name'] ?? 'Sin proveedor'} • ${e['category']}'),
                        trailing: Text(fmt.format(e['total']), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
