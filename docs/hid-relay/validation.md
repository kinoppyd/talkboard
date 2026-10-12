# 検証結果と残る実機確認

## 実施済み

- 専用Ruby音声処理: **19テスト・44 assertions、失敗0**。
- 接続データ: **5テスト・21 assertions、失敗0**。
- CのHID変換: Boot、NKRO、Consumer、LED、report長・不正descriptor・Usage indexの境界値を確認。
- descriptorパーサに決定的乱数で**10,000件**の不正入力を与え、AddressSanitizer/UndefinedBehaviorSanitizerで異常なし。
- C実行層のSDK/USBスタブ試験: endpoint準備待ちで押下→解放を保つこと、同じ押下の重複観測を防ぐこと、Boot切り替え、LED要求、観測overflow時の転送継続、切断時の解放を確認。
- 固定PicoRubyの新しいクリーンチェックアウトに、配布用4本のPatchを順次適用できることを確認。
- そのパッチ適用済みソースからPicoRubyライブラリ・専用main・PIO USB・SDKをコンパイルし、ELF/UF2の生成を確認。
- SDK/TinyUSBのsubmoduleソースは変更していない。

ホストテストはCRubyとネイティブCです。USBスタブは実際のUSBタイミングやMacの挙動を再現していません。PicoRuby実機上のGC・タスク・音声処理の動作確認とは区別します。

## ビルド環境・生成物

ローカルの検証出力先は `build/relay-clean/`。UF2は `Talkboard-0.1.0-PICO2W-20261012-371d176f.uf2`。

この生成物のSHA-256: `7a863629837d07c573cf7123b111040d472868e2773384e4f03709096bed03de`。ビルド環境はRuby 3.4.2、CMake 3.28.3、Arm GNU Toolchain 14.3.Rel1。ビルド日やソースパスが変わる場合の同一ハッシュを要求するものではありません。

`arm-none-eabi-size` によるELFの値:

| text | data | bss |
|---:|---:|---:|
| 905260 bytes | 0 bytes | 380916 bytes |

このbssには320KiBのRuby用静的ヒープ領域等を含みます。実行時の空きヒープや最大スタック使用量の測定ではありません。SDK・mruby・PIO USB由来のwarningは残っていますが、コンパイルとリンクは成功しています。

依存版は[versions.json](../../patches/picoruby-hid-relay/versions.json)。検証コマンドは[ビルド手順](build-and-run.md)を参照してください。生成バイナリはGitへコミットしていません。

## 未実施: 実機チェックリスト

キーボード機種は未定、初回の予定はUS配列＋Macです。

- [ ] キーボード機種、USBモード、macOS・Mac機種、ケーブル、電源を記録。
- [ ] 両電源を外した導通確認、3.3V/5V/VSYS/HOST_VBUSの測定。
- [ ] PC側への逆流と、通常・発話・suspend時の消費電流の測定。
- [ ] Picoの列挙、通常キー・修飾キー・短いタップ・押下/解放がMacへ届く。
- [ ] Shift/Ctrl/Option/Command、Backspace、長押しのPC側動作。
- [ ] Caps/Num/Scroll Lock等、対象キーボードが持つLED。
- [ ] 対象キーボードのNKRO・メディア・Systemキー。
- [ ] n/sh/ch等の末尾待ち、単音節と連続文の実際の発声。
- [ ] IC発話中でもキー転送が停止しない。直接接続比の平均/P99/最大遅延。
- [ ] 音声待ち満杯で新しい音声だけが破棄され、保持分は順番に発声。
- [ ] I²C切断・IC応答停止時でもキー転送が継続。
- [ ] キーボード抜去、PC抜去、再接続、休止・復帰。
- [ ] U3の過電流遮断と再起動復帰。意図的な短絡試験は電流制限電源と適切な測定環境で行う。

## 明示的な制約

- 全機種の互換性、電気的USB規格適合、自然な読みは保証しない。
- マウス一体型入力、内蔵ハブ、メーカー固有機能は未対応。
- USB低消費電力への移行は未実装。remote wakeup要求を送る実装と、suspend電流規格への適合は別。
- 実機での電源安定性、発声、入力遅延は未確認。これらを確認済みとして扱わない。
- パスワードも読まれ得る。機密情報を使わない検証環境で利用する。
