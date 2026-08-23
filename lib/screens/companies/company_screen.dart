import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});
  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  Map<String, dynamic>? _company;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<ERPProvider>();
    final company = await provider.getCompany();
    setState(() { _company = company; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_company == null) return const Center(child: Text('No hay empresa configurada'));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Datos de la Empresa', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _CompanyForm(company: _company!, onSave: _loadData),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyForm extends StatefulWidget {
  final Map<String, dynamic> company;
  final VoidCallback onSave;
  const _CompanyForm({required this.company, required this.onSave});

  @override
  State<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends State<_CompanyForm> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late TextEditingController _name;
  late TextEditingController _addressSearch;
  late TextEditingController _address1;
  late TextEditingController _address2;
  late TextEditingController _aptSuite;
  late TextEditingController _city;
  late TextEditingController _postalCode;
  late TextEditingController _phone;
  late TextEditingController _email;
  late TextEditingController _taxNumber;
  String? _logoPath;
  String? _provinceCode;

  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _loadingProvinces = true;
  bool _searchingAddress = false;

  @override
  void initState() {
    super.initState();
    final c = widget.company;
    _name = TextEditingController(text: c['name'] ?? '');
    _addressSearch = TextEditingController();
    _address1 = TextEditingController(text: c['address'] ?? '');
    _address2 = TextEditingController(text: c['address_line2'] ?? '');
    _aptSuite = TextEditingController(text: c['apt_suite'] ?? '');
    _city = TextEditingController(text: c['city'] ?? '');
    _postalCode = TextEditingController(text: c['postal_code'] ?? '');
    _phone = TextEditingController(text: c['phone'] ?? '');
    _email = TextEditingController(text: c['email'] ?? '');
    _taxNumber = TextEditingController(text: c['tax_number'] ?? '');
    _logoPath = c['logo_path'];
    _provinceCode = c['province_code'];
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    final provider = context.read<ERPProvider>();
    final provinces = await provider.getProvinces();
    setState(() { _provinces = provinces; _loadingProvinces = false; });
  }

  // ═══ ADDRESS AUTOCOMPLETE (Nominatim) ═══
  Future<void> _searchAddress(String query) async {
    if (query.length < 3) {
      setState(() { _addressSuggestions = []; _searchingAddress = false; });
      return;
    }
    setState(() => _searchingAddress = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&countrycodes=ca&format=json&addressdetails=1&limit=5'
      );
      final resp = await http.get(url, headers: {'User-Agent': 'ERPCanadaApp/1.0'});
      if (resp.statusCode == 200) {
        final List data = json.decode(resp.body);
        setState(() {
          _addressSuggestions = data.cast<Map<String, dynamic>>();
          _searchingAddress = false;
        });
      }
    } catch (_) {
      setState(() => _searchingAddress = false);
    }
  }

  void _applyAddressSuggestion(Map<String, dynamic> suggestion) {
    final addr = suggestion['address'] ?? {};
    setState(() {
      final houseNum = addr['house_number'] ?? '';
      final road = addr['road'] ?? suggestion['display_name']?.toString().split(',')[0] ?? '';
      _address1.text = houseNum.isNotEmpty ? '$houseNum $road' : road;
      _address2.clear();
      _aptSuite.clear();
      _city.text = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'] ?? '';
      _postalCode.text = addr['postcode']?.toString().replaceAll(' ', '') ?? '';
      final prov = addr['state'] ?? '';
      final provCode = _matchProvinceCode(prov);
      if (provCode != null) _provinceCode = provCode;
      _addressSuggestions = [];
      _addressSearch.clear();
    });
  }

  String? _matchProvinceCode(String name) {
    final map = {
      'Ontario': 'ON', 'Quebec': 'QC', 'British Columbia': 'BC',
      'Alberta': 'AB', 'Manitoba': 'MB', 'Saskatchewan': 'SK',
      'Nova Scotia': 'NS', 'New Brunswick': 'NB',
      'Newfoundland and Labrador': 'NL', 'Prince Edward Island': 'PE',
      'Yukon': 'YT', 'Northwest Territories': 'NT', 'Nunavut': 'NU',
    };
    for (final entry in map.entries) {
      if (name.toLowerCase().contains(entry.key.toLowerCase())) return entry.value;
    }
    return null;
  }

  @override
  void dispose() {
    _name.dispose();
    _addressSearch.dispose(); _address1.dispose(); _address2.dispose();
    _aptSuite.dispose(); _city.dispose(); _postalCode.dispose();
    _phone.dispose(); _email.dispose(); _taxNumber.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'company_logo${p.extension(picked.path)}';
    final savedFile = await File(picked.path).copy('${appDir.path}/$fileName');
    setState(() => _logoPath = savedFile.path);
  }

  void _removeLogo() {
    setState(() => _logoPath = null);
  }

  String _buildFullAddress() {
    final parts = <String>[];
    if (_address1.text.isNotEmpty) parts.add(_address1.text);
    if (_address2.text.isNotEmpty) parts.add(_address2.text);
    if (_aptSuite.text.isNotEmpty) parts.add(_aptSuite.text);
    final cityLine = <String>[];
    if (_city.text.isNotEmpty) cityLine.add(_city.text);
    if (_provinceCode != null) cityLine.add(_provinceCode!);
    if (cityLine.isNotEmpty) parts.add(cityLine.join(', '));
    if (_postalCode.text.isNotEmpty) parts.add(_postalCode.text);
    parts.add('Canada');
    return parts.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          // ═══ LOGO ═══
          Center(
            child: GestureDetector(
              onTap: _pickLogo,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                      image: _logoPath != null && File(_logoPath!).existsSync()
                          ? DecorationImage(
                              image: FileImage(File(_logoPath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _logoPath == null || !File(_logoPath!).existsSync()
                        ? Icon(Icons.business_rounded, size: 48,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          if (_logoPath != null)
            Center(
              child: TextButton.icon(
                onPressed: _removeLogo,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Quitar logo'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // ═══ INFORMACIÓN ═══
          Text('Información', style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre de la Empresa *'),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
            )),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _taxNumber,
            decoration: const InputDecoration(
              labelText: 'GST/HST Number', hintText: '123456789RT0001',
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // ═══ DIRECCIÓN ═══
          Text('Dirección', style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          )),
          const SizedBox(height: 12),

          // Buscador de direcciones
          TextField(
            controller: _addressSearch,
            decoration: InputDecoration(
              hintText: '🔍 Buscar dirección en Canadá...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchingAddress
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: _searchAddress,
          ),
          if (_addressSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _addressSuggestions.map((s) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on, size: 18),
                  title: Text(s['display_name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  onTap: () => _applyAddressSuggestion(s),
                )).toList(),
              ),
            ),
          const SizedBox(height: 12),

          TextFormField(controller: _address1, decoration: const InputDecoration(labelText: 'Dirección Línea 1')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(controller: _address2, decoration: const InputDecoration(labelText: 'Dirección Línea 2'))),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: _aptSuite, decoration: const InputDecoration(labelText: 'Apto / Suite'))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'Ciudad'))),
            const SizedBox(width: 12),
            Expanded(child: _loadingProvinces
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    value: _provinceCode,
                    decoration: const InputDecoration(labelText: 'Provincia'),
                    items: _provinces.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(
                      value: p['code'] as String,
                      child: Text('${p['code']} - ${p['name']}'),
                    )).toList(),
                    onChanged: (v) => setState(() => _provinceCode = v),
                  )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _postalCode,
              decoration: const InputDecoration(labelText: 'Código Postal', hintText: 'A1A 1A1'),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(
              initialValue: 'Canada',
              decoration: InputDecoration(labelText: 'País'),
              enabled: false,
            )),
          ]),

          // Preview de dirección
          const SizedBox(height: 12),
          if (_address1.text.isNotEmpty)
            Card(
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.preview, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _buildFullAddress(),
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  )),
                ]),
              ),
            ),

          const SizedBox(height: 24),

          // ═══ GUARDAR ═══
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<ERPProvider>().updateCompany({
      ...widget.company,
      'name': _name.text.trim(),
      'logo_path': _logoPath,
      'address': _address1.text.trim().isEmpty ? null : _address1.text.trim(),
      'address_line2': _address2.text.trim().isEmpty ? null : _address2.text.trim(),
      'apt_suite': _aptSuite.text.trim().isEmpty ? null : _aptSuite.text.trim(),
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'province_code': _provinceCode,
      'province': _provinceCode ?? '',
      'postal_code': _postalCode.text.trim().isEmpty ? null : _postalCode.text.trim().toUpperCase(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'tax_number': _taxNumber.text.trim(),
    });
    widget.onSave();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Empresa actualizada')),
      );
    }
  }
}
