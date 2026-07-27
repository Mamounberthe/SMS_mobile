import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/skeleton.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';

/// Notifications — corps hébergé dans AppShell (pas de Scaffold propre).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationService _service;
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = NotificationService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _service.list();
      setState(() => _items = res.items);
    } catch (e) {
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  IconData _iconFor(String type) => switch (type) {
        'low_stock' => Icons.trending_down,
        'out_of_stock' => Icons.error_outline,
        'expired' => Icons.dangerous,
        'near_expiry' => Icons.schedule,
        'order_status' => Icons.receipt_long,
        _ => Icons.notifications,
      };

  Color _colorFor(String type) => switch (type) {
        'low_stock' => Colors.orange,
        'out_of_stock' => Colors.red,
        'expired' => Colors.deepOrange,
        'near_expiry' => Colors.amber,
        _ => AppColors.brand,
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.xl, Insets.xl, 0),
            child: PageHeader(
              title: 'Notifications',
              actions: [
                TextButton(
                  onPressed: () async {
                    await _service.markAllRead();
                    _load();
                  },
                  child: const Text('Tout lire'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const SkeletonList();
    }
    if (_error != null && _items.isEmpty) {
      return EmptyState(icon: Icons.cloud_off, message: _error!, actionLabel: 'Réessayer', onAction: _load);
    }
    if (_items.isEmpty) {
      return const EmptyState(icon: Icons.notifications_none, message: 'Aucune notification.');
    }

    final s = AppSurface.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Insets.xl, Insets.lg, Insets.xl, Insets.xl),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
        itemBuilder: (context, i) {
          final n = _items[i];
          final color = _colorFor(n.type);
          return AppCard(
            padding: const EdgeInsets.all(Insets.md),
            onTap: n.read
                ? null
                : () async {
                    await _service.markRead(n.id);
                    _load();
                  },
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: n.read ? 0.08 : 0.15),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Icon(_iconFor(n.type), color: n.read ? s.muted : color, size: 20),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title,
                          style: TextStyle(
                              fontWeight: n.read ? FontWeight.w500 : FontWeight.w700, fontSize: 14)),
                      if (n.body != null) ...[
                        const SizedBox(height: 2),
                        Text(n.body!, style: TextStyle(color: s.muted, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                if (!n.read)
                  const Padding(
                    padding: EdgeInsets.only(left: Insets.sm),
                    child: Icon(Icons.circle, size: 9, color: Colors.blue),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
