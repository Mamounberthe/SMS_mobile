import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/stock.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/product_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/page_transitions.dart';
import '../widgets/app_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import 'product_form_screen.dart';

/// Détail d'un produit + son stock réparti par lieu.
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductService _service;
  late Future<List<Stock>> _stockFuture;

  @override
  void initState() {
    super.initState();
    _service = ProductService(context.read<ApiClient>());
    _stockFuture = _service.stockByLocation(widget.product.id);
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context)
        .push<bool>(SlidePageRoute(child: ProductFormScreen(product: widget.product)));
    if (saved == true && mounted) Navigator.of(context).pop(true); // remonte à la liste qui se rafraîchit
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Supprimer le produit ?',
      message: '« ${widget.product.name} » sera supprimé. Cette action est irréversible.',
      confirmLabel: 'Supprimer',
      danger: true,
    );
    if (!confirmed) return;
    
    try {
      await _service.delete(widget.product.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final s = AppSurface.of(context);
    final role = context.watch<AuthProvider>().user?.role;
    final canManage = role == 'admin' || role == 'director' || role == 'storekeeper';
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: canManage
            ? [
                IconButton(onPressed: _edit, icon: const Icon(Icons.edit_outlined), tooltip: 'Modifier'),
                IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline), tooltip: 'Supprimer'),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: [
          TwoPane(
            left: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Fiche produit ---
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(context, 'Code', p.code),
                      if (p.reference != null) _row(context, 'Référence', p.reference!),
                      if (p.categoryName != null) _row(context, 'Catégorie', p.categoryName!),
                      if (p.brand != null) _row(context, 'Marque', p.brand!),
                      _row(context, 'Prix de vente', fcfa(p.salePrice)),
                      _row(context, "Prix d'achat", fcfa(p.purchasePrice)),
                      _row(context, 'Stock minimum', '${p.minStock} ${p.unit}', isLast: true),
                    ],
                  ),
                ),
              ],
            ),
            right: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Stock par lieu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: s.text),
                ),
                const SizedBox(height: Insets.md),

                // --- Stock par lieu (chargé depuis l'API) ---
                FutureBuilder<List<Stock>>(
                  future: _stockFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: Insets.md),
                        child: SkeletonList(count: 3, padding: EdgeInsets.zero),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.only(top: Insets.lg),
                        child: EmptyState(
                          icon: Icons.cloud_off,
                          message: ApiClient.errorMessage(snapshot.error!),
                        ),
                      );
                    }
                    final stocks = snapshot.data!;
                    if (stocks.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: Insets.lg),
                        child: EmptyState(
                          icon: Icons.inventory_2_outlined,
                          message: 'Ce produit n\'a de stock dans aucun lieu.',
                        ),
                      );
                    }
                    final cards = <Widget>[];
                    for (var i = 0; i < stocks.length; i++) {
                      if (i > 0) cards.add(const SizedBox(height: Insets.md));
                      cards.add(_stockCard(context, stocks[i], p));
                    }
                    return Column(children: cards);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockCard(BuildContext context, Stock stock, Product p) {
    final s = AppSurface.of(context);
    final low = stock.quantity <= p.minStock;
    final isWarehouse = stock.location?.isWarehouse == true;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(
              isWarehouse ? Icons.warehouse : Icons.store,
              color: AppColors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stock.location?.name ?? 'Lieu #${stock.locationId}',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: s.text),
                ),
                if (stock.reservedQuantity > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Réservé : ${stock.reservedQuantity} · Dispo : ${stock.available}',
                    style: TextStyle(color: s.muted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${stock.quantity} ${p.unit}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: low ? Colors.orange.shade800 : s.text,
                ),
              ),
              if (low) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange.shade800),
                    const SizedBox(width: 2),
                    Text('Stock bas',
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool isLast = false}) {
    final s = AppSurface.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : Insets.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: s.muted))),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: s.text)),
          ),
        ],
      ),
    );
  }
}
