;***********************************************************
;*	This is the final project template for ECE375 Winter 2021
;***********************************************************
;*	 Author: Sheldon Roberts
;*   Date: 3/11/21
;***********************************************************
.include "m128def.inc"			; Include definition file
;***********************************************************
;*	Internal Register Definitions and Constants
;*	(feel free to edit these or add others)
;***********************************************************
.def	rlo = r0				; Low byte of MUL result
.def	rhi = r1				; High byte of MUL result
.def	zero = r2				; Zero register, set to zero in INIT, useful for calculations
.def	A = r3					; A variable
.def	B = r4					; Another variable
.def	oloop = r5				; Outer Loop Counter
.def	iloop = r6				; Inner Loop Counter
.def	dataptr = r7			; data ptr

.def	mpr = r16				; Multipurpose register
.def	mpr1 = r17				; Multipurpose register 1
.def	mpr2 = r18				; Multipurpose register 2
.def	mpr3 = r19				; Multipurpose register 3
.def	mpr4 = r20				; Multipurpose register 4
.def	mpr5 = r21				; Multipurpose register 5
.def	mpr6 = r22				; Multipurpose register 6
.def	mpr7 = r23				; Multipurpose reigster 7

.equ	Remainder_Addr			=	$0E15	; 2 bytes ($0E15:$0E16)
.equ	Sqrt_Loop_Counter_Addr	=	$0E17	; 2 bytes ($0E17:$0E18)
.equ	Fproduct_Addr			=	$0E19	; 4 bytes ($0E19:$0E1C)
.equ	Word1_Addr				=	$0E1D	; 2 bytes ($0E1D:$0E1E)
.equ	Word2_Addr				=	$0E1F	; 2 bytes ($0E1F:$0E20)
.equ	GMAddr					=	$0E21	; 4 bytes ($0E21:$0E24)
.equ	GM_TEMP_ADDR			=	$0E25	; 4 bytes ($0E25:$0E28)
.equ	Dec_Three_Byte_Addr		=	$0E29	; 3 bytes ($0E29:$0E2B)
.equ	Word7_Addr				=	$0E2C	; 7 bytes ($0E2C:$0E32)
.equ	Word4_Addr				=	$0E33	; 4 bytes ($0E33:$0E36)
.equ	Quotient7_Addr			=	$0E37	; 7 bytes ($0E37:$0E3D)
.equ	Quotient7_Rem_Addr		=	$0E3E	; 4 bytes ($0E3E:$0E41)


;***********************************************************
;*	Data segment variables
;*	(feel free to edit these or add others)
;***********************************************************
.dseg
.org	$0100						; data memory allocation for operands
operand1:		.byte 10			; allocate 10 bytes for a variable named op1


;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment
;-----------------------------------------------------------
; Interrupt Vectors
;-----------------------------------------------------------
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt
.org	$0046					; End of Interrupt Vectors

;-----------------------------------------------------------
; Program Initialization
;-----------------------------------------------------------
INIT:	; The initialization routine
		clr		zero

	; Initialize the stack
	ldi	mpr, high(ramend)
	out	sph, mpr
	ldi	mpr, low(ramend)
	out	spl, mpr

	; Uncomment this function to loop through every square in order
	;call SQUARE_IN_ORDER 
	nop

	;----------------------------------------------------------------------------------------------------------
	; PROBLEM A BEGIN

	; Clear the quotient space in data memory (all three bytes)
	ldi ZH, high(Quotient)
	ldi ZL, low(Quotient)
	ldi mpr6, $00
	st Z+, mpr6
	st Z+, mpr6
	st Z+, mpr6

	; Load GM into mpr..mpr3
	call GET_GM
	nop		; On this line, r16::r19 contain GM
	
	; Getting the r value
	ldi ZH, high(OrbitalRadius<<1)
	ldi ZL, low(OrbitalRadius<<1)
	; Z now has the address of the OrbitalRadius
	lpm mpr4, Z+					; mpr4 now has the less significant byte
	lpm mpr5, Z+					; mpr5 now has the more significant byte
	nop		; On this line, r20:r21 contain OrbitalRadius

DIV_LOOP_TOP:
	cpi mpr3, 0
	breq CHECK_MPR2_ZERO
	rjmp CALC_TEMP_MPR
CHECK_MPR2_ZERO:
	cpi mpr2, 0
	breq CHECK_MPR1_LT_MPR5
	rjmp CALC_TEMP_MPR
CHECK_MPR1_LT_MPR5:
	cp mpr1, mpr5
	brlo DIV_LOOP_TERMINATE		; If the latest subtraction of r made GM less than r, end the loop


CALC_TEMP_MPR:
	; Start of calculation of GM_TEMP_MPR
	cp mpr, mpr4			; If mpr < mpr4, we need to carry from a more significant byte
	brlo R0_MPR_LT_MPR4

	sub mpr, mpr4			; Else just subtract it
	rjmp CALC_TEMP_MPR1

R0_MPR_LT_MPR4:
	; now check if (mpr1 == 0)
	cpi mpr1, 0
	breq R0_MPR1_EQ_ZERO
	rjmp R0_MPR1_EQ_ZERO_N		; Just jump past the next condition checks. We know that mpr1 can be taken from

R0_MPR1_EQ_ZERO:
	; now check if (r2 == 0)
	cpi mpr2, 0
	breq R0_MPR2_EQ_ZERO
	rjmp R0_MPR2_EQ_ZERO_N

R0_MPR2_EQ_ZERO:
	; now check if (r3 == 0)
	cpi mpr3, 0
	breq R0_MPR3_EQ_ZERO
	rjmp R0_MPR3_EQ_ZERO_N		; We know that we can borrow from mpr3, so do that. Do not leave the loop.
	
R0_MPR3_EQ_ZERO:		; If we get here, we are leaving the loop
	; We can no longer subtract further
	; Do not update mpr0:mpr1:mpr2:mpr3, they currently have the correct values
	; Jump to the exit
	rjmp DIV_LOOP_TERMINATE		; Exit the loop
	
R0_MPR3_EQ_ZERO_N:
	dec mpr3

R0_MPR2_EQ_ZERO_N:
	dec mpr2

R0_MPR1_EQ_ZERO_N:
	dec mpr1			; if mpr1 is zero, it will become $FF because it loops around
	ldi mpr6, $FF		; Do the following equation: mpr6 = $FF - mpr4 + mpr + 1
	sub mpr6, mpr4
	add mpr6, mpr
	inc mpr6
	mov mpr, mpr6

CALC_TEMP_MPR1:

	; Check if (mpr1 < mpr5)
	cp mpr1, mpr5
	brlo R1_MPR1_LT_MPR5		; if mpr1 < mpr5, check more conditions (mpr2 == 0)

	sub mpr1, mpr5			; else, just do the subtraction
	rjmp DIV_LOOP_END		; Then jump to the end of the loop

R1_MPR1_LT_MPR5:
	; Now that we know (mpr1 < mpr5)
	; Check to see if (mpr2 == 0)
	cpi mpr2, 0
	breq R1_MPR2_EQ_ZERO		; If (mpr2 == 0), then check if (mpr3 == 0) as well before continuing
	rjmp R1_MPR2_EQ_ZERO_N		; Otherwise don't bother checking and just continue

R1_MPR2_EQ_ZERO:
	; Now that we know (mpr2 == 0)
	; Check if (mpr3 == 0)
	cpi mpr3, 0
	breq R1_MPR3_EQ_ZERO		; If (mpr3 == 0), then we need to be exiting the loop
	rjmp R1_MPR3_EQ_ZERO_N		; Otherwise continue

R1_MPR3_EQ_ZERO:
	; If we get here, we need to exit the loop
	; We can no longer subtract further
	; Do not update mpr0:mpr1:mpr2:mpr3, they currently have the correct values
	; Jump to the exit
	rjmp DIV_LOOP_TERMINATE		; Exit the loop

R1_MPR3_EQ_ZERO_N:
	dec mpr3

R1_MPR2_EQ_ZERO_N:
	dec mpr2			; if mpr2 is zero, it will become $FF because it loops around
	ldi mpr6, $FF		; Do the following equation: mpr6 = $FF - mpr5 + mpr1 + 1
	sub mpr6, mpr5
	add mpr6, mpr1
	inc mpr6
	mov mpr1, mpr6

DIV_LOOP_END:
	; Increment the quotient
	call INC_QUOTIENT
	nop

	rjmp DIV_LOOP_TOP


DIV_LOOP_TERMINATE:		; This is past the loop. At this point we should have the correct quotient and remainder
	; Store the remainder into memory
	ldi YH, high(Remainder_Addr)
	ldi YL, low(Remainder_Addr)
	st Y+, mpr
	st Y+, mpr1

	nop 
	
	; Round the quotient
	call ROUND_QUOTIENT
	nop

	; Find the square root of (GM/r)
	; Square root (GM/r)
	; UNComment this
	call SQUARE_ROOT
	nop		; On this line, Sqrt_Loop_Counter_Addr: 

	; Place final value into Velocity in program memory
	ldi ZH, high(Sqrt_Loop_Counter_Addr)
	ldi ZL, low(Sqrt_Loop_Counter_Addr)
	ldi YH, high(Velocity)
	ldi YL, low(Velocity)
	ldi mpr1, 0

