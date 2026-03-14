
[SOS]
;;;;;;;;;;;;;;;;;;;;;;;;
; S-OS用のワーク

WIDTH	EQU	80

_WIDTH:	DB	WIDTH
_XYADR:	DW	XYADR

XYADR:	DW	0
CSRNY:	DB	0		; カーソルY座標（0〜LINE-1）
INSFLG:	DB	0		; $00=上書き、$FF=挿入モード
LINTTB:	DS	25		; 行連結テーブル。$00=論理行開始、$FF=前行の続き
KEYPB:	DB	0		; キー入力プッシュバックバッファ（BRKEYが読んだ非Break文字を保存）

KBFAD	DS	128

KBFAD0:	DB	80
KBFAD1:	DB	0
KBFADX:	DS	80
	DB	0
PRBF:	DS	80
SUBPS:	DW	0
SUBBF:
	DS	256		;バッチファイル専用バッファ

_KBFAD:	dw	KBFAD

; TODO magicのコール呼び出し前にスタックを設定するが、ここでいいのか……？
STADR	EQU	0006H

;;;;;;;;;;;;;;;;;;;;;;;;;;
DSK:
	ds	1
DTADR:
	ds	2
EXADR:
	ds	2
SIZE:
	ds	4
WBOOTBK:
	dw	0
BIOS18BK:
	db	0
SPBK:
	dw	0
LPSW:
	db	0
DIRWILD:
	db	"*.*",0
TEMPDTA:
	ds	33

MESTBL:	DW	ER1,ER2,ER3,ER4,ER5,ER6,ER7,ER8
	DW	ER9,ER10,ER11,ER12,ER13,ER14

ER1:	DB	'Device I/O Error',0DH
ER2:	DB	'Device Offline',0DH
ER3:	DB	'Bad File Descripter',0DH
ER4:	DB	'Write Protected',0DH
ER5:	DB	'Bad Record',0DH
ER6:	DB	'Bad File Mode',0DH
ER7:	DB	'Bad Allocation Table',0DH
ER8:	DB	'File not Found',0DH
ER9:	DB	'Device Full',0DH
ER10:	DB	'File Already Exists',0DH
ER11:	DB	'Reserved Feature',0DH
ER12:	DB	'File not Open',0DH
ER13:	DB	'Syntax '
ER15:	DB	'Error ',0DH
ER14:	DB	'Bad Data',0DH
OK:	DB	'Complete !',0DH

[NAME_SPACE_DEFAULT]
