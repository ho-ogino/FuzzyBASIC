# リロケータブルバイナリ パッチ処理ガイド

Webアプリ実装者向けドキュメント。
`reloc_webapp.json` と `*.REL` ファイルを使って、各バイナリのロードアドレスを
ユーザー指定の値に変更する方法を説明する。

---

## 概要

FuzzyBASICでは複数のバイナリモジュール（MAGIC、サウンドドライバ、ペイントライブラリ等）が
それぞれ特定のアドレスにロードされる前提で動作する。リロケータブルバイナリシステムにより、
これらのアドレスをユーザーが変更できる。

### ファイル構成

| ファイル | 用途 |
|---|---|
| `reloc_webapp.json` | UI構築用メタデータ（シンボル一覧、バイナリ一覧、ローカライズラベル） |
| `*.REL` | パッチテーブル付きバイナリ（MAGIC.REL, PSGAKG.REL 等） |

---

## reloc_webapp.json の構造

```json
{
  "symbols": {
    "MAGICTOP": {
      "default": "0xB000",
      "constraint": "xx00h",
      "label": {"ja": "MAGIC", "en": "MAGIC"}
    },
    "SOUNDTOP": {
      "default": "0xC300",
      "constraint": "xx00h",
      "label": {"ja": "サウンドドライバ", "en": "Sound Driver"}
    }
  },
  "binaries": {
    "MAGIC.REL": {
      "rel_file": "MAGIC.REL",
      "output_file": "MAGIC.BIN",
      "binary_size": 4748,
      "groups": [
        {"name": "SELF", "symbol": "MAGICTOP", "default": "0xB000", "fixup_count": 645}
      ]
    },
    "FZBASIC.REL": {
      "rel_file": "FZBASIC.REL",
      "output_file": "FZBASIC.COM",
      "binary_size": 18670,
      "groups": [
        {"name": "MAGICTOP", "symbol": "MAGICTOP", "default": "0xB000", "fixup_count": 3},
        {"name": "SOUNDTOP", "symbol": "SOUNDTOP", "default": "0xC300", "fixup_count": 16}
      ]
    }
  }
}
```

### symbols

ユーザーが設定可能なアドレスシンボルの一覧。

| フィールド | 説明 |
|---|---|
| `default` | デフォルトアドレス（hex文字列）。RELファイル内のバイナリはこの値でビルド済み |
| `constraint` | `"xx00h"` — 256バイト境界のみ有効。下位バイトは常に00 |
| `label` | UI表示用のローカライズ文字列。キーは言語コード |

### binaries

各RELファイルとその依存情報。

| フィールド | 説明 |
|---|---|
| `rel_file` | 読み込むRELファイル名 |
| `output_file` | パッチ後にd88に格納する際のファイル名 |
| `binary_size` | パッチ後のバイナリサイズ（バイト） |
| `groups[].name` | グループ名。`"SELF"` は自身のORGアドレスのリロケーション |
| `groups[].symbol` | このグループが依存するシンボル名（`symbols` のキーに対応） |
| `groups[].default` | ビルド時のデフォルトアドレス |
| `groups[].fixup_count` | パッチ対象バイト数 |

---

## RELファイルのバイナリフォーマット

全てリトルエンディアン。

```
オフセット  サイズ  内容
────────────────────────────────────────
0x0000      2       table_size    テーブル部全体のバイト数
                                  （この値 = バイナリ本体の開始オフセット）
0x0002      2       binary_size   バイナリ本体のバイト数
0x0004      1       group_count   グループ数

--- グループ1 ---
0x0005      16      name          グループ名（ASCII、null埋め）
0x0015      2       default_addr  デフォルトアドレス
0x0017      2       fixup_count   パッチエントリ数 (N)
0x0019      N×2     fixup_offsets パッチ位置（バイナリ本体先頭からの相対オフセット）

--- グループ2 ---
(同構造の繰り返し)

--- バイナリ本体 ---
table_size  binary_size  バイナリデータ（デフォルトアドレスでアセンブル済み）
```

### 具体例: GPAINT.REL

```
00 00: 0B 01          table_size = 267
00 02: 66 04          binary_size = 1126
00 04: 02             group_count = 2

--- Group 0: "SELF" ---
00 05: 53 45 4C 46 00 00 ...  name = "SELF" (16 bytes, null-padded)
00 15: 00 D0          default_addr = 0xD000
00 17: 6E 00          fixup_count = 110
00 19: 06 00          fixup_offsets[0] = 0x0006
00 1B: 09 00          fixup_offsets[1] = 0x0009
...                   (110エントリ)

--- Group 1: "MAGICTOP" ---
xx xx: 4D 41 47 49 43 54 4F 50 00 ...  name = "MAGICTOP"
xx xx: 00 B0          default_addr = 0xB000
xx xx: 01 00          fixup_count = 1
xx xx: 65 04          fixup_offsets[0] = 0x0465

--- Binary body ---
(offset 267 から 1126 バイト)
```

---

## パッチ処理アルゴリズム

### 入力
- `reloc_webapp.json` からのシンボル一覧とバイナリ一覧
- ユーザーが指定した各シンボルの新アドレス（例: `MAGICTOP = 0xA000`）
- 対応する `*.REL` ファイル群

### 処理手順

