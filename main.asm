;
; AssemblerApplication1.asm
;
; Created: 08/11/2022 08:53:22
; Author : Lilian
;

/* Defines DESCENDO as value 1 */
#define PARADO 0
#define DESCENDO 1
#define SUBINDO 2



ldi R16, high(RAMEND)
ldi R17, low(RAMEND)
out SPL, R17
out SPH, R16

/* MOVEMENT CONTROL */


/*	Moves elevator from currentFloor to destinationFloor
	
	r20 - currentFloor (floor where the elevator is)
	r21 - destinationFloor (floor where the elevator should go) 
*/
.def currentFloor = r20
.def destinationFloor = r21
/*
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
/*
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
/*
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
/*
			.dseg
			.org SRAM_START		; SRAM initialization
isPresent:  .byte 4				; Allocate 4 bytes for array called isPresent
	sts isPresent, 0			; 
	sts isPresent + 1, 0
	sts isPresent + 2, 0
	sts isPresent + 3, 0
*/
	/* */
	/*
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
*/
/* */

.equ groundFloorOutsideButton = PIND0
.equ firstFloorOutsideButton  = PIND1
.equ secondFloorOutsideButton = PIND2
.equ thirdFloorOutsideButton  = PIND3

.equ groundFloorInsideButton  = PIND4
.equ firstFloorInsideButton   = PIND5
.equ secondFloorInsideButton  = PIND6
.equ thirdFloorInsideButton   = PIND7
/*
.def input = r10
in input, D0
*/

ldi R19, 0x00
out DDRD, R19 ; ENTRADA
ldi R19, 0xFF
out DDRB, R19 ; SAIDA

loop:
	in R19,PORTD ;EXEMPLO 0b0010000 CASO APERTE O BOTÃO 5
	out PORTB, R19;EXEMPLO 0b0010000 CASO APERTE O BOTÃO 5
	rjmp loop











