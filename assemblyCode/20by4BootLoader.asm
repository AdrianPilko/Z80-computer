;; Adrian Pilkington December 2024
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
#define AFTER_BOOT_CODE $A000     ; this will give 8192bytes of boot code, plenty for now!
#define DISPLAY_COLS 20
#define START_OF_TEXT_ASCII 2
#define END_OF_TEXT_ASCII 3
#define HALT_COMPUTER 4

;; port definitions
#define lcdRegisterSelectCommand $00   ; all zero address including line 0 which is connected to the LCD  ReadSelect (RS) pin 
#define lcdRegisterSelectData $01      ; all zero address except line 0 which is connected to the LCD  ReadSelect (RS) pin 
#define keypadInOutPort $20             ; A6 high the rest low

    .org $0
    
softReset    

    ld  sp , STACK_BOTTOM 
    
    call initialiseLCD
    
    
    
    ld hl, $8000    ;bootCode location
    ld (bootCodePtr), hl    
    
    ld a, $c3                 ; edffectively a jp,0x0 and so a soft reset
    ld (backstopReset), a
    xor a
    ld (oddEvenNibble), a    
    ld (backstopReset+1), a    
    ld (backstopReset+2), a
    ld (posInAddress), a
    
mainLoop  
    call arduinoInputScan
    ;; e now contains the byte read in if any, could be zero
    inc e 
    dec e    
    jr z, mainLoop
    ld a, e
    push af
        cp START_OF_TEXT_ASCII    ; when we get this control code, then loop back up to mainLoop     
        call z, initialiseLCD            
    pop af
        cp START_OF_TEXT_ASCII    ; when we get this control code, then loop back up to mainLoop
        jr z, mainLoop                
        cp END_OF_TEXT_ASCII    
        jr z, softReset                    
        cp HALT_COMPUTER
        jp z, haltComputer
    push af
        cp $0D  ; carridge return ASCII code           
        call z, doCarridgeReturn
    pop af
        cp $0D
        jr z, mainLoop
        cp 'V'
    push af        
        call z, viewMemory             ; currently this just displays the first 4 * 4 bytes
    pop af   
        cp 'V'
        jr z, mainLoop    ; this double compare to skip is a bit cumbersome and I will it 

        cp 'S'            ; change start address for entering code
    push af        
        call z, setStartAddress             
    pop af   
        cp 'S'
        jr z, mainLoop    ; this double compare to skip is a bit cumbersome and I will it 

        cp 'P'            ; print the current program store pointer
    push af        
        call z, printProgramStorePtr            
    pop af   
        cp 'P'
        jr z, mainLoop    ; this double compare to skip is a bit cumbersome and I will it 
        cp 'R'
        jr nz, carryOnLoadingCode
        jr z, runTheCode
runTheCode        
        call displayStar   ;; shows code has started
        jp RAM_START   ; this is where it gets interesting, we're now going to run the code that was placed in bootCode                                   
        ;; reset the bootCodePtr to go again     
        ld hl, RAM_START
        ld (bootCodePtr), hl         
        call displayHash   ;; shows program has finished
        jr mainLoop
