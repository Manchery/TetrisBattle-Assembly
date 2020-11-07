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
include		wsock32.inc
includelib	wsock32.lib
include		network.inc
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; Equ 等值定义
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ICO_MAIN				equ		1000h
ID_TIMER				equ		1
WINDOW_WIDTH			equ		300
WINDOW_HEIGHT			equ		200
TIMER_MAIN_INTERVAL		equ		10;ms
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 数据段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.data?
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 结构体定义(注意对齐，或总是使用DWORD)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
hInstance	dd		?
hWinMain	dd		?
hListenSocket	dd	?	;监听套接字，也使用WSASyncSelect监听accept事件
dwCenterX	dd		?	;圆心X
dwCenterY	dd		?	;圆心Y
dwRadius	dd		?	;半径

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	游戏状态
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
_onPlaying	dword	0;0 for notplay, 1 forplaying
_players	dword	0;a count for players
		.const
szClassName	db	'Tetris Server',0
szErrBind	db	'绑定到TCP端口10086时出错，请检查是否有其它程序在使用!',0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 代码段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 断开连接
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_Disconnect	proc
		local @cnt:dword
		pushad

		;清理缓冲区和变量
		mov inputQueue.len,		0
		mov	_players, 0

		;断开监听套接字
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
				; 清空结构体等
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
		;用户在DisconnectScreen中按下空格回到主界面。i.e.
		;invoke _ShowDisconnectScreen
		popad
		ret
_Disconnect	endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 连接到服务器
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_StartListen proc _hWnd	;_lParam;We dont need this params, for now.
		local	@stSin:sockaddr_in, @on:dword

;********************************************************************
; 创建 socket
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
; 开始监听，等待连接进入并为每个连接更新状态
;********************************************************************
		;设置监听套接字的最大队列数量及将其加入到消息循环中
		;绑定到WSASyncSelect之后用事件响应连入操作。
		;FD_CLOSE大概要判断下是不是监听套接字。如果是监听套接字就退出程序(或重连)吧。
		invoke	WSAAsyncSelect,hListenSocket,_hWnd,WM_SOCKET,FD_ACCEPT or FD_CLOSE
		invoke	listen,hListenSocket,100
		;下面的代码不在此处处理。
		;所以除了最后退出程序之外，貌似没有必要提前关闭hListenSocket
		;TODO:这句要注释
		;invoke	closesocket,hListenSocket
		ret
_StartListen	endp


;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 响应关闭事件
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_OnSocketClose proc @closedSocket
		local @cnt
		mov eax, @closedSocket
		.if(eax == hListenSocket)
			;监听服务器已关闭
			;关闭所有余下链接，终止服务器
			;TODO:关闭所有余下链接
			invoke closesocket, hListenSocket
			invoke ExitProcess, 0
		.endif
		;用户连接已关闭
		;直接清空这个连接即可
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
				; 清空结构体等
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
; 将消息加入队列
; 如果队列已满，则最早的一条消息将被覆盖
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_QueuePush	proc _queue, _msg
	pushad
	;获取队列的地址
	mov esi, _queue
	; esi points at queue len
	add esi, type NetworkMsg * NETWORK_MSGBUF_LENGTH
	mov edi, esi
	; edi points at queue head
	add edi, type dword
	mov ebx, [esi]		;获取长度
	mov eax, [edi]		;获取Head
	add eax, ebx
	.if eax >= NETWORK_MSGBUF_LENGTH
		sub eax, NETWORK_MSGBUF_LENGTH
	.endif
	;插入点在eax，接下来将其转换为队列中的地址
	mul typeNetworkMsg
	add eax, _queue
	;拷贝结构体
	invoke _CopyMemory, eax, _msg, type NetworkMsg
	;更新队列数据
	.if dword ptr [esi] == NETWORK_MSGBUF_LENGTH
		;队列已满，则队列头部后移，覆盖最早的消息
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
; 将消息弹出队列、并把弹出的消息返回到_msg所指向的位置（请留下充足的空间）
;（函数将修改eax.）
; 返回值: eax == 0 ,if it's already empty before pop
;		 eax != 0 ,otherwise
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_QueuePop	proc _queue, _msg
			local @isEmpty
	pushad
	;获取队列的地址
	mov esi, _queue
	; esi points at queue len
	add esi, type NetworkMsg * NETWORK_MSGBUF_LENGTH
	mov edi, esi
	; edi points at queue head
	add edi, type dword
	mov ebx, [esi]		;获取长度
	.if ebx == 0		;若长度为0，直接返回eax = 0
		mov @isEmpty, 0
		jmp _Ret
	.endif
	mov @isEmpty, 1
	mov eax, [edi]		;获取Head
	;弹出点在eax，接下来将其转换为队列中的地址
	mul typeNetworkMsg
	add eax, _queue
	;拷贝结构体
	invoke _CopyMemory, _msg, eax, type NetworkMsg
	;更新队列数据
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
; 处理缓冲区数据为消息结构体
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
; 接收数据包
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_RecvData	proc @socket
		local	@tmpBuffer[512]:byte, @msgLength
		local	@playerMsg, @socketaddr, @cnt

		pushad
		;计算读结构体的位置
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
		;没有找到指定结构体
		.if @cnt == MAX_PLAYERS
			ret
		.endif

		;将esi指向接收缓冲区中下一个可写的位置
		;ecx是缓冲区中已有的数据长度。
		mov ebx, @playerMsg
		lea edx, (Client ptr [ebx]).readBuffer
		mov	esi, edx
		lea edx, (Client ptr [ebx]).readBfCnt
		mov	ecx, [edx]
		add	esi,ecx
