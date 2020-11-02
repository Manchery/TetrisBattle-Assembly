;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Sample code for < Win32ASM Programming 2nd Edition>
; by 罗云彬, http://asm.yeah.net
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Clock.asm
; 时钟例子：使用 GDI 函数绘画指针
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 使用 nmake 或下列命令进行编译和链接:
; ml /c /coff Clock.asm
; rc Clock.rc
; Link /subsystem:windows Clock.obj Clock.res
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.386
		.model flat, stdcall
		option casemap :none
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Include 文件定义
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
include		windows.inc
include		user32.inc
includelib	user32.lib
include		kernel32.inc
includelib	kernel32.lib
include		Gdi32.inc
includelib	Gdi32.lib
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Equ 等值定义
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ICO_MAIN				equ		1000h
ID_TIMER				equ		1
WINDOW_WIDTH			equ		1200
WINDOW_HEIGHT			equ		960
TIMER_MAIN_INTERVAL		equ		10;ms
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; TODO 如果添加了新资源标识符，请从resource.h将其*复制*到此处。
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDB_BITMAP_TEST         equ	    101

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 数据段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 结构体定义(注意对齐，或总是使用DWORD)
KeyState	struct	;KeyState可识别上下左右、空格、ESC、数字1~6
	up		dword	0
	down	dword	0
	left	dword	0
	right	dword	0
	space	dword	0
	escape	dword	0
	n1		dword	0
	n2		dword	0
	n3		dword	0
	n4		dword	0
	n5		dword	0
	n6		dword	0
KeyState	ends
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
keys		KeyState	<>
hInstance	dd		?
hWinMain	dd		?
dwCenterX	dd		?	;圆心X
dwCenterY	dd		?	;圆心Y
dwRadius	dd		?	;半径

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	图片资源
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
bgTest		dword	0

		.const
szClassName	db	'Tetris: the game',0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 代码段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 计算时钟的位置、大小等参数
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_CalcClockParam	proc
		local	@stRect:RECT

		invoke	GetClientRect,hWinMain,addr @stRect
		mov	eax,@stRect.right
		sub	eax,@stRect.left	;eax = 宽度
		mov	ecx,@stRect.bottom
		sub	ecx,@stRect.top		;ecx = 高度
;********************************************************************
; 比较客户区宽度和高度，以小的值作为时钟的直径
;********************************************************************
		.if	ecx > eax
			mov	edx,eax		;高度 > 宽度
			sub	ecx,eax
			shr	ecx,1
			mov	dwCenterX,0
			mov	dwCenterY,ecx
		.else
			mov	edx,ecx
			sub	eax,ecx
			shr	eax,1
			mov	dwCenterX,eax
			mov	dwCenterY,0
		.endif
		shr	edx,1
		mov	dwRadius,edx
		add	dwCenterX,edx
		add	dwCenterY,edx
		ret

_CalcClockParam	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 计算时钟圆周上某个角度对应的 X 坐标
; X = 圆心X + Sin(角度) * 半径
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_dwPara180	dw	180
_CalcX		proc	_dwDegree,_dwRadius
		local	@dwReturn

		fild	dwCenterX
		fild	_dwDegree
		fldpi
		fmul			;角度*Pi
		fild	_dwPara180
		fdivp	st(1),st	;角度*Pi/180
		fsin			;Sin(角度*Pi/180)
		fild	_dwRadius
		fmul			;半径*Sin(角度*Pi/180)
		fadd			;X+半径*Sin(角度*Pi/180)
		fistp	@dwReturn
		mov	eax,@dwReturn
		ret

_CalcX		endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 计算时钟圆周上某个角度对应的 Y 坐标
; Y = 圆心Y - Cos(角度) * 半径
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_CalcY		proc	_dwDegree,_dwRadius
		local	@dwReturn

		fild	dwCenterY
		fild	_dwDegree
		fldpi
		fmul
		fild	_dwPara180
		fdivp	st(1),st
		fcos
		fild	_dwRadius
		fmul
		fsubp	st(1),st
		fistp	@dwReturn
		mov	eax,@dwReturn
		ret

