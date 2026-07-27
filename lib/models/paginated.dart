/// Enveloppe générique d'une réponse paginée Laravel : { data: [...], meta: {...} }.
///
/// `T` est le type des éléments. On passe une fonction qui sait transformer
/// un élément JSON en objet Dart (ex. Product.fromJson).
class Paginated<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  Paginated({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final data = (json['data'] as List).cast<Map<String, dynamic>>();
    final meta = (json['meta'] ?? const {}) as Map<String, dynamic>;
    return Paginated<T>(
      items: data.map(itemFromJson).toList(),
      currentPage: (meta['current_page'] ?? 1) as int,
      lastPage: (meta['last_page'] ?? 1) as int,
      total: (meta['total'] ?? data.length) as int,
    );
  }
}
