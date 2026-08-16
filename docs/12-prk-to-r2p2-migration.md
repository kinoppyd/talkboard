# PRK Firmware から R2P2 `Keyboard` への移行

PRK Firmware の保守終了を受け、PicoRuby 公式は R2P2 の `Keyboard` class を後継として案内しています。しかし API、配布形式、編集・復旧方法、split の責務は大きく異なります。既存 `keymap.rb` をそのまま R2P2 へコピーしても動きません。

詳細な R2P2 API は [R2P2 の `Keyboard` クラス](11-r2p2-keyboard.md)を参照してください。

## 最初の判断

| 状況 | 方針 |
|---|---|
| 既存 PRK keyboard を短期に修理する | 実績のある PRK UF2/tag と既存 keymap を固定する |
| 新しい RP2040/RP2350 keyboard を作る | R2P2 `Keyboard` を第一候補にする |
| PRK の `keymap.rb` を移植する | 配線・layer・tap/hold・周辺機能を段階的に書き換える |
| PRK の VIA/Remap、auto reload が必須 | R2P2 に同等の組込み機能があるとは仮定せず、要件を再設計する |
| Bluetooth と高度な layer 処理を併用したい | 現在の `Keyboard#start` と BLE HID loop の制約を検証してから採用する |

## 設計の差

| 関心ごと | PRK Firmware | R2P2 `Keyboard` |
|---|---|---|
| 実行環境 | keyboard 専用 firmware | PicoRuby shell と filesystem を持つ platform |
| application file | `PRK DRIVE/keymap.rb` | `/home/app.rb`、または優先される `/home/app.mrb` |
| 変更反映 | Mass Storage の保存後に reload | app を保存して再起動／実行する運用 |
| matrix 初期化 | `Keyboard.new` の後に `init_pins` | `Keyboard.new(row_pins, col_pins)` |
| layer 定義 | `add_layer :name, %i[...]` | `layer(:name) { row ... }` |
| transparent | `KC_NO` は何もしない | `KC_NO` は下位 layer へ fall-through |
| tap/hold | `define_mode_key` | `LT(layer, key)`、`MT(modifier, key)` |
| modifier | PRK の key/action 定義 | USB HID modifier keycode を自動 bit 化 |
| composite/combo | `define_composite_key` | `add_combo([keys], action)`（同時押し時間判定） |
| macro | Proc、`send_key` 等 | `add_macro` / `MC` は ASCII文字列を type |
| split | software mutual UART を実装 | transport と `inject_event` を利用者が実装 |
| RGB/encoder/sounder | PRK 専用 feature を `append` | R2P2 の PIO/GPIO/周辺 gem と `on_tick` 等で組み立てる |
| VIA/Remap | 一部組込み対応 | `Keyboard` class の直接対応は確認できない |

## 移行手順

### 1. 現行 PRK を丸ごと保存する

次を別 directory / Git repository に残します。

- PRK UF2、tag/commit、board名
- `keymap.rb`、`prk-conf.txt`、`via_map.txt`、`lib/`
- 回路図、GPIO table、diode方向
- split の data pin、anchor、左右の firmware version

R2P2 へ移行後に問題が出た場合、PRK 側で動いていた挙動を比較できるようにします。

### 2. R2P2 を最小構成で起動する

R2P2 UF2 を flash し、Web Terminal または serial shell に接続します。最初は `/home/app.rb` を置かず shell が使える状態にします。USB HID、filesystem、復旧操作が理解できてから keyboard app を入れます。

### 3. keyscan のみを移植する

PRK:

```ruby
kbd = Keyboard.new
kbd.init_pins([6, 7], [28, 27])
kbd.add_layer :default, %i[KC_A KC_B KC_C KC_D]
kbd.start!
```

R2P2:

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

ここでは PRK の一次元配列を、physical row ごとの `row` 呼出しへ変えています。R2P2 は keymap size が matrix の row × column と一致しないと `ArgumentError` になります。先にこの最小 keyboard で全 position の mapping を確定します。

### 4. layer を index として設計し直す

PRK では layer name を多くの API に使えます。R2P2 の `MO`、`LT`、`TG` は layer の定義順 index を使います。

```ruby
kb.layer(:base) do       # index 0
  row LT(1, KC_SPACE), KC_A
end

kb.layer(:symbols) do   # index 1
  row KC_1, KC_2
end
```

layer の並びを後で入れ替えると、`LT(1, ...)` の意味も変わります。layer index は constants で名前を付けると安全です。

```ruby
BASE = 0
SYMBOLS = 1

SPACE_SYMBOLS = LT(SYMBOLS, KC_SPACE)
```

