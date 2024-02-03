[org 0x7c00]

; 设置屏幕模式为文本模式，清除屏幕
mov ax, 3
int 0x10

; 初始化段寄存器
mov ax, 0
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7c00

; xchg bx, bx; bochs 魔术断点

mov si, booting
call print

mov edi, 0x1000 ; 读取硬盘数据存放的内存位置
mov ecx, 2 ; 读取硬盘起始扇区
mov bl, 4 ; 读取硬盘扇区数量 

call read_disk

cmp word [0x1000], 0x55aa
jnz error

jmp 0:0x1002

; 阻塞
jmp $

; 读取硬盘
read_disk:

    ; 第1步，设置要读取的扇区数量。
    ; 这个数值要写入**0x1f2**端口。
    mov dx, 0x1f2
    mov al, bl
    out dx, al

    ; 第2步，设置起始LBA扇区号。扇区的读写是连续的，因此只需要给出第一个扇区的编号就可以了。
    ; 28位的扇区号太长，需要将其分成4段，分别写入端口 0x1f3、0x1f4、0x1f5 和 0x1f6。
    inc dx ; 0x1f3
    mov al, cl ; 0x1f3号端口存放的是0～7位
    out dx, al

    inc dx; 0x1f4
    shr ecx, 8
    mov al, cl ; 0x1f4号端口存放的是8～15位
    out dx, al

    inc dx; 0x1f5
    shr ecx, 8
    mov al, cl ; 0x1f5号端口存放的是16～23位
    out dx, al

    inc dx ; 0x1f6
    shr ecx, 8
    and cl, 0b1111 ; 0x1f6端口的低4位用于存放逻辑扇区号的24～27位

    mov al, 0b1110_0000 ; 第4位用于指示硬盘号，0表示主盘，1表示从盘。高3位是“111”，表示LBA模式。
    or al, cl
    out dx, al

    ; 第3步，向端口 0x1f7 写入0x20，请求硬盘读。
    inc dx ; 0x1f7
    mov al, 0x20 ; 读硬盘
    out dx, al

    xor ecx, ecx ; 将 ecx 清空
    mov cl, bl ; 得到读写扇区的数量

    
    .read:
        push cx ; 保存 cx
        call .waits ; 等待数据准备完毕
        call .reads ; 读取一个扇区
        pop cx ; 恢复 cx
        loop .read

    ret
    
    ; 第4步，等待读写操作完成。
    .waits:
        mov dx, 0x1f7
        .check:
            in al, dx
            jmp $+2 ; nop 直接跳转到下一行
            jmp $+2 ; 一点点延迟
            jmp $+2
            and al, 0b1000_1000
            cmp al, 0b0000_1000
            jnz .check
        ret

    ; 第5步，连续取出数据。``0x1f0``是硬盘接口的数据端口，而且还是一个16位端口。
    .reads:
        mov dx, 0x1f0
        mov cx, 256 ; 一个扇区 256 字
        .readw:
            in ax, dx
            jmp $+2; 一点点延迟
            jmp $+2
            jmp $+2
            mov [edi], ax
            add edi, 2
            loop .readw
        ret

;打印 booting 汇编地址处的内存
print:
    mov ah, 0x0e
.next:
    mov al, [si]
    cmp al, 0
    jz .done
    int 0x10
    inc si
    jmp .next
.done:
    ret

booting:
    db "Booting Onix...", 10, 13, 0; \n\r

error:
    mov si, .msg
    call print
    hlt; 让 CPU 停止
    jmp $
    .msg db "Booting Error!!!", 10, 13, 0
    
; 填充 0
times 510 - ($ - $$) db 0

; 主引导扇区的最后两个字节必须是 0x55 0xaa
; dw 0xaa55
db 0x55, 0xaa