_CalcY		endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 按照 _dwDegreeInc 的步进角度，画 _dwRadius 为半径的小圆点
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_DrawDot	proc	_hDC,_dwDegreeInc,_dwRadius
		local	@dwNowDegree,@dwR
		local	@dwX,@dwY

		mov	@dwNowDegree,0
		mov	eax,dwRadius
		sub	eax,10
		mov	@dwR,eax
		.while	@dwNowDegree <=	360
			finit
;********************************************************************
; 计算小圆点的圆心坐标
;********************************************************************
			invoke	_CalcX,@dwNowDegree,@dwR
			mov	@dwX,eax
			invoke	_CalcY,@dwNowDegree,@dwR
			mov	@dwY,eax

			mov	eax,@dwX	;画点
			mov	ebx,eax
			mov	ecx,@dwY
			mov	edx,ecx
			sub	eax,_dwRadius
			add	ebx,_dwRadius
			sub	ecx,_dwRadius
			add	edx,_dwRadius
			invoke	Ellipse,_hDC,eax,ecx,ebx,edx

			mov	eax,_dwDegreeInc
			add	@dwNowDegree,eax
		.endw
		ret

_DrawDot	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 画 _dwDegree 角度的线条，半径=时钟半径-参数_dwRadiusAdjust
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_DrawLine	proc	_hDC,_dwDegree,_dwRadiusAdjust
		local	@dwR
		local	@dwX1,@dwY1,@dwX2,@dwY2

		mov	eax,dwRadius
		sub	eax,_dwRadiusAdjust
		mov	@dwR,eax
;********************************************************************
; 计算线条两端的坐标
;********************************************************************
		invoke	_CalcX,_dwDegree,@dwR
		mov	@dwX1,eax
		invoke	_CalcY,_dwDegree,@dwR
		mov	@dwY1,eax
		add	_dwDegree,180
		invoke	_CalcX,_dwDegree,10
		mov	@dwX2,eax
		invoke	_CalcY,_dwDegree,10
		mov	@dwY2,eax
		invoke	MoveToEx,_hDC,@dwX1,@dwY1,NULL
		invoke	LineTo,_hDC,@dwX2,@dwY2

		ret

_DrawLine	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_DrawCustomizedBackground	proc _hDC
		local @hBmpBack, @hDcBack ; 'Back' for 'background'. 
		.if	keys.down == 0
			ret
		.endif
		invoke	CreateCompatibleDC,_hDC; 创建与_hDC兼容的另一个DC(设备上下文)，以备后续操作
		mov		@hDcBack, eax
		invoke	SelectObject, @hDcBack, bgTest; 将图片绑定到DC，这样，图片才能被操作
		invoke	BitBlt,_hDC,0,0,WINDOW_WIDTH, WINDOW_HEIGHT, @hDcBack,0,0,SRCCOPY ; 通过DC读取图片，复制到hDC，从而完成显示
		invoke	DeleteDC, @hDcBack ;回收资源（DC）
		; For your ref:我应该使用DeleteDC还是ReleaseDC?
		; https://www.cnblogs.com/vranger/p/3564606.html
		invoke	DeleteObject, @hBmpBack
		; Todo: 没有自动补全怎么破...
		ret
_DrawCustomizedBackground	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_UpdateKeyState	proc  _wParam, _keyDown
		local @timenow
		;判断按键状态
		;如果是按下，将键盘设置为按下时的系统时间；松开则改为0
		;GetTickCount精度只有10~16ms，不要使用它进行过高精度的计算。
		;经测试，在Windows 10下，该函数的精度似乎为10ms.
		.if _keyDown != 0 ;current key is down.
			invoke	GetTickCount
			mov		@timenow,	eax
		.else
			mov		@timenow,	0
		.endif

		;更新按键
		.if	_wParam == VK_UP
			mov		eax,	@timenow
			mov		keys.up,	eax
		.elseif	_wParam == VK_DOWN
			mov		eax,	@timenow
			mov		keys.down,	eax
		.elseif _wParam == VK_LEFT
			mov		eax,	@timenow
			mov		keys.left,	eax
		.elseif	_wParam	== VK_RIGHT
			mov		eax,	@timenow
			mov		keys.right, eax
		.elseif	_wParam	== VK_SPACE
			mov		eax,	@timenow
			mov		keys.space, eax
		.elseif	_wParam	== VK_ESCAPE
			mov		eax,	@timenow
			mov		keys.escape,eax
		.elseif _wParam == 31h ;31h for number 1.
			mov		eax,	@timenow
			mov		keys.n1,	eax
		.elseif _wParam == 32h
			mov		eax,	@timenow
			mov		keys.n2,	eax
		.elseif _wParam == 33h
			mov		eax,	@timenow
			mov		keys.n3,	eax
		.elseif _wParam == 34h
			mov		eax,	@timenow
			mov		keys.n4,	eax
		.elseif _wParam == 35h
			mov		eax,	@timenow
			mov		keys.n5,	eax
		.elseif _wParam == 36h
			mov		eax,	@timenow
			mov		keys.n6,	eax
		.endif
		ret
