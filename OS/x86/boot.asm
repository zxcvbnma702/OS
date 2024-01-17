; 0xb800 文本缓冲区开始
mov ax, 0xb800
mov ds, ax

mov byte [0], 'u'

halt:
    jmp halt

times 510 -($ -$$) db 0
;主引导扇区最后两字节规定为0x55, 0xaa
;dw 0xaa55 cpu小端存储
db 0x55, 0xaa