VEL_WRITE_LOOP:
	ld mpr, Z+
	st Y+, mpr
	inc mpr1
	cpi mpr1, 2
	brne VEL_WRITE_LOOP

	nop		; On this line, the velocity should be correct in data memory

	; Problem A COMPLETE
	; -------------------------------------------------------------------------------------------------

	
	; -------------------------------------------------------------------------------------------------
	; PROBLEM B BEGIN

	; Store OrbitalRadius into the word1 and word2 data spaces, preparing for MUL_16
	ldi XH, high(Word1_Addr)
	ldi XL, low(Word1_Addr)
	ldi YH, high(Word2_Addr)
	ldi YL, low(Word2_Addr)
	ldi ZH, high(OrbitalRadius<<1)
	ldi ZL, low(OrbitalRadius<<1)
	lpm mpr, Z+
	lpm mpr1, Z+
	st X+, mpr
	st X+, mpr1
	st Y+, mpr
	st Y+, mpr1
	nop		; On this line, Word1($0E1D:$0E1E) and Word2($0E1F:$0E20) contain OrbitalRadius

	; Multiply r*r
	call MUL_16
	nop		; On this line, Fproduct($0E19:$0E1C) contains r^2
	nop		; Contains: 02 84 AF 10
			
	; Move Fproduct into Product
	call FP_ST_P
	nop		; On this line, Product($0E05:$0E0B) contains r^2

	; Multiply (r^2)*r
	call FOUR_MUL_RAD
	nop		; On this line, Product($0E05:$0E0B) contains r^3
			; Should be: 00 00 3F F0 EC F2 40
			; Currently: 00 00 3F F0 EC F2 40

	; Multiply (r^3)*4*(pi^2) == (r^3)*$28
	ldi mpr, $28
	mov r3, mpr
	call SIX_MUL_1
	nop		; On this line, Product($0E05:$0E0B) should contain (r^3)*$28
			; Should be: 00 09 FD A5 05 DA 00
			; Currently: 00 09 FD A5 05 DA 00

	; Clear Word7($0E2C:$0E32)
	ldi XH, high(Word7_Addr)
	ldi XL, low(Word7_Addr)
	call CLR_WORD7

	; Clear Word4($0E33:$0E36)
	ldi ZH, high(Word4_Addr)
	ldi ZL, low(Word4_Addr)
	ldi mpr, 0
	st Z+, mpr
	st Z+, mpr
	st Z+, mpr
	st Z+, mpr

	nop		; On this line, Word7($0E2C:$0E32) and Word4($0E33:$0E39) should be clear

	; Load Product into Word7 to prepare for a SEVEN_DIV_4 call
	call LOAD_PRODUCT_Word7
	nop		; On this line, Word7_Addr($0E2C:$0E32) should contain Product($0E05:$0E0B)
			; 00 09 FD A5 05 DA 00

	; Load GM into Word4 to prepare for a SEVEN_DIV_4 call
	call LOAD_GM_Word4
	nop		; On this line, Word4_Addr($0E33) should contain the GM

	; Divide Word7 by Word4
	call SEVEN_DIV_4
	nop		; On this line, Quotient7_Addr($0E37:$0E3D) should contain ( (4*pi^2*r^3) / (GM) )
			; Word7_Addr($0E2C) should contain the remainder
			; Correct:  00 00 00 1A 46 3C 61

				
	; Round Quotient7 based on the Quotient7_Rem and Product
	; call ROUND_QUOTIENT7
	nop		; On this line, Quotient7_Addr($0E37:$0E3D) should contain the correct, rounded, value


	; Calculate the square root of Quotient7 
	;call SEVEN_SQRT
	nop		; On this line, Period($0E0C:$0E0E) should contain the correct, rounded, value

	; ROUND THE FINAL PERIOD?

	; END OF PROBLEM B

	; PROBLEM B END
	; -------------------------------------------------------------------------------------------------


	jmp	Grading				; this should be the very last instruction of your code

;-----------------------------------------------------------
;	Procedures and Subroutines
;-----------------------------------------------------------

;-----------------------------------------------------------
;	Func: SEVEN_DIV_4
;	Desc: Divide Word7($0E2C) by Word4($0E33)
;   Parameters: Word7, Word4
;-----------------------------------------------------------
SEVEN_DIV_4:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6

	; Do division on Word7 and store result in Quotient7

	; Clear Quotient7_Addr($0E37)
	ldi XH, high(Quotient7_Addr)
	ldi XL, low(Quotient7_Addr)
	call CLR_WORD7
	nop		; On this line, Quotient7 is cleared

	ldi mpr1, 0

SEVEN_DIV_4_LOOP_TOP:
	call SEVEN_SUB_4
	nop		; On this line, Word7_Addr($0E2C) contains (Word7 - GM)
	; If Word7 == GM, use the current Quotient7_Addr($0E37). Do nothing and exit the loop.
	; Correct  : 00 09 FD A4 FF C4 F8
	; Currently: 00 09 FD A4 05 d9 00
	
	call SEVEN_CP_4
	nop		; On this line, mpr1 should equal 0, 1, or 2

	cpi mpr1, 0
	brne SEVEN_DIV_4_CHECK_ONE

	; Otherwise increment Quotient7 and continue the loop.
	call INC_QUOTIENT7
	nop		; On this line, Quotient7_Addr plus one
	rjmp SEVEN_DIV_4_LOOP_TOP

SEVEN_DIV_4_CHECK_ONE:
	cpi mpr1, 1
	brne SEVEN_DIV_4_LOOP_TERMINATE

	; Otherwise, Word7 < GM, Decrement Quotient7_Addr, and then exit the loop.
	call DEC_QUOTIENT7
	nop		; On this line, Quotient7 contains the quotient minus one

SEVEN_DIV_4_LOOP_TERMINATE:
	nop		; On this line, Quotient7_Addr($0E37) contains the quotient
			; Word7($0E2C) contains the remainder

	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: SEVEN_CP_4
;	Desc: Compare Word7_Addr to Word4_Addr
;	Return: mpr1
;-----------------------------------------------------------
SEVEN_CP_4:
	push mpr
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6
	push mpr7

	; If (w7[6] != 00), then exit with ZERO
	ldi ZH, high(Word7_Addr)
	ldi ZL, low(Word7_Addr)
	ldi mpr7, 6
	call POINT_Z_MPR7
	ld mpr, Z
	cpi mpr, 0
	breq LEAVE_ZERO_2

	; If (w7[5] != 00), then exit with ZERO
	ldi ZH, high(Word7_Addr)
	ldi ZL, low(Word7_Addr)
	ldi mpr7, 5
	call POINT_Z_MPR7
	ld mpr, Z
	cpi mpr, 0
	breq LEAVE_ZERO_2

	; If (w7[4] != 00), then exit with ZERO
	ldi ZH, high(Word7_Addr)
	ldi ZL, low(Word7_Addr)
	ldi mpr7, 4
	call POINT_Z_MPR7
	ld mpr, Z
	cpi mpr, 0
	breq LEAVE_ZERO_2

	rjmp SKIP_LEAVE_ZERO_2

LEAVE_ZERO_2:
	ldi mpr1, 0
	pop mpr7
	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr

	ret
	
SKIP_LEAVE_ZERO_2:
	; If (w7[3] == w4[3]), then branch to next conditions
	ldi ZH, high(Word7_Addr)
	ldi ZL, low(Word7_Addr)
	ldi mpr7, 3
	call POINT_Z_MPR7
	ld mpr, Z

	ldi ZH, high(Word4_Addr)
	ldi ZL, low(Word4_Addr)
	ldi mpr7, 3
	call POINT_Z_MPR7
	ld mpr2, Z

	cp mpr, mpr2
	breq MPR7_CP_IDX2

	; Elseif w7[3] > w4[3], LEAVE ZERO
	cp mpr2, mpr
	brlo SEVEN_CP_4_LEAVE_ZERO

	; Else LEAVE ONE
	rjmp SEVEN_CP_4_LEAVE_ONE

MPR7_CP_IDX2:

	; If (w7[2] == w4[2]), then branch to next conditions
	ldi ZH, high(Word7_Addr)
	ldi ZL, low(Word7_Addr)
	ldi mpr7, 2
	call POINT_Z_MPR7
	ld mpr, Z

	ldi ZH, high(Word4_Addr)
	ldi ZL, low(Word4_Addr)
	ldi mpr7, 2
	call POINT_Z_MPR7
	ld mpr2, Z

	cp mpr, mpr2
	breq MPR7_CP_IDX1

	; Elseif w7[2] > w4[2], LEAVE ZERO
	cp mpr2, mpr
	brlo SEVEN_CP_4_LEAVE_ZERO

	; Else LEAVE ONE
	rjmp SEVEN_CP_4_LEAVE_ONE

