# R2P2 の `Keyboard` クラス

調査日: 2026-08-16（Asia/Tokyo）
ローカルコード: `picoruby` `master`、commit `371d176f1bfd834d18ff2a8c86d2667b51b0fd32`
対象: [`picoruby-keyboard`](../repositories/picoruby/mrbgems/picoruby-keyboard/README.md) と [`picoruby-r2p2`](../repositories/picoruby/mrbgems/picoruby-r2p2/README.md)

## 結論

R2P2 の `Keyboard` は、PicoRuby/R2P2 上で GPIO matrix を読んで USB HID keyboard event に変換する、現在保守中のキーボード用 class です。[PicoRuby 公式サイト](https://picoruby.org/)は、保守終了した PRK Firmware の代わりにこの class を使うよう案内しています。

ただし、PRK の置換版 UF2 ではありません。PRK は USB drive の `PRK DRIVE/keymap.rb` を再ロードする専用 firmware、R2P2 は shell、filesystem、Ruby application の実行環境です。R2P2 では通常 `/home/app.rb` を保存し、起動時に実行させます。現行 R2P2 の USB 設定は MSC を無効にしているため、PRK のような runtime USB drive は現れません。

本資料は 2026-08-14 時点の `picoruby/master` を基準にします。GitHub の最新公開 release は [3.4.2](https://github.com/picoruby/picoruby/releases/tag/3.4.2)（2026-03-29）ですが、ローカル source は `4.0.1-238-g371d176f` と後続です。配布 UF2 と `master` では API・対応 board・機能が異なり得るため、実機では UF2 の version と `app.rb` を一組で記録してください。

## 構成

```text
GPIO switch matrix / direct buttons
          │
KeyboardMatrix（C: scan、pull-up、debounce、event queue）
          │  {row:, col:, pressed:}
Keyboard（Ruby: layer、tap/hold、combo、macro）
          │  {row:, col:, keycode:, modifier:, pressed:}
USB::HID.keyboard_send
          │
TinyUSB: HID keyboard interface
          │
PC / tablet / host
```

R2P2 firmware には keyboard、mouse、consumer control の三つの独立 HID interface と、main/debug/MIDI 用の三つの CDC interface が定義されています。`Keyboard` class 自体が扱うのは key matrix と keyboard event であり、mouse や consumer key を自動統合する class ではありません。

関連 source:

- [`Keyboard`](../repositories/picoruby/mrbgems/picoruby-keyboard/mrblib/keyboard.rb)
- [`LayerKeycode`](../repositories/picoruby/mrbgems/picoruby-keyboard/mrblib/0_layer_keycode.rb)
- [`KeyboardMatrix`](../repositories/picoruby/mrbgems/picoruby-keyboard_matrix/src/keyboard_matrix.c)
- [`USB::HID`](../repositories/picoruby/mrbgems/picoruby-usb-hid/mrblib/usb_hid.rb)
- [公式 API reference](https://picoruby.org/Keyboard.html)

## 対応環境と導入

### 現行 source の build matrix

[`build_config`](../repositories/picoruby/build_config) を確認すると、`picoruby-keyboard` は現行 R2P2 の全 build configuration に組み込まれています。

| VM | board | `Keyboard` を含む現行 build |
|---|---|---|
| FemtoRuby（mruby/c） | `pico`, `pico_w`, `pico2`, `pico2_w` | はい |
| PicoRuby（mruby VM） | `pico2`, `pico2_w` | はい |

R2P2 の README は、Pico/Pico W では FemtoRuby、Pico 2/Pico 2 W では FemtoRuby または PicoRuby を対象として説明します。Pico W/Pico 2 W を USB keyboard として使うだけなら Wi-Fi/BLE は必須ではありませんが、選ぶ UF2 により搭載機能とメモリ余裕は変わります。

### release UF2 を使う

最短経路は R2P2 の release UF2 を BOOTSEL mode の drive へコピーする方法です。公式の [Getting Started](https://picoruby.org/setup) は、`r2p2-latest.sh` による選択式 download、または [releases](https://github.com/picoruby/picoruby/releases/latest)からの手動取得を案内しています。

1. board に合う `R2P2-*.uf2` を取得・展開する。
2. BOOTSEL を押しながら Pico を USB 接続する。
3. `RPI-RP2`（Pico 2 では `RP2350`）drive へ UF2 をコピーする。
4. 再起動後、R2P2 Web Terminal または USB CDC serial terminal へ接続する。
5. `/home/app.rb` を作成し、再起動して autostart を確認する。

`RPI-RP2` / `RP2350` は boot ROM の UF2 書込み用です。R2P2 起動後に見える一般的な USB mass-storage drive ではありません。現行 source の `CFG_TUD_MSC` は `0` です。

R2P2 3.4 以降は [Web Terminal](https://picoruby.org/terminal-emulator) が初心者向けに推奨されています。serial terminal を使う場合は、R2P2 README が CDC 0 を shell/stdout、CDC 1 を debug、CDC 2 を raw MIDI output と説明しています。

### `app.rb` の保存と回復

R2P2 は起動時に shell を初期化し、`/home/app.mrb` があれば先に、なければ `/home/app.rb` を読みます。これは [`r2p2.rb`](../repositories/picoruby/mrbgems/picoruby-shell/shell_executables/r2p2.rb) で確認できます。

- 開発中は R2P2 shell/Web Terminal の editor を使い、`/home/app.rb` を保存する。
- 起動前に PC 側にも `app.rb` の copy を version 管理しておく。
- 壊れた `app.rb` で shell を操作できなくなったときは、R2P2 起動時に `S` を送る。公式 troubleshooting はこれで `app.rb` の自動実行を skip できると説明している。
- shell 自体が復帰しない場合は BOOTSEL から既知の UF2 を再書込みする。

`app.mrb` は `app.rb` より優先されます。古い bytecode を残すと、Ruby source を更新しても期待通りに起動しないため注意してください。

## 最小の keyboard application

以下は 2 row × 2 column matrix の最小例です。GPIO 番号と配線は実機に合わせて置き換えます。

```ruby
require 'keyboard'

include USB::HID::Keycode
include LayerKeycode

kb = Keyboard.new([6, 7], [28, 27], debounce_ms: 5)

kb.layer do
  row KC_A, KC_B
  row KC_C, KC_D
end

kb.start do |event|
  USB::HID.keyboard_send(event[:modifier], event[:keycode])
end
```

`Keyboard#start` は無限 scan loop に入り、block へ次の hash を渡します。

```ruby
{ row: 0, col: 1, keycode: KC_B, modifier: 0, pressed: true }
```

release event の `keycode` は class 側で `0` になります。callback では通常 `USB::HID.keyboard_send(event[:modifier], event[:keycode])` をそのまま呼びます。

### matrix の電気的前提

現在の `KeyboardMatrix` 実装は matrix mode で row を output、column を pull-up input とし、row を一つずつ LOW にして column を読みます。公式 README は diode の **cathode を row、anode を column** とする構成を示します。

- 最大は source 定数上 16 rows × 16 columns。
- default debounce は 5 ms。`Keyboard.new(..., debounce_ms: n)` で変えられる。
- `KeyboardMatrix` の event queue は有限である。scan loop や `on_tick` callback を長く block しない。
- 配線、diode 方向、GPIO番号（物理 pin 番号ではない）を最小 matrix で先に検証する。

### direct wiring

column array を空にすると、各 row pin を独立した button として扱います。switch は GPIO と GND の間に置き、内部 pull-up により LOW を押下として読みます。

```ruby
require 'keyboard'

include USB::HID::Keycode

kb = Keyboard.new([17, 18, 19], [])
kb.layer do
  row KC_LEFT
  row KC_DOWN
  row KC_RIGHT
end

kb.start { |event| USB::HID.keyboard_send(event[:modifier], event[:keycode]) }
```

matrix mode と direct mode を同じ application で混ぜる API はありません。button 数が少ない macropad には direct mode が扱いやすい一方、キー数だけ GPIO を消費します。

## layer と特殊 keycode

layer は block DSL で定義します。layer index は **定義した順**です。名前は `default_layer=` や調査用には使えますが、`MO`、`LT`、`TG` は名前ではなく index を受け取ります。

```ruby
kb.layer(:base) do       # index 0
  row LT(1, KC_SPACE), KC_A
  row TG(1),             MT(KC_LSFT, KC_ENTER)
end

kb.layer(:function) do  # index 1
  row KC_1, KC_2
  row KC_NO, KC_NO
end

kb.default_layer = :base
```

| 記法 | 動作 | 主な制約 |
|---|---|---|
| `MO(n)` | 押している間だけ layer `n` を有効化 | 0～255 |
| `LT(n, kc)` | tap で `kc`、hold で layer `n` | layer は 0～15、既定 tap 判定は 200 ms |
| `MT(mod, kc)` | tap で `kc`、hold で modifier | modifier は `KC_LCTL`～`KC_RGUI` |
| `TG(n)` | layer `n` を on/off | 一度に lock できる TG layer は一つ |
| `S(kc)` | 常に Left Shift + `kc` | tap/hold ではない |
| `MC(n)` | 登録済み macro slot `n` を入力 | 0～255 |
| `KC_NO` | その layer では透明。下位 layer を探索 | PRK の「何もしない」とは異なる |

複数の `MO` は stack として扱われ、最後に押した layer が優先されます。優先順位は `TG` で lock した layer、`MO` stack（LIFO）、default layer の順です。

### tap/hold の実際

`LT` と `MT` は、release が `tap_threshold_ms`（既定 200 ms）未満で、かつ別キーを押していなければ tap と判定します。閾値を超えるか、別キーを押すと直ちに hold へ移ります。

```ruby
kb.tap_threshold_ms = 170
kb.repush_threshold_ms = 200
```

`repush_threshold_ms` は二度押しして保持する動作の判定に使われます。入力癖、switch、debounce をまとめて実機で調整してください。

### modifier と `S`

USB HID modifier (`KC_LCTL`、`KC_LSFT` 等) は class が modifier bit として蓄積します。`S(KC_1)` は常に Shift+1 を送るため、US配列では `!` に相当します。記号の表示は host の keyboard layout に依存するので、日本語配列やOS固有の layout では期待する文字になるかを確認します。

## combo と macro

### combo

```ruby
kb.add_combo([KC_A, KC_B], KC_ESC)
kb.combo_term_ms = 35
kb.combo_reference_layer = :base # nil なら現在の有効 layer
```

複数キーが time window 内に押されたときに action を送ります。複数の定義が一致する場合は長い combo が優先されます。combo の候補キーは、time window が過ぎるまで通常入力を保留するため、`combo_term_ms` を長くしすぎると通常入力の反応が遅れます。

### macro

```ruby
hello = kb.add_macro("Hello, PicoRuby!\n")

kb.layer do
  row hello
end
```

`add_macro` は `MC(n)` の特殊 keycode を返します。現行実装の文字変換は ASCII の一部（英字、数字、space、`.-_/:@!=`、tab、newline 等）が中心です。日本語入力、IME、任意の Unicode text を type する仕組みではありません。また macro は host 上で実行中のアプリへ入力するため、安全な editor で検証します。

## visual layout: `V` と `X`

最初の `layer` block は `kb.layout` を作り、keymap editor 等が物理見た目を描くための情報になります。

- `V(0.5)`: 左端などに 0.5U の空白を置く
- `X(0.25)`: 直前の key の右側を 0.25U 拡張する

どちらも scan keymap からは除外されます。現行 source は 0.25U 単位で内部表現します。README に残る 0.1U / `V(1.5) == -15` の説明は旧形式なので、現在の [`LayerKeycode`](../repositories/picoruby/mrbgems/picoruby-keyboard/mrblib/0_layer_keycode.rb)を優先します。

これは PCB の row/column mapping を変える機能ではありません。見た目の row-stagger や 1.5U key を表現する補助情報です。

## split keyboard

PRK の `kbd.split = true` のような通信を内蔵した one-call 設定はありません。R2P2 `Keyboard` は次の分担を想定します。

```text
master half                         slave half
Keyboard（左右を含む全 keymap）      KeyboardMatrix（自側の raw scan）
  ↑ inject_event(row,col,pressed)      │
  └──── UART / I2C 等の利用者実装 ────┘
```

master 側は local matrix より大きい keymap を `keymap_rows:` / `keymap_cols:` で定義し、slave から受信したイベントを適切な row/column offset で `inject_event` します。slave 側は `KeyboardMatrix` を直接使い、raw `{row:, col:, pressed:}` を送ります。

公開 example の UART protocol は説明用の 1 byte encoding です。row が 3 bit、column が 4 bit という制限を持ち、再送、同期、切断、電源、connector の安全性を実装していません。製品・常用 keyboard では通信仕様、GND共有、error handling、左右の同時起動を別途設計します。

## 周辺機能との組合せ

### USB HID

R2P2 の `USB::HID` は次を提供します。

- `keyboard_send` / `send_key` / `send_text`
- `mouse_move` / `move_mouse` / `click_mouse`
- `media_send` / `send_media`
- `keyboard_led_state`（host が返す Caps Lock 等の LED state）

keyboard application では callback で `keyboard_send` を呼びます。RGB、PIO、sensor 等の周期処理は `kb.on_tick { |keyboard| ... }` へ短い処理として置けます。実際に [`gherkin_sk6812.rb`](../repositories/picoruby/mrbgems/picoruby-keyboard/example/gherkin_sk6812.rb) は PIO の LED 更新を `on_tick` で間引いています。

### BLE keyboard は現時点で別経路

Pico W/Pico 2 W の R2P2 には BLE 関連の構成がありますが、[`ble_keyboard.rb`](../repositories/picoruby/mrbgems/picoruby-ble-hid/example/ble_keyboard.rb) は `Keyboard#start` の event loop が BLE HID の loop と衝突すると明記しています。現時点の BLE example は `KeyboardMatrix` を直接使う単純な keymap です。

したがって、「R2P2 の `Keyboard` class で USB keyboard を作る」と「BLE HID keyboard を作る」は同じ完成度ではありません。layer、LT/MT、combo を含む BLE keyboard を新規設計する場合は、`Keyboard#scan` 相当の統合 API がまだないことを前提に検証します。

## 現在確認できる制限と注意点

- `Keyboard#start` は無限 loop。R2P2 shell と同時に対話的に使うのではなく、`app.rb` を専用 application として動かす構成が自然。
- callback contract は keycode を一つだけ渡し、`USB::HID.keyboard_send` も一つの keycode を受ける。source は modifier bit を蓄積する一方、複数の通常 keycode を同時 report に集約していない。ゲーム等で通常キーの同時押し・真の NKRO が必要なら、目的の chord を実機で必ず検証する。
- matrix scanner は N-key rollover を掲げるが、これは raw scan/event queue 層の性質であり、USB report の同時キー表現を保証する記述ではない。
- `Keyboard` class に PRK の VIA/Remap、`PRK DRIVE` 自動 reload、内蔵 split UART、RGB effect DSL はない。必要なら R2P2 の周辺 API と application code で構成する。
- PicoRuby は CRuby の完全互換ではない。`NoMethodError` は未実装 API、`NoMemoryError` は resource 上限の可能性がある。公式 troubleshooting を参照する。
- `on_tick` や callback 内で長い I/O、sleep、大量 allocation をすると scan と event queue に影響する。

## source build

release UF2 に必要な keyboard gem が入っているか不確かな場合や、PicoRuby `master` の機能を使う場合は source build を行います。現行 [`picoruby-r2p2 README`](../repositories/picoruby/mrbgems/picoruby-r2p2/README.md) と [`r2p2.rake`](../repositories/picoruby/tasks/picoruby/r2p2.rake)による手順です。

```sh
cd picoruby
bundle install
rake r2p2:setup
```

現行 source は内包 pico-sdk の tag `2.3.0` を要求します。

```sh
cd mrbgems/picoruby-r2p2/lib/pico-sdk
git checkout 2.3.0
git submodule update --init --recursive
```

主な build task:

```sh
# RP2040 / FemtoRuby
rake r2p2:femtoruby:pico:prod

# RP2350 / PicoRuby
rake r2p2:picoruby:pico2:prod

# RP2350 + Wi-Fi/BLE 対応 board / PicoRuby
rake r2p2:picoruby:pico2_w:prod
```

成果物は `build/r2p2/<vm>/<board>/<mode>/` に作られます。source build は Git、Ruby/Bundler、CMake 3.22 以上、Arm GNU toolchain 等を必要とします。SDK、PicoRuby commit、build task、生成UF2の checksum を一緒に残してください。

## 参考例

- [`meishi2.rb`](../repositories/picoruby/mrbgems/picoruby-keyboard/example/meishi2.rb): 2×2 matrix、LT/MT、combo
- [`direct_wiring.rb`](../repositories/picoruby/mrbgems/picoruby-keyboard/example/direct_wiring.rb): direct pin
- [`gherkin.rb`](../repositories/picoruby/mrbgems/picoruby-keyboard/example/gherkin.rb): 多 layer、LT/MT、`S`
- [`split_keyboard_master.rb`](../repositories/picoruby/mrbgems/picoruby-keyboard/example/split_keyboard_master.rb) と [`split_keyboard_slave.rb`](../repositories/picoruby/mrbgems/picoruby-keyboard/example/split_keyboard_slave.rb): split の骨格
- [`gherkin_sk6812.rb`](../repositories/picoruby/mrbgems/picoruby-keyboard/example/gherkin_sk6812.rb): `on_tick` と PIO LED
- [公式 `Keyboard` API](https://picoruby.org/Keyboard.html)
- [R2P2 setup](https://picoruby.org/setup)、[terminal emulator / Web Terminal](https://picoruby.org/terminal-emulator)、[troubleshooting](https://picoruby.org/troubleshooting)
