# 調査方法と参照資料

## 調査時点と再現情報

調査日: 2026-08-15（Asia/Tokyo）

ローカルで参照した PRK Firmware:

```text
repository: https://github.com/picoruby/prk_firmware.git
branch:     master
commit:     22ae329260749d1ad75ac64fd551278d48a0b576
describe:   0.10.0-11-g22ae329
```

最新正式 release として確認したもの:

```text
version:    0.10.0
release:    2024-11-17
commit:     c10abe5
asset:      RP2040 MSC_FLASH UF2（zip / gzip）
```

`picoruby` も `repositories/picoruby` に clone し、後継 `picoruby-keyboard` と R2P2 の記述を比較しました。

## ローカルコードの主要参照先

### PRK Firmware

- [README](../repositories/prk_firmware/README.md)
- [CHANGELOG](../repositories/prk_firmware/CHANGELOG.md)
- [Rakefile](../repositories/prk_firmware/Rakefile)
- [CMakeLists.txt](../repositories/prk_firmware/CMakeLists.txt)
- [Dockerfile](../repositories/prk_firmware/Dockerfile)
- [compose.yml](../repositories/prk_firmware/compose.yml)
- [CI workflow](../repositories/prk_firmware/.github/workflows/ruby.yml)
- [C entry point](../repositories/prk_firmware/src/main.c)
- [keyboard C binding](../repositories/prk_firmware/src/keyboard.c)
- [USB descriptors](../repositories/prk_firmware/src/usb_descriptors.c)
- [USB/keymap reload task](../repositories/prk_firmware/mrblib/usb_task.rb)
- [Keyboard Ruby implementation](../repositories/prk_firmware/lib/picoruby/mrbgems/picoruby-prk-keyboard/mrblib/keyboard.rb)
- [Keyboard RBS](../repositories/prk_firmware/lib/picoruby/mrbgems/picoruby-prk-keyboard/sig/keyboard.rbs)
- [Firmware gembox](../repositories/prk_firmware/lib/picoruby/mrbgems/prk_firmware.gembox)
- [Keyboard tests](../repositories/prk_firmware/test/tests/keyboard_test.rb)
- [VIA tests](../repositories/prk_firmware/test/tests/via_test.rb)

### 後継 PicoRuby

- [PicoRuby keyboard README](../repositories/picoruby/mrbgems/picoruby-keyboard/README.md)
- [PicoRuby keyboard gem](../repositories/picoruby/mrbgems/picoruby-keyboard)

## 公式 Web 資料

### 現状、release、source

- [PicoRuby 公式サイト](https://picoruby.org/) — PRK の deprecated / unmaintained と R2P2 後継の案内
- [PRK Firmware GitHub](https://github.com/picoruby/prk_firmware)
- [PRK Firmware 0.10.0 release](https://github.com/picoruby/prk_firmware/releases/tag/0.10.0)
- [PicoRuby GitHub](https://github.com/picoruby/picoruby)

### 公式 Wiki

- [Tutorial](https://github.com/picoruby/prk_firmware/wiki/Tutorial)
- [Building a binary](https://github.com/picoruby/prk_firmware/wiki/Building-a-binary)
- [Docker](https://github.com/picoruby/prk_firmware/wiki/Docker)
- [Keyscan matrix](https://github.com/picoruby/prk_firmware/wiki/Keyscan-matrix)
- [Layers and mode key](https://github.com/picoruby/prk_firmware/wiki/Layers-and-mode-key)
- [Split type keyboard](https://github.com/picoruby/prk_firmware/wiki/Split-type-keyboard)
- [RGBLED](https://github.com/picoruby/prk_firmware/wiki/RGBLED)
- [Rotary encoder](https://github.com/picoruby/prk_firmware/wiki/Rotary-encoder)
- [Mouse](https://github.com/picoruby/prk_firmware/wiki/Mouse)
- [VIA and Remap](https://github.com/picoruby/prk_firmware/wiki/VIA-and-Remap)
- [Debug print](https://github.com/picoruby/prk_firmware/wiki/Debug-print)
- [BOOTSEL mode](https://github.com/picoruby/prk_firmware/wiki/BOOTSEL-mode-of-RP2040)
- [Microcontroller boards and Keyboards](https://github.com/picoruby/prk_firmware/wiki/Microcontroller-boards-and-Keyboards)

Wiki は歴史的な利用例として重要ですが、ページによって更新時期が古いものがあります。build task 名、SDK version、split UART、driver の有無はローカル source を優先しました。

## 発表と歴史資料

- [RubyKaigi Takeout 2021: PRK Firmware](https://rubykaigi.org/2021-takeout/presentations/hasumikin.html)
- [RubyConf 2021 発表動画](https://www.youtube.com/watch?v=SLSwn41iJX4)
- [Ruby Prize 2021 finalist interview](https://rubyprize.jp/21_rubyprize/21_iv-nominees02-ja.html)
- [KBD.news: PRK firmware](https://kbd.news/PRK-firmware-1370.html)

外部記事は当時の反響や位置づけの把握に使い、現在の build/API の根拠にはしていません。

## 公開 keyboard/keymap 例

- [prk_meishi2](https://github.com/picoruby/prk_meishi2) — 小規模 matrix と mode key
- [prk_crkbd keymap](https://github.com/picoruby/prk_crkbd/blob/main/keymap.rb) — split、RGB、sounder 等
- [prk_cocot46plus](https://github.com/picoruby/prk_cocot46plus) — duplex、encoder、pointing device の歴史的な高度例

これらは独立 repository で、PRK 本体の現在 commit との組合せを保証するものではありません。

## 調査上の判断規則

矛盾した情報は次の順に扱いました。

1. 対象 commit の executable source と build definition
2. Git commit/tag/release と release asset
3. 同 repository の README/CHANGELOG
4. 公式 Wiki
5. 公開 keyboard repo、発表、外部記事

特に次の差を source で補正しました。

- Wiki の旧 build task と現在の `pico` / `pico2` task
- 現行 Rakefile の Pico SDK 2.1.0 と Dockerfile の SDK 1.5.1
- hardware UART 時代の split pin 制約と現在の software mutual UART
- 0.10.0 release 後に追加された RP2350 対応
- 過去の pointing-device driver と現在の gembox の差

## 未実施・保証しない範囲

- この調査環境での UF2 end-to-end build と実機 flash
- 列挙されたすべての keyboard/board combination の動作試験
- OS ごとの VIA/Remap、consumer key、gamepad 互換性試験
- 電気設計、EMC、USB certification、VID/PID 使用権の保証
- 保守終了後の fork や非公式 patch の網羅

今後実機調査を追加する場合は、結果を board/revision、PRK commit、UF2 checksum、host OS、配線、再現手順とともに記録してください。
