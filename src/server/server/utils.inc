
.data
_random_seed dword 0
_random_a1 dword 1664525
_random_a0 dword 1013904223

.code

_GetRandomIndex proc _maxValue: BYTE
    local performanceCount : QWORD
    
    push ebx
    push edx

    invoke QueryPerformanceCounter, ADDR performanceCount
    mov ebx, DWORD PTR performanceCount

    mov ax, bx
    mov ah,0 
    mov bl, _maxValue
    div bl
    mov al,ah 
    mov ah, 0

    movzx eax, ax

    pop edx
    pop ebx
    ret
_GetRandomIndex endp

_GetPseudoRandomIndex proc _maxValue: BYTE
    push ebx
    push edx
    
    mov eax, _random_seed
    mov ebx, _random_a1
    mul ebx
    add eax, _random_a0
    mov _random_seed, eax
    mov ebx, _random_seed

    mov ax, bx
    mov ah,0 
    mov bl, _maxValue
    div bl
    mov al,ah 
    mov ah, 0

    movzx eax, ax

    pop edx
    pop ebx
    ret
_GetPseudoRandomIndex endp


.data?

_NumbToStrBuff        db 11 dup(?)        ; the maximum unsigned number
                                ; stored by a DWORD = 4294967295 ( 10 chars )
                                ; size of the buffer = 10 + 1
                                ; the last character is the NULL terminator
.code
NumbToStr PROC uses ebx x:DWORD,buffer:DWORD

    mov     ecx,buffer
    mov     eax,x
    mov     ebx,10
    add     ecx,ebx             ; ecx = buffer + max size of string
@loop:
    xor     edx,edx
    div     ebx
    add     edx,48              ; convert the digit to ASCII
    mov     BYTE PTR [ecx],dl   ; store the character in the buffer
    dec     ecx                 ; decrement ecx pointing the buffer
    test    eax,eax             ; check if the quotient is 0
    jnz     @loop

    inc     ecx
    mov     eax,ecx             ; eax points the string in the buffer
    ret

NumbToStr ENDP