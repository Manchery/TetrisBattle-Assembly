;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Sample code for < Win32ASM Programming 2nd Edition>
; by ���Ʊ�, http://asm.yeah.net
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Clock.asm
; ʱ�����ӣ�ʹ�� GDI �����滭ָ��
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ʹ�� nmake ������������б��������:
; ml /c /coff Clock.asm
; rc Clock.rc
; Link /subsystem:windows Clock.obj Clock.res
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.386
		.model flat, stdcall
		option casemap :none
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Include �ļ�����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
include		windows.inc
include		user32.inc
includelib	user32.lib
include		kernel32.inc
includelib	kernel32.lib
include		Gdi32.inc
includelib	Gdi32.lib
include		wsock32.inc
includelib	wsock32.lib
include		network.inc
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Equ ��ֵ����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ICO_MAIN				equ		1000h
ID_TIMER				equ		1
WINDOW_WIDTH			equ		1200
WINDOW_HEIGHT			equ		960
TIMER_MAIN_INTERVAL		equ		10;ms
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; TODO ������������Դ��ʶ�������resource.h����*����*���˴���
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDB_BITMAP_TEST         equ	    101
IDB_BITMAP_BG1			equ		104
IDB_BITMAP_BG2          equ     105
IDB_BITMAP_BG4          equ     106
IDB_BITMAP_BLACK        equ     107
IDB_BITMAP_BOOM         equ     108
IDB_BITMAP_SKIP         equ     109
IDB_BITMAP_SPECIAL      equ     110
IDB_BITMAP_SQUARE       equ     112
IDB_BITMAP_SPEED        equ     113

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ���ݶ�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; �ṹ�嶨��(ע����룬������ʹ��DWORD)
KeyState	struct	;KeyState��ʶ���������ҡ��ո�ESC������1~6
	up		dword	0
	down	dword	0
	left	dword	0
	right	dword	0
	space	dword	0
	escape	dword	0
	return	dword	0
	n1		dword	0
	n2		dword	0
	n3		dword	0
	n4		dword	0
	n5		dword	0
	n6		dword	0
KeyState	ends

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
keys		KeyState	<>
_status		dword	0
hInstance	dd		?
hWinMain	dd		?
dwCenterX	dd		?	;Բ��X
dwCenterY	dd		?	;Բ��Y
dwRadius	dd		?	;�뾶

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	ͼƬ��Դ
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
bgTest		dword	0
_bg1		dword	0
_bg2		dword	0	
_bg4		dword	0
_black		dword	0
_boom		dword	0
_skip		dword	0	
_special	dword	0		
_square		dword	0
_speed		dword	0

		.const
szClassName	db	'Tetris: the game',0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; �����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; �Ͽ�����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_Disconnect	proc
		.if	hSocket
			invoke	closesocket,hSocket
			xor	eax,eax
			mov	hSocket,eax
		.endif

		;��ջ�����
		mov readBfCnt,			0
		mov writeBfCnt,			0
		mov inputQueue.len,		0
		mov outputQueue.len,	0
		;�����룬���ҵ����е�ʱ��������ַ����������Ի��ǵ�����RtlZeroMemory
		invoke RtlZeroMemory, offset readBuffer,  NETWORK_BUFFER_LENGTH
		invoke RtlZeroMemory, offset writeBuffer, NETWORK_BUFFER_LENGTH

		;todo:
		;�û���DisconnectScreen�а��¿ո�ص������档i.e.
		;invoke _ShowDisconnectScreen
		ret
_Disconnect	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ���ӵ�������
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_Connect	proc
		local	@stSin:sockaddr_in

		pushad
		xor	eax,eax
		;Todo what's a dbStep?
		;mov	dbStep,al
		mov	readBfCnt,eax
		mov	writeBfCnt,eax
