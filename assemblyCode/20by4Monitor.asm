;; Adrian Pilkington December 2023
;; this is written to run on the single board homebrew computer described 
;; by the schematics in this repo.

;;; memory model:
;;; 0x0000 to 7fff      - ROM
;;; 0x8000 to to 0xffff - RAM
;;; 
#define ROM_SIZE $7fff
#define SIZE_OF_SYSTEM_VARIABLES $0004
#define STACK_BOTTOM $ffff
#define RAM_START $8000  
#define DISPLAY_COLS 18
#define START_OF_TEXT_ASCII 2

;; port definitions
#define lcdRegisterSelectCommand $00   ; all zero address including line 0 which is connected to the LCD  ReadSelect (RS) pin 
#define lcdRegisterSelectData $01      ; all zero address except line 0 which is connected to the LCD  ReadSelect (RS) pin 
#define keypadInOutPort $20             ; A6 high the rest low

    .org $0
    
    ld  sp , STACK_BOTTOM 
    
    call initialiseLCD

    xor a
    ld (currentDisplayRow), a
    ld (currentDisplayCol), a
    
    xor a
    ld (rowCount), a    
    ld (charCount), a
    
mainLoop  
    call arduinoInputScan
    ;; e now contains the byte read in if any, could be zero
    inc e 
    dec e    
    jr z, mainLoop
    ld a, e
    cp START_OF_TEXT_ASCII
    push af
    push de
    call z, initialiseLCD    
    pop de
    pop af
    call nz, displayChar    
    jr mainLoop
    
    halt   ; should never reach this
          
writeTextToDisplay:    ; this always prints the contnets of DisplayBuffer
    ld hl, DisplayBuffer
    ld bc, 19
WriteRow:           
    push bc
        push hl       
            call waitLCD
        pop hl
        ld a, (hl)
        out (lcdRegisterSelectData), a
        inc hl
    pop bc
    djnz WriteRow 
    ret
    
copyToDisplayBuffer_hl_b:    
    ld de, DisplayBuffer
    ld c, b
    ld b, 0
    ldir
    ret

displayChar
    push af
    call waitLCD
    ld a, e
    out (lcdRegisterSelectData), a
    
    ld a, (charCount)
    inc a
    ld (charCount), a
    cp 18    
    jr z, doCarridgeReturn    
    jr endOfDisplayChar
    
doCarridgeReturn
    xor a
    ld (charCount), a
    ld a, (rowCount)
    inc a
    ld (rowCount), a
    cp 4
    jr z, jumpToTopRow
    cp 3
    jr z, jumpRow3Row
    cp 2
    jr z, jumpRow2Row
    cp 1
    jr z, jumpRow1Row    
    jr endOfDisplayChar

;Row	DDRAM Start Address	Set DDRAM Command (Hex)
;0	0x00	0x80   (after oring with 0x80)
;1	0x40	0xC0
;2	0x14	0x94
;3	0x54	0xD4

jumpRow3Row
    xor a
    ld (charCount), a
    call waitLCD
    ld a, $d4 
    out (lcdRegisterSelectCommand), a     ; Send command to LCD  

    jr endOfDisplayChar   
jumpRow2Row    
    xor a
    ld (charCount), a
    call waitLCD
    ld a, $94 
    out (lcdRegisterSelectCommand), a     ; Send command to LCD  

    jr endOfDisplayChar
jumpRow1Row    
    xor a
    ld (charCount), a
    call waitLCD
    ld a, $c0 
    out (lcdRegisterSelectCommand), a     ; Send command to LCD  
    
    jr endOfDisplayChar
jumpToTopRow    
    xor a
    ld (rowCount), a
    ld (charCount), a   
    call waitLCD    
    ld a, $80 
    out (lcdRegisterSelectCommand), a     ; Send command to LCD      
    
endOfDisplayChar    
    pop af    
    ret    
   
    
arduinoInputScan  
    call giveArduinoAChance_1
    call giveArduinoAChance_1
    call giveArduinoAChance_1
    call giveArduinoAChance_1
    call giveArduinoAChance_1
    call giveArduinoAChance_1
    
    call giveArduinoAChance_2
    call giveArduinoAChance_2
    call giveArduinoAChance_2
    call giveArduinoAChance_2
    call giveArduinoAChance_2
    call giveArduinoAChance_2
    ret
    
giveArduinoAChance_1
    ld c, keypadInOutPort    
    ld a,1      ; bit zero on out port    
    ld b, 255    
