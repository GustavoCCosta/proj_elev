;
; Projeto Elevador
; Main file
;

.dseg
.org	SRAM_START
queue:	.byte	2

.cseg
.def buttonPress = r16
.def timerTimeCount = r17
.def queueTop = r18
.def temp = r19
.def currentFloor = r20
.def targetFloor = r21
.def requested = r22
.def state = r23
.def queueSize = r24
.def temp1 = r25

.equ STOPPED = 0
.equ GOING_DOWN = 1
.equ GOING_UP = 2

.equ PRESCALE = 0b100		;binary code to /256 prescale
.equ PRESCALE_DIV = 256		;for calc

#define CLOCK 16.0e6			;Clock speed at 16Mhz
#define DELAY  1				;Delay seconds
#define INF 0xEE

.equ WGM = 0b0100			;Waveform generation mode: CTC = CLEAR TIME AND COMPARE
.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))

.cseg							;Code Memory
jmp reset						;Cold Start

/* Locate PINC Pin Change Interruption */
.org PCI1addr
jmp ButtonPINC_Interruption

/* Locate PIND Pin Change Interruption */
.org PCI2addr
jmp ButtonPIND_Interruption

/* Locate 16-bits Timer Interruption */
.org OC1Aaddr					
jmp OneSecondTimer				

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
	/* 	Set DDRC as Input (0x00)
	where DDRC is the register responsable for PORTC */
	ldi temp, 0x00	
	out DDRC, temp	
	/* 	Set DDRB as Output (0xFF)
	where DDB is the register responsable for PORTB */
	ldi temp, 0xFF	
	out DDRB, temp

	;END SET OF I/O REGISTERS

	;CONTROL REGISTERS FOR PIN INTERRUPTION

	/*Enable PCI on PIND (where PCI = Pin Change Interruption) */
	ldi temp, (1<<PCIE2) | (1<<PCIE1)
	sts PCICR, temp	
	/* Enable PCI on all pins of PIND */
	ldi temp, 0xFF	
	sts PCMSK2, temp
	/* Enable PCI on all pins of PINC */
	ldi temp, 0xFF	
	sts PCMSK1, temp

	;ldi temp, (1<<PCINT12) | (1<<PCINT13)	
	;sts PCMSK1, temp; SET INTERRUPTION ON PIN 1 and 2 OF PORT C
	;END CONTROL REGISTERS FOR PIN INTERRUPTION

	sei							;SET GLOBAL INTERRUPT ENABLE BIT

	rjmp initialize	;Goes to initialize Code.


/* */
ButtonPINC_Interruption:
	/* */
	push temp
	in temp, SREG
	push temp

	/* Checks if PORTC output is: 
	; 0000 (null)
	; 0001 (open door)
	; 0010 (close door)*/
	in temp, PINC
		
	cpi temp, 0 
	breq ButtonPINC_isZero
	cpi temp, 1
	breq ButtonPINC_isOne
		ldi timerTimeCount, INF
		rjmp ButtonPINC_endSwitch

	ButtonPINC_isOne:
		ldi timerTimeCount, INF
		rjmp ButtonPINC_endSwitch
	ButtonPINC_isZero:
	ButtonPINC_endSwitch:
	

	/* */
	pop temp
	out SREG, temp
	pop temp

	reti
	

ButtonPIND_Interruption:
	push temp
	in temp, SREG
	push temp
	
	/* Checks if PORTD output is: 
	; 0000 (null)
	; 0001 (inside request for ground floor)
	; 0010 (inside request for first door)
	; 0100 (inside request for second door)
	; 1000 (inside request for third door) 
	; 0001 0000 (outside request for ground floor)
	; 0010 0000 (outside request for first floor)
	; 0100 0000 (outside request for second floor)
	; 1000 0000 (outside request for third floor) */
	in targetFloor, PIND
	cpi targetFloor, 0
	breq ButtonPIND_isZero
	cpi targetFloor, 0x09
	brlo ButtonPIND_isInside
		/* Format output - shift right (1>>4) */
		ldi temp1, (1<<4)
		mul targetFloor, temp1
		mov targetFloor, r1
	ButtonPIND_isInside:
		call enqueue
	ButtonPIND_isZero:

	pop temp
	out SREG, temp
	pop temp

	reti
	

/* Uses timers to count seconds and store on variable */
OneSecondTimer:	
	push TEMP
	in TEMP, SREG
	push TEMP
	
	/* Increase timeCount by one (1 second has passed) */
	inc timerTimeCount 

	pop TEMP
	out SREG, TEMP
	pop TEMP

	reti

