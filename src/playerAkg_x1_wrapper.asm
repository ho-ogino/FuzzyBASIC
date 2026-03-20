; ====================================================================================================
; ArkosTracker AKG Player - X1 wrapper for FuzzyBASIC
;
; Builds with RASM: rasm playerAkg_x1_wrapper.asm -o PSGDRV_AKG -s
;
; Jump table layout:
;   +$00  JP Init         (L=mode: 0=non-CTC, 1=CTC)
;   +$03  JP BGMPlay      (HL=music data address)
;   +$06  JP BGMStop
;   +$09  JP BGMPause
;   +$0C  JP BGMResume
;   +$0F  JP SFXInit      (HL=SFX table address)
;   +$12  JP SFXPlay      (L=SFX number, H=channel)
;   +$15  JP SFXStop      (L=channel 0-2)
;   +$18  JP PSG_PROC     (polling: RET or NOP->fallthrough)
;   +$1B  JP PSG_END      (CTC teardown + stop)
;   +$1E  SND_CTC_PORT    (DW, caller writes)
;   +$20  SND_CTCVEC      (DW, caller writes)
;
; licence: MIT License (ArkosTracker player by Targhan/Arkos)
; ====================================================================================================

        org #c300

; ----------------------------------------------------------------------------------------------------
; Jump table
; ----------------------------------------------------------------------------------------------------
        jp AKG_X1_Init          ; +$00
        jp AKG_X1_BGMPlay       ; +$03
        jp AKG_X1_BGMStop       ; +$06
        jp AKG_X1_BGMPause      ; +$09
        jp AKG_X1_BGMResume     ; +$0C
        jp AKG_X1_SFXInit       ; +$0F
        jp AKG_X1_SFXPlay       ; +$12
        jp AKG_X1_SFXStop       ; +$15
        jp AKG_X1_PSG_PROC      ; +$18
        jp AKG_X1_PSG_END       ; +$1B

; ----------------------------------------------------------------------------------------------------
; Parameter area (caller writes before Init)
; ----------------------------------------------------------------------------------------------------
AKG_X1_SND_CTC_PORT:   dw 0    ; +$1E
AKG_X1_SND_CTCVEC:     dw 0    ; +$20


