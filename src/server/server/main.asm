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
WINDOW_WIDTH			equ		300
WINDOW_HEIGHT			equ		200
TIMER_MAIN_INTERVAL		equ		10;ms
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ���ݶ�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; �ṹ�嶨��(ע����룬������ʹ��DWORD)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
hInstance	dd		?
hWinMain	dd		?
hListenSocket	dd	?	;�����׽��֣�Ҳʹ��WSASyncSelect����accept�¼�
dwCenterX	dd		?	;Բ��X
dwCenterY	dd		?	;Բ��Y
dwRadius	dd		?	;�뾶

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	��Ϸ״̬
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_onPlaying	dword	0;0 for notplay, 1 forplaying
_players	dword	0;a count for players
		.const
szClassName	db	'Tetris Server',0
szErrBind	db	'�󶨵�TCP�˿�10086ʱ���������Ƿ�������������ʹ��!',0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; �����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; �Ͽ�����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_Disconnect	proc
		local @cnt:dword
		pushad

		;���������ͱ���
		mov inputQueue.len,		0
		mov	_players, 0

		;�Ͽ������׽���
		.if	hListenSocket
			invoke	closesocket,hListenSocket
			xor	eax,eax
			mov	hListenSocket,eax
		.endif

		mov esi, offset _sockets
		mov edi, offset _playerMsgs
		mov	@cnt, 0
		.while @cnt < MAX_PLAYERS
			.if (dword ptr [esi] != 0)
				push esi
				push edi
				invoke	closesocket,[esi]
				pop edi
				pop esi
				; ��սṹ���
				mov (Client ptr [edi]).readBfCnt, 0
				mov (Client ptr [edi]).writeBfCnt, 0
				mov (Client ptr [edi]).outputQueue.len, 0
				xor	eax,eax
				mov	[esi],eax
			.endif
			add esi, 4
			add edi, type Client
			inc @cnt
		.endw

		;todo:
		;�û���DisconnectScreen�а��¿ո�ص������档i.e.
		;invoke _ShowDisconnectScreen
		popad
		ret
_Disconnect	endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ���ӵ�������
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_StartListen proc _hWnd	;_lParam;We dont need this params, for now.
		local	@stSin:sockaddr_in, @on:dword

;********************************************************************
; ���� socket
;********************************************************************
		invoke	socket,AF_INET,SOCK_STREAM,0
		mov	hListenSocket,eax

		invoke	RtlZeroMemory,addr @stSin,sizeof @stSin
		invoke	htons,TCP_PORT
		mov	@stSin.sin_port,ax
		mov	@stSin.sin_family,AF_INET
		mov	@stSin.sin_addr,INADDR_ANY
		invoke	bind,hListenSocket,addr @stSin,sizeof @stSin
		.if	eax
			invoke	MessageBox,_hWnd,addr szErrBind,\;todo add a szErrBind str.
				NULL,MB_OK or MB_ICONSTOP
			invoke	ExitProcess,NULL
			ret
		.endif
		mov	@on, 1
		invoke	setsockopt, hListenSocket, SOL_SOCKET, SO_REUSEADDR, addr @on, type @on
		.if	eax
			invoke	MessageBox,_hWnd,addr szErrBind,\;todo add a szErrBind str.
				NULL,MB_OK or MB_ICONSTOP
			invoke	ExitProcess,NULL
			ret
		.endif
;********************************************************************
; ��ʼ�������ȴ����ӽ��벢Ϊÿ�����Ӹ���״̬
;********************************************************************
		;���ü����׽��ֵ�������������������뵽��Ϣѭ����
		;�󶨵�WSASyncSelect֮�����¼���Ӧ���������
		;FD_CLOSE���Ҫ�ж����ǲ��Ǽ����׽��֡�����Ǽ����׽��־��˳�����(������)�ɡ�
		invoke	WSAAsyncSelect,hListenSocket,_hWnd,WM_SOCKET,FD_ACCEPT or FD_CLOSE
		invoke	listen,hListenSocket,100
		;����Ĵ��벻�ڴ˴�����
		;���Գ�������˳�����֮�⣬ò��û�б�Ҫ��ǰ�ر�hListenSocket
		;TODO:���Ҫע��
		;invoke	closesocket,hListenSocket
		ret
