import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/erp_provider.dart';

class CustomerFormScreen extends StatefulWidget {
  final Map<String, dynamic>? customer;
  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabCtrl;

  // Info controllers
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _company;
  late TextEditingController _email;
  late TextEditingController _phone;
  late TextEditingController _idNumber;
  late TextEditingController _creditLimit;
  late TextEditingController _notes;

  // Address controllers
  late TextEditingController _addressSearch;
  late TextEditingController _address1;
  late TextEditingController _address2;
  late TextEditingController _aptSuite;
  late TextEditingController _city;
  late TextEditingController _postalCode;
  late TextEditingController _country;

  String? _provinceCode;
  String? _idType;
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _addressSuggestions = [];
  bool _loadingProvinces = true;
  bool _searchingAddress = false;

  bool get isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final c = widget.customer;
    _firstName = TextEditingController(text: c?['first_name'] ?? '');
    _lastName = TextEditingController(text: c?['last_name'] ?? '');
    _company = TextEditingController(text: c?['company_name'] ?? '');
    _email = TextEditingController(text: c?['email'] ?? '');
    _phone = TextEditingController(text: c?['phone'] ?? '');
    _idNumber = TextEditingController(text: c?['id_number'] ?? '');
    _creditLimit = TextEditingController(text: (c?['credit_limit'] ?? 0).toString());
    _notes = TextEditingController(text: c?['notes'] ?? '');
    _addressSearch = TextEditingController();
    _address1 = TextEditingController(text: c?['address_line1'] ?? '');
    _address2 = TextEditingController(text: c?['address_line2'] ?? '');
    _aptSuite = TextEditingController(text: c?['apt_suite'] ?? '');
    _city = TextEditingController(text: c?['city'] ?? '');
    _postalCode = TextEditingController(text: c?['postal_code'] ?? '');
    _country = TextEditingController(text: c?['country'] ?? 'CA');
    _provinceCode = c?['province_code'];
    _idType = c?['id_type'];
    _loadProvinces();
  }

  Future<void> _loadProvinces() async {
    final provider = context.read<ERPProvider>();
    final provinces = await provider.getProvinces();
    setState(() { _provinces = provinces; _loadingProvinces = false; });
  }

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
      _city.text = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'] ?? '';
      _postalCode.text = addr['postcode']?.toString().replaceAll(' ', '') ?? '';
      final prov = addr['state'] ?? '';
      final provCode = _matchProvinceCode(prov);
      if (provCode != null) _provinceCode = provCode;
      _country.text = 'CA';
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
    _tabCtrl.dispose();
    _firstName.dispose(); _lastName.dispose(); _company.dispose();
    _email.dispose(); _phone.dispose(); _idNumber.dispose();
    _creditLimit.dispose(); _notes.dispose();
    _addressSearch.dispose(); _address1.dispose(); _address2.dispose();
    _aptSuite.dispose(); _city.dispose(); _postalCode.dispose();
    _country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 750),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEditing ? 'Editar Cliente' : 'Nuevo Cliente',
                  style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                // Tabs
                TabBar(
                  controller: _tabCtrl,
                  tabs: const [
                    Tab(icon: Icon(Icons.person), text: 'Información'),
                    Tab(icon: Icon(Icons.location_on), text: 'Dirección'),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      // ═══ TAB INFO ═══
                      ListView(
                        children: [
                          Row(children: [
                            Expanded(child: TextFormField(
                              controller: _firstName,
                              decoration: const InputDecoration(labelText: 'Nombre *'),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(
                              controller: _lastName,
                              decoration: const InputDecoration(labelText: 'Apellido *'),
                              validator: (v) => v!.isEmpty ? 'Requerido' : null,
                            )),
                          ]),
                          TextFormField(controller: _company, decoration: const InputDecoration(labelText: 'Empresa')),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: DropdownButtonFormField<String>(
                              value: _idType,
                              decoration: const InputDecoration(labelText: 'Tipo de ID'),
                              items: const [
                                DropdownMenuItem(value: 'sin', child: Text('SIN')),
                                DropdownMenuItem(value: 'business_number', child: Text('Business Number')),
                                DropdownMenuItem(value: 'passport', child: Text('Pasaporte')),
                                DropdownMenuItem(value: 'drivers_license', child: Text('Driver\'s License')),
                                DropdownMenuItem(value: 'health_card', child: Text('Health Card')),
                                DropdownMenuItem(value: 'provincial_id', child: Text('Provincial ID')),
                                DropdownMenuItem(value: 'other', child: Text('Otro')),
                              ],
                              onChanged: (v) => setState(() => _idType = v),
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(
                              controller: _idNumber,
                              decoration: const InputDecoration(labelText: 'Número de Documento'),
                            )),
                          ]),
                          Row(children: [
                            Expanded(child: TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Teléfono'))),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(child: TextFormField(
                              controller: _creditLimit,
                              decoration: const InputDecoration(labelText: 'Límite de Crédito', prefixText: 'C\$ '),
                              keyboardType: TextInputType.number,
                            )),
                          ]),
                          TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Notas')),
                        ],
                      ),
                      // ═══ TAB DIRECCIÓN ═══
                      ListView(
                        children: [
                          // Nominatim search
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
                          Row(children: [
                            Expanded(child: TextFormField(controller: _address2, decoration: const InputDecoration(labelText: 'Dirección Línea 2'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(controller: _aptSuite, decoration: const InputDecoration(labelText: 'Apto / Suite'))),
                          ]),
                          Row(children: [
                            Expanded(child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'Ciudad'))),
                            const SizedBox(width: 12),
                            Expanded(child: _loadingProvinces
                                ? const LinearProgressIndicator()
                                : DropdownButtonFormField<String>(
                                    value: _provinceCode,
                                    isDense: true,
                                    decoration: const InputDecoration(labelText: 'Provincia'),
                                    items: _provinces.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(
                                      value: p['code'] as String,
                                      child: Tooltip(
                                        message: '${p['code']} - ${p['name']}',
                                        child: Text(p['code'] as String),
                                      ),
                                    )).toList(),
                                    onChanged: (v) => setState(() => _provinceCode = v),
                                  )),
                          ]),
                          Row(children: [
                            Expanded(child: TextFormField(
                              controller: _postalCode,
                              decoration: const InputDecoration(labelText: 'Código Postal', hintText: 'A1A 1A1'),
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: TextFormField(
                              controller: _country,
                              decoration: const InputDecoration(labelText: 'País'),
                            )),
                          ]),
                          const SizedBox(height: 16),
                          // Address preview
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
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _save, child: const Text('Guardar')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    if (_country.text.isNotEmpty) parts.add(_country.text);
    return parts.join('\n');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ERPProvider>();
    final data = {
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'company_name': _company.text.trim().isEmpty ? null : _company.text.trim(),
      'id_type': _idType,
      'id_number': _idNumber.text.trim().isEmpty ? null : _idNumber.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'address_line1': _address1.text.trim().isEmpty ? null : _address1.text.trim(),
      'address_line2': _address2.text.trim().isEmpty ? null : _address2.text.trim(),
      'apt_suite': _aptSuite.text.trim().isEmpty ? null : _aptSuite.text.trim(),
      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      'province_code': _provinceCode,
      'postal_code': _postalCode.text.trim().isEmpty ? null : _postalCode.text.trim().toUpperCase(),
      'country': _country.text.trim().isEmpty ? 'CA' : _country.text.trim(),
      'credit_limit': double.tryParse(_creditLimit.text) ?? 0,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };

    if (isEditing) {
      await provider.updateCustomer(widget.customer!['id'], data);
    } else {
      await provider.insertCustomer(data);
    }
    if (mounted) Navigator.pop(context);
  }
}
