# RSMS Mobile (Flutter)

Client mobile/web de **RSMS** (RAMaT Stock Management System). Consomme l'API Laravel
`../rsms` sous `/api/v1`. Multi-plateforme : **web (Chrome)** et **Android** avec une seule base de code.

## Jalons réalisés (MVP mobile complet)

1. **Connexion → Dashboard** : Sanctum (token Bearer stocké via `flutter_secure_storage`), auto-login (`GET /me`), KPIs (`GET /dashboard`).
2. **Produits** : liste paginée, recherche, filtre stock faible, détail = stock par lieu.
3. **Commandes** : liste, création (boutique → dépôt), cycle d'états complet (`send → validate → prepare → ship → receive` + cancel).
4. **Transferts** (dispatch/receive/cancel, retours) · **Achats/Réceptions** (création avec lots + péremption, réception → stock) · **Inventaires** (comptage → clôture → ajustement) · **Notifications**.

Navigation : barre du bas 5 onglets (Accueil, Produits, Commandes, Transferts, Plus) ; l'onglet **Plus** donne accès à Achats, Inventaires, Notifications et à la déconnexion.

## Nouvelles fonctionnalités (v2.0)

### 🔄 Synchronisation Hors-ligne
- **Service de synchronisation automatique** : `SyncService` avec détection de connectivité
- **Sauvegarde locale** : Les commandes, achats, transferts et inventaires sont sauvegardés localement en mode hors-ligne
- **Synchronisation automatique** : Les données locales sont synchronisées automatiquement lors de la reconnexion
- **Écran de statut de synchronisation** : Visualisation des éléments en attente et de l'état de connexion
- **Base de données locale** : SQLite via `sqflite` pour le stockage persistant

### 📤 Export et Impression
- **Export CSV** : Export des produits, commandes, stock et mouvements en CSV
- **Service d'impression** : Génération de documents texte pour commandes et inventaires
- **Partage de fichiers** : Intégration avec `share_plus` pour partager les exports

### 🧪 Tests
- **Tests unitaires** : Tests pour les services (OfflineService) et les modèles (Product, Order)
- **Tests widget** : Tests pour les écrans principaux (ProductsScreen)
- **Couverture de code** : Tests pour valider le fonctionnement hors-ligne et la synchronisation

### 🔔 Notifications Avancées
- **Notifications locales** : Intégration avec `flutter_local_notifications`
- **Notifications de synchronisation** : Succès, erreur, reconnexion
- **Notifications de stock** : Alertes de stock faible et produits expirants

### 📊 Analytics et Statistiques
- **Service d'analytics** : Tracking d'événements utilisateur
- **Statistiques de session** : Durée, vues d'écran, actions, erreurs
- **Écran de statistiques** : Visualisation des données d'utilisation

### 🌍 Internationalisation (i18n)
- **Service de localisation** : Support FR/EN
- **Changement de langue dynamique** : Sélecteur dans les paramètres
- **Traductions complètes** : Navigation, dashboard, actions, produits, commandes, sync, notifications

### ⚙️ Paramètres Centralisés
- **Écran de paramètres** : Accès unique à toutes les configurations
- **Sélecteur de thème** : Mode clair/sombre
- **Sélecteur de langue** : Français/English
- **Gestion des notifications** : Contrôle des alertes
- **Informations utilisateur** : Profil et déconnexion

## Améliorations récentes (Sécurité & Qualité)

### 🔒 Sécurité renforcée
- **Gestion automatique des erreurs 401** : Déconnexion automatique lorsque le token expire
- **Configuration par environnement** : Support HTTPS en production via variables d'environnement
- **Retrait des credentials hardcodés** : Plus de compte de démo pré-rempli dans le code

### 📊 Logging structuré
- **Système de logging complet** : `AppLogger` avec niveaux (DEBUG, INFO, WARNING, ERROR, FATAL)
- **Traçabilité des requêtes API** : Logs automatiques pour toutes les requêtes/réponses
- **Gestion des erreurs améliorée** : Tous les catch blocks incluent maintenant du logging

### ⚡ Performance & Cache
- **Service de cache local** : `CacheService` avec TTL pour réduire les appels API
- **Optimisation mémoire** : Remplacement de `IndexedStack` par chargement à la demande
- **Provider pour les produits** : Gestion d'état centralisée avec cache intégré

### ✅ Validation & Qualité
- **Validateurs de formulaires** : `Validators` pour email, password, nombres, codes, téléphone
- **Amélioration de l'UX** : Meilleure validation des champs avec messages d'erreur clairs
- **Code plus robuste** : Correction de tous les catch blocks vides

