# キーマップ API 実践ガイド

この章は現在の `master` にある [`keyboard.rb`](../repositories/prk_firmware/lib/picoruby/mrbgems/picoruby-prk-keyboard/mrblib/keyboard.rb) と [`keyboard.rbs`](../repositories/prk_firmware/lib/picoruby/mrbgems/picoruby-prk-keyboard/sig/keyboard.rbs) を基準にしています。公開キーマップは作成時の PRK version に依存するため、まず単純な構成で起動してから機能を足します。

## 定義する順序

互換性と読みやすさのため、次の順を推奨します。

1. `Keyboard.new`
2. split、VIA、anchor 等、pin 初期化前に必要な option
3. `init_pins`、`init_matrix_pins`、または `init_direct_pins`
4. `add_layer`
5. mode/composite key、hook、macro
6. RGB、encoder、sounder 等の feature
7. 最後に一度だけ `start!`

```ruby
kbd = Keyboard.new
kbd.split = true
kbd.set_anchor(:right)
kbd.init_pins(rows, cols)
kbd.add_layer :default, keys
# feature definitions ...
kbd.start!
```

## matrix の定義

### 通常の row/column matrix

```ruby
kbd.init_pins([6, 7], [28, 27])
```

`init_pins` は通常の Col2Row matrix 用の簡略 API です。diode の方向と回路が一致しない場合は押下を読めません。

### 任意 matrix、duplex、round-robin

`init_matrix_pins` では scan position ごとに input/output pin の組を並べられます。存在しない位置に `nil` を使う構成もあります。layer の key 配列には、その scan position と同じ順序・個数で値を置きます。

複雑な配線は公開キーマップをコピーするだけでなく、対象 API の現在の引数と回路図を照合してください。duplex は通常 matrix と電気的前提が異なります。

### direct scan

```ruby
kbd.init_direct_pins([2, 3, 4, 5])
```

一つの GPIO に一つの switch を割り当てます。4 pin なら layer にも 4 position が必要です。

## layer

```ruby
kbd.add_layer :default, %i[
  KC_Q KC_W KC_E KC_R
  KC_A KC_S KC_D KC_F
]

kbd.add_layer :raise, %i[
  KC_1 KC_2 KC_3 KC_4
  KC_LEFT KC_DOWN KC_UP KC_RIGHT
]
```

現在の実装では最初に追加した layer が default になります。古い資料との互換性と意図の明示のため、最初の名前を `:default` にしておくのが無難です。

`KC_NO` と別名 `XXXXXXX` は「この位置からキーを送らない」です。QMK の transparent key のように下の layer へ自動 fall-through する意味ではありません。公開 QMK keymap を移植するときに特に注意します。

layer の操作には raise/lower、lock/unlock 等があります。押下中だけ layer を切り替える場合は mode key と組み合わせるのが一般的です。

## mode key: tap と hold

`define_mode_key` は、短く押した動作と長押し動作を一つの位置に割り当てます。

```ruby
kbd.define_mode_key :SPC_RAISE, [
  :KC_SPC,  # release/tap
  :raise,   # hold layer
  200,      # hold とみなす時間 ms
  150       # 再押下の判定時間 ms
]
```

tap 側と hold 側には key、key 配列、layer 名、modifier、Proc 等、API が受け付ける対象を指定できます。閾値を短くしすぎると通常入力が hold になり、長すぎると layer の反応が遅れます。scan/debounce 条件も含めて実機で調整してください。

## composite key

複数キーの同時送信を名前付きで登録できます。

```ruby
kbd.define_composite_key :COPY, %i[KC_LCTL KC_C]
kbd.define_composite_key :PASTE, %i[KC_LCTL KC_V]
```

登録名を layer の位置に置いて使います。macOS 用には GUI modifier を使うなど、host OS の shortcut に合わせます。

## Proc と hook

Ruby の処理をキーへ割り当てられます。

```ruby
BOOTSEL = Proc.new { kbd.bootsel! }
MEMORY  = Proc.new { PicoRubyVM.print_alloc_stats }
```

`before_report`、`on_start`、`output_report_changed` 等の hook もあります。柔軟ですが、key scan loop 内で長い処理、blocking I/O、大量 allocation を行うとキー入力全体が遅延します。Proc は短く保ち、周辺機器処理は可能なら専用 task/API を使います。

## キー送信と macro

`send_key` はコードから key event を送り、`macro` は一連の入力を組み立てる用途に使われます。Consumer key は keyboard report とは別の HID report です。音量、再生等の `KC_VOLU`、`KC_VOLD` などを使う例では consumer key gem/API の初期化も確認してください。

自動入力 macro は、接続先で意図しない command や秘密情報を入力し得ます。接続直後や layer 切替直後に勝手に発火しないようにし、検証は安全な editor 上で行います。

## debounce

```ruby
kbd.set_debounce :per_key
```

選択肢は `:none`、`:per_row`、`:per_key` です。threshold を指定できる API もあります。切り分けの基本は次のとおりです。

- 同じ row の複数キーが影響する: wiring、diode、`:per_row` の条件を疑う
- 一キーだけ二重入力: switch と `:per_key` threshold を確認
- mode key の tap/hold だけ不安定: debounce と mode key の時間を別々に調整

## split keymap

```ruby
kbd = Keyboard.new
kbd.split = true
kbd.set_anchor(:right) # USB 側を論理右として扱う場合
kbd.init_pins(rows, cols)
```

- `split = true` と `set_anchor` は pin 初期化前に行う。
- 同じ `keymap.rb` を左右へ置く。
- USB 接続側が anchor、反対側が partner になる。
- 現在の実装は software mutual UART を使う。古い hardware one-way UART 手順を混ぜない。
- data 線だけでなく GND も共有する。

古い例にある `mutual_uart_at_my_own_risk` は現行実装では互換用の名残で、現在の方式を有効にするための必須 call ではありません。また古い Wiki の UART0 固定 pin 制約は hardware UART 時代の情報を含みます。現在も電気的安全性、通信品質、基板固有の予約 pin は別途検証が必要です。

左右を鏡像配置した matrix には `split_style = :right_side_flipped_split` を使う例があります。論理配列と物理の左右を紙に書き出し、一キーずつ確認するのが確実です。

## 外部 Ruby library

0.9.23 以降は `PRK DRIVE/lib` に Ruby file を置き、通常の `require` / `load` で利用できます。

```text
PRK DRIVE/
  keymap.rb
  lib/
    my_driver.rb
```

```ruby
require "my_driver"
```

PicoRuby は CRuby の完全実装ではなく、memory も限られます。PC の gem をそのままコピーできるとは限りません。依存する class/module と native gem の有無を確認し、小さな library から試します。
