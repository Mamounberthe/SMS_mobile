import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/order.dart';
import '../services/api_client.dart';
import '../services/offline_service.dart';
import '../services/order_service.dart';
import '../services/export_service.dart';
import '../theme.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/page_header.dart';
import 'create_order_screen.dart';
import 'order_detail_screen.dart';

/// Commandes — corps hébergé dans AppShell (pas de Scaffold propre).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrderService _service;
  final List<Order> _orders = [];
  bool _loading = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  String? _statusFilter;
  final List<String> _availableStatuses = ['sent', 'received', 'cancelled'];
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _service = OrderService(context.read<ApiClient>());
    _load(reset: true);
    
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 1;
        _orders.clear();
      }
    });
    try {
      final result = await _service.list(page: _page, status: _statusFilter);
      if (mounted) {
        setState(() {
          _orders.addAll(result.items);
          _lastPage = result.lastPage;
        });
      }
      // Mettre à jour le cache pour usage hors-ligne
      if (_page == 1) {
        final offline = context.read<OfflineService>();
        await offline.cacheOrders(result.items);
      }
    } catch (e) {
      // En cas d'erreur, essayer de charger depuis le cache
      if (_page == 1 && _orders.isEmpty) {
        try {
          final offline = context.read<OfflineService>();
          final cached = await offline.getCachedOrders();
          if (cached.isNotEmpty) {
            setState(() {
              _orders.addAll(cached);
              _lastPage = 1;
              _error = null;
            });
            return;
          }
        } catch (_) {
          // Ignorer les erreurs de cache
        }
      }
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _setStatusFilter(String? status) {
    setState(() => _statusFilter = status);
    _load(reset: true);
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _lastPage) return;
    _page++;
    await _load();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const CreateOrderScreen()));
    if (created == true) _load(reset: true);
  }

  Future<void> _openDetail(Order order) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)));
    _load(reset: true);
  }

  Future<void> _exportOrders() async {
    if (_orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune commande à exporter')),
      );
      return;
    }
    try {
      final exportService = ExportService();
      await exportService.exportOrders(_orders);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'export: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.xl, Insets.xl, 0),
            child: PageHeader(
              title: 'Commandes',
              actions: [
                IconButton.filledTonal(
                  tooltip: 'Exporter en CSV',
                  icon: const Icon(Icons.download),
                  onPressed: _exportOrders,
                ),
                FilledButton.icon(
                  onPressed: _openCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle'),
                ),
              ],
            ),
          ),
          // Status filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xl, vertical: Insets.md),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusChip(null, 'Tous'),
                  const SizedBox(width: Insets.sm),
                  ..._availableStatuses.map((status) => 
                    Padding(
                      padding: const EdgeInsets.only(right: Insets.sm),
                      child: _buildStatusChip(status, _statusLabel(status)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status, String label) {
    final isSelected = _statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _setStatusFilter(status),
      selectedColor: AppColors.brand.withValues(alpha: 0.2),
      checkmarkColor: AppColors.brand,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.brand : AppSurface.of(context).text,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status) {
      'sent' => 'Envoyée',
      'received' => 'Reçue',
      'cancelled' => 'Annulée',
      _ => status,
    };
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _orders.isEmpty) {
      return const SkeletonList();
    }
    if (_error != null && _orders.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off,
        message: _error!,
        actionLabel: 'Réessayer',
        onAction: () => _load(reset: true),
      );
    }
    if (_orders.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'Aucune commande.',
        actionLabel: 'Nouvelle commande',
        onAction: _openCreate,
      );
    }

    final s = AppSurface.of(context);
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.lg, Insets.xl, Insets.xl),
        children: [
          ResponsiveWrap(children: [for (final o in _orders) _orderCard(o, s)]),
          const SizedBox(height: Insets.md),
          _footer(),
        ],
      ),
    );
  }

  Widget _orderCard(Order o, AppSurface s) {
    return AppCard(
      onTap: () => _openDetail(o),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.brand),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.reference, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(o.storeName ?? 'Boutique #${o.storeId}', style: TextStyle(color: s.muted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          OrderStatusChip(status: o.status),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_page < _lastPage) {
      return Padding(
        padding: const EdgeInsets.only(top: Insets.sm),
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : OutlinedButton(
                  onPressed: () {
                    _page++;
                    _load();
                  },
                  child: const Text('Charger plus'),
                ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
