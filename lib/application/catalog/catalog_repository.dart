import 'package:bestpay/domain/catalog/catalog.dart';

/// Contract for loading the typed catalog.
///
/// Implementations must never throw: a missing, corrupt, or empty catalog is
/// represented as [Catalog.empty] so the app always starts (D-61).
abstract interface class CatalogRepository {
  Future<Catalog> load();
}


/// カタログ読み込みの失敗理由を画面に伝えるための任意のインターフェース。
///
/// カタログが空のとき「なぜ空なのか」が分からないと原因を追えないため、
/// 読み込めなかったファイル名を公開できる実装だけがこれを実装する。
abstract interface class CatalogDiagnosticsSource {
  /// 読み込めなかった（または形が不正だった）カタログファイル名。
  List<String> get missingFileNames;
}
