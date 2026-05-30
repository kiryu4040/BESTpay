import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../providers/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _Section('テーマ'),
          RadioListTile<ThemeMode>(
            title: const Text('システム設定に従う'),
            value: ThemeMode.system,
            groupValue: state.themeMode,
            onChanged: (v) => state.setTheme(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('ライトモード'),
            value: ThemeMode.light,
            groupValue: state.themeMode,
            onChanged: (v) => state.setTheme(v!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('ダークモード'),
            value: ThemeMode.dark,
            groupValue: state.themeMode,
            onChanged: (v) => state.setTheme(v!),
          ),
          const _Section('データのバックアップ／復元'),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('JSONファイルにエクスポート'),
            subtitle: const Text('設定・お気に入り・カスタムルールを保存'),
            onTap: () => _export(context),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('JSONファイルからインポート'),
            subtitle: const Text('保存したバックアップを復元'),
            onTap: () => _import(context),
          ),
          const _Section('アプリ情報'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('BestPay'),
            subtitle: Text('バージョン 1.0.0\n2026年5月時点の還元情報を搭載'),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '※ 還元率は各社の公式情報を必ずご確認ください。条件・対象店舗は変更されることがあります。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    try {
      final data = await DatabaseHelper.instance.exportAll();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getApplicationDocumentsDirectory();
      final fname =
          'bestpay_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${dir.path}/$fname');
      await file.writeAsString(json);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('エクスポートしました:\n${file.path}'),
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エクスポート失敗: $e')));
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (res == null || res.files.single.path == null) return;
      final file = File(res.files.single.path!);
      final txt = await file.readAsString();
      final json = jsonDecode(txt) as Map<String, dynamic>;
      await DatabaseHelper.instance.importAll(json);
      if (context.mounted) {
        await context.read<AppState>().refresh();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('インポートが完了しました')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('インポート失敗: $e')));
      }
    }
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(text,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}