/* Moves elevator down until requested floor */
goDown:

	/* Get queue top */
	ldi temp, (1<<4)
	lds temp1, queue+1
	mul temp1, temp
	mov queueTop, r1

	/* Sets states as GOING DOWN */
	ldi state, GOING_DOWN	
				
	/* Moves elevator down */
	goDown_loopIfDifferent: 
		cp currentFloor, queueTop		
		breq goDown_jumpIfEqual			
		 
		/* If three seconds has passed, go down.  */
		cpi timerTimeCount, 3
		brlo goDown_waiting3seconds
		/* Shift current floor to right (goes to a lower floor) */
		lsr currentFloor
		/* Update currentFloor on display */
		call parseDisplay
		/* Reset timer */
		ldi timerTimeCount, 0

		goDown_waiting3seconds:
			rjmp goDown_loopIfDifferent
	goDown_jumpIfEqual: 

	ldi state, STOPPED

	/* Request done, so remove from queue */
	call dequeue

	/*  */
	call turnOnLed

	/* Turn on buzzer after 5 seconds */
	ldi timerTimeCount, 0
	goDown_ringBuzzerAfter5seconds:
	cpi timerTimeCount, 5
	brlo goDown_ringBuzzerAfter5seconds
	call turnOnBuzzer

	/* Turn off devices after 5 seconds */
	ldi timerTimeCount, 0
	goDown_turnOffBuzzerAfter5seconds:
	cpi timerTimeCount, 5
	brlo goDown_turnOffBuzzerAfter5seconds
	call turnOffDevices

	ret

goUp:
	/* Get queue top */
	ldi temp, (1<<4)
	lds temp1, queue+1
	mul temp1, temp
	mov queueTop, r1
			
	/* Set state as GOING UP*/
	ldi state, GOING_UP			

	/* Moves elevator up */
	goUp_loopIfDifferent:
		cp currentFloor, queueTop	
		breq goUp_skipIfEqual
									
		/* If three seconds has passed, go down.  */
		cpi timerTimeCount, 3
		brlo goUp_waiting3seconds
		/* Shift current floor to left (goes to a higher floor) */
		lsl currentFloor
		/* Update currentFloor on display */
		call parseDisplay
		/* Reset timer */
		ldi timerTimeCount, 0

		goUp_waiting3seconds:
			rjmp goUp_loopIfDifferent
	goUp_skipIfEqual: 

	ldi state, STOPPED

	/* Request done, so remove from queue */
	call dequeue
	
	/*  */
	call turnOnLed

	/* Turn on buzzer after 5 seconds */
	ldi timerTimeCount, 0
	goUp_ringBuzzerAfter5seconds:
	cpi timerTimeCount, 5
	brlo goUp_ringBuzzerAfter5seconds
	call turnOnBuzzer

	/* Turn off devices after 5 seconds */
	ldi timerTimeCount, 0
	goUp_turnOffBuzzerAfter5seconds:
	cpi timerTimeCount, 5
	brlo goUp_turnOffBuzzerAfter5seconds
	call turnOffDevices
		
	/*  */
	ret

turnOnLed:
	/* */
	in temp, PORTB 
	ldi temp1, 1<<4
	or temp, temp1
	out PORTB, temp
	ret

turnOnBuzzer:
	/* */
	in temp, PORTB 
	ldi temp1, 1<<5
	or temp, temp1
	out PORTB, temp
	ret

turnOffDevices:
	in temp, PORTB
	ldi temp1, 0x30	
	eor temp, temp1
	out PORTB, temp
	ret

initialize:	
	/* Set current floor as ground (0001) */
	ldi currentFloor, 0x01
	
	/* Set current floor as ground (0001) */
	clr targetFloor

	/* Set requested floors (visited array) as empty
	example: if queue = [3, 2, 1], then request = [0, 1, 1, 1].
	This avoid multiple insertions of the same element on queue. */
	clr requested

	/* Set current floor as ground (0001) */
	clr queueSize

	/* Set state as STOPPED */
	ldi state, STOPPED

	rjmp main					

/* STACK CONTROL */

/* Decides if will insert, and effectively insert on the queue */
enqueue:
	
	/*	Checks if target floor on pressed button is alreary requested. 
		example: 
			if queue = [3, 1, 2], then request = [0, 1, 1, 1],
			if someone requests floor 3, then nothing happens.*/
	mov temp, requested
	and temp, targetFloor 
	cpi temp, 0				; (requested & targetFloor) != 0
	/* if (requested & targetFloor) == 0 , insert on queue */	
	brne enqueue_IsAlreadyRequested
	call parseEnqueue
	or requested, targetFloor
	enqueue_IsAlreadyRequested:	
	ret

