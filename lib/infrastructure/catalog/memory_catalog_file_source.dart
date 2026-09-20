import '../../application/catalog/catalog_file_source.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/app_error_code.dart';
import '../../core/result/app_result.dart';

/// In-memory catalog source for deterministic tests and composition.
final class MemoryCatalogFileSource implements CatalogFileSource {
  MemoryCatalogFileSource(Map<String, List<int>> files)
      : _files = Map<String, List<int>>.unmodifiable(
          files.map(
            (name, bytes) => MapEntry<String, List<int>>(
              name,
              List<int>.unmodifiable(bytes),
            ),
          ),
        );

  final Map<String, List<int>> _files;

  @override
  Future<AppResult<CatalogFileData>> read(String fileName) async {
    final bytes = _files[fileName];

    if (bytes == null) {
      return AppFailure<CatalogFileData>(
        AppError(
          code: AppErrorCode.catalogNotFound,
          operation: 'catalogFileSource.read',
          context: <String, Object?>{
            'fileName': fileName,
          },
        ),
      );
    }

    return AppSuccess<CatalogFileData>(
      CatalogFileData(
        fileName: fileName,
        bytes: bytes,
      ),
    );
  }
}