_UpdateKeyState	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_InitGame	proc  _hWnd

		;设置定时器
		invoke	SetTimer,_hWnd,ID_TIMER,TIMER_MAIN_INTERVAL,NULL
		
		;加载资源
		invoke	LoadBitmap, hInstance, IDB_BITMAP_TEST; 加载图片到bgTest
		mov		bgTest, eax

		ret
_InitGame	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_OnPaint	proc	_hWnd,_hDC
		local	@stTime:SYSTEMTIME, @bufferDC; bufferDC is cache for pictures.
		local	@bufferBmp

		pushad
		invoke	GetLocalTime,addr @stTime
		invoke	_CalcClockParam
;********************************************************************
; 启用双缓冲绘图方式，避免界面闪烁
;********************************************************************
		invoke	CreateCompatibleDC, _hDC
		mov		@bufferDC,	eax
		invoke	CreateCompatibleBitmap, _hDC, WINDOW_WIDTH, WINDOW_HEIGHT
		mov		@bufferBmp,	eax
		invoke	SelectObject, @bufferDC, @bufferBmp
;********************************************************************
; Customized 画一个自定义背景
;********************************************************************
		invoke _DrawCustomizedBackground, @bufferDC
;********************************************************************
; 画时钟圆周上的点
;********************************************************************
		invoke	GetStockObject,WHITE_BRUSH
		invoke	SelectObject,@bufferDC,eax
		invoke	_DrawDot,@bufferDC,360/12,3	;画12个大圆点
		invoke	_DrawDot,@bufferDC,360/60,1	;画60个小圆点
;********************************************************************
; 画时钟指针
;********************************************************************
		invoke	CreatePen,PS_SOLID,1,0FFFFFFh
		invoke	SelectObject,@bufferDC,eax
		invoke	DeleteObject,eax
		movzx	eax,@stTime.wSecond
		mov	ecx,360/60
		mul	ecx			;秒针度数 = 秒 * 360/60
		invoke	_DrawLine,@bufferDC,eax,15
;********************************************************************
		invoke	CreatePen,PS_SOLID,2,0FFFFFFh
		invoke	SelectObject,@bufferDC,eax
		invoke	DeleteObject,eax
		movzx	eax,@stTime.wMinute
		mov	ecx,360/60
		mul	ecx			;分针度数 = 分 * 360/60
		invoke	_DrawLine,@bufferDC,eax,20
;********************************************************************
		invoke	CreatePen,PS_SOLID,3,0FFFFFFh
		invoke	SelectObject,@bufferDC,eax
		invoke	DeleteObject,eax
		movzx	eax,@stTime.wHour
		.if	eax >=	12
			sub	eax,12
		.endif
		mov	ecx,360/12
		mul	ecx
		movzx	ecx,@stTime.wMinute
		shr	ecx,1
		add	eax,ecx
		invoke	_DrawLine,@bufferDC,eax,30
;********************************************************************
;		把缓存绘制到hDC上
;********************************************************************
		invoke	BitBlt,_hDC,0,0,WINDOW_WIDTH,WINDOW_HEIGHT,@bufferDC,0,0,SRCCOPY
		invoke	GetStockObject,NULL_PEN
		invoke	SelectObject,@bufferDC,eax
		invoke	DeleteObject,eax
		invoke	DeleteObject,@bufferBmp
		invoke	DeleteObject,@bufferDC
		popad
		ret

