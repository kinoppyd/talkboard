# RGB、エンコーダ、VIA、マウス等の機能

PRK は keyscan 以外にも多くの mrbgems を組み込みます。すべてを一度に有効化せず、基本 keymap が安定してから機能ごとに追加してください。古い Wiki と現在の API が異なる場合があるため、[`prk_firmware.gembox`](../repositories/prk_firmware/lib/picoruby/mrbgems/prk_firmware.gembox) と各 gem の Ruby/RBS 実装を確認します。

## RGB LED

基本形は、data pin、underglow 数、backlight 数、RGBW flag を `RGB.new` へ渡します。

```ruby
rgb = RGB.new(0, 12, 0, false)
rgb.effect = :rainbow_mood
kbd.append rgb
```

実装・例には `:swirl`、`:rainbow_mood`、`:breath`、`:nokogiri`、`:static`、`:ruby` 等の effect があります。version によって名称や parameter が異なるため、対象 commit の [`picoruby-prk-rgb`](../repositories/prk_firmware/lib/picoruby/mrbgems/picoruby-prk-rgb) を確認します。

電気面では次を先に計算します。

- LED 個数 × 最大電流が USB と regulator の上限を超えないか
- data signal の voltage 条件
- RGB / GRB 等の色順
- underglow と key backlight の個数
- split の左右で data chain がどう接続されるか

最大輝度の白は大電流になります。bring-up 時は低い輝度と少数 LED から始めます。

## Rotary Encoder

encoder の A/B pin と、clockwise/counter-clockwise block を定義し、keyboard に追加します。block 内から `send_key` を呼ぶことで、音量、scroll、layer 操作等を実装できます。

機械式 encoder はチャタリングし、A/B の順序を逆にすると回転方向が逆になります。左右 split では encoder がどちら側に接続されるかも指定・検証します。回転だけが取りこぼされる場合は、key matrix ではなく encoder task、pin、pull-up、処理 block の重さを切り分けます。

公式 Wiki: [Rotary encoder](https://github.com/picoruby/prk_firmware/wiki/Rotary-encoder)

## Consumer Control

音量、mute、再生/停止等は通常 keyboard key ではなく USB Consumer Control report です。PRK には consumer key gem があり、`KC_VOLU`、`KC_VOLD` 等を扱えます。

```ruby
require "consumer_key"
```

現在の `Keyboard` 実装も、Consumer key を使うにはこの `require` が必要だと明記しています。

host OS により解釈や対応 key が異なります。文字 key が動くのに media key だけ動かない場合は、keyboard report ではなく consumer report の初期化、keycode、OS 対応を確認します。

## Sounder と MML

圧電 sounder を GPIO に接続し、MML で曲を登録・再生できます。

```ruby
sounder = Sounder.new(15)
# add_song / play / replay 等は対象 version の API を確認
kbd.append sounder
```

GPIO で直接駆動できる部品か、transistor が必要な電流かを datasheet で確認します。音の再生が keyscan を阻害しないかも実機で測ります。

## Mouse / Pointing Device

0.9.21 以降の mouse 機能は、I2C、SPI、ADC 等で sensor/driver を接続し、mouse report を keyboard report と並行して送る設計です。公式 Wiki でも experimental な側面が説明されています。

- [Mouse Wiki](https://github.com/picoruby/prk_firmware/wiki/Mouse)
- [cocot46plus の旧実例](https://github.com/picoruby/prk_cocot46plus)

古い ADNS5050 例は現行 firmware に driver がそのまま含まれないため、現在の `master` で無変更に動くとは限りません。また changelog には split の partner 側で動かない制限が記された世代があります。pointing device 採用時は、sensor、driver、PRK version、接続側を一組で固定します。

## Joystick / Gamepad

Joystick は keyboard/mouse と別の HID interface で公開されます。ADC 等から axis/button を生成できます。OS や game/application により calibration と認識方法が異なるため、まず OS の game controller test で raw な axis/button を確認します。

## VIA と Remap

PRK 0.9.14 以降は VIA protocol の一部を実装します。一般的な設定順は次のとおりです。

```ruby
require "via"

kbd = Keyboard.new
kbd.via = true
# VIA で扱う layer 数等を pin 初期化前に設定
kbd.init_pins(rows, cols)
# layers ...
kbd.start!
```

`PRK DRIVE/prk-conf.txt` は次の一行形式です。

```text
0xVID:0xPID:PRODUCT_NAME
```

変更は再起動後に USB identity へ反映されます。通常の VIA desktop app では自動認識されず、[Remap](https://remap-keys.app/) を使う手順が公式 Wiki で案内されています。PRK の対応は VIA 全機能ではなく部分対応です。

運用上の注意:

- 変更前に `keymap.rb`、`prk-conf.txt`、`via_map.txt` を backup
- layer 数と key position 数を固定してから VIA を有効化
- VID/PID を変えると OS が別 device として扱う場合がある
- WebHID permission は信頼できる site/device にだけ許可
- 商品化する場合の VID/PID 利用権は別途確認

公式 Wiki: [VIA and Remap](https://github.com/picoruby/prk_firmware/wiki/VIA-and-Remap)

## Serial と対話機能

USB CDC は debug print に加えて、version により serial input、Ruby/IRB mode 等にも使われます。0.10.0 では起動時に `s` を送って keymap を skip できます。

serial へ出す log が多すぎると timing に影響し得ます。通常運用では必要な log だけにし、対話 mode や評価機能を有効にした状態で不特定の host へ接続しないようにします。

## `inject_switch` と外部入力

実装には物理 scan 以外から switch 状態を注入する API があります。独自 sensor、通信、test との統合に便利ですが、外部値の範囲、連打、release 漏れを防ぐ必要があります。異常時に key が押しっぱなしにならない fail-safe を設けます。

## 組込みで確認できない機能

現在の PRK は TinyUSB を中心とする USB firmware で、Bluetooth keyboard の標準手順は確認できません。また OLED 専用の完成した組込み class も主要 API には見当たりません。I2C/SPI と Ruby library を使った独自実装の余地はありますが、「PRK が標準対応」と「利用者が driver を実装できる」は区別すべきです。