_StartListen	endp


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ��Ӧ�ر��¼�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_OnSocketClose proc @closedSocket
		local @cnt
		mov eax, @closedSocket
		.if(eax == hListenSocket)
			;�����������ѹر�
			;�ر������������ӣ���ֹ������
			;TODO:�ر�������������
			invoke closesocket, hListenSocket
			invoke ExitProcess, 0
		.endif
		;�û������ѹر�
		;ֱ�����������Ӽ���
		mov esi, offset _sockets
		mov edi, offset _playerMsgs
		mov	@cnt, 0
		.while @cnt < MAX_PLAYERS
			mov eax, @closedSocket
			.if (dword ptr [esi] != 0) && (eax == [esi])
				push esi
				push edi
				invoke	closesocket,[esi]
				pop edi
				pop esi
				; ��սṹ���
				mov (Client ptr [edi]).readBfCnt, 0
				mov (Client ptr [edi]).writeBfCnt, 0
				mov (Client ptr [edi]).outputQueue.len, 0
				xor	eax,eax
				mov	[esi],eax
				.break
			.endif
			add esi, 4
			add edi, type Client
			inc @cnt
		.endw
		ret
_OnSocketClose	endp




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
_RecvData	proc @socket
		local	@tmpBuffer[512]:byte, @msgLength
		local	@playerMsg, @socketaddr, @cnt

		pushad
		;������ṹ���λ��
		mov esi, offset _sockets
		mov edi, offset _playerMsgs
		mov	@cnt, 0
		.while @cnt < MAX_PLAYERS
			mov eax, @socket
			.if eax == [esi]
				mov @playerMsg, edi
				mov @socketaddr, esi
				.break
			.endif
			add esi, 4
			add edi, type Client
			inc @cnt
		.endw
		;û���ҵ�ָ���ṹ��
		.if @cnt == MAX_PLAYERS
			ret
		.endif

		;��esiָ����ջ���������һ����д��λ��
		;ecx�ǻ����������е����ݳ��ȡ�
		mov ebx, @playerMsg
		lea edx, (Client ptr [ebx]).readBuffer
		mov	esi, edx
		lea edx, (Client ptr [ebx]).readBfCnt
		mov	ecx, [edx]
		add	esi,ecx
;********************************************************************
		;��eaxָ��ʣ����õ�ȫ����������С
		;��������Ϣ
		mov	eax, NETWORK_BUFFER_LENGTH
		sub	eax, ecx
		;added for debug/test
		;jmp _Recved;added for debug/test
		.if	eax ;����ж�ʵ�����ǲ���Ҫ�ģ�
			invoke	recv,@socket,esi,eax,NULL
			.if	eax ==	SOCKET_ERROR
				invoke	WSAGetLastError
				.if	eax !=	WSAEWOULDBLOCK
					invoke	_OnSocketClose, @socket
				.endif
				jmp	_Ret
			.endif
			mov ebx, @playerMsg
			add (Client ptr [ebx]).readBfCnt, eax
		.endif
