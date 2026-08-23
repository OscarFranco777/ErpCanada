import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/erp_provider.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/customers/customers_screen.dart';
import 'screens/companies/company_screen.dart';
import 'screens/quotes/quotes_screen.dart';
import 'screens/invoices/invoices_screen.dart';
import 'screens/suppliers/suppliers_screen.dart';
import 'screens/services/services_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/assets/assets_screen.dart';
import 'screens/expenses/expenses_screen.dart';
import 'screens/payments/payments_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ERPCanadaApp());
}

class ERPCanadaApp extends StatelessWidget {
  const ERPCanadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ERPProvider()..init(),
      child: MaterialApp(
        title: 'ERP Canadá',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF1B5E20),
          useMaterial3: true,
          brightness: Brightness.light,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        home: const AppShell(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Datos de módulos
// ─────────────────────────────────────────────

class ModuleItem {
  final IconData icon;
  final String label;
  final Widget Function() screenBuilder;
  final Color color;
  const ModuleItem(this.icon, this.label, this.screenBuilder, {required this.color});
}

class ModuleCategory {
  final String title;
  final IconData categoryIcon;
  final List<ModuleItem> items;
  const ModuleCategory(this.title, this.categoryIcon, this.items);
}

final List<ModuleCategory> _moduleCategories = [
  ModuleCategory('Configuración', Icons.settings_rounded, [
    ModuleItem(Icons.business_rounded, 'Empresa', () => const CompanyScreen(), color: const Color(0xFF455A64)),
    ModuleItem(Icons.tune_rounded, 'Configuración', () => const SettingsScreen(), color: const Color(0xFF546E7A)),
  ]),
  ModuleCategory('Ventas', Icons.point_of_sale_rounded, [
    ModuleItem(Icons.people_rounded, 'Clientes', () => const CustomersScreen(), color: const Color(0xFF1565C0)),
    ModuleItem(Icons.request_quote_rounded, 'Cotizaciones', () => const QuotesScreen(), color: const Color(0xFF0D47A1)),
    ModuleItem(Icons.receipt_long_rounded, 'Facturas', () => const InvoicesScreen(), color: const Color(0xFF1976D2)),
    ModuleItem(Icons.payments_rounded, 'Pagos', () => const PaymentsScreen(), color: const Color(0xFF42A5F5)),
  ]),
  ModuleCategory('Compras', Icons.shopping_cart_rounded, [
    ModuleItem(Icons.local_shipping_rounded, 'Proveedores', () => const SuppliersScreen(), color: const Color(0xFFE65100)),
    ModuleItem(Icons.account_balance_wallet_rounded, 'Gastos', () => const ExpensesScreen(), color: const Color(0xFFF57C00)),
  ]),
  ModuleCategory('Inventario', Icons.inventory_rounded, [
    ModuleItem(Icons.build_rounded, 'Servicios', () => const ServicesScreen(), color: const Color(0xFF6A1B9A)),
    ModuleItem(Icons.inventory_2_rounded, 'Productos', () => const ProductsScreen(), color: const Color(0xFF7B1FA2)),
    ModuleItem(Icons.precision_manufacturing_rounded, 'Activos', () => const AssetsScreen(), color: const Color(0xFF9C27B0)),
  ]),
];

// ─────────────────────────────────────────────
//  App Shell — Sidebar lateral
// ─────────────────────────────────────────────

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedGlobalIndex = -1; // -1 = dashboard
  Widget? _activeScreen;
  String _activeTitle = 'Dashboard';

  // Map: globalIndex → (categoryIndex, itemIndex)
  (int, int) _decodeIndex(int globalIdx) {
    int running = 0;
    for (var ci = 0; ci < _moduleCategories.length; ci++) {
      for (var ii = 0; ii < _moduleCategories[ci].items.length; ii++) {
        if (running == globalIdx) return (ci, ii);
        running++;
      }
    }
    return (0, 0);
  }

  int _encodeIndex(int catIdx, int itemIdx) {
    int running = 0;
    for (var ci = 0; ci < catIdx; ci++) {
      running += _moduleCategories[ci].items.length;
    }
    return running + itemIdx;
  }

  void _openModule(int globalIndex) {
    final modules = _allModules;
    if (globalIndex < 0 || globalIndex >= modules.length) return;
    final module = modules[globalIndex];
    setState(() {
      _selectedGlobalIndex = globalIndex;
      _activeScreen = module.screenBuilder();
      _activeTitle = module.label;
    });
  }

  void _openDashboard() {
    setState(() {
      _selectedGlobalIndex = -1;
      _activeScreen = null;
      _activeTitle = 'Dashboard';
    });
  }

  List<ModuleItem> get _allModules =>
      _moduleCategories.expand((c) => c.items).toList();

  @override
  Widget build(BuildContext context) {
    return Consumer<ERPProvider>(
      builder: (context, provider, _) {
        if (!provider.initialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 800;
            if (isWide) {
              return _buildWideLayout();
            } else {
              return _buildNarrowLayout();
            }
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  //  PANTALLA ANCHA — Sidebar fijo
  // ═══════════════════════════════════════════

  Widget _buildWideLayout() {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          const VerticalDivider(width: 1),
          // Contenido
          Expanded(
            child: _activeScreen ?? _buildDashboardContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // ─── Header Logo ───
          GestureDetector(
            onTap: _openDashboard,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ERP Canadá',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // ─── Dashboard ───
          _buildSidebarItem(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            isSelected: _selectedGlobalIndex == -1,
            onTap: _openDashboard,
          ),

          const Divider(height: 1, indent: 16, endIndent: 16),

          // ─── Categorías ───
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: _buildCategoryItems(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryItems() {
    List<Widget> widgets = [];
    int runningIndex = 0;

    for (var ci = 0; ci < _moduleCategories.length; ci++) {
      final category = _moduleCategories[ci];
      final startIdx = runningIndex;

      // ¿Algún item de esta categoría está seleccionado?
      final isActive = _selectedGlobalIndex >= startIdx &&
          _selectedGlobalIndex < startIdx + category.items.length;

      // Header de categoría
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(category.categoryIcon, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                category.title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );

      // Items
      for (var ii = 0; ii < category.items.length; ii++) {
        final module = category.items[ii];
        final globalIdx = startIdx + ii;
        widgets.add(
          _buildSidebarItem(
            icon: module.icon,
            label: module.label,
            isSelected: _selectedGlobalIndex == globalIdx,
            onTap: () => _openModule(globalIdx),
          ),
        );
      }

      runningIndex += category.items.length;

      // Separador entre categorías
      if (ci < _moduleCategories.length - 1) {
        widgets.add(const SizedBox(height: 4));
      }
    }

    return widgets;
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      leading: Icon(icon, size: 20),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: onTap,
    );
  }

  // ═══════════════════════════════════════════
  //  PANTALLA ESTRECHA — Drawer
  // ═══════════════════════════════════════════

  Widget _buildNarrowLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_activeTitle),
        leading: _activeScreen != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _openDashboard,
                tooltip: 'Volver',
              )
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
      ),
      drawer: _buildDrawer(),
      body: _activeScreen ?? _buildDashboardContent(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_rounded,
                    size: 28,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ERP Canadá',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Dashboard
            ListTile(
              leading: const Icon(Icons.dashboard_rounded),
              title: const Text('Dashboard'),
              selected: _selectedGlobalIndex == -1,
              onTap: () {
                _openDashboard();
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // Categorías expandibles
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: _moduleCategories.asMap().entries.map((catEntry) {
                  final ci = catEntry.key;
                  final category = catEntry.value;
                  final startIdx = _encodeIndex(ci, 0);
                  final endIdx = startIdx + category.items.length;
                  final isActive = _selectedGlobalIndex >= startIdx &&
                      _selectedGlobalIndex < endIdx;

                  return ExpansionTile(
                    leading: Icon(category.categoryIcon,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : null),
                    title: Text(
                      category.title,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    initiallyExpanded: isActive,
                    children: category.items.asMap().entries.map((entry) {
                      final globalIdx = startIdx + entry.key;
                      final module = entry.value;
                      return ListTile(
                        leading: Icon(module.icon, size: 20),
                        title: Text(module.label, style: const TextStyle(fontSize: 14)),
                        selected: _selectedGlobalIndex == globalIdx,
                        contentPadding: const EdgeInsets.only(left: 20),
                        onTap: () {
                          _openModule(globalIdx);
                          Navigator.pop(context);
                        },
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  DASHBOARD
  // ═══════════════════════════════════════════

  Widget _buildDashboardContent() {
    return const DashboardScreen();
  }
}
