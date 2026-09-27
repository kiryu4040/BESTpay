import 'dart:convert';

import 'package:bestpay/application/merchant/merchant_directory_repository.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/infrastructure/merchant/merchant_directory_decoder.dart';
import 'package:flutter/services.dart' show rootBundle;

/// アプリに同梱した `assets/data/*.json` から店舗一覧を読む。
///
/// 読み込みに失敗しても例外にせず空の一覧を返す（店舗が0件でも起動できる）。
final class AssetMerchantDirectoryRepository
    implements MerchantDirectoryRepository {
  const AssetMerchantDirectoryRepository({
    MerchantDirectoryDecoder decoder = const MerchantDirectoryDecoder(),
  }) : _decoder = decoder;

  final MerchantDirectoryDecoder _decoder;

  static const String _merchantsPath = 'assets/data/merchants.json';
  static const String _categoriesPath =
      'assets/data/merchant_categories.json';

  @override
  Future<MerchantDirectory> load() async {
    try {
      final merchants = await _readDocument(_merchantsPath);
      final categories = await _readDocument(_categoriesPath);

      return _decoder.decode(
        merchants: merchants,
        merchantCategories: categories,
      );
    } on Object {
      return MerchantDirectory.empty();
    }
  }

  Future<Map<String, Object?>> _readDocument(String path) async {
    final decoded = json.decode(await rootBundle.loadString(path));

    return (decoded as Map<dynamic, dynamic>).cast<String, Object?>();
  }
}
