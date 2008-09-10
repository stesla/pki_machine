%{

/* ===========================================================================

Scanner for interpreting commands in the simulator.

=========================================================================== */

#include <iostream>
#include <fstream>
#include <iomanip>
#include <stdlib.h>
#include <string.h>
#include "pki_machine.h"
#include "pki_sim_grammar.tab.h"

int sim_my_input( char *buf, int max_size );

extern "C" int sim_yywrap( void );

#define YY_INPUT(buf,result,max_size) result = sim_my_input( buf, max_size );

%}

%%

B|BR|BRE|BREA|BREAK  {
                         return( BREAK );
                     }

C|CO|CON|CONT|CONTI|CONTIN|CONTINU|CONTINUE {
                         return( CONTINUE );
                     }

CL|CLE|CLEA|CLEAR    {
                         return( CLEAR );
                     }

DM                   {
                         return( DM );
                     }

DR                   {
                         return( DR );
                     }

H|HE|HEL|HELP|\?     {
                         return( HELP );
                     }

L|LI|LIS|LIST        {
                         return( LIST );
                     }

O|OV|OVE|OVER        {
                         return( OVER );
                     }

Q|QU|QUI|QUIT|EXIT   {
                         return( QUIT );
                     }

R[0-9]+              {
                         sim_yylval.int_val = (int) strtoul( sim_yytext + 1, NULL, 0 );
                         return( REGISTER );
                     }

PC                   {
                         sim_yylval.int_val = -1; // Special magic constant (shhh!)
                         return( REGISTER );
                     }

SM                   {
                         return( SM );
                     }

SR                   {
                         return( SR );
                     }

ST|STA|STAC|STACK       {
                         return( STACK );
                     }


S|ST|STE|STEP        {
                         return( STEP );
                     }


0[xX][0-9a-fA-F]+|[0-9]+  {
                         sim_yylval.int_val = (int) strtoul( sim_yytext, NULL, 0 );
                         return( NUMBER );
                     }

[ \t\n]              {
                         // blanks we toss
                     }

.                    {
                         // cout << "Strange character seen: " << sim_yytext << "\n";
                         return( sim_yytext[ 0 ] ); // generate a syntax error
                     }

%%

/* ===========================================================================

sim_yywrap

Every line is the last line, so always return 1. This is very messy
black art here.

=========================================================================== */

extern "C" {

int sim_yywrap( void )
{

#if 0 // For a FLEX that is older than dirt.
      // Apparently, after two hours of poking, I discover that
      // unless you do this Voodoo magic, you are stuck at EOF
      // for ever and ever until you ^C outa here.
    YY_NEW_FILE;
#endif

    return( 1 );
}

};
