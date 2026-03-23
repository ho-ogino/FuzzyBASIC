; FuzzyBASIC for LSX-Dodgers

MAGICTOP	EQU	$B000
#IF exists IS_LSX
SOUNDTOP	EQU	$C300
SND_Init	EQU	SOUNDTOP+$00
SND_BGMPlay	EQU	SOUNDTOP+$03
SND_BGMStop	EQU	SOUNDTOP+$06
SND_BGMPause	EQU	SOUNDTOP+$09
SND_BGMResume	EQU	SOUNDTOP+$0C
SND_SFXInit	EQU	SOUNDTOP+$0F
SND_SFXPlay	EQU	SOUNDTOP+$12
SND_SFXStop	EQU	SOUNDTOP+$15
SND_PSG_PROC	EQU	SOUNDTOP+$18
SND_PSG_END	EQU	SOUNDTOP+$1B
SND_CTC_PORT	EQU	SOUNDTOP+$1E
SND_CTCVEC	EQU	SOUNDTOP+$20
#ENDIF
magic		EQU	(MAGICTOP+4)
pdata		EQU	(MAGICTOP+$1202)

_clr_		EQU	$0C
_cr_		EQU	$0D
_right_	EQU	$1C
_left_	EQU	$1D
_beta_	EQU	$7D

_iy		EQU	$FD

ssline		EQU	$00
ssspline	EQU	$01
ssbox		EQU	$02
sstrngl		EQU	$03
ssboxf		EQU	$04
sscircle	EQU	$05
sswindow	EQU	$06
ssmode		EQU	$07
sspoint		EQU	$08
sscls		EQU	$09
sspalet		EQU	$0a
ssdone		EQU	$0f

dmy		EQU	0000H

#IF !exists BEGIN
BEGIN	EQU	$100
#ENDIF

		org	BEGIN

		jp	COLD
		jp	HOT
		jp	SK
		jp	SK_SK
		jp	SK_SK_SK
		jp	SK_K
		jp	SK_SK_K
		jp	SK_SK_SK_K
		jp	err13
		jp	err14
		jp	ERR
		jp	ADRX


VERERR:
		ld	de, EM35
		call	SOS.MSX
		jp	SOS.HOT

;-------------------

COLD:
		call	SOS.LPTOF
		call	SOS.VER
		ld	a, l
		cp	20h ; ' '
		jr	c, VERERR
		xor	a
		call	LCHR0
		xor	a
		ld	(STOPF), a
		ld	(ERFLG), a
		ld	(VALW+1), a
		ld	(KEY0F), a
		call	PRMODE0

		; CTRL+CをHOT0に変更する(終了時に戻す)
	#IF exists IS_LSX
	; WBOOTBKはWIDCHより先に初期化する必要がある
	; 2回目以降のCOLDではWBOOTBKを上書きしない
	LD	HL,(SOS.WBOOTBK)
	LD	A,H
	OR	L
	JR	NZ,.SKIP_WBOOT
	#ENDIF
	LD	HL,(00001H)
	LD	(SOS.WBOOTBK),HL
	#IF exists IS_LSX
.SKIP_WBOOT
	; X1turbo実機ROM環境でも常にANK表示に寄せるため、
	; BIOS-ROMベクタ($0018)を退避して実行中は$FFにする
	LD	A,(SOS.BIOS18BK)
	OR	A
	JR	NZ,.SKIP_BIOS18BK
	LD	A,(00018H)
	LD	(SOS.BIOS18BK),A
.SKIP_BIOS18BK
	LD	A,$FF
	LD	(00018H),A
	#ENDIF
	LD	HL,HOT0
	LD	(00001H),HL

		ld	a, 80
		call	SOS.WIDCH

		call	SOS.MPRNT
		db "* Fuzzy BASIC interpreter"
#IF exists IS_LSX
		db " ver 1.2L *"
#ELSE
		db " ver 1.1S *"
#ENDIF
		dw 000Dh

		call	LIMITMAX
		ld	hl, TEXTAREA
		ld	(TEXTST), hl
		call	NEW+3
		ld	hl, VARSTK
		ld	(VSTKST), hl
		ld	hl, VARSTKED
		ld	(VSTKED), hl
		ld	(STKTP), hl
		ld	hl, VARVAL+16
		ld	(PROCVAR), hl
		ld	hl, STKED
		ld	(SYSSTK), hl
		ld	sp, hl
		call	RANDOM
		call	CLR
		call	SIZE
		call	_PRDEC
		call	SOS.MPRNT
		db	" bytes free"
		dw	0Dh
_autorun_:				; AUTORUN SW.
#IF exists ENABLE_AUTORUN
		db	$CD		; ON (CALL AUTORUN)
#ELSE
		db	$01		; OFF
#ENDIF
		dw AUTORUN
HOT:
		ld	sp, (SYSSTK)
		call	SOS.LPTOF
		call	BRKON
		call	SOS._NL
		call	SETTXE
		db	"ready "
		dw	0Dh
HOT0:
		call	COMIN
		jr	HOT0

PIX:
		inc	ix
		ld	a, (ix+0)
		ret	
PIXP:
		inc	ix
IXP:
		ld	a, (ix+0)
		inc	ix
		ret	

CAP:
		cp	61h ; 'a'
		ret	c
		cp	7Bh ; '{'
		ret	nc
		sub	20h ; ' '
		ret	

PAC:
		cp	41h ; 'A'
		ret	c
		cp	5Bh ; '['
		ret	nc
		add	a, 20h ; ' '
		ret	

SPSKP:
		ld	a, (ix+0)
		cp	20h ; ' '
		ret	nz
		inc	ix
		jr	SPSKP

SPCNT:
		ld	b, 0
SPCNT0:
		ld	a, (ix+0)
		cp	20h ; ' '
		jr	nz, SPCNT1
		inc	ix
		inc	b
		jr	SPCNT0
SPCNT1:
		dec	b
		ret	z
		inc	b
		ret	z
		dec	b
		ex	af, af'
		ld	a, b
		cp	20h ; ' '
		jr	c, .ifjmp
		ld	a, 1Fh

.ifjmp
		ld	(de), a
		inc	de
		ld	b, a
		ld	a, (LINE)
		add	a, b
		ld	(LINE),	a
		ex	af, af'
		ret	

SPXX:
		call	IXP
		cp	20h ; ' '
		ret	c
		ex	(sp), hl
		inc	hl
		inc	hl
		inc	hl
		ex	(sp), hl
		ret	

CLR:
		ld	hl, VARNAME+10
		ld	de, VARNAME+11
		ld	bc, 192+254
		ld	(hl), 0
		ldir	
INITSTK:
		ld	hl, (VSTKED)
		ld	(VARSP), hl
INITSTK0:
		ld	iy, FORSTKED
		ld	hl, INITSPDT
		ld	de, SUBSP
		ld	bc, 8
		ldir	
		ret	

INITSPDT:
		dw SUBSTKED
		dw REPSTKED
		dw WHLSTKED
		dw IFSTKED
	
;%%%%%%%%%%%%%%%%%%%%%%%
; TEXT EDITOR
;%%%%%%%%%%%%%%%%%%%%%%%
COMIN:
		call	_GETL
		ld	a, (de)
		cp	1Bh
		ret	z
COMIN00:
		call	DESPSKP
		or	a
		ret	z
		push	de
		pop	ix
		call	CHK
		ld	hl, 0
		ld	a, (de)
		cp	30h ; '0'
		jr	c, COMIN0
		cp	3Ah ; ':'
		jr	nc, COMIN0
		call	EVDEC
COMIN0:
		ld	(CONVAREA), hl
		ld	de, CONVAREA+2
		ld	a, 6
		ld	(LINE),	a
		call	HENKAN
		call	EDLIN
		ld	a, h
		or	l
		jp	z, DIRECT
		call	NEW0
		ld	a, (LINE)
		cp	50h ; 'P'
		jp	nc, err33
		call	SRCHLIN
		jr	z, TEXTIN2
		call	NEWLINLEN
		ld	a, c
		cp	3
		ret	z
		push	bc
TEXTIN0:
		ld	hl, (TEXTED)
		push	hl
		call	err150
		ld	(TEXTED), de
		push	ix
		pop	bc
		pop	hl
		push	bc
		push	hl
		sbc	hl, bc
		ld	b, h
		ld	c, l
		pop	hl
		inc	bc
		inc	bc
		inc	de
		inc	hl
		lddr	
TEXTIN1:
		pop	de
		pop	bc
		ld	hl, CONVAREA
		ldir	
		ret	

TEXTIN100:
		ld	b, h
		ld	c, l
		jr	TEXTIN0

TEXTIN101:
		push	ix
		jr	TEXTIN1

TEXTIN2:
		jr	c, TEXTIN3
		call	NEWLINLEN
		ld	a, c
		cp	3
		jp	z, DELETE1LIN
		push	bc
		call	LINLEN
		pop	hl
		push	hl
		sbc	hl, bc
		jr	z, TEXTIN101
		jr	nc, TEXTIN100
		call	_MINUS
		ex	(sp), hl
		ld	b, h
		ld	c, l
		push	ix
		pop	de
		ld	hl, CONVAREA
		ldir	
		pop	bc
		push	de
		ld	h, d
		ld	l, e
		jp	DELETE1LIN100

TEXTIN3:
		call	NEWLINLEN
		ld	a, c
		cp	3
		ret	z
		ld	hl, (TEXTED)
		call	err150
		ld	hl, CONVAREA
		push	ix
		pop	de
		inc	bc
		inc	bc
		ldir	
TEXTIN4:
		dec	de
		dec	de
		ld	(TEXTED), de
		ret	

NEWLINLEN:
		ld	de, CONVAREA+2
		ld	bc, 3
NLL:
		ld	a, (de)
		or	a
		ret	z
		inc	c
		inc	de
		jr	NLL

LINLEN:
		push	ix
		pop	de
		inc	de
		inc	de
		jr	NEWLINLEN+3

CHK:
		push	de
		ld	b, 80
DO000:
		ld	a, (de)
		inc	de
		or	a
		jr	z, CHK0
		djnz	DO000
		jp	err33
CHK0:
		pop	de
		ret	

DIRECT:
		ld	ix, CONVAREA+2
		ld	sp, (SYSSTK)
		jp	JIKKOU

HENKAN:
		ld	a, 1
		ld	(LISTW), a
		call	SPCNT
HENKAN0:
		or	a
		jr	z, HENKANED
		call	CONVERT
HENKAN1:
		call	SPSKP
		jr	HENKAN0
HENKANED:
		ld	(de), a
		inc	de
		ld	(de), a
		inc	de
		ld	(de), a
		ret	

CONVERT:
		call	ALPH_
		jr	c, CONV4
		ld	hl, STKED

CONV:
		ld	a, (hl)
		inc	hl
		or	a
		jr	z, CONV2
		ld	c, a
		ld	b, (hl)
		inc	hl
CONV0:
		ld	a, (hl)
		cp	20h ; ' '
		jr	z, CONV0-1
		ld	a, (ix+0)
		call	CAP
		cp	(hl)
		jr	nz, CONV1
		inc	hl
		call	CPST
		ret	z
CONV1:
		call	ZSRCH
		jr	CONV
CONV2:
		call	IXP
CONV3:
		ld	(de), a
		inc	de
		call	LINECOUNT
		xor	a
		ld	(LISTW), a
		ld	a, (ix+0)
		call	ALPHorNUM_
		ret	c
		inc	ix
		jr	CONV3
CONV4:
		ld	(de), a
		inc	de
		inc	ix
		call	LINECOUNT
		ld	b, a
		xor	a
		ld	(LISTW), a
		ld	a, b
		ld	b, 0
		cp	5Ch
		jr	z, CONVLBL
		cp	0A2h
		jr	z, CONVLBL
		cp	22h
		jr	z, CONVSTR
		cp	27h
		ret	nz

CONVREM:
		ld	c, 0
CONVXXX:
		ld	a, (ix+0)
		or	a
		ret	z
		ld	(de), a
		inc	de
		call	LINECOUNT
		inc	ix
		cp	c
		ret	z
		cp	b
		ret	z
		jr	CONVXXX
CONVLBL:
		ld	bc,$A35C	; TODO A35C??
		jr	CONVXXX
CONVSTR:
		ld	c, a
		jr	CONVXXX

ZSRCH:
		inc	(hl)
		dec	(hl)
		inc	hl
		ret	z
		jp	ZSRCH

LINECOUNT:
		push	hl
		ld	hl, LINE
		inc	(hl)
		pop	hl
		ret	

CPST:
		push	ix
		push	hl
CPST0:
		call	PIX
		call	CAP
CPST1:
		inc	(hl)
		dec	(hl)
		jr	z, CPOK
		or	a
		jr	z, CPST2
		cp	(hl)
		jr	nz, CPST2
		inc	hl
		jr	CPST0
CPST2:
		cp	2Eh ; '.'
		jr	z, CPOK0
		ld	a, (hl)
		cp	20h ; ' '
		jr	nz, CPST3
		inc	hl
		ld	a, (ix+0)
		jr	CPST0+3
CPST3:
		pop	hl
		pop	ix
		ret	
CPOK0:
		inc	ix
CPOK:
		ex	de, hl
		ld	(hl), c
		inc	hl
		ld	(hl), b
		inc	hl
		ex	de, hl
		pop	hl
		ld	a, (LINE)
		dec	hl
		ld	b, a
		call	LCHK
		jr	z, .pokbrk
		dec	hl
		ld	a, (hl)
		inc	hl
		cp	20h ; ' '
		jr	nz, .pokbrk
		inc	b

.pokbrk
		ld	a, b

ZCOUNT:
		inc	(hl)
		dec	(hl)
		jr	z, ZCNT
		inc	a
		inc	hl
		jr	ZCOUNT
ZCNT:
		ld	(LINE),	a
		pop	hl
		ret	

LCHK:
		ld	a, (LISTW)
		dec	a
		ld	a, 0
		ld	(LISTW), a
		ret	

DELETE1LIN00:
		call	SRCHLIN
		ret	c
DELETE1LIN:
		call	LINLEN
		push	ix
		pop	hl
		push	hl
DELETE1LIN100:
		add	hl, bc
		ex	de, hl
		ld	hl, (TEXTED)
		inc	hl
		inc	hl
		or	a
		sbc	hl, de
		ld	b, h
		ld	c, l
		pop	hl
		ex	de, hl
		ldir	
		jp	TEXTIN4

;%%%%%%%%%%%%%%%%%%%%%%%
; COMMAND
;%%%%%%%%%%%%%%%%%%%%%%%
DELETE:
		call	SMED
		jp	z, err13
		call	NEW0
		call	HANI00
		inc	de
		ld	a, d
		or	e
		jr	z, DELETEALL
		dec	de
DELETE0:
		push	de
		call	SRCHLIN
		pop	de
		call	c, DEL2
		push	ix
		ex	de, hl
		call	SRCHLIN
		call	z, DEL3
		push	ix
		pop	de
		ld	hl, (TEXTED)
		inc	hl
		inc	hl
		or	a
		sbc	hl, de
		ld	b, h
		ld	c, l
		pop	hl
		ex	de, hl
		ldir	
		dec	de
		dec	de
		ld	(TEXTED), de
DELRET:
		jp	HOT
DEL2:
		jr	z, DELRET
		ret	
DEL3:
		ret	c
		jp	PPESRCHP
DELETEALL:
		call	SRCHLIN
		ld	(TEXTED), ix
		ld	(ix+0),	0
		ld	(ix+1),	0
		jr	DELRET

SRCHLIN:
		ld	ix, (TEXTST)
LSRCH0:
		ex	de, hl
LSRCH00:
		ld	l, (ix+0)
		ld	h, (ix+1)
		ld	a, h
		or	l
		jr	z, LSRCH1
		or	a
		sbc	hl, de
		jr	z, LSRCH2
		jr	nc, LSRCH1
		call	PPESRCHP
		jp	LSRCH00
LSRCH1:
		ccf	
LSRCH2:
		ex	de, hl
		ret	

AUTO_:
		ld	a, 27h ; '''
		inc	ix
		jr	AUTO00
AUTO:
		ld	a, (ix+0)
		cp	2Ah ; '*'
		jr	z, AUTO_
		xor	a
AUTO00:
		ld	(AUTOW), a
		call	SMED
		ld	hl, 0Ah
		jr	z, AUTO0
		ld	a, (ix+0)
		cp	2Ch ; ','
		jr	z, AUTO100
		call	SK
		ld	a, h
		or	l
		jp	z, err14
AUTO100:
		ld	a, (ix+0)
		cp	2Ch ; ','
		jr	nz, AUTO0
		inc	ix
		push	hl
		call	SK
		ex	de, hl
		pop	hl
		call	err140
		jr	AUTO1
AUTO0:
		ld	de, 0Ah
AUTO1:
		xor	a
		call	PRMODE0
		call	SOS.LTNL

AUTO2:
		push	de
		call	EDITSUB
		pop	de
		call	AUTO3
		jp	c, HOT
		jr	AUTO2

EDIT:
		xor	a
		ld	(AUTOW), a
		call	PRMODE0
		call	SOS.LTNL
		call	SK
		ld	a, h
		or	l
		jp	z, err14
		call	EDITSUB
		jp	HOT

EDITSUB:
		push	hl
		ld	hl, PRCNT
		ld	(hl), 0
		pop	hl
		push	hl
		call	_PRDEC5
		pop	hl
		call	_PRNTS
		call	SRCHLIN
		jr	c, EDIT1
		jr	nz, EDIT1
		inc	ix
		call	PIX
		ld	(AUTOW2), a
		call	_line_
		call	SOS.LTNL
		call	EDIT10
EDIT0:
		call	COMIN
		ld	hl, (SOS._KBFAD)
		ld	a, (hl)
		cp	1Bh
		jp	z, HOT
		ret	
EDIT1:
		ld	a, (AUTOW)
		call	_PRINT
		jr	EDIT0
EDIT10:
		ld	a, (PRCNT)
		call	SOS._CSR
		ld	l, 6
		dec	h
		cp	28h ; '('
		jr	c, EDIT11
		ld	a, (SOS.WIDTH)
		cp	50h ; 'P'
		jr	z, EDIT11
		dec	h
EDIT11:
		ld	a, (AUTOW)
		or	a
		call	nz, EDIT12
		jp	SOS._LOC
EDIT12:
		call	SOS._SCRN
		cp	27h ; '''
		ret	nz
		inc	l
		ret	