;********************************************************************
; ���� socket
;********************************************************************
		invoke	RtlZeroMemory,addr @stSin,sizeof @stSin
		invoke	inet_addr,offset serverIpAddr
		.if	eax ==	INADDR_NONE
			invoke	MessageBox,hWinMain,addr szErrIP,NULL,MB_OK or MB_ICONSTOP
			jmp	_Err
		.endif
		mov	@stSin.sin_addr,eax
		mov	@stSin.sin_family,AF_INET
		invoke	htons,TCP_PORT
		mov	@stSin.sin_port,ax

		invoke	socket,AF_INET,SOCK_STREAM,0
		mov	hSocket,eax
;********************************************************************
; ��socket����Ϊ������ģʽ�����ӵ�������
;********************************************************************
		invoke	WSAAsyncSelect,hSocket,hWinMain,WM_SOCKET,FD_CONNECT or FD_READ or FD_CLOSE or FD_WRITE
		invoke	connect,hSocket,addr @stSin,sizeof @stSin
		.if	eax ==	SOCKET_ERROR
			invoke	WSAGetLastError
			.if eax != WSAEWOULDBLOCK
				invoke	MessageBox,hWinMain,addr szErrConnect,NULL,MB_OK or MB_ICONSTOP
				jmp	_Err
			.endif
		.endif
		ret
_Err:
		invoke	_Disconnect
		ret
_Connect	endp




;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ����Ϣ�������
; ��������������������һ����Ϣ��������
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_QueuePush	proc _queue, _msg
	pushad
	;��ȡ���еĵ�ַ
	mov esi, _queue
	; esi points at queue len
	add esi, type NetworkMsg * NETWORK_MSGBUF_LENGTH
	mov edi, esi
	; edi points at queue head
	add edi, type dword
	mov ebx, [esi]		;��ȡ����
	mov eax, [edi]		;��ȡHead
	add eax, ebx
	.if eax >= NETWORK_MSGBUF_LENGTH
		sub eax, NETWORK_MSGBUF_LENGTH
	.endif
	;�������eax������������ת��Ϊ�����еĵ�ַ
	mul typeNetworkMsg
	add eax, _queue
	;�����ṹ��
	invoke _CopyMemory, eax, _msg, type NetworkMsg
	;���¶�������
	.if dword ptr [esi] == NETWORK_MSGBUF_LENGTH
		;���������������ͷ�����ƣ������������Ϣ
		inc dword ptr [edi]
		.if dword ptr [edi] >= NETWORK_MSGBUF_LENGTH
			mov dword ptr [edi], 0
		.endif
	.else
		inc dword ptr [esi]
	.endif
	popad
	ret
_QueuePush	endp


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ����Ϣ�������С����ѵ�������Ϣ���ص�_msg��ָ���λ�ã������³���Ŀռ䣩
;���������޸�eax.��
; ����ֵ: eax == 0 ,if it's already empty before pop
;		 eax != 0 ,otherwise
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_QueuePop	proc _queue, _msg
			local @isEmpty
	pushad
	;��ȡ���еĵ�ַ
	mov esi, _queue
	; esi points at queue len
	add esi, type NetworkMsg * NETWORK_MSGBUF_LENGTH
	mov edi, esi
	; edi points at queue head
	add edi, type dword
	mov ebx, [esi]		;��ȡ����
	.if ebx == 0		;������Ϊ0��ֱ�ӷ���eax = 0
		mov @isEmpty, 0
		jmp _Ret
	.endif
	mov @isEmpty, 1
	mov eax, [edi]		;��ȡHead
	;��������eax������������ת��Ϊ�����еĵ�ַ
	mul typeNetworkMsg
	add eax, _queue
	;�����ṹ��
	invoke _CopyMemory, _msg, eax, type NetworkMsg
	;���¶�������
	dec dword ptr [esi]
	inc dword ptr [edi]
	.if dword ptr [edi] >= NETWORK_MSGBUF_LENGTH
		mov dword ptr [edi], 0	
	.endif
_Ret:
	popad
	mov eax, @isEmpty
	ret
