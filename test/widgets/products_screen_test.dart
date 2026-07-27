import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rsms_mobile/screens/products_screen.dart';
import 'package:rsms_mobile/services/api_client.dart';
import 'package:rsms_mobile/providers/auth_provider.dart';
import 'package:rsms_mobile/services/auth_service.dart';
import 'package:rsms_mobile/services/connectivity_service.dart';
import 'package:rsms_mobile/services/offline_service.dart';

void main() {
  group('ProductsScreen Widget Tests', () {
    testWidgets('should display products title', (WidgetTester tester) async {
      final apiClient = ApiClient();
      final authService = AuthService(apiClient);
      final connectivityService = ConnectivityService();
      final offlineService = OfflineService();
      final authProvider = AuthProvider(authService, apiClient, connectivityService, offlineService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: apiClient),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProductsScreen(),
            ),
          ),
        ),
      );

      expect(find.text('Produits'), findsOneWidget);
    });

    testWidgets('should display filter button', (WidgetTester tester) async {
      final apiClient = ApiClient();
      final authService = AuthService(apiClient);
      final connectivityService = ConnectivityService();
      final offlineService = OfflineService();
      final authProvider = AuthProvider(authService, apiClient, connectivityService, offlineService);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: apiClient),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProductsScreen(),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    });
  });
}