HANI:
		call	HANI00
		push	de
		call	SRCHLIN
		pop	de
		ret	nc
		jp	z, HOT
		push	hl
		ex	de, hl
		push	ix
		call	SRCHLIN
		ex	(sp), hl
		push	ix
		pop	de
		call	CP16
		jp	z, HOT
		push	hl
		pop	ix
		pop	de
		pop	hl
		call	CP16
		jp	z, HOT
		ret	
HANI00:
		call	SMED
		ld	hl, 1
		jr	z, HANI2
		ld	a, (ix+0)
		cp	2Ch ; ','
		jr	z, HANI0
		call	SK
		ld	a, h
		or	l
		jp	z, err14
		ld	a, (ix+0)
		cp	2Ch ; ','
		jr	nz, HANI1
HANI0:
		inc	ix
		call	SMED
		jr	z, HANI2
		push	hl
		call	SK
		ex	de, hl
		pop	hl
		jp	err140
HANI1:
		ld	d, h
		ld	e, l
		ret	
HANI2:
		ld	de, 0-1
		ret	

LIST_:
		ld	a, 1
		inc	ix
		jr	LIST00
LIST:
		ld	a, (ix+0)
		cp	2Ah ; '*'
		jr	z, LIST_
		xor	a
LIST00:
		ld	(LILI+1), a
		call	HANI
		ex	de, hl
LIST1:
		push	hl
		push	hl
		call	NXLINSUB+2
		jp	z, HOT
		pop	hl
		call	CP16
		jp	c, HOT
		call	LINLIST
		pop	hl
		jr	LIST1

LINELIST:
		call	NXLINSUB+2
		jp	z, HOT
LINLIST:
		ex	de, hl
LILI:
		ld	a, 0FFh
		or	a
		jr	nz, LIST__
LINLIS100:
		push	hl
		call	_PRDEC5
		call	_PRNTS
		call	_line_
		pop	hl
LINLISRET:
		call	_LTNL
LPAUSE:
		call	SOS.PAUSE
		dw HOT
		ret	

_line_:
		ld	a, 1
		ld	(LISTW), a
		call	IXP
		cp	20h ; ' '
		jr	nc, line_j1
		ld	b, a
DO002:
		call	_PRNTS
		djnz	DO002
line0:
		call	IXP
line_j1:
		or	a
		ret	z
		cp	0FBh ; '�'
		jr	c, line1
		ld	c, a
		ld	b, (ix+0)
		inc	ix
		call	PRWORD
		jr	line0
line1:
		call	_PRINT
		xor	a
		ld	(LISTW), a
		jr	line0