_QueuePop	endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ������������Ϊ��Ϣ�ṹ��
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcessMsg	proc _buffer, _len
			local @parsedMsg:NetworkMsg
		pushad

		invoke  RtlZeroMemory, addr @parsedMsg, type NetworkMsg

		mov		esi, _buffer
		movzx	eax, byte ptr [esi + 0]
		mov		@parsedMsg.inst,	eax
		movzx	eax, byte ptr [esi + 1]
		mov		@parsedMsg.sender,	eax
		movzx	eax, byte ptr [esi + 2]
		mov		@parsedMsg.recver,	eax

		mov		eax,	_len
		sub		eax,	3
		mov		@parsedMsg.msglen,	eax
		.if	eax
			add esi, 3
			invoke _CopyMemory, addr @parsedMsg.msg, esi, eax
		.endif

		;add @parsedMsg into inputQueue
		invoke	_QueuePush, offset inputQueue, addr @parsedMsg
		popad
		ret
_ProcessMsg	endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; �������ݰ�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_RecvData	proc
		local	@tmpBuffer[512]:byte, @msgLength

		pushad
		;��esiָ����ջ���������һ����д��λ��
		;ecx�ǻ����������е����ݳ��ȡ�
		mov	esi,offset readBuffer
		mov	ecx,readBfCnt
		add	esi,ecx
;********************************************************************
		;��eaxָ��ʣ����õ�ȫ����������С
		;��������Ϣ
		mov	eax, NETWORK_BUFFER_LENGTH
		sub	eax, ecx
		;added for debug/test
		;jmp _Recved;added for debug/test
		.if	eax ;����ж�ʵ�����ǲ���Ҫ�ģ�
				;��Ϊһ�ζ�ȡ+������ܲ�����ʣ�೬��255B��
				;����������8192B.
			invoke	recv,hSocket,esi,eax,NULL
			.if	eax ==	SOCKET_ERROR
				invoke	WSAGetLastError
				.if	eax !=	WSAEWOULDBLOCK
					invoke	_Disconnect
				.endif
				jmp	_Ret
			.endif
			add	readBfCnt,eax
		.endif
;********************************************************************
; ����������ݰ�������ϣ�����д���
;********************************************************************
_Recved:
		;whileѭ��������ܴ��ڵ�ճ������
		;��esi��λ��bufferͷ��
		mov	esi, offset readBuffer
		.while readBfCnt > 0
			movzx	eax, byte ptr[esi];��ȡ��һ����Ϣ�ĳ���
			mov		@msgLength, eax
			inc		eax;��readBuffer[0]��������
			.break .if eax > readBfCnt;�յ�����Ϣ�����������أ��ȴ��´ν���
			sub		readBfCnt, eax;readBfCnt -= Current Msg Length
			inc		esi
			invoke	_ProcessMsg, esi, @msgLength; ProcessMsg������esi.
			add		esi, @msgLength
		.endw
		
		;�������ʣ����ַ������Ͱ������Ƶ�bufferͷ����
		.if	readBfCnt > 0
			invoke	_CopyMemory, addr @tmpBuffer, esi, readBfCnt
			invoke  _CopyMemory, offset readBuffer, addr @tmpBuffer, readBfCnt
		.endif
;********************************************************************
_Ret:
		popad
		ret

_RecvData	endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ����ʱ�ӵ�λ�á���С�Ȳ���
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_CalcClockParam	proc
		local	@stRect:RECT

		invoke	GetClientRect,hWinMain,addr @stRect
		mov	eax,@stRect.right
		sub	eax,@stRect.left	;eax = ���
		mov	ecx,@stRect.bottom
		sub	ecx,@stRect.top		;ecx = �߶�
