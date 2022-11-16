;
; Projeto Elevador
; Main file
;

.dseg
.org	SRAM_START
queue:	.byte	2

.cseg
.def timerTimeCount = r17
.def queueTop = r18
.def temp = r19
.def currentFloor = r20
.def targetFloor = r21
.def requested = r22
.def state = r23
.def queueSize = r24
.def temp1 = r25

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

;.org PCI1addr
;jmp PCI1addr_Interruption

/* Locate Pin Change Interruption */
.org PCI2addr
jmp PCI2addr_Interruption

/* Locate 16-bits Timer Interruption */
.org OC1Aaddr					;;!!
jmp OC1A_Interrupt				;Interruption 16bits timer  ;;!!

reset:
	cli
	;Stack initialization
	ldi TEMP, low(RAMEND)
	out SPL, TEMP
	ldi TEMP, high(RAMEND)
	out SPH, TEMP
	;END Stack initialization

	/* 16-bits TIMER INITIALIZATION */ 

	.if TOP > 65535				;TOP MUST BE BETWEEN 0 AND 65535.
	.error "TOP is out of range"
	.endif

	ldi temp, high(TOP)
	sts OCR1AH, temp
	ldi temp, low(TOP)
	sts OCR1AL, temp
	
	ldi temp, ((WGM&0b11) << WGM10) ;lower 2 bits of WGM
	; WGM&0b11 = 0b0100 & 0b0011 = 0b0000 
	sts TCCR1A, temp
	;upper 2 bits of WGM and clock select
	ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
	; WGM >> 2 = 0b0100 >> 2 = 0b0001
	; (WGM >> 2) << WGM12 = (0b0001 << 3) = 0b0001000
	; (PRESCALE << CS10) = 0b100 << 0 = 0b100
	; 0b0001000 | 0b100 = 0b0001100
	sts TCCR1B, temp ;start counter

	lds temp, TIMSK1
	sbr temp, 1 <<OCIE1A
	sts TIMSK1, temp

	;SET OF I/O REGISTERS

	/* 	Set DDRD as Input (0x00)
	where DDRD is the register responsable for PORTD */
	ldi temp, 0x00	
	out DDRD, temp 
	/* 	Set DDRC as Output (0xFF)
	where DDRC is the register responsable for PORTC */
	ldi temp, 0xFF	
	out DDRC, temp	
	/* 	Set DDRB as Output (0xFF)
	where DDB is the register responsable for PORTB */
	ldi temp, 0xFF	
	out DDRB, temp

	;END SET OF I/O REGISTERS

	;CONTROL REGISTERS FOR PIN INTERRUPTION

	/*Enable PCI on PIND (where PCI = Pin Change Interruption) */
	ldi temp, (1<<PCIE2)
	sts PCICR, temp	
	/* Enable PCI on all pins of PIND */
	ldi temp, 0xFF	
	sts PCMSK2, temp

	;ldi temp, (1<<PCINT12) | (1<<PCINT13)	;0001 1000 = 0x18
	;sts PCMSK1, temp; SET INTERRUPTION ON PIN 1 and 2 OF PORT C
	;END CONTROL REGISTERS FOR PIN INTERRUPTION

	sei							;SET GLOBAL INTERRUPT ENABLE BIT

	rjmp initialize	;Goes to initialize Code.

	/*
PCI1addr_Interruption:;PORT C INTERRUPTION
	;BACKUP VALUES BEFORE INTERRUPTION
	push temp
	in temp, SREG
	push temp
	;END
	;INTERRUPT THINGS
	;CLOSE AND OPEN
	;END INTERRUPT THINGS
	;RESTORE VALUES BEFORE INTERRUPTION
	pop temp
	out SREG, temp
	pop temp
	;END
	reti
	*/

PCI2addr_Interruption:;PORT D INTERRUPTION
	;BACKUP VALUES BEFORE INTERRUPTION
	push temp
	in temp, SREG
	push temp
	;END

	;INTERRUPT THINGS

	/* Inserir andar apertado na queue */
	in targetFloor, PIND
	cpi targetFloor, 0
	breq skip6
	cpi targetFloor, 0x09
	brlo skip5
	/* */
	ldi temp1, (1<<4)
	mul targetFloor, temp1
	mov targetFloor, r1
	skip5:
	call enqueue
	skip6:

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
	
	inc timerTimeCount 

	;RESTORE VALUES BEFORE DO INTERRUPT
	pop TEMP
	out SREG, TEMP
	pop TEMP
	;END
	reti
	
