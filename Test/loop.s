/ Here is a file to demo how the delay slots and such can help when
/ executing a pipeline machine.
/ Author:	 Bill Mahoney

/ We'll print the numbers from 1 to 10. Something simple.

start:	lsc	r1,1		/ R1 remains constant - system call to print a number
	lsc	r2,1		/ R2 is the loop index
	lsc	r3,10		/ R3 is the loop limit
again:	syscall	r1,r2		/ Print the number
	sub	r0,r2,r3	/ See if we are still less than 10
	jump	slt,again	/ And do it again, but...
	add	r2,r2,r1	/ ... increment in the delay slot.

	syscall			/ Done