MPR7_CP_IDX1:

	; If (w7[1] == w4[1]), then branch to next conditions
	ldi ZH, high(Word7_Addr)
	ldi ZL, low(Word7_Addr)
	ldi mpr7, 1
	call POINT_Z_MPR7
	ld mpr, Z

	ldi ZH, high(Word4_Addr)
	ldi ZL, low(Word4_Addr)
	ldi mpr7, 1
	call POINT_Z_MPR7
	ld mpr2, Z

	cp mpr, mpr2
	breq MPR7_CP_IDX0

	; Elseif w7[1] > w4[1], LEAVE ZERO
	cp mpr2, mpr
	brlo SEVEN_CP_4_LEAVE_ZERO

	; Else LEAVE ONE
	rjmp SEVEN_CP_4_LEAVE_ONE

MPR7_CP_IDX0:
	; If (w7[0] == w4[0]), then LEAVE TWO
	ldi ZH, high(Word7_Addr)
	ldi ZL, low(Word7_Addr)
	ld mpr, Z

	ldi ZH, high(Word4_Addr)
	ldi ZL, low(Word4_Addr)
	ld mpr2, Z

	cp mpr, mpr2
	breq SEVEN_CP_4_LEAVE_TWO

	; Elseif w7[0] > w4[0], LEAVE ZERO
	cp mpr2, mpr
	brlo SEVEN_CP_4_LEAVE_ZERO

	; Else LEAVE ONE
	rjmp SEVEN_CP_4_LEAVE_ONE 

SEVEN_CP_4_LEAVE_ZERO:		; Zero means increment your counter and continue the loop
	ldi mpr1, 0
	rjmp SEVEN_CP_4_END

SEVEN_CP_4_LEAVE_ONE:		; One means exit the loop and use the PREVIOUS counter for your value
	ldi mpr1, 1
	rjmp SEVEN_CP_4_END

SEVEN_CP_4_LEAVE_TWO:		; Two means exit the loop and use the CURRENT counter as the square
	ldi mpr1, 2

SEVEN_CP_4_END:
	
	pop mpr7
	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: ROUND_QUOTIENT7
;	Desc: Round Quotient7($0E37) based on what is left in Word7($0E2C)
;	Parameters: Quotient7_Addr, Word7_Addr
;-----------------------------------------------------------
ROUND_QUOTIENT7:
	;
	ret

;-----------------------------------------------------------
;	Func: SEVEN_SUB_4
;	Desc: 
;	Parameters: Word7_Addr, mpr7
;-----------------------------------------------------------
SEVEN_SUB_4:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6

	ldi mpr7, 0
	call SEVEN_SUB_4_STEPS
	ldi mpr7, 1
	call SEVEN_SUB_4_STEPS
	ldi mpr7, 2
	call SEVEN_SUB_4_STEPS
	ldi mpr7, 3
	call SEVEN_SUB_4_STEPS
	
	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: SEVEN_SUB_4_STEPS
;	Desc: 
;	Parameters: mpr7
;-----------------------------------------------------------
SEVEN_SUB_4_STEPS:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6

	ldi ZH, high(Word4_Addr)
	ldi ZL, low(Word4_Addr)
	call POINT_Z_MPR7
	ld mpr1, Z

	ldi ZH, high(Word7_Addr)
	ldi ZL, low(Word7_Addr)
	call POINT_Z_MPR7
	ld mpr, Z+
	; Z is now pointing at w7[mpr7+1]

	nop		; On this line, mpr contains w7[mpr7] and mpr1 contains w4[mpr7]

	sub mpr, mpr1	; After this line, mpr contains w7[mpr7] - w4[mpr7]
	; If the subtraction didn't require a carry, jump to end
	brcc SEVEN_SUB_4_CC

	; Else decrement w7[mpr7+1]
	ld mpr, Z
	dec mpr
	st Z+, mpr		; Z is now pointing at w7[mpr7+2]
	cpi mpr, $FF
	brne SEVEN_SUB_4_CC	; If a carry was not required, jump to end

	; Else decrement w7[mpr7+2]
	ld mpr, Z
	dec mpr
	st Z+, mpr		; Z is now pointing at w7[mpr7+3]
	cpi mpr, $FF
	brne SEVEN_SUB_4_CC	; If a carry was not required, jump to end

	; Else decrement w7[mpr7+3]
	ld mpr, Z
	dec mpr
	st Z+, mpr		; Z is now pointing at w7[mpr7+4]
	cpi mpr, $FF
	brne SEVEN_SUB_4_CC	; If a carry was not required, jump to end

	; Else decrement w7[mpr7+4]
	ld mpr, Z
	dec mpr
	st Z+, mpr		; Z is now pointing at w7[mpr7+5]
	cpi mpr, $FF
	brne SEVEN_SUB_4_CC	; If a carry was not required, jump to end

	; Else decrement w7[mpr7+5]
	ld mpr, Z
	dec mpr
	st Z+, mpr		; Z is now pointing at w7[mpr7+6]
	cpi mpr, $FF
	brne SEVEN_SUB_4_CC	; If a carry was not required, jump to end

	; Else decrement w7[mpr7+6]
	ld mpr, Z
	dec mpr
	st Z, mpr

SEVEN_SUB_4_CC:	; Jump here if neither the subtraction nor the subsequent decrements required a carry

	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: SIX_MUL_1
;	Desc: Multiply the first six bytes in Product by r3. Store result in Product.
;   Parameters: r3, Product($0E05:$0E0B)
;-----------------------------------------------------------
SIX_MUL_1:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6
	push mpr7

	; Load the first 6 bytes of Product into mpr:mpr1:mpr2:mpr3:mpr4:mpr5
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	ld mpr, Z+
	ld mpr1, Z+
	ld mpr2, Z+
	ld mpr3, Z+
	ld mpr4, Z+
	ld mpr5, Z+
	nop		; On this line, mpr5:mpr4:mpr3:mpr2:mpr1:mpr contain Product($0E05:$0E0B)
			; Should be: 3F F0 EC F2 40
			; Currently: 00 3F F0 EC F2 40

	; Load $28 into r3
	ldi mpr6, $28
	mov r3, mpr6

	; Clear the product to get it ready for a new value calculation
	ldi XH, high(Product)
	ldi XL, low(Product)
	call CLR_WORD7

	; New Product will equal:
	; r3,mpr + r3,mpr1 + r3,mpr2 + r3,mpr3 + r3,mpr4 + r3,mpr5
	; (28*40)  + (28*F2)_s1   + 28*EC_s2   + 28*F0_s3   + r8*3F_s4   +  28*00_s5
	; = 00 09 FD A5 05 DA 00

	; CASE 0.
	mul r3, mpr
	; Simply place product into Product. p0<-r0, p1<-r1
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	st Z+, r0
	st Z+, r1
	nop		; On this line, Product contains: 00 00 00 00 00 0A 00
			;					   Currently: 00 00 00 00 00 0A 40

	; CASE 1. Left shift 1 byte
	ldi mpr7, 1
	mul r3, mpr1
	call SIX_MUL_1_STEPS
	nop		; On this line, Product contains: 00 00 00 00 25 DA 00

	; CASE 2. Left shift 2 bytes
	ldi mpr7, 2
	mul r3, mpr2
	call SIX_MUL_1_STEPS
	nop		; On this line, Product contains: 00 00 00 25 05 DA 00

	; CASE 3. Left shift 3 bytes
	ldi mpr7, 3
	mul r3, mpr3
	call SIX_MUL_1_STEPS
	nop		; On this line, Product contains: 00 00 25 A5 05 DA 00

	; CASE 4. Left shift 4 bytes
	ldi mpr7, 4
	mul r3, mpr4
	call SIX_MUL_1_STEPS
	nop		; On this line, Product contains: 00 09 FD A5 05 DA 00

	; CASE 5. Left shift 5 bytes
	ldi mpr7, 5
	mul r3, mpr5
	call SIX_MUL_1_STEPS
	nop		; On this line, Product contains: 00 09 FD A5 05 DA 00

	pop mpr7
	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: SIX_MUL_1_STEPS