;********************************************************************
; �ȽϿͻ�����Ⱥ͸߶ȣ���С��ֵ��Ϊʱ�ӵ�ֱ��
;********************************************************************
		.if	ecx > eax
			mov	edx,eax		;�߶� > ���
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
; ����ʱ��Բ����ĳ���Ƕȶ�Ӧ�� X ����
; X = Բ��X + Sin(�Ƕ�) * �뾶
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_dwPara180	dw	180
_CalcX		proc	_dwDegree,_dwRadius
		local	@dwReturn

		fild	dwCenterX
		fild	_dwDegree
		fldpi
		fmul			;�Ƕ�*Pi
		fild	_dwPara180
		fdivp	st(1),st	;�Ƕ�*Pi/180
		fsin			;Sin(�Ƕ�*Pi/180)
		fild	_dwRadius
		fmul			;�뾶*Sin(�Ƕ�*Pi/180)
		fadd			;X+�뾶*Sin(�Ƕ�*Pi/180)
		fistp	@dwReturn
		mov	eax,@dwReturn
		ret

_CalcX		endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ����ʱ��Բ����ĳ���Ƕȶ�Ӧ�� Y ����
; Y = Բ��Y - Cos(�Ƕ�) * �뾶
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
; ���� _dwDegreeInc �Ĳ����Ƕȣ��� _dwRadius Ϊ�뾶��СԲ��
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
; ����СԲ���Բ������
;********************************************************************
			invoke	_CalcX,@dwNowDegree,@dwR
			mov	@dwX,eax
			invoke	_CalcY,@dwNowDegree,@dwR
			mov	@dwY,eax

			mov	eax,@dwX	;����
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
; �� _dwDegree �Ƕȵ��������뾶=ʱ�Ӱ뾶-����_dwRadiusAdjust
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_DrawLine	proc	_hDC,_dwDegree,_dwRadiusAdjust
		local	@dwR
		local	@dwX1,@dwY1,@dwX2,@dwY2

		mov	eax,dwRadius
		sub	eax,_dwRadiusAdjust
		mov	@dwR,eax
;********************************************************************
; �����������˵�����
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
		;todo demo How to index an array.
		;mov		eax,	1
		;mov		ecx,	type NetworkMsg
		;mul		ecx
		;mov		inputQueue.msgs[eax].sender, 233
		invoke	CreateCompatibleDC,_hDC; ������_hDC���ݵ���һ��DC(�豸������)���Ա���������
		mov		@hDcBack, eax
		.if	_status == 0
			invoke	SelectObject, @hDcBack, _bg1; ��ͼƬ�󶨵�DC��������ͼƬ���ܱ�����
		.elseif _status ==1
			invoke	SelectObject, @hDcBack, bgTest; ��ͼƬ�󶨵�DC��������ͼƬ���ܱ�����
		.endif
		invoke	BitBlt,_hDC,0,0,WINDOW_WIDTH, WINDOW_HEIGHT, @hDcBack,0,0,SRCCOPY ; ͨ��DC��ȡͼƬ�����Ƶ�hDC���Ӷ������ʾ

		invoke	DeleteDC, @hDcBack ;������Դ��DC��
		; For your ref:��Ӧ��ʹ��DeleteDC����ReleaseDC?
		; https://www.cnblogs.com/vranger/p/3564606.html
		invoke	DeleteObject, @hBmpBack
		; Todo: û���Զ���ȫ��ô��...
		ret
_DrawCustomizedBackground	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>



;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ���ͻ������е����ݣ��ϴε������п���δ�����꣬��ÿ�η���ǰ��
; �Ƚ����ͻ������ϲ�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_SendData	proc
		local	@remainBfSize, @pendingMsg:NetworkMsg
		pushad
