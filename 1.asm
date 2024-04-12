;Robertas Buracevskis
;VU MIF PS1 1 grupe 1 kursas
;1 uzd. apdoroti MOV,OUT, NOT, RCR, XLAT

.model small
dydis EQU 512
.stack 100h

.data
	input 	db 13 dup(?) ;failu vardai
	output	db 13 dup(?)
	
	inputFH	dw	0	;failu handleriai/deskriptoriai
	outputFH dw 1
	
	skaitymo_buff db dydis dup (?) ;in_buff
	skaitymo_ilgis dw dydis		 ;read_length
	skaitymo_buff_ilgis dw dydis	 ;in_buff_length
	skaitymo_pabaiga dw 0		 ;in_buff_end
	
	rasymo_buff db dydis dup(?)	 ;out_buff
	rasymo_ilgis dw dydis         ;print_length
	rasymo_buff_instr dw 0      ;out_buff_i
	instr_buff db 50 dup(?)      ;instr_buff
	inst_ilgis db 0 			 ;instr_length
	instr_pointer dw ?			 ;instr_pointer
	
	inst_mov db "mov"
	inst_out db "out"
	instr_not db "not"
	instr_rcr db "rcr"
	instr_xlat db "xlat"
	instr_nezinoma db "Unknown"
	instr_pabaiga db "end"
	
	ip_reiksme dw 0
	d_reiksme db 0
	w_reiksme db 0
	mod_reiksme db 0
	reg_reiksme db 0
	rm_reiksme db 0
	port_reiksme db 0
	sreg_reiksme db 0
	poslinkio_reiksme dw 0
	vertimas_hex db 0
	praleisti_h db 0
	prefixas db 0
	end_of_file db 0
	
	simboliai db " ,[]:+"
	hex_reiksmes db "0123456789ABCDEF"
	registrai db "alcldlblahchdhbhaxcxdxbxspbpsidi"
	rm_registrai_pirma db "bx+sibx+dibp+sibp+di"
	rm_registrai_antra db "sidibpbx"
	segmentu_registrai db "escsssds"
	
	klaida1 db "Klaida atidarant .com faila$"
	klaida2 db "Klaida sukuriant rezultatu faila$"
	klaida3 db "Klaida uzdarant .com faila$"
	klaida4 db "Klaida uzdarant rezultatu faila$"
	klaida5 db "Klaida skaitant$"
	pagalbos_pranesimas db "Si programa vercia masinini koda i zmogui suprantama assembly koda$"
	exit_msg db "Programa baige darba$"
	
	newline	db 0Dh, 0Ah, 24h
	
.code
start:
	mov dx, @data
	mov ds, dx
	
	mov si, 0081h
	xor bx, bx
	mov cx, -1

;---------------------
;parametru nuskaitymas
;---------------------
parametrai:
	mov al, byte ptr es:[si] ;parametrai bus issaugoti al registre
	
	cmp al, 13 ;ar newline?
	je check_errors ;ar visi reikiami parametrai suvesti?
	
	cmp al, 20h ;ar tarpas? (pirmo parametro pabaiga)
	je tarpai
	
	cmp al, '/'; ar vartotojas bando ivesti /?
	je pagalbos_tikrinimas
	
	inc si ;issaugojame simboliai
	jmp write
	
pagalbos_tikrinimas:
	inc si
	mov al, byte ptr es:[si] ;tikriname ar sekantis baitas yra ?
	cmp al, '?'
	jne write_init
	
pagalba:
	mov ah, 09h
	mov dx, offset pagalbos_pranesimas
	int 21h
	
	mov ax, 4c00h
	int 21h
	
write_init:	;mini pataisymas ir rasymas i failu bufferius
	dec si
	mov al, byte ptr es:[si]
	inc si
    jmp write
	
tarpai:
	inc si
	mov al, byte ptr es:[si] ;praleidziami visi tarpai
	cmp al, 20h
	je tarpai
	inc cx ;kelintas parametras
	mov bx, 0 ;naujo parametro indexas
	jmp parametrai
	
