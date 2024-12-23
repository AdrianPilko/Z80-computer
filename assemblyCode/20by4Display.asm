
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
#define DISPLAY_COLS 19

;; port definitions
#define lcdRegisterSelectCommand $00   ; all zero address including line 0 which is connected to the LCD  ReadSelect (RS) pin 
#define lcdRegisterSelectData $01      ; all zero address except line 0 which is connected to the LCD  ReadSelect (RS) pin 
#define keypadInOutPort $20             ; A6 high the rest low

    .org $0
    
    ld  sp , STACK_BOTTOM 
    
    call initialiseLCD

    xor a
    ld (score), a
    ld (starPosRow), a
    ld (starPosCol), a
    ld (galaxyPosRow), a
    ld (alternateLoopUpdateFlag), a
    ld a, DISPLAY_COLS-1    
    ld (galaxyPosCol), a
    

    ;ld a, (RowAddresses+1)    ; 0 = row 1, 3 = row 4
    ld a, (RowAddresses+2)    ; 0 = row 1, 3 = row 4
    call setLCDRow_a
startOutChars:
    ;ld hl, RowMessages+5
    ld hl, RowMessages+10
WriteRow:         
    call waitLCD 
    ld a, (hl)
    cp $ff
    jp z, afterWriteRow
    out (lcdRegisterSelectData), a
    inc hl
    jr WriteRow

afterWriteRow   
    jr afterWriteRow     ; effectively halt


preMainLoop:    
    ld a, (RowAddresses+1)    ; 0 = row 1, 3 = row 4
    call setLCDRow_a
mainLoop:           
    call displayStar          
    call delaySome       
       
    ld a, (starPosCol)   
    inc a           
    cp DISPLAY_COLS
    jp nz, skipZeroA
    xor a   
skipZeroA:    
    ld (starPosCol), a
  
    jp mainLoop   
    
    
keyboardScanInit:
    ld c,keypadInOutPort  ;Port address
    ld a,1              ;Row to scan
    ld d,0              ;Row index    
keypadScanLoop:         
    ld c, keypadInOutPort    
    out (c), a    ; put row count out on the keypad port
    in e, (c)     ; immediately read back in    
    jp nz, keyFoundinRegARow_DCol
    inc d
    rlca
    jr nc,keypadScanLoop 
    ld b, 0 
    ret
keyFoundinRegARow_DCol:
    ld b, 1
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
    ret



moveLCDCursorLocation20by4:
   ; subroutine to set the cursor to a specified row and column on the lcd
    push bc ; save registers b and c if needed

    ld c, a ; copy row number from a to c
    cp 1 ; check if row is 1 (zero-indexed)
    jr z, row_one ; if row is 1, skip the calculation for the first row

    ; calculate ddram address for rows other than the first
    ld a, $40 ; address offset for second row onwards
    sub 1 ; adjust for zero-based index
    add a, c ; add row number offset
    ld c, a ; save the calculated address in c

row_one:
    ld a, c ; load ddram address from c
    add a, b ; add column number to the calculated address
    out (lcdRegisterSelectCommand), a ; send command to set ddram address
    ; replace lcd_control_port with the actual i/o port used to communicate with the lcd controller

    pop bc ; restore registers b and c if saved

    ret ; return from the subroutine
    
moveLCDCursorLocation16by2   ; a stores the column, b stores the row
    call waitLCD
    push bc 
    push af
    push af
    ld a, 1
    cp b
    ld a, $80
    ld b, 0           
    jp nz, skipAddhex40
    ld b, $40    
skipAddhex40:    
    add a, b
    pop bc            ; b stores original value of a
    add a, b          ; a is now $80 plus row offset (if b was 1) + col offset
    out (lcdRegisterSelectCommand), a     ; Send command to LCD       
    pop af
    pop bc
    ret 

displayStar
    push af
    call waitLCD
    ld a, '*'
    out (lcdRegisterSelectData), a
    pop af    
    ret
displayBlank
    push af
    call waitLCD   
    ld a, ' '
    out (lcdRegisterSelectData), a
    pop af  
    ret
displayGalaxy    
 
    push af
    call waitLCD
    ld a, '#'
    out (lcdRegisterSelectData), a
    pop af    
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
;1	0x00	0x80
;2	0x40	0xC0
;3	0x14	0x94
;4	0x54	0xD4
 
setLCDRow_a:   ; set a to the row address
    push af
    call waitLCD
    pop af
    ld d, $80       ; ddram command 
    or d    
    out (lcdRegisterSelectCommand), a     ; Send command to LCD         
    ret 


moveCursorToPostion:  ;; b store the cursor position 
	call waitLCD
	ld a, $fe
    ld (lcdRegisterSelectCommand), a
	call waitLCD
	ld a, $80      ; start offset into ddram for cursor, if b=0 thats top left
	add a, b
    ld (lcdRegisterSelectCommand), a	
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

GameOverMessage:
    .db "Game Over!!!",$ff    
BootMessage:
    .db "Z80 byteForever",$ff    

RowMessages    ; each row message is 5 bytes
    .db "1111",$ff    
    .db "2222",$ff        
    .db "3333",$ff    
    .db "4444",$ff    
    
;;; ram variables    
    .org RAM_START
starPosRow
    .db $00
starPosCol
    .db $00   
galaxyPosRow
    .db $00
galaxyPosCol
    .db $00     
alternateLoopUpdateFlag
    .db $00     
seedValue
    .db $00
score
    .db $00
to_print:
    .dw $0000
#END

