;-----------------------------------------------------------------------------
;
;  "Worple" -- A Wordle-Style Game for the Apple I
;
;  Jeff Jetton (inspired by a Javascript game by Josh Wardle)
;  Feb/Mar 2022
;
;  Written for the dasm assembler, but should work with tweaks for others
;
;-----------------------------------------------------------------------------

        processor 6502

; Constants  -----------------------------------------------------------------

KBD     equ $D010           ; Location of input character from keyboard
KBDCR   equ $D011           ; Keyboard control: Indicator that a new input
                            ;                   character is ready
ECHO    equ $FFEF           ; WozMon routine to display register A char
WOZMON  equ $FF1F           ; Entry point back to WozMonitor
NULL    equ $00             ; String terminator
CR      equ $0D             ; Carriage return ASCII value
ESC     equ $1B             ; Escape key ASCII value
BACKSP  equ '_              ; Yup. This is what the backspace key generates.
MAXGUES equ '6              ; Guesses are tracked as ASCII numbers, not ints!
BUFFER  equ $0200           ; Text buffer for user input



; Zero-page variables  -------------------------------------------------------

        seg.u VARS
        org $0000

APACK   ds 4    ; Workspace for packed version of answer
HINTWK  ds 5    ; Workspace for building hint string--starts as copy of ANSWER
RAND    ds 2    ; Pointer to a word in the list, constantly cycled in the
                ; key-polling routine to "randomly" pick one each game
COUNTER ds 1    ; Zero-page counter to use when X & Y are occupied in EVALUATE
TXTPTR  ds 2    ; Two-byte pointer to char in a text string.  Used by PRINT



