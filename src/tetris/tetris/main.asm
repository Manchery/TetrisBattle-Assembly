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
include		Msimg32.inc
includelib	Msimg32.lib
include		wsock32.inc
includelib	wsock32.lib

include		tetris2.inc
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
IDB_BITMAP_TEST				equ	    101
IDB_BITMAP_BG1				equ		104
IDB_BITMAP_BG2				equ     105
IDB_BITMAP_BG3				equ     123
IDB_BITMAP_BG4				equ     106
IDB_BITMAP_BG5				equ     127
IDB_BITMAP_BGWAIT			equ     128
IDB_BITMAP_STOP				equ     129
IDB_BITMAP_SQUARE			equ     130
IDB_BITMAP_BGREADY			equ     131
IDB_BITMAP_BGERROR			equ     132
IDB_BITMAP_BGWAITCON		equ     133
IDB_BITMAP_BOOMPIC          equ    134
IDB_BITMAP_LAUGH            equ    137

HOME_SINGLE_PAGE			equ		0
HOME_MULTIPLE_PAGE			equ		1
MULTIPLE_CONNECT_PAGE		equ		2
SINGLE_GAME_PAGE			equ		3
MULTIPLE_GAME_PAGE			equ		4
MULTIPLE_READY_PAGE			equ		5
MULTIPLE_WAIT_PAGE			equ		6
MULTIPLE_WAIT_CONNECT_PAGE	equ		7
MULTIPLE_CONNECT_ERROR_PAGE	equ		8

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ���ݶ�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; �ṹ�嶨��(ע����룬������ʹ��DWORD)
KeyState	struct	;KeyState��ʶ���������ҡ��ո�ESC������1~6
	up			dword	0
	down		dword	0
	left		dword	0
	right		dword	0
	space		dword	0
	escape		dword	0
	return		dword	0
	n0			dword	0
	n1			dword	0
	n2			dword	0
	n3			dword	0
	n4			dword	0
	n5			dword	0
	n6			dword	0
	n7			dword	0
	n8			dword	0
	n9			dword	0
	back		dword	0
	point		dword	0
