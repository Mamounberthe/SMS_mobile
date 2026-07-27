# Documentation des Services

## Table des matières
- [SyncService](#syncservice)
- [OfflineService](#offlineservice)
- [ExportService](#exportservice)
- [PrintService](#printservice)

---

## SyncService

### Description
Service de synchronisation pour gérer les données hors-ligne et les synchroniser automatiquement lors de la reconnexion.

### Fonctionnalités
- **Détection de connectivité** : Écoute les changements de connexion réseau via `connectivity_plus`
- **Synchronisation automatique** : Déclenche la synchronisation automatique lors de la reconnexion
- **Gestion des éléments en attente** : Compte et synchronise les commandes, achats, transferts et inventaires en attente
- **Vérification périodique** : Vérifie les éléments en attente toutes les 5 minutes

### Méthodes principales

#### `syncAll()`
Synchronise tous les éléments en attente avec l'API.

**Retour** : `Future<SyncResult>` contenant:
- `success` : booléen indiquant si la synchronisation a réussi
- `message` : message descriptif du résultat
- `syncedOrders`, `syncedPurchases`, `syncedTransfers`, `syncedInventories` : nombre d'éléments synchronisés par type
- `failedOrders`, `failedPurchases`, `failedTransfers`, `failedInventories` : nombre d'éléments échoués par type

#### `getPendingItems()`
Récupère tous les éléments en attente de synchronisation.

**Retour** : `Future<PendingItems>` contenant:
- `orders` : liste des commandes en attente
- `purchases` : liste des achats en attente
- `transfers` : liste des transferts en attente
- `inventories` : liste des inventaires en attente

### Propriétés
- `isSyncing` : indique si une synchronisation est en cours
- `isOnline` : indique si l'appareil est connecté
- `lastSyncError` : dernière erreur de synchronisation
- `lastSyncTime` : date de la dernière synchronisation
- `pendingCount` : nombre total d'éléments en attente

### Utilisation
```dart
final syncService = SyncService(
  api: apiClient,
  offline: offlineService,
  orderService: orderService,
  purchaseService: purchaseService,
  transferService: transferService,
  inventoryService: inventoryService,
);

// Synchroniser manuellement
final result = await syncService.syncAll();

// Obtenir les éléments en attente
final pending = await syncService.getPendingItems();
```

---

## OfflineService

### Description
Service pour la gestion hors-ligne avec SQLite. Stocke localement les produits et les éléments en attente de synchronisation.

### Tables de la base de données

#### `products`
Cache des produits pour usage hors-ligne.
- `id` : INTEGER PRIMARY KEY
- `code`, `reference`, `name`, `category_name`, `brand` : TEXT
- `purchase_price`, `sale_price`, `min_stock` : INTEGER
- `unit` : TEXT
- `is_active` : INTEGER
- `total_quantity` : INTEGER
- `cached_at` : INTEGER (timestamp)

#### `pending_orders`
Commandes en attente de synchronisation.
- `id` : INTEGER PRIMARY KEY AUTOINCREMENT
- `store_id` : INTEGER
- `items` : TEXT (JSON)
- `created_at` : INTEGER (timestamp)

#### `pending_purchases`
Achats en attente de synchronisation.
- `id` : INTEGER PRIMARY KEY AUTOINCREMENT
- `supplier_id` : INTEGER
- `items` : TEXT (JSON)
- `created_at` : INTEGER (timestamp)

#### `pending_transfers`
Transferts en attente de synchronisation.
- `id` : INTEGER PRIMARY KEY AUTOINCREMENT
- `from_location_id` : INTEGER
- `to_location_id` : INTEGER
- `items` : TEXT (JSON)
- `is_return` : INTEGER
- `created_at` : INTEGER (timestamp)

#### `pending_inventories`
Inventaires en attente de synchronisation.
- `id` : INTEGER PRIMARY KEY AUTOINCREMENT
- `location_id` : INTEGER
- `type` : TEXT
- `items` : TEXT (JSON)
- `created_at` : INTEGER (timestamp)

### Méthodes principales

#### Produits
- `cacheProducts(List<Product> products)` : Met en cache les produits
- `getCachedProducts()` : Récupère les produits en cache
- `hasCachedProducts()` : Vérifie si des produits sont en cache
- `clearCache()` : Vide le cache

#### Commandes en attente
- `addPendingOrder({required int storeId, required List<Map<String, dynamic>> items})`
- `getPendingOrders()`
- `removePendingOrder(int id)`

#### Achats en attente
- `addPendingPurchase({required int? supplierId, required List<Map<String, dynamic>> items})`
- `getPendingPurchases()`
- `removePendingPurchase(int id)`

#### Transferts en attente
- `addPendingTransfer({required int fromLocationId, required int toLocationId, required List<Map<String, dynamic>> items, bool isReturn = false})`
- `getPendingTransfers()`
- `removePendingTransfer(int id)`

#### Inventaires en attente
- `addPendingInventory({required int locationId, required String type, required List<Map<String, dynamic>> items})`
- `getPendingInventories()`
- `removePendingInventory(int id)`

### Utilisation
```dart
final offlineService = OfflineService();

// Mettre en cache des produits
await offlineService.cacheProducts(productList);

// Ajouter une commande en attente
await offlineService.addPendingOrder(
  storeId: 1,
  items: [
    {'product_id': 1, 'quantity': 10},
  ],
);

// Récupérer les commandes en attente
final pendingOrders = await offlineService.getPendingOrders();
```

---

## ExportService

### Description
Service pour l'export de données en CSV avec partage de fichiers.

### Fonctionnalités
- **Export CSV** : Génération de fichiers CSV pour produits, commandes, stock et mouvements
- **Partage de fichiers** : Intégration avec `share_plus` pour partager les exports
- **Échappement CSV** : Gestion automatique des caractères spéciaux

### Méthodes principales

#### `exportProducts(List<Product> products)`
Exporte la liste des produits en CSV.

**Colonnes** : Code, Référence, Nom, Catégorie, Marque, Prix Achat, Prix Vente, Stock Min, Unité, Actif, Stock Total

#### `exportOrders(List<Order> orders)`
Exporte la liste des commandes en CSV.

**Colonnes** : Référence, Boutique, Statut, Demandeur, Nombre Articles

#### `exportStock(List<Map<String, dynamic>> stock)`
Exporte les données de stock en CSV.

**Colonnes** : Produit, Lieu, Quantité Totale, Quantité Disponible

#### `exportMovements(List<Map<String, dynamic>> movements)`
Exporte l'historique des mouvements en CSV.

**Colonnes** : Produit, Type, Lieu, Utilisateur, Quantité, Date

#### `exportInventories(List<Inventory> inventories)`
Exporte la liste des inventaires en CSV.

**Colonnes** : Référence, Lieu, Type, Statut, Nombre Articles

### Utilisation
```dart
final exportService = ExportService();

// Exporter des produits
await exportService.exportProducts(productList);

// Exporter des commandes
await exportService.exportOrders(orderList);

// Exporter le stock
await exportService.exportStock(stockData);
```

---

## PrintService

### Description
Service pour l'impression de documents texte (format simple pour impression future).

### Fonctionnalités
- **Génération de documents texte** : Création de documents formatés pour commandes et inventaires
- **Partage de fichiers** : Intégration avec `share_plus` pour partager les documents

### Méthodes principales

#### `printOrder(Order order)`
Génère et partage un document texte pour une commande.

**Format** :
```
========================================
           COMMANDE DE STOCK
========================================

Référence: ORD001
Boutique: Store A
Statut: sent
Demandeur: John Doe

========================================
              ARTICLES
========================================

• Product A
  Demandé: 10
  Validé: 10
  Expédié: 0
  Reçu: 0

========================================
            FIN DU DOCUMENT
========================================
```

#### `printInventory(Inventory inventory)`
Génère et partage un document texte pour un inventaire.

**Format** :
```
========================================
           INVENTAIRE
========================================

Référence: INV001
Lieu: Warehouse A
Type: partial
Statut: open

========================================
              ARTICLES
========================================

• Product A
  Quantité Système: 100
  Quantité Comptée: 95
  Différence: -5
  Raison: Casse

========================================
            FIN DU DOCUMENT
========================================
```

### Utilisation
```dart
final printService = PrintService();

// Imprimer une commande
await printService.printOrder(order);

// Imprimer un inventaire
await printService.printInventory(inventory);
```

---

## Dépendances

Les services nécessitent les packages suivants (ajoutés dans `pubspec.yaml`):
- `sqflite` : Base de données locale
- `connectivity_plus` : Détection de connectivité
- `path_provider` : Accès aux répertoires système
- `share_plus` : Partage de fichiers

## Intégration dans l'application

Les services sont initialisés dans `main.dart` et disponibles via Provider:

```dart
MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
    Provider<OfflineService>.value(value: offline),
    ChangeNotifierProvider(create: (_) => SyncService(
      api: api,
      offline: offline,
      orderService: OrderService(api),
      purchaseService: PurchaseService(api),
      transferService: TransferService(api),
      inventoryService: InventoryService(api),
    )),
  ],
  child: const RsmsApp(),
)
```
