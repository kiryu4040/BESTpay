import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/store.dart';
import 'store_detail_screen.dart';

class StoreSearchScreen extends StatefulWidget {
  const StoreSearchScreen({super.key});
  @override
  State<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends State<StoreSearchScreen> {
  final _controller = TextEditingController();
  List<Store> _results = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  Future<void> _load(String kw) async {
    final db = DatabaseHelper.instance;
    final list = kw.trim().isEmpty
        ? await db.getStores()
        : await db.searchStores(kw.trim());
    if (!mounted) return;
    setState(() {
      _results = list;
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '店舗名・別名で検索',
            border: InputBorder.none,
          ),
          onChanged: _load,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _load('');
              },
            ),
        ],
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(child: Text('該当する店舗がありません'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final s = _results[i];
                    return ListTile(
                      leading:
                          Text(s.icon, style: const TextStyle(fontSize: 28)),
                      title: Text(s.name),
                      subtitle: Text(Store.categoryLabel(s.category)),
                      trailing: s.isFavorite
                          ? const Icon(Icons.star, color: Colors.amber)
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoreDetailScreen(storeId: s.id!),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