KeyState	ends

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
keys		KeyState	<>
_page		dword	0
_ipLen		dword	0
_ipStr		db		20 dup(0)
hInstance	dd		?
hWinMain	dd		?
dwCenterX	dd		?	;Բ��X
dwCenterY	dd		?	;Բ��Y
dwRadius	dd		?	;�뾶

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
_Connect	proc _hWnd
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
			invoke	MessageBox,_hWnd,addr szErrIP,NULL,MB_OK or MB_ICONSTOP
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
		invoke	WSAAsyncSelect,hSocket,_hWnd,WM_SOCKET,FD_CONNECT or FD_READ or FD_CLOSE or FD_WRITE
		invoke	connect,hSocket,addr @stSin,sizeof @stSin
		.if	eax ==	SOCKET_ERROR
			invoke	WSAGetLastError
			.if eax != WSAEWOULDBLOCK
				;invoke	MessageBox,hWinMain,addr szErrConnect,NULL,MB_OK or MB_ICONSTOP
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
		local @hDcBack; 'Back' for 'background'. 
		;todo demo How to index an array.
		;mov		eax,	1
		;mov		ecx,	type NetworkMsg
		;mul		ecx
		;mov		inputQueue.msgs[eax].sender, 233
		invoke	CreateCompatibleDC,_hDC; ������_hDC���ݵ���һ��DC(�豸������)���Ա���������
		mov		@hDcBack, eax
		.if	_page == HOME_SINGLE_PAGE
			invoke	SelectObject, @hDcBack, _bg1; ��ͼƬ�󶨵�DC��������ͼƬ���ܱ�����
		.elseif _page == HOME_MULTIPLE_PAGE
			invoke	SelectObject, @hDcBack, _bg2
		.elseif _page == MULTIPLE_CONNECT_PAGE
			invoke	SelectObject, @hDcBack, _bg3
		.elseif _page == SINGLE_GAME_PAGE
			invoke	SelectObject, @hDcBack, _bg4
		.elseif _page == MULTIPLE_GAME_PAGE
			invoke	SelectObject, @hDcBack, _bg5
		.elseif _page == MULTIPLE_READY_PAGE
			invoke	SelectObject, @hDcBack, _bgready
		.elseif _page == MULTIPLE_WAIT_PAGE
			invoke	SelectObject, @hDcBack, _bgwait
		.elseif _page == MULTIPLE_WAIT_CONNECT_PAGE
			invoke	SelectObject, @hDcBack, _bgWaitConnect
		.elseif _page == MULTIPLE_CONNECT_ERROR_PAGE
			invoke	SelectObject, @hDcBack, _bgConnectErr
		.endif
		invoke	BitBlt,_hDC,0,0,WINDOW_WIDTH, WINDOW_HEIGHT, @hDcBack,0,0,SRCCOPY ; ͨ��DC��ȡͼƬ�����Ƶ�hDC���Ӷ������ʾ

		invoke	DeleteDC, @hDcBack ;������Դ��DC��
		; For your ref:��Ӧ��ʹ��DeleteDC����ReleaseDC?
		; https://www.cnblogs.com/vranger/p/3564606.html
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
		.elseif	_wParam	== VK_BACK
			mov		keys.back,	eax
		.elseif _wParam == 30h ;30h for number 0.
			mov		keys.n0,	eax
		.elseif _wParam == 31h
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
		.elseif _wParam == 37h
			mov		keys.n7,	eax
		.elseif _wParam == 38h
			mov		keys.n8,	eax
		.elseif _wParam == 39h
			mov		keys.n9,	eax
		.elseif _wParam == VK_OEM_PERIOD
			mov		keys.point,	eax
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
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BG3
		mov		_bg3, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BG4
		mov		_bg4, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BG5
		mov		_bg5, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BGWAIT
		mov		_bgwait, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BGREADY
		mov		_bgready, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_STOP
		mov		_stop, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_SQUARE
		mov		_square, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BGERROR
		mov		_bgConnectErr, eax		
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BGWAITCON
		mov		_bgWaitConnect, eax	
		invoke	LoadBitmap, hInstance, IDB_BITMAP_LAUGH
		mov		_laugh, eax	
		invoke	LoadBitmap, hInstance, IDB_BITMAP_BOOMPIC
		mov		_boomPic, eax	

		;TODO �������Ը��Ļ������Կ��ǰ����б�����صı�������ṹ��
		;����ʵ���岻����Ϊ�ҵ�VSû���Զ���ȫ

		ret
_InitGame	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

_DrawIpAddress	proc _hDC
				local @textBmp, @hDcText, @font, @textRgn:RECT
		pushad
		invoke	CreateCompatibleDC,_hDC;��������ͼ��DC
		mov		@hDcText, eax

		;Parameters of CreateFont:
		;https://docs.microsoft.com/en-us/cpp/mfc/reference/cfont-class?view=msvc-160#createfont
		
		invoke	MultiByteToWideChar, CP_UTF8, 0, offset _fontName, -1, offset _fontNameW, 64;

		invoke	CreateFont, 20 , 12 , 0 , 0 , 600 , 0 , 0 , 0\
				,OEM_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS\
				,DEFAULT_QUALITY,DEFAULT_PITCH or FF_SCRIPT, offset _fontNameW
		mov		@font, eax
		invoke	SelectObject,@hDcText,eax;��ָ������ľ�������豸����


		invoke	CreateCompatibleBitmap, _hDC, 800, 400;��������ͼ��ͼƬ
		mov		@textBmp, eax
		invoke	SelectObject, @hDcText, @textBmp;��BMP��DC
		mov		@textRgn.left, 0
		mov		@textRgn.top, 0
		mov		@textRgn.right, 800
		mov		@textRgn.bottom, 400
		invoke	InvertRect,@hDcText,addr @textRgn;�ѱ�����Ϊȫ��

		invoke  TextOutA, @hDcText, 0, 0, addr _ipStr, _ipLen;��DC��д����
		invoke	TransparentBlt,_hDC,495,360,800,400,\
		@hDcText,0,0,800,400,0FFFFFFh;���˰�ɫ��ֻ������ͼ��ĺ�ɫ(����)����hDC��
		invoke	DeleteObject, @textBmp
		invoke	DeleteDC, @hDcText
		invoke	DeleteObject, @font
		popad
		ret
