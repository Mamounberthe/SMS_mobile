import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/order_service.dart';
import 'services/purchase_service.dart';
import 'services/transfer_service.dart';
import 'services/inventory_service.dart';
import 'services/reference_service.dart';
import 'services/sync_service.dart';
import 'services/offline_service.dart';
import 'services/report_service.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';
import 'services/localization_service.dart';
import 'theme.dart';
import 'theme_controller.dart';
import 'widgets/app_shell.dart';

/// Point d'entrée de l'application (équivalent de public/index.php).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();

  final api = ApiClient();
  final offline = OfflineService();
  final connectivity = ConnectivityService();
  final notificationService = NotificationService(api);
  final analyticsService = AnalyticsService();
  final localizationService = LocalizationService();

  // Services d'entité (partagés : mêmes instances pour les écrans et la sync).
  final orderService = OrderService(api);
  final purchaseService = PurchaseService(api);
  final transferService = TransferService(api);
  final inventoryService = InventoryService(api);
  final referenceService = ReferenceService(api, offline);
  final reportService = ReportService(api);

  // Créer l'AuthProvider avant de configurer le callback 401.
  final authProvider = AuthProvider(
    AuthService(api),
    api,
    connectivity,
    offline,
  );

  // Configurer le callback 401 après création de l'AuthProvider.
  api.onUnauthorized = authProvider.forceLogout;

  // Initialiser les services.
  await analyticsService.initialize();
  await localizationService.initialize();

  runApp(
    // MultiProvider rend des objets disponibles à tout l'arbre de widgets.
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<OfflineService>.value(value: offline),
        ChangeNotifierProvider<ConnectivityService>.value(value: connectivity),
        Provider<ReferenceService>.value(value: referenceService),
        Provider<OrderService>.value(value: orderService),
        Provider<PurchaseService>.value(value: purchaseService),
        Provider<TransferService>.value(value: transferService),
        Provider<InventoryService>.value(value: inventoryService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<AnalyticsService>.value(value: analyticsService),
        ChangeNotifierProvider(create: (_) => localizationService),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => SyncService(
          api: api,
          offline: offline,
          connectivity: connectivity,
          orderService: orderService,
          purchaseService: purchaseService,
          transferService: transferService,
          inventoryService: inventoryService,
          reportService: reportService,
          notificationService: notificationService,
          analyticsService: analyticsService,
        )),
      ],
      child: const RsmsApp(),
    ),
  );
}

class RsmsApp extends StatelessWidget {
  const RsmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSMS',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: context.watch<ThemeController>().mode, // clair / sombre / système
      home: const AuthGate(),
    );
  }
}

/// "Portail" : affiche l'écran adapté à l'état de connexion.
/// `context.watch` = ce widget se reconstruit quand l'auth change.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return switch (auth.status) {
      AuthStatus.unknown => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.authenticated => const AppShell(),
      AuthStatus.unauthenticated => const LoginScreen(),
    };
  }
}
