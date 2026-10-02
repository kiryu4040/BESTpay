import 'package:bestpay/core/value_objects/money_yen.dart';
import 'package:bestpay/domain/merchant/merchant_directory.dart';
import 'package:bestpay/domain/records/transaction_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ranking_controller.dart';

/// 記録の入力・修正の結果（D-162）。
final class RecordEditorResult {
  const RecordEditorResult.saved(this.record) : deleted = false;

  const RecordEditorResult.deleted()
      : record = null,
        deleted = true;

  final TransactionRecord? record;
  final bool deleted;
}

/// 会計1件を入力・修正するシート（D-161・D-162）。
///
/// [initial] が null なら新規入力、指定すると既存の記録の修正になる。
/// 新規入力（年間タブの「＋」）では日時を尋ねず、今日の日付で記録する。
/// 修正のときは日時も変更でき、削除もできる。
///
/// 店舗は「その他」を選べる。選ばなかった場合も「その他」として扱い、
/// カードの基本還元率で計算する（店舗上乗せを適用しない）。
final class RecordEditorSheet extends StatefulWidget {
  const RecordEditorSheet({
    super.key,
    required this.controller,
    this.initial,
    this.allowDate = true,
  });

  final RankingController controller;
  final TransactionRecord? initial;
  final bool allowDate;

  @override
  State<RecordEditorSheet> createState() => _RecordEditorSheetState();
}

final class _RecordEditorSheetState extends State<RecordEditorSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial!.amountYen}',
  );
  late String _date = widget.initial?.occurredOn ?? _today();
  late MerchantEntry? _merchant = _initialMerchant();
  late bool _isOther = _initialIsOther();
  late String? _instrumentId = widget.initial?.instrumentId;
  String? _error;

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  MerchantEntry? _initialMerchant() {
    final id = widget.initial?.merchantId;
    if (id == null || id.isEmpty) {
      return null;
    }

    return widget.controller.merchantById(id);
  }

  bool _initialIsOther() {
    final record = widget.initial;
    if (record == null) {
      return false;
    }

    // 店舗が空、または店舗が見つからない記録は「その他」として扱う。
    return record.merchantId.isEmpty ||
        widget.controller.merchantById(record.merchantId) == null;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = widget.controller.catalog.paymentInstrumentsById.values
        .where((card) => widget.controller.isCardVisible(card.id.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          Text(
            widget.initial == null ? '会計を記録する' : '記録を修正する',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              labelText: '使った金額（円）',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.allowDate) ...<Widget>[
            Card(
              child: ListTile(
                leading: const Icon(Icons.event),
                title: const Text('日付'),
                subtitle: Text(_date),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront),
              title: Text(_storeLabel()),
              subtitle: _isOther
                  ? const Text('カードの基本還元率で計算します')
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickMerchant,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _instrumentId,
            decoration: const InputDecoration(
              labelText: '使ったカード',
              border: OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String>>[
              for (final card in cards)
                DropdownMenuItem<String>(
                  value: card.id.value,
                  child: Text(card.name),
                ),
            ],
            onChanged: (value) => setState(() => _instrumentId = value),
          ),
          const SizedBox(height: 8),
          Text(
            'お店を選ばないときは「その他」として、カードの基本還元率で計算します。'
            'カードも選ばないときは基準カード（みずほ楽天カード）で記録します。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.initial == null ? '記録する' : '保存する'),
          ),
          if (widget.initial != null) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('この記録を削除する'),
            ),
          ],
        ],
      ),
    );
  }

  String _storeLabel() {
    if (_isOther || _merchant == null) {
      return 'その他（店舗を指定しない）';
    }

    return _merchant!.name;
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _date = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  void _pickMerchant() {
    final controller = widget.controller;
    final categories = controller.orderedCategories;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'お店を選ぶ',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.more_horiz),
              title: const Text('その他'),
              subtitle: const Text('店舗を指定しない（カードの基本還元率）'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                setState(() {
                  _merchant = null;
                  _isOther = true;
                });
              },
            ),
            const Divider(height: 1),
            for (final category in categories) ...<Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  category.name,
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
              ),
              for (final merchant
                  in controller.merchantsInCategoryOrdered(category.id))
                ListTile(
                  title: Text(merchant.name),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() {
                      _merchant = merchant;
                      _isOther = false;
                    });
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final record = widget.initial;
    if (record == null) {
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('この記録を削除しますか？'),
        content: const Text('削除すると元に戻せません。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) {
      return;
    }

    Navigator.of(context).pop(const RecordEditorResult.deleted());
  }

  void _submit() {
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    if (amount < 1) {
      setState(() => _error = '1円以上の整数を入力してください。');
      return;
    }

    final merchant = _merchant;
    final merchantId = merchant?.id.value ?? '';
    final merchantName = merchant?.name ?? 'その他';

    var instrumentId = _instrumentId;
    if (instrumentId == null) {
      if (merchant != null) {
        final ranking = widget.controller.evaluateAtMerchant(
          merchant: merchant,
          amount: MoneyYen(amount),
        );
        instrumentId =
            ranking.bestEntry?.instrumentId.value ?? 'mizuho_rakuten_card';
      } else {
        // 店舗が無いときは基準カードで記録する（D-084）。
        instrumentId = 'mizuho_rakuten_card';
      }
    }

    Navigator.of(context).pop(
      RecordEditorResult.saved(
        TransactionRecord(
          id: widget.initial?.id ?? '${DateTime.now().microsecondsSinceEpoch}',
          occurredOn: _date,
          merchantId: merchantId,
          merchantName: merchantName,
          instrumentId: instrumentId,
          amountYen: amount,
        ),
      ),
    );
  }
}