carryOnLoadingCode        
    push af
        cp 0    
        call nz, displayChar              ; echo the character to the lcd
    pop af
        call nz, storeBootCode     ; always store the byte (it's hex equivalent if valid)
    jr mainLoop
;;; best to keep jr mainLoop and haltComputer close
haltComputer    
    halt   
          
writeTextToDisplay:    ; this always prints the contnets of DisplayBuffer
    
WriteRow:           
    call waitLCD
    ld a, (hl)
    cp $ff
    jr z, endWriteRow
    out (lcdRegisterSelectData), a
    inc hl
    jr WriteRow
endWriteRow    
    ret
    
printProgramStorePtr  
    call initialiseLCD
    ld hl, programStorePtrtext
    call writeTextToDisplay
    
    ld hl, (bootCodePtr)
    ld ($to_print), hl
    call hexprint16
    call doCarridgeReturn
    ret

printNewProgramStorePtr
    ld hl, programStorePtrNewtext
    call writeTextToDisplay
    
    ld hl, (bootCodePtr)
    ld ($to_print), hl
    call hexprint16
    call doCarridgeReturn
    ret
    
viewMemory
    call initialiseLCD
    ld hl, $8000  
viewMemory_repeat
    ld b, 4
allRowsLoop    
    push bc
        push hl    
            ld ($to_print), hl
            call hexprint16    
            ld e, ':'         ; lets have a colon in between the memory address and the rest
            call displayChar
        pop hl
        ld b, 4
viewMemoryLoopRow
        push bc
            ld a, (hl)
            call hexprint8
            inc hl
            push hl
                ld e, '-'         ; lets have a colon in between the memory address and the rest
                call displayChar
            pop hl
        pop bc 
        djnz viewMemoryLoopRow
        push hl
            call doCarridgeReturn
        pop hl
    pop bc 
    djnz allRowsLoop
    
waitForUserPressViewMoreOrExit
    
    call arduinoInputScan
    ;; e now contains the byte read in if any, could be zero
    inc e 
    dec e    
    jr z, waitForUserPressViewMoreOrExit
    ld a, e
    
    cp 'V'  ; print next 16 bytes
    jp z, viewMemory_repeat
    cp 'E'  ; exit back
    jp z, exitViewMemory
    jp waitForUserPressViewMoreOrExit
exitViewMemory    
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
        
        ld a, (charCount)
        cp DISPLAY_COLS
        call z, doCarridgeReturn    
    pop af    
    ret    
    
    
enterCommand    

;; code here to store current line, then do a CR
      
    
endOfenterCommand    
    ret 


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
    jr endOfCR

;Row	DDRAM Start Address	Set DDRAM Command (Hex)
;0	0x00	0x80   (after oring with 0x80)
;1	0x40	0xC0
;2	0x14	0x94
;3	0x54	0xD4

jumpRow3Row
    xor a
    ld (charCount), a
    ld b, $54
    ld c, 0
    call setLCDRowCol_bc
    jr endOfCR   
jumpRow2Row    
    xor a
    ld (charCount), a
    ld b, $14 
    ld c, 0
    call setLCDRowCol_bc
    jr endOfCR 
jumpRow1Row    
    xor a
    ld (charCount), a
    ld b, $40 
    ld c, 0
    call setLCDRowCol_bc
    jr endOfCR
jumpToTopRow    
    xor a
    ld (rowCount), a
    ld (charCount), a   
    ld b, $00
    ld c, 0
    call setLCDRowCol_bc    
    ;call initialiseLCD   ; clears LCD
endOfCR    
    ret

ascii_convert_to_hex_char
    ld a, (ascii_char_to_convert) ; Load the ASCII character into A
    call ascii_to_nibble ; Convert ASCII to nibble
    ld (ascii_convert_result), a      ; Store the result in memory
    ; Program end (halt for simplicity)
    ret

ascii_to_nibble:
    cp '0'            ; Is it '0'-'9'?
    jr c, check_upper ; If less, check uppercase hex
    cp '9' + 1        ; Is it above '9'?
    jr nc, check_upper ; If greater, check uppercase hex
    sub '0'           ; Convert '0'-'9' to 0-9
    ret

check_upper:
    cp 'A'            ; Is it 'A'-'F'?
    jr c, check_lower ; If less, check lowercase hex
    cp 'F' + 1        ; Is it above 'F'?
    jr nc, check_lower ; If greater, check lowercase hex
    sub 'A'           ; Convert 'A'-'F' to 0-5
    add a, 10            ; Add 10 to get 10-15
    ret

check_lower:
    cp 'a'            ; Is it 'a'-'f'?
    jr c, invalid     ; If less, it's invalid
    cp 'f' + 1        ; Is it above 'f'?
    jr nc, invalid    ; If greater, it's invalid
    sub 'a'           ; Convert 'a'-'f' to 0-5
    add a, 10            ; Add 10 to get 10-15
    ret

invalid:
    xor a             ; Return 0 if invalid input
    ret


setStartAddress
    call printProgramStorePtr    
    call displayHash
    ;; the next 4 characters sent over from arduino are the 16bit address
    xor a
    ld (oddEvenNibble), a
    ld b, 2
noAddressChars_1 
    push bc
        call arduinoInputScan
        ;; e now contains the byte read in if any, could be zero
        inc e 
        dec e 
    pop bc        
        jr z, noAddressChars_1    
    push bc

        ld a, e
        ld (ascii_char_to_convert), a

        call ascii_convert_to_hex_char
        ld a, (oddEvenNibble)
        cp 0
        jr z, setAddloadFirstTime_1   ; is zero
        jr nz, setAddloadNextNibble_1   ;; else it must be 1 
setAddloadFirstTime_1
        ld a, 1
        ld (oddEvenNibble), a        
        ld hl, (bootCodePtr+1) 
        ld a, (ascii_convert_result)  
        and $0f
        ld (hl), a  
        call displayStar
        jr doNextLoopSetAdd_1
    
setAddloadNextNibble_1
        xor a
        ld (oddEvenNibble), a
        ld hl, (bootCodePtr+1)
        ld a, (hl)    
        ; rotate left a 4bits
        rlca
        rlca
        rlca
        rlca
        ; zero the lower 4 bits
        and $f0
        ld b, a   ; store a         
        ld a, (ascii_convert_result)    
        or b
        ld (bootCodePtr+1), a 
        call displayStar
doNextLoopSetAdd_1
    pop bc
    ld a, b
    dec a
    cp 0
    jp z, getNextByteOffAddress
    ld b, a
    jp noAddressChars_1
    
getNextByteOffAddress

    call displayHash
    xor a
    ld (oddEvenNibble), a
    ld b, 2
noAddressChars_2 
    push bc
        call arduinoInputScan
        ;; e now contains the byte read in if any, could be zero
        inc e 
        dec e    
    pop bc        
        jr z, noAddressChars_2   
    push bc  

        ld a, e
        ld (ascii_char_to_convert), a

        call ascii_convert_to_hex_char
        ld a, (oddEvenNibble)
        cp 0
        jr z, setAddloadFirstTime_2   ; is zero
        jr nz, setAddloadNextNibble_2   ;; else it must be 1 
setAddloadFirstTime_2
        ld a, 1
        ld (oddEvenNibble), a        
        ld hl, (bootCodePtr) 
        ld a, (ascii_convert_result)  
        and $0f
        ld (hl), a  
        call displayAt
        jr doNextLoopSetAdd_2
    
setAddloadNextNibble_2
        xor a
        ld (oddEvenNibble), a
        ld hl, (bootCodePtr)
        ld a, (hl)    
        ; rotate left a 4bits
        rlca
        rlca
        rlca
        rlca
        ; zero the lower 4 bits
        and $f0
        ld b, a   ; store a         
        ld a, (ascii_convert_result)    
        or b
        ld (bootCodePtr), a 
        call displayAt
doNextLoopSetAdd_2
    pop bc
    ld a, b
    dec a
    cp 0
    jp z, endOfGetProgramStoreAddress
    ld b, a
    jp noAddressChars_2

endOfGetProgramStoreAddress   
    call printNewProgramStorePtr
    ret 
    

storeBootCode  ; the byte to store is in reg "a"
    ;; we first need to convert the ascii to a number between 0 and 255 (0 to ff)
    ld (ascii_char_to_convert), a
    call ascii_convert_to_hex_char
    
    ld a, (oddEvenNibble)
    cp 0
    jr z, loadFirstTime   ; is zero
    jr nz, loadNextNibbleAndIncCodePtr   ;; else it must be 1 

loadNextNibbleAndIncCodePtr    
    xor a
    ld (oddEvenNibble), a
    
    ld hl, (bootCodePtr)     ; "derefference the memory pointer to the boot code
    
    ; load current memory contents into a 
    ld a, (hl)
       
    ; rotate left a 4bits
    rlca
    rlca
    rlca
    rlca
    ; zero the lower 4 bits
    and $f0
    ld b, a   ; store a         
    ld a, (ascii_convert_result)    
    or b
    ld (hl), a    
    inc hl    ; move buffer pointer on
    ld (bootCodePtr), hl
    jr printCurrentAddressAndMemory
loadFirstTime
    ld a, 1
    ld (oddEvenNibble), a        
    
    ld hl, (bootCodePtr) 
    ld a, (ascii_convert_result)  
    and $0f
    ld (hl), a     
    inc hl
    
printCurrentAddressAndMemory
;; print out current program pointer       
    dec hl
    push af
        ld hl, (bootCodePtr)
        ld ($to_print), hl
        call hexprint16
    pop af
    call hexprint8
    call doCarridgeReturn
endOfStoreCode    
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

displayStar
    push af
    call waitLCD
    ld a, '*'
    out (lcdRegisterSelectData), a
    pop af    
    ret

displayAt
    push af
    call waitLCD
    ld a, '@'
    out (lcdRegisterSelectData), a
    pop af    
    ret

displayHash
    push af
    call waitLCD
    ld a, '#'
    out (lcdRegisterSelectData), a
    pop af    
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
    
codeToDisplayHelloWorldManually
    ld e, 'H'
    call displayChar
    ld e, 'E'
    call displayChar
    ld e, 'L'
    call displayChar
    ld e, 'L'
    call displayChar
    ld e, 'O'
    call displayChar
    ld e, ','
    call displayChar
    ld e, 'W'
    call displayChar
    ld e, 'O'
    call displayChar
    ld e, 'R'
    call displayChar
    ld e, 'L'
    call displayChar
    ld e, 'D'
    call displayChar
    ld e, '!'
    call displayChar
    jp mainLoop
    
codeToDisplayHappyNewYear
    ld e, 'H'
    call displayChar
    ld e, 'A'
    call displayChar
    ld e, 'P'
    call displayChar
    ld e, 'P'
    call displayChar
    ld e, 'Y'
    call displayChar
    ld e, ' '
    call displayChar
    ld e, 'N'
    call displayChar
    ld e, 'E'
    call displayChar
    ld e, 'W'
    call displayChar
    ld e, ' '
    call displayChar
    ld e, 'Y'
    call displayChar
    ld e, 'E'
    call displayChar
    ld e, 'A'
    call displayChar    
    ld e, 'R'
    call displayChar    
    jp mainLoop    

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
DisplayBuffer    ; this is big enough to fit one complete row, $ff terminates
    .db "*****************",$ff,$ff,$ff,$ff,$ff,$ff,$ff
programStorePtrtext
    .db "store addr=",$ff
programStorePtrNewtext
    .db "new loc=",$ff    
;;; ram variables - anything you want to be non-constant!
    .org RAM_START    
; with the architecture of the computer in mind, anything after here is by 
; design in non volatile-RAM, and so any initialisation has to be done in 
; the EEPROM code (or boot code)
bootCode       
    .db 0    ; only define one byte here and use the .org command to move everything else after down
    .org AFTER_BOOT_CODE
backstopReset
    .db 0       ;; these are setup in the initialization code
    .dw $0000
oddEvenNibble
    .db 0
posInAddress    
    .db 0
ascii_char_to_convert
    .db 0   
ascii_convert_result
    .db 0       
to_print
    .dw $0000
rowCount
    .db 0
charCount
    .db 0
bootCodePtr
    .dw $0000          
#END