check_errors:
	cmp cx, 0
	je atidaryti_duom
	
	cmp cx, 1
	je atidaryti_duom
	
	cmp cx, 2
	je atidaryti_duom
	
	jmp pagalba
	
write:
	cmp cx, 0
	je pirmas_parametras
	
	cmp cx, 1
	je antras_parametras
	
	jmp pagalba
	
pirmas_parametras:
	mov [input + bx], al ;pirmo failo vardas
	inc bx
	jmp parametrai
	
antras_parametras:
	mov [output + bx], al ;antro (rez) failo vardas
	inc bx
	jmp parametrai
	
;---------------------------------
;Failu atidarymai, sukurimai
;---------------------------------
atidaryti_duom:
	
	mov ax, 3D00h
	mov dx, offset input
	int 21h
	
	jc klaida1_error
	mov inputFH, ax
	jmp atidaryti_rez
	
klaida1_error:
	lea dx, klaida1
	call spausdinti
	
	mov ax, 4c00h
	int 21h	
	
atidaryti_rez:
	xor cx,cx
	
	mov ax, 3c00h
	mov dx, offset output
	int 21h
	
	jc klaida2_error
	mov outputFH, ax
	jmp skait_ras_buff
		
klaida2_error:
	lea dx, klaida2
	call spausdinti


skait_ras_buff:
	mov ax, ds
	mov es, ax
	xor ax, ax
	lea si, skaitymo_buff
	lea di, instr_buff
	mov instr_pointer, di
	lea di, rasymo_buff
	
	xor ax, ax
	xor bx, bx
	xor cx, cx
	xor dx, dx
	
;---------------------------
; Pagrindine programos dalis
;---------------------------
main:
	call IPskaiciavimas ;IP nustatymas
	call skaitymas ;skaitome po 512 baitu
	cmp end_of_file, 1
	je main_pabaiga
	
	xor dh, dh
	mov dl, byte ptr [si]
	call Nustatymas  ;kuri tai instrukcija?
	
	mov cx, 1
	call CheckOutBuff
	mov byte ptr[di], 20h ;tarpas
	
	inc di
	inc rasymo_buff_instr


	push si
	mov cl, inst_ilgis
	lea si, instr_buff ;dedame instrukcija i bendra bufferi
	call PushToOutBuff ; instrukcija dedama i rasymo bufferi
	mov inst_ilgis, 0 ;nunulinamas instrukcijos ilgis
	lea si, instr_buff
	mov instr_pointer, si
	pop si
	call pushnewline

	cmp rasymo_buff_instr, dydis ;ar pilnai uzpildytas bendras bufferis
	jb main ;skaitome toliau
	call spausdinti
	
	jmp main
	
main_pabaiga:
	mov cx, 3
	lea si, instr_pabaiga
	call PushToOutBuff
	call print
	
;duomenu failo uzdarymas
	cmp inputFH, 0
	je rezultatu_uzdarymas
	mov ah, 3Eh
	mov bx, inputFH
	int 21h
	jc klaida3_error
	jmp rezultatu_uzdarymas

klaida3_error:
	lea dx, klaida3
	call spausdinti

rezultatu_uzdarymas:
	cmp outputFH, 1
	je exit
	mov ah, 3Eh
	mov bx, outputFH
	int 21h
	jc klaida4_error
	jmp exit

klaida4_error:
	lea dx, klaida4
	int 21h
	
exit:
	mov ah, 09h
	mov dx, offset 	exit_msg
	int 21h
	
	mov ax, 4c00h
	int 21h

;-----------
; Proceduros
;-----------
PROC Nustatymas
	cmp dl, 26h
	jne skip_es
	mov prefixas, 0
	jmp segmentas
	
skip_es:
	cmp dl, 2Eh
	jne skip_cs
	mov prefixas, 1
	jmp segmentas
	
skip_cs:
	cmp dl, 36h
	jne skip_ss
	mov prefixas, 2
	jmp segmentas
	
skip_ss:
	cmp dl, 3Eh
	jne skip_ds
	mov prefixas, 3
	jmp segmentas
	
skip_ds:
	mov prefixas, 4
	jmp nesegmentas
	
