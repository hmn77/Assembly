;
; AssemblerApplication1.asm
;
; Created: 4/19/2020 6:26:35 PM
; Author : Hooman tahayori
; 
; UI: '=' for performing frequency and '+' for performing Duty Cycle
;     this UI has no clear buttom to recheck your input, I WAS TIRED FOR THAT
;     some times may put your finger on the buttom for a long time, this means alot of input (it doesn't work at rising of fallin edge)
;     the clock frequency must 4MHz or less, this is so important to have correct frequency and true input(HOLD Delay of buttoms are low becarefull)
;==================================================================================================================================================== 
; [READ ME] This is a assembly project which produce squre wave in the output. 
; Whit a matrix keypad you can chang frequency[100Hz : 1000Hz] and duty cycle[0%:100%].
; NO NEED EXTRA BUTTOM TO COMFORM THE NUMBER YOU WANT but after you enter your full number, 
; press '=' to confirm frequency in range [100 : 1000] and press '+'  to confirm duty cycle in range [0 : 100] to MCU.
; ABOUT TIME: I didn't use deley for makking time, it's terrible for RTOS designe. I preffered to use counter and skipping tasks._see in codes_ 
; I exprinced that each buttom hold about 100:150< mSEC and a buttom will press twice after 300:400> mSEC _seccond buttom will press after 300 msec_
; This MCU work at 4MHz. So each command _clock_ wast 1/4 uSEC. You can calculate how many should your counter counts to make that delay. my counter was
; in R18 , R17 16 bit full. and for clock 4MHz makes about 300mSEC delay.
; For making that time,R18, R17 sets on 0xFFFF at pressed buttom, MCU won't see keypad changes untill they become 0x0000
; more info about UI, registers, challanges, etc will put as a command.
;-----------------------------------------------------------------------ARCHITECTURE------------------
;R18-R17 is for counting. 16 bits. used in wait 300mSec for keypad input.
;R16 is a temp register for driving values into IN, OUT, DDR, PORT, etc registers
;R20 is fixed on 0x0A
;R19 is fixed on 0x00
;R31, R30 ON ROUND NUMBER wich makes delay
;R29, R28 OFF ROUND NUMBER wich makes delay
;R0 : R6 are used in arithmetic functions and reserved
;R21 and R23 are used in arithmetic functions (DEVISION) and reserved 

.INCLUDE "M32DEF.INC"
;-------------------------------
;-----------------------RAM -----
.EQU golden_T_2_addr		 = 0x0061
.EQU golden_T_1_addr		 = 0x0062
.EQU golden_T_0_addr		 = 0x0063
.EQU in_frequency_H_addr	  = 0x0064
.EQU in_frequency_L_addr	  = 0x0065
.EQU DutyCycle_addr			 = 0x0066
.EQU tottal_round_H_addr	 = 0x0067
.EQU tottal_round_L_addr	 = 0x0068
.EQU ON_round_H_addr		 = 0x0069
.EQU ON_round_L_addr		 = 0x0070
.EQU OFF_round_H_addr		 = 0x0071
.EQU OFF_round_L_addr		 = 0x0072
;----------------------Constant numbers-----
.EQU loop_freq_0 = 0xB0
.EQU loop_freq_1 = 0xAD
.EQU loop_freq_2 = 0x01

.EQU ten_num = 0x0A
.EQU zero_num = 0x00

.EQU yekan_full = 0xFF
.EQU dahgan_full =0xFF
;----------------------register defines----
.DEF temp = R16
.DEF KeyPad_counter_L = R17
.DEF KeyPad_counter_H = R18
.DEF clear = R19
.DEF ten = R20
;-------------------------------------DISGARD THIS------------------
       ;.EQU state = (R17) _It should be the address_  Beacuse of the LINE 41, when port became low by MCU ,the current flow from the pins hang them  
		  ;low and did'nt come back to high, in another hand i could'nt put those high by exprience. I tried to use state of a bottom to wait some
		  ; times, if the bottom was not pressed i can use line 41.(The pins acctully become Short Circut for a while) But I examine ussing small 
		  ;Ressistor on the pins(3:0) to prevent this event. that was usefull and effective and easy.
       ;.EQU  key_on  = 0xFE ;It works like a timmer. it counts while the register become 0x00 and it means buttom is free
       ;.EQU  key_off  = 0x00
;----------------------------------------------------------------------------------------------------
;=============================configurations and initiolization==================================
LDI R19 , zero_num   ;Constant number for clearring registers
LDI R20 , ten_num  ;Constant number 10 DEC. It used in multiplies in arithmetic functions
 MOV R2 , clear    ;clearring R2 and R3, it is the initiollizing for multiplies in arithmetic functions
 MOV R3 , clear

LDI R21 , loop_freq_0 ; R21 , R22 , R23 NEEDS FOR DEVIDER FUNCTION
LDI R22 , loop_freq_1
LDI R23 , loop_freq_2 
;------------------------------------------
LDI temp , HIGH(RAMEND) ; SP set
OUT SPH , temp
LDI R16 , LOW(RAMEND)
OUT SPL , R16
;--------------
LDI R16 , 0xF0  
OUT DDRD , R16  ; High nible of PORTD sets as output and low nible of PORTD set as input.
LDI R16 , 0x00  ; High nible input HZ
OUT PORTD , R16 ; High nible HZ and Low nible sets 0000

LDI R16 , 0xFF ; I use PORTB for show the key pressed number
OUT DDRB , R16 ; PORTB set as output.
LDI R16 , 0x00
OUT PORTB , R16 ; PORTB = 0x00

LDI R16 , 0xFF ; I preffered to use port A for my wave
OUT DDRA , R16 ; PORTA set as output.
LDI R16 , 0x00
OUT PORTA , R16 ; PORTA = 0x00
;--------------------------------------------------------------
LDI temp,0x32  ; 0x32 = 50
STS DutyCycle_addr,temp ;duty cycle=50% init value
;---
LDI temp,0x04
STS tottal_round_H_addr, temp ;now we have tottal number of rounds for makking T period of input frequency  
LDI temp,0x4C
STS tottal_round_L_addr, temp

LDI temp,0x02
STS OFF_round_H_addr, temp ;now we have tottal number of rounds for makking T period of input frequency  
LDI temp,0x26
STS OFF_round_L_addr, temp

LDI temp,0x02
STS ON_round_H_addr, temp ;now we have tottal number of rounds for makking T period of input frequency  
LDI temp,0x26
STS ON_round_L_addr, temp

LDI R31,0x02
LDI R30,0x26

LDI R29,0x02
LDI R28,0x26

;NOTE: 1100 rounds on + 1100 rounds off => f=100Hz , duty cycle = 50% THIS IS FOR CLOCK 8 MHz
;       44C HEX			44C HEX

;NOTE: 550 rounds on + 550 rounds off => f=100Hz , duty cycle = 50% THIS IS FOR CLOCK 4 MHz
;       226 HEX			226 HEX
;----------------------------------------------MAIN PROJECT----------------------------------------------------------------------  
start:
	TST R17				;Examine flag Z for condition  FOR MORE INFO ABOUT THIS, SEE LINE 11 AND 12 AND 13
	BREQ yekan_0        ;If Z=1 _R17=0_ don't decreas R17. R17 is used to (as a counter) for skipping keypad input watching
		DEC R17
		RJMP Blinking_Task
	yekan_0:		  				 ; I need mor bits to count more than 256
	    TST R18
		BREQ dahgan_0        ;If Z=1 _R18=0_ don't decreas R17. R17 is used to (as a counter) for skipping keypad input watching
			DEC R17
			DEC R18
		    RJMP Blinking_Task
		dahgan_0:
				;---------------------
				LDI R16 , 0x00    ;low nible must be 0000  because did not work when it was F/ ROW DIEGNOSING
				OUT PORTD , R16   ; PORTD = 0000---- for dignossing ROW
				;---------------------			
				SBIS PIND , 0 ; IF BOTTOM PRESSED FROM ROW 0
				 CALL Key_Press_Row0 ; GO FOR DIGNOSING THE COLUMN
				SBIS PIND , 1
				  CALL Key_Press_Row1			    
				SBIS PIND , 2
				  CALL Key_Press_Row2
				SBIS PIND , 3
				  CALL Key_Press_Row3 
                ;---------------------
				
		   Blinking_Task:
			   
;========R31 , R30 is for ON TIME			   
TST R30				;Examine flag Z for condition  FOR MORE INFO ABOUT THIS, SEE LINE 11 AND 12 AND 13
	BREQ yekan_1        ;If Z=1 _R17=0_ don't decreas R17. R17 is used to (as a counter) for skipping keypad input watching
		DEC R30
		RJMP LED_ON
	yekan_1:		  				 ; I need mor bits to count more than 256
	    TST R31
		BREQ dahgan_1        ;If Z=1 _R18=0_ don't decreas R17. R17 is used to (as a counter) for skipping keypad input watching
			DEC R30
			DEC R31
		    RJMP LED_ON
		dahgan_1:
;-------R29 , R28 is for OFF TIME
TST R28				;Examine flag Z for condition  FOR MORE INFO ABOUT THIS, SEE LINE 11 AND 12 AND 13
	BREQ yekan_2        ;If Z=1 _R17=0_ don't decreas R17. R17 is used to (as a counter) for skipping keypad input watching
		DEC R28
		RJMP LED_OFF
	yekan_2:		  				 ; I need mor bits to count more than 256
	    TST R29
		BREQ dahgan_2        ;If Z=1 _R18=0_ don't decreas R17. R17 is used to (as a counter) for skipping keypad input watching
			DEC R28
			DEC R29
		    RJMP LED_OFF
		dahgan_2:
		LDS R31,ON_round_H_addr
		LDS R30,ON_round_L_addr
		
LED_ON:
    LDI R16,0xFF
    OUT PORTA,R16 
	LDS R29,OFF_round_H_addr
    LDS R28,OFF_round_L_addr
	NOP ;calabrating...
	NOP
	NOP			 
RJMP start

LED_OFF:
  LDI R16,0x00
  OUT PORTA,R16
  NOP
RJMP start
    
;======================================================================================================================================
;When the row dignosed, MCU will pass here to find wich column cause that pin low
;-------------------------------------------ROW 0 DIGNOSED LET'S CLEAR THE COLUMN---------------------------------------------------------
 Key_Press_Row0: ;Readding from keypad
    LDI R16 , 0xE0 ;low nible must be 0000  because did not work when it was F
	OUT PORTD , R16 ; PORTD = 0111----
	SBIS PIND , 0
	  RJMP Show_00  ; to show the nomber on portb/ 04 means column0 row0
	
	LDI R16 , 0xD0 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1011----
	SBIS PIND , 0
	  RJMP Show_10  ; to show the nomber on portb/ 04 means column1 row0

	LDI R16 , 0xB0 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1101----
	SBIS PIND , 0
	  RJMP Show_20  ; to show the nomber on portb/ 04 means column2 row0

	LDI R16 , 0x70 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1110----
	SBIS PIND , 0
	  RJMP Show_30   ; to show the nomber on portb/ 04 means column3 row0
 RJMP start ; Some times row dignose and MCU will come here, but it would'nt find the column _maybe becuse of the noise_
					 ; and continiue the trail wich is no need, this line is for unpredicted event _the column have'nt seen_
					 ;I did'nt use RJMP Key_Press_Row0 beacuse i tried and some times it lock in this loop, start is much better
;------------------------------------------ROW 1 DIGNOSED LET'S CLEAR THE COLUMN--------------------------
 Key_Press_Row1: ;Readding from keypad
    LDI R16 , 0xE0 ;low nible must be 0000  because did not work when it was F
	OUT PORTD , R16 ; PORTD = 0111----
	SBIS PIND , 1
	  RJMP Show_01  ; to show the nomber on portb/ 04 means column0 row1
	
	LDI R16 , 0xD0 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1011----
	SBIS PIND , 1
	  RJMP Show_11  ; to show the nomber on portb/ 04 means column1 row1

	LDI R16 , 0xB0 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1101----
	SBIS PIND , 1
	  RJMP Show_21  ; to show the nomber on portb/ 04 means column2 row1

	LDI R16 , 0x70 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1110----
	SBIS PIND , 1
	  RJMP Show_31  ; to show the nomber on portb/ 04 means column3 row1
 RJMP start ; Some times row dignose and MCU will come here, but it would'nt find the column _maybe becuse of the noise_
					 ; and continiue the trail wich is no need, this line is for unpredicted event _the column have'nt seen_
					 ;I did'nt use RJMP Key_Press_Row1 beacuse i tried and some times it lock in this loop, start is much better
;------------------------------------------ROW 2 DIGNOSED LET'S CLEAR THE COLUMN--------------------------
 Key_Press_Row2: ;Readding from keypad
    LDI R16 , 0xE0 ;low nible must be 0000  because did not work when it was F
	OUT PORTD , R16 ; PORTD = 0111----
	SBIS PIND , 2
	  RJMP Show_02  ; to show the nomber on portb/ 04 means column0 row2
	
	LDI R16 , 0xD0 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1011----
	SBIS PIND , 2
	  RJMP Show_12  ; to show the nomber on portb/ 04 means column1 row2

	LDI R16 , 0xB0 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1101----
	SBIS PIND , 2
	  RJMP Show_22  ; to show the nomber on portb/ 04 means column2 row2

	LDI R16 , 0x70 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1110----
	SBIS PIND , 2
	  RJMP Show_32  ; to show the nomber on portb/ 04 means column3 row2
 RJMP start ; Some times row dignose and MCU will come here, but it would'nt find the column _maybe becuse of the noise_
					 ; and continiue the trail wich is no need, this line is for unpredicted event _the column have'nt seen_
					 ;I did'nt use RJMP Key_Press_Row2 beacuse i tried and some times it lock in this loop, start is much better
;------------------------------------------ROW 3 DIGNOSED LET'S CLEAR THE COLUMN--------------------------
 Key_Press_Row3: ;Readding from keypad
    LDI R16 , 0xE0 ;low nible must be 0000  because did not work when it was F
	OUT PORTD , R16 ; PORTD = 0111----
	SBIS PIND , 3
	  RJMP Show_03  ; to show the nomber on portb/ 04 means column0 row3
	
	LDI R16 , 0xD0 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1011----
	SBIS PIND , 3
	  RJMP Show_13  ; to show the nomber on portb/ 04 means column0 row3

	LDI R16 , 0xB0 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1101----
	SBIS PIND , 3
	  RJMP Show_23  ; to show the nomber on portb/ 04 means column0 row3

	LDI R16 , 0x70 ;low nible must be 0000  
	OUT PORTD , R16 ; PORTD = 1110----
	SBIS PIND , 3
	  RJMP Show_33  ; to show the nomber on portb/ 04 means column0 row3
 RJMP start ; Some times row dignose and MCU will come here, but it would'nt find the column _maybe becuse of the noise_
					 ; and continiue the trail wich is no need, this line is for unpredicted event _the column have'nt seen_
					 ;I did'nt use RJMP Key_Press_Row3 beacuse i tried and some times it lock in this loop, start is much better
 ;================================KEYPAD LOOKUP TABLE=========================================================
 ; After clearring both row and column, MCU pass here to show then number on PORTB, Then return to main _job_
 ;------------row 0--------------
 Show_00:
   LDI R16 , 0x07
   OUT PORTB , R16
    CALL Arith_Function
	;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_10:
   LDI R16 , 0x08
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_20:
   LDI R16 , 0x09
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_30:
   LDI R16 , 0xFF
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET
;-------------row 1---------------
Show_01:
   LDI R16 , 0x04
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_11:
   LDI R16 , 0x05
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_21:
   LDI R16 , 0x06
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_31:
   LDI R16 , 0xFE
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET
;-----------row 2----------------
Show_02:
   LDI R16 , 0x01
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_12:
   LDI R16 , 0x02
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_22:
   LDI R16 , 0x03
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_32:
   LDI R16 , 0xFD
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET
;-----------row 3---------------
Show_03:
   LDI R16 , 0xEF
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_13:
   LDI R16 , 0x00
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_23:
   LDI R16 , 0xDF
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET

Show_33:
   LDI R16 , 0xFC
   OUT PORTB , R16
    CALL Arith_Function
		;I have a number from keypad and must store it. Mention that you must store it one time
     RET
;=================ARITHMETIC FUNCTION===============
Arith_Function:
		LDI KeyPad_counter_L , yekan_full   ;Full for keypad timmer (DISABLE HOLD TIME)  
		LDI KeyPad_counter_H , dahgan_full
		
	CPI temp , 0xDF      ;'=' code for freq	        ;We have a number on R16. We should check it if it is '=' or not
	BREQ frequency_is_pressed
	   CPI temp , 0xFC   ;'+' code for duty cycle	;We have a number on R16. We should check it if it is '+' or not
	   BREQ DutyCycle_is_pressd	
	         MUL R2 , ten  ; R20 =0x0A ;this would be wrong if the number in R2 and R3 more than 256 
							; R2 must be clear for first number. EX:the number 300 contains R3 but we just mul R2,0x0A
			 CLC ; clear cary
	         ADD R0 , temp
			 ADC R1 , clear ;add just with carry R19=0x00 becouse input num is 1 byte
			 MOV R2 , R0	;storring in R3,R2 for next number to be ready for multiply
			 MOV R3 , R1			 			 
		RET ;i have a digit, go for next one or apply by pressing '=' or '+' on the next come
			 		  
	frequency_is_pressed:
	; I have frequency value in R3,R2 so need to save them and prepare for devision => 1/f = T
	; My main loop containe 40 commands, and each command (4MHz clk) wait for 1/4uSEC ==> each round in my main loop waits for 40*(1/4)uSEC => f=0.1MHz
	; Now, For 100Hz => T is 0.01SEC(10mSEC) it means that I have to wait 1,000 rouns (1uSEC*1,000 = 1,000uSEC = 10mSEC)
	; So, for make delay I count rouns, (rounds = 0.1MHz  /  input frequency) or (rounds = input T / 5 uSEC) --- 0.2MHz named loop_freq_k
	; This is period. for duty cycle it must be dived. X% ON round and (100-X)% OFF rounds. see duty cycle algorithm for more information 	  
	STS in_frequency_H_addr, R3 ;storring frequencu in SRAM    
	STS in_frequency_L_addr, R2
	;--Preparring values in registers for devision:
	  MOV R4 , R2		 ; R4 and R5 are the registers that contain Frequency values
	  MOV R5 , R3		 ; AND NEEDS FOR DEVIDER FUNCTION
	  MOV R6 , clear     ; this is 24 bits devide by 16 bits you know
	   	  
	  MOV R24, clear  ;clearring R25 and R24 (quotient)
	  MOV R25, clear 
	   
	  LDI R21 , loop_freq_0 ; R21 , R22 , R23 NEEDS FOR DEVIDER FUNCTION
	  LDI R22 , loop_freq_1
	  LDI R23 , loop_freq_2 
	  ;--go for devision function:
      ;--R23 , R22 , R21 devide by R6 , R5 , R4 =result=> number of rounds wiche is input T ,(loop f/input f). put the result into R25 , R24 
	  CALL Dev_Start ;registers have their own valuse and go for function.

	   STS tottal_round_H_addr, R25 ;now we have tottal number of rounds for makking T period of input frequency  
	   STS tottal_round_L_addr, R24 ;I'm sure its going to osilate in than frequency let's go for setting duty cycle
	   ;--befor next step we must clearring registers and initiolizing them for another begging.
		MOV R2 , clear ;clearring R2 and R3 for begging time
	    MOV R3 , clear 
		MOV R24 , clear ;clearring R2 and R3 for begging time
	    MOV R25 , clear
		 	 
  RJMP Recheck     ;when a new frequency applied. it must fit with the duty cycle that exsist in DutyCycle_addr
	  

    DutyCycle_is_pressd: ;Befor, READ LINE " frequency_is_pressed: "
	;We have tottal rounds (T) and it must devide by duty cycle input.
	;X% is for ON round and (100-X)% is for OFF rounds. 
	      ;Here after the '+' pressed, a number [0:100]<255 fit in register R2 		 
		  STS DutyCycle_addr, R2  ;storring duty cycle in SRAM		  	 
		  ;I have tottal rounds and want to seprate it in ON and OFF rounds
		  ;----So prepare values in register for division. (tottal rounds*duty cycle)/100 _becouse duty cycle is in percent_
		  ;--First 16 bit * 8 bit multiply 
  Recheck: ;RESET THE DUTY CYCLE BECOUSE FREQUENCY CHANGED
		  LDS R21,tottal_round_L_addr   ;R22, R21 * R4
		  LDS R22,tottal_round_H_addr   ;total rounds loaded for multiply DutyCycle
		  MOV R23 , clear
		  LDS R4, DutyCycle_addr        ;Put duty cycle value from DutyCycle_addr to R4 for multiply
		  
		    ;--------this is a little compact: 
			 MUL R21,R4				;    R23     R22      R21
			 MOV R21,R0				; x                   R4 
			 MOV temp,R1			;-----------------------
			 MUL R22,R4				; =		     temp     R21     :R21= R4 * R21 and temp= R4 * R22 
			 ADD R0,temp			;    R1      R0
			 ADC R1,clear		    ;    R1      R0       R21 
			 MOV R22,R0				;    R23     R22      R21 = (total rounds x DutyCyle)
			 MOV R23,R1
			 
			 ;R23, R22, R21 are ready for dividding by 100DEC 0x64
		  ;--This is 24 bit / 8 bit division.  
		  MOV R24, clear ;clearring R25 and R24 , 
	      MOV R25, clear
		  
		  LDI temp, 0x64 
		  MOV R4, temp   ;R23, R22, R21 are ready for dividding by 100DEC 0x64
		  MOV R5,clear   ;we don't need R5, you know
		  MOV R6,clear   ;we don't need R6, you know
		  
	 CALL Dev_Start	;For any usage of this function, make sure that you load the right number into R23, R22, R21/R6, R5, R4
				  
		 STS ON_round_H_addr,R25    ;We have (total rounds x DutyCyle)/100 in the registers R25,R24
		 STS ON_round_L_addr,R24
		 MOV R31,R25  ;ON ROUNDS IN REGISTERS R31 and R30 as you see in main
		 MOV R30,R24	
		   STS ON_round_H_addr, R31 ;now we have tottal number of rounds for makking T period of input frequency 
		   STS ON_round_L_addr, R30

		 LDS R29,tottal_round_H_addr ;R29 and R28 contain tottal rounds
		 LDS R28,tottal_round_L_addr 
		 SUB R28,R30    ;OFF ROUNDS = tottal rounds - ON rounds
		 SBC R29,R31     		   
		   STS OFF_round_H_addr, R29 ;now we have tottal number of rounds for makking T period of input frequency
		   STS OFF_round_L_addr, R28 	
	    MOV R2 , clear ;clearring R2 and R3 for begging time
	    MOV R3 , clear 
		MOV R24 , clear ;clearring R2 and R3 for begging time
	    MOV R25 , clear
		  
    RET ;We have vlues in our registers. R28, R29, R30, R31

;==================================================================================================
;This is simple division algorithm. The error of this is +-1 in quotient and doen't check the signed of remain
;becous i just need the quotient. And the error is low for that.
;24 bits devision algorithm R23, R22, R21 / R6 , R5 , R4 AND R25 , R24 are the results (quotient)-------------
Dev_Start:  
  CP R23,R6		;check if the big num devide by small num 
  BRBS 4,final  ;If negetive RET ;devide is imposible and opration finishned. HAVE R24 , R25
; BREQ level_0  ;it become wrong , i couldent find solution for this line. really no need actully.
    ADIW R25: R24, 1  ;increasing quotient and then subcribe true number
    SUB R21 , R4	  ;subcibbing...
    SBC R22 , R5
    SBC R23 , R6
RJMP Dev_Start			;go for anouther check, if it is devidble do it 
  level_0:
    CP R22,R5			;check if the big num devide by small num
	BRBS 4,final		;If negetive RET ;devide is imposible and opration finishned. HAVE R24 , R25
;	BREQ level_1		;it become wrong , i couldent find solution for this line. really no need actully.
	  ADIW R25: R24, 1  ;increasing quotient and then subcribe true number
	  SUB R21 , R4		;subcibbing...
	  SBC R22 , R5
;	  SBC R23 , R6		;no need, clearly
  RJMP level_0			;go for anouther check, if it is devidble do it
    level_1:
	  CP R21,R4				 ;check if the big num devide by small num
	  BRBS 4,final			;If negetive RET ;devide is imposible and opration finishned. HAVE R24 , R25
;	  BREQ final			;it become wrong , i couldent find solution for this line. really no need actully.
	    ADIW R25: R24, 1    ;increasing quotient and then subcribe true number
		SUB R21 , R4		;subcibbing...
;		SBC R22 , R5        ;no need, clearly
;		SBC R23 , R6
	RJMP level_1			;go for anouther check, if it is devidble do it
  final:  ;the division is finished, we arrived at remain in R23,R22,R21 registers  
 RET
 
