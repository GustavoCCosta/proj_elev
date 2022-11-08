;
; AssemblerApplication1.asm
;
; Created: 08/11/2022 08:53:22
; Author : Lilian
;

/* Defines DESCENDO as value 1 */
.def PARADO = r17
.def DESCENDO = r18
.def SUBINDO = r19

ldi R16, high(RAMEND)
ldi R17, low(RAMEND)
out SPL, R17
out SPH, R16

;salvar valor de registrador para não ser sobrescrito
push R16 		;save register value
ldi R16, $FF 	;use register freely
out PORTB, R16 
pop R16 		;restore register value before continuing

;trocar valores entre dois registradores (swap)
push R5 		;R5 moved to temporary location on stack
mov R5, R6
pop R6 			;temp location removed from stack to R6


/* MOVEMENT CONTROL */


/*	Moves elevator from currentFloor to destinationFloor
	
	r20 - currentFloor (floor where the elevator is)
	r21 - destinationFloor (floor where the elevator should go) 
*/
.def currentFloor = r20
.def destinationFloor = r21

goDown:
	pop destinationFloor
	pop currentFloor		
	ldi state, DESCENDO					; Sets state as DESCENDO
	loop1:
		cp currentFloor, destinationFloor	; Compare
		breq skip1							; Branch if not equal (!=)
		dec currentFloor					
		sleep 3000
		rjmp loop1 
	skip1: 
	ldi state, PARADO
	/* Acionar o buzzer por X segundos */

goUp:
	pop destinationFloor
	pop currentFloor		
	ldi state, SUBINDO					; Sets state as DESCENDO
	loop2:
		cp currentFloor, destinationFloor	; Compare 
		breq skip							; Branch if not equal (!=)
		inc currentFloor					
		sleep 3000
		rjmp loop2
	skip2: 
	ldi state, PARADO
	/* Acionar o buzzer por X segundos */

initialize:
	cp currentFloor, 0
	breq skip3
	push currentFloor
	push destinationFloor
	call goDown
	skip3:
	ldi state, PARADO

/* END OF MOVEMENT CONTROL */


/* STACK CONTROL */
			.dseg
			.org SRAM_START		; SRAM initialization
isPresent:  .byte 4				; Allocate 4 bytes for array called isPresent
	sts isPresent, 0			; 
	sts isPresent + 1, 0
	sts isPresent + 2, 0
	sts isPresent + 3, 0

/* */
enqueue:
	pop destinationFloor
	cp isPresent + destinationFloor, 1
	bneq skip4
	ldi isPresent + destinationFloor, 1
	push destinationFloor	
	skip4:

dequeue:
	ldi isPresent + currentFloor, 0
	pop currentFloor
	

	





/* */



