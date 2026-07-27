import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';

/// Client HTTP unique de l'application (basé sur Dio).
///
/// Rôle :
///  - centralise l'URL de base et l'en-tête Accept: application/json ;
///  - ajoute AUTOMATIQUEMENT le token Bearer à chaque requête (intercepteur) ;
///  - stocke le token de façon sécurisée (flutter_secure_storage).
class ApiClient {
  final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'rsms_token';
  void Function()? onUnauthorized;

  ApiClient({this.onUnauthorized})
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            headers: {'Accept': 'application/json'},
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ) {
    // Intercepteur : s'exécute avant CHAQUE requête pour injecter le token.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Gérer les erreurs 401 (token expiré/invalide)
          if (error.response?.statusCode == 401) {
            await clearToken();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  /// Extrait un message d'erreur lisible depuis une exception Dio.
  static String errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      // Erreurs de validation Laravel (422) : affiche le 1er détail précis.
      if (data is Map && data['errors'] is Map) {
        final errors = data['errors'] as Map;
        if (errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
      }
      if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return "Impossible de joindre le serveur. L'API est-elle démarrée ?";
      }
      return 'Erreur ${error.response?.statusCode ?? ''}'.trim();
    }
    // Erreur non-HTTP (ex. parsing) : on expose la cause réelle plutôt qu'un
    // message opaque, pour faciliter le diagnostic.
    return 'Une erreur inattendue est survenue : $error';
  }
}