segmentas:
	call skaitymas
	mov dl, byte ptr [si]
	
nesegmentas:
;---
;MOV
;---
	mov al, dl
	xor al, 10001000b ;jei tai mov_1 turetu skirtis/arba ne tik paskutiniai du bitai (didziausia reiksme 3 - 00000011)
	cmp al, 4
	jae mov_1 ;jei didesnis ar lygus
	call mov_1_detected
	ret
	
mov_1:
	mov al, dl
	xor al, 11000110b ;jei tai mov_2 gali skirtis tik paskutinis bitas (w), max reiksme 1
	cmp al, 2
	jae mov_2
	call mov_2_detected
	ret
	
mov_2:
	mov al, dl
	xor al, 10110000b;jei tai mov_3 gali skirtis tik paskutiniai 4 bitai, max reiksme 15
	cmp al, 16
	jae mov_3
	call mov_3_detected
	ret
	
mov_3:
	mov al, dl
	xor al, 10100000b; gali skirtins tik paskutinis bitas, jei mov4 arba mov5
	cmp al, 4
	jae mov_4_5
	call mov_4_5_detected
	ret
	
mov_4_5:
	mov al, dl
	xor al, 10001100b; gali skirtis tik priespaskutinis bitas
	shr al, 1 ;shift right
	cmp al, 2 ;max reiksme 1
	jae mov_6
	call mov_6_detected
	ret
	
mov_6:
;---
;OUT
;---
	mov al, dl
	xor al, 11100110b ; gali skirtis tik paskutinis bitas
	cmp al, 2
	jae out_1
	call out_1_detected
	ret
	
out_1:
	mov al, dl
	xor al, 11101110b; gali skirtis tik paskutinis bitas
	cmp al, 2
	jae out_2
	call out_2_detected
	ret

out_2:
;---
;NOT
;---
	mov al, dl
	xor al, 11110110b; gali skirtis tik paskutinis bitas
	cmp al, 2
	jae skip_not
	call not_detected
	ret

skip_not:
;---
;RCR
;---
	mov al, dl
	xor al, 11010000b; gali skirtis tik paskutiniai du bitai
	cmp al, 4
	jae skip_rcr
	call rcr_detected
	ret
	
skip_rcr:
;----
;XLAT
;----
	mov al, dl
	xor al, 11010111b; niekas nesiskiria, turi gautis 0000 0000
	cmp al, 1
	jae skip_xlat
	call xlat_detected
	ret

skip_xlat:
;------------------
;Kitos instrukcijos
;------------------
	call Unknown_instruction
	ret
endp Nustatymas

PROC Nuskaitymas
	push ax
	push bx
	push cx
	push dx
	
	mov ah, 3Fh
	mov bx, inputFH
	mov cx, skaitymo_ilgis
	lea dx, skaitymo_buff
	int 21h
	
	jnc pavyko_nuskaityti
	
;nepavyko_nuskaityti
	mov ah, 09h
	lea dx, klaida5
	int 21h
	
pavyko_nuskaityti:
	lea si, skaitymo_buff
	mov skaitymo_pabaiga, si
	add skaitymo_pabaiga, ax
	mov skaitymo_buff_ilgis, ax
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp Nuskaitymas

PROC print
	push ax
	push bx
	push cx
	push dx
	
	mov ah, 40h
	mov bx, outputFH
	mov cx, rasymo_buff_instr
	lea dx, rasymo_buff
	int 21h
	
	mov rasymo_buff_instr, 0
	lea di, rasymo_buff
	
	pop dx
	pop cx
	pop bx
	pop ax
	ret
endp print

PROC skaitymas
	push dx
	
	cmp si, skaitymo_pabaiga
	jb checkinbuff_skip_read
	
	cmp skaitymo_buff_ilgis, dydis ;?????
	je inc_si_read
	
	mov end_of_file, 1 ;failo pabaiga
	pop dx
	ret
	
inc_si_read:
	call Nuskaitymas
	jmp inc_si_end
checkinbuff_skip_read:
	inc si
