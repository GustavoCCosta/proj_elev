; Illustrate the use of a Timer/Counter to show hex in Disp display and changes hex after 1s until 0x47 = 0b01000111
;Disp on PORTD
;Clock speed 16 MHz

;Timer 1 È utilizado para definir um intervalo de 1 s
;A cada intervalo os segmento recebe um bin·rio de 1 byte para configurar o display de forma a mostrar hex de 0 a F

.def temp = r16
.def leds = r17 ;current LED value
.def Disp = r19
clr Disp
.cseg

jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt

OCI1A_Interrupt:
	push temp
	push Disp
	in temp, SREG
	push temp
	
	;LÛgica para passar o valor q Z aponta para Disp na porta D
	lpm Disp, Z	;Disp recebe o valor de Z
	adiw Z,2	;Z marca 
	out PORTD, Disp
	
	pop temp
	out SREG, temp
	pop Disp
	pop temp
	reti

;Tabela na Cseg para os caracteres em hex.
;Note que ser· gerada uma lista de avisos pois .db armazena 1 byte, porÈm cseg utiliza word(2bytes)
table:
	.db 0x7E	;0
	.db 0x30	;1
	.db 0x6D	;2
	.db 0x79	;3
	.db 0x33	;4
	.db 0x5B	;5
	.db 0x5F	;6
	.db 0x70	;7
	.db 0x7F	;8
	.db 0x7B	;9
	.db 0x77	;A
	.db 0x1F	;B
	.db 0x4E	;C
	.db 0x3D	;D
	.db 0x4F	;E
	.db 0x47	;F


reset:
	;Stack initialization
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	;Saida para Disp(portas digitais 0,1,2,3,4,5,6,7 do arduino para respectivamente G,F,E,D,C,B,A,. do display)
	ldi temp, 0xFF
	out DDRD, temp

	#define CLOCK 16.0e6 ;clock speed
	#define DELAY 0.001 ;seconds
	.equ PRESCALE = 0b100 ;/256 prescale
	.equ PRESCALE_DIV = 256
	.equ WGM = 0b0100 ;Waveform generation mode: CTC
	;you must ensure this value is between 0 and 65535
	.equ TOP = int(0.5 + ((CLOCK/PRESCALE_DIV)*DELAY))
	.if TOP > 65535
	.error "TOP is out of range"
	.endif

	;CONFIGURAÁ√O DE INTERRUP«‘ES E TIMERS
	;On MEGA series, write high byte of 16-bit timer registers first
	ldi temp, high(TOP) ;initialize compare value (TOP)
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

	lds r16, TIMSK1
	sbr r16, 1 <<OCIE1A
	sts TIMSK1, r16

	;Z recebe a primeira posiÁ„o da tabela.
	ldi ZH, high(table*2)
	ldi ZL, LOW(table*2)

	sei
	main_lp:
		cpi Disp,0x47	;Compara Disp ao ˙ltimo valor da tabela.
		brne main_lp	;Se for igual, Z tem que receber o comeÁo da tabela para voltar para o loop, se diferente, volta para o loop main_lp
		ldi ZH, high(table*2)	;Z recebe a primeira posiÁ„o da tabela
		ldi ZL, LOW(table*2)
			rjmp main_lp