goDown:

	/* */
	ldi temp, (1<<4)
	lds temp1, queue+1
	mul temp1, temp
	mov queueTop, r1

	ldi state, DESCENDO					; Sets state as DESCENDO
	goDown_loopIfDifferent: 
		cp currentFloor, queueTop		; Compare
		breq goDown_jumpIfEqual			; Branch if not equal (!=)
		 
		/* se reg interrupcao 8 bits = 1  */
		cpi timerTimeCount, 3
		brne goDown_waiting3seconds
		/* */
		lsr currentFloor
		/* */
		call parseDisplay
		out PORTC, currentFloor
		ldi timerTimeCount, 0
		
		/* reg interrupcao 8 bits = 0 */
		goDown_waiting3seconds:
		rjmp goDown_loopIfDifferent
	goDown_jumpIfEqual: 

	ldi state, PARADO

	
	/* */
	call dequeue

	/* Chegou no andar, acender led e tocar buzzer depois de 5 segundos */

	/* Acender led */
	in temp, PORTB 
	ldi temp1, 1<<4
	or temp, temp1
	out PORTB, temp

	/* Toca o buzzer depois de 5 segundos */
	ldi timerTimeCount, 0
	goDown_ringBuzzerAfter5seconds:
		cpi timerTimeCount, 2
		brne goDown_ringBuzzerAfter5seconds
	in temp, PORTB 
	ldi temp1, 1<<5
	or temp, temp1
	out PORTB, temp

	/* Desligar os dois depois de 5 segundos */
	ldi timerTimeCount, 0
	goDown_turnOffBuzzerAfter5seconds:
		cpi timerTimeCount, 2
		brne goDown_turnOffBuzzerAfter5seconds
	in temp, PORTB
	ldi temp1, 0x30
	eor temp, temp1
	out PORTB, temp


	ret

goUp:
	/* */
	ldi temp, (1<<4)
	lds temp1, queue+1
	mul temp1, temp
	mov queueTop, r1
			
	ldi state, SUBINDO					; Sets state as DESCENDO


	goUp_loopIfDifferent:
		cp currentFloor, queueTop	; Compare 
		breq goUp_skipIfEqual							; Branch if not equal (!=)
		/* TIMER:: Wait 3000ms */
		cpi timerTimeCount, 3
		brne goUp_waiting3seconds
		;call wait3seconds
		/* */
		lsl currentFloor
		/* */
		call parseDisplay

		out PORTC, currentFloor

		ldi timerTimeCount, 0
		goUp_waiting3seconds:
		rjmp goUp_loopIfDifferent
	goUp_skipIfEqual: 

	ldi state, PARADO

	/* */
	call dequeue
	
	/* Chegou no andar, acender led e tocar buzzer depois de 5 segundos */
	/* Acender led */
	in temp, PORTB 
	ldi temp1, 1<<4
	or temp, temp1
	out PORTB, temp

	/* Toca o buzzer depois de 5 segundos */
	ldi timerTimeCount, 0
	goUp_ringBuzzerAfter5seconds:
		cpi timerTimeCount, 2
		brne goUp_ringBuzzerAfter5seconds
	in temp, PORTB 
	ldi temp1, 1<<5
	or temp, temp1
	out PORTB, temp

	/* Desligar os dois depois de 5 segundos */
	ldi timerTimeCount, 0
	goUp_turnOffBuzzerAfter5seconds:
		cpi timerTimeCount, 2
		brne goUp_turnOffBuzzerAfter5seconds
	in temp, PORTB
	ldi temp1, 0x30
	eor temp, temp1
	out PORTB, temp

	
	/* Acionar o buzzer por X segundos */
	ret

initialize:
	;Note que não usamos persistência, logo, os registradores poderão conter lixo.
	ldi currentFloor, 0x01
	
	clr targetFloor
	ldi requested, 0x00
	clr queueSize

	ldi state, PARADO

	rjmp main					;Goes to Main Code.
/* END OF MOVEMENT CONTROL */


/* STACK CONTROL */


/* Decide se vai colocar na queue ou nao, e coloca */
enqueue:
	
	mov temp, requested
	and temp, targetFloor
	cpi temp, 0
		
;	(requested & targetFloor) != 0
	;0001 & 0000 = 0000

	brne skip4
	call parseEnqueue
	or requested, targetFloor	

	skip4:		
	; 0001 0010 
	ret

