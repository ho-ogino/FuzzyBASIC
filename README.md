# Fuzzy BASIC for SHARP X1

瀧山孝氏がOh!MZ誌上で発表したS-OS SWORD用BASICインタプリタ「Fuzzy BASIC」を、SHARP X1上のLSX-Dodgersで動作するように移植したものです。

Fuzzy BASICの仕様については [Oh!石さんのサイト](http://retropc.net/ohishi/s-os/fubasic.htm) を参照してください。

## ビルド

### 必要なツール

- Python 3
- [ailz80asm](https://github.com/AILight/AILZ80ASM) — Z80アセンブラ (FuzzyBASIC本体用)
- [RASM](https://github.com/EdouardBERGE/rasm) — Z80アセンブラ (ArkosTrackerサウンドドライバ用)
- [ndc](https://github.com/tablacus/ndc) — D88ディスクイメージ操作 (LSX-Dodgers版deploy時)
- [HuDisk](https://github.com/ho-ogino/HuDisk/tree/feature/write-basic-mode) — S-OSディスクイメージ操作 (S-OS版deploy時、`--basic`オプション対応のフォーク版)

`ailz80asm` は `--assembler` オプション、環境変数 `AILZ80ASM`、またはPATH上から探索します。
`rasm` はPATH上に必要です。

### アセンブル

```sh
# LSX-Dodgers版 (デフォルト)
python3 build.py

# S-OS版
python3 build.py sos

# 全ターゲット
python3 build.py all

# AUTORUN.BAS自動実行を有効にしてビルド
python3 build.py lsx --autorun
```

### ディスクイメージ作成・配布zip生成

```sh
# LSX-Dodgers版 (デフォルト)
python3 build.py deploy

# S-OS版
python3 build.py deploy sos

# 全ターゲット
python3 build.py deploy all
```

`dist/` 以下にd88・README.txt・COPYING・COPYING.AT3を含むzipが生成されます。

## ディレクトリ構成

| ディレクトリ | 内容 |
|---|---|
| `src/` | ソースコード (ASM) |
| `assets/` | ディスクに同梱するファイル (MAGIC.BIN、BASプログラム、BGM/SFXデータ等) |
| `disk/clean/` | 元になるクリーンなディスクイメージ |
| `disk/work/` | deploy時の作業用ディスクイメージ (gitignore) |
| `disk/` | 配布用README.txt、COPYING |
| `doc/` | 中間コード仕様書等のドキュメント |
| `tools/` | ビルド補助ツール (アドレスマップJSON生成等) |
| `out/` | ビルド生成物 (gitignore) |
| `dist/` | 配布用zip (gitignore) |

## サウンド機能 (v1.2L)

ArkosTracker 3対応のPSGサウンドドライバを搭載しています。

- **PSGAKM.BIN** — AKM (軽量版プレイヤー)
- **PSGAKG.BIN** — AKG (フル機能プレイヤー、グライド/アルペジオ/ピッチエフェクト対応)

どちらもRASMでビルドされ、同じSOUNDコマンドAPIで操作できます。
曲データ・SFXデータはArkosTracker 3で作成し、それぞれのフォーマットでエクスポートしてください。

### SOUND命令一覧

| コマンド | 機能 |
|---|---|
| `SOUND 0` | ドライバ無効化・終了 |
| `SOUND 1` | ドライバ初期化 |
| `SOUND 2,addr` | BGM再生 |
| `SOUND 3` | BGM停止 |
| `SOUND 4` | BGM一時停止 |
| `SOUND 5` | BGM再開 |
| `SOUND 6,addr` | SFXテーブル初期化 |
| `SOUND 7,n,ch` | SFX再生 (n=番号, ch=チャンネル0-2) |
| `SOUND 8,ch` | SFX停止 (ch=チャンネル0-2) |

## ライセンス

本リポジトリには複数のライセンスのソフトウェアが含まれています。詳細は [disk/README.txt](disk/README.txt) を参照してください。

- **Fuzzy BASIC** — Oh!MZ 1986年9月号掲載。Oh!X 1994年4月号「アプリケーションのフリーソフト化計画」によりプログラムリストのコピー・配布が自由化 (著作権は作者に帰属)
- **ArkosTracker 3 プレイヤー** — MIT License (Copyright (c) 2016-2025 Julien Nevo)
- **グラフィックパッケージMAGIC** — 作者の吉村ことり氏により権利行使放棄、自由利用可。X1/turbo用バイナリのみ同梱 (`assets/MAGIC.BIN`)
- **LSX-Dodgers** — MIT License (Copyright (c) 1995 Gaku)
