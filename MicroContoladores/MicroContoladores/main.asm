.def display2 = r17
.def display1 = r18
.def serial = r19
.def buffer = r20
.def counter = r21
.def state = r22 
.def temp = r23
.def display = r24
.def timer2 = r25
.def timer3 = r26
.def timer4 = r27
.def s4 = r28
.def s3 = r29
.def s2 = r30
.def s1 = r31

.cseg							;Code Memory

jmp reset						;Cold Start
.org OC1Aaddr			
jmp OC1A_Interrupt				;Interruption
.org OC0Aaddr					
jmp OC0A_Interrupt				;Interruption

reset:

	ldi temp, low(RAMEND)		;Stack initialization
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

								;TIMER INITIALIZATION
	#define CLOCK 16.0e6		;Clock speed at 16Mhz
	#define DELAY 1				;Delay seconds
	.equ PRESCALE = 0b100		;binary code to /256 prescale
	.equ PRESCALE_DIV = 256		;for calc
	.equ WGM = 0b0100			;Waveform generation mode: CTC = CLEAR TIME AND COMPARE
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535				;TOP MUST BE BETWEEN 0 AND 65535.
	.error "TOP is out of range"
	.endif
	ldi temp, high(TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp			;OCR1A = TOP

	ldi temp, ((WGM&0b11) << WGM10) ;TEMP = (0b0100 & 0b0011) WITH A SHIFT OF WGM10 BITS // FIRST 2 BITS OF WGM
	sts TCCR1A, temp
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10);TEMP = (0b1000 | 0b0100) = 0b1100
	sts TCCR1B, temp			;Start counter // SET TTCT1B WITH PRESCALE AND OP MODE

	lds temp, TIMSK1			;LOADS TIMSK1 TO TEMP, SET BIT IN TEMP WITH A SHIFT OF OCIE1A BITS AND STORES TEMP TO TIMSK1
	sbr temp, (0b0001 << OCIE1A)
	sts TIMSK1, temp

	sei							;Set Global Interrupt Enable Bit

	jmp main					;Go to Main Code.

	OC1A_Interrupt:
