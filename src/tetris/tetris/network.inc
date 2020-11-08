;Hint 如果修改了这个文件中的变量，需要重新生成项目

;include		windows.inc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Equ等值定义
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TCP_PORT				equ		10086;Server will need to listen on 10086.
NETWORK_BUFFER_LENGTH	equ		8192
NETWORK_MSGBUF_LENGTH	equ		128;任意时刻，最多可有128条未读消息和未发消息。
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
serverIpAddr	db		    '127.0.0.1', 0, 10 DUP(0) 	;use localhost to test network
_ipLen			dword		9
_ipStr			db			'127.0.0.1', 20 dup(0)
hSocket			dd			?
readBuffer		byte		NETWORK_BUFFER_LENGTH	dup(0)
writeBuffer		byte		NETWORK_BUFFER_LENGTH	dup(0)
readBfCnt		dword		0
writeBfCnt		dword		0


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

inputQueue	MsgQueue	<>
outputQueue	MsgQueue	<>
;TODO 写个操作消息队列的函数.

		.const
szErrIP		db	'无效的服务器IP地址!',0
szErrConnect	db	'无法连接到服务器!',0
szErrLogin	db	'无法登录到服务器，请检查用户名密码!',0
szSpar		db	' : ',0
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