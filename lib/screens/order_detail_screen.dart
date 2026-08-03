import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/comment.dart';
import '../models/order.dart';
import '../services/api_client.dart';
import '../services/comment_service.dart';
import '../services/order_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/responsive.dart';
import '../widgets/skeleton.dart';

/// Une action possible sur une commande (bouton).
typedef OrderAction = ({String label, String endpoint, IconData icon, Color color, bool destructive});

/// Actions disponibles selon le statut courant (cycle simplifié : En attente -> Expédiée -> Reçue).
List<OrderAction> _actionsFor(String status) {
  const ship = (label: 'Expédier', endpoint: 'ship', icon: Icons.local_shipping, color: Colors.blue, destructive: false);
  const receive = (label: 'Réceptionner', endpoint: 'receive', icon: Icons.check_circle, color: Colors.green, destructive: false);
  const cancel = (label: 'Annuler', endpoint: 'cancel', icon: Icons.cancel, color: Colors.red, destructive: true);

  return switch (status) {
    'pending' => [ship, cancel],
    'shipped' => [receive],
    _ => const [],
  };
}

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrderService _service;
  late final CommentService _commentService;
  Order? _order;
  List<Comment> _comments = [];
  bool _loading = true;
  bool _busy = false;
  bool _loadingComments = false;
  String? _error;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = OrderService(context.read<ApiClient>());
    _commentService = CommentService(context.read<ApiClient>());
    _load();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await _service.get(widget.orderId);
      setState(() => _order = o);
    } catch (e) {
      setState(() => _error = ApiClient.errorMessage(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await _commentService.list(widget.orderId);
      if (mounted) setState(() => _comments = comments);
    } catch (_) {
      // Silencieux - les commentaires sont optionnels
    } finally {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      final comment = await _commentService.create(
        orderId: widget.orderId,
        content: content,
      );
      setState(() {
        _comments.add(comment);
        _commentController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${ApiClient.errorMessage(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _runAction(OrderAction a) async {
    // L'expédition : confirmation simple
    if (a.endpoint == 'ship') {
      final ok = await confirmAction(context,
          title: 'Expédier la commande ?',
          message: 'Vous allez marquer la commande comme expédiée.',
          confirmLabel: 'Expédier',
          danger: a.destructive);
      if (!ok) return;
      await _shipOrder();
      return;
    }

    // La réception ouvre la feuille de réception (quantités ligne par ligne).
    if (a.endpoint == 'receive') {
      final ok = await confirmAction(context,
          title: 'Réceptionner la commande ?',
          message: 'Vous allez confirmer la réception et déplacer le stock.',
          confirmLabel: 'Réceptionner',
          danger: a.destructive);
      if (!ok) return;
      await _receiveOrder();
      return;
    }

    // Autres actions (annulation) : confirmation simple.
    if (a.destructive) {
      final ok = await confirmAction(context,
          title: '${a.label} la commande ?',
          message: 'Cette action est définitive.',
          confirmLabel: a.label,
          danger: true);
      if (!ok) return;
    }

    setState(() => _busy = true);
    try {
      final updated = await _service.action(widget.orderId, a.endpoint);
      setState(() => _order = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commande ${orderStatusInfo(updated.status).label.toLowerCase()}.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Expédition : marque la commande comme expédiée (sans déplacer le stock).
  Future<void> _shipOrder() async {
    setState(() => _busy = true);
    try {
      final updated = await _service.action(widget.orderId, 'ship');
      setState(() => _order = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commande ${orderStatusInfo(updated.status).label.toLowerCase()}.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Réception : ouvre une feuille où l'on ajuste les quantités réellement
  /// reçues par ligne, puis déplace le stock dépôt → boutique.
  Future<void> _receiveOrder() async {
    final o = _order;
    if (o == null) return;

    final received = await showModalBottomSheet<Map<int, int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => OrderReceptionSheet(order: o),
    );
    if (received == null) return; // annulé

    setState(() => _busy = true);
    try {
      final updated = await _service.receive(widget.orderId, received: received);
      setState(() => _order = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commande ${orderStatusInfo(updated.status).label.toLowerCase()}.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.errorMessage(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      appBar: AppBar(title: Text(o?.reference ?? 'Commande')),
      body: _loading
          ? const SkeletonList()
          : o == null
              ? EmptyState(
                  icon: _error != null ? Icons.cloud_off : Icons.search_off,
                  message: _error ?? 'Introuvable',
                  actionLabel: _error != null ? 'Réessayer' : null,
                  onAction: _error != null ? _load : null,
                )
              : _content(o),
      bottomNavigationBar: o == null ? null : _actionBar(o),
    );
  }

  Widget _content(Order o) {
    final s = AppSurface.of(context);
    return ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        TwoPane(
          leftFlex: 3,
          rightFlex: 2,
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.storeName ?? 'Boutique #${o.storeId}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (o.requesterName != null)
                            Padding(
                              padding: const EdgeInsets.only(top: Insets.xs),
                              child: Text('Demandé par ${o.requesterName}', style: TextStyle(color: s.muted)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    OrderStatusChip(status: o.status),
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
              Text('Articles', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: Insets.sm),
              for (final it in o.items) ...[
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(it.productName ?? 'Produit #${it.productId}'),
                    subtitle: Text(_quantitiesLabel(it)),
                    trailing: Text('x${it.quantityRequested}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                if (it != o.items.last) const SizedBox(height: Insets.sm),
              ],
            ],
          ),
          right: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Commentaires', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: Insets.sm),
              if (_loadingComments)
                const Center(child: CircularProgressIndicator())
              else if (_comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Insets.md),
                  child: Text('Aucun commentaire', style: TextStyle(color: s.muted)),
                )
              else
                ..._comments.map((comment) => _commentTile(comment, s)),
              const SizedBox(height: Insets.md),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Ajouter un commentaire...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                        ),
                        maxLines: 2,
                        minLines: 1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _addComment,
                      color: AppColors.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _commentTile(Comment comment, AppSurface s) {
    return AppCard(
      padding: const EdgeInsets.all(Insets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.person, color: AppColors.brand, size: 16),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(comment.authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(
                      _formatDate(comment.createdAt),
                      style: TextStyle(color: s.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(comment.content, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) return 'À l\'instant';
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Affiche l'avancement des quantités (demandé → validé → expédié → reçu).
  String _quantitiesLabel(OrderItem it) {
    final parts = <String>['Demandé : ${it.quantityRequested}'];
    if (it.quantityValidated != null) parts.add('Validé : ${it.quantityValidated}');
    if (it.quantityShipped != null) parts.add('Expédié : ${it.quantityShipped}');
    if (it.quantityReceived != null) parts.add('Reçu : ${it.quantityReceived}');
    return parts.join(' · ');
  }

  Widget? _actionBar(Order o) {
    final actions = _actionsFor(o.status);
    if (actions.isEmpty) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            for (final a in actions) ...[
              Expanded(
                child: a.destructive
                    ? OutlinedButton.icon(
                        onPressed: _busy ? null : () => _runAction(a),
                        icon: Icon(a.icon, color: a.color),
                        label: Text(a.label, style: TextStyle(color: a.color)),
                      )
                    : FilledButton.icon(
                        onPressed: _busy ? null : () => _runAction(a),
                        style: FilledButton.styleFrom(backgroundColor: a.color),
                        icon: _busy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(a.icon),
                        label: Text(a.label),
                      ),
              ),
              const SizedBox(width: Insets.sm),
            ],
          ],
        ),
      ),
    );
  }
}

/// Feuille de réception : ajuste les quantités reçues ligne par ligne avant de
/// valider la livraison (dépôt → boutique). Retourne, via `Navigator.pop`, un
/// map { order_item_id → quantité reçue }, ou `null` si annulé.
class OrderReceptionSheet extends StatefulWidget {
  final Order order;
  const OrderReceptionSheet({super.key, required this.order});

  @override
  State<OrderReceptionSheet> createState() => _OrderReceptionSheetState();
}

class _OrderReceptionSheetState extends State<OrderReceptionSheet> {
  late final Map<int, TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final it in widget.order.items)
        it.id: TextEditingController(text: '${it.quantityRequested}'),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setAllRequested() {
    setState(() {
      for (final it in widget.order.items) {
        _ctrls[it.id]!.text = '${it.quantityRequested}';
      }
    });
  }

  void _validate() {
    final received = <int, int>{};
    for (final it in widget.order.items) {
      final v = int.tryParse(_ctrls[it.id]!.text.trim()) ?? 0;
      received[it.id] = v < 0 ? 0 : v;
    }
    Navigator.of(context).pop(received);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);
    final maxH = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.md, Insets.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Réception de la commande',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Ajuste les quantités réellement reçues.',
                            style: TextStyle(fontSize: 12.5, color: s.muted)),
                      ],
                    ),
                  ),
                  TextButton(onPressed: _setAllRequested, child: const Text('Tout recevoir')),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: Insets.xl, vertical: Insets.md),
                itemCount: widget.order.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Insets.sm),
                itemBuilder: (context, i) {
                  final it = widget.order.items[i];
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.productName ?? 'Produit #${it.productId}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('Demandé : ${it.quantityRequested}',
                                style: TextStyle(fontSize: 12.5, color: s.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      SizedBox(
                        width: 92,
                        child: TextField(
                          controller: _ctrls[it.id],
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(labelText: 'Reçu', isDense: true),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(Insets.sm),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.brand),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Text('Le stock du dépôt sera déplacé vers la boutique.',
                              style: TextStyle(fontSize: 12, color: s.muted)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  FilledButton.icon(
                    onPressed: _validate,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Valider la réception'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
