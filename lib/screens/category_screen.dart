import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/store.dart';
import 'store_detail_screen.dart';

class CategoryScreen extends StatefulWidget {
  final String category;
  final String title;
  const CategoryScreen({super.key, required this.category, required this.title});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<Store> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list =
        await DatabaseHelper.instance.getStores(category: widget.category);
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('このカテゴリには店舗がありません'))
              : ListView.separated(
                  itemCount: _list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = _list[i];
                    return ListTile(
                      leading:
                          Text(s.icon, style: const TextStyle(fontSize: 28)),
                      title: Text(s.name),
                      trailing: s.isFavorite
                          ? const Icon(Icons.star, color: Colors.amber)
                          : const Icon(Icons.chevron_right),
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
