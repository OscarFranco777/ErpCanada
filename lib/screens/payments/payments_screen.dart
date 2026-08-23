import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/erp_provider.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final payments = await provider.getPayments();
    setState(() { _payments = payments; _loading = false; });
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
            Text('Pagos', style: Theme.of(context).textTheme.headlineMedium),
            const Spacer(),
            FilledButton.icon(onPressed: () {/* TODO */}, icon: const Icon(Icons.add), label: const Text('Registrar Pago')),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator())
                : _payments.isEmpty ? const Center(child: Text('No hay pagos registrados'))
                : ListView.builder(
                    itemCount: _payments.length,
                    itemBuilder: (context, index) {
                      final p = _payments[index];
                      return Card(child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: const Icon(Icons.payments, color: Colors.green)),
                        title: Text('${p['invoice_number']} - ${fmt.format(p['amount'])}'),
                        subtitle: Text('${p['payment_date']} • ${p['payment_method']}'),
                        trailing: p['reference_number'] != null ? Text(p['reference_number'], style: const TextStyle(fontSize: 12)) : null,
                      ));
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