; Main program  --------------------------------------------------------------

        seg CODE
        org $0300
        
        ; Init the program
        cli                 ; No interrupts (just to be safe)
        cld                 ; BCD mode off
        jsr INITRND         ; Set RAND pointer to beginning of word list


        ; Show welcome message and ask if user wants instructions
        jsr PRINT
        dc CR
        dc "WORPLE!"
        dc CR
        dc CR
        dc "INSTRUCTIONS (Y/N)? "
        dc NULL
        jsr GETLINE         ; Ask user for a string in input text
        lda BUFFER          ; Put first character of that string in A
        cmp #'Y             ; Is it Y?
        beq INSTR           ; Yes, show instructions
        jmp NEWGAME         ; Too far for a branch :-(
        
INSTR   jsr PRINT
        dc "YOU HAVE SIX TURNS TO GUESS MY 5-LETTER"
        dc CR
        dc "WORD.  I'LL GIVE YOU HINTS AFTER EACH:"
        dc CR
        dc CR
        dc "  * = LETTER IN CORRECT PLACE"
        dc CR
        dc "  ? = RIGHT LETTER, WRONG PLACE"
        dc CR
        dc "  - = NOT IN WORD"
        dc CR
        dc NULL
        

NEWGAME jsr PRINT
        dc CR
        dc NULL
        lda #'0             ; Init GNUM (guess number) to ASCII "0"
        sta GNUM            ; We store this directly in the prompt text
;        jsr INITRND        ; Uncomment to debug (always pick 1st word)
        jsr UNPACK          ; Unpack into ANSWER whatever RAND now points to

        
NXTTURN inc GNUM            ; Next guess number
PROMPT  jsr PRINT           ; Display prompt...
        dc "GUESS #"
GNUM    dc 'N               ; Current guess # is embedded here
        dc ": "
        dc NULL
        jsr GETLINE         ; Get player guess
        
        cpx #5              ; User typed exactly five chars + CR?
        beq EVALUAT         ; Yes
        cpx #0              ; No chars?
        beq PROMPT          ; Yes, just redo prompt without err msg
        jsr PRINT           ; Display error message amd try again
        dc " ENTER 5 LETTERS"
        dc CR
        dc NULL
        jmp PROMPT
        
        
EVALUAT SUBROUTINE          ; Build hint string.  The workspace keeps track
                            ; of which letters in the ANSWER we've matched
                            ; to already, in some way or another.
        lda #0
        sta COUNTER         ; Track number of matches in COUNTER
        ldx #4
.exalp  lda ANSWER,X
        cmp BUFFER,X        ; Exact match to guess at this position?
        beq .match          ; Yes
        sta HINTWK,X        ; Store the answer letter in HINTWK workspace
        lda #'-             ;    for possible inexact matching later
        sta HINT,X          ; Store "-" in HINT for now
        bne .nxtltr         ; Always taken
.match  lda #'*             ; Put "*" in both HINT (for display) and HINTWK
        sta HINT,X          ;     (so the letter is out of the running for
        sta HINTWK,X        ;      the inexact match check below)
        inc COUNTER
.nxtltr dex                 ; Loop backwards for exact matches
        bpl .exalp
        
        ldx #0              ; Now check (looping forward) for inexact matches
.inxlp  lda HINTWK,X
        cmp #'*             ; Have we exact-matched this letter already?
        beq .nextx          ; Yes, move on to next guessed letter
        lda BUFFER,X        ; A holds guessed letter
        ldy #0
.chkltr cmp HINTWK,Y        ; Does guessed letter match answer letter at Y?
        beq .inxmch         ; Yes, it's an inexact match
        iny
        cpy #5
        bne .chkltr
        beq .nextx
.inxmch lda #'?
        sta HINT,X          ; Put "?" at the guessed letter's position in HINT
        sta HINTWK,Y        ; and at the tested letter's position in HINTWK, so
                            ; it won't get re-matched by a later guessed letter
.nextx  inx
        cpx #5
        bne .inxlp

        ; Display the hint string
        jsr PRINT
        dc "          "
HINT    dc "-----"          ; This gets overwritten by hint string at runtime
        dc CR
        dc NULL
        
        ; Was that a winning guess? (i.e., did we get five matches?)
        lda #5
        cmp COUNTER
        beq WINNER

        ; Are we done yet?
        lda GNUM           ; Check current guess number
        cmp #MAXGUES       ; Was that the last turn?
        beq LOSE           ; Yup
        jmp NXTTURN
        
LOSE    jsr PRINT 
        dc "SORRY, THE WORD WAS "
        dc '"
ANSWER  dc "XXXXX"         ; Overwritten by answer text at runtime
        dc '"
        dc NULL
        jmp REPLAY
        
WINNER  lda GNUM           ; We won! Set up a response string to print...
        and #%111          ; Convert ASCII GNUM "1" to "6" to values 1 to 6
        asl                ; Mult. by two to yield an offset from 2 to 12
        tax                ; Move offset to X
        lda [PTRTBL-2],X   ; Copy over LSB of response string
        sta TXTPTR
        lda [PTRTBL-1],X   ; ...and the MSB
        sta TXTPTR+1
        jsr PRPTR          ; Call print subroutine that assumes TXTPTR is set
        lda #'!            ; Saves one byte vs. putting the ! in each string
        jsr ECHO
        
REPLAY  jsr PRINT
        dc CR
        dc CR
        dc "PLAY AGAIN (Y/N)? "
        dc NULL
        jsr GETLINE
        lda BUFFER         ; First character of response
        cmp #'Y            ; Is it Y?
        bne QUIT           ; No
        jmp NEWGAME
QUIT    jmp WOZMON         ; Exit to monitor





; Subroutines  ---------------------------------------------------------------


UNPACK  SUBROUTINE      ; Unpack the word currently pointed to by RAND

        ldy #2          ; First copy the three bytes of the packed answer into
                        ; the last three bytes of four-byte workspace APACK
.cpylp  lda (RAND),Y    
        sta [APACK+1],Y
        dey
        bpl .cpylp      ; Loop if not done copying
        
        lda RAND        ; Which part of the word list is RAND on (0 or 1)?
        cmp #<WORDS_1   ; Subtract LSB of "1" list address from MSB of RAND
                        ; We use cmp since we don't care about the result,
                        ; just the carry flag (cmp sets carry automatically)
        lda RAND+1      ; Subtract the MSB of "1" list from MSG of RAND
        sbc #>WORDS_1   ; taking into account the carry flag from the cmp step
        lda #0          ; Carry flag winds up equal to what bit 25 should be
        adc #0          ; Put carry flag in A
        sta APACK       ; 1 if we're into "1" list, 0 if not

        ldy #6          ; Shift the 25 bits of the packed word to the leftmost
.shftlp jsr ROTWKSP     ;    end of the four-byte (32-bit) workspace
        dey
        bpl .shftlp
        
        iny             ; Bump Y to zero to track ANSWER byte offset
.nxtltr lda #5          ; Each letter is encoded into five bits
        sta COUNTER     ;    which we'll count using COUNTER
.nxtbit jsr ROTWKSP     ; Rotate leftmost workspace bit into carry
        rol             ; Rotate that carry into A
        dec COUNTER
        bne .nxtbit 
        clc             ; Letter is ready.  Convert to ASCII char.
        adc #$A1        ;     The 5 we put in A at .nxtltr was never cleared.
                        ;     So we can't just add 65 to convert 0-25 to ASCII
                        ;     65-90. The shifted 101 means the letters are now
                        ;     encoded as 10100000-10111001 ($A0-$B9), so we
                        ;     add $A1.  Not clearing A saves two bytes :-)
        sta ANSWER,Y    ; Store freshly-unpacked letter in the ANSWER string
        iny
        cpy #5          ; Have we done all five letters?
        bmi .nxtltr     ; No, do next letter...
        rts



ROTWKSP SUBROUTINE      ; Rotates all 32 bits of APACK to the left, into carry
                        ; Used by UNPACK above.  Destroys X.
        ldx #3          ; Loop uses 4 fewer bytes than unrolled version
.shflp  ROL APACK,X
        dex
        bpl .shflp
        rts



INITRND lda #<WORDS_0   ; Start RAND address at beginning of word list
        sta RAND
        lda #>WORDS_0
        sta RAND + 1
        rts



; Input handling. Similar to WozMon's GETLINE, but doesn't do a CR first
; and also cycles through RAND offsets while polling for a key press.
; Ignores non-alpha keys except for backspace, escape, and return.
; Treats backspace like an escape (cancels current input line), so the hint
; string will still line up with the guess correctly.

