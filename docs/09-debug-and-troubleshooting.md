# デバッグとトラブルシューティング

## 最初に確保するもの

- 動作が分かっている UF2
- 最小の `keymap.rb`
- `PRK DRIVE` 全体の backup
- keyboard の回路図、controller pinout、multimeter
- 115200 bps の serial terminal
- 使用中の PRK tag/commit と board revision

問題が複数ある状態で feature を足さず、USB、keymap parse、keyscan、layer、周辺機能の順に一段ずつ確認します。

## USB drive が現れない

まず名前を区別します。

- `RPI-RP2`: BOOTSEL mode。UF2 を書くための RP2040 drive
- `PRK DRIVE`: PRK の MSC build が起動した後の keymap drive

確認順:

1. charge-only でない USB cable を使う。
2. hub を外し、別 port/host で試す。
3. BOOTSEL を押しながら接続し `RPI-RP2` が現れるか確認。
4. 正しい RP2040 用 `MSC_FLASH` UF2 を再書込み。
5. serial device だけでも列挙されていないか OS の USB 情報を確認。
6. `NO_MSC` build を書いた可能性を確認。この場合 `PRK DRIVE` は仕様上現れない。
7. RP2350 に RP2040 release UF2 を使っていないか確認。

## `keymap.rb` 更新後に動かない

1. serial output の Ruby syntax/runtime error を読む。
2. 0.10.0 なら起動後約 2 秒以内に `s` を送り、keymap を skip。
3. PC 上の最小 keymap を `PRK DRIVE` へコピー。
4. 保存完了後 5～7 秒程度待つ。
5. reload task 自体が止まった場合は USB を安全に eject して再起動。

PC の `ruby -c keymap.rb` は単純な syntax typo の予備検査には使えますが、PicoRuby と CRuby の対応構文・組込み class は同一ではありません。最終判定は対象 PRK の compiler と実機 serial error です。

drive 上で直接編集せず、PC 側で一回の完成 file にしてコピーします。editor が作る swap、backup、metadata file は `.gitignore` の対象でも、FAT drive へ書かれることがあります。

## キーが全く反応しない

- `start!` が最後に呼ばれているか
- row/column に GPIO 番号を使っているか
- `init_pins` の row/column 順と diode 方向
- switch の導通、GND、solder bridge
- layer 配列の position 数
- serial に scan/setup error がないか
- board 固有の予約 pin を使っていないか

一つの switch と一組の pin だけの最小 keymap へ戻します。software と hardware を同時に大きく変えないことが重要です。

## キー位置がずれる

全 position に異なる keycode を順番に割り当て、実際に出た順を表にします。原因候補:

- row/column list の順序
- physical layout と scan order の取り違え
- `nil` position の不足
- split の anchor/right-side flip
- duplex/round-robin の position 定義

見た目の keyboard 配列と layer の一次元配列は直接一致するとは限りません。

## 二重入力、取りこぼし、押しっぱなし

- 一キーのみ: switch、solder、`:per_key` debounce
- row 全体: row wiring、diode、`:per_row` debounce
- 同時押しのみ: ghosting、diode 方向、power/signal integrity
- tap/hold のみ: mode key threshold と debounce を別々に調整
- Proc 実行時のみ: blocking 処理や allocation を減らす
- RGB 最大輝度時のみ: 電源降下を疑う

押しっぱなしになった場合、まず USB を抜いて host への入力を止めます。macro や injected switch は release event の漏れも確認します。

## split の反対側が動かない

1. 左右を一台ずつ USB 接続し、それぞれ単体 keyscan が動くか確認。
2. 両方が同じ PRK version と同じ `keymap.rb` か確認。
3. `split = true` が `init_pins` より前か確認。
4. GND が共有され、data 線が想定 GPIO へ届くか導通確認。
5. anchor の向きが違うだけなら `set_anchor` を見直す。
6. 古い hardware UART/one-way 手順を現行 software UART と混ぜていないか確認。
7. RGB、mouse、encoder を一旦外し、split keyscan のみにする。

電源が入ったまま TRRS plug を挿抜すると conductor が滑る途中で短絡し得ます。電源を切って配線を変更します。

## VIA/Remap で認識されない

- `require "via"` と `kbd.via = true` の順序
- VIA layer 数と key position 数
- `prk-conf.txt` の `0xVID:0xPID:PRODUCT` 形式
- 設定後に再起動したか
- 通常 VIA desktop app ではなく Remap を使っているか
- browser の WebHID permission
- OS が古い VID/PID descriptor を cache していないか
- `via_map.txt` の破損。backup と比較

VIA を外した最小 keymap が動くことを確認してから再度有効にします。

## RGB、encoder、sounder、mouse の問題

| 機能 | 最初の切り分け |
|---|---|
| RGB | LED 数、data pin、色順、輝度、電流、最初の LED の向き |
| Encoder | A/B pin、回転方向、pull-up、block 内処理、split side |
| Sounder | pin、部品の駆動電流、PWM、長い再生が scan を妨げないか |
| Mouse | driver が現在の build に存在するか、bus/pin、sensor ID、split side 制限 |
| Joystick | OS の controller test、axis range、ADC calibration |

公開例が古い場合、API 名だけでなく gem が firmware に組み込まれているかを `prk_firmware.gembox` で調べます。

## memory と長時間動作

Ruby object を loop ごとに作る処理、増え続ける配列/文字列、頻繁な log は memory と timing を悪化させます。`PicoRubyVM.print_alloc_stats` を安全な debug key に割り当て、操作前後を比較できます。

確認項目:

- idle 中も allocation が増え続けるか
- RGB effect や macro を止めると安定するか
- 外部 library を一つずつ外した場合
- debug build と release build の差
- USB host や suspend/resume 後だけ再現するか

## build error

build 時の主な確認順:

1. `git submodule status --recursive`
2. `PICO_SDK_PATH` の実体と SDK tag 2.1.0
3. `PICO_EXTRAS_PATH`
4. CMake 3.24 以上
5. Arm GNU toolchain が PATH 上にあるか
6. `bundle exec rake -T` に現行 task が出るか
7. 古い build cache を対象 directory ごとに clean
8. 現行 Dockerfile の SDK 1.5.1 mismatch を踏んでいないか

詳細は[ソースからのビルド](08-build.md)を参照してください。

## BOOTSEL への戻り方

優先順:

1. BOOTSEL button を押しながら USB 接続
2. 対応 board/firmware なら reset を素早く二回
3. 正常な keymap に用意した `kbd.bootsel!`
4. 0.10.0 の startup `s` で keymap を skip して修復

公式 Wiki: [BOOTSEL mode of RP2040](https://github.com/picoruby/prk_firmware/wiki/BOOTSEL-mode-of-RP2040)、[Debug print](https://github.com/picoruby/prk_firmware/wiki/Debug-print)
