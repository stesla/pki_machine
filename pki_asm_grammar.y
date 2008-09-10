%{

/* ===========================================================================

Pki-M assembler

Interface routine: pki_asm() (2-pass assembler).

This is a simple-minded assembler for the PKI_Machine discussed in
Computer Science 4350. So there.

Updated to PKI Machine 1.5 (and then 2.0) - May, 2008.  Jay Pedersen.
Merging of assember and simulator into a single program.

PKI 1.4 updates June 2005: Bill.  Rearranged several of the
opcodes, and also suddenly the PKI machine is a 32-bit architecture as
well. These things just happen when it's a virtual machine, you know?
The code is, however, still C and not C++ based on it's legacy. This
was an update of the 1.3 assember which traces its roots back to one
that I put together XX years ago. Note that that's two digits there...

Author:   Bill Mahoney
Date:     June 3, 2001
For:      CS 4350 and others...
Revision: November 12, 2001 - added MUL (same as SHL) and DIV (same as SHR)
          July 2005 - Converted to a 32-bit machine, and rearranged
          instructions. Jump, call, return, and syscall all have the
          same opcode now. The 32 bit part doesn't have that much
          effect except for declaration of constants.

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
#include        "pki_machine.h"

using namespace std;

int usage( void );
int sym_compare( const void *a, const void *b );
int addr_compare( const void *a, const void *b );
FOUR_BYTE de_reference( char *sym );
int yyerror( const char *msg );
int my_input( char *buf, int max_size );
void detab( char *line );
int yylex( void );
TWO_BYTE de_reg( const char *reg_str );

inline bool is_double_op( const TWO_BYTE op ) 
{ 
    return( ( op & 0xc000 ) == 0xc000 ); 
}

void put2( BYTE *p, TWO_BYTE val ) 
{     
    *p++ = ( val & 0xff00 ) >> 8;
    *p = ( val & 0x00ff );
}

void put4( BYTE *p, FOUR_BYTE val ) 
{     
    *p++ = ( val & 0xff000000 ) >> 24;
    *p++ = ( val & 0x00ff0000 ) >> 16;
    *p++ = ( val & 0x0000ff00 ) >> 8;
    *p =   ( val & 0x000000ff );
}

void add_symbol(char *p_symbol_name, FOUR_BYTE loc, bool trim_colon)
{
    if (trim_colon)
    {
        if ( p_symbol_name[ strlen( p_symbol_name ) - 1 ] == ':' )
            p_symbol_name[ strlen( p_symbol_name ) - 1 ] = '\0';
    }
    (void) strcpy( symbol_table[ symbols ].str_val, p_symbol_name);
    symbol_table[ symbols ].location = loc;
    symbols++;
}

// This needs to be in C mode since it is called from within the scanner.
// Not sure why flex doesn't fix that up, but if you compile it in C++
// mode the linker can't find it.
extern "C" int yywrap( void );

char            listing_line[ 132 ];    // for listings.  
int             err_count;              // # of errors.   
int             pass = 1;               // Two pass assembler.  
short           echo;                   // true echos input
short           lex_debug;              // true debugs scanner  
short           line = 0;               // For listings   
ifstream        infile;                 // source file (assembly program)
FOUR_BYTE       location_counter;       // Absolute address...  

%}

%token <str_val> LABEL OPERAND REG
%token <str_ptr> STRING
%token <partial_opcode> SYSCALL RETURN
%token <partial_opcode> SHL SHR MUL DIV
%token <partial_opcode> ADD SUB AND OR XOR
%token <partial_opcode> LSC LLC
%token <partial_opcode> LDI STI
%token <partial_opcode> LOAD STORE
%token <partial_opcode> CALL JUMP
%token <int_val> DC DS DA ORG
%token <partial_opcode> SLT SLE ULT C ULE EQ Z NE NZ N P OV

%type <instruction_addr> line
%type <partial_opcode> operation
%type <partial_opcode> type_three reg_addr_instr
%type <partial_opcode> three_register one_register
%type <long_opcode> reg_addr
%type <int_val> dcs
%type <partial_opcode> jcond cond

%%

program         :       program line
            {

                if ( ( interactive_flag || verbose ) && 
                     ( pass == 2 ) )
                {
                    // ASM_SOURCE_PTR p = new ASM_SOURCE_LINE[1];
                    ASM_SOURCE_PTR p = new ASM_SOURCE_LINE;
                    if (! p)
                    {
                        cerr << "Internal error: "
                             << "Memory allocation failure on source line"
                             << endl;
                        exit( 15 );
                    }
                    p->line_num = line;
                    p->pc       = $2;
                    strncpy(p->source, listing_line, MAX_SOURCE_LINE);
                    // detab(p->source); NO! This may make the line
                    // LONGER than MAX_SOURCE_LINE and you're toast.
                    for( int i = 0; p->source[ i ]; i++ )
                        if ( p->source[ i ] == '\t' )
                            p->source[ i ] = ' ';
                    if (p->source[ strlen( p->source ) - 1 ] == '\n')
                        p->source[ strlen( p->source ) - 1 ] = '\0';
                    asm_source_lines[ line ] = p;
                    asm_source_by_pc[ $2 ] = p;
                }

                /* Subtlety here - the location counter has */
                /* already been advanced, so be careful printing */
                /* memory[ -1 ]. */
                if ( ( listing      ) &&
                     ( pass == 2    ) )
                {
                    TWO_BYTE temp = ( memory[ $2 ] << 8 ) | ( memory[ $2 + 1 ] );
                    // (Line - 1) used because the scanner has already read the
                    // next line before the parser reduces up to here.
                    if ( is_double_op( temp ) )
                        cout << dec << setw( 3 ) << line - 1 << " -->\t@" 
                             << hex << setw( 6 ) << setfill( '0' ) << $2 << " " 
                             << hex << setw( 2 ) << setfill( '0' ) 
                             << (unsigned) memory[ $2 ] 
                             << hex << setw( 2 ) << setfill( '0' ) 
                             << (unsigned) memory[ $2 + 1 ]
                             << hex << setw( 2 ) << setfill( '0' ) 
                             << (unsigned) memory[ $2 + 2 ]
                             << hex << setw( 2 ) << setfill( '0' ) 
                             << (unsigned) memory[ $2 + 3 ]
                             << " " << listing_line;
                    else
                        cout << dec << setw( 3 ) << line - 1 << " -->\t@" 
                             << hex << setw( 6 ) << setfill( '0' ) << $2 << " "
                             << hex << setw( 2 ) << setfill( '0' ) 
                             << (unsigned) memory[ $2 ] 
                             << hex << setw( 2 ) << setfill( '0' ) 
                             << (unsigned) memory[ $2 + 1 ]
                             << "     " << listing_line;
                }
            }
            | /* <LAMBDA> */
        ;