;********************************************************************
; ����������ݰ�������ϣ�����д���
;********************************************************************
_Recved:
		;whileѭ��������ܴ��ڵ�ճ������
		;��esi��λ��bufferͷ��
		lea edx, (Client ptr [ebx]).readBuffer
		mov	esi, edx
		;todo check if this is fine
		.while dword ptr (Client ptr [ebx]).readBfCnt > 0
			movzx	eax, byte ptr[esi];��ȡ��һ����Ϣ�ĳ���
			mov		@msgLength, eax
			inc		eax;��readBuffer[0]��������
			.break .if eax > dword ptr (Client ptr [ebx]).readBfCnt;�յ�����Ϣ�����������أ��ȴ��´ν���
			sub		(Client ptr [ebx]).readBfCnt, eax;readBfCnt -= Current Msg Length
			inc		esi
			invoke	_ProcessMsg, esi, @msgLength; ProcessMsg������esi��ebx.
			add		esi, @msgLength
		.endw
		
		;�������ʣ����ַ������Ͱ������Ƶ�bufferͷ����
		.if	dword ptr (Client ptr [ebx]).readBfCnt > 0
			push ebx
			invoke	_CopyMemory, addr @tmpBuffer, esi, (Client ptr[ebx]).readBfCnt
			pop ebx
			invoke  _CopyMemory, addr (Client ptr [ebx]).readBuffer, addr @tmpBuffer, (Client ptr[ebx]).readBfCnt
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
; ���ͻ������е����ݣ��ϴε������п���δ�����꣬��ÿ�η���ǰ��
; �Ƚ����ͻ������ϲ�
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_SendData	proc @socket
		local	@remainBfSize, @pendingMsg:NetworkMsg
		local	@playerMsg, @socketaddr, @cnt

		pushad
		;����д�ṹ���λ��
		mov esi, offset _sockets
		mov edi, offset _playerMsgs
		mov	@cnt, 0
		.while @cnt < MAX_PLAYERS
			mov eax, @socket
			.if (eax == [esi])
				mov @playerMsg, edi
				mov @socketaddr, esi
				.break
			.endif
			add esi, 4
			add edi, type Client
			inc @cnt
		.endw
		;û���ҵ�ָ���ṹ��
		.if @cnt == MAX_PLAYERS
			ret
		.endif
;********************************************************************
; ��ⷢ�Ͷ������Ƿ������ݣ�����У�
; �ͳ��Խ�Ҫ���͵����ݼӵ���������β��
;********************************************************************
		.while TRUE
			; ���㻺�������²��ֵĳ���
			mov ebx, @playerMsg
			mov eax, NETWORK_BUFFER_LENGTH
			sub eax, (Client ptr [ebx]).writeBfCnt
			mov @remainBfSize, eax
			;�Ӷ�����ѭ����ȡ�ṹ��
			;ֱ���ӿջ��߻�������
			.while dword ptr (Client ptr [ebx]).outputQueue.len != 0
				push ebx
				invoke _QueuePop, addr (Client ptr [ebx]).outputQueue, addr @pendingMsg
				pop ebx
				mov eax, @pendingMsg.msglen
				add	eax, 4
				.break .if eax > @remainBfSize ;��������
				lea edx, (Client ptr [ebx]).writeBuffer
				mov esi, edx
				add esi, (Client ptr [ebx]).writeBfCnt
				sub @remainBfSize, eax
				add (Client ptr [ebx]).writeBfCnt, eax
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
			mov ebx, @playerMsg
			.break .if dword ptr (Client ptr [ebx]).writeBfCnt == 0;�����û����Ҫ���͵����ݣ��˳�ѭ��
			@@:
				lea edx, (Client ptr [ebx]).writeBuffer
				mov	esi, edx
				mov	ebx,(Client ptr [ebx]).writeBfCnt
				or	ebx,ebx
				jz	_Ret
				;The line below is necessary for program:
				invoke	send,@socket,esi,ebx,0

				;for debug/todo:
				;ģ��5���ֽڳɹ����͵��¼�
				;mov ecx, @playerMsg
				;.if dword ptr (Client ptr [ecx]).writeBfCnt > 5
				;	mov eax, 5
				;.else
				;	mov eax, (Client ptr [ecx]).writeBfCnt
				;.endif

				;�쳣����
				.if	eax ==	SOCKET_ERROR
					invoke	WSAGetLastError
					.if	eax !=	WSAEWOULDBLOCK
						;�������ʱ�������˻�������֮��Ĵ���
						;ֱ�ӶϿ�����
						invoke	_OnSocketClose, @socket
					.endif
					jmp	_Ret
				.endif
				.if (eax == 0) || (eax > NETWORK_BUFFER_LENGTH)
					;д0�����ֽ�
					jmp	_Ret
				.endif
				mov ebx, @playerMsg
				sub	(Client ptr [ebx]).writeBfCnt,eax
				mov	ecx,(Client ptr [ebx]).writeBfCnt
				lea edx, (Client ptr [ebx]).writeBuffer
				mov	edi, edx
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
; ����Ϣ����ָ�����û�
; 0����������������������ӵĿͻ��ˣ�
; 1~4���������û���
; ����ֵ���ɹ����͵��û�����
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_SendMsgTo	proc @user, @msgAddr
			local @cnt, @sentCnt
	mov esi, offset _playerMsgs
	mov edi, offset _sockets
	mov @cnt, 0
	mov @sentCnt, 0
	.while @cnt < MAX_PLAYERS
		mov eax, @user 
		.if (dword ptr [edi] == 0) || ((eax != 0) && (eax != @cnt))
		.else
			invoke  _QueuePush, addr (Client ptr [esi]).outputQueue, @msgAddr
			invoke _SendData, [edi]
			inc @sentCnt
		.endif
		inc @cnt
		add edi, type dword
		add esi, type Client
	.endw
	mov eax, @sentCnt
	ret