;********************************************************************
; ��ⷢ�Ͷ������Ƿ������ݣ�����У�
; �ͳ��Խ�Ҫ���͵����ݼӵ���������β��
;********************************************************************
		.while TRUE
			; ���㻺�������²��ֵĳ���
			mov eax, NETWORK_BUFFER_LENGTH
			sub eax, writeBfCnt
			mov @remainBfSize, eax
			;�Ӷ�����ѭ����ȡ�ṹ��
			;ֱ���ӿջ��߻�������
			.while outputQueue.len != 0
				invoke _QueuePop, offset outputQueue, addr @pendingMsg
				mov eax, @pendingMsg.msglen
				add	eax, 4
				.break .if eax > @remainBfSize ;��������
				mov esi, offset writeBuffer
				add esi, writeBfCnt
				sub @remainBfSize, eax
				add writeBfCnt, eax
				;����ǰ4����ֵ��writeBuffer��
				dec	eax
				mov [esi], al
				mov	eax, @pendingMsg.inst
				mov	[esi + 1], al
				mov	eax, @pendingMsg.sender
				mov	[esi + 2], al
				mov	eax, @pendingMsg.recver
				mov	[esi + 3], al
				add esi, 4
				;�������µ���Ϣ�嵽writeBuffer��
				.if @pendingMsg.msglen > 0
					invoke _CopyMemory, esi, addr @pendingMsg.msg, @pendingMsg.msglen
				.endif
			.endw
			.break .if writeBfCnt == 0;�����û����Ҫ���͵����ݣ��˳�ѭ��
			@@:
				mov	esi,offset writeBuffer
				mov	ebx,writeBfCnt
				or	ebx,ebx
				jz	_Ret
				;The line below is necessary for program:
				invoke	send,hSocket,esi,ebx,0

				;for debug/todo:
				;ģ��5���ֽڳɹ����͵��¼�
				;.if writeBfCnt > 5
				;	mov eax, 5
				;.else
				;	mov eax, writeBfCnt
				;.endif

				;�쳣����
				.if	eax ==	SOCKET_ERROR
					invoke	WSAGetLastError
					.if	eax !=	WSAEWOULDBLOCK
						;�������ʱ�������˻�������֮��Ĵ���
						;ֱ�ӶϿ�����
						invoke	_Disconnect
					.endif
					jmp	_Ret
				.endif
				.if (eax == 0) || (eax > NETWORK_BUFFER_LENGTH)
					;д0�����ֽ�
					jmp	_Ret
				.endif
				sub	writeBfCnt,eax
				mov	ecx,writeBfCnt
				mov	edi,offset writeBuffer
				lea	esi,[edi+eax]
				.if	ecx && (edi != esi)
					cld
					rep	movsb
					jmp	@B
				.endif
		.endw
_Ret:
		popad
		ret

_SendData	endp



;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_UpdateKeyState	proc  _wParam, _keyDown
		local @timenow
		;�жϰ���״̬
		;����ǰ��£�����������Ϊ����ʱ��ϵͳʱ�䣻�ɿ����Ϊ0
		;GetTickCount����ֻ��10~16ms����Ҫʹ�������й��߾��ȵļ��㡣
		;�����ԣ���Windows 10�£��ú����ľ����ƺ�Ϊ10ms.
		.if _keyDown != 0 ;current key is down.
			invoke	GetTickCount
			mov		@timenow,	eax
		.else
			mov		@timenow,	0
		.endif

		;���°���
		mov		eax,	@timenow
		.if	_wParam == VK_UP
			mov		keys.up,	eax
		.elseif	_wParam == VK_DOWN
			mov		keys.down,	eax
		.elseif _wParam == VK_LEFT
			mov		keys.left,	eax
		.elseif	_wParam	== VK_RIGHT
			mov		keys.right, eax
		.elseif	_wParam	== VK_SPACE
			mov		keys.space, eax
		.elseif	_wParam	== VK_ESCAPE
			mov		keys.escape,eax
		.elseif	_wParam	== VK_RETURN
			mov		keys.return,eax
		.elseif _wParam == 31h ;31h for number 1.
			mov		keys.n1,	eax
		.elseif _wParam == 32h
			mov		keys.n2,	eax
		.elseif _wParam == 33h
			mov		keys.n3,	eax
		.elseif _wParam == 34h
			mov		keys.n4,	eax
		.elseif _wParam == 35h
			mov		keys.n5,	eax
		.elseif _wParam == 36h
			mov		keys.n6,	eax
		.endif
		ret
