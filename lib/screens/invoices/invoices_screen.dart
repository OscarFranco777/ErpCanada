import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  String _statusFilter = 'all';
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final status = _statusFilter == 'all' ? null : _statusFilter;
    final invoices = await provider.getInvoices(status: status);
    setState(() { _invoices = invoices; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Facturas', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Todas')),
                ButtonSegment(value: 'draft', label: Text('Borrador')),
                ButtonSegment(value: 'sent', label: Text('Enviada')),
                ButtonSegment(value: 'paid', label: Text('Pagada')),
                ButtonSegment(value: 'overdue', label: Text('Vencida')),
              ],
              selected: {_statusFilter},
              onSelectionChanged: (s) { setState(() => _statusFilter = s.first); _loadData(); },
            ),
            const SizedBox(width: 12),
            FilledButton.icon(onPressed: () {/* TODO */}, icon: const Icon(Icons.add), label: const Text('Nueva Factura')),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator())
                : _invoices.isEmpty ? const Center(child: Text('No hay facturas'))
                : ListView.builder(
                    itemCount: _invoices.length,
                    itemBuilder: (context, index) {
                      final i = _invoices[index];
                      final isCN = i['is_credit_note'] == 1;
                      final sc = {'draft': Colors.grey, 'sent': Colors.blue, 'paid': Colors.green, 'partial': Colors.orange, 'overdue': Colors.red};
                      final color = sc[i['status']] ?? Colors.grey;
                      return Card(child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCN ? Colors.red.withValues(alpha: 0.1) : color.withValues(alpha: 0.1),
                          child: Icon(isCN ? Icons.money_off : Icons.receipt_long, color: isCN ? Colors.red : color),
                        ),
                        title: Text('${i['invoice_number']} - ${i['customer_name']}'),
                        subtitle: Text('Vence: ${i['due_date'] ?? '-'}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('C\$${(i['total'] as num).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: isCN ? Colors.red : null)),
                            Text('Saldo: C\$${(i['balance_due'] as num).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
                          ]),
                          const SizedBox(width: 12),
                          Chip(label: Text(i['status'], style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
                        ]),
                      ));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
