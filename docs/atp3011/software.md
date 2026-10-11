# PicoRubyの準備と対話読み上げ

## 対象環境

Raspberry Pi Pico 2 W、R2P2の **PicoRuby VM版、pico2_w用** を使用する。PRK FirmwareやMicroPythonのUF2では実行できない。照合したソースはPicoRuby commit `371d176f1bfd834d18ff2a8c86d2667b51b0fd32`。この構成にはI²C、GPIO、標準入出力、`io/console`、`Machine.uptime_us` が含まれる。別バージョンのファームウェアでは下のAPIチェックを行う。

新規導入は[公式セットアップ](https://picoruby.org/setup)からPico 2 W対応のR2P2を選ぶ。UF2書き込みは、BOOTSELを押しながらUSB接続し、現れたRP2350のBOOTドライブへ対象UF2をコピーする。BOOTドライブはRubyファイルの保存先ではない。通常起動後のR2P2ファイルシステムへはUSBシリアル経由で転送する。

ソースから同じ構成を生成する場合は、ツールチェーン、CMake、Ninja、Ruby/Rake、必要なsubmoduleを用意したPicoRubyチェックアウトで以下を実行する。

```sh
# このプロジェクトの新しい worktree のルートから
cd ../../repositories/picoruby
git rev-parse HEAD
git submodule update --init --recursive
rake r2p2:picoruby:pico2_w:prod
```

タスクは `tasks/picoruby/r2p2.rake`、設定は `build_config/r2p2-picoruby-pico2_w.rb`。参照コミットはPico SDK `2.3.0` を要求する。実行ログで生成先の `R2P2-...PICO2_W...uf2` を確認する。`pico`、`pico_w`、`pico2` 用と取り違えない。これは再現用のビルド手順であり、今回UF2生成・書き込みは実施していない。既存のR2P2環境が下記APIを備えていればビルドは不要。

## USBターミナルとファイルの配置

[公式Web Terminal](https://picoruby.org/terminal)はデスクトップChrome/EdgeのWeb Serialで接続できる。[2026-10-11時点の公式案内](https://picoruby.org/terminal-emulator)ではR2P2 4.0以降を対象とする。接続はshell/stdoutのCDCポートを選ぶ。別のシリアルアプリが同じポートを開いている場合は先に閉じる。

1. Web Terminalで `Connect` を押し、Picoのシリアルポートを選ぶ。R2P2のシェルプロンプトが出ることを確認する。
2. File Editor (PicoModem)で `Open local file` から [atp3011.rb](../../examples/atp3011/atp3011.rb) を開く。保存先を **`/home/atp3011.rb`**、転送形式を **Plain** にして `Upload`。
3. 同じ操作で [speak.rb](../../examples/atp3011/speak.rb) を **`/home/speak.rb`** にアップロードする。初期表示の `/home/app.rb` のまま送らない。
4. シェルで `ls /home`、`cat /home/speak.rb` を実行して保存先と内容を確認する。必要ならFile Editorの `Download` で読み戻し、元ファイルと比較する。

`speak.rb` は `/home/atp3011.rb` を絶対パスでロードするので2ファイルとも必要。ソース形式のまま配置する。起動アプリ `app.rb` は使わず、任意のタイミングで読み上げスクリプトを実行する。Wi-Fi設定やAPIキーは不要。

APIの簡単な確認はR2P2シェルで `irb` に入り、次を1行ずつ実行する。

```ruby
require 'i2c'
require 'gpio'
require 'io/console'
Machine.uptime_us
```

正常なら `exit` でシェルへ戻る。`LoadError` やメソッド未定義なら、上の対応構成のファームウェアを使う。このチェックだけでI²Cの配線や発声成功が確認できたことにはならない。

## 実行

R2P2シェルで以下を入力する。PCのシェルで実行するコマンドではない。

```text
/home/speak.rb
```

またはR2P2の `irb` から `load '/home/speak.rb'`。起動するとU1をリセットし、I²Cの応答とバージョンを確認する。

```text
ATP3011 speech: ASCII phonetic text, max 127 bytes.
:quit = exit, :reset = reset device; example: konnichiwa.
[ready] VF1a
say> konnichiwa.
[done]
say> ohayo-.
[done]
say> :quit
Bye.
```

バージョンの4文字は実物のリビジョンに依存する。`VF1a` はテスト用の例示であり、全チップの保証値ではない。`[done]` はLSIがコマンド完了を返した意味で、スピーカーの接続や可聴音量を検出した表示ではない。

入力は半角ASCIIの音声記号列。普通の日本語ローマ字表記と必ずしも同一ではなく、発音やアクセントの細則は[メーカー資料§14](https://www.a-quest.com/archive/manual/atp3011_datasheet.pdf)に従う。句点やアクセント記号を含めて127バイト以内にする。漢字・かな・全角英数はそのまま送れない。

| 操作 | 動作 |
|---|---|
| 音声記号列 + Enter | 発話が終了するまで待ち、次の入力へ戻る |
| 空行、空白だけ | 送信せず次のプロンプト |
| `:reset` + Enter | U1をハードウェアリセットして応答とバージョンを再確認 |
| `:quit` + Enter | U1をリセットして終了、R2P2シェルへ戻る |
| 空の入力行でCtrl-D | 標準入力EOFとして終了 |
| Ctrl-C | R2P2の割込み処理に依存して終了。確実な通常終了は `:quit` を使う |

前後の空白は削除する。CR/LFはPC入力の行区切りとして取り除く。ターミナルは送信改行をLF、ローカルエコーをOFFにすると扱いやすい。`STDIN.cooked` により本体側の入力エコー・Backspace・EOF処理を使う。発話中は次のプロンプトが出るまで入力を待つ。大量貼り付けをキューとして使う設計ではなく、R2P2の受信バッファを超える先行入力は保証しない。

## 実装と通信設定

| 設定 | 値 | コード上の場所 |
|---|---|---|
| I²C | I2C1、100 kHz、7bitアドレス0x2E | `speak.rb`、`ATP3011::ADDRESS` |
| ピン | SDA=GP6、SCL=GP7、RESET=GP2 | `speak.rb` |
| I²C転送タイムアウト | 100 ms/転送 | `I2C.new(timeout: 100)` |
| 発話応答期限 | 60秒 | `ATP3011.new` の `timeout_ms` |
| 状態読み出し | 1バイト、10 ms以上間隔 | `read_response` |
| 初期化期限 | Ready、Versionをそれぞれ2秒 | `reset!` |
| リセット | Low 10 ms、High後100 ms待機 | `silence!` |

PicoRubyのユニット名 `:RP2040_I2C1` はRP2350でも共通の実装名として使う。GPIO番号による割り当てはソースのRP2ポートと照合済み。UARTのTX/RXやボーレート設定はこの回路では使用しない。

送信は本文にCRを1つ追加した、最大128バイトの一括I²C書き込み。レジスタアドレスやNULは追加しない。今回のPicoRuby実装にはArduino Wireの32バイト制約はない。I²Cの戻り値の送信バイト数も検査する。

LSIへの状態問い合わせでBusyを表す `*` / `0xFF` が返る間は待機し、終端 `>` まで応答を読む。正常発話の応答は空文字+終端、エラーは `E` と3桁の番号+終端。長さ・文字種も検査し、壊れた応答で無限に待たない。10 msの待ちを毎回挟み、過剰なポーリングによる音切れを防ぐ。時刻は単調増加する `Machine.uptime_us` から得る。期限超過の検出には実行中I²C転送の最大100 msとスケジューラ遅延が加わり得る。

起動確認に `#V` を使用するが、ユーザー入力中の `#` と `$`、制御文字は拒否する。読み上げ用入力がEEPROM更新・中断コマンドとして送られないようにするためで、音声記号そのものの完全な構文検証はLSIに任せる。通常の数字タグに使う `<`、`>`、大文字、数字等は保持する。`#` を含む高度な表記には本実装は対応しない。

## エラーと復帰

LSIが返す `E105` などの完結したエラーは表示後、次の行を受け付ける。配線断、NACK、短い転送、期限超過、応答破損の場合は「同期していない」状態にし、**`:reset` に成功するまで新しい発話を送信しない**。転送途中の文章を重複再生したり、次の入力へ連結したりしないためである。リセットはGP2経由で受信途中の文章も消去する。

| 症状 | 確認・対応 |
|---|---|
| 起動直後にI²C failure / NACK | 電源を切り、U1の両VCC/GND、SDA/SCL、抵抗、設定端子を確認。出荷時アドレスは0x2E |
| 中古LSIでアドレス不明 | 電源OFFでPMOD0だけGNDへ変更し、PMOD1はHighのままにするとセーフモードで0x2Eに固定できる。通常配線へ戻す場合も電源OFF後に変更 |
| response timed out | モードと配線、電源、実際に長い発話かを確認。まず `:reset`。必要なら `ATP3011.new(bus, reset_pin, timeout_ms: 120_000)` で期限を延ばす |
| E105 | 音声記号列の読み記号を見直す。まず `konnichiwa.` で切り分け |
| E106 / E107 | タグの構文・長さをメーカー資料で確認 |
| `[done]` だが無音 | 通信は完了。AOUT→フィルタ→VR→アンプ→C9→SPの経路とU2の5 V、音量を確認 |
| 発声すると再起動・音が割れる | 音量を下げ、USB給電、C6/C7、GND取り回しを確認 |
| 入力が二重に見える | PCターミナル側のローカルエコーをOFF |
| `cannot load /home/atp3011.rb` | 2ファイルの保存先・Plain転送を確認 |

配線を直す際はUSBを抜く。`:reset` は誤配線を修正する機能ではない。終了処理はRubyの `ensure` でU1をリセットするが、USB抜去やVM強制停止のようにRuby処理を実行できない終了は対象外。
