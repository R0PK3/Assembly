;Robertas Buracevskis, 1 grupe
;Programa nuskaito duomenis is nurodyto duomenu failo, rastus skaitmenis pakeicia zodziais ir rezultatus isveda nurodytame rezultatu faile

.MODEL small	

    skBufDydis	EQU 73	  ;konstantos
	raBufDydis	EQU 512	
    
.stack 100h	

.data	

	duom	    db 100 dup(0)	;duomenu ir rezultatu failu bufferiai
	rez     	db 100 dup(0)

	dFH			dw ?	 ;duomenu file handleris
	rFH			dw ?     ;rezultatu file handleris

	skBuf		db skBufDydis dup (?)	; Skaitymo ir rasymo bufferiai
	raBuf		db raBufDydis dup (?)	

	nulis   	db "nulis"		
    vienas  	db "vienas"		
    du      	db "du"			
    trys    	db "trys"		
    keturi  	db "keturi"		
    penki   	db "penki"		
    sesi    	db "sesi"		
    septyni 	db "septyni"	
    astuoni 	db "astuoni"	
    devyni  	db "devyni"		
	
	
    msg_pagalba	db "Programa nuskaito duomenis is nurodyto duomenu failo, rastus skaitmenis pakeicia zodziais ir rezultatus isveda nurodytame rezultatu faile. $"
	msg_pabaiga db "Programa baige darba.$"
	
	klaida_1 db "Nepavyko atidaryti duomenu failo skaitymui.$"
	klaida_2 db "Nepavyko atidaryti rezultatu failo rasymui.$"
	klaida_3 db "Nepavyko uzdaryti rezultatu failo.$"
	klaida_4 db "Nepavyko uzdaryti duomenu failo.$"
	klaida_5 db "Nepavyko duomenu nuskaityti is failo i buferi.$"
	klaida_6 db "Ivyko dalinis irasymas. Programa baigia darba.$"
	klaida_7 db "Ivyko klaida rasant i faila.$"
	
.code    	     
start:	
  
    MOV	dx, @data	
	MOV	ds, dx		
    XOR si, si		
    XOR di, di	
  
;Darbas su parametrais

	MOV bx, 80h			
	XOR cx, cx
	MOV cl, es:[bx]		;Tikrinama kiek parametru simboliu buvo ivesta
	CMP cx, 0			
	JE Pagalba
	
	INC bx	; nuo 81h prasideda parametrai
	
	Ieskoti_pagalbos:	
	CMP es:[bx], '?/'		; ieskoma /?
	JE Pagalba		
	INC bx					
	LOOP Ieskoti_pagalbos	

;Darbas su failu vardais
	
	MOV bx, 81h		;Jeigu nerandamas /?, griztama i 81h es baita, kad nuskaityt failu vardus
	
    Parametru_tikrinimas:
    MOV ax, es:[bx]			
    CMP al, 0Dh				; Tikrinama ar newline (po programos paleidimo enteris)
    JE  Ar_Parametrai_Ivesti	
 
    Tikrinti_duomenu_failo_parametra:
    MOV ax, es:[bx]	
    CMP al, 20h		;Tikrinama, ar AL registre esantis simbolis yra tarpas (20h)
	JE  Tikrinti_rezultatu_failo_parametra	
    CMP al, 0Dh		;Tikrinama, ar Al registre esantis simbolis yra newline (jei po duomenu failo pavadinimo yra enteris, isvedamas pagalbos pranesimas)   
    JE  Pagalba	
    MOV [duom + si], al	;Duomenu failo pavadinimo nuskaitymas po 1 baita
	INC bx			
    INC si		
    JMP Tikrinti_duomenu_failo_parametra	
	
    Tikrinti_rezultatu_failo_parametra:
    INC bx				           
    CMP bx, 82h			        
    JE  Parametru_tikrinimas	
    MOV ax, es:[bx]		
    CMP al, 0Dh			;Tikrinama, Al registre esantis simbolis yra newline (jei po rezultatu failo pavadinimo yra enteris, tikrinama kiek parametru buvo ivesta)
    JE  Ar_parametrai_ivesti
    MOV [rez + di], al	;Rezultatu failo pavadinimo nuskaitymas po 1 baita
    INC di				
    JMP Tikrinti_rezultatu_failo_parametra	
 
    Pagalba:
	MOV ah, 09h
    MOV dx, offset msg_pagalba	
    INT 21h						
    JMP Pabaiga							
 
    Ar_parametrai_ivesti:
    CMP duom, 0			; Tikrinama, ar duomenu failo kintamojo reiksme 0
    JE Pagalba			
    CMP rez, 0			; Tikrinama, ar rezultatu failo kintamojo reiksme 0
    JE Pagalba			
	
