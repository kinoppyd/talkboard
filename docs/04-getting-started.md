# 導入と最初のキーマップ

この章は RP2040 ボードと、リリース済み `MSC_FLASH` UF2 を使う最短経路を説明します。Pico 2 / RP2350 は配布版 0.10.0 の対象外なので、先に[ソースからのビルド](08-build.md)を参照してください。

## 用意するもの

- RP2040 搭載ボード
- データ通信に対応した USB ケーブル
- 配線が分かるキーボード、または少数スイッチの試験回路
- `keymap.rb` を編集できるテキストエディタ
- 問題調査用に 115200 bps を扱える serial terminal
- 現在の `PRK DRIVE` のバックアップ先

GPIO 番号と基板上の物理 pin 番号は同じとは限りません。キーマップには原則として GPIO 番号を書きます。ボードの pinout とキーボードの回路図を照合してください。

## 1. UF2 を書き込む

1. [0.10.0 release](https://github.com/picoruby/prk_firmware/releases/tag/0.10.0) から `MSC_FLASH` の UF2 zip または gzip を取得し、展開する。
2. BOOTSEL ボタンを押しながら RP2040 ボードを USB 接続する。
3. `RPI-RP2` という USB drive が現れたら、UF2 をコピーする。
4. コピー後にボードが再起動し、今度は `PRK DRIVE` が現れることを確認する。

`RPI-RP2` は RP2040 boot ROM の書込み用 drive、`PRK DRIVE` は PRK 実行中の keymap 用 drive です。両者を混同しないでください。

既存キーボードを更新する場合、UF2 書込み前に `keymap.rb`、`prk-conf.txt`、`via_map.txt`、`lib/` を退避します。現在の実装は mount 失敗時に format を試すため、唯一のコピーを drive 上だけに置くべきではありません。

## 2. 最小の `keymap.rb`

2 行 × 2 列の通常 matrix を仮定した最小例です。GPIO と配列は実機の回路に合わせて変更します。

```ruby
kbd = Keyboard.new

kbd.init_pins(
  [6, 7],   # row GPIO
  [28, 27]  # column GPIO
)

kbd.add_layer :default, %i[
  KC_A KC_B
  KC_C KC_D
]

kbd.start!
```

配列は keyscan が返す位置順です。見た目が 2 行 × 2 列でも、回路上の row/column、diode 方向、スキャン方向が想定と違えば異なるキーが出ます。まず一キーずつ導通と位置を確認してください。

## 3. 保存して読み込ませる

1. PC 上の作業フォルダで `keymap.rb` を編集し、履歴管理する。
2. 完成したファイルを `PRK DRIVE/keymap.rb` へコピーする。
3. drive の書込み完了を待つ。
4. 数秒後に新しいキーマップが動くことを確認する。

Wiki では再ロードに 5～7 秒程度かかる場合があると説明されています。drive 上のファイルをエディタで直接開くと、一時ファイル、複数回保存、部分書込みによって意図しない再ロードが起こり得るため、PC 上で編集して最後にコピーする方法を推奨します。

## 4. serial output を確認する

PRK は USB CDC serial に起動情報と Ruby error を出します。設定は通常次のとおりです。

```text
115200 bps / 8 data bits / no parity / 1 stop bit / no flow control
```

macOS なら `/dev/cu.usbmodem...`、Linux なら `/dev/ttyACM...` のような device が現れます。OS ごとの権限や device 名は環境により異なります。

0.10.0 では起動時の約 2 秒間に serial terminal から `s` を送ると `keymap.rb` の実行を skip できます。壊れた keymap が起動直後に例外や無限処理を起こす場合の回復手段です。

## ダイレクトピンの最小例

diode matrix を使わず、スイッチごとに GPIO を一つ割り当てる場合は `init_direct_pins` を使います。

```ruby
kbd = Keyboard.new
kbd.init_direct_pins([2, 3, 4])
kbd.add_layer :default, %i[KC_A KC_B KC_C]
kbd.start!
```

小さな macropad では分かりやすい方式ですが、キー数だけ GPIO を消費します。pin の pull-up/pull-down とスイッチの接続先は PRK の実装・回路例に合わせ、電源と GPIO を短絡させないよう確認してください。

## 起動しない場合の回復順

1. serial を開いて再起動し、Ruby error を読む。
2. 0.10.0 なら起動直後に `s` を送って keymap を skip する。
3. BOOTSEL を押したまま接続し、既知の UF2 を再書込みする。
4. 対応版では reset を素早く二回行う方法、または keymap に登録した `kbd.bootsel!` を使う。
5. バックアップした最小 keymap から機能を一つずつ戻す。

詳しい切り分けは[デバッグとトラブルシューティング](09-debug-and-troubleshooting.md)を参照してください。