line    :       operation '\n'
            {
                $$ = location_counter;
                location_counter += ( is_double_op( $1 ) ? 4 : 2 );
            }
        |       LABEL operation '\n'
            {
                $$ = location_counter;
                if ( pass == 1 )
                    add_symbol ( $1, location_counter, true );
                location_counter += ( is_double_op( $2 ) ? 4 : 2 );
            }
        |       OPERAND '=' OPERAND '\n'
            {
                $$ = location_counter;
                /* symbol = value. This would be a      */
                /* #define or "const" in a hll. The lex */
                /* can tell these apart by the lack of  */
                /* a trailing ':'...                    */
                if ( pass == 1 )
                    add_symbol( $1, de_reference( $3 ) , false );
            }
        |       LABEL dcs OPERAND '\n'
            {
                $$ = location_counter;
                // This defines words with contents
                // already in them. For example:
                // FOO: DC 1
                // Or you can define space (reserve it)
                // FOO: DS 5
                if ( pass == 1 )
                    add_symbol( $1, location_counter, true );

                // if it is DS, we need to set aside the space
                if ( $2 == DS )
                    location_counter += de_reference( $3 );
                else 
                {
                    if ( pass == 2 )
                    {
                        FOUR_BYTE temp = de_reference( $3 );
                        put4( &memory[ location_counter ], temp );
                    }
                    location_counter += 4;
                }
            }
        |       dcs OPERAND '\n'
            {
                $$ = location_counter;
                // if it is DS, we need to set aside the space
                if ( $1 == DS )
                    location_counter += de_reference( $2 );
                else 
                {
                    if ( pass == 2 )
                    {
                        FOUR_BYTE temp = de_reference( $2 );
                        put4( &memory[ location_counter ], temp );
                    }
                    location_counter += 4;
                }
            }
        |       LABEL DA STRING '\n'
            {
                int len = strlen( $3 );
                $$ = location_counter;
                if ( pass == 1 )
                    add_symbol( $1, location_counter, true );
                // The string has quotes on the front and back, so accomodate by -1
                if ( pass == 2 )
                {
                    // Start at the byte after the initial quote
                    memcpy( &memory[ location_counter ], $3 + 1, len - 2 );
                    memory[ location_counter + len - 2 ] = '\0';
                }
                location_counter += len - 1;
                free( $3 );
            }
        |       ORG OPERAND '\n'
            {
                /* Set origin somewhere else. Set $$ first so that this line */
                /* has the old address and the next line has the new one.    */
                $$ = location_counter;
                location_counter = de_reference( $2 );
            }
        |       operation error '\n'
            {
            yyerror( "Extra junk on that line; syntax error?" );
            $$ = location_counter;
            }
        |       '\n'
            {
                $$ = location_counter;
            }
        |       LABEL '\n'
            {
                $$ = location_counter;
                if ( pass == 1 )
                    add_symbol( $1, location_counter, true );
            }
        ;

