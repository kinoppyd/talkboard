# Pico 2 W + ATP3011F1-PU 対話読み上げ

設計・調査日: 2026-10-11。Raspberry Pi Pico 2 W 上の PicoRuby/R2P2 でスクリプトを起動し、USB 標準入力に打ち込んだローマ字音声記号列を ATP3011F1-PU で読み上げる。発話終了を確認すると次の `say>` を表示する。ネット接続、PC 側の音声合成、Wi-Fi は不要。

入力形式はユーザー指定の ASCII 音声記号列。漢字かな変換や英語文章の読み上げは含まない。例: `konnichiwa.`。一度に送る本文は最大127バイト。

## 資料とコード

- [回路・部品・ブレッドボードの接続](hardware.md): 全ピン表、回路接続図、部品表、配置、初回通電。
- [導入と使い方](software.md): PicoRuby の準備、ファイル配置、実行、プロトコル、トラブル対応。
- [検証と参照資料](validation-and-sources.md): 自動テスト、実機での受け入れ手順、一次資料と参照コミット。
- [atp3011.rb](../../examples/atp3011/atp3011.rb): I²C ドライバと標準入力の対話処理。
- [speak.rb](../../examples/atp3011/speak.rb): Pico 2 W 用エントリーポイント。
- [ホスト側テスト](../../test/atp3011_test.rb)。

```text
PC の USB ターミナル
        │ 文字入力 / 標準入出力
        ▼
Pico 2 W (PicoRuby / R2P2)
        │ I2C1: GP6=SDA, GP7=SCL / GP2=RESET
        ▼
ATP3011F1-PU (3.3 V)
        │ AOUT: 音声 PWM
        ▼
RC フィルタ → DC カット → 音量 VR → LM386N-1 (5 V) → 8 Ω スピーカー
```

**設計・コードとホストテストは用意済み。実機での発話、アナログ波形・音量・ノイズ、USB 給電の余裕は未測定**。組み立て後は検証資料の順序で確認する。ファームウェアの UF2 は本変更には含めない。

作業ブランチは `feature/atp3011-speech`、worktree は `talkboard/.worktree/atp3011-speech`。既存の `repositories/` は親チェックアウトにある調査用ソースを参照した。worktree 内へのソース複製は不要。
