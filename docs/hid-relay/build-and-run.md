# ビルド・書き込み・初回使用

## 必要なツールと固定版

検証環境はmacOS、Ruby 3.4.2、CMake 3.28.3、Arm GNU Toolchain 14.3.Rel1です。Rubyは3.1以上を推奨します。macOS付属Ruby 2.6でPicoRuby本体をビルドしないでください。Git、Rake、Python3、make、zip、gzip、C/C++コンパイラも必要です。

[versions.json](../../patches/picoruby-hid-relay/versions.json)に依存コミットを固定しています。

| 依存 | 固定版 |
|---|---|
| PicoRuby | 371d176f1bfd834d18ff2a8c86d2667b51b0fd32 |
| Pico SDK | 2.3.0 / 98a542c1a62fb549ffb5d66a3e5892b06276b670 |
| 同梱TinyUSB | 86ad6e56c1700e85f1c5678607a762cfe3aa2f47 |
| Pico-PIO-USB | 5a37a66dc5d3fbe0ef3cdbeda923a757440f984f |
| picotool | 2.3.0 / 6f6458d792b93685a11423b244a585eaa99eafcf |

SDK/TinyUSB等のsubmodule自体は変更しません。USB拡張はPicoRuby側のPatchとして適用します。

## 新しい依存チェックアウトの用意

以下はtalkboardのワークツリールートから実行します。既存の研究用 `repositories/picoruby` へ上書きせず、別名の作業コピーを作ります。既に同名ディレクトリがある場合は勝手に消さず、別名にして以降の引数を合わせてください。

```sh
git clone https://github.com/picoruby/picoruby.git repositories/picoruby-relay
git -C repositories/picoruby-relay checkout --detach 371d176f1bfd834d18ff2a8c86d2667b51b0fd32
git -C repositories/picoruby-relay submodule update --init --recursive

git clone https://github.com/sekigon-gonnoc/Pico-PIO-USB.git repositories/Pico-PIO-USB
git -C repositories/Pico-PIO-USB checkout --detach 5a37a66dc5d3fbe0ef3cdbeda923a757440f984f
```

システムの `ruby`、`rake`、`arm-none-eabi-gcc`、`cmake` が意図した版か確認します。Apple SiliconのHomebrew Rubyを使う例:

```sh
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/bin:$PATH"
ruby --version
rake --version
arm-none-eabi-gcc --version
cmake --version
```

## パッチを順次適用

```sh
ruby tools/apply_relay_patches.rb repositories/picoruby-relay
```

適用ツールはHEADとクリーン状態を確認し、別の一時indexで全Patchの順次適用を事前検査した後、作業ツリーへ適用します。PicoRuby側でコミットを自動作成しません。同じコピーへ二重適用しようとすると停止します。

| 順番 | Patch | 意味単位 |
|---:|---|---|
| 1 | 0001-dual-usb-build.patch | 専用ビルド構成、PIO USB Host設定、クロック、main差し替え |
| 2 | 0002-hid-report-core.patch | 境界を検査するdescriptor解析、キー・Consumer・LED形式変換 |
| 3 | 0003-hid-relay-runtime.patch | core1 Host、core0転送、LED、有限バッファと観測 |
| 4 | 0004-ruby-observation-api.patch | HIDRelay.read/generation/errorsのRuby API |
| 5 | 0005-standalone-observation.patch | PC未接続時の観測継続、GP14によるVBUS検出、再接続時の最新状態同期 |

全5本を順次適用してからビルドします。中間段階で単独ビルドできるという意味ではありません。旧4本適用済みコピーは、ユーザー変更がないことを確認し5本目だけ `git apply --check` 後に適用するか、新しいクリーンコピーを作って全列を適用します。新UF2にはR12/R13のGP14検出配線も必要です。

## picotool

SDKがpicotoolを見つけない場合、configure中にネットワーク取得・ビルドします。ネットワーク制限環境や版の固定には、先に公式ソースからローカルprefixへ用意できます。

```sh
git clone --branch 2.3.0 https://github.com/raspberrypi/picotool.git repositories/picotool
git -C repositories/picotool checkout --detach 6f6458d792b93685a11423b244a585eaa99eafcf
cmake -S repositories/picotool -B build/picotool \
  -DPICO_SDK_PATH="$PWD/repositories/picoruby-relay/mrbgems/picoruby-r2p2/lib/pico-sdk" \
  -DPICOTOOL_NO_LIBUSB=1 -DCMAKE_INSTALL_PREFIX="$PWD/build/picotool-install"
cmake --build build/picotool --parallel 4
cmake --install build/picotool
export CMAKE_PREFIX_PATH="$PWD/build/picotool-install"
```

