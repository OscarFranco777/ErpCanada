import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/erp_provider.dart';

class TaxRatesScreen extends StatefulWidget {
  const TaxRatesScreen({super.key});

  @override
  State<TaxRatesScreen> createState() => _TaxRatesScreenState();
}

class _TaxRatesScreenState extends State<TaxRatesScreen> {
  List<Map<String, dynamic>> _provinces = [];
  bool _loading = true;
  String _filter = 'all'; // 'all', 'hst', 'pst', 'gst_only'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    final provider = context.read<ERPProvider>();
    final provinces = await provider.getProvinces();
    setState(() {
      _provinces = provinces;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredProvinces {
    var list = _provinces;

    // Filtro por búsqueda
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final name = (p['name'] as String).toLowerCase();
        final code = (p['code'] as String).toLowerCase();
        return name.contains(q) || code.contains(q);
      }).toList();
    }

    // Filtro por tipo
    switch (_filter) {
      case 'hst':
        return list.where((p) => (p['hst_rate'] as double) > 0).toList();
      case 'pst':
        return list.where((p) => (p['pst_rate'] as double) > 0).toList();
      case 'gst_only':
        return list.where((p) =>
            (p['gst_rate'] as double) > 0 &&
            (p['pst_rate'] as double) == 0 &&
            (p['hst_rate'] as double) == 0 &&
            (p['qst_rate'] as double) == 0).toList();
      default:
        return list;
    }
  }

  double _totalRate(Map<String, dynamic> p) {
    return (p['gst_rate'] as double) +
        (p['pst_rate'] as double) +
        (p['hst_rate'] as double) +
        (p['qst_rate'] as double);
  }

  String _taxSystem(Map<String, dynamic> p) {
    final hst = p['hst_rate'] as double;
    final pst = p['pst_rate'] as double;
    final qst = p['qst_rate'] as double;
    if (hst > 0) return 'HST';
    if (qst > 0) return 'GST + QST';
    if (pst > 0) return 'GST + PST';
    return 'Solo GST';
  }

  Color _taxSystemColor(Map<String, dynamic> p) {
    final hst = p['hst_rate'] as double;
    final pst = p['pst_rate'] as double;
    final qst = p['qst_rate'] as double;
    if (hst > 0) return Colors.blue;
    if (qst > 0) return Colors.deepPurple;
    if (pst > 0) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.percentPattern('es_CA');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasas de Impuesto por Provincia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Información del sistema tributario',
            onPressed: _showTaxInfo,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ─── Resumen general ───
                _buildSummaryCard(fmt),

                // ─── Buscador ───
                _buildSearchBar(),

                // ─── Filtros ───
                _buildFilters(),

                // ─── Tabla ───
                Expanded(
                  child: _buildProvincesList(fmt),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(NumberFormat fmt) {
    final totalProvinces = _provinces.length;
    final withHST = _provinces.where((p) => (p['hst_rate'] as double) > 0).length;
    final withPST = _provinces.where((p) => (p['pst_rate'] as double) > 0).length;
    final withQST = _provinces.where((p) => (p['qst_rate'] as double) > 0).length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _summaryItem(Icons.map_rounded, '$totalProvinces', 'Provincias', Colors.teal),
            const SizedBox(width: 24),
            _summaryItem(Icons.receipt_rounded, '$withHST', 'Con HST', Colors.blue),
            const SizedBox(width: 24),
            _summaryItem(Icons.receipt_long_rounded, '$withPST', 'Con PST', Colors.orange),
            const SizedBox(width: 24),
            _summaryItem(Icons.payment_rounded, '$withQST', 'Con QST', Colors.deepPurple),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Buscar provincia por nombre o código...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _filterChip('Todas', 'all'),
          const SizedBox(width: 8),
          _filterChip('Solo GST', 'gst_only'),
          const SizedBox(width: 8),
          _filterChip('Con HST', 'hst'),
          const SizedBox(width: 8),
          _filterChip('Con PST', 'pst'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildProvincesList(NumberFormat fmt) {
    final filtered = _filteredProvinces;

    if (filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No hay provincias con este filtro', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final province = filtered[index];
        final total = _totalRate(province);
        final system = _taxSystem(province);
        final systemColor = _taxSystemColor(province);
        final isActive = (province['is_active'] as int) == 1;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: systemColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  province['code'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: systemColor,
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    province['name'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: isActive ? null : TextDecoration.lineThrough,
                      color: isActive ? null : Colors.grey,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: systemColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    system,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: systemColor,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  _rateBadge('GST', province['gst_rate'] as double, Colors.green),
                  const SizedBox(width: 6),
                  _rateBadge('PST', province['pst_rate'] as double, Colors.orange),
                  const SizedBox(width: 6),
                  _rateBadge('HST', province['hst_rate'] as double, Colors.blue),
                  const SizedBox(width: 6),
                  _rateBadge('QST', province['qst_rate'] as double, Colors.deepPurple),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Total: ${fmt.format(total)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: isActive,
                  onChanged: (val) => _toggleProvince(province, val),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  tooltip: 'Editar tasas',
                  onPressed: () => _editRates(province),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rateBadge(String label, double rate, Color color) {
    final isActive = rate > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Text(
        '$label: ${rate > 0 ? '${(rate * 100).toStringAsFixed(rate == 0.09975 ? 2 : 0)}%' : '-'}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive ? color : Colors.grey,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  ACCIONES
  // ═══════════════════════════════════════════

  Future<void> _editRates(Map<String, dynamic> province) async {
    final gstController = TextEditingController(text: ((province['gst_rate'] as double) * 100).toString());
    final pstController = TextEditingController(text: ((province['pst_rate'] as double) * 100).toString());
    final hstController = TextEditingController(text: ((province['hst_rate'] as double) * 100).toString());
    final qstController = TextEditingController(text: ((province['qst_rate'] as double) * 100).toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tasas — ${province['name']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Editá las tasas de impuesto para esta provincia.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              _rateField(ctx, 'GST (%)', gstController, Colors.green),
              const SizedBox(height: 12),
              _rateField(ctx, 'PST (%)', pstController, Colors.orange),
              const SizedBox(height: 12),
              _rateField(ctx, 'HST (%)', hstController, Colors.blue),
              const SizedBox(height: 12),
              _rateField(ctx, 'QST (%)', qstController, Colors.deepPurple),
              const SizedBox(height: 16),
              // Preview del total
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Total: ', style: TextStyle(fontWeight: FontWeight.w500)),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: gstController,
                      builder: (_, gst, __) => ValueListenableBuilder<TextEditingValue>(
                        valueListenable: pstController,
                        builder: (_, pst, __) => ValueListenableBuilder<TextEditingValue>(
                          valueListenable: hstController,
                          builder: (_, hst, __) => ValueListenableBuilder<TextEditingValue>(
                            valueListenable: qstController,
                            builder: (_, qst, __) {
                              final g = double.tryParse(gst.text) ?? 0;
                              final p = double.tryParse(pst.text) ?? 0;
                              final h = double.tryParse(hst.text) ?? 0;
                              final q = double.tryParse(qst.text) ?? 0;
                              final total = g + p + h + q;
                              return Text(
                                '${total.toStringAsFixed(total == total.roundToDouble() ? 0 : 2)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Theme.of(ctx).colorScheme.primary,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Guardar'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (result == true) {
      final provider = context.read<ERPProvider>();
      await provider.updateProvinceTaxRates(
        province['code'] as String,
        gstRate: (double.tryParse(gstController.text) ?? 0) / 100,
        pstRate: (double.tryParse(pstController.text) ?? 0) / 100,
        hstRate: (double.tryParse(hstController.text) ?? 0) / 100,
        qstRate: (double.tryParse(qstController.text) ?? 0) / 100,
      );
      await _loadProvinces();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Tasas de ${province['name']} actualizadas'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _rateField(BuildContext ctx, String label, TextEditingController controller, Color color) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: '%',
        prefixIcon: Icon(Icons.percent_rounded, color: color, size: 18),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _toggleProvince(Map<String, dynamic> province, bool value) async {
    final provider = context.read<ERPProvider>();
    await provider.toggleProvinceActive(province['code'] as String, value);
    await _loadProvinces();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '✅ ${province['name']} activada'
                : '⏸ ${province['name']} desactivada',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showTaxInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sistema Tributario Canadiense'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoSection('GST (Goods & Services Tax)',
                  'Impuesto federal del 5% aplicado en todo Canadá sobre bienes y servicios gravables.'),
              _infoSection('HST (Harmonized Sales Tax)',
                  'Combina GST + PST en una sola tasa. Se aplica en:\n'
                  '• New Brunswick: 15%\n'
                  '• Newfoundland: 15%\n'
                  '• Nova Scotia: 15%\n'
                  '• PEI: 15%\n'
                  '• Ontario: 13%'),
              _infoSection('PST (Provincial Sales Tax)',
                  'Impuesto provincial cobrado aparte del GST:\n'
                  '• British Columbia: 7%\n'
                  '• Saskatchewan: 6%\n'
                  '• Manitoba: 7%'),
              _infoSection('QST (Quebec Sales Tax)',
                  'Impuesto de Quebec cobrado junto con el GST:\n'
                  '• Quebec: 9.975%'),
              _infoSection('Solo GST (5%)',
                  'Alberta, Territorios del Noroeste, Nunavut y Yukon no tienen impuesto provincial.'),
              const Divider(),
              Text(
                'Los productos y servicios pueden estar exentos de ciertos impuestos '
                '(ej: alimentos básicos, medicamentos). Configurá la exención en '
                'cada producto/servicio.',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4)),
        ],
      ),
    );
  }
}
