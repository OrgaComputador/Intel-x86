segment pila	 stack
	resb 64

segment datos data
msgProcesarSiguienteRegistro db 'Presione cualquier tecla para procesar el siguiente registro',13,10,'$'
fechaGregoriana times 10 resb 1,
				db 13,
				db 10,
				db '$'
				
diaGregoriano resb 1
mesGregoriano resb 1
anho resw 1
anhoEsBisiesto resb 1 ;1h si es bisiesto, 0h si no.
cantDiasValido resb 1 ;1h si el registro tiene cantidad de dias validos, 0h si no.
dias resw 1
vecDiasMes times 3 resd 1
msgIngSiglo db 'Ingrese el siglo correspondiente a las fechas del archivo (01-99): ',13,10,'$'
		db 3
		db 0
siglo times 3 resb 1
sigloEnHexa resw 1
diez db 10
cien db 64h ;100 expresado en base 16
mil dw 03E8h ;1000 expresado en base 16
fileName db "fechas",0	
fHandle resw 1
registro times 6 resb 1
msjErrOpen db "Error en apertura$"
msjErrRead db "Error en lectura$"
msjErrClose db "Error en cierre$"
msjErrDiasInvalidos db 'No se proceso este registro. (0 < DDDD <= 365 (366 con anho bisiesto)',13,10,'$'
msjFinProceso db 'Fin del procesamiento de registros',13,10,'$'
segment codigo code
..start:
	;Inicialización de registro DS y SS	
	
	mov ax,datos
	mov ds,ax
	mov ax,pila
	mov ss,ax
	;código de la solución al problema
	;luego pido el siglo
	;primero lleno el vector vecDiasMes
	call inicializarCalendario
	call preguntarSiglo
	call guardarSiglo
	call abrirArchLectura
	procesarRegistros:	
		call leerRegistro
		call obtenerAnho 
		call esBisiesto
		cmp byte[anhoEsBisiesto], 01h 
		jne continuar
		inc byte[vecDiasMes + 1]
		continuar:
			call obtenerDias
			call validarCantidadDias
			cmp byte[cantDiasValido], 01h
			jne siguienteRegistro
			call diaYMesEnGregoriano
			call fechaToAscii
			mov dx,fechaGregoriana
			call printMsg ;muestro la fecha
			siguienteRegistro:
				mov dx, msgProcesarSiguienteRegistro
				call printMsg
				mov ah, 8h
				int 21h
				cmp byte[anhoEsBisiesto], 01h
				jne procesarRegistros ;antes de leer prox registro reestablezco el calendario
				dec byte[vecDiasMes + 1]
				jmp procesarRegistros ;loop lectura registros


inicializarCalendario:
    mov BYTE[vecDiasMes], 31
	mov BYTE[vecDiasMes+1], 28
	mov BYTE[vecDiasMes+2], 31
	mov BYTE[vecDiasMes+3], 30
	mov BYTE[vecDiasMes+4], 31
	mov BYTE[vecDiasMes+5], 30
	mov BYTE[vecDiasMes+6], 31
	mov BYTE[vecDiasMes+7], 31
	mov BYTE[vecDiasMes+8], 30
	mov BYTE[vecDiasMes+9], 31
	mov BYTE[vecDiasMes+10], 30
	mov BYTE[vecDiasMes+11], 31
	ret
	
preguntarSiglo:
    lea dx, [msgIngSiglo]
	call printMsg
	lea dx, [siglo-2] ;cargo desplazamiento del buffer
	mov ah, 0ah
	int 21h ;ingreso del siglo
	jmp validarSiglo

validarSiglo:
    mov ax, [siglo]
	cmp ax, 3030h
	je preguntarSiglo 
	cmp ah, 30h
	jl preguntarSiglo
	cmp ah, 39h
	jg preguntarSiglo
	cmp al, 30h
	jl preguntarSiglo
	cmp al, 39h
	jg preguntarSiglo
	ret
	
guardarSiglo:
    mov bx, 0 ;acumula el año 1 correspondiente al siglo ingresado
    mov ax, 0
	mov al, [siglo]
	sub al, 30h
	mul word[mil]
	add bx, ax
	mov ax, 0
	mov al, [siglo+1]
	sub al, 30h
	mul byte[cien]
	add bx, ax
	sub bx, 100 ;resto 100 años
	mov [sigloEnHexa], bx
	ret
	
abrirArchLectura:
	mov	al, 0		         ;al = tipo de acceso (0=lectura; 1=escritura; 2=lectura y escritura)
	mov	dx, fileName	         ;dx = dir del nombre del archivo
	mov	ah, 3dh		         ;ah = servicio para abrir archivo 3dh
	int	21h
	jc	errOpen
	mov	[fHandle], ax	         ; en ax queda el handle del archivo
	ret
	
leerRegistro:
	mov	bx, [fHandle]	;bx = handle del archivo
	mov	cx, 6		;cx = cantidad de bytes a escribir
	mov	dx, registro	;dx = dir del area de memoria q contiene los bytes leidos del archivo
	mov	ah, 3fh		;ah = servicio para escribir un archivo: 40h
	int	21h
	jc	errRead
         cmp      ax,0
         je       closeFil
	ret

;guarda el año del registro en la variable anho	
obtenerAnho:
	mov bx, [registro]
	shl bh, 4
	shr bh, 4
	shl bl, 4
	shr bl, 4
	mov ax, 0
	mov al, 10
	mul bl
	add al, bh
	cmp al, 0
	jne noSumarCienAnhos
	add al,100
	noSumarCienAnhos:
		add ax, [sigloEnHexa]
		mov [anho], ax
		ret
	
