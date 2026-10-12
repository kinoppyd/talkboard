# 新規回路・部品・ブレッドボード配線

## 回路の位置づけ

新規設計のPoC回路です。前回の検証回路からの差分配線ではなく、ここに記した部品・接続を一式として組み立てます。電気的動作、音量、USB信号品質は未実測です。組み立て前に部品の現物の型番・パッケージ・極性を照合してください。

[回路図SVG](../../hardware/hid-relay/schematic.svg)はネット名接続方式です。同じネット名は電気的に接続し、`NC`は各々未接続です。Picoの番号だけは基板の**物理端子番号**、ICはパッケージのピン番号です。正本は[netlist.json](../../hardware/hid-relay/netlist.json)。図は `ruby tools/render_relay_schematic.rb` で再生成できます。

### 電源・USBの接続概要

```text
Mac ── データ対応USBケーブル ── Pico 2 WのMicro USB端子
                                   │ 標準USB Device
                                   │
外部の安定化5V電源 ── +5V_EXT ──┬── D1(1N5819) ── Pico VSYS(物理39)
                               │    A       K(帯側)
                               ├── U2 LM386の電源
                               └── U3 TPS2051B ── HOST_VBUS ── J1 USB-A pin1
                                     EN ← GP12                    キーボード
                                    /OC → GP13
Pico GP10 ── R1 22Ω ── USB_DP ── J1 pin3
Pico GP11 ── R2 22Ω ── USB_DM ── J1 pin2
共通GND ──────────────────────── J1 pin4・電源マイナス
Pico 3V3 ── ATP3011・I²Cプルアップ
GP6/GP7 ── SDA/SCL、GP2 ── ATP3011 /RESET
```

**外部5VやHOST_VBUSをPicoのVBUS（物理40）に接続しません。** Pico基板のUSB→VSYS経路と追加D1で電源を合流します。D1は外部5VがないときにVSYSから外部レールへ流れるのを防ぎます。PCケーブル内のVBUSは通常どおりPicoのUSB端子に接続されます。Macと外部電源の5V出力を直接並列にしないでください。

外部電源は絶縁済みの市販の安定化5V・2Aを使用し、商用電源側は加工しません。USB-Aの5V出力を使う場合も、取り出し用端子の+/-を確認します。PDで9V等を出すトリガー基板は使用しません。

USB給電と外部給電の電圧差によりPico自身はPCからも給電され得ます。descriptorはself-powered属性＋PC側100mA申告です。2mAしか流れないという設計ではありません。実際のPC側電流、suspend中の消費、逆流は実機測定が必要です。現コードはUSBサスペンド電流の適合を保証しません。

## 部品リスト

下表は接続データと同じ参照番号です。R3/R4は欠番です（PIO USBがGPIOのプルダウンを設定するため外付け並列抵抗を実装しません）。

抵抗は挿入型1/4W・±5%以下、コンデンサは16V以上を基本とします。無極性指定を電解に置き換えないでください。

| 番号 | 型番・値 | 数 |
|---|---|---:|
| MCU1 | Raspberry Pi Pico 2 W (headers) | 1 |
| U1 | ATP3011F1-PU DIP28 | 1 |
| U2 | LM386N-1/NOPB DIP8 | 1 |
| U3 | TPS2051BD SOIC8 + DIP adapter | 1 |
| J1 | USB-A female breakout (keyboard) | 1 |
| J2 | Regulated 5V 2A isolated supply input | 1 |
| D1 | 1N5819 Schottky DO-41 | 1 |
| R1 | 22 ohm | 1 |
| R2 | 22 ohm | 1 |
| R5 | 4.7k ohm | 1 |
| R6 | 4.7k ohm | 1 |
| R7 | 10k ohm | 1 |
| R8 | 100k ohm | 1 |
| R9 | 10k ohm | 1 |
| R10 | 1k ohm | 1 |
| R11 | 10 ohm | 1 |
| VR1 | 10k linear potentiometer | 1 |
| C1 | 100nF ceramic | 1 |
| C2 | 100nF ceramic | 1 |
| C3 | 10uF electrolytic 16V | 1 |
| C4 | 47nF film | 1 |
| C5 | 1uF film nonpolar | 1 |
| C6 | 100nF ceramic | 1 |
| C7 | 100uF electrolytic 16V | 1 |
| C8 | 10uF electrolytic 16V | 1 |
| C9 | 220uF electrolytic 16V | 1 |
| C10 | 47nF film | 1 |
| C11 | 100nF ceramic (U3 IN) | 1 |
| C12 | 10uF electrolytic 16V (U3 IN) | 1 |
| C13 | 150uF electrolytic 16V (USB VBUS) | 1 |
| C14 | 100nF ceramic (USB VBUS) | 1 |
| SP1 | 8 ohm >=0.5W passive speaker | 1 |