LIST__:
		call	SPXX
		call	IXP
		cp	27h ; '''
		jr	nz, LIST___
		push	ix
		pop	de
		call	LIST____
LIST___:
		call	ESRCHP
		jr	LINLISRET
LIST____:
		ld	a, (de)
		or	a
		jp	nz, _MSX
		jp	_LTNL

TABLESUB:
		ld	hl, RSVTBL
TABLES:
		ld	a, (hl)
		or	a
		jr	nz, TABLES_j1
		scf	
		ret	
TABLES_j1:
		inc	hl
		ld	d, (hl)
		inc	hl
		ld	e, a
		ex	de, hl
		or	a
		sbc	hl, bc
		ret	z
		ex	de, hl
		call	ZSRCH
		jp	TABLES

TABLE:
		call	SK_K
		ld	b, h
		ld	c, l
		call	TABLESUB
		jp	c, err14
		ex	de, hl
		ret	

PRWORD:
		call	TABLESUB
		jr	nc, PRWORD0
		ld	a, 7Bh ; '{'
		jp	_PRINT
PRWORD0:
		ld	a, (de)
		cp	20h ; ' '
		jr	nz, PRWORD1
		call	LCHK
		jr	nz, PRWORD1
		inc	de
PRWORD1:
		ld	a, (de)
		inc	de
		or	a
		ret	z

LCHRW:
		call	PAC
		call	_PRINT
		jp	PRWORD1

LCHR:
		call	SK
		ld	a, l
		or	a
LCHR0:
		ld	a, 0CDh
		jr	nz, .lchrjmp1
		ld	a, 1
.lchrjmp1
		ld	(LCHRW), a
		ret	

RENUM:
		ld	hl, 0Ah
		call	SMED
		jr	z, RENUM100
		call	_more_
		jr	z, RENUM1
		call	SK
		call	_more_
		jr	z, RENUM1
RENUM100:
		ld	ix, (TEXTST)
RENUM0:
		call	NEW0
		dec	ix
		ld	c, 0Ah
RENUM00:
		call	NXLINSUB
		jp	z, HOT
		ld	(ix-1), h
		ld	(ix-2), l
		add	hl, bc
		call	ESRCH
		jr	RENUM00
RENUM1:
		push	hl
		call	SK
		pop	de
		ex	de, hl
		call	CP16
		jp	c, err14
		push	de
		ex	de, hl
		call	SRCHLIN
		pop	hl
		jr	RENUM0

CHECK:
		call	HANI
CHECK0:
		push	de
		call	LINSUM
		pop	de
		call	CP16
		jp	nc, NLHOT
		jr	CHECK0

LINSUM:
		call	NXLINSUB+2
		jp	z, NLHOT
		ex	de, hl
LINS:
		push	hl
		call	_PRDEC5
		ld	a, 3Ah ; ':'
		call	_PRINT
		ld	l, 0
		call	SPXX
LINS0:
		call	IXP
		or	a
		jr	z, LINS1
		call	CAP
		cp	0A2h
		jr	nz, .linj1
		ld	a, 5Ch
.linj1
		cp	0A3h
		jr	nz, .linj2
		ld	a, 5Ch
.linj2
		cp	21h
		jr	nz, .linj3
		ld	a, 89h
.linj3
		cp	23h
		jr	nz, .linj4
		ld	a, 8Bh
.linj4
		cp	3Fh
		jr	nz, .linj5
		ld	a, 96h
.linj5
		add	a, l
		ld	l, a
		jr	LINS0
LINS1:
		call	_PRHEX2
		pop	hl
		call	LPAUSE
		call	_PRNTS
		jp	_PRNTS

SEARCH:
		xor	a
		ld	(LILI+1), a
		push	ix
		pop	de
		call	SEARC
		inc	c
		dec	c
		jp	z, HOT
		ld	ix, (TEXTST)
		dec	ix
		ld	b, c
SRCH0:
		push	de
		call	NXLINSUB
		pop	de
		jp	z, HOT
		push	ix
		pop	de
		ld	c, 0
		push	de
		call	NLL
		pop	de
		ld	a, c
		sub	b
		jr	c, SRCH1
		inc	a
		ld	c, a
DO003:
		call	SAME
		jr	z, SRCH2
		inc	de
		dec	c
		jr	nz, DO003
SRCH1:
		call	ESRCH
		jr	SRCH0
SRCH2:
		dec	ix
		dec	ix
		push	bc
		push	de
		push	hl
		call	LINELIST
		pop	hl
		pop	de
		pop	bc
		dec	ix
		jr	SRCH0

SAME:
		push	bc
		push	de
		push	hl
DO004:
		ld	a, (de)
		cp	(hl)
		jr	nz, SAMERET
		inc	de
		inc	hl
		djnz	DO004
SAMERET:
		pop	hl
		pop	de
		pop	bc
		ret	

SEARC:
		ld	a, (de)
		cp	22h ; '"'
		jr	z, SEARC1

SEARC0:
		push	de
		ld	c, 0
		call	NLL
		pop	hl
		ret	
SEARC1:
		inc	de
		call	SEARC0
		dec	de
		ld	a, (de)
		cp	22h ; '"'
		ret	nz
		xor	a
		ld	(de), a
		inc	c
		dec	c
		ret	z
		dec	c
		ret	

TXBEGIN:
		ld	hl, (TEXTST)
		ret	

TXEND:
		ld	hl, (TEXTED)
		ret	

TEXT:
		call	SK
		ld	de, (MEMAX)
		call	CP16
		jp	nc, err14
		ld	(TEXTST), hl
TEXT0:
		ld	hl, 0-1
		push	ix
		call	SRCHLIN
		ld	(TEXTED), ix
		pop	ix
		ret	

LIMIT:
		call	SK
		ld	de, (TEXTED)
		inc	de
		call	CP16
		jp	c, err14

LIMIT0:
		dec	hl
		ld	(MEMAX), hl
		ret	

LIMITMAX:
		call	MAXAD
		jr	LIMIT0

MAXAD:
		ld	hl, (SOS.MEMAX)
		dec	hl
		ret	

NEW:
		ld	hl, (TEXTST)
		ld	(TEXTED), hl
		ld	e, (hl)
		ld	(hl), 0
		inc	hl
		ld	d, (hl)
		ld	(hl), 0
		ld	(RCVDT), de
NEW0:
		push	hl
		ld	hl, 0
		ld	(BRK), hl
		ld	(NOAREA+126), hl
		pop	hl
		ret	

RECOVER:
		ld	hl, (TEXTST)
		ld	de, (RCVDT)
		ld	(hl), e
		inc	hl
		ld	(hl), d
		jr	TEXT0

VSTACK:
		call	SK_SK
		ex	de, hl
		call	CP16
		ex	de, hl
		jp	c, err14
		ld	(VSTKST), hl
		sbc	hl, de
		rr	l
		jr	z, .ifjmp
		dec	de
.ifjmp
		inc	de
		ld	(VSTKED), de
		ld	(STKTP), de
		ld	(VARSP), de
		ld	hl, VARSTKED
		call	CP16
		ret	nc
		ld	hl, VARSTK
		ld	(STKTP), hl
		ret	

STOFF:
		ld	a, (STOPF)
		or	1
		jr	STSET

STON:
		ld	a, (STOPF)
		and	0FEh ; '�'
STSET:
		ld	(STOPF), a
		ret	

BRKOFF:
		ld	a, (STOPF)
		or	2
		jr	STSET

BRKON:
		ld	a, (STOPF)
		and	0FDh
		jr	STSET

ERMODE:
		call	SK
		ld	a, l
		ld	(ERFLG), a
		ret	

VLIST:
		push	ix
		ld	ix, VARVAL
		ld	hl, 2041h	; TODO 2041h?
		ld	b, 1Ah
DO005:
		push	bc
		ld	d, h
		ld	e, l
		call	VLISSUB
		pop	bc
		inc	l
		djnz	DO005
		ld	hl, VARNAME
VLIS0:
		ld	a, (hl)
		or	a
		jr	z, VLIS1
		ld	d, a
		inc	hl
		ld	e, (hl)
		inc	hl
		call	VLISSUB
		jr	VLIS0
VLIS1:
		pop	ix
		jp	_PRNL

VLISSUB:
		push	hl
		ex	de, hl
		call	_PRCHR
		ld	a, 3Dh ; '='
		call	_PRINT
		ld	l, (ix+0)
		ld	h, (ix+1)
		call	_PRDEC5
		inc	ix
		inc	ix
		call	_PRNTS
		call	_PRNTS
		pop	hl
		ret	

SIZE:
		ld	hl, (MEMAX)
		ld	de, (TEXTED)
		or	a
		sbc	hl, de
		ret	

LODMES:	db "Loading "
		db 0
APDMES:	db "Appending "
		db 0
ARNAME:	db "AUTORUN.BAS"
		db 0

LOAD:
		call	_FILE2
		xor	a
		ld	de, LODMES
LOAD1000:
		call	LOADSUB
		jp	TEXT0

APPEND:
		call	_FILE2
		ld	a, 1
		ld	de, APDMES
		jr	LOAD1000

AUTORUN:
		ld	a, (SOS.DSK)
		call	SOS.SDVSW
		ld	a, 2
		ld	de, ARNAME
		call	SOS.FILE
		ld	hl, 0
		ld	ix, 0
		jr	CHAIN0-3

CHAIN:
		call	_FILE2
		ld	hl, 0
		ld	(CHDT),	hl
		call	_more_
		jr	nz, CHAIN0
		call	SK
		ld	(CHDT),	hl
CHAIN0:
		call	LOAD+3
		call	NEW0
		call	INITSTK0
		ld	hl, (CHDT)
		ld	a, h
		or	l
		jp	z, RUN1
		xor	a
		ld	(GOTOW), a
		jp	GOTO0

MERGE:
		call	_FILE4
		call	_ROPEN
		ld	hl, (TEXTED)
		ld	bc, 0Bh
		add	hl, bc
		ld	(SOS.DTADR), hl
		ld	de, LODMES
		call	LOADSUB0
		ld	hl, (SOS.DTADR)
		push	hl
MERGE0:
		ld	a, (hl)
		or	a
		jr	z, MERGE1
#IF exists IS_LSX
		cp	1Ah		; EOF(CP/M)
		jr	z, .meof
		cp	0Ah		; LF → スキップ(詰める)
		jr	z, .mskip
#ENDIF
		cp	0Dh
		jr	nz, .mjmp1
		ld	(hl), 0
.mjmp1
		inc	hl
		jr	MERGE0
#IF exists IS_LSX
.mskip
		; LFを詰める: HL以降を1バイト前にシフト
		push	hl
		ld	d, h
		ld	e, l		; DE = 現在位置(コピー先)
		inc	hl		; HL = 次の位置(コピー元)
.mskiplp
		ld	a, (hl)
		ld	(de), a
		or	a
		jr	z, .mskipdn
		inc	hl
		inc	de
		jr	.mskiplp
.mskipdn
		pop	hl
		jr	MERGE0
.meof
		ld	(hl), 0		; EOFを終端に置換
		jr	MERGE1
#ENDIF
MERGE1:
		pop	hl
		inc	(hl)
		dec	(hl)
		jp	z, HOT
		push	hl
		call	ZSRCH
		ex	(sp), hl
		ex	de, hl
		call	COMIN00
		jr	MERGE1

_FILE4:
		call	_FILESUB
		ld	a, 4
		jr	_FILE0
_FILE1:
		call	_FILESUB
		ld	a, 1
		jr	_FILE0
_FILE2:
		call	_FILESUB
		ld	a, 2
_FILE0:
		call	SOS.FILE
		ld	a, (LDWK+1)
		ld	(ix-1), a
		ret	

_FILESUB:
		call	SMED
		jr	z, _FLSUB1
		cp	22h ; '"'
		jr	nz, _FLSUB2
		inc	ix
		push	ix
		pop	de
_FLSUB0:
		call	D_QUES
		cp	22h ; '"'
		jr	nz, _FLSUB0
_FLSUB00:
		ld	(LDWK+1), a
		ld	(ix-1), 0
		ret	

_FLSUB1:
		call	SOS.RDVSW
		cp	53h ; 'S'
		jp	c, err13
		push	ix
		pop	de
		ld	a, (ix-1)
		dec	de
		jr	_FLSUB00
_FLSUB2:
		call	SK
		ld	d, h
		ld	e, l
		ld	a, (ix-1)
		jr	_FLSUB00

_ROPEN:
		call	SOS.ROPEN
		jr	c, FERR0
		ret	z
		call	SOS.MPRNT
		db "Found "
		db 0
		call	_FPRNT
		jr	_ROPEN

_FPRNT:
		call	SOS.FPRNT
		jp	SOS._NL

LOADSUB:
		ld	(LDWK),	a
		push	de
		call	_ROPEN
		ld	a, (LDWK)
		ld	hl, (TEXTST)
		or	a
		call	nz, APP
		ld	(SOS.DTADR), hl
		call	MEMOVER_Q
		ld	de, (MEMAX)
		inc	de
		inc	de
		sbc	hl, de
		jr	nc, MEMOVER
		pop	de
LOADSUB0:
		call	SOS.MSX
		call	_FPRNT
		call	SOS.RDD
		jr	c, FERR0
		ret	

APP:
		ld	hl, (TEXTED)
		ret	

MEMOVER_Q:
		ld	de, (SOS.SIZE)
		add	hl, de
		ret	nc
MEMOVER:
		ld	a, 0Fh
FERR0:
		jp	ERR

MEMPROT_Q:
		ld	de, (MEMAX)
		inc	de
		inc	de
		call	CP16
		ret	nc
MEMPROT:
		ld	a, 25h ; '%'
		jr	FERR0

LOADM:
		call	_FILE1
		call	_more_
		jr	nz, LOADM2
		call	SK
		ld	a, 1
		ld	(LDWK+3), hl
LOADM00:
		ld	(LDWK+2), a
		call	_ROPEN
		ld	a, (LDWK+2)
		ld	hl, (SOS.DTADR)
		or	a
		jr	z, LOADM1
		ld	hl, (LDWK+3)
		ld	(SOS.DTADR), hl
LOADM1:
		call	MEMPROT_Q
		call	MEMOVER_Q
		ld	de, LODMES
		call	SOS.MSX
		call	_FPRNT
		call	SOS.RDD
		jr	c, FERR0
		jp	TEXT0
LOADM2:
		xor	a
		jr	LOADM00

SAVEM:
		call	_FILE1
		call	CARE_Q
		call	SK_SK
		ld	(SOS.DTADR), hl
		ex	de, hl
		or	a
		sbc	hl, de
		inc	hl
		ld	(SOS.SIZE), hl
		call	_more_
		jr	nz, SAVE0
		call	SK
		ld	(SOS.EXADR), hl
SAVE0:
		call	SOS.WOPEN
		jr	c, FERR
		call	SOS._NL
		call	SOS.MPRNT
		db "Writing "
		db 0
		call	_FPRNT
		call	SOS.WRD
		jr	c, FERR
		ret	

SAVE:
		call	_FILE2
		ld	de, (TEXTST)
		ld	(SOS.DTADR), de
		ld	hl, (TEXTED)
		or	a
		sbc	hl, de
		inc	hl
		inc	hl
		ld	(SOS.SIZE), hl
		ld	hl, HOT
		ld	(SOS.EXADR), hl
		call	SAVE0
		jp	HOT

FSET:
		call	_FILE2
		call	SOS._SET
		jr	KILL0

FRESET:
		call	_FILE2
		call	SOS._RESET
		jr	KILL0

RENAME:
		call	_FILESUB
		call	SOS.FILE
		ld	a, (de)
		cp	3Ah ; ':'
		jr	z, .renjmp1
		ld	a, 0Dh
		scf	
.renjmp1
		inc	de
		call	nc, SOS.NAME
		ex	af, af'
		call	_FILE0+3
		ex	af, af'
		jr	KILL0

KILL:
		call	_FILE2
		call	SOS.KILL
KILL0:
		ret	nc
FERR:
		jp	ERR

READ:
		call	DEV_SK_SK_SK
		ld	a, c
		call	SOS.DRDSB
		jr	KILL0

WRITE:
		call	DEV_SK_SK_SK
		ld	a, c
		call	SOS.DWTSB
		jr	KILL0

DEV_SK_SK_SK:
		ld	a, (ix+0)
		cp	2Ch ; ','
		call	SETDEV0
		call	CARE_Q
		jp	SK_SK_SK

DEVICE:
		call	DEV
		jp	SOS.SDVSW

DSK:
		call	SOS.RDVSW
		ld	l, a
		ld	h, 0
		ret	

DIR:
		call	SETDEV
		call	SOS.DIR
		ret	nc
		jr	FERR

SETDEV:
		call	SMED
SETDEV0:
		call	SETDEV1
		ld	(SOS.DSK), a
		ret	
SETDEV1:
		jp	z, SOS.RDVSW
DEV:
		call	SK
		ld	a, l
		cp	3Ah ; ':'
		ret	nz
		ld	a, h
		ret	

LET:
DAINYU:
		ld	a, (ix+0)
		call	AtoZ
DAINYU0:
		call	ADRX+3
		call	IXP
		cp	25h ; '%'
		jr	z, LETIO
		cp	5Bh ; '['
		jr	z, LETSGL
		cp	28h ; '('
		call	z, LETDBL
		call	EQ_QUES
DAINYU1:
		push	hl
		call	SK
		ex	de, hl
		pop	hl
		ld	(hl), e
		inc	hl
		ld	(hl), d
		ret	

LETSGL:
		call	SGL
		call	P_QUES
		push	hl
		call	SK
		ex	de, hl
		pop	hl
		ld	(hl), e
		ret	
LETIO:
		call	IXP
		cp	5Bh ; '['
		jr	z, LETIOSGL
		cp	28h ; '('
		jp	nz, err13
LETIODBL:
		call	DBL
		call	P_QUES
		push	hl
		call	SK
		pop	bc
		ex	de, hl
		jp	_WOUT+2
LETIOSGL:
		call	SGL
		call	P_QUES
		push	hl
		call	SK
		pop	bc
		out	(c), l
		ret	
LETDBL:
		call	DBL
		jp	IXP
SGL:
		ex	de, hl
SGL0:
		push	hl
		call	SK_KK
		pop	de
		add	hl, de
		ret	

DBL:
		ex	de, hl
DBL0:
		push	hl
		call	SK_K
		add	hl, hl
		pop	de
		add	hl, de
		ret	

ALPHorNUM_:
		cp	30h ; '0'
		ret	c
		cp	3Ah ; ':'
		jr	c, AtoZ1

ALPH_:
		cp	41h ; 'A'
		ret	c
		cp	5Bh ; '['
		jr	c, AtoZ1
		cp	61h ; 'a'
		ret	c
		cp	7Bh ; '{'
		jr	c, AtoZ1
		scf	
		ret	
AtoZ1:
		or	a
		ret	
AtoZ:
		call	ALPH_
		ret	nc
		jp	err13
AtoZN:
		call	ALPHorNUM_
		jr	AtoZ+3

ADRX:
		ld	a, (ix+0)
		call	AtoZ
		call	CAP
		call	EVVAR
		ex	de, hl
		ret	

ADR:
		call	ADRX
		jp	K_QUES

SK:
		ld	hl, 0FFB0h
		add	hl, sp
		ld	de, (STKTP)
		call	CP16
		jp	c, err27
		call	SK_LR
SKSK:
		ld	a, (ix+0)
		cp	0FCh
		ret	nz
		push	hl
		call	PIXP
		push	af
		call	SK_LR
		pop	af
		pop	de
		sub	80h
		jr	z, AND_
		dec	a
		jr	z, OR_
XOR_:
		ld	a, h
		xor	d
		ld	h, a
		ld	a, l
		xor	e
		ld	l, a
		jr	SKSK
AND_:
		ld	a, h
		and	d
		ld	h, a
		ld	a, l
		and	e
		ld	l, a
		jr	SKSK

OR_:
		ld	a, h
		or	d
		ld	h, a
		ld	a, l
		or	e
		ld	l, a
		jr	SKSK

SK_LR:
		call	SKPM
		ld	a, (ix+0)
		cp	3Ch ; '<'
		jr	z, SLESS
		cp	3Eh ; '>'
		jr	z, SGRE
		cp	3Dh ; '='
		ret	nz
SEQU:
		inc	ix
		push	hl
		call	SKPM
		pop	de
		call	_OP_EQ
		jr	SK_LR+3
SLESS:
		call	PIX
		push	hl
		cp	3Dh ; '='
		jr	z, SLRSE
		cp	3Eh ; '>'
		jr	z, SNEQU
		call	SKPM
		pop	de
		call	_OP_GREAT
		jr	SK_LR+3
SLRSE:
		inc	ix
		call	SKPM
		pop	de
		call	_OP_GR_THAN
		jr	SK_LR+3
SNEQU:
		inc	ix
		call	SKPM
		pop	de
		call	_OP_NOTEQ
		jr	SK_LR+3
SGRE:
		call	PIX
		push	hl
		cp	3Dh ; '='
		jr	z, SGREE
		cp	3Ch ; '<'
		jr	z, SNEQU
		call	SKPM
		pop	de
		call	_OP_LESS
		jr	SK_LR+3
SGREE:
		inc	ix
		call	SKPM
		pop	de
		call	_OP_LESS_THAN
		jr	SK_LR+3

SKPM:
		call	SKMD
		ld	a, (ix+0)
		cp	2Bh ; '+'
		jr	z, PLUS
		cp	2Dh ; '-'
		ret	nz
MINUS:
		inc	ix
		push	hl
		call	SKMD
		ex	de, hl
		pop	hl
		or	a
		sbc	hl, de
		jr	SKPM+3
PLUS:
		inc	ix
		push	hl
		call	SKMD
		pop	de
		add	hl, de
		jr	SKPM+3

SKMD:
		call	SKKOU
		ld	a, (ix+0)
		cp	2Ah ; '*'
		jr	z, MUL_
		cp	2Fh ; '/'
		ret	nz
DIV_:
		inc	ix
		push	hl
		call	SKKOU
		ex	de, hl
		pop	hl
		call	_DIV
		jr	SKMD+3
MUL_:
		inc	ix
		push	hl
		call	SKKOU
		pop	de
		call	_MUL
		jr	SKMD+3

SKKOU:
		ld	a, (ix+0)
		cp	0FDh
		jp	z, FUNCT
		cp	2Dh ; '-'
		jr	z, FU
		cp	22h ; '"'
		jp	z, EVSTR
		cp	24h ; '$'
		jp	z, EVHEX
		cp	26h ; '&'
		jp	z, EVHEB1
		cp	28h ; '('
		jr	z, EV_K
		cp	30h ; '0'
		jr	c, err130
		cp	3Ah ; ':'
		jp	c, EVDEC
		call	CAP
		cp	41h ; 'A'
		jr	c, err130
		cp	5Bh ; '['
		jp	c, EVVARIABLE
		jr	err130
FU:
		inc	ix
		call	SKKOU

_MINUS:
		call	_NOT
		inc	hl
		ret	

EV_K:
		inc	ix
SK_K:
		call	SK
K_QUES:
		call	IXP
		cp	29h ; ')'
		ret	z
		jr	err130
SK__:
		call	SK
CARE_Q:
		call	IXP
		cp	2Ch ; ','
		ret	z
		jr	err130
SK_KK:
		call	SK
		call	IXP
		cp	5Dh ; ']'
		ret	z
		jr	err130
P_Q:
		call	IXP
_QUES:
		cp	22h ; '"'
		ret	z
		jr	err130
P_QUES:
		call	IXP
EQ_QUES:
		cp	3Dh ; '='
		ret	z
		jr	err130
D_QUES:
		call	IXP
		or	a
		ret	nz
err130:
		jp	err13

MORE:
		inc	hl
		jr	SK_SK+3

SK_SK:
		call	SK__
		push	hl
		call	SK
		ex	de, hl
		pop	hl
		ret	
SK_SK_K:
		call	SK_SK
		jr	K_QUES
SK_SK_SK:
		call	SK__
		push	hl
		call	SK__
		push	hl
		call	SK
		ld	b, h
		ld	c, l
		pop	de
		pop	hl
		ret	
SK_SK_SK_K:
		call	SK_SK_SK
		jr	K_QUES

_more_:
		ld	a, (ix+0)
more0:
		cp	2Ch ; ','
		ret	nz
		inc	ix
		ret	

EVSTR:
		inc	ix
		ld	hl, 0
		call	STRED
		ret	z
		ld	l, a
		call	STRED
		ret	z
		ld	h, l
		ld	l, a
		call	STRED
		jr	nz, err130
		ret	
STRED:
		call	IXP
		cp	22h ; '"'
		ret	

EVHEX:
		call	PIXC
		call	SOS.HEX
		jr	c, err130
		ld	l, a
		ld	h, 0
		ld	b, 0
EVHEX0:
		call	PIXC
		call	SOS.HEX
		ret	c
		add	hl, hl
		add	hl, hl
		add	hl, hl
		add	hl, hl
		ld	c, a
		add	hl, bc
		jr	EVHEX0
EVHEB1:
		call	PIX
		call	CAP
		cp	48h ; 'H'
		jr	z, EVHEX
		cp	42h ; 'B'
		jr	nz, EVBIN+3

EVBIN:
		call	PIX
		sub	30h ; '0'
		jr	c, err130
		cp	2
		jp	nc, err13
		ld	l, a
		ld	h, 0
EVBIN0:
		call	PIX
		sub	30h ; '0'
		ret	c
		cp	2
		ret	nc
		rra	
		adc	hl, hl
		jr	EVBIN0

EVDEC:
		and	0Fh
		ld	l, a
		ld	h, 0
		ld	b, 0
EVDEC0:
		call	PIX
		sub	30h ; '0'
		ret	c
		cp	0Ah
		ret	nc
		ld	d, h
		ld	e, l
		add	hl, hl
		add	hl, hl
		add	hl, de
		add	hl, hl
		ld	c, a
		add	hl, bc
		jr	EVDEC0

EVVARIABLE:
		call	EVVAR
		ld	a, (ix+0)
		cp	25h ; '%'
		jr	z, EVIO
		cp	5Bh ; '['
		jr	z, EVSGL
		cp	28h ; '('
		ret	nz
EVDBL:
		inc	ix
		call	DBL0
		ld	a, (hl)
		inc	hl
		ld	h, (hl)
		ld	l, a
		ret	
EVSGL:
		inc	ix
		call	SGL0
		ld	l, (hl)
		ld	h, 0
		ret	
EVIO:
		call	PIX
		cp	5Bh ; '['
		jr	z, EVIOSGL
		cp	28h ; '('
		jp	nz, err13
EVIODBL:
		inc	ix
		call	DBL0
		jp	_WINP
EVIOSGL:
		inc	ix
		call	SGL0
		ld	b, h
		ld	c, l
		in	l, (c)
		ld	h, 0
		ret	

EVVAR0:
		call	PIX
		call	ALPHorNUM_
		ret	c
		call	CAP
EVVAR00:
		inc	ix
		ld	b, a
		ret	

EVVAR:
		ld	c, a
		ld	b, 20h ; ' '
		call	EVVAR0
		ld	a, b
		cp	20h ; ' '
		jr	z, EVVARM
EVVAL10:
		call	VARSKP
SRCHVAR:
		ld	hl, VARNAME
_SRCHvar_:
		ld	a, (hl)
		or	a
		jr	z, MAKEVAR
		inc	hl
		ld	d, (hl)
		ld	e, a
		call	CPVAR
		jr	z, FINDVAR
		inc	hl
		jp	_SRCHvar_
CPVAR:
		cp	c
		ret	nz
		ld	a, d
		cp	b
		ret	

VARSKP:
		ld	a, (ix+0)
		call	ALPHorNUM_
		ret	c
		inc	ix
		jr	VARSKP

MAKEVAR:
		ld	de, VARNAME+254-52
		call	CP16
		jp	z, err32
		ld	(hl), c
		inc	hl
		ld	(hl), b
FINDVAR:
		ld	bc, VARVAL+51-VARNAME
		add	hl, bc
		ex	de, hl
		ld	a, (de)
		inc	de
		ld	l, a
		ld	a, (de)
		ld	h, a
		dec	de
		ret	

EVVARM:
		ld	a, c
		sub	41h ; 'A'
		add	a, a
		ld	c, a
		ld	b, 0
		ld	hl, VARVAL
		jr	FINDVAR+3

_OP_EQ:
		xor	a
		sbc	hl, de
		ld	hl, 0
		ret	nz
		inc	l
		ret	

_OP_NOTEQ:
		call	_OP_EQ
NOTNOT:
		ld	a, l
		xor	1
		ld	l, a
		ret	

_OP_GREAT:
		ex	de, hl
_OP_LESS:
		xor	a
		sbc	hl, de
		adc	a, a
		ld	h, 0
		ld	l, a
		ret	

_OP_GR_THAN:
		call	_OP_LESS
		jr	NOTNOT

_OP_LESS_THAN:
		call	_OP_GREAT
		jr	NOTNOT

err140:
		ld	a, d
		or	e
		ret	nz
		call	CP16
		ret	nc
		jr	err14
err150:
		add	hl, bc
		jr	c, err151
		ex	de, hl
		ld	hl, (MEMAX)
		call	CP16
		ret	nc
err151:
		ld	ix, 0
		jr	err15
err260:
		ld	ix, (GOTIX)
		jr	err26

STEP:
TO:
THEN:
err13:
		ld	a, 0Dh
		db    1 ;  
err14:
		ld	a, 0Eh
		db    1 ;  
err15:
		ld	a, 0Fh
		db    1 ;  
err16:
		ld	a, 10h
		db    1 ;  
err17:
		ld	a, 11h
		db    1 ;  
err18:
		ld	a, 12h
		db    1 ;  
err19:
		ld	a, 13h
		db    1 ;  
err20:
		ld	a, 14h
		db    1 ;  
err21:
		ld	a, 15h
		db    1 ;  
err22:
		ld	a, 16h
		db    1 ;  
err23:
		ld	a, 17h
		db    1 ;  
err24:
		ld	a, 18h
		db    1 ;  
err25:
		ld	a, 19h
		db    1 ;  
err26:
		ld	a, 1Ah
		db    1 ;  
err27:
		ld	a, 1Bh
		db    1 ;  
err28:
		ld	a, 1Ch
		db    1 ;  
err29:
		ld	a, 1Dh
		db    1 ;  
err30:
		ld	a, 1Eh
		db    1 ;  
err31:
		ld	a, 1Fh
		db    1 ;  
err32:
		ld	a, 20h ; ' '
		db    1 ;  
err33:
		ld	a, 21h ; '!'
		db    1 ;  
err34:
		ld	a, 22h ; '"'
		db    1 ;  
err35:
		ld	a, 23h ; '#'
		db    1 ;  
err36:
		ld	a, 24h ; '$'
ERR:
		ld	hl, 0
		ld	(BRK), hl
		push	af
		xor	a
		call	PRMODE0
		call	INITSTK0
		ld	a, (VALW+1)
		or	a
		jr	z, .errjmp1
		ld	ix, (VALW)
.errjmp1
		xor	a
		ld	(VALW+1), a
		pop	af
		call	ERROR
		call	NOW
		jp	c, HOT
		ld	a, (ERFLG)
		or	a
		jr	z, ER1
		ld	de, ERMES
ER0:
		call	SOS.MSX
		call	SOS.MPRNT
		db " in "
		db 0
		call	_PRDEC
		call	SOS._NL
		jp	HOT
ER1:
		ld	ix, (NOWADR)
		call	LINLIS100
		jr	ER1-3
ERROR:
		call	SOS._NL
		cp	0Fh
		jp	c, SOS.ERROR
		cp	26h ; '&'
		jp	nc, SOS.ERROR
		sub	0Fh
		add	a, a
		ld	c, a
		ld	b, 0
		ld	hl, ERRMES
		add	hl, bc
		ld	e, (hl)
		inc	hl
		ld	d, (hl)
		call	SOS.MSX
		call	SOS.BELL
		jp	SOS._NL

ERRMES:	dw	EM15,EM16,EM17,EM18
		dw	EM19,EM20,EM21,EM22
		dw	EM23,EM24,EM25,EM26
		dw	EM27,EM28,EM29,EM30
		dw	EM31,EM32,EM33,EM34
		dw	EM35,EM36,EM37
EM15:	db "Out of memory"
		db 0
EM16:	db "Bad NEXT"
		db 0
EM17:	db "Bad RETURN"
		db 0
EM18:	db "Bad UNTIL"
		db 0
EM19:	db "Bad WEND"
		db 0
EM20:	db "Bad END IF"
		db 0
EM21:	db "Bad FOR"
		db 0
EM22:	db "Bad GOSUB"
		db 0
EM23:	db "Bad REPEAT"
		db 0
EM24:	db "Bad WHILE"
		db 0
EM25:	db "Bad Block IF"
		db 0
EM26:	db "Undefined label"
		db 0
EM27:	db "Stack over flow"
		db 0
EM28:	db "Division by 0"
		db 0
EM29:	db "Can"
		db 27h
		db "t continue"
		db 0
EM30:	db "Var stack empty"
		db 0
EM31:	db "Var stack over flow"
		db 0
EM32:	db "Too many variables"
		db 0
EM33:	db "Line length over"
		db 0
EM34:	db "Bad ELSE"
		db 0
EM35:	db "Can"
		db 27h
		db "t do it."
		db 0
EM36:	db "Bad RET FUNC"
		db 0
EM37:	db "Memory protected"
		db 0

BREAK100:
		ld	hl, STOPF
		ld	b, (hl)
		set	2, (hl)
		call	BREAK
		ld	(hl), b
		ret	

BREAK:
		ld	a, (STOPF)
		and	2
		ret	nz
		ld	de, BREMES
BREAK00:
		ld	hl, 0
		ld	(BRK), hl
		call	SOS.BELL
		call	NOW
		jp	c, HOT
		ld	(BRK), ix
BREAK0:
		xor	a
		call	PRMODE0
		call	SOS._NL
		jp	ER0

STOP:
		ld	a, (STOPF)
		and	1
		ret	nz
		ld	de, STMES
		jr	BREAK00

ERMES:	db "Error"
		db 0
BREMES:	db "Break"
		db 0
STMES:	db "Stop"
		db 0

COM:
		call	NOW
		jp	nc, err35
		ld	hl, COMTBL
COM0:
		ld	bc, LINED
		push	bc
		jr	TBLJMP

FUNCT:
		ld	hl, FUNCTBL
TBLJMP:
		call	PIXP
		sub	80h ; '�'
		jp	c, err35
TBLJMP0:
		add	a, a
		ld	c, a
		ld	b, 0
		add	hl, bc
		ld	a, (hl)
		inc	hl
		ld	h, (hl)
		ld	l, a
		jp	(hl)

STATEMENT:
		ld	hl, SMTBL
		jp	COM0

END:
		call	NOW
		jr	c, _CONT
		ld	hl, 0
		ld	(BRK), hl
		call	INITSTK0

_CONT:
		jp	HOT
CONT:
		ld	hl, (BRK)
		ld	a, h
		or	l
		jp	z, err29
		push	hl
		pop	ix
		ld	a, (STOPF)
		ld	b, a
		and	4
		ret	z
		ld	a, b
		and	0FBh
		ld	(STOPF), a
		jr	JIKKOU

JIKKO00:
		or	a
		jp	z, err13
JIKKO0:
		inc	ix
JIKKOU:
		ld	a, (ix+0)
		cp	20h ; ' '
		jr	c, JIKKO00
		cp	0FFh
		jr	z, STATEMENT
		cp	27h ; '''
		jr	z, REMREM
		cp	5Ch ; '\'
		jr	z, LABSKP
		cp	0A2h
		jr	z, LABSKP
		cp	3Fh ; '?'
		jr	z, PRINT_Q
		cp	21h ; '!'
		jr	z, GOSUB_E
		cp	23h ; '#'
		jr	z, PROC_S
		cp	0FEh
		jp	z, COM
		call	DAINYU0