;********************************************************************
		;将eax指向剩余可用的全部缓冲区大小
		;并接收消息
		mov	eax, NETWORK_BUFFER_LENGTH
		sub	eax, ecx
		;added for debug/test
		;jmp _Recved;added for debug/test
		.if	eax ;这个判断实际上是不必要的，
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
; 如果整个数据包接收完毕，则进行处理
;********************************************************************
_Recved:
		;while循环解决可能存在的粘包现象。
		;将esi定位到buffer头部
		lea edx, (Client ptr [ebx]).readBuffer
		mov	esi, edx
		;todo check if this is fine
		.while dword ptr (Client ptr [ebx]).readBfCnt > 0
			movzx	eax, byte ptr[esi];获取下一条消息的长度
			mov		@msgLength, eax
			inc		eax;将readBuffer[0]计算在内
			.break .if eax > dword ptr (Client ptr [ebx]).readBfCnt;收到的信息不完整，返回，等待下次接收
			sub		(Client ptr [ebx]).readBfCnt, eax;readBfCnt -= Current Msg Length
			inc		esi
			invoke	_ProcessMsg, esi, @msgLength; ProcessMsg将保存esi和ebx.
			add		esi, @msgLength
		.endw
		
		;如果还有剩余的字符串，就把它复制到buffer头部。
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
; 发送缓冲区中的数据，上次的数据有可能未发送完，故每次发送前，
; 先将发送缓冲区合并
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_SendData	proc @socket
		local	@remainBfSize, @pendingMsg:NetworkMsg
		local	@playerMsg, @socketaddr, @cnt

		pushad
		;计算写结构体的位置
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
		;没有找到指定结构体
		.if @cnt == MAX_PLAYERS
			ret
		.endif
