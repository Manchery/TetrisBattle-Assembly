include		draw.inc
include		utils.inc

.data

; ���Ƶ�ͼ���ꡢ��С��Ϣ
_blockSideLength EQU 40
_mapOffsetX EQU 100
_mapOffsetY EQU 82

_nextOffsetX EQU 480
_nextOffsetY EQU 130

; ��ͼ��С 20 * 10
_mapHeight EQU 20
_mapWidth EQU 10
_map dword 200 dup(0)	; �洢��ɫ��0 ��ʾ��

; ��ǰ���顢��ɫ����ת״̬��λ��
_currentBlock dword -1
_currentColor dword 0
_currentStatus dword 0
_currentPosI dword 0
_currentPosJ dword 0

; TODO: init block random
; ��һ�����顢��ɫ
_nextBlock dword 0
_nextColor dword 0
_nextPosI dword 0
_nextPosJ dword 0
_nextStatus dword 0

.const 

; 7 ����״�� 4 ����ת״̬��˳ʱ�룩
_blockOffset	dword	2,0, 2,1, 2,2, 2,3 ;I
				dword	0,2, 1,2, 2,2, 3,2
				dword	2,0, 2,1, 2,2, 2,3
				dword	0,1, 1,1, 2,1, 3,1

				dword	0,0, 1,0, 1,1, 1,2 ;J
				dword	0,1, 0,2, 1,1, 2,1
				dword	1,0, 1,1, 1,2, 2,2
				dword	0,1, 1,1, 2,0, 2,1

				dword	0,2, 1,0, 1,1, 1,2;L
				dword	0,1, 1,1, 2,1, 2,2
				dword	1,0, 1,1, 1,2, 2,0
				dword	0,0, 0,1, 1,1, 2,1

				dword	0,0, 0,1, 1,0, 1,1;O
				dword	0,0, 0,1, 1,0, 1,1
				dword	0,0, 0,1, 1,0, 1,1
				dword	0,0, 0,1, 1,0, 1,1

				dword	0,1, 0,2, 1,0, 1,1;S
				dword	0,1, 1,1, 1,2, 2,2
				dword	1,1, 1,2, 2,0, 2,1
				dword	0,0, 1,0, 1,1, 2,1

				dword	0,1, 1,0, 1,1, 1,2;T
				dword	0,1, 1,1, 1,2, 2,1
				dword	1,0, 1,1, 1,2, 2,1
				dword	0,1, 1,0, 1,1, 2,1

				dword	0,0, 0,1, 1,1, 1,2;Z
				dword	0,2, 1,1, 1,2, 2,1
				dword	1,0, 1,1, 2,1, 2,2
				dword	0,1, 1,0, 1,1, 2,0

; 7 ����״�ĳ�ʼλ��
_blockInitPos	dword	-2,3; I
				dword	0,4;J
				dword	0,4;L
				dword	0,4;O
				dword	0,4;S
				dword	0,4;T
				dword	0,4;Z

.code

; ��ȡ map[i][j]
_GetMap proc _i,_j
	push ecx
	mov eax, _i
	mov ecx, _mapWidth
	mul ecx
	mov ecx, _j
	add eax, ecx	
	
	mov eax, _map[eax*4]	; eax = width * i + j
	pop ecx
	ret
_GetMap endp

; ���� map[i][j]
_DrawSquare proc _hDC, _i, _j, _color, _offsetX, _offsetY
	local @hDcSquare

	; ע�⸺�����жϣ�>=0 ���ж���������ģ������������磬���������� <= �Ǹ�����
	.if (_i>=0) && (_i<_mapHeight) && (_j>=0) && (_j<_mapWidth)	
		pushad

		invoke	CreateCompatibleDC,_hDC; ������_hDC���ݵ���һ��DC(�豸������)���Ա���������
		mov		@hDcSquare, eax
		invoke	SelectObject, @hDcSquare, _square

		;׼�� left, top, right, bottom
		mov eax, _i
		mov ecx, _blockSideLength
		mul ecx
		mov ebx, eax
		add ebx, _offsetY
		mov eax, _j
		mul ecx
		add eax, _offsetX

		; TODO: ����λͼ
		;invoke	Rectangle, _hDC, eax, ebx, ecx, edx

		dec _color
		; TODO ѡ����ɫ
		.if _color!=-1
			push eax
			
			mov ecx, 60 
			mov eax, _color
			mul ecx
			mov ecx, eax

			pop eax
			invoke	BitBlt,_hDC, eax, ebx, _blockSideLength, _blockSideLength, @hDcSquare, ecx, 0, SRCCOPY
		.endif

		invoke	DeleteDC, @hDcSquare
		popad
	.endif
	ret
_DrawSquare endp

; �ж�ĳһ��״��ĳһ״̬��ĳһλ���Ƿ�Ϸ���������û�и�����ص�
_PositionValid proc _block, @status, _posI, _posJ
	local	@i

	pushad

	mov eax, _block
	mov ecx, 4
	mul ecx
	add eax, @status
	mov ecx, 8
	mul ecx
	; ��ʱ eax ָ�� blockOffset ��ָ����״��ָ��״̬

	mov @i, 0
	.while @i < 4
		mov ecx, _posI
		add ecx, _blockOffset[eax * 4]
		add eax, 1
		mov edx, _posJ
		add edx, _blockOffset[eax * 4]
		add eax, 1
		;(ecx, edx) Ŀ����λ��

		;ע�⸺�����жϣ�>=0 ���ж���������ģ������������磬���������� <= �Ǹ�����
		.if (ecx>=_mapHeight) || (ecx<0) || (edx<0) || (edx>=_mapWidth)
			jmp _PositionValidFail
		.endif
		
		push eax	; �˷��޸� eax
		push edx	; �˷��޸� edx

		mov eax, ecx
		mov esi, _mapWidth
		mul esi
		pop edx		; �˷��޸� edx
		add eax, edx
		mov ebx, _map[eax*4] ; eax = ecx*_mapWidth + edx
		pop eax		; �˷��޸� eax

		.if (ebx!=0)
			jmp _PositionValidFail
		.endif
		
		inc @i
	.endw

	popad 
	mov eax, 1
	ret