NO_LIBUSBのpicotoolはUF2生成用です。USB経由のpicotool書き込み操作には使わず、下記BOOTSELドライブへコピーします。

## ホストテストとUF2生成

```sh
ruby tools/test_relay.rb repositories/picoruby-relay
ruby tools/build_relay.rb repositories/picoruby-relay repositories/Pico-PIO-USB
```

出力は `build/relay/Talkboard-0.1.0-PICO2W-<日付>-<revision>.uf2` とELFです。日付・Git revisionを含むのでファイル名を固定せず、実際の生成物を確認してください。CMakeキャッシュを異なるPicoRubyチェックアウトで使い回す場合は、出力先を分けます。

```sh
TALKBOARD_BUILD_DIR="$PWD/build/relay-fresh" \
  ruby tools/build_relay.rb repositories/picoruby-relay repositories/Pico-PIO-USB
```

ビルドツールは `speech.rb` と `main.rb` を生成用mainへ連結し、mrbcでUF2に埋め込みます。生成物・依存チェックアウトはGit管理外です。日付・パスの差を含むため、異なる環境でバイナリがビット単位に同一になるとは主張しません。

## 書き込みと初回試験

1. [回路の無通電チェック](hardware.md)を終え、キーボードを外す。
2. PicoのUSB・アダプタ・電池をすべて外して電源を切る。外部給電だけ残すとBOOTSEL起動に入らないことがある。
3. BOOTSELを押しながらMacへUSB接続し、RP2350のUSBドライブ（通常 `RP2350`）が現れるのを確認する。
4. 生成されたUF2をそのドライブへコピーする。接続先がPico 2 Wであることを確認してから行う。他の機器へ書き込まない。
5. 自動再起動後、アダプタを接続しS1をEXTへ。HOST_VBUSと各電源、PC接続時のGP14約2.5Vをテスターで測る。
6. US配列キーボードを下流USB-Aへ接続する。Macにキーボード識別画面が出たらUS/ANSIとして設定し、入力ソースもUS/ABCで試す。
7. 空のテキストエディタで通常入力、Shift/Commandショートカット、Backspace、CapsLock LEDを確認する。
8. `konnichiwa`、`shi`、`katta`、`n`等を入力する。音声はIC終了待ちで遅れてよいが、Macの入力が音声待ちで止まらないか確認する。
9. 結果とキーボード機種・macOS版を記録する。未定だった機種に対応できないdescriptorがあれば、実機のdescriptorを基に解析器を拡張する。

起動スクリプトは不要です。UF2の起動時に専用mainが走ります。CDCインターフェースは残りますが対話shellはありません。R2P2 DRIVEへファイルを書き込んで動かす構成でもありません。

単独動作はUSBとアダプタを外し、保護付き18650を装着してS1をBATにします。同じUF2・同じRuby mainでキーボードと発声が動きます。[電池の配線・安全確認・PC着脱試験](standalone-power.md)を必ず先に実施してください。S1で電源を切り替える際は装置全体を停止し、PCからPicoだけに給電が残る状態で切り替えないでください。

## 症状別の確認

| 症状 | 確認 |
|---|---|
| buildでCYW43が未定義 | 専用構成・USE_WIFI=OFFを使っているか。通常のpico2_w構成は別物 |
| picotool取得失敗 | 上記ローカルビルドとCMAKE_PREFIX_PATHを使う |
| CMake source mismatch | TALKBOARD_BUILD_DIRで新しい出力先を指定 |
| Macに現れない | データ対応ケーブル、UF2、電源、USB端子、R12/R13とGP14（約2.5V） |
| キーボードが点灯しない | S1、選択後5V、電池保護・F1、GP12、U3 /OC、HOST_VBUS。過電流時は全電源を切って確認 |
| PCなしで音声が止まる | 5本目Patch適用・再ビルドの確認。GP14はPCケーブルなしで約0V。BAT時のHOST_VBUSと電池電圧 |
| キーの一部が来ない | NKRO/Report ID/interface数・長さ・解析対象Usageを確認。未対応機種の可能性 |
| 音声だけ止まる | I²C配線、U1設定ピン、電源、RESET、アンプ。worker故障は再起動で復帰 |
| 読みが途中で分かれる | 50msの末尾待ち。speech.rbのwait_msを調整し再ビルド |
| 打鍵の一部が読まれない | ショートカット・編集キーは意図的に無視。キュー満杯は新しい音声を破棄 |
