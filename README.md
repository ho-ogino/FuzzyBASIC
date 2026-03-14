# Fuzzy BASIC for SHARP X1

瀧山孝氏がOh!MZ誌上で発表したS-OS SWORD用BASICインタプリタ「Fuzzy BASIC」を、SHARP X1上のLSX-Dodgersで動作するように移植したものです。

Fuzzy BASICの仕様については [Oh!石さんのサイト](http://retropc.net/ohishi/s-os/fubasic.htm) を参照してください。

## ビルド

### 必要なツール

- Python 3
- [ailz80asm](https://github.com/AILight/AILZ80ASM) — Z80アセンブラ
- [ndc](https://github.com/tablacus/ndc) — D88ディスクイメージ操作 (LSX-Dodgers版deploy時)
- [HuDisk](https://github.com/ho-ogino/HuDisk/tree/feature/write-basic-mode) — S-OSディスクイメージ操作 (S-OS版deploy時、`--basic`オプション対応のフォーク版)

`ailz80asm` は `--assembler` オプション、環境変数 `AILZ80ASM`、またはPATH上から探索します。

### アセンブル

```sh
# LSX-Dodgers版 (デフォルト)
python3 build.py

# S-OS版
python3 build.py sos

# 全ターゲット
python3 build.py all
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

`dist/` 以下にd88・README.txt・COPYINGを含むzipが生成されます。

## ディレクトリ構成

| ディレクトリ | 内容 |
|---|---|
| `src/` | ソースコード (ASM) |
| `assets/` | ディスクに同梱するファイル (MAGIC.BIN、BASプログラム、PCGデータ等) |
| `disk/clean/` | 元になるクリーンなディスクイメージ |
| `disk/work/` | deploy時の作業用ディスクイメージ (gitignore) |
| `disk/` | 配布用README.txt、COPYING |
| `out/` | ビルド生成物 (gitignore) |
| `dist/` | 配布用zip (gitignore) |

## ライセンス

本リポジトリには複数のライセンスのソフトウェアが含まれています。詳細は [disk/README.txt](disk/README.txt) を参照してください。

- **Fuzzy BASIC** — Oh!MZ 1986年9月号掲載。Oh!X 1994年4月号「アプリケーションのフリーソフト化計画」によりプログラムリストのコピー・配布が自由化 (著作権は作者に帰属)
- **グラフィックパッケージMAGIC** — 作者の吉村ことり氏により権利行使放棄、自由利用可。X1/turbo用バイナリのみ同梱 (`assets/MAGIC.BIN`)
- **LSX-Dodgers** — MIT License (Copyright (c) 1995 Gaku)
