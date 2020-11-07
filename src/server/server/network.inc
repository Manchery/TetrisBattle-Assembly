;Hint 如果修改了这个文件中的变量，需要重新生成项目

;include		windows.inc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Equ等值定义
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TCP_PORT				equ		10086;Server will need to listen on 10086.
NETWORK_BUFFER_LENGTH	equ		8192
NETWORK_MSGBUF_LENGTH	equ		256;任意时刻，最多可有256条未读消息和未发消息。
MAX_PLAYERS				equ		4;最大的可支持的玩家数量
WM_SOCKET				equ		WM_USER + 100
	.data
NetworkMsg  struct;收发队列均用该结构体
	inst	dword	0;指令的类型，从0~255.
	sender	dword	0;发送指令的用户，0代表服务器，1~255代表客户端，此参数不总是起作用
	recver	dword	0;接收指令的用户，0代表服务器，1~255代表客户端，此参数不总是起作用
	msglen  dword	0;消息体的长度。TODO:确定，当发送时，是否要求填写此条目
	msg		byte	256	dup(0);消息体，*不要*提交超过250个字节（尽管预留了256Bytes）
NetworkMsg	ends

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  网络I/O
;  逻辑层不要操作这里的任何内容
;  总是调用提供的接口收、发数据
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
hSocket			dd			?

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  逻辑层网络接口
;  可以操作这里进行收发数据
;  本质是循环队列
;  **队满时，后到来的数据将会替换最早的数据**
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;严禁修改此结构体的定义
;修改前请联系zysj
MsgQueue	struct;收发队列均用该结构体
	msgs	NetworkMsg		NETWORK_MSGBUF_LENGTH dup(<>);消息队列
	len		dword			0;队列长度
	head	dword			0;队列头
MsgQueue	ends

Client			struct
	readBuffer		byte		NETWORK_BUFFER_LENGTH	dup(0)
	writeBuffer		byte		NETWORK_BUFFER_LENGTH	dup(0)
	outputQueue		MsgQueue    <>; 输出队列被移动到了这里
	readBfCnt		dword		0
	writeBfCnt		dword		0
Client			ends

inputQueue		MsgQueue	<>
_playerMsgs		Client		MAX_PLAYERS dup(<>)
;_sockets可同时用来判断连接状态
;如果_sockets == 0，就代表已断开连接
;因此，总是需要及时清空_sockets.
_sockets		dword		MAX_PLAYERS dup(0) 
_playerAlive	dword		MAX_PLAYERS dup(0)
_readyPlayers	dword		0;这个还没加到清缓存的部分中
_gameBoard		byte		160 dup(0) 
		.const
typeNetworkMsg dword type NetworkMsg
testString  db  5, 'abcde', 3, 20, 30, 40, 4, '1234' 
testStrlen  dword 15

		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 内存复制函数，不会在末尾添加0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_CopyMemory	proc uses esi edi ecx, _dest, _src, len
	mov		esi, _src
	mov		edi, _dest
	mov		ecx, len
	cld
	rep		movsb
	ret
_CopyMemory	endp


;Hint 如果修改了这个文件中的变量，需要重新生成项目