;Duomenu failo atidarymas skaitymui
	MOV	ah, 3Dh			
	MOV	al, 0			;Failas atidaromas skaitymui		         
	MOV	dx, offset duom	
	INT 21h				
	JC	Klaida_atidarant_skaitymui
	MOV	dFH, ax	
	
;Rezultatu failo sukurimas ir atidarymas rasymui
	MOV	ah, 3Ch		
	MOV	cx, 0			;(read-only)
	MOV	dx, offset rez	
	INT	21h				
	JC	Klaida_atidarant_rasymui	
	MOV	rFH, ax		
	
;Duomenu failo nuskaitymas i skaitymo bufferi
	Duomenu_nuskaitymas:                     
    MOV bx, dFH		
    CALL Skaityti_i_Buferi	
	
    CMP ax, 0				;Jei 0 - failo pabaiga
    JE Uzdaryti_rasymui		


;Darbas su informacija
    MOV bx, ax				;Kiek baitu nuskaityta
    MOV si, offset skBuf	
	MOV di, offset raBuf	
	
	XOR dx, dx				
	CALL Pakeitimas	
	MOV cx, dx				
	CALL Irasyti_i_Faila		
    JMP Duomenu_nuskaitymas	
	
;Rezultatu failo uzdarymas
	Uzdaryti_rasymui:
	MOV	ah, 3Eh							
	MOV	bx, rFH				
	INT	21h							
	JC	Klaida_uzdarant_rasymui		

;Duomenu failo uzdarymas
	Uzdaryti_skaitymui:
	MOV	ah, 3Eh					
	MOV	bx, dFH				
	INT	21h						
	JC	Klaida_uzdarant_skaitymui

;Programos pabaiga 
	
	MOV ah, 09h
	MOV dx, offset msg_pabaiga 
	INT 21h						
	    
	Pabaiga:
  	MOV	ah, 4Ch			
	MOV	al, 0	
	INT	21h	 
  
;Klaidos
	
	Klaida_atidarant_skaitymui:
	MOV ah, 09h
	MOV dx, offset klaida_1	
    INT 21h
	JMP	Pabaiga   			
	
	Klaida_atidarant_rasymui:
	MOV ah, 09h
	MOV dx, offset klaida_2 
    INT 21h
	JMP	Uzdaryti_skaitymui   
	
	Klaida_uzdarant_rasymui:
	MOV ah, 09h
    MOV dx, offset klaida_3 
    INT 21h
	JMP	Uzdaryti_skaitymui	

	Klaida_uzdarant_skaitymui:
	MOV ah, 09h
	MOV dx, offset klaida_4 
	INT 21h
	JMP Pabaiga	
  
;Proceduros

