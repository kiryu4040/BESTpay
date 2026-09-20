import 'package:crypto/crypto.dart';

import '../../application/catalog/content_hasher.dart';

/// SHA-256 implementation that hashes the original file bytes.
final class Sha256ContentHasher implements ContentHasher {
  const Sha256ContentHasher();

  @override
  String sha256Hex(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }
}