;	Desc: Addition steps executed during SIX_MUL_1.
;   Parameters: r1:r0, mpr7, Product($0E05:$0E0B)
;-----------------------------------------------------------
SIX_MUL_1_STEPS:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6

	; Left shift pruduct by mpr7 bytes


	; Add r1:r0 to Product, but left shifted mpr7 times
	; (p[mpr7]) <- (r0 + p[mpr7])

	; Load p[mpr7] into mpr. Then add it to r0
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	call POINT_Z_MPR7
	nop		; On this line, Z is pointing at p[mpr7]

	ld mpr, Z+		; Z is now pointing at p[mpr7+1]
	add r0, mpr
	brcc SIX_MUL_1_R0_CC		; If p[mpr7] doesnt overflow, don't increment p[mpr7+1]

	; Else increment p[mpr7+1]
	; Z currently points to p[mpr7+1]
	ld mpr, Z		; Load p[mpr7+1] into mpr
	inc mpr			; Increment p[mpr7+1]
	st Z+, mpr		; Store the incremented p[mpr7+1] back into memory
	cpi mpr, 0		; If p[mpr7+1] doesn't overflow, don't increment p[mpr7+2]
	brne SIX_MUL_1_R0_CC

	; Else increment p[mpr7+2]
	; Z currently points to p[mpr7+2]
	ld mpr, Z		; Load p[mpr7+2] into mpr
	inc mpr			; Increment p[mpr7+2]
	st Z+, mpr		; Store the incremented p[mpr7+2] back into memory
	cpi mpr, 0		; If p[mpr7+2] doesn't overflow, don't increment p[mpr7+3]
	brne SIX_MUL_1_R0_CC

	; Else increment p[mpr7+3]
	; Z currently points to p[mpr7+3]
	ld mpr, Z		; Load p[mpr7+3] into mpr
	inc mpr			; Increment p[mpr7+3]
	st Z+, mpr		; Store the incremented p[mpr7+3] back into memory
	cpi mpr, 0		; If p[mpr7+3] doesn't overflow, don't increment p[mpr7+4]
	brne SIX_MUL_1_R0_CC

	; Else increment p[mpr7+4]
	; Z currently points to p[mpr7+4]
	ld mpr, Z		; Load p[mpr7+4] into mpr
	inc mpr			; Increment p[mpr7+4]
	st Z+, mpr		; Store the incremented p[mpr7+4] back into memory
	cpi mpr, 0		; If p[mpr7+4] doesn't overflow, don't increment p[mpr7+5]
	brne SIX_MUL_1_R0_CC

	; Else increment p[mpr7+5]
	; Z currently points to p[mpr7+5]
	ld mpr, Z		; Load p[mpr7+5] into mpr
	inc mpr			; Increment p[mpr7+5]
	st Z+, mpr		; Store the incremented p[mpr7+5] back into memory


SIX_MUL_1_R0_CC:		; Jump here as soon as the CF doesn't get set by the original add or conditional increments
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	call POINT_Z_MPR7
	st Z+, r0			; Store (p[mpr7] + r0) into p[mpr7]
	

	; NOW ADD r1 TO p[mpr7+1]

	; (p[mpr7+1]) <- (r1 + p[mpr7+1])

	; Load p[mpr7+1] into mpr. Then add it to r1
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	call POINT_Z_MPR7
	adiw ZH:ZL, 1

	ld mpr, Z+
	add r1, mpr 	; If p[mpr7+1] doesnt overflow, don't increment p[mpr7+2]
	brcc SIX_MUL_1_R1_CC

	; Else increment p[mpr7+2]
	; Z currently points to p[mpr7+2]
	ld mpr, Z		; Load p[mpr7+2] into mpr
	inc mpr			; Increment p[mpr7+2]
	st Z+, mpr		; Store the incremented p[mpr7+2] back into memory
	cpi mpr, 0		; If p[mpr7+2] doesn't overflow, don't increment p[mpr7+3]
	brne SIX_MUL_1_R1_CC

	; Else increment p[mpr7+3]
	; Z currently points to p[mpr7+3]
	ld mpr, Z		; Load p[mpr7+3] into mpr
	inc mpr			; Increment p[mpr7+3]
	st Z+, mpr		; Store the incremented p[mpr7+3] back into memory
	cpi mpr, 0		; If p[mpr7+3] doesn't overflow, don't increment p[mpr7+4]
	brne SIX_MUL_1_R1_CC

	; Else increment p[mpr7+4]
	; Z currently points to p[mpr7+4]
	ld mpr, Z		; Load p[mpr7+4] into mpr
	inc mpr			; Increment p[mpr7+4]
	st Z+, mpr		; Store the incremented p[mpr7+4] back into memory


SIX_MUL_1_R1_CC:		; Jump here as soon as the CF doesn't get set by the original add or conditional increments
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	call POINT_Z_MPR7
	adiw ZH:ZL, 1
	st Z+, r1			; Store (p[mpr7+1] + r1) into p[mpr7+1]

	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: FOUR_MUL_RAD
;	Desc: Multiply the first four bytes of Product by OrbitalRadius. Store result in Product($0E05:$0E0B).
;-----------------------------------------------------------
FOUR_MUL_RAD:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6
	push mpr7

	; Load the first 4 bytes of Product into mpr3:mpr2:mpr1:mpr
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	ld mpr, Z+
	ld mpr1, Z+
	ld mpr2, Z+
	ld mpr3, Z+
	nop		; On this line, mpr3:mpr2:mpr1:mpr contain Product($0E05:$0E0B)
			; Yup

	; Load OrbitalRadius into mpr5:mpr4
	ldi ZH, high(OrbitalRadius<<1)
	ldi ZL, low(OrbitalRadius<<1)
	lpm mpr4, Z+
	lpm mpr5, Z+
	nop		; On this line, mpr5:mpr4 contains OrbitalRadius

	; Clear the product to get it ready for a new value calculation
	ldi XH, high(Product)
	ldi XL, low(Product)
	call CLR_WORD7
	nop		; On this line, Product($0E05:$0E0B) should contain: 00 00 00 00 00 00 00
			; Yup

	; mpr,mpr4 + mpr,mpr5 + mpr1,mpr4 + mpr1,mpr5 + mpr2,mpr4 + mpr2,mpr5  + mpr3,mpr4 + mpr3,mpr5
	; 0640     + 019000   + 445C00    + 11170000  + 33900000  + 0CE4000000 + C8000000  + 3200000000

	; CASE 0.
	mul mpr, mpr4
	; Simply place product into Product. p0<-r0, p1<-r1
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	st Z+, r0
	st Z+, r1
	nop		; On this line, Product contains: 00 00 00 00 00 06 40

	; CASE 1. Left shift 1 byte
	ldi mpr7, 1
	mul mpr, mpr5
	call FOUR_MUL_RAD_STEPS
	nop		; On this line, Product contains: 00 00 00 00 01 96 40

	mul mpr1, mpr4
	call FOUR_MUL_RAD_STEPS
	nop		; On this line, Product contains: 00 00 00 00 45 F2 40

	; CASE 2. Left shift 2 bytes
	ldi mpr7, 2
	mul mpr1, mpr5
	call FOUR_MUL_RAD_STEPS
	nop		; On this line, Product contains: 00 00 00 11 5C F2 40

	mul mpr2, mpr4
	call FOUR_MUL_RAD_STEPS
	nop		; On this line, Product contains: 00 00 00 44 EC F2 40

	; CASE 3. Left shift 3 bytes
	ldi mpr7, 3
	mul mpr2, mpr5
	call FOUR_MUL_RAD_STEPS
	nop		; On this line, Product contains: 00 00 0D 28 EC F2 40

	mul mpr3, mpr4
	call FOUR_MUL_RAD_STEPS
	nop		; On this line, Product contains: 00 00 0D F0 EC F2 40

	; CASE 4. Left shift 4 bytes
	ldi mpr7, 4
	mul mpr3, mpr5
	call FOUR_MUL_RAD_STEPS
	nop		; On this line, Product contains: 00 00 3F F0 EC F2 40

			; WHAT IT NEEDS TO EQUAL: 		  00 00 3F F0 EC F2 40

	pop mpr7
	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: FOUR_MUL_RAD_STEPS
;	Desc: Add r1:r0 to Product, but left shifted by mpr7 bytes
;	Parameters: r1:r0, mpr7
;-----------------------------------------------------------
FOUR_MUL_RAD_STEPS:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6

	; Left shift pruduct by mpr7 bytes


	; Add r1:r0 to Product, but left shifted mpr7 times
	; (p[mpr7]) <- (r0 + p[mpr7])

	; Load p[mpr7] into mpr. Then add it to r0
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	call POINT_Z_MPR7
	ld mpr, Z+
	add r0, mpr
	brcc R0_CC		; If p[mpr7] doesnt overflow, don't increment p[mpr7+1]

	; Else increment p[mpr7+1]
	; Z currently points to p[mpr7+1]
	ld mpr, Z		; Load p[mpr7+1] into mpr
	inc mpr			; Increment p[mpr7+1]
	st Z+, mpr		; Store the incremented p[mpr7+1] back into memory
	cpi mpr, 0		; If p[mpr7+1] doesn't overflow, don't increment p[mpr7+2]
	brne R0_CC

	; Else increment p[mpr7+2]
	; Z currently points to p[mpr7+2]
	ld mpr, Z		; Load p[mpr7+2] into mpr
	inc mpr			; Increment p[mpr7+2]
	st Z+, mpr		; Store the incremented p[mpr7+2] back into memory
	cpi mpr, 0		; If p[mpr7+2] doesn't overflow, don't increment p[mpr7+3]
	brne R0_CC

	; Else increment p[mpr7+3]
	; Z currently points to p[mpr7+3]
	ld mpr, Z		; Load p[mpr7+3] into mpr
	inc mpr			; Increment p[mpr7+3]
	st Z+, mpr		; Store the incremented p[mpr7+3] back into memory
	cpi mpr, 0		; If p[mpr7+3] doesn't overflow, don't increment p[mpr7+4]
	brne R0_CC

	; Else increment p[mpr7+4]
	; Z currently points to p[mpr7+4]
	ld mpr, Z		; Load p[mpr7+4] into mpr
	inc mpr			; Increment p[mpr7+4]
	st Z+, mpr		; Store the incremented p[mpr7+4] back into memory


