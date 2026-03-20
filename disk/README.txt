Fuzzy BASIC ver 1.1L for SHARP X1 / LSX-Dodgers
=================================================

概要
----
Fuzzy BASICは、瀧山孝氏がOh!MZ誌上で発表したS-OS SWORD用の
BASICインタプリタです。

本ディスクイメージは、Fuzzy BASICをSHARP X1上のLSX-Dodgersで
動作するように移植したものです。

収録ファイル
------------
- FZBASIC.COM  : Fuzzy BASIC本体 (LSX-Dodgers用)
- PSGAKM.BIN   : PSGサウンドドライバ AKM版 (軽量)
- PSGAKG.BIN   : PSGサウンドドライバ AKG版 (フル機能)
- TE.COM       : テキストエディタ (GPL-2.0)
- その他       : LSX-Dodgers システムファイル

起動方法
--------
ディスクイメージから起動すると、AUTOEXEC.BATにより
Fuzzy BASICが自動的に起動します。

手動で起動する場合は、LSX-Dodgers上で以下を実行してください:

  A>FZBASIC

使い方
------
Fuzzy BASICは一般的なBASICとは異なる独自の仕様を持っています。
コマンドや文法の詳細については、Oh!石さんのサイトを参照してください:

  http://retropc.net/ohishi/s-os/fubasic.htm

本バージョンで追加した命令
--------------------------
- PCGDEF ch, addr
    キャラクターコードchにaddrのPCGデータを定義します。

- TCOLOR n
    テキストカラーを設定します(0〜7)。
    $20をOR(加算)するとPCG表示が有効になります。
    例: TCOLOR 7 ... 白、PCG無効
        TCOLOR $27 ... 白、PCG有効

- SOUND n [,引数...]
    PSGサウンドドライバ (ArkosTracker 3 対応) を制御します。
    事前にBLOADなどでドライバを$C300にロードしてください。

    ドライバは2種類あり、どちらも同じコマンドで操作できます:
      PSGAKM.BIN ... AKM (軽量版、基本再生+SFX)
      PSGAKG.BIN ... AKG (フル版、グライド/アルペジオ/ピッチ効果+SFX)

    曲データ・SFXデータはArkosTracker 3で作成し、それぞれのフォーマット
    (AKM/AKG)でエクスポートしてください。

    コマンド一覧:
      SOUND 0           ... ドライバ無効化・終了
      SOUND 1           ... ドライバ初期化・有効化
      SOUND 2,addr      ... BGM再生 (addrは曲データアドレス)
      SOUND 3           ... BGM停止
      SOUND 4           ... BGM一時停止
      SOUND 5           ... BGM再開
      SOUND 6,addr      ... SFXテーブル初期化 (addrはSFXデータアドレス)
      SOUND 7,n,ch      ... SFX再生 (n=SFX番号1〜, ch=チャンネル0〜2)
      SOUND 8,ch        ... SFX停止 (ch=チャンネル0〜2)

    使い方の例:
      BLOAD "PSGAKG.BIN",$C300 ← ドライバロード
      BLOAD "BGM.BIN",$8000   ← 曲データロード
      BLOAD "SFX.BIN",$9000   ← SFXデータロード
      SOUND 1                 ← ドライバ初期化
      SOUND 6,$9000           ← SFXテーブル初期化
      SOUND 2,$8000           ← BGM再生開始
      SOUND 7,1,0             ← SFX #1をチャンネル0で再生
      SOUND 8,0               ← チャンネル0のSFX停止
      SOUND 3                 ← BGM停止
      SOUND 0                 ← ドライバ終了

    注意:
    - ドライバを$C300にロードせずにSOUND 1を実行すると暴走します
    - CTC非搭載機(標準X1)ではプログラム実行中(RUN)のみBGMが進行します
      直接入力待ち中はBGMが停止します
    - CTC搭載機(X1turbo/FM音源ボード搭載機)では常時BGMが進行します

    メモリマップ:
      $0100-$48FF   Fuzzy BASIC本体
      $B000-$C28C   MAGIC.BIN (グラフィックス、使用時)
      $C300-$CB98   PSGAKM.BIN (AKM版ドライバ使用時)
      $C300-$D112   PSGAKG.BIN (AKG版ドライバ使用時)
      〜$D705       TPA上限 (LSX-Dodgers)
    ドライバの後〜$D705が曲データ等に使用可能な空き領域です。
    AKM版: 約$2D6D (11,629バイト) / AKG版: 約$25F3 (9,715バイト) 空き

動作環境
--------
- SHARP X1シリーズ上のLSX-Dodgers (または互換エミュレータ)

ライセンスについて
------------------
本ディスクイメージには以下のソフトウェアが含まれています。

[Fuzzy BASIC]
  作者: 瀧山孝
  Oh!MZ 1986年9月号に掲載。Oh!X 1994年4月号の
  「アプリケーションのフリーソフト化計画」により
  プログラムリストのコピー・配布が自由化(著作権は作者に帰属)。
  LSX-Dodgers移植: ひろし☆H.O SOFT
  ソースコード: https://github.com/ho-ogino/FuzzyBASIC

[PSGサウンドドライバ (AKM/AKG)]
  ArkosTracker 3 プレイヤー
  作者: Targhan/Arkos
  ライセンス: MIT License
  X1用ラッパー: FuzzyBASICプロジェクト
  オリジナル: https://www.julien-nevo.com/arkstracker/

[グラフィックパッケージMAGIC]
  作者: 吉村ことり
  権利行使を放棄し、誰でも自由に使えるものとして公開。
  X1/turbo用バイナリのみ同梱しています。

[te (テキストエディタ)]
  ライセンス: GNU General Public License version 2 (GPL-2.0)
  同梱のCOPYINGファイルにライセンス全文があります。
  改変版ソースコード: https://github.com/ho-ogino/te

[LSX-Dodgers]
  作者: Gaku
  ライセンス: MIT License
  Copyright (c) 1995 Gaku
  ソースコード: https://github.com/tablacus/LSX-Dodgers

  Permission is hereby granted, free of charge, to any person obtaining
  a copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