LINED:
		call	SOS.BRKEY
		call	z, BREAK
#IF exists IS_LSX
		call	SNDPOLL
#ENDIF
		ld	a, (ix+0)
		cp	3Ah ; ':'
		jr	z, JIKKO0
		or	a
		jr	z, NXLIN
		cp	27h ; '''
		jr	z, REMREM
		jp	err13

NXLIN:
		call	NXLIN_Q
		call	SOS.BRKEY
		call	z, BREAK100
#IF exists IS_LSX
		call	SNDPOLL
#ENDIF
		jr	JIKKOU

LABSKP:
		inc	ix
LABSKP0:
		call	IXP
		cp	5Ch ; '\'
		jr	z, LINED
		cp	0A3h
		jr	z, LINED
		or	a
		jr	z, LINED
		jr	LABSKP0

REMREM:
		call	ESRCH
		jr	NXLIN

PRINT_Q:
		inc	ix
		call	PRINT
		jr	LINED

GOSUB_E:
		inc	ix
		call	GOSUB
		jr	LINED

PROC_S:
		inc	ix
		call	PROC
		jr	LINED

NXLIN_Q:
		call	NXLINSUB
		jp	z, END
		ld	(NOWADR), ix
		ret	

NXLINSUB:
		inc	ix
		ld	e, (ix+0)
		inc	ix
		ld	d, (ix+0)
		inc	ix
		ld	a, d
		or	e
		ret	

ESRCH:
		ld	a, (ix+0)
		or	a
		ret	z
		inc	ix
		jp	ESRCH

PPESRCHP:
		inc	ix
		inc	ix

ESRCHP:
		call	ESRCH
		inc	ix
		ret	

SMED:
		ld	a, (ix+0)
		or	a
		ret	z
		cp	27h ; '''
		ret	z
		cp	3Ah ; ':'
		ret	

CP16:
		push	hl
		or	a
		sbc	hl, de
		pop	hl
		ret	

LINTOP:
		ld	de, (NOWADR)
		push	ix
		pop	hl
		dec	hl
		dec	hl
		or	a
		sbc	hl, de
		ret	z
		inc	h
		dec	h
		jr	nz, LINTP
		dec	l
		ret	z
LINTP:
		xor	a
		dec	a
		ret	

LINTOPE:
		call	LINTOP
		ret	z
		jp	err13

ONGOTO:
		ld	a, l
		sub	1
		jp	c, ONSKP
		jr	z, GOTO
		ld	b, a
DO006:
		call	COMSKP
		ret	c
		djnz	DO006
		jr	GOTO

LOADRUNNER:
		cp	22h ; '"'
		jp	z, CHAIN

GOTO:
		call	SKorL
GOTO0:
		ld	a, (GOTOW)
		or	a
		jr	z, GOTO1
		xor	a
		ld	(GOTOW), a
		push	hl
		pop	ix
		pop	hl
		jp	LINED
GOTO1:
		call	SRCHHL
		jp	c, err260
RUN000:
		dec	ix
RUN0:
		pop	hl
		jp	NXLIN

RUN:
		call	CLR
		call	SMED
		jr	nz, LOADRUNNER
RUN1:
		ld	ix, (TEXTST)
		ld	a, (STOPF)
		and	0FBh
		ld	(STOPF), a
		jr	RUN000

SRCHHL:
		ld	ix, NOAREA+127
		ld	b, 3Fh ; '?'
DO007:
		ld	e, (ix-1)
		ld	d, (ix+0)
		ld	a, d
		or	e
		jr	z, SRCHHL0
		call	CP16
		jr	z, SRCHHL1
		dec	ix
		dec	ix
		djnz	DO007
		ld	ix, NOAREA+127
SRCHHL0:
		push	ix
		call	SRCHLIN
		pop	de
		ret	c
		ex	de, hl
		ld	(hl), d
		dec	hl
		ld	(hl), e
		xor	a
		dec	hl
		ld	(hl), a
		dec	hl
		ld	(hl), a
		ld	de, 82h
		add	hl, de
		or	a
PUSHIX:
		push	ix
		pop	de
		dec	hl
		ld	(hl), d
		dec	hl
		ld	(hl), e
		ret	

SRCHHL1:
		ld	e, (ix+7Dh)
		ld	d, (ix+7Eh)
		push	de
		pop	ix
		ret	

SKorL:
		ld	(GOTIX), ix
		ld	hl, GOTOW
		ld	(hl), 0
		ld	a, (ix+0)
		cp	0A2h
		jr	z, LBL
		cp	5Ch ; '\'
		jp	nz, SK
LBL:
		inc	(hl)
		inc	ix
		push	ix
		pop	de
		call	LBLCNT
		inc	b
		dec	b
		jp	z, err13
		ld	c, b
		push	ix
		ld	ix, (TEXTST)
LBL0:
		push	de
		call	NXLINSUB+2
		pop	de
		jp	z, err260
		call	SPXX
		call	IXP
		cp	0A2h
		jr	nz, .lbl0jmp1
		ld	a, 5Ch ; '\'
.lbl0jmp1
		cp	5Ch ; '\'
		call	z, LBL1
		call	ESRCHP
		jr	LBL0
LBL1:
		call	CPLBL
		ret	nz
		pop	hl
		push	ix
		pop	hl
		pop	ix
		ret	

LBLCNT:
		ld	b, 0
LBLCNT0:
		call	D_QUES
		cp	5Ch ; '\'
		ret	z
		cp	0A3h
		ret	z
		inc	b
		jr	LBLCNT0

CPLBL:
		push	de
		ld	b, c
DO008:
		ld	a, (de)
		cp	(ix+0)
		jr	nz, CPLBL0
		inc	de
		inc	ix
		djnz	DO008
		call	IXP
		cp	0A3h
		jr	z, CPLBL0
		cp	5Ch ; '\'
CPLBL0:
		pop	de
		ret	

ONGOSUB:
		ld	a, l
		sub	1
		jp	c, ONSKP
		jr	z, ONGOSUB1
		ld	b, a
DO009:
		call	COMSKP
		ret	c
		djnz	DO009
ONGOSUB1:
		call	SKorL
		call	ONSKP
		jr	GOSUB+3


GOSUB:
		call	SKorL
		push	hl
		jr	PROC1

PROC:
		call	SKorL
		push	hl
		call	PROCSUB
		call	SMED
		jp	nz, err13
PROC1:
		call	SUBSTOV
		call	PUSHIX
		ld	(SUBSP), hl
		pop	hl
		jp	GOTO0

PROCSUB:
		ld	hl, (VARSP)
		ld	bc, 0Ch
		or	a
		sbc	hl, bc
		ld	de, (VSTKST)
		call	CP16
		jp	c, err31
		ld	(VARSP), hl
		ex	de, hl
		ld	hl, (PROCVAR)
		push	hl
		ldir	
		jp	PROCS
DO010:
		ld	a, (ix+0)
		cp	2Ch ; ','
		ret	nz
		inc	ix
		push	bc
		push	hl
		call	SK
		ex	de, hl
		pop	hl
		ld	(hl), e
		inc	hl
		ld	(hl), d
		inc	hl
		pop	bc
		djnz	DO010
		ret	

SUBSTOV:
		ld	hl, (SUBSP)
		ld	a, 0ACh
		cp	l
		ret	nz
		jp	err22

SUBSTEMP:
		ld	hl, (SUBSP)
		ld	a, 0AAh
		cp	l
		ret	nz
		jp	err17

POPIX:
		ld	e, (hl)
		inc	hl
		ld	d, (hl)
		inc	hl
		push	de
		pop	ix
		ret	

RETPROC:
		call	RETPROCSUB

RETURN:
		call	SUBSTEMP
		call	SMED
		jr	z, RETURN1
RETURN0:
		inc	hl
		inc	hl
		ld	(SUBSP), hl
		jp	GOTO
RETURN1:
		call	POPIX
		ld	(SUBSP), hl
		ret	

RETPROCSUB:
		ld	de, (VARSP)
		push	de
		ld	hl, (VSTKED)
		ld	bc, 0Ch
		or	a
		sbc	hl, bc
		call	CP16
		pop	hl
		jp	c, err30
		ld	de, (PROCVAR)
		ldir	
		ld	(VARSP), hl
		ret	

ONRETURN:
		ld	a, l
		sub	1
		jr	c, ONSKP
		jr	z, ONRET1
		ld	b, a
DO011:
		call	COMSKP
		ret	c
		djnz	DO011
ONRET1:
		call	SUBSTEMP
		jr	RETURN0

_goto_	EQU	no+10
_gosub_	EQU	no+11
_return_	EQU	no+12

ON:
		call	SK
		inc	h
		dec	h
		jr	nz, ONSKP
		call	IXP
		cp	0FFh
		jr	nz, err131
		call	IXP
		cp	89h ; _goto_
		jp	z, ONGOTO
		cp	8Ah ; _gosub_
		jp	z, ONGOSUB
		cp	8Bh ; _return_
		jr	z, ONRETURN
err131:
		jp	err13

ONSKP:
		call	SMED
		ret	z
		inc	ix
		jr	ONSKP

COMSKP:
		call	SMED
		jr	z, COMSKP0
		inc	ix
		cp	2Ch ; ','
		ret	z
		jr	COMSKP
COMSKP0:
		scf	
		ret	

_step_	EQU	no+4
_to_		EQU	no+3

		push	iy
FOR:	db 0FDh ;  iy
		ld	a, l
		; cp	2Ch ; ','	FORSTK
		cp	low FORSTK
		jp	z, err21
		ld	bc, 0FFF8h
		add	iy, bc
		call	ADRX
		call	P_QUES
		ld	(iy+0),	l
		ld	(iy+1),	h
		call	DAINYU1
		call	IXP
		cp	2Ch ; ','
		jr	z, FOR0
		cp	0FFh
		jr	nz, err131
		call	IXP
		cp	82h
		jr	nz, err131
FOR0:
		call	SK
		ld	(iy+2),	l
		ld	(iy+3),	h
		ld	a, (ix+0)
		ld	hl, 1
		cp	2Ch ; ','
		jr	z, FOR1
		cp	0FFh
		jr	nz, FOR2
		call	PIX
		cp	83h
		jr	nz, err131
FOR1:
		inc	ix
		call	SK
FOR2:
		ld	(iy+4),	l
		ld	(iy+5),	h
		push	ix
		pop	hl
		ld	(iy+6),	l
		ld	(iy+7),	h
		ret	

		push	iy
NEXT:	db 0FDh ; �	iy
		ld	a, l

		; cp	0ACh ; 	FORSTKED
		cp	low FORSTKED
		jp	z, err16
		call	SMED
		jr	z, NEXT1
NEXT00:
		call	ADRX
		ld	e, (iy+0)
		ld	d, (iy+1)
		call	CP16
		jp	nz, err14
		jr	NEXT2
NEXT1:
		ld	l, (iy+0)
		ld	h, (iy+1)
NEXT2:
		push	hl
		ld	a, (hl)
		inc	hl
		ld	h, (hl)
		ld	l, a
		ld	e, (iy+4)
		ld	d, (iy+5)
		add	hl, de
		jr	c, NEXT5
		ex	de, hl
		pop	hl
		ld	(hl), e
		inc	hl
		ld	(hl), d
		ld	l, (iy+2)
		ld	h, (iy+3)
		call	CP16
		jr	c, NEXT4
		ld	e, (iy+6)
		ld	d, (iy+7)
		push	de
		pop	ix
		ret	
NEXT5:
		pop	hl
NEXT4:
		ld	bc, 8
		add	iy, bc
		call	_more_
		ret	nz
		jr	NEXT00
		ret	

REPEAT:
		ld	hl, (REPSP)
		ld	a, l
		; cp	0ECh ;  REPSTK
		cp	low REPSTK
		jp	z, err23
		call	PUSHIX
		ld	(REPSP), hl
		ret	

UNTIL:
		ld	hl, (REPSP)
		ld	a, l
		; cp	0Ch	; REPSTKED
		cp	low REPSTKED
		jp	z, err18
		push	hl
		call	SK
		ld	a, h
		or	l
		jr	z, UNTIL0
		pop	hl
		inc	hl
		inc	hl
		ld	(REPSP), hl
		ret	
UNTIL0:
		pop	hl
		call	POPIX
		ret	

_wend_	EQU	no+9
_while_	EQU	no+8

WHILE:
		push	ix
		call	LINTOPE
		ld	hl, (WHLSP)
		ld	a, l
		; cp	0Ch		; WHLSTK
		cp	low WHLSTK
		jp	z, err24
		push	hl
		call	SK
		ld	a, h
		or	l
		jr	z, WHILE0
		pop	hl
		pop	de
		dec	de
		dec	de
		dec	de
		dec	de
		dec	hl
		ld	(hl), d
		dec	hl
		ld	(hl), e
		ld	(WHLSP), hl
		ret	
WHILE0:
		pop	hl
		pop	hl
		ld	b, 1
WHILE1:
		call	ESRCH
		call	NXLIN_Q
		call	SPXX
WHL00:
		call	IXP
		cp	0FFh
		jr	nz, WHILE1
		call	IXP
		cp	88h ; _wend_
		jr	z, WHILE2
		cp	87h ; _while_
		jr	nz, WHILE1
		inc	b
		jr	WHILE1
WHILE2:
		djnz	WHILE1
		ret	

WEND:
		ld	hl, (WHLSP)
		ld	a, l
		; cp	2Ch ; WHLSTKED
		cp	low WHLSTKED
		jp	z, err19
		call	POPIX
		ld	(WHLSP), hl
		jp	RUN000

_if_		EQU	no+16
_then_	EQU no+17
_else_	EQU no+18
_endif_	EQU no+19

IF:
		call	SK
		call	SMED
		jr	z, BLOCKIF
IFIFIF:
		call	IXP
		cp	0FFh
		jp	nz, err13
		call	IXP
		cp	89h ; _goto_
		jr	z, IFGOTO
		cp	8Ah ; _gosub_
		jr	z, IFGOSUB
		cp	8Bh ; _return_
		jr	z, IFRETURN
		cp	90h ; _then_
		jp	nz, err13
IFTHEN:
		ld	a, h
		or	l
		jr	nz, IFRET
IFELSE:
		call	SRCHELSE
IFRET:
		pop	hl
		jp	JIKKOU
IFRET0:
		call	SMED
		ret	z
		jr	IFRET

IFGOTO:
		ld	a, h
		or	l
		jr	z, IFELSE
		jp	GOTO
IFGOSUB:
		ld	a, h
		or	l
		jr	z, IFELSE
		jp	GOSUB
IFRETURN:
		ld	a, h
		or	l
		jr	z, IFELSE
		jp	RETURN

SRCHELSE:
		call	IXP
		or	a
		jr	z, SRCHELRET
		cp	0FFh
		jr	nz, SRCHELSE
		call	IXP
		cp	91h
		jr	nz, SRCHELSE+3
		ret	
SRCHELRET:
		dec	ix
		pop	hl
		ret	

BLOCKIF:
		push	hl
		call	ESRCH
		ld	hl, (IFSP)
		call	IFPUSH
		ld	(hl), 0
		pop	de
		ld	a, d
		or	e
		jr	nz, BLIFT
		inc	(hl)
BLIFNIL:
		call	NXLIN_Q
		call	SPXX
BLIFNL:
		call	IXP
		cp	0FFh
		jr	nz, BLIFN
		call	IXP
		cp	8Fh ; _if_
		jr	z, FBLIF
		cp	91h ; _else_
		jr	z, FELSE
		cp	92h ; _endif_
		jr	z, FEDIF
BLIFN:
		call	ESRCH
		jr	BLIFNIL

BLIFT:
		call	NXLIN_Q
		call	SPXX
BLIFT00:
		call	IXP
		cp	0FFh
		jr	nz, GOTO4
		call	IXP
		cp	90h ; _then_
		jp	z, IFRET0
GOTO4:
		ld	ix, (NOWADR)
		dec	ix
		dec	ix
		jp	RUN000

FBLIF:
		ld	a, (ix+0)
		cp	0FFh
		jr	z, BLIFN
		or	a
		jr	z, FBLIF00
		inc	ix
		jr	FBLIF
FBLIF00:
		call	IFPUSH
		ld	(hl), 3
		jr	BLIFNIL