; ====================================================================================================
; Init (L=mode: 0=non-CTC, 1=CTC)
; ====================================================================================================
AKG_X1_Init:
        di
        push af
        push bc
        push de
        push hl
        push ix
        push iy

        ; L = mode: 0=non-CTC, 1=CTC
        ld a,l
        or a
        jp z,AKG_X1_Init_NoCTC

        ; CTC present?
        ld bc,(AKG_X1_SND_CTC_PORT)
        ld a,c
        or b
        jp z,AKG_X1_Init_NoCTC

        ; Program CTC channel 1 (~61Hz)
        ld bc,(AKG_X1_SND_CTC_PORT)
        dec c           ; Channel 1
        ld a,#a7        ; Reset, prescaler 256, interrupt enabled
        out (c),a
        ld a,0          ; Time constant 256
        out (c),a

        ; Hook CTC1 interrupt vector -> AKG_X1_PlayISR
        ld hl,(AKG_X1_SND_CTCVEC)
        inc l
        inc l           ; CTC1 entry
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (AKG_X1_CTC_Backup),bc      ; Save original vector
        dec hl
        ld bc,AKG_X1_PlayISR
        ld (hl),c
        inc hl
        ld (hl),b

        ; Ensure PSG_PROC is RET (in case previously NOP'd by non-CTC init)
        ld a,#c9        ; RET opcode
        ld (AKG_X1_PSG_PROC),a

        jr AKG_X1_Init_Done

AKG_X1_Init_NoCTC:
        ; NOP PSG_PROC -> falls through to AKG_X1_PlayISR
        ld hl,AKG_X1_PSG_PROC
        xor a
        ld (hl),a       ; NOP

AKG_X1_Init_Done:
        xor a
        ld (AKG_X1_Paused),a
        ld (AKG_X1_Active),a   ; Not yet active until BGMPlay

        pop iy
        pop ix
        pop hl
        pop de
        pop bc
        pop af
        ei
        ret


; ====================================================================================================
; BGMPlay (HL=music data address)
; ====================================================================================================
AKG_X1_BGMPlay:
        xor a
        ld (AKG_X1_Active),a    ; Inactive during init (prevent ISR from calling Play)
        ld (AKG_X1_Paused),a    ; Clear pause flag
        push ix
        push iy
        xor a                   ; Subsong 0
        call PLY_AKG_Init
        pop iy
        pop ix
        ld a,1
        ld (AKG_X1_Active),a    ; Now safe to play
        ret


; ====================================================================================================
; BGMStop
; ====================================================================================================
AKG_X1_BGMStop:
        xor a
        ld (AKG_X1_Active),a    ; Mark music as inactive
        ld (AKG_X1_Paused),a    ; Clear pause flag
        jp PLY_AKG_Stop


; ====================================================================================================
; BGMPause
; ====================================================================================================
AKG_X1_BGMPause:
        ld a,(AKG_X1_Paused)
        or a
        ret nz          ; Already paused
        ld a,1
        ld (AKG_X1_Paused),a
        jp PLY_AKG_Stop ; Mute all channels


; ====================================================================================================
; BGMResume
; ====================================================================================================
AKG_X1_BGMResume:
        ld a,(AKG_X1_Paused)
        or a
        ret z           ; Not paused
        xor a
        ld (AKG_X1_Paused),a
        ret


; ====================================================================================================
; SFXInit (HL=SFX table address)
; ====================================================================================================
AKG_X1_SFXInit:
        jp PLY_AKG_InitSoundEffects


; ====================================================================================================
; SFXPlay (L=SFX number 1-based, H=channel 0-2)
; ====================================================================================================
AKG_X1_SFXPlay:
        ld a,l          ; SFX number
        ld c,h          ; Channel
        ld b,0          ; Full volume (inverted=0)
        jp PLY_AKG_PlaySoundEffect


; ====================================================================================================
; SFXStop (L=channel 0-2)
; ====================================================================================================
AKG_X1_SFXStop:
        ld a,l          ; Channel number
        jp PLY_AKG_StopSoundEffectFromChannel


; ====================================================================================================
; PSG_PROC - Polling entry point
; ====================================================================================================
AKG_X1_PSG_PROC:
        ret
; ====================================================================================================
; PlayISR - Actual play routine (CTC interrupt or PSG_PROC fallthrough)
; ====================================================================================================
AKG_X1_PlayISR:
        di
        push af
        ld a,(AKG_X1_Active)
        or a
        jr z,AKG_X1_PlayISR_Skip
        ld a,(AKG_X1_Paused)
        or a
        jr nz,AKG_X1_PlayISR_Skip
        push hl
        push de
        push bc
        push ix
        push iy
        ex af,af'
        push af                 ; Save AF'
        exx
        push hl                 ; Save HL'
        push de                 ; Save DE'
        push bc                 ; Save BC'
        call PLY_AKG_Play
        pop bc                  ; Restore BC'
        pop de                  ; Restore DE'
        pop hl                  ; Restore HL'
        exx
        pop af                  ; Restore AF'
        ex af,af'
        pop iy
        pop ix
        pop bc
        pop de
        pop hl
AKG_X1_PlayISR_Skip:
        pop af
        ei
        reti


; ====================================================================================================
; PSG_END - CTC teardown + stop
; ====================================================================================================
AKG_X1_PSG_END:
        call PLY_AKG_Stop

        ; CTC present?
        ld hl,(AKG_X1_SND_CTC_PORT)
        ld a,l
        or h
        ret z           ; No CTC -> done

        ; Stop CTC1
        ld hl,(AKG_X1_SND_CTC_PORT)
        dec l
        ld c,l
        ld b,h
        ld a,3
        out (c),a

        ; Restore original CTC1 vector
        ld hl,(AKG_X1_SND_CTCVEC)
        inc l
        inc l
        ld de,(AKG_X1_CTC_Backup)
        ld (hl),e
        inc hl
        ld (hl),d
        ret


; ====================================================================================================
; Work area
; ====================================================================================================
AKG_X1_CTC_Backup:     dw 0    ; Original CTC1 vector
AKG_X1_Paused:         db 0    ; Pause flag
AKG_X1_Active:         db 0    ; Music active flag (0=not started, 1=playing)


; ====================================================================================================
; AKG Player configuration
; ====================================================================================================
        PLY_AKG_HARDWARE_X1 = 1
        PLY_AKG_MANAGE_SOUND_EFFECTS = 1

        include "PlayerAkg_x1.asm"

; ====================================================================================================
AKG_X1_End:
