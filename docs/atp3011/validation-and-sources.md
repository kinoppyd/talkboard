# 検証と参照資料

## 実施済みの検証

検証日: 2026-10-11。PC上のCRubyで実行するI²C・GPIO・時刻のテストダブルを使った検証。電気回路のエミュレーションや実際のPicoRuby実機試験ではない。

worktreeのルートで実行:

```sh
ruby -c examples/atp3011/atp3011.rb
ruby -c examples/atp3011/speak.rb
ruby test/atp3011_test.rb
git diff --check
```

テストは標準の `minitest` と `stringio` を使う。環境のRubyにminitestがない場合はホスト側のテスト環境に追加する。本開発環境では `/usr/bin/ruby` で実行できる。マイコンへテストファイルを転送する必要はない。

実行結果: **18 tests / 71 assertions、失敗・エラー0**。2つの実行用Rubyファイルの構文、追加ファイルの末尾空白、追加資料のローカルリンクも確認済み。

確認範囲:

- リセットパルス、起動待機、バージョン読み出し。
- 正常発話、Busyと0xFF、Busyを観測しない即時完了、CR終端、10 ms以上のポーリング間隔。
- 127バイト境界、128バイト以上、非ASCII、制御文字、コマンド混入の拒否。
- 句読点・アクセント・数字タグを改変せず送信。
- LSIエラー、NACK、短いI²C読み書き、不正応答、タイムアウトと同期喪失後の送信停止。
- リセットによる復帰、空行、複数行の対話、EOF、`:quit`、`:reset`、割込み時の終了処理。

回路については、メーカーPDFのピン配置・基本回路・LM386参考回路を画像で確認し、配線表と照合した。C4/R4とC9/SPのカットオフは理想値計算のみ。実機の音圧、PWM残留、アンプの発振、消費電流、熱、USB転送は未測定。PicoRuby上での実行・UF2ビルドも未実施なので、このホストテストだけでハードウェア動作を保証しない。

## 組み立て後の受け入れテスト

| 順序 | 操作・測定 | 合格条件 |
|---:|---|---|
| 1 | 無通電でピン向き・電源レール・C9極性・全VCC/GNDを確認 | 回路表どおり、短絡なし |
| 2 | VR最小でUSB接続、電圧測定 | U1電源が約3.3 V、U2電源が約5 V、発熱・再起動なし |
| 3 | R2P2でAPI確認、2ファイル転送と読み戻し | 読み込みエラーなし、内容が一致 |
| 4 | `/home/speak.rb` 実行 | `[ready]` とバージョン、`say>` |
| 5 | `konnichiwa.`、次に `ohayo-.` | それぞれ発話し、完了後に次のプロンプト |
| 6 | 空行、ひらがな、128文字のASCIIを入力 | 空行は無音、それ以外はエラー。次の正常入力で動作継続 |
| 7 | `zzz` など無効な読み記号の後に正常入力 | LSIエラーが表示され、その後の正常発話が可能 |
| 8 | `:reset`、続けて正常入力、`:quit` | リセット後に発話でき、終了後シェルへ戻る。再実行可能 |
| 9 | スクリプトを再実行し空行でCtrl-D | EOFで終了し、R2P2へ戻る |
| 10 | USBを抜きSDAを外す→電源ON→実行 | 通信エラーが有限時間で返る。電源OFFで復旧後、再実行すれば成功 |
| 11 | 音量を少しずつ上げ、電源降下・発熱・ノイズを観察 | 必要な音量で電源安定・許容音質。割れる前の位置を上限にする |

発話完了の応答と可聴出力は別々に確認する。可能ならロジックアナライザでアドレス0x2E、100 kHz、CR終端、読み出し間隔も測る。オシロスコープでU1 AOUT、RC後、U2 OUTを見れば音源・フィルタ・アンプの切り分けができる。プローブのGNDは回路GNDへ接続する。

## 一次資料

