/// Port for calculating a lowercase hexadecimal SHA-256 digest.
abstract interface class ContentHasher {
  String sha256Hex(List<int> bytes);
}