FELSE:
		ld	a, l
		; cp	0ECh ; IFSTKED
		cp	low IFSTKED
		jp	z, err34
		ld	a, (hl)
		sub	1
		jr	c, BLIFN
		jp	z, IFRET0
		cp	2
		jp	nz, err34
		dec	(hl)
		jr	BLIFN

FEDIF:
		ld	a, l
		; cp	0ECh ; IFSTKED
		cp	low IFSTKED
		jp	z, err20
		ld	a, (hl)
		inc	hl
		ld	(IFSP),	hl
		cp	2
		ret	c
		jr	BLIFN

IFPUSH:
		ld	a, l
		; cp	0DCh ; IFSTK
		cp	low IFSTK
		jp	z, err25
		dec	hl
		ld	(IFSP),	hl
		ret	

ENDIF:
		ld	hl, (IFSP)
		ld	a, l
		; cp	0ECh ; IFSTKED
		cp	low IFSTKED
		jp	z, err20
		inc	hl
		ld	(IFSP),	hl
		ret	

ELSE:
		call	LINTOP
		jp	nz, ESRCH
		ld	hl, (IFSP)
		ld	a, l
		; cp	0ECh ; IFSTKED
		cp	low IFSTKED
		jp	z, err34
		inc	(hl)
		dec	(hl)
		jp	nz, err34
		jp	BLIFN

_CALL_:
		call	SK
		push	iy
		push	ix
		push	hl
		pop	iy
CALL100:
		ld	de, CALL0
		push	de
		jp	(iy)
CALL0:
		pop	ix
		pop	iy
		ret	

CALL_A:
		call	SK
CALL_A100:
		push	iy
		push	ix
		push	hl
		pop	ix
		ld	de, CALL_A0
		push	de
		ld	(SPSP),	sp
		ld	sp, VARVAL+52
		pop	af
		pop	bc
		pop	de
		pop	hl
		ld	sp, (SPSP)
		jp	(ix)
CALL_A0:
		ld	(SPSP),	sp
		ld	sp, VARVAL+60
		push	hl
		push	de
		push	bc
		push	af
		ld	sp, (SPSP)
		jr	CALL0

USR_A:
		call	SK_K
		jr	CALL_A100

USR:
		call	SK
		push	iy
		push	hl
		call	_more_
		jr	nz, USR100
		call	SK
USR100:
		call	K_QUES
		pop	iy
		push	ix
		jr	CALL100

FUNC:
		call	SKorL
		push	hl
		call	PROCSUB
		call	K_QUES
		call	SUBSTOV
		call	PUSHIX
		ld	(SUBSP), hl
		ex	(sp), hl
		jp	GOTO0

RETFUNC:
		ld	hl, 0Dh
		add	hl, sp
		ld	de, (SYSSTK)
		call	CP16
		jp	nc, err36
		call	SK
		push	hl
		call	RETPROCSUB
		call	SUBSTEMP
		call	POPIX
		ld	(SUBSP), hl
		pop	hl
		pop	de
		ret	

LOCAL:
		call	SK
		ld	a, l
		sub	41h ; 'A'
		jp	c, err15
		cp	15h
		jp	nc, err15
		add	a, a
		ld	c, a
		ld	b, 0
		ld	hl, VARVAL
		add	hl, bc
		ld	(PROCVAR), hl
		ret	

PRINT:
		call	SMED
		jp	z, _LTNL
PRINT0:
		call	PRINTZ
		call	SMED
		ret	z
		call	PRINTY
		inc	ix
		call	SMED
		ret	z
		jp	PRINT0

PRINTZ:
		call	IXP
		cp	23h ; '#'
		jp	z, PRHEX100
		cp	21h ; '!'
		jp	z, PRMSX0
		cp	25h ; '%'
		jp	z, PRDEC50
		cp	3Ch ; '<'
		jr	z, PRDPCT
		cp	2Fh ; '/'
		jp	z, _LTNL
		cp	22h ; '"'
		jr	z, PRSTR
		cp	0FBh
		jr	nz, PRDEC
		call	IXP
		ld	hl, PRTTBL
		jp	TBLJMP+3

PRINTY:
		cp	2Fh ; '/'
		jp	z, _LTNL
		cp	2Ch ; ','
		jp	z, _PRNTS
		cp	3Bh ; ';'
		ret	z
err132:
		jp	err13

PRSTR:
		call	D_QUES
		cp	22h ; '"'
		ret	z
		call	_PRINT
		jp	PRSTR

PRDPCT:
		call	IXP
		cp	3Eh ; '>'
		ret	z
		cp	43h ; 'C'
		jr	c, PRDPCT2
		ld	hl, PRDPCTTBL
PRDPCT0:
		inc	(hl)
		dec	(hl)
		jr	z, err132
		cp	(hl)
		inc	hl
		jr	z, PRDPCT1
		inc	hl
		jr	PRDPCT0
PRDPCT1:
		ld	a, (hl)
		call	_PRDPCTSUB
		jp	PRDPCT
PRDPCT2:
		sub	30h ; '0'
		jr	c, err132
		cp	7
		jr	nc, err132
		jr	PRDPCT1+1

PRDPCTTBL:
		db "D"
		db    1 ;  
		db "U"
		db    2 ;  
		db "R"
		db    3 ;  
		db "L"
		db    4 ;  
		db "H"
		db    5 ;  
		db "C"
		db    6 ;  
		db    0 ;  

PRDEC:
		dec	ix
		call	SK
		jp	_PRDEC
PRMSX:
		call	PRMSX0
		call	PREND
		jr	PRMSX
PRMSG:
		call	SK
		call	_PRMSG
		call	PREND
		jr	PRMSG
PRCHR:
		call	SK
		call	_PRCHR
		call	PREND
		jr	PRCHR
PRSPC:
		call	SK
		call	_PRSPC
		call	PREND
		jr	PRSPC
PRTAB:
		call	SK
		call	_PRTAB
		call	PREND
		jr	PRTAB
PRBIN:
		call	SK
		call	_PRBIN
		call	PREND
		jr	PRBIN
PRBINL:
		call	SK
		call	_PRBINL
		call	PREND
		jr	PRBINL
PRHEX2:
		call	PRHEX200
		call	PREND
		jr	PRHEX2
PRHEX4:
		call	PRHEX400+2
		call	PREND
		jr	PRHEX4
PRDEC5:
		call	PRDEC50
		call	PREND
		jr	PRDEC5
PRPN:
		call	SK
		call	_PRPN
		call	PREND
		jr	PRPN
PRLEFT:
		call	SK_SK_K
		jp	_PRLEFT
PRRIGHT:
		call	SK_SK_K
		jp	_PRRIGHT
PRSTRING:
		call	SK_SK_K
		jp	_PRSTRING
PRDEC50:
		call	SK
		jp	_PRDEC5
PRMSX0:
		call	SK
		jr	_PRMSX
PRHEX100:
		ld	a, (ix+0)
		cp	23h ; '#'
		jr	z, PRHEX400
PRHEX200:
		call	SK
		jp	_PRHEX2
PRHEX400:
		inc	ix
		call	SK
		jr	_PRHEX4

PREND:
		call	IXP
		cp	3Bh ; ';'
		ret	z
		cp	2Ch ; ','
		jr	z, _PRNTS
		cp	29h ; ')'
		jp	nz, err13
		pop	hl
		ret	

_GETL:
		ld	de, (SOS._KBFAD)
		ld	a, (KEY0F)
		or	a
		ld	a, 0
		ld	(KEY0F), a
		ret	nz
		jp	SOS._GETL

_PRNTS:
		push	af
		ld	a, 20h ; ' '
		call	_PRINT
		pop	af
		ret	

CLS:
		call	SOS.LPTOF
		ld	a, 0Ch
		jp	SOS._PRINT

_PRINT:
		call	SOS._PRINT
		push	hl
		ld	hl, PRCNT
		inc	(hl)
		pop	hl
		ret	

_PRINT0:
		call	SOS.LPTON
		call	SOS._PRINT
		jp	LPTER_Q0

_PRMSG:
		ex	de, hl
_MSG:
		push	af
		push	de
MSG_1:
		ld	a, (de)
		inc	de
		cp	0Dh
		jr	z, MSG_2
		call	_PRINT
		jr	MSG_1
MSG_2:
		pop	de
		pop	af
		ret	

_PRMSX:
		ex	de, hl
_MSX:
		push	af
		push	de
MSX_1:
		ld	a, (de)
		inc	de
		or	a
		jr	z, MSG_2
		call	_PRINT
		jr	MSX_1

_PRNL:
		push	af
		push	hl
		ld	hl, (PRCNT)	; TODO 正しいか？
		ld	a, (hl)
		or	a
		call	nz, _LTNL
		pop	hl
		pop	af
		ret	

_LTNL:
		push	af
		ld	a, 0Dh
		call	_PRINT

		pop	af
		ret	

_PRHEX4:
		ld	a, h
		call	PRHEX
_PRHEX2:
		ld	a, l
PRHEX:
		push	af
		rrca	
		rrca	
		rrca	
		rrca	
		call	PRHEX0
		pop	af
PRHEX0:
		call	SOS.ASC
		jr	_PRINT
_PRPN:
		ld	a, h
		and	80h
		jr	z, _PRDEC
		ld	a, 2Dh ; '-'
		call	_PRINT
		call	_MINUS
_PRDEC:
		call	HLDEC
		call	DESPSKP
		jr	_MSX
_PRDEC5:
		call	HLDEC
		jr	_MSX
HLDEC:
		ld	de, PRWK+5
		xor	a
		ld	(de), a
		ld	bc, 50Ah
DO012:
		call	DIVHLC
		or	30h ; '0'
		dec	de
		ld	(de), a
		djnz	DO012
		push	de
		ld	b, 4
DO013:
		ld	a, (de)
		cp	30h ; '0'
		jr	nz, HLDECRET
		ld	a, 20h ; ' '
		ld	(de), a
		inc	de
		djnz	DO013
HLDECRET:
		pop	de
		ret	

DESPSKP:
		ld	a, (de)
		cp	20h ; ' '
		ret	nz
		inc	de
		jr	DESPSKP

_PRBIN:
		ld	c, h
		call	PRBIN1
_PRBINL:
		ld	c, l
PRBIN1:
		ld	b, 8
DO014:
		xor	a
		rl	c
		rla	
		or	30h ; '0'
		call	_PRINT
		djnz	DO014
		ret	

_PRCHR:
		ld	a, h
		call	_PRINT_Q
		ld	a, l
		jp	_PRINT_Q

_PRSPC:
		ld	a, 20h ; ' '
PRSPC_1:
		inc	l
		dec	l
		ret	z
		ld	b, l
DO015:
		call	_PRINT
		djnz	DO015
		ret	

_PRTAB:
		ld	a, 1Ch ; _right_
		jr	PRSPC_1

_PRSTRING:
		ex	de, hl
		ld	a, e
		jr	PRSPC_1

_PRLEFT:
		ld	a, d
		or	e
		ret	z
		ex	de, hl
DO016:
		ld	a, (de)
		inc	de
		or	a
		ret	z
		call	_PRINT
		dec	hl
		ld	a, h
		or	l
		jr	nz, DO016
		ret	

_PRRIGHT:
		ld	a, d
		or	e
		ret	z
		push	hl
		call	ZSRCH
		dec	hl
		pop	bc
		push	hl
		or	a
		sbc	hl, bc
		call	CP16
		pop	hl
		jr	nc, .prightjmp1	;_PRDPCTSUB
		ld	d, b
		ld	e, c
		jp	_MSX
.prightjmp1
		sbc	hl, de
		ex	de, hl
		jp	_MSX
_PRDPCTSUB:
		cp	5
		jr	z, _HOME
		ld	b, 0
		ld	c, a
		ld	hl, CNTTBL
		add	hl, bc
		ld	a, (hl)
		jp	_PRINT
_HOME:
		push	hl
		ld	hl, 0
		call	SOS._LOC
		pop	hl
		ret	

CNTTBL:	db    0 ;  
		db  1Fh ;  
		db  1Eh ;  
		db  1Ch ;  
		db  1Dh ;  
		db    0 ;  
		db  0Ch ;  

INPUT:
		call	NOW
		jp	c, err35
INPUT0:
		ld	a, (ix+0)
		cp	22h ; '"'
		jr	nz, INPUT100
		inc	ix
		call	PRSTR
		call	IXP
		cp	3Bh ; ';'
		jp	nz, err13
		jr	INPUT1
INPUT100:
		ld	a, 3Fh ; '?'
		call	SOS._PRINT
INPUT1:
		call	SOS._CSR
		ld	a, l
		ld	(INPW), a
		call	ADRX
		push	hl
		call	_GETL
		ld	a, (de)
		cp	1Bh
		jr	z, INPUT3
		call	CHK
		push	ix
		ld	hl, (INPW)
		ld	h, 0
		add	hl, de
		push	hl
		pop	ix
		ld	de, CONVAREA
		push	de
		call	HENKAN1
		pop	ix
		ld	a, (ix+0)
		or	a
		jr	z, INPUT4
		call	SK
		pop	ix
		ex	de, hl
		pop	hl
		ld	(hl), e
		inc	hl
		ld	(hl), d
INPUT2:
		call	_more_
		ret	nz
		jr	INPUT0
INPUT4:
		pop	ix
INPUT3:
		pop	hl
		jr	INPUT2

POKE:
		call	SK_SK
POKE0:
		ld	(hl), e
		call	_more_
		ret	nz
		call	MORE
		jr	POKE0

WPOKE:
		call	SK_SK
WPOKE0:
		ld	(hl), e
		inc	hl
		ld	(hl), d
		call	_more_
		ret	nz
		call	MORE
		jr	WPOKE0

VSADR:
		ld	hl, (VSTKST)
		ret	
VEADR:
		ld	hl, (VSTKED)
		ret	

NEST:
		call	SK_K
		ld	a, l
		cp	5
		jp	nc, err14
		ld	hl, NESTTBL
		jp	TBLJMP0
NESTTBL:
		dw SUBNEST
		dw FORNEST
		dw REPNEST
		dw WHLNEST
		dw IFNEST

SUBNEST:
		ld	de, (SUBSP)
		ld	hl, SUBSTKED
NESTRET:
		or	a
		sbc	hl, de
		srl	l
		ret	
REPNEST:
		ld	de, (REPSP)
		ld	hl, REPSTKED
		jr	NESTRET
WHLNEST:
		ld	de, (WHLSP)
		ld	hl, WHLSTKED
		jr	NESTRET
IFNEST:
		ld	de, (IFSP)
		ld	hl, IFSTKED
		or	a
		sbc	hl, de
		ret	
FORNEST:
		push	iy
		pop	de
		ld	hl, FORSTKED
		or	a
		sbc	hl, de
		srl	l
		srl	l
		srl	l
		ret	

BYE		EQU	SOS.HOT
MON		EQU	SOS.MON
BOOT	EQU	SOS.BOOT

_EX_:
		call	SK_K
		ld	a, h
		ld	h, l
		ld	l, a
		ret	

HIGH:
		call	SK_K
		ld	l, h
		ld	h, 0
		ret	

LOW:
		call	SK_K
		ld	h, 0
		ret	

DIVHLC:
		push	bc
		xor	a
		ld	b, 10h
DO017:
		add	hl, hl
		rla	
		inc	l
		sub	c
		jr	nc, .divjmp1
		add	a, c
		dec	l
.divjmp1
		djnz	DO017
		pop	bc
		ret	

_DIV:
		push	af
		ld	a, d
		or	e
		jp	z, err28
		push	bc
		ld	b, d
		ld	c, e
		ex	de, hl
		ld	hl, 0
		ld	a, 10h
DO018:
		ex	de, hl
		add	hl, hl
		ex	de, hl
		adc	hl, hl
		inc	e
		sbc	hl, bc
		jr	nc, .divjmp2
		add	hl, bc
		dec	e
.divjmp2
		dec	a
		jr	nz, DO018
		ex	de, hl
		pop	bc
		pop	af
		ret	

MOD:
		call	SK_SK_K
		call	_DIV
		ex	de, hl
		ret	

MULH:
		call	SK_SK_K
		call	_MUL
		ex	de, hl
		ret	

SUM:
		call	SK_K
		ld	d, h
		ld	e, l
		inc	hl
		call	_MUL
		rr	e
		rr	h
		rr	l
		ret	

_SQU:
		ld	d, h
		ld	e, l

_MUL:
		push	af
		push	bc
		ld	b, h
		ld	c, l
		ld	hl, 0
		ld	a, 10h
DO019:
		add	hl, hl
		rl	e
		rl	d
		jr	nc, .muljmp1
		add	hl, bc
		jr	nc, .muljmp1
		inc	de
.muljmp1
		dec	a
		jr	nz, DO019
		pop	bc
		pop	af
		ret	

SQR:
		call	SK_K
		ld	de, 0
SQR_0:
		scf	
		sbc	hl, de
		jr	c, SQRRET
		sbc	hl, de
		jr	c, SQRRET
		inc	de
		jr	SQR_0
SQRRET:
		ex	de, hl
		ret	

LOG:
		call	SK_K
		ld	bc, 0Ah
LOG_0:
		call	DIVHLC
		ld	a, h
		or	l
		jr	z, LOG_1
		inc	b
		jr	LOG_0
LOG_1:
		ld	l, b
		ld	h, 0
		ret	

PARITY:
		call	SK_K
		xor	a
		call	PAR0
		ld	h, l
		call	PAR0
		ld	l, a
		ret	
PAR0:
		ld	b, 8
DO020:
		sla	h
		adc	a, 0
		djnz	DO020
		ret	

MIRROR:
		call	SK_K
		call	_MIRROR0
		ld	c, a
		ld	h, l
		call	_MIRROR0
		ld	h, a
		ld	l, c
		ret	
_MIRROR0:
		ld	b, 8
DO021:
		rl	h
		rra	
		djnz	DO021
		ret	

ZERO:
		call	SK_K
		ld	a, h
		or	l
		jr	nz, .zerojmp1
		inc	l
		ret	
.zerojmp1
		ld	hl, 0
		ret	

NOT:
		call	SK_K
_NOT:
		ld	a, h
		cpl	
		ld	h, a
		ld	a, l
		cpl	
		ld	l, a
		ret	
ROTL:
		call	SK_K
		jr	_ROTL
ROTLD:
		call	SK_K
		call	_ROTL
		call	_ROTL
		call	_ROTL
_ROTL:
		rlc	h
		rr	h
		rl	l
		rl	h
		ret	