R0_CC:		; Jump here as soon as the CF doesn't get set by the original add or conditional increments
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	call POINT_Z_MPR7
	st Z+, r0			; Store (p[mpr7] + r0) into p[mpr7]


	; NOW ADD r1 TO p[mpr7+1]

	; (p[mpr7+1]) <- (r1 + p[mpr7+1])

	; Load p[mpr7+1] into mpr. Then add it to r1
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	call POINT_Z_MPR7
	adiw ZH:ZL, 1
	ld mpr, Z+
	add r1, mpr
	brcc R1_CC		; If p[mpr7+1] doesnt overflow, don't increment p[mpr7+2]

	; Else increment p[mpr7+2]
	; Z currently points to p[mpr7+2]
	ld mpr, Z		; Load p[mpr7+2] into mpr
	inc mpr			; Increment p[mpr7+2]
	st Z+, mpr		; Store the incremented p[mpr7+2] back into memory
	cpi mpr, 0		; If p[mpr7+2] doesn't overflow, don't increment p[mpr7+3]
	brne R1_CC

	; Else increment p[mpr7+3]
	; Z currently points to p[mpr7+3]
	ld mpr, Z		; Load p[mpr7+3] into mpr
	inc mpr			; Increment p[mpr7+3]
	st Z+, mpr		; Store the incremented p[mpr7+3] back into memory
	cpi mpr, 0		; If p[mpr7+3] doesn't overflow, don't increment p[mpr7+4]
	brne R1_CC

	; Else increment p[mpr7+4]
	; Z currently points to p[mpr7+4]
	ld mpr, Z		; Load p[mpr7+4] into mpr
	inc mpr			; Increment p[mpr7+4]
	st Z+, mpr		; Store the incremented p[mpr7+4] back into memory


R1_CC:		; Jump here as soon as the CF doesn't get set by the original add or conditional increments
	ldi ZH, high(Product)
	ldi ZL, low(Product)
	call POINT_Z_MPR7
	adiw ZH:ZL, 1
	st Z+, r1			; Store (p[mpr7+1] + r1) into p[mpr7+1]

	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: POINT_Z_MPR7
;	Desc: After this function runs, Z should be pointed at p[mpr7]
;	Parameters: mpr7
;-----------------------------------------------------------
POINT_Z_MPR7:
	push mpr1

	mov mpr1, mpr7
LOOP_Z_MPR7:
	cpi mpr1, 0
	breq LOOP_Z_MPR7_END

	adiw ZH:ZL, 1
	dec mpr1
	rjmp LOOP_Z_MPR7
LOOP_Z_MPR7_END:

	pop mpr1

	ret

;-----------------------------------------------------------
;	Func: MUL_16_POINT_Z_MPR7
;	Desc: After this function runs, Z should be pointed at fp[mpr7]
;	Parameters: mpr7
;-----------------------------------------------------------
MUL_16_POINT_Z_MPR7:
	push mpr1

	ldi ZH, high(Fproduct_Addr)
	ldi ZL, low(Fproduct_Addr)

	mov mpr1, mpr7
MUL_16_LOOP_Z_MPR7:
	cpi mpr1, 0
	breq MUL_16_LOOP_Z_MPR7_END

	adiw ZH:ZL, 1
	dec mpr1
	rjmp MUL_16_LOOP_Z_MPR7
MUL_16_LOOP_Z_MPR7_END:

	pop mpr1

	ret

;-----------------------------------------------------------
;	Func: SQUARE_ROOT
;	Desc: Find the square root of (GM/r)
;-----------------------------------------------------------
SQUARE_ROOT:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push r0
	push r1
	 
	; Load the quotient into mpr, mpr1, mpr2
	ldi ZH, high(Quotient)
	ldi ZL, low(Quotient)
	ld mpr, Z+
	ld mpr1, Z+
	ld mpr2, Z+
	nop

	; Clear the SQRT_LOOP_COUNTER (2 bytes)
	ldi ZH, high(Sqrt_Loop_Counter_Addr)
	ldi ZL, low(Sqrt_Loop_Counter_Addr)
	ldi mpr6, 0
	st Z+, mpr6
	st Z+, mpr6
	nop

SQRT_LOOP_TOP:
	; Load the loop counter into mpr3 and mpr4
	ldi ZH, high(Sqrt_Loop_Counter_Addr)
	ldi ZL, low(Sqrt_Loop_Counter_Addr)
	ld mpr3, Z+
	ld mpr4, Z+
	nop

	; Store the loop counter into the word1($0E1C:$0E1D) and word2($0E1F:$0E20) data spaces, preparing for MUL_16
	ldi ZH, high(Word1_Addr)
	ldi ZL, low(Word1_Addr)
	st Z+, mpr3
	st Z+, mpr4
	nop

	ldi ZH, high(Word2_Addr)
	ldi ZL, low(Word2_Addr)
	st Z+, mpr3
	st Z+, mpr4
	nop

	; Calculate SQRT_LOOP_COUNTER^2 = product
	call MUL_16
	nop		; On this line, Fproduct_Addr($0E19:0E1C) now has the correct squared value!!

	; Check if the quotient is lower than the product
	ldi ZH, high(Quotient)
	ldi ZL, low(Quotient)
	ld mpr, Z+
	ld mpr1, Z+
	ld mpr2, Z+

	; Call a function that compares the Quotient to Fproduct_Addr
	; If Q>P, mpr6==0, increment the loopCounter and continue
	; If Q<P, mpr6==1, exit the loop and use the PREVIOUS loopCounter for sqrt
	; If Q==P, mpr6==2, exit the loop and use the CURRENT loopCounter for sqrt
	call THREE_BYTE_CP_LT
	nop

	; On this line, mpr6 should have a zero, one, or two
	; If mpr6==2, jump to loop end without incrementing SQRT_LOOP_COUNTER. We already have our sqrt
	cpi mpr6, 2
	breq SQRT_LOOP_END

	; If mpr6==0, which means we are under the quotient,
	; so lets increment the loopCounter and restart the loop
	cpi mpr6, 1
	brne mpr6_EQ_1_N

	; Else mpr6 must be equal to one, which means we went over the quotient,
	; so we need to use the previous SQRT_LOOP_COUNTER value as our sqrt.
	; Dec SQRT_LOOP_COUNTER and then jump to end of loop
	ldi ZH, high(Sqrt_Loop_Counter_Addr)
	ldi ZL, low(Sqrt_Loop_Counter_Addr)
	ldi YH, high(Dec_Three_Byte_Addr)
	ldi YL, low(Dec_Three_Byte_Addr)
	ldi mpr1, 0
GET_SQRT_LOOP_COUNTER_ADDR_LOOP:
	ld mpr, Z+
	st Y+, mpr
	inc mpr1
	cpi mpr1, 3
	brne GET_SQRT_LOOP_COUNTER_ADDR_LOOP

	call DEC_THREE_BYTE
	; Now store the result back into Sqrt_Loop_Counter
	ldi ZH, high(Dec_Three_Byte_Addr)
	ldi ZL, low(Dec_Three_Byte_Addr)
	ldi YH, high(Sqrt_Loop_Counter_Addr)
	ldi YL, low(Sqrt_Loop_Counter_Addr)
	ld mpr, Z+
	ld mpr1, Z+
	st Y+, mpr
	st Y+, mpr1

	rjmp SQRT_LOOP_END		; SQRT_LOOP_COUNTER now has the correct sqrt of the quotient. Jump to the exit

mpr6_EQ_1_N:
	; Else mpr6 must equal one, which means the product is still less than the quotient
	; We will increment the counter and restart the loop to try again

	; Check if the current loop counter is == $0FFF
	; If so, $0FFF must be the square root even if its product wasn't equal to the quotient, so branch to the end of the function.
	ldi ZH, high(Sqrt_Loop_Counter_Addr)
	ldi ZL, low(Sqrt_Loop_Counter_Addr)
	ld mpr, Z+		; Loading low byte of counter into mpr
	cpi mpr, $FF
	brne SKIP_TO_RESTART

	; Else, also check if the high byte is $0F
	ld mpr, Z+		; Loading high byte of counter into mpr
	cpi mpr, $0F
	breq SQRT_LOOP_END	; If the latest loop we completed was testing if $0FFF is the sqrt of the quotient,
						; then we can assume that $0FFF is the sqrt.
	; Else just increment the counter and restart the loop
