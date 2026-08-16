# 実機、配線、公開キーボード事例

## 対応ボードの読み方

公式 Wiki の [Microcontroller boards and Keyboards](https://github.com/picoruby/prk_firmware/wiki/Microcontroller-boards-and-Keyboards) には、Raspberry Pi Pico、SparkFun Pro Micro RP2040、Adafruit KB2040、Seeed XIAO RP2040、RP2040-Zero 等の利用例があります。ただし同ページは主に 2022 年までの情報で、一覧は現在の正式な互換性保証ではありません。

RP2040 搭載だけでは判断せず、最低でも次を確認します。

- board の flash 容量と USB data 対応
- GPIO voltage は 3.3 V。5 V を GPIO へ直接入れない
- onboard LED、flash、USB、BOOTSEL 等が占有する pin
- pin 番号表記が GPIO 番号か物理番号か
- key matrix の diode 方向
- RGB LED や trackball の電流。USB/レギュレータの上限
- split connector の挿抜時短絡と TRRS hot-plug の危険

Pico 2 / RP2350 のコード対応はありますが 0.10.0 配布 UF2 には含まれないため、自前 build が必要です。

## 通常 matrix

matrix は row と column の交点に switch を配置し、少ない GPIO で多数のキーを読みます。たとえば 4 row × 5 column なら 9 GPIO で最大 20 position を表せます。

実機 bring-up は次の順が安全です。

1. USB と MCU 単体で PRK が起動することを確認する。
2. multimeter で GND、3.3 V、switch、diode 方向を確認する。
3. row/column を一組だけ定義した最小 keymap で試す。
4. 全 position を `KC_A`, `KC_B` のように固有にして scan 順を記録する。
5. 正しい配列が分かってから本来の layer を入れる。
6. RGB、encoder、split 等を最後に足す。

複数キーを押したときだけ ghosting や取りこぼしが起こるなら、software より先に diode の有無・向きと matrix 配線を調べます。

## split keyboard

現在の PRK は software mutual UART で左右を接続します。同じファームウェアと keymap を両方へ配置し、USB が接続された側を anchor として動かします。

実装時の要点:

- 左右で GND を必ず共有する。
- data pin と connector の対応を確認する。
- 左右に同じ PRK version を書き込む。
- `kbd.split = true` を `init_pins` より前に置く。
- anchor の論理方向が逆なら `set_anchor(:right)` を pin 初期化前に置く。
- 電源投入中の TRRS 挿抜は、一瞬の短絡を起こす connector 構造があるため避ける。
- 問題時は左右をそれぞれ単体 USB 接続し、keyscan が成立するか切り分ける。

古い Wiki や keymap には hardware UART 時代の pin 制約、one-way 通信、`mutual_uart_at_my_own_risk` が残ります。現在のコードを基準にし、異なる世代の手順を混在させないでください。

## 公開されている具体例

PRK 本体の `keyboards/` は実質空で、QMK のように多数の board definition を一つの本体 repo に収録する方式ではありません。keyboard ごとに別 repo の `keymap.rb` が公開されています。

### meishi2: 最小構成を学ぶ例

[prk_meishi2](https://github.com/picoruby/prk_meishi2) は、小さな matrix、三つの layer、mode key、memory stats、`bootsel!` がまとまった読みやすい例です。

現在公開されている keymap の骨格は次のようなものです。

- rows `[6, 7]`、columns `[28, 27]`
- `:default`、`:layer1`、`:layer2`
- tap で Space / hold で layer1
- tap で Enter / hold で layer2
- Proc から `PicoRubyVM.print_alloc_stats` と `kbd.bootsel!`

API を学ぶには適していますが、pin は meishi2 の回路用です。他の board へ数値だけ流用しません。

### CRKBD: split と複数機能の例

[prk_crkbd の keymap](https://github.com/picoruby/prk_crkbd/blob/main/keymap.rb) は、split、複数 layer、mode/composite key、RGB、sounder 等を組み合わせた例です。

一方、古い互換 call `mutual_uart_at_my_own_risk` も残っています。これは「公開例が常に現在の推奨 API の見本とは限らない」ことを示します。全体をコピーするのではなく、必要な機能だけを現行 `keyboard.rbs` と照合して移植します。

### cocot46plus: pointing device を含む高度な例

[prk_cocot46plus](https://github.com/picoruby/prk_cocot46plus) は、duplex matrix、RGB、encoder、ADNS5050 pointing device を組み合わせています。PRK でどこまで Ruby 化できるかを理解する資料として有用です。

ただし、この repo は古い `adns5050` library に依存し、現在の PRK gembox では当時の driver 構成と一致しません。現行 `master` で無変更に動作する例とは扱わず、使用時は当時の PRK version を特定するか driver を移植します。

## 公開 keymap を採用する前のチェックリスト

- 対象 keyboard の正確な revision が一致するか
- controller が同一か、少なくとも pin mapping が同一か
- keymap repo の最終更新日と対象 PRK version/tag
- `require` している library が現在の firmware または `/lib` にあるか
- split API が hardware UART 世代か software UART 世代か
- RGB の色順、LED 数、最大輝度と電力
- pointing device driver の interface と pin
- VIA の VID/PID、layer 数、保存 file
- `keymap.rb` に予期しない Proc、macro、外部入力処理がないか

## 完成後に残すべき情報

将来の修理用に、次をキーボードと一緒に version 管理します。

- 回路図と PCB revision
- controller board 名と pinout
- PRK tag/commit、または使用した UF2 自体と checksum
- `keymap.rb`、`prk-conf.txt`、`via_map.txt`、`lib/`
- 左右それぞれの書込み手順と anchor 向き
- USB cable、hub、OS を変えた動作確認結果
