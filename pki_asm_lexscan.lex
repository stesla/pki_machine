%{

/* ===========================================================================

scanner for assembler portion of PKI-M interpreter. 

This is your basic lex/flex input file, symbols.l. We just look for
the non-terminals and terminals as usual and pass them up.

Author: Bill Mahoney
Date:   June 3, 2001
For:    CS 4350 and others...

=========================================================================== */

#include        <iostream>
#include        <iomanip>
#include        <stdlib.h>
#include        <string.h>
#include        "pki_machine.h"
#include        "pki_asm_grammar.tab.h"

using namespace std;

extern YYSTYPE  yylval;
extern short    lex_debug, line;
extern char listing_line[];

int asm_keyword( const char *string, int *type, TWO_BYTE *op );

// Define this so that it will call our input routine (my_input) instead
// of reading from stdin (cin) as a normal flex-generated scanner would.
int my_input( unsigned char *buf, int max_size );
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) result = my_input( (unsigned char *) buf, max_size );

%}

AL              [a-zA-Z]
NUM             [0-9]
ALNUM           [a-zA-Z0-9_$]
SP              [ \r\t]

%%

[;/]            {
                    // These are comments.
                    while ( yyinput() != '\n' )
                        ;

                    unput( '\n' );
                    if ( lex_debug )
                        cout << "Removed comment from input stream.\n";
                }

{SP}            ; // Chew up tabs and spaces - not used

R{NUM}+         {
                    (void) strcpy( yylval.str_val, yytext );
                    if ( lex_debug )
                        cout << "Symbol REG, value \"" << yytext << "\"\n";
                    return( REG );
                }

DC|DS|DA|ORG    {
                    if ( lex_debug )
                        cout << "Symbol DC/DS/DA/ORG\n";
                    if ( yytext[ 0 ] == 'O' )
                        return( yylval.int_val = ORG );
                    else if ( yytext[ 1 ] == 'C' )
                        return( yylval.int_val = DC );
                    else if ( yytext[ 1 ] == 'S' )
                        return( yylval.int_val = DS );
                    else
                        return( yylval.int_val = DA );
                }

^{AL}{ALNUM}*:  {
                    if ( lex_debug )
                        cout << "Symbol LABEL, value \"" << yytext << "\"\n";
                    (void) strcpy( yylval.str_val, yytext );
                    return( LABEL );
                }

{AL}+           {
                    // Might be a keyword OR an operand. Check the table.
                    int      keyword_value;
                    TWO_BYTE scanner_opcode;
                    if ( asm_keyword( yytext, &keyword_value, &scanner_opcode ) )
                    {
                        if ( lex_debug )
                            cout << "Symbol KEYWORD is \"" << yytext
                                 << " value 0x" << hex << setw( 4 )
                                 << setfill( '0' )
                                 << scanner_opcode << dec << endl;
                        yylval.partial_opcode = scanner_opcode;
                        return( keyword_value );
                    }
                    else
                    {
                        if ( lex_debug )
                            cout << "Symbol OPERAND, value \"" << yytext
                                 << "\"\n";
                        (void) strcpy( yylval.str_val, yytext );
                        return( OPERAND );
                    }
                }

{NUM}+|\-{NUM}+|{ALNUM}+ {
                    strcpy( yylval.str_val, yytext );
                    if ( lex_debug )
                        cout << "Symbol OPERAND, value \"" << yytext << "\"\n";
                    return( OPERAND );
                }

[,=\n]          {
                    if ( lex_debug )
                    {
                        if ( yytext[ 0 ] == '\n' )
                            cout << "Symbol (ASCII) is newline\n";
                        else
                            cout << "Symbol (ASCII) is \"" << yytext[ 0 ]
                                 << "\"\n";
                    }
                    yylval.int_val = yytext[ 0 ];
                    return( yytext[ 0 ] );
                }

\"[^\"\n]*\"    {
                    if ( lex_debug )
                        cout << "Symbol STRING \"" << yytext << "\"\n";
                    yylval.str_ptr = strdup( yytext );
                    return( STRING );
                }

%%

struct  tab     {
    char     word[ 8 ];
    int      value;
    TWO_BYTE opcode;
};

int asm_keyword( const char *string, int *type, TWO_BYTE *op )
{

    int             comp( const void *, const void * );
    struct tab      *ptr;
    static struct   tab     table[] = {
                                        { "ADD", ADD, ADD_OP },
                                        { "AND", AND, AND_OP },
                                        { "C", C, C_FLAG },
                                        { "CALL", CALL, CALL_OP },
                                        { "DIV", DIV, DIV_OP },
                                        { "EQ", EQ, EQ_FLAG },
                                        { "JUMP", JUMP, JUMP_OP },
                                        { "LDI", LDI, LDI_OP },
                                        { "LLC", LLC, LLC_OP },
                                        { "LOAD", LOAD, LOAD_OP },
                                        { "LSC", LSC, LSC_OP },
                                        { "MUL", MUL, MUL_OP },
                                        { "N", N, N_FLAG },
                                        { "NE", NE, NE_FLAG },
                                        { "NZ", NZ, NZ_FLAG },
                                        { "OR", OR, OR_OP },
                                        { "OV", OV, OV_FLAG },
                                        { "P", P, P_FLAG },
                                        { "RETURN", RETURN, RETURN_OP },
                                        { "SLE", SLE, SLE_FLAG },
                                        { "SLT", SLT, SLT_FLAG },
                                        { "STI", STI, STI_OP },
                                        { "STORE", STORE, STORE_OP },
                                        { "SUB", SUB, SUB_OP },
                                        { "SYSCALL", SYSCALL, SYSCALL_OP },
                                        { "ULE", ULE, ULE_FLAG },
                                        { "ULT", ULT, ULT_FLAG },
                                        { "XOR", XOR, XOR_OP },
                                        { "Z", Z, Z_FLAG }
                                      };

    ptr = (struct tab *) bsearch( string, (char *) &table[ 0 ],
                                  sizeof( table ) / sizeof( table[ 0 ] ),
                                  sizeof( table[ 0 ] ), comp );
    if ( ptr )
    {
        *op = ptr -> opcode;
        *type = ptr -> value;
        return( TRUE );
    }
    else
        return( FALSE );
    
}

int comp( const void *a, const void *b )
{
    return( strcmp( ( ( struct tab *) a ) -> word, 
            ( ( struct tab *) b ) -> word ) );
}