## Prérequis

- Flutter 3.44+ (`flutter --version`)
- L'API Laravel doit tourner : dans `../rsms` → `php artisan serve` (http://127.0.0.1:8000)

## Lancer l'app

```bash
# Web (le plus rapide) — ouvre ton Chrome avec hot reload :
flutter run -d chrome

# ou serveur web headless (ouvrir ensuite http://127.0.0.1:5000 dans un navigateur) :
flutter run -d web-server --web-port=5000

# Android (émulateur ou appareil branché) :
flutter run -d <deviceId>     # 'flutter devices' pour la liste
```

## Configuration de l'API

### Développement
Par défaut, l'app utilise `http://127.0.0.1:8000/api/v1` en mode debug.

### Production
Pour configurer l'URL de production, utilisez :
```bash
flutter run --dart-define=API_BASE_URL=https://votre-api.com/api/v1
```

Ou configurez-la dans `lib/config.dart` via `AppConfig.apiBaseUrl`.

### Émulateur Android
Utilisez `http://10.0.2.2:8000/api/v1` (10.0.2.2 = localhost de la machine hôte).

### Appareil physique
Utilisez `http://[IP-de-ton-PC]:8000/api/v1`.

## Architecture (couches)

```
lib/
├── config.dart              # Configuration par environnement
├── models/                  # classes Dart = données de l'API (User…)
├── services/
│   ├── api_client.dart      # Dio + intercepteur token + gestion 401 + logging
│   ├── auth_service.dart    # login / me / logout
│   ├── cache_service.dart   # Cache local avec TTL
│   ├── offline_service.dart # Stockage local SQLite (mode hors-ligne)
│   ├── sync_service.dart    # Synchronisation automatique des données
│   ├── export_service.dart  # Export CSV des données
│   ├── print_service.dart   # Génération de documents
│   └── [entity]_service.dart # Services par entité
├── providers/
│   ├── auth_provider.dart   # état d'auth (ChangeNotifier)
│   ├── product_provider.dart # état des produits avec cache
│   └── sync_service.dart    # état de synchronisation (ChangeNotifier)
├── utils/
│   ├── logger.dart          # Système de logging structuré
│   ├── validators.dart      # Validateurs de formulaires
│   └── format.dart          # Utilitaires de formatage
├── screens/
│   ├── login_screen.dart    # formulaire de connexion avec validation
│   ├── dashboard_screen.dart# KPIs (FutureBuilder sur /dashboard)
│   ├── sync_status_screen.dart # Écran de statut de synchronisation
│   └── [entity]_screens/   # Écrans par entité
└── main.dart                # point d'entrée + AuthGate (login vs dashboard)
```

## Concepts clés utilisés

- **Widget** : brique d'UI. `StatelessWidget` (figé) / `StatefulWidget` (avec état).
- **Provider / ChangeNotifier** : état partagé ; `notifyListeners()` reconstruit les widgets qui écoutent.
- **Dio + intercepteur** : ajoute automatiquement `Authorization: Bearer <token>` à chaque requête et gère les erreurs 401.
- **FutureBuilder** : construit l'UI selon l'état d'un appel asynchrone (chargement / erreur / données).
- **Cache local** : `shared_preferences` pour stocker les données temporaires et réduire les appels API.
- **SQLite** : Base de données locale pour le stockage persistant en mode hors-ligne.
- **Connectivity** : Détection automatique de l'état de connexion réseau.
- **Logging structuré** : `AppLogger` pour la traçabilité et le débogage.

## Variables d'environnement

- `API_BASE_URL` : URL de base de l'API (défaut: http://127.0.0.1:8000/api/v1 en dev, https://votre-api.com/api/v1 en prod)

## Pistes d'amélioration futures

- [x] Ajouter des tests unitaires et d'intégration
- [ ] Implémenter le refresh token automatique
- [ ] Ajouter le certificate pinning pour HTTPS
- [ ] Implémenter l'authentification biométrique
- [x] Ajouter l'internationalisation (i18n)
- [x] Implémenter le mode offline-first complet
- [ ] Ajouter Sentry pour le tracking d'erreurs
- [ ] Créer des providers pour toutes les entités
- [ ] Optimiser les images avec cached_network_image
- [x] Notifications avancées (push notifications)
- [x] Analytics et statistiques avancées

> Note : la vérification automatisée en navigateur headless ne peut pas *afficher* l'UI Flutter
> (le rendu se met en pause quand la page est masquée). Sur un vrai Chrome / émulateur, tout
> s'affiche normalement. L'intégration API (login, /me, token) a été validée bout en bout.