### 5. `KC_NO` を見直す

これは最も誤りやすい相違です。

```ruby
# PRK: KC_NO / XXXXXXX は、その位置からキーを送らない。
# R2P2: KC_NO は透明で、下位 layer の同じ位置を探索する。
```

PRK の空キーを R2P2 で本当に無効化したい場合、下位 layer も含めて keycode `0` になるか、別の layer 配計を取る必要があります。安易に `KC_NO` へ置換せず、全 layer の priority を紙に書いて確認します。

### 6. mode/composite/macro を対応付ける

| PRK の意図 | R2P2 の候補 | 違い |
|---|---|---|
| Space tap / Fn hold | `LT(FN, KC_SPACE)` | tap threshold は keyboard 全体の設定 |
| Enter tap / Shift hold | `MT(KC_LSFT, KC_ENTER)` | modifier は HID keycode を指定 |
| Fn を押している間 | `MO(FN)` | layer index を使用 |
| layer 固定 | `TG(FN)` | lock は一つだけ |
| Ctrl+C の名前付き key | callback/専用設計、または combo | PRK composite と R2P2 combo は同じ概念ではない |
| 文字列 type macro | `add_macro("...")` | ASCII の一部のみ |
| Ruby の任意 Proc | `on_tick` 等へ設計し直す | 走査 loop を block しない |

PRK の `define_composite_key :COPY, %i[KC_LCTL KC_C]` は「一位置で chord を出す」定義です。一方、R2P2 の `add_combo([KC_A, KC_B], KC_ESC)` は「複数の物理キーを同時に押したときの action」です。目的が同じに見えても置換先は異なります。

### 7. split は通信層から移植する

PRK の auto split をそのまま再現しようとせず、先に片側だけを R2P2 `Keyboard` で動かします。その後、slave を `KeyboardMatrix`、master を全 keymap にします。

1. slave で raw row/column/pressed event を得る。
2. UART/I2C 等で master へ送る protocol を決める。
3. master 側で slave の physical position に offset を加える。
4. `kb.inject_event(row, col, pressed)` に渡す。
5. disconnect、reboot、通信破損時に stuck key を release する処理を設計する。

この手順は PRK より実装量が増えますが、通信方式、左右非対称 layout、別 controller を明示的に選べます。

### 8. 周辺機能を一つずつ戻す

PRK の RGB effect、encoder、sounder、mouse、VIA は移植単位が異なります。R2P2 の USB HID は keyboard/mouse/consumer control を用意しますが、PRK の feature API が同名で再現されるわけではありません。

- LED: `on_tick` と PIO/GPIO の小さな更新から始める。
- encoder: GPIO/IRQ 等で event を作り、`USB::HID` を呼ぶ。
- mouse/consumer: R2P2 の `USB::HID.move_mouse` / `send_media` を個別に検証する。
- OLED、driver、外部 library: R2P2 build config に gem が入るか確認する。
- VIA/Remap: 既存 workflow が必要なら別の keymap editor/protocol を選定する。

### 9. autostart と回復をテストする

`/home/app.rb` は起動時に走るため、USB keyboard として動作中は shell に戻れない場合があります。次を実機で確認します。

- `S` で `app.rb` を skip して shell へ戻れるか
- BOOTSEL を使った UF2 再書込み
- `app.mrb` が残っていないか
- USB cable/host を替えて HID が列挙されるか
- 電源投入時に不要な key/macro を送らないか

## PRK と R2P2 の使い分け

PRK は既存 keyboard の保守に便利な自己完結型 firmware、R2P2 は keyboard を含む PicoRuby application platform です。新規 keyboard で R2P2 を選ぶなら、編集が `PRK DRIVE` のコピー操作から `/home/app.rb` の application 開発へ変わることを受け入れる必要があります。

R2P2 は source が継続更新されている利点があります。一方、現時点の `Keyboard` class は 2026 年に導入・拡張された若い API です。公開 release と `master` の差、USB multi-key rollover、BLE の loop 競合、split transport、周辺機器の統合は、対象 hardware と version を固定して検証します。

## 参照資料

- [PicoRuby: PRK deprecated と R2P2 への案内](https://picoruby.org/)
- [公式 `Keyboard` API](https://picoruby.org/Keyboard.html)
- [R2P2 setup](https://picoruby.org/setup)
- [R2P2 troubleshooting](https://picoruby.org/troubleshooting)
- [ローカル Keyboard implementation](../repositories/picoruby/mrbgems/picoruby-keyboard/mrblib/keyboard.rb)
- [ローカル R2P2 build task](../repositories/picoruby/tasks/picoruby/r2p2.rake)
