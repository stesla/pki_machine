%{

/* ===========================================================================

Pki-M simulator - command interpreter

Author: Bill Mahoney
For:    CS 4350 and others...

Modifications: For 2.0 the "step" command took an optional number,
               which was then ignored. So now "s 3" steps 3 times.

=========================================================================== */

#include <iostream>
#include <fstream>
#include <iomanip>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "pki_machine.h"

using namespace std;

// This needs to be in C mode since it is called from within the scanner.
// Not sure why flex doesn't fix that up, but if you compile it in C++
// mode the linker can't find it.
extern "C" int sim_yywrap( void );

void do_help( void );
void do_list( int list_count );
int sim_yyerror( const char * );
int sim_yylex( void );
void dm_command( const int );
void sm_command( const int, const BYTE );
void do_break( const int );
void clear_break( const int );
void dr_command( void );
void sr_command( const int reg, const int val );
void stack_command( void );
bool do_step( void );
void show_next( void );
bool is_break( const int point );

%}

%token <int_val> BREAK CONTINUE DM DR HELP NUMBER
%token <int_val> LIST OVER SM SR STACK STEP QUIT
%token <int_val> REGISTER
%token <void>    CLEAR
%type  <int_val> optnum
%type  <int_val> command

%start command

%%

command : BREAK NUMBER
            {
                cout << "Setting breakpoint...\n";
                do_break( $2 );
            }
        | CLEAR NUMBER
            {
                cout << "Clearing breakpoint...\n";
                clear_break( $2 );
            }
        | CONTINUE
            {
                extern FOUR_BYTE pc;
                extern bool verbose;
                bool is_break( const int point );

                cout << "Continuing...\n";
                if ( ! do_step() )  // execute a step (even if at a break)
                    cout << "Stopped...\n";
                else
                {
                    while ( 1 )
                        if ( is_break( pc ) )
                        {
                            show_next();  // hit breakpoint
                            break;
                        }
                        else if ( ! do_step() )
                        {
                            cout << "Stopped...\n";
                            break;
                        }
                }
            }
        | DM optnum
            {
                cout << "Displaying memory...\n";
                // Note that we expect an address; DM will handle
                // converting this into an array subscript for us.
                dm_command( $2 );
            }
        | DR
            {
                cout << "Registers...\n";
                dr_command();
            }
        | HELP
            {
                do_help();
            }
        | LIST optnum
            {
                do_list( $2 );
            }
        | OVER optnum
            {
                extern FOUR_BYTE pc;
                extern BYTE *ram_image;
                bool keep_going = true, in_skip = false;
                FOUR_BYTE after_call, counter = 0;

                cout << "Executing over...\n";
                // We need to do a certain number of them
                for( int i = 0; i < $2 && keep_going; i++ )
                {
                    // Really need to remove this magic number at some point.
                    // It is opcode F with condition 1 that's a call.
                    in_skip =    ( ram_image[ pc ] == 0xf1 );
                    after_call = ( ram_image[ pc ] == 0xf1 ) ? pc + 4 : 0xffffffff;

                    do {
                        if ( ! do_step() )
                        {
                            cout << "Stimulation finished.\n";
                            keep_going = false;
                        }
                        else
                        {
                            if ( in_skip ) 
                                counter++; // count the skipped instructions
                            else
                                show_next();

                            if ( is_break( pc ) )
                            {
                                // hit a breakpoint; bail big time.
                                cout << "Reached a break point while executing \"over\"." << endl;
                                if ( in_skip ) show_next(); // since we otherwise would not see it.
                                keep_going = false;
                            }
                        }

                    } while ( in_skip && pc != after_call && keep_going );
                    
                    if ( pc == after_call )
                    {
                        cout << "Skipped " << dec << counter << " instruction(s)...\n";
                        counter = 0;
                        show_next();
                    }
                } // for
            }
        | SM NUMBER NUMBER
            {
                cout << "Setting memory...\n";
                sm_command( $2, $3 );
            }
        | SR REGISTER NUMBER
            {
                sr_command( $2, $3 );
            }
        | STACK
            {
                cout << "Stack trace...\n";
                stack_command();
            }
        | STEP optnum
            {
                cout << "Stepping...\n";
                for( int i = 0; i < $2; i++ )
                    if ( ! do_step() )
                        cout << "Stimulation finished.\n";
                    else
                        show_next();
            }
        | QUIT
            {
                cout << "Quitting...\n\n";
                return( 2 );
            }
        |   error
            {
            }
        ;

optnum  : NUMBER
            {
                // this is an integer value here, not a TWO_BYTE.
                $$ = $1;
            }
        |
            {
                $$ = 1; // Default value
            }
        ;

%%

/* ===========================================================================

do_help

=========================================================================== */

void do_help()
{

    cout << "\nCommands available (upper case shows minimum typing):\n\n"
         << "BReak [<addr>]   == stops executing before the instruction at <addr>\n"
         << "                    if no address given, lists breakpoints\n"
         << "CLear [<addr>]   == remove a breakpoint\n"
         << "                    if no address given, use current location\n"
         << "Continue         == run from this point until you hit a break\n"
         << "DM [<addr>]      == display memory at <addr>, or from last address\n"
         << "DR               == display registers\n"
         << "List [<num>]     == list next source lines, num defaults to 4\n"
         << "Over [<num>]     == step, but go over call instructions\n"
         << "                    (execute the function, but stop when you get back)\n"
         << "SM <addr> <num>  == Substitute memory; put <num> into <addr>\n"
         << "SR <reg> <num>   == Substitute register; put <num> into register <reg>\n"
         << "                    (Can be used to fix little things without having to restart)\n"
         << "STAck            == Show what is on the stack, in a nice format\n"
         << "Step [<num>]     == step one instruction, or <num> instructions\n\n"
         << "Quit or Exit     == leave the simulator\n\n"
         << "<addr> and <num> can be hex, with a leading \"0x\", or in decimal.\n"
         << "<reg> is something like \"R3\" or \"r14\".\n"
         << "Brackets [] enclose optional arguments.\n";
}

/* ===========================================================================

sim_yyerror

=========================================================================== */

int sim_yyerror( const char *err )
{
    cout << "Error: ";
    cout << err << "\n";
    while ( sim_yylex() )
        ;
}

/* ===========================================================================

sim_my_input, sim_reset_input

This requires some notes. The scanner will call here for a buffer of
text. We return a buffer of text, but of course the scanner is going
to call us again for more. So on the second call, we treat it as if
that's EOF on the input stream. After sim_yyparse() returns back, the main
application can call "sim_reset_input()" to get ready for another line.

Toggling "signal_EOF" does not work, by the way, because we'll get
multiple calls to sim_my_input when there is a parse (syntax) error.

Inputs:  buf - the place to put the line of text
         max_size - size of the buffer
Outputs: buf - filled in
Returns: Number of characters filled in, or 0 on the second call

=========================================================================== */

static bool signal_EOF = 0;

int sim_my_input( char *buf, int max_size )
{

    // cout << "sim_my_input: signal_EOF = " << signal_EOF << "\n";

    if ( ! signal_EOF )
    {
        cin.getline( buf, max_size );
        for( int i = 0; buf[ i ]; i++ )
            if ( isalpha( buf[ i ] ) )
                buf[ i ] = toupper( buf[ i ] );
        // Special case - convert empty line to "step"
        if ( ! buf[ 0 ] )
            strcpy( buf, "STEP" );
        signal_EOF = 1;
        return( strlen( buf ) );
    }
    else
        return( 0 );
}

void sim_reset_input( void )
{
    signal_EOF = 0;
}