_UpdateKeyState	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_InitGame	proc  _hWnd
		local	@stWsa:WSADATA
		;��ʼ������
		invoke	WSAStartup, 101h, addr @stWsa

		;���ö�ʱ��
		invoke	SetTimer,_hWnd,ID_TIMER,TIMER_MAIN_INTERVAL,NULL
		
		;������Դ
		invoke	LoadBitmap, hInstance, IDB_BITMAP_TEST; ����ͼƬ��bgTest
		mov		bgTest, eax		;�Ժ�ÿ��Ҫʹ����Դ���͵���bgTest
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BG1
		mov		_bg1, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BG2
		mov		_bg2, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BG4
		mov		_bg4, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BLACK
		mov		_black, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BOOM
		mov		_boom, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_SKIP
		mov		_skip, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_SPECIAL
		mov		_special, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_SQUARE
		mov		_square, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_SPEED
		mov		_speed, eax		
		;TODO �������Ը��Ļ������Կ��ǰ����б�����صı�������ṹ��
		;����ʵ���岻����Ϊ�ҵ�VSû���Զ���ȫ

		ret
_InitGame	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

.data

_map dword 200 dup(0)

_currentColor dword 1
_currentBlock dword -1
_currentStatus dword 0
_nextColor dword 1
_nextBlock dword 1

_currentPosI dword -2
_currentPosJ dword 3

.const 

;_blockInitPos dword

_mapHeight EQU 20
_mapWidth EQU 10
_blockSideLength EQU 40
_mapOffsetX EQU 20
_mapOffsetY EQU 20

_blockOffset  dword	2,0, 2,1, 2,2, 2,3 ;I
dword				0,2, 1,2, 2,2, 3,2
dword					2,0, 2,1, 2,2, 2,3
dword					0,1, 1,1, 2,1, 3,1

dword					0,0, 1,0, 1,1, 1,2 ;J
	dword				0,1, 0,2, 1,1, 2,1
		dword			1,0, 1,1, 1,2, 2,2
			dword		0,1, 1,1, 2,0, 2,1

			dword		0,2, 1,0, 1,1, 1,2;L
				dword	0,1, 1,1, 2,1, 2,2
			dword		1,0, 1,1, 1,2, 2,0
			dword		0,0, 0,1, 1,1, 2,1

				dword	0,0, 0,1, 1,0, 1,1;O
				dword	0,0, 0,1, 1,0, 1,1
					dword 0,0, 0,1, 1,0, 1,1
					dword 0,0, 0,1, 1,0, 1,1

dword					0,1, 0,2, 1,0, 1,1;S
dword					0,1, 1,1, 1,2, 2,2
	dword				1,1, 1,2, 2,0, 2,1
		dword			0,0, 1,0, 1,1, 2,1

		dword			0,1, 1,0, 1,1, 1,2;T
			dword		0,1, 1,1, 1,2, 2,1
			dword		1,0, 1,1, 1,2, 2,1
			dword		0,1, 1,0, 1,1, 2,1

			dword		0,0, 0,1, 1,1, 1,2;Z
			dword		0,2, 1,1, 1,2, 2,1
			dword		1,0, 1,1, 2,1, 2,2
			dword		0,1, 1,0, 1,1, 2,0

_blockInitPos dword	-2,3; I
dword					0,4;J
dword					0,4;L
dword					0,4;O
dword					0,4;S
dword					0,4;T
dword					0,4;Z

.code

_GetMap proc _i,_j
	push ecx
	mov eax, _i
	mov ecx, _mapWidth
	mul ecx
	mov ecx, _j
	add eax, ecx
	mov eax, _map[eax*4]
	pop ecx
	ret
_GetMap endp

