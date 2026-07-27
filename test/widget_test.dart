import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rsms_mobile/screens/login_screen.dart';

void main() {
  testWidgets("L'écran de connexion affiche le bouton", (tester) async {
    // On rend uniquement l'écran de connexion (pas besoin de l'API ici).
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
  });
}
