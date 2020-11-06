.data

; 绘制地图坐标、大小信息
_blockSideLength EQU 40
_mapOffsetX EQU 20
_mapOffsetY EQU 20

; 地图大小 20 * 10
_mapHeight EQU 20
_mapWidth EQU 10
_map dword 200 dup(0)	; 存储颜色，0 表示空

; 当前方块、颜色、旋转状态、位置
_currentBlock dword -1
_currentColor dword 1
_currentStatus dword 0
_currentPosI dword -2
_currentPosJ dword 3

; 下一个方块、颜色
_nextBlock dword 1
_nextColor dword 1

.const 

; 7 种形状的 4 种旋转状态（顺时针）
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

; 7 种形状的初始位置
_blockInitPos	dword	-2,3; I
				dword	0,4;J
				dword	0,4;L
				dword	0,4;O
				dword	0,4;S
				dword	0,4;T
				dword	0,4;Z

.code

; 获取 map[i][j]
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

; 绘制 map[i][j]
_DrawSquare proc _hDC, _i, _j, _color
	
	; 注意负数的判断，>=0 的判断是无意义的，但是由于下溢，负数不满足 <= 那个条件
	.if (_i>=0) && (_i<_mapHeight) && (_j>=0) && (_j<_mapWidth)	
		pushad

		; TODO 选择颜色
		.if _color==0
			invoke	GetStockObject,BLACK_BRUSH
		.else
			invoke	GetStockObject,WHITE_BRUSH
		.endif

		invoke	SelectObject,_hDC, eax
		invoke	DeleteObject, eax

		;准备 left, top, right, bottom
		mov eax, _i
		mov ecx, _blockSideLength
		mul ecx
		mov ebx, eax
		add ebx, _mapOffsetY
		mov eax, _j
		mul ecx
		add eax, _mapOffsetY
		mov ecx, eax
		add ecx, _blockSideLength
		mov edx, ebx
		add edx, _blockSideLength

		; TODO: 绘制位图
		invoke	Rectangle, _hDC, eax, ebx, ecx, edx

		popad
	.endif
	ret
_DrawSquare endp

; 判断某一形状的某一状态在某一位置是否合法，就是有没有跟别的重叠
_PositionValid proc _block, @status, _posI, _posJ
	local	@i

	pushad

	mov eax, _block
	mov ecx, 4
	mul ecx
	add eax, @status
	mov ecx, 8
	mul ecx
	; 此时 eax 指向 blockOffset 中指定形状的指定状态

	mov @i, 0
	.while @i < 4
		mov ecx, _posI
		add ecx, _blockOffset[eax * 4]
		add eax, 1
		mov edx, _posJ
		add edx, _blockOffset[eax * 4]
		add eax, 1
		;(ecx, edx) 目标检查位置

		;注意负数的判断，>=0 的判断是无意义的，但是由于下溢，负数不满足 <= 那个条件
		.if (ecx>=_mapHeight) || (ecx<0) || (edx<0) || (edx>=_mapWidth)
			jmp _PositionValidFail
		.endif
		
		push eax	; 乘法修改 eax
		push edx	; 乘法修改 edx

		mov eax, ecx
		mov esi, _mapWidth
		mul esi
		pop edx		; 乘法修改 edx
		add eax, edx
		mov ebx, _map[eax*4] ; eax = ecx*_mapWidth + edx
		pop eax		; 乘法修改 eax

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

; 给 map 上的位置赋值
; 假设位置合法，也就是满足 _PositionValid 的判断
_WriteMap proc _block, @status, _posI, _posJ, _color
	local	@i

	pushad

	mov eax, _block
	mov ecx, 4
	mul ecx
	add eax, @status
	mov ecx, 8
	mul ecx
	; 此时 eax 指向 blockOffset 中指定形状的指定状态

	mov @i, 0
	.while @i < 4
		mov ecx, _posI
		add ecx, _blockOffset[eax * 4]
		add eax, 1
		mov edx, _posJ
		add edx, _blockOffset[eax * 4]
		add eax, 1
		;(ecx, edx) 目标修改位置
		
		push eax	; 乘法修改 eax
		push edx	; 乘法修改 edx

		mov eax, ecx
		mov esi, _mapWidth
		mul esi
		pop edx		; 乘法修改 edx
		add eax, edx
		
		mov ebx, _color
		mov _map[eax*4], ebx ; eax = ecx*_mapWidth + edx

		pop eax		; 乘法修改 eax
		inc @i
	.endw

	popad 
	ret
_WriteMap endp

; 尝试移动当前块
_TryMove proc _deltaI, _deltaJ
	push ebx
	push ecx

	mov ecx, _deltaI
	add ecx, _currentPosI
	mov ebx, _deltaJ
	add ebx, _currentPosJ
	;(ecx, ebx) 期望目的位置

	invoke _PositionValid, _currentBlock, _currentStatus, ecx, ebx

	.if eax!=0
		; 成功
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

;  尝试旋转当前块
_TryChangeStatus proc
	push ecx
	mov ecx, _currentStatus
	inc ecx
	.if ecx>=4
		sub ecx, 4
	.endif

	invoke _PositionValid, _currentBlock, ecx, _currentPosI, _currentPosJ

	.if eax != 0
		; 成功
		mov _currentStatus, ecx
		mov eax, 1
	.else
		mov eax, 0
	.endif

	pop ecx
	ret
_TryChangeStatus endp



.data 

_readyNext dd 1					; 当前块已经固定，可以切换到操作下一个块


_sinceLastMoveDown dd 0			; 距离上一次当前块下移已经过去了多少个单位时间
_moveDownInternal dd 50			; 当前块下移的时间间隔

_scores dd 0					; 分数

.code

; 尝试消去满行
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
		mov esi, eax ; @i 行开头（从下往上扫）
		push esi

		mov eax, 1

		; 遍历一遍当前行，判断是否填满
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
			; 未满则保留
			mov eax, @j
			mov ebx, _mapWidth
			mul ebx
			mov edi, eax ; @j行开头

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
			; 消去加分
			add _scores, 100 
		.endif

		dec @i
	.endw
	
	; 剩余的全部为空
	.while @j != -1
		mov eax, @j
		mov ebx, _mapWidth
		mul ebx
		mov edi, eax ; @j行开头

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