SKIP_TO_RESTART:
	; Else if mpr6==0, continue on to increment the SQRT_LOOP_COUNTER and restart loop
	call INC_SQRT_LOOP_COUNTER
	rjmp SQRT_LOOP_TOP


SQRT_LOOP_END:
	pop r1
	pop r0
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr
	
	ret

;-----------------------------------------------------------
;	Func: DEC_THREE_BYTE
;	Desc: Decrement the Dec_Three_Byte_Addr
;-----------------------------------------------------------
DEC_THREE_BYTE:
	push mpr
	push mpr1
	push mpr2

	; Load mpr2:mpr1:mpr with Dec_Three_Byte_Addr
	ldi ZH, high(Dec_Three_Byte_Addr)
	ldi ZL, low(Dec_Three_Byte_Addr)
	ld mpr, Z+
	ld mpr1, Z+
	ld mpr2, Z+

	dec mpr
	; If mpr doesn't require a carry, end the function
	cpi mpr, $FF
	brne DEC_THREE_BYTE_END
	; Else dec mpr1
	dec mpr1

	; If mpr1 doesn't require a carry, end the function
	cpi mpr1, $FF
	brne DEC_THREE_BYTE_END
	; Else dec mpr2
	dec mpr2

DEC_THREE_BYTE_END:
	ldi ZH, high(Dec_Three_Byte_Addr)
	ldi ZL, low(Dec_Three_Byte_Addr)
	st Z+, mpr
	st Z+, mpr1
	st Z+, mpr2

	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: THREE_BYTE_CP_LT
;	Desc: Call a function that compares if a 3 byte value in mpr2:mpr1:mpr is 
;		  less than the three byte value at Fproduct_Addr in data memory
;-----------------------------------------------------------
THREE_BYTE_CP_LT:
	; The value passed in is in mpr2:mpr1:mpr
	push mpr3
	push mpr4
	push mpr5

	; Load the product into mpr5:mpr4:mpr3
	; f2==mpr5, f1==mpr4, f0==mpr3
	ldi ZH, high(Fproduct_Addr)
	ldi ZL, low(Fproduct_Addr)
	ld mpr3, Z+
	ld mpr4, Z+
	ld mpr5, Z+

	; AT THIS POINT,
	; The Sqrt_Loop_Counter_Addr has the correct loopCounter
	; Fproduct_Addr has the correct product
	; Word1_Addr has the correct word
	; Word2_Addr has the correct word

	; If (mpr2 == f2), then branch to the next conditions.
	cp mpr2, mpr5
	breq BRNCH_CP_MPR1
	; Else if (mpr2 < f2), then the quotient is definitely smaller than the product.
	; Set mpr6 flag to 1 so we know to jump out of sqrtLoop and use current LoopCounter for sqrt.
	; Leave function
	cp mpr2, mpr5
	brlo LEAVE_ONE
	; Else mpr2 must be greater than f2, so the quotient is definitely bigger than the product.
	; Set mpr6 flag to 0 so we know to continue the sqrtLoop.
	rjmp LEAVE_ZERO

BRNCH_CP_MPR1:
	; If (mpr1 == f1), then branch to the next conditions.
	cp mpr1, mpr4
	breq BRNCH_CP_MPR
	; Else if (mpr1 < f1), then the quotient is definitely smaller than the product.
	; Set mpr6 flag to 1 so we know to jump out of sqrtLoop and use the previous LoopCounter for sqrt.
	; Leave function
	cp mpr1, mpr4
	brlo LEAVE_ONE
	; Else mpr1 must be greater than f1, so the quotient is definitely bigger than the product.
	; Set mpr6 flag to 0 so we know to continue the sqrtLoop.
	rjmp LEAVE_ZERO
	
BRNCH_CP_MPR:
	; If (mpr == f0), then the product must be equal to the quotient.
	; The sqrt of the quotient is the current LoopCounter
	; Set the mpr6 flag to 2 so that the sqrtLoop will exit with the current LoopCounter value
	cp mpr, mpr3
	breq LEAVE_TWO
	; If (f0 < mpr), then the quotient is definitely greater than the product.
	; Set mpr6 flag to 0 so we know to continue the sqrtLoop.
	; Leave function
	cp mpr3, mpr
	brlo LEAVE_ZERO
	; Else mpr must be less than f0, so the quotient is less than the product
	; Set mpr6 flag to 1 so we know to jump out of sqrtLoop and use the previous LoopCounter for sqrt.
	rjmp LEAVE_ONE

LEAVE_TWO:
	ldi mpr6, 2
	rjmp THREE_BYTE_CP_LT_END
LEAVE_ONE:
	ldi mpr6, 1
	rjmp THREE_BYTE_CP_LT_END

LEAVE_ZERO:
	ldi mpr6, 0

THREE_BYTE_CP_LT_END:
	pop mpr5
	pop mpr4
	pop mpr3

	ret

;-----------------------------------------------------------
;	Func: MUL_16
;	Desc: Multiply Word1($0E1D:$0E1E) by Word2($0E1F:$0E20) and stores the result in Fproduct($0E19:$0E1C)
;-----------------------------------------------------------
MUL_16:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6
	push mpr7

	; Clear Fproduct($0E19:$0E1C)
	ldi mpr7, 0
	ldi ZH, high(Fproduct_Addr)
	ldi ZL, low(Fproduct_Addr)
	st Z+, mpr7
	st Z+, mpr7
	st Z+, mpr7
	st Z+, mpr7

	; Load Word1 into mpr:mpr1 and Word2 into mpr2:mpr3
	ldi ZH, high(Word1_Addr)
	ldi ZL, low(Word1_Addr)
	ld mpr, Z+
	ld mpr1, Z+
	nop		; On this line, mpr:mpr1 contains Word1($0E1D:$0E1E)

	ldi ZH, high(Word2_Addr)
	ldi ZL, low(Word2_Addr)
	ld mpr2, Z+
	ld mpr3, Z+
	nop		; On this line, mpr2:mpr3 contains Word2($0E1F:$0E20)

	; (mpr,mpr2) + (mpr1,mpr2)0 + (mpr,mpr3)0 + (mpr1,mpr3)00

	; CASE 0.
	mul mpr, mpr2	; 
	; Simply place product into Fproduct. fp0<-r0, fp1<-r1
	ldi ZH, high(Fproduct_Addr)
	ldi ZL, low(Fproduct_Addr)
	st Z+, r0
	st Z+, r1
	nop		; On this line, Fproduct contains: 00 00 27 10

	; CASE 1. Left shift 1 byte
	ldi mpr7, 1
	mul mpr1, mpr2
	call MUL_16_STEPS
	nop		; On this line, Fproduct contains: 00 09 EB 10

	mul mpr, mpr3	; (64*19)0
	call MUL_16_STEPS
	nop		; On this line, Fproduct contains: 00 13 AF 10
			; (64*19)0	+ 00 09 EB 10

	; CASE 2. Left shift 2 bytes
	ldi mpr7, 2
	mul mpr1, mpr3		; (19*19)00 + 00 13 AF 10
	call MUL_16_STEPS
	nop		; On this line, Fproduct contains: 02 84 AF 10

	pop mpr7
	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: MUL_16_STEPS
;	Desc: Do MUL_16 addition steps
;	Parameters: r1:r0, mpr7, Fproduct($0E19:$0E1C)
;-----------------------------------------------------------
MUL_16_STEPS:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6

	; Left shift pruduct by mpr7 bytes

	; Add r1:r0 to Fproduct, but left shifted mpr7 times
	; (p[mpr7]) <- (r0 + p[mpr7])

	; Load fp[mpr7] into mpr. Then add it to r0
	call MUL_16_POINT_Z_MPR7
	nop		; On this line, Z should point at fp[mpr7}
	ld mpr, Z+
	add r0, mpr
	brcc MUL_16_R0_CC		; If p[mpr7] doesnt overflow, don't increment p[mpr7+1]

	; Else increment p[mpr7+1]
	; Z currently points to p[mpr7+1]
	ld mpr, Z		; Load p[mpr7+1] into mpr
	inc mpr			; Increment p[mpr7+1]
	st Z+, mpr		; Store the incremented p[mpr7+1] back into memory
	cpi mpr, 0		; If p[mpr7+1] doesn't overflow, don't increment p[mpr7+2]
	brne MUL_16_R0_CC

	; Else increment p[mpr7+2]
	; Z currently points to p[mpr7+2]
	ld mpr, Z		; Load p[mpr7+2] into mpr
	inc mpr			; Increment p[mpr7+2]
	st Z+, mpr		; Store the incremented p[mpr7+2] back into memory