giveChanceLoop1    
    out (c), a    ; output 1 on the ready to rx pin    
    in e, (c)     ; read in 1 byte into e from the keyboard port (now used as arduino "keyboard emulator"
    djnz giveChanceLoop1
    ret

giveArduinoAChance_2
    ld c, keypadInOutPort   
    xor a
    ld b, 255
giveChanceLoop2
    out (c), a    ; set ready rx pin to off
    djnz giveChanceLoop2
    ret


    
delaySome:    
    push bc    ; preserve bc register
    ld b, $ff
waitLoopAfterKeyFound11:    
    push bc
    ld b, $1f
waitLoopAfterKeyFound22:        
    djnz waitLoopAfterKeyFound22
    pop bc
    djnz waitLoopAfterKeyFound11    
    pop bc
    ret
 
      
  
initialiseLCD:
    ld hl,InitCommandList
    call waitLCD
loopLCDInitCommands
    ld a, (hl)
    cp $ff
    jp z, initialiseLCD_ret
    out (lcdRegisterSelectCommand), a     ; send command to lcd (assuming lcd control port is at 0x00)
    inc hl
    jp loopLCDInitCommands    
initialiseLCD_ret    
    xor a
    ld (rowCount), a    
    ld (charCount), a
    ret

;;; "generic" display code
; self evident, this clears the display
clearDisplay:
    push af
    call waitLCD
	ld a, $01
	ld (lcdRegisterSelectCommand), a
    pop af
	ret 

;Row	DDRAM Start Address	Set DDRAM Command (Hex)
;1	0x00	0x80   (after oring with 0x80)
;2	0x40	0xC0
;3	0x14	0x94
;4	0x54	0xD4
 
setLCDRowCol_bc:   ; set b to row, c to column
    push bc
    call waitLCD
    pop bc
    ld a, b
    add a, c           ; add the column
    ld d, $80       ; ddram command 
    or d   
    out (lcdRegisterSelectCommand), a     ; Send command to LCD         
    ret 

;;; make sure the lcd isn't busy - by checking the busy flag
waitLCD:    
    push af
waitForLCDLoop:             
    in a,(lcdRegisterSelectCommand)  
    rlca              
    jr c,waitForLCDLoop    
    pop af
    ret 
    
displayCharacter:    ; register a stores tghe character
    call waitLCD
    out (lcdRegisterSelectData), a
    ret 

hexprint16_onRight
    call waitLCD
    ld a, $80+$49        ; Set DDRAM address to start line 2 plus 5
    out (lcdRegisterSelectCommand), a     ; Send command to LCD    
    call hexprint16
    
    ret

    
hexprint16  ; print one 2byte number stored in location $to_print modified from hprint http://swensont.epizy.com/ZX81Assembly.pdf?i=1
	;ld hl,$ffff  ; debug check conversion to ascii
    ;ld ($to_print), hl
    
	ld hl,$to_print+$01	
	ld b,2	
hexprint16_loop	
    call waitLCD    
	ld a, (hl)
	push af ;store the original value of a for later
	and $f0 ; isolate the first digit
	rrca
	rrca
	rrca
	rrca        
    call ConvertToASCII
	out (lcdRegisterSelectData), a
    call waitLCD 
	pop af ; retrieve original value of a
	and $0f ; isolate the second digit
    call ConvertToASCII       
	out (lcdRegisterSelectData), a
	dec hl
	djnz hexprint16_loop
	ret	  

hexprint8 		
	push af ;store the original value of a for later
    call waitLCD 
    pop af
    push af ;store the original value of a for later
	and $f0 ; isolate the first digit    
	rrca
	rrca
	rrca
	rrca  
    call ConvertToASCII
	out (lcdRegisterSelectData), a
    call waitLCD 
	pop af ; retrieve original value of a
	and $0f ; isolate the second digit
    call ConvertToASCII       
	out (lcdRegisterSelectData), a
	ret

ConvertToASCII:
    ; assuming the value in register a (0-15) to be converted to ascii
    ; convert the value to its ascii representation
    add a, '0'       ; convert value to ascii character
    cp  ':'        ; compare with ascii '9'
    jr  nc, ConvertToASCIIdoAdd     ; jump if the value is not between 0-9
    jp ConvertToASCII_ret
ConvertToASCIIdoAdd:    
    add a, 7     ; if greater than '9', adjust to ascii a-f
ConvertToASCII_ret:
        
    ret              ; return from subroutine
    

;;; rom "constants"

InitCommandList:
;            4 line mode
;            |       clear display
;            |       |   cursor auto increment
;            |       |   |
    .db $38,$0e,$01,$06,$ff
;   .db $38,$09,$0e,$01,$06,$ff
        


;Step	Command (Hex)	Description
;1	0x33	Initialize in 8-bit mode (repeated to ensure).
;2	0x32	Switch to 4-bit mode.
;3	0x28	Function set: 4-bit mode, 2 lines, 5x8 dots.
;4	0x0C	Display ON, Cursor OFF, Blink OFF.
;5	0x01	Clear display.
;6	0x06	Entry mode: Increment, No shift.        
;    .db $33, $33, $32, $28, $01, $06

RowAddresses:
    .db $00,$40,$14,$54
BootMessage:
    .db "Z80 byteForever",$ff    

TestMessageRow1
    .db "Hello,World!",$ff    
TestMessageRow2   
    .db "ByteForever",$ff        
TestMessageRow3    
    .db "3333",$ff    
TestMessageRow4    
    .db "4444",$ff    
rowCount
    .db 0
charCount
    .db 0    
DisplayBufferProtectZone
    .db "                                             "
        
DisplayBuffer    ; this is big enough to fit one complete row, $ff terminates
    .db "*****************",$ff,$ff,$ff,$ff,$ff,$ff,$ff
DisplayBufferProtectZone2
    .db "                                             "    
;;; ram variables    
    .org RAM_START
currentDisplayRow
    .db $00
currentDisplayCol
    .db $00   
to_print:
    .dw $0000
#END

