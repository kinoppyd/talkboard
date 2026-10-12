# USB HID中継・ローマ字読み上げPoC

US配列キーボードとMacの間で標準HID入力を中継し、入力のコピーをPicoRubyで解析してATP3011F1-PUに読み上げさせる試作です。**ソフトウェアのホストテストとUF2ビルドを実施。配線・Macでの入力・実際の発声は未検証です。**

## 読む順序

1. [回路・部品・配線](hardware.md): 新規回路、ブレッドボード組み立て、給電の注意。
2. [ビルド・書き込み・使い方](build-and-run.md): 固定依存版、パッチ適用、UF2、初回確認。
3. [実装の構造と制約](implementation.md): USBとRubyの分担、ローマ字規則、キュー。
4. [検証結果と実機チェックリスト](validation.md): 実施済みと未実施を区別。
5. [設計検討・確定要件](../todo/hub_architecture.md)。

## 成果物

- [回路図SVG](../../hardware/hid-relay/schematic.svg)と[接続データ](../../hardware/hid-relay/netlist.json)
- [意味単位のPicoRuby Patch列](../../patches/picoruby-hid-relay/series)
- [専用音声処理](../../firmware/relay/speech.rb)と[実行エントリ](../../firmware/relay/main.rb)
- [パッチ適用](../../tools/apply_relay_patches.rb)、[ビルド](../../tools/build_relay.rb)、[テスト](../../tools/test_relay.rb)の各ツール

前回のIC動作確認回路・標準入力コンソールは使用しません。電源断でも透過する装置や汎用USBハブではありません。VIA・RGB設定等、パスワード判定・ミュート、IME・文脈解析・抑揚指定は対象外です。パスワード入力も読まれるため、検証には機密情報を使わないでください。
