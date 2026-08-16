# ソースからのビルド

この章はローカルの現在の [`Rakefile`](../repositories/prk_firmware/Rakefile) と [`CMakeLists.txt`](../repositories/prk_firmware/CMakeLists.txt) を基準にしています。公式 Wiki の古い `rake` 一発の例や Docker 手順とは差があります。

## 通常はビルド不要

RP2040 で `PRK DRIVE` と `keymap.rb` を使うだけなら、[0.10.0 release](https://github.com/picoruby/prk_firmware/releases/tag/0.10.0) の `MSC_FLASH` UF2 を使う方が簡単です。

ソース build が必要なのは主に次の場合です。

- Raspberry Pi Pico 2 / RP2350 を使う
- 現在の `master` の変更が必要
- keymap を埋め込んだ `NO_MSC` firmware を作る
- mrbgem、USB descriptor、低レベル driver を変更する
- 特殊な `MSC_SD` / SQLite3 構成を研究する

## 必要なもの

現在の build 定義から確認できる要件:

- Git と submodule
- Ruby、Bundler、Rake
- CMake 3.24 以上
- Arm GNU toolchain (`arm-none-eabi-gcc` 等)
- Python 等、Pico SDK が要求する tool
- Raspberry Pi Pico SDK **2.1.0** と submodule
- `pico-extras`
- archive 作成用の `zip`、`gzip`

`Rakefile` は `PICO_SDK_PATH` の末尾にある SDK の Git tag が `2.1.0` であることを検査します。別 SDK version を暗黙に使うと失敗します。

`CMakeLists.txt` は `pico_extras_import.cmake` も読みます。`PICO_EXTRAS_PATH` を設定する、PRK と期待される相対位置へ `pico-extras` を置く、または CMake の fetch option を明示する必要があります。

## 取得

この調査 workspace では submodule を含めて clone 済みです。新規に取得する場合は次の形です。

```sh
git clone --recursive https://github.com/picoruby/prk_firmware.git
cd prk_firmware
```

すでに clone 済みで submodule が欠ける場合:

```sh
git submodule update --init --recursive
```

SDK と extras は PRK の外側へ置く例です。

```sh
git clone --branch 2.1.0 --recursive \
  https://github.com/raspberrypi/pico-sdk.git ../pico-sdk
git clone --recursive \
  https://github.com/raspberrypi/pico-extras.git ../pico-extras

export PICO_SDK_PATH=/absolute/path/to/pico-sdk
export PICO_EXTRAS_PATH=/absolute/path/to/pico-extras
```

path は実在する absolute path に置き換えます。CI や複数 project で SDK を共有するなら、shell profile に固定する前に project ごとの version 衝突を考慮します。

PRK は Pico SDK を 2.1.0 に固定する一方、`pico-extras` の commit は固定していません。`pico-extras` の現在の `master` は将来の SDK 向けに変化するため、clone 後の commit を必ず記録してください。2024-11-26 の RP2350 対応を当時に近い状態で再現する候補は、その直前の [`pico-extras` commit `f05d4f7`](https://github.com/raspberrypi/pico-extras/commit/f05d4f7371802440cadd36744789a26944d950ac) です。ただし、これは両 repository の日付から選んだ再現候補で、PRK が公式に指定した pin ではありません。

```sh
git -C ../pico-extras checkout f05d4f7371802440cadd36744789a26944d950ac
```

## 初期 setup

```sh
bundle install
rake setup
```

`rake setup` は PRK と内包 PicoRuby 側の Ruby dependency、submodule を準備します。先に `bundle install` が必要かどうかは使用中の Ruby/Bundler の起動方法によりますが、`bundle exec rake setup` として Bundler context を固定する方法もあります。

```sh
bundle exec rake setup
```

## RP2040 build

```sh
bundle exec rake pico
```

構成 directory は `build_pico/` です。成功すると project 名、board、MSC 種別、version/date/commit を含む UF2 と圧縮 archive が生成される定義です。

debug build:

```sh
bundle exec rake pico_debug
```

## RP2350 / Pico 2 build

```sh
bundle exec rake pico2
```

構成 directory は `build_pico2/` です。debug build は次です。

```sh
bundle exec rake pico2_debug
```

Pico 2 対応は 0.10.0 release 後に入ったため、この task を使う場合は `master` の具体的 commit を記録してください。

## keymap 埋込み `NO_MSC` build

完成した keyboard で USB mass storage を公開しない場合、`keyboards/<name>/keymap.rb` を用意して埋込み build を使います。

```text
prk_firmware/
  keyboards/
    my_keyboard/
      keymap.rb
```

RP2040:

```sh
bundle exec rake 'build_with_keymap_pico[my_keyboard]'
```

RP2350:

```sh
bundle exec rake 'build_with_keymap_pico2[my_keyboard]'
```

shell が brackets を glob と解釈しないよう task 全体を quote しています。成果物は keyboard directory 配下の `build_pico` または `build_pico2` に作られます。

古い Wiki の `build_with_keymap[name]` は現在の task 名と一致しません。現行 `rake -T` と `Rakefile` を基準にしてください。

## その他の task

```sh
bundle exec rake          # 現在は利用可能な主 task の案内を表示
bundle exec rake build    # configure 済み build directory を build
bundle exec rake clean
bundle exec rake deep_clean
bundle exec rake sqlite3  # Pico 2 + SD/MSC-SD の特殊構成
```

`deep_clean` は生成物や依存側 build を広く掃除し得るため、実行前に `rake -T` と task body を確認してください。workspace 内の user change を誤って消さないよう、clean 対象を確認します。

## Dockerfile の注意

現在の [`Dockerfile`](../repositories/prk_firmware/Dockerfile) は Pico SDK 1.5.1 を取得する一方、現在の `Rakefile` は 2.1.0 を要求します。また `amd64` 前提の base image 指定を含みます。そのため、[古い Docker Wiki](https://github.com/picoruby/prk_firmware/wiki/Docker)の command を現在の `master` にそのまま適用することは推奨できません。

Docker を使うなら、最低でも次を修正・検証します。

- SDK を 2.1.0 に合わせる
- pico-extras を用意し path を渡す
- host architecture と image architecture
- Ruby/Bundler version
- submodule と build cache

再現性を求めるなら、PRK commit、SDK tag、toolchain image digest をまとめて固定します。

## build failure の典型

| 症状 | 確認点 |
|---|---|
| Pico SDK が見つからない | `PICO_SDK_PATH` が absolute path で、SDK 2.1.0 checkout か |
| extras import failure | `PICO_EXTRAS_PATH`、配置、submodule |
| gem / rake task error | repository root、Bundler、`rake setup`、内包 PicoRuby submodule |
| compiler が見つからない | `arm-none-eabi-gcc` が PATH にあり、CMake から実行できるか |
| 古い build cache の定義が残る | 対象 build directory を確認して `clean`、必要時のみ `deep_clean` |
| Wiki と task 名が違う | `bundle exec rake -T` と現在の `Rakefile` を優先 |
| Docker 内で SDK version error | 現行 Dockerfile と Rakefile の version mismatch |

## この調査での検証範囲

Rake task、CMake 定義、Pico SDK version check、出力名、RP2040/RP2350 分岐はソースで確認しました。一方、この workspace では専用 SDK/extras/toolchain を揃えて UF2 の完全 build までは行っていません。実際の build を再現した際は、tool version と command log を別途保存してください。
