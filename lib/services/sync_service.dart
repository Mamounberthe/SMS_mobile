import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'connectivity_service.dart';
import 'offline_service.dart';
import 'order_service.dart';
import 'purchase_service.dart';
import 'transfer_service.dart';
import 'inventory_service.dart';
import 'report_service.dart';
import 'notification_service.dart';
import 'analytics_service.dart';

/// Service de synchronisation pour gérer les données hors-ligne
/// et les synchroniser automatiquement lors de la reconnexion.
///
/// S'appuie sur [ConnectivityService] (source unique d'état réseau) plutôt que
/// sur `connectivity_plus` directement, afin d'éviter le bug de comparaison
/// `List<ConnectivityResult>` == enum et la duplication des subscriptions.
class SyncService extends ChangeNotifier {
  final ApiClient api;
  final OfflineService offline;
  final ConnectivityService connectivity;
  final OrderService orderService;
  final PurchaseService purchaseService;
  final TransferService transferService;
  final InventoryService inventoryService;
  final ReportService reportService;
  final NotificationService notificationService;
  final AnalyticsService analyticsService;

  SyncService({
    required this.api,
    required this.offline,
    required this.connectivity,
    required this.orderService,
    required this.purchaseService,
    required this.transferService,
    required this.inventoryService,
    required this.reportService,
    required this.notificationService,
    required this.analyticsService,
  }) {
    _initConnectivityListener();
  }

  bool _isSyncing = false;
  String? _lastSyncError;
  DateTime? _lastSyncTime;
  int _pendingCount = 0;

  bool get isSyncing => _isSyncing;
  /// En ligne ? Reflète l'état du [ConnectivityService] (source unique).
  bool get isOnline => connectivity.isOnline;
  String? get lastSyncError => _lastSyncError;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingCount => _pendingCount;

  VoidCallback? _connectivityListener;
  Timer? _syncTimer;

