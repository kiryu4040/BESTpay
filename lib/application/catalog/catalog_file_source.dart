import '../../core/result/app_result.dart';

/// Immutable bytes returned by a catalog file source.
final class CatalogFileData {
  CatalogFileData({
    required this.fileName,
    required List<int> bytes,
  }) : bytes = List<int>.unmodifiable(bytes);

  final String fileName;
  final List<int> bytes;
}

/// Port for reading one catalog file without exposing a file-system API.
abstract interface class CatalogFileSource {
  Future<AppResult<CatalogFileData>> read(String fileName);
}
