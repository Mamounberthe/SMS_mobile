import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour l'internationalisation (i18n)
class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  static const String _keyLocale = 'app_locale';
  
  Locale _currentLocale = const Locale('fr');

  Locale get currentLocale => _currentLocale;
  bool get isFrench => _currentLocale.languageCode == 'fr';
  bool get isEnglish => _currentLocale.languageCode == 'en';

  /// Initialiser le service
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_keyLocale);
    
    if (localeCode != null) {
      _currentLocale = Locale(localeCode);
      notifyListeners();
    }
  }

  /// Changer la langue
  Future<void> setLocale(String languageCode) async {
    _currentLocale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, languageCode);
    notifyListeners();
  }

  /// Obtenir la traduction
  String translate(String key) {
    return _translations[key]?[_currentLocale.languageCode] ?? key;
  }

  /// Traductions
  static const Map<String, Map<String, String>> _translations = {
    // Navigation
    'home': {'fr': 'Accueil', 'en': 'Home'},
    'products': {'fr': 'Produits', 'en': 'Products'},
    'orders': {'fr': 'Commandes', 'en': 'Orders'},
    'transfers': {'fr': 'Transferts', 'en': 'Transfers'},
    'more': {'fr': 'Plus', 'en': 'More'},
    
    // Dashboard
    'dashboard': {'fr': 'Tableau de bord', 'en': 'Dashboard'},
    'stock_value': {'fr': 'Valeur du stock', 'en': 'Stock Value'},
    'total_products': {'fr': 'Total produits', 'en': 'Total Products'},
    'low_stock': {'fr': 'Stock faible', 'en': 'Low Stock'},
    'out_of_stock': {'fr': 'Rupture de stock', 'en': 'Out of Stock'},
    'expiring': {'fr': 'Expirant', 'en': 'Expiring'},
    'expired': {'fr': 'Expiré', 'en': 'Expired'},
    'pending_orders': {'fr': 'Commandes en attente', 'en': 'Pending Orders'},
    'pending_purchases': {'fr': 'Achats en attente', 'en': 'Pending Purchases'},
    
    // Actions
    'add': {'fr': 'Ajouter', 'en': 'Add'},
    'edit': {'fr': 'Modifier', 'en': 'Edit'},
    'delete': {'fr': 'Supprimer', 'en': 'Delete'},
    'save': {'fr': 'Enregistrer', 'en': 'Save'},
    'cancel': {'fr': 'Annuler', 'en': 'Cancel'},
    'confirm': {'fr': 'Confirmer', 'en': 'Confirm'},
    'search': {'fr': 'Rechercher', 'en': 'Search'},
    'filter': {'fr': 'Filtrer', 'en': 'Filter'},
    'export': {'fr': 'Exporter', 'en': 'Export'},
    'print': {'fr': 'Imprimer', 'en': 'Print'},
    'refresh': {'fr': 'Actualiser', 'en': 'Refresh'},
    
    // Common
    'loading': {'fr': 'Chargement...', 'en': 'Loading...'},
    'error': {'fr': 'Erreur', 'en': 'Error'},
    'success': {'fr': 'Succès', 'en': 'Success'},
    'no_data': {'fr': 'Aucune donnée', 'en': 'No data'},
    'retry': {'fr': 'Réessayer', 'en': 'Retry'},
    'close': {'fr': 'Fermer', 'en': 'Close'},
    
    // Auth
    'login': {'fr': 'Connexion', 'en': 'Login'},
    'logout': {'fr': 'Déconnexion', 'en': 'Logout'},
    'email': {'fr': 'Email', 'en': 'Email'},
    'password': {'fr': 'Mot de passe', 'en': 'Password'},
    'forgot_password': {'fr': 'Mot de passe oublié?', 'en': 'Forgot password?'},
    
    // Products
    'product': {'fr': 'Produit', 'en': 'Product'},
    'new_product': {'fr': 'Nouveau produit', 'en': 'New product'},
    'product_name': {'fr': 'Nom du produit', 'en': 'Product name'},
    'product_code': {'fr': 'Code produit', 'en': 'Product code'},
    'category': {'fr': 'Catégorie', 'en': 'Category'},
    'brand': {'fr': 'Marque', 'en': 'Brand'},
    'purchase_price': {'fr': 'Prix d\'achat', 'en': 'Purchase price'},
    'sale_price': {'fr': 'Prix de vente', 'en': 'Sale price'},
    'min_stock': {'fr': 'Stock minimum', 'en': 'Min stock'},
    'unit': {'fr': 'Unité', 'en': 'Unit'},
    'active': {'fr': 'Actif', 'en': 'Active'},
    
    // Orders
    'order': {'fr': 'Commande', 'en': 'Order'},
    'new_order': {'fr': 'Nouvelle commande', 'en': 'New order'},
    'order_reference': {'fr': 'Référence commande', 'en': 'Order reference'},
    'store': {'fr': 'Boutique', 'en': 'Store'},
    'status': {'fr': 'Statut', 'en': 'Status'},
    'requester': {'fr': 'Demandeur', 'en': 'Requester'},
    'items': {'fr': 'Articles', 'en': 'Items'},
    'quantity': {'fr': 'Quantité', 'en': 'Quantity'},
    
    // Sync
    'synchronization': {'fr': 'Synchronisation', 'en': 'Synchronization'},
    'sync_status': {'fr': 'Statut de synchronisation', 'en': 'Sync status'},
    'sync_now': {'fr': 'Synchroniser maintenant', 'en': 'Sync now'},
    'offline': {'fr': 'Hors ligne', 'en': 'Offline'},
    'online': {'fr': 'En ligne', 'en': 'Online'},
    'pending': {'fr': 'En attente', 'en': 'Pending'},
    'synced': {'fr': 'Synchronisé', 'en': 'Synced'},
    'sync_success': {'fr': 'Synchronisation réussie', 'en': 'Sync successful'},
    'sync_error': {'fr': 'Erreur de synchronisation', 'en': 'Sync error'},
    'saved_locally': {'fr': 'Sauvegardé localement', 'en': 'Saved locally'},
    'reconnected': {'fr': 'Connexion rétablie', 'en': 'Reconnected'},
    
    // Notifications
    'notifications': {'fr': 'Notifications', 'en': 'Notifications'},
    'mark_read': {'fr': 'Marquer comme lu', 'en': 'Mark as read'},
    'mark_all_read': {'fr': 'Tout marquer comme lu', 'en': 'Mark all as read'},
  };
}
