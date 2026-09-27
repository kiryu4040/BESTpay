# BESTpay v2 決定記録（docs/decisions）

このディレクトリは、BESTpay v2 の**すべての設計判断の正本**です。
会話履歴・作業環境・AIの記憶が失われても、ここを読めば同じ判断を再現できます。

## ファイル

| ファイル | 役割 |
|---|---|
| `decision_ledger.json` | 全78件の決定（機械可読な正本） |
| `card_addition_runbook.md` | カード1枚を追加する唯一の手順（6段） |
| `scope_phases.md` | 何を第1期／第2期に作るか（スコープの区分） |
| `../spec/conflict_resolution.csv` | 資料間の食い違いの裁定（48件・既存） |
| `../spec/conflict_resolution_addendum_2026-09-27.csv` | 2026-09-27に追加で確定した裁定（CR-049〜） |

## 正本の優先順位

1. `decision_ledger.json`（本書）— 実装時の拘束条件
2. `../spec/conflict_resolution.csv` と追加裁定表 — 資料間の食い違いの扱い
3. `../spec/BESTpay_v2_integration_checkpoint_2026-09-18_v1.1.0.txt` — 統合作業のチェックポイント
4. 資料パッケージの統合文書3件
5. `lib/` の実装コード
6. 資料パッケージの元文書115件（**単独では使わない**。参照用の倉庫）

## 変更プロトコル（つぎはぎを防ぐ）

新しい要望・思いつきが出たときは、**実装より先に**次を行います。

1. **番号を振る** — `D-079` のように `decision_ledger.json` に追記する
2. **4項目を書く** — ①何を ②なぜ ③どの期に入れるか ④既存の決定（D-xxx / CR-xxx）と矛盾しないか
3. **矛盾があれば先に裁定する** — 矛盾を残したまま実装しない
4. **期の移動で表現する** — 既存機能を前倒し／後回しにする場合は `phase` を書き換える。機能を思いつきで足さない
5. **スコープ外は消さずに記録する** — 「やらない」と決めたことも `phase: "-"` として残す

## 仕様の食い違いが出たとき

`conflict_resolution.csv` と同じ列構成で `CR-049` 以降として追記します。
列は `conflictId,priority,domain,legacyDefinition,decision,status,authority,notes` です。

## カードを追加したとき

`card_addition_runbook.md` の6段を必ず踏みます。この手順を踏めば、**アプリ本体のコードは触りません**。

## 中断した作業の再開方法

1. `decision_ledger.json` を読む（何が決まっているか）
2. `scope_phases.md` を読む（次に何を作るか）
3. `../spec/` の裁定表を読む（以前の食い違いを蒸し返さない）
4. リポジトリの最新コミットを確認する（どこまで実装済みか）

この4点で、判断の再現に必要な情報は揃います。