operation       :       SYSCALL
            {
                if ( pass == 2 )
                    put2( &memory[ location_counter ], $1 );
            }
        |       SYSCALL REG ',' REG
            {
                if ( pass == 2 )
                    put2( &memory[ location_counter ],
                          $1 | 
                          ( de_reg( $2 ) << 8 ) |
                          ( de_reg( $4 ) << 4 ) );
            }
        |       RETURN
            {
                if ( pass == 2 )
                    put2( &memory[ location_counter ], $1 );
            }
        |       type_three three_register
            {
                if ( pass == 2 )
                    put2( &memory[ location_counter ], $1 | $2 );
            }
        |       LSC one_register
            {
                if ( pass == 2 )
                    put2( &memory[ location_counter ], $1 | $2 );
            }
        |       reg_addr_instr reg_addr
            {
                if ( pass == 2 )
                    put4( &memory[ location_counter ], ( $1 << 16 ) | $2 );
            }
        |       JUMP jcond OPERAND
            {
                if ( pass == 2 )
                {
                    FOUR_BYTE destination = de_reference( $3 );
                    put2( &memory[ location_counter ], 
                          $1 | $2 |
                     ( ( destination & HIGH_ADDR_BYTE ) >> HIGH_ADDR_SHIFT ) );
                    put2( &memory[ location_counter ] + 2,
                          ( destination & LOW_ADDR_BYTES ) );
                }
            }
        |       CALL OPERAND
            {
                if ( pass == 2 )
                {
                    FOUR_BYTE destination = de_reference( $2 );
                    put2( &memory[ location_counter ], 
                          $1 |
                     ( ( destination & HIGH_ADDR_BYTE ) >> HIGH_ADDR_SHIFT ) );
                    put2( &memory[ location_counter ] + 2,
                         ( destination & LOW_ADDR_BYTES ) );
                }
            }
        ;

type_three      :       MUL
        |               DIV
        |               ADD
        |               SUB
        |               AND
        |               OR
        |               XOR
        |               LDI
        |               STI
        ;

three_register  :       REG ',' REG ',' REG
            {
                /* $1, etc. have the string "Rx" where x is reg # */
                $$ = de_reg( $1 ) << 8 |
                     de_reg( $3 ) << 4 |
                     de_reg( $5 );
            }
        |       error
            {
                yyerror( "This operation requires three registers." );
            }
        ;

one_register    :       REG ',' OPERAND
            {
                /* Some sign trickery here, because the constant is */
                /* supposed to be treated as a signed number -128..127 */
                /* Note that de_reference returns unsigned, so if it */
                /* starts with '-' it's a negative number and we convert it */
                /* right here instead of below. */
                int      temp;
                temp = ( $3[ 0 ] == '-' ) ? atoi( $3 ) : de_reference( $3 );
                if ( ( temp < -128 ) || ( temp > 127  ) )
                    yyerror( "Constant is out of range -128..127" );
                $$ = ( de_reg( $1 ) << 8 ) | ( temp & 0xff );
            }
        |       error
            {
                yyerror( "This operation requires one regester and one operand." );
            }
        ;

reg_addr_instr  :       LLC
        |               LOAD
        |               STORE
        ;

reg_addr        :       REG ',' OPERAND
            {
                if ( pass == 2 )
                    $$ = ( de_reg( $1 ) << 24 ) |
                            ( de_reference( $3 ) & 0x00ffffff );
                else
                    $$ = 0;
            }
        |       error
            {
                yyerror( "Load/store requires one regester and one symbol." );
            }
        ;

dcs             :       DC
        |               DS
        ;

jcond           :      cond ','
        |
            {   
                /* No condition == 0000 bits */
                $$ = 0x0000;
            }
        |       error
            {
                yyerror( "Missing jump condition before ','?" );
            }
        ;

