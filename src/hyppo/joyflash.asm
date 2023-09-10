  ;; -------------------------------------------------------------------
  ;;   MEGA65 "HYPPOBOOT" Combined boot and hypervisor ROM.
  ;;   Paul Gardner-Stephen, 2014-2019.
  ;;   -------------------------------------------------------------------
  ;;   Purpose:
  ;;   1. Verify checksum of ROM area of slow RAM.
  ;;   2. If checksum fails, load complete ROM from SD card.
  ;;   3. Select default disk image for F011 emulation.

  ;;   The hyppo ROM is 16KB in length, and maps at $8000-$BFFF
  ;;   in hypervisor mode.

  ;;   Hyppo modifies RAM from $0000-$07FFF (ZP, stack, 40-column
  ;;   screen, 16-bit text mode) during normal boot.

  ;;   BG: is the below true still, I dont think so.
  ;;   If Hyppo needs to load the ROM from SD card, then it may
  ;;   modify the first 64KB of fast ram.

  ;;   We will use the convention of C=0 means failure, ie CLC/RTS,
  ;;                             and C=1 means success, ie SEC/RTS.


  ;;   This included file defines many of the alias used throughout
  ;;   it also suggests some memory-map definitions
  ;;   ----------------------------------------------------------------

!src "constants.asm"
!src "macros.asm"
!src "machine.asm"

!addr TrapEntryPoints_Start        = $8000
!addr RelocatedCPUVectors_Start    = $81f8
!addr Traps_Start                  = $8200
!addr DOSDiskTable_Start           = $bb00
!addr SysPartStructure_Start       = $bbc0
!addr DOSWorkArea_Start            = $bc00
!addr ProcessDescriptors_Start     = $bd00
!addr HyppoStack_Start             = $be00
!addr HyppoZP_Start                = $bf00
!addr Hyppo_End                    = $bfff

;; .file [name="../../bin/HICKUP.M65", type="bin", segments="TrapEntryPoints,RelocatedCPUVectors,Traps,DOSDiskTable,SysPartStructure,DOSWorkArea,ProcessDescriptors,HyppoStack,HyppoZP"]
	!to "bin/BRICKUP.M65", plain

;; .segmentdef TrapEntryPoints        [min=TrapEntryPoints_Start,     max=RelocatedCPUVectors_Start-1                         ]
;; .segmentdef RelocatedCPUVectors    [min=RelocatedCPUVectors_Start, max=Traps_Start-1                                       ]
;; .segmentdef Traps                  [min=Traps_Start,               max=DOSDiskTable_Start-1                                ]
;; .segmentdef DOSDiskTable           [min=DOSDiskTable_Start,        max=SysPartStructure_Start-1,                           ]
;; .segmentdef SysPartStructure       [min=SysPartStructure_Start,    max=DOSWorkArea_Start-1                                 ]
;; .segmentdef DOSWorkArea            [min=DOSWorkArea_Start,         max=ProcessDescriptors_Start-1                          ]
;; .segmentdef ProcessDescriptors     [min=ProcessDescriptors_Start,  max=HyppoStack_Start-1                                  ]
;; .segmentdef HyppoStack             [min=HyppoStack_Start,          max=HyppoZP_Start-1,            fill, fillByte=$3e      ]
;; .segmentdef HyppoZP                [min=HyppoZP_Start,             max=Hyppo_End,                  fill, fillByte=$3f      ]
;; .segmentdef Data                   [min=Data_Start,                max=$ffff                                               ]

;;         .segment TrapEntryPoints
        * = TrapEntryPoints_Start

;; /*  -------------------------------------------------------------------
;;     CPU Hypervisor Trap entry points.
;;     64 x 4 byte entries for user-land traps.
;;     some more x 4 byte entries for system traps (reset, page fault etc)
;;     ---------------------------------------------------------------- */

