;
; Projeto Elevador
; Main file
;


.cseg
.def temp = r19
.def currentFloor = r20
.def destinationFloor = r21
.def requested = r22
.def state = r23
.equ PARADO = 0
.equ DESCENDO = 1
.equ SUBINDO = 2
.equ PRESCALE = 0b100		;binary code to /256 prescale
.equ PRESCALE_DIV = 256		;for calc
#define CLOCK 16.0e6			;Clock speed at 16Mhz
#define DELAY  1				;Delay seconds
.equ WGM = 0b0100			;Waveform generation mode: CTC = CLEAR TIME AND COMPARE
.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))

.cseg							;Code Memory
jmp reset						;Cold Start
jmp reset
.org PCI1addr
jmp PCI1addr_Interruption
.org PCI2addr
jmp PCI2addr_Interruption
.org OC1Aaddr			
jmp OC1A_Interrupt				;Interruption 16bits timer

/*.org OC0Aaddr					
jmp OC0A_Interrupt				;Interruption 8bits timer
*/

reset:
	cli
	;Stack initialization
	ldi TEMP, low(RAMEND)
	out SPL, TEMP
	ldi TEMP, high(RAMEND)
	out SPH, TEMP
	;END Stack initialization

	;TIMER INITIALIZATION
	.if TOP > 65535				;TOP MUST BE BETWEEN 0 AND 65535.
	.error "TOP is out of range"
	.endif
	ldi TEMP, high(TOP)
	sts OCR1AH, TEMP
	ldi TEMP, low(TOP)
	sts OCR1AL, TEMP			;OCR1A = TOP, OCR1A IS USED IN A COMPARATOR TO GENERATE AN INTERRUPT
	;END TIMER INITIALIZATION

	;CONTROL REGISTERS FOR TIMER INTERRUPTION
	ldi TEMP, ((WGM&0b11) << WGM10) ;TEMP = (0b0100 & 0b0011) WITH A SHIFT OF WGM10 BITS // FIRST 2 BITS OF WGM
	sts TCCR1A, TEMP			;SET TCCT1A 2 FIRST BITS WITH THE WGM DEFINED
	ldi TEMP, ((WGM>> 2) << WGM12)|(PRESCALE << CS10);TEMP = (0b1000 | 0b0100) = 0b1100
	sts TCCR1B, TEMP			;Start counter // SET TCCT1B WITH PRESCALE AND OP MODE

	lds TEMP, TIMSK1			;LOADS TIMSK1 TO TEMP, SET BIT IN TEMP WITH A SHIFT OF OCIE1A BITS AND STORES TEMP TO TIMSK1
	sbr TEMP, (0b0001 << OCIE1A)
	sts TIMSK1, TEMP			;TIMSK1 > INTERRUPTION MASK REGISTER FOR 
	;END CONTROL REGISTERS FOR TIMER INTERRUPTION

	;SET OF I/O REGISTERS
	ldi temp, 0x00	;BIT 0 IS INPUT
	out DDRD, temp ; ALL PIN D AS INPUT
	ldi temp, 0x00	;BIT 0 IS INPUT
	out DDRC, temp	;ALL PIN C AS INPUT
	ldi temp, 0xFF	;BIT 1 IS OUTPUT
	out DDRB, temp ; ALL PIN B AS OUTPUT
	;END SET OF I/O REGISTERS

	;CONTROL REGISTERS FOR PIN INTERRUPTION
	ldi temp, (1<<PCIE2) | (1<<PCIE1)
	sts PCICR, temp	;SET PIN CHANGE INTERRUPTION TO PORT D AND C ->code 0b0110 = 6.
	ldi temp, 0xFF	;1111 1111
	sts PCMSK2, temp; ;SET INTERRUPTION ON ALL PINs OF PORT D
	ldi temp, (1<<PCINT12) | (1<<PCINT13)	;0001 1000
	sts PCMSK1, temp; SET INTERRUPTION ON PIN 1 and 2 OF PORT C
	;END CONTROL REGISTERS FOR PIN INTERRUPTION

	sei							;SET GLOBAL INTERRUPT ENABLE BIT

	rjmp initialize	;Goes to initialize Code.

PCI1addr_Interruption:;PORT C INTERRUPTION
	;BACKUP VALUES BEFORE INTERRUPTION
	push temp
	in temp, SREG
	push temp
	;END
	;INTERRUPT THINGS
	in destinationFloor, PINC
	push destinationFloor
	call enqueue
	;END INTERRUPT THINGS
	;RESTORE VALUES BEFORE INTERRUPTION
	pop temp
	out SREG, temp
	pop temp
	;END
	reti

PCI2addr_Interruption:;PORT D INTERRUPTION
	;BACKUP VALUES BEFORE INTERRUPTION
	push temp
	in temp, SREG
	push temp
	;END
	;INTERRUPT THINGS
	in destinationFloor, PIND
	push destinationFloor
	call enqueue
	;END INTERRUPT THINGS
	;RESTORE VALUES BEFORE INTERRUPTION
	pop temp
	out SREG, temp
	pop temp
	;END
	reti

OC1A_Interrupt:	;TIMER INTERRUPTION 16BITS
	;BACKUP VALUES BEFORE DO INTERRUPT
	push TEMP
	in TEMP, SREG
	push TEMP
	;END

	;in TEMP,PIND	;EXEMPLO 0b0010000 CASO APERTE O BOTÃO 5
	;out PORTB, TEMP	;EXEMPLO 0b0010000 CASO APERTE O BOTÃO 5 PORTB IS ALWAYS SET AFTER THIS IF NOTHING RESET IT..
	
	;RESTORE VALUES BEFORE DO INTERRUPT
	pop TEMP
	out SREG, TEMP
	pop TEMP
	;END
	reti

goDown:
	pop destinationFloor
	pop currentFloor		
	ldi state, DESCENDO					; Sets state as DESCENDO
	loop1:
		cp currentFloor, destinationFloor	; Compare
		breq skip1							; Branch if not equal (!=)
		ror currentFloor	
		/* Wait 3000ms */	
		rjmp loop1 
	skip1: 
	ldi state, PARADO
	/* Acionar o buzzer por X segundos */
	ret

goUp:
	pop destinationFloor
	pop currentFloor		
	ldi state, SUBINDO					; Sets state as DESCENDO
	loop2:
		cp currentFloor, destinationFloor	; Compare 
		breq skip2							; Branch if not equal (!=)
		rol currentFloor					
		/* Wait 3000ms */
		rjmp loop2
	skip2: 
	ldi state, PARADO
	/* Acionar o buzzer por X segundos */
	ret

initialize:
	cpi currentFloor, 0
	breq skip3
	push currentFloor
	push destinationFloor
	call goDown
	skip3:
	ldi state, PARADO
	rjmp main					;Goes to Main Code.
/* END OF MOVEMENT CONTROL */


/* STACK CONTROL */

enqueue:
	pop destinationFloor
	mov temp, requested
	and temp, destinationFloor
	cpi temp, 0x00
	brne skip4
	or requested, destinationFloor
	push destinationFloor	
	skip4:
	ret

dequeue:
	eor requested, currentFloor
	pop currentFloor
	ret

main:
	rjmp main