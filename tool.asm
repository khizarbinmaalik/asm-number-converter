.model small
.stack 100h

.data
    ; ---- Menu strings ----
    menuTitle   db 13,10,'=== Number Conversion Tool ===',13,10,'$'
    line1       db '1. Decimal to Binary',13,10,'$'
    line2       db '2. Decimal to Hexadecimal',13,10,'$'
    line3       db '3. Binary to Decimal',13,10,'$'
    line4       db '4. Hexadecimal to Decimal',13,10,'$'
    line5       db '5. Exit',13,10,'$'
    chooseMsg   db 'Choose (1-5): $'

    ; ---- Input prompts ----
    askDec      db 13,10,'Enter decimal (0-65535): $'
    askBin      db 13,10,'Enter binary  (e.g. 1010): $'
    askHex      db 13,10,'Enter hex     (e.g. 1A3F): $'

    ; ---- Result labels ----
    lblBin      db 13,10,'Binary  = $'
    lblHex      db 13,10,'Hex     = $'
    lblDec      db 13,10,'Decimal = $'

    ; ---- Other messages ----
    newline     db 13,10,'$'
    badMsg      db 13,10,'Invalid choice. Try again.',13,10,'$'
    badHexMsg   db 13,10, 'Invalid hex input! Only 0-9 and A-F allowed.',13,10,'$'
    waitMsg     db 13,10,'Press any key...',13,10,'$'

    ; ---- Buffers ----
    inBuf       db 10, 0, 10 dup(0)  ; [maxLen][actualLen][typed chars...]
    outBuf      db 20 dup('$')        ; where we build the result string
    tmpBuf      db 6  dup(0)          ; temp storage used during digit reversal

    ; ---- Shared variable ----
    numVal      dw 0  
    validFlag   db 1    

.code

;  MAIN - program entry point and menu loop
main PROC
    mov ax, @data   ; get the address of the data segment
    mov ds, ax      ; DS must point to .data before we can use variables
    mov es, ax      ; set ES to same segment for safety

MenuLoop:
    call PrintMenu  ; show the menu on screen

    mov ah, 01h     
    int 21h         

    push ax

    mov ah, 09h
    mov dx, OFFSET newline   
    int 21h

    pop ax            

    cmp al, '1'
    je  DoDecToBin
    cmp al, '2'
    je  DoDecToHex
    cmp al, '3'
    je  DoBinToDec
    cmp al, '4'
    je  DoHexToDec
    cmp al, '5'
    jne InvalidChoice
    jmp ExitProg

InvalidChoice:
    ; If none of the above matched, the choice is invalid
    mov dx, OFFSET badMsg
    mov ah, 09h
    int 21h
    jmp MenuLoop   

; ---- Option 1: Decimal to Binary ----
DoDecToBin:
    mov dx, OFFSET askDec
    mov ah, 09h
    int 21h
    call ReadString    ; read user input into inBuf
    call ParseDecimal  ; inBuf text  → numVal (integer)
    call DecToBin      ; numVal      → outBuf (binary string)
    mov dx, OFFSET lblBin
    mov ah, 09h
    int 21h
    mov dx, OFFSET outBuf
    mov ah, 09h
    int 21h
    call WaitKey
    jmp MenuLoop

; ---- Option 2: Decimal to Hexadecimal ----
DoDecToHex:
    mov dx, OFFSET askDec
    mov ah, 09h
    int 21h
    call ReadString
    call ParseDecimal
    call DecToHex      ; numVal → outBuf (hex string)
    mov dx, OFFSET lblHex
    mov ah, 09h
    int 21h
    mov dx, OFFSET outBuf
    mov ah, 09h
    int 21h
    call WaitKey
    jmp MenuLoop