GETLINE SUBROUTINE      ; Get user input and cycle word pointer while polling
        ldx #0          ; Register X is our current buffer offset
        
.getkey clc             ; Move RAND pointer up by three bytes
        lda RAND
        adc #3
        sta RAND
        lda RAND+1
        adc #0
        sta RAND+1
        lda RAND        ; Did we move past the end of the word list?
        cmp #<WRDEND    ; (See UNPACK for notes on how this weird check works)
        lda RAND+1
        sbc #>WRDEND 
        bcc .chkpia     ; Carry clear = had to borrow, so not past end yet
        jsr INITRND     ; Otherwise, set back at beginning of list
        
.chkpia lda KBDCR       ; Check PIA for keyboard input
        bpl .getkey     ; Loop if A is "positive" (bit 7 low... no key ready)
        lda KBD         ; Get the keyboard character
        and #%01111111  ; Clear bit 7, which is always set for some reason

        cmp #'[         ; Did they type something greater than Z?
        bcs .notaz      ; Yes -- so not A-Z, check for other commands
        cmp #'A         ; Less than A?
        bcc .notaz      ; Yes
        
        sta BUFFER,X    ; Store letter in buffer
        jsr ECHO        ;     display it
        inx             ;     bump up buffer pointer
        bmi .reprmt     ; If we overflowed the buffer, reprompt
                        ; (Otherwise this will fall through to the bne .getkey)
        
.notaz  cmp #CR         ; Return/Enter?
        beq .enter      ; Yes, echo it and return without zeroing X
        cmp #BACKSP     ; Did they hit a backspace?
        beq .reprmt     ; Yes, reprompt
        cmp #ESC        ; What about Escape?
        bne .getkey     ; Nope. Ignore this key and get next one
.reprmt ldx #0          ; Set X back to zero and return (causing a re-prompt)
.enter  lda #CR
        jmp ECHO

; End of input line handler



; Print routines:  Use PRINT to print text immediately after JSR PRINT call
;                  (Immediate mode).  PRPTR is, in turn, called by PRINT.
;                  PRPTR assumes TXTPTR is already correctly set up.  Call it
;                  directly when setting up TXTPTR in some other way.  Note
;                  that PRPTR starts with an INC, so set TXTPTR to one less
;                  than the address of the string you want to print.

PRINT   SUBROUTINE      ; Prints any null-terminated text following its call
        pla             ; JSR stores the return address minus one on the stack
        sta TXTPTR      ; Pop it back off and put it in our text pointer
        pla             ; (Little end was last in!)
        sta TXTPTR+1
        jsr PRPTR       ; Call print routine now that TXTPTR is set up
        lda TXTPTR+1    ; Push current pointer onto the stack (big end first)
        pha             ;    This will be on the NULL, i.e. address-1 of the
        lda TXTPTR      ;    next operation after the end of the string,
        pha             ;    which is what RTS expects to see
        rts
        
PRPTR   SUBROUTINE      ; Prints null-terminated string starting from TXTPTR+1
        ldx #0          ; No non-indexed indirect mode, so just keep X at zero
.nextch inc TXTPTR      ; Bump up the pointer one byte
        bne .readch     ; If we didn't wrap, read next character
        inc TXTPTR+1    ; We did wrap, so bump up the most-sig byte too
.readch lda (TXTPTR,X)
        beq .done       ; If we're on a NULL, stop printing
        jsr ECHO        ; Otherwise, display the character
        jmp .nextch
.done   rts



; Stored data   --------------------------------------------------------------


PTRTBL  ; Pointer table for the "winner" responses below

        .word TXT_W1-1       ; PRPTR routine assumes we start
        .word TXT_W2-1       ; by pointing to the address
        .word TXT_W3-1       ; just before the string
        .word TXT_W4-1       ; we really want
        .word TXT_W5-1
        .word TXT_W6-1

; The responses themselves, depending on guess #

TXT_W1  dc "LUCKY"
        dc NULL
TXT_W2  dc "AMAZING"
        dc NULL
TXT_W3  dc "WOO-HOO"
        dc NULL
TXT_W4  dc "WELL DONE"
        dc NULL
TXT_W5  dc "NOT BAD"
        dc NULL
TXT_W6  dc "PHEW"
        dc NULL


        
; ****  Word lists  **********************************************************

; Letters are coded into five-bit chunks, so 25 bits for a five-letter word.
; Ex:  A = 0 (00000), P = 15 (01111), Q = 16 (10000), and Z = 25 (11001)
; To fit into three bytes (24 bits), we don't store the leftmost bit of the
; first letter.  Instead it's inferred and reconstructed based on which section
; of the alphabetical list of words we're in:

; Words starting with A-P, where the unstored leftmost bit should be zero:
WORDS_0 INCBIN "words_0.bin"

; Words starting with Q-Z, where unstored leftmost bit should be one:
WORDS_1 INCBIN "words_1.bin"

WRDEND     ; Symbol to let us know we've reached the end of the list


        
        