別途必要: 830穴程度のブレッドボード2枚、Pico用2.54mmヘッダ、U3用SOIC8→DIP8変換基板とヘッダ、USB-Aソケット変換基板、短い単線ジャンパ、データ対応USBケーブル、Mac側の必要なUSB変換アダプタ、テスター。U3を変換基板へはんだ付けする作業が必要です。

### 選定理由

- **Pico 2 W**: 標準USBをPC側、PIO0のSM0/1/2をキーボード側に割り当てます。CPUは120MHz。Wi-Fi/BLEは使用しません。PIO USBの送信用DMAは空きチャンネルを確保します。
- **ATP3011F1-PU**: 音声合成済みファームウェアを持つDIP28品。裸のATmega328PやATP3012へは置き換えられません。3.3V、I²C、コマンドモードで使います。AVR書き込み器は不要で、チップ消去は行いません。
- **TPS2051BD**: 500mAクラスの電流制限付きUSB電源スイッチ。DパッケージSOIC8を指定します。SOT-23品とはピン番号が異なります。短絡等で/OCがLowになるとGP12をLowにして遮断し、復帰は配線確認後の再起動です。ソフトの故障検出に加えIC自体も電流制限します。
- **LM386N-1/NOPB**: DIP8、5V動作、外付け利得設定なしで20倍。VR1で音量を絞ります。スピーカーはIC出力に直接つなぎません。
- **D1**: 1N5819の帯側がVSYS。逆にすると外部電源からPicoに給電されません。耐電流に余裕がある挿入型ショットキーダイオードです。

想定電流の設計枠は、キーボード500mA以下、Pico約100mA以下を目安に実測、音声・アンプは数百mAの余裕を確保します。合計の実測値ではありません。高消費電力のRGBキーボードや内蔵ハブは初回試験に避けます。電源2Aは各部へ2Aを強制する意味ではなく、U3下流は独立して制限されます。

## 全接続表

`+5V_EXT`・`+3V3`・`GND`の3レールを明確に分けます。`PC_VBUS_NC`は物理40番から外へ配線しないという意味です。アンプとUSBキーボードのGNDは、細い音声信号GNDを経由せず、電源の共通点へ別の短い線で戻します。

