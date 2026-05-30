import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_condition.dart';
import '../providers/app_state.dart';

class ConditionScreen extends StatelessWidget {
  const ConditionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = state.conditions;
    return Scaffold(
      appBar: AppBar(title: const Text('条件達成状況')),
      body: ListView(
        children: [
          _section('🥇 三井住友 Vポイントアッププログラム'),
          _DropdownTile(
            title: 'Oliveアカウント',
            value: c[UserConditionKeys.oliveAccount] ?? 'none',
            options: const [
              ('none', '未保有'),
              ('standard', '一般'),
              ('gold', 'ゴールド'),
            ],
            onChanged: (v) =>
                state.setCondition(UserConditionKeys.oliveAccount, v),
          ),
          _BoolTile(
            title: 'SBI証券 口座保有・取引',
            value: c[UserConditionKeys.sbiSecurities] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.sbiSecurities, v ? '1' : '0'),
          ),
          _IntTile(
            title: '家族ポイント登録人数',
            value: int.tryParse(c[UserConditionKeys.familyPoints] ?? '0') ?? 0,
            min: 0,
            max: 5,
            onChanged: (v) => state.setCondition(
                UserConditionKeys.familyPoints, v.toString()),
          ),
          _BoolTile(
            title: '選べる特典 選択済み',
            value: c[UserConditionKeys.selectableBenefit] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.selectableBenefit, v ? '1' : '0'),
          ),
          _BoolTile(
            title: '三井住友銀行アプリ ログイン',
            value: c[UserConditionKeys.smbcAppLogin] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.smbcAppLogin, v ? '1' : '0'),
          ),
          _BoolTile(
            title: 'Vポイントアプリ ログイン',
            value: c[UserConditionKeys.vpointAppLogin] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.vpointAppLogin, v ? '1' : '0'),
          ),
          _BoolTile(
            title: '住宅ローン契約あり',
            value: c[UserConditionKeys.housingLoan] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.housingLoan, v ? '1' : '0'),
          ),
          _section('💴 PayPayステップ'),
          _BoolTile(
            title: '月30回以上の200円以上支払い達成',
            value: c[UserConditionKeys.paypay30Times] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.paypay30Times, v ? '1' : '0'),
          ),
          _BoolTile(
            title: '月10万円以上支払い達成',
            value: c[UserConditionKeys.paypay100KYen] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.paypay100KYen, v ? '1' : '0'),
          ),
          _BoolTile(
            title: 'PayPayカード ゴールド保有',
            value: c[UserConditionKeys.paypayGold] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.paypayGold, v ? '1' : '0'),
          ),
          _section('🟥 楽天 SPU / 5と0のつく日'),
          _BoolTile(
            title: '楽天モバイル契約',
            value: c[UserConditionKeys.rakutenMobile] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.rakutenMobile, v ? '1' : '0'),
          ),
          _BoolTile(
            title: '楽天銀行（楽天カード引落）',
            value: c[UserConditionKeys.rakutenBank] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.rakutenBank, v ? '1' : '0'),
          ),
          _BoolTile(
            title: '楽天証券（投信積立月3万円以上）',
            value: c[UserConditionKeys.rakutenSecurities] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.rakutenSecurities, v ? '1' : '0'),
          ),
          _BoolTile(
            title: '楽天ひかり',
            value: c[UserConditionKeys.rakutenHikari] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.rakutenHikari, v ? '1' : '0'),
          ),
          _BoolTile(
            title: '楽天トラベル予約あり',
            value: c[UserConditionKeys.rakutenTravel] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.rakutenTravel, v ? '1' : '0'),
          ),
          _BoolTile(
            title: '5と0のつく日に購入',
            value: c[UserConditionKeys.fiveZeroDay] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.fiveZeroDay, v ? '1' : '0'),
          ),
          _section('🟡 LYP / Yahoo!ショッピング'),
          _BoolTile(
            title: 'LYPプレミアム会員',
            value: c[UserConditionKeys.lypPremium] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.lypPremium, v ? '1' : '0'),
          ),
          _BoolTile(
            title: '日曜日／5のつく日に購入',
            value: c[UserConditionKeys.sundayBonus] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.sundayBonus, v ? '1' : '0'),
          ),
          _section('🔶 三菱UFJ ポイントアッププログラム'),
          _BoolTile(
            title: 'MUFGアプリログイン',
            value: c[UserConditionKeys.mufgAppLogin] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.mufgAppLogin, v ? '1' : '0'),
          ),
          _DropdownTile(
            title: '月間利用金額レベル',
            value: c[UserConditionKeys.mufgMonthlyUse] ?? '0',
            options: const [
              ('0', '0円～'),
              ('1', '3万円以上'),
              ('2', '10万円以上'),
              ('3', '20万円以上'),
            ],
            onChanged: (v) =>
                state.setCondition(UserConditionKeys.mufgMonthlyUse, v),
          ),
          _section('💊 ウエル活'),
          _BoolTile(
            title: '毎月20日にWAON POINTを利用する',
            value: c[UserConditionKeys.welKatsu] == '1',
            onChanged: (v) => state.setCondition(
                UserConditionKeys.welKatsu, v ? '1' : '0'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14)),
      );
}

class _BoolTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _BoolTile(
      {required this.title, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
        title: Text(title), value: value, dense: true, onChanged: onChanged);
  }
}

class _DropdownTile extends StatelessWidget {
  final String title;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  const _DropdownTile(
      {required this.title,
      required this.value,
      required this.options,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        items: options
            .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _IntTile extends StatelessWidget {
  final String title;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  const _IntTile(
      {required this.title,
      required this.value,
      required this.min,
      required this.max,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Text('$value',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
