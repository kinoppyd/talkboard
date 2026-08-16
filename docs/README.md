# PRK Firmware 調査ノート

調査日: 2026-08-15（Asia/Tokyo）
対象コード: `prk_firmware` の `master`、commit `22ae329260749d1ad75ac64fd551278d48a0b576`
比較対象: 同じ作業ディレクトリに取得した `picoruby`

PRK Firmware は、RP2040 系マイコン上で PicoRuby を動かし、Ruby の `keymap.rb` でキーボードを定義するファームウェアです。リリース済みバイナリを使う通常運用では、キーマップ変更のたびに C/C++ のツールチェーンで再ビルドする必要がありません。

ただし、[PicoRuby 公式サイト](https://picoruby.org/) は 2026 年現在 PRK Firmware を **deprecated（非推奨・保守終了）** とし、新規開発には R2P2 の `Keyboard` クラスを案内しています。本資料は、既存の PRK キーボードの理解・保守・再現を主目的とします。

## 文書一覧

- [概要、位置づけ、現状](01-overview-and-status.md)
- [歴史と主要な変更](02-history.md)
- [内部構成と動作原理](03-architecture.md)
- [導入と最初のキーマップ](04-getting-started.md)
- [キーマップ API 実践ガイド](05-keymap-guide.md)
- [実機、配線、公開キーボード事例](06-hardware-and-examples.md)
- [RGB、エンコーダ、VIA、マウス等の機能](07-features.md)
- [ソースからのビルド](08-build.md)
- [デバッグとトラブルシューティング](09-debug-and-troubleshooting.md)
- [調査方法と参照資料](10-sources.md)

## 最初に押さえるべき判断

| 目的 | 推奨する選択 |
|---|---|
| 既存の PRK キーボードを直す | 本資料と、そのキーボードで実績のある PRK バージョンを使う |
| RP2040 で既存キーマップを試す | まず [0.10.0 リリース](https://github.com/picoruby/prk_firmware/releases/tag/0.10.0)の UF2 を検討する |
| Pico 2 / RP2350 で PRK を使う | `master` からビルドが必要。Pico 2 対応は 0.10.0 より後の変更である |
| 新規に Ruby でキーボードを作る | 保守中の [PicoRuby `Keyboard`](https://github.com/picoruby/picoruby/tree/master/mrbgems/picoruby-keyboard) を先に評価する |

## 読む際の注意

- GitHub Wiki は有用ですが、ページによって 2021～2022 年の API やビルド手順が残っています。本資料では現在の `master` のコードを優先しました。
- `repositories/` はこの調査用 Git リポジトリでは ignore されています。文書内のローカルリンクは、同ディレクトリへリポジトリを clone 済みであることを前提にしています。
- ソースビルド手順はコードから検証しましたが、この調査時点ではツールチェーン一式を揃えたエンドツーエンドの UF2 生成までは実施していません。
- `keymap.rb` は設定データではなく実行可能な Ruby プログラムです。出所を信頼できるファイルだけを使用してください。
