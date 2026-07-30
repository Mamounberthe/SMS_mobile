import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../services/api_client.dart';
import '../services/product_service.dart';
import '../services/reference_service.dart';
import '../services/offline_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

/// Formulaire de création / édition d'un produit.
class ProductFormScreen extends StatefulWidget {
  final Product? product; // null = création
  const ProductFormScreen({super.key, this.product});

  bool get isEdit => product != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  late final ProductService _service;
  late final ReferenceService _ref;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _code;
  late final TextEditingController _reference;
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _purchase;
  late final TextEditingController _sale;
  late final TextEditingController _minStock;
  late final TextEditingController _unit;

  List<Category> _categories = [];
  List<Supplier> _suppliers = [];
  int? _categoryId;
  int? _supplierId;
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = ProductService(context.read<ApiClient>());
    _ref = ReferenceService(context.read<ApiClient>(), context.read<OfflineService>());
    final p = widget.product;
    _code = TextEditingController(text: p?.code ?? '');
    _reference = TextEditingController(text: p?.reference ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _purchase = TextEditingController(text: p != null ? '${p.purchasePrice}' : '');
    _sale = TextEditingController(text: p != null ? '${p.salePrice}' : '');
    _minStock = TextEditingController(text: p != null ? '${p.minStock}' : '0');
    _unit = TextEditingController(text: p?.unit ?? 'unité');
    _categoryId = p?.categoryId;
    _supplierId = p?.supplierId;
    _isActive = p?.isActive ?? true;
    _loadRefs();
  }

  @override
  void dispose() {
    for (final c in [_code, _reference, _name, _brand, _purchase, _sale, _minStock, _unit]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRefs() async {
    try {
      final cats = await _ref.categories();
      final sups = await _ref.suppliers();
      setState(() {
        _categories = cats;
        _suppliers = sups;
      });
    } catch (_) {
      // dropdowns vides si erreur
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisis une catégorie.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _saving = true);
    final data = <String, dynamic>{
      'code': _code.text.trim(),
      'reference': _reference.text.trim().isEmpty ? null : _reference.text.trim(),
      'name': _name.text.trim(),
      'category_id': _categoryId,
      'supplier_id': _supplierId,
      'brand': _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      'purchase_price': int.tryParse(_purchase.text.trim()) ?? 0,
      'sale_price': int.tryParse(_sale.text.trim()) ?? 0,
      'min_stock': int.tryParse(_minStock.text.trim()) ?? 0,
      'unit': _unit.text.trim().isEmpty ? 'unité' : _unit.text.trim(),
      'is_active': _isActive,
    };
    try {
      if (widget.isEdit) {
        await _service.update(widget.product!.id, data);
      } else {
        await _service.create(data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Modifier le produit' : 'Nouveau produit')),
      body: _loading
          ? const SkeletonList()
          : FormWrap(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: formPadding(context),
                  children: [
                AppCard(
                  child: Column(
                    children: [
                      _field(_name, 'Nom *', validator: _required),
                      const SizedBox(height: Insets.md),
                      _field(_code, 'Code *', validator: _required),
                      const SizedBox(height: Insets.md),
                      _field(_reference, 'Référence'),
                      const SizedBox(height: Insets.md),
                      DropdownButtonFormField<int>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(labelText: 'Catégorie *', prefixIcon: Icon(Icons.category)),
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                      const SizedBox(height: Insets.md),
                      DropdownButtonFormField<int?>(
                        initialValue: _supplierId,
                        decoration: const InputDecoration(labelText: 'Fournisseur', prefixIcon: Icon(Icons.business)),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('—')),
                          ..._suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (v) => setState(() => _supplierId = v),
                      ),
                      const SizedBox(height: Insets.md),
                      _field(_brand, 'Marque'),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.md),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _field(_purchase, "Prix d'achat (XOF)", number: true)),
                          const SizedBox(width: Insets.md),
                          Expanded(child: _field(_sale, 'Prix de vente (XOF)', number: true)),
                        ],
                      ),
                      const SizedBox(height: Insets.md),
                      Row(
                        children: [
                          Expanded(child: _field(_minStock, 'Stock minimum', number: true)),
                          const SizedBox(width: Insets.md),
                          Expanded(child: _field(_unit, 'Unité')),
                        ],
                      ),
                      SwitchListTile(
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        title: const Text('Produit actif'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.xxl),
              ],
            ),
          ),
        ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(widget.isEdit ? 'Enregistrer' : 'Créer le produit'),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool number = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    );
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Requis' : null;
}
