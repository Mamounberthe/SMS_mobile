import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/order.dart';
import '../models/inventory.dart';

/// Service pour l'impression de documents en PDF
class PrintService {
  /// Imprimer une commande
  Future<void> printOrder(Order order) async {
    final pdfContent = _generateOrderPdf(order);
    final file = await _savePdf('commande-${order.reference}', pdfContent);
    await Share.shareXFiles([XFile(file.path)], text: 'Commande ${order.reference}');
  }

  /// Imprimer un inventaire
  Future<void> printInventory(Inventory inventory) async {
    final pdfContent = _generateInventoryPdf(inventory);
    final file = await _savePdf('inventaire-${inventory.reference}', pdfContent);
    await Share.shareXFiles([XFile(file.path)], text: 'Inventaire ${inventory.reference}');
  }

  /// Générer le contenu PDF pour une commande
  String _generateOrderPdf(Order order) {
    final buffer = StringBuffer();
    
    buffer.writeln('========================================');
    buffer.writeln('           COMMANDE DE STOCK');
    buffer.writeln('========================================');
    buffer.writeln('');
    buffer.writeln('Référence: ${order.reference}');
    buffer.writeln('Boutique: ${order.storeName ?? "N/A"}');
    buffer.writeln('Statut: ${order.status}');
    buffer.writeln('Demandeur: ${order.requesterName ?? "N/A"}');
    buffer.writeln('');
    buffer.writeln('========================================');
    buffer.writeln('              ARTICLES');
    buffer.writeln('========================================');
    buffer.writeln('');
    
    for (final item in order.items) {
      buffer.writeln('• ${item.productName ?? "N/A"}');
      buffer.writeln('  Demandé: ${item.quantityRequested}');
      buffer.writeln('  Validé: ${item.quantityValidated ?? "N/A"}');
      buffer.writeln('  Expédié: ${item.quantityShipped ?? "N/A"}');
      buffer.writeln('  Reçu: ${item.quantityReceived ?? "N/A"}');
      buffer.writeln('');
    }
    
    buffer.writeln('========================================');
    buffer.writeln('            FIN DU DOCUMENT');
    buffer.writeln('========================================');
    
    return buffer.toString();
  }

  /// Générer le contenu PDF pour un inventaire
  String _generateInventoryPdf(Inventory inventory) {
    final buffer = StringBuffer();
    
    buffer.writeln('========================================');
    buffer.writeln('           INVENTAIRE');
    buffer.writeln('========================================');
    buffer.writeln('');
    buffer.writeln('Référence: ${inventory.reference}');
    buffer.writeln('Lieu: ${inventory.locationName ?? "N/A"}');
    buffer.writeln('Type: ${inventory.type}');
    buffer.writeln('Statut: ${inventory.status}');
    buffer.writeln('');
    buffer.writeln('========================================');
    buffer.writeln('              ARTICLES');
    buffer.writeln('========================================');
    buffer.writeln('');
    
    for (final item in inventory.items) {
      buffer.writeln('• ${item.productName ?? "N/A"}');
      buffer.writeln('  Quantité Système: ${item.systemQuantity}');
      buffer.writeln('  Quantité Comptée: ${item.countedQuantity}');
      buffer.writeln('  Différence: ${item.difference}');
      if (item.reason != null && item.reason!.isNotEmpty) {
        buffer.writeln('  Raison: ${item.reason}');
      }
      buffer.writeln('');
    }
    
    buffer.writeln('========================================');
    buffer.writeln('            FIN DU DOCUMENT');
    buffer.writeln('========================================');
    
    return buffer.toString();
  }

  /// Sauvegarder le fichier PDF
  Future<File> _savePdf(String filename, String content) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/$filename-$timestamp.txt');
    await file.writeAsString(content);
    return file;
  }
}