ROTR:
		call	SK_K
		jr	_ROTR
ROTRD:
		call	SK_K
		call	_ROTR
		call	_ROTR
		call	_ROTR
_ROTR:
		rrc	l
		rl	l
		rr	h
		rr	l
		ret	

PEEK:
		call	SK_K
		ld	l, (hl)
		ld	h, 0
		ret	

WPEEK:
		call	SK_K
		ld	a, (hl)
		inc	hl
		ld	h, (hl)
		ld	l, a
		ret	

_LDIR_:
		call	SK_SK_SK
		ldir	
		ret	

_LDDR_:
		call	SK_SK_SK
		lddr	
		ret	

TRANS:
		call	SK_SK_SK
		call	CP16
		jr	c, .transjmp1
		ex	de, hl
.transjmp1
		push	hl
		ex	de, hl
		or	a
		sbc	hl, de
		ex	de, hl
		pop	hl
		push	bc
		push	de
		pop	bc
		pop	de
		call	CP16
		jr	nc, TRANS1
		add	hl, bc
		ex	de, hl
		add	hl, bc
		ex	de, hl
		inc	bc
		lddr	
		ret	
TRANS1:
		inc	bc
		ldir	
		ret	

RND:
		call	SK_K
		push	hl
		ld	hl, (LRND)
		call	_NOT
		ld	de, 383h
		call	_MUL
RND0:				; 
		ld	(LRND),	hl
		ld	a, h
		ld	h, l
		ld	l, a
		pop	de
		ld	a, d
		or	e
		ret	z
		jp	MOD+3

RANDOM:
		ld	hl, (LRND)
		ld	a, r
		xor	h
		ld	h, a
		ld	a, r
		xor	l
		ld	l, a
		push	hl
		jr	RND0

PRMODE:
		call	SK
		ld	a, l
		cp	3
		jr	c, PRMODE0
		xor	a
PRMODE0:
		push	hl
		add	a, a
		ld	c, a
		ld	b, 0
		ld	hl, PRNTBL
		add	hl, bc
		ld	a, (hl)
		inc	hl
		ld	h, (hl)
		ld	l, a
		ld	(_PRINT+1), hl
		pop	hl
		ret	
PRNTBL:	dw SOS._PRINT
		dw _PRINT0
		dw _LPRNT_

WIDTH:
		call	SK
		ld	a, l
		call	SOS.WIDCH
		jp	CLS

CHARA:
		call	SK_SK_K
		ld	h, e
		call	SOS._SCRN
		jp	c, err14
		ld	h, 0
		ld	l, a
		ret	

CURSOR:
LOCATE:
		call	SK_SK
		ld	h, e
		call	SOS._LOC
		jp	c, err14
		ret	

CURX:
		call	SOS._CSR
		ld	h, 0
		ret	
CURY:
		call	SOS._CSR
		jp	HIGH+3

GETKY:
		call	SOS._GETKY
		or	a
		jr	nz, _KEY
#IF exists IS_LSX
		; BDOS $06でキーなし → _KEYD(押下中キー)をフォールバック参照
		push	hl
		ld	a, (SOS.WBOOTBK+1)
		ld	h, a
		ld	l, $92		; _KEYDオフセット
		ld	a, (hl)
		pop	hl
#ENDIF
		jr	_KEY

FLASH:
		call	SOS._FLGET
		jr	_KEY

INKEY:
		call	SOS.INKEY

_KEY:
		ld	l, a
		ld	h, 0
		ret	

WAITSUB:
		ld	bc, 19000	; 4A38h
DO022:
		dec	bc
		ld	a, b
		or	c
		jr	nz, DO022
		ret	

WAIT:
		call	SK
DO023:
		call	WAITSUB
		call	SOS.BRKEY
		jp	z, BREAK
		dec	hl
		ld	a, h
		or	l
		jr	nz, DO023
		ret	

PAUSE:
		call	SOS.PAUSE
		adc	a, e
		ld	b, b
		ret	

INP:
		call	SK_K
		ld	b, h
		ld	c, l
		in	l, (c)
		ld	h, 0
		ret	

WINP:
		call	SK_K
_WINP:
		ld	b, h
		ld	c, l
		in	l, (c)
		inc	bc
		in	h, (c)
		ret	

_OUT_:
		call	SK_SK
		ld	b, h
		ld	c, l
		out	(c), e
		call	_more_
		ret	nz
		call	MORE
		jr	_OUT_+3

WOUT:
		call	SK_SK
		call	_WOUT
		call	_more_
		ret	nz
		inc	hl
		call	MORE
		jr	WOUT+3
_WOUT:
		ld	b, h
		ld	c, l
		out	(c), e
		inc	bc
		out	(c), d
		ret	

LINADR:
		call	SK_K
		ld	a, h
		or	l
		jr	nz, .linjmp1
		ld	hl, CONVAREA
		ret	
.linjmp1
		push	ix
		call	SRCHHL
		push	ix
		pop	hl
		pop	ix
		ret	nc
		jp	err26

NOW:
		push	de
		push	ix
		pop	hl
		ld	de, VARSTK
		call	CP16
		jr	c, NOW2
		push	ix
		ld	ix, (TEXTST)
		ld	b, h
		ld	c, l
NOW0:
		call	NXLINSUB+2
		jr	z, NOW00
		ld	(NOWADR), ix
		call	ESRCHP
		push	ix
		pop	hl
		sbc	hl, bc
		jr	c, NOW0
NOW00:
		ex	de, hl
		pop	ix
NOW1:
		pop	de
		ret	
NOW2:
		ld	hl, 0
		jr	NOW1

LEN:
		call	SK
		ld	c, 0
		call	IXP
		cp	29h ; ')'
		jr	z, _LEN
		call	CARE_Q+3
		push	hl
		call	SK_K
		ld	c, l
		pop	hl
_LEN:
		ld	a, c
		ld	bc, 0
		cpir	
		ld	hl, 0FFFFh
		or	a
		sbc	hl, bc
		ret	

_CP_:
		call	SK_SK_SK_K
_CP:
		call	_SAME
_CP0:
		ld	hl, 0
		ret	nz
		inc	l
		ret	

_SAME:
		push	bc
		push	de
		push	hl
DO024:
		ld	a, (de)
		cp	(hl)
		jr	nz, _SAME0
		inc	de
		inc	hl
		dec	bc
		ld	a, b
		or	c
		jr	nz, DO024
_SAME0:
		pop	hl
		pop	de
		pop	bc
		ret	

CP_:
		call	CP_0
		jr	_CP

INSTR:
		call	SK_SK_SK_K
_INSTR:
		push	hl
_INSTR0:
		call	_SAME
		jr	z, _INSTR1
		inc	hl
		inc	(hl)
		dec	(hl)
		jr	nz, _INSTR0
		pop	hl
		ld	hl, 0
		ret	
_INSTR1:
		pop	de
		sbc	hl, de
		inc	hl
		ret	
INSTR_D:
		call	CP_0
		jr	_INSTR

CP_0:
		call	SK__
		call	P_Q
		push	ix
		pop	de
		ld	bc, 0FFFFh
CP_1:
		call	D_QUES
		inc	bc
		cp	22h ; '"'
		jr	nz, CP_1
		jp	K_QUES

MEM_:
		call	SK__
		call	P_Q
MEM_D0:
		call	D_QUES
		cp	22h ; '"'
		jr	z, MEM_D1
		ld	(hl), a
		inc	hl
		jr	MEM_D0
MEM_D1:
		call	SMED
		ret	z
		cp	40h ; '@'
		jp	nz, err13
		inc	ix
		ld	(hl), 0
		ret	

STR_:
		call	SK_SK
		call	_STR_D
		jr	MEM_D1

HEX_:
		call	SK_SK
		call	_HEX_D
		jr	MEM_D1

BIN_:
		call	SK_SK
		call	_BIN_D
		jr	MEM_D1

VAL:
		call	SK_K
		ld	(VALW),	ix
		push	hl
		pop	ix
		call	SK
		ld	ix, (VALW)
		xor	a
		ld	(VALW+1), a
		ret	

_STR_D:
		ex	de, hl
		push	de
		call	HLDEC
		call	DESPSKP
		pop	hl
_STR0:
		or	a
		ret	z
		ld	(hl), a
		inc	de
		ld	a, (de)
		inc	hl
		jr	_STR0

_HEX_D:
		ld	a, d
		call	_HEX_D0
		ld	a, e
_HEX_D0:
		push	af
		rrca	
		rrca	
		rrca	
		rrca	
		call	_HEX_D1
		pop	af
_HEX_D1:
		call	SOS.ASC
		ld	(hl), a
		inc	hl
		ret	

_BIN_D:
		call	_BIN_D0
		ld	d, e
_BIN_D0:
		ld	b, 8
DO025:
		xor	a
		rl	d
		rla	
		or	30h ; '0'
		ld	(hl), a
		inc	hl
		djnz	DO025
		ret	

MIRROR_:
		call	SK
		push	hl
		call	ZSRCH
		ex	de, hl
		pop	hl
		dec	de
		call	CP16
		ret	z

_MIRROR_D0:
		dec	de
		ld	a, (de)
		ld	b, (hl)
		ld	(hl), a
		ld	a, b
		ld	(de), a
		inc	hl
		call	CP16
		ret	nc
		jr	_MIRROR_D0

LINPUT:
		call	SK
		call	_GETL
		ld	a, (de)
		cp	1Bh
		jp	z, BREAK
_LINPUT0:
		ld	(hl), a
		inc	hl
		or	a
		ret	z
		inc	de
		ld	a, (de)
		jr	_LINPUT0

KEY0:
		call	P_Q
		ld	de, (SOS._KBFAD)
KEY1:
		call	IXP
		or	a
		jp	z, err13
		cp	22h ; '"'
		jr	z, KEY2
		ld	(de), a
		inc	de
		jr	KEY1
KEY2:
		call	KEY3
		ld	(KEY0F), a
		ret	

SWAP:
		call	ADRX
		call	CARE_Q
		push	hl
		push	de
		call	ADRX
		pop	bc
		ld	(hl), c
		inc	hl
		ld	(hl), b
		pop	hl
SWAP0:
		ld	(hl), e
		inc	hl
		ld	(hl), d
		ret	

_INC_:
		call	ADRX
		inc	de
		call	SWAP0
		call	_more_
		ret	nz
		jr	_INC_

WINC:
		call	ADRX
		inc	de
		inc	de
		call	SWAP0
		call	_more_
		ret	nz
		jr	WINC

_DEC_:
		call	ADRX
		dec	de
		call	SWAP0
		call	_more_
		ret	nz
		jr	_DEC_

WDEC:
		call	ADRX
		dec	de
		dec	de
		call	SWAP0
		call	_more_
		ret	nz
		jr	WDEC

MAX:
		call	MANY
		call	_MAX
		ret	

MIN:
		call	MANY
		call	_MIN
		ret	

MANY:
		ld	b, 1
MANY0:
		push	bc
		call	SK
		pop	bc
		ex	(sp), hl
		push	hl
		call	IXP
		cp	29h ; ')'
		ret	z
		call	CARE_Q+3
		inc	b
		jr	MANY0

_MAX:
		ld	de, 0
DO026:
		pop	hl
		ex	(sp), hl
		call	CP16
		jr	c, .maxjmp1
		ex	de, hl
.maxjmp1
		djnz	DO026
		ex	de, hl
		ret	

_MIN:
		ld	de, 0FFFFh
DO027:
		pop	hl
		ex	(sp), hl
		call	CP16
		jr	nc, .minjmp1
		ex	de, hl
.minjmp1
		djnz	DO027
		ex	de, hl
		ret	

VSTOV_Q:
		ld	hl, (VARSP)
		ld	de, (VSTKST)
		call	CP16
		ret	nz
		jp	err31
VSTEMP_Q:
		ld	hl, (VARSP)
		ld	de, (VSTKED)
		call	CP16
		ret	nz
		jp	err30

TOP:
		call	VSTEMP_Q
		ld	e, (hl)
		inc	hl
		ld	d, (hl)
		ex	de, hl
		ret	

_POP_:
		call	TOP
		inc	de
		ld	(VARSP), de
		ret	

PULL:
		call	ADRX
		push	hl
		call	_POP_
		ex	de, hl
		pop	hl
		ld	(hl), e
		inc	hl
		ld	(hl), d
		call	_more_
		ret	nz
		jr	PULL

_PUSH_:
		call	SK
		push	hl
		call	VSTOV_Q
		pop	de
		dec	hl
		ld	(hl), d
		dec	hl
		ld	(hl), e
		ld	(VARSP), hl
		call	_more_
		ret	nz
		jr	_PUSH_

BITSUB:
		ex	de, hl
		ld	c, 8
		call	DIVHLC
		add	hl, de
		ex	de, hl
		ld	c, a
		ld	b, 0
		ld	hl, BITTBL
		add	hl, bc
		ld	a, (hl)
		ex	de, hl
		ret	

BITTBL:	db    1 ;  
		db    2 ;  
		db    4 ;  
		db    8 ;  
		db  10h ;  
		db  20h ;  
		db  40h ; @
		db  80h ; �

_BIT_:
		call	SK_SK_K
		call	BITSUB
		and	(hl)
		ld	hl, 0
		ret	z
		inc	l
		ret	

_SET_:
		call	SK_SK
		call	BITSUB
		or	(hl)
		ld	(hl), a
		ret	

RESET:
		call	SK_SK
		call	BITSUB
		cpl	
		and	(hl)
		ld	(hl), a
		ret	

BEEP:
		call	SMED
		jp	z, SOS.BELL
		call	SK
DO028:
		call	SOS.BELL
		call	WAITSUB
		call	SOS.BRKEY
		call	z, BREAK
		dec	hl
		ld	a, h
		or	l
		jr	nz, DO028
		ret	

_MSP:
		ld	hl, 0Ch
		add	hl, sp
		ret	

CODE:
		call	IXP
		cp	0FBh ; '�'
		jp	c, err14
		ld	l, a
		call	IXP
		ld	h, a
		jp	K_QUES

COMTBL:
		dw	RUN,CONT,LOAD,SAVE
		dw	APPEND,MERGE,LIST,AUTO
		dw	DELETE,TEXT,NEW,RECOVER
		dw	SEARCH,CHECK,RENUM,VLIST
		dw	VSTACK,ERMODE,EDIT,LCHR
SMTBL:
		dw	LET,FOR,TO,STEP
		dw	NEXT,REPEAT,UNTIL,WHILE
		dw	WEND,GOTO,GOSUB,RETURN
		dw	PROC,RETPROC,ON,IF

		dw	THEN,ELSE,ENDIF,RETFUNC
		dw	INPUT,LINPUT,PRMODE,PRINT
SMTBL_CLS:
		dw	CLS,CLR,STOP,END
		dw	_INC_,_DEC_,WINC,WDEC

		dw	SWAP,_PUSH_,PULL,_LDIR_
		dw	_LDDR_,TRANS,POKE,WPOKE
		dw	_OUT_,WOUT,_SET_,RESET
		dw	CURSOR,WIDTH,PAUSE,WAIT

		dw	MON,BYE,COLD,BOOT
		dw	STOFF,STON,BRKOFF,BRKON
		dw	BEEP,MEM_,STR_,BIN_
		dw	HEX_,MIRROR_,CHAIN,LOADM

		dw	SAVEM,DEVICE,LOCAL,LIMIT
		dw	_CALL_,CALL_A,RANDOM,KILL
		dw	RENAME,FSET,FRESET,READ
		dw	WRITE,KEY0,CLR,DIR

		dw	DIR,LOCATE,err35,err35
		dw	err35,err35,GRAPH,err35
		dw	err35,err35,err35,err35
		dw	err35,err35,err35,err35

		dw	err35,err35,err35,err35
		dw	err35,err35,err35,err35
#IF exists IS_LSX
		dw	PCGDEF_,TCOLOR_,SOUND_,err35
#ELSE
		dw	PCGDEF_,TCOLOR_,err35,err35
#ENDIF

FUNCTBL:
		dw	HIGH,LOW,_EX_,NOT
		dw	MIRROR,ROTL,ROTR,ROTLD
		dw	ROTRD,MOD,MULH,ZERO
		dw	SQU,SQR,SUM,LOG

		dw	MAX,MIN,RND,PARITY
		dw	_BIT_,PEEK,WPEEK,INP
		dw	WINP,INKEY,GETKY,FLASH
		dw	ADR,NOW,LINADR,TOP

		dw	_POP_,CODE,_MSP,SIZE
		dw	CURX,CURY,CHARA,NEST
		dw	FUNC,LEN,_CP_,CP_
		dw	INSTR,INSTR_D,USR,USR_A

		dw	TXBEGIN,TXEND,VSADR,VEADR
		dw	VAL,MAXAD,SOS.VER,DSK
		dw	TABLE,err35,err35,err35
		dw	err35,err35,err35,err35

		dw	err35,err35,COS,SIN
#IF exists IS_LSX
		dw	PAI,JOY,err35,err35
#ELSE
		dw	PAI,err35,err35,err35
#ENDIF

PRTTBL:
		dw	PRCHR,PRBIN,PRBINL,PRDEC5
		dw	PRHEX2,PRHEX4,PRLEFT,PRTAB
		dw	PRMSG,PRMSX,PRPN,PRRIGHT
		dw	PRSPC,PRSTRING,err35,err35

_s		EQU	$FF
_c		EQU	$FE
_f		EQU	$FD
_l		EQU	$FC
_p		EQU	$FB
no		EQU	$7F


SETTXE:
		call	TEXT0
		jp	SOS.MPRNT

EDLIN:
		ld	hl, (CONVAREA)
		inc	hl
		ld	a, h
		or	l
		ret	z
		dec	hl
		ld	(EDLNW), hl
		ret	

AUTO3:
		ld	hl, (EDLNW)
		add	hl, de
		ret	c
		inc	hl
		ld	a, h
		or	l
		dec	hl
		ret	nz
		scf	
		ret	

NLHOT:
		call	_LTNL
		jp	HOT

PIXC:
		call	PIX
		jp	CAP
PROCS:
		dec	hl
		ld	de, PROBUF+11
		ld	bc, 0Ch
		lddr	
		inc	de
		ex	de, hl
		push	hl
		ld	b, 6
		call	DO010
		pop	hl
		pop	de
		ld	bc, 0Ch
		ldir	
		ret	

_PRINT_Q:
		or	a
		ret	z
		jp	_PRINT

