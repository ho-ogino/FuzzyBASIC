; S-OSコール ディスク関連(LSX-Dodgers)

[SOS]

_ALLOC	EQU	$1B

; FuzzyBASICで使うFCB
FCBADR	EQU	$5C
FCBSZ	EQU	(FCBADR+16)

; ファイル名を拾い、それを元にFCB情報を整える
FILE:
	; DEにファイル名文字列が入っている
	LD	HL,FCBADR
	LD	C,_CHKFN
	CALL	BDOS

	; FCBADRにFCB情報が入る
	LD	A,(FCBADR)	; カレントドライブ番号
	ADD	A,'A'-1
	LD	(DSK),A	; アクセスしようとするデバイス名
	RET

; デフォルトデバイスの設定
SDVSW:
	PUSH	BC

	CALL	CAP
	LD	(DSK),A		; DSK変数も更新
	SUB	'A'

	LD	E,A
	LD	C,_SELDSK
	CALL	BDOS

	POP	BC
	RET

; デフォルトデバイスをAに読み出す
RDVSW:
	PUSH	BC
	PUSH	AF

	LD	C,_CURDRV
	CALL	BDOS

	ADD	A,'A'
	LD	B,A

	POP	AF
	LD	A,B
	POP	BC
	RET

; FILEでセットされたファイルがディスク上にあるかどうかのチェックをする
; 存在する場合、DTADR、EXADR、SIZEがセットされる
; 存在しない場合、キャリーが立って返る
; はずだが、とりあえずSIZEだけ入れる(DTADR,EXADRは取れないため)
; 破壊: AF,BC,DE,HL
ROPEN:
	LD	DE,FCBADR
	LD	C,_FSIZE
	CALL	BDOS
	
	LD	HL,(FCBSZ)
	LD	(SIZE),HL

	; オープンする
	LD	DE,FCBADR
	LD	C,_FOPEN
	CALL	BDOS

	; EXADR,DTADRはファイル自体では持たないので未設定と思われる
	RET

; 書き込み用にファイルを開く
; TODO 新しいファイルかどうかのチェックを行うらしい
WOPEN:
	; ファイルを作る(サイズ0になる？)
	LD	DE,FCBADR
	LD	C,_FMAKE
	CALL	BDOS

	; オープンする(必要？)
	LD	DE,FCBADR
	LD	C,_FOPEN
	CALL	BDOS

	; FCBのレコードサイズ←1
	; +14からの2バイト
	LD	HL,1
	LD	(FCBADR+14),HL

	; FCBのランダムレコード←書き込み開始レコード
	; +33からの3バイト
	DEC	HL
	LD	(FCBADR+33),HL
	LD	(FCBADR+34),HL	; 1バイト重複して0を書いている(無駄)
	RET

; FILEで設定したファイルのファイル名を表示する(のかな)
FPRNT:
	LD	HL,FCBADR
.disp
	; ドライブ名表示
	LD	A,(HL)
	ADD	A,'A'-1
	CALL	PRINT
	LD	A,':'
	CALL	PRINT

	; ファイル名表示
	INC	HL
	LD	B,8
.loop
	LD	A,(HL)
	CP	' '
	JR	Z,.loopnokori
	INC	HL
	CALL	PRINT
	DJNZ	.loop
	JR	.fileend
.loopnokori
	INC	HL
	DJNZ	.loopnokori
.fileend

	; 拡張子がない場合は . を表示しない
	LD	A,(HL)
	CP	' '
	JR	Z,.efileend

	LD	A,'.'
	CALL	PRINT

	; 拡張子表示 
	LD	B,3
.loopext
	LD	A,(HL)
	CP	' '
	JR	Z,.eloopnokori
	INC	HL
	CALL	PRINT
	DJNZ	.loopext
	JR	.efileend
.eloopnokori
	INC	HL
	DJNZ	.eloopnokori
.efileend

.end
	RET

; ROPENしたファイルを読み込む
RDD:
	; DTAを設定
	LD	DE,(DTADR)
	LD	C,_SETDTA
	CALL	BDOS

	; 読み込む
	LD	DE,FCBADR

	; FCB+14 レコードサイズを1にする
	LD	HL,1
	LD	(FCBADR+14),HL

	; 読み出し開始レコードを0にする(冗長)
	DEC	HL
	LD	(FCBADR+33),HL
	LD	(FCBADR+34),HL

	LD	HL,(SIZE)
	LD	C,_RDBLK
	CALL	BDOS

	; 念のためクローズ
	LD	DE,FCBADR
	LD	C,_FCLOSE
	CALL	BDOS

	RET