/* */ 
parseEnqueue:
	/* destino esta em targetFloor, precisamos adicionar na queue*/
	/* o numero de requisicoes na fila é qnt */
	
	mov temp, targetFloor

	cpi queueSize, 0
	breq Format_QueueHasSizeZero
	cpi queueSize, 1
	breq Format_QueueHasSizeOne
	cpi queueSize, 2
	breq Format_QueueHasSizeTwo
	cpi queueSize, 3
	breq Format_QueueHasSizeThree

	/* [XXXX] 0000 0000 0000 */
	Format_QueueHasSizeZero:
	ldi temp1, (1<<4)
	mul temp, temp1
	sts queue+1, r0

	rjmp Format_endSwitch	
		
	/* [YYYY] [XXXX] 0000 0000 */
	Format_QueueHasSizeOne:
	lds temp1, queue+1 ; temp = 0001 0000
	or temp, temp1 ; temp | dest = 0001 0000 | 0000 0010 = 0001 0010 
	sts queue+1, temp
		

	rjmp Format_endSwitch

	/* 0000 0000 [XXXX] 0000 */
	Format_QueueHasSizeTwo:
	ldi temp1, (1<<4)
	mul temp, temp1
	sts queue, r0

	rjmp Format_endSwitch	

	/* 0000 0000 [YYYY] [XXXX] */
	Format_QueueHasSizeThree:
	lds temp1, queue
	or temp, temp1
	sts queue, temp

	rjmp Format_endSwitch	

	Format_EndSwitch:
	inc queueSize

	ret

dequeue:
	eor requested, currentFloor

	/* carregar (high(queue)<<4) em temp1 
	[1000 0100] [1 0000] = [0000 1000 0100 0000] */
	lds temp1, queue+1
	ldi temp, (1<<4)
	mul temp1, temp
	sts queue+1, r0

	/* */

	; carregar (low(queue)>>4) temp1 
	lds temp1, queue
	ldi temp, (1<<4)
	mul temp1, temp
	; faz (low(queue)>>4) | high(queue) 
	lds temp, queue+1
	or temp, r1
	sts queue+1, temp

	/* */
	/* carregar (low(queue)<<4) em temp1 
	[1000 1000] * [1 0000] = [0000 1000 1000 0000] */
	lds temp1, queue
	ldi temp, (1<<4)
	mul temp1, temp
	sts queue, r0

	dec queueSize
	ret

resolve:
	/* olha o topo da fila
	se o topo da fila > current floor ---  chame goUp
	se o topo da fila < current floor chame goDown */
	
	/* Checa se tem alguem na fila */
	cpi queueSize, 0
	breq resolve_Return

	/* Pega o topo da fila */
	ldi temp, (1<<4)
	lds temp1, queue+1
	mul temp1, temp
	mov queueTop, r1

	/* Reset 3 second timer */
	ldi timerTimeCount, 0
	
	cp currentFloor, queueTop
	brlo resolve_BranchIfLower
		call goDown
		rjmp resolve_endSwitch
	resolve_BranchIfLower:		
		call goUp
	resolve_endSwitch:

	resolve_Return:

	ret

parseDisplay:
	/* pega currentFloor e joga no display
	XXXX = ABCD
	0001 = 0001
	0010 = 0010
	0100 = 0011
	1000 = 0100 */

	cpi currentFloor, (1<<0) ; 0001
	breq parseDisplay_numberZero
	cpi currentFloor, (1<<1) ; 0010
	breq parseDisplay_numberOne
	cpi currentFloor, (1<<2) ; 0100
	breq parseDisplay_numberTwo
	cpi currentFloor, (1<<3) ; 1000
	breq parseDisplay_numberThree

	parseDisplay_numberZero:
	ldi temp, 0
	out PORTB, temp
	rjmp parseDisplay_endSwitch	
		
	parseDisplay_numberOne:
	ldi temp, 1
	out PORTB, temp
	rjmp parseDisplay_endSwitch

	parseDisplay_numberTwo:
	ldi temp, 2
	out PORTB, temp
	rjmp parseDisplay_endSwitch	

	parseDisplay_numberThree:
	ldi temp, 3
	out PORTB, temp
	rjmp parseDisplay_endSwitch	

	parseDisplay_endSwitch:
	ret


main:
	
	/* Usar currentFloor para decidir se vai para cima ou para baixo com goUp, goDown */
	;lds temp, queueSize
	
	call parseDisplay
	/* */
	call resolve
	;lds temp, queue+1
	rjmp main