.def temp = r19

.cseg
.equ PRESCALE = 0b100		;binary code to /256 prescale
.equ PRESCALE_DIV = 256		;for calc
#define CLOCK 16.0e6			;Clock speed at 16Mhz
#define DELAY  1				;Delay seconds
.equ WGM = 0b0100			;Waveform generation mode: CTC = CLEAR TIME AND COMPARE
.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))

.cseg							;Code Memory
jmp reset						;Cold Start
.org PCINT20
jmp PD4_Interrupt
.org OC1Aaddr			
jmp OC1A_Interrupt				;Interruption 16bits timer

/*.org OC0Aaddr					
jmp OC0A_Interrupt				;Interruption 8bits timer
*/

reset:
	;Stack initialization
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	;END Stack initialization

	;TIMER INITIALIZATION
	.if TOP > 65535				;TOP MUST BE BETWEEN 0 AND 65535.
	.error "TOP is out of range"
	.endif
	ldi temp, high(TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp			;OCR1A = TOP, OCR1A IS USED IN A COMPARATOR TO GENERATE AN INTERRUPT
	;END TIMER INITIALIZATION

	;CONTROL REGISTERS FOR TIMER INTERRUPTION
	ldi temp, ((WGM&0b11) << WGM10) ;TEMP = (0b0100 & 0b0011) WITH A SHIFT OF WGM10 BITS // FIRST 2 BITS OF WGM
	sts TCCR1A, temp			;SET TCCT1A 2 FIRST BITS WITH THE WGM DEFINED
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10);TEMP = (0b1000 | 0b0100) = 0b1100
	sts TCCR1B, temp			;Start counter // SET TCCT1B WITH PRESCALE AND OP MODE

	lds temp, TIMSK1			;LOADS TIMSK1 TO TEMP, SET BIT IN TEMP WITH A SHIFT OF OCIE1A BITS AND STORES TEMP TO TIMSK1
	sbr temp, (0b0001 << OCIE1A)
	sts TIMSK1, temp			;TIMSK1 > INTERRUPTION MASK REGISTER FOR 
	;END CONTROL REGISTERS FOR TIMER INTERRUPTION

	;CONTROL REGISTERS FOR PIN INTERRUPTION
	ldi temp, 0x04
	sts PCICR, temp	;SET PIN CHANGE INTERRUPTION TO PORT D
	ldi temp, 0x10
	sts PCMSK2, temp; ;SET PIN D4 OR PCINT20

	;END CONTROL REGISTERS FOR PIN INTERRUPTION

	;SET OF I/O REGISTERS
	ldi temp, 0x00	;LOW LOGIC LEVEL IS INPUT
	out DDRD, temp ; INPUT
	ldi temp, 0xFF	;HIGH LOGIC LEVEL IS OUTPUT
	out DDRB, temp ; OUTPUT
	;END SET OF I/O REGISTERS

	sei							;SET GLOBAL INTERRUPT ENABLE BIT

	rjmp main					;Goes to Main Code.

OC1A_Interrupt:	;TIMER INTERRUPTION 16BITS
	;BACKUP VALUES BEFORE DO INTERRUPT
	push temp
	in temp, SREG
	push temp
	;END

	;in temp,PIND	;EXEMPLO 0b0010000 CASO APERTE O BOTÃO 5
	;out PORTB, temp	;EXEMPLO 0b0010000 CASO APERTE O BOTÃO 5 PORTB IS ALWAYS SET AFTER THIS IF NOTHING RESET IT..
	
	;RESTORE VALUES BEFORE DO INTERRUPT
	pop temp
	out SREG, temp
	pop temp
	;END
	reti

PD4_Interrupt:
	;BACKUP VALUES BEFORE DO INTERRUPT
	push temp
	in temp, SREG
	push temp
	;END
	;INTERRUPT THINGS
	in temp,PIND
	out PORTB, temp
	;END INTERRUPT THINGS
	;RESTORE VALUES BEFORE DO INTERRUPT
	pop temp
	out SREG, temp
	pop temp
	;END
	reti

main:
	nop
	rjmp main