cond            :       SLT
        |               SLE
        |               ULT
        |               C
        |               ULE
        |               EQ
        |               Z
        |               NE
        |               NZ
        |               N
        |               P
        |               OV
        |               error
            {
                yyerror( "Unknown jump condition before ','." );
            }
        ;

%%

/* ===========================================================================

sym_compare

This is a comparison routine so that qsort can sort the symbol table
into alpha order.

Inputs:  Two pointers to symbol table entries
Outputs: None
Returns: something < 0 if the symbol in 'a' is < the symbol in 'b'
         something > 0 if the symbol in 'a' is > the symbol in 'b'
   zero if they are the same

=========================================================================== */

int sym_compare( const void *a, const void *b )
{
    return( strcmp( ( ( const struct sym_s *) a ) -> str_val, 
                    ( ( const struct sym_s *) b ) -> str_val ) );
}

int addr_compare( const void *a, const void *b )
{
    return( ( ( const struct sym_s *) a ) -> location - 
            ( ( const struct sym_s *) b ) -> location );
}

/* ===========================================================================

de_reference

If I have the name of a symbol, I need to map that into the address of
the symbol. We do this in a simple (read: inefficient) way, by simply
linearly scanning the symbol table. Not the best, but for the programs
we will write in 4350, good 'nuf. 

Inputs:  sym - the string we want to look up (note that strings like
         "45" end up getting returned as unsigned 45.
Outputs: None
Returns: the address (value) of the symbol.

=========================================================================== */

FOUR_BYTE de_reference( char *sym )
{
    int     i;
    
    for( i = 0; i < symbols; i++ )
        if ( strcmp( symbol_table[ i ].str_val, sym ) == 0 )  /* match */
            return( symbol_table[ i ].location );

    /* No match.  Maybe it is a number? */
    if ( ( isdigit( *sym ) ) || 
         ( *sym == '-' )     ||
         ( *sym == '+' ) )
        return( (FOUR_BYTE) strtoul( sym, NULL, 0 ) );
    else
    {
        yyerror( "Mysterious operand!?" );
        cerr << "Unable to figure out operand: \"" << sym << "\"\n";
        return 0;
    }
    
} /* de_reference */

/* ===========================================================================

yyerror

This is called from within the parser when something is not matching a
grammar rule. It can also be called manually (see de_reference) to
generate an error for some other reason. 

Inputs:  None
Outputs: None
Returns: int?

=========================================================================== */

int yyerror( const char *msg )
{
    cerr << "Error: line " << line << ": " << listing_line << endl;
    cerr << msg << endl;
    err_count++;
    return 0;
}

/* ===========================================================================

yywrap

This function is called automatically when we tell the scanner that
the file is done. The purpose is to let the scanner know if there is
more input coming up (like from an additonal file) or not. In the case
of the assembler, we want to go through the file two times - once to
make the symbol table, once to do the dirty work. So the first time
we're called, rewind to the beginning of the file. Second time, tell
them that we're really done.

Inputs:  None
Outputs: None
Returns: 0 as an indication that there is more input (pass two for us)
         1 on a true end-of-file

=========================================================================== */

extern "C" {

int yywrap( void )
{
    if ( ( pass == 1 ) &&
         ( err_count == 0 ) )
    {
        ram_image_size = location_counter;

        // Either an interactive mode or verbose requires us to set up
        // to watch source lines.

        if ( interactive_flag || verbose )
        {
            int i;
            if ((ram_image_size <= 0) || (line <= 0))
            {
                cerr << "Internal error: "
                     << "Invalid ram_image_size or line count" << endl;
                exit( 12 );
            }
            asm_source_line_count = line;
            // Overallocate by 1, so we can index directly by line-number
            asm_source_lines = new ASM_SOURCE_PTR[asm_source_line_count+1];
            asm_source_by_pc = new ASM_SOURCE_PTR[ram_image_size+1];
            if ((! asm_source_lines) ||
                (! asm_source_by_pc))
            {
                cerr << "Internal error: "
                     << "Memory allocation failure on source pointers" << endl;
                exit( 14 );
            }
            for (i = 0; i <= asm_source_line_count; i++)
                asm_source_lines[i] = NULL;
            for (i = 0; i <= ram_image_size; i++)
                asm_source_by_pc[i] = NULL;
        }
        /* begin second pass */
        if ( yydebug )
            cout << "\n\nStarting second pass...\n";
        infile.clear(); /* Necessary... */
        infile.seekg( 0L );
        pass++;
        line = 0;
        location_counter = 0;
        return 0; /* start over */
    }
    else
        return 1; /* done! */
}

};