; ---- Option 3: Binary to Decimal ----
DoBinToDec:
    mov dx, OFFSET askBin
    mov ah, 09h
    int 21h
    call ReadString
    call ParseBinary   
    call NumToDecStr   ; numVal → outBuf (decimal string)
    mov dx, OFFSET lblDec
    mov ah, 09h
    int 21h
    mov dx, OFFSET outBuf
    mov ah, 09h
    int 21h
    call WaitKey
    jmp MenuLoop

; ---- Option 4: Hexadecimal to Decimal ----
DoHexToDec:
    mov dx, OFFSET askHex
    mov ah, 09h
    int 21h
    call ReadString
    call ParseHex      ; inBuf hex string → numVal

    cmp validFlag, 0      
    jne DHD_ValidInput    
    mov dx, OFFSET badHexMsg
    mov ah, 09h
    int 21h               
    call WaitKey
    jmp MenuLoop          

DHD_ValidInput:
    call NumToDecStr   ; numVal → outBuf (decimal string)
    mov dx, OFFSET lblDec
    mov ah, 09h
    int 21h
    mov dx, OFFSET outBuf
    mov ah, 09h
    int 21h
    call WaitKey
jmp MenuLoop

ExitProg:
    mov ax, 4C00h  ; DOS terminate-program service (exit code 0)
    int 21h
main ENDP

PrintMenu PROC
    push ax            ; save AX and DX because we will modify them
    push dx
    mov ah, 09h
    lea dx, menuTitle     
    int 21h
    mov dx, OFFSET line1        
    int 21h
    mov dx, OFFSET line2        
    int 21h
    mov dx, OFFSET line3        
    int 21h
    mov dx, OFFSET line4        
    int 21h
    mov dx, OFFSET line5        
    int 21h
    mov dx, OFFSET chooseMsg    
    int 21h
    pop dx             
    pop ax
    ret
PrintMenu ENDP

ReadString PROC
    push ax
    push dx

    mov dx, OFFSET inBuf  
    mov ah, 0Ah           
    int 21h               

    mov dx, OFFSET newline
    mov ah, 09h
    int 21h
    pop dx
    pop ax
    ret
ReadString ENDP

WaitKey PROC
    push ax
    push dx

    mov dx, OFFSET waitMsg
    mov ah, 09h
    int 21h

    mov ah, 08h  ; DOS service 08h: wait for a keypress (no echo)
    int 21h

    pop dx
    pop ax
    ret
WaitKey ENDP

;  ClearOutBuf - fills outBuf with '$' (DOS string terminator)
;  This resets the buffer before writing a new result
ClearOutBuf PROC
    push ax
    push cx
    push di
    mov di, OFFSET outBuf  ; DI = pointer to start of buffer
    mov cx, 20             
    mov al, '$'
ClearLoop:
    mov [di], al           
    inc di                 
loop ClearLoop         
    pop di
    pop cx
    pop ax
    ret
ClearOutBuf ENDP

; ================================================================
;  ParseDecimal - converts decimal string in inBuf → numVal
;
;  Algorithm (for each character):
;    numVal = (numVal * 10) + digit
;
;  Multiply by 10 without MUL instruction, using SHL:
;    n * 10  =  n * 8  +  n * 2
;    n * 8   =  n shifted left 3 times  (SHL 1, SHL 1, SHL 1)
;    n * 2   =  n shifted left 1 time   (SHL 1)
; ================================================================
ParseDecimal PROC
    push ax
    push bx
    push cx
    push si

    mov numVal, 0              ; start accumulator at zero
    mov si, OFFSET inBuf + 2 
    mov cl, [inBuf + 1]       ; CL = number of characters typed
    mov ch, 0                 ; CX = full character count

PD_Loop:
    cmp cx, 0
    je  PD_Done

    mov al, [si]              
    sub al, '0'               
    mov ah, 0                 

    push ax                   ; save digit while we multiply numVal by 10
    mov bx, numVal            ; BX = current accumulated value (n)

    ; BX * 10 = BX*8 + BX*2  (using SHL = shift left)
    mov ax, bx                ; AX = n
    shl ax, 1                 ; AX = n * 2
    shl bx, 1                 ; BX = n * 2
    shl bx, 1                 ; BX = n * 4
    shl bx, 1                 ; BX = n * 8
    add bx, ax                ; BX = n*8 + n*2 = n * 10

    pop ax                    ; restore digit back into AX
    add bx, ax                ; BX = (numVal * 10) + digit
    mov numVal, bx            ; store updated value

    inc si                    
    dec cx                    