```
各バイナリ（RELファイル）について:

1. RELファイルを読み込む

2. ヘッダ解析:
   table_size   = read_uint16(offset 0)
   binary_size  = read_uint16(offset 2)
   group_count  = read_uint8(offset 4)

3. バイナリ本体を取り出す:
   binary = rel_data[table_size : table_size + binary_size]
   （このbinaryのコピーに対してパッチを適用する）

4. 各グループについて:
   a. グループヘッダ読み取り:
      name          = read_string(16 bytes)
      default_addr  = read_uint16()
      fixup_count   = read_uint16()

   b. ユーザー指定の新アドレスを取得:
      new_addr = user_settings[group.symbol]
      （symbolはreloc_webapp.jsonのgroups[].symbolから取得）

   c. 差分計算:
      diff = (new_addr >> 8) - (default_addr >> 8)
      （上位バイトの差分。xx00h制約により下位バイトは常に0）

   d. diff == 0 ならこのグループはスキップ（変更なし）

   e. 各fixupオフセットについて:
      offset = read_uint16()
      binary[offset] = (binary[offset] + diff) & 0xFF

5. パッチ済み binary を output_file の名前でd88に格納
```

### 疑似コード (JavaScript)

```javascript
function patchREL(relName, relArrayBuffer, symbolAddresses, webappConfig) {
  // relName: reloc_webapp.json の binaries キー (例: "MAGIC.REL")
  const view = new DataView(relArrayBuffer);
  const tableSize = view.getUint16(0, true);  // little-endian
  const binarySize = view.getUint16(2, true);
  const groupCount = view.getUint8(4);

  // バイナリ本体をコピー
  const binary = new Uint8Array(
    relArrayBuffer.slice(tableSize, tableSize + binarySize)
  );

  // 各グループを処理
  let pos = 5;
  for (let g = 0; g < groupCount; g++) {
    // グループ名（16バイト、null-padded ASCII）
    const nameBytes = new Uint8Array(relArrayBuffer, pos, 16);
    const name = String.fromCharCode(...nameBytes).replace(/\0+$/, '');
    pos += 16;

    const defaultAddr = view.getUint16(pos, true);
    pos += 2;
    const fixupCount = view.getUint16(pos, true);
    pos += 2;

    // このグループに対応するシンボルの新アドレスを取得
    // webappConfig.binaries[relName].groups からsymbolを引く
    const groupInfo = webappConfig.binaries[relName]
      .groups.find(gi => gi.name === name);
    const symbolName = groupInfo.symbol;
    const newAddr = symbolAddresses[symbolName];  // ユーザー指定値

    const diff = (newAddr >> 8) - (defaultAddr >> 8);

    // パッチ適用
    for (let i = 0; i < fixupCount; i++) {
      const offset = view.getUint16(pos, true);
      pos += 2;
      binary[offset] = (binary[offset] + diff) & 0xFF;
    }
  }

  return binary;  // パッチ済みバイナリ（output_fileの名前でd88に格納）
}
```

---

## UI構築ガイド

### アドレス設定画面

`reloc_webapp.json` の `symbols` を列挙してフォームを生成する。

```javascript
const lang = 'ja';  // or 'en'
for (const [key, sym] of Object.entries(webapp.symbols)) {
  // sym.label[lang] → "MAGIC", "サウンドドライバ" 等
  // sym.default → "0xB000" 等
  renderAddressInput(sym.label[lang], key, parseInt(sym.default, 16));
}
```

### バリデーション

- アドレスは `xx00h`（256バイト境界）のみ有効
- `addr & 0xFF !== 0` ならエラー
- メモリ領域の衝突チェック（各バイナリのサイズは `binary_size` で取得可能）

### 衝突チェック例

以下はSELFグループを持つリロケータブルモジュール同士の衝突チェック例。
FZBASIC.COMのような固定配置バイナリ（$0100〜）や、LSX-DodgersのOS領域（$D706〜）
などの固定領域は別途ハードコードして追加する必要がある。

```javascript
function checkOverlap(binaries, symbolAddresses) {
  const regions = [];

  // 固定領域を追加（リロケート対象外）
  regions.push({ name: 'FZBASIC.COM', start: 0x0100, end: 0x4A3B });
  regions.push({ name: 'LSX-Dodgers',  start: 0xD706, end: 0xFFFF });

  // SELFグループを持つリロケータブルモジュール
  for (const [relName, info] of Object.entries(binaries)) {
    const selfGroup = info.groups.find(g => g.name === 'SELF');
    if (selfGroup) {
      const addr = symbolAddresses[selfGroup.symbol];
      regions.push({
        name: info.output_file,
        start: addr,
        end: addr + info.binary_size - 1
      });
    }
  }
  // 全ペアで重なりチェック
  for (let i = 0; i < regions.length; i++) {
    for (let j = i + 1; j < regions.length; j++) {
      if (regions[i].start <= regions[j].end &&
          regions[j].start <= regions[i].end) {
        return { overlap: true, a: regions[i], b: regions[j] };
      }
    }
  }
  return { overlap: false };
}
```

---

## 注意事項

- **xx00h制約**: 全てのシンボルアドレスは256バイト境界（下位バイト=00）必須。
  パッチはhigh-byte（上位バイト）のみ書き換える設計のため
- **パッチ順序**: グループ間に依存関係はない。全グループのパッチを独立に適用可能
- **SELF以外のグループ**: バイナリ自体のORGは変わらず、外部参照アドレスのみ書き換わる。
  例: FZBASIC.COMは$0100固定だが、内部のMAGICTOP/SOUNDTOP参照先が変わる
- **RELファイルの再利用**: 同じRELファイルから異なるアドレスのバイナリを何度でも生成可能
- **d88格納時**: `output_file`（例: "MAGIC.BIN"）をファイル名として使用する。
  SELFグループを持つバイナリは、対応するシンボルのアドレスがロードアドレスとなる
