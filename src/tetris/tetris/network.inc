include		windows.inc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Equ等值定义
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
NETWORK_BUFFER_LENGTH	equ		8192
NETWORK_MSGBUF_LENGTH	equ		128;任意时刻，最多可有128条未读消息和未发消息。

	.data?
NetworkMsg  struct;收发队列均用该结构体
	inst	dword	0;指令的类型，从0~255.
	sender	dword	0;发送指令的用户，0代表服务器，1~255代表客户端，此参数不总是起作用
	recver	dword	0;接收指令的用户，0代表服务器，1~255代表客户端，此参数不总是起作用
	msglen  dword	0;消息体的长度。TODO:确定，当发送时，是否要求填写此条目
	msg		byte	256	dup(0);消息体，*不要*提交超过253个字节（尽管预留了256Bytes）
NetworkMsg	ends

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  网络I/O
;  逻辑层不要操作这里的任何内容
;  总是调用提供的接口收、发数据
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
readBuffer		byte		NETWORK_BUFFER_LENGTH  dup(0)
writeBuffer		byte		NETWORK_BUFFER_LENGTH  dup(0)
readBfCnt		dword		0
writeBfCnt		dword		0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  逻辑层网络接口
;  可以操作这里进行收发数据
;  本质是循环队列
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MsgQueue	struct;收发队列均用该结构体
	te		dword			10 dup(0)
	msgs	NetworkMsg		NETWORK_MSGBUF_LENGTH dup(<>);消息队列
	
	len		dword			0;队列长度
	head	dword			0;队列头
MsgQueue	ends

inputQueue	MsgQueue	<>
outputQueue	MsgQueue	<>
;TODO 写个操作消息队列的函数.