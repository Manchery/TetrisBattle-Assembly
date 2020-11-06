
.data
_random_seed dword 0
_random_a1 dword 1812433253
_random_a0 dword 1812433253

.code

_GetRandomIndex proc _maxValue: BYTE
    local performanceCount : QWORD
    
    push ebx
    push edx

    invoke QueryPerformanceCounter, ADDR performanceCount
    mov ebx, DWORD PTR performanceCount
    
    ;mov eax, _random_seed
    ;mov ebx, _random_a1
    ;mul eax
    ;add eax, _random_a0
    ;mov _random_seed, eax

    ;mov ebx, _random_seed

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