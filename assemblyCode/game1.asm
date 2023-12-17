
;; simple dodge game - Adrian Pilkington December 2023
;; this is written to run on the single board homebrew computer described 
;; by the schematics in this repo.

;; Dodge: you play the star running endlessless through space 
;; your mission is to avoid the oncoming galaxy's which threaten to absorb you
;; todo this press abnd hold any key on the keypad to switch rows to row 2
;; 


;;; memory model:
;;; 0x0000 to 7fff      - ROM
;;; 0x8000 to to 0xffff - RAM
;;; 
#define ROM_SIZE $7fff
#define SIZE_OF_SYSTEM_VARIABLES $0004
#define STACK_BOTTOM $ffff
#define RAM_START $8000  
#define DISPLAY_COLS 16

;; port definitions
#define lcdRegisterSelectCommand $00   ; all zero address including line 0 which is connected to the LCD  ReadSelect (RS) pin 
#define lcdRegisterSelectData $01      ; all zero address except line 0 which is connected to the LCD  ReadSelect (RS) pin 
#define keypadInOutPort $20             ; A6 high the rest low

    .org $0
    
    ld  sp , STACK_BOTTOM 
    
    call initialiseLCD
    call setLCDRow2
    xor a
    ld (starPosRow), a
    ld (starPosCol), a
    ld (galaxyPosRow), a
    ld (alternateLoopUpdateFlag), a
    ld a, DISPLAY_COLS-1    
    ld (galaxyPosCol), a
    
    ; Initialize seed
    ld a, $33
    ld (seedValue), a  

mainLoop:      
        
    ld a, (starPosRow)
    ld b, a
    ld a, (starPosCol)    
    call moveLCDCursorLocation
    call displayStar    
    ; store the star position
    ld (starPosCol), a
    ld a, b
    ld (starPosRow), a    
    ; now display the enemy "galaxy" 
        
    ld a, (galaxyPosRow)
    ld b, a 
    ld a, (galaxyPosCol)
    call moveLCDCursorLocation
    call displayGalaxy  


    call checkCollision    
    
    ld a, (starPosRow)          
    ld b, a
    ld a, (starPosCol)
    call moveLCDCursorLocation
    call delaySome
    call displayBlank    

    ld a, (galaxyPosRow)
    ld b, a 
    ld a, (galaxyPosCol)
    call moveLCDCursorLocation
    call displayBlank    

    ld a,(alternateLoopUpdateFlag)
    cp 0
    jp z, skipAlternateLoopThisTime
    
    xor a 
    ld (alternateLoopUpdateFlag), a 

    ld a, (galaxyPosCol)
    dec a
    ld (galaxyPosCol), a    
    cp 0
    jp nz, skipResetGalaxyPos
    ld a, DISPLAY_COLS-1
    ld (galaxyPosCol), a    
    ;; now chose random row for galaxy

    ld a, (seedValue)  ; Read from address pointed by HL    
    rrca         ; Rotate A right through carry (pseudo-random due to varying timing)
    and 1
    ld (galaxyPosRow), a            
    jp skipResetGalaxyPos
skipAlternateLoopThisTime:
    ld a, 1
    ld (alternateLoopUpdateFlag), a 
skipResetGalaxyPos:            
    call keyboardScanInit
    ld a, b
    ld (starPosRow), a

    ld a, (starPosCol)   
    inc a           
    cp DISPLAY_COLS
    jp nz, skipZeroA
    xor a   
skipZeroA:    
    ld (starPosCol), a
    rrca
    ld (seedValue), a               
    
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
    
gameOver
    ld a, 0
    ld b, 0
    call moveLCDCursorLocation
    ld hl, GameOverMessage
gameOverMessageLoop:         
    call waitLCD 
    ld a, (hl)
    cp $ff
    jp z, lastInstruction
    out (lcdRegisterSelectData), a
    inc hl
    jp gameOverMessageLoop    
lastInstruction
    halt
    
checkCollision
    ; check if row equal
    ld a, (starPosRow)
    ld b, a    ; b now stores star position row
    ld a, (galaxyPosRow)
    cp b
    jp nz, skipGameOver

    ; check if column equal
    ld a, (starPosCol)
    ld b, a    ; b now stores star position col
    ld a, (galaxyPosCol)
    cp b
    jp nz, skipGameOver 
    jp gameOver
skipGameOver    
    ;; you avoided -- for now!!!
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

moveLCDCursorLocation   ; a stores the column, b stores the row
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

setLCDRow1:
    call waitLCD
    ld a, $80         ; Set DDRAM address to start of the first row
    out (lcdRegisterSelectCommand), a     ; Send command to LCD         
    ret 

setLCDRow2:
    push af
    call waitLCD
    ld a, $80+$40        ; Set DDRAM address to start of the second line (0x40)
    out (lcdRegisterSelectCommand), a     ; Send command to LCD         
    pop af
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
    .db $38,$0e,$01,$06,$ff
GameOverMessage:
    .db "Game Over!!!",$ff    
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
    .db $13
to_print:
    .dw $0000
#END