/* Inserts parsed output in the queue */ 
parseEnqueue:
	/* */	
	mov temp, targetFloor

	cpi queueSize, 0
	breq Format_QueueHasSizeZero
	cpi queueSize, 1
	breq Format_QueueHasSizeOne
	cpi queueSize, 2
	breq Format_QueueHasSizeTwo
	cpi queueSize, 3
	breq Format_QueueHasSizeThree

	/* 	Performs insertion if queue is empty
		queue = 0000 0000 0000 0000 -> queue = [XXXX] 0000 0000 0000.
		example: queue = 0000 0000 0000 0000,
				 targetFloor = 1000 (third floor),
				 then updated queue = 1000 0000 0000 0000. */
	Format_QueueHasSizeZero:
	ldi temp1, (1<<4)
	mul temp, temp1
	sts queue+1, r0		; queue+1 = HIGH(queue)
	rjmp Format_endSwitch	
		
	/* 	Performs insertion if queue has size one
		queue = [AAAA] 0000 0000 0000 -> queue = [AAAA] [XXXX] 0000 0000.
		example: queue = 1000 0000 0000 0000,
				 targetFloor = 0010 (first floor),
				 then updated queue = 1000 0010 0000 0000. */
	Format_QueueHasSizeOne:
	lds temp1, queue+1 
	or temp, temp1  
	sts queue+1, temp
	rjmp Format_endSwitch

	/* 	Performs insertion if queue has size two
		queue = [AAAA] [BBBB] 0000 0000 -> queue = [AAAA] [BBBB] [XXXX] 0000.
		example: queue = 0010 1000 0000 0000,
				 targetFloor = 0100 (third floor),
				 then updated queue = 0010 1000 0100 0000. */
	Format_QueueHasSizeTwo:
	ldi temp1, (1<<4)
	mul temp, temp1
	sts queue, r0

	rjmp Format_endSwitch	

	/* 	Performs insertion if queue has size three
		queue = [AAAA] [BBBB] [CCCC] 0000 -> queue = [AAAA] [BBBB] [CCCC] [XXXX].
		example: queue = 0010 1000 0100 0000,
				 targetFloor = 0001 (ground floor),
				 then updated queue = 0010 1000 0100 0000. */
	Format_QueueHasSizeThree:
	lds temp1, queue
	or temp, temp1
	sts queue, temp
	rjmp Format_endSwitch	

	Format_EndSwitch:
	inc queueSize

	ret

/* Removes the queue top from the queue */
dequeue:
	/*  Removes current floor from requested floors. 
		example: requested [0, 1, 0, 1] = 1010 
				 currentFloor = 1000 (third floor)
				 updated requested = 1010 xor 1000 = 0010 [0, 1, 0, 0] */
	eor requested, currentFloor

	/* Shifts HIGH(queue) to the left four times
		example:
			queue = 0000 0000 1000 0100 
			updated queue = 0000 1000 0100 0000 */
	lds temp1, queue+1
	ldi temp, (1<<4)
	mul temp1, temp
	sts queue+1, r0

	/* Shifts bottom of HIGH(queue) with top of LOW(queue) 
		to the left four times
		example:
			queue = 0000 1000 0001 0100 
			updated queue = 1000 0001 0100 0000 */
	lds temp1, queue
	ldi temp, (1<<4)
	mul temp1, temp

	lds temp, queue+1
	or temp, r1
	sts queue+1, temp

	/* Shifts LOW(queue) to the left four times
		example:
			queue = 0000 0000 1000 0100 
			updated queue = 0000 1000 0100 0000 */
	lds temp1, queue
	ldi temp, (1<<4)
	mul temp1, temp
	sts queue, r0

	/* */
	dec queueSize
	ret

/* Solve the most important request (queue top) */
resolve:

	/* If nobody on queue, return */
	cpi queueSize, 0
	breq resolve_Return

	/* Get queue top */
	ldi temp, (1<<4)
	lds temp1, queue+1
	mul temp1, temp
	mov queueTop, r1

	/* Reset timer count */
	ldi timerTimeCount, 0
	
	/* If currentFloor > queueTop, call goDown (move elevator down).
		otherwise, call goUp (move elevator up) */
	cp currentFloor, queueTop
	brlo resolve_BranchIfLower
		call goDown
		rjmp resolve_endSwitch
	resolve_BranchIfLower:		
		call goUp
	resolve_endSwitch:
	resolve_Return:

	ret

/* Format current floor into printable display output */
parseDisplay:


	/* 	example:
		(current floor) XXXX = (display output) ABCD
						0001 = 0001
						0010 = 0010
						0100 = 0011
						1000 = 0100 */
		 
	cpi currentFloor, (1<<0)			; 0001
	breq parseDisplay_numberZero		; 0001 -> 0001
	cpi currentFloor, (1<<1)			; 0010
	breq parseDisplay_numberOne		    ; 0010 -> 0010
	cpi currentFloor, (1<<2)			; 0100
	breq parseDisplay_numberTwo			; 0100 -> 0011
	cpi currentFloor, (1<<3)			; 1000
	breq parseDisplay_numberThree		; 1000 -> 0100
	
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
	
	/* Update display */	
	call parseDisplay

	/* Check if something needs to be done */
	call resolve

	rjmp main