_DrawIpAddress endp


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_OnPaint	proc	_hWnd,_hDC
		local	@stTime:SYSTEMTIME, @bufferDC; bufferDC is cache for pictures.
		local	@bufferBmp
		local	@i
		local	@j

		pushad
		invoke	GetLocalTime,addr @stTime
		invoke	_CalcClockParam
;********************************************************************
; ����˫�����ͼ��ʽ�����������˸
;********************************************************************
		invoke	CreateCompatibleDC, _hDC
		mov		@bufferDC,	eax
		invoke	CreateCompatibleBitmap, _hDC, WINDOW_WIDTH, WINDOW_HEIGHT
		mov		@bufferBmp,	eax
		invoke	SelectObject, @bufferDC, @bufferBmp
;********************************************************************
; Customized ��һ���Զ��屳��
;********************************************************************
		invoke _DrawCustomizedBackground, @bufferDC

		;Draw Ip Address text to _page2
		.if _page == 2
			invoke _DrawIpAddress, @bufferDC
		.endif

		.if (_page == SINGLE_GAME_PAGE) || (_page == MULTIPLE_GAME_PAGE)
			;********************************************************************
			; ����ͼ
			;********************************************************************
			
			mov @i, 0

			.while @i < _mapHeight
				mov @j, 0
				.while @j < _mapWidth
					invoke _GetMap, @i, @j
					invoke _DrawSquare, @bufferDC, @i, @j, eax, _mapOffsetX, _mapOffsetY
					inc @j
				.endw
				inc @i
			.endw

			;********************************************************************
			; ��ǰ��
			;********************************************************************
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

					invoke _DrawSquare, @bufferDC, ecx, edx, _currentColor, _mapOffsetX, _mapOffsetY
					inc @i
				.endw
			.endif

			;********************************************************************
			; ��һ��
			;********************************************************************
			.if _nextBlock != -1
				mov eax, _nextBlock
				mov ecx, 4
				mul ecx
				add eax, _nextStatus
				mov ecx, 8
				mul ecx

				mov @i, 0
				.while @i < 4
					mov ecx, _nextPosI
					add ecx, _blockOffset[eax * 4]
					add eax, 1
					mov edx, _nextPosJ
					add edx, _blockOffset[eax * 4]
					add eax, 1

					invoke _DrawSquare, @bufferDC, ecx, edx, _nextColor, _nextOffsetX, _nextOffsetY
					inc @i
				.endw
			.endif

			;********************************************************************
			; ������������
			;********************************************************************
			invoke _DrawNumber, @bufferDC, 600, 475, _scores, 80, 36
			invoke _DrawNumber, @bufferDC, 700, 705, _tools[0], 40, 18
			invoke _DrawNumber, @bufferDC, 900, 705, _tools[4], 40, 18
			invoke _DrawNumber, @bufferDC, 1100, 705, _tools[8], 40, 18
		.endif

		.if (_page == SINGLE_GAME_PAGE)
			.if _paused==1
				invoke _DrawPause, @bufferDC
			.endif
		.endif

		;@@@@@@@@@@@@@@@@@@@@@@@@@@ DEV
		.if (_page == SINGLE_GAME_PAGE)
			.if _blackScreeningRemain
				invoke _DrawBlackScreen, @bufferDC
				dec _blackScreeningRemain
			.endif

			.if _bombPicRemain
				invoke _DrawBombPic, @bufferDC
				dec _bombPicRemain
			.endif
		.endif
		;@@@@@@@@@@@@@@@@@@@@@@@@@@@

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

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ComputeGameLogic	proc  _hWnd
		;local @testNetworkMsg:NetworkMsg
		;TODO ������д��Ϸ���߼�

		;������(����)�����������API�ĺ���
		;һ������ȫ��ͨ������Щ����ͻᱻ�Ƴ�
		;����Ҳ�����������԰�������Ϊ��
		;��debugʱ�������ɿ��¼������յ��������Ҫ�ֶ����ð���״̬
		;.if FALSE;keys.right;���ң��ͽ���3��Input��Ϣ��������
		;	mov edi, offset readBuffer
		;	add edi, readBfCnt
		;	mov eax, testStrlen
		;	add	readBfCnt, eax
		;	invoke _CopyMemory, edi, offset testString, testStrlen
		;	mov keys.right, 0
		;.elseif FALSE;keys.left;keys.left;���󣬰�inputBuffer�������ṹ����
		;	invoke _RecvData;, offset readBuffer, readBfCnt
		;	mov keys.left, 0
		;	mov	eax, eax
		;	mov keys.left, 0
		;.elseif keys.up;���ϣ�ģ��ȡ��һ��Input��Ϣ
		;���Ͻ�������
		;	mov keys.up, 0
		;	invoke _Connect, _hWnd
		;	mov	eax, eax
		;.elseif keys.space;���ո����������ܳ���Ϊ7��Output��Ϣ�����������Ϸ���
		;	invoke _QueuePop, offset inputQueue, addr @testNetworkMsg
		;	mov	@testNetworkMsg.inst, 233
		;	mov	@testNetworkMsg.sender, 15
		;	mov	@testNetworkMsg.recver, 25
		;	mov @testNetworkMsg.msglen, 3
		;	invoke _QueuePush, offset outputQueue, addr @testNetworkMsg
		;	invoke _QueuePush, offset outputQueue, addr @testNetworkMsg
		;	invoke _SendData
		;	mov	eax, eax
		;	mov keys.space, 0
		;.elseif FALSE;keys.return
		;	invoke _SendData
		;	mov	eax, eax
		;	mov keys.return, 0
		;.endif

		pushad 

		;@@@@@@@@@@@@@@@@@@@@@ ��ҳ:ѡ�е��� @@@@@@@@@@@@@@@@@@@@@
		.if _page == HOME_SINGLE_PAGE
			.if keys.right
				mov _page, 1
				mov keys.right, HOME_MULTIPLE_PAGE
			.elseif keys.return
				mov _page, SINGLE_GAME_PAGE
				invoke _InitSingleGame
				mov keys.return, 0
			.endif
		; @@@@@@@@@@@@@@@@@@@@ ��ҳ:ѡ�ж��� @@@@@@@@@@@@@@@@@@@@@
		.elseif _page == HOME_MULTIPLE_PAGE
			.if keys.left
				mov _page, HOME_SINGLE_PAGE
				mov keys.left, 0
			.elseif keys.return
				mov _page, MULTIPLE_CONNECT_PAGE
				mov keys.return, 0
			.endif
		; @@@@@@@@@@@@@@@@@@@@ ����:׼������ @@@@@@@@@@@@@@@@@@@@@
		.elseif _page == MULTIPLE_CONNECT_PAGE
			.if keys.return
				mov keys.return, 0
				invoke	RtlZeroMemory,addr serverIpAddr,sizeof serverIpAddr
				invoke _CopyMemory,addr serverIpAddr,addr _ipStr,_ipLen
				invoke _Connect, _hWnd
				mov _page, MULTIPLE_WAIT_CONNECT_PAGE
			.elseif keys.back
				.if _ipLen > 0
					dec _ipLen
				.endif
				mov keys.back, 0
			.elseif keys.n0
				.if _ipLen < 15
					mov eax, _ipLen
					mov _ipStr[eax], '0'
					inc _ipLen
				.endif
				mov keys.n0, 0
			.elseif keys.n1
				.if _ipLen < 15
					mov eax, _ipLen
					mov _ipStr[eax], '1'
					inc _ipLen
				.endif
				mov keys.n1, 0
			.elseif keys.n2
				.if _ipLen < 15
					mov eax, _ipLen
					mov _ipStr[eax], '2'
					inc _ipLen
				.endif
				mov keys.n2, 0
			.elseif keys.n3
				.if _ipLen < 15
					mov eax, _ipLen
					mov _ipStr[eax], '3'
					inc _ipLen
				.endif
				mov keys.n3, 0
			.elseif keys.n4
				.if _ipLen < 15
					mov eax, _ipLen
					mov _ipStr[eax], '4'
					inc _ipLen
				.endif
				mov keys.n4, 0
			.elseif keys.n5
				.if _ipLen < 15
					mov eax, _ipLen
					mov _ipStr[eax], '5'
					inc _ipLen
				.endif
				mov keys.n5, 0
			.elseif keys.n6
				.if _ipLen < 15
					mov eax, _ipLen
					mov _ipStr[eax], '6'
					inc _ipLen
				.endif
				mov keys.n6, 0
			.elseif keys.n7
				.if _ipLen < 15
					mov eax, _ipLen
					mov _ipStr[eax], '7'
					inc _ipLen
				.endif
				mov keys.n7, 0
			.elseif keys.n8
				.if _ipLen < 15
					mov eax, _ipLen
					mov _ipStr[eax], '8'
					inc _ipLen
				.endif
				mov keys.n8, 0
			.elseif keys.n9
				.if _ipLen < 15
					mov eax, _ipLen
					mov _ipStr[eax], '9'
					inc _ipLen
				.endif
				mov keys.n9, 0
			.elseif keys.point
				.if _ipLen < 15
					mov eax, _ipLen
					mov _ipStr[eax], '.'
					inc _ipLen
				.endif
				mov keys.point, 0
			.endif 
		; @@@@@@@@@@@@@@@@@@@@ ����:׼����ʼ��Ϸ @@@@@@@@@@@@@@@@@@@@@
		.elseif _page == MULTIPLE_READY_PAGE
			.if keys.return
				mov keys.return, 0
				;to do ����׼�����˵���Ϣ
				mov _page, MULTIPLE_WAIT_PAGE
			.endif
		; @@@@@@@@@@@@@@@@@@@@ ����: ��Ϸ @@@@@@@@@@@@@@@@@@@@@
		.elseif _page == SINGLE_GAME_PAGE
			.if _paused==0
				inc _sinceLastMoveDown

				;TODO: game start init

				.if _currentBlock == -1
					invoke _GetNextBlock
				.endif

				;�л�����һ����
				.if _readyNext==1
					.if _currentBlock != -1
						; д���ͼ
						invoke _WriteMap, _currentBlock, _currentStatus, _currentPosI, _currentPosJ, _currentColor
						; ��������
						invoke _ReduceLines, 0
					
						.if eax==1
							add _scores, 5
						.elseif eax==2
							add _scores, 15
							invoke _GetRandomIndex, 3
							inc _tools[eax*4]
						.elseif eax==3
							add _scores, 30
							invoke _GetRandomIndex, 3
							inc _tools[eax*4]
							invoke _GetRandomIndex, 3
							inc _tools[eax*4]
						.elseif eax==4
							add _scores, 50
							invoke _GetRandomIndex, 3
							inc _tools[eax*4]
							invoke _GetRandomIndex, 3
							inc _tools[eax*4]
							invoke _GetRandomIndex, 3
							inc _tools[eax*4]
						.endif

						invoke _UpdateMoveDownInternal
					.endif

					mov eax, _nextBlock
					mov _currentBlock, eax
					mov eax, _nextColor
					mov _currentColor, eax
					mov eax, _nextPosI
					mov _currentPosI, eax
					mov eax, _nextPosJ
					mov _currentPosJ, eax
					mov eax, _nextStatus
					mov _currentStatus, eax

					invoke _PositionValid, _currentBlock, _currentStatus, _currentPosI, _currentPosJ
					.if eax==0
						;TODO: gameover
					.endif

					invoke _GetNextBlock

					mov _readyNext, 0
				.endif

				; ����Ȼ����
				.if _readyNext==0
					.if _slowingRemain==0
						mov eax, _sinceLastMoveDown
						.if eax >=_moveDownInternal
							invoke _TryMove, 1, 0
							mov _sinceLastMoveDown, 0
							.if eax==0
								mov _readyNext, 1
							.endif
						.endif
					.else
						mov eax, _sinceLastMoveDown
						.if eax >=_slowingMoveDownInternal
							invoke _TryMove, 1, 0
							mov _sinceLastMoveDown, 0
							.if eax==0
								mov _readyNext, 1
								dec _slowingRemain
							.endif
						.endif
					.endif
				.endif

				;********************************************************************
				; ��������
				;********************************************************************
				.if keys.up != 0
					.if _readyNext==0
						invoke _TryChangeStatus
					.endif
					mov keys.up, 0
				.endif

				.if keys.left!=0
					.if _readyNext==0
						invoke _TryMove, 0, -1
					.endif
					mov keys.left, 0
				.endif

				.if keys.right!=0
					.if _readyNext==0
						invoke _TryMove, 0, 1
					.endif
					mov keys.right, 0
				.endif

				.if keys.down!=0
					.if _readyNext==0
						invoke _TryMove, 1, 0
						.if eax==1
							mov _sinceLastMoveDown, 0
						.endif
					.endif
					mov keys.down, 0
				.endif

				;********************************************************************
				; ����
				;********************************************************************
				.if keys.n1!=0
					.if _tools[0]>0
						invoke _ReduceLines, 3
						dec _tools[0]
					.endif
					mov keys.n1, 0
				.endif

				.if keys.n2!=0
					.if _tools[4]>0
						mov _slowingRemain, 1
						mov eax, _moveDownInternal
						sal eax, 1								;����ʱ����
						mov _slowingMoveDownInternal, eax
					
						dec _tools[4]
					.endif
					mov keys.n2, 0
				.endif
			
				.if keys.n3!=0
					.if _tools[8]>0
						invoke _GetNextBlock
						dec _tools[8]
					.endif
					mov keys.n3, 0
				.endif

				.if keys.space != 0
					mov _paused, 1
					mov keys.space, 0
				.endif

				;@@@@@@@@@@@@@@@@@@@@@@@@@ DEV @@@@@@@@@@@@@@@@@@@@@
				.if keys.n4!=0
					mov _blackScreeningRemain, 300
					mov keys.n4, 0
				.endif

				.if keys.n5!=0
					mov _bombPicRemain, 100
					invoke _Bomb
					mov keys.n5, 0
				.endif

				.if keys.n6!=0
					mov _specialBlockRemain, 3
					invoke _GetNextBlock
					mov keys.n6, 0
				.endif

				.if keys.n7!=0
					add _scores, 10
					mov keys.n7, 0
				.endif
				;@@@@@@@@@@@@@@@@@@@@@@@@@ DEV @@@@@@@@@@@@@@@@@@@@@
			.else
				.if keys.space != 0
					mov _paused, 0
					mov keys.space, 0
				.endif
			.endif

		.elseif _page == MULTIPLE_GAME_PAGE

		.endif

		popad
		ret
_ComputeGameLogic	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcessTimer	proc  _hWnd, timerId
		;TODO ����ProcessTimer�����жϾ���Ķ�ʱ�����Ͳ�������Ӧ��
		;�磬��ǰ�Ķ�ʱ��������UpdateFrame��ʱ����
		;��ʱ���Ǿͼ��㵱ǰ��״̬�����޸Ķ�Ӧ��״̬��
		.if timerId == ID_TIMER
			invoke	_ComputeGameLogic, _hWnd
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
