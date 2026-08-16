# 歴史と主要な変更

## 誕生の背景

PRK Firmware の最初の Git commit は 2021-03-09 です。RP2040 を搭載した Raspberry Pi Pico が登場した時期に、PicoRuby をキーボードファームウェアとして実用化するプロジェクトとして始まりました。2021-04-14 に public beta が告知され、同年の [RubyKaigi Takeout 2021](https://rubykaigi.org/2021-takeout/presentations/hasumikin.html) と [RubyConf 2021](https://www.youtube.com/watch?v=SLSwn41iJX4) でも紹介されました。

[Ruby Prize 2021 の公式インタビュー](https://rubyprize.jp/21_rubyprize/21_iv-nominees02-ja.html)では開発者の Hitoshi Hasumi 氏が finalist として紹介され、PicoRuby と PRK Firmware の目的や、小さなマイコン上で Ruby を動かす取り組みが説明されています。リポジトリの README には Fukuoka Ruby Award 2022 のバッジも掲示されています。

## 主要なマイルストーン

以下は [CHANGELOG](../repositories/prk_firmware/CHANGELOG.md)、Git tag、release を照合した要約です。

| 時期 | バージョン / 出来事 | 意味 |
|---|---|---|
| 2021-03 | 最初の commit | RP2040 上の Ruby キーボード実装が開始 |
| 2021-04 | public beta | 一般利用に向けた公開 |
| 2021-05～06 | RGB、ロータリエンコーダ | キースキャン以外の周辺機能を拡張 |
| 2021-09 | 0.9.0 | `PRK DRIVE` と `keymap.rb` 自動再読込を導入。通常利用での再コンパイルを不要にした |
| 2021-09 | 0.9.1 | ダブルリセットで BOOTSEL へ移行 |
| 2021-10～11 | 0.9.3～0.9.6 | キー別名、左右反転 split、静的テスト、RGB 制御を追加 |
| 2022-01～03 | 0.9.8～0.9.11 | エンコーダ改善、direct scan、composite key、duplex/round-robin scan |
| 2022-05 | 0.9.13 | debounce、ソフトウェア BOOTSEL、`keymap.rb` 領域 10 KiB |
| 2022-06 | 0.9.14 | VIA/Remap、Caps Lock indicator |
| 2022-09 | 0.9.15 | joystick、任意名の default layer |
| 2022-11 | 0.9.17～0.9.18 | Consumer key、Serial、Mouse、RGB matrix、Sounder/MML、BIOS 等 |
| 2022-12 | 0.9.19～0.9.20 | macOS/iOS 向け修正。hardware one-way UART を非推奨にし mutual software UART へ統一 |
| 2023-05 | 0.9.21 | Mouse と Mass Storage を再実装し `PRK DRIVE` を復活 |
| 2023-06 | 0.9.22 | software bitbang SPI |
| 2023-09 | 0.9.23 | `/lib` の外部 Ruby ファイルを `require` / `load` |
| 2024-11 | 0.10.0 | 新しい PicoRuby と Prism compiler、起動時 `s` による壊れた keymap の回避 |
| 2024-11 | `master` の後続変更 | RP2350 / Raspberry Pi Pico 2 対応 |
| 2026 | 公式サイトで deprecated | PRK の保守を終了し、R2P2 `Keyboard` を後継に指定 |

### 0.9.12 について

0.9.12 は changelog 上で revoked（撤回）とされています。古い実機やキーマップからバージョンを再現するときは、この版を基準にしない方が安全です。

### 日付の不整合

CHANGELOG の 0.9.19 と 0.9.20 の見出しには、バージョン順と日付順が逆転して見える箇所があります。本資料の順序は Git tag と release の前後関係を優先しました。履歴を厳密に引用する場合は commit と tag を直接確認してください。

## PRK がもたらした設計上の特徴

### キーマップをコンパイル対象から実行対象へ

0.9.0 の `PRK DRIVE` 導入が大きな転換点です。UF2 にすべてのキーマップを焼き込むだけでなく、USB ドライブ上の Ruby ファイルを実機が読み、保存後に再ロードする開発体験を実現しました。これは PRK が QMK と比較されるときの中心的な差です。

### Ruby を設定 DSL に限定しない

レイヤ配列だけでなく、`Proc`、フック、マクロ、周辺機器ドライバ、外部ライブラリまで Ruby で動かせます。高い自由度と引き換えに、文法エラー、無限ループ、メモリ消費もユーザーの `keymap.rb` が引き起こし得ます。0.10.0 の起動時リカバリは、この自由度を実機で扱うための改善です。

### PicoRuby 本体への知見の還元

PRK のライフサイクル後半で、キーボード専用リポジトリから PicoRuby/R2P2 側へ機能を再編する方向が明確になりました。現在の後継実装は [`picoruby-keyboard`](../repositories/picoruby/mrbgems/picoruby-keyboard/README.md) にあり、PRK は組み込み Ruby の実験・実用化を進めた歴史的プロジェクトとして読むことができます。

## バージョン固定の考え方

既存キーボードを再現する場合、単に最新 `master` を使うより次の三点を一組で記録する方が確実です。

- UF2 または PRK の tag / commit
- `keymap.rb` と `/lib` のファイル一式
- 使用ボード、GPIO 配線、左右 split の向き

公開キーマップには、当時は存在したが後に削除・変更された API やドライバが含まれる場合があります。たとえば古い split キーマップの `mutual_uart_at_my_own_risk` は現在は実質不要であり、古いマウス例のドライバが現在の組込み gembox に含まれないケースもあります。
