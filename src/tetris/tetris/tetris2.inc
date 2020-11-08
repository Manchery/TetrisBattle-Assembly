include		draw.inc
include		utils.inc

.data

; 绘制地图坐标、大小信息
_blockSideLength EQU 40
_mapOffsetX EQU 100
_mapOffsetY EQU 82

_nextOffsetX EQU 480
_nextOffsetY EQU 130

; 地图大小 20 * 10
_mapHeight EQU 20
_mapWidth EQU 10
_map dword 200 dup(0)	; 存储颜色，0 表示空

; 当前方块、颜色、旋转状态、位置
_currentBlock dword -1
_currentColor dword 0
_currentStatus dword 0
_currentPosI dword 0
_currentPosJ dword 0

; TODO: init block random
; 下一个方块、颜色
_nextBlock dword 0
_nextColor dword 0
_nextPosI dword 0
_nextPosJ dword 0
_nextStatus dword 0

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

				dword	0,0, 0,2, 2,0, 2,2; special 1
				dword	0,0, 0,2, 2,0, 2,2
				dword	0,0, 0,2, 2,0, 2,2
				dword	0,0, 0,2, 2,0, 2,2

				dword	0,1, 1,0, 1,2, 2,1; special 2
				dword	0,1, 1,0, 1,2, 2,1
				dword	0,1, 1,0, 1,2, 2,1
				dword	0,1, 1,0, 1,2, 2,1

				dword	0,1, 1,2, 2,1, 3,2; special 3
				dword	2,0, 1,1, 2,2, 1,3
				dword	0,1, 1,2, 2,1, 3,2
				dword	2,0, 1,1, 2,2, 1,3

; 7 种形状的初始位置
_blockInitPos	dword	-2,3; I
				dword	0,4;J
				dword	0,4;L
				dword	0,4;O
				dword	0,4;S
				dword	0,4;T
				dword	0,4;Z
				dword	0,3;special 1
				dword	0,3;special 1
				dword	0,3;special 1

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
_DrawSquare proc _hDC, _i, _j, _color, _offsetX, _offsetY
	local @hDcSquare

	; 注意负数的判断，>=0 的判断是无意义的，但是由于下溢，负数不满足 <= 那个条件
	.if (_i>=0) && (_i<_mapHeight) && (_j>=0) && (_j<_mapWidth)	
		pushad

		invoke	CreateCompatibleDC,_hDC; 创建与_hDC兼容的另一个DC(设备上下文)，以备后续操作
		mov		@hDcSquare, eax
		invoke	SelectObject, @hDcSquare, _square

		;准备 left, top, right, bottom
		mov eax, _i
		mov ecx, _blockSideLength
		mul ecx
		mov ebx, eax
		add ebx, _offsetY
		mov eax, _j
		mul ecx
		add eax, _offsetX

		; TODO: 绘制位图
		;invoke	Rectangle, _hDC, eax, ebx, ecx, edx

		dec _color
		; TODO 选择颜色
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

.data
_playerRemain dword 0
WINDOW_WIDTH  equ 1200
WINDOW_HEIGHT equ 960
.code

_DrawOtherMap proc _hDC, @map, _offsetX, _offsetY, _sideLength
	local @hDc, @hBmp, @brush
	local @i, @j
	pushad

	invoke	CreateCompatibleDC, _hDC
	mov		@hDc, eax
	invoke	CreateCompatibleBitmap, _hDC, WINDOW_WIDTH, WINDOW_HEIGHT 
	mov		@hBmp, eax
	invoke	SelectObject, @hDc, @hBmp

	invoke	GetStockObject, GRAY_BRUSH
	mov		@brush, eax
	invoke	SelectObject, @hDc, eax

	mov esi, @map

	mov @i, 0
	.while @i<20
		mov @j, 0
		.while @j<10
			
			mov eax, @i
			mov ecx, 20
			mul ecx
			add eax, @j

			mov dl, [esi]

			.if dl != 0
				
				mov eax, @i
				mov ecx, _sideLength
				mul ecx
				mov ebx, eax
				add ebx, _offsetY
				mov eax, @j
				mul ecx
				add eax, _offsetX
				mov ecx, eax
				add ecx, _sideLength
				mov edx, ebx
				add edx, _sideLength

				invoke	Rectangle, @hDc, eax, ebx, ecx, edx
			.endif

			inc @j
			inc esi
		.endw
		inc @i
	.endw

	invoke	TransparentBlt, _hDC,0,0,WINDOW_WIDTH,WINDOW_HEIGHT,\
	@hDc,0,0,WINDOW_WIDTH,WINDOW_HEIGHT,0;过滤黑色，只把灰色砖块贴到hDC上
	
	invoke	DeleteObject, @brush
	invoke	DeleteObject, @hBmp
	invoke	DeleteDC, @hDc
	popad
	ret