;Procedura, keicianti skaitmeni i zodi
PROC Pakeitimas 	
	
	Kartoti:			
	CMP bx, 0			;Ar liko simboliu, kuriuos reikia pakeist
	JA Kitas_simbolis	
	
	RET		
	
	Kitas_simbolis:
    MOV al, ds:[si]	   ;Imama po 1 simboli
	
    CMP al, "0"		
    JE Pakeisti_0	
    CMP al, "1"		
    JE Pakeisti_1  	
    CMP al, "2"		
    JE Pakeisti_2	
    CMP al, "3"		
    JE Pakeisti_3  	
    CMP al, "4"		
    JE Pakeisti_4	
    CMP al, "5"		
    JE Pakeisti_5  	
    CMP al, "6"		
    JE Pakeisti_6	
    CMP al, "7"		
    JE Pakeisti_7	
    CMP al, "8"		
    JE Pakeisti_8	
    CMP al, "9"	
    JE Pakeisti_9 
	
	
    MOV [di], al	
    INC di			
	INC dx			
	JMP Simboliams	
	
    Pakeisti_0:
	PUSH si					
    MOV si, offset nulis	
    MOV cx, 5            	
    JMP Rasyti_i_buferi		
    Pakeisti_1:
	PUSH si					
    MOV si, offset vienas	
    MOV cx, 6              	
    JMP Rasyti_i_buferi 		
    Pakeisti_2:
	PUSH si					
    MOV si, offset du		
    MOV cx, 2              	
    JMP Rasyti_i_buferi 		
    Pakeisti_3:
	PUSH si					
    MOV si, offset trys		
    MOV cx, 4				
    JMP Rasyti_i_buferi        
    Pakeisti_4:
	PUSH si					
    MOV si, offset keturi	
    MOV cx, 6				
    JMP Rasyti_i_buferi 		
    Pakeisti_5:
	PUSH si					
    MOV si, offset penki	
    MOV cx, 5				
    JMP Rasyti_i_buferi 		
    Pakeisti_6:
	PUSH si					
    MOV si, offset sesi		
    MOV cx, 4				
    JMP Rasyti_i_buferi 		
    Pakeisti_7:
	PUSH si					
    MOV si, offset septyni	
    MOV cx, 7				
    JMP Rasyti_i_buferi 		
    Pakeisti_8:
	PUSH si					
    MOV si, offset astuoni	
    MOV cx, 7				
    JMP Rasyti_i_buferi 	
    Pakeisti_9:
	PUSH si					
    MOV si, offset devyni	
    MOV cx, 6 				
    JMP Rasyti_i_buferi 		
    
	Rasyti_i_buferi:
	CMP cx, 0				
	JE Rasyti_i_buferi_pabaiga	
	MOV al, [si]				;Rasymas i rezultatu bufferi
	MOV [di], al			
	DEC cx					
	INC di					
	INC si					
	INC dx						;Skaitliukas kiek simboliu reikia isvest i rezultatu faila (dx buvo apnulintas pries proceduros iskvietima)
	JMP Rasyti_i_buferi 		
	
	Rasyti_i_buferi_pabaiga:
	POP si					;Grazinama duomenu bufferio pozicija
	
	Simboliams:
	INC si					
	DEC bx					;Mazinamas likusiu apdoroti simboliu skaicius
	JMP Kartoti				
	
ENDP Pakeitimas 	

;Procedura nuskaitanti duomenis is duomenu failo
PROC Skaityti_i_buferi	
    
    MOV ah, 3Fh				
    MOV cx, skBufDydis		 
    MOV dx, offset skBuf	
    INT 21h					
    JC Klaida_skaitant		
    
	Skaityti_i_buferi_pabaiga:
	RET		
    
	Klaida_skaitant:
	MOV ah, 09h
	MOV dx, offset klaida_5	
	INT 21h
	XOR ax, ax				;Apnulinamas ax registras jei nebuvo nuskaitytas ne vienas simbolis
	JMP Skaityti_i_buferi_pabaiga	
	
ENDP Skaityti_i_buferi 	

;Procedura, rasanti duomenis i rezultatu faila
PROC Irasyti_i_faila 	
    MOV bx, rFH			
	MOV dx, offset raBuf	
    MOV ah, 40h				
    INT 21h					
	JC Klaida_rasant			
	CMP cx, ax				
	JNE Dalinis_irasymas		
	
	Irasyti_i_faila_pabaiga:
    RET	
	
	Dalinis_irasymas:
	MOV ah, 09h
	MOV dx, offset klaida_6	
	INT 21h
	JMP Irasyti_i_faila_pabaiga	
	
	Klaida_rasant:
	MOV ah, 09h
	MOV dx, offset klaida_7	
	INT 21h
	JMP Irasyti_i_faila_pabaiga	
	
ENDP Irasyti_i_faila 	
	
END start	