;********************************************************************
; 检测发送队列中是否还有数据，如果有，
; 就尝试将要发送的内容加到缓冲区的尾部
;********************************************************************
		.while TRUE
			; 计算缓冲区余下部分的长度
			mov ebx, @playerMsg
			mov eax, NETWORK_BUFFER_LENGTH
			sub eax, (Client ptr [ebx]).writeBfCnt
			mov @remainBfSize, eax
			;从队列中循环抽取结构体
			;直到队空或者缓冲区满
			.while dword ptr (Client ptr [ebx]).outputQueue.len != 0
				push ebx
				invoke _QueuePop, addr (Client ptr [ebx]).outputQueue, addr @pendingMsg
				pop ebx
				mov eax, @pendingMsg.msglen
				add	eax, 4
				.break .if eax > @remainBfSize ;缓冲区满
				lea edx, (Client ptr [ebx]).writeBuffer
				mov esi, edx
				add esi, (Client ptr [ebx]).writeBfCnt
				sub @remainBfSize, eax
				add (Client ptr [ebx]).writeBfCnt, eax
				;拷贝前4个数值到writeBuffer中
				dec	eax
				mov [esi], al
				mov	eax, @pendingMsg.inst
				mov	[esi + 1], al
				mov	eax, @pendingMsg.sender
				mov	[esi + 2], al
				mov	eax, @pendingMsg.recver
				mov	[esi + 3], al
				add esi, 4
				;复制余下的消息体到writeBuffer中
				.if @pendingMsg.msglen > 0
					invoke _CopyMemory, esi, addr @pendingMsg.msg, @pendingMsg.msglen
				.endif
			.endw
			mov ebx, @playerMsg
			.break .if dword ptr (Client ptr [ebx]).writeBfCnt == 0;如果已没有需要发送的数据，退出循环
			@@:
				lea edx, (Client ptr [ebx]).writeBuffer
				mov	esi, edx
				mov	ebx,(Client ptr [ebx]).writeBfCnt
				or	ebx,ebx
				jz	_Ret
				;The line below is necessary for program:
				invoke	send,@socket,esi,ebx,0

				;for debug/todo:
				;模拟5个字节成功发送的事件
				;mov ecx, @playerMsg
				;.if dword ptr (Client ptr [ecx]).writeBfCnt > 5
				;	mov eax, 5
				;.else
				;	mov eax, (Client ptr [ecx]).writeBfCnt
				;.endif

				;异常处理
				.if	eax ==	SOCKET_ERROR
					invoke	WSAGetLastError
					.if	eax !=	WSAEWOULDBLOCK
						;如果发送时遇到除了缓冲区满之外的错误
						;直接断开连接
						invoke	_OnSocketClose, @socket
					.endif
					jmp	_Ret
				.endif
				.if (eax == 0) || (eax > NETWORK_BUFFER_LENGTH)
					;写0或负数字节
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
; 把消息发给指定的用户
; 0代表所有与服务器保持连接的客户端；
; 1~4代表具体的用户。
; 返回值：成功发送的用户个数
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
; 响应连接到服务器的事件：一次一条
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_OnSocketAccept proc _hWnd
				local @connectMsg:NetworkMsg
		;响应接入的连接
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

			;发送初始化消息(消息指令为0)
			invoke	RtlZeroMemory, addr @connectMsg, type NetworkMsg
			mov eax, _players
			inc eax
			mov @connectMsg.recver, eax
			invoke _SendMsgTo, _players, addr @connectMsg

			;维护计数器
			inc _players
		.endif
		;并不是，我们只有通过关闭套接字的方式才能阻止新传入的连接...
		;回上面。。但也不一定。。就让它们在队列里等着不香嘛233
		;所以除了最后退出程序之外，貌似没有必要提前关闭hListenSocket
		;所以下面这句应该放在程序退出前
		;invoke	closesocket,hListenSocket
		ret
_OnSocketAccept	endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_InitServer	proc  _hWnd
		local	@stWsa:WSADATA
		;初始化网络
		invoke	WSAStartup, 101h, addr @stWsa
		invoke  _StartListen, _hWnd

		;设置定时器
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
		;invoke _DrawCustomizedBackground, @bufferDC
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
_OnSendingMsg	proc  _hWnd
		local @testNetworkMsg:NetworkMsg
		;TODO 在这里写服务器的发送事件的逻辑

		
		ret
_OnSendingMsg	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcessTimer	proc  _hWnd, timerId
		;TODO 调用ProcessTimer，以判断具体的定时器类型并做出响应。
		;如，当前的定时器可能是UpdateFrame计时器，
		;此时我们就计算当前的状态，并修改对应的状态。
		.if timerId == ID_TIMER
			invoke	_OnSendingMsg, _hWnd
			invoke	InvalidateRect,_hWnd,NULL,FALSE
		.else
			;TODO 在此处添加其它的计时器
			ret
		.endif
		ret
_ProcessTimer	endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 响应接收到事件时的操作
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_OnRecevingMsg proc 
		local @receivedMsg:NetworkMsg, @sentMsg:NetworkMsg
		.while inputQueue.len != 0
			;提取消息
			invoke _QueuePop, offset inputQueue, addr @receivedMsg

			;先判断发消息的用户是否已死亡或断开连接
			;无视已死亡或断开连接用户发来的消息

			;先判断是否已断开连接
			mov eax, @receivedMsg.sender
			dec eax
			.if dword ptr _sockets[4 * eax] == 0
				.continue
			.endif
			
			;解析信息，并做出合适的响应(响应不必总是要发回消息)
			.if (@receivedMsg.inst == 1) && (_onPlaying == 0)
				;玩家准备开始指令
				mov eax, @receivedMsg.sender
				mov dword ptr _playerAlive[4 * eax], 1
				inc _readyPlayers
				mov eax, _players
				.if eax == _readyPlayers
					;所有玩家都已经准备好，游戏开始
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


			;再判断是否已断开连接
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
; 处理 Socket 消息
;********************************************************************
			mov	eax,lParam
			.if	ax ==	FD_READ
				invoke	_RecvData, wParam
				invoke	_OnRecevingMsg
			.elseif	ax ==	FD_WRITE
				invoke	_SendData, wParam	;继续发送缓冲区数据
			.elseif	ax ==	FD_CLOSE
				invoke	_OnSocketClose, wParam
				;todo: 当游戏过程中，连接的用户数量为0（或1）时，就考虑终止游戏
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