jmp PD_Loop

PD_Done:
    pop si
    pop cx
    pop bx
    pop ax
    ret
ParseDecimal ENDP

;  Algorithm (for each bit):
;    numVal = (numVal SHL 1) OR bit
;
;  SHL 1 shifts all bits one position left (makes room for new bit)
;  OR inserts the new bit into the lowest position
ParseBinary PROC
    push ax
    push bx
    push cx
    push si

    mov numVal, 0
    mov si, OFFSET inBuf + 2
    mov cl, [inBuf + 1]
    mov ch, 0

PB_Loop:
    cmp cx, 0
    je  PB_Done

    mov al, [si]              
    sub al, '0'               
    mov ah, 0                 

    mov bx, numVal
    shl bx, 1                 
    or  bx, ax                ; OR in the new bit at the lowest position
    mov numVal, bx

    inc si
loop PB_Loop

PB_Done:
    pop si
    pop cx
    pop bx
    pop ax
    ret
ParseBinary ENDP

;
;  Algorithm (for each hex digit = "nibble"):
;    numVal = (numVal SHL 4) OR nibble
;
;
;  AND 0DFh forces a letter to uppercase:
;    It clears bit 5 of the ASCII code.
;    'a'(97) AND 0DFh = 'A'(65).  Safe to apply only after confirming it's a letter.
; ================================================================
ParseHex PROC
    push ax
    push bx
    push cx
    push si

    mov numVal, 0
    mov validFlag, 1
    mov si, OFFSET inBuf + 2
    mov cl, [inBuf + 1]
    mov ch, 0

PH_Loop:
    cmp cx, 0
    je  PH_Done

    mov al, [si]              

    ; Is it a decimal digit?
    cmp al, '0'
    jl  PH_IsLetter           ; below '0' → must be a letter
    cmp al, '9'
    jg  PH_IsLetter           ; above '9' → must be a letter
    sub al, '0'               ; '0'→0, '9'→9
    jmp PH_GotNibble

PH_IsLetter:
    and al, 0DFh              ; force to uppercase (clears bit 5 of ASCII)
    cmp al, 'A'
    jl  PH_Invalid   ; ← below 'A'? REJECTED
    cmp al, 'F'
    jg  PH_Invalid
    sub al, 'A'               ; 'A'→0, 'B'→1, ... 'F'→5
    add al, 10                ; → 10, 11, ... 15
    jmp PH_GotNibble

PH_Invalid:
    mov numVal, 0    ; clear result
    mov validFlag, 0 ; signal bad input
    jmp PH_Done

PH_GotNibble:
    mov ah, 0                 ; AX = nibble value (0 to 15)
    mov bx, numVal
    ; SHL 4 times = shift left 4 bits = multiply by 16
    shl bx, 1
    shl bx, 1
    shl bx, 1
    shl bx, 1
    or  bx, ax                
    mov numVal, bx

    inc si
    dec cx
jmp PH_Loop

PH_Done:
    pop si
    pop cx
    pop bx
    pop ax
    ret
ParseHex ENDP

DecToBin PROC
    push ax
    push bx
    push dx
    push si
    push di

    call ClearOutBuf
    mov di, OFFSET outBuf  ; DI = write pointer into outBuf
    mov bx, numVal         ; BX = the number to convert
    mov dx, 8000h          ; DX = bit mask (bit 15 = 1000 0000 0000 0000)
    mov si, 0              ; SI = started flag: 0 = haven't written any '1' yet

    cmp bx, 0
    jne DTB_BitLoop
    mov BYTE PTR [di], '0' ; special case: value is 0, just write "0"
    jmp DTB_Done

