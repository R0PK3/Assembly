.model tiny
.code
org 0100h
start:
	not ax
	xlat
	xlat
	not di
	not bx
	not si
	not ah
	mov ax, 54h
	mov dx, di
	mov bx, si
	mov bx, 6541h
	mov dh, ah
	mov kint, ax
	mov ax, kint
	mov es, dx
	mov es, ax
	mov ss, si
	mov ds, sp
	mov ss, di
    out 94h, al
    out 51h, ax
    out dx, al
    out dx, al
    out dx, ax
	xlat
	rcr ax, 2
	rcr al, 1
	rcr al, 1
	kint dw 0h
	kint2 db 1h
	add al, bl
end start