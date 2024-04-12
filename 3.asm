;Robertas Buracevskis, MIF, PS, 1 kursas, 1 grupe, 1 pogrupis
;18 užduotis
;Parašykite programa, kuri iveda simboliu eilute ir atspausdina rastu tarpu skaiciu. 
;Pvz.: ivedus abs 52 d4 turi atspausdinti 2

.model small		;nurodoma, kokio dydzio bus programinis kodas
.stack 100h			;apibreziama, kad bus naudojamas stekas, 100h (256 baitu) dydzio
.data																;data segmento pradzia
	msg1        db  "Iveskite simboliu eilute atskirta tarpais:$" 	;apibreziama tekstine eilute
	msg2        db  "Ivestu simboliu nerasta."   					;apibreziama tekstine eilute
	newline     db  10,13,"$"   									;apibreziama nauja eilute
	rezultatai  db  "Tarpu skaicius:"                               ;apibreziama tekstine eilute
	atsbufferis db 	3 dup(0), "$"								    ;apibreziamas bufferis
	bufferis    db  255, ?, 255 dup (0) 							;apibreziamas bufferis
	 
	                                                        
	
.code						;kodo segmento pradzia
start:
	mov dx, @data			; priskiriama duomenu segmento pradzios vieta
	mov ds, dx				; i duomenu segmenta ds perkialiama dx reiksme
	
	mov ah, 09h				; MS Dos eilutes spausdinimo funkcija: string'as uzrasomas standartiniame output'e (ekrane)
	mov dx, offset msg1		; Nuoroda i vieta, kur uzrasytas "msg1", offset- poslinkis nuo duomenu segmento pradzios
	int 21h					; Pertraukimas: i ekrana isvedamas nurodytas pranesimas
	
	mov ah, 0Ah				; MS Dos eilutes nuskaitymo funkcija: vartotojo ivestas string'as irasomas bufferyje
	mov dx, offset bufferis	; Nuoroda i vieta, kur yra rezervuota vieta bufferiui
	int 21h 				; Pertraukimas: i bufferi surasoma vartotojo ivestis 
	
	mov ah, 09h				; MS Dos eilutes spausdinimo funkcija: string'as uzrasomas standartiniame output'e (ekrane)
	mov dx, offset newline	; Nuoroda i vieta, kur uzrasyta nauja_eilute 
	int 21h					; Pertraukimas: i ekrana isvedama nauja eilutes
		                    
	mov ah, 09h             ; MS Dos eilutes spausdinimo funkcija: string'as uzrasomas standartiniame output'e (ekrane)
	mov dx, offset rezultatai ; Nuoroda i vieta, kur uzrasyta "rezultatai", offset- poslinkis nuo duomenu segmento pradzios
	int 21h                 ; Pertraukimas: i ekrana isvedamas nurodytas pranesimas
	
	mov si, offset bufferis	; I SI registra perkeliamas DS segmento poslinkis iki bufferio
	inc si					; Registro SI reiksme padidinama vienetu (kad suzinot kiek buvo ivesta simboliu)
	mov al, [si] 			; I AL perkeliama tai, kas yra DS su poslinkiu SI
	
	cmp al, 0				; AL reiksme (ivestu nariu kiekis) lyginama su nuliu
	JE  tuscia				; Jeigu AL reiksme lygi nuliui, sokama i bloka "tuscia" (vartotojas neivede jokiu simboliu)
	
	xor ah,ah				; Nunulinama ah registro reiksme
	mov cx,ax 				; I cx registra perkeliami ax registro duomenys (nuskaitytu simboliu skaicius)
	
ciklas:      
							
    mov al, ds:[si+1]		; I al registra perkeliama si reiksme + 1 (elementu skaiciai)

    cmp al, 20h				; Lyginama al registro reiksme su 20h (tarpu)
    jne praleisti		    ; Jeigu al reiksme nelygi 20h (tarpui), sokama i bloka "praleisti"
    
    inc bx					; Didinama bx reiksme vienetu (skaiciuojame kiek yra tarpu)

    
praleisti:
    inc si                  ; Didinama si reiksme, kad pereiti prie sekancio elemento
    loop ciklas             ; Loop'inamas blokas "ciklas"    


    mov si, offset atsbufferis + 2 ; I si registra perkeliamas atsbufferio galas
    mov cx, 3                      ; I cx ikeliama reiksme "3", nes daugiausiai gali buti trizenklis skaicius tarpu
    
    mov ax, bx                     ; I ax registra perkeliamas bx registras
    mov bx, 10                     ; Bx registrui suteikiama reiksme 10, nes verciame i desimtaine skaiciavimo sistema
    
vertimas: 

    xor dx, dx                    ; Nunulinama dx reiksme, nes joje bus gaunamos liekanos
    div bx                        ; ax = (dx ax) / bx, dx bus liekana
    add dx, 30h                   ; Prie registro dx reiksmes pridedama 30h : prie liekanos (kuri gali buti nuo 0 iki 9) pridejus 30h, gaunama skaitine reiksme ASCII
    
	mov [si], dl                  ; Liekana pernesama i registra si nuo galo
    
	cmp ax, 0                     ; Ax lyginamas su 0
    je pabaiga                    ; Jeigu ax = 0, Sokama i bloka "pabaiga"
    dec si                        ; Mazinama Si reiksme, pereiname prie sekancio skaitmens (nuo galo)
    
	loop vertimas                 ; Loop'inamas "vertimas" blokas
    
    
tuscia:
    
	mov ah, 09h				; Ms Dos eilutes spausdinimo funkcija: string'as uzrasomas standartiniame output'e (ekrane)
	mov dx, offset msg2		; Nuoroda i vieta, kur uzrasytas "msg2", offset- poslinkis nuo duomenu segmento pradzios
	int 21h    				; Pertraukimas: i ekrana isvedamas nurodytas pranesimas
    
pabaiga:
    
    mov ah, 09h             ; Ms Dos eilute spausdinimo funkcija: stringas' uzrasomas standartiniame outpue (ekrane)
    mov dx, offset atsbufferis ; Nuoroda i vieta, kur yra "atsbufferis", offset- poslinkis nuo duomenu segmento pradzios
    int 21h                 ; Pertraukimas: i ekrana isvedamas nurodytas pranesimas
    	
    mov ax, 4c00h           ; Programos pabaigos funkcija
    int 21h                 ; Pertraukimas: Dos'ui grazinamas valdymas
    
end start		;programos pabaiga