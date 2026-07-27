import '../models/user.dart';
import 'api_client.dart';

/// Regroupe les appels d'authentification vers l'API.
class AuthService {
  final ApiClient api;
  AuthService(this.api);

  /// POST /login → stocke le token et renvoie l'utilisateur.
  Future<User> login(String email, String password) async {
    final res = await api.dio.post('/login', data: {
      'email': email,
      'password': password,
      'device_name': 'flutter',
    });
    await api.saveToken(res.data['token'] as String);
    // login renvoie user à plat ; on gère aussi le cas {data: {...}}.
    final userJson = (res.data['user']['data'] ?? res.data['user']) as Map<String, dynamic>;
    return User.fromJson(userJson);
  }

  /// GET /me → utilisateur courant (le token est ajouté par l'intercepteur).
  Future<User> me() async {
    final res = await api.dio.get('/me');
    final userJson = (res.data['data'] ?? res.data) as Map<String, dynamic>;
    return User.fromJson(userJson);
  }

  /// POST /logout → révoque le token côté serveur puis local.
  Future<void> logout() async {
    try {
      await api.dio.post('/logout');
    } finally {
      await api.clearToken();
    }
  }
}
