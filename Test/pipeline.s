
/ This file is used to test the oepration of the PKI "CPU" instruction set.
/ Author: Bill Mahoney
	
// start:

/ First, test the flags based on add/subtract. In the case of the simulator
/ for the PKI machine, they go through the same code, so testing some with
/ add and some with sub is acceptable. (Sub is just a 2's compliment add.)

test_1:		lsc	r2,1		/ Test 1 - set Z flag and jump if set
		lsc	r3,5
		lsc	r4,5
		sub	r5,r3,r4
		jump	z,test_2
		add	r0,r0,r0        / NOP
		jump	error

test_2:		lsc	r2,2		/ Test 2 - un-set Z flag and jump if not set
		lsc	r3,5
		lsc	r4,4
		sub	r5,r3,r4
		jump	nz,test_3
		add	r0,r0,r0        / NOP
		jump	error

test_3:		lsc	r2,3		/ Test 3 - set C flag and jump if set
		lsc	r3,-1		/ (makes 0xffffffff in R3)
		lsc	r4,1
		add	r5,r3,r4
		jump	c,test_4
		add	r0,r0,r0        / NOP
		jump	error

test_4:		lsc	r2,4		/ Test 4 - un-set C flag and jump if not set
		lsc	r3,-2		/ (makes 0xfffffffe in R3)
		lsc	r4,1
		add	r5,r3,r4
		jump	c,error

test_5:		lsc	r2,5		/ Test 5 - set N on a negative number
		add	r3,r0,r0
		lsc	r4,1
		sub	r5,r3,r4
		jump	n,test_6
		add	r0,r0,r0        / NOP
		jump	error

test_6:		lsc	r2,6		/ Test 6 - un-set N on a positive number
		lsc	r3,-1
		lsc	r4,1
		add	r5,r3,r4
		jump	n,error

test_7:		lsc	r2,7		/ Test 7 - set the overflow flag
		load	r3,seven_f
		lsc	r4,1
		add	r5,r3,r4
		jump	ov,test_8
		add	r0,r0,r0        / NOP
		jump	error	

test_8:		lsc	r2,8		/ Test 8 - set the overflow flag a different way
		load	r3,eighty
		lsc	r4,-1
		add	r5,r3,r4
		jump	ov,test_9
		add	r0,r0,r0        / NOP
		jump	error

test_9:		lsc	r2,9		/ Test 9 - un-set overflow flag
		load	r3,seven_f
		lsc	r4,1
		sub	r5,r3,r4
		jump	ov,error

test_10:	lsc	r2,10		/ Test 10 - un-set overflow flag
		load	r3,eighty
		lsc	r4,1
		add	r5,r3,r4
		jump	ov,error

test_11:	lsc	r2,11		/ Test SLT
		lsc	r3,5
		lsc	r4,6
		sub	r5,r3,r4
		jump	slt,test_12
		add	r0,r0,r0        / NOP
		jump	error

test_12:	lsc	r2,12		/ Test SLT
		lsc	r3,-5
		lsc	r4,6
		sub	r5,r3,r4
		jump	slt,test_13
		add	r0,r0,r0        / NOP
		jump	error

test_13:	lsc	r2,13		/ Test SLT
		lsc	r3,-5
		lsc	r4,-4
		sub	r5,r3,r4
		jump	slt,test_14
		add	r0,r0,r0        / NOP
		jump	error

test_14:	lsc	r2,14		/ Test SLT
		lsc	r3,3
		lsc	r4,3
		sub	r5,r3,r4
		jump	slt,error

test_15:	lsc	r2,15		/ Test SLE
		lsc	r3,5
		lsc	r4,6
		sub	r5,r3,r4
		jump	sle,test_16
		add	r0,r0,r0        / NOP
		jump	error

test_16:	lsc	r2,16		/ Test SLE
		lsc	r3,-5
		lsc	r4,6
		sub	r5,r3,r4
		jump	sle,test_17
		add	r0,r0,r0        / NOP
		jump	error

test_17:	lsc	r2,17		/ Test SLE
		lsc	r3,-5
		lsc	r4,-4
		sub	r5,r3,r4
		jump	sle,test_18
		add	r0,r0,r0        / NOP
		jump	error

test_18:	lsc	r2,18		/ Test SLE
		lsc	r3,3
		lsc	r4,3
		sub	r5,r3,r4
		jump	sle,test_19

test_19:	lsc	r2,19		/ Test ULE
		lsc	r3,4
		lsc	r4,5
		sub	r5,r3,r4
		jump	ule,test_20
		add	r0,r0,r0        / NOP
		jump	error

test_20:	lsc	r2,20		/ Test ULE
		lsc	r3,6
		lsc	r4,5
		sub	r5,r3,r4
		jump	ule,error

test_21:	lsc	r2,21		/ Test ULE
		lsc	r3,5
		lsc	r4,5
		sub	r5,r3,r4
		jump	ule,test_22
		add	r0,r0,r0        / NOP
		jump	error

test_22:	lsc	r2,22		/ Test ULE
		load	r3,seven_f
		load	r4,eighty
		sub	r5,r3,r4
		jump	ule,test_23
		add	r0,r0,r0        / NOP
		jump	error

test_23:	lsc	r2,23		/ Test ULE
		load	r3,eighty
		load	r4,seven_f
		sub	r5,r3,r4
		jump	ule,error

test_24:	lsc	r2,24		/ Test ULT
		lsc	r3,4
		lsc	r4,5
		sub	r5,r3,r4
		jump	ult,test_25
		add	r0,r0,r0        / NOP
		jump	error

test_25:	lsc	r2,25		/ Test ULT
		lsc	r3,6
		lsc	r4,5
		sub	r5,r3,r4
		jump	ult,error

test_26:	lsc	r2,26		/ Test ULT
		lsc	r3,5
		lsc	r4,5
		sub	r5,r3,r4
		jump	ULT,error

test_27:	lsc	r2,27		/ Test ULT
		load	r3,seven_f
		load	r4,eighty
		sub	r5,r3,r4
		jump	ult,test_28
		add	r0,r0,r0        / NOP
		jump	error

test_28:	lsc	r2,28		/ test ULT
		load	r3,eighty
		load	r4,seven_f
		sub	r5,r3,r4
		jump	ult,error

/ -------------------------------------------------------------------
/ Test the same thing but with multiply and divide. This is a tad easier
/ because these instructions always reset carry and overflow, FYI.
/ -------------------------------------------------------------------

test_29:	lsc	r2,29		/ Test Z with multiply
		lsc	r3,5
		lsc	r4,0
		mul	r5,r3,r4
		jump	nz,error
test_30:	lsc	r2,30		/ Un-set Z flag and jump if set
		lsc	r3,5
		lsc	r4,4
		mul	r5,r3,r4
		jump	z,error

test_31:	lsc	r2,31		/ Set Z via a divide (5/6) and jump if not set
		lsc	r3,5
		lsc	r4,6
		div	r5,r3,r4
		jump	nz,error

test_32:	lsc	r2,32		/ Un-set Z via divide (6/5) and jump if set
		lsc	r3,6		/ (makes 0xfffffffe in R3)
		lsc	r4,5
		div	r5,r3,r4
		jump	z,error

test_33:	lsc	r2,33		/ Divide by zero - should set overflow flag
		lsc	r3,1	        / (And not crash the simulator...)
		lsc	r4,0
		div	r5,r3,r4
		jump	ov,test_34
		add	r0,r0,r0        / NOP
		jump	error

test_34:	lsc	r2,34		/ Multiply and test sign flag
		lsc	r3,-1
		lsc	r4,1
		mul	r5,r3,r4
		jump	p,error

test_35:	lsc	r2,35		/ Other way...
		lsc	r3,1
		lsc	r4,-1
		mul	r5,r3,r4
		jump	n,test_36
		add	r0,r0,r0        / NOP
		jump	error	

test_36:	lsc	r2,36		/ MUL two negatives, should give positive
		lsc	r3,-1
		lsc	r4,-1
		mul	r5,r3,r4
		jump	p,test_37
		add	r0,r0,r0        / NOP
		jump	error

test_37:	lsc	r2,37		/ MUL two positives, should give positive
		load	r3,1
		lsc	r4,1
		mul	r5,r3,r4
		jump	n,error

test_38:	lsc	r2,38		/ DIV 1/-1 should give negative
		lsc	r3,1
		lsc	r4,-1
		div	r5,r3,r4
		jump	p,error

test_39:	lsc	r2,39		/ DIV -1/1 should give negaive
		lsc	r3,-1
		lsc	r4,1
		div	r5,r3,r4
		jump	p,error

test_40:	lsc	r2,40		/ DIV -1/-1 should give 1
		lsc	r3,-5
		lsc	r4,-5
		sub	r5,r3,r4
		jump	n,error

test_41:	lsc	r2,41		/ DIV +/+ should give +
		lsc	r3,25
		lsc	r4,5
		div	r5,r3,r4
		jump	n,error

test_42:	lsc	r2,42		/ Multiply two very large integers and check for
		load	r3,seven_f	/ overflow. If the simulator is not on a G++
		lsc	r4,3		/ implementation (with unsigned long long) you
		mul	r5,r3,r4	/ may fail this test.
		jump	ov,test_43
		add	r0,r0,r0        / NOP
		jump	error

test_43:	lsc	r2,43		/ This one should not overflow
		load	r3,seven_f
		lsc	r4,2
		mul	r5,r3,r4
		jump	ov,error

test_44:	lsc	r2,44		/ This one should overflow
		llc	r3,0x10000
		llc	r4,0x10000
		mul	r5,r3,r4
		jump	ov,test_45
		add	r0,r0,r0        / NOP
		jump	error

test_45:	lsc	r2,45		/ Test the logical operations. These can be done
		load	r3,seven_f	/ all at once. They set/reset Z and N but always
		load	r4,eighty	/ clear carry and overflow.
		and	r5,r3,r4	/ AND
		jump	nz,error
		add	r0,r0,r0        / NOP
		jump	ov,error
		add	r0,r0,r0        / NOP
		jump	c,error
		add	r0,r0,r0        / NOP
		jump	n,error
		or	r5,r3,r4	/ OR
		jump	z,error
		add	r0,r0,r0        / NOP
		jump	ov,error
		add	r0,r0,r0        / NOP
		jump	c,error
		add	r0,r0,r0        / NOP
		jump	p,error
		xor	r5,r3,r4	/ XOR
		jump	z,error
		add	r0,r0,r0        / NOP
		jump	ov,error
		add	r0,r0,r0        / NOP
		jump	c,error
		add	r0,r0,r0        / NOP
		jump	p,error
	
test_46:	lsc	r2,46		/ 0x7fffffff versus 0x7fffffff
		load	r3,seven_f
		and	r5,r3,r3
		jump	z,error
		add	r0,r0,r0        / NOP
		jump	ov,error
		add	r0,r0,r0        / NOP
		jump	c,error
		add	r0,r0,r0        / NOP
		jump	n,error
		or	r5,r3,r3
		jump	z,error
		add	r0,r0,r0        / NOP
		jump	ov,error
		add	r0,r0,r0        / NOP
		jump	c,error
		add	r0,r0,r0        / NOP
		jump	n,error
		xor	r5,r3,r3
		jump	nz,error
		add	r0,r0,r0        / NOP
		jump	ov,error
		add	r0,r0,r0        / NOP
		jump	c,error
		add	r0,r0,r0        / NOP
		jump	n,error
	
test_47:	lsc	r2,47		/ 0x80000000 versus 0x80000000
		load	r4,eighty
		and	r5,r4,r4
		jump	z,error
		add	r0,r0,r0        / NOP
		jump	ov,error
		add	r0,r0,r0        / NOP
		jump	c,error
		add	r0,r0,r0        / NOP
		jump	p,error
		or	r5,r4,r4
		jump	z,error
		add	r0,r0,r0        / NOP
		jump	ov,error
		add	r0,r0,r0        / NOP
		jump	c,error
		add	r0,r0,r0        / NOP
		jump	p,error
		xor	r5,r4,r4
		jump	nz,error
		add	r0,r0,r0        / NOP
		jump	ov,error
		add	r0,r0,r0        / NOP
		jump	c,error
		add	r0,r0,r0        / NOP
		jump	n,error
	
/ -------------------------------------------------------------------
/ Here are some general math tests, AND, XOR, ... as well.
/ -------------------------------------------------------------------
	
test_48:	lsc	r2,48		/ Some simple tests for multiplication and division
		llc	r4,0x00007fff
		llc	r5,0x00007fff
		mul	r6,r4,r5	/ 0x3fff0001
		llc	r5,0x10000
		div	r6,r6,r5	/ 0x3fff
		llc	r5,0x3fff
		sub	r0,r6,r5
		jump	nz,error

test_49:	lsc	r2,49		/ Test 2 - some more mult/div testing
		llc	r4,0xff
		llc	r5,0x100
		mul	r4,r4,r5	/ 0xff00
		mul	r4,r4,r5	/ 0xff0000
		mul	r4,r4,r5	/ 0xff000000
		jump	p,error
		div	r4,r4,r5	/ 0xffff0000 (sign-extends the negative number)
		div	r4,r4,r5	/ 0xffffff00
		div	r4,r4,r5	/ 0xffffffff
		lsc	r5,1
		add	r0,r4,r5
		jump	nz,error

test_50:	lsc	r2,50		/ Test 3 - some simple + (most is checked in "flags.s" and is "known good")
		llc	r4,0xffffff
		llc	r5,100
		mul	r4,r4,r5	/ 0xffffff00
		add	r4,r4,r5	/ 0x00000000 and an overflow
		jump	n,error
		add	r0,r4,r0	/ Should still be zero
		jump	nz,error

test_51:	lsc	r2,51		/ And, or, xor
		load	r4,a_bits
		load	r5,five_bits
		or	r6,r4,r5	/ 0xffffffff
		lsc	r7,1
		add	r6,r6,r7	/ 0x00000000 and an overflow
		jump	nz,error
		and	r6,r4,r5	/ 0x00000000 and no overflow
		jump	nz,error
		xor	r6,r4,r4	/ 0x00000000 and no overflow
		jump	nz,error
		xor	r6,r4,r5	/ 0xffffffff
		add	r6,r6,r7	/ 0x00000000 and an overflow
		jump	nz,error
	
		
/ -------------------------------------------------------------------
/ Test the call and return instructions in particular.
/ -------------------------------------------------------------------
	
test_52:	lsc	r2,52		/ Test 52 - simple call and return
		call	test_52_func
		xor	r0,r0,r0	/NOP
		jump	test_53
		and	r0,r0,r0	/NOP
test_52_func:	return
		or	r0,r0,r0	/NOP
	
test_53:	lsc	r2,53		/ Test 2 - a return-jump
		lsc	r3,4		/ Size of a PC push
		sub	r15,r15,r3	/ Decrement stack pointer
		llc	r3,test_54	/ The return address (next test)
		sti	r3,r15,r0
		return			/ Should go to test 54
		sub	r0,r0,r0	/NOP
		jump	error

test_54:	lsc	r2,54		/ Another goofy test
		call	t54_next
		sub	r0,r0,r0	/NOP
t54_next:	ldi	r3,r15,r0
		lsc	r4,4
		add	r15,r15,r4	/ Adjust stack pointer back up
		llc	r4,t54_next	/ Here R3 and R4 should be =
		sub	r0,r3,r4
		jump	z,t54_pass
		add	r0,r0,r0        / NOP
		jump	error
		add	r0,r0,r0        / NOP
t54_pass:

/ -------------------------------------------------------------------
/ Jump to "pass" (or fall through) when all is well.
/ -------------------------------------------------------------------
	
pass:		lsc	r1,2
		llc	r2,your_ok
		syscall	r1,r2		/ print success
		syscall			/ Halt
	
/ -------------------------------------------------------------------
/ If we	are here, R2 contains the failed test number.	
/ -------------------------------------------------------------------

error:		lsc	r1,2		/ Print string
		llc	r3,notice
		syscall r1,r3	
		lsc	r1,1		/ Print the test number in R2
		syscall	r1,r2	
		syscall			/ Stop

	
your_ok:	da	"Passed all tests."
notice:		da	"The following test number failed:"
seven_f:	dc	0x7fffffff
eighty:		dc	0x80000000
a_bits:		dc	0xaaaaaaaa
five_bits:	dc	0x55555555	
