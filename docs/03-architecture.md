# 内部構成と動作原理

## 全体像

PRK は、C/C++ のハードウェア層、PicoRuby VM、Ruby のキーボードロジックを一つの UF2 にまとめています。

```text
USB host
  ├─ CDC serial
  ├─ Mass Storage: PRK DRIVE（MSC build のみ）
  ├─ HID: keyboard / mouse / consumer / raw HID
  └─ HID: joystick/gamepad
          │
TinyUSB + Pico SDK（C/C++）
          │
PicoRuby VM + 組込み mrbgems
          │
usb_task.rb ── keymap.rb の監視・再ロード
          │
Keyboard（Ruby）── scan / layers / mode keys / features
          │
GPIO matrix・split UART・RGB・encoder・sounder 等
```

重要な入口は次のファイルです。

- [`src/main.c`](../repositories/prk_firmware/src/main.c): VM、メモリ、USB task、keymap task の起動
- [`mrblib/usb_task.rb`](../repositories/prk_firmware/mrblib/usb_task.rb): ボリュームの mount と keymap 自動再ロード
- [`keyboard.rb`](../repositories/prk_firmware/lib/picoruby/mrbgems/picoruby-prk-keyboard/mrblib/keyboard.rb): スキャン、レイヤ、レポート生成の中心
- [`src/usb_descriptors.c`](../repositories/prk_firmware/src/usb_descriptors.c): USB 複合デバイスの descriptor
- [`prk_firmware.gembox`](../repositories/prk_firmware/lib/picoruby/mrbgems/prk_firmware.gembox): ファームウェアへ組み込む mrbgems

## 起動からキー入力まで

1. `main.c` が PicoRuby VM とメモリプールを初期化する。
2. USB task を作成し、TinyUSB を定期的に処理する。
3. MSC build では内蔵 flash または SD の FAT volume を mount する。
4. `Keyboard.restart` が設定を表示し、`keymap.rb` を Sandbox 内で読み込む。
5. `keymap.rb` が `Keyboard` を構築し、最後に `start!` を呼ぶ。
6. Ruby の scan loop が GPIO を読み、debounce、レイヤ解決、mode key 判定を行う。
7. HID report を C/TinyUSB へ渡し、PC へキー、マウス、consumer report を送る。
8. ホストから `keymap.rb` が書き換えられると MSC callback が reload を予約し、Ruby task が新しい内容を読み直す。

再ロードが失敗・停止した場合は、再起動が必要になることがあります。ファイル保存の途中を読ませないためにも、PC 上で編集を完了してから `PRK DRIVE` へコピーする運用が安全です。

## `PRK DRIVE`

MSC build は USB Mass Storage として `PRK DRIVE` を公開します。主要ファイルは次のとおりです。

| パス | 用途 |
|---|---|
| `/keymap.rb` | 実行するキーボード定義 |
| `/prk-conf.txt` | VIA/Remap 用 VID、PID、product name |
| `/via_map.txt` | VIA の割当保存で利用されるファイル |
| `/lib/*.rb` | `require` / `load` する追加ライブラリ |
| `/README.txt` | ドライブ上に生成される簡単な説明 |

mount に失敗した場合、実装は volume の format を試みます。ファームウェア更新や実験の前に、`keymap.rb`、設定、ライブラリを必ず PC 側へバックアップすべきです。

`NO_MSC` の keymap 埋込み build ではドライブを公開せず、Ruby のソースを UF2 に含めます。ストレージをホストへ見せたくない場合や完成後の固定ファームウェアに適しますが、変更には再ビルドが必要です。

## USB 構成

ソースの descriptor では、次の機能を持つ USB composite device です。

- CDC: デバッグ出力と対話用 serial
- MSC: `PRK DRIVE`。MSC build のみ
- HID report: keyboard、mouse、consumer control、raw HID
- gamepad/joystick 用 HID

既定 VID/PID は `0x16c0:0x27db`、manufacturer string は `PRK Firmware developers` です。VIA を有効にした場合は `prk-conf.txt` の VID/PID/product を flash に適用できます。VID/PID は USB 製品識別子なので、製品配布時に任意の値を無断で使ってよいという意味ではありません。

## メモリ構成

[`src/main.c`](../repositories/prk_firmware/src/main.c) の現在値では、PicoRuby 用 heap は次のように分かれます。

- RP2040: 194 KiB
- RP2350: 通常 454 KiB
- RP2350 + SQLite3 構成: 434 KiB

Ruby の配列、文字列、Proc、大きな外部ライブラリ、RGB matrix 状態は heap を消費します。実機で不安定になる場合は、キー処理だけでなく Ruby object の増加も疑います。公開 meishi2 例のように `PicoRubyVM.print_alloc_stats` を Proc に割り当てると、調査用のメモリ統計を出せます。

## 組込み mrbgems

`prk_firmware.gembox` には、compiler、`require`、VFS/FAT、keyboard、debounce、consumer key、mouse、joystick、RGB、encoder、sounder、VIA、I2C/SPI/ADC/PWM、watchdog 等が列挙されています。

この一覧は互換性判断の根拠になります。公開キーマップが `require "何か"` を呼ぶ場合、次のどちらかが必要です。

- その gem が対象 PRK build に組み込まれている
- 対応する Ruby ファイルが `PRK DRIVE/lib` にある

過去のリポジトリで使えた名称が現在の gembox にない場合、キーマップだけをコピーしても動きません。

## スキャンと debounce

通常の matrix は出力側を順に駆動し、入力側の状態から押下位置を判定します。direct scan はキーごとに GPIO を一つ使います。duplex/round-robin は同じ配線群の方向を切り替えてより多くのキーを読みます。

debounce は `:none`、`:per_row`、`:per_key` を選択できます。現在の `start!` は一般的な matrix と direct scan で適した既定を選びますが、チャタリング、scan 間隔、モードキーの tap/hold 判定が絡む場合は明示設定して比較します。

## 静的型情報とテスト

API の型情報は [`keyboard.rbs`](../repositories/prk_firmware/lib/picoruby/mrbgems/picoruby-prk-keyboard/sig/keyboard.rbs) にあります。CI は Ruby 上の compiler/mrubyc 系テストを実行し、キーボードと VIA のテストもリポジトリにあります。ただし、USB timing、実配線、diode 方向、split の信号品質はホスト上テストでは保証されません。最終確認は実機で必要です。