inc_si_end:
	inc ip_reiksme
	;masininis kodas
	cmp outputFH,1
	jne skip_incsi_push
	;masininis kodas
	xor dh, dh
	mov praleisti_h, 1
	mov dl, byte ptr[si]
	call PushOutHexValue
	mov praleisti_h, 0
	
skip_incsi_push:
	pop dx
	ret
endp skaitymas

proc CheckOutBuff ;ar isvedimo bufferis uzpildytas
	push ax
	
	mov ax, rasymo_buff_instr
	add ax, cx
	
	cmp ax, rasymo_ilgis ; ar visas bufferis pilnas
	jbe checkoutbuff_skip_print ;jei ne dar nespausdinam
	
	call print
	
checkoutbuff_skip_print:
	pop ax
	ret
endp CheckOutBuff

;Ideti cx simboliu is ds:si i isvedimo bufferi (es:di)
proc PushToOutBuff
	call CheckOutBuff
	add rasymo_buff_instr, cx
	rep movsb
	
	ret
endp PushToOutBuff

proc PushToBuffer
	push di
	add inst_ilgis, cl
	mov di, instr_pointer
	rep movsb
	
	mov instr_pointer, di
	pop di
	ret
endp PushToBuffer

proc PushSpecialSymbol
	push si
	mov cx, 1
	lea si, simboliai + bx
	call PushToBuffer
	pop si
	ret
endp PushSpecialSymbol

proc PushOutHexValue
	;dx yra zodzio reiksme
	push ax
	xor ah,ah
	push si
	mov cx, 5
	call CheckOutBuff
	cmp vertimas_hex, 1
	je pushouthexvalue_force ;jei 2 baitai
	cmp dh, 0
	je pushouthexvalue_byte
	;zmogui suprantamas pavidalas
pushouthexvalue_force:
	mov al, dh
	and al, 0F0h
	shr al, 4
	lea si, hex_reiksmes
	add si, ax
	movsb
	
	mov al, dh
	and al, 0Fh ; 00001111
	lea si, hex_reiksmes
	add si, ax
	movsb
	
	add rasymo_buff_instr, 2
	
pushouthexvalue_byte:
	mov al, dl
	and al, 0F0h
	shr al, 4
	lea si, hex_reiksmes
	add si, ax
	movsb
	
	mov al, dl
	and al, 0Fh
    lea si, hex_reiksmes
	add si, ax
	movsb
	
	add rasymo_buff_instr, 2 ;dvi raides vienas baitas
	
	cmp vertimas_hex, 1
	je pushouthexvalue_skip_h
	cmp praleisti_h, 1
	je pushouthexvalue_skip_h
	mov byte ptr [di],"h"
	inc di
	inc rasymo_buff_instr
pushouthexvalue_skip_h:
	pop si
	pop ax
	ret
endp PushOutHexValue

proc PushHexValue
	push ax
	xor ah, ah
	
	push si
	push di
	
	mov di, instr_pointer
	
	cmp vertimas_hex, 1 ;ip
	je pushhexvalue_force ;jei 2 baitai
	cmp dh, 0
	je pushhexvalue_byte
pushhexvalue_force:
	mov al, dh
	and al, 0F0h ;11110000
	shr al, 4
	lea si, hex_reiksmes
	add si, ax
	movsb
	
	mov al, dh
	and al, 0Fh ;00001111
	lea si, hex_reiksmes
	add si, ax
	movsb
	
	add inst_ilgis, 2
	
pushhexvalue_byte:
	mov al, dl
	and al, 0F0h
	shr al, 4
	lea si, hex_reiksmes
	add si, ax
	movsb
	
	mov al, dl
	and al, 0Fh
	lea si, hex_reiksmes
	add si, ax
	movsb
	
	add inst_ilgis, 2
	
	cmp vertimas_hex, 1
	je pushhexvalue_skip_h
	cmp praleisti_h, 1
	je pushhexvalue_skip_h
	mov byte ptr [di], "h" ;pridedama raide h
	inc di
	inc inst_ilgis
pushhexvalue_skip_h:
	mov instr_pointer, di
	pop di
	pop si
	pop ax
	ret
endp PushHexValue

