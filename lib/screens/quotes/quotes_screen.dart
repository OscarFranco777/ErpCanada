import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';
import 'quote_form_screen.dart';
import 'quote_detail_screen.dart';

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});
  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  String _statusFilter = 'all';
  List<Map<String, dynamic>> _quotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final status = _statusFilter == 'all' ? null : _statusFilter;
    final quotes = await provider.getQuotes(status: status);
    setState(() { _quotes = quotes; _loading = false; });
  }

  Future<void> _deleteQuote(Map<String, dynamic> quote) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Cotización'),
        content: Text('¿Eliminar la cotización ${quote['quote_number']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;

    final provider = context.read<ERPProvider>();
    final success = await provider.deleteQuote(quote['id']);
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede eliminar: ya fue convertida a factura'), backgroundColor: Colors.orange),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cotización eliminada'), backgroundColor: Colors.green),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColors = {
      'draft': Colors.grey, 'sent': Colors.blue, 'accepted': Colors.green,
      'rejected': Colors.red, 'converted': Colors.purple,
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Cotizaciones', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('Todas')),
                  ButtonSegment(value: 'draft', label: Text('Borrador')),
                  ButtonSegment(value: 'sent', label: Text('Enviada')),
                  ButtonSegment(value: 'accepted', label: Text('Aceptada')),
                  ButtonSegment(value: 'converted', label: Text('Convertida')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (s) { setState(() => _statusFilter = s.first); _loadData(); },
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (_) => const QuoteFormScreen(),
                  );
                  if (result == true) _loadData();
                },
                icon: const Icon(Icons.add), label: const Text('Nueva Cotización'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _quotes.isEmpty
                    ? const Center(child: Text('No hay cotizaciones'))
                    : ListView.builder(
                        itemCount: _quotes.length,
                        itemBuilder: (context, index) {
                          final q = _quotes[index];
                          final color = statusColors[q['status']] ?? Colors.grey;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.1),
                                child: Icon(Icons.request_quote, color: color),
                              ),
                              title: Text('${q['quote_number']} - ${q['customer_name']}'),
                              subtitle: Text(q['company_name'] ?? ''),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('C\$${(q['total'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                Chip(label: Text(q['status'], style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (v) {
                                    switch (v) {
                                      case 'view':
                                        Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => QuoteDetailScreen(quoteId: q['id']),
                                        )).then((_) => _loadData());
                                        break;
                                      case 'edit':
                                        showDialog(
                                          context: context,
                                          builder: (_) => QuoteFormScreen(quote: q),
                                        ).then((result) { if (result == true) _loadData(); });
                                        break;
                                      case 'delete':
                                        _deleteQuote(q);
                                        break;
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'view', child: ListTile(leading: Icon(Icons.visibility), title: Text('Ver Detalle'), dense: true)),
                                    if (q['status'] != 'converted')
                                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'), dense: true)),
                                    if (q['status'] != 'converted')
                                      const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Eliminar'), dense: true)),
                                  ],
                                ),
                              ]),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => QuoteDetailScreen(quoteId: q['id']),
                                )).then((_) => _loadData());
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
