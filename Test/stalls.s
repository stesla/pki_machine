/ Demonstrate pipeline stalls. Run this once in the plain CPU (one
/ clock per instruction) and the pipeline CPU (with stalls) and
/ see the difference.
/ Author:	Bill Mahoney

start:	lsc	r1,1		/ Doesn't matter much what we do
	lsc	r2,2		/ so let's just load 'em up and move 'em out
	add	r3,r1,r2	/ Stall 1 clock because of R1/R2
	add	r4,r3,r2	/ Stall 1 clock because of R3
	syscall
	