| 資料 | 用途 |
|---|---|
| [AQUEST ATP3011データシート](https://www.a-quest.com/archive/manual/atp3011_datasheet.pdf) | §3–5: DIPピン配置と基本回路、§7–9:モード・プロトコル、§13:アナログ回路とエラー、§14:音声記号 |
| [TI LM386データシート Rev.D](https://www.ti.com/lit/ds/symlink/lm386.pdf) | ピン配置、品種ごとの電源条件、図9-1のゲイン20回路、入力・出力バイアス |
| [TI LM386N-1/NOPB製品情報](https://www.ti.com/product/LM386/part-details/LM386N-1/NOPB) | 部品型番とDIPパッケージ |
| [Raspberry Pi Pico 2 Wデータシート](https://datasheets.raspberrypi.com/picow/pico-2-w-datasheet.pdf) | ピン番号、GPIO、3V3/VBUS/GND |
| [R2P2 setup](https://picoruby.org/setup) | ボードへのR2P2導入 |
| [Terminal Emulator](https://picoruby.org/terminal-emulator)、[Web Terminal](https://picoruby.org/terminal) | USBシリアル接続、4.0以降の対象範囲、File Editor/Upload |
| [PicoRuby I2C API](https://picoruby.org/I2C.html) | 公開API。実装細部は下の固定コミットを優先 |

## ローカルソースとの照合

対象は親チェックアウトの `repositories/picoruby`、commit `371d176f1bfd834d18ff2a8c86d2667b51b0fd32`。2026-10-11時点のGitHub最新コミットを意味しない。下のリンクは検証した内容に固定している。

- [I2C Ruby API](https://github.com/picoruby/picoruby/blob/371d176f1bfd834d18ff2a8c86d2667b51b0fd32/mrbgems/picoruby-i2c/mrblib/i2c.rb): コンストラクタとタイムアウトの単位。
- [I2C mruby binding](https://github.com/picoruby/picoruby/blob/371d176f1bfd834d18ff2a8c86d2667b51b0fd32/mrbgems/picoruby-i2c/src/mruby/i2c.c): Stringの一括送信、送信数、String読み出し、IOError。
- [I2C RP2 port](https://github.com/picoruby/picoruby/blob/371d176f1bfd834d18ff2a8c86d2667b51b0fd32/mrbgems/picoruby-i2c/ports/rp2040/i2c.c): GP6/7のI2C1割り当て、RP2350共通のユニット名。
- [GPIO](https://github.com/picoruby/picoruby/blob/371d176f1bfd834d18ff2a8c86d2667b51b0fd32/mrbgems/picoruby-gpio/mrblib/gpio.rb): 出力ピンの初期化。
- [Machine mruby binding](https://github.com/picoruby/picoruby/blob/371d176f1bfd834d18ff2a8c86d2667b51b0fd32/mrbgems/picoruby-machine/src/mruby/machine.c): uptime_us。
- [RP2標準入力](https://github.com/picoruby/picoruby/blob/371d176f1bfd834d18ff2a8c86d2667b51b0fd32/mrbgems/picoruby-machine/ports/rp2040/machine.c)、[io/console](https://github.com/picoruby/picoruby/blob/371d176f1bfd834d18ff2a8c86d2667b51b0fd32/mrbgems/picoruby-io-console/mrblib/io-console.rb): cooked入力、エコー、Backspace、Ctrl-D。
- [shell](https://github.com/picoruby/picoruby/blob/371d176f1bfd834d18ff2a8c86d2667b51b0fd32/mrbgems/picoruby-shell/mrblib/shell.rb): 絶対パスのスクリプト実行、PicoModem接続。
- [pico2_w build config](https://github.com/picoruby/picoruby/blob/371d176f1bfd834d18ff2a8c86d2667b51b0fd32/build_config/r2p2-picoruby-pico2_w.rb)、[build task](https://github.com/picoruby/picoruby/blob/371d176f1bfd834d18ff2a8c86d2667b51b0fd32/tasks/picoruby/r2p2.rake): PicoRuby VM、RP2350、ボード選択。

固定リンクはworktreeに `repositories/` がなくても参照できる。取得したメーカーPDFのコピーや派生画像はGit管理せず、公式URLを参照する。