_DrawOtherMap endp



_DrawBlackScreen proc _hDC
	local @hDcBlackScreen
	pushad

	invoke	CreateCompatibleDC,_hDC; 创建与_hDC兼容的另一个DC(设备上下文)，以备后续操作
	mov		@hDcBlackScreen, eax
	invoke	SelectObject, @hDcBlackScreen, _laugh

	invoke	TransparentBlt, _hDC, 30, 300, 550, 550 , @hDcBlackScreen, 0, 0, 396, 400 , 0FFFFFFh

	invoke	DeleteDC, @hDcBlackScreen
	popad
	ret
_DrawBlackScreen endp

_DrawPause proc _hDC
	local @hDcPause
	pushad

	invoke	CreateCompatibleDC,_hDC; 创建与_hDC兼容的另一个DC(设备上下文)，以备后续操作
	mov		@hDcPause, eax
	invoke	SelectObject, @hDcPause, _stop

	invoke	BitBlt, _hDC, 271, 226, 712, 371 , @hDcPause, 0, 0, SRCCOPY
	
	invoke	DeleteDC, @hDcPause
	popad
	ret
_DrawPause endp

_DrawGameOverSingle proc _hDC
	local @hDcPause
	pushad

	invoke	CreateCompatibleDC,_hDC; 创建与_hDC兼容的另一个DC(设备上下文)，以备后续操作
	mov		@hDcPause, eax
	invoke	SelectObject, @hDcPause, _singleOverBox

	invoke	BitBlt, _hDC, 271, 226, 712, 371 , @hDcPause, 0, 0, SRCCOPY
	
	invoke	DeleteDC, @hDcPause
	popad
	ret
_DrawGameOverSingle endp

.data
_debug byte '1233', 0

.code

_DrawNumber	proc _hDC, _destX, _destY, _number, _fontH, _fontW
		local @textBmp, @hDcText, @font, @textRgn:RECT
		local @str, @len
		pushad
		invoke	CreateCompatibleDC,_hDC;创建文字图层DC
		mov		@hDcText, eax

		;Parameters of CreateFont:
		;https://docs.microsoft.com/en-us/cpp/mfc/reference/cfont-class?view=msvc-160#createfont
		
		invoke	MultiByteToWideChar, CP_UTF8, 0, offset _fontName, -1, offset _fontNameW, 64;

		invoke	CreateFont, _fontH , _fontW , 0 , 0 , 1000 , 0 , 0 , 0\
				,OEM_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS\
				,DEFAULT_QUALITY,DEFAULT_PITCH or FF_SCRIPT, ADDR _fontNameW
		mov		@font, eax
		invoke	SelectObject,@hDcText,eax;把指向字体的句柄放入设备环境


		invoke	CreateCompatibleBitmap, _hDC, 800, 400;创建文字图层图片
		mov		@textBmp, eax
		invoke	SelectObject, @hDcText, @textBmp;绑定BMP和DC
		mov		@textRgn.left, 0
		mov		@textRgn.top, 0
		mov		@textRgn.right, 800
		mov		@textRgn.bottom, 400
		invoke	InvertRect,@hDcText,addr @textRgn;把背景设为全白

		invoke NumbToStr, _number, OFFSET _NumbToStrBuff
		mov @str, eax
		mov @len, OFFSET _NumbToStrBuff
		add @len, 10
		sub @len, eax
		inc @len

		invoke  TextOutA, @hDcText, 0, 0, @str, @len ;在DC上写文字
		invoke	TransparentBlt,_hDC,_destX,_destY,800,400,\
		@hDcText,0,0,800,400,0FFFFFFh;过滤白色，只把文字图层的黑色(文字)贴到hDC上
		invoke	DeleteObject, @textBmp
		invoke	DeleteDC, @hDcText
		invoke	DeleteObject, @font
		popad
		ret
_DrawNumber endp

_DrawGameOverMultiple proc _hDC, _rank
	local @hDcPause
	pushad

	invoke	CreateCompatibleDC,_hDC; 创建与_hDC兼容的另一个DC(设备上下文)，以备后续操作
	mov		@hDcPause, eax
	invoke	SelectObject, @hDcPause, _mulOverBox

	invoke	BitBlt, _hDC, 120, 320, 356, 186 , @hDcPause, 0, 0, SRCCOPY
	invoke _DrawNumber, _hDC, 120+220, 320+85, _rank, 80, 36
	
	invoke	DeleteDC, @hDcPause
	popad
	ret
