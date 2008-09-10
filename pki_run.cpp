/* ===========================================================================

pki_run.cpp : entry point into "pki_run" command; assembler/simulator
              Parses command line and uses pki_asm() and pki_sim() to
              perform the work.

Updated to PKI Machine 1.5 - May, 2008.  Jay Pedersen.
Merging of assember and simulator into a single program.

=========================================================================== */

#include        <iostream>       // Just plain needed...
#include        <iomanip>        // Needed for setw, hex, ...
#include        <fstream>        // Needed for ofstream type
#include        <stdio.h>
#include        <sys/types.h>
#include        <sys/stat.h>
#include        <fcntl.h>
#include        <unistd.h>
#include        <stdlib.h>
#include        <ctype.h>
#include        <string.h>
#define         EXTERN           // pki_machine actually declares globals
#include        "pki_machine.h"

using namespace std;

/* Forward declarations */
int usage( void );

/* ===========================================================================

Main starts here. Open up the source file and try to assemble. We are
a two-pass assembler, so the first pass creates the symbol table, and
the second pass generates the (absolute) object.

Inputs:  ac - argument count
         av - argument vector
Outputs: With any luck, your program!
Returns: 0 for no errors (UNIX-like) and non-zero if errors

=========================================================================== */

int main( int ac, char *av[] )
{
    
    int  i;

    if ( ac < 2 )
        exit( usage() );

    interactive_flag       = false;
    yydebug     = 0;  /* no bison debugging */
    listing     = 0;  /* no listing file */
    maxsim      = 50000;
    verbose     = false;

    for( i = 1; i < ac; i++ )
        if ( av[ i ][ 0 ] == '-' )
            switch( av[ i ][ 1 ] )
            {
                case 'i':  interactive_flag = true;
                    break;
                case 'm':  /* max instructions for simulator */
                    if ( av[ i ][ 2 ] )
                        if ( isdigit( av[ i ][ 2 ] ) )
                            maxsim = atol( &av[ i ][ 2 ] );
                        else
                            exit( usage() );
                    else
                        if ( i < ac - 1 )
                            maxsim = atol( av[ ++i ] );
                        else
                            exit( usage() );
                    if ( maxsim == 0 )
                        exit( usage() );
                    break;
                case 'p':  execute_pipeline = true;
                    break;
                case 's':  listing = true;
                    break;
                case 'v':  verbose = true;
                    break;
                case 'y':  yydebug = true;
                    break;
                default:   exit( usage() );
            }
        else
            filename = av[ i ];

    cout << "Starting...\n";
    cout << "PKI-M Assembler/Simulator, Version 2.0\n";

    // Create ram_image for use by simulator...  The old assembler
    // code refers to this as "memory" but the old simulator code
    // called it "ram_image". They're the same thing now that these
    // are the same program.

    memory = ram_image = new BYTE[ memory_size ];
    if ( ! ram_image )
    {
        cout << "pki_sim" << ": Unable to allocate " << memory_size
             << " bytes of memory!" << endl;
        exit( 5 );
    }
    else
        cout << "Allocated " << memory_size << " bytes for image." << endl;

    if ( pki_asm() == 0 )  /* assemble */
        if ( ! listing )   /* listing only? then stop */
            pki_sim();     /* run/interpret */

}  /* main */

/*===========================================================================

usage

Print usage message, curl up, and die. Basically we just return 1
always, as we are usually called as "exit( usage() )". So there.

Inputs:  None
Outputs: None
Returns: 1 always

=========================================================================== */

int usage( void )
{
    cout << "\nPKI Machine Assembler / Interpreter 2.0\n\n";
    cout << "usage: pki_run <file> [-e] [-l] [-m size ] [-p] [-s] [-y]\n"
         << "-i       == interactive mode\n"
         << "-m count == maximum instructions to execute (default 50,000)\n"
         << "-s       == generates assembly listing file to stdout\n"
         << "-v       == verbose mode, print each instruction as executed\n"
         << "-y       == internal debugging (yydebug)\n\n";
    return( 1 );
}