;verifica si el anho del registro es bisiesto y lo guarda en la variable esBisiesto
esBisiesto:

	mov AX, [anho]						        	;Mueve el anho leido en el archivo al registro AX	
	mov DX, 0000h								;Limpia DX para una division
	mov BX, 0190h								;Mueve a BX 400d
	div BX									;Realiza la operacion ANIO/400d
	cmp DX, 0000h								;Compara el residuo de la operacion con 0
	je EsBisiesto								;Si es igual entonces el año es bisiesto, sino hace otra comparacion
	jne Evaluar								;Salta si la division anterior no dio un resultado positivo a la siguiente condicional
	Evaluar:
		mov AX, [anho]							;Mueve a AX el año ingresado por el usuario
		mov DX, 0000h							;Reinicializa el registro DX
		mov BX, 0004h							;Mueve a BX 00004h
		div BX							        ;Hace la division AX/0004h
		cmp DX, 0000h							;Compara el residuo de la division con 0h
		je Evaluar2							;Salta a la segunda comparacion si el residuo de la division es 0
		jne NoBisiesto						        ;Si el residuo de la division es diferente de cero define que no es año bisiesto
	Evaluar2:
		mov DX, 0000h	                                                ;Reinicializa el registro DX
		mov AX, [anho]							;Mueve el año ingresado por el usuario a AX
		mov BX, 0064h							;Mueve a BX 100d
		Div BX								;Anio / 100d
		cmp DX, 0000h							;Compara el residuo de la division con 0h
		jne EsBisiesto						        ;Si el residuo no es cero, entonces se define que es año bisiesto
		je NoBisiesto						        ;Si el residuo es cero el año es un año normal
	EsBisiesto:
		mov byte[anhoEsBisiesto], 01h						;Define el año como un año bisiesto poniendo 1 en el resultado
		ret							;Salta al final del macro
	NoBisiesto:
		mov byte[anhoEsBisiesto], 00h						;Define el año como un año normal poniendo 0 en el resultado
		ret	

obtenerDias:

	mov ax, 0
	mov bl, [registro + 3] ;aca tengo el numero mas significativo del dia
	mov cl, [registro + 4] ;aca tengo el segundo mas significativo
	shl cl, 4
	shl bl, 4
	shr cl, 4
	shr bl, 4 ;elimino primer nibble
	mov al, [cien] ;p/multiplicar con el registro bl
	mul bl
	mov bx, ax ;lo de bx ya no lo necesito
	mov ax, 10
	mul cx
	add ax, bx ;solo falta sumar al digito menos significativo
	mov bx, 0
	mov bl,[registro + 5]
	shl bl, 4
	shr bl, 4
	add ax, bx
	mov [dias], ax
	ret

validarCantidadDias:
	mov ax, [dias]
	cmp byte[anhoEsBisiesto], 01h
	je validarCantidadDiasBisiesto
	cmp word[dias], 365
	jg cantidadDiasInvalido
	cmp word[dias], 0
	jle cantidadDiasInvalido
	validarCantidadDiasBisiesto:
		cmp word[dias], 366
		jg cantidadDiasInvalido
	mov byte[cantDiasValido], 01h
	ret
	cantidadDiasInvalido:
		mov dx, msjErrDiasInvalidos
		call printMsg
		mov byte[cantDiasValido], 00h
		ret
		
diaYMesEnGregoriano:
	mov si, 0 ;puntero al vector diaMes
	mov bx, 0 ;para almacenar los dias del mes actual
	mov ax, [dias]
	avanzarMes:
		mov bl, [vecDiasMes + si]
		sub ax, bx
		cmp ax, 0	
		JLE diaYMesHallados
		cmp si, 11
		JE diaYMesHallados
		inc si
		jmp avanzarMes
	diaYMesHallados: ;en si esta mes-1, y ax+bx el dia 
		add ax, bx
		inc si
		mov [diaGregoriano], al
		mov bx, 0
		add bx, si ;para mover solo un byte
		mov [mesGregoriano], bl
		ret

fechaToAscii:
	mov byte[fechaGregoriana + 2], 47
	mov byte[fechaGregoriana + 5], 47 
	colocarDia:
	    mov ax,0
		mov al, [diaGregoriano]
		call dosDigitosAAscii
		mov [fechaGregoriana], al
		mov [fechaGregoriana + 1], ah
	colocarMes:
		mov ax,0
		mov al, [mesGregoriano]
		call dosDigitosAAscii
		mov [fechaGregoriana+3], al
		mov [fechaGregoriana+4], ah
	colocarAnho:
		mov ax,0
		mov ax, [anho]
		mov bx, 100
		div bx
		call dosDigitosAAscii ;en al quedo cociente
		mov [fechaGregoriana+6], al
		mov [fechaGregoriana+7], ah
		mov ax,dx
		call dosDigitosAAscii
		mov [fechaGregoriana+8], al
		mov [fechaGregoriana+9], ah
		ret

dosDigitosAAscii:
	div byte[diez]
	add al, 48
	add ah, 48
	ret
	
errOpen:
	mov	dx, msjErrOpen
	call printMsg
	jmp	fin
	
errRead:
	mov	dx, msjErrRead
	call printMsg
	jmp fin
	
closeFil:
	;CIERRA EL ARCHIVO
	mov	bx, [fHandle]	;bx = handle del archivo
	mov	ah, 3eh		;ah = servicio para cerrar archivo: 3eh
	int	21h
	jc	errClose
	jmp	fin
	
errClose:
	mov	dx, msjErrClose
printMsg:
	mov ah, 9
	int 21h
	ret
	
fin:
	mov dx, msjFinProceso
	call printMsg
	mov  ax, 4c00h  ; retornar al SO
	int  21h	

