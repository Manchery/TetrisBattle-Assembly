;Hint ����޸�������ļ��еı�������Ҫ����������Ŀ

;include		windows.inc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Equ��ֵ����
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TCP_PORT				equ		10086;Server will need to listen on 10086.
NETWORK_BUFFER_LENGTH	equ		8192
;todo change 4 to 128. 4 is used for debugging.
NETWORK_MSGBUF_LENGTH	equ		128;����ʱ�̣�������128��δ����Ϣ��δ����Ϣ��
WM_SOCKET				equ		WM_USER + 100
	.data
NetworkMsg  struct;�շ����о��øýṹ��
	inst	dword	0;ָ������ͣ���0~255.
	sender	dword	0;����ָ����û���0������������1~255�����ͻ��ˣ��˲���������������
	recver	dword	0;����ָ����û���0������������1~255�����ͻ��ˣ��˲���������������
	msglen  dword	0;��Ϣ��ĳ��ȡ�TODO:ȷ����������ʱ���Ƿ�Ҫ����д����Ŀ
	msg		byte	256	dup(0);��Ϣ�壬*��Ҫ*�ύ����250���ֽڣ�����Ԥ����256Bytes��
NetworkMsg	ends

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  ����I/O
;  �߼��㲻Ҫ����������κ�����
;  ���ǵ����ṩ�Ľӿ��ա�������
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
serverIpAddr	db		    '127.0.0.1', 0	;use localhost to test network
hSocket			dd			?
readBuffer		byte		NETWORK_BUFFER_LENGTH	dup(0)
writeBuffer		byte		NETWORK_BUFFER_LENGTH	dup(0)
readBfCnt		dword		0
writeBfCnt		dword		0


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  �߼�������ӿ�
;  ���Բ�����������շ�����
;  ������ѭ������
;  **����ʱ�����������ݽ����滻���������**
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;�Ͻ��޸Ĵ˽ṹ��Ķ���
;�޸�ǰ����ϵzysj
MsgQueue	struct;�շ����о��øýṹ��
	msgs	NetworkMsg		NETWORK_MSGBUF_LENGTH dup(<>);��Ϣ����
	len		dword			0;���г���
	head	dword			0;����ͷ
MsgQueue	ends

inputQueue	MsgQueue	<>
outputQueue	MsgQueue	<>
;TODO д��������Ϣ���еĺ���.

		.const
szErrIP		db	'��Ч�ķ�����IP��ַ!',0
szErrConnect	db	'�޷����ӵ�������!',0
szErrLogin	db	'�޷���¼���������������û�������!',0
szSpar		db	' : ',0
typeNetworkMsg dword type NetworkMsg
testString  db  5, 'abcde', 3, 20, 30, 40, 4, '1234' 
testStrlen  dword 15

		.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; �ڴ渴�ƺ�����������ĩβ����0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_CopyMemory	proc uses esi edi ecx, _dest, _src, len
	mov		esi, _src
	mov		edi, _dest
	mov		ecx, len
	cld
	rep		movsb
	ret
_CopyMemory	endp

;Hint ����޸�������ļ��еı�������Ҫ����������Ŀ