SQU:
		call	SK_K
		jp	_SQU

_LPRNT_:
		call	SOS.LPRNT
		ret	nc
LPTER:
		ld	a, 1
		jp	ERR
LPTER_Q0:
		ld	a, (SOS.LPSW)
		or	a
		jr	z, LPTER
		jp	SOS.LPTOF

KEY3:
		xor	a
		ld	(de), a
		ld	hl, (SOS._KBFAD)
		sbc	hl, de
		ret	z
		inc	a
		ret	

SIN:
		call	SK_SK_K
		jr	SIN_
COS_:
		ld	bc, 5Ah	; 'Z'
		add	hl, bc
SIN_:
		push	de
		bit	7, h
		jr	z, SIN0
		call	_MINUS
		ld	de, 0B4h
		add	hl, de
SIN0:
		ld	de, 168h
		call	CP16
		call	nc, MOD+3
		xor	a
		ld	c, a
		ld	de, 0B4h
		sbc	hl, de
		jr	nc, SIN1
		add	hl, de
		inc	c
SIN1:
		or	a
		ld	e, 5Ah ; 'Z'
		sbc	hl, de
		jr	nc, SIN2
		add	hl, de
		jr	SIN3
SIN2:
		ex	de, hl
		sbc	hl, de
SIN3:
		add	hl, hl
		ld	de, SINTBL
		add	hl, de
		ld	e, (hl)
		inc	hl
		ld	d, (hl)
		ex	de, hl
		pop	de
		call	_MUL
		ex	de, hl
		rl	d
		adc	hl, hl
		rl	d
		adc	hl, hl
		dec	c
		ret	z
		jp	_MINUS

COS:
		call	SK_SK_K
		jr	COS_

PAI:
		call	SK_K
		ld	de, 0C910h	; TODO C910 ok?
		call	_MUL
		ex	de, hl
		rl	d
		adc	hl, hl
		rl	d
		adc	hl, hl
		ret	

EDLNW:
		dw 0
PROBUF:
		ds 12

SINTBL:
		dw 0000h,011Eh,023Ch,0359h
		dw 0477h,0594h,06B1h,07CDh
		dw 08E8h,0A03h,0B1Dh,0C36h
		dw 0D4Eh,0E66h,0F7Ch,1090h
		dw 11A4h,12B6h,13C7h,14D6h
		dw 15E4h,16F0h,17FAh,1902h
		dw 1A08h,1B0Ch,1C0Eh,1D0Eh
		dw 1E0Ch,1F07h,2000h,20F6h
		dw 21EAh,22DBh,23CAh,24B5h
		dw 259Eh,2684h,2767h,2847h
		dw 2923h,29FDh,2AD3h,2BA6h
		dw 2C75h,2D41h,2E0Ah,2ECEh
		dw 2F90h,304Dh,3107h,31BDh
		dw 326Fh,331Dh,33C7h,346Dh
		dw 350Fh,35ADh,3646h,36DCh
		dw 376Dh,37FAh,3882h,3906h
		dw 3986h,3A01h,3A78h,3AEAh
		dw 3B57h,3BC0h,3C24h,3C83h
		dw 3CDEh,3D34h,3D85h,3DD2h
		dw 3E19h,3E5Ch,3E9Ah,3ED3h
		dw 3F07h,3F36h,3F61h,3F86h
		dw 3FA6h,3FC2h,3FD8h,3FEAh
		dw 3FF6h,3FFEh,4000h

GRAPHIC:
LINE_:
		ld	hl, DLINE
		push	hl
		call	NOTFL
		call	SETMODE
		push	hl
		inc	hl
		call	CONCT_Q
		call	PALA
		jp	c, err13
		ld	(hl), ssdone
		pop	hl
		xor	a
		sub	b
		ld	(hl), a

CLMAGIC:
		ex	(sp), ix
		push	iy
		ld	a, (MD)
		cp	3
		jp	z, PSET
		ld	(ix+1),	a
		ld	a, (COL)
		ld	c, a
		ld	b, 3
CLMAG:
		ld	a, 3
		sub	b
		ld	(ix+2),	a
		rr	c
		call	c, MAGIC_S
		djnz	CLMAG
MGRET:
		pop	iy
		pop	ix
		ret	

MAGIC1:
		ex	(sp), ix
		push	iy
		ld	(SPSP),	sp
		ld	sp, (SOS.STADR)
		call	magic
		ld	sp, (SPSP)
		jr	MGRET

MAGIC_S:
		push	ix
		push	bc
		call	magic
		pop	bc
		pop	ix
		ret	

PSET:
		ld	b, 3
		ld	a, (COL)
		ld	c, a
		ld	a, (FULWK)
		or	a
		jr	nz, MAGICF
PSET0:
		ld	a, 3
		sub	b
		ld	(ix+2),	a
		xor	a
		rr	c
		rl	a
		rl	a
		ld	(ix+1),	a
		call	MAGIC_S
		djnz	PSET0
		jr	MGRET

MAGICF:
		ld	l, (ix+4)
		ld	h, (ix+5)
		ld	(TILBF), hl
MAGFL:
		ld	a, 3
		sub	b
		ld	(ix+2),	a
		ld	hl, (TILBF)
		ld	de, 0
		rr	c
		jr	c, MAGF0
		ex	de, hl
MAGF0:
		call	TILSET
		call	MAGIC_S
		djnz	MAGFL
		ld	hl, (TILBF)
		call	TILSET
		jp	MGRET

TILSET:
		ld	(ix+4),	l
		ld	(ix+5),	h
		ld	(ix+6),	l
		ld	(ix+7),	h
		ret	

SETMODE:
		ld	de, 4
		add	hl, de
		push	hl
		ld	hl, (DFCM)
		ld	a, (ix+0)
		cp	5Bh ; '['
		call	z, SETM
		ld	(MD), hl
		pop	hl
		ret	
SETM:
		inc	ix
		call	SK_SK
		call	IXP
		cp	5Dh ; ']'
		jp	nz, err13
SETM0:
		ld	a, l
		cp	4
		jr	nc, err14G
		ld	a, e
		cp	8
		jr	nc, err14G
		ld	h, e
		ret	

COLOR:
		call	SK_SK
		call	SETM0
		ld	(DFCM),	hl
		ret	

PALA:
		call	SMED
		scf	
		ret	z
PALA1:
		push	bc
		call	PALASUB
		pop	bc
		dec	b
		call	SMED
		ret	z
		cp	2Dh ; '-'
		inc	ix
		jr	nz, err13G
		inc	b
		djnz	PALA1
		ret	
PALASUB:
		call	IXP
		cp	28h ; '('
		jr	nz, err13G
PALASUB0:
		ld	(PALAX+1), hl
		inc	hl
		inc	hl
		ld	(PALAY+1), hl
		call	SK_SK_K
PALAX:
		ld	(dmy), hl
		ld	(LPX), hl
		ex	de, hl
PALAY:
		ld	(dmy), hl
		ld	(LPY), hl
		ld	hl, (PALAY+1)
		inc	hl
		inc	hl
		ret	

PALC:
		ld	a, l
		cp	8
		ret	c
err14G:
		jp	err14

CLS_S:
		call	SMED
		jp	z, CLS
		call	SK
		ld	a, l
		cp	3
		jr	nc, err14G
		or	a
		jp	z, CLS
		dec	a
		jr	z, CLSG
		call	CLS
CLSG:
		ld	hl, DCLS
		push	hl
		jp	MAGIC1

SPLINE:
		ld	hl, DSPLN
		push	hl
		call	NOTFL
		call	SETMODE
SPLINE0:
		ld	b, 3
		call	PALA
MAGIC0_Q:
		jp	nc, CLMAGIC
err13G:
		jp	err13

BOX:
		ld	a, (ix+0)
		cp	40h ; '@'
		jp	z, BOXFULL
		ld	hl, DBOX
		push	hl
		call	NOTFL
		call	SETMODE
BOX0:
		ld	b, 2
		call	PALA
		jp	MAGIC0_Q

BOXFULL:
		ld	hl, DBOXF
		push	hl
		call	FUL
		inc	ix
		call	SETMODE
		ld	de, 4
		add	hl, de
		jp	BOX0

TRIANGLE:
		ld	hl, DTRGL
		push	hl
		call	FUL
		call	SETMODE
		ld	de, 4
		add	hl, de
		jp	SPLINE0

CIRCLE:
		ld	a, (ix+0)
		cp	40h ; '@'
		jr	nz, CIRCL
		inc	ix
CRCLFL:
		ld	hl, DCRCL
		push	hl
		call	FUL
		call	SETMODE
		ld	de, 4
		add	hl, de
		call	SMED
		jp	z, CLMAGIC
		call	PALASUB
		call	CARE_Q
		push	hl
		call	SK
		ex	de, hl
		pop	hl
		ld	(hl), e
		inc	hl
		ld	(hl), d
		jp	CLMAGIC

CIRCL:
		call	SETMODE
		call	IXP
		cp	28h ; '('
		jp	nz, err13
		call	SK_SK_K
		ld	(CRCLX+1), hl
		ld	(CRCLY+1), de
		call	CARE_Q
		call	SK
		ld	(CRCLRX+1), hl
		srl	h
		rr	l
		call	CIRPL
		ld	(CRCLRY+1), hl
		ld	hl, 0
		call	CIRPL
		ld	(CIRST+1), hl
		ld	hl, 168h
		call	CIRPL
		ld	(CIRED+1), hl
		ld	hl, 5
		call	CIRPL
		ld	(CIRSTP+1), hl
		call	NOTFL
		push	ix
		ld	a, 2
		ld	(DLINE+4), a
		ld	a, 0Fh
		ld	(DLINE+13), a
		ld	hl, (CIRST+1)
		ld	de, (CRCLRX+1)
		call	COS_
		ld	de, (CRCLX+1)
		add	hl, de
		ld	(DLINE+9), hl
		ld	hl, (CIRST+1)
		ld	de, (CRCLRY+1)
		call	SIN_
		ld	de, (CRCLY+1)
		add	hl, de
		ld	(DLINE+11), hl
		jr	CIRCL2
CIRCL1:
		ld	hl, (DLINE+11)
CIRCL2:
		ld	(DLINE+7), hl
		ld	hl, (DLINE+9)
		ld	(DLINE+5), hl
CIRST:
		ld	hl, dmy
CIRSTP:
		ld	de, dmy
		add	hl, de
		push	hl
		ld	(CIRST+1), hl
CRCLRX:
		ld	de, dmy
		call	COS_
CRCLX:
		ld	de, dmy
		add	hl, de
		ld	(DLINE+9), hl
		pop	hl
		push	hl
CRCLRY:
		ld	de, dmy
		call	SIN_
CRCLY:
		ld	de, dmy
		add	hl, de
		ld	(DLINE+11), hl
		call	CIRLIN
		pop	hl
CIRED:
		ld	de, dmy
		or	a
		sbc	hl, de
		jp	c, CIRCL1
		pop	ix
		ret	

CIRPL:
		call	SMED
		ret	z
		call	CARE_Q
		ld	a, (ix+0)
		cp	2Ch ; ','
		ret	z
		jp	SK
CIRLIN:
		ld	hl, DLINE
		push	hl
		jp	CLMAGIC

WINDOW:
		ld	hl, DWIDW
		push	hl
		inc	hl
		ld	b, 2
		call	PALA
		jp	nc, MAGIC1
		jp	err13

DOT:
		ld	hl, DDOT
		push	hl
		call	NOTFL
		call	SETMODE
		call	SMED
		jp	z, CLMAGIC
		inc	hl
		call	PALASUB
		jp	CLMAGIC

POINT:
		call	POINT0
		ld	a, (pdata)
		cp	0FFh
		jp	z, err14
		ld	l, a
		ld	h, 0
		ret	
POINT0:
		ld	hl, DPONT
		push	hl
		inc	hl
		call	PALASUB0
		jp	MAGIC1

PALET:
		ld	hl, DPALT
		push	hl
		inc	hl
		ld	b, 7
PALET0:
		push	bc
		push	hl
		call	SK__
		call	PALC
		pop	hl
		ld	(hl), a
		inc	hl
		pop	bc
		djnz	PALET0
		push	hl
		call	SK
		call	PALC
		pop	hl
		ld	(hl), a
		jp	MAGIC1

TILE:
		call	SK
		ld	(BOXFT),hl
		ld	(TRGLT),hl
		ld	(CRCLT),hl
		ld	(BOXFT+2),hl
		ld	(TRGLT+2),hl
		ld	(CRCLT+2),hl
		ret

CONCT_Q:
		ld	b, 0
		ld	a, (ix+0)
		cp	2Dh ; '-'
		ret	nz
		inc	ix
		dec	b
		ld	de, (LPX)
		ld	(hl), e
		inc	hl
		ld	(hl), d
		inc	hl
		ld	de, (LPY)
		ld	(hl), e
		inc	hl
		ld	(hl), d
		inc	hl
		ret	

GRAPH:
		ld	l, 1
		call	SMED
		call	nz, SK
		ld	a, l
		dec	a
		call	z, GON
		call	nz, GOFF
		ld	hl, GRAPHTBL
GRAPH0:
		ex	af, af'
		dec	(hl)
		inc	(hl)
		ret	z
		ex	af, af'
		ld	e, (hl)
		inc	hl
		ld	d, (hl)
		inc	hl
		call	GRAPH1
		jr	GRAPH0
GRAPH1:
		jr	z, GRAPH2
		inc	hl
		inc	hl
		ld	bc, err35
		ex	de, hl
		ld	(hl), c
		inc	hl
		ld	(hl), b
		ex	de, hl
		ret	
GRAPH2:
		ldi	
		ldi	
		ret	

GON:
		ld	hl, CLS_S
GONOFF:
		ld	(SMTBL_CLS), hl
		ret	
GOFF:
		ld	hl, CLS
		jr	GONOFF

_MAGIC_:
		call	SK
		push	hl
		jp	MAGIC1

NOTFL:
		xor	a
		db    1
FUL:
		ld	a, 1
FUI_Q:
		ld	(FULWK), a
		ret	

TILBF:		dw 0
FULWK:		db 0
LPX:		dw 0
LPY:		dw 0
DFCM:		dw 703h
MD:			db 0
COL:		db 0
DDOT:
		db	ssmode
		db	2,0
		db	ssline
		db	1
		dw	0,0
		db	ssdone
DLINE:
		db	ssmode
		db	2,0
		db	ssline
		db	1
		dw	0,0
		db	ssdone
		ds	50
DSPLN:
		db	ssmode
		db	2,0
		db	ssspline
		dw	0,0,0,0,0,0
		db	ssdone
DBOX:
		db	ssmode
		db	2,0
		db	ssbox
		dw	0,0,0,0
		db	ssdone
DTRGL:
		db	ssmode
		db	2,0
		db	sstrngl
TRGLT:
		dw	-1,-1
		dw	0,0,0,0,0,0
		db	ssdone
DBOXF:
		db	ssmode
		db	2,0
		db	ssboxf
BOXFT:
		dw	-1,-1
		dw	0,0,0,0
		db	ssdone
DCRCL:
		db	ssmode
		db	2,0
		db	sscircle
CRCLT:
		dw	-1,-1
		dw	0,0,0
		db	ssdone
DWIDW:
		db	sswindow
		dw	0,0,639,199
		db	ssdone
DPONT:
		db	sspoint
		dw	0,0
		db	ssdone
DPALT:
		db	sspalet
		db	0,1,2,3,4,5,6,7
		db	ssdone
DCLS:
		db	ssmode,2,2
		db	sscls
		db	ssmode,2,1
		db	sscls
		db	ssmode,2,0
		db	sscls
		db	ssdone

GRAPHTBL:
		dw	SMTBL+(5124h-4FDAh),POINT	; 511Ch→5124h: SMTBL拡張(+8bytes)に伴うFUNCTBLオフセット補正
		dw	SMTBL+(507eh-4FDAh),BOX
		dw	SMTBL+(5080h-4FDAh),CIRCLE
		dw	SMTBL+(5084h-4FDAh),DOT
		dw	SMTBL+(5088h-4FDAh),LINE_
		dw	SMTBL+(508ch-4FDAh),PALET
		dw	SMTBL+(508eh-4FDAh),SPLINE
		dw	SMTBL+(5090h-4FDAh),WINDOW
		dw	SMTBL+(50a2h-4FDAh),TILE
		dw	SMTBL+(50a4h-4FDAh),TRIANGLE
		dw	SMTBL+(50a6h-4FDAh),_MAGIC_
		dw	SMTBL+(50a8h-4FDAh),COLOR
		dw	dmy,dmy
		dw	dmy,dmy
		db	0
; 5783H
GRAPHEND:

; PCGDEF CH,ADDR
PCGDEF_:
		call	SK_SK
		jp	PCGDEF

; TCOLOR VAL
TCOLOR_:
		call	SK
		ld	a, l
		ld	(SOS.AT_COLORF), a
#IF exists IS_LSX
		; LSX-Dodgers: OS作業領域の_COLORFにも書き込む
		push	hl
		ld	a, (SOS.WBOOTBK+1)
		ld	h, a
		ld	l, $96		; _COLORFオフセット
		ld	a, (SOS.AT_COLORF)
		ld	(hl), a
		pop	hl
#ENDIF
		ret

#IF exists IS_LSX
; ====================================================================================================
; SOUND n コマンド
;   SOUND 0         ... ドライバ無効化・終了
;   SOUND 1         ... ドライバ初期化・有効化
;   SOUND 2,addr    ... BGM再生
;   SOUND 3         ... BGM停止
;   SOUND 4         ... BGM一時停止
;   SOUND 5         ... BGM再開
;   SOUND 6,addr    ... SFXテーブル初期化
;   SOUND 7,n,ch    ... SFX再生 (n=SFX番号, ch=チャンネル0-2)
;   SOUND 8,ch      ... SFX停止 (ch=チャンネル0-2)
; ====================================================================================================
SOUND_:
		call	SK		; 式評価 → HL, L=サブコマンド番号
		ld	a, l
		or	a
		jp	z, .SOFF	; SOUND 0 → 無効化
		dec	a
		jr	z, .SON		; SOUND 1 → 有効化
		; SOUND 2-8はSNDFLG!=0(SOUND 1済み)が必要
		push	af
		ld	a, (SOS.SNDFLG)
		or	a
		jr	nz, .SNDOK
		pop	af
		jp	err13		; SOUND未初期化エラー
