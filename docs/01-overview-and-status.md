# 概要、位置づけ、現状

## PRK Firmware とは

PRK Firmware は、Raspberry Pi Pico を中心とする RP2040 系ボードを自作キーボードのコントローラにし、Ruby で配線・レイヤ・マクロ・周辺機能を記述できる PicoRuby ベースのファームウェアです。

一般的な利用では、配布 UF2 を一度マイコンへ書き込むと、USB マスストレージとして現れる `PRK DRIVE` の `keymap.rb` を更新してキーマップを変更できます。QMK のようにキーマップ変更ごとに C のファームウェアをコンパイルする方式とは異なり、マイコン上の PicoRuby が Ruby コードを読み込んで実行します。

主な特徴は次のとおりです。

- キーマトリクス、ダイレクトピン、duplex、round-robin のスキャン
- 複数レイヤ、モードキー、複合キー、Ruby の `Proc` を使う動作
- 1 線のソフトウェア UART を使った左右分割キーボード
- RGB LED、ロータリエンコーダ、サウンダ、マウス、ジョイスティック
- USB キーボード、Consumer Control、マウス、Raw HID、シリアル、ストレージ
- VIA/Remap の一部対応
- Ruby ファイルを `/lib` に置き、`require` する拡張

実装は MIT License で公開されています。上位ロジックの多くが Ruby、USB や GPIO などの低レベル部分が C/C++ という構成です。

## 2026 年時点の状態

[PicoRuby 公式サイト](https://picoruby.org/) は、PRK Firmware を次のように位置づけています。

- PRK Firmware は deprecated
- 2026 年現在は保守されていない
- 代わりに R2P2 の `Keyboard` クラスを使用する

GitHub の最新正式リリースは [0.10.0](https://github.com/picoruby/prk_firmware/releases/tag/0.10.0) で、2024-11-17 に公開されました。ローカルで確認した `master` の先頭は 2025-01-09 の commit です。このため、現在は「公開済みの安定した完成品」ではあるものの、将来の SDK、OS、USB ホスト、部品への追従を期待するプロジェクトではありません。

### RP2040 と RP2350

0.10.0 の配布アセットは RP2040 用の `MSC_FLASH` UF2 です。一方、`master` の [Rakefile](../repositories/prk_firmware/Rakefile) には `rake pico2` があり、RP2350/Pico 2 対応 commit は 0.10.0 の後に入りました。

したがって、選択は次のようになります。

- Raspberry Pi Pico / RP2040: 0.10.0 のリリース UF2を使うのが最短
- Raspberry Pi Pico 2 / RP2350: `master` から自分でビルド
- Pico W / Pico 2 W: 無線機能を使う PRK の公式手順は確認できない。単に RP 系ボードだから使えるとは判断しない

## QMK、KMK、後継 PicoRuby との違い

| 項目 | PRK Firmware | QMK | KMK | 現行 PicoRuby Keyboard |
|---|---|---|---|---|
| 主な記述言語 | Ruby | C | CircuitPython | Ruby |
| 通常のキーマップ変更 | `PRK DRIVE` にコピー | 再ビルドして書込 | Python ファイル更新 | R2P2 の構成に従う |
| 主な対象 | RP2040、`master` は RP2350 も | 多数の MCU | CircuitPython 対応 MCU | PicoRuby/R2P2 対応環境 |
| 現在の状態 | 保守終了・非推奨 | 活発 | 継続中 | PRK の公式な後継 |

新規設計では後継を優先すべきですが、API はそのまま互換ではありません。PRK の典型的な `Keyboard.new`、`init_pins`、`add_layer` に対し、現行の [`picoruby-keyboard` README](../repositories/picoruby/mrbgems/picoruby-keyboard/README.md) は、行・列ピンをコンストラクタへ渡し、ブロック形式の `layer` と `MO`、`LT`、`MT`、`TG` 等を使います。既存キーマップの移行は機械的なコピーではなく書き換えになります。

## 向いている用途、避けるべき用途

向いている用途:

- 既存の PRK 採用キーボードの保守
- Ruby で USB キーボードが動く仕組みの研究
- 当時の PicoRuby、組み込み Ruby、USB 複合デバイスの調査
- バージョンを固定できる個人用キーボード

慎重にすべき用途:

- 長期サポートが必須の製品や業務機器
- セキュリティ更新や新しい Pico SDK への継続追従が必要な用途
- Bluetooth 前提のキーボード
- RP2350 で配布済みバイナリだけを使いたい場合
- Wiki の古い手順を変更せずそのまま自動化する場合

## 調査対象の基準

本資料では、食い違いがある場合に次の順で情報を採用しました。

1. ローカルに取得した現在のソースコード
2. GitHub のリリースと Git 履歴
3. 公式 Wiki と README
4. 発表、インタビュー、外部記事

そのため、古いキーボードリポジトリの例が現在の `master` では動かない可能性も明示しています。