_DrawGameOverMultiple endp

_DrawBombPic proc _hDC
	local @hDcBombPic
	pushad

	invoke	CreateCompatibleDC,_hDC; 创建与_hDC兼容的另一个DC(设备上下文)，以备后续操作
	mov		@hDcBombPic, eax
	invoke	SelectObject, @hDcBombPic, _boomPic

	invoke	TransparentBlt, _hDC, 350, 90, 136, 159 , @hDcBombPic, 0, 0, 136, 159 , 0FFFFFFh

	invoke	DeleteDC, @hDcBombPic
	popad
	ret
_DrawBombPic endp

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

_slowingRemain dword 0				; 减慢剩余块数
_slowingMoveDownInternal dword 0	; 减慢时的速度

_sinceSendMap dd 0	
_sendMapInternal dd 200

_tools dword 0, 0, 1

_othermap byte 800 dup(0)

.code

; 初始化一局游戏
_InitGameStatus proc
	local @i
	push eax

	mov @i, 0
	.while @i<200
		mov eax, @i
		mov _map[eax*4], 0
		inc @i
	.endw

	mov @i, 0
	.while @i<800
		mov eax, @i
		mov _othermap[eax], 0
		inc @i
	.endw

	mov _currentBlock, -1
	mov _currentColor, 0
	mov _currentStatus, 0
	mov _currentPosI, 0
	mov _currentPosJ, 0

	mov _nextBlock, 0
	mov _nextColor, 0
	mov _nextPosI, 0
	mov _nextPosJ, 0
	mov _nextStatus, 0

	mov _readyNext, 1	
	mov _sinceLastMoveDown, 0	
	mov _moveDownInternal, 50	

	mov _scores, 0			
	mov _slowingRemain, 0				
	mov	_slowingMoveDownInternal, 0

	mov _tools[0], 0
	mov _tools[4], 0
	mov _tools[8], 0
	invoke _GetRandomIndex, 3
	inc _tools[eax*4]

	mov _blackScreeningRemain, 0
	mov _bombPicRemain, 0
	mov _specialBlockRemain, 0
	mov _paused, 0
	mov _gameover, 0

	mov _sinceSendMap, 0	
	mov _sendMapInternal, 200

	mov _playerRemain, 0
	mov _mulrank, 0

	pop eax
	ret
_InitGameStatus endp

; 尝试消去满行
; _force：强制消掉底下若干行
_ReduceLines proc _force
	local @i, @j, @k, @lines

	mov @lines, 0

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
		
		.if (_force==0) && (eax!=1)
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
			; 消去一行
			inc @lines 
			.if _force>0
				dec _force
			.endif
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
	mov eax, @lines
	ret
_ReduceLines endp

_UpdateMoveDownInternal proc
	.if _scores < 50
		mov _moveDownInternal, 50
	.elseif _scores < 100
		mov _moveDownInternal, 45
	.elseif _scores < 150
		mov _moveDownInternal, 40
	.elseif _scores < 200
		mov _moveDownInternal, 35
	.elseif _scores < 250
		mov _moveDownInternal, 30
	.elseif _scores < 300
		mov _moveDownInternal, 25
	.elseif _scores < 350
		mov _moveDownInternal, 20
	.elseif _scores < 400
		mov _moveDownInternal, 15
	.else
		mov _moveDownInternal, 10
	.endif
	ret
_UpdateMoveDownInternal endp

.data 

_blackScreeningRemain dword 0
_bombPicRemain dword 0
_specialBlockRemain dword 0

_bombProb EQU 20

_paused dword 0
_gameover dword 0

_mulrank dword 0

.code

_Bomb proc
	local @i
	pushad
	
	mov @i, 0 
	.while @i<200
		mov esi, @i
		.if _map[esi*4]!=0
			invoke _GetPseudoRandomIndex, 100
			.if eax < _bombProb
				mov _map[esi*4], 0
			.endif
		.endif
		inc @i
	.endw

	popad
	ret
_Bomb endp


_GetNextBlock proc
	push eax
	push ebx

	.if _specialBlockRemain==0
		invoke _GetRandomIndex, 7
		mov _nextBlock, eax
	.elseif
		invoke _GetRandomIndex, 3
		add eax, 7
		mov _nextBlock, eax
		dec _specialBlockRemain
	.endif
	
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