.SNDOK
		pop	af
		dec	a
		jp	z, .SBGM	; SOUND 2,addr → BGM再生
		dec	a
		jp	z, .SBGMSTOP	; SOUND 3 → BGM停止
		dec	a
		jp	z, .SBGMPAUSE	; SOUND 4 → BGM一時停止
		dec	a
		jp	z, .SBGMRESUME	; SOUND 5 → BGM再開
		dec	a
		jp	z, .SSFXINIT	; SOUND 6,addr → SFXテーブル初期化
		dec	a
		jp	z, .SSFXPLAY	; SOUND 7,n,ch → SFX再生
		dec	a
		jp	z, .SSFXSTOP	; SOUND 8,ch → SFX停止
		jp	err13		; パラメータエラー

.SON
		ld	a, (SOS.SNDFLG)
		or	a
		jr	z, .SON_FIRST
		; 二重初期化
		ld	a, (SOS.SNDCTC)
		or	a
		jr	nz, .SON_REINIT_CTC
		; 非CTC: 完全再初期化（PSG_PROCのNOP化をやり直す必要あり）
		call	SND_BGMStop		; BGMStop
		xor	a
		ld	(SOS.SNDFLG), a		; フラグクリアして初回扱い
		jr	.SON_FIRST
.SON_REINIT_CTC
		; CTC: ワーククリアのみ（CTC割り込みはそのまま）
		jp	SND_BGMStop		; BGMStop → LINED戻り
.SON_FIRST
		; WBOOTBKからOSページを取得し、CTC情報を計算
		ld	a, (SOS.WBOOTBK+1)	; OSページ高位バイト
		ld	h, a
		ld	l, $8C			; _CTCオフセット
		ld	c, (hl)
		inc	hl
		ld	b, (hl)			; BC = CTC I/Oポート (0=CTC無し)
		ld	(SND_CTC_PORT), bc	; SND_CTC_PORT

		ld	a, b
		or	c
		jr	z, .SON_NOCTC

		; CTC有り: CTC0アドレスも計算
		ld	a, (SOS.WBOOTBK+1)
		ld	h, a
		ld	l, $C0			; CTC0オフセット
		ld	(SND_CTCVEC), hl	; SND_CTCVEC
		ld	a, $FF
		ld	(SOS.SNDCTC), a
		ld	l, 1			; CTC割り込みモード
		jr	.SON_INIT

.SON_NOCTC
		ld	hl, 0
		ld	(SND_CTCVEC), hl	; SND_CTCVEC = 0
		xor	a
		ld	(SOS.SNDCTC), a
		ld	l, 0			; 非CTCモード

.SON_INIT
		call	SND_Init
		ld	a, $FF
		ld	(SOS.SNDFLG), a
		xor	a
		ld	(SOS.VSYNC_PREV), a
		ret

.SOFF
		ld	a, (SOS.SNDFLG)
		or	a
		ret	z			; 未初期化時はno-op
		ld	a, (SOS.SNDCTC)
		or	a
		jr	z, .SOFF_NOCTC
		call	SND_PSG_END		; PSG_END (CTC解除+停止)
		jr	.SOFF_DONE
.SOFF_NOCTC
		call	SND_BGMStop		; BGMStop
.SOFF_DONE
		xor	a
		ld	(SOS.SNDFLG), a
		ret

.SBGM
		call	CARE_Q
		call	SK			; HL=BGMデータアドレス
		jp	SND_BGMPlay		; BGMPlay

.SBGMSTOP
		jp	SND_BGMStop		; BGMStop

.SBGMPAUSE
		jp	SND_BGMPause		; BGMPause

.SBGMRESUME
		jp	SND_BGMResume		; BGMResume

.SSFXINIT
		call	CARE_Q
		call	SK			; HL=SFXテーブルアドレス
		jp	SND_SFXInit		; SFXInit

.SSFXPLAY
		call	CARE_Q
		call	SK			; HL, L=SFX番号
		push	hl
		call	CARE_Q
		call	SK			; HL, L=チャンネル番号
		pop	de			; D=不要, E=SFX番号(元のL)
		ld	h, l			; H=チャンネル番号
		ld	l, e			; L=SFX番号
		jp	SND_SFXPlay		; SFXPlay (L=SFX番号, H=チャンネル)

.SSFXSTOP
		call	CARE_Q
		call	SK			; HL, L=チャンネル番号(0-2)
		jp	SND_SFXStop		; SFXStop

; ====================================================================================================
; JOY(n) - ジョイスティック入力 (n=0:ポート1, n=1:ポート2)
;   DI/EI で囲み、BGM再生中でもPSGレジスタ14/15を安全に読み取る
; ====================================================================================================
JOY:
		call	SK_K
		ld	a, l
		cp	2
		jp	nc, err13	; 0/1以外はエラー
		di
		add	a, $0E		; $0E=R14(joy1), $0F=R15(joy2)
		ld	bc, $1C00
		out	(c), a
		dec	b		; BC=$1B00
		in	l, (c)
		ld	h, c		; H=0 (C=$00)
		ei
		ret

; ====================================================================================================
; SNDPOLL - VSYNCポーリングによるサウンドドライバ呼び出し
;   LINED (各文実行後のBRKEYチェック直後) から呼ばれる
;   非CTC環境でのみ VSYNC立ち上がりエッジを検出して PSG_PROC を呼ぶ
; ====================================================================================================
SNDPOLL:
		ld	a, (SOS.SNDFLG)
		or	a
		ret	z			; SOUND無効なら即リターン
		ld	a, (SOS.SNDCTC)
		or	a
		ret	nz			; CTC使用中なら割り込みに任せる

		; VSYNC edge detection (port $1A01 bit 7)
		ld	bc, $1A01
		in	a, (c)
		and	$80
		ld	b, a			; B = 現在のVSYNC状態 ($80 or $00)
		ld	a, (SOS.VSYNC_PREV)
		ld	c, a			; C = 前回の状態
		ld	a, b
		ld	(SOS.VSYNC_PREV), a	; 状態を保存
		xor	c			; 前回と異なる？
		ret	z			; 変化なし → スキップ
		bit	7, b
		ret	z			; VSYNC期間終了(立ち下がり) → スキップ
		; VSYNC立ち上がりエッジ → PSG_PROC呼出し
		jp	SND_PSG_PROC		; PSG_PROC
#ENDIF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LSX-Dodgers用のS-OS互換コール群
#IF !exists BEGIN_SOS
include	"SOSCALL.ASM"
include	"SOSDISK.ASM"
#ENDIF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

include	"pcgdef.asm"

	;ds	83

VARNAME:
	db	"AFBCDEHLVS"

;VARVAL	EQU	$58A1
;VARSP	EQU	VARVAL+60
;VARVAL2	EQU	VARSP+2

	ds	193,0
VARVAL:
	ds	60,0
VARSP:
	ds	194,0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LSX-Dodgers用のS-OS互換ワーク群
#IF !exists BEGIN_SOS
include	"SOSWORK.ASM"
#ENDIF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;		org	599fh
LRND:
		dw 0
PRWK:
		ds	6
INPW:
		db 0
SPSP:
		dw 0
SYSSTK:
		dw 0
STKTP:
		dw 0
VSTKST:
		dw 0
VSTKED:
		dw 0
PROCVAR:
		dw 0
SUBSP:
		dw 0
REPSP:
		dw 0
WHLSP:
		dw 0
IFSP:
		dw 0
STOPF:
		db 0
ERFLG:
		db 0
BRK:
		dw 0
NOWADR:
		dw 0
MEMAX:
		dw 0
TEXTST:
		dw 0
TEXTED:
		dw 0
RCVDT:
		dw 0
LDWK:
		ds	5
CHDT:
		dw 0
LINE:
		db 0
GOTOW:
		db 0
GOTIX:
		dw 0
VALW:
		ds 2
KEY0F:
		db 0
AUTOW:
		db 0
AUTOW2:
		db 0
LISTW:
		db 0
PRCNT:
		db 0
IFSTK:
		ds	16
IFSTKED:
REPSTK:
		ds	32
REPSTKED:
WHLSTK:
		ds	32
WHLSTKED:
FORSTK:
		ds	128
FORSTKED:
SUBSTK:
		ds	254
SUBSTKED:
NOAREA:
		ds	254
CONVAREA:
		ds	88
VARSTK:
		ds	$500	; $6200-$5d00
VARSTKED:
STKTOP:
		ds	$100
STKED:
	; STKED == RSVTBL である必要がある
	; org	$6300
RSVTBL:
	db	_c,no+08,"AUTO",0
	db	_f,no+29,"ADR(",0
	db	_l,no+01," AND ",0
	db	_c,no+05,"APPEND",0
	db	_s,no+57,"BEEP ",0
	db	_p,no+02,"BIN(",0
	db	_s,no+60,"BIN@ ",0
	db	_p,no+03,"BINL(",0
	db	_f,no+21,"BIT(",0
	db	_s,no+64,"BLOAD ",0
	db	_s,no+52,"BOOT",0
	db	_s,no+83,"BOX ",0
	db	_s,no+55,"BROFF",0
	db	_s,no+56,"BRON",0
	db	_s,no+65,"BSAVE ",0
	db	_s,no+50,"BYE",0
	db	_c,no+02,"CONT",0
	db	_s,no+70,"CALL@ ",0
	db	_s,no+69,"CALL ",0
	db	_s,no+63,"CHAIN ",0
	db	_f,no+39,"CHARA(",0
	db	_c,no+14,"CHECK",0
	db	_p,no+01,"CHR$(",0
	db	_s,no+84,"CIRCLE ",0
	db	_s,no+26,"CLR",0
	db	_s,no+79,"CLEAR",0
	db	_s,no+25,"CLS",0
	db	_f,no+34,"CODE(",0
	db	_s,no+51,"COLD",0
	db	_f,no+43,"CP(",0
	db	_f,no+44,"CP$(",0
	db	_s,no+85,"@PAINT ",0
	db	_s,no+45,"CURSOR ",0
	db	_f,no+37,"CURX",0
	db	_f,no+38,"CURY",0
	db	_s,no+81,"DIR ",0
	db	_p,no+04,"DECI(",0
	db	_s,no+30,"DEC ",0
	db	_c,no+09,"DELETE",0
	db	_s,no+66,"DEVICE ",0
	db	_s,no+76,"DEVI ",0
	db	_s,no+77,"DEVO ",0
	db	_s,no+86,"DOT ",0
	db	_f,no+56,"DSK",0
	db	_c,no+19,"EDIT",0
	db	_s,no+18," ELSE ",0
	db	_s,no+19,"END IF",0
	db	_s,no+28,"END",0
	db	_c,no+18,"ERMODE",0
	db	_f,no+03,"EX(",0
	db	_s,no+02,"FOR ",0
	db	_s,no+80,"FILES ",0
	db	_f,no+28,"FLASH",0
	db	_s,no+75,"FRESET ",0
	db	_s,no+74,"FSET ",0
	db	_f,no+41,"FUNC(",0
	db	_f,no+59,"FN^A(",0
	db	_f,no+60,"FN^B(",0
	db	_f,no+61,"FN^C(",0
	db	_f,no+62,"FN^D(",0
	db	_f,no+63,"FN^E(",0
	db	_f,no+64,"FN^F(",0
	db	_f,no+65,"FN^G(",0
	db	_f,no+66,"FN^H(",0

	db	_s,no+10," GOTO ",0
	db	_s,no+11," GOSUB ",0
	db	_f,no+27,"GET",0
	db	_s,no+87,"GRAPH ",0

	db	_p,no+05,"HEX2(",0
	db	_p,no+06,"HEX4(",0
	db	_s,no+61,"HEX@ ",0
	db	_f,no+01,"HIGH(",0
	db	_s,no+21,"INPUT ",0
	db	_s,no+16,"IF ",0
	db	_s,no+29,"INC ",0
	db	_f,no+26,"INKEY",0
	db	_f,no+24,"INP(",0
	db	_f,no+45,"INSTR(",0
	db	_f,no+46,"INSTR$(",0

	db	_s,no+78,"KEY0 ",0
	db	_s,no+72,"KILL ",0

	db	_c,no+07,"LIST",0
	db	_s,no+36,"LDIR ",0
	db	_s,no+37,"LDDR ",0
	db	_f,no+42,"LEN(",0
	db	_p,no+07,"LEFT$(",0
	db	_s,no+01,"LET ",0
	db	_s,no+68,"LIMIT ",0
	db	_f,no+31,"LINADR(",0
	db	_s,no+22,"LINPUT ",0
	db	_s,no+88,"LINE ",0
	db	_c,no+20,"LMODE",0
	db	_c,no+03,"LOAD",0
	db	_s,no+82,"LOCATE ",0
	db	_s,no+67,"LOCAL ",0
	db	_f,no+16,"LOG(",0
	db	_f,no+02,"LOW(",0

	db	_c,no+06,"MERGE ",0
	db	_f,no+17,"MAX(",0
	db	_f,no+54,"MAX",0
	db	_s,no+58,"MEM ",0
	db	_f,no+18,"MIN(",0
	db	_f,no+05,"MIRROR(",0
	db	_s,no+62,"MIRROR@ ",0
	db	_f,no+10,"MOD(",0
	db	_s,no+49,"MON",0
	db	_p,no+09,"MSG(",0
	db	_f,no+35,"MSP",0
	db	_p,no+10,"MSX(",0
	db	_f,no+11,"MULH(",0

	db	_s,no+05,"NEXT ",0
	db	_f,no+40,"NEST(",0
	db	_c,no+11,"NEW",0
	db	_f,no+04,"NOT(",0
	db	_f,no+30,"NOW",0

	db	_s,no+41,"OUT ",0
	db	_s,no+15,"ON ",0
	db	_l,no+02," OR ",0

	db	_s,no+24,"PRINT ",0
	db	_s,no+47,"PAUSE",0
	db	_f,no+20,"PARITY(",0
	db	_s,no+89,"@AINT ",0
	db	_s,no+90,"PALET ",0
	db	_f,no+22,"PEEK(",0
	db	_p,no+11,"PN(",0
	db	_s,no+39,"POKE ",0
	db	_f,no+33,"POP",0
	db	_f,no+58,"POINT(",0
	db	_p,no+15,"PR^A(",0
	db	_p,no+16,"PR^B(",0
	db	_s,no+23,"PRMODE ",0
	db	_s,no+13,"PROC ",0

	db	_s,no+35,"PULL ",0
	db	_s,no+34,"PUSH ",0

	db	_c,no+01,"RUN",0
	db	_s,no+71,"RANDOMIZE",0
	db	_s,no+12," RETURN ",0
	db	_c,no+12,"RECOVER",0
	db	_c,no+15,"RENUM",0
	db	_s,no+73,"RENAME ",0
	db	_s,no+06,"REPEAT",0
	db	_s,no+44,"RESET ",0
	db	_s,no+20,"RET FUNC ",0
	db	_s,no+14,"RET PROC ",0
	db	_p,no+12,"RIGHT$(",0
	db	_f,no+19,"RND(",0
	db	_f,no+06,"ROTL(",0
	db	_f,no+07,"ROTR(",0
	db	_f,no+08,"ROTLD(",0
	db	_f,no+09,"ROTRD(",0

	db	_s,no+04," STEP ",0
	db	_c,no+04,"SAVE",0
	db	_c,no+13,"SEARCH",0
	db	_s,no+43,"SET ",0
	db	_f,no+36,"SIZE",0
	db	_p,no+13,"SPC(",0
	db	_s,no+91,"SPLINE ",0
	db	_f,no+14,"SQR(",0
	db	_f,no+13,"SQU(",0
	db	_s,no+27,"STOP",0
	db	_s,no+53,"STOFF",0
	db	_s,no+54,"STON",0
	db	_p,no+14,"STRING(",0
	db	_s,no+59,"STR ",0
	db	_f,no+15,"SUM(",0
	db	_s,no+33,"SWAP ",0

	db	_s,no+17," THEN ",0
	db	_f,no+57,"TABLE(",0
	db	_p,no+08,"TAB(",0
	db	_c,no+10,"TEXT",0
	db	_f,no+32,"TOP",0
	db	_s,no+03," TO ",0
	db	_s,no+38,"TRANS ",0
	db	_f,no+49,"TXBEGIN",0
	db	_f,no+50,"TXEND",0
	db	_s,no+07,"UNTIL ",0
	db	_f,no+47,"USR(",0
	db	_f,no+48,"USR@(",0
	db	_s,no+93,"USR^A ",0
	db	_s,no+94,"USR^B ",0
	db	_s,no+95,"USR^C ",0
	db	_s,no+96,"USR^D ",0
	db	_s,no+97,"USR^E ",0
	db	_s,no+98,"USR^F ",0
	db	_s,no+99,"USR^G ",0
	db	_s,no+100,"USR^H ",0

	db	_c,no+16,"VLIST",0
	db	_f,no+53,"VAL(",0
	db	_f,no+55,"VERSION",0
	db	_f,no+52,"VEADR",0
	db	_f,no+51,"VSADR",0
	db	_c,no+17,"VSTACK",0

	db	_s,no+08,"WHILE ",0
	db	_s,no+48,"WAIT ",0
	db	_s,no+32,"WDEC ",0
	db	_s,no+09,"WEND",0
	db	_s,no+46,"WIDTH ",0
	db	_s,no+31,"WINC ",0
	db	_f,no+25,"WINP(",0
	db	_s,no+92,"WINDOW ",0
	db	_s,no+42,"WOUT ",0
	db	_f,no+23,"WPEEK(",0
	db	_s,no+40,"WPOKE ",0

	db	_l,no+03," XOR ",0

	db	_f,no+12,"ZERO(",0
	db	_f,no+67,"COS(",0
	db	_f,no+68,"SIN(",0
	db	_f,no+69,"PAI(",0
	db	_s,no+101,"TILE ",0
	db	_s,no+102,"TRIANGLE ",0
	db	_s,no+103,"MAGIC ",0
	db	_s,no+104,"COLOR ",0
	db	_s,no+105,"PCGDEF ",0
	db	_s,no+106,"TCOLOR ",0
#IF exists IS_LSX
	db	_s,no+107,"SOUND ",0
	db	_f,no+70,"JOY(",0
#ENDIF

	db	0
	ds	72,0
RSVEND:
	ds	3,0
;	org	$6a00
TEXTAREA:
	.end