_DrawSquare proc _hDC, _i, _j, _color
	
	.if (_i>=0) && (_i<_mapHeight) && (_j>=0) && (_j<_mapWidth)
		pushad

		.if _color==0
			invoke	GetStockObject,BLACK_BRUSH
		.else
			invoke	GetStockObject,WHITE_BRUSH
		.endif

		invoke	SelectObject,_hDC, eax
		invoke	DeleteObject, eax

		;׼�� left, top, right, bottom
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

		invoke	Rectangle, _hDC, eax, ebx, ecx, edx

		popad
	.endif
	ret
_DrawSquare endp

_PositionValid proc _block, @status, _posI, _posJ
	local	@i

	pushad

	mov eax, _block
	mov ecx, 4
	mul ecx
	add eax, @status
	mov ecx, 8
	mul ecx

	mov @i, 0
	.while @i < 4
		mov ecx, _posI
		add ecx, _blockOffset[eax * 4]
		add eax, 1
		mov edx, _posJ
		add edx, _blockOffset[eax * 4]
		add eax, 1
		;(ecx, edx) Ŀ����λ��

		;TODO: ��������
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

;����λ�úϷ�
_WriteMap proc _block, @status, _posI, _posJ, _color
	local	@i

	pushad

	mov eax, _block
	mov ecx, 4
	mul ecx
	add eax, @status
	mov ecx, 8
	mul ecx

	mov @i, 0
	.while @i < 4
		mov ecx, _posI
		add ecx, _blockOffset[eax * 4]
		add eax, 1
		mov edx, _posJ
		add edx, _blockOffset[eax * 4]
		add eax, 1
		
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


_TryMove proc _deltaI, _deltaJ
	push ebx
	push ecx

	mov ecx, _deltaI
	add ecx, _currentPosI
	mov ebx, _deltaJ
	add ebx, _currentPosJ

	invoke _PositionValid, _currentBlock, _currentStatus, ecx, ebx

	.if eax!=0
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


_TryChangeStatus proc
	push ecx
	mov ecx, _currentStatus
	inc ecx
	.if ecx>=4
		sub ecx, 4
	.endif

	invoke _PositionValid, _currentBlock, ecx, _currentPosI, _currentPosJ

	.if eax != 0
		mov _currentStatus, ecx
		mov eax, 1
	.else
		mov eax, 0
	.endif

	pop ecx
	ret
_TryChangeStatus endp


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_OnPaint	proc	_hWnd,_hDC
		local	@stTime:SYSTEMTIME, @bufferDC; bufferDC is cache for pictures.
		local	@bufferBmp
		local	@i
		local	@j

		pushad
;********************************************************************
; ����˫�����ͼ��ʽ�����������˸
;********************************************************************
		invoke	CreateCompatibleDC, _hDC
		mov		@bufferDC,	eax
		invoke	CreateCompatibleBitmap, _hDC, WINDOW_WIDTH, WINDOW_HEIGHT
		mov		@bufferBmp,	eax
		invoke	SelectObject, @bufferDC, @bufferBmp

;********************************************************************
; ����ͼ
;********************************************************************

		mov @i, 0

		.while @i < _mapHeight
			mov @j, 0
			.while @j < _mapWidth
				invoke _GetMap, @i, @j
				invoke _DrawSquare, @bufferDC, @i, @j, eax
				inc @j
			.endw
			inc @i
		.endw

		.if _currentBlock != -1
			mov eax, _currentBlock
			mov ecx, 4
			mul ecx
			add eax, _currentStatus
			mov ecx, 8
			mul ecx

			mov @i, 0
			.while @i < 4
				mov ecx, _currentPosI
				add ecx, _blockOffset[eax * 4]
				add eax, 1
				mov edx, _currentPosJ
				add edx, _blockOffset[eax * 4]
				add eax, 1

				invoke _DrawSquare, @bufferDC, ecx, edx, _currentColor
				inc @i
			.endw
		.endif
;********************************************************************
;		�ѻ�����Ƶ�hDC��
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

.data 

_readyNext dd 1
_sinceLastMoveDown dd 0