proc PushNewLine
	mov cx, 2
	call CheckOutBuff
	
	mov byte ptr[di], 13
	inc di
	mov byte ptr[di], 10
	inc di
	
	add rasymo_buff_instr, 2
	ret
endp PushNewLine

proc spausdinti
	push ax
	
	mov ah, 09h
	int 21h
	lea dx, newline
	int 21h
	
	pop ax
	ret
endp spausdinti

proc PushOffset
	mov bx, 5 ;+
	call PushSpecialSymbol
	call read_bytes ;poslinkis
	call PushHexValue
	ret
endp PushOffset

proc read_bytes
	xor dh, dh
	call skaitymas ;KAS TOKS?
	mov dl, [si]
	;mod = 01 ---> vieno baito poslinkis
	;mod = 10 ---> dvieju baitu poslinks
	;tiesioginis adresas ---> dvieju baitu poslinkis
	cmp mod_reiksme, 01b
	je read_b_offset
	call skaitymas ;Irgi
	mov dh, [si]
read_b_offset:
	ret
endp read_bytes

proc read_w_bytes
	xor dh, dh
	call skaitymas
	mov dl, [si]
	cmp w_reiksme, 0
	je read_w_b_offset
	call skaitymas
	mov dh, [si]
read_w_b_offset:
	ret
endp read_w_bytes

proc dwmodregrm
	;w
	mov al, dl
	and al, 1b
	mov w_reiksme, al
	
	;d
	mov al, dl
	and al, 10b
	shr al, 1
	mov d_reiksme, al
	
	;mod reg rm
	call skaitymas
	mov dl, byte ptr [si]
	
	;mod
	mov al, dl
	and al, 11000000b
	shr al, 6
	mov mod_reiksme, al
	
	;reg
	mov al, dl
	and al, 111000b
	shr al, 3
	mov reg_reiksme, al
	
	;rm
	mov al, dl
	and al, 111b
	mov rm_reiksme, al
	
	ret
endp dwmodregrm

proc analizuok_reg
	push si
	xor bh, bh
	
	lea si, registrai
	mov bl, reg_reiksme
	cmp w_reiksme, 0 ; zodziai ar baitai
	je parse_reg_skip_add ; jei zodziai, tai + 8
	add bx, 8 ;al pavirs ax
	
parse_reg_skip_add:
	add bx, bx
	add si, bx
	mov cx, 2
	call PushToBuffer; idedame i bufferi
	
	pop si
	ret
endp analizuok_reg

proc analizuok_sreg
	push si
	xor bh, bh
	;nustatome segmenta
	lea si, segmentu_registrai
	mov bl, sreg_reiksme
	add bx, bx
	add si, bx
	mov cx, 2
	call PushToBuffer
	
	pop si
	ret
endp analizuok_sreg

proc analizuok_rm
    ;mod nusako, koks yra poslinkis, mod 11 - r/m laukas yra registre (AL, AH, BL...)
	cmp mod_reiksme, 11b
	jne rm_skip_mod11
	mov al, rm_reiksme
	mov reg_reiksme, al
	call analizuok_reg
	ret
	
rm_skip_mod11:
	cmp prefixas, 4
	je rm_ne_prefixas
	mov al, prefixas
	mov sreg_reiksme, al
	call analizuok_sreg
	mov bx, 4 ; :
	call PushSpecialSymbol

rm_ne_prefixas:
	mov bx, 2 ; [
	call PushSpecialSymbol
	
	cmp rm_reiksme, 100b
	jb parse_rm_0
	
	cmp rm_reiksme, 110b ;ar tiesioginis adresas
	jne rm_skip_direct
	
	cmp mod_reiksme, 00b
	jne rm_skip_direct


	call read_bytes
	call PushHexValue
	mov bx, 3; ]
	call PushSpecialSymbol
	ret

rm_skip_direct:
	push si
	xor bh, bh
	mov bl, rm_reiksme
	sub bl, 4
	add bl, bl
	mov cx, 2 ; [
	lea si, rm_registrai_antra + bx
	call PushToBuffer
	pop si
	
	;ar reik poslinkio
	cmp mod_reiksme, 00b
	je rm_registrai_antra_be_poslinkio
	call PushOffset
	
rm_registrai_antra_be_poslinkio:
	mov bx, 3 ;]
	call PushSpecialSymbol
	ret
	