_OnPaint	endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ComeputeGameLogic	proc  _hWnd
		;TODO 在这里写游戏的逻辑
		ret
_ComeputeGameLogic	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcessTimer	proc  _hWnd, timerId
		;TODO 调用ProcessTimer，以判断具体的定时器类型并做出响应。
		;如，当前的定时器可能是UpdateFrame计时器，
		;此时我们就计算当前的状态，并修改对应的状态。
		.if timerId == ID_TIMER
			invoke	_ComeputeGameLogic, _hWnd
			invoke	InvalidateRect,_hWnd,NULL,FALSE
		.else
			;TODO 在此处添加其它的计时器
			ret
		.endif
		ret
_ProcessTimer	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcWinMain	proc	uses ebx edi esi hWnd,uMsg,wParam,lParam
		local	@stPS:PAINTSTRUCT

		mov	eax,uMsg
		.if	eax ==	WM_TIMER
			invoke	_ProcessTimer, hWnd, wParam
;********************************************************************
		.elseif	eax ==	WM_KEYDOWN
			invoke	_UpdateKeyState, wParam, 1
		.elseif	eax ==	WM_KEYUP
			invoke	_UpdateKeyState, wParam, 0
;********************************************************************
		.elseif	eax ==	WM_PAINT
			invoke	BeginPaint,hWnd,addr @stPS
			invoke	_OnPaint,hWnd,eax 
			invoke	EndPaint,hWnd,addr @stPS
;********************************************************************
		.elseif	eax ==	WM_CREATE
			invoke	_InitGame, hWnd
		.elseif	eax ==	WM_CLOSE
			invoke	KillTimer,hWnd,ID_TIMER
			invoke	DestroyWindow,hWinMain
			invoke	PostQuitMessage,NULL
;********************************************************************
		.elseif	eax ==	WM_ERASEBKGND
			ret
		.else
			invoke	DefWindowProc,hWnd,uMsg,wParam,lParam
			ret
		.endif
;********************************************************************
		xor	eax,eax
		ret

_ProcWinMain	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_WinMain	proc
		local	@stWndClass:WNDCLASSEX
		local	@stMsg:MSG
		
		invoke	GetModuleHandle,NULL
		mov	hInstance,eax
;********************************************************************
; 注册窗口类
;********************************************************************
		invoke	RtlZeroMemory,addr @stWndClass,sizeof @stWndClass
		invoke	LoadIcon,hInstance,ICO_MAIN
		mov	@stWndClass.hIcon,eax
		mov	@stWndClass.hIconSm,eax
		invoke	LoadCursor,0,IDC_ARROW
		mov	@stWndClass.hCursor,eax
		push	hInstance
		pop	@stWndClass.hInstance
		mov	@stWndClass.cbSize,sizeof WNDCLASSEX
		mov	@stWndClass.style,CS_HREDRAW or CS_VREDRAW
		mov	@stWndClass.lpfnWndProc,offset _ProcWinMain
		mov	@stWndClass.hbrBackground,COLOR_WINDOW + 1
		mov	@stWndClass.lpszClassName,offset szClassName
		invoke	RegisterClassEx,addr @stWndClass
;********************************************************************
; 建立并显示窗口
;********************************************************************
		;设置窗口大小固定
		mov	eax, WS_OVERLAPPEDWINDOW
		xor	eax, WS_THICKFRAME
		invoke	CreateWindowEx,WS_EX_CLIENTEDGE,\
			offset szClassName,offset szClassName,\
			eax,\
			100,100,WINDOW_WIDTH,WINDOW_HEIGHT,\
			NULL,NULL,hInstance,NULL
		mov	hWinMain,eax
		invoke	ShowWindow,hWinMain,SW_SHOWNORMAL
		invoke	UpdateWindow,hWinMain
;********************************************************************
; 消息循环
;********************************************************************
		.while	TRUE
			invoke	GetMessage,addr @stMsg,NULL,0,0
			.break	.if eax == 0
			invoke	TranslateMessage,addr @stMsg
			invoke	DispatchMessage,addr @stMsg
		.endw
		ret

_WinMain	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
start:
		call	_WinMain
		invoke	ExitProcess,NULL
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		end	start
