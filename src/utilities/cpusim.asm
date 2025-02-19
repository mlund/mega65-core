	!to "src/utilities/cpusim.prg", plain
foop:
	lda #$00
	clc
	adc #$01
	sec
	sbc #$02
	
	;; MAP some SDRAM to $6000-$7FFF : $8000000+$6000 @ $6000
	lda #$00
	ldx #$80
	ldy #$00
	ldz #$00
	MAP
	ldx #$0f
	lda #$80
	ldy #$00
	ldz #$00
	MAP

	;; Enable SDRAM cache line use
	lda #$04
	sta $d7fe
	
	;; Now do some simple accesses
	ldx #$0f
loop:	
	txa
	sta $6000,x
	dex
	bpl loop

	ldx #$00
loop2:	
	lda $6000,x
	inx
	cpx #$10
	bne loop2

end:	jmp end