_SendMsgTo	endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ��Ӧ���ӵ����������¼���һ��һ��
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_OnSocketAccept proc _hWnd
				local @connectMsg:NetworkMsg
		;��Ӧ���������
		.if (_onPlaying == 0) && (_players < MAX_PLAYERS) 
			invoke	accept,hListenSocket,NULL,0
			.if eax == INVALID_SOCKET
				ret
			.endif
			mov edi, offset _sockets
			mov ebx, _players
			lea edi, [edi + 4 * ebx]
			mov [edi], eax
			invoke	WSAAsyncSelect,eax,_hWnd,WM_SOCKET,FD_READ or FD_WRITE or FD_CLOSE

			;���ͳ�ʼ����Ϣ(��Ϣָ��Ϊ0)
			invoke	RtlZeroMemory, addr @connectMsg, type NetworkMsg
			mov eax, _players
			inc eax
			mov @connectMsg.recver, eax
			invoke _SendMsgTo, _players, addr @connectMsg

			;ά��������
			inc _players
		.endif
		;�����ǣ�����ֻ��ͨ���ر��׽��ֵķ�ʽ������ֹ�´��������...
		;�����档����Ҳ��һ���������������ڶ�������Ų�����233
		;���Գ�������˳�����֮�⣬ò��û�б�Ҫ��ǰ�ر�hListenSocket
		;�����������Ӧ�÷��ڳ����˳�ǰ
		;invoke	closesocket,hListenSocket
		ret
_OnSocketAccept	endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_InitServer	proc  _hWnd
		local	@stWsa:WSADATA
		;��ʼ������
		invoke	WSAStartup, 101h, addr @stWsa
		invoke  _StartListen, _hWnd

		;���ö�ʱ��
		invoke	SetTimer,_hWnd,ID_TIMER,TIMER_MAIN_INTERVAL,NULL

		ret
_InitServer	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_OnPaint	proc	_hWnd,_hDC
		local	@stTime:SYSTEMTIME, @bufferDC; bufferDC is cache for pictures.
		local	@bufferBmp

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
		;invoke _DrawCustomizedBackground, @bufferDC
;********************************************************************
; ��ʱ��Բ���ϵĵ�
;********************************************************************
		invoke	GetStockObject,WHITE_BRUSH
		invoke	SelectObject,@bufferDC,eax
		invoke	_DrawDot,@bufferDC,360/12,3	;��12����Բ��
		invoke	_DrawDot,@bufferDC,360/60,1	;��60��СԲ��
;********************************************************************
; ��ʱ��ָ��
;********************************************************************
		invoke	CreatePen,PS_SOLID,1,0FFFFFFh
		invoke	SelectObject,@bufferDC,eax
		invoke	DeleteObject,eax
		movzx	eax,@stTime.wSecond
		mov	ecx,360/60
		mul	ecx			;������� = �� * 360/60
		invoke	_DrawLine,@bufferDC,eax,15