DTB_BitLoop:
    cmp dx, 0              ; have we processed all 16 bits?
    je  DTB_Done

    mov ax, bx
    and ax, dx             ; isolate current bit: AX = numVal AND mask
    jnz DTB_ItsOne         ; if result is not zero, this bit is 1

    ; Current bit is 0
    cmp si, 1              ; have we written any '1' yet?
    jne DTB_NextBit        ; no → this is a leading zero, skip it
    mov al, '0'
    mov [di], al           
    inc di
    jmp DTB_NextBit

DTB_ItsOne:
    mov al, '1'
    mov [di], al           ; write '1' to outBuf
    inc di
    mov si, 1              ; mark that output has started (no more skipping)

DTB_NextBit:
    shr dx, 1              ; shift mask right to check the next lower bit
    jmp DTB_BitLoop

DTB_Done:
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    ret
DecToBin ENDP

; ================================================================
;  Strategy: extract nibbles from LOW to HIGH (using AND 0Fh + SHR)
;  Store in tmpBuf (they come out in reverse order),
;  then write tmpBuf in reverse into outBuf (correct order).
; ================================================================
DecToHex PROC
    push ax
    push bx
    push cx
    push si
    push di

    call ClearOutBuf
    mov di, OFFSET outBuf
    mov bx, numVal
    mov si, OFFSET tmpBuf  ; SI → temp buffer (stores digits low→high)
    mov cx, 0              ; CX = count of hex digits found

    cmp bx, 0
    jne DTH_ExtractLoop
    mov BYTE PTR [di], '0' 
    jmp DTH_Done

DTH_ExtractLoop:
    cmp bx, 0              ; keep going as long as BX has value left
    je  DTH_Reverse

    mov ax, bx
    and ax, 000Fh          ; isolate the lowest 4 bits (one nibble = 0 to 15)

    cmp al, 9              
    jbe DTH_IsDigit
    add al, 7              ; adjust for letters: 10→'A' (since 10+7+'0'=65='A')
DTH_IsDigit:
    add al, '0'            
    mov [si], al           
    inc si
    inc cx                 

    ; Shift BX right 4 bits to bring the next nibble into the lowest position
    shr bx, 1
    shr bx, 1
    shr bx, 1
    shr bx, 1
jmp DTH_ExtractLoop

DTH_Reverse:
    dec si                 
DTH_RevLoop:
    mov al, [si]           
    mov [di], al           
    inc di
    dec si
    dec cx
jnz DTH_RevLoop        ; continue until all digits are written

DTH_Done:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret
DecToHex ENDP

;  Strategy: divide numVal by 10 repeatedly.
;    Each division gives a remainder = one decimal digit.
;    But remainders come out in REVERSE order (least significant first),
;    so store them in tmpBuf then write them out in reverse.
NumToDecStr PROC
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    call ClearOutBuf
    mov di, OFFSET outBuf
    mov ax, numVal         
    mov si, OFFSET tmpBuf  
    mov cx, 0              ; CX = digit count

    cmp ax, 0
    jne NTD_DivLoop
    mov BYTE PTR [di], '0' ; special case: value is 0
    jmp NTD_Done

NTD_DivLoop:
    cmp ax, 0              ; keep dividing until nothing left
    je  NTD_Reverse
    mov dx, 0              ; DX:AX is the dividend; DX must be 0
    mov bx, 10
    div bx                 ; AX = AX / 10 (quotient), DX = remainder (the digit)
    add dl, '0'            ; convert remainder digit to ASCII
    mov [si], dl           ; store in temp buffer
    inc si
    inc cx                 ; count this digit
jmp NTD_DivLoop

NTD_Reverse:
    dec si                 
NTD_RevLoop:
    mov al, [si]           
    mov [di], al           
    inc di
    dec si
    dec cx
jnz NTD_RevLoop

NTD_Done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
NumToDecStr ENDP

END main