MUL_16_R0_CC:		; Jump here as soon as the CF doesn't get set by the original add or conditional increments
	call MUL_16_POINT_Z_MPR7
	st Z+, r0			; Store (p[mpr7] + r0) into p[mpr7]
	

	; NOW ADD r1 TO p[mpr7+1]

	; (p[mpr7+1]) <- (r1 + p[mpr7+1])

	; Load p[mpr7+1] into mpr. Then add it to r1
	call MUL_16_POINT_Z_MPR7
	adiw ZH:ZL, 1
	ld mpr, Z+
	add r1, mpr
	brcc MUL_16_R1_CC		; If p[mpr7+1] doesnt overflow, don't increment p[mpr7+2]

	; Else increment p[mpr7+2]
	; Z currently points to p[mpr7+2]
	ld mpr, Z		; Load p[mpr7+2] into mpr
	inc mpr			; Increment p[mpr7+2]
	st Z+, mpr		; Store the incremented p[mpr7+2] back into memory

MUL_16_R1_CC:		; Jump here as soon as the CF doesn't get set by the original add or conditional increments
	call MUL_16_POINT_Z_MPR7
	adiw ZH:ZL, 1
	st Z+, r1			; Store (p[mpr7+1] + r1) into p[mpr7+1]

	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: INC_SQRT_LOOP_COUNTER
;	Desc: Increment the number that we want to square in order to check if it's the right square root
;-----------------------------------------------------------
INC_SQRT_LOOP_COUNTER:
	push mpr
	push mpr1

	; Load the counter from memory
	ldi ZH, high(Sqrt_Loop_Counter_Addr)
	ldi ZL, low(Sqrt_Loop_Counter_Addr)
	ld mpr, Z+
	ld mpr1, Z+

	; Increment mpr. If mpr overflows, also increment mpr1
	inc mpr
	brne INC_SQRT_LOOP_COUNTER_END
	inc mpr1

INC_SQRT_LOOP_COUNTER_END:
	ldi ZH, high(Sqrt_Loop_Counter_Addr)
	ldi ZL, low(Sqrt_Loop_Counter_Addr)
	st Z+, mpr
	st Z+, mpr1

	pop mpr1
	pop mpr
	ret

;-----------------------------------------------------------
;	Func: ROUND_QUOTIENT
;	Desc: Round the quotient based on the remainder
;-----------------------------------------------------------
ROUND_QUOTIENT:
	; Load radius into mpr and mpr1
	ldi ZH, high(OrbitalRadius<<1)
	ldi ZL, low(OrbitalRadius<<1)
	lpm mpr, Z+
	lpm mpr1, Z+
	
	; Load remainder into mpr2, mpr3, and mpr4
	ldi ZH, high(Remainder_Addr)
	ldi ZL, low(Remainder_Addr)
	ld mpr2, Z+
	ld mpr3, Z+
	ld mpr4, Z+

	; Divide radius by two
	lsr mpr1
	lsr mpr

	; If half the radius is less than the remainder, round the number up

	; If mpr4 is not zero, round up and finish
	cpi mpr4, 0
	brne ROUND_UP
	; Else go on to compare mpr1 to mpr3 and mpr to mpr2 respectively

	; If mpr3 is less than mpr1, Do not round up
	cp mpr3, mpr1
	brlo ROUND_QUOTIENT_END

	; If mpr is less than mpr2, jump to the end. Do not round up
	cp mpr, mpr2
	brlo ROUND_QUOTIENT_END

	; If none of the above conditions pass,
	; then the remainder must be greater than or equal to half the radius, so round up
ROUND_UP:
	call INC_QUOTIENT

ROUND_QUOTIENT_END:
	ret

;-----------------------------------------------------------
;	Func: INC_QUOTIENT7
;	Desc: Increment Quotient7
;-----------------------------------------------------------
INC_QUOTIENT7:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6

	; Get address of quotient into Z
	ldi ZH, high(Quotient7_Addr)
	ldi ZL, low(Quotient7_Addr)

	ld mpr, Z+		; Get the seven quotient bytes in order
	ld mpr1, Z+
	ld mpr2, Z+
	ld mpr3, Z+
	ld mpr4, Z+
	ld mpr5, Z+
	ld mpr6, Z+

	inc mpr
	brne INC_QUOTIENT7_END		; if mpr does not reset, jump to end

	; Else increment mpr1 as well
	inc mpr1
	brne INC_QUOTIENT7_END		; If mpr1 does not reset, jump to end

	; Else increment mpr2 as well
	inc mpr2
	brne INC_QUOTIENT7_END

	; Else increment mpr3 as well
	inc mpr3
	brne INC_QUOTIENT7_END	

	; Else increment mpr4 as well
	inc mpr4
	brne INC_QUOTIENT7_END	

	; Else increment mpr5 as well
	inc mpr5
	brne INC_QUOTIENT7_END	

	; Else increment mpr6 as well
	inc mpr6

INC_QUOTIENT7_END:
	ldi ZH, high(Quotient7_Addr)		; Store the incremented quotient back into memory
	ldi ZL, low(Quotient7_Addr)
	st Z+, mpr
	st Z+, mpr1
	st Z+, mpr2
	st Z+, mpr3
	st Z+, mpr4
	st Z+, mpr5
	st Z+, mpr6

	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: DEC_QUOTIENT7
;	Desc: Decrement Quotient7
;-----------------------------------------------------------
DEC_QUOTIENT7:
	push mpr
	push mpr1
	push mpr2
	push mpr3
	push mpr4
	push mpr5
	push mpr6

	; Get address of Quotient7 into Z
	ldi ZH, high(Quotient7_Addr)
	ldi ZL, low(Quotient7_Addr)

	ld mpr, Z+		; Get the seven quotient bytes in order
	ld mpr1, Z+
	ld mpr2, Z+
	ld mpr3, Z+
	ld mpr4, Z+
	ld mpr5, Z+
	ld mpr6, Z+

	dec mpr
	cpi mpr, $FF
	brne INC_QUOTIENT7_END		; if mpr does not reset, jump to end

	; Else decrement mpr1 as well
	dec mpr1
	cpi mpr1, $FF
	brne DEC_QUOTIENT7_END		; If mpr1 does not reset, jump to end

	; Else decrement mpr2 as well
	dec mpr2
	cpi mpr2, $FF
	brne DEC_QUOTIENT7_END

	; Else decrement mpr3 as well
	dec mpr3
	cpi mpr3, $FF
	brne DEC_QUOTIENT7_END	

	; Else decrement mpr4 as well
	dec mpr4
	cpi mpr4, $FF
	brne DEC_QUOTIENT7_END	

	; Else decrement mpr5 as well
	dec mpr5
	cpi mpr5, $FF
	brne DEC_QUOTIENT7_END	

	; Else deccrement mpr6 as well
	dec mpr6

DEC_QUOTIENT7_END:
	ldi ZH, high(Quotient7_Addr)		; Store the incremented quotient back into memory
	ldi ZL, low(Quotient7_Addr)
	st Z+, mpr
	st Z+, mpr1
	st Z+, mpr2
	st Z+, mpr3
	st Z+, mpr4
	st Z+, mpr5
	st Z+, mpr6

	pop mpr6
	pop mpr5
	pop mpr4
	pop mpr3
	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: INC_QUOTIENT
;	Desc: Increment the quotient for each time the DIV_LOOP runs
;-----------------------------------------------------------
INC_QUOTIENT:
	push mpr
	push mpr1
	push mpr2

	; Get address of quotient into Z
	ldi ZH, high(Quotient)
	ldi ZL, low(Quotient)

	ld mpr, Z+		; Get the three quotient bytes in order
	ld mpr1, Z+
	ld mpr2, Z+

	inc mpr
	brne INC_QUOTIENT_END		; if mpr does not reset, jump to end

	; Else increment mpr1 as well
	inc mpr1
	brne INC_QUOTIENT_END		; If mpr1 does not reset, jump to end

	; Else increment mpr2 as well
	inc mpr2

INC_QUOTIENT_END:
	ldi ZH, high(Quotient)		; Store the incremented quotient back into memory
	ldi ZL, low(Quotient)
	st Z+, mpr
	st Z+, mpr1
	st Z+, mpr2

	pop mpr2
	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: FP_ST_P
;	Desc: Copy contents of Fproduct into Product
;-----------------------------------------------------------
FP_ST_P:
	push mpr

	ldi ZH, high(Fproduct_Addr)
	ldi ZL, low(Fproduct_Addr)
	ldi YH, high(Product)
	ldi YL, low(Product)
	ld mpr, Z+
	st Y+, mpr
	ld mpr, Z+
	st Y+, mpr
	ld mpr, Z+
	st Y+, mpr
	ld mpr, Z+
	st Y+, mpr

	pop mpr

	ret