_moveDownInternal dd 50

_scores dd 0

.code

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
		mov esi, eax ; @i�п�ͷ
		push esi

		mov eax, 1

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
			add _scores, 100 
		.endif

		dec @i
	.endw
	
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

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ComeputeGameLogic	proc  _hWnd
		pushad 
		
		inc _sinceLastMoveDown

		.if _readyNext==1
			.if _currentBlock != -1
				invoke _WriteMap, _currentBlock, _currentStatus, _currentPosI, _currentPosJ, _currentColor
				invoke _ReduceLines
			.endif

			mov eax, _nextBlock
			mov _currentBlock, eax
			mov eax, _nextColor
			mov _currentColor, eax
			mov _currentStatus, 0
			
			mov ebx, _currentBlock
			mov eax, _blockInitPos[ebx * 8]
			mov _currentPosI, eax
			mov eax, _blockInitPos[ebx * 8 + 4]
			mov _currentPosJ, eax

			invoke _PositionValid, _currentBlock, _currentStatus, _currentPosI, _currentPosJ
			.if eax==0
				;TODO: gameover
			.endif
			
			inc _nextBlock
			.if _nextBlock >= 7
				sub _nextBlock, 7
			.endif
			mov _nextColor, 1

			mov _readyNext, 0
		.endif

		
		mov eax, _sinceLastMoveDown
		.if eax >=_moveDownInternal
			invoke _TryMove, 1, 0
			mov _sinceLastMoveDown, 0
			.if eax==0
				mov _readyNext, 1
			.endif
		.endif

;********************************************************************
; ��������Ϣ
;********************************************************************
		.if keys.up!=0
			mov keys.up, 0
			invoke _TryChangeStatus
		.endif

		.if keys.left!=0
			mov keys.left, 0
			.if _readyNext==0
				invoke _TryMove, 0, -1
			.endif
		.endif

		.if keys.right!=0
			mov keys.right, 0
			.if _readyNext==0
				invoke _TryMove, 0, 1
			.endif
		.endif

		.if keys.down!=0
			mov keys.down, 0
			.if _readyNext==0
				invoke _TryMove, 1, 0
				.if eax==1
					mov _sinceLastMoveDown, 0
				.endif
			.endif
		.endif

		popad
		ret
_ComeputeGameLogic	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcessTimer	proc  _hWnd, timerId
		;TODO ����ProcessTimer�����жϾ���Ķ�ʱ�����Ͳ�������Ӧ��
		;�磬��ǰ�Ķ�ʱ��������UpdateFrame��ʱ����
		;��ʱ���Ǿͼ��㵱ǰ��״̬�����޸Ķ�Ӧ��״̬��
		.if timerId == ID_TIMER
			invoke	_ComeputeGameLogic, _hWnd
			invoke	InvalidateRect,_hWnd,NULL,FALSE
		.else
			;TODO �ڴ˴���������ļ�ʱ��
			ret
		.endif
		ret
_ProcessTimer	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcWinMain	proc	uses ebx edi esi hWnd,uMsg,wParam,lParam
		local	@stPS:PAINTSTRUCT

		mov	eax,uMsg
		.if	eax ==	WM_SOCKET
;********************************************************************
; ���� Socket ��Ϣ
;********************************************************************
			mov	eax,lParam
			.if	ax ==	FD_READ
				invoke	_RecvData
			.elseif	ax ==	FD_WRITE
				invoke	_SendData	;�������ͻ���������
			.elseif	ax ==	FD_CONNECT
				;TODO ��Ӻ��ʵ�֪ͨ
				ret
			.elseif	ax ==	FD_CLOSE
				call	_Disconnect
			.endif
;********************************************************************
		.elseif	eax ==	WM_TIMER
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
			invoke  _Disconnect
			invoke	WSACleanup
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
; ע�ᴰ����
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
; ��������ʾ����
;********************************************************************
		;���ô��ڴ�С�̶�
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
; ��Ϣѭ��
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
