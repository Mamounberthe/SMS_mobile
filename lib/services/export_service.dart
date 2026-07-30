import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/product.dart';
import '../models/order.dart';
import '../models/inventory.dart';

/// Service pour l'export de données en CSV
class ExportService {
  /// Exporter les produits en CSV
  Future<String> exportProducts(List<Product> products) async {
    final buffer = StringBuffer();
    
    // En-têtes
    buffer.writeln('Code,Référence,Nom,Catégorie,Marque,Prix Achat,Prix Vente,Stock Min,Unité,Actif,Stock Total');
    
    // Données
    for (final product in products) {
      buffer.writeln(
        '${_escapeCsv(product.code)},'
        '${_escapeCsv(product.reference ?? '')},'
        '${_escapeCsv(product.name)},'
        '${_escapeCsv(product.categoryName ?? '')},'
        '${_escapeCsv(product.brand ?? '')},'
        '${product.purchasePrice},'
        '${product.salePrice},'
        '${product.minStock},'
        '${_escapeCsv(product.unit)},'
        '${product.isActive ? 'Oui' : 'Non'},'
        '${product.totalQuantity ?? 0}',
      );
    }
    
    return await _saveFile('produits', buffer.toString());
  }

  /// Exporter les commandes en CSV
  Future<String> exportOrders(List<Order> orders) async {
    final buffer = StringBuffer();
    
    // En-têtes
    buffer.writeln('Référence,Boutique,Statut,Demandeur,Nombre Articles');
    
    // Données
    for (final order in orders) {
      buffer.writeln(
        '${_escapeCsv(order.reference)},'
        '${_escapeCsv(order.storeName ?? '')},'
        '${_escapeCsv(order.status)},'
        '${_escapeCsv(order.requesterName ?? '')},'
        '${order.items.length}',
      );
    }
    
    return await _saveFile('commandes', buffer.toString());
  }

  /// Exporter les mouvements de stock en CSV
  Future<String> exportMovements(List<Map<String, dynamic>> movements) async {
    final buffer = StringBuffer();
    
    // En-têtes
    buffer.writeln('Produit,Type,Lieu,Utilisateur,Quantité,Date');
    
    // Données
    for (final movement in movements) {
      buffer.writeln(
        '${_escapeCsv(movement['product_name'] ?? '')},'
        '${_escapeCsv(movement['type'] ?? '')},'
        '${_escapeCsv(movement['location_name'] ?? '')},'
        '${_escapeCsv(movement['user_name'] ?? '')},'
        '${movement['quantity'] ?? 0},'
        '${_escapeCsv(movement['created_at'] ?? '')}',
      );
    }
    
    return await _saveFile('mouvements', buffer.toString());
  }

  /// Exporter le stock en CSV
  Future<String> exportStock(List<Map<String, dynamic>> stock) async {
    final buffer = StringBuffer();
    
    // En-têtes
    buffer.writeln('Produit,Lieu,Quantité Totale,Quantité Disponible');
    
    // Données
    for (final item in stock) {
      buffer.writeln(
        '${_escapeCsv(item['product_name'] ?? '')},'
        '${_escapeCsv(item['location_name'] ?? '')},'
        '${item['total_quantity'] ?? 0},'
        '${item['available_quantity'] ?? 0}',
      );
    }
    
    return await _saveFile('stock', buffer.toString());
  }

  /// Exporter les inventaires en CSV
  Future<String> exportInventories(List<Inventory> inventories) async {
    final buffer = StringBuffer();
    
    // En-têtes
    buffer.writeln('Référence,Lieu,Type,Statut,Nombre Articles');
    
    // Données
    for (final inventory in inventories) {
      buffer.writeln(
        '${_escapeCsv(inventory.reference)},'
        '${_escapeCsv(inventory.locationName ?? '')},'
        '${_escapeCsv(inventory.type)},'
        '${_escapeCsv(inventory.status)},'
        '${inventory.items.length}',
      );
    }
    
    return await _saveFile('inventaires', buffer.toString());
  }

  /// Échapper les valeurs CSV
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Sauvegarder le fichier et partager
  Future<String> _saveFile(String prefix, String content) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/$prefix-$timestamp.csv');
    await file.writeAsString(content);
    
    // Partager le fichier
    await Share.shareXFiles([XFile(file.path)], text: 'Export RSMS - $prefix');
    
    return file.path;
  }
}