trap_entry_points:

        ;; Traps $00-$07 (user callable)
        ;;
        jmp nosuchtrap                ;; Trap #$00 (unsure what to call it)
        eom                                     ;; refer: hyppo_dos.asm
        jmp nosuchtrap                         ;; Trap #$01
        eom                                     ;; refer: hyppo_mem.asm
        jmp nosuchtrap                        ;; Trap #$02
        eom                                     ;; refer: hyppo_syspart.asm
        jmp nosuchtrap                         ;; Trap #$03
        eom                                     ;; refer serialwrite in this file
        jmp nosuchtrap                        ;; Trap #$04
        eom                                     ;; Reserved for Xemu to use
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom

        ;; Traps $08-$0F (user callable)
        ;;
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom

        ;; Traps $10-$17 (user callable)
        ;;
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom

        ;; Traps $18-$1F (user callable)
        ;;
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom

        ;; Traps $20-$27 (user callable)
        ;;
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom

        ;; Traps $28-$2F (user callable)
        ;;
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom

        ;; Traps $30-$37
        ;;
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom

        jmp nosuchtrap           ;; Trap #$32 (Protected Hardware Configuration)
        eom                                     ;; refer: hyppo_task


        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom

        ;; Traps $38-$3F (user callable)
        ;;
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
	;; Writing to $D67F shall trap to freezer, as though user had triggered it.
        jmp nosuchtrap
        eom

        ;; Traps $40-$4F (reset, page fault and other system-generated traps)
        jmp reset_entry                         ;; Trap #$40 (power on / reset)
        eom                                     ;; refer: below in this file

        jmp nosuchtrap                          ;; Trap #$41 (page fault)
        eom                                     ;; refer: hyppo_mem

        jmp nosuchtrap                  ;; Trap #$42 (press RESTORE for 0.5 - 1.99 seconds)
        eom                                     ;; refer: hyppo_task "1000010" x"42"

        jmp nosuchtrap                  ;; Trap #$43 (C= + TAB combination)
        eom                                     ;; refer: hyppo_task

        jmp nosuchtrap		;; Trap #$44 (virtualised F011 sector read)
        eom

        jmp nosuchtrap                  ;; Trap #$45 (virtualised F011 sector write)
        eom

        jmp nosuchtrap        ;; Trap #$46 (6502 unstable illegal opcode)
        eom
        jmp nosuchtrap                    ;; Trap #$47 (6502 KIL instruction)
        eom	
        jmp nosuchtrap                ;; Trap #$48 (Ethernet remote control trap) 
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom
        jmp nosuchtrap
        eom

        ;; Leave room for relocated cpu vectors below
        ;;
        ;; .segment RelocatedCPUVectors
        * = RelocatedCPUVectors_Start

        ;; Then we have relocated CPU vectors at $81F8-$81FF
        ;; (which are 2-byte vectors for interrupts, not 4-byte
        ;; trap addresses).
        ;; These are used to catch interrupts in hypervisor mode
        ;; (although the need for them may have since been removed)
        !16 reset_entry    ;; unused vector
        !16 reset_entry ;; NMI
        !16 reset_entry    ;; RESET
        !16 reset_entry ;; IRQ


        ;; .segment Traps
        * = Traps_Start

nosuchtrap:
	;; FALLTHROUGH
reset_entry:
        sei

	;; Write # to serial port as debug
	ldx #$23
        stx hypervisor_write_char_to_serial_monitor
	
	;; Clear 16-bit text mode
	LDA #$00
	STA $D054

	;; Ask FPGA to boot from part-way through slot 7
	;; Slot 7 = 7x8MB = $3800000.
	;; So we boot from $3810000.
	LDA #$00
	STA $D6C8
	LDA #$00
	STA $D6C9
	LDA #$81
	STA $D6CA
	LDA #$03
	STA $D6CB

	LDA #$42
	STA $D6CF
	
loop:	
	inc $D020
	jmp loop

	;; Make sure we pad to full size
	* = Hyppo_End
	!8 0
	
