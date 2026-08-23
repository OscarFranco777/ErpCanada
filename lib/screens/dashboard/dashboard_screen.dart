import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/erp_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final stats = await provider.getDashboardStats();
    setState(() { _stats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final formatter = NumberFormat.currency(locale: 'en_CA', symbol: 'C\$');
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Row(children: [
            _StatCard(icon: Icons.account_balance_wallet, title: 'Cuentas por Cobrar',
              value: formatter.format(_stats['total_receivable'] ?? 0), color: Colors.orange),
            const SizedBox(width: 16),
            _StatCard(icon: Icons.inventory_2, title: 'Inventario',
              value: formatter.format(_stats['total_inventory'] ?? 0), color: Colors.blue),
            const SizedBox(width: 16),
            _StatCard(icon: Icons.warning_amber, title: 'Facturas Vencidas',
              value: '${_stats['overdue_invoices'] ?? 0}', color: Colors.red),
            const SizedBox(width: 16),
            _StatCard(icon: Icons.request_quote, title: 'Cotizaciones Activas',
              value: '${_stats['open_quotes'] ?? 0}', color: Colors.green),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _StatCard(icon: Icons.people, title: 'Clientes',
              value: '${_stats['total_customers'] ?? 0}', color: Colors.purple),
            const SizedBox(width: 16),
            _StatCard(icon: Icons.precision_manufacturing, title: 'Activos Fijos',
              value: formatter.format(_stats['total_assets'] ?? 0), color: Colors.teal),
          ]),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