; WOPEN したファイルを書き込む
WRD:
	; DTA設定
	LD	DE,(DTADR)
	LD	C,_SETDTA
	CALL	BDOS

	; 書き込み
	LD	DE,FCBADR
	LD	HL,(SIZE)
	LD	C,_WRBLK
	CALL	BDOS

	; クローズ
	LD	DE,FCBADR
	LD	C,_FCLOSE
	CALL	BDOS

	RET

; ファイルをプロテクトする(未対応)
_SET:
	RET

; ファイルプロテクトを外す(未対応)
_RESET:
	RET

; ファイル名変更 (S-OS #NAME相当)
; 入力: DE=新ファイル名文字列、FCBADRに旧ファイル名FCBがセット済み
; 出力: CY=エラー
NAME:
	; 新ファイル名をFCBADR+16に解析
	LD	HL,FCBADR+16
	LD	C,_CHKFN
	CALL	BDOS

	; ドライブ番号を旧ファイルと同じにする
	LD	A,(FCBADR)
	LD	(FCBADR+16),A

	; リネーム実行
	LD	DE,FCBADR
	LD	C,_FREN
	CALL	BDOS

	; エラーチェック: A=$FFならエラー
	INC	A
	SCF
	RET	Z		; エラー(CY=1)
	OR	A		; CY=0
	RET

; 指定ファイルを削除
KILL:
	LD	DE,FCBADR
	LD	C,_FDEL
	CALL	BDOS
	RET

; DEが示すレコードナンバーからAが示すレコードにHLが示すアドレスに読み込む
; ※多分想定どおりに動かない。とても危険。
; ※とりあえず論理セクタ単位での読み込みになっている
DRDSB:
	PUSH	BC
	PUSH	DE
	PUSH	HL

	; DTAを設定
	PUSH	AF
	EX	DE,HL
	LD	C,_SETDTA
	CALL	BDOS
	EX	DE,HL
	POP	AF

	; TODO DEにはレコードナンバーが入っているが_RDABSは論理セクタ番号を入れるので単位をあわせないとダメ
	LD	H,A	; 読み出すレコード数(を、論理セクタ数に変更しないといけないが、もう面倒なのでいいかなという気分になっている)

	LD	A,(DSK)
	CALL	_CAP
	SUB	'A'
	LD	L,A	; 読み出すディスクドライブの番号

	LD	C,_RDABS
	CALL	BDOS

	POP	HL
	POP	DE
	POP	BC
	RET

; HLが示すアドレスからAレコード分(A*256バイト)の内容をDEを先頭レコードとして記録する
; ※多分想定どおりに動かない。とても危険。
DWTSB:
	PUSH	BC
	PUSH	DE
	PUSH	HL

	PUSH	AF
	EX	DE,HL
	LD	C,_SETDTA
	CALL	BDOS
	EX	DE,HL
	POP	AF

	; TODO DEにはレコードナンバーが入っているが_RDABSは論理セクタ番号を入れるので単位をあわせないとダメ
	LD	H,A	; 書き込むレコード番号(_RDABSだと論理セクタの数)

	LD	A,(DSK)
	CALL	_CAP
	SUB	'A'
	LD	L,A	; 書き込むディスクドライブの番号

	LD	C,_WRABS
	CALL	BDOS

	POP	HL
	POP	DE
	POP	BC
	RET

; DSKで指定されたデバイス上の全ディレクトリを表示する
; 仮で作る(ファイル名を""で囲みたいので DIR を呼び出す、といった事はしないでおく)
DIR:
	; 33バイトの領域が必要
	LD	DE,TEMPDTA
	LD	C,_SETDTA
	CALL	BDOS

	; *.*で探す
	LD	DE,DIRWILD
	LD	HL,FCBADR
	LD	C,_CHKFN
	CALL	BDOS

	LD	A,(DSK)
	CALL	CAP
	SUB	'A'
	INC	A
.setdsk
	LD	(FCBADR),A

	LD	DE,FCBADR
	LD	C,_SFIRST
	CALL	BDOS
	OR	A
	JR	NZ,.end

.loop
	call	PAUSE
	dw	.end

	; 空白 & " 表示
	CALL	MPRNT
	DB	"     \"",0	

	; TEMPDTAのファイル名を表示
	LD	HL,TEMPDTA
	call	FPRNT.disp

	CALL	MPRNT
	DB	"\""
	DW	000dh

	LD	C,_SNEXT
	CALL	BDOS
	OR	A
	JR	Z,.loop
.end
	PUSH	IX
	PUSH	IY
	LD	A,(FCBADR)
	LD	E,A
	LD	C,_ALLOC
	CALL	BDOS
	POP	IY
	POP	IX

	; HLの内容を10進数で表示
	CALL	NAME_SPACE_DEFAULT._PRDEC5

	CALL	_MPRNT
	DB	" Clusters Free"
	DB	$0D,0

	CALL	_NL
	RET


[NAME_SPACE_DEFAULT]
