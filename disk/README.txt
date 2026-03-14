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