;-----------------------------------------------------------
;	Func: CLR_WORD7
;	Desc: Clear 7 bytes given an address in X
;-----------------------------------------------------------
CLR_WORD7:
	push mpr
	push mpr1

	ldi mpr, 0
	ldi mpr1, 7
CLR_WORD7_LOOP:
	st X+, mpr
	dec mpr1
	brne CLR_WORD7_LOOP

	pop mpr1
	pop mpr
	ret

;-----------------------------------------------------------
;	Func: LOAD_PRODUCT_Word7
;	Desc: Load Product($0E05:$0E0B) into Word7
;-----------------------------------------------------------
LOAD_PRODUCT_Word7:
	push mpr
	push mpr1

	ldi ZH, high(Product)
	ldi ZL, low(Product)
	ldi YH, high(Word7_Addr)
	ldi YL, low(Word7_Addr)
	ldi mpr, 0
	ldi mpr1, 7

LOAD_PRODUCT_Word7_LOOP:
	ld mpr, Z+
	st Y+, mpr
	dec mpr1
	brne LOAD_PRODUCT_Word7_LOOP

	nop		; On this line, Word7($0E2C:$0E32) should have the contents of Product($0E05:$0E0B)

	pop mpr1
	pop mpr

	ret

;-----------------------------------------------------------
;	Func: LOAD_GM_Word4
;	Desc: Load the selected GM value into Word4_Addr($0E33:$0E39)
;-----------------------------------------------------------
LOAD_GM_Word4:
	push mpr

	; Putting the index of the planet to select into mpr
	ldi ZH, high(SelectedPlanet<<1)
	ldi ZL, low(SelectedPlanet<<1)		; We only need the low byte because the second byte is just for padding
	lpm mpr, Z+
	; mpr now has the index of the planet we want

	ldi ZH, high(PlanetInfo<<1)
	ldi ZL, low(PlanetInfo<<1)
	; Z is now pointing to the beginning of the GM array in program memory


LOAD_GM_ARRAY_LOOP:					; Get the correct index for the address
	cpi mpr, 0
	breq LOAD_GM_ARRAY_LOOP_END
	dec mpr
	adiw ZH:ZL, 4
	rjmp LOAD_GM_ARRAY_LOOP

LOAD_GM_ARRAY_LOOP_END:
	nop		; On this line, Z is pointing at the correct GM

	ldi YH, high(Word4_Addr)
	ldi YL, low(Word4_Addr)

	; Load all 4 bytes from the GM into Word4_Addr($0E33:$0E39)
	lpm mpr, Z+
	st Y+, mpr
	lpm mpr, Z+
	st Y+, mpr
	lpm mpr, Z+
	st Y+, mpr
	lpm mpr, Z+
	st Y+, mpr

	nop		; On this line, Word4_Addr($0E33:$0E39) contains the correct GM

	pop mpr
	
	ret

;-----------------------------------------------------------
;	Func: GET_GM
;	Desc: Get GM address into Y, Load GM into mpr..mpr3, Store GM into dataspace at GMAddr
;-----------------------------------------------------------
GET_GM:
	; Putting the index of the planet to select into oloop
	ldi ZH, high(SelectedPlanet<<1)
	ldi ZL, low(SelectedPlanet<<1)		; We only need the low byte because the second byte is just for padding
	lpm mpr, Z+
	nop

	; TESTING LINE ==================================================================================================
	;ldi mpr, 2
	nop
	; TESTING LINE ==================================================================================================

	; Get the GM value of the selected planet from the array into Z
	; It is 4 bytes long
	ldi ZH, high(PlanetInfo<<1)
	ldi ZL, low(PlanetInfo<<1)

ARRAY_LOOP:					; Get the correct index for the address
	cpi mpr, 0
	breq GET_GM_END
	adiw ZH:ZL, 4
	dec mpr
	rjmp ARRAY_LOOP

GET_GM_END:
	; Z now has the address of the selected planet's GM
	lpm mpr, Z+
	lpm mpr1, Z+
	lpm mpr2, Z+
	lpm mpr3, Z+
	
	ret

;-----------------------------------------------------------
;	Func: SQUARE_IN_ORDER
;	Desc: Square root numbers in order starting from 0
;-----------------------------------------------------------
SQUARE_IN_ORDER:
	push mpr
	push mpr1

	ldi mpr, 0
	ldi mpr1, 0

SQUARE_IN_ORDER_LOOP_TOP:
	; Store mpr1:mpr into Word1_Addr
	ldi ZH, high(Word1_Addr)
	ldi ZL, low(Word1_Addr)
	st Z+, mpr
	st Z+, mpr1

	; Store mpr1:mpr into Word2_Addr
	ldi ZH, high(Word2_Addr)
	ldi ZL, low(Word2_Addr)
	st Z+, mpr
	st Z+, mpr1
	
	call MUL_16
	nop				; On this line, Fproduct($0E19:$0E1C) should have the correct square

	inc mpr
	brne SQUARE_IN_ORDER_LOOP_INC_MPR1_N

	inc mpr1
	breq SQUARE_IN_ORDER_LOOP_END

SQUARE_IN_ORDER_LOOP_INC_MPR1_N:
	rjmp SQUARE_IN_ORDER_LOOP_TOP

SQUARE_IN_ORDER_LOOP_END:
	pop mpr1
	pop mpr

	ret

;***********************************************************
;*	Custom stored data
;*	(feel free to edit these or add others)
;***********************************************************
SomeConstant:	.DB	0x86, 0xA4



;***end of your code***end of your code***end of your code***end of your code***end of your code***
;*************************** Do not change anything below this point*******************************
;*************************** Do not change anything below this point*******************************
;*************************** Do not change anything below this point*******************************

Grading:
		nop					; Check the results in data memory begining at address $0E00 (The TA will set a breakpoint here)
rjmp Grading


;***********************************************************
;*	Stored program data that you cannot change
;***********************************************************

; Contents of program memory will be changed during testing
; The label names (OrbitalRadius, SelectedPlanet, PlanetInfo, MercuryGM, etc) are not changed
; NOTE: All values are provided using the little-endian convention.
OrbitalRadius:	.DB	0x64, 0x19				; the radius that should be used during computations (in kilometers)
											; in this example, the value is 6,500 kilometers
											; the radius will be provided as a 16 bit unsigned value (unless you are
											; completing the extra credit, in which case the radius is an unsigned 24 bit value)

SelectedPlanet:	.DB	0x02, 0x00				; This is how your program knows which GM value should be used.
											; SelectedPlanet is an unsigned 8 bit value that provides you with the
											; index of the planet (and hence, tells you which GM value to use).
											; Note: only the first byte is used. The second byte is just for padding.
											; In this example, the value is 2. If we check the planet at index 2, (from the data below)
											; that corresponds to Earth.
											; if the value was 7, that would correspond to the planet Neptune

PlanetInfo:									; Note that these values will be changed during testing!
MercuryGM:		.DB	0x0E, 0x56, 0x00, 0x00	; Gravitational parameters will be provided as unsigned 32 bit integers (little-endian)
VenusGM:		.DB	0x24, 0xF5, 0x04, 0x00	; the units are in: (km * km * km)/(sec * sec)
EarthGM:		.DB	0x08, 0x15, 0x06, 0x00	; <-- note that this is 398,600
MarsGM:			.DB	0x4E, 0xA7, 0x00, 0x00
JupiterGM:		.DB	0x30, 0x13, 0x8D, 0x07	; A word of advice... treat these like an array, where each element
SaturnGM:		.DB	0xF8, 0xC7, 0x42, 0x02	; occupies 4 bytes of memory.
UranusGM:		.DB	0xD0, 0x68, 0x58, 0x00	; Mercury is at index 0, Venus is at index 1, ...and the final planet is at index 8.
NeptuneGM:		.DB	0x38, 0x4B, 0x68, 0x00
FinalGM:		.DB	0xFF, 0xFF, 0xFF, 0xFF


;***********************************************************
;*	Data Memory Allocation for Results
;*	Your answers need to be stored into these locations (using little-endian representation)
;*	These exact variable names will be used when testing your code!
;***********************************************************
.dseg
.org	$0E00						; data memory allocation for results - Your grader only checks $0E00 - $0E14
Quotient:		.byte 3				; This is the intermediate value that is generated while you are computing the satellite's velocity.
									; It is a 24 bit unsigned value.
Velocity:		.byte 2				; This is where you will store the computed velocity. It is a 16 bit signed number.
									; The velocity value is normally positive, but it can also be -1 or -2 in case of error
									; (see "Special Cases" in the assignment documentation).
Product:		.byte 7				; This is the intermediate product that is generated while you are computing the orbital period.
Period:			.byte 3				; This is where the orbital period of the satellite will be placed.
									; It is a 24 bit signed value.
									; The period value is normally positive, but it can also be -1 or -2 in case of error
									; (see "Special Cases" in the assignment documentation).

;***********************************************************
;*	Additional Program Includes
;***********************************************************
; There are no additional file includes for this program