| 部品 | ピン → ネット |
|---|---|
| MCU1 | 4 → `RESET_N`、9 → `SDA`、10 → `SCL`、14 → `DP_GPIO`、15 → `DM_GPIO`、16 → `HOST_EN`、17 → `HOST_OC_N`、36 → `+3V3`、38 → `GND`、39 → `VSYS`、40 → `PC_VBUS_NC` |
| U1 | 1 → `RESET_N`、2 → `NC`、3 → `NC`、4 → `GND`、5 → `+3V3`、6 → `+3V3`、7 → `+3V3`、8 → `GND`、9 → `NC`、10 → `NC`、11 → `NC`、12 → `AOUT`、13 → `NC`、14 → `+3V3`、15 → `+3V3`、16 → `NC`、17 → `NC`、18 → `NC`、19 → `NC`、20 → `+3V3`、21 → `NC`、22 → `GND`、23 → `NC`、24 → `NC`、25 → `NC`、26 → `NC`、27 → `SDA`、28 → `SCL` |
| U2 | 1 → `NC`、2 → `GND`、3 → `AMP_IN`、4 → `GND`、5 → `AMP_OUT`、6 → `+5V_EXT`、7 → `BYPASS`、8 → `NC` |
| U3 | 1 → `GND`、2 → `+5V_EXT`、3 → `+5V_EXT`、4 → `HOST_EN`、5 → `HOST_OC_N`、6 → `HOST_VBUS`、7 → `HOST_VBUS`、8 → `HOST_VBUS` |
| J1 | 1 → `HOST_VBUS`、2 → `USB_DM`、3 → `USB_DP`、4 → `GND`、SHIELD → `GND` |
| J2 | POS → `+5V_EXT`、NEG → `GND` |
| D1 | A → `+5V_EXT`、K → `VSYS` |
| R1 | 1 → `DP_GPIO`、2 → `USB_DP` |
| R2 | 1 → `DM_GPIO`、2 → `USB_DM` |
| R5 | 1 → `SDA`、2 → `+3V3` |
| R6 | 1 → `SCL`、2 → `+3V3` |
| R7 | 1 → `RESET_N`、2 → `+3V3` |
| R8 | 1 → `HOST_EN`、2 → `GND` |
| R9 | 1 → `HOST_OC_N`、2 → `+3V3` |
| R10 | 1 → `AOUT`、2 → `FILTER` |
| R11 | 1 → `ZOBEL`、2 → `GND` |
| VR1 | HIGH → `AUDIO_AC`、WIPER → `AMP_IN`、LOW → `GND` |
| C1 | 1 → `+3V3`、2 → `GND` |
| C2 | 1 → `+3V3`、2 → `GND` |
| C3 | PLUS → `+3V3`、MINUS → `GND` |
| C4 | 1 → `FILTER`、2 → `GND` |
| C5 | 1 → `FILTER`、2 → `AUDIO_AC` |
| C6 | 1 → `+5V_EXT`、2 → `GND` |
| C7 | PLUS → `+5V_EXT`、MINUS → `GND` |
| C8 | PLUS → `BYPASS`、MINUS → `GND` |
| C9 | PLUS → `AMP_OUT`、MINUS → `SPEAKER` |
| C10 | 1 → `AMP_OUT`、2 → `ZOBEL` |
| C11 | 1 → `+5V_EXT`、2 → `GND` |
| C12 | PLUS → `+5V_EXT`、MINUS → `GND` |
| C13 | PLUS → `HOST_VBUS`、MINUS → `GND` |
| C14 | 1 → `HOST_VBUS`、2 → `GND` |
| SP1 | PLUS → `SPEAKER`、MINUS → `GND` |

### Pico側ピンとソフトウェアの契約

| 物理端子 | GPIO/機能 | 接続 |
|---:|---|---|
| 4 | GP2 | ATP3011 /RESET |
| 9 | GP6 / I²C1 SDA | U1-27 |
| 10 | GP7 / I²C1 SCL | U1-28 |
| 14 | GP10 / PIO USB D+ | R1経由でJ1-3 |
| 15 | GP11 / PIO USB D− | R2経由でJ1-2 |
| 16 | GP12 | U3 EN |
| 17 | GP13 | U3 /OC |
| 36 | 3V3(OUT) | ATP3011とプルアップ |
| 38 | GND | 共通GND |
| 39 | VSYS | D1のK |
| 40 | VBUS | 外部配線なし |

GPIO番号と物理端子番号を取り違えないでください。USB-Aソケットは表裏で左右の見え方が変わるため、変換基板の印字・導通でpin1〜4を特定します。

### USBと電源スイッチ

U3-2/3を+5V_EXT、6/7/8をHOST_VBUSとしてそれぞれ全部接続します。C11/C12は入力近傍、C13/C14はUSB-A電源近傍です。R8は起動前のENをLowにし、R9はopen-drainの/OCを3.3Vへ引き上げます。/OCを5Vへプルアップしません。

D+/D−の22ΩはPico側近傍に置き、ジャンパを短く対にして引き回します。PIO USB自身のGPIOプルダウンを使います。外付けUSB PHYによる規格適合回路ではないため、電気的USB適合・長いケーブル・ブレッドボードでの信号品質は保証しません。USBコネクタ周辺だけ小基板へまとめることを推奨します。TVS等の製品向けESD保護・ケースは本PoCに含みません。

