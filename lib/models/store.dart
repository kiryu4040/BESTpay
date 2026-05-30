class Store {
  final int? id;
  final String name;
  final String category;
  final String aliases;
  final String icon;
  bool isFavorite;

  Store({
    this.id,
    required this.name,
    required this.category,
    this.aliases = '',
    this.icon = '🏪',
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'aliases': aliases,
        'icon': icon,
        'is_favorite': isFavorite ? 1 : 0,
      };

  factory Store.fromMap(Map<String, dynamic> m) => Store(
        id: m['id'] as int?,
        name: m['name'] as String,
        category: m['category'] as String? ?? 'other',
        aliases: m['aliases'] as String? ?? '',
        icon: m['icon'] as String? ?? '🏪',
        isFavorite: (m['is_favorite'] as int?) == 1,
      );

  static String categoryLabel(String c) {
    const map = {
      'convenience': 'コンビニ',
      'restaurant': 'ファミレス／飲食',
      'cafe': 'カフェ',
      'drugstore': 'ドラッグストア',
      'supermarket': 'スーパー',
      'department': '百貨店',
      'ec': 'EC／ネット',
      'transit': '交通',
      'gas': 'ガソリン',
      'discount': '100均／ディスカウント',
      'other': 'その他',
    };
    return map[c] ?? c;
  }

  static String categoryIcon(String c) {
    const map = {
      'convenience': '🏪',
      'restaurant': '🍝',
      'cafe': '☕',
      'drugstore': '💊',
      'supermarket': '🛒',
      'department': '🏬',
      'ec': '📦',
      'transit': '🚊',
      'gas': '⛽',
      'discount': '💯',
      'other': '🏷️',
    };
    return map[c] ?? '🏷️';
  }
}
