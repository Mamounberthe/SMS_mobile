import '../models/comment.dart';
import 'api_client.dart';

/// Service pour gérer les commentaires sur les commandes
class CommentService {
  final ApiClient api;
  CommentService(this.api);

  /// Récupérer tous les commentaires d'une commande
  Future<List<Comment>> list(int orderId) async {
    final res = await api.dio.get('/orders/$orderId/comments');
    final data = (res.data['data'] as List).cast<Map<String, dynamic>>();
    return data.map(Comment.fromJson).toList();
  }

  /// Créer un nouveau commentaire
  Future<Comment> create({
    required int orderId,
    required String content,
  }) async {
    final res = await api.dio.post('/orders/$orderId/comments', data: {
      'content': content,
    });
    return Comment.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Mettre à jour un commentaire
  Future<Comment> update(int commentId, String content) async {
    final res = await api.dio.put('/comments/$commentId', data: {
      'content': content,
    });
    return Comment.fromJson(Map<String, dynamic>.from(res.data['data']));
  }

  /// Supprimer un commentaire
  Future<void> delete(int commentId) async {
    await api.dio.delete('/comments/$commentId');
  }
}