  void _initConnectivityListener() {
    // Réagir aux transitions offline → online via la source unique.
    bool wasOnline = connectivity.isOnline;
    _connectivityListener = () {
      final online = connectivity.isOnline;
      if (!wasOnline && online) {
        // Reconnexion → synchroniser automatiquement.
        if (kDebugMode) {
          print('Reconnexion détectée, synchronisation automatique...');
        }
        notificationService.notifyReconnected();
        syncAll();
      }
      wasOnline = online;
      notifyListeners();
    };
    connectivity.addListener(_connectivityListener!);

    // Vérifier périodiquement les éléments en attente.
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _updatePendingCount();
    });

    _updatePendingCount();
  }

  Future<void> _updatePendingCount() async {
    try {
      final orders = await offline.getPendingOrders();
      final purchases = await offline.getPendingPurchases();
      final transfers = await offline.getPendingTransfers();
      final inventories = await offline.getPendingInventories();

      _pendingCount = orders.length + purchases.length + transfers.length + inventories.length;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors du comptage des éléments en attente: $e');
      }
    }
  }

  /// Synchroniser tous les éléments en attente
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      return SyncResult(success: false, message: 'Synchronisation déjà en cours');
    }

    if (!connectivity.isOnline) {
      return SyncResult(success: false, message: 'Pas de connexion internet');
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    int syncedOrders = 0;
    int syncedPurchases = 0;
    int syncedTransfers = 0;
    int syncedInventories = 0;
    int failedOrders = 0;
    int failedPurchases = 0;
    int failedTransfers = 0;
    int failedInventories = 0;

    try {
      // Synchroniser les commandes
      final pendingOrders = await offline.getPendingOrders();
      for (final order in pendingOrders) {
        try {
          await _syncOrder(order);
          await offline.removePendingOrder(order['id'] as int);
          syncedOrders++;
        } catch (e) {
          failedOrders++;
          if (kDebugMode) {
            print('Erreur sync commande ${order['id']}: $e');
          }
        }
      }

      // Synchroniser les achats
      final pendingPurchases = await offline.getPendingPurchases();
      for (final purchase in pendingPurchases) {
        try {
          await _syncPurchase(purchase);
          await offline.removePendingPurchase(purchase['id'] as int);
          syncedPurchases++;
        } catch (e) {
          failedPurchases++;
          if (kDebugMode) {
            print('Erreur sync achat ${purchase['id']}: $e');
          }
        }
      }

      // Synchroniser les transferts
      final pendingTransfers = await offline.getPendingTransfers();
      for (final transfer in pendingTransfers) {
        try {
          await _syncTransfer(transfer);
          await offline.removePendingTransfer(transfer['id'] as int);
          syncedTransfers++;
        } catch (e) {
          failedTransfers++;
          if (kDebugMode) {
            print('Erreur sync transfert ${transfer['id']}: $e');
          }
        }
      }

      // Synchroniser les inventaires
      final pendingInventories = await offline.getPendingInventories();
      for (final inventory in pendingInventories) {
        try {
          await _syncInventory(inventory);
          await offline.removePendingInventory(inventory['id'] as int);
          syncedInventories++;
        } catch (e) {
          failedInventories++;
          if (kDebugMode) {
            print('Erreur sync inventaire ${inventory['id']}: $e');
          }
        }
      }

      _lastSyncTime = DateTime.now();
      await _updatePendingCount();

      // Rafraîchir les caches de lecture : au retour réseau on veut que les
      // listes (offline) reflètent les données serveur à jour, y compris les
      // éléments tout juste synchronisés.
      await _refreshCaches();

      final totalSynced = syncedOrders + syncedPurchases + syncedTransfers + syncedInventories;
      final totalFailed = failedOrders + failedPurchases + failedTransfers + failedInventories;

      // Notification de succès
      if (totalSynced > 0) {
        await notificationService.notifySyncSuccess(totalSynced);
      }

      // Notification d'erreur
      if (totalFailed > 0) {
        await notificationService.notifySyncError('$totalFailed élément(s) échoué(s)');
      }

      // Tracking analytics
      await analyticsService.trackSync(
        success: totalFailed == 0,
        syncedCount: totalSynced,
        failedCount: totalFailed,
      );

      return SyncResult(
        success: totalFailed == 0,
        message: totalSynced > 0
            ? '$totalSynced élément(s) synchronisé(s)'
            : 'Rien à synchroniser',
        syncedOrders: syncedOrders,
        syncedPurchases: syncedPurchases,
        syncedTransfers: syncedTransfers,
        syncedInventories: syncedInventories,
        failedOrders: failedOrders,
        failedPurchases: failedPurchases,
        failedTransfers: failedTransfers,
        failedInventories: failedInventories,
      );
    } catch (e) {
      _lastSyncError = e.toString();
      return SyncResult(
        success: false,
        message: 'Erreur de synchronisation: $e',
      );
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncOrder(Map<String, dynamic> order) async {
    final storeId = order['store_id'] as int;
    final items = _parseItems(order['items'] as String);
    final notes = order['notes'] as String?;

    await orderService.create(
      storeId: storeId,
      items: items,
      notes: notes,
    );
  }

  /// Après une synchronisation réussie, rafraîchit les caches de lecture pour
  /// que les listes (offline) reflètent les données serveur à jour.
  Future<void> _refreshCaches() async {
    try {
      final orders = await orderService.list();
      await offline.cacheOrders(orders.items);
    } catch (_) {}
    try {
      final purchases = await purchaseService.list();
      await offline.cachePurchases(purchases.items);
    } catch (_) {}
    try {
      final transfers = await transferService.list();
      await offline.cacheTransfers(transfers.items);
    } catch (_) {}
    try {
      final inventories = await inventoryService.list();
      await offline.cacheInventories(inventories.items);
    } catch (_) {}
    try {
      final stocks = await reportService.stocks(page: 1);
      await offline.cacheStocks(stocks.items);
    } catch (_) {}
  }

  Future<void> _syncPurchase(Map<String, dynamic> purchase) async {
    final supplierId = purchase['supplier_id'] as int?;
    final items = _parseItems(purchase['items'] as String);
    // `location_id` est désormais persisté côté offline (v2). Avant la v2,
    // il était absent → on retombe sur 1 (dépôt principal par défaut).
    final locationId = (purchase['location_id'] as int?) ?? 1;

    await purchaseService.create(
      supplierId: supplierId ?? 1,
      locationId: locationId,
      items: items,
    );
  }

  Future<void> _syncTransfer(Map<String, dynamic> transfer) async {
    final fromLocationId = transfer['from_location_id'] as int;
    final toLocationId = transfer['to_location_id'] as int;
    final items = _parseItems(transfer['items'] as String);
    // `is_return` est stocké en SQLite sous forme d'entier (0/1), pas un bool.
    // L'ancien code lisait un `bool` → était toujours faux ; les retours
    // étaient créés comme des transferts normaux.
    final rawReturn = transfer['is_return'];
    final isReturn = rawReturn is bool
        ? rawReturn
        : ((rawReturn is int) && rawReturn == 1);

    await transferService.create(
      fromLocationId: fromLocationId,
      toLocationId: toLocationId,
      items: items,
      isReturn: isReturn,
    );
  }

  Future<void> _syncInventory(Map<String, dynamic> inventory) async {
    final locationId = inventory['location_id'] as int;
    final type = inventory['type'] as String;
    final items = _parseInventoryItems(inventory['items'] as String);

    await inventoryService.create(
      locationId: locationId,
      type: type,
      productIds: items.map((item) => item['product_id'] as int).toList(),
    );
  }

  List<Map<String, dynamic>> _parseItems(String itemsString) {
    try {
      final decoded = jsonDecode(itemsString) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Erreur parsing items: $e');
      }
      return [];
    }
  }

  List<Map<String, dynamic>> _parseInventoryItems(String itemsString) {
    try {
      final decoded = jsonDecode(itemsString) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Erreur parsing inventory items: $e');
      }
      return [];
    }
  }

  /// Obtenir les détails des éléments en attente
  Future<PendingItems> getPendingItems() async {
    final orders = await offline.getPendingOrders();
    final purchases = await offline.getPendingPurchases();
    final transfers = await offline.getPendingTransfers();
    final inventories = await offline.getPendingInventories();

    return PendingItems(
      orders: orders,
      purchases: purchases,
      transfers: transfers,
      inventories: inventories,
    );
  }

  @override
  void dispose() {
    if (_connectivityListener != null) {
      connectivity.removeListener(_connectivityListener!);
    }
    _syncTimer?.cancel();
    super.dispose();
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int syncedOrders;
  final int syncedPurchases;
  final int syncedTransfers;
  final int syncedInventories;
  final int failedOrders;
  final int failedPurchases;
  final int failedTransfers;
  final int failedInventories;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedOrders = 0,
    this.syncedPurchases = 0,
    this.syncedTransfers = 0,
    this.syncedInventories = 0,
    this.failedOrders = 0,
    this.failedPurchases = 0,
    this.failedTransfers = 0,
    this.failedInventories = 0,
  });

  int get totalSynced => syncedOrders + syncedPurchases + syncedTransfers + syncedInventories;
  int get totalFailed => failedOrders + failedPurchases + failedTransfers + failedInventories;
}

class PendingItems {
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> purchases;
  final List<Map<String, dynamic>> transfers;
  final List<Map<String, dynamic>> inventories;

  PendingItems({
    required this.orders,
    required this.purchases,
    required this.transfers,
    required this.inventories,
  });

  int get total => orders.length + purchases.length + transfers.length + inventories.length;
}