/* ===========================================================================

my_input

This function is dropped in in the place of the normal scanner input
function. The reason we do this is to allow us to count input lines,
generate listing output, and so on. To set this up, in the scanner
define YY_INPUT to call here instead if handling it internally. Then
whenever the scanner wants data we call here, read a line, return
it. At the end of file it is necessary to return a 0 to indicate "no
more".

Inputs:  buf - pointer to a place where the scanner wants the data
         max_size - the largest buffer that the scanner will accept
Outputs: buf - filled in with data from the input file (one byte at a
         time using this function, although the data is still buffered
         internally to us, so it isn't too inefficient).
Returns: 0 on end-of-file
         N - number of bytes read into "buf" (always one this version)

=========================================================================== */

int my_input( unsigned char *buf, int max_size )
{
    if ( ! infile.eof() )
        infile.getline( listing_line, sizeof( listing_line ) );
    
    if ( infile.eof() )
    {
        listing_line[ 0 ] = '\0';
        *buf = '\0';
        return 0; // A.k.a. YY_NULL 
    }
    else
    {
        char *s;
        // Getline tosses the newline, but we want it on there.
        // Various things depend on it (it is treated as a token).
        strcat( listing_line, "\n" );
        if ( listing )
            detab( listing_line );
        line++;
        for( s = listing_line; *s; s++ )
            *buf++ = toupper( *s );
        return( s - listing_line );
    }
}

/* ===========================================================================

detab

Remove any tab characters from the input line and replace them with spaces.

Inputs:  line - the line to handle
Outputs: line - with tabs replaced by spaces
Returns: none

=========================================================================== */

void detab( char *line )
{
    static char   temp[ BUFSIZ ];
    register char *s, *d;
    int     col;

    col = 0; s = line; d = temp;
    while ( *s )
        if ( *s != '\t' )
            *d++ = *s++, col++;
        else
        {
            do  {
                *d++ = ' ';
                col++;
                } while ( col % 8 );
            s++;
        }
    *d = '\0';
    (void) strcpy( line, temp );
} 

/* ===========================================================================

de_reg

If we have a string representation for a register ("R5"), take out the
number part, convert it ti an unsigned, and pass it back out. Also
check that it is in range, and toss a yyerror if it is not.

Since we are using strtoul with a base == 0, the user can specify
strange things like "R011" which is really register 9, since 011 is
octal. Or, for that matter, "R0xb" which is register 11. (But in
reality, the latter case will not work because the scanner will return
two tokens, one for "R0" and one of type OPERAND for "xb".)

Inputs:  reg_str - the string represention of the register
Outputs: none
Returns: the nuber part, converted to unsigned

=========================================================================== */

TWO_BYTE de_reg( const char *reg_str )
{
    TWO_BYTE value;
    value = (TWO_BYTE) strtoul( reg_str + 1, NULL, 0 );
    if ( ( value >= REGISTERS        ) ||
         ( ! isdigit( reg_str[ 1 ] ) ) )
        yyerror( "Illegal register number..." );
    return( value );
}

/* Entry point to assembler */

int pki_asm()
{
    int i, bytes;

    pass = 1;  /* 2-pass assembler, ready for pass 1 */

    infile.open( filename, ios::in );
    if ( ! infile )
    {
        cerr << "Can't open source file!\n";
        exit( 2 );
    }

    /* We can test the return of yyparse, but I'll go ahead */
    /* and track an error count internally and use that.    */

    (void) yyparse();

    if ( ! err_count )
    {
        if ( listing )
            cout << '\n';
        cout << "Source assembled ok." << endl;
    }
    else
    {
        cerr << "Completed with " << err_count << " errors.\n";
        exit( 1 );
    }
    
    infile.close();
    
    if ( listing )
    {
        qsort( (char *) symbol_table, symbols, sizeof( symbol_table[ 0 ] ),
               sym_compare );
        cout << "\nSymbols by name:\n";
        for( i = 0; i < symbols; i++ )
            cout << "\t0x" << hex << setw( 4 ) << setfill( '0' ) 
                 << symbol_table[ i ].location << " "
                 << symbol_table[ i ].str_val << endl;
        qsort( (char *) symbol_table, symbols, sizeof( symbol_table[ 0 ] ),
               addr_compare );
        cout << "\nSymbols by address:\n";
        for( i = 0; i < symbols; i++ )
            cout << "\t0x" << hex << setw( 4 ) << setfill( '0' ) 
                 << symbol_table[ i ].location << " "
                 << symbol_table[ i ].str_val << endl;
    }

    return 0;
          
} /* pki_asm */