parse_rm_0:
	push si
	xor bh, bh
	mov bl, rm_reiksme
	;nustatome pozicija
	mov cx, 5
	mov al, bl
	mul cl
	mov bl, al
	lea si, rm_registrai_pirma + bx
	call PushToBuffer
	pop si
	
	cmp mod_reiksme, 00b
	je rm_registrai_pirma_be_poslinkio
	call PushOffset
	
rm_registrai_pirma_be_poslinkio:
	mov bx, 3 ; ]
	call PushSpecialSymbol
	ret
endp analizuok_rm

proc IPskaiciavimas
	push dx
	mov vertimas_hex, 1
	mov dx, ip_reiksme
	call PushOutHexValue
	pop dx
	mov vertimas_hex, 0
	
	mov cx, 2
	call CheckOutBuff
	mov byte ptr [di], ":"
	inc di
	mov byte ptr [di], " "
	inc di
	add rasymo_buff_instr, 2
	ret
endp IPskaiciavimas

proc mov_detected
	push si
	
	mov cx, 3
	lea si, inst_mov
	call PushToBuffer ; i bufferi ikeliama mov instrukcija
	mov bx, 0
	call PushSpecialSymbol ;i bufferi ikeliamas tarpas
	
	pop si
	ret
endp mov_detected

proc mov_1_detected
	xor bx, bx
	call mov_detected
	call dwmodregrm
	
	cmp d_reiksme, 1 ; d = 0 -> reg -> r/m; d=1 -> r/m -> reg
	je parse_mov_1_d1
	
	call analizuok_rm
	mov bx, 1
	call PushSpecialSymbol ; ikeliamas kablelis
	mov bx, 0
	call PushSpecialSymbol; ikeliamas tarpas
	call analizuok_reg
	jmp parse_mov_1_end
	
parse_mov_1_d1:
	call analizuok_reg
	mov bx, 1
	call PushSpecialSymbol ; ikeliamas kablelis i bufferi
	mov bx, 0 ;ikeliamas tarpas i bufferi
	call PushSpecialSymbol
    call analizuok_rm

parse_mov_1_end:
	ret
endp mov_1_detected

proc mov_2_detected
	call mov_detected
	call dwmodregrm
	call analizuok_rm
	
	mov bx, 1 ; ,
	call PushSpecialSymbol
	
	mov bx, 0 ; tarpas
	call PushSpecialSymbol
	call read_w_bytes 
	call PushHexValue ; paverciame i hex pavidala
	ret
endp mov_2_detected

proc mov_3_detected
	mov al, dl
	and al, 111b
	mov reg_reiksme, al
	
	mov al, dl
	and al, 1000b
	shr al, 3
	mov w_reiksme, al
	
	call mov_detected
	call analizuok_reg
	mov bx, 1 ; ,
	call PushSpecialSymbol
	mov bx, 0 ; tarpas
	call PushSpecialSymbol
	call read_w_bytes
	call PushHexValue ; hex pavidalas
	ret
endp mov_3_detected

proc mov_4_5_detected
	mov al, dl
	and al, 1
	mov w_reiksme, al
	
	mov al, dl
	and al, 10b
	shr al, 1
	mov d_reiksme, al
	
	mov mod_reiksme, 0
	mov reg_reiksme, 0 ; akumuliatorius
	mov rm_reiksme, 110b
	;tiesiogine adresacija
	cmp prefixas, 4
	jne mov_4_5_segmentas
	dec prefixas
	
mov_4_5_segmentas:
	call mov_detected
	cmp d_reiksme, 1
	je parse_mov_5
	call analizuok_reg ;al arba ax
	mov bx, 1; ,
	call PushSpecialSymbol
	mov bx, 0 ; tarpas
	call PushSpecialSymbol
	call analizuok_rm
	ret
	
parse_mov_5:
	call analizuok_rm
	mov bx, 1 ; ,
	call PushSpecialSymbol
	mov bx, 0; tarpas
	call PushSpecialSymbol
	call analizuok_reg
	ret
