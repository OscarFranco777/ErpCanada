import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/erp_provider.dart';

class QuoteDetailScreen extends StatefulWidget {
  final int quoteId;
  const QuoteDetailScreen({super.key, required this.quoteId});

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  Map<String, dynamic>? _quote;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _company;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final quote = await provider.getQuote(widget.quoteId);
    final items = await provider.getQuoteItems(widget.quoteId);
    final company = await provider.getCompany();
    setState(() {
      _quote = quote;
      _items = items;
      _company = company;
      _loading = false;
    });
  }

  Future<void> _updateStatus(String status) async {
    final provider = context.read<ERPProvider>();
    await provider.database.update('quotes', {
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [widget.quoteId]);
    _loadData();
  }

  Future<void> _convertToInvoice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convertir a Factura'),
        content: const Text('¿Crear una factura a partir de esta cotización?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Convertir')),
        ],
      ),
    );
    if (confirmed != true) return;

    final provider = context.read<ERPProvider>();
    final invoiceId = await provider.convertQuoteToInvoice(widget.quoteId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Factura INV-${invoiceId.toString().padLeft(4, '0')} creada'), backgroundColor: Colors.green));
      _loadData();
    }
  }

  Future<void> _printQuote() async {
    final pdf = pw.Document();
    final q = _quote!;
    final company = _company;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        // Header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(company?['name'] ?? 'ERP Canadá', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('${company?['address'] ?? ''}\n${company?['city'] ?? ''}, ${company?['province'] ?? ''} ${company?['postal_code'] ?? ''}'),
                pw.Text('Tel: ${company?['phone'] ?? ''}'),
                pw.Text('Email: ${company?['email'] ?? ''}'),
                pw.Text('Tax #: ${company?['tax_number'] ?? ''}'),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('COTIZACIÓN', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 4),
                pw.Text('# ${q['quote_number']}', style: pw.TextStyle(fontSize: 14)),
                pw.Text('Fecha: ${q['quote_date']}'),
                pw.Text('Vence: ${q['expiry_date'] ?? 'N/A'}'),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: q['status'] == 'accepted' ? PdfColors.green100 : PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(q['status'].toString().toUpperCase(), style: const pw.TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 24),

        // Customer info
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('CLIENTE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 4),
              pw.Text('${q['customer_name']}', style: const pw.TextStyle(fontSize: 12)),
              if (q['company_name'] != null && q['company_name'].toString().isNotEmpty)
                pw.Text('${q['company_name']}', style: const pw.TextStyle(fontSize: 11)),
              if (q['job_address'] != null && q['job_address'].toString().isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text('DIRECCIÓN DEL TRABAJO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text('${q['job_address']}, ${q['job_city'] ?? ''} ${q['job_province'] ?? ''} ${q['job_postal_code'] ?? ''}'),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Items table
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          cellAlignments: {
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.center,
            4: pw.Alignment.centerRight,
          },
          headers: ['Descripción', 'Cant.', 'P. Unit.', 'Dto%', 'Total'],
          data: _items.map((i) => [
            '${i['item_name'] ?? i['description']}',
            '${(i['quantity'] as num).toStringAsFixed(i['quantity'].truncateToDouble() == i['quantity'] ? 0 : 1)}',
            'C\$${(i['unit_price'] as num).toStringAsFixed(2)}',
            '${((i['discount_pct'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}%',
            'C\$${(i['line_total'] as num).toStringAsFixed(2)}',
          ]).toList(),
        ),
        pw.SizedBox(height: 16),

        // Totals
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 200,
              child: pw.Column(children: [
                _totalsRow('Subtotal', 'C\$${(q['subtotal'] as num).toStringAsFixed(2)}'),
                if ((q['gst_amount'] as num) > 0) _totalsRow('GST', 'C\$${(q['gst_amount'] as num).toStringAsFixed(2)}'),
                if ((q['pst_amount'] as num) > 0) _totalsRow('PST', 'C\$${(q['pst_amount'] as num).toStringAsFixed(2)}'),
                if ((q['hst_amount'] as num) > 0) _totalsRow('HST', 'C\$${(q['hst_amount'] as num).toStringAsFixed(2)}'),
                if ((q['qst_amount'] as num) > 0) _totalsRow('QST', 'C\$${(q['qst_amount'] as num).toStringAsFixed(2)}'),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text('C\$${(q['total'] as num).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ]),
            ),
          ],
        ),

        if (q['notes'] != null && q['notes'].toString().isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text('Notas:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('${q['notes']}'),
        ],

        pw.SizedBox(height: 30),
        pw.Text('Gracias por su preferencia', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) => pdf.save(), name: 'Cotizacion_${q['quote_number']}');
  }

  pw.Widget _totalsRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
        ),
    );
  }

  Future<void> _shareWhatsApp() async {
    final q = _quote!;
    final msg = StringBuffer();
    msg.writeln('*COTIZACIÓN ${q['quote_number']}*');
    msg.writeln('Cliente: ${q['customer_name']}');
    msg.writeln('Fecha: ${q['quote_date']}');
    msg.writeln('');
    for (final i in _items) {
      final name = i['item_name'] ?? i['description'];
      msg.writeln('- $name x${i['quantity']} = C\$${(i['line_total'] as num).toStringAsFixed(2)}');
    }
    msg.writeln('');
    msg.writeln('*TOTAL: C\$${(q['total'] as num).toStringAsFixed(2)}*');
    if (q['job_address'] != null && q['job_address'].toString().isNotEmpty) {
      msg.writeln('\n📍 ${q['job_address']}, ${q['job_city'] ?? ''}');
    }

    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(msg.toString())}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: copy to clipboard
      await Clipboard.setData(ClipboardData(text: msg.toString()));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cotización copiada al portapapeles')));
    }
  }

  Future<void> _shareEmail() async {
    final q = _quote!;
    final subject = Uri.encodeComponent('Cotización ${q['quote_number']}');
    final body = Uri.encodeComponent(
      'Cotización ${q['quote_number']}\n'
      'Fecha: ${q['quote_date']}\n\n'
      'Ítems:\n${_items.map((i) => '- ${i['item_name'] ?? i['description']} x${i['quantity']} = C\$${(i['line_total'] as num).toStringAsFixed(2)}').join('\n')}\n\n'
      'TOTAL: C\$${(q['total'] as num).toStringAsFixed(2)}\n'
    );
    final email = q['customer_email'] ?? '';
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el cliente de correo')));
    }
  }

  Future<void> _shareLink() async {
    final q = _quote!;
    final msg = StringBuffer();
    msg.writeln('Cotización ${q['quote_number']}');
    msg.writeln('Total: C\$${(q['total'] as num).toStringAsFixed(2)}');
    await Clipboard.setData(ClipboardData(text: msg.toString()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resumen copiado al portapapeles')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_quote == null) {
      return const Scaffold(body: Center(child: Text('Cotización no encontrada')));
    }

    final q = _quote!;
    final statusColors = {
      'draft': Colors.grey, 'sent': Colors.blue, 'accepted': Colors.green,
      'rejected': Colors.red, 'converted': Colors.purple,
    };
    final color = statusColors[q['status']] ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: Text('${q['quote_number']} - ${q['customer_name']}'),
        actions: [
          if (q['status'] != 'converted')
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                switch (v) {
                  case 'print': _printQuote(); break;
                  case 'email': _shareEmail(); break;
                  case 'whatsapp': _shareWhatsApp(); break;
                  case 'link': _shareLink(); break;
                  case 'send': _updateStatus('sent'); break;
                  case 'accept': _updateStatus('accepted'); break;
                  case 'reject': _updateStatus('rejected'); break;
                  case 'convert': _convertToInvoice(); break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'print', child: ListTile(leading: Icon(Icons.print), title: Text('Imprimir PDF'), dense: true)),
                const PopupMenuItem(value: 'email', child: ListTile(leading: Icon(Icons.email), title: Text('Enviar por Correo'), dense: true)),
                const PopupMenuItem(value: 'whatsapp', child: ListTile(leading: Icon(Icons.chat), title: Text('Compartir WhatsApp'), dense: true)),
                const PopupMenuItem(value: 'link', child: ListTile(leading: Icon(Icons.link), title: Text('Copiar Resumen'), dense: true)),
                const PopupMenuDivider(),
                if (q['status'] == 'draft')
                  const PopupMenuItem(value: 'send', child: ListTile(leading: Icon(Icons.send), title: Text('Marcar Enviada'), dense: true)),
                if (q['status'] == 'sent') ...[
                  const PopupMenuItem(value: 'accept', child: ListTile(leading: Icon(Icons.check_circle), title: Text('Marcar Aceptada'), dense: true)),
                  const PopupMenuItem(value: 'reject', child: ListTile(leading: Icon(Icons.cancel), title: Text('Rechazada'), dense: true)),
                ],
                if (q['status'] == 'accepted')
                  const PopupMenuItem(value: 'convert', child: ListTile(leading: Icon(Icons.receipt_long), title: Text('Convertir a Factura'), dense: true)),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status + Dates
            Row(children: [
              Chip(
                label: Text(q['status'].toString().toUpperCase(), style: TextStyle(fontSize: 12, color: color)),
                backgroundColor: color.withValues(alpha: 0.1),
                side: BorderSide(color: color.withValues(alpha: 0.3)),
              ),
              const Spacer(),
              Text('Fecha: ${q['quote_date']}', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(width: 16),
              Text('Vence: ${q['expiry_date'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600])),
            ]),
            const SizedBox(height: 20),

            // Company + Customer info
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _buildInfoCard('Empresa', [
                _company?['name'] ?? '',
                '${_company?['address'] ?? ''}',
                '${_company?['city'] ?? ''}, ${_company?['province'] ?? ''} ${_company?['postal_code'] ?? ''}',
                'Tel: ${_company?['phone'] ?? ''}',
                'Tax #: ${_company?['tax_number'] ?? ''}',
              ])),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoCard('Cliente', [
                '${q['customer_name']}',
                if (q['company_name'] != null && q['company_name'].toString().isNotEmpty) '${q['company_name']}',
                if (q['customer_email'] != null) 'Email: ${q['customer_email']}',
                if (q['customer_phone'] != null) 'Tel: ${q['customer_phone']}',
                if (q['job_address'] != null && q['job_address'].toString().isNotEmpty)
                  '📍 ${q['job_address']}, ${q['job_city'] ?? ''} ${q['job_province'] ?? ''}',
              ])),
            ]),
            const SizedBox(height: 24),

            // Items table
            Text('Ítems', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(4), 1: FlexColumnWidth(1),
                2: FlexColumnWidth(2), 3: FlexColumnWidth(1),
                4: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  children: ['Descripción', 'Cant.', 'P. Unit.', 'Dto%', 'Total']
                      .map((h) => Padding(padding: const EdgeInsets.all(8), child: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))).toList(),
                ),
                ..._items.map((i) => TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i['item_name'] ?? i['description'], style: const TextStyle(fontSize: 13)),
                        Text('${i['item_type'] == 'service' ? 'Servicio' : 'Producto'}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ],
                    )),
                    Padding(padding: const EdgeInsets.all(8), child: Text('${i['quantity']}', textAlign: TextAlign.center)),
                    Padding(padding: const EdgeInsets.all(8), child: Text('C\$${(i['unit_price'] as num).toStringAsFixed(2)}', textAlign: TextAlign.right)),
                    Padding(padding: const EdgeInsets.all(8), child: Text('${((i['discount_pct'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}%', textAlign: TextAlign.center)),
                    Padding(padding: const EdgeInsets.all(8), child: Text('C\$${(i['line_total'] as num).toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 16),

            // Totals
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 250,
                child: Column(children: [
                  _buildTotalRow('Subtotal', (q['subtotal'] as num).toDouble()),
                  if ((q['gst_amount'] as num) > 0) _buildTotalRow('GST', (q['gst_amount'] as num).toDouble()),
                  if ((q['pst_amount'] as num) > 0) _buildTotalRow('PST', (q['pst_amount'] as num).toDouble()),
                  if ((q['hst_amount'] as num) > 0) _buildTotalRow('HST', (q['hst_amount'] as num).toDouble()),
                  if ((q['qst_amount'] as num) > 0) _buildTotalRow('QST', (q['qst_amount'] as num).toDouble()),
                  const Divider(),
                  Row(children: [
                    const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    Text('C\$${(q['total'] as num).toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Theme.of(context).colorScheme.primary)),
                  ]),
                ]),
              ),
            ),

            if (q['notes'] != null && q['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Notas', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${q['notes']}', style: TextStyle(color: Colors.grey[700])),
                  ]),
                ),
              ),
            ],
          ],
        ),
      ),
      // Action buttons at bottom
      bottomNavigationBar: q['status'] == 'converted'
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(icon: Icons.print, label: 'Imprimir', color: Colors.blue, onTap: _printQuote),
                  _ActionButton(icon: Icons.email, label: 'Correo', color: Colors.orange, onTap: _shareEmail),
                  _ActionButton(icon: Icons.chat, label: 'WhatsApp', color: Colors.green, onTap: _shareWhatsApp),
                  _ActionButton(icon: Icons.link, label: 'Copiar', color: Colors.purple, onTap: _shareLink),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(String title, List<String> lines) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(l, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text(label, style: TextStyle(color: Colors.grey[600])),
        const Spacer(),
        Text('C\$${amount.toStringAsFixed(2)}'),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Action Button widget
// ═══════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