_PositionValidFail:
	popad 
	mov eax, 0
	ret
_PositionValid endp

; �� map �ϵ�λ�ø�ֵ
; ����λ�úϷ���Ҳ�������� _PositionValid ���ж�
_WriteMap proc _block, @status, _posI, _posJ, _color
	local	@i

	pushad

	mov eax, _block
	mov ecx, 4
	mul ecx
	add eax, @status
	mov ecx, 8
	mul ecx
	; ��ʱ eax ָ�� blockOffset ��ָ����״��ָ��״̬

	mov @i, 0
	.while @i < 4
		mov ecx, _posI
		add ecx, _blockOffset[eax * 4]
		add eax, 1
		mov edx, _posJ
		add edx, _blockOffset[eax * 4]
		add eax, 1
		;(ecx, edx) Ŀ���޸�λ��
		
		push eax	; �˷��޸� eax
		push edx	; �˷��޸� edx

		mov eax, ecx
		mov esi, _mapWidth
		mul esi
		pop edx		; �˷��޸� edx
		add eax, edx
		
		mov ebx, _color
		mov _map[eax*4], ebx ; eax = ecx*_mapWidth + edx

		pop eax		; �˷��޸� eax
		inc @i
	.endw

	popad 
	ret
_WriteMap endp

; �����ƶ���ǰ��
_TryMove proc _deltaI, _deltaJ
	push ebx
	push ecx

	mov ecx, _deltaI
	add ecx, _currentPosI
	mov ebx, _deltaJ
	add ebx, _currentPosJ
	;(ecx, ebx) ����Ŀ��λ��

	invoke _PositionValid, _currentBlock, _currentStatus, ecx, ebx

	.if eax!=0
		; �ɹ�
		mov _currentPosI, ecx
		mov _currentPosJ, ebx
		mov eax, 1
	.else
		mov eax, 0
	.endif

	pop ecx
	pop ebx
	ret
_TryMove endp

;  ������ת��ǰ��
_TryChangeStatus proc
	push ecx
	mov ecx, _currentStatus
	inc ecx
	.if ecx>=4
		sub ecx, 4
	.endif

	invoke _PositionValid, _currentBlock, ecx, _currentPosI, _currentPosJ

	.if eax != 0
		; �ɹ�
		mov _currentStatus, ecx
		mov eax, 1
	.else
		mov eax, 0
	.endif

	pop ecx
	ret
_TryChangeStatus endp



.data 

_readyNext dd 1					; ��ǰ���Ѿ��̶��������л���������һ����


_sinceLastMoveDown dd 0			; ������һ�ε�ǰ�������Ѿ���ȥ�˶��ٸ���λʱ��
_moveDownInternal dd 50			; ��ǰ�����Ƶ�ʱ����

_scores dd 0					; ����

.code

; ������ȥ����
_ReduceLines proc 
	local @i, @j, @k

	pushad

	mov @i, _mapHeight
	dec @i
	mov @j, _mapHeight
	dec @j

	.while @i != -1
		mov eax, @i
		mov ebx, _mapWidth
		mul ebx
		mov esi, eax ; @i �п�ͷ����������ɨ��
		push esi

		mov eax, 1

		; ����һ�鵱ǰ�У��ж��Ƿ�����
		mov @k, 0
		.while @k < _mapWidth
			mov ebx, _map[esi * 4]
			.if ebx==0
				mov eax, 0
				.break
			.endif
			inc @k
			inc esi
		.endw

		pop esi
		
		.if eax!=1
			; δ������
			mov eax, @j
			mov ebx, _mapWidth
			mul ebx
			mov edi, eax ; @j�п�ͷ

			.if esi!=edi
				mov @k, 0
				.while @k < _mapWidth
					mov ebx, _map[esi * 4]
					mov _map[edi * 4], ebx
					inc @k
					inc esi
					inc edi
				.endw
			.endif

			dec @j
		.else
			; ��ȥ�ӷ�
			add _scores, 100 
		.endif

		dec @i
	.endw
	
	; ʣ���ȫ��Ϊ��
	.while @j != -1
		mov eax, @j
		mov ebx, _mapWidth
		mul ebx
		mov edi, eax ; @j�п�ͷ

		mov @k, 0
		.while @k < _mapWidth
			mov _map[edi * 4], 0
			inc @k
			inc edi
		.endw

		dec @j
	.endw

	popad
	ret
_ReduceLines endp


_GetNextBlock proc
	push eax
	push ebx

	invoke _GetRandomIndex, 7
	mov _nextBlock, eax
	invoke _GetRandomIndex, 8
	mov _nextColor, eax
	inc _nextColor

	mov ebx, _nextBlock
	mov eax, _blockInitPos[ebx * 8]
	mov _nextPosI, eax
	mov eax, _blockInitPos[ebx * 8 + 4]
	mov _nextPosJ, eax

	mov _nextStatus, 0

	pop ebx
	pop eax

	ret
_GetNextBlock endp