### ATP3011と音声部分

DIP28を上から見て切り欠きを上にすると左上が1、左下が14、右下が15、右上が28です。中央の溝をまたいで置きます。U1のVCCは7/20、GNDは8/22を省略せず接続し、C1は7番近傍、C2は20番近傍に置きます。I.CピンはGNDへ落とさず未接続です。

R5/R6はSDA/SCLから3.3Vへの枝であり、直列抵抗ではありません。U1はSMOD0=Low、SMOD1=High、PMOD0/1=High、/SLEEP=High。設定ピンはリセットで反映されます。GP2はソフトが出力するので、直接GNDへ落とすリセットボタンは追加しません。

音声経路は次の通りです。

```text
AOUT -- R10 1k -- FILTER -- C5 1uF(無極性) -- VR1 HIGH
                    |                           LOW -- GND
                  C4 47nF                     WIPER -- U2-3
                    |
                   GND

U2-2/4 -- GND       U2-6 -- +5V_EXT       U2-1/8 -- 未接続
U2-7 -- C8 10uF (+がU2側) -- GND
U2-5 --+-- C9 220uF (+がU2側) -- SP1 -- GND
       +-- C10 47nF -- R11 10Ω -- GND
```

R10/C4は約3.4kHzの一次ローパス、C5は入力の直流遮断、C9はアンプ出力の直流からスピーカーを守ります。C10/R11は直列の安定化回路であり、スピーカーと直列にしません。C6/C7はアンプ電源の近くです。VR1のワイパーは端子順が製品で異なるためテスターで特定します。最初はGND側へ回し、音量最小にします。

## 組み立て・通電順序

1. **MacのUSBと外部5Vの両方を外す**。ブレッドボードのレール分断と5穴グループをテスターで確認する。
2. PicoをBB1、U1/U2をBB2の中央溝に置く。U3ははんだ付け済み変換基板にして、番号をSOIC側と対応付ける。
3. GND、3V3、外部5V、VSYSの配線を先に行う。D1と電解の極性、U3の入力出力、Pico40番に外部配線がないことを確認する。
4. U1設定・I²C、音声回路を全接続表どおり配線する。USB信号線は電源・スピーカー線から離す。
5. 無通電で+5V/GND、3V3/GND、D+/D−に意図しない短絡がないか調べる。電解の充電で一瞬導通表示が変化する場合は短絡と区別する。
6. キーボードとMacは外したまま外部5Vを投入し、U1-7/20が約3.3V、U2-6/U3-2/3が約5V、VSYSが5VからD1降下分だけ低いことを測る。異常・発熱があればすぐ外す。
7. [UF2書き込み手順](build-and-run.md)を実施する。通常起動後、HOST_ENがHigh、HOST_VBUSが約5Vになることを測る。
8. 普通の低消費電力キーボードをJ1へ接続し、Mac上で入力を確認する。入力先は空のテキストエディタにする。
9. `konnichiwa` 等を入力し、VR1をゆっくり上げる。USB入力と発声を別々に記録する。
10. 発話時の電源降下、PC側消費電流、キーボードLEDを確認する。配線の変更は両電源を抜いてから行う。

## 設計根拠

- [Pico 2 W公式データシート](https://datasheets.raspberrypi.com/picow/pico-2-w-datasheet.pdf): ピン・VSYSとUSB給電。
- [ATP3011データシート](https://www.a-quest.com/archive/manual/atp3011_datasheet.pdf): DIPピン、動作電圧、通信・動作モード。
- [LM386 TIデータシート](https://www.ti.com/lit/ds/symlink/lm386.pdf): 5V動作、基本アンプ構成。コンデンサ値等は本PoCの設計値。
- [TPS2051B TIデータシート](https://www.ti.com/lit/ds/symlink/tps2051b.pdf): SOIC8ピン、active-high EN、open-drain /OC、電流制限。
- [固定版Pico-PIO-USB](https://github.com/sekigon-gonnoc/Pico-PIO-USB/tree/5a37a66dc5d3fbe0ef3cdbeda923a757440f984f): GPIO USB構成。プルダウン設定は `src/usb_tx.pio` 等を確認。
