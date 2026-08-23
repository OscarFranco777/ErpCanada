import 'package:flutter/material.dart';
import 'tax_rates_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configuración', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Base de Datos'),
                  subtitle: const Text('Copia de seguridad de la base de datos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {/* TODO: Backup */},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('Plantillas PDF'),
                  subtitle: const Text('Personalizar plantillas de facturas y cotizaciones'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {/* TODO: PDF Templates */},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.numbers),
                  title: const Text('Secuencias de Numeración'),
                  subtitle: const Text('Configurar prefijos y numeración'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {/* TODO: Sequences */},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel),
                  title: const Text('Tasas de Impuesto'),
                  subtitle: const Text('Revisar tasas GST/PST/HST/QST por provincia'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TaxRatesScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
