# Makefile for the CS4350/4700 Assembler (PKI-Machine)
# Works on generic Linux-type things, such as Cygwin.
# Updated July, 2005 - Bill M., May 2008, Jay P

YACC=bison
LEX=flex
CC=g++
LN=g++
COPT=-g
LOPT=-g
DIFF=diff

OBJS = pki_run.o pki_asm.o pki_asm_lexscan.o pki_sim.o pki_sim_grammar.o pki_sim_lexscan.o

pki_run :	$(OBJS)
	$(CC) $(LOPT) -o pki_run $(OBJS)

pki_run.o:	pki_run.cpp pki_machine.h 
	$(CC) $(COPT) -c pki_run.cpp

pki_sim.o :	pki_sim.cpp pki_machine.h
	$(CC) $(COPT) -c pki_sim.cpp

# Bison has this annoying habit of sending yydebug to stderr
# so I change that to go to stdout, which I like better.
# Bison puts output in the non-traditional place; move it.
pki_asm.o :	pki_asm_grammar.y pki_machine.h
	$(YACC) -d -t pki_asm_grammar.y
	sed "s/stderr/stdout/" pki_asm_grammar.tab.c >pki_asm.cpp ; rm pki_asm_grammar.tab.c
	$(CC) $(COPT) -c pki_asm.cpp

pki_asm_lexscan.o :	pki_asm_lexscan.lex pki_asm_grammar.tab.h pki_machine.h
	$(LEX) pki_asm_lexscan.lex
	mv lex.yy.c pki_asm_lexscan.cpp
	$(CC) $(COPT) -c pki_asm_lexscan.cpp

pki_sim_grammar.o :	pki_sim_grammar.y pki_machine.h
	$(YACC) -d -t -p sim_yy pki_sim_grammar.y
	sed "s/stderr/stdout/" pki_sim_grammar.tab.c >pki_sim_grammar.cpp ; rm pki_sim_grammar.tab.c
	$(CC) $(COPT) -c pki_sim_grammar.cpp

pki_sim_lexscan.o :	pki_sim_lexscan.lex pki_sim_grammar.tab.h
	$(LEX) -I -Psim_yy pki_sim_lexscan.lex
	mv lex.sim_yy.c pki_sim_lexscan.cpp
	$(CC) $(COPT) -c pki_sim_lexscan.cpp

NONEXE = pki_asm.cpp pki_asm_lexscan.cpp y.tab.h pki_sim_grammar.cpp pki_sim_lexscan.cpp

clean :	
	-rm pki_run pki_run.exe $(NONEXE) pki_*.tab.h *.o *~ 

# The pipeline test on the plain CPU fails for test 54 (0x36) but
# should work up to then. The issue is comparing the pushed return
# address - on a pipeline it is incremented already, on a plain CPU it
# is not.
test :	pki_run
	./pki_run Test/cpu_test.s    | grep PASSED
	./pki_run -p Test/pipeline.s | grep PASSED

keepexe:
	rm $(NONEXE)