;********************************************************************
		invoke	CreatePen,PS_SOLID,2,0FFFFFFh
		invoke	SelectObject,@bufferDC,eax
		invoke	DeleteObject,eax
		movzx	eax,@stTime.wMinute
		mov	ecx,360/60
		mul	ecx			;������� = �� * 360/60
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
_OnSendingMsg	proc  _hWnd
		local @testNetworkMsg:NetworkMsg
		;TODO ������д�������ķ����¼����߼�

		
		ret
_OnSendingMsg	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcessTimer	proc  _hWnd, timerId
		;TODO ����ProcessTimer�����жϾ���Ķ�ʱ�����Ͳ�������Ӧ��
		;�磬��ǰ�Ķ�ʱ��������UpdateFrame��ʱ����
		;��ʱ���Ǿͼ��㵱ǰ��״̬�����޸Ķ�Ӧ��״̬��
		.if timerId == ID_TIMER
			invoke	_OnSendingMsg, _hWnd
			invoke	InvalidateRect,_hWnd,NULL,FALSE
		.else
			;TODO �ڴ˴���������ļ�ʱ��
			ret
		.endif
		ret
_ProcessTimer	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; ��Ӧ���յ��¼�ʱ�Ĳ���
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_OnRecevingMsg proc 
		local @receivedMsg:NetworkMsg, @sentMsg:NetworkMsg
		.while inputQueue.len != 0
			;��ȡ��Ϣ
			invoke _QueuePop, offset inputQueue, addr @receivedMsg

			;���жϷ���Ϣ���û��Ƿ���������Ͽ�����
			;������������Ͽ������û���������Ϣ

			;���ж��Ƿ��ѶϿ�����
			mov eax, @receivedMsg.sender
			dec eax
			.if dword ptr _sockets[4 * eax] == 0
				.continue
			.endif
			
			;������Ϣ�����������ʵ���Ӧ(��Ӧ��������Ҫ������Ϣ)
			.if (@receivedMsg.inst == 1) && (_onPlaying == 0)
				;���׼����ʼָ��
				mov eax, @receivedMsg.sender
				mov dword ptr _playerAlive[4 * eax], 1
				inc _readyPlayers
				mov eax, _players
				.if eax == _readyPlayers
					;������Ҷ��Ѿ�׼���ã���Ϸ��ʼ
					mov _onPlaying, 1
					mov @sentMsg.inst, 2
					mov @sentMsg.sender, 0
					mov @sentMsg.recver, 0
					mov @sentMsg.msglen, 0
					mov eax, _players
					mov byte ptr @sentMsg.msg[0], al
					invoke _SendMsgTo, 0, addr @sentMsg
				.endif
			.else
				;default choice for missing all branches.

			.endif


			;���ж��Ƿ��ѶϿ�����
			mov eax, @receivedMsg.sender
			dec eax
			.if dword ptr _playerAlive[4 * eax] == 0
				.continue
			.endif
		.endw
		ret
_OnRecevingMsg endp
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
				invoke	_RecvData, wParam
				invoke	_OnRecevingMsg
			.elseif	ax ==	FD_WRITE
				invoke	_SendData, wParam	;�������ͻ���������
			.elseif	ax ==	FD_CLOSE
				invoke	_OnSocketClose, wParam
				;todo: ����Ϸ�����У����ӵ��û�����Ϊ0����1��ʱ���Ϳ�����ֹ��Ϸ
			.elseif ax ==	FD_ACCEPT
				invoke  _OnSocketAccept, hWnd
			.endif
;********************************************************************
		.elseif	eax ==	WM_TIMER
			invoke	_ProcessTimer, hWnd, wParam
;********************************************************************
		.elseif	eax ==	WM_PAINT
			invoke	BeginPaint,hWnd,addr @stPS
			invoke	_OnPaint,hWnd,eax 
			invoke	EndPaint,hWnd,addr @stPS
;********************************************************************
		.elseif	eax ==	WM_CREATE
			invoke	_InitServer, hWnd
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
