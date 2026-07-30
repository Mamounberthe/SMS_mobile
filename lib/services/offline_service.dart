import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/purchase.dart';
import '../models/transfer.dart';
import '../models/inventory.dart';
import '../models/location.dart';
import '../models/supplier.dart';
import '../models/category.dart';
import '../models/user.dart';
import '../models/stock.dart';
import 'dart:convert';

/// Service pour la gestion hors-ligne avec SQLite.
///
/// Stratégie **offline-first** : toutes les listes lues en ligne sont mises
/// en cache pour permettre la consultation sans réseau. Les créations
/// effectuées hors-ligne sont placées dans des tables `pending_*` et
/// synchronisées par [SyncService] au retour du réseau.
///
/// Version 2 (ajouts) :
///  - `user` (cache de l'utilisateur courant pour restauration de session offline)
///  - `references` (lieux / fournisseurs / catégories) au format clé → JSON
///  - `purchases`, `transfers`, `inventories` (caches de lecture)
///  - migration de schéma via `onUpgrade` (DB version 1 → 2)
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rsms_offline.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createV1Tables(db);
    await _createV2Tables(db);
  }

  /// Tables de la version initiale (déjà déployée en v1).
  Future<void> _createV1Tables(Database db) async {
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY,
        code TEXT,
        reference TEXT,
        name TEXT,
        category_name TEXT,
        brand TEXT,
        purchase_price INTEGER,
        sale_price INTEGER,
        min_stock INTEGER,
        unit TEXT,
        is_active INTEGER,
        total_quantity INTEGER,
        cached_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_orders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id INTEGER,
        items TEXT,
        notes TEXT,
        retry_count INTEGER DEFAULT 0,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE orders(
        id INTEGER PRIMARY KEY,
        reference TEXT,
        store_id INTEGER,
        store_name TEXT,
        status TEXT,
        requester_name TEXT,
        items TEXT,
        cached_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_purchases(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER,
        location_id INTEGER,
        items TEXT,
        retry_count INTEGER DEFAULT 0,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_transfers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        from_location_id INTEGER,
        to_location_id INTEGER,
        items TEXT,
        is_return INTEGER,
        retry_count INTEGER DEFAULT 0,
        created_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_inventories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location_id INTEGER,
        type TEXT,
        items TEXT,
        retry_count INTEGER DEFAULT 0,
        created_at INTEGER
      )
    ''');

    // Dead letter queue for failed sync operations after max retries
    await db.execute('''
      CREATE TABLE IF NOT EXISTS dead_letter(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        data TEXT,
        error TEXT,
        created_at INTEGER
      )
    ''');
  }

  /// Tables ajoutées en v2 (offline-first étendu).
  Future<void> _createV2Tables(Database db) async {
    // Utilisateur courant (restauration de session hors-ligne).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS current_user(
        id INTEGER PRIMARY KEY,
        data TEXT,
        cached_at INTEGER
      )
    ''');

    // Références génériques (lieux / fournisseurs / catégories).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reference_cache(
        key TEXT PRIMARY KEY,
        data TEXT,
        cached_at INTEGER
      )
    ''');

    // Cache de lecture des achats.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases(
        id INTEGER PRIMARY KEY,
        reference TEXT,
        supplier_id INTEGER,
        supplier_name TEXT,
        status TEXT,
        total_amount INTEGER,
        items TEXT,
        cached_at INTEGER
      )
    ''');

    // Cache de lecture des transferts.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transfers(
        id INTEGER PRIMARY KEY,
        reference TEXT,
        from_location_id INTEGER,
        from_name TEXT,
        to_location_id INTEGER,
        to_name TEXT,
        status TEXT,
        is_return INTEGER,
        items TEXT,
        cached_at INTEGER
      )
    ''');

    // Cache de lecture des inventaires.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventories(
        id INTEGER PRIMARY KEY,
        reference TEXT,
        location_id INTEGER,
        location_name TEXT,
        type TEXT,
        status TEXT,
        items TEXT,
        cached_at INTEGER
      )
    ''');

    // Cache de lecture des stocks.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stocks(
        id INTEGER PRIMARY KEY,
        product_id INTEGER,
        product_name TEXT,
        location_id INTEGER,
        location_name TEXT,
        quantity INTEGER,
        available INTEGER,
        reserved_quantity INTEGER,
        cached_at INTEGER
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration incrémentale (1 → 2). On ajoute les nouvelles tables ET les
    // colonnes optionnelles des tables `pending_*` existantes, sans perte de
    // données (ALTER TABLE ADD COLUMN plutôt que recréation).
    if (oldVersion < 2) {
      await _createV2Tables(db);
      await _addColumnIfMissing(db, 'pending_orders', 'notes', 'TEXT');
      await _addColumnIfMissing(db, 'pending_purchases', 'location_id', 'INTEGER');
    }
  }

  /// Ajoute une colonne uniquement si elle n'existe pas déjà (idempotent).
  Future<void> _addColumnIfMissing(Database db, String table, String column, String type) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    final exists = cols.any((c) => (c['name'] as String?) == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  // ===== PRODUITS =====

  Future<void> cacheProducts(List<Product> products) async {
    final db = await database;
    final batch = db.batch();

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final product in products) {
      batch.insert(
        'products',
        {
          'id': product.id,
          'code': product.code,
          'reference': product.reference,
          'name': product.name,
          'category_name': product.categoryName,
          'brand': product.brand,
          'purchase_price': product.purchasePrice,
          'sale_price': product.salePrice,
          'min_stock': product.minStock,
          'unit': product.unit,
          'is_active': product.isActive ? 1 : 0,
          'total_quantity': product.totalQuantity,
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Product>> getCachedProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products');

    return maps.map((map) => Product(
      id: map['id'] as int,
      code: map['code'] as String,
      reference: map['reference'] as String?,
      name: map['name'] as String,
      categoryName: map['category_name'] as String?,
      brand: map['brand'] as String?,
      purchasePrice: map['purchase_price'] as int,
      salePrice: map['sale_price'] as int,
      minStock: map['min_stock'] as int,
      unit: map['unit'] as String,
      isActive: (map['is_active'] as int) == 1,
      totalQuantity: map['total_quantity'] as int?,
    )).toList();
  }

  Future<bool> hasCachedProducts() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    return (Sqflite.firstIntValue(result) ?? 0) > 0;
  }

  // ===== COMMANDES EN ATTENTE =====

  Future<void> addPendingOrder({
    required int storeId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final db = await database;
    await db.insert('pending_orders', {
      'store_id': storeId,
      'items': jsonEncode(items),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOrders() async {
    final db = await database;
    return await db.query('pending_orders');
  }

  Future<void> removePendingOrder(int id) async {
    final db = await database;
    await db.delete('pending_orders', where: 'id = ?', whereArgs: [id]);
  }

  // ===== ACHATS EN ATTENTE =====

  Future<void> addPendingPurchase({
    required int? supplierId,
    required List<Map<String, dynamic>> items,
    int? locationId,
  }) async {
    final db = await database;
    await db.insert('pending_purchases', {
      'supplier_id': supplierId,
      'items': jsonEncode(items),
      if (locationId != null) 'location_id': locationId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingPurchases() async {
    final db = await database;
    return await db.query('pending_purchases');
  }

  Future<void> removePendingPurchase(int id) async {
    final db = await database;
    await db.delete('pending_purchases', where: 'id = ?', whereArgs: [id]);
  }

  // ===== TRANSFERTS EN ATTENTE =====

  Future<void> addPendingTransfer({
    required int fromLocationId,
    required int toLocationId,
    required List<Map<String, dynamic>> items,
    bool isReturn = false,
  }) async {
    final db = await database;
    await db.insert('pending_transfers', {
      'from_location_id': fromLocationId,
      'to_location_id': toLocationId,
      'items': jsonEncode(items),
      'is_return': isReturn ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingTransfers() async {
    final db = await database;
    return await db.query('pending_transfers');
  }

  Future<void> removePendingTransfer(int id) async {
    final db = await database;
    await db.delete('pending_transfers', where: 'id = ?', whereArgs: [id]);
  }

  // ===== INVENTAIRES EN ATTENTE =====

  Future<void> addPendingInventory({
    required int locationId,
    required String type,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await database;
    await db.insert('pending_inventories', {
      'location_id': locationId,
      'type': type,
      'items': jsonEncode(items),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingInventories() async {
    final db = await database;
    return await db.query('pending_inventories');
  }

  Future<void> removePendingInventory(int id) async {
    final db = await database;
    await db.delete('pending_inventories', where: 'id = ?', whereArgs: [id]);
  }

  // ===== COMMANDES CACHE (lecture) =====

  Future<void> cacheOrders(List<Order> orders) async {
    final db = await database;
    final batch = db.batch();

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final order in orders) {
      batch.insert(
        'orders',
        {
          'id': order.id,
          'reference': order.reference,
          'store_id': order.storeId,
          'store_name': order.storeName,
          'status': order.status,
          'requester_name': order.requesterName,
          'items': jsonEncode(order.items.map((i) => {
            'id': i.id,
            'product_id': i.productId,
            'product_name': i.productName,
            'quantity_requested': i.quantityRequested,
          }).toList()),
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Order>> getCachedOrders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('orders');

    return maps.map((map) {
      final m = Map<String, dynamic>.from(map);
      if (m['items'] is String && (m['items'] as String).isNotEmpty) {
        try {
          final itemsRaw = jsonDecode(m['items'] as String) as List;
          m['items'] = itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {
          m['items'] = [];
        }
      } else {
        m['items'] = m['items'] ?? [];
      }
      return Order.fromJson(m);
    }).toList();
  }

  // ===== ACHATS CACHE (lecture) =====

  Future<void> cachePurchases(List<Purchase> purchases) async {
    final db = await database;
    final batch = db.batch();

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final p in purchases) {
      batch.insert(
        'purchases',
        {
          'id': p.id,
          'reference': p.reference,
          'supplier_id': p.supplierId,
          'supplier_name': p.supplierName,
          'status': p.status,
          'total_amount': p.totalAmount,
          'items': jsonEncode(p.items.map((i) => {
            'id': i.id,
            'product_id': i.productId,
            'product_name': i.productName,
            'quantity': i.quantity,
            'unit_price': i.unitPrice,
          }).toList()),
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Purchase>> getCachedPurchases() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('purchases');

    return maps.map((map) {
      final m = Map<String, dynamic>.from(map);
      if (m['items'] is String && (m['items'] as String).isNotEmpty) {
        try {
          final itemsRaw = jsonDecode(m['items'] as String) as List;
          m['items'] = itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {
          m['items'] = [];
        }
      } else {
        m['items'] = m['items'] ?? [];
      }
      return Purchase.fromJson(m);
    }).toList();
  }

  // ===== TRANSFERTS CACHE (lecture) =====

  Future<void> cacheTransfers(List<Transfer> transfers) async {
    final db = await database;
    final batch = db.batch();

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final t in transfers) {
      batch.insert(
        'transfers',
        {
          'id': t.id,
          'reference': t.reference,
          'from_location_id': t.fromLocationId,
          'from_name': t.fromName,
          'to_location_id': t.toLocationId,
          'to_name': t.toName,
          'status': t.status,
          'is_return': t.isReturn ? 1 : 0,
          'items': jsonEncode(t.items.map((i) => {
            'id': i.id,
            'product_id': i.productId,
            'product_name': i.productName,
            'quantity': i.quantity,
          }).toList()),
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Transfer>> getCachedTransfers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('transfers');

    return maps.map((map) {
      final m = Map<String, dynamic>.from(map);
      if (m['items'] is String && (m['items'] as String).isNotEmpty) {
        try {
          final itemsRaw = jsonDecode(m['items'] as String) as List;
          m['items'] = itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {
          m['items'] = [];
        }
      } else {
        m['items'] = m['items'] ?? [];
      }
      return Transfer.fromJson(m);
    }).toList();
  }

  // ===== INVENTAIRES CACHE (lecture) =====

  Future<void> cacheInventories(List<Inventory> inventories) async {
    final db = await database;
    final batch = db.batch();

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final inv in inventories) {
      batch.insert(
        'inventories',
        {
          'id': inv.id,
          'reference': inv.reference,
          'location_id': inv.locationId,
          'location_name': inv.locationName,
          'type': inv.type,
          'status': inv.status,
          'items': jsonEncode(inv.items.map((i) => {
            'id': i.id,
            'product_id': i.productId,
            'product_name': i.productName,
            'system_quantity': i.systemQuantity,
          }).toList()),
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Inventory>> getCachedInventories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('inventories');

    return maps.map((map) {
      final m = Map<String, dynamic>.from(map);
      if (m['items'] is String && (m['items'] as String).isNotEmpty) {
        try {
          final itemsRaw = jsonDecode(m['items'] as String) as List;
          m['items'] = itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } catch (_) {
          m['items'] = [];
        }
      } else {
        m['items'] = m['items'] ?? [];
      }
      return Inventory.fromJson(m);
    }).toList();
  }

  // ===== STOCKS CACHE (lecture) =====

  Future<void> cacheStocks(List<Stock> stocks) async {
    final db = await database;
    final batch = db.batch();

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final st in stocks) {
      batch.insert(
        'stocks',
        {
          'id': st.id,
          'product_id': st.productId,
          'product_name': st.productName,
          'location_id': st.locationId,
          'location_name': st.location?.name,
          'quantity': st.quantity,
          'available': st.available,
          'reserved_quantity': st.reservedQuantity,
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Stock>> getCachedStocks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('stocks');

    return maps.map((map) => Stock(
      id: map['id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String?,
      locationId: map['location_id'] as int,
      location: map['location_name'] != null 
          ? Location(
              id: map['location_id'] as int,
              name: map['location_name'] as String,
              code: '',
              type: 'warehouse',
            )
          : null,
      quantity: (map['quantity'] as int?) ?? 0,
      available: (map['available'] as int?) ?? 0,
      reservedQuantity: (map['reserved_quantity'] as int?) ?? 0,
    )).toList();
  }

  // ===== UTILISATEUR COURANT =====

  Future<void> cacheCurrentUser(User user) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'current_user',
      {
        'id': user.id,
        'data': jsonEncode({
          'id': user.id,
          'name': user.name,
          'email': user.email,
          'role': user.role,
          'role_label': user.roleLabel,
          'location_id': user.locationId,
          'is_active': user.isActive,
        }),
        'cached_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<User?> getCachedCurrentUser() async {
    final db = await database;
    final maps = await db.query('current_user', limit: 1);
    if (maps.isEmpty) return null;
    try {
      final dataStr = maps.first['data'];
      if (dataStr == null) return null;
      final data = jsonDecode(dataStr as String) as Map<String, dynamic>;
      return User.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCachedCurrentUser() async {
    final db = await database;
    await db.delete('current_user');
  }

  /// Purge la session utilisateur (token, user) mais CONSERVE les files d'attente.
  Future<void> clearSession() async {
    final db = await database;
    await db.delete('current_user');
    // On NE supprime PAS pending_orders, pending_purchases, pending_transfers, pending_inventories
  }

  // ===== DEAD LETTER QUEUE =====

  Future<void> moveToDeadLetter(String type, Map<String, dynamic> data, String error) async {
    final db = await database;
    await db.insert('dead_letter', {
      'type': type,
      'data': jsonEncode(data),
      'error': error,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getDeadLetters() async {
    final db = await database;
    return await db.query('dead_letter', orderBy: 'created_at DESC');
  }

  Future<void> clearDeadLetter(int id) async {
    final db = await database;
    await db.delete('dead_letter', where: 'id = ?', whereArgs: [id]);
  }

  // ===== RETRY COUNT =====

  Future<void> incrementRetryCount(String table, int id) async {
    final db = await database;
    await db.rawUpdate('UPDATE $table SET retry_count = retry_count + 1 WHERE id = ?', [id]);
  }

  Future<int> getRetryCount(String table, int id) async {
    final db = await database;
    final result = await db.query(table, columns: ['retry_count'], where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return 0;
    return (result.first['retry_count'] as int?) ?? 0;
  }

  // ===== RÉFÉRENCES (lieux / fournisseurs / catégories) =====

  Future<void> _cacheReference(String key, List<dynamic> items) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'reference_cache',
      {
        'key': key,
        'data': jsonEncode(items.map((i) {
          // Sérialisation via le modèle (chaque modèle expose fromJson/toJson
          // indirectement — on round-trip par les champs connus).
          if (i is Location) return {
            'id': i.id, 'name': i.name, 'code': i.code, 'type': i.type,
            'address': i.address, 'phone': i.phone, 'is_active': i.isActive,
          };
          if (i is Supplier) return {
            'id': i.id, 'name': i.name, 'contact_name': i.contactName,
            'phone': i.phone, 'email': i.email, 'address': i.address,
            'is_active': i.isActive,
          };
          if (i is Category) return {
            'id': i.id, 'name': i.name, 'description': i.description,
            'parent_id': i.parentId,
          };
          return <String, dynamic>{};
        }).toList()),
        'cached_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> _getReference(String key) async {
    final db = await database;
    final maps = await db.query('reference_cache', where: 'key = ?', whereArgs: [key], limit: 1);
    if (maps.isEmpty) return const [];
    try {
      final data = maps.first['data'];
      if (data == null) return const [];
      final decoded = jsonDecode(data as String) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> cacheLocations(List<Location> locations) => _cacheReference('locations', locations);
  Future<List<Location>> getCachedLocations() async =>
      (await _getReference('locations')).map(Location.fromJson).toList();

  Future<void> cacheSuppliers(List<Supplier> suppliers) => _cacheReference('suppliers', suppliers);
  Future<List<Supplier>> getCachedSuppliers() async =>
      (await _getReference('suppliers')).map(Supplier.fromJson).toList();

  Future<void> cacheCategories(List<Category> categories) => _cacheReference('categories', categories);
  Future<List<Category>> getCachedCategories() async =>
      (await _getReference('categories')).map(Category.fromJson).toList();

  // ===== NETTOYAGE =====

  Future<void> clearCache() async {
    final db = await database;
    await db.delete('products');
    await db.delete('orders');
    await db.delete('purchases');
    await db.delete('transfers');
    await db.delete('inventories');
    await db.delete('stocks');
    await db.delete('reference_cache');
    // On conserve `pending_*` (file d'attente) et `current_user` (session).
  }

  /// Vide tout (déconnexion) : caches + pending + user.
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('products');
    await db.delete('orders');
    await db.delete('purchases');
    await db.delete('transfers');
    await db.delete('inventories');
    await db.delete('stocks');
    await db.delete('reference_cache');
    await db.delete('current_user');
    await db.delete('pending_orders');
    await db.delete('pending_purchases');
    await db.delete('pending_transfers');
    await db.delete('pending_inventories');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