endp mov_4_5_detected

proc mov_6_detected
	push dx
	call mov_detected
	call dwmodregrm
	pop dx
	
	mov al, dl
	and al, 10b
	shr al, 1
	mov d_reiksme, al
	mov w_reiksme, 1
	
	mov al, reg_reiksme
	mov sreg_reiksme, al
	
	cmp d_reiksme, 0
	jne mov_6_d1
	
	call analizuok_rm
	mov bx, 1; ,
	call PushSpecialSymbol
	mov bx, 0; tarpas
	call PushSpecialSymbol
	call analizuok_sreg
	ret
	
mov_6_d1:
	call analizuok_sreg
	mov bx, 1; ,
	call PushSpecialSymbol
	mov bx, 0; tarpas
	call PushSpecialSymbol
	call analizuok_rm
	ret
endp mov_6_detected

proc out_detected
	push si
	mov cx, 3
	lea si, inst_out
	call PushToBuffer
	pop si
	mov bx, 0; tarpas
	call PushSpecialSymbol
	ret
endp out_detected

proc out_1_detected
	push dx
	mov w_reiksme, 0
	call read_w_bytes ;skaitysim 1 baita
	mov port_reiksme, dl
	pop dx
	
	mov al, dl
	and al, 1
	mov w_reiksme, al
	mov reg_reiksme, 000; al kai w = 0, ax kai w = 1
	
	call out_detected
	push dx
	xor dh, dh
	mov dl, port_reiksme
	call PushHexValue ; vertimas i hex
	pop dx
	mov bx, 1 ;,
	call PushSpecialSymbol
	mov bx, 0 ;tarpas
	call PushSpecialSymbol
	call analizuok_reg ;ax arba al registras
	ret
endp out_1_detected

proc out_2_detected
	push dx
	call out_detected
	mov w_reiksme, 1
	mov reg_reiksme, 010b; isvedame dx registra
	call analizuok_reg
	
	pop dx
	mov al, dl
	and al, 1
	mov w_reiksme, al
	
	mov bx, 1; ,
	call PushSpecialSymbol
	mov bx, 0; tarpas
	call PushSpecialSymbol
	
	mov reg_reiksme, 0 ;siunciame is ax arba is al
	call analizuok_reg
	
	ret
endp out_2_detected

proc not_detected
	call dwmodregrm
	
	cmp reg_reiksme, 010b
	jne not_not
	
	push si
	mov cx, 3
	lea si, instr_not
	call PushToBuffer
	pop si
	mov bx, 0 ; tarpas
	call PushSpecialSymbol
	
	call analizuok_rm
	ret

not_not:
	call Unknown_instruction
	ret
endp not_detected

proc rcr_detected
	call dwmodregrm
	
	cmp reg_reiksme, 011b
	jne not_rcr
	
	push si
	mov cx, 3
	lea si, instr_rcr
	call PushToBuffer
	pop si
	mov bx, 0 ; tarpas
	call PushSpecialSymbol
	
	call analizuok_rm
	mov bx, 1 ; ,
	call PushSpecialSymbol
	mov bx, 0; tarpas
	call PushSpecialSymbol
	
	cmp d_reiksme, 1
	je rcr_v1
	
	;jei v = 0, tai shift right per 1 pozicija
	push di
	mov di, instr_pointer
	mov byte ptr [di], "1"
	inc di
	inc inst_ilgis
	mov instr_pointer, di
	pop di
	ret
	
	;jei v = 1, offset yra cl reiksme
rcr_v1:
	mov w_reiksme, 0
	mov reg_reiksme, 001b
	call analizuok_reg
	ret
	
not_rcr:
	call Unknown_instruction
	ret
endp rcr_detected

proc xlat_detected
	push si
	mov cx, 4
	lea si, instr_xlat
	call PushToBuffer
	pop si
	ret
endp xlat_detected

proc Unknown_instruction
	push si
	mov cx, 7
	lea si, instr_nezinoma
	call PushToBuffer
	pop si
	ret
endp Unknown_instruction

end start
	